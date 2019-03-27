module HSL.Receive

open FStar.Integers
open FStar.HyperStack.ST

module G = FStar.Ghost
module List = FStar.List.Tot

module HS = FStar.HyperStack
module ST = FStar.HyperStack.ST
module B = LowStar.Buffer

module HSM = HandshakeMessages
module LP = LowParse.Low.Base

open HSL.Common

#reset-options "--max_fuel 0 --max_ifuel 0 --using_facts_from '* -FStar.Tactics -FStar.Reflection'"

type inc_st_t = G.erased (bytes & in_progress_flt_t)

noeq
type hsl_state = {
  rgn: Mem.rgn;
  inc_st: (p:B.pointer inc_st_t{
    rgn `region_includes` B.loc_buffer p
  });
}

let region_of st = st.rgn

let parsed_bytes st h = fst (G.reveal (B.deref h st.inc_st))

let in_progress_flt st h = snd (G.reveal (B.deref h st.inc_st))

let invariant s h = B.live h s.inc_st

let footprint s = B.loc_buffer s.inc_st

let frame_hsl_state _ _ _ _ = ()

let create r =
  let inc_st = B.malloc r (G.hide (Seq.empty, F_none)) 1ul in
  { rgn = r; inc_st = inc_st }

module HSM13 = Parsers.Handshake13
module HSMType = Parsers.HandshakeType
module Fin13 = Parsers.Handshake13_m_finished
module EE = Parsers.Handshake13_m_encrypted_extensions

assume val parsing_error : TLSError.error
assume val unexpected_flight_error : TLSError.error
assume val bytes_remain_error : TLSError.error

let parse_hsm13
  (#a:Type) (#k:LP.parser_kind{k.LP.parser_kind_subkind == Some LP.ParserStrong})
  (#p:LP.parser k a) (#cl:LP.clens HSM13.handshake13 a)
  (#gacc:LP.gaccessor HSM13.handshake13_parser p cl)
  (tag:HSMType.handshakeType)
  (acc:LP.accessor gacc)
  (b:slice) (from:uint_32)
  : Stack (TLSError.result (option (G.erased a & uint_32)))
    (requires fun h ->
      LP.live_slice h b /\
      from <= b.LP.len /\
      (forall (m:HSM13.handshake13).
         (HSM13.tag_of_handshake13 m == tag) <==> cl.LP.clens_cond m))
    (ensures fun h0 r h1 ->
      B.modifies B.loc_none h0 h1 /\
      (let open FStar.Error in
       match r with
       | Error _ -> True
       | Correct None -> True
       | Correct (Some (a_msg, pos)) ->
         from <= pos /\
         LP.valid HSM13.handshake13_parser h1 b from /\
         LP.content_length HSM13.handshake13_parser h1 b from == v (pos - from) /\
         (let msg13 = LP.contents HSM13.handshake13_parser h1 b from in
          HSM13.tag_of_handshake13 msg13 == tag /\
          cl.LP.clens_get msg13 == G.reveal a_msg
    )))
  = let open FStar.Error in
  
    let pos = HSM13.handshake13_validator b from in

    if pos <= LP.validator_max_length then begin
      let parsed_tag = HSMType.handshakeType_reader b from in
      if parsed_tag = tag then
        let payload_begin = acc b from in
        let payload =
          let h = ST.get () in
          let payload = LP.contents p h b payload_begin in
          G.hide payload
        in
        Correct (Some (payload, pos))
      else Error unexpected_flight_error
    end
  else if pos = LP.validator_error_not_enough_data then Correct None
  else Error parsing_error

let save_incremental_state
  (st:hsl_state) (b:slice) (from to:uint_32) (in_progress:in_progress_flt_t)
  : Stack unit
    (requires fun h ->
      B.live h st.inc_st /\
      B.live h b.LP.base /\
      B.loc_disjoint (footprint st) (B.loc_buffer b.LP.base) /\
      from <= to /\ to <= b.LP.len)
    (ensures fun h0 _ h1 ->
      B.modifies (footprint st) h0 h1 /\
      parsed_bytes st h1 ==
        Seq.slice (B.as_seq h1 b.LP.base) (v from) (v to) /\
      in_progress_flt st h1 == in_progress)
  = let inc_st =
      let h = ST.get () in
      let parsed_bytes = LP.bytes_of_slice_from_to h b from to in
      G.hide (parsed_bytes, in_progress)
    in
    B.upd st.inc_st 0ul inc_st

let reset_incremental_state (st:hsl_state)
  : Stack unit
    (requires fun h -> B.live h st.inc_st)
    (ensures fun h0 _ h1 ->
      B.modifies (footprint st) h0 h1 /\
      parsed_bytes st h1 == Seq.empty /\
      in_progress_flt st h1 == F_none)
  =  let inc_st = G.hide (Seq.empty, F_none) in
     B.upd st.inc_st 0ul inc_st

let receive_flight13_ee_c_cv_fin _ _ _ _ = admit()
let receive_flight13_ee_cr_c_cv_fin _ _ _ _ = admit ()

let mk_ee_fin
  (begin_fin:uint_32)
  (ee_msg:G.erased EE.handshake13_m_encrypted_extensions) 
  (fin_msg:G.erased Fin13.handshake13_m_finished)
  : flight13_ee_fin
  = Mkflight13_ee_fin begin_fin ee_msg fin_msg

let receive_flight13_ee_fin st b from to =
  let open FStar.Error in

  let r = parse_hsm13
            HSMType.Encrypted_extensions
            HSM13.handshake13_accessor_encrypted_extensions
            b from in
  match r with
  | Error _ -> Error parsing_error
  | Correct None ->
    save_incremental_state st b from to F13_ee_fin;
    Correct None
  | Correct (Some (ee_payload, fin_begin)) ->
    let r = parse_hsm13 HSMType.Finished HSM13.handshake13_accessor_finished b fin_begin in
    match r with
    | Error _ -> Error parsing_error
    | Correct None ->
      save_incremental_state st b from to F13_ee_fin;
      Correct None
    | Correct (Some (fin_payload, pos)) ->
      if pos <> to then Error bytes_remain_error
      else begin
        reset_incremental_state st;
        Correct (Some (mk_ee_fin fin_begin ee_payload fin_payload))
      end

let receive_flight13_fin st b from to =
  let open FStar.Error in

  let r = parse_hsm13 HSMType.Finished HSM13.handshake13_accessor_finished b from in
  match r with
  | Error _ -> Error parsing_error
  | Correct None ->
    save_incremental_state st b from to F13_fin;
    Correct None
  | Correct (Some (fin_payload, pos)) ->
    if pos <> to then Error bytes_remain_error
    else begin
      reset_incremental_state st;
      Correct (Some ({ fin_msg = fin_payload }))
    end

let receive_flight13_c_cv_fin _ _ _ _ = admit ()
let receive_flight13_eoed _ _ _ _ = admit ()
let receive_flight13_nst _ _ _ _ = admit ()
