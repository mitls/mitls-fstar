(* Copyright (C) 2012--2017 Microsoft Research and INRIA *)
(**
This modules defines TLS 1.3 Extensions.

- An AST, and it's associated parsing and formatting functions.
- Nego calls prepareExtensions : config -> list extensions.

@summary: TLS 1.3 Extensions.
*)
module Extensions

open FStar.Bytes
open FStar.Error

open TLSError
open TLSConstants
open Parse

#set-options "--initial_fuel 2 --max_fuel 2 --initial_ifuel 1 --max_ifuel 1 --z3rlimit 10"

//NS: hoisting a convenient function to avoid a closure conversion
let rec existsb2 (f: 'a -> 'b -> bool) (x:'a) (y:list 'b) : bool =
  match y with
  | [] -> false
  | hd::tl -> f x hd || existsb2 f x tl

(*************************************************
 Define extension.
 *************************************************)

//17-05-01 deprecated---use TLSError.result instead?
// SI: seems to be only used internally by parseServerName. Remove.
(** local, failed-to-parse exc. *)
private type canFail (a:Type) =
| ExFail of error 
| ExOK of list a

let error s = fatal Decode_error ("Extensions parsing: "^s)


(* PRE-SHARED KEYS AND KEY EXCHANGES *)

val pskiBytes: psk_identifier * PSK.obfuscated_ticket_age -> bytes

let pskiBytes (i,ot) =
  lemma_repr_bytes_values (UInt32.v ot);
  (vlbytes2 i @| bytes_of_int32 ot)

private
let pskiListBytes_aux acc pski = 
  let pb = pskiBytes pski in
  assume (UInt.fits (length acc + length pb) 32);
  acc @| pb

//val pskiListBytes: list pskIdentity -> bytes
let pskiListBytes ids =
  List.Tot.fold_left pskiListBytes_aux empty_bytes ids


let rec binderListBytes_aux (bl:list binder)
    : Tot (b:bytes{length b <= op_Multiply (List.Tot.length bl) 256}) =
    match bl with
    | [] -> empty_bytes
    | b::t ->
      let bt = binderListBytes_aux t in
      assert(length bt <= op_Multiply (List.Tot.length bl - 1) 256);
      let b0 = Parse.vlbytes1 b in
      assert(length b0 <= 256);
      let bt = binderListBytes_aux t in
      assume (UInt.fits (length b0 + length bt) 32);
      b0 @| bt

val binderListBytes: binders -> Pure bytes
  (requires True)
  (ensures fun b -> length b >= 33 /\ length b <= 65535)
let binderListBytes bs =
  match bs with
  | h::t ->
    let b = binderListBytes_aux t in
    let b0 = Parse.vlbytes1 h in
    assert(length b0 >= 33);
    assume (UInt.fits (length b0 + length b) 32);
    b0 @| b

let bindersBytes bs =
  let b = binderListBytes bs in
  Parse.vlbytes2 b

let rec parseBinderList_aux (b:bytes) (binders:list binder)
  : Tot (result (list binder)) (decreases (length b)) =
    if length b > 0 then
      if length b >= 5 then
        match vlsplit 1 b with
        | Error z -> error "parseBinderList failed to parse a binder"
        | Correct (x) ->
          let binder, bytes = x in
          if length binder < 32 then error "parseBinderList: binder too short"
            else (assume (length bytes < length b);
                  parseBinderList_aux bytes (binders @ [binder]))
      else error "parseBinderList: too few bytes"
    else Correct binders

let parseBinderList (b:bytes{2 <= length b}) : result binders =
  if length b < 2 then
    error "pskBinderList not enough bytes to read length header"
  else
    match vlparse 2 b with
    | Correct b ->
      begin
      match parseBinderList_aux b [] with
      | Correct bs ->
        let len = List.Tot.length bs in
        if 0 < len && len < 255 then
          Correct bs
        else
          error "none or too many binders"
      | Error z -> Error z
      end
    | Error z -> error "parseBinderList"

