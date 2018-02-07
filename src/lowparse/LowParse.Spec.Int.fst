module LowParse.Spec.Int
include LowParse.Spec.Combinators

module Seq = FStar.Seq
module E = FStar.Kremlin.Endianness
module U8  = FStar.UInt8
module U16 = FStar.UInt16
module U32 = FStar.UInt32

let parse_u8_kind : parser_kind = total_constant_size_parser_kind 1

let decode_u8
  (b: bytes { Seq.length b == 1 } )
: GTot U8.t
= Seq.index b 0
  
let parse_u8: parser parse_u8_kind U8.t =
  make_total_constant_size_parser 1 U8.t decode_u8

let serialize_u8 : serializer parse_u8 =
  Seq.create 1

let decode_u16
  (b: bytes { Seq.length b == 2 } )
: GTot U16.t
= E.lemma_be_to_n_is_bounded b;
  U16.uint_to_t (E.be_to_n b)

(* TODO: move to FStar.Kremlin.Endianness *)

#set-options "--z3rlimit 32"

let rec be_to_n_inj
  (b1 b2: bytes)
: Lemma
  (requires (Seq.length b1 == Seq.length b2 /\ E.be_to_n b1 == E.be_to_n b2))
  (ensures (Seq.equal b1 b2))
  (decreases (Seq.length b1))
= if Seq.length b1 = 0
  then ()
  else begin
    be_to_n_inj (Seq.slice b1 0 (Seq.length b1 - 1)) (Seq.slice b2 0 (Seq.length b2 - 1));
    Seq.lemma_split b1 (Seq.length b1 - 1);
    Seq.lemma_split b2 (Seq.length b2 - 1)
  end

#reset-options

let decode_u16_injective'
  (b1: bytes { Seq.length b1 == 2 } )
  (b2: bytes { Seq.length b2 == 2 } )
: Lemma
  (decode_u16 b1 == decode_u16 b2 ==> Seq.equal b1 b2)
= if decode_u16 b1 = decode_u16 b2
  then begin
    E.lemma_be_to_n_is_bounded b1;
    E.lemma_be_to_n_is_bounded b2;
    assert (U32.v (U32.uint_to_t (E.be_to_n b1)) == E.be_to_n b1);
    assert (U32.v (U32.uint_to_t (E.be_to_n b2)) == E.be_to_n b2);
    assert (E.be_to_n b1 == E.be_to_n b2);
    be_to_n_inj b1 b2
  end else ()

let decode_u16_injective
  ()
: Lemma
  (make_total_constant_size_parser_precond 2 U16.t decode_u16)
= Classical.forall_intro_2 decode_u16_injective'

let parse_u16_kind : parser_kind =
  total_constant_size_parser_kind 2

#set-options "--z3rlimit 16"

let parse_u16: parser parse_u16_kind U16.t =
  decode_u16_injective ();
  let p =
    make_total_constant_size_parser 2 U16.t decode_u16
  in
  p

#set-options "--z3rlimit 64"

let serialize_u16 : serializer parse_u16 =
  (fun (x: U16.t) -> E.n_to_be 2ul (U16.v x))

#reset-options

let decode_u32
  (b: bytes { Seq.length b == 4 } )
: GTot U32.t
= E.lemma_be_to_n_is_bounded b;
  U32.uint_to_t (E.be_to_n b)

#set-options "--z3rlimit 16"

let decode_u32_injective'
  (b1: bytes { Seq.length b1 == 4 } )
  (b2: bytes { Seq.length b2 == 4 } )
: Lemma
  (decode_u32 b1 == decode_u32 b2 ==> Seq.equal b1 b2)
= if decode_u32 b1 = decode_u32 b2
  then begin
    E.lemma_be_to_n_is_bounded b1;
    E.lemma_be_to_n_is_bounded b2;
    assert (U32.v (U32.uint_to_t (E.be_to_n b1)) == E.be_to_n b1);
    assert (U32.v (U32.uint_to_t (E.be_to_n b2)) == E.be_to_n b2);
    assert (E.be_to_n b1 == E.be_to_n b2);
    be_to_n_inj b1 b2
  end else ()

#reset-options

let decode_u32_injective () : Lemma
  (make_total_constant_size_parser_precond 4 U32.t decode_u32)
= Classical.forall_intro_2 decode_u32_injective'

let parse_u32_kind : parser_kind =
  total_constant_size_parser_kind 4

let parse_u32: parser parse_u32_kind U32.t =
  decode_u32_injective ();
  make_total_constant_size_parser 4 U32.t decode_u32

#set-options "--z3rlimit 128"

let serialize_u32 : serializer parse_u32 =
  (fun (x: U32.t) -> E.n_to_be 4ul (U32.v x))

#reset-options
