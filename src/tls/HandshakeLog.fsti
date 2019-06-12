module HandshakeLog

/// Handles incoming and outgoing messages for the TLS handshake,
/// grouping them into flights, hiding their parsing/formatting, and
/// incrementally computing hashes of the whole session transcript.
///
/// Private state is held in a single reference (with a local
/// specification expressed using refinements) so we don't need an
/// external stateful invariant.
///
/// 18-02-28 To support stateless HelloRetryRequests, we will now
///          tolerate updates on the server in the initial "open"
///          state (and hence need a stateful invariant) until the
///          hash algorithm is fixed.
/// 
/// 17-11-11 Partly verified, still missing regions and modifies
///          clauses.  We are planning a rewrite of this interface
///          from lists of messages to constructed flights, to
///          facilitate its low-level extraction.

(* TODO
- add subregion discipline and the corresponding framing conditions
- make prior ghost
- add record-layer calls, keeping track of bytes buffers and their effective lengths
- support abstract plaintexts and multiple epochs
*)

open FStar.Ghost 

open Mem
open HandshakeMessages // for pattern matching on messages

module HS = FStar.HyperStack

open FStar.Error
open TLSError
open Hashing
open Hashing.CRF
open FStar.Bytes

let hash = Hashing.h //18-08-31 

include TLS.Handshake.Send 


/// Specifies which messages indicate the end of incoming flights and
/// triggers their handshake processing.
let eoflight = function
  | Client_hello
  | End_of_early_data
  | Server_hello
  | Server_hello_done
  | New_session_ticket
  | Finished -> true
  | _ -> false

/// Specifies which messages require an intermediate transcript hash
/// in incoming flights. In doubt, we hash!
let tagged (m: msg) : bool =
  match tag_of m with
  | Client_hello
  | Server_hello
  | End_of_early_data        // for Client finished
  | Certificate       // for CertVerify payload in TLS 1.3
  | Encrypted_extensions // For PSK handshake: [EE; Finished]
  | Certificate_verify   // for ServerFinish payload in TLS 1.3
  | Client_key_exchange   // only for client signing
  | New_session_ticket    // for server finished in TLS 1.2
  | Finished -> true    // for 2nd Finished
  | _ -> false
// NB CCS is not explicitly handled here, but can trigger tagging and end-of-flights.

let weak_valid_transcript hsl =
    match hsl with
    | [] -> true
    | [Msg (M_client_hello ch)] -> true
    | (Msg (M_client_hello ch)) :: (Msg (M_server_hello sh)) :: rest -> true
    | _ -> false

let transcript_version (x: list msg {weak_valid_transcript x}) = 
    match x with
    | (Msg (M_client_hello ch)) :: (Msg (M_server_hello sh)) :: rest -> Some sh.version
    | _ -> None

