
//**********************************************************************************************************************************
//
//   Purpose: TESTER OBJECT source code file
//
//   Project: Everest
//
//  Filename: SimpleServer.cpp
//
//   Authors: Caroline.M.Mathieson (CMM)
//
//**********************************************************************************************************************************
//
//  Description
//  -----------
//
//! \file SimpleServer.cpp
//! \brief Contains an implementation of simple server to allow monitoring of protocol exchanges.
//!
//**********************************************************************************************************************************

#include "Tester.h" // pulls in everything else

//**********************************************************************************************************************************

FILE *ConsoleCopyFile = NULL;

void OpenConsoleCopyFile ( void )
{
    ConsoleCopyFile = fopen ( "ConsoleCopyFile.txt", "wt" );
}

void CloseConsoleCopyFile ( void )
{
    fclose ( ConsoleCopyFile );
}

#define CONSOL1( a );                printf ( a );                fprintf ( ConsoleCopyFile, a );
#define CONSOL2( a, b );             printf ( a, b );             fprintf ( ConsoleCopyFile, a, b );
#define CONSOL3( a, b, c );          printf ( a, b, c );          fprintf ( ConsoleCopyFile, a, b, c );
#define CONSOL4( a, b, c, d  );      printf ( a, b, c, d  );      fprintf ( ConsoleCopyFile, a, b, c, d  );
#define CONSOL5( a, b, c, d, e );    printf ( a, b, c, d, e );    fprintf ( ConsoleCopyFile, a, b, c, d, e );
#define CONSOL6( a, b, c, d, e, f ); printf ( a, b, c, d, e, f ); fprintf ( ConsoleCopyFile, a, b, c, d, e, f );

//**********************************************************************************************************************************

const char *COLOUR_DEFAULT       = "\033[0;0m";
const char *COLOUR_UNDERLINE_ON  = "\033[0;4m";
const char *COLOUR_UNDERLINE_OFF = "\033[0;24m";

const char *COLOUR_BLACK   = "\033[0;30m";
const char *COLOUR_RED     = "\033[0;31m";
const char *COLOUR_GREEN   = "\033[0;32m";
const char *COLOUR_YELLOW  = "\033[0;33m";
const char *COLOUR_BLUE    = "\033[0;34m";
const char *COLOUR_MAGENTA = "\033[0;35m";
const char *COLOUR_CYAN    = "\033[0;36m";
const char *COLOUR_WHITE   = "\033[0;37m";

const char *COLOUR_BRIGHTBLACK   = "\033[0;90m";
const char *COLOUR_BRIGHTRED     = "\033[0;91m";
const char *COLOUR_BRIGHTGREEN   = "\033[0;92m";
const char *COLOUR_BRIGHTYELLOW  = "\033[0;93m";
const char *COLOUR_BRIGHTBLUE    = "\033[0;94m";
const char *COLOUR_BRIGHTMAGENTA = "\033[0;95m";
const char *COLOUR_BRIGHTCYAN    = "\033[0;96m";
const char *COLOUR_BRIGHTWHITE   = "\033[0;97m";

const char *CHARACTER_SET_ASCII = "\033(B";
const char *CHARACTER_SET_DEC   = "\033(0";

//**********************************************************************************************************************************
/*
Box Drawing Characters in dec mode
hex   ascii DEC (nearest unicode equivalent)
0x6a	j	┘ bottom right corner
0x6b	k	┐ top right corner
0x6c	l	┌ top left corner
0x6d	m	└ bottom left corner
0x6e	n	┼ crossbar
0x71	q	─ horizontal bar
0x74	t	├ vertical inset left
0x75	u	┤ vertical inset right
0x76	v	┴ horizontal inset bottom
0x77	w	┬ horizontal inset top
0x78	x	│ vertical bar
*/

//**********************************************************************************************************************************

EXTENSION_TYPE_ENTRY ExtensionTypeDescriptionTable [] = //  https://www.iana.org/assignments/tls-extensiontype-values/tls-extensiontype-values.xhtml
{
    TLS_ET_SERVER_NAME,                                    "TLS_ET_SERVER_NAME",                             "Server name Indicator",
    TLS_ET_MAX_FRAGMENT_LENGTH,                            "TLS_ET_MAX_FRAGMENT_LENGTH",                     "Max Fragment Length",
    TLS_ET_CLIENT_CERTIFICATE_URL,                         "TLS_ET_CLIENT_CERTIFICATE_URL",                  "Client Certificate URL",
    TLS_ET_TRUSTED_CA_KEYS,                                "TLS_ET_TRUSTED_CA_KEYS",                         "Trusted Certiciate Authority Keys",
    TLS_ET_TRUNCATED_HMAC,                                 "TLS_ET_TRUNCATED_HMAC",                          "Truncated HMAC",
    TLS_ET_STATUS_REQUEST,                                 "TLS_ET_STATUS_REQUEST",                          "Status Request",
    TLS_ET_USER_MAPPING,                                   "TLS_ET_USER_MAPPING",                            "User mapping",
    TLS_ET_CLIENT_AUTHZ,                                   "TLS_ET_CLIENT_AUTHZ",                            "Client Authorisation",
    TLS_ET_SERVER_AUTHZ,                                   "TLS_ET_SERVER_AUTHZ",                            "Server Authorisation",
    TLS_ET_CERT_TYPE,                                      "TLS_ET_CERT_TYPE",                               "Certificate Type",
    TLS_ET_SUPPORTED_GROUPS,                               "TLS_ET_SUPPORTED_GROUPS",                        "Supported Groups",
    TLS_ET_EC_POINT_FORMATS,                               "TLS_ET_EC_POINT_FORMATS",                        "Eliptic Curve Point Formats",
    TLS_ET_SRP,                                            "TLS_ET_SRP",                                     "Secure Remote Password",
    TLS_ET_SIGNATURE_ALGORITHMS,                           "TLS_ET_SIGNATURE_ALGORITHMS",                    "Signature Algorithms",
    TLS_ET_USE_SRTP,                                       "TLS_ET_USE_SRTP",                                "Use Secure RTP",
    TLS_ET_HEARTBEAT,                                      "TLS_ET_HEARTBEAT",                               "Heartbeat",
    TLS_ET_APPLICATION_LAYER_PROTOCOL_NEGOTIATION,         "TLS_ET_APPLICATION_LAYER_PROTOCOL_NEGOTIATION",  "Application Layer Protocol Negotiation",
    TLS_ET_STATUS_REQUEST_V2,                              "TLS_ET_STATUS_REQUEST_V2",                       "Status Request V2",
    TLS_ET_SIGNED_CERTIFICATE_TIMESTAMP,                   "TLS_ET_SIGNED_CERTIFICATE_TIMESTAMP",            "Signed Certificate Timestamp",
    TLS_ET_CLIENT_CERTIFICATE_TYPE,                        "TLS_ET_CLIENT_CERTIFICATE_TYPE",                 "Client Certificate Type",
    TLS_ET_SERVER_CERTIFICATE_TYPE,                        "TLS_ET_SERVER_CERTIFICATE_TYPE",                 "Server Certificate Type",
    TLS_ET_PADDING,                                        "TLS_ET_PADDING",                                 "Padding",
    TLS_ET_ENCRYPT_THEN_MAC,                               "TLS_ET_ENCRYPT_THEN_MAC",                        "Encrypt The MAC",
    TLS_ET_EXTENDED_MASTER_SECRET,                         "TLS_ET_EXTENDED_MASTER_SECRET",                  "Extended Master Secret",
    TLS_ET_TOKEN_BINDING,                                  "TLS_ET_TOKEN_BINDING",                           "Token Binding",
    TLS_ET_CACHED_INFO,                                    "TLS_ET_CACHED_INFO",                             "Cached Information",
    TLS_ET_QUIC_TRANSPORT_PARAMETERS,                      "TLS_ET_QUIC_TRANSPORT_PARAMETERS",               "QUIC Transport Parameters (new)",
    TLS_ET_COMPRESS_CERTIFICATE,                           "TLS_ET_COMPRESS_CERTIFICATE",                    "Compress Certificate",
    TLS_ET_RECORD_SIZE_LIMIT,                              "TLS_ET_RECORD_SIZE_LIMIT",                       "Record Size Limit",
    TLS_ET_SESSIONTICKET,                                  "TLS_ET_SESSIONTICKET",                           "Session Ticket",
    TLS_ET_KEY_SHARE,                                      "TLS_ET_KEY_SHARE",                               "Key Share",
    TLS_ET_PRE_SHARED_KEY,                                 "TLS_ET_PRE_SHARED_KEY",                          "Pre-Shared Key",
    TLS_ET_EARLY_DATA,                                     "TLS_ET_EARLY_DATA",                              "Early Data",
    TLS_ET_SUPPORTED_VERSIONS,                             "TLS_ET_SUPPORTED_VERSIONS",                      "Supported Versions",
    TLS_ET_COOKIE,                                         "TLS_ET_COOKIE",                                  "Cookie",
    TLS_ET_PSK_KEY_EXCHANGE_MODES,                         "TLS_ET_PSK_KEY_EXCHANGE_MODES",                  "PSK Key Exchange Modes",
    TLS_ET_CERTIFICATE_AUTHORITIES,                        "TLS_ET_CERTIFICATE_AUTHORITIES",                 "Certificate Authorities",
    TLS_ET_OID_FILTERS,                                    "TLS_ET_OID_FILTERS",                             "Object ID Filters",
    TLS_ET_POST_HANDSHAKE_AUTH,                            "TLS_ET_POST_HANDSHAKE_AUTH",                     "Post Handshake Authentitation",
    TLS_ET_SIGNATURE_ALGORITHMS_CERT,                      "TLS_ET_SIGNATURE_ALGORITHMS_CERT",               "Signature Algorithm Certificate",
    TLS_ET_KEY_SHARE,                                      "TLS_ET_KEY_SHARE",                               "Key Share",

     // Generate Random Extensions And Sustain Extensibility (Google). See https://tools.ietf.org/html/draft-davidben-tls-grease-01#section-5 page 4.

    TLS_ET_RESERVED_GREASE_0,                              "TLS_ET_RESERVED_GREASE_0",                       "GREASE protocol random extension 0",
    TLS_ET_RESERVED_GREASE_1,                              "TLS_ET_RESERVED_GREASE_1",                       "GREASE protocol random extension 1",
    TLS_ET_RESERVED_GREASE_2,                              "TLS_ET_RESERVED_GREASE_2",                       "GREASE protocol random extension 2",
    TLS_ET_RESERVED_GREASE_3,                              "TLS_ET_RESERVED_GREASE_3",                       "GREASE protocol random extension 3",
    TLS_ET_RESERVED_GREASE_4,                              "TLS_ET_RESERVED_GREASE_4",                       "GREASE protocol random extension 4",
    TLS_ET_RESERVED_GREASE_5,                              "TLS_ET_RESERVED_GREASE_5",                       "GREASE protocol random extension 5",
    TLS_ET_RESERVED_GREASE_6,                              "TLS_ET_RESERVED_GREASE_6",                       "GREASE protocol random extension 6",
    TLS_ET_RESERVED_GREASE_7,                              "TLS_ET_RESERVED_GREASE_7",                       "GREASE protocol random extension 7",
    TLS_ET_RESERVED_GREASE_8,                              "TLS_ET_RESERVED_GREASE_8",                       "GREASE protocol random extension 8",
    TLS_ET_RESERVED_GREASE_9,                              "TLS_ET_RESERVED_GREASE_9",                       "GREASE protocol random extension 9",
    TLS_ET_RESERVED_GREASE_A,                              "TLS_ET_RESERVED_GREASE_A",                       "GREASE protocol random extension A",
    TLS_ET_RESERVED_GREASE_B,                              "TLS_ET_RESERVED_GREASE_B",                       "GREASE protocol random extension B",
    TLS_ET_RESERVED_GREASE_C,                              "TLS_ET_RESERVED_GREASE_C",                       "GREASE protocol random extension C",
    TLS_ET_RESERVED_GREASE_D,                              "TLS_ET_RESERVED_GREASE_D",                       "GREASE protocol random extension D",
    TLS_ET_RESERVED_GREASE_E,                              "TLS_ET_RESERVED_GREASE_E",                       "GREASE protocol random extension E",
    TLS_ET_RESERVED_GREASE_F,                              "TLS_ET_RESERVED_GREASE_F",                       "GREASE protocol random extension F",

    TLS_ET_RENEGOTIATION_INFO,                             "TLS_ET_RENEGOTIATION_INFO",                      "Renegotioation Information",

    TLS_ET_UNDEFINED_EXTENSION_TYPE,                       "TLS_ET_UNDEFINED_EXTENSION_TYPE",                "Undefined Extension Type",
};

