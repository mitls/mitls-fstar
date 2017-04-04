#include <stdio.h>
#include <memory.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/cdefs.h>
#if __APPLE__ 
#include <sys/errno.h> // OS/X only provides include/sys/errno.h
#else
#include <errno.h> // MinGW only provides include/errno.h
#include <malloc.h>
#endif
#include <caml/callback.h>
#include <caml/alloc.h>
#include <caml/memory.h>
#include <caml/threads.h>
#include <caml/printexc.h>
#include "mitlsffi.h"

#define MITLS_FFI_LIST \
  MITLS_FFI_ENTRY(Config) \
  MITLS_FFI_ENTRY(SetCertChainFile) \
  MITLS_FFI_ENTRY(SetPrivateKeyFile) \
  MITLS_FFI_ENTRY(SetCAFile) \
  MITLS_FFI_ENTRY(Connect) \
  MITLS_FFI_ENTRY(AcceptConnected) \
  MITLS_FFI_ENTRY(Send) \
  MITLS_FFI_ENTRY(Recv)
 
// Pointers to ML code.  Initialized in FFI_mitls_init().  Invoke via caml_callback()
#define MITLS_FFI_ENTRY(x) value* g_mitls_FFI_##x;
MITLS_FFI_LIST
#undef MITLS_FFI_ENTRY

// Pass a C pointer into F* and recover it back.  OCaml limits integers to 2^30/2^62
// so shift right by 1 before conversion to OCaml.  The low bit must be 0 in order to
// meet structure alignment rules, so this is not lossy.
_Static_assert(sizeof(size_t) <= sizeof(value), "OCaml value isn't large enough to hold a C pointer");
#define PtrToValue(p) Val_long(((size_t)p)>>1)
#define ValueToPtr(v) ((void*)((Long_val(v)<<1)))

typedef struct mitls_state {
    value fstar_state;    // a GC root representing an F*-side state object
} mitls_state;

//
// Initialize miTLS.
//
//  Called once ahead of using miTLS
//
//  Returns:  0 for error, nonzero for success
//
int  FFI_mitls_init(void)
{
    char *Argv[2];

    // Build a stub argv[] to satisfy caml_Startup()
    Argv[0] = "";
    Argv[1] = NULL;
    
    // Initialize the OCaml runtime
    caml_startup(Argv);
    
    // Bind to functions registered via Callback.register from ML
#define MITLS_FFI_ENTRY(x) \
    g_mitls_FFI_##x = caml_named_value("MITLS_FFI_" # x); \
    if (!g_mitls_FFI_##x) { \
        return 0; \
    }
 MITLS_FFI_LIST  
 #undef MITLS_FFI_ENTRY
 
    // On return from caml_startup(), this thread continues to own
    // the OCaml global runtime lock as if it was running OCaml code.
    // Release it, so other threads can call into OCaml.
    caml_release_runtime_system();
    
    return 1; // success
}

void FFI_mitls_cleanup(void)
{
#define MITLS_FFI_ENTRY(x) \
    g_mitls_FFI_##x = NULL;
 MITLS_FFI_LIST  
 #undef MITLS_FFI_ENTRY
}

// Called by the host app to configure miTLS ahead of creating a connection
int FFI_mitls_configure(mitls_state **state, const char *tls_version, const char *host_name, char **outmsg, char **errmsg)
{
    CAMLparam0();
    CAMLlocal3(config, version, host);
    int ret = 0;

    *state = NULL;
    *outmsg = NULL;
    *errmsg = NULL;
    
    caml_acquire_runtime_system();
    version = caml_copy_string(tls_version);  
    host = caml_copy_string(host_name);
    config = caml_callback2_exn(*g_mitls_FFI_Config, version, host);
    if (Is_exception_result(config)) {
        // call caml_format_exception(Extract_exception(config)) to extract the exception information
    } else {
        mitls_state * s;
        
        // Allocate space on the heap, to store an OCaml value
        s = (mitls_state*)malloc(sizeof(mitls_state));
        if (s) {
            // Tell the OCaml GC about the heap address, so it is treated
            // as a GC root, keeping the config object live.
            s->fstar_state = config; 
            caml_register_generational_global_root(&s->fstar_state);
            *state = s;
            ret = 1;
        }
    }
    caml_release_runtime_system();

    CAMLreturnT(int,ret);
}

