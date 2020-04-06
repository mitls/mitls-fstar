(**
Provides authenticated encryption for a stream of variable-length plaintexts;
concretely, we use AES_GCM but any other AEAD algorithm would do.
*)
module StreamAE
module HST = FStar.HyperStack.ST //Added automatically

open FStar.HyperStack
open FStar.Seq
open FStar.Monotonic.Seq
open FStar.Error
open FStar.Bytes

open Mem
open TLSError
open TLSConstants
open TLSInfo
open StreamPlain

module AEAD = AEADProvider
module HS = FStar.HyperStack

type rid = HST.erid

type id = i:id { ID13? i }

let alg (i:id) =
  let AEAD ae _ = aeAlg_of_id i in ae

let ltag i : nat = UInt32.v (EverCrypt.aead_tagLen (alg i))
let cipherLen i (l:plainLen) : nat = l + ltag i
type cipher i (l:plainLen) = lbytes (cipherLen i l)

// will require proving before decryption
let lenCipher i (c:bytes { ltag i <= length c }) : nat = length c - ltag i

type entry (i:id) =
  | Entry: l:plainLen -> c:cipher i l -> p:plain i l -> entry i

// key materials (from the AEAD provider)
type key (i:id) = AEAD.key i
type iv  (i:id) = AEAD.salt i
 
let ideal_log (r:erid) (i:id) = log_t r (entry i)

let log_ref (r:erid) (i:id) : Tot Type0 =
  if authId i then ideal_log r i else unit