//**********************************************************************************************************************************

ALERT_DESCRIPTION_ENTRY AlertDescriptionTable [] =
{
    TLS_AD_CLOSE_NOTIFY,                    "TLS_AD_CLOSE_NOTIFY",                    "Close Notify",
    TLS_AD_UNEXPECTED_MESSAGE,              "TLS_AD_UNEXPECTED_MESSAGE",              "Unexpected Message",
    TLS_AD_BAD_RECORD_MAC,                  "TLS_AD_BAD_RECORD_MAC",                  "Bad Record MAC",
    TLS_AD_DECRYPTION_FAILED_RESERVED,      "TLS_AD_DECRYPTION_FAILED_RESERVED",      "Decryption Failed Reservered",
    TLS_AD_RECORD_OVERFLOW,                 "TLS_AD_RECORD_OVERFLOW",                 "Record Overflow",
    TLS_AD_DECOMPRESSION_FAILURE,           "TLS_AD_DECOMPRESSION_FAILURE",           "Decompression Failure",
    TLS_AD_HANDSHAKE_FAILURE,               "TLS_AD_HANDSHAKE_FAILURE",               "Handshake Failure",
    TLS_AD_NO_CERTIFICATE_RESERVED,         "TLS_AD_NO_CERTIFICATE_RESERVED",         "No Certificate Reserved",
    TLS_AD_BAD_CERTIFICATE,                 "TLS_AD_BAD_CERTIFICATE",                 "Bad Certificate",
    TLS_AD_UNSUPPORTED_CERTIFICATE,         "TLS_AD_UNSUPPORTED_CERTIFICATE",         "Unsupported Certificate",
    TLS_AD_CERTIFICATE_REVOKED,             "TLS_AD_CERTIFICATE_REVOKED",             "Certificate Revoked",
    TLS_AD_CERTIFICATE_EXPIRED,             "TLS_AD_CERTIFICATE_EXPIRED",             "Certificate Expired",
    TLS_AD_CERTIFICATE_UNKNOWN,             "TLS_AD_CERTIFICATE_UNKNOWN",             "Certificate Unknown",
    TLS_AD_ILLEGAL_PARAMETER,               "TLS_AD_ILLEGAL_PARAMETER",               "Illegal Parameter",
    TLS_AD_UNKNOWN_CA,                      "TLS_AD_UNKNOWN_CA",                      "Unknown Certificate Authority",
    TLS_AD_ACCESS_DENIED,                   "TLS_AD_ACCESS_DENIED",                   "Access Denied",
    TLS_AD_DECODE_ERROR,                    "TLS_AD_DECODE_ERROR",                    "Decode Error",
    TLS_AD_DECRYPT_ERROR,                   "TLS_AD_DECRYPT_ERROR",                   "Decryption Error",
    TLS_AD_EXPORT_RESTRICTION_RESERVED,     "TLS_AD_EXPORT_RESTRICTION_RESERVED",     "Export Restriction Reserved",
    TLS_AD_PROTOCOL_VERSION,                "TLS_AD_PROTOCOL_VERSION",                "Protocol Version",
    TLS_AD_INSUFFICIENT_SECURITY,           "TLS_AD_INSUFFICIENT_SECURITY",           "Insufficient Security",
    TLS_AD_INTERNAL_ERROR,                  "TLS_AD_INTERNAL_ERROR",                  "Internal Error",
    TLS_AD_USER_CANCELED,                   "TLS_AD_USER_CANCELED",                   "User Cancelled",
    TLS_AD_NO_RENEGOTIATION,                "TLS_AD_NO_RENEGOTIATION",                "No Renegotiation",
    TLS_AD_UNSUPPORTED_EXTENSION,           "TLS_AD_UNSUPPORTED_EXTENSION",           "Unsupported Extension",
    TLS_AD_CERTIFICATE_UNOBTAINABLE,        "TLS_AD_CERTIFICATE_UNOBTAINABLE",        "Certificate Unobtainable",
    TLS_AD_UNRECOGNIZED_NAME,               "TLS_AD_UNRECOGNIZED_NAME",               "Unrecognized Name",
    TLS_AD_BAD_CERTIFICATE_STATUS_RESPONSE, "TLS_AD_BAD_CERTIFICATE_STATUS_RESPONSE", "Bad Certificate Status Response",
    TLS_AD_BAD_CERTIFICATE_HASH_VALUE,      "TLS_AD_BAD_CERTIFICATE_HASH_VALUE",      "Bad Certificate Hash Value",
    TLS_AD_UNKNOWN,                         "TLS_AD_UNKNOWN",                         "Unknown Alert Code"
};

//**********************************************************************************************************************************

// these are in client hello and mitls debug but names don't quite match list below!
//"TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256:"
//"TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256:"
//"TLS_DHE_RSA_WITH_CHACHA20_POLY1305_SHA256"

CIPHER_SUITE_DESCRIPTION_ENTRY CipherSuiteDescriptionTable [] =
{
//  Enumerated Type                          "Name"                                     Supported  Value
//  ----------------------------------------------------------------------------------------------------
    TLS_RSA_WITH_RC4_128_SHA,                "TLS_RSA_WITH_RC4_128_SHA",                FALSE, // 0x0005
    TLS_RSA_WITH_3DES_EDE_CBC_SHA,           "TLS_RSA_WITH_3DES_EDE_CBC_SHA",           FALSE, // 0x000A
    TLS_RSA_WITH_AES_128_CBC_SHA,            "TLS_RSA_WITH_AES_128_CBC_SHA",            FALSE, // 0x002F
    TLS_DH_DSS_WITH_AES_128_CBC_SHA,         "TLS_DH_DSS_WITH_AES_128_CBC_SHA",         FALSE, // 0x0030
    TLS_DH_RSA_WITH_AES_128_CBC_SHA,         "TLS_DH_RSA_WITH_AES_128_CBC_SHA",         FALSE, // 0x0031
    TLS_DHE_DSS_WITH_AES_128_CBC_SHA,        "TLS_DHE_DSS_WITH_AES_128_CBC_SHA",        FALSE, // 0x0032
    TLS_DHE_RSA_WITH_AES_128_CBC_SHA,        "TLS_DHE_RSA_WITH_AES_128_CBC_SHA",        FALSE, // 0x0033
    TLS_DH_ANON_WITH_AES_128_CBC_SHA,        "TLS_DH_ANON_WITH_AES_128_CBC_SHA",        FALSE, // 0x0034
    TLS_RSA_WITH_AES_256_CBC_SHA,            "TLS_RSA_WITH_AES_256_CBC_SHA",            FALSE, // 0x0035
    TLS_DH_DSS_WITH_AES_256_CBC_SHA,         "TLS_DH_DSS_WITH_AES_256_CBC_SHA",         FALSE, // 0x0036
    TLS_DH_RSA_WITH_AES_256_CBC_SHA,         "TLS_DH_RSA_WITH_AES_256_CBC_SHA",         FALSE, // 0x0037
    TLS_DHE_DSS_WITH_AES_256_CBC_SHA,        "TLS_DHE_DSS_WITH_AES_256_CBC_SHA",        FALSE, // 0x0038
    TLS_DHE_RSA_WITH_AES_256_CBC_SHA,        "TLS_DHE_RSA_WITH_AES_256_CBC_SHA",        FALSE, // 0x0039
    TLS_DH_ANON_WITH_AES_256_CBC_SHA,        "TLS_DH_ANON_WITH_AES_256_CBC_SHA",        FALSE, // 0x003A
    TLS_RSA_WITH_AES_128_CBC_SHA256,         "TLS_RSA_WITH_AES_128_CBC_SHA256",         FALSE, // 0x003C
    TLS_RSA_WITH_AES_128_GCM_SHA256,         "TLS_RSA_WITH_AES_128_GCM_SHA256",         FALSE, // 0x009C
    TLS_RSA_WITH_AES_256_GCM_SHA384,         "TLS_RSA_WITH_AES_256_GCM_SHA384",         FALSE, // 0x009D
    TLS_DHE_DSS_WITH_AES_128_GCM_SHA256,     "TLS_DHE_DSS_WITH_AES_128_GCM_SHA256",     TRUE,  // 0x00A2
    TLS_DHE_RSA_WITH_AES_128_GCM_SHA256,     "TLS_DHE_RSA_WITH_AES_128_GCM_SHA256",     FALSE, // 0x009E
    TLS_DHE_RSA_WITH_AES_256_GCM_SHA384,     "TLS_DHE_RSA_WITH_AES_256_GCM_SHA384",     TRUE,  // 0x009F
    TLS_EMPTY_RENEGOTIATION_INFO_SCSV,       "TLS_EMPTY_RENEGOTIATION_INFO_SCSV",       FALSE, // 0x00FF
    TLS_AES_128_GCM_SHA256,                  "TLS_AES_128_GCM_SHA256",                  TRUE,  // 0x1301
    TLS_AES_256_GCM_SHA384,                  "TLS_AES_256_GCM_SHA384",                  TRUE,  // 0x1302
    TLS_CHACHA20_POLY1305_SHA256,            "TLS_CHACHA20_POLY1305_SHA256",            TRUE,  // 0x1303
    TLS_AES_128_CCM_SHA256,                  "TLS_AES_128_CCM_SHA256",                  FALSE, // 0x1304
    TLS_AES_128_CCM_8_SHA256,                "TLS_AES_128_CCM_8_SHA256",                FALSE, // 0x1305
    TLS_RESERVED_GREASE,                     "Reserved (GREASE)",                       FALSE, // 0x6A6A
    TLS_ECDHE_ECDSA_WITH_RC4_128_SHA,        "TLS_ECDHE_ECDSA_WITH_RC4_128_SHA",        FALSE, // 0xC007
    TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA,    "TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA",    FALSE, // 0xC009
    TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA,    "TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA",    FALSE, // 0xC00A
    TLS_ECDHE_RSA_WITH_RC4_128_SHA,          "TLS_ECDHE_RSA_WITH_RC4_128_SHA",          FALSE, // 0xC011
    TLS_ECDHE_RSA_WITH_3DES_EDE_CBC_SHA,     "TLS_ECDHE_RSA_WITH_3DES_EDE_CBC_SHA",     FALSE, // 0xC012
    TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA,      "TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA",      FALSE, // 0xC013
    TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA,      "TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA",      FALSE, // 0xC014
    TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA256, "TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA256", FALSE, // 0xC023
    TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256,   "TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256",   TRUE,  // 0xC027
    TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,   "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256",   FALSE, // 0xC02F
    TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256, "TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256", TRUE,  // 0xC02B
    TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,   "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384",   TRUE,  // 0xC030
    TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384, "TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384", TRUE,  // 0xC02C
    TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305,    "TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305",    FALSE, // 0xCCA8
    TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305,  "TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305",  FALSE, // 0xCCA9
    TLS_DHE_RSA_WITH_CHACHA20_POLY1305,      "TLS_DHE_RSA_WITH_CHACHA20_POLY1305",      FALSE, // 0xCCAA
    TLS_CIPHER_SUITE_UNDEFINED,              "TLS_CIPHER_SUITE_UNDEFINED",              FALSE, // 0xFFFF
};

//**********************************************************************************************************************************