int FFI_mitls_configure_cert_chain_file(/* in */ mitls_state *state, const char * file)
{
    CAMLparam0();
    CAMLlocal2(config, camlfile);
    int ret = 0;

    caml_acquire_runtime_system();
    camlfile = caml_copy_string(file);
    config = caml_callback2_exn(*g_mitls_FFI_SetCertChainFile, state->fstar_state, camlfile);
    if (Is_exception_result(config)) {
        // call caml_format_exception(Extract_exception(config)) to extract the exception information
    } else {
        state->fstar_state = config;
        ret = 1;
    }
    caml_release_runtime_system();

    CAMLreturnT(int,ret);
}

int FFI_mitls_configure_private_key_file(/* in */ mitls_state *state, const char * file)
{
    CAMLparam0();
    CAMLlocal2(config, camlfile);
    int ret = 0;

    caml_acquire_runtime_system();
    camlfile = caml_copy_string(file);
    config = caml_callback2_exn(*g_mitls_FFI_SetPrivateKeyFile, state->fstar_state, camlfile);
    if (Is_exception_result(config)) {
        // call caml_format_exception(Extract_exception(config)) to extract the exception information
    } else {
        state->fstar_state = config;
        ret = 1;
    }
    caml_release_runtime_system();

    CAMLreturnT(int,ret);
}

int FFI_mitls_configure_ca_file(/* in */ mitls_state *state, const char * file)
{
    CAMLparam0();
    CAMLlocal2(config, camlfile);
    int ret = 0;

    caml_acquire_runtime_system();
    camlfile = caml_copy_string(file);
    config = caml_callback2_exn(*g_mitls_FFI_SetCAFile, state->fstar_state, camlfile);
    if (Is_exception_result(config)) {
        // call caml_format_exception(Extract_exception(config)) to extract the exception information
    } else {
        state->fstar_state = config;
        ret = 1;
    }
    caml_release_runtime_system();

    CAMLreturnT(int,ret);
}



// Called by the host app to free a mitls_state allocated by FFI_mitls_configure()
void FFI_mitls_close(mitls_state *state)
{
    if (state) {
        caml_acquire_runtime_system();
        caml_remove_generational_global_root(&state->fstar_state);
        caml_release_runtime_system();
        state->fstar_state = 0;
        free(state);
    }
}

void FFI_mitls_free_msg(char *msg)
{

}

void FFI_mitls_free_packet(void *packet)
{
    free(packet);
}

void * copypacket(value packet, /* out */ size_t *packet_size)
{
    void *p;
    mlsize_t size;
        
    size = caml_string_length(packet);
    p = malloc(size);
    if (p) {
        memcpy(p, String_val(packet), size);
        *packet_size = size;
    }
    return p;
}

// Called from FStar code to send via TCP
CAMLprim value ocaml_send_tcp(value cookie, value bytes)
{
    mlsize_t buffer_size;
    char *buffer;
    int retval;
    struct _FFI_mitls_callbacks *callbacks;
    char *localbuffer;

    CAMLparam2(cookie, bytes);
    
    callbacks = (struct _FFI_mitls_callbacks *)ValueToPtr(cookie);
    buffer = Bp_val(bytes);
    buffer_size = caml_string_length(bytes);
    // Copy the buffer out of the OCaml heap into a local buffer on the stack
    localbuffer = (char*)alloca(buffer_size);
    memcpy(localbuffer, buffer, buffer_size);
    
    caml_release_runtime_system();
    // All pointers into the OCaml heap are now off-limits until the
    // runtime_system lock has been re-aquired.
    retval = (*callbacks->send)(callbacks, localbuffer, buffer_size);
    caml_acquire_runtime_system();
    
    CAMLreturn(Val_int(retval));
}

// Called from FStar code to receive via TCP
CAMLprim value ocaml_recv_tcp(value cookie, value bytes)
{
    mlsize_t buffer_size;
    char *buffer;
    ssize_t retval;
    struct _FFI_mitls_callbacks *callbacks;
    char *localbuffer;
    
    CAMLparam2(cookie, bytes);
    
    callbacks = (struct _FFI_mitls_callbacks *)ValueToPtr(cookie);
    buffer_size = caml_string_length(bytes);
    localbuffer = (char*)alloca(buffer_size);
    
    caml_release_runtime_system();
    // All pointers into the OCaml heap are now off-limits until the
    // runtime_system lock has been re-aquired.
    retval = (*callbacks->recv)(callbacks, localbuffer, buffer_size);
    caml_acquire_runtime_system();
    
    buffer = Bp_val(bytes);
    memcpy(buffer, localbuffer, buffer_size);
    
    CAMLreturn(Val_int(retval));
}

