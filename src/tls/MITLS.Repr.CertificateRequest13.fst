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
module MITLS.Repr.CertificateRequest13
(* Summary:

   This module encapsulates wire-format representations of
   Parsers.CertificateRequest13.certificateRequest13

   Its main type, `repr b` is an instance of MITLS.Repr.repr
   instantiated with Parsers.CertificateRequest13.certificateRequest13_parser
*)
module LP = LowParse.Low.Base
module B = LowStar.Monotonic.Buffer
module HS = FStar.HyperStack
module R = MITLS.Repr
open FStar.Integers
open FStar.HyperStack.ST

module CR13 = Parsers.CertificateRequest13

let t = CR13.certificateRequest13

let repr (b:R.slice) =
  R.repr_p t b CR13.certificateRequest13_parser32