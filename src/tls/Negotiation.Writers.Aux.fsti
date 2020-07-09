module Negotiation.Writers.Aux

(* TODO: all of these, along with their implementations in the .fst, should be automatically generated by QuackyDucky *)

module LWP = LowParseWriters.Parsers
module LPI = LowParse.Low.Int

val valid_pskBinderEntry_intro : LWP.valid_rewrite_t (LWP.parse_vlbytes 32ul 255ul) Parsers.PskBinderEntry.lwp_pskBinderEntry (fun _ -> True) (fun x -> x)

val valid_pskBinderEntry_elim : LWP.valid_rewrite_t Parsers.PskBinderEntry.lwp_pskBinderEntry (LWP.parse_vlbytes 32ul 255ul) (fun _ -> True) (fun x -> x)

val valid_pskIdentity_intro : LWP.valid_rewrite_t (Parsers.PskIdentity.lwp_pskIdentity_identity `LWP.parse_pair` LWP.parse_u32) Parsers.PskIdentity.lwp_pskIdentity (fun _ -> True) (fun (identity, age) -> { Parsers.PskIdentity.identity = identity; Parsers.PskIdentity.obfuscated_ticket_age = age; })

let rec offeredPsks_binders_list_bytesize_correct
  (l: list Parsers.PskBinderEntry.pskBinderEntry)
: Lemma
  (Parsers.OfferedPsks.offeredPsks_binders_list_bytesize l == LWP.list_size Parsers.PskBinderEntry.lwp_pskBinderEntry l)
  [SMTPat (Parsers.OfferedPsks.offeredPsks_binders_list_bytesize l)]
= match l with
  | [] -> ()
  | a :: q ->
    Parsers.PskBinderEntry.pskBinderEntry_bytesize_eq a;
    offeredPsks_binders_list_bytesize_correct q

val valid_offeredPsks_binders_intro : LWP.valid_rewrite_t
  (LWP.parse_vllist Parsers.PskBinderEntry.lwp_pskBinderEntry 33ul 65535ul)
  Parsers.OfferedPsks.lwp_offeredPsks_binders
  (fun _ -> True)
  (fun x -> x)

val valid_offeredPsks_binders_elim : LWP.valid_rewrite_t
  Parsers.OfferedPsks.lwp_offeredPsks_binders
  (LWP.parse_vllist Parsers.PskBinderEntry.lwp_pskBinderEntry 33ul 65535ul)
  (fun _ -> True)
  (fun x -> x)

let rec offeredPsks_identities_list_bytesize_correct
  (l: list Parsers.PskIdentity.pskIdentity)
: Lemma
  (Parsers.OfferedPsks.offeredPsks_identities_list_bytesize l == LWP.list_size Parsers.PskIdentity.lwp_pskIdentity l)
  [SMTPat (Parsers.OfferedPsks.offeredPsks_identities_list_bytesize l)]
= match l with
  | [] -> ()
  | a :: q ->
    Parsers.PskIdentity.pskIdentity_bytesize_eq a;
    offeredPsks_identities_list_bytesize_correct q

val valid_offeredPsks_identities_intro : LWP.valid_rewrite_t
  (LWP.parse_vllist Parsers.PskIdentity.lwp_pskIdentity 7ul 65535ul)
  Parsers.OfferedPsks.lwp_offeredPsks_identities
  (fun _ -> True)
  (fun x -> x)

val valid_offeredPsks_identities_elim : LWP.valid_rewrite_t
  Parsers.OfferedPsks.lwp_offeredPsks_identities
  (LWP.parse_vllist Parsers.PskIdentity.lwp_pskIdentity 7ul 65535ul)
  (fun _ -> True)
  (fun x -> x)

val valid_offeredPsks_intro : LWP.valid_rewrite_t
  (Parsers.OfferedPsks.lwp_offeredPsks_identities `LWP.parse_pair` Parsers.OfferedPsks.lwp_offeredPsks_binders) 
  Parsers.OfferedPsks.lwp_offeredPsks
  (fun _ -> True)
  (fun (identities, binders) -> {
    Parsers.OfferedPsks.identities = identities;
    Parsers.OfferedPsks.binders = binders;
  })

