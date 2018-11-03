(* This file is transitional. It gathers all manual calls to the
   LowParse combinators (beyond LowParse.*.Base) so that they can be
   extracted with cross-module inlining enabled for this file but not
   its clients, until cross-module inlining issues UNrelated to
   parsing are fixed.

   As stated in Makefile.common, for now, only Parsers.* and Format.*
   should explicitly call non-base LowParse combinators. Thus, this
   file should *only* depend on Parsers.* and Format.*
   
*)

module Parsers.Misc

module M2 = Parsers.Misc2

friend Parsers.Misc2
friend LowParse.SLow

let cipherSuitesVLBytes = M2.cipherSuitesVLBytes

let parseVLCipherSuites = M2.parseVLCipherSuites