SIGNATURE_ALGORITHM_DESCRIPTION_ENTRY SignatureAlgorithmDescriptionTable [] = // in numerical order
{
//  Enumerated Type                "Name"                           Supported  Value
//  --------------------------------------------------------------------------------
    TLS_SA_RSA_PKCS1_SHA1,         "TLS_SA_RSA_PKCS1_SHA1",         FALSE, // 0x0201
    TLS_SA_DSA_SHA1,               "TLS_SA_DSA_SHA1",               FALSE, // 0x0202
    TLS_SA_ECDSA_SHA1,             "TLS_SA_ECDSA_SHA1",             FALSE, // 0x0203
    TLS_SA_DSA_SHA224,             "TLS_SA_DSA_SHA224",             FALSE, // 0x0302
    TLS_SA_RSA_PKCS1_SHA256,       "TLS_SA_RSA_PKCS1_SHA256",       FALSE, // 0x0401
    TLS_SA_DSA_SHA256,             "TLS_SA_DSA_SHA256",             FALSE, // 0x0402
    TLS_SA_ECDSA_SECP256R1_SHA256, "TLS_SA_ECDSA_SECP256R1_SHA256", TRUE,  // 0x0403 "ECDSA+SHA256" may be expected name
    TLS_SA_RSA_PKCS1_SHA384,       "TLS_SA_RSA_PKCS1_SHA384",       FALSE, // 0x0501
    TLS_SA_DSA_SHA384,             "TLS_SA_DSA_SHA384",             FALSE, // 0x0502
    TLS_SA_ECDSA_SECP384R1_SHA384, "TLS_SA_ECDSA_SECP384R1_SHA384", TRUE,  // 0x0503 "ECDSA+SHA384" may be expected name
    TLS_SA_RSA_PKCS1_SHA512,       "TLS_SA_RSA_PKCS1_SHA512",       FALSE, // 0x0601
    TLS_SA_DSA_SHA512,             "TLS_SA_DSA_SHA512",             FALSE, // 0x0602
    TLS_SA_ECDSA_SECP521R1_SHA512, "TLS_SA_ECDSA_SECP521R1_SHA512", TRUE,  // 0x0603 "ECDSA+SHA512" may be expected name
    TLS_SA_RSA_PSS_SHA256,         "TLS_SA_RSA_PSS_SHA256",         FALSE, // 0x0804
    TLS_SA_RSA_PSS_SHA384,         "TLS_SA_RSA_PSS_SHA384",         FALSE, // 0x0805
    TLS_SA_RSA_PSS_SHA512,         "TLS_SA_RSA_PSS_SHA512",         FALSE, // 0x0806
    TLS_SA_ED25519,                "TLS_SA_ED25519",                FALSE, // 0x0807
    TLS_SA_ED448,                  "TLS_SA_ED448",                  FALSE, // 0x0808

    TLS_SA_UNDEFINED, "TLS_SA_UNDEFINED", FALSE // 0xFFFF
};

//**********************************************************************************************************************************

NAMED_GROUP_DESCRIPTION_ENTRY NamedGroupDescriptionTable [] =
{
//  Enumerated Type   LoggingName         "ExpectedName" Supported  Value
//  ----------------------------------------------------------------------------------------------------
    TLS_NG_SECP256R1, "TLS_NG_SECP256R1", "P-256",     TRUE,  //= 0x0017
    TLS_NG_SECP384R1, "TLS_NG_SECP384R1", "P-384",     TRUE,  //= 0x0018
    TLS_NG_SECP521R1, "TLS_NG_SECP521R1", "P-521",     TRUE,  //= 0x0019
    TLS_NG_X25519,    "TLS_NG_X25519",    "x25519",    TRUE,  //= 0x001D
    TLS_NG_X448,      "TLS_NG_X448",      "x448",      FALSE, //= 0x001E
    TLS_NG_FFDHE2048, "TLS_NG_FFDHE2048", "ffdhe2048", TRUE,  //= 0x0100
    TLS_NG_FFDHE3072, "TLS_NG_FFDHE3072", "ffdhe3072", TRUE,  //= 0x0101
    TLS_NG_FFDHE4096, "TLS_NG_FFDHE4096", "ffdhe4096", TRUE,  //= 0x0102
    TLS_NG_FFDHE6144, "TLS_NG_FFDHE6144", "ffdhe6144", FALSE, //= 0x0103
    TLS_NG_FFDHE8192, "TLS_NG_FFDHE8192", "ffdhe8192", FALSE, //= 0x0104
    TLS_NG_UNDEFINED, "TLS_NG_UNDEFINED", "unknown",   FALSE  //  0xFFFF
};

// taken from tlsparser.py
//NAME                    = "Name"
//INTERPRETATION          = "Interpretation"
//RAW_CONTENTS            = "RawContents"
//DIRECTION               = "Direction"
//GROUP_NAME              = "GroupName"
//VERSION_ID              = "VersionID"
//KEY_SHARE               = "KeyShare"
//KEY_SHARE_ENTRY         = "KeyShareEntry"
//SIGNATURE_ALGORITHM     = "SignatureAlgorithm"
//CIPHER_SUITE            = "CipherSuite"
//RECORD_TYPE             = "Record type"
//PROTOCOL                = "Protocol"
//ALERT                   = "Alert"
//LENGTH                  = "Length"
//RAW_RECORD              = "Raw record"
//HANDSHAKE_TYPE          = "HandshakeType"
//HANDSHAKE_MSG           = "Handshake message"
//RANDOM                  = "Random"
//LEGACY_ID               = "LegacySessionID"
//CIPHER_SUITES           = "Cipher suites"
//LEGACY_COMPRESSION      = "Legacy compression"
//EXTENSIONS              = "Extensions"
//RECORD                  = "Record"
//SELECTED_CIPHER_SUITE   = "Selected cipher suite"
//RAW_MSG                 = "Raw message"
//DECRYPTED_RECORD_TYPE   = "Decrypted record type"
//DECRYPTED_RECORD        = "Decrypted record"
//REQUEST_CONTEXT         = "RequestContext"
//RAW_CERTIFICATE         = "RawCertificate"
//CERT_ENTRY              = "CertificateEntry"
//CERTIFICATES            = "Certificates"
//CERTIFICATE             = "Certificate"
//OPAQUE_CERT             = "OpaqueCert"
//CERTIFICATE_LIST        = "CertificateList"
//CERTIFICATE_VERIFY      = "CertificateVerify"
//SIGNATURE_SCHEME        = "Signature scheme"
//SIGNATURE               = "Signature"
//IV_AND_KEY              = "IV and Key"
//PARENT_NODE             = "ParentNode"
//SWAP_ITEMS              = "SwapItems"
//EXTRACT_TO_PLAINTEXT    = "ExtractToPlaintext"
//REMOVE_ITEM             = "RemoveItem"
//PSK_IDENTITIES          = "PSK_Identities"
//PSK_BINDERS             = "PSK_Binder"
//TICKET_AGE              = "TicketAge"
//PSK_IDENTITY            = "PSK_Identity"
//PSK_OPAQUE_IDENTITY     = "PSK Opaque Identity"
//BINDER                  = "Binder"
//PSK                     = "Preshared Key"
//PSK_SELECTED_IDENTITY   = "Selected PSK"
//TICKET_LIFETIME         = "ticket_lifetime"
//TICKET_AGE_ADD          = "ticket_age_add"
//TICKET                  = "ticket"
//TICKET_NONCE            = "ticket_nonce"
//NEW_SESSION_TICKET      = "NewSessionTicket"
//MAX_EARLY_DATA_SIZE     = "max_early_data_size"
//DELAY_COUNT             = "DelayMsgCount"
//PSK_MODE                = "PSK_Mode"
//
//LEAKED_KEYS_DIR     = "leaked_keys"

//**********************************************************************************************************************************

const char ContentTypeComment       [] = "       Content Type = %d (%s)\n";
const char ProtocolVersionComment   [] = "   Protocol Version = %d.%d (%s)\n";
const char ContentLengthComment     [] = "     Content Length = %u octets\n";
const char MessageTypeComment       [] = "       Message Type = %d (%s)\n";
const char MessageLengthComment     [] = "     Message Length = %02X %02X %02X (%u octets)\n";

const char HelloVersionComment             [] = "              Hello Version = %d.%d (%s)\n";
const char RandomUnixTimeComment           [] = "             RandomUnixTime = %u seconds since Jan 1st 1970\n";
const char RandomValueComment              [] = "               Random Value = %s\n";
const char SessionIdentifierLengthComment  [] = "   Session Identifer length = %d\n";
const char SessionIdentifierComment        [] = "          Session Identifer = %s\n";
const char CipherSuitesLengthComment       [] = "       Cipher Suites Length = %d octets\n";
const char CipherSuiteComment              [] = "               Cipher Suite = 0x%04X (%s)\n";
const char CipherSuiteNumberComment        [] = "               Cipher Suite = [%2d] 0x%04X (%s)\n";
const char CompressionMethodsLengthComment [] = " Compression Methods Length = %d octets\n";
const char CompressionMethodComment        [] = "         Compression Method = %d\n";
const char CompressionMethodsComment       [] = "         Compression Method = [%2d] %d\n";
const char ExtensionsLengthComment         [] = "          Extensions Length = %d octets\n";

const char ExtensionTypeComment                          [] = "               Extension Type = %d (%s)\n";
const char ExtensionLengthComment                        [] = "             Extension Length = %d octets\n";
const char ExtensionDataComment                          [] = "               Extension Data = "; // no newline!
const char ExtensionSupportedVersionLengthComment        [] = "     Supported Version Length = %d octets (%d versions)\n";
const char ExtensionSupportedVersionComment              [] = "       Supported Version [%2d] = 0x%04X (%s)\n";
const char ExtensionClientKeyShareLengthComment          [] = "      Client Key Share Length = %d octets\n";
const char ExtensionClientKeyShareGroupComment           [] = "       Client Key Share Group = 0x%04X (%s)\n";
const char ExtensionClientKeyShareKeyLengthComment       [] = "  Client Key Share Key Length = %d octets\n";
const char ExtensionClientKeyShareKeyComment             [] = "         Client Key Share Key = "; // no newline!
const char ExtensionSignatureHashAlgorithmsLengthComment [] = "       Hash Algorithms Length = %d octets (%d algorithms)\n";
const char ExtensionSignatureHashAlgorithmComment        [] = "          Hash Algorithm [%2d] = 0x%04X (%s)\n";
const char ExtensionSupportedNamedGroupsLengthComment    [] = "      Supported Groups Length = %d octets (%d Groups)\n";
const char ExtensionSupportedNamedGroupComment           [] = "            Named Group [%2d] = 0x%04X (%s)\n";

const char CertificateLengthComment [] = "        Certificate Length = %u octets\n";
const char CertificateComment       [] = " Certificate [ %d ] Length = %u octets\n";

const char AlertLevelComment        [] = "        Alert Level = %d\n";
const char AlertDescriptionComment  [] = "  Alert Description = %d %s\n";

//**********************************************************************************************************************************

#define MAX_DUMP_LINES       (2000)
#define MAX_DUMP_LINE_LENGTH (200)

static char TempLine [ MAX_DUMP_LINE_LENGTH ];

static char OutputLine [ MAX_DUMP_LINES * MAX_DUMP_LINE_LENGTH + 1 ]; // so that printing can be done atomically;

void DumpPacket ( void         *Packet,         // the packet to be hex dumped
                  unsigned int  PacketLength,   // the length of the packet in octets
                  unsigned int  HighlightStart, // the first octet of special interest
                  unsigned int  HighlightEnd,   // the last octet of special interest (0 = none)
                  const char   *Title )         // the purpose of the packet (if known)
{
    unsigned char *PacketPointer            = (unsigned char *) Packet;
    unsigned char  Character                = 0;
    unsigned int   Count                    = 0;
    unsigned int   Index                    = 0;
    unsigned int   OctetCount               = 16; // number of octets to dump in one line
    unsigned int   HighlightStartLineNumber = ( HighlightStart / OctetCount ) * OctetCount; // round down
    unsigned int   HighlightEndLineNumber   = ( HighlightEnd   / OctetCount ) * OctetCount; // round down
    bool           PrintLine                = FALSE;

    memset ( OutputLine, 0, sizeof ( OutputLine ) );

    strcat ( OutputLine, "\n" );

    // if there is a title then print it first

    if ( strlen ( Title ) > 0 )
    {
        sprintf ( TempLine, "%s %s of %u octets %s\n\n", COLOUR_UNDERLINE_ON, Title, PacketLength, COLOUR_DEFAULT );

        strcat ( OutputLine, TempLine );
    }

    // print out the packet in multiple lines with an address field, a hex field and then a character field. If the packet has a
    // highlighted section, then only print the lines containing that section.

    for ( Count = 0; Count < PacketLength; Count += OctetCount )
    {
        // should we print this line at all?

        if ( HighlightEnd == 0 )
        {
            PrintLine = TRUE; // no highlight so print all lines
        }
        else
        {
            // highlight indicated so work out if this line has an octet or octets to be highlighted:
            //
            //    HighlightStartLineNumber <= Count <= HighlightEndLineNumber

            if ( ( Count >= HighlightStartLineNumber ) && ( Count <= HighlightEndLineNumber ) )
            {
                PrintLine = TRUE;
            }
            else
            {
                PrintLine = FALSE;
            }
        }

        if ( PrintLine )
        {
            // ADDRESS PART

            sprintf ( TempLine, "%s0x%04X%s ", COLOUR_BRIGHTGREEN, Count, COLOUR_GREEN );

            strcat ( OutputLine, TempLine );

            // HEX PART

            for ( Index = 0; Index < OctetCount; Index++ )
            {
                Character = PacketPointer [ Index ];

                if ( ( Count + Index ) < PacketLength )
                {
                    // is this octet to be highlighted ?

                    if ( ( ( Count + Index ) >= HighlightStart ) && ( ( Count + Index ) <= HighlightEnd ) && ( HighlightEnd != 0 ) )
                    {
                        sprintf ( TempLine, "%s%02X ", COLOUR_BRIGHTYELLOW, Character );

                        strcat ( OutputLine, TempLine );
                    }
                    else
                    {
                        sprintf ( TempLine, "%s%02X ", COLOUR_GREEN, Character );

                        strcat ( OutputLine, TempLine );
                    }
                }
                else
                {
                    strcat ( OutputLine, "   " );
                }

                if ( ( Index % 8 ) == 7 ) { strcat ( OutputLine, " " );}; // put an extra space between every 8 octets
            }

            // CHARACTER PART

            sprintf ( TempLine, "%s | ", COLOUR_WHITE );

            strcat ( OutputLine, TempLine );

            for ( Index = 0; Index < OctetCount; Index++ )
            {
                Character = PacketPointer [ Index ];

                if ( ( Count + Index ) < PacketLength )
                {
                    // if character not printable then just print a dot "."

                    if ( ( Character > 31 ) && ( Character < 127 ) )
                    {
                        sprintf ( TempLine, "%c", Character );

                        strcat ( OutputLine, TempLine );
                    }
                    else
                    {
                        strcat ( OutputLine, "." );
                    }
                }
                else
                {
                    strcat ( OutputLine, " " );
                }
            }

            sprintf ( TempLine, " |\n%s", COLOUR_DEFAULT );

            strcat ( OutputLine, TempLine );

        } // end if print line

        PacketPointer += OctetCount;

    } // end for count

    CONSOL2 ( "%s\n", OutputLine ); // print the whole array as one string

    //fflush ( stdout );
 }

