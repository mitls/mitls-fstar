module StreamPlain

open FStar.Seq
open Platform.Bytes
open Platform.Error

open TLSError
open TLSConstants
open TLSInfo
open Range
open Content

// Defines an abstract "plain i len" plaintext typed interface from
// the more concrete & TLS-specific type "Content.fragment i".

// This module is used only for TLS 1.3.

type id = i:id { ~ (is_AEAD i.aeAlg) } //  { pv_of_id i = TLS_1p3 }  


(***  plain := fragment | CT | 0*  ***)

// naming: we switch from fragment to plain as we are no longer TLS-specific
// similarly, the length accounts for the TLS-specific CT byte.
// internally, we know len > 0

private type plain (i:id) (len:nat) = f:fragment i { len = snd (Content.rg i f) + 1 }

let pad payload ct (len:nat { len > length payload}) = payload @| ctBytes ct @| createBytes (len - length payload - 1) 0uy

val ghost_repr: #i:id -> #len: nat -> f:plain i len -> GTot (bs:lbytes len)
let ghost_repr i len f = 
  let ct,_ = ct_rg i f in 
  let payload = Content.ghost_repr #i f in 
  pad payload ct len

val repr: i:id{ ~(safeId i)} -> len: nat -> p:plain i len -> Tot (b:lbytes len {b = ghost_repr #i #len p})
let repr i len f = 
  let ct,_ = ct_rg i f in 
  let payload = Content.repr #i f in 
  pad payload ct len

// slight code duplication between monads; avoidable? 

(* 
val scan: bs:bytes -> j: nat { j < length bs /\ (forall (k:nat {j < k /\ k < length bs}). Seq.index bs k = 0uy) } -> 
  Tot (o:option(j:nat { j < length bs /\ Seq.index bs j <> 0uy /\ (forall (k:nat {j < k /\ k < length bs}). Seq.index bs k = 0uy) }))
 
let rec scan bs j =
  if Seq.index bs j <> 0uy then Some j 
  else if j = 0            then None 
  else scan bs (j-1)
*)

val scan: i:id { ~ (authId i) } -> bs:bytes -> 
  j: nat { j < length bs /\ (forall (k:nat {j < k /\ k < length bs}). Seq.index bs k = 0uy) } -> 
  Tot(Result(p:plain i (length bs) { bs = ghost_repr #i #(length bs) p }))
 
let rec scan i bs j =
  let len = length bs in 
  if len > max_TLSPlaintext_fragment_length || j = 0 then Error (AD_decode_error, "") else
  match Seq.index bs j with 
  | 0uy  -> scan i bs (j-1)
  | 21uy -> let rg = (0, len - 1) in
           let payload, rest = Platform.Bytes.split bs j in 
           let f = CT_Alert rg payload in 
           lemma_eq_intro bs (pad payload Alert len);
           Correct f
  | 22uy -> let rg = (0, length bs - 1) in
           let payload = fst (Platform.Bytes.split bs j) in 
           let f = CT_Handshake rg payload in 
           lemma_eq_intro bs (pad payload Handshake len);
           Correct f
  | 23uy -> let rg = (0, length bs - 1) in
           let payload = fst (Platform.Bytes.split bs j) in
           let d = DataStream.mk_fragment i rg payload in
           assert(forall (k:nat {j < k /\ k < length bs}). Seq.index bs k = 0uy);
           lemma_eq_intro bs (pad payload Application_data len);
           Correct (CT_Data rg d)
  | _    -> Error (AD_decode_error, "")

//val pinverse_scan: i:id -> len:nat -> f:plain i len ->
//  Lemma(let bs = ghost_repr i len f in is_Correct(scan i bs (len - 1)))


type plainrepr i = bs: bytes { length bs > 0 /\ is_Correct(scan i bs (length bs - 1)) }

val mk_plain: i:id{ ~(authId i)} -> bs:plainrepr i -> Tot (p:plain i (length bs) {bs = ghost_repr #i #(length bs) p})

let mk_plain i bs = match scan i bs (length bs - 1) with Correct p -> p


