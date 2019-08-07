module Model.AEAD

module U8 = FStar.UInt8
module Seq = FStar.Seq
module SC = Spec.AEAD
module U32 = FStar.UInt32
module HS = FStar.HyperStack
module HST = FStar.HyperStack.ST
module G = FStar.Ghost
module F = Flags
module B = LowStar.Buffer // for loc, modifies

(* THIS MODULE MUST NOT BE EXTRACTED *)

type plain_pred = (plain: Seq.seq SC.uint8) -> Tot Type0

val state (a: SC.supported_alg) (phi: plain_pred) : Tot Type0

val state_kv
  (#a: SC.supported_alg) (#phi: plain_pred)
  (s: state a phi)
: Tot (SC.kv a)

val invariant (#a: SC.supported_alg) (#phi: plain_pred) (h: HS.mem) (s: state a phi) : GTot Type0

val footprint (#a: SC.supported_alg) (#phi: plain_pred) (s: state a phi) : GTot B.loc

val frame_invariant
  (#a: SC.supported_alg) (#phi: plain_pred) (h: HS.mem) (s: state a phi)
  (l: B.loc) (h' : HS.mem)
: Lemma
  (requires (B.modifies l h h' /\ B.loc_disjoint l (footprint s) /\ invariant h s))
  (ensures (invariant h' s))

val fresh_iv
  (#a: SC.supported_alg)
  (#phi: plain_pred)
  (h: HS.mem)
  (s: state a phi) // key
  (iv: SC.iv a)
: GTot Type0

val frame_fresh_iv
  (#a: SC.supported_alg)
  (#phi: plain_pred)
  (h: HS.mem)
  (s: state a phi) // key
  (iv: SC.iv a)
  (l: B.loc)
  (h' : HS.mem)
: Lemma
  (requires (
    invariant h s /\
    B.modifies l h h' /\
    B.loc_disjoint l (footprint s)
  ))
  (ensures (fresh_iv h' s iv <==> fresh_iv h s iv))

val is_fresh_iv
  (#a: SC.supported_alg)
  (#phi: plain_pred)
  (s: state a phi) // key
  (iv: SC.iv a)
: HST.Stack bool
  (requires (fun h -> 
    Flags.ideal_iv == true /\
    invariant h s
  ))
  (ensures (fun h res h' ->
    B.modifies B.loc_none h h' /\
    (res == true <==> fresh_iv h s iv)
  ))

val encrypt
  (#a: SC.supported_alg)
  (#phi: plain_pred)
  (s: state a phi) // key
  (iv: SC.iv a)
  (plain: SC.plain a)
: HST.Stack (SC.encrypted plain)
  (requires (fun h ->
    Flags.model == true /\
    invariant h s /\
    (Flags.ideal_iv == true ==> fresh_iv h s iv) /\
    phi plain
  ))
  (ensures (fun h cipher h' -> 
    B.modifies (footprint s) h h' /\
    Seq.length cipher <= SC.max_length a + SC.tag_length a /\
    invariant h' s /\
    (Flags.ideal_AEAD == false ==>
      SC.encrypt (state_kv s) iv Seq.empty plain == cipher
  )))

val decrypt
  (#a: SC.supported_alg)
  (#phi: plain_pred)
  (s: state a phi) // key
  (iv: SC.iv a)
  (cipher: SC.cipher a { Seq.length cipher <= SC.max_length a + SC.tag_length a })
: HST.Stack (option (SC.decrypted cipher))
  (requires (fun h ->
    Flags.model == true /\
    invariant h s
  ))
  (ensures (fun h res h' ->
    B.modifies (footprint s) h h' /\
    (Flags.ideal_AEAD == false ==> (
      SC.decrypt (state_kv s) iv Seq.empty cipher == res
    )) /\
    invariant h' s /\
    begin match res with
    | None -> True
    | Some plain ->
      (Flags.ideal_AEAD == true ==> phi plain)
    end
  ))