//**********************************************************************************************************************************
//
// Decode a network packet. A network packet can contain one or more TLS Records as indicated by the ContentLength header field and
// each TLS record can contain one or more messages as indicated by the MessageLength header field within the record. Not all TLS
// records contain messages however. For example the Alert does not contain any.
//

unsigned long DecodePacket ( void       *Packet,
                             size_t      PacketLength,
                             const char *Title )
{
    unsigned char *PacketPointer = (unsigned char *) Packet;
    unsigned char *EndOfPacket   = &PacketPointer [ PacketLength - 1 ];
    unsigned char *RecordPointer = ( unsigned char *) Packet;
    unsigned long  RecordLength  = 0;

    // hex dump the complete packet first

    DumpPacket ( Packet, PacketLength, 0, 0, Title );

    // keep decoding records until the end of the packet is reached or an unknown record is detected

    while ( RecordPointer < EndOfPacket )
    {
        // assume that TLS records are being sent and start to decode them if so by examining the header first

        RecordLength = DecodeRecord ( ( TLS_RECORD * ) RecordPointer );

        if ( RecordLength == 0 ) return ( 0 ); // decode failure so stop decoding records

        // point at the next record based on the size of the decoded one

        RecordPointer += RecordLength;
    }

    return ( (unsigned long) PacketLength );
}

//**********************************************************************************************************************************
//
// A TLS Record consists of the record header followed by one or more handshake records. The ContentLength field specifies how large
// the set of records is, but not how many. So it is necessary to look into each record for the MessageHeader and decode the records
// until the end of the TLSRecord is reached. It is a curious fact that the content length field is only 2 bytes but the message
// length field inside each record is three bytes! This would imply that message fragmentation could occur but there is no mechanism
// to handle this, such as a fragment indicator or a fragment number etc.
//
//  -------------------------------------------------------------
// |                           TLS Record                        |
// |-------------------------------------------------------------|
// |         Record Header         |      Handshake Record(s)    |
// |-------------------------------|-----------------------------|
// | Content |  Protocol | Content | Record |    ...    | Record |
// |  Type   |  Version  | Length  |    1   |           |   N    |
//  -------------------------------------------------------------
//

unsigned long DecodeRecord ( void *Record )
{
    TLS_RECORD    *TLSRecord          = (TLS_RECORD *) Record;
    const char    *TLSProtocolVersion = NULL;
    unsigned char *MessagePointer     = NULL;
    unsigned char *RecordPointer      = (unsigned char *) Record;
    unsigned char *EndOfRecord        = NULL;
    unsigned long  ContentLength      = 0;
    unsigned long  MessageLength      = 0;

    if ( TLSRecord->RecordHeader.ContentType == TLS_CT_HANDSHAKE )
    {
        CONSOL1 ( COLOUR_UNDERLINE_ON );

        CONSOL1 ( "TLS Handshake Record:-\n" );

        CONSOL1 ( COLOUR_DEFAULT );

        CONSOL3 ( ContentTypeComment, TLS_CT_HANDSHAKE, "TLS_CT_HANDSHAKE" );

        // convert numeric version to string version

        TLSProtocolVersion = GetVersionString ( TLSRecord->RecordHeader.ProtocolVersion.MajorVersion,
                                                TLSRecord->RecordHeader.ProtocolVersion.MinorVersion );

        CONSOL4 ( ProtocolVersionComment,
                  TLSRecord->RecordHeader.ProtocolVersion.MajorVersion,
                  TLSRecord->RecordHeader.ProtocolVersion.MinorVersion,
                  TLSProtocolVersion );

        ContentLength = ( TLSRecord->RecordHeader.ContentLengthHigh * 256 ) + TLSRecord->RecordHeader.ContentLengthLow;

        CONSOL2 ( ContentLengthComment, ContentLength );

        EndOfRecord = &RecordPointer [ ContentLength ]; // was ContentLength - 1

        // keep decoding messages until the end of the record is reached or an unknown message is detected

        MessagePointer = ( unsigned char * ) &TLSRecord->HandshakeRecords.TLSGenericRecord; // the first one

        //while ( MessagePointer <= EndOfRecord )
        //{
            MessageLength = DecodeHandshakeRecord ( (void *) MessagePointer );

            if ( MessageLength == 0 ) return ( 0 ); // decode failure so stop decoding messages

        //    // point at the next mesaage based on the size of the decoded one
        //
        //    MessagePointer += MessageLength;
        //}
    }
    else
    {
        if ( TLSRecord->RecordHeader.ContentType == TLS_CT_CHANGE_CIPHER_SPEC )
        {
            CONSOL1 ( COLOUR_UNDERLINE_ON );

            CONSOL1 ( "TLS Change Cipher Spec Record:-\n" );

            CONSOL1 ( COLOUR_DEFAULT );

            CONSOL3 ( ContentTypeComment, TLS_CT_CHANGE_CIPHER_SPEC, "TLS_CT_CHANGE_CIPHER_SPEC" );

            return ( 0 ); // no decode possible so stop decoding
        }
        else
        {
            if ( TLSRecord->RecordHeader.ContentType == TLS_CT_ALERT )
            {
                CONSOL1 ( COLOUR_UNDERLINE_ON );

                CONSOL1 ( "TLS Alert Record:-\n" );

                CONSOL1 ( COLOUR_DEFAULT );

                CONSOL3 ( ContentTypeComment, TLS_CT_ALERT, "TLS_CT_ALERT" );

                // convert numeric version to string version

                TLSProtocolVersion = GetVersionString ( TLSRecord->RecordHeader.ProtocolVersion.MajorVersion,
                                                        TLSRecord->RecordHeader.ProtocolVersion.MinorVersion );

                CONSOL4 ( ProtocolVersionComment,
                          TLSRecord->RecordHeader.ProtocolVersion.MajorVersion,
                          TLSRecord->RecordHeader.ProtocolVersion.MinorVersion,
                          TLSProtocolVersion );

                ContentLength = ( TLSRecord->RecordHeader.ContentLengthHigh * 256 ) + TLSRecord->RecordHeader.ContentLengthLow;

                CONSOL2 ( ContentLengthComment, ContentLength );

                CONSOL2 ( AlertLevelComment, TLSRecord->HandshakeRecords.TLSAlertRecord.AlertLevel );

                // find alert in table

                int Index = 0;

                while ( AlertDescriptionTable [ Index ].Value != TLS_AD_UNKNOWN )
                {
                    if ( AlertDescriptionTable [ Index ].Value == TLSRecord->HandshakeRecords.TLSAlertRecord.AlertDescription )
                    {
                        CONSOL3 ( AlertDescriptionComment,
                                  TLSRecord->HandshakeRecords.TLSAlertRecord.AlertDescription,
                                  AlertDescriptionTable [ Index ].Text );

                        break;
                    }

                    Index++;
                }
            }
            else
            {
                if ( TLSRecord->RecordHeader.ContentType == TLS_CT_APPLICATION_DATA )
                {
                    CONSOL1 ( COLOUR_UNDERLINE_ON );

                    CONSOL1 ( "TLS Application Data Record:-\n" );

                    CONSOL1 ( COLOUR_DEFAULT );

                    CONSOL3 ( ContentTypeComment, TLS_CT_APPLICATION_DATA, "TLS_CT_APPLICATION_DATA" );

                    return ( 0 ); // no further decode possible so stop decoding
                }
                else
                {
                    if ( TLSRecord->RecordHeader.ContentType == TLS_CT_HEARTBEAT )
                    {
                        CONSOL1 ( COLOUR_UNDERLINE_ON );

                        CONSOL1 ( "TLS Heartbeat Record:-\n" );

                        CONSOL1 ( COLOUR_DEFAULT );

                        CONSOL3 ( ContentTypeComment, TLS_CT_HEARTBEAT, "TLS_CT_HEARTBEAT" );

                        return ( 0 ); // no further decode possible so stop decoding
                    }
                    else
                    {
                        CONSOL1 ( COLOUR_UNDERLINE_ON );

                        CONSOL2 ( "Unknown Content Type (%d):-\n", TLSRecord->RecordHeader.ContentType );

                        CONSOL1 ( COLOUR_DEFAULT );

                        return ( 0 ); // no further decode possible so stop decoding
                    }
                }
            }
        }
    }

    return ( ContentLength + sizeof ( TLS_RECORD_HEADER ) );
}

//**********************************************************************************************************************************
//
// Each handshake record contains a message header followed by one or more messages. The MessageLength field specifies how large the
// set of messages is, but not how many. So it is necessary to look into each message and decode them. Many messages have no obvious
// length field so the inherent size of the specific message must be known. Many messages have variable size fields within them.
//
//  -----------------------------------------------------
// |                  Handshake Record                   |
// |-----------------------------------------------------|
// |    Message Header  |          Messages(s)           |
// |--------------------|--------------------------------|
// | Message |  Message | Message  |    ...    | Message |
// |  Type   |  Length  |    1     |           |    N    |
//  -----------------------------------------------------
//

const unsigned char HexDigits [] = "0123456789ABCDEF";

unsigned char RandomBytesBuffer       [ ( 2 * RANDOM_BYTES_LENGTH           ) + 2 ]; // two hex digits per octet plus the terminator
unsigned char SessionIdentifierBuffer [ ( 2 * MAX_SESSION_IDENTIFIER_LENGTH ) + 2 ];

