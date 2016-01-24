module StreamAE

// Provides authenticated encryption for a stream of variable-length
// plaintexts; concretely, we use AES_GCM but any other algorithm
// would do.

open FStar.Heap
open FStar.HyperHeap
open FStar.Seq
open FStar.SeqProperties // for e.g. found
open Platform.Error
open Platform.Bytes
//open CoreCrypto          // for algorithm names, and key, IV, tag lengths

open TLSError
open TLSConstants
open TLSInfo
open StreamPlain

type id = i:id { pv_of_id i = TLS_1p3 }

assume val alg: i:id -> Tot CoreCrypto.aead_cipher // unclear what to re-use as alg IDs

let ltag i = CoreCrypto.aeadTagSize (alg i)
let cipherLen i (l:plainLen) = l + ltag i

type cipher i (l:plainLen) = lbytes (cipherLen i l)

// we may need some WFness condition, e.g. correct padding
//val make: i:sid { ~(authId i) } -> r:repr i -> p:plain i { length r = plength p } 
//val repr: i:sid { ~(safeId i) } -> p:plain i -> r:repr i { length r = plength p }  

type entry (i:id) = | Entry: l:plainLen -> c:cipher i l -> p:plain i l -> entry i

// key materials 
private type key (i:id) = lbytes (CoreCrypto.aeadKeySize (alg i)) 
private type iv  (i:id) = lbytes (CoreCrypto.aeadRealIVSize (alg i)) // should it be aeadSaltSize?

type seqn i = n:nat { repr_bytes n <= aeadRecordIVSize (alg i)}

val max_uint64: n:nat {repr_bytes n <= 8} 
let max_uint64 = 
  //let n = 18446744073709551615 in
  let n = 1073741823 in //2^30-1 4611686018427387903 in // (2^62-1) (* TODO: Fix this *)
  lemma_repr_bytes_values n; n

type state (i:id) (rw:rw) =
  | State: #region:rid 
         -> #peer_region:rid{HyperHeap.disjoint region peer_region}
         -> key:key i
         -> iv: iv i
         -> log: rref (if rw=Reader then peer_region else region) (seq (entry i)) // ghost, subject to cryptographic assumption
         -> counter: rref region (seqn i) // types are sufficient to anti-alias log and counter
         -> state i rw
// Some invariants:
// - the writer counter is the length of the log; the reader counter is lower or equal
// - gen is called at most once for each (i:id), generating distinct refs for each (i:id)
// - the log is monotonic

type writer i = s:state i Writer
type reader i = s:state i Reader

// Generate a fresh instance with index i in a fresh sub-region of r0
// (we might drop this spec, since F* will infer something at least as precise,
// but we keep it for documentation)
val gen: reader_parent:rid -> writer_parent:rid -> i:id -> ST (reader i * writer i)
  (requires (fun h0 -> HyperHeap.disjoint reader_parent writer_parent))
  (ensures  (fun h0 (rw:reader i * writer i) h1 ->
           let r = fst rw in 
           let w = snd rw in 
           (* let bang = fun x -> sel h1 x in  *)
           modifies Set.empty h0 h1
         /\ w.region = r.peer_region
         /\ r.region = w.peer_region
         /\ extends (w.region) writer_parent
         /\ extends (r.region) reader_parent
         /\ fresh_region w.region h0 h1
         /\ fresh_region r.region h0 h1
         /\ op_Equality #(rref w.region (seq (entry i))) w.log r.log  //the explicit annotation here 
         /\ contains_ref w.counter h1
         /\ contains_ref r.counter h1
         /\ contains_ref w.log h1
         /\ sel h1 w.counter = 0
         /\ sel h1 r.counter = 0
         /\ sel h1 w.log = createEmpty
         ))

let gen reader_parent writer_parent i =
  let kv   = CoreCrypto.random (CoreCrypto.aeadKeySize (alg i)) in
  let iv   = CoreCrypto.random (CoreCrypto.aeadRealIVSize (alg i)) in
  let reader_r = new_region reader_parent in
  let writer_r = new_region writer_parent in
  lemma_repr_bytes_values 0;
  let ectr = ralloc writer_r 0 in
  let dctr = ralloc reader_r 0 in
  let log  = ralloc writer_r Seq.createEmpty in
  let writer  = State #i #Writer #writer_r #reader_r kv iv log ectr in
  let reader  = State #i #Reader #reader_r #writer_r kv iv log dctr in
  reader, writer

