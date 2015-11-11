open Bytes
open Error
open Unix 

type networkStream = file_descr
type tcpListener = file_descr

let listen s i = 
    let server_sock = socket PF_INET SOCK_STREAM 0 in
    (setsockopt server_sock SO_REUSEADDR true ;
     let address = (gethostbyname(gethostname())).h_addr_list.(0) in
     bind server_sock (ADDR_INET (address, i)) ;
     listen server_sock 10 ;
     server_sock)

let accept s = 
    let (client_sock, client_addr) = accept s in
    client_sock

let acceptTimeout t s = accept s

let stop s = shutdown s SHUTDOWN_ALL

let connect s i = 
    let client_sock = socket PF_INET SOCK_STREAM 0 in
    let hentry = gethostbyname s in
    connect client_sock (ADDR_INET (hentry.h_addr_list.(0), i)) ; 
    client_sock

let connectTimeout t s i = connect s i

let sock_send sock str =
    let str = cbytes str in
    let len = String.length str in
    send sock str 0 len []

let sock_recv sock maxlen =
    let str = String.create maxlen in
    let recvlen = recv sock str 0 maxlen [] in
    let str = String.sub str 0 recvlen in
    abytes str

let read s i = 
    try Correct (sock_recv s i) 
    with Unix_error (e,s1,s2) ->
     Error (Printf.sprintf "%s: %s(%s)" (error_message e) s1 s2)

let write s b = 
    try (let n = sock_send s b in if n < Bytes.length b then Error(Printf.sprintf "Network error, wrote %d bytes" n) else Correct())
    with Unix_error (e,s1,s2) ->
     Error (Printf.sprintf "%s: %s(%s)" (error_message e) s1 s2)

let close s = 
    close s        


(*
open Unix

(* Convert human readable form to 32 bit value *)
let packed_ip = inet_addr_of_string "208.146.240.1" in


(* Convert 32 bit value to ip adress *)
let ip_address = string_of_inet_addr (packed_ip) in

(* Create socket object *)
let sock = socket PF_INET SOCK_STREAM 0 in

(* Get socketname *)
let saddr = getsockname sock ;;

let sock_send sock str =
    let len = String.length str in
    send sock str 0 len []

let sock_recv sock maxlen =
    let str = String.create maxlen in
    let recvlen = recv sock str 0 maxlen [] in
    String.sub str 0 recvlen

let client_sock = socket PF_INET SOCK_STREAM 0 in
let hentry = gethostbyname "coltrane" in
connect client_sock (ADDR_INET (hentry.h_addr_list.(0), 25)) ; (* SMTP *)

sock_recv client_sock 1024 ;

sock_send client_sock "mail from: <pleac@localhost>\n" ;
sock_recv client_sock 1024 ;

sock_send client_sock "rcpt to: <erikd@localhost>\n" ;
sock_recv client_sock 1024;

sock_send client_sock "data\n" ;
sock_recv client_sock 1024 ;

sock_send client_sock "From: Ocaml whiz\nSubject: Ocaml rulez!\n\nYES!\n.\n" ;
sock_recv client_sock 1024 ;

close client_sock ;;

let server_sock = socket PF_INET SOCK_STREAM 0 in

(* so we can restart our server quickly *)
setsockopt server_sock SO_REUSEADDR true ;

(* build up my socket address *)
let address = (gethostbyname(gethostname())).h_addr_list.(0) in
bind server_sock (ADDR_INET (address, 1029)) ;

(* Listen on the socket. Max of 10 incoming connections. *)
listen server_sock 10 ;

(* accept and process connections *)
while true do
        let (client_sock, client_addr) = accept server_sock in
        let str = "Hello\n" in
        let len = String.length str in
        let x = send client_sock str 0 len [] in
        shutdown client_sock SHUTDOWN_ALL
        done ;;

*)