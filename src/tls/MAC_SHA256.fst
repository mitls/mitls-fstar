﻿module MAC_SHA256

open FStar.Heap
open FStar.HyperHeap
open FStar.HyperStack
open FStar.Seq
 // for e.g. found

open Platform.Bytes
open TLSConstants
open TLSInfo
open Platform.Error
open TLSError

// idealizing HMAC
// for concreteness; the rest of the module is parametric in a

let a = HMAC CoreCrypto.SHA256

type id = i:id { ID12? i /\ ~(AEAD? (aeAlg_of_id i)) }

type text = bytes
type tag (i:id) = bytes
type keyrepr (i:id) = bytes
type key (i:id) = keyrepr i

// TBD in Encode?
type good (i:id) (b:bytes) = True


// we keep the tag in case we want to enforce tag authentication
type entry (i:id) = | Entry: t:tag i -> p:bytes { good i p } -> entry i

// readers and writers share the same state: a log of MACed messages
(*
 * AR: similar to MAC changes, region is of type rgn and log is a ref.
 *)
noeq type state (i:id) (rw:rw) = | State:
  #region:rgn -> // the region of the *writer*
  key: key i ->
  log: ref (seq (entry i)){log.id = region} ->
  state i rw

private type writer i = s:state i Writer
private type reader i = s:state i Reader

val gen: w:rid{is_eternal_region w}
    -> i:id
    -> St (reader i * writer i) //TODO: a more complete spec here
let gen writer_parent i =
  let kv = CoreCrypto.random (macKeySize a) in
  let writer_r = new_region writer_parent in
  let log = ralloc writer_r Seq.createEmpty in
  State #i #Reader #writer_r kv log,
  State #i #Writer #writer_r kv log

val mac: i:id -> wr:writer i -> p:bytes { good i p } -> ST (tag i)
  (requires (fun h0 -> True))
  (ensures (fun h0 t h1 ->
    modifies (Set.singleton wr.region) h0 h1 /\ // skipping modifies rref, as the region contains only one ref
    sel h1 wr.log == snoc (sel h0 wr.log) (Entry t p)))

(*
 * AR: similar to MAC, had to add a recall on wr.log.
 *)
let mac i wr p =
  assume (HashMAC.is_tls_mac (macAlg_of_id i));
  let t : tag i = HashMAC.tls_mac a wr.key p in
  recall wr.log;
  wr.log := snoc !wr.log (Entry #i t p); // We log every authenticated texts, with their index and resulting tag
  t

val matches: i:id -> p:text -> entry i -> Tot bool
let matches i p (Entry _ p') = p = p'

val verify: i:id -> rd:reader i -> p:bytes -> t:tag i -> ST bool
  (requires (fun h0 -> True))
  (ensures (fun h0 b h1 ->
    h0 == h1 /\
    (b ==> good i p)))

let verify i rd p t =
    let v = HashMAC.tls_macVerify a rd.key p t in
    let l = !rd.log in
    // We use the log to correct any verification errors
    v &&
    Some? (seq_find (matches i p) l)