(** REMARK: we don't serialize the binders length; we do it when serializing Binders *)
val pskBytes: psk -> bytes
let pskBytes = function
  | ClientPSK ids len ->
    vlbytes2 (pskiListBytes ids)
  | ServerPSK sid ->
    lemma_repr_bytes_values (UInt16.v sid);
    bytes_of_int 2 (UInt16.v sid)

val parsePskIdentity: b:bytes -> result pskIdentity
let parsePskIdentity b =
  if length b < 2 then
    error "not enough bytes to parse the length of the identity field of PskIdentity"
  else
    match vlsplit 2 b with
    | Error z -> error "malformed PskIdentity"
    | Correct (x) ->
      let id, ota = x in
      if length ota = 4 then
        let ota = uint32_of_bytes ota in
        lemma_repr_bytes_values (length id);
        Correct (id, ota)
      else error "malformed PskIdentity"

#reset-options "--admit_smt_queries true"
let rec parsePskIdentities_aux : b:bytes -> list pskIdentity -> Tot (result (list pskIdentity)) (decreases (length b))
  = fun b psks ->
    if length b > 0 then
      if length b >= 2 then
        match vlsplit 2 b with
        | Error z -> error "parsePskIdentities failed to parse id"
        | Correct (x) ->
          let id, bytes = x in
          lemma_repr_bytes_values (length id);
          if length bytes >= 4 then
            let ot, bytes = split bytes 4ul in
            match parsePskIdentity (vlbytes2 id @| ot) with
            | Correct pski -> parsePskIdentities_aux bytes (psks @ [pski])
            | Error z -> Error z
          else error "parsePSKIdentities too few bytes"
      else error "parsePSKIdentities too few bytes"
    else Correct psks
#reset-options

val parsePskIdentities: b:bytes{length b >= 2} -> result (list pskIdentity)
let parsePskIdentities b =
  match vlparse 2 b with
  | Correct b ->
    if length b >= 7 then parsePskIdentities_aux b []
    else error "parsePskIdentities: too short"
  | Error z -> error "parsePskIdentities: failed to parse"

#reset-options "--admit_smt_queries true"
val client_psk_parse : bytes -> result (psk * option binders)
let client_psk_parse b =
  match vlsplit 2 b with
  | Error z -> error "client_psk_parse failed to parse"
  | Correct(ids,binders_bytes) -> (
    // SI: add ids header back.
    match parsePskIdentities (vlbytes2 ids) with
    | Correct ids -> (
    	match parseBinderList binders_bytes with
    	| Correct bl -> Correct (ClientPSK ids (length binders_bytes), Some bl)
    	| Error z -> error "client_psk_parse_binders")
    | Error z -> error "client_psk_parse_ids")
#reset-options

val server_psk_parse : lbytes 2 -> psk
let server_psk_parse b = ServerPSK (UInt16.uint_to_t (int_of_bytes b))

val parse_psk: ext_msg -> bytes -> result (psk * option binders)
let parse_psk mt b =
  match mt with
  | EM_ClientHello -> client_psk_parse b
  | EM_ServerHello ->
    if length b = 2 then Correct (server_psk_parse b, None)
    else error "Invalid format of server PSK"
  | _ -> error "PSK extension cannot appear in this message type"
#reset-options

// https://tlswg.github.io/tls13-spec/#rfc.section.4.2.8
// restricting both proposed PSKs and future ones sent by the server
// will also be used in the PSK table, and possibly in the configs

val psk_kex_bytes: psk_kex -> Tot (lbytes 1)
let psk_kex_bytes = function
  | PSK_KE -> abyte 0z
  | PSK_DHE_KE -> abyte 1z
let parse_psk_kex: pinverse_t psk_kex_bytes = fun b -> match b.[0ul] with
  | 0z -> Correct PSK_KE
  | 1z -> Correct PSK_DHE_KE
  | _ -> error  "psk_key"

let client_psk_kexes_bytes (ckxs: client_psk_kexes): b:bytes {length b <= 3} =
  let content: b:bytes {length b = 1 || length b = 2} =
    match ckxs with
    | [x] -> psk_kex_bytes x
    | [x;y] -> psk_kex_bytes x @| psk_kex_bytes y in
  lemma_repr_bytes_values (length content);
  vlbytes 1 content

let client_psk_kexes_length (l:client_psk_kexes): Lemma (List.Tot.length l < 3) = ()

#set-options "--admit_smt_queries true"

let parse_client_psk_kexes: pinverse_t client_psk_kexes_bytes = fun b ->
  if b = client_psk_kexes_bytes [PSK_KE] then Correct [PSK_KE] else
  if b = client_psk_kexes_bytes [PSK_DHE_KE] then Correct [PSK_DHE_KE] else
  if b = client_psk_kexes_bytes [PSK_KE; PSK_DHE_KE] then Correct [PSK_KE; PSK_DHE_KE]  else
  if b = client_psk_kexes_bytes [PSK_DHE_KE; PSK_KE] then Correct [PSK_DHE_KE; PSK_KE]
  else error "PSK KEX payload"
  // redundants lists yield an immediate decoding error.
#reset-options

(* EARLY DATA INDICATION *)

val earlyDataIndicationBytes: edi:earlyDataIndication -> Tot bytes
let earlyDataIndicationBytes = function
  | None -> empty_bytes // ClientHello, EncryptedExtensions
  | Some max_early_data_size -> // NewSessionTicket
    FStar.Bytes.bytes_of_int32 max_early_data_size // avoids overflow in QUIC

val parseEarlyDataIndication: bytes -> result earlyDataIndication
let parseEarlyDataIndication data =
  match length data with
  | 0 -> Correct None
  | 4 ->
      let n = int_of_bytes data in
      lemma_repr_bytes_values n;
      assert_norm (pow2 32 == 4294967296);
      Correct (Some (UInt32.uint_to_t n))
  | _ -> error "early data indication"

(* EC POINT FORMATS *)

let rec ecpfListBytes_aux: list point_format -> bytes = function
  | [] -> empty_bytes
  | ECP_UNCOMPRESSED :: r -> 
    let a = abyte 0z in 
    let b = ecpfListBytes_aux r in
    assume (UInt.fits (length a + length b) 32);
    a @| b
  | ECP_UNKNOWN t :: r -> 
    let a = bytes_of_int 1 t in
    let b = ecpfListBytes_aux r in
    assume (UInt.fits (length a + length b) 32);
    a @| b

val ecpfListBytes: l:list point_format{length (ecpfListBytes_aux l) < 256} -> Tot bytes
let ecpfListBytes l =
  let al = ecpfListBytes_aux l in
  lemma_repr_bytes_values (length al);
  let bl:bytes = vlbytes 1 al in
  bl

(* ALPN *)

let rec alpnBytes_aux: l:alpn -> Tot (b:bytes{length b <= op_Multiply 256 (List.Tot.length l)})
  = function
  | [] -> empty_bytes
  | protocol :: r ->
    lemma_repr_bytes_values (length protocol);
    vlbytes 1 protocol @| alpnBytes_aux r

let alpnBytes a =
  let r = alpnBytes_aux a in
  lemma_repr_bytes_values (length r);
  vlbytes 2 r

let rec parseAlpn_aux (al:alpn) (b:bytes) : Tot (result alpn) (decreases (length b)) =
  if length b = 0 then Correct(al)
  else
    if List.Tot.length al < 255 then
      match vlsplit 1 b with
      | Correct(x) ->
        let cur, r = x in
        if length cur > 0 then
          begin
          List.Tot.append_length al [cur];
          parseAlpn_aux (al @ [cur]) r
          end
        else
          error "illegal empty protocol name in ALPN extension"
      | Error z -> Error z
    else error "too many entries in protocol_name_list in ALPN extension"

let parseAlpn : pinverse_t alpnBytes = fun b ->
  if length b >= 2 then
    match vlparse 2 b with
    | Correct l -> parseAlpn_aux [] l
    | Error(z) -> Error z
  else error "parseAlpn: extension is too short"

let parse_uint16 (b:bytes) : result UInt16.t =
  if length b = 2 then
    Correct (uint16_of_bytes b)
  else error "invalid uint16 encoding"

let parse_uint32 (b:bytes) : result UInt32.t =
  if length b = 4 then Correct (uint32_of_bytes b)
  else error "invalid uint32 encoding"

(* PROTOCOL VERSIONS *)

#set-options "--admit_smt_queries true"
private let protocol_versions_bytes_aux acc v = acc @| TLSConstants.versionBytes v

val protocol_versions_bytes: protocol_versions -> b:bytes {length b <= 255}
let protocol_versions_bytes = function
  | ServerPV pv -> versionBytes pv
  | ClientPV vs ->  vlbytes 1 (List.Tot.fold_left protocol_versions_bytes_aux empty_bytes vs)
  // todo length bound; do we need an ad hoc variant of fold?
#reset-options

//17-05-01 added a refinement to control the list length; this function verifies.
//17-05-01 should we use generic code to parse such bounded lists?
//REMARK: This is not tail recursive, contrary to most of our parsing functions

#reset-options "--using_facts_from '* -LowParse.Spec.Base'"

val parseVersions:
  b:bytes ->
  Tot (result (l:list TLSConstants.protocolVersion' {FStar.Mul.( length b == 2 * List.Tot.length l)})) (decreases (length b))
let rec parseVersions b =
  match length b with
  | 0 -> let r = [] in assert_norm (List.Tot.length r == 0); Correct r
  | 1 -> error "malformed version list"
  | _ ->
    let b2, b' = split b 2ul in
    match TLSConstants.parseVersion b2 with
    | Error z -> Error z
    | Correct v ->
      match parseVersions b' with
      | Error z -> Error z
      | Correct vs -> (
          let r = v::vs in
          assert_norm (List.Tot.length (v::vs) == 1 + List.Tot.length vs);
          Correct r)

val parseSupportedVersions: b:bytes{2 <= length b /\ length b < 256} -> result protocol_versions
let parseSupportedVersions b =
  if length b = 2 then
    (match parseVersion b with
    | Error z -> Error z
    | Correct (Unknown_protocolVersion _) ->
      fatal Illegal_parameter "server selected a version we don't support"
    | Correct pv -> Correct (ServerPV pv))
  else
    (match vlparse 1 b with
    | Error z -> error "protocol versions"
    | Correct b ->
      begin
      match parseVersions b with
      | Error z -> Error z
      | Correct vs ->
        let n = List.Tot.length vs in
        if 1 <= n && n <= 127
        then Correct (ClientPV vs)
        else error "too many or too few protocol versions"
      end)

(* SERVER NAME INDICATION *)

#reset-options "--admit_smt_queries true"
private val serverNameBytes: list serverName -> Tot bytes
let rec serverNameBytes = function
  | [] -> empty_bytes
  | SNI_DNS x :: r -> abyte 0z @| bytes_of_int 2 (length x) @| x @| serverNameBytes r
  | SNI_UNKNOWN(t, x) :: r -> bytes_of_int 1 t @| bytes_of_int 2 (length x) @| x @| serverNameBytes r
#reset-options

private
let snidup: serverName -> serverName -> Tot bool
    = fun cur x ->
        match x,cur with
        | SNI_DNS _, SNI_DNS _ -> true
      	| SNI_UNKNOWN(a,_), SNI_UNKNOWN(b,_) -> a = b
      	| _ -> false

#reset-options "--admit_smt_queries true"
private let rec parseServerName_aux
  : b:bytes -> Tot (canFail serverName) (decreases (length b))
  = fun b ->
    if b = empty_bytes then ExOK []
    else if length b >= 3 then
      let ty,v = split b 1ul in
      begin
      match vlsplit 2 v with
      | Error(q) ->
          let x, y = q in
	      ExFail(x, "Failed to parse SNI length: "^ (FStar.Bytes.print_bytes b))
      | Correct(x) ->
        let cur, next = x in
      	begin
      	match parseServerName_aux next with
      	| ExFail(x,y) -> ExFail(x,y)
      	| ExOK l ->
      	  let cur =
      	    begin
      	    match ty.[0ul] with
      	    | 0z -> SNI_DNS(cur)
      	    | v  -> SNI_UNKNOWN(int_of_bytes ty, cur)
      	    end
      	  in
      	  if existsb2 snidup cur l then
      	    ExFail(fatalAlert Unrecognized_name, perror __SOURCE_FILE__ __LINE__ "Duplicate SNI type")
      	  else ExOK(cur :: l)
      	end
      end
    else ExFail(fatalAlert Decode_error, "Failed to parse SNI (list header)")

private val parseServerName: r:ext_msg -> b:bytes -> Tot (result (list serverName))
let parseServerName mt b =
  match mt with
  | EM_EncryptedExtensions
  | EM_ServerHello ->
    if length b = 0 then correct []
    else
    	let msg = "Failed to parse SNI list: should be empty in ServerHello, has size " ^ string_of_int (length b) in
    	error (perror __SOURCE_FILE__ __LINE__ msg)
  | EM_ClientHello ->
    if length b >= 2 then
    	begin
    	match vlparse 2 b with
    	| Error z -> error (perror __SOURCE_FILE__ __LINE__ "Failed to parse SNI list")
    	| Correct b ->
      	(match parseServerName_aux b with
      	| ExFail(x,y) -> Error(x,y)
      	| ExOK [] -> fatal Unrecognized_name (perror __SOURCE_FILE__ __LINE__ "Empty SNI extension")
      	| ExOK l -> correct l)
    	end
    else
      error (perror __SOURCE_FILE__ __LINE__ "Failed to parse SNI list")
  | _ -> error "SNI extension cannot appear in this message type"
#reset-options

let bindersLen (#p: (lbytes 2 -> GTot Type0)) (el: list (extension' p)) : nat =
  match List.Tot.find E_pre_shared_key? el with
  | Some (Extensions.E_pre_shared_key (ClientPSK _ len)) -> 2 + len
  | _ -> 0

let string_of_extension (#p: (lbytes 2 -> GTot Type0)) (e: extension' p) = match e with
  | E_server_name _ -> "server_name"
  | E_supported_groups _ -> "supported_groups"
  | E_signature_algorithms _ -> "signature_algorithms"
  | E_signature_algorithms_cert _ -> "signature_algorithms_cert"
  | E_key_share _ -> "key_share"
  | E_pre_shared_key _ -> "pre_shared_key"
  | E_session_ticket _ -> "session_ticket"
  | E_early_data _ -> "early_data"
  | E_supported_versions _ -> "supported_versions"
  | E_cookie _ -> "cookie"
  | E_psk_key_exchange_modes _ -> "psk_key_exchange_modes"
  | E_extended_ms -> "extended_master_secret"
  | E_ec_point_format _ -> "ec_point_formats"
  | E_alpn _ -> "alpn"
  | E_unknown_extension n _ -> print_bytes n

let rec string_of_extensions (#p: (lbytes 2 -> GTot Type0)) (l: list (extension' p)) = match l with
  | e0 :: es -> string_of_extension e0 ^ " " ^ string_of_extensions es
  | [] -> ""

let sameExt (#p: (lbytes 2 -> GTot Type0)) (e1: extension' p) (e2: extension' p) =
  let q : extension' p * extension' p = e1, e2 in
  match q with
  | E_server_name _, E_server_name _ -> true
  | E_supported_groups _, E_supported_groups _ -> true
  | E_signature_algorithms _, E_signature_algorithms _ -> true
  | E_signature_algorithms_cert _, E_signature_algorithms_cert _ -> true
  | E_key_share _, E_key_share _ -> true
  | E_pre_shared_key _, E_pre_shared_key _ -> true
  | E_session_ticket _, E_session_ticket _ -> true
  | E_early_data _, E_early_data _ -> true
  | E_supported_versions _, E_supported_versions _ -> true
  | E_cookie _, E_cookie _ -> true
  | E_psk_key_exchange_modes _, E_psk_key_exchange_modes _ -> true
  | E_extended_ms, E_extended_ms -> true
  | E_ec_point_format _, E_ec_point_format _ -> true
  | E_alpn _, E_alpn _ -> true
  // same, if the header is the same: mimics the general behaviour
  | E_unknown_extension h1 _, E_unknown_extension h2 _ -> h1 = h2
  | _ -> false

(*************************************************
 extension formatting
 *************************************************)

//17-05-05 no good reason to pattern match twice when formatting? follow the same structure as for parsing?
val extensionHeaderBytes: #p: unknownTag -> extension' p -> lbytes 2
let extensionHeaderBytes #p ext =
  match ext with             // 4.2 ExtensionType enum value
  | E_server_name _               -> twobytes (0x00z, 0x00z)
  | E_supported_groups _          -> twobytes (0x00z, 0x0Az) // 10
  | E_signature_algorithms _      -> twobytes (0x00z, 0x0Dz) // 13
  | E_signature_algorithms_cert _ -> twobytes (0x00z, 50z)   //
  | E_session_ticket _            -> twobytes (0x00z, 0x23z) // 35
  | E_key_share _                 -> twobytes (0x00z, 51z)   // (was 40)
  | E_pre_shared_key _            -> twobytes (0x00z, 0x29z) // 41
  | E_early_data _                -> twobytes (0x00z, 0x2az) // 42
  | E_supported_versions _        -> twobytes (0x00z, 0x2bz) // 43
  | E_cookie _                    -> twobytes (0x00z, 0x2cz) // 44
  | E_psk_key_exchange_modes _    -> twobytes (0x00z, 0x2dz) // 45
  | E_extended_ms                 -> twobytes (0x00z, 0x17z) // 45
  | E_ec_point_format _           -> twobytes (0x00z, 0x0Bz) // 11
  | E_alpn _                      -> twobytes (0x00z, 0x10z) // 16
  | E_unknown_extension h b       -> h


let unknown: unknownTag = fun h ->
  forall (p: unknownTag) (e: extension' p {h=extensionHeaderBytes e}) . E_unknown_extension? e

//18-02-22 not sure how to avoid duplicating these constants
#reset-options "--admit_smt_queries true"
let is_unknown x =
  x <> twobytes (0x00z, 0x00z) &&
  x <> twobytes (0x00z, 0x0Az) &&
  x <> twobytes (0x00z, 0x0Dz) &&
  x <> twobytes (0x00z, 50z)   &&
  x <> twobytes (0x00z, 0x1Az) &&
  x <> twobytes (0x00z, 0x23z) &&
  x <> twobytes (0x00z, 51z)   &&
  x <> twobytes (0x00z, 0x29z) &&
  x <> twobytes (0x00z, 0x2az) &&
  x <> twobytes (0x00z, 0x2bz) &&
  x <> twobytes (0x00z, 0x2cz) &&
  x <> twobytes (0x00z, 0x2dz) &&
  x <> twobytes (0x00z, 0x17z) &&
  x <> twobytes (0x00z, 0x0Bz) &&
  x <> twobytes (0x00z, 0x10z)

(* Application extensions *)
private val ext_of_custom_aux: acc:list extension -> el:custom_extensions -> Tot (list extension)
let rec ext_of_custom_aux acc = function
  | [] -> acc
  | (h, b) :: t -> 
  let bh = bytes_of_uint16 h in
  assume (unknown bh);
  ext_of_custom_aux (E_unknown_extension bh b :: acc) t
#reset-options

let ext_of_custom el = List.Tot.rev (ext_of_custom_aux [] el)

#reset-options "--admit_smt_queries true"
private val custom_of_ext_aux: acc:custom_extensions -> l:list extension -> Tot custom_extensions
let rec custom_of_ext_aux acc = function
  | [] -> acc
  | (E_unknown_extension hd b) :: t -> custom_of_ext_aux ((uint16_of_bytes hd, b) :: acc) t
  | _ :: t -> custom_of_ext_aux acc t

let custom_of_ext el = List.Tot.rev (custom_of_ext_aux [] el)
#reset-options

private let app_filter (e:extension) =
  match e with
  | E_server_name _
  | E_signature_algorithms _
  | E_signature_algorithms_cert _
  | E_alpn _
  | E_supported_groups _
  | E_unknown_extension _ _ -> true
  | _ -> false

// Filter for extensions that we expose to the application by nego callback
let app_ext_filter =
  function
  | None -> None
  | Some l -> Some (List.Tot.filter app_filter l)

#reset-options "--admit_smt_queries true"
private
let equal_extensionHeaderBytes_sameExt
  (e1 e2: extension)
: Lemma
  (requires (extensionHeaderBytes e1 = extensionHeaderBytes e2))
  (ensures (sameExt e1 e2))
= assert (extensionHeaderBytes e1 == extensionHeaderBytes e2);
  match e1 with
  | E_unknown_extension _ _ -> assert (E_unknown_extension? e2)
  | _ -> ()

private
let sameExt_equal_extensionHeaderBytes
  (e1 e2: extension)
: Lemma
  (requires (sameExt e1 e2))
  (ensures (extensionHeaderBytes e1 = extensionHeaderBytes e2))
= ()
#reset-options

(* API *)

// Missing refinements in `extension` type constructors to be able to prove the length bound
#set-options "--admit_smt_queries true"
(** Serializes an extension payload *)
private let extensionPayloadBytes_aux acc v = acc @| versionBytes v
val extensionPayloadBytes: extension -> b:bytes { length b < 65536 - 4 }
let rec extensionPayloadBytes = function
  | E_server_name []                -> vlbytes 2 empty_bytes // ServerHello, EncryptedExtensions
  | E_server_name l                 -> vlbytes 2 (vlbytes 2 (serverNameBytes l)) // ClientHello
  | E_supported_groups l            -> vlbytes 2 (CommonDH.namedGroupsBytes l)
  | E_signature_algorithms sha      -> vlbytes 2 (signatureSchemeListBytes sha)
  | E_signature_algorithms_cert sha -> vlbytes 2 (signatureSchemeListBytes sha)
  | E_session_ticket b              -> vlbytes 2 b
  | E_key_share ks                  -> vlbytes 2 (CommonDH.keyShareBytes ks)
  | E_pre_shared_key psk -> (match psk with
    | ClientPSK ids len             -> vlbytes_trunc 2 (pskBytes psk) (2 + len)
    | _                             -> vlbytes 2 (pskBytes psk))
  | E_early_data edi                -> vlbytes 2 (earlyDataIndicationBytes edi)
  | E_supported_versions vs         -> vlbytes 2 (protocol_versions_bytes vs)
  | E_cookie c                      -> (lemma_repr_bytes_values (length c); vlbytes 2 (vlbytes 2 c))
  | E_psk_key_exchange_modes kex    -> vlbytes 2 (client_psk_kexes_bytes kex)
  | E_extended_ms                   -> vlbytes 2 empty_bytes
  | E_ec_point_format l             -> vlbytes 2 (ecpfListBytes l)
  | E_alpn l                        -> vlbytes 2 (alpnBytes l)
  | E_unknown_extension _ b         -> vlbytes 2 b
#reset-options

let rec extensionBytes ext =
  let head = extensionHeaderBytes ext in
  let payload = extensionPayloadBytes ext in
  lemma_repr_bytes_values (length payload);
  //let payload = vlbytes 2 payload in
  head @| payload

#reset-options "--admit_smt_queries true"
let extensionBytes_is_injective
  (ext1: extension)
  (s1: bytes)
  (ext2: extension)
  (s2: bytes)
: Lemma
  (requires (Bytes.equal (extensionBytes ext1 @| s1) (extensionBytes ext2 @| s2)))
  (ensures (ext1 == ext2 /\ s1 == s2))
= let head1 = extensionHeaderBytes ext1 in
  let payload1 = extensionPayloadBytes ext1 in
  let head2 = extensionHeaderBytes ext2 in
  let payload2 = extensionPayloadBytes ext2 in
  //TODO bytes NS 09/27
  //append_assoc head1 payload1 s1;
  //append_assoc head2 payload2 s2;
  //lemma_append_inj head1 (payload1 @| s1) head2 (payload2 @| s2);
  equal_extensionHeaderBytes_sameExt ext1 ext2;
  match ext1 with
  | E_supported_groups l1 ->
    let (E_supported_groups l2) = ext2 in
    assume (List.Tot.length l1 < 65536/2 );
    let n1 = CommonDH.namedGroupsBytes l1 in
    assume (List.Tot.length l2 < 65536/2 );
    let n2 = CommonDH.namedGroupsBytes l2 in
    assume (repr_bytes (length n1) <= 2);
    assume (repr_bytes (length n2) <= 2);
    lemma_vlbytes_inj_strong 2 n1 s1 n2 s2;
    // namedGroupsBytes_is_injective l1 empty_bytes l2 empty_bytes
    admit() // cwinter: not needed with the new parsers
  | E_signature_algorithms sha1 ->
    let (E_signature_algorithms sha2) = ext2 in
    let sg1 = signatureSchemeListBytes sha1 in
    let sg2 = signatureSchemeListBytes sha2 in
    assume (repr_bytes (length sg1) <= 2);
    assume (repr_bytes (length sg2) <= 2);
    lemma_vlbytes_inj_strong 2 sg1 s1 sg2 s2;
    // signatureSchemeListBytes_is_injective sha1 empty_bytes sha2 empty_bytes
    admit() // cwinter: not needed with the new parsers
  | E_signature_algorithms_cert sha1 -> // duplicating the proof above
    let (E_signature_algorithms sha2) = ext2 in
    let sg1 = signatureSchemeListBytes sha1 in
    let sg2 = signatureSchemeListBytes sha2 in
    assume (repr_bytes (length sg1) <= 2);
    assume (repr_bytes (length sg2) <= 2);
    lemma_vlbytes_inj_strong 2 sg1 s1 sg2 s2
    //;signatureSchemeListBytes_is_injective sha1 empty_bytes sha2 empty_bytes
  | E_extended_ms ->
    lemma_repr_bytes_values (length empty_bytes);
    lemma_vlbytes_inj_strong 2 empty_bytes s1 empty_bytes s2
  | E_unknown_extension h1 b1 ->
    let E_unknown_extension h2 b2 = ext2 in
    assume (repr_bytes (length b1) <= 2);
    assume (repr_bytes (length b2) <= 2);
    lemma_vlbytes_inj_strong 2 b1 s1 b2 s2
  | _ ->
    assume (ext1 == ext2 /\ s1 == s2)
#reset-options

private let extensionListBytes_aux l s = 
  let es = extensionBytes s in
  assume (UInt.fits (length l + length es) 32);
  l @| es
  
let extensionListBytes exts =
  List.Tot.fold_left extensionListBytes_aux empty_bytes exts

#reset-options "--admit_smt_queries true"
private let rec extensionListBytes_eq exts accu :
  Lemma (List.Tot.fold_left (fun l s -> l @| extensionBytes s) accu exts ==
  accu @| extensionListBytes exts)
= match exts with
  | [] -> () //append_empty_bytes_r accu //TODO bytes NS 09/27
  | s :: q ->
    let e = extensionBytes s in
    //append_empty_bytes_l e; //TODO bytes NS 09/27
    extensionListBytes_eq q (accu @| e);
    extensionListBytes_eq q e
    //append_assoc accu e (extensionListBytes q) //TODO bytes NS 09/27

let extensionListBytes_cons
  (e: extension)
  (es: list extension)
: Lemma
  (extensionListBytes (e :: es) == extensionBytes e @| extensionListBytes es)
= let l = extensionBytes e in
  //append_empty_bytes_l l; //TODO bytes NS 09/27
  extensionListBytes_eq es l

let rec extensionListBytes_append
  (e1 e2: list extension)
: Lemma
  (extensionListBytes (e1 @ e2) == extensionListBytes e1 @| extensionListBytes e2)
= match e1 with
  | [] ->
    () //append_empty_bytes_l (extensionListBytes e2) //TODO bytes NS 09/27
  | e :: q ->
    extensionListBytes_cons e (q @ e2);
    extensionListBytes_append q e2;
    // append_assoc (extensionBytes e) (extensionListBytes q) (extensionListBytes e2); //TODO bytes NS 09/27
    extensionListBytes_cons e q

let rec extensionListBytes_is_injective_same_length_in
  (exts1: list extension)
  (s1: bytes)
  (exts2: list extension)
  (s2: bytes)
: Lemma
  (requires (Bytes.equal (extensionListBytes exts1 @| s1) (extensionListBytes exts2 @| s2) /\ List.Tot.length exts1 == List.Tot.length exts2))
  (ensures (exts1 == exts2 /\ s1 == s2))
= match exts1, exts2 with
  | [], [] ->
    () //lemma_append_inj empty_bytes s1 empty_bytes s2 //TODO bytes NS 09/27
  | ext1::q1, ext2::q2 ->
    let e1 = extensionBytes ext1 in
    let l1 = extensionListBytes q1 in
    extensionListBytes_cons ext1 q1;
    //append_assoc e1 l1 s1; //TODO bytes NS 09/27
    let e2 = extensionBytes ext2 in
    let l2 = extensionListBytes q2 in
    extensionListBytes_cons ext2 q2;
    //append_assoc e2 l2 s2; //TODO bytes NS 09/27
    extensionBytes_is_injective ext1 (l1 @| s1) ext2 (l2 @| s2);
    extensionListBytes_is_injective_same_length_in q1 s1 q2 s2

let rec extensionListBytes_is_injective_same_length_out
  (exts1: list extension)
  (s1: bytes)
  (exts2: list extension)
  (s2: bytes)
: Lemma
  (requires (
    let l1 = extensionListBytes exts1 in
    let l2 = extensionListBytes exts2 in (
    Bytes.equal (l1 @| s1) (l2 @| s2) /\ length l1 == length l2
  )))
  (ensures (exts1 == exts2 /\ s1 == s2))
= match exts1 with
  | [] ->
    begin match exts2 with
    | [] -> () //lemma_append_inj empty_bytes s1 empty_bytes s2 //TODO bytes NS 09/27
    | e :: q -> extensionListBytes_cons e q
    end
  | ext1::q1 ->
    extensionListBytes_cons ext1 q1;
    let (ext2::q2) = exts2 in
    let e1 = extensionBytes ext1 in
    let l1 = extensionListBytes q1 in
    //append_assoc e1 l1 s1; //TODO bytes NS 09/27
    let e2 = extensionBytes ext2 in
    let l2 = extensionListBytes q2 in
    extensionListBytes_cons ext2 q2;
    //append_assoc e2 l2 s2; //TODO bytes NS 09/27
    extensionBytes_is_injective ext1 (l1 @| s1) ext2 (l2 @| s2);
    extensionListBytes_is_injective_same_length_out q1 s1 q2 s2

let rec extensionListBytes_is_injective
  (exts1: list extension)
  (exts2: list extension)
: Lemma
  (requires (Bytes.equal (extensionListBytes exts1) (extensionListBytes exts2)))
  (ensures (exts1 == exts2))
= extensionListBytes_is_injective_same_length_out exts1 empty_bytes exts2 empty_bytes

let rec extensionListBytes_same_bindersLen
  (exts1: list extension)
  (s1: bytes)
  (exts2: list extension)
  (s2: bytes)
: Lemma
  (requires (
    let e1 = extensionListBytes exts1 in
    let e2 = extensionListBytes exts2 in (
    Bytes.equal (e1 @| s1) (e2 @| s2) /\ length e1 + bindersLen exts1 == length e2 + bindersLen exts2
  )))
  (ensures (bindersLen exts1 == bindersLen exts2))
= match exts1, exts2 with
  | x1::q1, x2::q2 ->
    extensionListBytes_cons x1 q1;
    let ex1 = extensionBytes x1 in
    let eq1 = extensionListBytes q1 in
    //append_assoc ex1 eq1 s1; //TODO bytes NS 09/27
    extensionListBytes_cons x2 q2;
    let ex2 = extensionBytes x2 in
    let eq2 = extensionListBytes q2 in
    //append_assoc ex2 eq2 s2; //TODO bytes NS 09/27
    extensionBytes_is_injective x1 (eq1 @| s1) x2 (eq2 @| s2);
    if E_pre_shared_key? x1
    then ()
    else begin
      // Seq.lemma_len_append ex1 eq1; //TODO bytes NS 09/27 seems unnecessary
      // Seq.lemma_len_append ex2 eq2; //TODO bytes NS 09/27 seems unnecessary
      extensionListBytes_same_bindersLen q1 s1 q2 s2
    end
  | _ -> ()

let extensionListBytes_is_injective_strong
  (exts1: list extension)
  (s1: bytes)
  (exts2: list extension)
  (s2: bytes)
: Lemma
  (requires (
    let e1 = extensionListBytes exts1 in
    let e2 = extensionListBytes exts2 in (
    Bytes.equal (e1 @| s1) (e2 @| s2) /\ length e1 + bindersLen exts1 == length e2 + bindersLen exts2
  )))
  (ensures (exts1 == exts2 /\ s1 == s2))
= extensionListBytes_same_bindersLen exts1 s1 exts2 s2;
  extensionListBytes_is_injective_same_length_out exts1 s1 exts2 s2

val noExtensions: exts:extensions {exts == []}
let noExtensions =
  lemma_repr_bytes_values (length (extensionListBytes []));
  []

let extensionsBytes exts =
  let b = extensionListBytes exts in
  let binder_len = bindersLen exts in
  lemma_repr_bytes_values (length b + binder_len);
  vlbytes_trunc 2 b binder_len

let extensionsBytes_is_injective_strong
  (exts1:extensions {length (extensionListBytes exts1) + bindersLen exts1 < 65536})
  (s1: bytes)
  (exts2:extensions {length (extensionListBytes exts2) + bindersLen exts2 < 65536})
  (s2: bytes)
: Lemma
  (requires (Bytes.equal (extensionsBytes exts1 @| s1) (extensionsBytes exts2 @| s2)))
  (ensures (exts1 == exts2 /\ s1 == s2))
= let b1 = extensionListBytes exts1 in
  let binder_len1 = bindersLen exts1 in
  lemma_repr_bytes_values (length b1 + binder_len1);
  let b2 = extensionListBytes exts2 in
  let binder_len2 = bindersLen exts2 in
  lemma_repr_bytes_values (length b2 + binder_len2);
  vlbytes_trunc_injective 2 b1 binder_len1 s1 b2 binder_len2 s2;
  extensionListBytes_is_injective_strong exts1 s1 exts2 s2

let extensionsBytes_is_injective
  (ext1: extensions {length (extensionListBytes ext1) + bindersLen ext1 < 65536} )
  (ext2: extensions {length (extensionListBytes ext2) + bindersLen ext2 < 65536} )
: Lemma (requires True)
  (ensures (Bytes.equal (extensionsBytes ext1) (extensionsBytes ext2) ==> ext1 == ext2))
= Classical.move_requires (extensionsBytes_is_injective_strong ext1 empty_bytes ext2) empty_bytes

(*************************************************
 Extension parsing
**************************************************)

private val addOnce: extension -> list extension -> Tot (result (list extension))
let addOnce ext extList =
  if existsb2 sameExt ext extList then
    fatal Handshake_failure (perror __SOURCE_FILE__ __LINE__ "Same extension received more than once")
  else
    let res = FStar.List.Tot.append extList [ext] in
    correct res

private let rec parseEcpfList_aux
        : b:bytes -> Tot (result (list point_format)) (decreases (length b))
        = fun b ->
          if b = empty_bytes then Correct []
          else if length b = 0 then error "malformed curve list"
          else
            let u,v = split b 1ul in
            ( match parseEcpfList_aux v with
              | Error z -> Error z
              | Correct l ->
                let cur =
                match u.[0ul] with
                | 0z -> ECP_UNCOMPRESSED
                | _ -> ECP_UNKNOWN(int_of_bytes u) in
                Correct (cur :: l))

val parseEcpfList: bytes -> result (list point_format)
let parseEcpfList b =
    match parseEcpfList_aux b with
    | Error z -> Error z
    | Correct l ->
      if List.Tot.mem ECP_UNCOMPRESSED l
      then correct l
      else error "uncompressed point format not supported"

let parseKeyShare mt data =
  match mt with
  | EM_ClientHello -> CommonDH.parseClientKeyShare data
  | EM_ServerHello -> CommonDH.parseServerKeyShare data
  | EM_HelloRetryRequest -> CommonDH.parseHelloRetryKeyShare data
  | _ -> error "key_share extension cannot appear in this message type"

(* We don't care about duplicates, not formally excluded. *)
#set-options "--admit_smt_queries true"

inline_for_extraction
let normallyNone ctor r =
  (ctor r, None)

let parseExtension mt b =
  if length b < 4 then error "extension type: not enough bytes" else
  let head, payload = split b 2ul in
  match vlparse 2 payload with
  | Error (_,s) -> error ("extension: "^s)
  | Correct data ->
    match cbyte2 head with
    | (0x00z, 0x00z) ->
//      mapResult E_server_name (parseServerName mt data)
      mapResult (normallyNone E_server_name) (parseServerName mt data)

    | (0x00z, 0x0Az) -> // supported groups
      if length data < 2 || length data >= 65538 then error "supported groups" else
      mapResult (normallyNone E_supported_groups) (
        match (CommonDH.parseNamedGroups data) with 
        | Some (x, _) -> Correct x 
        | _ -> error "supported_groups parser error")

    | (0x00z, 13z) -> // sigAlgs
      if length data < 2 || length data >= 65538 then error "supported signature algorithms" else
      mapResult (normallyNone E_signature_algorithms) (TLSConstants.parseSignatureSchemeList data)

    | (0x00z, 50z) -> // sigAlgs_cert
      if length data < 2 || length data >= 65538 then error "supported signature algorithms (cert)" else
      mapResult (normallyNone E_signature_algorithms_cert) (TLSConstants.parseSignatureSchemeList data)

    | (0x00z, 0x10z) -> // application_layer_protocol_negotiation
      if length data < 2 || length data >= 65538 then error "application layer protocol negotiation" else
      mapResult (normallyNone E_alpn) (parseAlpn data)

    | (0x00z, 0x23z) -> // session_ticket
      Correct (E_session_ticket data, None)

    | (0x00z, 51z) -> // key share
      mapResult (normallyNone E_key_share) (parseKeyShare mt data)

    | (0x00z, 0x29z) -> // PSK
      if length data < 2 then error "PSK"
      else (match parse_psk mt data with
      | Error z -> Error z
      | Correct (psk, None) -> Correct (E_pre_shared_key psk, None)
      | Correct (psk, Some binders) -> Correct (E_pre_shared_key psk, Some binders))

    | (0x00z, 0x2az) -> // early data
      if length data <> 0 && length data <> 4 then error "early data indication" else
      mapResult (normallyNone E_early_data) (parseEarlyDataIndication data)

    | (0x00z, 0x2bz) ->
      if length data < 2 || length data >= 256 then error "supported versions" else
      mapResult (normallyNone E_supported_versions) (parseSupportedVersions data)

    | (0x00z, 0x2cz) -> // cookie
      if length data <= 2 || length data >= 65538 then error "cookie" else
      (match vlparse 2 data with
      | Error z -> Error z
      | Correct data -> Correct (E_cookie data, None))

    | (0x00z, 0x2dz) -> // key ex
      if length data < 2 then error "psk_key_exchange_modes" else
      mapResult (normallyNone E_psk_key_exchange_modes) (parse_client_psk_kexes data)

    | (0x00z, 0x17z) -> // extended ms
      if length data > 0 then error "extended master secret" else
      Correct (E_extended_ms,None)

    | (0x00z, 0x0Bz) -> // ec point format
      if length data < 1 || length data >= 256 then error "ec point format"
      else
       begin
        lemma_repr_bytes_values (length data);
        match vlparse 1 data with
        | Error z -> Error z
        | Correct ecpfs -> mapResult (normallyNone E_ec_point_format) (parseEcpfList ecpfs)
       end
    | _ -> Correct (E_unknown_extension head data, None)

//17-05-08 TODO precondition on bytes to prove length subtyping on the result
// SI: simplify binder accumulation code. (Binders should be the last in the list.)
private
let rec parseExtensions_aux
        : mt:ext_msg -> b:bytes -> list extension * option binders -> Tot (result (list extension * option binders))
          (decreases (length b))
   = fun mt b (exts, obinders) ->
       if length b >= 4 then
         let ht, b = split b 2ul in
         match vlsplit 2 b with
         | Error(z) -> error "extension length"
         | Correct(ext, bytes) ->
      	   (* assume (Prims.precedes (Prims.LexCons b) (Prims.LexCons (ht @| vlbytes 2 ext))); *)
      	   (match parseExtension mt (ht @| vlbytes 2 ext) with
      	   // SI:
      	     | Correct (ext, Some binders) ->
      	       (match addOnce ext exts with // fails if the extension already is in the list
      	        | Correct exts -> parseExtensions_aux mt bytes (exts, Some binders) // keep the binder we got
      	        | Error z -> Error z)
      	     | Correct (ext, None) ->
      	       (match addOnce ext exts with // fails if the extension already is in the list
       	        | Correct exts -> parseExtensions_aux mt bytes (exts, obinders)  // use binder-so-far.
      	        | Error z -> Error z)
      	     | Error z -> Error z)
       else Correct (exts,obinders)

let parseExtensions mt b =
  if length b < 2 then error "extensions" else
  match vlparse 2 b with
  | Correct b -> parseExtensions_aux mt b ([], None)
  | Error z -> error "extensions"

(* SI: API. Called by HandshakeMessages. *)
// returns either Some,Some or None,
let parseOptExtensions mt data =
  if length data = 0
  then Correct (None,None)
  else (
    match parseExtensions mt data with
    | Error z -> Error z
    | Correct (ee,obinders) -> Correct (Some ee, obinders))

(*************************************************
 Other extension functionality
 *************************************************)

(* JK: Need to get rid of such functions *)
private let rec list_valid_cs_is_list_cs (l:valid_cipher_suites): list cipherSuite =
  match l with
  | [] -> []
  | hd :: tl -> hd :: list_valid_cs_is_list_cs tl

#set-options "--admit_smt_queries true"
private let rec list_valid_ng_is_list_ng (l:CommonDH.supportedNamedGroups) : CommonDH.namedGroups =
  match l with
  | [] -> []
  | hd :: tl -> hd :: list_valid_ng_is_list_ng tl
#reset-options


(* SI: API. Called by Nego. *)
(* RFC 4.2:
When multiple extensions of different types are present, the
extensions MAY appear in any order, with the exception of
“pre_shared_key” Section 4.2.10 which MUST be the last extension in
the ClientHello. There MUST NOT be more than one extension of the same
type in a given extension block.

RFC 8.2. ClientHello msg must:
If not containing a “pre_shared_key” extension, it MUST contain both a
“signature_algorithms” extension and a “supported_groups” extension.
If containing a “supported_groups” extension, it MUST also contain a
“key_share” extension, and vice versa. An empty KeyShare.client_shares
vector is permitted.

*)
#set-options "--admit_smt_queries true"
(* SI: implement prepareExtensions prep combinators, of type exts->data->exts, per ext group.
   For instance, PSK, HS, etc extensions should all be done in one function each.
   This seems to make this prepareExtensions more modular. *)

// We define these functions at top-level so that Kremlin can compute their pointers
// when passed to higher-order functions.
// REMARK: could use __proj__MkpskInfo__item__allow_psk_resumption, but it's a mouthful.
private let allow_psk_resumption x = x.allow_psk_resumption
private let allow_dhe_resumption x = x.allow_dhe_resumption
private let allow_resumption ((_,x):PSK.pskid * pskInfo) =
  x.allow_psk_resumption || x.allow_dhe_resumption
private let send_supported_groups cs = isDHECipherSuite cs || CipherSuite13? cs
private let compute_binder_len (ctr:nat) (pski:pskInfo) =
  let h = PSK.pskInfo_hash pski in
  ctr + 1 + (UInt32.v (Hacl.Hash.Definitions.hash_len h))

private val obfuscate_age: UInt32.t -> list (PSK.pskid * pskInfo) -> list pskIdentity
let rec obfuscate_age now = function
  | [] -> []
  | (id, ctx) :: t ->
    let age = FStar.UInt32.((now -%^ ctx.time_created) *%^ 1000ul) in
    (id, PSK.encode_age age ctx.ticket_age_add) :: (obfuscate_age now t)

let prepareExtensions minpv pv cs host alps custom ems sren edi ticket sigAlgs namedGroups ri ks psks now =
    let res = ext_of_custom custom in
    (* Always send supported extensions.
       The configuration options will influence how strict the tests will be *)
    (* let cri = *)
    (*    match ri with *)
    (*    | None -> FirstConnection *)
    (*    | Some (cvd, svd) -> ClientRenegotiationInfo cvd in *)
    (* let res = [E_renegotiation_info(cri)] in *)
    let res =
      match minpv, pv with
      | TLS_1p3, TLS_1p3 -> E_supported_versions (ClientPV [TLS_1p3]) :: res
      | TLS_1p2, TLS_1p3 -> E_supported_versions (ClientPV [TLS_1p3; TLS_1p2]) :: res
      // REMARK: The case below is not mandatory. This behaviour should be configurable
      // | TLS_1p2, TLS_1p2 -> E_supported_versions [TLS_1p2] :: res
      | _ -> res
    in
    let res =
      match pv, ks with
      | TLS_1p3, Some ks -> E_key_share ks::res
      | _,_ -> res
    in
    let res =
      match host with
      | Some dns -> E_server_name [SNI_DNS dns] :: res
      | None -> res
    in
    let res =
      match alps with
      | Some al -> E_alpn al :: res
      | None -> res
    in
    let res =
      match ticket with
      | Some t -> E_session_ticket t :: res
      | None -> res
    in
    // Include extended_master_secret when resuming
    let res = if ems then E_extended_ms :: res else res in
    // TLS 1.3#23: we never include signature_algorithms_cert, as it
    // is not yet enabled in our API; hence sigAlgs are used both for
    // TLS signing and certificate signing.
    let res = E_signature_algorithms sigAlgs :: res in
    let res =
      if List.Tot.existsb isECDHECipherSuite (list_valid_cs_is_list_cs cs) then
	      E_ec_point_format [ECP_UNCOMPRESSED] :: res
      else res
    in
    let res =
      if List.Tot.existsb send_supported_groups (list_valid_cs_is_list_cs cs) then
        E_supported_groups (list_valid_ng_is_list_ng namedGroups) :: res
      else res
    in
    let res =
      match pv with
      | TLS_1p3 ->
        if List.Tot.filter allow_resumption psks <> [] then
          let (pskids, pskinfos) : list PSK.pskid * list pskInfo = List.Tot.split psks in
          let psk_kex = [] in
          let psk_kex =
            if List.Tot.existsb allow_psk_resumption pskinfos
            then PSK_KE :: psk_kex else psk_kex in
          let psk_kex =
            if List.Tot.existsb allow_dhe_resumption pskinfos
            then PSK_DHE_KE :: psk_kex else psk_kex in
          let res = E_psk_key_exchange_modes psk_kex :: res in
          let binder_len = List.Tot.fold_left compute_binder_len 0 pskinfos in
          let pskidentities = obfuscate_age now psks in
          let res =
            if edi then (E_early_data None) :: res
            else res in
          E_pre_shared_key (ClientPSK pskidentities binder_len) :: res // MUST BE LAST
        else
          E_psk_key_exchange_modes [PSK_KE; PSK_DHE_KE] :: res
      | _ -> res
    in
    let res = List.Tot.rev res in
    assume (List.Tot.length res < 256);  // JK: Specs in type config in TLSInfo unsufficient
    res
#reset-options

(*
// TODO the code above is too restrictive, should support further extensions
// TODO we need an inverse; broken due to extension ordering. Use pure views instead?
val matchExtensions: list extension{List.Tot.length l < 256} -> Tot (
  protocolVersion *
  k:valid_cipher_suites{List.Tot.length k < 256} *
  bool *
  bool *
  list signatureScheme -> list (x:namedGroup{SEC? x \/ FFDHE? x}) *
  option (cVerifyData * sVerifyData) *
  option CommonDH.keyShare )
let matchExtensions ext = admit()

let prepareExtensions_inverse pv cs sres sren sigAlgs namedGroups ri ks:
  Lemma(
    matchExtensions (prepareExtensions pv cs sres sren sigAlgs namedGroups ri ks) =
    (pv, cs, sres, sren, sigAlgs, namedGroups, ri, ks)) = ()
*)

(*************************************************
 SI:
 The rest of the code might be dead.
 Some of the it is called by Nego, but it might be that
 it needs to move to Nego.
 *************************************************)

(* SI: is renego deadcode? *)
(*
type renegotiationInfo =
  | FirstConnection
  | ClientRenegotiationInfo of (cVerifyData)
  | ServerRenegotiationInfo of (cVerifyData * sVerifyData)

val renegotiationInfoBytes: renegotiationInfo -> Tot bytes
let renegotiationInfoBytes ri =
  match ri with
  | FirstConnection ->
    lemma_repr_bytes_values 0;
    vlbytes 1 empty_bytes
  | ClientRenegotiationInfo(cvd) ->
    lemma_repr_bytes_values (length cvd);
    vlbytes 1 cvd
  | ServerRenegotiationInfo(cvd, svd) ->
    lemma_repr_bytes_values (length (cvd @| svd));
    vlbytes 1 (cvd @| svd)

val parseRenegotiationInfo: pinverse_t renegotiationInfoBytes
let parseRenegotiationInfo b =
  if length b >= 1 then
    match vlparse 1 b with
    | Correct(payload) ->
	let (len, _) = split b 1 in
	(match int_of_bytes len with
	| 0 -> Correct (FirstConnection)
	| 12 | 36 -> Correct (ClientRenegotiationInfo payload) // TLS 1.2 / SSLv3 client verify data sizes
	| 24 -> // TLS 1.2 case
	    let cvd, svd = split payload 12 in
	    Correct (ServerRenegotiationInfo (cvd, svd))
	| 72 -> // SSLv3
	    let cvd, svd = split payload 36 in
	    Correct (ServerRenegotiationInfo (cvd, svd))
	| _ -> Error (AD_decode_error, perror __SOURCE_FILE__ __LINE__ "Inappropriate length for renegotiation info data (expected 12/24 for client/server in TLS1.x, 36/72 for SSL3"))
    | Error z -> Error(AD_decode_error, perror __SOURCE_FILE__ __LINE__ "Failed to parse renegotiation info length")
  else Error (AD_decode_error, perror __SOURCE_FILE__ __LINE__ "Renegotiation info bytes are too short")
*)

(* JP: manual hoisting *)
let rec containsExt (l: list extension) (ext: extension): bool =
  match l with
  | [] -> false
  | ext' :: l' -> sameExt ext ext' || containsExt l' ext

(* TODO (adl):
   The negotiation of renegotiation indication is incorrect,
   Needs to be consistent with clientToNegotiatedExtension
*)
#set-options "--admit_smt_queries true"
private val serverToNegotiatedExtension:
  config ->
  list extension ->
  cipherSuite ->
  option (cVerifyData * sVerifyData) ->
  bool ->
  result protocolVersion ->
  extension ->
  result protocolVersion
let serverToNegotiatedExtension cfg cExtL cs ri resuming res sExt =
  match res with
  | Error z -> Error z
  | Correct pv0 ->
    if not (List.Helpers.exists_b_aux sExt sameExt cExtL) then
      fatal Unsupported_extension (perror __SOURCE_FILE__ __LINE__ "server sent an unexpected extension")
    else match sExt with
    (*
    | E_renegotiation_info sri ->
      if List.Tot.existsb E_renegotiation_info? cExtL then
      begin
      match sri, replace_subtyping ri with
      | FirstConnection, None -> correct ()
      | ServerRenegotiationInfo(cvds,svds), Some(cvdc, svdc) ->
        if equalBytes cvdc cvds && equalBytes svdc svds then
          correct l
        else
          Error(AD_handshake_failure, perror __SOURCE_FILE__ __LINE__ "Mismatch in contents of renegotiation indication")
      | _ -> Error(AD_handshake_failure, perror __SOURCE_FILE__ __LINE__ "Detected a renegotiation attack")
      end
      *)
    | E_supported_versions v ->
      (match pv0, v with
      | _, ClientPV _ -> fatal Illegal_parameter (perror __SOURCE_FILE__ __LINE__ "list of protocol versions in ServerHello")
      | TLS_1p2, ServerPV pv -> correct pv
      | _ -> fatal Illegal_parameter (perror __SOURCE_FILE__ __LINE__ "failed extension-based version negotiation"))
    | E_server_name _ ->
      // RFC 6066, bottom of page 6
      //When resuming a session, the server MUST NOT include a server_name extension in the server hello
      if resuming then fatal Unsupported_extension (perror __SOURCE_FILE__ __LINE__ "server sent SNI acknowledge in resumption")
      else res
    | E_session_ticket _ -> res
    | E_alpn sal -> if List.Tot.length sal = 1 then res
      else fatal Illegal_parameter (perror __SOURCE_FILE__ __LINE__ "Multiple ALPN selected by server")
    | E_extended_ms -> res
    | E_ec_point_format spf -> res // Can be sent in resumption, apparently (RFC 4492, 5.2)
    | E_key_share (CommonDH.ServerKeyShare sks) -> res
    | E_pre_shared_key (ServerPSK pski) -> res // bound check in Nego
      | E_supported_groups named_group_list ->
      if resuming then fatal Unsupported_extension (perror __SOURCE_FILE__ __LINE__ "server sent supported groups in resumption")
      else res
    | e ->
      fatal Handshake_failure (perror __SOURCE_FILE__ __LINE__ ("unhandled server extension: "^(string_of_extension e)))

private
let rec serverToNegotiatedExtensions_aux cfg cExtL cs ri resuming rpv (sExtL:list extension) =
  match sExtL with
  | [] -> rpv
  | hd::tl ->
    match serverToNegotiatedExtension cfg cExtL cs ri resuming rpv hd with
    | Error z -> Error z
    | rpv ->
      serverToNegotiatedExtensions_aux cfg cExtL cs ri resuming rpv tl

let negotiateClientExtensions pv cfg cExtL sExtL cs ri resuming =
  match pv, cExtL, sExtL with
  | SSL_3p0, _, None -> Correct (SSL_3p0)
  | SSL_3p0, _, Some _ -> fatal Internal_error (perror __SOURCE_FILE__ __LINE__ "Received extensions in SSL 3.0 ServerHello")
  | _, None, _ -> fatal Internal_error (perror __SOURCE_FILE__ __LINE__ "negotiation failed: missing extensions in TLS ClientHello (shouldn't happen)")
  | pv, _, None -> if pv <> TLS_1p3 then Correct (pv) else fatal Internal_error (perror __SOURCE_FILE__ __LINE__ "Cannot negotiate TLS 1.3 explicitly")
  | pv, Some cExtL, Some sExtL ->
    serverToNegotiatedExtensions_aux cfg cExtL cs ri resuming (correct pv) sExtL

#reset-options

#reset-options "--using_facts_from '* -LowParse.Spec.Base'"

private val clientToServerExtension: protocolVersion
  -> config
  -> cipherSuite
  -> option (cVerifyData * sVerifyData)
  -> option nat // PSK index
  -> option CommonDH.keyShare
  -> bool
  -> extension
  -> option extension
let clientToServerExtension pv cfg cs ri pski ks resuming cext =
  match cext with
  | E_supported_versions _ ->
    if pv = TLS_1p3 then Some (E_supported_versions (ServerPV pv))
    else None
  | E_key_share _ ->
    if pv = TLS_1p3 then Option.mapTot E_key_share ks // ks should be in one of client's groups
    else None
  | E_alpn cal ->
    (match cfg.alpn with
    | None -> None
    | Some sal ->
      let common = List.Helpers.filter_aux sal List.Helpers.mem_rev cal in
      match common with
      | a :: _ -> Some (E_alpn [a])
      | _ -> None)
  | E_server_name server_name_list ->
    if resuming then None // RFC 6066 page 6
    else
      (match List.Tot.tryFind SNI_DNS? server_name_list with
      | Some name -> Some (E_server_name []) // Acknowledge client's choice
      | _ -> None)
  | E_extended_ms ->
    if pv = TLS_1p3 || not cfg.extended_master_secret then None
    else Some E_extended_ms
  | E_ec_point_format ec_point_format_list -> // REMARK: ignores client's list
    if pv = TLS_1p3 then None // No ec_point_format in TLS 1.3
    else Some (E_ec_point_format [ECP_UNCOMPRESSED])
  | E_pre_shared_key _ ->
    if pski = None || pv <> TLS_1p3 then None
    else
      let x = Some?.v pski in
      begin
        assume (x < 65536);
        Some (E_pre_shared_key (ServerPSK (UInt16.uint_to_t x)))
      end
  | E_supported_groups named_group_list ->
    if pv = TLS_1p3 then
      // REMARK: Purely informative, can only appear in EncryptedExtensions
      Some (E_supported_groups (list_valid_ng_is_list_ng cfg.named_groups))
    else None
  | E_early_data b -> // EE
    if Some? cfg.max_early_data && pski = Some 0 then Some (E_early_data None) else None
  | E_session_ticket b ->
     if pv = TLS_1p3 || not cfg.enable_tickets then None
     else Some (E_session_ticket empty_bytes) // TODO we may not always want to refresh the ticket
  | _ -> None

(* SI: API. Called by Handshake. *)
let rec choose_clientToServerExtension pv cfg cs ri pski ks resuming (cExtL:list extension) =
  match cExtL with
  | [] -> []
  | hd::cExtL ->
    match clientToServerExtension pv cfg cs ri pski ks resuming hd with
    | None -> choose_clientToServerExtension pv cfg cs ri pski ks resuming cExtL
    | Some e -> e::choose_clientToServerExtension pv cfg cs ri pski ks resuming cExtL

let negotiateServerExtensions pv cExtL csl cfg cs ri pski ks resuming =
   match cExtL with
   | Some cExtL ->
     let sexts = choose_clientToServerExtension pv cfg cs ri pski ks resuming cExtL in
     Correct (Some sexts)
   | None ->
     begin
     match pv with
(* SI: deadcode ?
       | SSL_3p0 ->
          let cre =
              if contains_TLS_EMPTY_RENEGOTIATION_INFO_SCSV (list_valid_cs_is_list_cs csl) then
                 Some [E_renegotiation_info (FirstConnection)] //, {ne_default with ne_secure_renegotiation = RI_Valid})
              else None //, ne_default in
          in Correct cre
*)
     | _ ->
       fatal Internal_error (perror __SOURCE_FILE__ __LINE__ "No extensions in ClientHello")
     end

// https://tools.ietf.org/html/rfc5246#section-7.4.1.4.1
(* SI: API. Called by HandshakeMessages. *)
let default_signatureScheme pv cs =
  let open Hashing.Spec in
  match sigAlg_of_ciphersuite cs with
  | ECDSA -> [ Ecdsa_sha1 ]
  | _ -> [ Rsa_pkcs1_sha1 ]

#reset-options
