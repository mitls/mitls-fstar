module Content // was TLSFragment

// Multiplexing protocol payloads into record-layer plaintext
// fragments, and defining their projection to application-level
// streams.

open FStar
open FStar.Seq
open FStar.SeqProperties

open Platform.Bytes
open Platform.Error

open TLSError
open TLSConstants
open TLSInfo
open Range
open DataStream


type fragment (i:id) =
    | CT_Alert     : rg: frange i -> f: rbytes rg -> fragment i // could insist we get exactly 2n bytes
    | CT_Handshake : rg: frange i -> f: rbytes rg -> fragment i // concrete
    | CT_CCS       : fragment i // empty; never encrypted or decrypted
    | CT_Data      : rg: frange i -> f: DataStream.fragment i rg -> fragment i // abstract
// for TLS 1.3
//  | CT_EncryptedHandshake : rg: frange i -> f: Handshake.fragment i rg -> fragment i // abstract
//  | CT_EarlyData : rg: frange i -> f: DataStream.fragment i rg -> fragment i // abstract

let ct_alert (i:id) (ad:alertDescription) : fragment i = CT_Alert (2,2) (Alert.alertBytes ad)

// consider replacing (rg,f) with just bytes for HS and Alert
// consider being more concrete, e.g. CT_Alert: alertDescription -> fragment i


// move to Seq?
val split: #a: Type -> s:seq a {Seq.length s > 0} -> Tot(seq a * a)
let split s =
  let last = Seq.length s - 1 in
  Seq.slice s 0 last, Seq.index s last

// Alert fragmentation is forbidden in TLS 1.3; as a slight deviation
// from the standard, we also forbid it in earlier version. 
// Anyway, this is internal to the Alert protocol.

// Ghost projection from low-level multiplexed fragments to application-level deltas
// Some fragments won't parse; they are ignored in the projection. 
// We may prove that they are never written on authentic streams.
val project: i:id -> fs:seq (fragment i) -> Tot(seq (DataStream.delta i))
  (decreases %[Seq.length fs]) // not-quite-stuctural termination
let rec project i fs =
  if Seq.length fs = 0 then Seq.createEmpty
  else
      let fs, f = split #(fragment i) fs in
      let ds = project i fs in
      (match f with
      | CT_Data (rg: frange i) d -> cut(Wider fragment_range rg); snoc ds (DataStream.Data d)
      | CT_Alert rg alf -> // alert parsing may fail, or return several deltas
          if length alf = 2 then 
          (match Alert.parse alf with
          | Correct ad -> snoc ds (DataStream.Alert ad)
          | Error _    -> ds) // ill-formed alert contents are ignored
          else ds            // ill-formed alert packets are ignored
      | _              -> ds) // other fragments are internal to TLS

// try out a few lemmas
// we may also need a projection that takes a low-level pos and yields a high-level pos

val project_ignores_Handshake: i:id -> s: seq (fragment i) {Seq.length s > 0 /\ is_CT_Handshake (Seq.index s (Seq.length s - 1))} -> 
  Lemma(project i s = project i (Seq.slice s 0 (Seq.length s - 1)))

let project_ignores_Handshake i s = ()


// --------------- parsing and formatting content types ---------------------

type ContentType =
    | Change_cipher_spec
    | Alert
    | Handshake
    | Application_data

type ContentType13 = ct: ContentType { ct <> Change_cipher_spec }

val ctBytes: ContentType -> Tot (lbytes 1)
let ctBytes ct =
    match ct with
    | Change_cipher_spec -> abyte 20uy
    | Alert              -> abyte 21uy
    | Handshake          -> abyte 22uy
    | Application_data   -> abyte 23uy

val parseCT: pinverse_t ctBytes
let parseCT b =
    match cbyte b with
    | 20uy -> Correct Change_cipher_spec
    | 21uy -> Correct Alert
    | 22uy -> Correct Handshake
    | 23uy -> Correct Application_data
    | _    -> Error(AD_decode_error, perror __SOURCE_FILE__ __LINE__ "")

val inverse_ct: x:_ -> Lemma
  (requires (True)) 
  (ensures lemma_inverse_g_f ctBytes parseCT x)
  [SMTPat (parseCT (ctBytes x))]
let inverse_ct x = ()

val pinverse_ct: x:_ -> Lemma
  (requires (True))
  (ensures (lemma_pinverse_f_g Seq.Eq ctBytes parseCT x))
  [SMTPat (ctBytes (Correct._0 (parseCT x)))]
let pinverse_ct x = ()

let ctToString = function
    | Change_cipher_spec -> "CCS"
    | Alert              -> "Alert"
    | Handshake          -> "Handshake"
    | Application_data   -> "Data"


// --------------- conditional access to fragment representation ---------------------

val ghost_repr: #i:id -> fragment i -> GTot bytes
let ghost_repr i f =
  match f with
  | CT_Data rg d      -> DataStream.ghost_repr d
  | CT_Handshake rg f -> f
  | CT_CCS            -> empty_bytes
  | CT_Alert rg f     -> f

val repr: i:id{ ~(safeId i)} -> p:fragment i -> Tot (b:bytes {b = ghost_repr #i p})
let repr i f =
  match f with
  | CT_Data rg d      -> DataStream.repr rg d
  | CT_Handshake rg f -> f
  | CT_CCS            -> empty_bytes
  | CT_Alert rg f     -> f

let ct_rg (i:id) (f:fragment i) : ContentType * frange i =
  match f with
  | CT_Data rg d      -> Application_data, rg
  | CT_Handshake rg f -> Handshake, rg
  | CT_CCS            -> Change_cipher_spec, zero
  | CT_Alert rg f     -> Alert, rg

let rg (i:id) (f:fragment i) : frange i =
  match f with
  | CT_Data rg d      -> rg
  | CT_Handshake rg f -> rg
  | CT_CCS            -> zero
  | CT_Alert rg f     -> rg


// "plain interface" for conditional security (TODO restore details)

val mk_fragment: i:id{ ~(authId i)} -> ct:ContentType -> rg:frange i ->
  b:rbytes rg { ct = Change_cipher_spec ==> rg == zero }->
  Tot (p:fragment i {b = ghost_repr p})
let mk_fragment i ct rg b =
    match ct with
    | Application_data   -> CT_Data      rg (DataStream.mk_fragment i rg b)
    | Handshake          -> CT_Handshake rg b
    | Change_cipher_spec -> cut(Eq b empty_bytes);CT_CCS  //* rediscuss
    | Alert -> CT_Alert     rg b

val mk_ct_rg: 
  i:id{ ~(authId i)} -> 
  ct:ContentType -> 
  rg:frange i ->
  b:rbytes rg { ct = Change_cipher_spec ==> rg = zero } ->
  Lemma ((ct,rg) = ct_rg i (mk_fragment i ct rg b))
let mk_ct_rg i ct rg b = ()
