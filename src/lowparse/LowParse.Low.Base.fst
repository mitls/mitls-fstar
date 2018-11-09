module LowParse.Low.Base
include LowParse.Spec.Base

module B = LowStar.Buffer
module M = LowStar.ModifiesPat
module U32 = FStar.UInt32
module HS = FStar.HyperStack
module HST = FStar.HyperStack.ST

inline_for_extraction
type buffer8 = B.buffer FStar.UInt8.t

noeq
type slice = {
  base: buffer8;
  len: (len: U32.t { len == B.len base } );
}

let live_slice (h: HS.mem) (s: slice) : GTot Type0 = B.live h s.base

abstract
let loc_slice_from (s: slice) (pos: U32.t) : GTot B.loc =
  if U32.v pos <= U32.v s.len
  then B.loc_buffer (B.gsub s.base pos (s.len `U32.sub` pos))
  else B.loc_none

abstract
let loc_includes_union_l_loc_slice_from (l1 l2: B.loc) (s: slice) (pos: U32.t) : Lemma
  (requires (B.loc_includes l1 (loc_slice_from s pos) \/ B.loc_includes l2 (loc_slice_from s pos)))
  (ensures (B.loc_includes (B.loc_union l1 l2) (loc_slice_from s pos)))
  [SMTPat (B.loc_includes (B.loc_union l1 l2) (loc_slice_from s pos))]
= ()

abstract
let loc_slice_from_includes_r (s: slice) (pos: U32.t) : Lemma
  (B.loc_includes (B.loc_buffer s.base) (loc_slice_from s pos))
  [SMTPat (loc_slice_from s pos)]
= ()

abstract
let loc_slice_from_eq
  (s: slice)
  (pos: U32.t)
: Lemma
  (requires (U32.v pos <= U32.v s.len))
  (ensures (loc_slice_from s pos == B.loc_buffer (B.gsub s.base pos (s.len `U32.sub` pos))))
= ()

abstract
let loc_slice_from_includes_l
  (s: slice)
  (pos1 pos2: U32.t)
: Lemma
  (requires (U32.v pos1 <= U32.v pos2))
  (ensures (B.loc_includes (loc_slice_from s pos1) (loc_slice_from s pos2)))
  [SMTPat (B.loc_includes (loc_slice_from s pos1) (loc_slice_from s pos2))]
= ()

