﻿module HMAC

open Platform.Bytes
open TLSConstants
open CoreCrypto

type key = bytes
type data = bytes
type mac (a:macAlg) = lbytes (macSize a)

(* SSL/TLS constants *)

let ssl_pad1_md5  = createBytes 48 0x36uy
let ssl_pad2_md5  = createBytes 48 0x5cuy
let ssl_pad1_sha1 = createBytes 40 0x36uy
let ssl_pad2_sha1 = createBytes 40 0x5cuy

(* SSL3 keyed hash *)

type sslHashAlg = h:hashAlg { h = Hash MD5 \/ h = Hash SHA1 }
val sslKeyedHashPads: sslHashAlg -> Tot(bytes * bytes)
let sslKeyedHashPads = function
    | Hash MD5 -> (ssl_pad1_md5, ssl_pad2_md5)
    | Hash SHA1 -> (ssl_pad1_sha1, ssl_pad2_sha1)

let sslKeyedHash (a:sslHashAlg) k p =
    let (pad1, pad2) = sslKeyedHashPads a in
    let h = HASH.hash a (k @| pad1 @| p) in
    let h = HASH.hash a (k @| pad2 @| h) in
    h

let sslKeyedHashVerify (a:sslHashAlg) k p t : bool =
    let result = sslKeyedHash a k p in
    equalBytes result t

(* Parametric keyed hash *)

let hmac (a:hashAlg {is_Hash a}) k p =
    match a with Hash h  -> CoreCrypto.hmac h k p

// why do I need this declaration??
val hmacVerify: a:hashAlg {is_Hash a} -> key -> data -> bytes -> Tot bool
let hmacVerify (a:hashAlg {is_Hash a}) k p t : bool =
    let result = hmac a k p in
    equalBytes result t

(* Top level MAC function *)

let tls_mac a k d : mac a =
    match a with
    | HMAC     alg -> hmac (Hash alg) k d  
    | SSLKHASH alg -> sslKeyedHash (Hash alg) k d 

let tls_macVerify a k d t =
    match a with
    | HMAC     alg -> hmacVerify (Hash alg) k d t
    | SSLKHASH alg -> sslKeyedHashVerify (Hash alg) k d t