inline_for_extraction
noextract
let offeredPsks_intro
  (#inv: LWP.memory_invariant)
  #identities_pre #identities_post #identities_post_err
  ($identities: (unit -> LWP.EWrite unit LWP.parse_empty Parsers.OfferedPsks.lwp_offeredPsks_identities identities_pre identities_post identities_post_err inv))
  #binders_pre #binders_post #binders_post_err
  ($binders: (unit -> LWP.EWrite unit LWP.parse_empty Parsers.OfferedPsks.lwp_offeredPsks_binders binders_pre binders_post binders_post_err inv))
  ()
:
  LWP.EWrite
    unit
    LWP.parse_empty
    Parsers.OfferedPsks.lwp_offeredPsks
    (fun _ -> identities_pre () /\ binders_pre ())
    (fun _ _ x ->
      identities_pre () /\ binders_pre () /\
      begin match LWP.destr_repr_spec _ _ _ _ _ _ _ identities (), LWP.destr_repr_spec _ _ _ _ _ _ _ binders () with
      | LWP.Correct (_, identities), LWP.Correct (_, binders) -> x == {
          Parsers.OfferedPsks.identities = identities;
          Parsers.OfferedPsks.binders = binders;
        } /\
        identities_post () () identities /\
        binders_post () () binders
      | _ -> False
      end
    )
    (fun _ ->
      identities_pre () /\ binders_pre () /\
      (binders_post_err () \/ identities_post_err ()) /\
      ~ (
        LWP.Correct? (LWP.destr_repr_spec _ _ _ _ _ _ _ identities ()) /\
        LWP.Correct? (LWP.destr_repr_spec _ _ _ _ _ _ _ binders ())
      )
    )
    inv
=
  LWP.recast_writer _ _ _ _ _ _ _ identities;
  LWP.frame _ _ _ _ _ _ _ (fun _ -> LWP.recast_writer _ _ _ _ _ _ _ binders);
  LWP.valid_rewrite _ _ _ _ _ valid_offeredPsks_intro

let valid_preSharedKeyClientExtension_intro : LWP.valid_rewrite_t
  Parsers.OfferedPsks.lwp_offeredPsks
  Parsers.PreSharedKeyClientExtension.lwp_preSharedKeyClientExtension
  (fun _ -> True)
  (fun x -> x)
=
  Parsers.PreSharedKeyClientExtension.preSharedKeyClientExtension_parser_serializer_eq ();
  LWP.valid_rewrite_parser_eq _ _

let valid_preSharedKeyClientExtension_elim : LWP.valid_rewrite_t
  Parsers.PreSharedKeyClientExtension.lwp_preSharedKeyClientExtension
  Parsers.OfferedPsks.lwp_offeredPsks
  (fun _ -> True)
  (fun x -> x)
=
  Parsers.PreSharedKeyClientExtension.preSharedKeyClientExtension_parser_serializer_eq ();
  LWP.valid_rewrite_parser_eq _ _

unfold
let mk_clientHelloExtension_CHE_pre_shared_key_intro
  (x: LWP.Parser?.t (LWP.parse_vldata Parsers.PreSharedKeyClientExtension.lwp_preSharedKeyClientExtension 0ul 65535ul))
: Tot (LWP.Parser?.t (Parsers.ClientHelloExtension.lwp_clientHelloExtension_CHE_pre_shared_key))
= Parsers.PreSharedKeyClientExtension.preSharedKeyClientExtension_bytesize_eq x;
  x

val valid_clientHelloExtension_CHE_pre_shared_key_intro : LWP.valid_rewrite_t
  (LWP.parse_vldata Parsers.PreSharedKeyClientExtension.lwp_preSharedKeyClientExtension 0ul 65535ul)
  Parsers.ClientHelloExtension.lwp_clientHelloExtension_CHE_pre_shared_key
  (fun _ -> True)
  mk_clientHelloExtension_CHE_pre_shared_key_intro

inline_for_extraction
noextract
let clientHelloExtension_CHE_pre_shared_key_intro #inv () : LWP.Write
  unit
  (LWP.parse_vldata Parsers.PreSharedKeyClientExtension.lwp_preSharedKeyClientExtension 0ul 65535ul)
  Parsers.ClientHelloExtension.lwp_clientHelloExtension_CHE_pre_shared_key
  (fun _ -> True)
  (fun x _ y -> (x <: Parsers.OfferedPsks.offeredPsks) == (y <: Parsers.OfferedPsks.offeredPsks))
  inv
=
  let x = LWP.get_state () in
  Parsers.PreSharedKeyClientExtension.preSharedKeyClientExtension_bytesize_eq x;
  LWP.valid_rewrite _ _ _ _ _
    valid_clientHelloExtension_CHE_pre_shared_key_intro

  (* NOTE: I could also define the elim but QuackyDucky already defines an accessor *)

module L = FStar.List.Tot

let rec list_size_pskKeyExchangeMode
  (l: list Parsers.PskKeyExchangeMode.pskKeyExchangeMode)
: Lemma
  (LWP.list_size Parsers.PskKeyExchangeMode.lwp_pskKeyExchangeMode l == 1 `Prims.op_Multiply` L.length l)
  [SMTPat (LWP.list_size Parsers.PskKeyExchangeMode.lwp_pskKeyExchangeMode l)]
= match l with
  | [] -> ()
  | a :: q -> list_size_pskKeyExchangeMode q

val valid_rewrite_pskKeyExchangeModes_intro : LWP.valid_rewrite_t
  (LWP.parse_vllist Parsers.PskKeyExchangeMode.lwp_pskKeyExchangeMode 1ul 255ul)
  Parsers.PskKeyExchangeModes.lwp_pskKeyExchangeModes
  (fun _ -> True)
  (fun x -> x)

val valid_rewrite_pskKeyExchangeModes_elim : LWP.valid_rewrite_t
  Parsers.PskKeyExchangeModes.lwp_pskKeyExchangeModes
  (LWP.parse_vllist Parsers.PskKeyExchangeMode.lwp_pskKeyExchangeMode 1ul 255ul)
  (fun _ -> True)
  (fun x -> x)

val valid_clientHelloExtension_CHE_psk_key_exchange_modes_intro : LWP.valid_rewrite_t
  (LWP.parse_vldata Parsers.PskKeyExchangeModes.lwp_pskKeyExchangeModes 0ul 65535ul)
  Parsers.ClientHelloExtension.lwp_clientHelloExtension_CHE_psk_key_exchange_modes
  (fun _ -> True)
  (fun x ->
    Parsers.PskKeyExchangeModes.pskKeyExchangeModes_bytesize_eq x;
    x)

val valid_clientHelloExtension_CHE_early_data_intro : LWP.valid_rewrite_t
  (LWP.parse_vldata LWP.parse_empty 0ul 65535ul)
  Parsers.ClientHelloExtension.lwp_clientHelloExtension_CHE_early_data
  (fun _ -> True)
  (fun x -> x)