let valid'
  (#k: parser_kind)
  (#t: Type)
  (p: parser k t)
  (h: HS.mem)
  (s: slice)
  (pos: U32.t)
: GTot Type0
= U32.v pos <= U32.v s.len /\
  live_slice h s /\
  Some? (parse p (B.as_seq h (B.gsub s.base pos (s.len `U32.sub` pos))))

abstract
let valid
  (#k: parser_kind)
  (#t: Type)
  (p: parser k t)
  (h: HS.mem)
  (s: slice)
  (pos: U32.t)
: GTot Type0
= valid' p h s pos

abstract
let valid_dec
  (#k: parser_kind)
  (#t: Type)
  (p: parser k t)
  (h: HS.mem)
  (s: slice)
  (pos: U32.t)
: Ghost bool
  (requires (live_slice h s))
  (ensures (fun b ->
    b == true <==> valid p h s pos
  ))
= (not (pos `U32.gt` s.len)) && Some? (parse p (B.as_seq h (B.gsub s.base pos (s.len `U32.sub` pos))))

abstract
let valid_equiv
  (#k: parser_kind)
  (#t: Type)
  (p: parser k t)
  (h: HS.mem)
  (s: slice)
  (pos: U32.t)
: Lemma
  (valid p h s pos <==> valid' p h s pos)
= ()

abstract
let valid_elim
  (#k: parser_kind)
  (#t: Type)
  (p: parser k t)
  (h: HS.mem)
  (s: slice)
  (pos: U32.t)
: Lemma
  (requires (valid p h s pos))
  (ensures (valid' p h s pos))
  [SMTPat (valid p h s pos)]
= ()

let contents'
  (#k: parser_kind)
  (#t: Type)
  (p: parser k t)
  (h: HS.mem)
  (s: slice)
  (pos: U32.t)
: Ghost t
  (requires (valid' p h s pos))
  (ensures (fun _ -> True))
= let Some (v, _) = parse p (B.as_seq h (B.gsub s.base pos (s.len `U32.sub` pos))) in
  v

abstract
let contents
  (#k: parser_kind)
  (#t: Type)
  (p: parser k t)
  (h: HS.mem)
  (s: slice)
  (pos: U32.t)
: Ghost t
  (requires (valid p h s pos))
  (ensures (fun _ -> True))
= contents' p h s pos

abstract
let contents_eq
  (#k: parser_kind)
  (#t: Type)
  (p: parser k t)
  (h: HS.mem)
  (s: slice)
  (pos: U32.t)
: Lemma
  (requires (valid p h s pos))
  (ensures (valid' p h s pos /\ contents p h s pos == contents' p h s pos))
= ()

let content_length'
  (#k: parser_kind)
  (#t: Type)
  (p: parser k t)
  (h: HS.mem)
  (sl: slice)
  (pos: U32.t)
: Ghost nat
  (requires (valid' p h sl pos))
  (ensures (fun res ->
    U32.v pos + res <= U32.v sl.len /\
    k.parser_kind_low <= res /\ (
    match k.parser_kind_high with
    | None -> True
    | Some max -> res <= max
  )))
= let Some (_, consumed) = parse p (B.as_seq h (B.gsub sl.base pos (sl.len `U32.sub` pos))) in
  consumed

abstract
let content_length
  (#k: parser_kind)
  (#t: Type)
  (p: parser k t)
  (h: HS.mem)
  (sl: slice)
  (pos: U32.t)
: Ghost nat
  (requires (valid p h sl pos))
  (ensures (fun res ->
    U32.v pos + res <= U32.v sl.len /\
    k.parser_kind_low <= res /\ (
    match k.parser_kind_high with
    | None -> True
    | Some max -> res <= max
  )))
= content_length' p h sl pos

abstract
let serialized_length
  (#k: parser_kind)
  (#t: Type)
  (#p: parser k t)
  (s: serializer p)
  (x: t)
: Ghost nat
  (requires True)
  (ensures (fun res ->
    k.parser_kind_low <= res /\ (
    match k.parser_kind_high with
    | None -> True
    | Some max -> res <= max
  )))
= Seq.length (serialize s x)

abstract
let serialized_length_eq
  (#k: parser_kind)
  (#t: Type)
  (#p: parser k t)
  (s: serializer p)
  (x: t)
: Lemma
  (serialized_length s x == Seq.length (serialize s x))
= ()

abstract
let content_length_eq_gen
  (#k: parser_kind)
  (#t: Type)
  (p: parser k t)
  (h: HS.mem)
  (sl: slice)
  (pos: U32.t)
: Lemma
  (requires (valid p h sl pos))
  (ensures (valid' p h sl pos /\ content_length p h sl pos == content_length' p h sl pos))
= ()

abstract
let content_length_eq
  (#k: parser_kind)
  (#t: Type)
  (#p: parser k t)
  (s: serializer p)
  (h: HS.mem)
  (sl: slice)
  (pos: U32.t)
: Lemma
  (requires (valid p h sl pos))
  (ensures (content_length p h sl pos == serialized_length s (contents p h sl pos)))
  [SMTPat (serialized_length s (contents p h sl pos))]
= let b = B.as_seq h (B.gsub sl.base pos (sl.len `U32.sub` pos)) in
  let Some (x, consumed) = parse p b in
  assert (x == contents p h sl pos);
  let ps' = parse p (serialize s x) in
  assert (serializer_correct p s);
  assert (Some? ps');
  assert (injective_precond p b (serialize s x))

let valid_pos
  (#k: parser_kind)
  (#t: Type)
  (p: parser k t)
  (h: HS.mem)
  (sl: slice)
  (pos: U32.t)
  (pos' : U32.t)
= valid p h sl pos /\
  U32.v pos + content_length p h sl pos == U32.v pos'

abstract
let get_valid_pos
  (#k: parser_kind)
  (#t: Type)
  (p: parser k t)
  (h: HS.mem)
  (sl: slice)
  (pos: U32.t)
: Ghost U32.t
  (requires (valid p h sl pos))
  (ensures (fun pos' -> valid_pos p h sl pos pos'))
= pos `U32.add` U32.uint_to_t (content_length p h sl pos)

let valid_content_pos
  (#k: parser_kind)
  (#t: Type)
  (p: parser k t)
  (h: HS.mem)
  (sl: slice)
  (pos: U32.t)
  (x: t)
  (pos' : U32.t)
= valid_pos p h sl pos pos' /\
  contents p h sl pos == x

abstract
let valid_frame
  (#k: parser_kind)
  (#t: Type)
  (p: parser k t)
  (h: HS.mem)
  (sl: slice)
  (pos: U32.t)
  (l: B.loc)
  (h': HS.mem)
: Lemma
  (requires (valid p h sl pos /\ B.modifies l h h' /\ B.loc_disjoint (loc_slice_from sl pos) l))
  (ensures (
    valid_content_pos p h' sl pos (contents p h sl pos) (get_valid_pos p h sl pos)
  ))
  [SMTPatOr [
    [SMTPat (valid p h sl pos); SMTPat (B.modifies l h h')];
    [SMTPat (valid p h' sl pos); SMTPat (B.modifies l h h')];
    [SMTPat (contents p h sl pos); SMTPat (B.modifies l h h')];
    [SMTPat (contents p h' sl pos); SMTPat (B.modifies l h h')];
    [SMTPat (content_length p h sl pos); SMTPat (B.modifies l h h')];
    [SMTPat (content_length p h' sl pos); SMTPat (B.modifies l h h')];
  ]]
= ()

abstract
let valid_facts
  (#k: parser_kind)
  (#t: Type)
  (p: parser k t)
  (h: HS.mem)
  (sl: slice)
  (pos: U32.t)
: Lemma
  ((valid p h sl pos <==> valid' p h sl pos) /\
   (valid p h sl pos ==> (
     contents p h sl pos == contents' p h sl pos /\
     content_length p h sl pos == content_length' p h sl pos
  )))
= ()


(* Accessors *)

noeq
type clens (#t1: Type) (clens_cond: t1 -> GTot Type0) (t2: Type) = {
  clens_get: (x1: t1) -> Ghost t2 (requires (clens_cond x1)) (ensures (fun _ -> True));
  clens_put: (x1: t1) -> t2 -> Ghost t1 (requires (clens_cond x1)) (ensures (fun x1' -> clens_cond x1'));
  clens_get_put: (x1: t1) -> (x2: t2) -> Lemma (requires (clens_cond x1)) (ensures (clens_get (clens_put x1 x2) == x2));
  clens_put_put: (x1: t1) -> (x2: t2) -> (x2' : t2) -> Lemma (requires (clens_cond x1)) (ensures (clens_put (clens_put x1 x2) x2' == clens_put x1 x2'));
  clens_put_get: (x1: t1) -> Lemma (requires (clens_cond x1)) (ensures (clens_put x1 (clens_get x1) == x1));
}

let clens_get_put'
  (#t1: Type) (#clens_cond: t1 -> GTot Type0) (#t2: Type) (l: clens clens_cond t2)
  (x1: t1) (x2: t2)
: Lemma
  (requires (clens_cond x1))
  (ensures (l.clens_get (l.clens_put x1 x2) == x2))
  [SMTPat (l.clens_get (l.clens_put x1 x2))]
= l.clens_get_put x1 x2

let clens_put_put'
  (#t1: Type) (#clens_cond: t1 -> GTot Type0) (#t2: Type) (l: clens clens_cond t2)
  (x1: t1) (x2: t2) (x2' : t2)
: Lemma
  (requires (clens_cond x1))
  (ensures (l.clens_put (l.clens_put x1 x2) x2' == l.clens_put x1 x2'))
  [SMTPat (l.clens_put (l.clens_put x1 x2) x2')]
= l.clens_put_put x1 x2 x2'

let clens_put_get'
  (#t1: Type) (#clens_cond: t1 -> GTot Type0) (#t2: Type) (l: clens clens_cond t2)
  (x1: t1)
: Lemma
  (requires (clens_cond x1))
  (ensures (l.clens_put x1 (l.clens_get x1) == x1))
  [SMTPat (l.clens_put x1 (l.clens_get x1))]
= l.clens_put_get x1

abstract
let clens_disjoint_l
  (#t0: Type)
  (#clens_cond2: t0 -> GTot Type0)
  (#clens_cond3: t0 -> GTot Type0)
  (#t2 #t3: Type)
  (l2: clens clens_cond2 t2)
  (l3: clens clens_cond3 t3)
: GTot Type0
= (forall (x0: t0) (x2: t2) . (clens_cond2 x0 /\ clens_cond3 x0) ==> 
  (let x0' = l2.clens_put x0 x2 in clens_cond3 x0' /\ l3.clens_get x0' == l3.clens_get x0))

abstract
let clens_disjoint_l_elim
  (#t0: Type)
  (#clens_cond2: t0 -> GTot Type0)
  (#clens_cond3: t0 -> GTot Type0)
  (#t2 #t3: Type)
  (l2: clens clens_cond2 t2)
  (l3: clens clens_cond3 t3)
  (x0: t0) (x2: t2)
: Lemma
  (requires (clens_disjoint_l l2 l3 /\ clens_cond2 x0 /\ clens_cond3 x0))
  (ensures (let x0' = l2.clens_put x0 x2 in clens_cond3 x0' /\ l3.clens_get x0' == l3.clens_get x0))
  [SMTPat (l3.clens_get (l2.clens_put x0 x2))]
= ()

abstract
let clens_disjoint_l_intro
  (#t0: Type)
  (#clens_cond2: t0 -> GTot Type0)
  (#clens_cond3: t0 -> GTot Type0)
  (#t2 #t3: Type)
  (l2: clens clens_cond2 t2)
  (l3: clens clens_cond3 t3)
  (lem: (
    (x0: t0) ->
    (x2: t2) ->
    Lemma
    (requires (clens_cond2 x0 /\ clens_cond3 x0))
    (ensures (clens_cond2 x0 /\ clens_cond3 x0 /\ (let x0' = l2.clens_put x0 x2 in clens_cond3 x0' /\ l3.clens_get x0' == l3.clens_get x0)))
  ))
: Lemma
  (clens_disjoint_l l2 l3)
= let lem'
    (x0: t0)
    (x2: t2)
  : Lemma
    ((clens_cond2 x0 /\ clens_cond3 x0) ==>
    (ensures (clens_cond2 x0 /\ clens_cond3 x0 /\ (let x0' = l2.clens_put x0 x2 in clens_cond3 x0' /\ l3.clens_get x0' == l3.clens_get x0))))
  = Classical.move_requires (lem x0) x2
  in
  Classical.forall_intro_2 lem'

let clens_disjoint
  (#t0: Type)
  (#clens_cond2: t0 -> GTot Type0)
  (#clens_cond3: t0 -> GTot Type0)
  (#t2 #t3: Type)
  (l2: clens clens_cond2 t2)
  (l3: clens clens_cond3 t3)
: GTot Type0
= clens_disjoint_l l2 l3 /\ clens_disjoint_l l3 l2

let clens_disjoint_sym
  (#t0: Type)
  (#clens_cond2: t0 -> GTot Type0)
  (#clens_cond3: t0 -> GTot Type0)
  (#t2 #t3: Type)
  (l2: clens clens_cond2 t2)
  (l3: clens clens_cond3 t3)
: Lemma
  (clens_disjoint l2 l3 <==> clens_disjoint l3 l2)
  [SMTPat (clens_disjoint l2 l3)]
= ()

let clens_compose_cond
  (#t1: Type)
  (#clens_cond1: t1 -> GTot Type0)
  (#t2: Type)
  (l12: clens clens_cond1 t2)
  (clens_cond2: t2 -> GTot Type0)
  (x1: t1)
: GTot Type0
= clens_cond1 x1 /\
  clens_cond2 (l12.clens_get x1)

let clens_compose
  (#t1: Type)
  (#clens_cond1: t1 -> GTot Type0)
  (#t2: Type)
  (#clens_cond2: t2 -> GTot Type0)
  (#t3: Type)
  (l12: clens clens_cond1 t2)
  (l23: clens clens_cond2 t3)
: Tot (clens (clens_compose_cond l12 clens_cond2) t3)
= {
  clens_get = (fun x1 -> l23.clens_get (l12.clens_get x1));
  clens_put = (fun x1 x3 ->
    let x2' = l23.clens_put (l12.clens_get x1) x3 in
    let x1' = l12.clens_put x1 x2' in
    x1'
  );
  clens_get_put = (fun x1 x3 -> ());
  clens_put_put = (fun x1 x3 x3' -> ());
  clens_put_get = (fun x1 -> ());
}

abstract
let clens_disjoint_compose
  (#t0: Type)
  (#clens_cond2: t0 -> GTot Type0)
  (#clens_cond3: t0 -> GTot Type0)
  (#t2 #t3: Type)
  (l2: clens clens_cond2 t2)
  (l3: clens clens_cond3 t3)
  (#clens_cond3': t3 -> GTot Type0)
  (#t3' : Type)
  (l3' : clens clens_cond3' t3')
: Lemma
  (requires (clens_disjoint l2 l3))
  (ensures (clens_disjoint l2 (clens_compose l3 l3')))
  [SMTPat (clens_disjoint l2 (clens_compose l3 l3'))]
= ()

let gaccessor_pre
  (#k1: parser_kind)
  (#t1: Type)
  (p1: parser k1 t1)
  (#k2: parser_kind)
  (#t2: Type)
  (p2: parser k2 t2)
  (#pre: t1 -> GTot Type0)
  (cl: clens pre t2)
  (sl: bytes)
: GTot Type0
= match parse p1 sl with
  | Some (x1, _) -> pre x1
  | _ -> False

let gaccessor_post
  (#k1: parser_kind)
  (#t1: Type)
  (p1: parser k1 t1)
  (#k2: parser_kind)
  (#t2: Type)
  (p2: parser k2 t2)
  (#pre: t1 -> GTot Type0)
  (cl: clens pre t2)
  (sl: bytes)
  (pos' : nat)
: GTot Type0
= pos' <= Seq.length sl /\
  begin match parse p1 sl with
  | Some (x1, consumed1) ->
    begin match parse p2 (Seq.slice sl pos' (Seq.length sl)) with
    | Some (x2, consumed2) ->
      pre x1 /\
      x2 == cl.clens_get x1 /\
      pos' + consumed2 <= consumed1
    | _ -> False
    end
  | _ -> False
  end

let gaccessor
  (#k1: parser_kind)
  (#t1: Type)
  (p1: parser k1 t1)
  (#k2: parser_kind)
  (#t2: Type)
  (p2: parser k2 t2)
  (#pre: t1 -> GTot Type0)
  (cl: clens pre t2)
: Tot Type
= (sl: bytes) ->
  Ghost nat
  (requires (gaccessor_pre p1 p2 cl sl))
  (ensures (fun pos' -> gaccessor_post p1 p2 cl sl pos'))

abstract
let gaccessors_disjoint
  (#k1: parser_kind)
  (#t1: Type)
  (#p1: parser k1 t1)
  (#k2: parser_kind)
  (#t2: Type)
  (#p2: parser k2 t2)
  (#pre2: t1 -> GTot Type0)
  (#cl2: clens pre2 t2)
  (g2: gaccessor p1 p2 cl2)
  (#k3: parser_kind)
  (#t3: Type)
  (#p3: parser k3 t3)
  (#pre3: t1 -> GTot Type0)
  (#cl3: clens pre3 t3)
  (g3: gaccessor p1 p3 cl3)
: GTot Type0
= clens_disjoint cl2 cl3 /\
  (forall (sl: bytes) . (
     match parse p1 sl with
     | Some (x1, _) -> pre2 x1 /\ pre3 x1
     | _ -> False
   ) ==> (
   let pos2 = g2 sl in
   let pos3 = g3 sl in
   match parse p2 (Seq.slice sl pos2 (Seq.length sl)), parse p3 (Seq.slice sl pos3 (Seq.length sl)) with
   | Some (_, consumed2), Some (_, consumed3) ->
     pos2 + consumed2 <= pos3 \/ pos3 + consumed3 <= pos2
   | _ -> True
  ))

abstract
let gaccessors_disjoint_clens_disjoint
  (#k1: parser_kind)
  (#t1: Type)
  (#p1: parser k1 t1)
  (#k2: parser_kind)
  (#t2: Type)
  (#p2: parser k2 t2)
  (#pre2: t1 -> GTot Type0)
  (#cl2: clens pre2 t2)
  (g2: gaccessor p1 p2 cl2)
  (#k3: parser_kind)
  (#t3: Type)
  (#p3: parser k3 t3)
  (#pre3: t1 -> GTot Type0)
  (#cl3: clens pre3 t3)
  (g3: gaccessor p1 p3 cl3)
: Lemma
  (requires (gaccessors_disjoint g2 g3))
  (ensures (clens_disjoint cl2 cl3))
  [SMTPat (gaccessors_disjoint g2 g3)]
= ()

abstract
let gaccessors_disjoint_elim
  (#k1: parser_kind)
  (#t1: Type)
  (#p1: parser k1 t1)
  (#k2: parser_kind)
  (#t2: Type)
  (#p2: parser k2 t2)
  (#pre2: t1 -> GTot Type0)
  (#cl2: clens pre2 t2)
  (g2: gaccessor p1 p2 cl2)
  (#k3: parser_kind)
  (#t3: Type)
  (#p3: parser k3 t3)
  (#pre3: t1 -> GTot Type0)
  (#cl3: clens pre3 t3)
  (g3: gaccessor p1 p3 cl3)
  (sl: bytes)
: Lemma
  (requires (gaccessors_disjoint g2 g3 /\ (
     match parse p1 sl with
     | Some (x1, _) -> pre2 x1 /\ pre3 x1
     | _ -> False
  )))
  (ensures (
    let pos2 = g2 sl in
    let pos3 = g3 sl in
    match parse p2 (Seq.slice sl pos2 (Seq.length sl)), parse p3 (Seq.slice sl pos3 (Seq.length sl)) with
     | Some (_, consumed2), Some (_, consumed3) ->
       pos2 + consumed2 <= pos3 \/ pos3 + consumed3 <= pos2
     | _ -> True
  ))
= ()

abstract
let gaccessors_disjoint_intro
  (#k1: parser_kind)
  (#t1: Type)
  (#p1: parser k1 t1)
  (#k2: parser_kind)
  (#t2: Type)
  (#p2: parser k2 t2)
  (#pre2: t1 -> GTot Type0)
  (#cl2: clens pre2 t2)
  (g2: gaccessor p1 p2 cl2)
  (#k3: parser_kind)
  (#t3: Type)
  (#p3: parser k3 t3)
  (#pre3: t1 -> GTot Type0)
  (#cl3: clens pre3 t3)
  (g3: gaccessor p1 p3 cl3)
  (clens_disj: squash (clens_disjoint cl2 cl3))
  (lem: (
    (sl: bytes) ->
    Lemma
    (requires (
      match parse p1 sl with
      | Some (x1, _) -> pre2 x1 /\ pre3 x1
      | _ -> False
    ))
    (ensures ((
      match parse p1 sl with
      | Some (x1, _) -> pre2 x1 /\ pre3 x1
      | _ -> False) /\ (
      let pos2 = g2 sl in
      let pos3 = g3 sl in
      match parse p2 (Seq.slice sl pos2 (Seq.length sl)), parse p3 (Seq.slice sl pos3 (Seq.length sl)) with
      | Some (_, consumed2), Some (_, consumed3) ->
        pos2 + consumed2 <= pos3 \/ pos3 + consumed3 <= pos2
      | _ -> True
    )))
  ))
: Lemma
  (gaccessors_disjoint g2 g3)
= let lem'
   (sl: bytes)
 : Lemma
   ((
     match parse p1 sl with
     | Some (x1, _) -> pre2 x1 /\ pre3 x1
     | _ -> False
   ) ==> (
   let pos2 = g2 sl in
   let pos3 = g3 sl in
   match parse p2 (Seq.slice sl pos2 (Seq.length sl)), parse p3 (Seq.slice sl pos3 (Seq.length sl)) with
   | Some (_, consumed2), Some (_, consumed3) ->
     pos2 + consumed2 <= pos3 \/ pos3 + consumed3 <= pos2
   | _ -> True
   ))
 = Classical.move_requires lem sl
 in
 Classical.forall_intro lem'

let gaccessor_compose'
  (#k1: parser_kind)
  (#t1: Type)
  (#p1: parser k1 t1)
  (#k2: parser_kind)
  (#t2: Type)
  (#p2: parser k2 t2)
  (#pre1: (t1 -> GTot Type0))
  (#cl12: clens pre1 t2)
  (a12: gaccessor p1 p2 cl12)
  (#pre2: (t2 -> GTot Type0))
  (#k3: parser_kind)
  (#t3: Type)
  (#p3: parser k3 t3)
  (#cl23: clens pre2 t3)
  (a23: gaccessor p2 p3 cl23)
  (input: bytes)
: Ghost nat
  (requires (gaccessor_pre p1 p3 (clens_compose cl12 cl23) input))
  (ensures (fun pos' -> True))
=
  let pos2 = a12 input in
  let input2 = Seq.slice input pos2 (Seq.length input) in
  pos2 + a23 input2

let gaccessor_compose_correct
  (#k1: parser_kind)
  (#t1: Type)
  (#p1: parser k1 t1)
  (#k2: parser_kind)
  (#t2: Type)
  (#p2: parser k2 t2)
  (#pre1: (t1 -> GTot Type0))
  (#cl12: clens pre1 t2)
  (a12: gaccessor p1 p2 cl12)
  (#pre2: (t2 -> GTot Type0))
  (#k3: parser_kind)
  (#t3: Type)
  (#p3: parser k3 t3)
  (#cl23: clens pre2 t3)
  (a23: gaccessor p2 p3 cl23)
  (input: bytes)
: Lemma
  (requires (gaccessor_pre p1 p3 (clens_compose cl12 cl23) input))
  (ensures (gaccessor_post p1 p3 (clens_compose cl12 cl23) input (gaccessor_compose' a12 a23 input)))
= ()

let gaccessor_compose_
  (#k1: parser_kind)
  (#t1: Type)
  (#p1: parser k1 t1)
  (#k2: parser_kind)
  (#t2: Type)
  (#p2: parser k2 t2)
  (#pre1: (t1 -> GTot Type0))
  (#cl12: clens pre1 t2)
  (a12: gaccessor p1 p2 cl12)
  (#pre2: (t2 -> GTot Type0))
  (#k3: parser_kind)
  (#t3: Type)
  (#p3: parser k3 t3)
  (#cl23: clens pre2 t3)
  (a23: gaccessor p2 p3 cl23)
  (input: bytes)
: Ghost nat
  (requires (gaccessor_pre p1 p3 (clens_compose cl12 cl23) input))
  (ensures (fun pos' -> gaccessor_post p1 p3 (clens_compose cl12 cl23) input pos'))
= gaccessor_compose_correct a12 a23 input;
  gaccessor_compose' a12 a23 input

let gaccessor_compose
  (#k1: parser_kind)
  (#t1: Type)
  (#p1: parser k1 t1)
  (#k2: parser_kind)
  (#t2: Type)
  (#p2: parser k2 t2)
  (#pre1: (t1 -> GTot Type0))
  (#cl12: clens pre1 t2)
  (a12: gaccessor p1 p2 cl12)
  (#pre2: (t2 -> GTot Type0))
  (#k3: parser_kind)
  (#t3: Type)
  (#p3: parser k3 t3)
  (#cl23: clens pre2 t3)
  (a23: gaccessor p2 p3 cl23)
: Tot (gaccessor p1 p3 (clens_compose cl12 cl23))
= gaccessor_compose_ a12 a23

let slice_access'
  (h: HS.mem)
  (#k1: parser_kind)
  (#t1: Type)
  (#p1: parser k1 t1)
  (#k2: parser_kind)
  (#t2: Type)
  (#p2: parser k2 t2)
  (#pre: t1 -> GTot Type0)
  (#cl: clens pre t2)
  (g: gaccessor p1 p2 cl)
  (sl: slice)
  (pos: U32.t)
: Ghost U32.t
  (requires (
    valid' p1 h sl pos /\
    pre (contents' p1 h sl pos)
  ))
  (ensures (fun pos' -> True))
= pos `U32.add` U32.uint_to_t (g (B.as_seq h (B.gsub sl.base pos (sl.len `U32.sub` pos))))

abstract
let slice_access
  (h: HS.mem)
  (#k1: parser_kind)
  (#t1: Type)
  (#p1: parser k1 t1)
  (#k2: parser_kind)
  (#t2: Type)
  (#p2: parser k2 t2)
  (#pre: t1 -> GTot Type0)
  (#cl: clens pre t2)
  (g: gaccessor p1 p2 cl)
  (sl: slice)
  (pos: U32.t)
: Ghost U32.t
  (requires (
    valid p1 h sl pos /\
    pre (contents p1 h sl pos)
  ))
  (ensures (fun pos' ->
    valid p2 h sl pos' /\
    contents p2 h sl pos' == cl.clens_get (contents p1 h sl pos) /\
    // useful for framing
    U32.v pos <= U32.v pos' /\
    U32.v pos' + content_length p2 h sl pos' <= U32.v pos + content_length p1 h sl pos
  ))
= slice_access' h g sl pos

abstract
let slice_access_eq
  (h: HS.mem)
  (#k1: parser_kind)
  (#t1: Type)
  (#p1: parser k1 t1)
  (#k2: parser_kind)
  (#t2: Type)
  (#p2: parser k2 t2)
  (#pre: t1 -> GTot Type0)
  (#cl: clens pre t2)
  (g: gaccessor p1 p2 cl)
  (sl: slice)
  (pos: U32.t)
: Lemma
  (requires (
    valid p1 h sl pos /\
    pre (contents p1 h sl pos)
  ))
  (ensures (
    valid' p1 h sl pos /\
    pre (contents' p1 h sl pos) /\
    slice_access h g sl pos == slice_access' h g sl pos
  ))
= ()

abstract
let slice_access_frame
  (h: HS.mem)
  (#k1: parser_kind)
  (#t1: Type)
  (#p1: parser k1 t1)
  (#k2: parser_kind)
  (#t2: Type)
  (#p2: parser k2 t2)
  (#pre: t1 -> GTot Type0)
  (#cl: clens pre t2)
  (g: gaccessor p1 p2 cl)
  (sl: slice)
  (pos: U32.t)
  (l: B.loc)
  (h' : HS.mem)
: Lemma
  (requires (
    valid p1 h sl pos /\
    pre (contents p1 h sl pos) /\
    B.modifies l h h' /\
    B.loc_disjoint l (loc_slice_from sl pos)
  ))
  (ensures (
    valid p1 h' sl pos /\
    pre (contents p1 h' sl pos) /\
    slice_access h' g sl pos == slice_access h g sl pos
  ))
  [SMTPatOr [
    [SMTPat (slice_access h g sl pos); SMTPat (B.modifies l h h')];
    [SMTPat (slice_access h' g sl pos); SMTPat (B.modifies l h h')];
  ]]
= ()

inline_for_extraction
let max_uint32 : U32.t = 4294967295ul

let max_uint32_correct
  (x: U32.t)
: Lemma
  (U32.v x <= U32.v max_uint32)
= ()

inline_for_extraction
class validator_cls = {
  // FIXME: ideally, the min bound on validator_max_length should not be a hard constant
  validator_max_length: (u: U32.t { 4 <= U32.v u /\ U32.v u < U32.v max_uint32 } )
}

inline_for_extraction
let validator [| validator_cls |] (#k: parser_kind) (#t: Type) (p: parser k t) : Tot Type =
  (sl: slice) ->
  (pos: U32.t) ->
  HST.Stack U32.t
  (requires (fun h -> live_slice h sl /\ U32.v pos <= U32.v sl.len /\ U32.v sl.len <= U32.v validator_max_length))
  (ensures (fun h res h' ->
    B.modifies B.loc_none h h' /\ (
    if U32.v res <= U32.v validator_max_length
    then
      valid_pos p h sl pos res
    else
      (~ (valid p h sl pos))
  )))

inline_for_extraction
let jumper
  (#k: parser_kind)
  (#t: Type)
  (p: parser k t)
: Tot Type
= (sl: slice) ->
  (pos: U32.t) ->
  HST.Stack U32.t
  (requires (fun h -> valid p h sl pos))
  (ensures (fun h pos' h' ->
    B.modifies B.loc_none h h' /\
    U32.v pos + content_length p h sl pos == U32.v pos'
  ))

inline_for_extraction
let accessor
  (#k1: parser_kind)
  (#t1: Type)
  (#p1: parser k1 t1)
  (#k2: parser_kind)
  (#t2: Type)
  (#p2: parser k2 t2)
  (#pre: t1 -> GTot Type0)
  (#cl: clens pre t2)
  (g: gaccessor p1 p2 cl)
: Tot Type
= (sl: slice) ->
  (pos: U32.t) ->
  HST.Stack U32.t
  (requires (fun h -> valid p1 h sl pos /\ pre (contents p1 h sl pos))) 
  (ensures (fun h pos' h' ->
    B.modifies B.loc_none h h' /\
    pos' == slice_access h g sl pos
  ))

#push-options "--z3rlimit 16"

inline_for_extraction
let accessor_compose
  (#k1: parser_kind)
  (#t1: Type)
  (#p1: parser k1 t1)
  (#k2: parser_kind)
  (#t2: Type)
  (#p2: parser k2 t2)
  (#pre1: (t1 -> GTot Type0))
  (#cl12: clens pre1 t2)
  (#a12: gaccessor p1 p2 cl12)
  (a12' : accessor a12)
  (#pre2: (t2 -> GTot Type0))
  (#k3: parser_kind)
  (#t3: Type)
  (#p3: parser k3 t3)
  (#cl23: clens pre2 t3)
  (#a23: gaccessor p2 p3 cl23)
  (a23' : accessor a23)
: Tot (accessor (gaccessor_compose a12 a23))
= fun input pos -> 
  let pos2 = a12' input pos in
  a23' input pos2

#pop-options

inline_for_extraction
let leaf_reader
  (#k: parser_kind)
  (#t: Type)
  (p: parser k t)
: Tot Type
= (sl: slice) ->
  (pos: U32.t) ->
  HST.Stack t
  (requires (fun h -> valid p h sl pos))
  (ensures (fun h res h' ->
    B.modifies B.loc_none h h' /\
    res == contents p h sl pos
  ))

inline_for_extraction
let leaf_reader_ext
  (#k1: parser_kind)
  (#t: Type)
  (#p1: parser k1 t)
  (p32: leaf_reader p1)
  (#k2: parser_kind)
  (p2: parser k2 t)
  (lem: (
    (x: bytes) ->
    Lemma
    (parse p2 x == parse p1 x)
  ))
: Tot (leaf_reader p2)
= fun sl pos ->
  let h = HST.get () in
  [@inline_let] let _ = lem (B.as_seq h (B.gsub sl.base pos (sl.len `U32.sub` pos))) in
  p32 sl pos

inline_for_extraction
let leaf_writer_weak
  (#k: parser_kind)
  (#t: Type)
  (#p: parser k t)
  (s: serializer p)
: Tot Type
= (x: t) ->
  (sl: slice) ->
  (pos: U32.t) ->
  HST.Stack U32.t
  (requires (fun h -> live_slice h sl /\ U32.v pos <= U32.v sl.len /\ U32.v sl.len < U32.v max_uint32))
  (ensures (fun h pos' h' ->
    B.modifies (loc_slice_from sl pos) h h' /\ (
    if pos' = max_uint32
    then U32.v pos + serialized_length s x > U32.v sl.len
    else valid_content_pos p h' sl pos x pos'
  )))

abstract
let loc_slice_from_to
  (sl: slice)
  (pos pos' : U32.t)
: GTot B.loc
= if U32.v pos' > U32.v sl.len
  then loc_slice_from sl pos
  else if U32.v pos > U32.v pos'
  then B.loc_none
  else B.loc_buffer (B.gsub sl.base pos (pos' `U32.sub` pos))

abstract
let loc_includes_union_l_loc_slice_from_to (l1 l2: B.loc) (s: slice) (pos pos' : U32.t) : Lemma
  (requires (B.loc_includes l1 (loc_slice_from_to s pos pos') \/ B.loc_includes l2 (loc_slice_from_to s pos pos')))
  (ensures (B.loc_includes (B.loc_union l1 l2) (loc_slice_from_to s pos pos')))
  [SMTPat (B.loc_includes (B.loc_union l1 l2) (loc_slice_from_to s pos pos'))]
= ()

abstract
let loc_slice_from_to_includes_r
  (sl: slice)
  (pos pos' : U32.t)
: Lemma
  (B.loc_includes (loc_slice_from sl pos) (loc_slice_from_to sl pos pos'))
  [SMTPat (loc_slice_from_to sl pos pos')]
= ()

abstract
let loc_slice_from_to_eq
  (sl: slice)
  (pos pos' : U32.t)
: Lemma
  (requires (U32.v pos <= U32.v pos' /\ U32.v pos' <= U32.v sl.len))
  (ensures (loc_slice_from_to sl pos pos' == B.loc_buffer (B.gsub sl.base pos (pos' `U32.sub` pos))))
= ()

abstract
let loc_slice_from_to_includes_l
  (sl: slice)
  (posl posr posl' posr' : U32.t)
: Lemma
  (requires (U32.v posl <= U32.v posl' /\ U32.v posr' <= U32.v posr))
  (ensures (loc_slice_from_to sl posl posr `B.loc_includes` loc_slice_from_to sl posl' posr'))
  [SMTPat (loc_slice_from_to sl posl posr `B.loc_includes` loc_slice_from_to sl posl' posr')]
= ()

abstract
let loc_slice_from_to_disjoint
  (sl: slice)
  (posl1 posr1 posl2 posr2 : U32.t)
: Lemma
  (requires (U32.v posr1 <= U32.v posl2))
  (ensures (B.loc_disjoint (loc_slice_from_to sl posl1 posr1) (loc_slice_from_to sl posl2 posr2)))
  [SMTPat (B.loc_disjoint (loc_slice_from_to sl posl1 posr1) (loc_slice_from_to sl posl2 posr2))]
= ()

abstract
let loc_slice_from_loc_slice_from_to_disjoint
  (sl: slice)
  (pos1 pos2 pos' : U32.t)
: Lemma
  (requires (U32.v pos2 <= U32.v pos'))
  (ensures (B.loc_disjoint (loc_slice_from_to sl pos1 pos2) (loc_slice_from sl pos')))
  [SMTPat (B.loc_disjoint (loc_slice_from_to sl pos1 pos2) (loc_slice_from sl pos'))]
= ()

inline_for_extraction
let leaf_writer_strong
  (#k: parser_kind)
  (#t: Type)
  (#p: parser k t)
  (s: serializer p)
: Tot Type
= (x: t) ->
  (sl: slice) ->
  (pos: U32.t) ->
  HST.Stack U32.t
  (requires (fun h -> live_slice h sl /\ U32.v pos + serialized_length s x <= U32.v sl.len))
  (ensures (fun h pos' h' ->
    B.modifies (loc_slice_from_to sl pos pos') h h' /\
    valid_content_pos p h' sl pos x pos'
  ))

inline_for_extraction
let serializer32
  (#k: parser_kind)
  (#t: Type)
  (#p: parser k t)
  (s: serializer p)
: Tot Type
= (x: t) ->
  (b: buffer8) ->
  HST.Stack U32.t
  (requires (fun h -> B.live h b /\ Seq.length (serialize s x) <= B.length b))
  (ensures (fun h len h' ->
    Seq.length (serialize s x) == U32.v len /\ (
    let b' = B.gsub b 0ul len in
    B.modifies (B.loc_buffer b') h h' /\
    B.live h b /\
    B.as_seq h' b' `Seq.equal` serialize s x
  )))

inline_for_extraction
let leaf_writer_strong_of_serializer32
  (#k: parser_kind)
  (#t: Type)
  (#p: parser k t)
  (#s: serializer p)
  (s32: serializer32 s)
  (u: squash (k.parser_kind_subkind == Some ParserStrong))
: Tot (leaf_writer_strong s)
= fun x input pos ->
  let b = B.sub input.base pos (input.len `U32.sub` pos) in
  let len = s32 x b in
  let h = HST.get () in
  [@inline_let] let pos' = pos `U32.add` len in
  [@inline_let] let _ : squash (valid_content_pos p h input pos x pos') =
    let small = B.as_seq h (B.gsub b 0ul len) in
    let large = B.as_seq h b in
    assert (no_lookahead_on p small large);
    assert (injective_postcond p small large);
    valid_facts p h input pos;
    ()
  in
  pos'

inline_for_extraction
let leaf_writer_weak_of_strong_constant_size
  (#k: parser_kind)
  (#t: Type)
  (#p: parser k t)
  (#s: serializer p)
  (s32: leaf_writer_strong s)
  (sz: U32.t)
  (u: squash (
    k.parser_kind_high == Some k.parser_kind_low /\
    k.parser_kind_low == U32.v sz /\
    k.parser_kind_low < U32.v max_uint32
  ))
: Tot (leaf_writer_weak s)
= fun x input pos ->
  if (input.len `U32.sub` pos) `U32.lt` sz
  then max_uint32
  else s32 x input pos

#set-options "--z3rlimit 16"

inline_for_extraction
let copy_strong
  (#k: parser_kind)
  (#t: Type)
  (p: parser k t)
  (src: slice) // FIXME: length is useless here
  (spos spos' : U32.t)
  (dst: slice)
  (dpos: U32.t)
: HST.Stack U32.t
  (requires (fun h ->
    k.parser_kind_subkind == Some ParserStrong /\
    valid_pos p h src spos spos' /\ (
    let clen = content_length p h src spos in
    U32.v dpos + clen <= U32.v dst.len /\
    live_slice h dst /\
    B.loc_disjoint (loc_slice_from_to src spos spos') (loc_slice_from_to dst dpos (dpos `U32.add` (U32.uint_to_t clen)))
  )))
  (ensures (fun h dpos' h' ->
    B.modifies (loc_slice_from_to dst dpos dpos') h h' /\
    valid_content_pos p h' dst dpos (contents p h src spos) dpos'
  ))
= let h0 = HST.get () in
  let len = spos' `U32.sub` spos in
  let src' = B.sub src.base spos len in
  let dst' = B.sub dst.base dpos len in
  B.blit src' 0ul dst' 0ul len;
  let h = HST.get () in
  [@inline_let] let dpos' = dpos `U32.add` len in
  assert (
    B.modifies (loc_slice_from_to dst dpos dpos') h0 h
  );
  assert (no_lookahead_on p (B.as_seq h0 (B.gsub src.base spos (src.len `U32.sub` spos))) (B.as_seq h (B.gsub dst.base dpos (dst.len `U32.sub` dpos))));
  assert (no_lookahead_on_postcond p (B.as_seq h0 (B.gsub src.base spos (src.len `U32.sub` spos))) (B.as_seq h (B.gsub dst.base dpos (dst.len `U32.sub` dpos))));
  assert (injective_precond p (B.as_seq h0 (B.gsub src.base spos (src.len `U32.sub` spos))) (B.as_seq h (B.gsub dst.base dpos (dst.len `U32.sub` dpos))));  
  dpos'

#reset-options

inline_for_extraction
let copy_weak_with_length
  (#k: parser_kind)
  (#t: Type)
  (p: parser k t)
  (src: slice) // FIXME: length is useless here
  (spos spos' : U32.t)
  (dst: slice)
  (dpos: U32.t)
: HST.Stack U32.t
  (requires (fun h ->
    k.parser_kind_subkind == Some ParserStrong /\
    valid_pos p h src spos spos' /\
    live_slice h dst /\
    U32.v dpos <= U32.v dst.len /\
    U32.v dst.len < U32.v max_uint32 /\
    B.loc_disjoint (loc_slice_from_to src spos spos') (loc_slice_from dst dpos)
  ))
  (ensures (fun h dpos' h' ->
    B.modifies (loc_slice_from dst dpos) h h' /\ (
    if dpos' = max_uint32
    then
      U32.v dpos + content_length p h src spos > U32.v dst.len
    else
      valid_content_pos p h' dst dpos (contents p h src spos) dpos'
  )))
= if (dst.len `U32.sub` dpos) `U32.lt` (spos' `U32.sub` spos)
  then max_uint32
  else copy_strong p src spos spos' dst dpos

inline_for_extraction
let copy_weak
  (#k: parser_kind)
  (#t: Type)
  (p: parser k t)
  (jmp: jumper p)
  (src: slice)
  (spos : U32.t)
  (dst: slice)
  (dpos: U32.t)
: HST.Stack U32.t
  (requires (fun h ->
    k.parser_kind_subkind == Some ParserStrong /\
    valid p h src spos /\
    live_slice h dst /\
    U32.v dpos <= U32.v dst.len /\
    U32.v dst.len < U32.v max_uint32 /\
    B.loc_disjoint (loc_slice_from src spos) (loc_slice_from dst dpos)
  ))
  (ensures (fun h dpos' h' ->
    B.modifies (loc_slice_from dst dpos) h h' /\ (
    if dpos' = max_uint32
    then
      U32.v dpos + content_length p h src spos > U32.v dst.len
    else
      valid_content_pos p h' dst dpos (contents p h src spos) dpos'
  )))
= let spos' = jmp src spos in
  copy_weak_with_length p src spos spos' dst dpos


(* Case where we do not have the strong prefix property (e.g. lists): we need an extra length *)

let valid_exact'
  (#k: parser_kind)
  (#t: Type)
  (p: parser k t)
  (h: HS.mem)
  (s: slice)
  (pos: U32.t)
  (pos' : U32.t)
: GTot Type0
= U32.v pos <= U32.v pos' /\
  U32.v pos' <= U32.v s.len /\
  live_slice h s /\ (
  let len' = pos' `U32.sub` pos in
  match parse p (B.as_seq h (B.gsub s.base pos len')) with
  | None -> False
  | Some (_, consumed) -> (consumed <: nat) == U32.v len'
  )

abstract
let valid_exact
  (#k: parser_kind)
  (#t: Type)
  (p: parser k t)
  (h: HS.mem)
  (s: slice)
  (pos: U32.t)
  (pos' : U32.t)
: GTot Type0
= valid_exact' p h s pos pos'

abstract
let valid_exact_elim
  (#k: parser_kind)
  (#t: Type)
  (p: parser k t)
  (h: HS.mem)
  (s: slice)
  (pos: U32.t)
  (pos' : U32.t)
: Lemma
  (requires (valid_exact p h s pos pos'))
  (ensures (valid_exact' p h s pos pos'))
  [SMTPat (valid_exact p h s pos pos')]
= ()

abstract
let valid_exact_equiv
  (#k: parser_kind)
  (#t: Type)
  (p: parser k t)
  (h: HS.mem)
  (s: slice)
  (pos: U32.t)
  (pos' : U32.t)
: Lemma
  (valid_exact p h s pos pos' <==> valid_exact' p h s pos pos')
= ()

let contents_exact'
  (#k: parser_kind)
  (#t: Type)
  (p: parser k t)
  (h: HS.mem)
  (s: slice)
  (pos: U32.t)
  (pos' : U32.t)
: Ghost t
  (requires (valid_exact' p h s pos pos'))
  (ensures (fun _ -> True))
= let (Some (v, _)) = parse p (B.as_seq h (B.gsub s.base pos (pos' `U32.sub` pos))) in
  v

abstract
let contents_exact
  (#k: parser_kind)
  (#t: Type)
  (p: parser k t)
  (h: HS.mem)
  (s: slice)
  (pos: U32.t)
  (pos' : U32.t)
: Ghost t
  (requires (valid_exact p h s pos pos'))
  (ensures (fun _ -> True))
= contents_exact' p h s pos pos'

abstract
let contents_exact_eq
  (#k: parser_kind)
  (#t: Type)
  (p: parser k t)
  (h: HS.mem)
  (s: slice)
  (pos: U32.t)
  (pos' : U32.t)
: Lemma
  (requires (valid_exact p h s pos pos'))
  (ensures (valid_exact' p h s pos pos' /\ contents_exact p h s pos pos' == contents_exact' p h s pos pos'))
= ()

abstract
let valid_exact_frame
  (#k: parser_kind)
  (#t: Type)
  (p: parser k t)
  (h: HS.mem)
  (s: slice)
  (pos: U32.t)
  (pos' : U32.t)
  (l: B.loc)
  (h' : HS.mem)
: Lemma
  (requires (valid_exact p h s pos pos' /\ B.modifies l h h' /\ B.loc_disjoint l (loc_slice_from_to s pos pos')))
  (ensures (valid_exact p h' s pos pos' /\ contents_exact p h' s pos pos' == contents_exact p h s pos pos'))
  [SMTPatOr [
    [SMTPat (valid_exact p h s pos pos'); SMTPat (B.modifies l h h')];
    [SMTPat (valid_exact p h' s pos pos'); SMTPat (B.modifies l h h')];
    [SMTPat (contents_exact p h s pos pos'); SMTPat (B.modifies l h h')];
    [SMTPat (contents_exact p h' s pos pos'); SMTPat (B.modifies l h h')];
  ]]
= ()

abstract
let valid_valid_exact
  (#k: parser_kind)
  (#t: Type)
  (p: parser k t)
  (h: HS.mem)
  (s: slice)
  (pos: U32.t)
: Lemma
  (requires (valid p h s pos /\ k.parser_kind_subkind == Some ParserStrong))
  (ensures (
    let npos' = U32.v pos + content_length p h s pos in
    npos' <= U32.v s.len /\ (
    let pos' = U32.uint_to_t npos' in
    valid_exact p h s pos pos' /\
    contents_exact p h s pos pos' == contents p h s pos
  )))
= let npos' = U32.v pos + content_length p h s pos in
  assert (npos' <= U32.v s.len);
  let pos' = U32.uint_to_t npos' in
  assert (no_lookahead_on p (B.as_seq h (B.gsub s.base pos (s.len `U32.sub` pos))) (B.as_seq h (B.gsub s.base pos (pos' `U32.sub` pos))));
  assert (injective_precond p (B.as_seq h (B.gsub s.base pos (s.len `U32.sub` pos))) (B.as_seq h (B.gsub s.base pos (pos' `U32.sub` pos))));
  assert (injective_postcond p (B.as_seq h (B.gsub s.base pos (s.len `U32.sub` pos))) (B.as_seq h (B.gsub s.base pos (pos' `U32.sub` pos))))

abstract
let valid_pos_valid_exact
  (#k: parser_kind)
  (#t: Type)
  (p: parser k t)
  (h: HS.mem)
  (s: slice)
  (pos: U32.t)
  (pos' : U32.t)
: Lemma
  (requires (valid_pos p h s pos pos' /\ k.parser_kind_subkind == Some ParserStrong))
  (ensures (
    valid_exact p h s pos pos' /\
    contents_exact p h s pos pos' == contents p h s pos
  ))
= valid_valid_exact p h s pos

abstract
let valid_exact_valid
  (#k: parser_kind)
  (#t: Type)
  (p: parser k t)
  (h: HS.mem)
  (s: slice)
  (pos: U32.t)
  (pos' : U32.t)
: Lemma
  (requires (valid_exact p h s pos pos' /\ k.parser_kind_subkind == Some ParserStrong))
  (ensures (
    valid_content_pos p h s pos (contents_exact p h s pos pos') pos'
  ))
= assert (no_lookahead_on p (B.as_seq h (B.gsub s.base pos (pos' `U32.sub`pos))) (B.as_seq h (B.gsub s.base pos (s.len `U32.sub` pos))));
  assert (injective_precond p (B.as_seq h (B.gsub s.base pos (pos' `U32.sub` pos))) (B.as_seq h (B.gsub s.base pos (s.len `U32.sub` pos))));
  assert (injective_postcond p (B.as_seq h (B.gsub s.base pos (pos' `U32.sub` pos))) (B.as_seq h (B.gsub s.base pos (s.len `U32.sub` pos))))

let valid_pos_frame_strong
  (#k: parser_kind)
  (#t: Type)
  (p: parser k t)
  (h: HS.mem)
  (sl: slice)
  (pos: U32.t)
  (pos' : U32.t)
  (l: B.loc)
  (h': HS.mem)
: Lemma
  (requires (valid_pos p h sl pos pos' /\ B.modifies l h h' /\ B.loc_disjoint (loc_slice_from_to sl pos pos') l /\ k.parser_kind_subkind == Some ParserStrong))
  (ensures (
    valid_content_pos p h' sl pos (contents p h sl pos) pos'
  ))
  [SMTPatOr [
    [SMTPat (valid_pos p h sl pos pos'); SMTPat (valid p h' sl pos); SMTPat (B.modifies l h h')];
    [SMTPat (valid_pos p h sl pos pos'); SMTPat (contents p h' sl pos); SMTPat (B.modifies l h h')];
    [SMTPat (valid_pos p h sl pos pos'); SMTPat (content_length p h' sl pos); SMTPat (B.modifies l h h')];
  ]]
= valid_pos_valid_exact p h sl pos pos';
  valid_exact_valid p h' sl pos pos'

abstract
let valid_exact_ext_intro
  (#k: parser_kind)
  (#t: Type)
  (p: parser k t)
  (h: HS.mem)
  (s1: slice)
  (pos1: U32.t)
  (pos1' : U32.t)
  (s2: slice)
  (pos2: U32.t)
  (pos2' : U32.t)
: Lemma
  (requires (
    valid_exact p h s1 pos1 pos1' /\
    live_slice h s2 /\
    U32.v pos1' - U32.v pos1 == U32.v pos2' - U32.v pos2 /\
    U32.v pos2' <= U32.v s2.len /\
    B.as_seq h (B.gsub s1.base pos1 (pos1' `U32.sub` pos1)) `Seq.equal` B.as_seq h (B.gsub s2.base pos2 (pos2' `U32.sub` pos2))
  ))
  (ensures (
    valid_exact p h s2 pos2 pos2' /\
    contents_exact p h s2 pos2 pos2' == contents_exact p h s1 pos1 pos1'
  ))
= ()

abstract
let valid_exact_ext_elim
  (#k: parser_kind)
  (#t: Type)
  (p: parser k t)
  (h: HS.mem)
  (s1: slice)
  (pos1: U32.t)
  (pos1' : U32.t)
  (s2: slice)
  (pos2: U32.t)
  (pos2' : U32.t)
: Lemma
  (requires (
    valid_exact p h s1 pos1 pos1' /\
    valid_exact p h s2 pos2 pos2' /\
    contents_exact p h s1 pos1 pos1' == contents_exact p h s2 pos2 pos2'
  ))
  (ensures (
    U32.v pos2' - U32.v pos2 == U32.v pos1' - U32.v pos1 /\
    B.as_seq h (B.gsub s1.base pos1 (pos1' `U32.sub` pos1)) == B.as_seq h (B.gsub s2.base pos2 (pos2' `U32.sub` pos2))
  ))
= assert (injective_precond p (B.as_seq h (B.gsub s1.base pos1 (pos1' `U32.sub` pos1))) (B.as_seq h (B.gsub s2.base pos2 (pos2' `U32.sub` pos2))));
  assert (injective_postcond p (B.as_seq h (B.gsub s1.base pos1 (pos1' `U32.sub` pos1))) (B.as_seq h (B.gsub s2.base pos2 (pos2' `U32.sub` pos2))))