// Coerce an instance with index i in a fresh sub-region of r0
val coerce: r0:rid -> p0:rid -> i:id{~(safeId i)} -> role:rw -> kv:key i -> iv:iv i -> ST (state i role)
  (requires (fun h0 -> disjoint r0 p0))
  (ensures  (fun h0 s h1 ->
                modifies Set.empty h0 h1
              /\ extends s.region r0
              /\ extends s.peer_region p0
              /\ fresh_region s.region h0 h1
              /\ fresh_region s.peer_region h0 h1))
let coerce r0 p0 i role kv iv =
  let r = new_region r0 in
  let p = new_region p0 in 
  lemma_repr_bytes_values 0; 
  let ctr : rref r _ = ralloc r 0 in
  if role=Reader
  then let log : rref p _ = ralloc p Seq.createEmpty in
       State #i #role #r #p kv iv log ctr
  else let log : rref r _ = ralloc r Seq.createEmpty in 
       State #i #role #r #p kv iv log ctr //NS: worryingly, succeeds with implicit arguments even without the role=Writer

val leak: i:id{~(safeId i)} -> role:rw -> state i role -> ST (key i * iv i)
  (requires (fun h0 -> True))
  (ensures  (fun h0 r h1 -> modifies Set.empty h0 h1 ))

let leak i role s = State.key s, State.iv s


// The per-record nonce for the AEAD construction is formed as follows:
//
// 1. The 64-bit record sequence number is padded to the left with zeroes to iv_length.
//
// 2. The padded sequence number is XORed with the static client_write_iv or server_write_iv, 
//    depending on the role.
//
// The XORing is a fixed, ad hoc, random permutation; not sure what is gained;
// we can reason about sequence-number collisions before applying it.
let aeIV i (n:seqn i) (staticIV: iv i) : iv i = 
  let l = CoreCrypto.aeadRealIVSize (alg i) in
  let extended: iv i = createBytes (l - 8) 0uy @| bytes_of_seq n (* 64 bits *) in
  xor l extended staticIV

// not relying on additional data
let noAD = empty_bytes 

// Raw encryption (on concrete bytes), returns (cipher @| tag)
// Keeps seqn and nonce implicit; requires the counter not to overflow
val enc:
  i:id -> e:writer i -> l:plainLen -> p:lbytes l -> ST (cipher i l)
    (requires (fun h -> True))
    (ensures  (fun h0 c h1 -> 
                 modifies (Set.singleton e.region) h0 h1
               /\ modifies_rref e.region !{as_ref e.counter} h0 h1
               // /\ sel h1 e.counter = sel h0 e.counter + 1
    ))

let enc i e l p =
  recall e.counter;
  let iv = aeIV i !e.counter e.iv in
  let c = CoreCrypto.aead_encrypt (alg i) e.key iv noAD p in
  let n = !e.counter in
  if n + 1 < max_uint64 then 
    begin
      lemma_repr_bytes_values (n + 1);
      e.counter := n + 1
    end
  else
    begin
      // overflow, we don't care
      lemma_repr_bytes_values 0;
      e.counter := 0
    end;
   c


// encryption of plaintexts; safe instances are idealized
val encrypt:
  i:id -> e:writer i -> l:plainLen -> p:plain i l -> ST (cipher i l)
    (requires (fun h0 -> True))
    (ensures  (fun h0 c h1 ->
                           modifies (Set.singleton e.region) h0 h1
                         /\ modifies_rref e.region !{as_ref e.counter, as_ref e.log} h0 h1
                         /\ contains_ref e.log h1 
                         /\ contains_ref e.counter h1
                         (* /\ sel h1 e.counter = sel h0 e.counter + 1 *)
                         /\ sel h1 e.log = snoc (sel h0 e.log) (Entry l c p)))

