module HSL.Receive

open FStar.Integers
open FStar.HyperStack.ST

module G = FStar.Ghost
module List = FStar.List.Tot

module HS = FStar.HyperStack
module B = LowStar.Buffer

module HSM = HandshakeMessages
module LP = LowParse.Low.Base

open HSL.Common

#reset-options "--max_fuel 0 --max_ifuel 0 --using_facts_from '* -FStar.Tactics -FStar.Reflection'"

noeq
type hsl_state = {
  rgn: Mem.rgn;
  from_to: B.pointer (option range_t);
  parsed_bytes: (p:B.pointer (G.erased bytes){
   let open B in
   let locs =
     [loc_buffer from_to;
      loc_buffer p]
   in
    all_disjoint locs /\
    rgn `region_includes` B.loc_union_l locs
  });
}

let region_of s = s.rgn

let index_from_to s h = B.deref h s.from_to

let parsed_bytes s h = G.reveal (B.deref h s.parsed_bytes)

let invariant s h =
  B.live h s.from_to /\
  B.live h s.parsed_bytes

let footprint s = B.(loc_union (loc_buffer s.from_to) (loc_buffer s.parsed_bytes))

let frame_hsl_state _ _ _ _ = ()

let create r =
  let from_to = B.malloc r None 1ul in
  let parsed_bytes = B.malloc r (G.hide (Seq.empty)) 1ul in
  { rgn = r; from_to = from_to; parsed_bytes = parsed_bytes }

let receive_flight13_ee_c_cv_fin _ _ _ _ = admit()
let receive_flight13_ee_cr_c_cv_fin _ _ _ _ = admit ()
let receive_flight13_ee_fin _ _ _ _ = admit ()
let receive_flight13_fin _ _ _ _ = admit ()
let receive_flight13_c_cv_fin _ _ _ _ = admit ()
let receive_flight13_eoed _ _ _ _ = admit ()
let receive_flight13_nst _ _ _ _ = admit ()