unsigned long DecodeHandshakeRecord ( void *HandshakeRecord )
{
    TLS_MESSAGE_HEADER *TLSMessage      = (TLS_MESSAGE_HEADER *) HandshakeRecord;
    const char         *TLSHelloVersion = NULL;
    unsigned char      *DecodePointer   = NULL;
    unsigned char      *MessagePointer  = NULL;
    unsigned char      *EndOfMessage    = NULL;

    int MessageLength = ( TLSMessage->MessageLengthLow    <<  0 ) +
                        ( TLSMessage->MessageLengthMiddle <<  8 ) +
                        ( TLSMessage->MessageLengthHigh   << 16 );

    MessagePointer = (unsigned char *) TLSMessage;

    EndOfMessage = &MessagePointer [ MessageLength + sizeof ( TLS_MESSAGE_HEADER ) ] - 1;

    CONSOL1 ( "\n" );

    switch ( TLSMessage->MessageType )
    {
        case TLS_MT_HELLO_REQUEST:
        {
            CONSOL1 ( COLOUR_YELLOW );

            CONSOL3 ( MessageTypeComment, TLS_MT_HELLO_REQUEST, "TLS_MT_HELLO_REQUEST" );

            CONSOL1 ( COLOUR_DEFAULT );

            CONSOL5 ( MessageLengthComment,
                      TLSMessage->MessageLengthHigh,
                      TLSMessage->MessageLengthMiddle,
                      TLSMessage->MessageLengthLow,
                      MessageLength );

            TLS_CLIENT_HELLO_RECORD *TLSClientHelloRecord = (TLS_CLIENT_HELLO_RECORD *) TLSMessage;

            TLSHelloVersion = GetVersionString ( TLSClientHelloRecord->HelloVersion.MajorVersion,
                                                 TLSClientHelloRecord->HelloVersion.MinorVersion );

            CONSOL4 ( HelloVersionComment,
                      TLSClientHelloRecord->HelloVersion.MajorVersion,
                      TLSClientHelloRecord->HelloVersion.MinorVersion,
                      TLSHelloVersion );

            break;
        }

        case TLS_MT_CLIENT_HELLO:
        {
            DecodeClientHello ( TLSMessage );

            break;
        }

        case TLS_MT_SERVER_HELLO:
        {
            CONSOL1 ( COLOUR_YELLOW );

            CONSOL3 ( MessageTypeComment, TLS_MT_SERVER_HELLO, "TLS_MT_SERVER_HELLO" );

            CONSOL1 ( COLOUR_DEFAULT );

            // MessageHeader

            CONSOL5 ( MessageLengthComment,
                      TLSMessage->MessageLengthHigh,
                      TLSMessage->MessageLengthMiddle,
                      TLSMessage->MessageLengthLow,
                      MessageLength );

            TLS_SERVER_HELLO_RECORD *TLSServerHelloRecord = (TLS_SERVER_HELLO_RECORD *) TLSMessage;

            // HelloVersion

            TLSHelloVersion = GetVersionString ( TLSServerHelloRecord->HelloVersion.MajorVersion,
                                                 TLSServerHelloRecord->HelloVersion.MinorVersion );

            CONSOL4 ( HelloVersionComment,
                      TLSServerHelloRecord->HelloVersion.MajorVersion,
                      TLSServerHelloRecord->HelloVersion.MinorVersion,
                      TLSHelloVersion );

            // Random

            unsigned long UnixTime = ( TLSServerHelloRecord->Random.UnixTime [ 0 ] <<  0 ) +
                                     ( TLSServerHelloRecord->Random.UnixTime [ 1 ] <<  8 ) +
                                     ( TLSServerHelloRecord->Random.UnixTime [ 2 ] << 16 ) +
                                     ( TLSServerHelloRecord->Random.UnixTime [ 3 ] << 24 );

            CONSOL2 ( RandomUnixTimeComment, UnixTime );

            for ( int Offset = 0; Offset < RANDOM_BYTES_LENGTH; Offset++ )
            {
                RandomBytesBuffer [ ( Offset * 2 ) + 0 ] = HexDigits [ TLSServerHelloRecord->Random.RandomBytes [ Offset ] / 16 ];
                RandomBytesBuffer [ ( Offset * 2 ) + 1 ] = HexDigits [ TLSServerHelloRecord->Random.RandomBytes [ Offset ] % 16 ];
            }

            RandomBytesBuffer [ ( RANDOM_BYTES_LENGTH * 2 ) + 0 ] = '\0';
            RandomBytesBuffer [ ( RANDOM_BYTES_LENGTH * 2 ) + 1 ] = '\0';

            CONSOL2 ( RandomValueComment, RandomBytesBuffer );

            // Session Identifer

            int SessionIdentifierLength = TLSServerHelloRecord->SessionIdentifierLength;

            CONSOL2 ( SessionIdentifierLengthComment, SessionIdentifierLength );

            //
            // this is the start of the variable length field section of the message, so start decoding it using a pointer
            //
            DecodePointer = (unsigned char *) &TLSServerHelloRecord->SessionIdentifierLength;

            if ( SessionIdentifierLength > 0 )
            {
                for ( int Offset = 0; Offset < RANDOM_BYTES_LENGTH; Offset++ )
                {
                    SessionIdentifierBuffer [ ( Offset * 2 ) + 0 ] = HexDigits [ TLSServerHelloRecord->SessionIdentifier [ Offset ] / 16 ];
                    SessionIdentifierBuffer [ ( Offset * 2 ) + 1 ] = HexDigits [ TLSServerHelloRecord->SessionIdentifier [ Offset ] % 16 ];
                }

                SessionIdentifierBuffer [ ( SessionIdentifierLength * 2 ) + 0 ] = '\0';
                SessionIdentifierBuffer [ ( SessionIdentifierLength * 2 ) + 1 ] = '\0';

                CONSOL2 ( SessionIdentifierComment, SessionIdentifierBuffer );
            }

            DecodePointer += ( sizeof ( TLSServerHelloRecord->SessionIdentifierLength ) + SessionIdentifierLength );

            // CipherSuite

            int CipherSuiteHigh = *DecodePointer++;
            int CipherSuiteLow  = *DecodePointer++;

            int CipherSuite = ( CipherSuiteHigh * 256 ) + CipherSuiteLow;

            // lookup the cipher suite in the cipher suite description table

            int Index = 0;

            while ( CipherSuiteDescriptionTable [ Index ].Value != TLS_CIPHER_SUITE_UNDEFINED )
            {
                if ( CipherSuiteDescriptionTable [ Index ].Value == CipherSuite ) break;

                Index++;
            }

            CONSOL3 ( CipherSuiteComment,
                      CipherSuite,
                      CipherSuiteDescriptionTable [ Index ].Name );

            // CompressionMethod

            unsigned char CompressionMethod = *DecodePointer++;

            CONSOL2 ( CompressionMethodComment, CompressionMethod );

            // ExtensionsLength

            int ExtensionsLengthHigh = *DecodePointer++;
            int ExtensionsLengthLow  = *DecodePointer++;

            int ExtensionsLength = ( ExtensionsLengthHigh * 256 ) + ExtensionsLengthLow;

            CONSOL2 ( ExtensionsLengthComment, ExtensionsLength );

            break;
        }

        case TLS_MT_NEW_SESSION_TICKET:
        {
            CONSOL1 ( COLOUR_YELLOW );

            CONSOL3 ( MessageTypeComment, TLS_MT_NEW_SESSION_TICKET, "TLS_MT_NEW_SESSION_TICKET" );

            CONSOL1 ( COLOUR_DEFAULT );

            break;
        }

        case TLS_MT_END_OF_EARLY_DATA:
        {
            CONSOL1 ( COLOUR_YELLOW );

            CONSOL3 ( MessageTypeComment, TLS_MT_END_OF_EARLY_DATA, "TLS_MT_END_OF_EARLY_DATA" );

            CONSOL1 ( COLOUR_DEFAULT );

            break;
        }

        case TLS_MT_HELLO_RETRY_REQUEST:
        {
            CONSOL1 ( COLOUR_YELLOW );

            CONSOL3 ( MessageTypeComment, TLS_MT_HELLO_RETRY_REQUEST, "TLS_MT_HELLO_RETRY_REQUEST" );

            CONSOL1 ( COLOUR_DEFAULT );

            break;
        }

        case TLS_MT_ENCRYPTED_EXTENSIONS:
        {
            CONSOL1 ( COLOUR_YELLOW );

            CONSOL3 ( MessageTypeComment, TLS_MT_ENCRYPTED_EXTENSIONS, "TLS_MT_ENCRYPTED_EXTENSIONS" );

            CONSOL1 ( COLOUR_DEFAULT );

            break;
        }

        case TLS_MT_CERTIFICATE:
        {
            // certificates are ASN encoded so we can't decode them here but the size is decodeable

            CONSOL1 ( COLOUR_YELLOW );

            CONSOL3 ( MessageTypeComment, TLS_MT_CERTIFICATE, "TLS_MT_CERTIFICATE" );

            CONSOL1 ( COLOUR_DEFAULT );

            CONSOL5 ( MessageLengthComment,
                      TLSMessage->MessageLengthHigh,
                      TLSMessage->MessageLengthMiddle,
                      TLSMessage->MessageLengthLow,
                      MessageLength );

            TLS_CERTIFICATE_RECORD *TLSCertificateRecord = (TLS_CERTIFICATE_RECORD *) TLSMessage;

            int CertificatesFieldLength = ( TLSCertificateRecord->CertificatesFieldLengthLow    <<  0 ) +
                                          ( TLSCertificateRecord->CertificatesFieldLengthMiddle <<  8 ) +
                                          ( TLSCertificateRecord->CertificatesFieldLengthHigh   << 16 );

            CONSOL2 ( CertificateLengthComment, CertificatesFieldLength );

            // extract and print out the certificate info

            int CertificateNumber = 0;

            unsigned char *CertificatePointer = (unsigned char *) &TLSCertificateRecord->Certificates [ CertificateNumber ]; // the first certificate

            while ( CertificatePointer < EndOfMessage ) // don't go beyond the end of the message
            {
                TLS_CERTIFICATE *Certificate = (TLS_CERTIFICATE *) CertificatePointer;

                int CertificateLength = ( Certificate->CertificateLengthLow    <<  0 ) +
                                        ( Certificate->CertificateLengthMiddle <<  8 ) +
                                        ( Certificate->CertificateLengthHigh   << 16 );

                CONSOL3 ( CertificateComment, CertificateNumber, CertificateLength );

                DecodeASN ( &Certificate->Certificate [ CertificateNumber ], CertificateLength ); // try to decode this certificate

                // find the next certificate

                CertificateNumber++;

                CertificatePointer += ( CertificateLength + 3 * ( sizeof ( unsigned char ) ) ); // 3 octet header plus certificate
            }

            break;
        }

        case TLS_MT_SERVER_KEY_EXCHANGE:
        {
            CONSOL1 ( COLOUR_YELLOW );

            CONSOL3 ( MessageTypeComment, TLS_MT_SERVER_KEY_EXCHANGE, "TLS_MT_SERVER_KEY_EXCHANGE" );

            CONSOL1 ( COLOUR_DEFAULT );

            CONSOL5 ( MessageLengthComment,
                      TLSMessage->MessageLengthHigh,
                      TLSMessage->MessageLengthMiddle,
                      TLSMessage->MessageLengthLow,
                      MessageLength );

            break;
        }

        case TLS_MT_CERTIFICATE_REQUEST:
        {
            CONSOL1 ( COLOUR_YELLOW );

            CONSOL3 ( MessageTypeComment, TLS_MT_CERTIFICATE_REQUEST, "TLS_MT_CERTIFICATE_REQUEST" );

            CONSOL1 ( COLOUR_DEFAULT );

            break;
        }

        case TLS_MT_SERVER_HELLO_DONE:
        {
            CONSOL1 ( COLOUR_YELLOW );

            CONSOL3 ( MessageTypeComment, TLS_MT_SERVER_HELLO_DONE, "TLS_MT_SERVER_HELLO_DONE" );

            CONSOL1 ( COLOUR_DEFAULT );

            CONSOL5 ( MessageLengthComment,
                      TLSMessage->MessageLengthHigh,
                      TLSMessage->MessageLengthMiddle,
                      TLSMessage->MessageLengthLow,
                      MessageLength );

            break;
        }

        case TLS_MT_CERTIFICATE_VERIFY:
        {
            CONSOL1 ( COLOUR_YELLOW );

            CONSOL3 ( MessageTypeComment, TLS_MT_CERTIFICATE_VERIFY, "TLS_MT_CERTIFICATE_VERIFY" );

            CONSOL1 ( COLOUR_DEFAULT );

            break;
        }

        case TLS_MT_CLIENT_KEY_EXCHANGE:
        {
            CONSOL1 ( COLOUR_YELLOW );

            CONSOL3 ( MessageTypeComment, TLS_MT_CLIENT_KEY_EXCHANGE, "TLS_MT_CLIENT_KEY_EXCHANGE" );

            CONSOL1 ( COLOUR_DEFAULT );

            break;
        }

        case TLS_MT_FINISHED:
        {
            CONSOL1 ( COLOUR_YELLOW );

            CONSOL3 ( MessageTypeComment, TLS_MT_FINISHED, "TLS_MT_FINISHED" );

            CONSOL1 ( COLOUR_DEFAULT );

            break;
        }

        case TLS_MT_KEY_UPDATE:
        {
            CONSOL1 ( COLOUR_YELLOW );

            CONSOL3 ( MessageTypeComment, TLS_MT_KEY_UPDATE, "TLS_MT_KEY_UPDATE" );

            CONSOL1 ( COLOUR_DEFAULT );

            break;
        }

        case TLS_MT_MESSAGE_HASH:
        {
            CONSOL1 ( COLOUR_YELLOW );

            CONSOL3 ( MessageTypeComment, TLS_MT_MESSAGE_HASH, "TLS_MT_MESSAGE_HASH" );

            CONSOL1 ( COLOUR_DEFAULT );

            break;
        }

        default :
        {
            CONSOL1 ( COLOUR_RED );

            CONSOL1 ( "Unknown Message Type:-\n" );

            CONSOL1 ( COLOUR_DEFAULT );

            break;
        }
    }

    return ( MessageLength + sizeof ( TLS_MESSAGE_HEADER ) );
}

