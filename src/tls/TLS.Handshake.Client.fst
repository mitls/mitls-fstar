module TLS.Handshake.Client

//open FStar.Integers
open Mem
open TLSConstants
open TLSInfo
open TLSError

module HS = FStar.HyperStack
open FStar.HyperStack.ST

open TLS.Handshake.Messaging
open TLS.Handshake.Machine

module Send = TLS.Handshake.Send
module Recv = TLS.Handshake.Receive

module HD = Hashing.Spec
module Nego = Negotiation 
module LB = LowStar.Buffer
module CH = Parsers.ClientHello
module Epochs = Old.Epochs
module Msg = HandshakeMessages
module PF = TLS.Handshake.ParseFlights // avoidable?
module HMAC = Old.HMAC.UFCMA
module KS = Old.KeySchedule
module Transcript = TLS.Handshake.Transcript

#set-options "--max_fuel 0 --max_ifuel 0"

(*** Hello messages ***)

//19-09-03 much left to do for stateful TCing
//#push-options "--admit_smt_queries true"

// FIXME(adl): I think we should do things properly with the
// initial multi-hash transcript - my proposal is to materialize
// a joint type, since we only have 2 cases with TLS 1.3
// (there is no SHA2_512 ciphersuite yet). There is a lot left
// to specify (disjointness and consistency)

noeq type agile_transcript_ = {
  tx_sha256: option (Transcript.state HD.SHA2_256);
  tx_sha384: option (Transcript.state HD.SHA2_384);
}

let agile_transcript_defined (a:HD.alg) (t:agile_transcript_) = 
  match a with
  | HD.SHA2_256 -> Some? t.tx_sha256
  | HD.SHA2_384 -> Some? t.tx_sha384
  | _ -> false

type agile_transcript (a:HD.alg) =
  t:agile_transcript_{agile_transcript_defined a t}

let agile_transcript_inv #a (t:agile_transcript a) h =
  (Some? t.tx_sha256 ==> Transcript.invariant (Some?.v t.tx_sha256) h) /\
  (Some? t.tx_sha384 ==> Transcript.invariant (Some?.v t.tx_sha384) h)

let agile_transcript_base #a (t:agile_transcript a) : (Transcript.state a) =
  match a with
  | HD.SHA2_256 -> Some?.v t.tx_sha256
  | HD.SHA2_384 -> Some?.v t.tx_sha384

