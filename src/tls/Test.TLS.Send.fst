module Test.TLS.Send

module HS = FStar.HyperStack
module Nego = Negotiation
module HST = FStar.HyperStack.ST
module TS = TLS.Handshake.Send
module T = HSL.Transcript
module B = LowStar.Buffer

module HSM = Parsers.Handshake
module HSM12 = Parsers.Handshake12
module HSM13 = Parsers.Handshake13


open FStar.Integers
open FStar.HyperStack.ST
open CipherSuite
open TLSError

// TODO may require switching from Tot to Stack
assume val trace: string -> unit

noeq type handshake = | HS:
  #region: Mem.rgn {Mem.is_hs_rgn region} ->
  r: TLSConstants.role ->
  nego: Nego.t region r ->
  #a: EverCrypt.Hash.alg ->
  stt: TS.transcript_state a ->
  #n: Ghost.erased nat ->                 // Length of the current transcript
  t:T.g_transcript_n n ->                // Ghost transcript
  sto:TS.send_state ->
//  log: HandshakeLog.t {HandshakeLog.region_of log = region} ->
//  ks: KeySchedule.ks (*region*) ->
//  epochs: epochs region (Nego.nonce nego) ->
//  state: ref machineState {HS.frameOf state = region} -> // state machine; should be opaque and depend on r.
  handshake

let invariant (hs:handshake) (h:HS.mem) =
  TS.invariant hs.sto h /\
  T.invariant hs.stt (Ghost.reveal hs.t) h /\
  Nego.inv hs.nego h /\
  B.loc_disjoint (TS.footprint hs.sto) (T.footprint hs.stt) /\
  B.loc_disjoint (TS.footprint hs.sto) (Nego.footprint hs.nego) /\
  B.loc_disjoint (T.footprint hs.stt) (Nego.footprint hs.nego)

let footprint (hs:handshake) =
  TS.footprint hs.sto `B.loc_union`
  T.footprint hs.stt `B.loc_union` 
  Nego.footprint hs.nego

let is_state13 (hs:handshake) = T.Transcript13? (Ghost.reveal hs.t)

// TODO: Should be computed using key schedule
assume val svd:HSM13.handshake13_m13_finished
//TODO: Should be computed from nego + certificate13 parsers
assume val cert:HSM13.handshake13_m13_certificate
// TODO: Should be computed from nego. Requires lowering to take hash instead of bytes?
assume val signature:HSM13.handshake13_m13_certificate_verify

// TODO: should tag be allocated inside of a function? on the stack?

val serverFinished: hs:handshake -> tag:Hacl.Hash.Definitions.hash_t (hs.a) -> ST (result handshake)
    (requires fun h -> invariant hs h /\ B.live h tag /\ is_state13 hs /\
      Ghost.reveal hs.n < T.max_transcript_size - 4 /\
      B.loc_disjoint (B.loc_buffer tag) (B.loc_region_only true Mem.tls_tables_region) /\
      B.loc_disjoint (B.loc_buffer tag) (footprint hs))
    (ensures fun h0 res h1 -> 
      B.(modifies (footprint hs `loc_union` loc_buffer tag `loc_union` loc_region_only true Mem.tls_tables_region)) h0 h1 /\
      begin match res with
      | Correct hs' -> invariant hs' h1
      | _ -> True
      end
    )

#set-options "--z3rlimit 50"

