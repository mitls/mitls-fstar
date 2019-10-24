(*
  Copyright 2015--2019 INRIA and Microsoft Corporation

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

  Authors: T. Ramananandro, A. Rastogi, N. Swamy
*)
module MITLS.Repr.Handshake12

(*
 * This module provides a repr for Handshake12 messages
 *   i.e. Parsers.Handshake12
 *
 * It defines predicates for indicating that a repr from
 *   this module is a specific instance (such as CR or SHD)
 *
 * Given such a predicate (and validity of the repr),
 *   clients can obtain reprs for the instance types
 *   (e.g. repr for CR or SHD messages)
 *)

module ST = FStar.HyperStack.ST
module LP = LowParse.Low.Base
module LS = LowParse.SLow.Base
module B  = LowStar.Buffer
module HS = FStar.HyperStack
module R  = LowParse.Repr

open FStar.Integers
open FStar.HyperStack.ST

module HSM12 = Parsers.Handshake12

module HRRepr  = MITLS.Repr.HelloRequest12
module CRepr   = MITLS.Repr.Certificate12
module SKERepr = MITLS.Repr.ServerKeyExchange12
module CRRepr  = MITLS.Repr.CertificateRequest12
module SHDRepr = MITLS.Repr.ServerHelloDone12
module CVRepr  = MITLS.Repr.CertificateVerify12
module CKERepr = MITLS.Repr.ClientKeyExchange12
module NSTRepr = MITLS.Repr.NewSessionTicket12
module FinRepr = MITLS.Repr.Finished12

type t = HSM12.handshake12

type ptr =
  R.repr_ptr_p t HSM12.handshake12_parser

type pos (b:R.const_slice) =
  R.repr_pos_p t b HSM12.handshake12_parser