let agile_transcript_variant #a (t:agile_transcript a)
  (a':HD.alg{agile_transcript_defined a' t}) : (Transcript.state a') =
  match a' with
  | HD.SHA2_256 -> Some?.v t.tx_sha256
  | HD.SHA2_384 -> Some?.v t.tx_sha384

let agile_transcript_footprint #a (t:agile_transcript a) =
  let fp1 = if Some? t.tx_sha256 then Transcript.footprint (Some?.v t.tx_sha256) else B.loc_none in
  let fp2 = if Some? t.tx_sha384 then Transcript.footprint (Some?.v t.tx_sha384) else B.loc_none in
  B.loc_union fp1 fp2

let agile_transcript_frame
  #a
  (t: agile_transcript a)
  (l: B.loc)
  (h0 h1: HS.mem)
: Lemma
  (requires (
    agile_transcript_inv t h0 /\
    B.modifies l h0 h1 /\
    B.loc_disjoint l (agile_transcript_footprint t)
  ))
  (ensures (
    agile_transcript_inv t h1
  ))
= ()

// See TLS.Handshake.Machine for the definition of expected_initial_transcript
let agile_transcript_initial #a (t:agile_transcript a) re ch h =
  (Some? t.tx_sha256 ==>
    Transcript.transcript (Some?.v t.tx_sha256) h == expected_initial_transcript re ch) /\
  (Some? t.tx_sha384 ==>
    Transcript.transcript (Some?.v t.tx_sha384) h == expected_initial_transcript re ch)

#push-options "--fuel 1"
let agile_transcript_create (a:HD.alg{a==HD.SHA2_256 \/ a == HD.SHA2_384})
  (r:rgn) retry ch
  : ST (agile_transcript a)
  (requires fun h0 -> r `disjoint` Mem.tls_tables_region)
  (ensures fun h0 t h1 ->
    agile_transcript_inv t h1 /\
    agile_transcript_initial t retry ch h1 /\
    B.modifies (agile_transcript_footprint t) h0 h1 /\
    B.fresh_loc (Transcript.footprint (agile_transcript_base t)) h0 h1)
  =
  let t = transcript_start r a retry ch false in
  let x : agile_transcript_ = match a with
  | HD.SHA2_256 -> {tx_sha256 = Some t; tx_sha384 = None}
  | HD.SHA2_384 -> {tx_sha256 = None; tx_sha384 = Some t} in
  assert(agile_transcript_defined a x);
  x
#pop-options

 // FIXME(adl) disjointness + agile framing
#push-options "--admit_smt_queries true"
let agile_transcript_extend #a (t:agile_transcript a) a' retry ch
  : ST (agile_transcript a)
  (requires fun h0 -> agile_transcript_inv t h0)
  (ensures fun h0 t' h1 ->
    B.modifies (agile_transcript_footprint t') h0 h1 /\
    agile_transcript_inv t' h1 /\
    agile_transcript_initial t' retry ch h1 /\
    agile_transcript_defined a' t')
  =
  let t' = if agile_transcript_defined a' t then t
    else
      let r = Transcript.region_of (agile_transcript_base t) in
      let t' = transcript_start r a' retry ch false in
      match a' with
      | HD.SHA2_256 -> {t with tx_sha256 = Some t'}
      | HD.SHA2_384 -> {t with tx_sha384 = Some t'}
      in
  let h1 = get () in
  assume(agile_transcript_inv t' h1); t'
#pop-options

// Should free all the temporary non-base states
let agile_transcript_free #a (t:agile_transcript a)
  : ST (Transcript.state a)
  (requires fun h0 -> agile_transcript_inv t h0)
  (ensures fun h0 r h1 -> B.modifies B.loc_none h0 h1 /\
    Transcript.invariant r h1)
  =
  agile_transcript_base t


/// Compute binder MACs for the PSKs; in rare cases we allocate an
/// auxiliary transcripts for other hash algorithms.
///
/// We pass the (full, truncated) offer, or its repr, in order to
/// specify/recompute what is MACed.

// TODO type; tch & logical payload; prove by induction that the
// resulting binders have the right length, reusing ParsersAux
// ADL: extended to work on the second client hello - taking offer
// as input instead of full_offer to avoid re-hashing CH0
// I assume that only the compatible PSKs are offered the second time
// such that one CH digest is enough
val client_Binders:
  region:rgn ->
  ha0: HD.alg ->
  di: agile_transcript ha0 ->
  retry: option Transcript.retry ->
  tch: Msg.ch { Msg.ch_bound tch} ->
  bkey: list KS.binder_key ->
  ST Parsers.OfferedPsks_binders.(b:list Parsers.PskBinderEntry.pskBinderEntry {offeredPsks_binders_list_bytesize b = binder_key_list_bytesize bkey})
  (requires fun h0 ->
    agile_transcript_inv di h0 /\
    agile_transcript_initial di retry tch h0)
  (ensures fun h0 b h1 ->
    B.modifies (agile_transcript_footprint di) h0 h1 /\
    agile_transcript_inv di h1)

#push-options "--z3rlimit 16 --max_fuel 1 --initial_fuel 1 --max_ifuel 1 --initial_ifuel 1"

let rec client_Binders region ha0 di0 retry tch bkeys =
  match bkeys with
  | [] ->
    []
  | ik :: bkeys ->
    let (| i, k |) = ik in
    let h0 = get () in
    let ha = binderId_hash i in
    let di' = agile_transcript_extend di0 ha retry tch in
    let tag = transcript_extract (agile_transcript_variant di' ha) in
    let binder = HMAC.mac k tag in
    let h2 = get () in
    assume (agile_transcript_inv di' h2);
    assume (agile_transcript_initial di' retry tch h2);
    let res =
      binder :: client_Binders region ha0 di' retry tch bkeys
    in
    let h3 = get () in
    assume (B.modifies (agile_transcript_footprint di0) h0 h3);
    assume (agile_transcript_inv di0 h3);
    res

#pop-options

// TODO also return a slice in the sending buffer containing the
// serialized [ch]; it is not constant yet as we may need to patch the
// binders.

#push-options "--admit_smt_queries true" 
let client_ClientHello hs =
  let Client region config r = hs in 
  let (cfg,resume) = config in
  let C_init random = !r in
  let groups =
    match cfg.max_version with
    | TLS_1p3 -> trace "offering ClientHello 1.3" LowStar.Printf.done; Some cfg.offer_shares
    | _       -> trace "offering ClientHello 1.2" LowStar.Printf.done; None in
    // groups = None indicates a 1.2 handshake
    // groups = Some [] is valid, may be used to deliberately trigger HRR
  let ks, shares = KS.ks_client_init random cfg.is_quic groups in

  match Negotiation.client_ClientHello config random shares with
  | Error z -> 
    let h2 = get() in
    assume(invariant hs h2);
    Error z
  | Correct offer0 ->

  // provable? the extraction of [now] in [offered0] seems too strict
  assume(offered0 config offer0); 
  
  assume( // TODO in Negotiation.client_ClientHello
    Msg.ch_bound offer0 ==>
       Parsers.OfferedPsks.offeredPsks_binders_list_bytesize (Msg.ch_binders offer0) 
    == bkey_list_bytesize (snd resume));
    
  let ha = Negotiation.offered_ha offer0 in
  let di0 = agile_transcript_create ha region None offer0 in

  let ms = create_msg_state region ParseFlights.F_c_wait_ServerHello random ha
    (Some (agile_transcript_base di0)) None in
  let h = get() in
  
  assert(Send.invariant ms.sending h);
  assert(agile_transcript_initial di0 None offer0 h);
  
  match Send.send_tch ms.sending offer0 with
  | Error z -> 
    let h2 = get() in
    assume(invariant hs h2);
    Error z
  | Correct (sending, ptch) -> (

  // This is specification-only, ensuring that offer0 has the
  // canonical binders used to keep track of the tch transcript,
  // instead of the dummy binders produced by Negotation from ha
  // information. (Not great--to revisit when lowering Nego.) This
  // does not affect the concrete, truncated representation of the
  // message.
  let offer0 = Msg.clear_binders offer0 in
  let full0 = {full_retry = None; full_ch = offer0} in
  
  // Compute the binders
  let ks', offer1, sending = (
    match resume with
    | (_,[]) -> ks, offer0, sending
    | (_,psks) -> (
      // Both derives the binder keys and stores the associated early secrets
      let ks', binder_keys = KS.ks_client13_get_binder_keys ks psks in
      let binders = client_Binders region ha di0 None offer0 binder_keys in
      let offer1 = Msg.set_binders offer0 binders in
      Send.patch_binders ms.digest sending ptch binders;
      // FIXME!! this should be internal to patch_binders
      let (| _, chr |) = get_handshake_repr (Msg.M_client_hello offer1) in
      let lbl = Transcript.LR_CompleteTCH chr in
      Transcript.extend ms.digest lbl;

      // Set up 0RTT keys if offered
      let sending =
        if Negotiation.find_early_data offer0 then (
          trace "setting up 0RTT" LowStar.Printf.done;
          let digest_CH = transcript_extract ms.digest in
          // TODO LATER consider doing export & register within KS
          let early_exporter_secret, edk = KS.ks_client13_ch ks' digest_CH in
          export ms.epochs early_exporter_secret;
          register ms.epochs edk;
          Send.signals sending (Some (true, false)) false )
        else sending in
      ks', offer1, sending )) in

  // Go back to non-agile transcript
  let di0 = agile_transcript_free di0 in
  r := C_wait_ServerHello full0 ms ks;
  let ms = {ms with sending = sending} in

  // In both cases, the transcript is now at [ClientHello None offer1]
  let h1 = get() in
  let full1 = {full_retry=None; full_ch=offer1} in
  assert (Transcript.invariant ms.digest h1);

  r := C_wait_ServerHello full1 ms ks';
  let h2 = get() in
  assume(invariant hs h2);
  Correct () )
#pop-options

#push-options "--admit_smt_queries true" 
let client_HelloRetryRequest hs hrr =
  let Client region config r = hs in
  let C_wait_ServerHello offer ms ks = !r in
  let open Parsers.HelloRetryRequest in
  // JP: this is not Low* as it gc-allocates a string... should be fixed by defining Nego.print_hrres!
  trace "HelloRetryRequest with extensions %s" (Nego.string_of_hrres (Msg.hrr_extensions hrr)) LowStar.Printf.done;

  // We may need to change our mind about the hash
  let ch0 = offer.full_ch in
  let ha0 = Negotiation.offered_ha ch0 in
  let ha1 = Msg.hrr_ha hrr in
  let di0 : Transcript.state ha1 =
    if ha1 = ha0 then ms.digest
    else (* free ms.digest; *) transcript_start region ha1 None ch0 true in

  // We will restart the concrete transcript using the hashed ch0
  let tag0 = transcript_extract di0 in
  let retry = Some (Msg.M_message_hash tag0, hrr) in

  let share, ks =
    match TLS.Cookie.find_keyshare hrr with
    | None ->
      // this case should only ever happen in QUIC stateless retry address validation
      // FIXME(adl) deprecated in current QUIC with transport retry
      // is this still used for other purposes? Spec does not explicitly forbid it
      trace "Server did not specify a group in HRR, re-using the previous choice" LowStar.Printf.done;
      None, ks
    | Some ng ->
      match CommonDH.group_of_namedGroup ng with
      | None -> admit() //TODO handle group decoding error
      | Some g -> (
        let s, ks = KS.ks_client13_hello_retry ks g in
        Some (| g, s |), ks )
  in
  let h0 = get() in assume(Send.invariant ms.sending h0); //TODO framing
  let now = UInt32.uint_to_t (FStar.Date.secondsFromDawn()) in
  
  // N.B. this will filter out all PSKs that do not use ha1
  match Nego.client_HelloRetryRequest ch0 hrr share now (snd config) with
  | Error z -> Receive.InError z
  | Correct ch1 ->

  // The rest of the code is similar to client_ClientHello's, might
  // even be shared.
  assume(Negotiation.offered_ha ch1 == Msg.hrr_ha hrr);
  assume( // TODO in Negotiation.client_ClientHello
    Msg.ch_bound ch1 ==>
    Parsers.OfferedPsks.offeredPsks_binders_list_bytesize (Msg.ch_binders ch1) ==
    bkey_list_bytesize (snd (snd config)));
  // TODO prove Nego.offered_hash ch1 == ha1

  match Send.send_tch ms.sending ch1 with
  | Error z -> Receive.InError z
  | Correct (sending, ptch) ->

  (* N.B. all of this should be erased *)
  let offer1 = Msg.clear_binders ch1 in
  let full_retry = Some({ch0=ch0; sh0 = hrr}) in
  let retry = Some (hash_ch0 region ha1 ch0, hrr) in
  let full1 = {full_retry=full_retry; full_ch=offer1} in

  // FIXME free old digest - we are restarting with retry
  assume False; //19-09-14 TBC after fixing client_transcript
  let di1 = agile_transcript_create ha1 region retry ch1 in
  let ms = {ms with digest = agile_transcript_base di1} in
  r := C_wait_ServerHello full1 ms ks;

  let cfg, resume = config in
  let offer2, sending = (
    // TODO RFC recheck we send binders for the initial bkeys
    // ADL: no, we should filter out PSKs that don't match with HRR's ha
    match resume with
    | (_,[]) -> offer1, sending
    | (_,psks) -> (
      let ks', binder_keys = KS.ks_client13_get_binder_keys ks psks in
      let binders = client_Binders region ha1 di1 retry ch1 binder_keys in
      let offer = Msg.set_binders offer1 binders in
      Send.patch_binders ms.digest ms.sending ptch binders;
      // FIXME!! this should be internal to patch_binders
      let (| _, chr |) = get_handshake_repr (Msg.M_client_hello offer) in
      let lbl = Transcript.LR_CompleteTCH chr in
      Transcript.extend ms.digest lbl;

      // Set up 0RTT keys if offered ---- is it enabled after HRR?
      let sending =
        if Negotiation.find_early_data offer then (
          trace "setting up 0RTT" LowStar.Printf.done;
          let digest_CH = transcript_extract (agile_transcript_base di1) in
          // TODO LATER consider doing export & register within KS
          let early_exporter_secret, edk = KS.ks_client13_ch ks digest_CH in
          export ms.epochs early_exporter_secret;
          register ms.epochs edk;
          Send.signals sending (Some (true, false)) false )
        else sending in
      offer, sending )) in

  let full2 = ({full_retry=full_retry; full_ch=offer2}) in

  r := C_wait_ServerHello full2 ms ks;
  Receive.InAck false false
#pop-options 

(*
let client_HelloRetryRequest (Client region config r) hrr =
  trace "client_HelloRetryRequest";
  let C_wait_ServerHello offer ms ks = !r in
  let share, ks =
    match Negotiation.group_of_hrr hrr with
    | None ->
      // this case should only ever happen in QUIC stateless retry address validation
      // FIXME(adl) deprecated in current QUIC with transport retry
      trace "Server did not specify a group in HRR, re-using the previous choice"; None, ks
    | Some ng ->
        let Some g = CommonDH.group_of_namedGroup ng in
        let s, ks = KS.ks_client13_hello_retry ks g in
        Some (| g, s |), ks
    in
  match Negotiation.client_HelloRetryRequest offer.full_ch hrr share with
  | Error z -> Receive.InError z
  | Correct offer2 -> (

    // // Note: we stay in Wait_ServerHello
    // // Only the Nego state machine was moved by HRR
    Receive.InAck false false )
*)

#push-options "--admit_smt_queries true" 
//#push-options "--max_ifuel 3 --z3rlimit 32"
let client_ServerHello (Client region config r) sh =
  push_frame ();
  trace "client_ServerHello" LowStar.Printf.done;
  let cfg,_ = config in
  let C_wait_ServerHello offer ms ks = !r in
  let r = match Negotiation.client_accept_ServerHello cfg offer.full_ch sh with
  | Error z -> Receive.InError z
  | Correct (cs,pski) -> (
    //assert (Correct? (Negotiation.selected_version sh));
    match cs with
    | CipherSuite13 ae ha -> (
      trace "Running TLS 1.3" LowStar.Printf.done;
      
      let ms = // we need to restart digest if server changes hash (ignoring binders)
        if ha = Nego.offered_ha offer.full_ch then ms
	else
	  // N.B. this can only happen if retry = None
	  let di = transcript_start region ha None offer.full_ch true in
	  trace ("Server changed hash") LowStar.Printf.done;
	  {ms with digest = di} in

      let server_share = Negotiation.find_serverKeyShare sh in
      let (| _, shr |) = get_handshake_repr (Msg.M_server_hello sh) in
      let label = Transcript.LR_ServerHello shr in
      Transcript.extend ms.digest label;

      //assert(transcript_sh == transcript13 offer sh []);
      let digest_ServerHello = transcript_extract ms.digest in
      let ks, hs_keys = KS.ks_client13_sh region ks
        (Msg.sh_random sh)
        (CipherSuite13 ae ha)
        digest_ServerHello
        server_share
        pski in
      register ms.epochs hs_keys; // register new epoch
      if Negotiation.find_early_data offer.full_ch then (
        // Skip the 0-RTT epoch on the reading side
        Epochs.incr_reader ms.epochs;
        match pski with
        | None ->
          trace "0-RTT rejected early (no PSK was selected)" LowStar.Printf.done;
          Epochs.incr_writer ms.epochs
        | Some _ ->
          trace "0RTT potentially accepted (wait for EE to confirm)" LowStar.Printf.done;
          // No EOED in QUIC, so we immediately enable HSK
          if cfg.is_quic then Epochs.incr_writer ms.epochs )
      else // No EOED to send in 0-RTT epoch
        Epochs.incr_writer ms.epochs; // Next flight (CFin) will use HSK

      Epochs.incr_reader ms.epochs; // Client 1.3 HSK switch to handshake key for decrypting EE etc...
      // assume(
      //   selected_ha sh == offered_ha offer.full_ch /\
      //   PF.length_parsed_bytes ms.receiving.Receive.pf_st == 0
      //   );
      // let ms: msg_state region PF.F_c_wait_ServerHello (offer.full_ch.Msg.random) (selected_ha sh) = ms in
      // let ms: msg_state region PF.F_c13_wait_Finished1 (offer.full_ch.Msg.random) (selected_ha sh) = {ms with receiving = ms.receiving } in
      let ms = { ms with receiving = ms.receiving } in
      r := C13_wait_Finished1 offer sh ms ks;
      Receive.InAck true false // Client 1.3 HSK
    )
    | CipherSuite kex sa ae -> (
      trace "Running classic TLS" LowStar.Printf.done;
      trace "Offered SID=%a Server SID=%a" TLS.Tracing.print_bytes offer.full_ch.CH.session_id
        TLS.Tracing.print_bytes (Msg.sh_session_id sh) LowStar.Printf.done;
      Receive.InError (fatalAlert Handshake_failure, "TLS 1.2 TBC")
      // if Negotiation.resume_12 mode then
      // begin // 1.2 resumption
      //   trace "Server accepted our 1.2 ticket.";
      //   let Some (tid, Ticket.Ticket12 pv cs ems msId ms) = fst (Negotiation.resume s.nego) in
      //   let pv' = mode.Negotiation.n_protocol_version in
      //   let cs' = mode.Negotiation.n_cipher_suite in
      //   let sr = mode.Negotiation.n_server_random in
      //   let nst = Negotiation.sendticket_12 mode in
      //   if pv = pv' && cs = cs' then // TODO check full session
      //   begin
      //     let adk = KS.ks_client12_resume s.ks sr pv cs ems msId ms in
      //     let digestSH = HSL.hash_tag #ha s.log in
      //     register s adk;
      //     s.state := (if nst then C_wait_NST true else C_wait_CCS (true, digestSH));
      //     InAck false false
      //   end
      //   else
      //     InError (fatalAlert Handshake_failure, "inconsistent protocol version or ciphersuite during resumption")
      // end
      // else
      // begin // 1.2 full handshake
      //   s.state := C_wait_ServerHelloDone;
      //   InAck false false
      // end
      ))
  in pop_frame (); r
#pop-options
// let client_ServerHello_HRR s ch1 hri sh =
//   trace "client_ServerHello";
//   match Nego.check_retry ch1 hri sh with
//   | Error z -> InError z
//   | Correct () ->
//     client_ServerHello s sh

(*** TLS 1.3 ***)

#push-options "--z3rlimit 200 --max_fuel 1"
let client13_Finished2 (Client region config r) =
  let C13_complete offer sh ee server_id fin1 ms (Finished_pending cfk ks sent_eoed) = !r in
  let ha = Negotiation.selected_ha sh in

  // LATER: support certificate-based client authentication
  // let digest =
  //   match ocr with
  //   | Some cr ->
  //     let open Parsers.Certificate13 in
  //     let c = ({certificate_request_context = Bytes.empty_bytes; certificate_list = []}) in
  //     HandshakeLog.send_tag #ha hs.log (HSL.Msg13 (Msg.M13_certificate c))
  //   | None -> digestServerFinished in

  let h = get() in
  assume(Transcript.invariant ms.digest h);
  let digest_Finished1 = transcript_extract ms.digest in

  assume False; // missing too many stateful invariants

  // to be updated, possibly using btag as output buffer.
  let cvd = HMAC.mac (dsnd cfk) digest_Finished1 in
  let fin2 = Ghost.hide #Msg.finished cvd in

  match Send.send_extract13 ms.digest ms.sending (Msg.M13_finished cvd) with
  | Error z -> Error z
  | Correct (sending, digest_Finished2) ->
  let ks = KS.ks_client13_cf ks digest_Finished2 in // post-handshake keying
  Epochs.incr_reader ms.epochs; // to ATK
  let sending = Send.signals sending (Some (true, false)) true in

  let ms = { ms with sending = sending } in
  // updating [ms.sending fin2 ks]
  r := C13_complete offer sh ee server_id fin1 ms (Finished_sent fin2 ks);
  Correct ()
#pop-options


#push-options "--max_ifuel 1"
let client13_nego_cb cfg ee =
  trace "Received encrypted extensions %s" (Negotiation.string_of_ees ee) LowStar.Printf.done;
  trace "Negotiation callback to process application extensions." LowStar.Printf.done;
  let uexts = List.Tot.filter Parsers.EncryptedExtension.EE_Unknown_extensionType? ee in
  // the length check below could be statically excluded from the definition of filtering
  if not (Parsers.EncryptedExtensions.check_encryptedExtensions_list_bytesize uexts)
  then
    fatal Internal_error "encrypted extensions are too large"
  else
  let uexts_bytes = Parsers.EncryptedExtensions.encryptedExtensions_serializer32 uexts in
  // to be simplified (see TLS.Callbacks)
  let cb = cfg.nego_callback in
  let open TLS.Callbacks in
  match cb.negotiate cb.nego_context TLS_1p3 uexts_bytes None with
  | Nego_abort    -> fatal Handshake_failure "application requested to abort the handshake"
  | Nego_retry _  -> fatal Internal_error "client application requested a server retry"
  | Nego_accept _ -> Correct ()
#pop-options

// annoying differently refined bytes, to be reviewed
type cert_repr = Parsers.ASN1Cert.aSN1Cert // aka b:bytes {length b < 16777216} but with another syntax
private let coerce_asncert (x:Parsers.ASN1Cert.aSN1Cert): cert_repr = x
private let coerce_crt crt = List.Tot.map coerce_asncert crt

// it may be more convenient to pass the whole ms with its invarian
// ADL(march 16 2020): verification regressed since oct 2019,
// turning off for merge to dev
#push-options "--admit_smt_queries true"
let client13_c_cv #ha sending (digest: Transcript.state ha) cfg offer
  (c: Parsers.Handshake13_m13_certificate.handshake13_m13_certificate)
  (cv: Msg.certificateVerify13) :
  ST (result unit)
  (requires fun h0 ->
    let t = Transcript.transcript digest h0 in
    Send.invariant sending h0 /\
    Transcript.extensible t /\
    Transcript.invariant digest h0 /\
    B.loc_disjoint (Transcript.footprint digest) (TLS.Handshake.Send.footprint sending) /\
    Transcript.Transcript13? t)
  (ensures fun h0 r h1 ->
    True)
  =
  match extend13 sending digest (Msg.M13_certificate c) with
  | Error z -> Error z
  | Correct () ->
  let digest_signed = transcript_extract digest in
  let h = get () in
  assume(Transcript.extensible (Transcript.transcript digest h));
  
  match extend13 sending digest (Msg.M13_certificate_verify cv) with
  | Error z -> Error z
  | Correct () ->
  // TODO ensure that valid_offer mandates signature extensions for 1.3
  let sal = match Negotiation.find_signature_algorithms offer with
  | Some sal -> sal
  | None -> [] in
    let sa = cv.Msg.algorithm in
    let chain = Some (c, sa) in
    if not (List.Tot.mem sa sal)
    then
      fatal Bad_certificate "The server signed with an algorithm we did not offer"
    else
      let tbs = Negotiation.to_be_signed TLS_1p3 TLSConstants.Server None digest_signed in
      let chain = coerce_crt (Cert.chain_down c.Msg.certificate_list) in
      if not (TLS.Callbacks.cert_verify_cb cfg.cert_callbacks chain sa tbs cv.Msg.signature)
      then (
        trace("Certificate & signature 1.3 callback failed") LowStar.Printf.done;
        fatal Bad_certificate "Failed to validate signature or certificate" )
      else (
        trace("Certificate & signature 1.3 callback succeeded") LowStar.Printf.done;
        Correct () )

// #push-options "--max_ifuel 2 --max_fuel 2 --z3rlimit 32"
#push-options "--admit_smt_queries true" // TODO prove invariant in postcondition
let client13_Finished1 hs ee client_cert_request server_cert_certverify finished
=
  let Client region (cfg,_) r = hs in
  match client13_nego_cb cfg ee with
  | Error z -> Receive.InError z
  | Correct _ ->
  match client_cert_request with
  | Some _ -> Receive.InError (fatalAlert Handshake_failure,"unsupported client certificate request")
  | None ->

  let C13_wait_Finished1 offer sh ms ks = !r in
  let ha = Negotiation.selected_ha sh in
  let hlen = Hacl.Hash.Definitions.hash_len ha in
  let btag: Hacl.Hash.Definitions.hash_t ha =
    B.sub (B.alloca 0uy 64ul) 0ul hlen in // allocated large enough for any digest
  let h0 = get() in assume(invariant hs h0);//TODO frame a few calls above
  match extend13 ms.sending ms.digest (Msg.M13_encrypted_extensions ee) with
  | Error z -> Receive.InError z
  | Correct () ->
  let psk_based = Some? (Negotiation.find_serverPske sh) in
  let verified_server =
    match server_cert_certverify with
    | None ->
        if not psk_based then
          fatal Handshake_failure "missing certificate chain and sigature"
        else
          // relying on a previously received & verified server
          // certificate chain & signature recorded for this PSK; TODO
          // confirm this context is available to the application.
          Correct ()

    | Some (c,cv) ->
        if psk_based then
          fatal Handshake_failure "unexpected certificate chain and signature"
        else
          client13_c_cv #ha ms.sending ms.digest cfg offer.full_ch c cv
  in
  match verified_server with
  | Error z -> Receive.InError z
  | Correct transcript_maced -> (
    // let oc =
    // let open Parsers.Certificate13 in
    // match oc with | None -> None | Some c -> Some c.certificate_list in
    // let cfg = Negotiation.local_config hs.nego in
    // match Negotiation.clientComplete_13 hs.nego ee ocr oc ocv digestCert with

  let digest_maced = transcript_extract ms.digest in
  match extend13 ms.sending ms.digest (Msg.M13_finished finished) with
  | Error z -> Receive.InError z
  | Correct () -> (
  let digest_Finished1 = transcript_extract ms.digest in
  let ks, (sfin_key, cfin_key, app_keys, exporter_master_secret) =
    KS.ks_client13_sf ks digest_Finished1 in
  // ADL: 4th returned value is the exporter master secret.
  // should be passed to application somehow --- store in Nego? We need agreement.

  if not (HMAC.verify (dsnd sfin_key) digest_maced finished)
  then
    Receive.InError (fatalAlert Decode_error, "Finished MAC did not verify: expected digest "^Bytes.print_bytes digest_maced)
  else (
    export ms.epochs exporter_master_secret;
    register ms.epochs app_keys; // ATKs are ready to use in both directions

    let send_eoed = Negotiation.zeroRTT sh && not cfg.is_quic in
    if send_eoed then ( // EOED emitting (not used for QUIC)
      trace "Early data accepted; emitting EOED." LowStar.Printf.done;
      match Send.send13 #ha ms.digest ms.sending (Msg.M13_end_of_early_data ()) with
      | Correct sending -> (
        let sending = Send.signals sending (Some (false, false)) false in
        let fin1 = Ghost.hide Bytes.empty_bytes in
        r := C13_complete offer sh ee server_cert_certverify fin1 ms
	  (Finished_pending cfin_key ks true);
        Receive.InAck false false )
      | Error z -> Receive.InError z )
    else (
      (if Negotiation.zeroRTT sh
      then trace "Early data accepted (QUIC, no EOED)." LowStar.Printf.done
      else trace "Early data rejected" LowStar.Printf.done);
      let fin1 = Ghost.hide Bytes.empty_bytes in
      r := C13_complete offer sh ee server_cert_certverify fin1 ms
	  (Finished_pending cfin_key ks false);
      match client13_Finished2 hs with
      | Error z   -> Receive.InError z
      | Correct _ -> Receive.InAck true false // Client 1.3 ATK; next the client will read again to send Finished, writer++, and the Complete signal
      ))))
#pop-options

let client13_NewSessionTicket (Client region config r) st13 =
  let open TLS.Callbacks in
  let open Parsers.NewSessionTicket13 in
  let open Parsers.NewSessionTicketExtension in
  let tid = st13.ticket in
  let nonce = st13.ticket_nonce in
  let age_add = st13.ticket_age_add in
  trace "Received ticket: %a nonce: %a" TLS.Tracing.print_bytes tid TLS.Tracing.print_bytes nonce LowStar.Printf.done;
  assume False; // FIXME some pre-conditions need updating

  let C13_complete offer sh ee server_id _fin1 _ms (Finished_sent _fin2 ks) = !r in
  let cs = Msg.sh_cipher_suite sh in
  let Some cs = CipherSuite.cipherSuite_of_name cs in // add static refinement?
  assume(CipherSuite13? cs); // TODO machine invariant 
  
  let ed = List.Tot.find NSTE_early_data? st13.extensions in
  let now = UInt32.uint_to_t (FStar.Date.secondsFromDawn()) in
  let info = TicketInfo_13 TLS.Callbacks.({
    ticket_nonce = Some nonce;
    time_created = now;
    ticket_age_add = age_add;
    allow_early_data = Some? ed;
    allow_dhe_resumption = true;
    allow_psk_resumption = true;
    early_cs = cs;
    identities = (Bytes.empty_bytes, Bytes.empty_bytes); // TODO certs
  }) in

  let psk = KS.ks_client13_rms_psk ks nonce in
  let snio = Bytes.iutf8_opt (Negotiation.get_sni offer.full_ch) in
  assume(Some? snio); // TODO machine invariant? 
  let Some sni = snio in 

  let cfg = fst config in
  let valid_ed =
    if cfg.is_quic then
      (match ed with
      | None -> true
      | Some (NSTE_early_data x) -> x = 0xfffffffful
      | _ -> false)
    else true in
  if valid_ed then
    (let tcb = cfg.ticket_callback in
    tcb.new_ticket tcb.ticket_context sni tid info psk;
    Receive.InAck false false)
  else
    Receive.InError (fatalAlert Illegal_parameter, "QUIC tickets must allow 0xFFFFFFFF bytes of early data")

let early_rejected (Client region config r) =
  match !r with
  | C13_wait_Finished1 offer sh _ _
  | C13_complete offer sh _ _ _ _ _ ->
    Negotiation.find_early_data offer.full_ch &&
    not (List.Tot.existsb Parsers.ServerHelloExtension.SHE_early_data? (Msg.sh_extensions sh))
  | _ -> false

(*** TLS 1.2 ***)

private let convert_kex = function
  | Kex_RSA -> Correct Msg.Rsa
  | Kex_DHE -> Correct Msg.Dhe
  | Kex_ECDHE -> Correct Msg.Ecdhe
  | _ -> fatal Internal_error "Incorrect key exchange selected for 1.2"

let client12_ServerHelloDone hs c ske_bytes ocr =
  trace "processing ...ServerHelloDone" LowStar.Printf.done;
  Receive.InError (fatalAlert Internal_error, "TBC")
  // let kex = Negotiation.kexAlg (Negotiation.getMode hs.nego) in
  // match convert_kex kex with
  // | Error z -> InError z
  // | Correct kex ->
  // match Msg.serverKeyExchange_parser32 kex ske_bytes with
  // | None -> InError (fatalAlert Decode_error, "invalid client key exchange")
  // | Some (ske, _) ->
  // match Negotiation.client_ServerKeyExchange hs.nego c kex ske ocr with
  // | Error z -> InError z
  // | Correct mode -> (
  //   (match ocr with
  //   | None -> ()
  //   | Some cr ->
  //     trace "processing certificate request (TODO)";
  //     HSL.send hs.log (HSL.Msg12 (Msg.M12_certificate [])));
  //   let nst = Negotiation.sendticket_12 mode in
  //   let gy = Some?.v (mode.Negotiation.n_server_share) in // already set in KS
  //   let gx =
  //     KS.ks_client12_full_dh hs.ks
  //     mode.Negotiation.n_server_random
  //     mode.Negotiation.n_protocol_version
  //     mode.Negotiation.n_cipher_suite
  //     (Negotiation.emsFlag mode) // a flag controlling the use of ems
  //     gy in
  //   let (|g, _|) = gy in
  //   let gxb = CommonDH.serialize_raw gx in
  //   let open Parsers.ClientKeyExchange in
  //   let cke : clientKeyExchange kex =
  //     match kex with
  //     | Msg.Ecdhe -> Cke_ecdhe gxb
  //     | Msg.Dhe -> Cke_dhe gxb in
  //   let msg = Msg.M12_client_key_exchange (
  //     clientKeyExchange_serializer32 kex cke) in
  //   let ha = verifyDataHashAlg_of_ciphersuite (mode.Negotiation.n_cipher_suite) in
  //   let digestClientKeyExchange = HSL.send_tag #ha hs.log (HSL.Msg12 msg) in
  //   let cfin_key, app_keys = KS.ks_client12_set_session_hash hs.ks digestClientKeyExchange in
  //   register hs app_keys;
  //   // we send CCS then Finished;  we will use the new keys only after CCS
  //   let cvd = TLSPRF.finished12 ha cfin_key Client digestClientKeyExchange in
  //   let fin = Msg.M12_finished cvd in
  //   let digestClientFinished = HSL.send_CCS_tag #ha hs.log (HSL.Msg12 fin) false in
  //   hs.state := (
  //     if nst then
  //        C_wait_NST false
  //     else
  //       C_wait_CCS (false, digestClientFinished));
  //   InAck false false)

let client12_R_ServerFinished hs f digestNewSessionTicket digestServerFinished =
  trace "client_R_ServerFinished" LowStar.Printf.done;
  Receive.InError (fatalAlert Internal_error, "TBC")
  // let sfin_key = KS.ks12_finished_key hs.ks in
  // let mode = Negotiation.getMode hs.nego in
  // let ha = verifyDataHashAlg_of_ciphersuite mode.Negotiation.n_cipher_suite in
  // let expected_svd = TLSPRF.finished12 ha sfin_key Server digestNewSessionTicket in
  // if f = expected_svd
  // then (
  //   let cvd = TLSPRF.finished12 ha sfin_key Client digestServerFinished in
  //   let _ = HSL.send_CCS_tag #ha hs.log (HSL.Msg12 (Msg.M12_finished cvd)) true in
  //   hs.state := C_Complete; // ADL: TODO need a proper renego state Idle (Some (vd,svd)))};
  //   InAck false false // send_CCS_tag buffers the complete
  // )
  // else
  //   InError (fatalAlert Decode_error, "Finished MAC did not verify: expected digest "^Bytes.print_bytes digestNewSessionTicket)

let client12_ServerFinished hs f digestClientFinished =
  Receive.InError (fatalAlert Internal_error, "TBC")
  // let sfin_key = KS.ks12_finished_key hs.ks in
  // let mode = Negotiation.getMode hs.nego in
  // let ha = verifyDataHashAlg_of_ciphersuite mode.Negotiation.n_cipher_suite in
  // let expected_svd = TLSPRF.finished12 ha sfin_key Server digestClientFinished in
  // //let expected_svd = TLSPRF.verifyData (mode.Negotiation.n_protocol_version,mode.Negotiation.n_cipher_suite) sfin_key Server digestClientFinished in
  // if f = expected_svd
  // then (
  //   hs.state := C_Complete; // ADL: TODO need a proper renego state Idle (Some (vd,svd)))};
  //   InAck false true // Client 1.2 ATK
  //   )
  // else
  //   InError (fatalAlert Decode_error, "Finished MAC did not verify: expected digest "^Bytes.print_bytes digestClientFinished)

let client12_NewSessionTicket hs (resume:bool) (digest:Hashing.anyTag) (st: Msg.newSessionTicket12) =
  let open Parsers.NewSessionTicket12 in
  let open TLS.Callbacks in
  trace "Processing ticket: %a" TLS.Tracing.print_bytes st.ticket LowStar.Printf.done;
  Receive.InError (fatalAlert Internal_error, "TBC")
  // hs.state := C_wait_CCS (resume, digest);
  // let cfg = Negotiation.local_config hs.nego in
  // let tcb = cfg.ticket_callback in
  // let mode = Negotiation.getMode hs.nego in
  // let Some sni = Bytes.iutf8_opt (Negotiation.get_sni mode.Negotiation.n_offer) in

  // let (_msId, ms) = KS.ks12_ms hs.ks in
  // let info = TLS.Callbacks.TicketInfo_12 (
  //   mode.Negotiation.n_protocol_version,
  //   mode.Negotiation.n_cipher_suite,
  //   Negotiation.emsFlag mode) in

  // tcb.new_ticket tcb.ticket_context sni st.ticket info ms;
  // InAck false false