//**********************************************************************************************************************************

void DecodeClientHello ( TLS_MESSAGE_HEADER *TLSMessage )
{
    const char    *TLSHelloVersion = NULL;
    unsigned char *MessagePointer  = NULL;
    unsigned char *EndOfMessage    = NULL;
    unsigned int   MessageLength   = 0;
    unsigned int   MessageIndex    = 0;

    MessageLength = ( TLSMessage->MessageLengthLow    <<  0 ) +
                    ( TLSMessage->MessageLengthMiddle <<  8 ) +
                    ( TLSMessage->MessageLengthHigh   << 16 );

    MessagePointer = (unsigned char *) TLSMessage;

    EndOfMessage = &MessagePointer [ MessageLength + sizeof ( TLS_MESSAGE_HEADER ) ] - 1;

    CONSOL1 ( COLOUR_YELLOW );

    CONSOL3 ( MessageTypeComment, TLS_MT_CLIENT_HELLO, "TLS_MT_CLIENT_HELLO" );

    CONSOL1 ( COLOUR_DEFAULT );

    // MessageHeader 0 to 3

    CONSOL5 ( MessageLengthComment,
              TLSMessage->MessageLengthHigh,
              TLSMessage->MessageLengthMiddle,
              TLSMessage->MessageLengthLow,
              MessageLength );

    DumpPacket ( MessagePointer, MessageLength, MessageIndex, MessageIndex + 3, "" );

    TLS_CLIENT_HELLO_RECORD *TLSClientHelloRecord = (TLS_CLIENT_HELLO_RECORD *) TLSMessage;

    // HelloVersion 4 to 5

    TLSHelloVersion = GetVersionString ( TLSClientHelloRecord->HelloVersion.MajorVersion,
                                         TLSClientHelloRecord->HelloVersion.MinorVersion );

    CONSOL4 ( HelloVersionComment,
              TLSClientHelloRecord->HelloVersion.MajorVersion,
              TLSClientHelloRecord->HelloVersion.MinorVersion,
              TLSHelloVersion );

    DumpPacket ( MessagePointer, MessageLength, MessageIndex + 4, MessageIndex + 5, "" );

    // Random 6 to 9 then 10 to 37

    unsigned long UnixTime = ( TLSClientHelloRecord->Random.UnixTime [ 0 ] <<  0 ) +
                             ( TLSClientHelloRecord->Random.UnixTime [ 1 ] <<  8 ) +
                             ( TLSClientHelloRecord->Random.UnixTime [ 2 ] << 16 ) +
                             ( TLSClientHelloRecord->Random.UnixTime [ 3 ] << 24 );

    CONSOL2 ( RandomUnixTimeComment, UnixTime );

    DumpPacket ( MessagePointer, MessageLength, MessageIndex + 6, MessageIndex + 9, "" );

    for ( int Offset = 0; Offset < RANDOM_BYTES_LENGTH; Offset++ )
    {
        RandomBytesBuffer [ ( Offset * 2 ) + 0 ] = HexDigits [ TLSClientHelloRecord->Random.RandomBytes [ Offset ] / 16 ];
        RandomBytesBuffer [ ( Offset * 2 ) + 1 ] = HexDigits [ TLSClientHelloRecord->Random.RandomBytes [ Offset ] % 16 ];
    }

    RandomBytesBuffer [ ( RANDOM_BYTES_LENGTH * 2 ) + 0 ] = '\0';
    RandomBytesBuffer [ ( RANDOM_BYTES_LENGTH * 2 ) + 1 ] = '\0';

    CONSOL2 ( RandomValueComment, RandomBytesBuffer );

    DumpPacket ( MessagePointer, MessageLength, MessageIndex + 10, MessageIndex + 10 + RANDOM_BYTES_LENGTH - 1, "" );

    // Session Identifer

    int SessionIdentifierLength = TLSClientHelloRecord->SessionIdentifierLength;

    CONSOL2 ( SessionIdentifierLengthComment, SessionIdentifierLength );

    //
    // this is the start of the variable length field section of the message, so start decoding it using a pointer and index
    //

    MessageIndex = offsetof ( TLS_CLIENT_HELLO_RECORD, SessionIdentifierLength );

    DumpPacket ( MessagePointer, MessageLength, MessageIndex, MessageIndex + sizeof ( TLSClientHelloRecord->SessionIdentifierLength ) - 1, "" );

    if ( SessionIdentifierLength > 0 )
    {
        for ( int Offset = 0; Offset < RANDOM_BYTES_LENGTH; Offset++ )
        {
            SessionIdentifierBuffer [ ( Offset * 2 ) + 0 ] = HexDigits [ TLSClientHelloRecord->SessionIdentifier [ Offset ] / 16 ];
            SessionIdentifierBuffer [ ( Offset * 2 ) + 1 ] = HexDigits [ TLSClientHelloRecord->SessionIdentifier [ Offset ] % 16 ];
        }

        SessionIdentifierBuffer [ ( SessionIdentifierLength * 2 ) + 0 ] = '\0';
        SessionIdentifierBuffer [ ( SessionIdentifierLength * 2 ) + 1 ] = '\0';

        CONSOL2 ( SessionIdentifierComment, SessionIdentifierBuffer );

        DumpPacket ( MessagePointer,
                     MessageLength,
                     MessageIndex + sizeof ( TLSClientHelloRecord->SessionIdentifierLength ),
                     MessageIndex + sizeof ( TLSClientHelloRecord->SessionIdentifierLength ) + SessionIdentifierLength - 1,
                     "" );
    }

    MessageIndex += ( sizeof ( TLSClientHelloRecord->SessionIdentifierLength ) + SessionIdentifierLength );

    // CipherSuitesLength

    int CipherSuiteLengthHigh = MessagePointer [ MessageIndex++ ];
    int CipherSuiteLengthLow  = MessagePointer [ MessageIndex++ ];

    int CipherSuiteLength = ( CipherSuiteLengthHigh * 256 ) + CipherSuiteLengthLow;

    CONSOL2 ( CipherSuitesLengthComment, CipherSuiteLength );

    DumpPacket ( MessagePointer, MessageLength, MessageIndex - 2, MessageIndex - 1, "" );

    for ( int Count = 0; Count < CipherSuiteLength / 2; Count++ )
    {
        int CipherSuiteHigh = MessagePointer [ MessageIndex++ ];
        int CipherSuiteLow  = MessagePointer [ MessageIndex++ ];

        int CipherSuite = ( CipherSuiteHigh * 256 ) + CipherSuiteLow;

        // lookup the cipher suite in the cipher suite description table

        bool IsSupported = NULL;

        const char *CipherSuiteName = LookupCipherSuite ( CipherSuite, &IsSupported );

        CONSOL4 ( CipherSuiteNumberComment,
                  Count,
                  CipherSuite,
                  CipherSuiteName );
    }

    CONSOL1 ( "\n" );

    // CompressionMethods Length

    int CompressionMethodLength = MessagePointer [ MessageIndex++ ];

    CONSOL2 ( CompressionMethodsLengthComment, CompressionMethodLength );

    DumpPacket ( MessagePointer, MessageLength, MessageIndex - 1, MessageIndex - 1, "" );

    // CompressionMethods

    for ( int Count = 0; Count < CompressionMethodLength; Count++ )
    {
        unsigned char CompressionMethod = MessagePointer [ MessageIndex++ ];

        CONSOL3 ( CompressionMethodsComment, Count, CompressionMethod );

        DumpPacket ( MessagePointer, MessageLength, MessageIndex - 1, MessageIndex - 1, "" );
    }

    // ExtensionsLength

    unsigned int ExtensionsLengthHigh = MessagePointer [ MessageIndex++ ];
    unsigned int ExtensionsLengthLow  = MessagePointer [ MessageIndex++ ];

    unsigned int ExtensionsLength = ( ExtensionsLengthHigh * 256 ) + ExtensionsLengthLow;

    CONSOL2 ( ExtensionsLengthComment, ExtensionsLength );

    DumpPacket ( MessagePointer, MessageLength, MessageIndex - 2, MessageIndex - 1, "" );

    // Extensions ( 2 bytes type, 2 bytes length then data (if any)

    unsigned int ExtensionsIndex = 0; // octet index into the extensions field

    while ( ExtensionsIndex < ExtensionsLength )
    {
        unsigned int ExtensionTypeHigh   = MessagePointer [ MessageIndex++ ]; ExtensionsIndex++;
        unsigned int ExtensionTypeLow    = MessagePointer [ MessageIndex++ ]; ExtensionsIndex++;
        unsigned int ExtensionLengthHigh = MessagePointer [ MessageIndex++ ]; ExtensionsIndex++;
        unsigned int ExtensionLengthLow  = MessagePointer [ MessageIndex++ ]; ExtensionsIndex++;

        unsigned int ExtensionType = ( ExtensionTypeHigh * 256 ) + ExtensionTypeLow;

        unsigned int ExtensionLength = ( ExtensionLengthHigh * 256 ) + ExtensionLengthLow;

        DecodeExtension ( ExtensionType, ExtensionLength, ExtensionsIndex, MessagePointer, MessageIndex );

        MessageIndex    += ExtensionLength;
        ExtensionsIndex += ExtensionLength;
    }
}

//**********************************************************************************************************************************