let serverFinished hs tag =
    trace "prepare Server Finished";
    let mode = Nego.getMode hs.nego in
    let cfg = Nego.local_config hs.nego in
    let kex = Nego.kexAlg mode in
    let pv = mode.Nego.n_protocol_version in
    let cs = mode.Nego.n_cipher_suite in
    let exts = mode.Nego.n_server_extensions in
    let eexts = match mode.Nego.n_encrypted_extensions with | None -> [] | Some ee -> ee in

    let digestFinished : result handshake =
      match kex with
      | Kex_ECDHE -> // [Certificate; CertificateVerify]
        let m = HSM13.M13_encrypted_extensions eexts in
        begin
        match TS.send13 hs.stt hs.t hs.sto m with
        | Correct (sto, t') ->
          // TODO: let cert = let Some (chain, _) = mode.n_server_cert in { certificate_list = chain; certificate_request_context = empty_bytes } in
          let m = HSM13.M13_certificate cert in // AF suggests to have this whole message already as part of mode, instead of just chain
          begin
          match TS.send_tag13 hs.stt t' sto m tag with
          | Correct (sto, t') ->
            begin
            // TODO: let tbs = Nego.to_be_signed pv ... tag in let signature = Nego.sign hs.nego tbs in
            match TS.send_tag13 hs.stt t' sto (HSM13.M13_certificate_verify signature) tag with
            | Correct (sto, t') -> Correct (HS hs.r hs.nego hs.stt t' sto)
            | Error z -> Error z
            end
          | Error z -> Error z
          end
        | Error z -> Error z
        end
      | _ -> // PSK
        let m = HSM13.M13_encrypted_extensions eexts in
        match TS.send_tag13 hs.stt hs.t hs.sto m tag with
        | Correct (sto, t') -> 
          let h1 = get() in
          Correct (HS hs.r hs.nego hs.stt t' sto)
        | Error z -> Error z
    in
    match digestFinished with
    | Correct hs' ->
      // TODO: let svd = let (| _, sfin_key |) = KS.ks_server_13_server_finished hs.ks in HMAC_UFCMA.mac sfin_key tag in
      let m = HSM13.M13_finished svd in
      begin
      match TS.send_tag13 hs'.stt hs'.t hs'.sto m tag with
      | Correct (sto, t') ->
        // TODO: export, register, send signals, nego state
        Correct (HS hs.r hs.nego hs.stt t' sto)
      | Error z -> Error z
      end
    | Error z -> Error z


val server_ClientHello: 
  #region: _ -> ns: Nego.t region TLSConstants.Server ->
  out: TS.send_state ->
  T.hs_ch -> 
  ST (result handshake)
  (requires fun h0 -> 
    Mem.is_hs_rgn region /\
    Nego.inv ns h0 /\
    TS.invariant out h0 /\
    B.loc_disjoint (TS.footprint out) (Nego.footprint ns) /\
    (let s = HS.sel h0 ns.Nego.state in Nego.S_Init? s)) // TODO:  \/ Nego.S_HRR? s
  (ensures fun h0 r h1 -> 
    B.modifies (Nego.footprint ns `B.loc_union` TS.footprint out `B.loc_union` B.loc_region_only true Mem.tls_tables_region) h0 h1 /\
    begin match r with
    | Correct hs ->
      invariant hs h1 /\
      hs.region == region /\
      hs.r == TLSConstants.Server /\
      hs.nego == ns /\
      T.ClientHello? (Ghost.reveal hs.t)
      // TODO: /\ hs.t == ...
    |  _ -> True
    end
    )
  // [S_Init | S_HRR ==> S_ClientHello m cert] 
  // ensures r = computeServerMode ns.cfg ns.nonce offer (stateful)
  // but [compute_cs13] and [negotiateCipherSuite] are pure. 

assume val computeServerMode: result Nego.serverMode

assume val find_cookie: Nego.offer -> option Extensions.cookie 

assume val serverMode_hashAlg: Nego.serverMode -> Tot Hashing.Spec.alg

(*
  cfg: TLSConstants.config ->
  co: TLSConstants.offer ->
  serverRandom: TLSInfo.random ->
  ST (result serverMode)
  (requires fun h0 -> True)
  (ensures fun h0 r h1 -> 
    B.(modifies loc_none h0 h1) /\ 
    ( match r with 
      | Correct (ServerRetry hrr) -> TLS.Cookie.hrr_len hrr <= 16 // leaving enough room for the cookie 
      | _ -> True )
    )
*)

#push-options "--z3rlimit 300 --max_ifuel 8 --initial_ifuel 8"

let server_ClientHello #region ns out offer =
// TODO: match !ns.Nego.state with  | Nego.S_HRR o1 hrr -> server_ClientHello2_stateful ns o1 hrr offer
//  | Nego.S_Init _ ->
    let sm = computeServerMode in // ns.Nego.cfg offer ns.Nego.nonce in
    match sm with
    | Error z -> Error z
    | Correct r ->
      let h = get() in
      // TRANSCRIPT:
      let tr = T.create region (serverMode_hashAlg r) in
      let stateless_retry = 
        match find_cookie (HSM.M_client_hello?._0 offer) with
        | None -> None 
        | Some c ->
          // stateless HRR.
          match TLS.Cookie.decrypt c with
          | Error _ -> 
            // This connection is doomed: we could instead return a fatal error. 
            None
            
          | Correct (digest, extra, hrr) ->
            // TODO check consistency of sm with hrr's cs and group;
            // this is required to enforce the earlier server policy.

            // Lowering: we can use the output buffer as scratch space
            // for outputting the digest (of known size) and the hrr
            // (possibly quite large), since we only need them for
            // computing the transcript digest.
            //
            // Alternatively, we could pass the hrr in two chunks: the
            // (small, reconstructed) hrr prefix, and the (received)
            // encrypted cookie.
            //
            // TRANSCRIPT 
            // extend_stateless hrr digest hrr //{ Start(None) --HRR digest hrr--> Start(Some(digest,hrr)) }
            // using sm's hash algorithm. 
            Some extra // to be passed to the server nego callback
        in 
        fatal Handshake_failure "negotiation failed after a retry"
      
(*

      // let tr = Transcript.create (ha_of_sm sm) in // { state(tr) == Start(None) }
      

      // TRANSCRIPT 
      // extend_ch offer //{ Start(r) --> ClientHello(r,offer) }
      let h = get() in assert (inv ns h);
      match r with 
      | ServerRetry hrr -> (
        if Some? stateless_retry then 
          fatal Handshake_failure "negotiation failed after a retry"
        else (
          // Internal HRR caused by group negotiation
          // We do not invoke the server nego callback in this case
          // record the initial offer and return the HRR to HS
          trace ("no common group, sending a retry request...");
          // TODO create Transcript in state Start(Some(digest,hrr)) to compute this digest
          let ha = TLS.Cookie.hrr_ha hrr in 
          let digest = HandshakeLog.hash_tag #ha log0 in 
          let hrr = TLS.Cookie.append digest empty_bytes hrr in
          ns.state := S_HRR offer hrr;
          sm ))

      | ServerMode m cert _ -> (
        let nego_cb = ns.cfg.nego_callback in
        let exts = List.Tot.filter CHE_Unknown_extensionType? offer.CH.extensions in
        // 19-06-16 recurring problem with list filtering; might disappear by lowering, or we could use the list serializer.
        assume(clientHelloExtensions_list_bytesize exts <= 65535);
        let exts_bytes = clientHelloExtensions_serializer32 exts in
        trace ("Negotiation callback to handle extra extensions and query for stateless retry.");
        trace ("Application data in cookie: "^(match stateless_retry with | Some c -> hex_of_bytes c | _ -> "none"));
        let r = nego_cb.negotiate nego_cb.nego_context m.n_protocol_version exts_bytes stateless_retry in
        let h = get() in assert (inv ns h);
        match r with 
        | Nego_abort -> (
          trace ("Application requested to abort the handshake.");
          fatal Handshake_failure "application requested to abort the handshake.")

        | Nego_retry filling -> (
          trace ("Application requested to retry the handshake.");
          assume(CipherSuite13? m.n_cipher_suite); // from ServerMode 
          let hrr = TLS.Cookie.hrr0 offer.CH.session_id m.n_cipher_suite in
          let ha = TLS.Cookie.hrr_ha hrr in 
          let digest = HandshakeLog.hash_tag #ha log0 in
          let hrr = TLS.Cookie.append digest filling hrr in
          ns.state := S_HRR offer hrr;
          Correct (ServerRetry hrr))
        
        | Nego_accept sexts -> (
          trace ("Application accepted "^
            string_of_pv m.n_protocol_version^" "^
            string_of_ciphersuite m.n_cipher_suite);
          ns.state := S_ClientHello m cert;
          Correct (ServerMode m cert sexts)))) in
  r
#pop-options