(* TODO: move to something like FStar.List.GTot *)
let rec gforall (#a: Type) (f: (a -> GTot bool)) (l: list a) : GTot bool =
  match l with
  | [] -> true
  | x :: q -> f x && gforall f q

let valid_transcript (hsl:list msg) : GTot bool =
  weak_valid_transcript hsl

let hs_transcript: Type0 = l:list msg {valid_transcript l}

let append_transcript (l:hs_transcript) (m:list msg {valid_transcript (l @ m)}): Tot hs_transcript = l @ m

val transcript_bytes: hs_transcript -> GTot bytes

// formatting of the whole transcript is injective (what about binders?)
val transcript_format_injective: ms0:hs_transcript -> ms1:hs_transcript ->
  Lemma(Bytes.equal (transcript_bytes ms0) (transcript_bytes ms1) ==> ms0 == ms1)

//val transcript_bytes_append: ms0: hs_transcript -> ms1: list msg ->
//  Lemma (transcript_bytes (ms0 @ ms1) = transcript_bytes ms0 @| transcript_bytes ms1)

let narrowTag a (b:anyTag { len b = Hacl.Hash.Definitions.hash_len a}) : tag a = b
let hash_length (b:anyTag) = len b

// full specification of the hashed-prefix tags required for a given flight
// (in relational style to capture computational-hashed)
//val tags: a:alg -> prior: list msg -> ms: list msg -> hs: list anyTag(tag a) -> Tot Type0 (decreases ms)
#set-options "--admit_smt_queries true"
let rec tags (a:alg) (prior: list msg) (ms: list msg) (hs:list anyTag) : Tot Type0 (decreases ms) =
  match ms with
  | [] -> hs == []
  | m :: ms ->
      let prior = prior@[m] in
      match tagged m, hs with
      | true, h::hs ->
          valid_transcript prior /\ (
          let t = transcript_bytes prior in
          (  hash_length h = Hacl.Hash.Definitions.hash_len a /\
             (  let h = narrowTag a h in
                hashed a t /\ h == Hashing.h a t /\
                tags a prior ms hs ))
          )
      | false, hs -> tags a prior ms hs
      | _ -> False
#reset-options

val tags_append: 
  a:alg -> 
  prior: list msg -> 
  ms0: list msg -> 
  ms1: list msg -> 
  hs0: list anyTag -> 
  hs1: list anyTag -> 
  Lemma (tags a prior ms0 hs0 /\ tags a (prior@ms0) ms1 hs1 ==> tags a prior (ms0 @ ms1) (hs0 @ hs1))

(*
type usage =
  | HandshakeOnly
  | Writable
  | Complete // always usable for writing appdata
*)

(* STATE *)

val log: Type0
type t = log

val get_reference: log -> GTot HS.some_ref
let region_of s =
  let (HS.Ref r) = get_reference s in
  HS.frameOf r

let modifies_one (s: log) (h0 h1: HS.mem) =
  let (HS.Ref r) = get_reference s in
  let rg = region_of s in (
    HS.modifies (Set.singleton rg) h0 h1 /\
    HS.modifies_ref rg (Set.singleton (HS.as_addr r)) h0 h1
  )


// the Handshake can write
val writing: h:HS.mem -> log -> GTot bool

// the assigned hash algorithm, if any
val hashAlg: h:HS.mem -> log -> GTot (option Hashing.alg)

// the transcript of past messages, in both directions
val transcript: h:HS.mem -> log -> GTot hs_transcript

//17-04-12 for now always called with pv = None.
val create: reg:rgn -> pv:option TLSConstants.protocolVersion -> ST log
  (requires (fun h -> True))
  (ensures (fun h0 out h1 ->
    HS.modifies (Set.singleton reg) h0 h1 /\ // todo: we just allocate (ref_of out)
    transcript h1 out == [] /\
    writing h1 out /\
    hashAlg h1 out == None ))

val setParams: s:log ->
  TLSConstants.protocolVersion ->
  a: Hashing.alg ->
  option TLSConstants.kexAlg ->
  option CommonDH.group -> ST unit
  (requires (fun h0 -> None? (hashAlg h0 s)))
  (ensures (fun h0 _ h1 ->
    modifies_one s h0 h1 /\
    transcript h1 s == transcript h0 s /\
    writing h1 s == writing h0 s /\
    hashAlg h1 s == Some a ))


(* Outgoing *)

// We send one message at a time (or in two steps for CH);
// for call-site simplicity we distinguish between tagged and untagged messages
// We require ms_0 be empty; otherwise the hash computation is messed up

// We do not enforce "tagged m", a local decision

// shared postcondition
let write_transcript h0 h1 (s:log) (m:msg) =
    modifies_one s h0 h1 /\
    writing h1 s /\
    hashAlg h1 s == hashAlg h0 s /\
    transcript h1 s == transcript h0 s @ [m]
(*
val load_stateless_cookie: s:log -> h:hrr -> digest:bytes -> ST unit
  (requires (fun h0 -> writing h0 s /\ valid_transcript (transcript h0 s)))
  (ensures (fun h0 _ h1 -> modifies_one s h0 h1 /\ writing h1 s))
*)

val send_truncated: s:log -> m:msg -> t:UInt32.t -> ST unit
  (requires (fun h0 ->
    writing h0 s /\
    valid_transcript (transcript h0 s @ [m])))
  (ensures (fun h0 _ h1 -> write_transcript h0 h1 s m))

val send: s:log -> m:msg -> ST unit
  (requires (fun h0 ->
    writing h0 s /\
    valid_transcript (transcript h0 s @ [m]) /\
    (*match m with
    | HelloRetryRequest hrr -> Some? (TLSConstants.cipherSuite_of_name hrr.hrr_cipher_suite)
    | _ ->*) True))
  (ensures (fun h0 _ h1 -> write_transcript h0 h1 s m))

val send_raw: s:log -> b:bytes -> ST unit
  (requires (fun h0 -> writing h0 s))
  (ensures (fun h0 _ h1 ->
    modifies_one s h0 h1 /\
    writing h1 s /\
    hashAlg h1 s == hashAlg h0 s))

#set-options "--admit_smt_queries true"
val hash_tag: #a:alg -> s:log -> ST (tag a)
  (requires fun h0 -> True)
  (ensures fun h0 h h1 ->
    let bs = transcript_bytes (transcript h1 s)  in
    h0 == h1 /\
    hashed a bs /\ h == Hashing.h a bs )

val hash_tag_truncated: #a:alg -> s:log -> suffix_len:UInt32.t
  -> ST (tag a)
  (requires fun h0 ->
    let bs = transcript_bytes (transcript h0 s) in
    None? (hashAlg h0 s) /\
    UInt32.v suffix_len <= length bs )
  (ensures fun h0 h h1 ->
    let bs = transcript_bytes (transcript h1 s)  in
    h0 == h1 /\ UInt32.v suffix_len <= length bs /\ (
    let prefix = sub bs FStar.UInt32.(len bs -^ suffix_len) suffix_len in
    hashed a prefix /\ h == Hashing.h a prefix))

val send_tag: #a:alg -> s:log -> m:msg -> ST (tag a)
  (requires fun h0 ->
    writing h0 s /\
    valid_transcript (transcript h0 s @ [m]))
  (ensures fun h0 h h1 ->
    let bs = transcript_bytes (transcript h1 s)  in
    write_transcript h0 h1 s m /\
    hashed a bs /\ h == Hashing.h a bs)

// An ad hoc variant for caching a message to be sent immediately after the CCS
// We always increment the writer, sometimes report handshake completion.
// This variant also sets flags and 'drops' the writing state
val send_CCS_tag: #a:alg -> s:log -> m:msg -> complete:bool -> ST (tag a)
  (requires (fun h0 ->
    writing h0 s /\
    valid_transcript (transcript h0 s @ [m]) /\
    hashAlg h0 s = Some a ))
  (ensures (fun h0 h h1 ->
    let bs = transcript_bytes (transcript h1 s)  in
    write_transcript h0 h1 s m /\
    hashed a bs /\ h == Hashing.h a bs ))

// Setting signals 'drops' the writing state, to prevent further writings until the signals have been transmitted
val send_signals: s:log -> next_keys:option (bool & bool) -> complete:bool -> ST unit
  (requires fun h0 ->
    writing h0 s /\
    (Some? next_keys || complete))
  (ensures fun h0 _ h1 ->
    modifies_one s h0 h1 /\
    hashAlg h0 s == hashAlg h1 s /\
    transcript h0 s == transcript h1 s)


// provides outputs to the record layer, one fragment at a time
// never fails, in contrast with Handshake.next_fragment

val to_be_written: s:log -> ST nat
  (requires fun h0 -> True)
  (ensures fun h0 _ h1 -> modifies_none h0 h1)

val write_at_most: s:log -> i:id -> max:nat -> ST (outgoing i)
  (requires fun h0 -> True)
  (ensures fun h0 _ h1 ->
    modifies_one s h0 h1 /\
    hashAlg h0 s == hashAlg h1 s /\
    transcript h0 s == transcript h1 s)

val next_fragment: s:log -> i:id -> ST (outgoing i)
  (requires fun h0 -> True)
  (ensures fun h0 _ h1 ->
    modifies_one s h0 h1 /\
    hashAlg h0 s == hashAlg h1 s /\
    transcript h0 s == transcript h1 s)
// the post-condition misses outgoing-related properties
// when changing keys (or is it for Handshake to say?)


(* Incoming *)

// We receive messages & hashes in whole flights;
// Until a full flight is received, we lose "writing h1 r"
val receive: s:log -> bytes -> ST (result (option (list msg & list anyTag)))
//TODO return instead ST (result (list msg * list anyTag))
  (requires (fun h0 -> True))
  (ensures (fun h0 o h1 ->
    let oa = hashAlg h1 s in
    let t0 = transcript h0 s in
    let t1 = transcript h1 s in
    oa == hashAlg h0 s /\
    modifies_one s h0 h1 /\ (
    match o with
    | Error _ -> True // left underspecified
    | Correct None ->
        t1 == t0
    | Correct (Some (ms, hs)) ->
        t1 == t0 @ ms /\
        writing h1 s /\
        (match oa with Some a -> tags a t0 ms hs | None -> hs == [])  )))

// We receive CCS as external end-of-flight signals;
// we return the messages & hashes processed so far, and their final tag;
// we still can't write (we should receive Finished next)
// This should *fail* if there are pending input bytes.
val receive_CCS: #a:Hashing.alg -> s:log -> ST (result (list msg & list anyTag & anyTag))
  (requires (fun h0 -> hashAlg h0 s == Some a))
  (ensures (fun h0 res h1 ->
    let oa = hashAlg h1 s in
    let t0 = transcript h0 s in
    let t1 = transcript h1 s in
    modifies_one s h0 h1 /\
    hashAlg h0 s == hashAlg h1 s /\ (
    match res with
    | Error _ -> True // left underspecified
    | Correct (ml,tl,h) ->
       t1 == t0 @ ml /\ tags a t0 ml tl)))