// Called by the host app to create a TLS connection.
int FFI_mitls_connect(struct _FFI_mitls_callbacks *callbacks, /* in */ mitls_state *state, /* out */ char **outmsg, /* out */ char **errmsg)
{
    CAMLparam0();
    CAMLlocal1(result);
    int ret;
    
    *outmsg = NULL;
    *errmsg = NULL;
    
    caml_acquire_runtime_system();
    result = caml_callback2_exn(*g_mitls_FFI_Connect, state->fstar_state, PtrToValue(callbacks));
    if (Is_exception_result(result)) {
        // Call caml_format_exception(Extract_exception(result)) to extract the exception text
        ret = 0;
    } else {
        // Connect returns back (Connection.connection * int)
        value connection = Field(result,0);
        ret = Int_val(Field(result,1));
        if (ret == 0) {
            caml_modify_generational_global_root(&state->fstar_state, connection);
            ret = 1;
        } else {
            ret = 0;
        }
    }
    caml_release_runtime_system();
    CAMLreturnT(int,ret);
}

// Called by the host server app, after a client has connected to a socket and the calling server has accepted the TCP connection.
int FFI_mitls_accept_connected(struct _FFI_mitls_callbacks *callbacks, /* in */ mitls_state *state, /* out */ char **outmsg, /* out */ char **errmsg)
{
    CAMLparam0();
    CAMLlocal1(result);
    int ret;

    *outmsg = NULL;
    *errmsg = NULL;

    caml_acquire_runtime_system();
    result = caml_callback2_exn(*g_mitls_FFI_AcceptConnected, state->fstar_state, PtrToValue(callbacks));
    if (Is_exception_result(result)) {
        // Call caml_format_exception(Extract_exception(result)) to extract the exception text
        ret = 0;
    } else {
        // AcceptConnected returns back (Connection.connection * int)
        value connection = Field(result,0);
        ret = Int_val(Field(result,1));
        if (ret == 0) {
            caml_modify_generational_global_root(&state->fstar_state, connection);
            ret = 1;
        } else {
            ret = 0;
        }
    }
    caml_release_runtime_system();
    CAMLreturnT(int,ret);
}

// Called by the host app transmit a packet
int FFI_mitls_send(/* in */ mitls_state *state, const void* buffer, size_t buffer_size, /* out */ char **outmsg, /* out */ char **errmsg)
{
    CAMLparam0();
    CAMLlocal2(buffer_value, result);
    int ret = 0;

    *outmsg = NULL;
    *errmsg = NULL;
    
    caml_acquire_runtime_system();
    buffer_value = caml_alloc_string(buffer_size);
    memcpy(Bp_val(buffer_value), buffer, buffer_size);
    
    result = caml_callback2_exn(*g_mitls_FFI_Send, state->fstar_state, buffer_value);
    if (Is_exception_result(result)) {
        // Call caml_format_exception(Extract_exception(result)) to extract the exception text
        ret = 0;
    } else {
        ret = 1;
    }
    caml_release_runtime_system();
    
    CAMLreturnT(int,ret);
}

// Called by the host app to receive a packet
void * FFI_mitls_receive(/* in */ mitls_state *state, /* out */ size_t *packet_size, /* out */ char **outmsg, /* out */ char **errmsg)
{
    CAMLparam0();
    CAMLlocal1(result);
    void *p = NULL;

    *outmsg = NULL;
    *errmsg = NULL;

    caml_acquire_runtime_system();
    result = caml_callback_exn(*g_mitls_FFI_Recv, state->fstar_state);
    if (Is_exception_result(result)) {
        // call caml_format_exception(Extract_exception(result)) to extract the exception text
        p = NULL;
    } else {
        // Return the plaintext data
        p = copypacket(result, packet_size);
    }
    caml_release_runtime_system();
    
    CAMLreturnT(void*,p);
}


// Register the calling thread, so it can call miTLS.  Returns 1 for success, 0 for error.
int FFI_mitls_thread_register(void)
{
    return caml_c_thread_register();
}

// Unregister the calling thread, so it can no longer call miTLS.  Returns 1 for success, 0 for error.
int FFI_mitls_thread_unregister(void)
{
    return caml_c_thread_unregister();
}
