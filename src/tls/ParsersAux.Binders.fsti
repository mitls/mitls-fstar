module ParsersAux.Binders

module LP = LowParse.Low.Base
module HS = FStar.HyperStack
module U32 = FStar.UInt32

(* ClientHello binders *)

module L = FStar.List.Tot
module H = Parsers.Handshake
module CH = Parsers.ClientHello
module CHE = Parsers.ClientHelloExtension
module Psks = Parsers.OfferedPsks

let has_binders (m: H.handshake) : Tot bool = (* TODO: harmonize with HSL.Transcript.client_hello_has_psk *)
  H.M_client_hello? m && (
  let c = H.M_client_hello?._0 m in
  Cons? (c.CH.extensions) &&
  CHE.CHE_pre_shared_key? (L.last c.CH.extensions)
  )

let get_binders (m: H.handshake {has_binders m}) : Tot Psks.offeredPsks_binders =
  let c = H.M_client_hello?._0 m in
  (CHE.CHE_pre_shared_key?._0 (L.last c.CH.extensions)).Psks.binders

val set_binders (m: H.handshake {has_binders m}) (b' : Psks.offeredPsks_binders { Psks.offeredPsks_binders_bytesize b' == Psks.offeredPsks_binders_bytesize (get_binders m)})
  : Tot (m' : H.handshake {
    has_binders m' /\ (
    let c = H.M_client_hello?._0 m in
    let c' = H.M_client_hello?._0 m' in
    c'.CH.version == c.CH.version /\
    c'.CH.random == c.CH.random /\
    c'.CH.session_id == c.CH.session_id /\
    c'.CH.cipher_suites == c.CH.cipher_suites /\
    c'.CH.compression_method == c.CH.compression_method /\
    Cons? c'.CH.extensions /\
    L.init c'.CH.extensions == L.init c.CH.extensions /\
    CHE.CHE_pre_shared_key? (L.last c'.CH.extensions) /\
    (CHE.CHE_pre_shared_key?._0 (L.last c'.CH.extensions)).Psks.identities == (CHE.CHE_pre_shared_key?._0 (L.last c.CH.extensions)).Psks.identities /\
    get_binders m' == b'
  )})

let set_binders_get_binders (m: H.handshake {has_binders m}) : Lemma
  (set_binders m (get_binders m) == m)
= L.init_last_inj (H.M_client_hello?._0 m).CH.extensions (H.M_client_hello?._0 (set_binders m (get_binders m))).CH.extensions

val set_binders_bytesize
  (m: H.handshake {has_binders m})
  (b' : Psks.offeredPsks_binders { Psks.offeredPsks_binders_bytesize b' == Psks.offeredPsks_binders_bytesize (get_binders m)})