void DecodeExtension ( unsigned int   ExtensionType,   // the type of the extension (enumerated)
                       unsigned int   ExtensionLength, // the length of the extension in octets
                       unsigned int   ExtensionsIndex, // octet index into the extensions field
                       unsigned char *MessagePointer,  // points at the beginning of the message
                       unsigned int   MessageIndex )   // index into the message for the extension
{
    unsigned int TableIndex = 0;
    unsigned int ArrayIndex = 0;
    unsigned int KeyIndex   = 0;

    while ( ExtensionTypeDescriptionTable [ TableIndex ].Value != TLS_ET_UNDEFINED_EXTENSION_TYPE )
    {
        if ( ExtensionTypeDescriptionTable [ TableIndex ].Value == ExtensionType ) break;

        TableIndex++;
    }

    CONSOL1 ( COLOUR_CYAN );

    CONSOL3 ( ExtensionTypeComment,
              ExtensionType,
              ExtensionTypeDescriptionTable [ TableIndex ].Text );

    CONSOL1 ( COLOUR_DEFAULT );

    CONSOL2 ( ExtensionLengthComment, ExtensionLength );

    switch ( ExtensionType )
    {
//        case TLS_ET_SERVER_NAME :
//        case TLS_ET_MAX_FRAGMENT_LENGTH :
//        case TLS_ET_CLIENT_CERTIFICATE_URL :
//        case TLS_ET_TRUSTED_CA_KEYS :
//        case TLS_ET_TRUNCATED_HMAC :
//        case TLS_ET_STATUS_REQUEST :
//        case TLS_ET_USER_MAPPING :
//        case TLS_ET_CLIENT_AUTHZ :
//        case TLS_ET_SERVER_AUTHZ :
//        case TLS_ET_CERT_TYPE :
        case TLS_ET_SUPPORTED_GROUPS :
        {
            unsigned char OctetLengthOfGroupsHigh = MessagePointer [ MessageIndex + ArrayIndex++ ]; // first octet is octet length of Groups array high
            unsigned char OctetLengthOfGroupsLow  = MessagePointer [ MessageIndex + ArrayIndex++ ]; // first octet is octet length of Groups array low

            unsigned int OctetLengthOfGroups = ( OctetLengthOfGroupsHigh * 256 ) + OctetLengthOfGroupsLow;

            // note that this really should be an even value! but round it down in any case

            unsigned int NumberOfGroups = OctetLengthOfGroups / 2; // 2 octets per version just like protocol version

            CONSOL3 ( ExtensionSupportedNamedGroupsLengthComment, OctetLengthOfGroups, NumberOfGroups );

            for ( unsigned int GroupIndex = 0; GroupIndex < NumberOfGroups; GroupIndex++ )
            {
                unsigned char GroupHigh = MessagePointer [ MessageIndex + ArrayIndex++ ]; // octet is signature Group high
                unsigned char GroupLow  = MessagePointer [ MessageIndex + ArrayIndex++ ]; // octet is signature Group low

                unsigned int Group = ( GroupHigh * 256 ) + GroupLow;

                bool Supported = FALSE;

                const char *GroupName = LookupNamedGroup ( Group, &Supported );

                CONSOL4 ( ExtensionSupportedNamedGroupComment, GroupIndex, Group, GroupName );
            }

            break;
        }

//        case TLS_ET_EC_POINT_FORMATS :
//        case TLS_ET_SRP :
        case TLS_ET_SIGNATURE_ALGORITHMS :
        {
            unsigned char OctetLengthOfAlgorithmsHigh = MessagePointer [ MessageIndex + ArrayIndex++ ]; // first octet is octet length of algorithms array high
            unsigned char OctetLengthOfAlgorithmsLow  = MessagePointer [ MessageIndex + ArrayIndex++ ]; // first octet is octet length of algorithms array low

            unsigned int OctetLengthOfAlgorithms = ( OctetLengthOfAlgorithmsHigh * 256 ) + OctetLengthOfAlgorithmsLow;

            // note that this really should be an even value! but round it down in any case

            unsigned int NumberOfAlgorithms = OctetLengthOfAlgorithms / 2; // 2 octets per version just like protocol version

            CONSOL3 ( ExtensionSignatureHashAlgorithmsLengthComment, OctetLengthOfAlgorithms, NumberOfAlgorithms );

            for ( unsigned int AlgorithmIndex = 0; AlgorithmIndex < NumberOfAlgorithms; AlgorithmIndex++ )
            {
                unsigned char AlgorithmHigh = MessagePointer [ MessageIndex + ArrayIndex++ ]; // octet is signature algorithm high
                unsigned char AlgorithmLow  = MessagePointer [ MessageIndex + ArrayIndex++ ]; // octet is signature algorithm low

                unsigned int Algorithm = ( AlgorithmHigh * 256 ) + AlgorithmLow;

                bool Supported = FALSE;

                const char *HashAlgorithmName = LookupSignatureAlgorithm ( Algorithm, &Supported );

                CONSOL4 ( ExtensionSignatureHashAlgorithmComment, AlgorithmIndex, Algorithm, HashAlgorithmName );
            }

            break;
        }
//        case TLS_ET_USE_SRTP :
//        case TLS_ET_HEARTBEAT :
//        case TLS_ET_APPLICATION_LAYER_PROTOCOL_NEGOTIATION :
//        case TLS_ET_STATUS_REQUEST_V2 :
//        case TLS_ET_SIGNED_CERTIFICATE_TIMESTAMP :
//        case TLS_ET_CLIENT_CERTIFICATE_TYPE :
//        case TLS_ET_SERVER_CERTIFICATE_TYPE :
//        case TLS_ET_PADDING :
//        case TLS_ET_ENCRYPT_THEN_MAC :
//        case TLS_ET_EXTENDED_MASTER_SECRET :
//        case TLS_ET_TOKEN_BINDING :
//        case TLS_ET_CACHED_INFO :
//        case TLS_ET_QUIC_TRANSPORT_PARAMETERS :
//        case TLS_ET_COMPRESS_CERTIFICATE:
//        case TLS_ET_RECORD_SIZE_LIMIT :
//        case TLS_ET_SESSIONTICKET :
//        case TLS_ET_PRE_SHARED_KEY :
//        case TLS_ET_EARLY_DATA :
        case TLS_ET_SUPPORTED_VERSIONS :
        {
            unsigned int OctetLengthOfVersions = MessagePointer [ MessageIndex + ArrayIndex++ ]; // first octet is octet length of versions

            // note that this really should be an even value! but round it down in any case

            unsigned int NumberOfVersions = OctetLengthOfVersions / 2; // 2 octets per version just like protocol version

            CONSOL3 ( ExtensionSupportedVersionLengthComment, OctetLengthOfVersions, NumberOfVersions );

            for ( unsigned int VersionIndex = 0; VersionIndex < NumberOfVersions; VersionIndex++ )
            {
                unsigned char MajorVersion = MessagePointer [ MessageIndex + ArrayIndex++ ]; // octet is major version
                unsigned char MinorVersion = MessagePointer [ MessageIndex + ArrayIndex++ ]; // octet is minor version

                unsigned int Version = ( MajorVersion * 256 ) + MinorVersion;

                CONSOL4 ( ExtensionSupportedVersionComment, VersionIndex, Version, GetVersionString ( MajorVersion, MinorVersion ) );
            }

            break;
        }
//        case TLS_ET_COOKIE :
//        case TLS_ET_PSK_KEY_EXCHANGE_MODES :
//        case TLS_ET_CERTIFICATE_AUTHORITIES :
//        case TLS_ET_OID_FILTERS :
//        case TLS_ET_POST_HANDSHAKE_AUTH :
//        case TLS_ET_SIGNATURE_ALGORITHMS_CERT :
        case TLS_ET_KEY_SHARE :
        {
            unsigned char ClientKeyShareLengthHigh = MessagePointer [ MessageIndex + ArrayIndex++ ]; // octet is client key share length high
            unsigned char ClientKeyShareLengthLow  = MessagePointer [ MessageIndex + ArrayIndex++ ]; // octet is client key share length low

            unsigned int ClientKeyShareLength = ( ClientKeyShareLengthHigh * 256 ) + ClientKeyShareLengthLow;

            CONSOL2 ( ExtensionClientKeyShareLengthComment, ClientKeyShareLength );

            unsigned char ClientKeyShareGroupHigh = MessagePointer [ MessageIndex + ArrayIndex++ ]; // octet is client key share group high
            unsigned char ClientKeyShareGroupLow  = MessagePointer [ MessageIndex + ArrayIndex++ ]; // octet is client key share group low

            unsigned int ClientKeyShareGroup = ( ClientKeyShareGroupHigh * 256 ) + ClientKeyShareGroupLow;

            bool Supported = FALSE;

            const char *ClientKeyShareGroupName = LookupNamedGroup ( ClientKeyShareGroup, &Supported )

            CONSOL3 ( ExtensionClientKeyShareGroupComment, ClientKeyShareGroup, ClientKeyShareGroupName );

            unsigned char ClientKeyShareKeyLengthHigh = MessagePointer [ MessageIndex + ArrayIndex++ ]; // octet is client key share key length high
            unsigned char ClientKeyShareKeyLengthLow  = MessagePointer [ MessageIndex + ArrayIndex++ ]; // octet is client key share key length low

            unsigned int ClientKeyShareKeyLength = ( ClientKeyShareKeyLengthHigh * 256 ) + ClientKeyShareKeyLengthLow;

            CONSOL2 ( ExtensionClientKeyShareKeyLengthComment, ClientKeyShareKeyLength );

            // print out the octets of the key in hex

            CONSOL1 ( ExtensionClientKeyShareKeyComment );

            for ( int KeyIndex = 0; KeyIndex < ExtensionLength; KeyIndex++ )
            {
                unsigned char Data = MessagePointer [ MessageIndex + ArrayIndex + KeyIndex ]; // octet is key octet

                CONSOL2 ( "%02X ", Data );
            }

            CONSOL1 ( "\n" );

            break;
        }
//        case TLS_ET_RESERVED_GREASE_0 :
//        case TLS_ET_RESERVED_GREASE_1 :
//        case TLS_ET_RESERVED_GREASE_2 :
//        case TLS_ET_RESERVED_GREASE_3 :
//        case TLS_ET_RESERVED_GREASE_4 :
//        case TLS_ET_RESERVED_GREASE_5 :
//        case TLS_ET_RESERVED_GREASE_6 :
//        case TLS_ET_RESERVED_GREASE_7 :
//        case TLS_ET_RESERVED_GREASE_8 :
//        case TLS_ET_RESERVED_GREASE_9 :
//        case TLS_ET_RESERVED_GREASE_A :
//        case TLS_ET_RESERVED_GREASE_B :
//        case TLS_ET_RESERVED_GREASE_C :
//        case TLS_ET_RESERVED_GREASE_D :
//        case TLS_ET_RESERVED_GREASE_E :
//        case TLS_ET_RESERVED_GREASE_F :
//        case TLS_ET_RENEGOTIATION_INFO:
//        case TLS_ET_UNDEFINED_EXTENSION_TYPE:

        default :
        {
            // just print out a hex dump of the extension data octets, if any

            if ( ExtensionLength > 0 )
            {
                CONSOL1 ( ExtensionDataComment );

                for ( ArrayIndex = 0; ArrayIndex < ExtensionLength; ArrayIndex++ )
                {
                    unsigned char Data = MessagePointer [ MessageIndex + ArrayIndex ];

                    CONSOL2 ( "%02X ", Data );
                }

                CONSOL1 ( "\n" );
            }

            break;
        }
    }
}

//**********************************************************************************************************************************
//
// Certificates are encoded using ASN.1 DER (Abstract Syntax Notation - Destinguished Encoding Rules) which is always a multiple of
// whole octets in length. Each part is encoded using what is called TLV (Tag Length Value) notation. This means that the type is
// given first, followed by the length and then the value. All three fields can be multiple octets in length. A certificate is a
// very complex structure so the value fields are actually structured and decode further. All octets in ASN encoding have the bits
// numbered 8 to 1 rather than 7 to 0, Where the MSB (Most Significant Bit) is bit 8.
//
//  ----------------------------------------------------------------------------------------
// |                          Certificate (one or more TLV fields)                          |
// |----------------------------------------------------------------------------------------|
// |  Tag    |  Length  |    Value    |      ....        |  Tag    |  Length  |    Value    |
//  ----------------------------------                    ----------------------------------
//
// The Tag field is constructed as follows:-
//
//    MSB                         LSB
//    -------------------------------
//   | 8 | 7 | 6 | 5 | 4 | 3 | 2 | 1 |
//    -------------------------------
//     \---/   ^  \----------------/
//       ^     |          ^
//       |     |          |       Tag Number
//       |     |          \------ 0 0 0 0 1 Boolean
//       |     |                  0 0 0 1 0 Integer
//       |     |                  0 0 0 1 1 Bit String
//       |     |                  0 0 1 0 0 Octet String
//       |     |                  0 0 1 0 1 Null
//       |     |                  0 0 1 1 0 Object Identifier
//       |     |                  0 1 0 0 1 Real Value
//       |     |                  1 0 0 0 0 Sequence and "Sequence Of"
//       |     |                  1 0 0 0 1 SET or "SET of"
//       |     |                  1 0 0 1 1 PrintableString
//       |     |                  1 0 1 0 0 T61String
//       |     |                  1 0 1 1 0 IA5String
//       |     |                  1 0 1 1 1 UTCTime
//       |     |                  1 1 1 1 1 Extended format tag (more than one octet)
//       |     |
//       |     \---  0 Primitive
//       |           1 Constructed
//       |
//       \----------- Class: 0 0 Universal
//                           0 1 Application
//                           1 0 Context Specific
//                           1 1 Private
//
// The field names and values are all defined in an ASN message definition. These are often collected together into a set of
// definitions called a module. This decoder uses the definitions given in the X.509 ASN Module found in the specification.
//
//**********************************************************************************************************************************

unsigned long NumberOfASNEntries = 0;

ASNENTRY ASNEntries [ MAX_ASN_ENTRIES ];

//**********************************************************************************************************************************

unsigned char *DecodeASN ( unsigned char *ASNMessage,
                           unsigned long  MessageLength )
{
    unsigned char *MessagePointer = ASNMessage;
    unsigned char  Octet          = 0;
    unsigned long  EntryNumber    = 0;
    ASNCLASS       Class          = ASN_CLASS_UNIVERSAL;
    ASNTAGNUMBER   TagNumber      = ASN_TAG_UNUSED_0;

    Octet = *MessagePointer++;

    return ( NULL );
}

//**********************************************************************************************************************************

const char *GetVersionString ( unsigned char MajorVersion, unsigned char MinorVersion )
{
    const char *TLSVersion = NULL;

    switch ( MajorVersion )
    {
    case 0 :

        switch ( MinorVersion )
        {
            case 0 : TLSVersion = "SSL v1"; break;
            case 1 : TLSVersion = "SSL v2"; break;
            case 2 : TLSVersion = "SSL v3"; break;

            default : TLSVersion = "unknown";
        }

        break;

    case 3 :

        switch ( MinorVersion )
        {
            case 1 : TLSVersion = "TLS 1.0"; break;
            case 2 : TLSVersion = "TLS 1.1"; break;
            case 3 : TLSVersion = "TLS 1.2"; break;
            case 4 : TLSVersion = "TLS 1.3"; break;

            default : TLSVersion = "unknown";
        }

        break;

    case 0x7F : // experimental version

        switch ( MinorVersion )
        {
            case 20 : TLSVersion = "TLS 1.3 Draft 20"; break;
            case 21 : TLSVersion = "TLS 1.3 Draft 21"; break;
            case 22 : TLSVersion = "TLS 1.3 Draft 22"; break;
            case 23 : TLSVersion = "TLS 1.3 Draft 23"; break;
            case 24 : TLSVersion = "TLS 1.3 Draft 24"; break;
            case 25 : TLSVersion = "TLS 1.3 Draft 25"; break;
            case 26 : TLSVersion = "TLS 1.3 Draft 26"; break;
            case 27 : TLSVersion = "TLS 1.3 Draft 27"; break;
            case 28 : TLSVersion = "TLS 1.3 Draft 28"; break;

            default : TLSVersion = "TLS 1.3 unknown draft"; break;
        }

        break;

    default :

        TLSVersion = "unknown";
    }

    return ( TLSVersion );
}

