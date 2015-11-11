module TLS

// Draft TLS API using hyperheaps in F*
// incorporating definitions and comments from TLS.fs7 and TLS.fsi
// - each connection runs through a sequence of epochs
// - each epoch has two streams of application data
// - each secure stream maintains a log of data (and warnings) written so far
//   and the reader position in that log.

open Heap
open FStar.HyperHeap
open Seq
open SeqProperties // for e.g. found

open Platform.Bytes
open Platform.Error
open Platform.Tcp

open TLSError
open TLSInfo

// using DataStream

type dispatch

// consider making this type private, with explicit accessors
type connection = | C:
  #rid:    regionId ->
  tcp:     Tcp.networkStream ->
  hs:      Handshake.hs { Handshake.HS.rid = rid } (* providing role, config, and uid *) ->
  alert:   Alert.state ->
  reading: rref rid dispatch ->
  writing: rref rid dispatch ->
  connection

// let c_rid  c = C.rid c
// let c_tcp  c = C.tcp c
let c_role c = Handshake.HS.role (C.hs c)
let c_id   c = Handshake.HS.id   (C.hs c)
let c_cfg  c = Handshake.HS.cfg  (C.hs c)

// val c_resume:    connection -> Tot (option sessionID)
// val c_epoch:  cn:connection -> Tot (rref (c_region cn) epoch)

//------------------------- control API ----------------------------

//? how to define boolean functions abbreviating formulas in specs?

let initial:  -> cn: connection -> h:heap -> Tot bool =
    extends (c_region cn) root /\ // we allocate a fresh, opaque region for the connection
    c_role cn   = role /\
    c_tcp cn    = ns /\
    c_resume cn = resume /\
    c_config cn = c /\
    sel h (c_epoch cn) = Init // assuming Init epoch implicitly have no data sent/received

//* should we still return ConnectionInfo ?
//* merging connect and resume with an optional sessionID
val connect: ns:Tcp.networkStream -> c:config -> resume: option sessionID -> ST connection
  (requires (fun h0 -> True))
  (ensures (fun h0 cn h1 ->
    modifies Set.empty h0 h1 /\
    initial Client ns c resume cn h1
    //TODO: even if the server declines, we authenticate the client's intent to resume from this sid.
  ))

//* do we need both?
val accept: Tcp.TcpListener -> c:config -> ST connection
  (requires (fun h0 -> True))
  (ensures (fun h0 cn h1 ->
    modifies Set.empty h0 h1 /\
    exists ns. initial Server ns c None cn h1
  ))
val accept_connected: ns:Tcp.NetworkStream -> c:config -> ST connection
  (requires (fun h0 -> True))
  (ensures (fun h0 cn h1 ->
    modifies Set.empty h0 h1 /\
    initial Server ns c None cn h1
  ))

//TODO merge implementations from resume, connect, init, accept...

//* not sure how to record the change of config in the calls below
//* it is needed to ask for new certs, but I'd rather avoid mutable configs

// the client can ask for rekeying --- no immediate effect
val rekey: cn:connection { c_role cn = Client } -> ST unit
  (requires (fun h0 -> True))
  (ensures (fun h0 b h1 -> modifies Set.empty h0 h1 // no visible change in cn
  ))

val rehandshake: cn:connection { c_role cn = Client } -> c:config -> ST unit
  (requires (fun h0 -> True))
  (ensures (fun h0 b h1 -> modifies Set.empty h0 h1 // no visible change in cn
  ))

val request: cn:connection { c_role cn = Server } -> c:config -> ST unit
  (requires (fun h0 -> True))
  (ensures (fun h0 b h1 -> modifies Set.empty h0 h1 // no visible change in cn
  ))

//------------------------- reading ----------------------------

