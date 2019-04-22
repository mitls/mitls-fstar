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
module B  = LowStar.Buffer
module HS = FStar.HyperStack
module R  = MITLS.Repr

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

type repr (b:R.slice) =
  R.repr_p t b HSM12.handshake12_parser

let is_hr (#b:R.slice) (r:repr b) : GTot bool =
  HSM12.M12_hello_request? (R.value r)

let is_c (#b:R.slice) (r:repr b) : GTot bool =
  HSM12.M12_certificate? (R.value r)

let is_ske (#b:R.slice) (r:repr b) : GTot bool =
  HSM12.M12_server_key_exchange? (R.value r)

let is_cr (#b:R.slice) (r:repr b) : GTot bool =
  HSM12.M12_certificate_request? (R.value r)

let is_shd (#b:R.slice) (r:repr b) : GTot bool =
  HSM12.M12_server_hello_done? (R.value r)

let is_cv (#b:R.slice) (r:repr b) : GTot bool =
  HSM12.M12_certificate_verify? (R.value r)

let is_cke (#b:R.slice) (r:repr b) : GTot bool =
  HSM12.M12_client_key_exchange? (R.value r)

let is_nst (#b:R.slice) (r:repr b) : GTot bool =
  HSM12.M12_new_session_ticket? (R.value r)

let is_fin (#b:R.slice) (r:repr b) : GTot bool =
  HSM12.M12_finished? (R.value r)

(*
 * Common precondition for functions that return the
 *   reprs for specific instance types
 *)
unfold let repr_pre (#b:R.slice) (r:repr b)
  : HS.mem -> Type0
  = fun h -> R.valid r h

(*
 * Common postcondition for functions that return the
 *   reprs for specific instance types
 *)
unfold let repr_post_common
  (#b:R.slice)
  (#a:Type) (#k:LP.parser_kind) (#p:LP.parser k a)
  (r:repr b)  //input repr
  : HS.mem -> R.repr_p a b p -> HS.mem -> Type0
  = fun h0 rr h1 ->
    let open R in
    B.(modifies loc_none h0 h1) /\
    valid rr h1 /\  //the returned repr is valid in h1
    r.start_pos <= rr.start_pos /\  //slice indices for the instance repr are contained in the slice indices of r ...
    rr.end_pos <= r.end_pos  //... useful for framing

let get_hr_repr (#b:R.slice) (r:repr b{is_hr r})
  : Stack (HRRepr.repr b)
    (requires repr_pre r)
    (ensures  fun h0 rr h1 ->
      R.value r == HSM12.M12_hello_request (R.value rr) /\
      repr_post_common r h0 rr h1)
  = R.reveal_valid ();

    let pos = HSM12.handshake12_accessor_hello_request b r.R.start_pos in
    let end_pos = HSM12.handshake12_m12_hello_request_jumper b pos in

    R.mk b pos end_pos HSM12.handshake12_m12_hello_request_parser

let get_c_repr (#b:R.slice) (r:repr b{is_c r})
  : Stack (CRepr.repr b)
    (requires repr_pre r)
    (ensures  fun h0 rr h1 ->
      let l = Parsers.Certificate12.certificate12_bytesize (R.value rr) in
      0 <= l /\ l <= 16777215 /\
      R.value r == HSM12.M12_certificate (R.value rr) /\
      repr_post_common r h0 rr h1)
  = R.reveal_valid ();

    let pos = HSM12.handshake12_accessor_certificate b r.R.start_pos in
    let pos = HSM12.handshake12_m12_certificate_accessor b pos in
    let end_pos = Parsers.Certificate12.certificate12_jumper b pos in

    R.mk b pos end_pos Parsers.Certificate12.certificate12_parser

let get_ske_repr (#b:R.slice) (r:repr b{is_ske r})
  : Stack (SKERepr.repr b)
    (requires repr_pre r)
    (ensures  fun h0 rr h1 ->
      R.value r == HSM12.M12_server_key_exchange (R.value rr) /\
      repr_post_common r h0 rr h1)
  = R.reveal_valid ();

    let pos = HSM12.handshake12_accessor_server_key_exchange b r.R.start_pos in
    let end_pos = HSM12.handshake12_m12_server_key_exchange_jumper b pos in

    R.mk b pos end_pos HSM12.handshake12_m12_server_key_exchange_parser

let get_cr_repr (#b:R.slice) (r:repr b{is_cr r})
  : Stack (CRRepr.repr b)
    (requires repr_pre r)
    (ensures  fun h0 rr h1 ->
      R.value r == HSM12.M12_certificate_request (R.value rr) /\
      repr_post_common r h0 rr h1)
  = R.reveal_valid ();

    let pos = HSM12.handshake12_accessor_certificate_request b r.R.start_pos in
    let pos = HSM12.handshake12_m12_certificate_request_accessor b pos in
    let end_pos = Parsers.CertificateRequest12.certificateRequest12_jumper b pos in

    R.mk b pos end_pos Parsers.CertificateRequest12.certificateRequest12_parser

let get_shd_repr (#b:R.slice) (r:repr b{is_shd r})
  : Stack (SHDRepr.repr b)
    (requires repr_pre r)
    (ensures  fun h0 rr h1 ->
      R.value r == HSM12.M12_server_hello_done (R.value rr) /\
      repr_post_common r h0 rr h1)
  = R.reveal_valid ();

    let pos = HSM12.handshake12_accessor_server_hello_done b r.R.start_pos in
    let end_pos = HSM12.handshake12_m12_server_hello_done_jumper b pos in

    R.mk b pos end_pos HSM12.handshake12_m12_server_hello_done_parser

let get_cv_repr (#b:R.slice) (r:repr b{is_cv r})
  : Stack (CVRepr.repr b)
    (requires repr_pre r)
    (ensures  fun h0 rr h1 ->
      R.value r = HSM12.M12_certificate_verify (R.value rr) /\
      repr_post_common r h0 rr h1)
  = R.reveal_valid ();

    let pos = HSM12.handshake12_accessor_certificate_verify b r.R.start_pos in
    let pos = HSM12.handshake12_m12_certificate_verify_accessor b pos in
    let end_pos = Parsers.CertificateVerify12.certificateVerify12_jumper b pos in

    R.mk b pos end_pos Parsers.CertificateVerify12.certificateVerify12_parser

let get_cke_repr (#b:R.slice) (r:repr b{is_cke r})
  : Stack (CKERepr.repr b)
    (requires repr_pre r)
    (ensures  fun h0 rr h1 ->
      R.value r == HSM12.M12_client_key_exchange (R.value rr) /\
      repr_post_common r h0 rr h1)
  = R.reveal_valid ();

    let pos = HSM12.handshake12_accessor_client_key_exchange b r.R.start_pos in
    let end_pos = HSM12.handshake12_m12_client_key_exchange_jumper b pos in

    R.mk b pos end_pos HSM12.handshake12_m12_client_key_exchange_parser

let get_nst_repr (#b:R.slice) (r:repr b{is_nst r})
  : Stack (NSTRepr.repr b)
    (requires repr_pre r)
    (ensures  fun h0 rr h1 ->
      R.value r == HSM12.M12_new_session_ticket (R.value rr) /\
      repr_post_common r h0 rr h1)
  = R.reveal_valid ();

    let pos = HSM12.handshake12_accessor_new_session_ticket b r.R.start_pos in
    let pos = HSM12.handshake12_m12_new_session_ticket_accessor b pos in
    let end_pos = Parsers.NewSessionTicket12.newSessionTicket12_jumper b pos in

    R.mk b pos end_pos Parsers.NewSessionTicket12.newSessionTicket12_parser

let get_fin_repr (#b:R.slice) (r:repr b{is_fin r})
  : Stack (FinRepr.repr b)
    (requires repr_pre r)
    (ensures  fun h0 rr h1 ->
      R.value r == HSM12.M12_finished (R.value rr) /\
      repr_post_common r h0 rr h1)
  = R.reveal_valid ();

    let pos = HSM12.handshake12_accessor_finished b r.R.start_pos in
    let end_pos = HSM12.handshake12_m12_finished_jumper b pos in

    R.mk b pos end_pos HSM12.handshake12_m12_finished_parser