//**********************************************************************************************************************************

const char *LookupCipherSuite ( int   CipherSuite,
                                bool *Supported )
{
    int Index = 0;

    while ( CipherSuiteDescriptionTable [ Index ].Value != TLS_CIPHER_SUITE_UNDEFINED )
    {
        if ( CipherSuiteDescriptionTable [ Index ].Value == CipherSuite ) break;

        Index++;
    }

    *Supported = CipherSuiteDescriptionTable [ Index ].Supported;

    return ( CipherSuiteDescriptionTable [ Index ].Name );
}

//**********************************************************************************************************************************

const char *LookupSignatureAlgorithm ( int   SignatureAlgorithm,
                                       bool *Supported )
{
    int Index = 0;

    while ( SignatureAlgorithmDescriptionTable [ Index ].Value != TLS_SA_UNDEFINED )
    {
        if ( SignatureAlgorithmDescriptionTable [ Index ].Value == SignatureAlgorithm ) break;

        Index++;
    }

    *Supported = SignatureAlgorithmDescriptionTable [ Index ].Supported;

    return ( SignatureAlgorithmDescriptionTable [ Index ].Name );
}

//**********************************************************************************************************************************

const char *LookupNamedGroup ( int   NamedGroup,
                               bool *Supported )
{
    int Index = 0;

    while ( NamedGroupDescriptionTable [ Index ].Value != TLS_SA_UNDEFINED )
    {
        if ( NamedGroupDescriptionTable [ Index ].Value == NamedGroup ) break;

        Index++;
    }

    *Supported = NamedGroupDescriptionTable [ Index ].Supported;

    return ( NamedGroupDescriptionTable [ Index ].LoggingName );
}

//**********************************************************************************************************************************

char LastSocketErrorName   [ 200 + 1 ];
char LastSocketErrorString [ 200 + 1 ];

int PrintSocketError ( void )
{
    int SocketError;

    strcpy ( LastSocketErrorName,   "" );
    strcpy ( LastSocketErrorString, "" );

    SocketError = WSAGetLastError ();

    if ( SocketError )
    {
        switch ( SocketError )
        {
            case WSAEINTR           : strcpy ( LastSocketErrorName, "WSAEINTR"           ); strcpy ( LastSocketErrorString, "interrupted system call"                         ); break;
            case WSAEBADF           : strcpy ( LastSocketErrorName, "WSAEBADF"           ); strcpy ( LastSocketErrorString, "bad socket identifier"                           ); break;
            case WSAEACCES          : strcpy ( LastSocketErrorName, "WSAEACCES"          ); strcpy ( LastSocketErrorString, "access denied"                                   ); break;
            case WSAEFAULT          : strcpy ( LastSocketErrorName, "WSAEFAULT"          ); strcpy ( LastSocketErrorString, "bad address"                                     ); break;
            case WSAEINVAL          : strcpy ( LastSocketErrorName, "WSAEINVAL"          ); strcpy ( LastSocketErrorString, "invalid argument"                                ); break;
            case WSAEMFILE          : strcpy ( LastSocketErrorName, "WSAEMFILE"          ); strcpy ( LastSocketErrorString, "too many open files"                             ); break;
            case WSAEWOULDBLOCK     : strcpy ( LastSocketErrorName, "WSAEWOULDBLOCK"     ); strcpy ( LastSocketErrorString, "the operation would block"                       ); break;
            case WSAEINPROGRESS     : strcpy ( LastSocketErrorName, "WSAEINPROGRESS"     ); strcpy ( LastSocketErrorString, "the operation is now in progress"                ); break;
            case WSAEALREADY        : strcpy ( LastSocketErrorName, "WSAEALREADY"        ); strcpy ( LastSocketErrorString, "the operation is already in progress"            ); break;
            case WSAENOTSOCK        : strcpy ( LastSocketErrorName, "WSAENOTSOCK"        ); strcpy ( LastSocketErrorString, "socket operation on non-socket"                  ); break;
            case WSAEDESTADDRREQ    : strcpy ( LastSocketErrorName, "WSAEDESTADDRREQ"    ); strcpy ( LastSocketErrorString, "destination address required"                    ); break;
            case WSAEMSGSIZE        : strcpy ( LastSocketErrorName, "WSAEMSGSIZE"        ); strcpy ( LastSocketErrorString, "message too long"                                ); break;
            case WSAEPROTOTYPE      : strcpy ( LastSocketErrorName, "WSAEPROTOTYPE"      ); strcpy ( LastSocketErrorString, "protocol is wrong type for socket"               ); break;
            case WSAENOPROTOOPT     : strcpy ( LastSocketErrorName, "WSAENOPROTOOPT"     ); strcpy ( LastSocketErrorString, "bad protocol option"                             ); break;
            case WSAEPROTONOSUPPORT : strcpy ( LastSocketErrorName, "WSAEPROTONOSUPPORT" ); strcpy ( LastSocketErrorString, "protocol not supported"                          ); break;
            case WSAESOCKTNOSUPPORT : strcpy ( LastSocketErrorName, "WSAESOCKTNOSUPPORT" ); strcpy ( LastSocketErrorString, "socket type not supported"                       ); break;
            case WSAEOPNOTSUPP      : strcpy ( LastSocketErrorName, "WSAEOPNOTSUPP"      ); strcpy ( LastSocketErrorString, "operation not supported on socket"               ); break;
            case WSAEPFNOSUPPORT    : strcpy ( LastSocketErrorName, "WSAEPFNOSUPPORT"    ); strcpy ( LastSocketErrorString, "protocol family not supported"                   ); break;
            case WSAEAFNOSUPPORT    : strcpy ( LastSocketErrorName, "WSAEAFNOSUPPORT"    ); strcpy ( LastSocketErrorString, "address family not supported by protocol family" ); break;
            case WSAEADDRINUSE      : strcpy ( LastSocketErrorName, "WSAEADDRINUSE"      ); strcpy ( LastSocketErrorString, "address already in use"                          ); break;
            case WSAEADDRNOTAVAIL   : strcpy ( LastSocketErrorName, "WSAEADDRNOTAVAIL"   ); strcpy ( LastSocketErrorString, "cannot assign requested address"                 ); break;
            case WSAENETDOWN        : strcpy ( LastSocketErrorName, "WSAENETDOWN"        ); strcpy ( LastSocketErrorString, "the network is down"                             ); break;
            case WSAENETUNREACH     : strcpy ( LastSocketErrorName, "WSAENETUNREACH"     ); strcpy ( LastSocketErrorString, "ICMP network unreachable"                        ); break;
            case WSAENETRESET       : strcpy ( LastSocketErrorName, "WSAENETRESET"       ); strcpy ( LastSocketErrorString, "the network was reset"                           ); break;
            case WSAECONNABORTED    : strcpy ( LastSocketErrorName, "WSAECONNABORTED"    ); strcpy ( LastSocketErrorString, "connection aborted by peer"                      ); break;
            case WSAECONNRESET      : strcpy ( LastSocketErrorName, "WSAECONNRESET"      ); strcpy ( LastSocketErrorString, "connection reset by peer"                        ); break;
            case WSAENOBUFS         : strcpy ( LastSocketErrorName, "WSAENOBUFS"         ); strcpy ( LastSocketErrorString, "no buffer space available"                       ); break;
            case WSAEISCONN         : strcpy ( LastSocketErrorName, "WSAEISCONN"         ); strcpy ( LastSocketErrorString, "the socket is already connected"                 ); break;
            case WSAENOTCONN        : strcpy ( LastSocketErrorName, "WSAENOTCONN"        ); strcpy ( LastSocketErrorString, "socket is not connected"                         ); break;
            case WSAESHUTDOWN       : strcpy ( LastSocketErrorName, "WSAESHUTDOWN"       ); strcpy ( LastSocketErrorString, "cannot send after socket shutdown"               ); break;
            case WSAETOOMANYREFS    : strcpy ( LastSocketErrorName, "WSAETOOMANYREFS"    ); strcpy ( LastSocketErrorString, "too many references"                             ); break;
            case WSAETIMEDOUT       : strcpy ( LastSocketErrorName, "WSAETIMEDOUT"       ); strcpy ( LastSocketErrorString, "the connection timed out"                        ); break;
            case WSAECONNREFUSED    : strcpy ( LastSocketErrorName, "WSAECONNREFUSED"    ); strcpy ( LastSocketErrorString, "connection refused by peer"                      ); break;
            case WSAELOOP           : strcpy ( LastSocketErrorName, "WSAELOOP"           ); strcpy ( LastSocketErrorString, "too many levels of symbolic links"               ); break;
            case WSAENAMETOOLONG    : strcpy ( LastSocketErrorName, "WSAENAMETOOLONG"    ); strcpy ( LastSocketErrorString, "name too long"                                   ); break;
            case WSAEHOSTDOWN       : strcpy ( LastSocketErrorName, "WSAEHOSTDOWN"       ); strcpy ( LastSocketErrorString, "host is down"                                    ); break;
            case WSAEHOSTUNREACH    : strcpy ( LastSocketErrorName, "WSAEHOSTUNREACH"    ); strcpy ( LastSocketErrorString, "the host is unreachable"                         ); break;
            case WSAENOTEMPTY       : strcpy ( LastSocketErrorName, "WSAENOTEMPTY"       ); strcpy ( LastSocketErrorString, "directory not empty"                             ); break;
            case WSAEPROCLIM        : strcpy ( LastSocketErrorName, "WSAEPROCLIM"        ); strcpy ( LastSocketErrorString, "the process limitwould ne exceeded"              ); break;
            case WSAEUSERS          : strcpy ( LastSocketErrorName, "WSAEUSERS"          ); strcpy ( LastSocketErrorString, "not a valid user"                                ); break;
            case WSAEDQUOT          : strcpy ( LastSocketErrorName, "WSAEDQUOT"          ); strcpy ( LastSocketErrorString, "disk quota exceeded"                             ); break;
            case WSAESTALE          : strcpy ( LastSocketErrorName, "WSAESTALE"          ); strcpy ( LastSocketErrorString, "stale file handle"                               ); break;
            case WSAEREMOTE         : strcpy ( LastSocketErrorName, "WSAEREMOTE"         ); strcpy ( LastSocketErrorString, "the object is remote"                            ); break;
            case WSASYSNOTREADY     : strcpy ( LastSocketErrorName, "WSASYSNOTREADY"     ); strcpy ( LastSocketErrorString, "system not ready"                                ); break;
            case WSAVERNOTSUPPORTED : strcpy ( LastSocketErrorName, "WSAVERNOTSUPPORTED" ); strcpy ( LastSocketErrorString, "requested version is not supported"              ); break;
            case WSANOTINITIALISED  : strcpy ( LastSocketErrorName, "WSANOTINITIALISED"  ); strcpy ( LastSocketErrorString, "windows sockets not initialised"                 ); break;
            case WSAEDISCON         : strcpy ( LastSocketErrorName, "WSAEDISCON"         ); strcpy ( LastSocketErrorString, "connection disconected"                          ); break;
            case WSAHOST_NOT_FOUND  : strcpy ( LastSocketErrorName, "WSAHOST_NOT_FOUND"  ); strcpy ( LastSocketErrorString, "host not found"                                  ); break;
            case WSATRY_AGAIN       : strcpy ( LastSocketErrorName, "WSATRY_AGAIN"       ); strcpy ( LastSocketErrorString, "try agian"                                       ); break;
            case WSANO_RECOVERY     : strcpy ( LastSocketErrorName, "WSANO_RECOVERY"     ); strcpy ( LastSocketErrorString, "non-recoverable error"                           ); break;
            case WSANO_DATA         : strcpy ( LastSocketErrorName, "WSANO_DATA"         ); strcpy ( LastSocketErrorString, "no data record available"                        ); break;

            default : strcpy ( LastSocketErrorName, "UNKNOWN" ); CONSOL3 ( LastSocketErrorString, "unknown socket error = %d\n", SocketError );
        }

        CONSOL4 ( "Windows socket error: %d = %s %s\n", SocketError, LastSocketErrorName, LastSocketErrorString );
    }

    return ( SocketError );
}

//**********************************************************************************************************************************