type ioresult_i (e:epoch) =
    | Read of DataStream.delta e
        // this delta has been added to the input stream; we may have read
        // - an application-data fragment or a warning (leaving the connection live)
        // - a closure or a fatal alert (tearing down the connection)
        // If the alert is a warning, the connection remains live.
        // If the alert is final, the connection has been closed by our peer;
        // the application may reuse the underlying TCP stream
        // only after normal closure (a = AD_close_notify)

    | ReadError of option alertDescription * string
        // We encountered an error while reading, so the connection dies.
        // we return the fatal alert we may have sent, if any,
        // or None in case of an internal error.
        // The connection is gone; its state is undefined.

    | CertQuery of query * bool
        // We received the peer certificates for the next epoch, to be authorized before proceeding.
        // the bool is what the Windows certificate store said about this certificate.
    | CompletedFirst
        // Handshake is completed, and we have already sent our finished message,
        // so only the incoming epoch changes
    | CompletedSecond
        // Handshake is completed, and we have already sent our finished message,
        // so only the incoming epoch changes
    | DontWrite
        // Nothing read yet, but we can't write anymore.

    // internal states only
    | ReadAgain
    | ReadAgainFinishing
    | ReadFinished

let live_i e r = // is the connection still live?
  match r with
  | Read d      -> not(DataStream.final e d)
  | ReadError _ -> false
  | _           -> true


// let's specify reading d off the input DataStream (incrementing the reader pos)

type delta h0 cn =
  let id, _ = sel_reader h cn in
  DataStream.delta id

val sel_reader: h:heap -> cn:connection -> Tot (i:id * StatefulLHAE.reader i) // self-specified
let sel_reader h cn =
  let hs_log = sel h (Handshake.HS.log (Connection.hs cn)) in
  match hs_log.[0] with
  | Keys h r w -> (hs_id h, r)
  // todo: add other cases depending on dispatch state

val append_r: h0:heap -> heap -> cn:connection -> d: delta h0 cn -> Tot bool
let append_r h0 h1 cn d  =
  let id, reader = sel_reader h0 cn in // we statically know those are unchanged
  let log0 = sel h0 (StatefulLHAE.StReader.log reader) in
  let log1 = sel h1 (StatefulLHAE.StReader.log reader) in
  let pos0 = sel h0 (StatefulLHAE.StReader.seqn reader) in
  let pos1 = sel h1 (StatefulLHAE.StReader.seqn reader) in
  log1 = log0 &&
  pos1 = pos0 + 1 &&
  log1.[pos0] = d

//* do we also need to specify when the connection is writable?

//* we used to specify the resulting connection in ioresult_i,
//* now we do that in the read postcondition

val read: cn:connection -> ST ioresult_i
  (requires (fun h0 -> live h0 cn))
  (ensures (fun h0 r h1 ->
    modifies (c_region cn) h0 h1 /\
    live h1 cn = live_i r /\
    (is_Read d  ==> append_r h0 h1 cn d)

    // (is_Close r \/ isFatal r) /\ Auth(epoch cn) ==> we have read everything
    // is_Warning r /\ Auth(epoch cn) ==> this warning was sent at this AD position
  ))

// responding to a certificate-validation query,
// so that we have an explicit user decision to blame,
// but in fact a follow-up read would do as well.
// to be adapted once we have a proper PKI model
val authorize : c:Connection -> q:query -> ST ioresult_i
  (requires (fun h0 -> True))
  (ensures (fun h0 result h1))
val refuse    : c:Connection -> q:query -> ST unit
  (requires (fun h0 -> True))
  (ensures (fun h0 result h1))

//------------------------- writing ----------------------------

type ioresult_w =
    // public results
    | Written       // Application data was written, and the connection remains writable
    | MustRead            // Nothing written, and the connection is busy completing a handshake
    | WriteError of alertDescription * string // The connection is down, possibly after sending an alert
//  | WritePartial of unsent_data // worth restoring?

    // transient, internal results
    | WriteDone           // No more data to send in the current state
    | WriteHSComplete     // The handshake is complete [while reading]
    | SentClose           // [while reading]
    | WriteAgain          // there is more to send
    | WriteAgainFinishing // the outgoing epoch changed & more to send to finish the handshake
    | WriteAgainClosing   // we are tearing down the connection & must still send an alert

type ioresult_o = r:io_result_w
  { is_WriteComplete r \/ is_MustRead r \/ is_WriteError r }

//* was: d:(;ConnectionEpochOut(c),CnStream_o(c)) msg_o
val write: cn:connection -> d:msg_o cn -> ST ioresult_o
  (requires (fun h0 ->
    True
    // the connection is writable: see CanWrite(CnInfo(c))
  ))
  (ensures (fun h0 result h1 ->
    True
    // result = Written -> sel h1 cn.written = snoc (sel h0 cn.written) d
    // result = MustRead -> cn.written is unchanged
  ))