let is_hr (#b:R.const_slice) (r:pos b) : GTot bool =
  HSM12.M12_hello_request? (R.value_pos r)

let is_c (#b:R.const_slice) (r:pos b) : GTot bool =
  HSM12.M12_certificate? (R.value_pos r)

let is_ske (#b:R.const_slice) (r:pos b) : GTot bool =
  HSM12.M12_server_key_exchange? (R.value_pos r)

let is_cr (#b:R.const_slice) (r:pos b) : GTot bool =
  HSM12.M12_certificate_request? (R.value_pos r)

let is_shd (#b:R.const_slice) (r:pos b) : GTot bool =
  HSM12.M12_server_hello_done? (R.value_pos r)

let is_cv (#b:R.const_slice) (r:pos b) : GTot bool =
  HSM12.M12_certificate_verify? (R.value_pos r)

let is_cke (#b:R.const_slice) (r:pos b) : GTot bool =
  HSM12.M12_client_key_exchange? (R.value_pos r)

let is_nst (#b:R.const_slice) (r:pos b) : GTot bool =
  HSM12.M12_new_session_ticket? (R.value_pos r)

let is_fin (#b:R.const_slice) (r:pos b) : GTot bool =
  HSM12.M12_finished? (R.value_pos r)

type hr12_pos (b:R.const_slice) = m:pos b{is_hr m}
type c12_pos (b:R.const_slice) = m:pos b{is_c m}
type ske12_pos (b:R.const_slice) = m:pos b{is_ske m}
type cr12_pos (b:R.const_slice) = m:pos b{is_cr m}
type shd12_pos (b:R.const_slice) = m:pos b{is_shd m}
type cv12_pos (b:R.const_slice) = m:pos b{is_cv m}
type cke12_pos (b:R.const_slice) = m:pos b{is_cke m}
type nst12_pos (b:R.const_slice) = m:pos b{is_nst m}
type fin12_pos (b:R.const_slice) = m:pos b{is_fin m}


(*
 * Common precondition for functions that return the
 *   reprs for specific instance types
 *)
unfold let repr_pre (#b:R.const_slice) (r:pos b)
  : HS.mem -> Type0
  = fun h -> R.repr_pos_valid r h

let repr = pos

let end_pos #t #b (r:R.repr_pos t b)
  : GTot uint_32
  = let open R in
    r.start_pos + (Pos?.meta r).len

(*
 * Common postcondition for functions that return the
 *   reprs for specific instance types
 *)
unfold let repr_post_common
  (#b:R.const_slice)
  (#a:Type) (#k:LP.parser_kind) (#p:LP.parser k a)
  (r:repr b)  //input repr
  : HS.mem -> R.repr_pos_p a b p -> HS.mem -> Type0
  = fun h0 rr h1 ->
    let open R in
    B.(modifies loc_none h0 h1) /\
    R.repr_pos_valid rr h1 /\  //the returned repr is valid in h1
    r.start_pos <= rr.start_pos /\  //slice indices for the instance repr are contained in the slice indices of r ...
    end_pos rr <= end_pos r  //... useful for framing

let get_hr_repr (#b:R.const_slice) (r:pos b{is_hr r})
  : Stack (HRRepr.pos b)
    (requires repr_pre r)
    (ensures  fun h0 rr h1 ->
      R.value_pos r == HSM12.M12_hello_request (R.value_pos rr) /\
      repr_post_common r h0 rr h1)
  = admit()// ;
    // R.reveal_valid ();
    // let lp_b = R.to_slice b in
    // let pos = HSM12.handshake12_accessor_hello_request lp_b r.R.start_pos in
    // let end_pos = HSM12.handshake12_m12_hello_request_jumper lp_b pos in

    // R.mk_repr_pos_from_const_slice b pos end_pos HSM12.handshake12_m12_hello_request_parser32

let get_c_repr (#b:R.const_slice) (r:pos b{is_c r})
  : Stack (CRepr.pos b)
    (requires repr_pre r)
    (ensures  fun h0 rr h1 ->
      let l = Parsers.Certificate12.certificate12_bytesize (R.value_pos rr) in
      0 <= l /\ l <= 16777215 /\
      R.value_pos r == HSM12.M12_certificate (R.value_pos rr) /\
      repr_post_common r h0 rr h1)
  = admit()// ;
    // R.reveal_valid ();
    // let lp_b = R.to_slice b in
    // let pos = HSM12.handshake12_accessor_certificate lp_b r.R.start_pos in
    // let pos = HSM12.handshake12_m12_certificate_accessor lp_b pos in
    // let end_pos = Parsers.Certificate12.certificate12_jumper lp_b pos in

    // R.mk_from_const_slice b pos end_pos Parsers.Certificate12.certificate12_parser32

let get_ske_repr (#b:R.const_slice) (r:pos b{is_ske r})
  : Stack (SKERepr.pos b)
    (requires repr_pre r)
    (ensures  fun h0 rr h1 ->
      R.value_pos r == HSM12.M12_server_key_exchange (R.value_pos rr) /\
      repr_post_common r h0 rr h1)
  = admit()// R.reveal_valid ();
    // let lp_b = R.to_slice b in
    // let pos = HSM12.handshake12_accessor_server_key_exchange lp_b r.R.start_pos in
    // let end_pos = HSM12.handshake12_m12_server_key_exchange_jumper lp_b pos in

    // R.mk_from_const_slice b pos end_pos HSM12.handshake12_m12_server_key_exchange_parser32

let get_cr_repr (#b:R.const_slice) (r:pos b{is_cr r})
  : Stack (CRRepr.pos b)
    (requires repr_pre r)
    (ensures  fun h0 rr h1 ->
      R.value_pos r == HSM12.M12_certificate_request (R.value_pos rr) /\
      repr_post_common r h0 rr h1)
  = admit()// R.reveal_valid ();
    // let lp_b = R.to_slice b in
    // let pos = HSM12.handshake12_accessor_certificate_request lp_b r.R.start_pos in
    // let pos = HSM12.handshake12_m12_certificate_request_accessor lp_b pos in
    // let end_pos = Parsers.CertificateRequest12.certificateRequest12_jumper lp_b pos in

    // R.mk_from_const_slice b pos end_pos Parsers.CertificateRequest12.certificateRequest12_parser32

let get_shd_repr (#b:R.const_slice) (r:pos b{is_shd r})
  : Stack (SHDRepr.pos b)
    (requires repr_pre r)
    (ensures  fun h0 rr h1 ->
      R.value_pos r == HSM12.M12_server_hello_done (R.value_pos rr) /\
      repr_post_common r h0 rr h1)
  = admit()// R.reveal_valid ();
    // let lp_b = R.to_slice b in
    // let pos = HSM12.handshake12_accessor_server_hello_done lp_b r.R.start_pos in
    // let end_pos = HSM12.handshake12_m12_server_hello_done_jumper lp_b pos in

    // R.mk_from_const_slice b pos end_pos HSM12.handshake12_m12_server_hello_done_parser32

let get_cv_repr (#b:R.const_slice) (r:pos b{is_cv r})
  : Stack (CVRepr.pos b)
    (requires repr_pre r)
    (ensures  fun h0 rr h1 ->
      R.value_pos r = HSM12.M12_certificate_verify (R.value_pos rr) /\
      repr_post_common r h0 rr h1)
  = admit()// R.reveal_valid ();
    // let lp_b = R.to_slice b in
    // let pos = HSM12.handshake12_accessor_certificate_verify lp_b r.R.start_pos in
    // let pos = HSM12.handshake12_m12_certificate_verify_accessor lp_b pos in
    // let end_pos = Parsers.CertificateVerify12.certificateVerify12_jumper lp_b pos in

    // R.mk_from_const_slice b pos end_pos Parsers.CertificateVerify12.certificateVerify12_parser32

let get_cke_repr (#b:R.const_slice) (r:pos b{is_cke r})
  : Stack (CKERepr.pos b)
    (requires repr_pre r)
    (ensures  fun h0 rr h1 ->
      R.value_pos r == HSM12.M12_client_key_exchange (R.value_pos rr) /\
      repr_post_common r h0 rr h1)
  = admit()// R.reveal_valid ();
    // let lp_b = R.to_slice b in
    // let pos = HSM12.handshake12_accessor_client_key_exchange lp_b r.R.start_pos in
    // let end_pos = HSM12.handshake12_m12_client_key_exchange_jumper lp_b pos in

    // R.mk_from_const_slice b pos end_pos HSM12.handshake12_m12_client_key_exchange_parser32

let get_nst_repr (#b:R.const_slice) (r:pos b{is_nst r})
  : Stack (NSTRepr.pos b)
    (requires repr_pre r)
    (ensures  fun h0 rr h1 ->
      R.value_pos r == HSM12.M12_new_session_ticket (R.value_pos rr) /\
      repr_post_common r h0 rr h1)
  = admit()// R.reveal_valid ();
    // let lp_b = R.to_slice b in
    // let pos = HSM12.handshake12_accessor_new_session_ticket lp_b r.R.start_pos in
    // let pos = HSM12.handshake12_m12_new_session_ticket_accessor lp_b pos in
    // let end_pos = Parsers.NewSessionTicket12.newSessionTicket12_jumper lp_b pos in

    // R.mk_from_const_slice b pos end_pos Parsers.NewSessionTicket12.newSessionTicket12_parser32

let get_fin_repr (#b:R.const_slice) (r:pos b{is_fin r})
  : Stack (FinRepr.pos b)
    (requires repr_pre r)
    (ensures  fun h0 rr h1 ->
      R.value_pos r == HSM12.M12_finished (R.value_pos rr) /\
      repr_post_common r h0 rr h1)
  = admit()// R.reveal_valid ();
    // let lp_b = R.to_slice b in
    // let pos = HSM12.handshake12_accessor_finished lp_b r.R.start_pos in
    // let end_pos = HSM12.handshake12_m12_finished_jumper lp_b pos in

    // R.mk_from_const_slice b pos end_pos HSM12.handshake12_m12_finished_parser32

(* Serializer from high-level value via intermediate-level formatter *)

let serialize
  (b:LP.slice R.mut_p R.mut_p{ LP.(b.len <= validator_max_length) })
  (from:R.index (R.of_slice b))
  (x: t)
  : Stack (option (pos (R.of_slice b)))
    (requires fun h ->
      LP.live_slice h b)
    (ensures fun h0 r h1 ->
      B.modifies (LP.loc_slice_from b from) h0 h1 /\
      begin match r with
      | None ->
        (* not enough space in output slice *)
        Seq.length (LP.serialize HSM12.handshake12_serializer x) > FStar.UInt32.v (b.LP.len - from)
      | Some r ->
        R.repr_pos_valid r h1 /\
        r.R.start_pos == from /\
        R.value_pos r == x
      end)
  = R.mk_repr_pos_from_serialize
        b from
        HSM12.handshake12_parser32
        HSM12.handshake12_serializer32
        HSM12.handshake12_size32
        x