(* we primarily model the ideal functionality, the concrete code that actually
   runs on the network is what remains after dead code elimination when
   safeId i is fixed to false and after removal of the cryptographic ghost log,
   i.e. all idealization is turned off *)
let encrypt i e l p =
  recall e.log;
  let text = if safeId i then createBytes l 0uy else repr i l p in
  let c = enc i e l text in
  e.log := snoc !e.log (Entry l c p);
  recall e.counter; 
  c


// raw decryption (returning concrete bytes)
private val dec: 
  i:id{~(authId i)} -> d:reader i -> l:plainLen -> c:cipher i l
  -> ST (option (lbytes l))
  (requires (fun h -> True))
  (ensures  (fun h0 _ h1 -> modifies Set.empty h0 h1))

let dec i d l c =
  let iv = aeIV i !d.counter d.iv  in
  match CoreCrypto.aead_decrypt (alg i) d.key iv noAD c with 
  | Some p -> Some p 
  | None   -> None

val matches: #i:id -> l:plainLen -> c:cipher i l -> entry i -> Tot bool
let matches i l c (Entry l' c' _) = l = l' && c = c' 

// decryption, idealized as a lookup of (c,ad) in the log for safe instances
val decrypt: 
  i:id -> d:reader i -> l:plainLen -> c:cipher i l
  -> ST (option (plain i l))
  (requires (fun h0 -> True))
  (ensures  (fun h0 res h1 ->
               modifies Set.empty h0 h1
             /\ (authId i ==>
                 Let (sel h0 d.log) // no let, as we still need a type annotation
                   (fun (log:seq (entry i)) ->
                       (is_None res ==> (forall (j:nat{j < Seq.length log}).{:pattern (found j)}
                                            found j /\ ~(matches l c (Seq.index log j))))
                     /\ (is_Some res ==> (exists (j:nat{j < Seq.length log}).{:pattern (found j)}
                                           found j
                                           /\ matches l c (Seq.index log j)
                                           /\ Entry.p (Seq.index log j) == Some.v res))))))


// decryption, idealized as a lookup of (c,ad) in the log for safe instances
let decrypt i d l c =
  recall d.log;
  let log = !d.log in
  if authId i then 
    match seq_find (matches l c) log with
    | None -> None
    | Some e -> Some (Entry.p e)
  else 
    match dec i d l c with 
    | Some pr -> 
       (match mk_plain i l pr with 
        | Some p -> Some p 
        | None  -> None)
    | None -> None

(* TODO 

- Check that decrypt indeed must use authId and not safeId (like in the F7 code)
- How to handle counter overflows?
- Injective allocation table from i to refs

*)

(* another version; we'll probably also need an explicit invariant
val encrypt: #i:sid -> wr:writer i -> p:plain i -> ST (cipher i (plength p))
  (requires (fun h -> 
      st_enc_inv wr h /\ 
      is_seqn (sel h wr.seqn + 1)))
  (ensures  (fun h0 c h1 ->
      st_enc_inv wr h1 /\ 
      modifies (Set.singleton wr.region) h0 h1 /\
      modifies_rref wr.region (refs_in_e wr) h0 h1 /\
      sel h1 wr.seqn = sel h0 wr.seqn + 1 /\
      sel h1 wr.log = snoc (sel h0 wr.log) (Entry c p)))

val decrypt: i:sid -> d:reader i -> c:bytes -> ST (option (dplain i c))
  (requires (fun h -> 
      (authId ==> st_dec_inv rd h) /\ 
      is_seqn (sel h rd.seqn + 1)))

  (ensures  (fun h0 res h1 ->
               modifies Set.empty h0 h1
             /\ (authId i ==>
                 Let (sel h0 d.log) // no let, as we still need a type annotation
                   (fun (log:seq (entry i)) ->
                       (is_None res ==> (forall (j:nat{j < Seq.length log}).{:pattern (found j)}
                                            found j /\ ~(matches c ad (Seq.index log j))))
                     /\ (is_Some res ==> (exists (j:nat{j < Seq.length log}).{:pattern (found j)}
                                           found j
                                           /\ matches c ad (Seq.index log j)
                                           /\ Entry.p (Seq.index log j) == Some.v res))))))
*)