let read ca =
  let outcome = Dispatch.read ca in
    match outcome with
      | RError(err) -> ReadError(None,err)
      | WriteOutcome(WError(err)) -> ReadError(None,err)
      | RAppDataDone(b) -> Read(cb,b)
      | RQuery(q,adv) -> CertQuery(cb,q,adv)
      | RHSDone -> CompletedFirst(cb)
      | RClose -> Close (networkStream cb)
      | RFatal(ad) -> Fatal(ad)
      | RWarning(ad) -> Warning(cb,ad)
      | WriteOutcome(WriteFinished) -> DontWrite(cb)
      | WriteOutcome(WHSDone) -> CompletedSecond(cb)
      | WriteOutcome(SentFatal(ad,s)) -> ReadError(Some(ad),s)
      | WriteOutcome(SentClose) -> Close (networkStream cb)
      | WriteOutcome(WriteAgain) -> unexpected "[read] Dispatch.read should never return WriteAgain"
      | _ -> ReadError(None, perror __SOURCE_FILE__ __LINE__ "Invalid dispatcher state. This is probably a bug, please report it")

let write c msg =
    let c,outcome = Dispatch.write c msg in
    match outcome with
      | WError(err) -> WriteError(None,err)
      | WAppDataDone -> Written c
      | WDone ->
          (* We are in the open state, and providing some data to be sent, so only WAppDataDone can apply here *)
          WriteError(None, perror __SOURCE_FILE__ __LINE__ "Invalid dispatcher state. This is probably a bug, please report it")
      | WHSDone ->
          (* A top-level write should never lead to HS completion.
             Currently, we report this as an internal error.
             Being more precise about the Dispatch state machine, we should be
             able to prove that this case should never happen, and so use the
             unexpected function. *)
          WriteError(None, perror __SOURCE_FILE__ __LINE__ "Invalid dispatcher state. This is probably a bug, please report it")
      | WriteFinished ->
          MustRead(c)
      | SentClose ->
          (* A top-level write can never send a closure alert on its own.
             Either the user asks for half_shutdown, and the connection is consumed,
             or it asks for full_shutdown, and then it cannot write anymore *)
          WriteError(None, perror __SOURCE_FILE__ __LINE__ "Invalid dispatcher state. This is probably a bug, please report it")
      | SentFatal(ad,err) ->
          WriteError(Some(ad),err)
      | WriteAgain | WriteAgainFinishing | WriteAgainClosing ->
          unexpected "[write] writeAll should never ask to write again"



let full_shutdown c = Dispatch.full_shutdown c
let half_shutdown c = Dispatch.half_shutdown c


// AP: we will have to internally send a fatal alert,
// AP: and this might fail. We might want to give some feedback to the user.
// AP: Same as for half_shutdown

let authorize c q =
    let cb,outcome = Dispatch.authorize c q in
    match outcome with
      | WriteOutcome(WError(err)) -> ReadError(None,err)
      | RError(err) -> ReadError(None,err)
      | RHSDone -> CompletedFirst(cb)
      | RClose -> Close (networkStream cb)
      | RFatal(ad) -> Fatal(ad)
      | RWarning(ad) -> Warning(cb,ad)
      | WriteOutcome(WriteFinished) -> DontWrite(cb)
      | WriteOutcome(WHSDone) -> CompletedSecond(cb)
      | WriteOutcome(SentFatal(ad,s)) -> ReadError(Some(ad),s)
      | WriteOutcome(SentClose) -> Close (networkStream cb)
      | WriteOutcome(WriteAgain) -> unexpected "[read] Dispatch.read should never return WriteAgain"
      | _ -> ReadError(None, perror __SOURCE_FILE__ __LINE__ "Invalid dispatcher state. This is probably a bug, please report it")

let refuse c q        = Dispatch.refuse c q
let getEpochIn c      = Dispatch.getEpochIn c
let getEpochOut c     = Dispatch.getEpochOut c
let getSessionInfo ki = epochSI(ki)
let getInStream  c    = Dispatch.getInStream c
let getOutStream c    = Dispatch.getOutStream c