noextract
let ilog (#r:erid) (#i:id) (l:log_ref r i{authId i}) : Tot (ideal_log r i) =
  l

irreducible let max_ctr: n:nat{n = 18446744073709551615} =
  assert_norm (pow2 64 - 1 = 18446744073709551615);
  pow2 64 - 1

type counter = c:nat{c <= max_ctr}

let ideal_ctr (#l:erid) (r: erid) (i:id) (log:ideal_log l i) : Tot Type0 =
  FStar.Monotonic.Seq.seqn r log max_ctr
  // An increasing counter, at most min(length log, 2^64-1)

let concrete_ctr (r:erid) (i:id) : Tot Type0 =
  m_rref r counter increases

let ctr_ref (#l:erid) (r:erid) (i:id) (log:log_ref l i) : Tot Type0 =
  if authId i
  then ideal_ctr r i (log <: ideal_log l i)
  else m_rref r counter increases

let ctr (#l:erid) (#r:erid) (#i:id) (#log:log_ref l i) (c:ctr_ref r i log)
  : Tot (m_rref r (if authId i
		   then seqn_val #l #(entry i) r log max_ctr
		   else counter)
		increases) =
  c

// kept concrete for log and counter, but the key and iv should be private.
noeq type state (i:id) (rw:rw) =
  | State: #region: rgn
         -> #log_region: rgn{if rw = Writer then region = log_region else HS.disjoint region log_region}
         -> aead: AEAD.state i rw
         -> log: log_ref log_region i // ghost, subject to cryptographic assumption
         -> counter: ctr_ref region i log // types are sufficient to anti-alias log and counter
         -> state i rw

// Some invariants:
// - the writer counter is the length of the log; the reader counter is lower or equal
// - gen is called at most once for each (i:id), generating distinct refs for each (i:id)
// - the log is monotonic

type writer i = state i Writer
type reader i = state i Reader

#set-options "--admit_smt_queries true"

// We generate first the writer, then the reader (possibly several of them)
let genPost (#i:id) parent h0 (w:writer i) h1 =
  modifies_none h0 h1 /\
  HS.parent w.region = parent /\
  HS.fresh_region w.region h0 h1 /\
  color w.region = color parent /\
//  extends (AEAD.region w.aead) parent /\
//  HS.fresh_region (AEAD.region w.aead) h0 h1 /\
//  color (AEAD.region w.aead) = color parent /\
  (authId i ==>
      (h1 `HS.contains` (ilog w.log) /\
       sel h1 (ilog w.log) == Seq.empty)) /\
  h1 `HS.contains` (ctr w.counter) /\
  sel h1 (ctr w.counter) == 0
//16-04-30 how to share the whole ST ... instead of genPost?

// Generate a fresh instance with index i in a fresh sub-region of r0
// (we might drop this spec, since F* will infer something at least as precise,
// but we keep it for documentation)
val gen: parent:rgn -> i:id -> ST (writer i)
  (requires (fun h0 -> witnessed (region_contains_pred parent))) 
  (ensures (genPost parent))

#set-options "--z3rlimit 100 --initial_fuel 0 --max_fuel 0 --initial_ifuel 1 --max_ifuel 1"
let gen parent i =
  let writer_r = new_region parent in
  lemma_ID13 i;
  let aead = AEAD.gen i parent in
  let _ = cut (is_eternal_region writer_r) in
  if authId i then
    let log : ideal_log writer_r i = alloc_mref_seq writer_r Seq.empty in
    let ectr: ideal_ctr #writer_r writer_r i log = new_seqn #(entry i) #writer_r #max_ctr writer_r 0 log in
    State #i #Writer #writer_r #writer_r aead log ectr
  else
    let ectr: concrete_ctr writer_r i = HST.ralloc writer_r 0 in
    State #i #Writer #writer_r #writer_r aead () ectr

val genReader: parent:rgn -> #i:id -> w:writer i -> ST (reader i)
  (requires (fun h0 -> 
    witnessed (region_contains_pred parent) /\ 
    disjoint parent w.region /\
//    disjoint parent (AEAD.region w.aead)) /\
    True)) //16-04-25  we may need w.region's parent instead
  (ensures  (fun h0 (r:reader i) h1 ->
         modifies Set.empty h0 h1 /\
         r.log_region = w.region /\
         HS.parent r.region = parent /\
	       color r.region = color parent /\
         HS.fresh_region r.region h0 h1 /\
         w.log == r.log /\
	 h1 `HS.contains` (ctr r.counter) /\
	 sel h1 (ctr r.counter) == 0))
// encryption (on concrete bytes), returns (cipher @| tag)
// Keeps seqn and nonce implicit; requires the counter not to overflow
// encryption of plaintexts; safe instances are idealized

#set-options "--z3rlimit 100 --initial_fuel 0 --max_fuel 0 --initial_ifuel 1 --max_ifuel 1"
let genReader parent #i w =
  let reader_r = new_region parent in
  let writer_r : rgn = w.region in
  assert(HS.disjoint writer_r reader_r);
  lemma_ID13 i;
  let raead = AEAD.genReader parent #i w.aead in
  if authId i then
    let log : ideal_log w.region i = w.log in
    let dctr: ideal_ctr reader_r i log = new_seqn reader_r 0 log in
    State #i #Reader #reader_r #writer_r raead w.log dctr
  else let dctr : concrete_ctr reader_r i = HST.ralloc reader_r 0 in
    State #i #Reader #reader_r #writer_r raead () dctr

// Coerce a writer with index i in a fresh subregion of parent
// (coerced readers can then be obtained by calling genReader)
val coerce: parent:rgn -> i:id{~(authId i)} -> kv:key i -> iv:iv i -> ST (writer i)
  (requires (fun h0 -> True))
  (ensures  (genPost parent))

let coerce parent i kv iv =
  assume false; // coerce missing post-condition
  let writer_r = new_region parent in
  let ectr: concrete_ctr writer_r i = HST.ralloc writer_r 0 in
  let aead = AEAD.coerce i parent kv iv in
  State #i #Writer #writer_r #writer_r aead () ectr

val leak: #i:id{~(authId i)} -> #role:rw -> state i role -> ST (key i * iv i)
  (requires (fun h0 -> True))
  (ensures  (fun h0 r h1 -> modifies Set.empty h0 h1 ))

let leak #i #role s =
  lemma_ID13 i;
  AEAD.leak #i #role (State?.aead s)

val encrypt: #i:id -> e:writer i -> ad:bytes -> l:plainLen -> p:plain i l -> ST (cipher i l)
    (requires (fun h0 ->
      lemma_ID13 i;
//      HS.disjoint e.region (AEAD.log_region #i e.aead) /\
      l <= max_TLSPlaintext_fragment_length /\
      sel h0 (ctr e.counter) < max_ctr))
    (ensures  (fun h0 c h1 ->
      lemma_ID13 i;
      modifies (Set.as_set [e.log_region (*; AEAD.log_region #i e.aead *)]) h0 h1 /\
      h1 `HS.contains` (ctr e.counter) /\
      sel h1 (ctr e.counter) == sel h0 (ctr e.counter) + 1 /\
	    (authId i ==>
		    (let log = ilog e.log in
		    let ent = Entry l c p in
		    let n = Seq.length (sel h0 log) in
		    h1 `HS.contains` log /\
		    witnessed (at_least n ent log) /\
		    sel h1 log == snoc (sel h0 log) ent))))

(* we primarily model the ideal functionality, the concrete code that actually
   runs on the network is what remains after dead code elimination when
   safeId i is fixed to false and after removal of the cryptographic ghost log,
   i.e. all idealization is turned off *)
#set-options "--z3rlimit 150 --max_ifuel 2 --initial_ifuel 0 --max_fuel 2 --initial_fuel 0 --admit_smt_queries true"
let encrypt #i e ad l p =
  let h0 = get() in
  let ctr = ctr e.counter in
  HST.recall ctr;
  let text = if safeId i then create_ l 0z else repr i l p in
  let n = HST.op_Bang ctr in
  lemma_repr_bytes_values n;
  let nb = bytes_of_int (AEAD.noncelen i) n in
  let iv = AEAD.create_nonce e.aead nb in
  lemma_repr_bytes_values (length text);
  let c = AEAD.encrypt #i #l e.aead iv ad text in
  if authId i then
    begin
    let ilog = ilog e.log in
    HST.recall ilog;
    let ictr: ideal_ctr e.region i ilog = e.counter in
    testify_seqn ictr;
    write_at_end ilog (Entry l c p); //need to extend the log first, before incrementing the counter for monotonicity; do this only if ideal
    HST.recall ictr;
    increment_seqn ictr;
    HST.recall ictr
    end
  else
    ctr := n + 1;
  c

(* val matches: #i:id -> l:plainLen -> cipher i l -> entry i -> Tot bool *)
let matches (#i:id) (l:plainLen) (c:cipher i l) (e:entry i) : Tot bool =
  let Entry l' c' _ = e in
  l = l' && c = c'

// decryption, idealized as a lookup of (c,ad) in the log for safe instances
val decrypt: #i:id -> d:reader i -> ad:bytes -> l:plainLen -> c:cipher i l
  -> ST (option (plain i (min l (max_TLSPlaintext_fragment_length + 1))))
  (requires (fun h0 ->
     l <= max_TLSPlaintext_fragment_length /\ // FIXME ADL: why is plainLen <= max_TLSCiphertext_fragment_length_13 ?? Fix StreamPlain!
     sel h0 (ctr d.counter) < max_ctr))
  (ensures  (fun h0 res h1 ->
      let j : nat = sel h0 (ctr d.counter) in
      (authId i ==>
    	(let log = sel h0 (ilog d.log) in
    	 if j < Seq.length log && matches l c (Seq.index log j)
    	 then res = Some (Entry?.p (Seq.index log j))
    	 else res = None)) /\
      (match res with
       | None -> HS.modifies_transitively Set.empty h0 h1
       | _ -> let ctr_counter_as_hsref = ctr d.counter in
             HS.modifies_one d.region h0 h1 /\
             HS.modifies_ref d.region (Set.singleton (Heap.addr_of (as_ref ctr_counter_as_hsref))) h0 h1 /\
             sel h1 (ctr d.counter) == j + 1)))

val strip_refinement: #a:Type -> #p:(a -> Type0) -> o:option (x:a{p x}) -> option a
let strip_refinement #a #p = function
  | None -> None
  | Some x -> Some x

#set-options "--z3rlimit 100 --initial_fuel 0 --initial_ifuel 1 --max_fuel 0 --max_ifuel 1"
// decryption, idealized as a lookup of (c,ad) in the log for safe instances
let decrypt #i d ad l c =
  let ctr = ctr d.counter in
  HST.recall ctr;
  let j = HST.op_Bang ctr in
  if authId i
  then (
    let ilog = ilog d.log in
    let log  = HST.op_Bang ilog in
    let ictr: ideal_ctr d.region i ilog = d.counter in
    testify_seqn ictr; //now we know that j <= Seq.length log
    if j < Seq.length log && matches l c (Seq.index log j) then
      begin
      increment_seqn ictr;
      HST.recall ctr;
      Some (Entry?.p (Seq.index log j))
      end
    else None )
  else //concrete
   begin
   lemma_ID13 i;
   assert (AEAD.noncelen i = AEAD.iv_length i);
   lemma_repr_bytes_values j;
   let nb = bytes_of_int (AEAD.noncelen i) j in
   let iv = AEAD.create_nonce d.aead nb in
   match AEAD.decrypt #i #l d.aead iv ad c with
   | None -> None
   | Some pr ->
     begin
       assert (FStar.Bytes.length pr == l);
       let p = strip_refinement (mk_plain i l pr) in
       if Some? p then ctr := (j + 1);
       p
     end
   end

(* TODO

- Check that decrypt indeed must use authId and not safeId (like in the F7 code)
- Injective allocation table from i to refs

*)