: Lemma
  (H.handshake_bytesize (set_binders m b') == H.handshake_bytesize m)

let set_binders_set_binders
  (m: H.handshake {has_binders m})
  (b1: Psks.offeredPsks_binders { Psks.offeredPsks_binders_bytesize b1 == Psks.offeredPsks_binders_bytesize (get_binders m)})
  (b2: Psks.offeredPsks_binders { Psks.offeredPsks_binders_bytesize b2 == Psks.offeredPsks_binders_bytesize b1})
: Lemma
  (set_binders (set_binders m b1) b2 == set_binders m b2)
= L.init_last_inj (H.M_client_hello?._0 (set_binders (set_binders m b1) b2)).CH.extensions (H.M_client_hello?._0 (set_binders m b2)).CH.extensions

val binders_offset
  (m: H.handshake {has_binders m})
: Tot (u: U32.t { U32.v u <= Seq.length (LP.serialize H.handshake_serializer m) })

val binders_offset_set_binder
  (m: H.handshake {has_binders m})
  (b' : Psks.offeredPsks_binders { Psks.offeredPsks_binders_bytesize b' == Psks.offeredPsks_binders_bytesize (get_binders m) } )
: Lemma
  (binders_offset (set_binders m b') == binders_offset m)

module BY = FStar.Bytes

let truncate_clientHello_bytes
  (m: H.handshake {has_binders m})
: Tot BY.bytes
= BY.slice (H.handshake_serializer32 m) 0ul (binders_offset m)

val truncate_clientHello_bytes_correct
  (m: H.handshake {has_binders m})
: Lemma
  (H.handshake_serializer32 m == BY.append (truncate_clientHello_bytes m) (Psks.offeredPsks_binders_serializer32 (get_binders m)))

val truncate_clientHello_bytes_set_binders
  (m: H.handshake {has_binders m})
  (b' : Psks.offeredPsks_binders { Psks.offeredPsks_binders_bytesize b' == Psks.offeredPsks_binders_bytesize (get_binders m) } )
: Lemma
  (truncate_clientHello_bytes (set_binders m b') == truncate_clientHello_bytes m)

val truncate_clientHello_bytes_inj_binders_bytesize
  (m1: H.handshake {has_binders m1})
  (m2: H.handshake {has_binders m2})
: Lemma
  (requires (truncate_clientHello_bytes m1 == truncate_clientHello_bytes m2))
  (ensures (
    Psks.offeredPsks_binders_bytesize (get_binders m1) == Psks.offeredPsks_binders_bytesize (get_binders m2)
  ))

module LPS = LowParse.SLow.Base

let truncate_clientHello_bytes_inj
  (m1: H.handshake {has_binders m1})
  (m2: H.handshake {has_binders m2})
  (b' : Psks.offeredPsks_binders)
: Lemma
  (requires (
    truncate_clientHello_bytes m1 == truncate_clientHello_bytes m2 /\
    (Psks.offeredPsks_binders_bytesize b' == Psks.offeredPsks_binders_bytesize (get_binders m1) \/ Psks.offeredPsks_binders_bytesize b' == Psks.offeredPsks_binders_bytesize (get_binders m2))
  ))
  (ensures (
    Psks.offeredPsks_binders_bytesize b' == Psks.offeredPsks_binders_bytesize (get_binders m1) /\
    Psks.offeredPsks_binders_bytesize b' == Psks.offeredPsks_binders_bytesize (get_binders m2) /\
    set_binders m1 b' == set_binders m2 b'
  ))
= truncate_clientHello_bytes_inj_binders_bytesize m1 m2;
  truncate_clientHello_bytes_correct m1;
  truncate_clientHello_bytes_correct m2;
  Psks.offeredPsks_binders_bytesize_eq b';
  Psks.offeredPsks_binders_bytesize_eq (get_binders m1);
  Psks.offeredPsks_binders_bytesize_eq (get_binders m2);
  truncate_clientHello_bytes_correct (set_binders m1 b');
  truncate_clientHello_bytes_correct (set_binders m2 b');
  truncate_clientHello_bytes_set_binders m1 b' ;
  truncate_clientHello_bytes_set_binders m2 b' ;
  LPS.serializer32_injective _ H.handshake_serializer32 (set_binders m1 b') (set_binders m2 b')

(* TODO: replace with accessors once we introduce accessors to elements of variable-length lists *)

let valid_truncate_clientHello
  (#rrel #rel: _)
  (h: HS.mem)
  (sl: LP.slice rrel rel)
  (pos: U32.t)
: Lemma
  (requires (
    LP.valid H.handshake_parser h sl pos /\
    has_binders (LP.contents H.handshake_parser h sl pos)
  ))
  (ensures (
    let m = LP.contents H.handshake_parser h sl pos in
    let pos' = LP.get_valid_pos H.handshake_parser h sl pos in
    U32.v pos + U32.v (binders_offset m) + Psks.offeredPsks_binders_bytesize (get_binders m) == U32.v pos' /\
    LP.bytes_of_slice_from_to h sl pos (pos `U32.add` binders_offset m) == BY.reveal (truncate_clientHello_bytes m) /\
    LP.valid_content_pos Psks.offeredPsks_binders_parser h sl (pos `U32.add` binders_offset m) (get_binders m) pos'
  ))
= let m = LP.contents H.handshake_parser h sl pos in
  LP.serialized_length_eq H.handshake_serializer m;
  truncate_clientHello_bytes_correct m;
  let b = get_binders m in
  Psks.offeredPsks_binders_bytesize_eq b;
  LP.serialized_length_eq Psks.offeredPsks_binders_serializer b;
  LP.valid_valid_exact H.handshake_parser h sl pos;
  let pos' = LP.get_valid_pos H.handshake_parser h sl pos in
  LP.valid_exact_serialize H.handshake_serializer h sl pos pos' ;
  let pos1 = pos `U32.add` binders_offset m in
  assert (LP.bytes_of_slice_from_to h sl pos1 pos' == Seq.slice (LP.bytes_of_slice_from_to h sl pos pos') (U32.v pos1 - U32.v pos) (U32.v pos' - U32.v pos));
  LP.serialize_valid_exact Psks.offeredPsks_binders_serializer h sl b pos1 pos' ;
  LP.valid_exact_valid Psks.offeredPsks_binders_parser h sl pos1 pos'

let truncate_clientHello_valid
  (#rrel #rel: _)
  (h: HS.mem)
  (sl: LP.slice rrel rel)
  (pos: U32.t)
  (pos1: U32.t)
  (pos' : U32.t)
  (m: H.handshake {has_binders m})
: Lemma
  (requires (
    LP.live_slice h sl /\
    U32.v pos <= U32.v pos1 /\
    LP.valid_content_pos Psks.offeredPsks_binders_parser h sl pos1 (get_binders m) pos' /\
    LP.bytes_of_slice_from_to h sl pos pos1 `Seq.equal` BY.reveal (truncate_clientHello_bytes m)
  ))
  (ensures (
    LP.valid_content_pos H.handshake_parser h sl pos m pos'
  ))
= let b = get_binders m in
  LP.valid_valid_exact Psks.offeredPsks_binders_parser h sl pos1 ;
  LP.valid_exact_serialize Psks.offeredPsks_binders_serializer h sl pos1 pos' ;
  truncate_clientHello_bytes_correct m;
  LP.serialize_valid_exact H.handshake_serializer h sl m pos pos' ;
  LP.valid_exact_valid H.handshake_parser h sl pos pos'

module B = LowStar.Monotonic.Buffer
module HST = FStar.HyperStack.ST

val binders_pos
  (#rrel #rel: _)
  (sl: LP.slice rrel rel)
  (pos: U32.t)
: HST.Stack U32.t
  (requires (fun h ->
    LP.valid H.handshake_parser h sl pos /\
    has_binders (LP.contents H.handshake_parser h sl pos)
  ))
  (ensures (fun h res h' ->
    let m = LP.contents H.handshake_parser h sl pos in
    B.modifies B.loc_none h h' /\
    U32.v res <= U32.v pos /\
    U32.v pos + U32.v (binders_offset m) == U32.v res /\
    LP.valid_content_pos Psks.offeredPsks_binders_parser h sl res (get_binders m) (LP.get_valid_pos H.handshake_parser h sl pos)
  ))

let valid_binders_mutate
  (#rrel #rel: _)
  (h1: HS.mem)
  (sl: LP.slice rrel rel)
  (pos: U32.t)
  (pos1: U32.t)
  (l: B.loc)
  (h2: HS.mem)
: Lemma
  (requires (
    LP.valid H.handshake_parser h1 sl pos /\ (
    let m = LP.contents H.handshake_parser h1 sl pos in
    let pos' = LP.get_valid_pos H.handshake_parser h1 sl pos in
    has_binders m /\
    U32.v pos + U32.v (binders_offset m) == U32.v pos1 /\
    LP.valid_pos Psks.offeredPsks_binders_parser h2 sl pos1 pos' /\
    B.modifies (l `B.loc_union` LP.loc_slice_from_to sl pos1 pos') h1 h2 /\
    B.loc_disjoint l (LP.loc_slice_from_to sl pos pos')
  )))
  (ensures (
    let m = LP.contents H.handshake_parser h1 sl pos in
    let pos' = LP.get_valid_pos H.handshake_parser h1 sl pos in
    U32.v pos + U32.v (binders_offset m) <= U32.v pos' /\ (
    let b1 = get_binders m in
    let b2 = LP.contents Psks.offeredPsks_binders_parser h2 sl pos1 in
    Psks.offeredPsks_binders_bytesize b1 == Psks.offeredPsks_binders_bytesize b2 /\
    LP.valid_content_pos H.handshake_parser h2 sl pos (set_binders m b2) pos'
  )))
= valid_truncate_clientHello h1 sl pos;
  let pos' = LP.get_valid_pos H.handshake_parser h1 sl pos in
  let m = LP.contents H.handshake_parser h1 sl pos in
  let b2 = LP.contents Psks.offeredPsks_binders_parser h2 sl pos1 in
  LP.content_length_eq Psks.offeredPsks_binders_serializer h2 sl pos1 ;
  LP.serialized_length_eq Psks.offeredPsks_binders_serializer b2;
  Psks.offeredPsks_binders_bytesize_eq b2;
  truncate_clientHello_bytes_set_binders m b2;
  B.modifies_buffer_from_to_elim sl.LP.base pos pos1 (l `B.loc_union` LP.loc_slice_from_to sl pos1 pos') h1 h2;
  truncate_clientHello_valid h2 sl pos pos1 pos' (set_binders m b2)
