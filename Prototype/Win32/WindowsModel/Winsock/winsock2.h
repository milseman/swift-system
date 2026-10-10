// A model of the Winsock declarations that SystemWinSocks and its tests use,
// for Prototype/Win32/check-winsock.sh, in the manner of ../WinSDK.h: only
// what the code uses, with the types Swift gives them on 64-bit Windows.
// - SOCKET is UINT_PTR, 64 bits; `long` and `u_long` are 32 bits (LLP64),
//   so they're spelled `int` and `unsigned int` here.
// - The structures that macOS's C library also defines (sockaddr_in,
//   in_addr, linger and the rest) have private tags: Clang rejects two
//   different definitions of one tag when a test file sees both modules
//   (WinSDK.h does the same for sockaddr). Code reaches them through the
//   SDK's typedef names, SOCKADDR_IN and the like, which Windows has too.
// - C enums have an `int` underlying type, as MSVC gives them.
// - Macros that the importer can't evaluate on Windows (casts of an
//   expression, function-like macros) are left out; the overlay model, or
//   the code, declares them, as on Windows.
// Each declaration names the SDK header it comes from. Constant values match
// the SDK headers; check-winsock.sh compares them with Rust's standard
// library bindings, which are generated from Microsoft's Windows metadata,
// where those have them.

// Declarations from WinSDK.h that this model uses: CHAR, WORD, DWORD, LONG,
// ULONG, USHORT, SHORT, INT, PVOID, LPVOID, LPDWORD, HANDLE, ULONG_PTR,
// OVERLAPPED and LPOVERLAPPED, ADDRESS_FAMILY, SOCKADDR (with its private
// tag), and the AF_UNSPEC, AF_INET and AF_INET6 macros.
#include <WinSDK.h>

typedef unsigned char UCHAR; // mirrors: winnt.h
typedef char *PSTR; // mirrors: winnt.h
typedef const char *PCSTR; // mirrors: winnt.h
typedef unsigned long long UINT_PTR; // mirrors: basetsd.h

typedef unsigned char u_char; // mirrors: winsock2.h
typedef unsigned short u_short; // mirrors: winsock2.h
typedef unsigned int u_int; // mirrors: winsock2.h
typedef unsigned int u_long; // mirrors: winsock2.h

typedef UINT_PTR SOCKET; // mirrors: winsock2.h
// INVALID_SOCKET is (SOCKET)(~0), which doesn't import: WinSDK+Winsock.swift.
#define SOCKET_ERROR (-1) // mirrors: winsock2.h
typedef unsigned int GROUP; // mirrors: winsock2.h

// MARK: - Startup and errors

#define WSADESCRIPTION_LEN 256 // mirrors: winsock2.h
#define WSASYS_STATUS_LEN 128 // mirrors: winsock2.h

// The 64-bit layout: the counts and the vendor pointer come first.
typedef struct WSAData { // mirrors: winsock2.h
  WORD wVersion;
  WORD wHighVersion;
  unsigned short iMaxSockets;
  unsigned short iMaxUdpDg;
  char *lpVendorInfo;
  char szDescription[WSADESCRIPTION_LEN + 1];
  char szSystemStatus[WSASYS_STATUS_LEN + 1];
} WSADATA, *LPWSADATA;

int WSAStartup(WORD wVersionRequested, LPWSADATA lpWSAData); // mirrors: winsock2.h
int WSAGetLastError(void); // mirrors: winsock2.h
void WSASetLastError(int iError); // mirrors: winsock2.h

// winerror.h spells these with an L suffix, a 32-bit long on Windows; here
// they're ints, which import as the same type.
#define WSAEINTR 10004 // mirrors: winerror.h
#define WSAEBADF 10009 // mirrors: winerror.h
#define WSAEACCES 10013 // mirrors: winerror.h
#define WSAEFAULT 10014 // mirrors: winerror.h
#define WSAEINVAL 10022 // mirrors: winerror.h
#define WSAEMFILE 10024 // mirrors: winerror.h
#define WSAEWOULDBLOCK 10035 // mirrors: winerror.h
#define WSAEINPROGRESS 10036 // mirrors: winerror.h
#define WSAEALREADY 10037 // mirrors: winerror.h
#define WSAENOTSOCK 10038 // mirrors: winerror.h
#define WSAEDESTADDRREQ 10039 // mirrors: winerror.h
#define WSAEMSGSIZE 10040 // mirrors: winerror.h
#define WSAEPROTOTYPE 10041 // mirrors: winerror.h
#define WSAENOPROTOOPT 10042 // mirrors: winerror.h
#define WSAEPROTONOSUPPORT 10043 // mirrors: winerror.h
#define WSAESOCKTNOSUPPORT 10044 // mirrors: winerror.h
#define WSAEOPNOTSUPP 10045 // mirrors: winerror.h
#define WSAEPFNOSUPPORT 10046 // mirrors: winerror.h
#define WSAEAFNOSUPPORT 10047 // mirrors: winerror.h
#define WSAEADDRINUSE 10048 // mirrors: winerror.h
#define WSAEADDRNOTAVAIL 10049 // mirrors: winerror.h
#define WSAENETDOWN 10050 // mirrors: winerror.h
#define WSAENETUNREACH 10051 // mirrors: winerror.h
#define WSAENETRESET 10052 // mirrors: winerror.h
#define WSAECONNABORTED 10053 // mirrors: winerror.h
#define WSAECONNRESET 10054 // mirrors: winerror.h
#define WSAENOBUFS 10055 // mirrors: winerror.h
#define WSAEISCONN 10056 // mirrors: winerror.h
#define WSAENOTCONN 10057 // mirrors: winerror.h
#define WSAESHUTDOWN 10058 // mirrors: winerror.h
#define WSAETOOMANYREFS 10059 // mirrors: winerror.h
#define WSAETIMEDOUT 10060 // mirrors: winerror.h
#define WSAECONNREFUSED 10061 // mirrors: winerror.h
#define WSAELOOP 10062 // mirrors: winerror.h
#define WSAENAMETOOLONG 10063 // mirrors: winerror.h
#define WSAEHOSTDOWN 10064 // mirrors: winerror.h
#define WSAEHOSTUNREACH 10065 // mirrors: winerror.h
#define WSAENOTEMPTY 10066 // mirrors: winerror.h
#define WSAEPROCLIM 10067 // mirrors: winerror.h
#define WSAEUSERS 10068 // mirrors: winerror.h
#define WSAEDQUOT 10069 // mirrors: winerror.h
#define WSAESTALE 10070 // mirrors: winerror.h
#define WSAEREMOTE 10071 // mirrors: winerror.h
#define WSASYSNOTREADY 10091 // mirrors: winerror.h
#define WSAVERNOTSUPPORTED 10092 // mirrors: winerror.h
#define WSANOTINITIALISED 10093 // mirrors: winerror.h
#define WSAEDISCON 10101 // mirrors: winerror.h
#define WSAENOMORE 10102 // mirrors: winerror.h
#define WSAECANCELLED 10103 // mirrors: winerror.h
#define WSAEINVALIDPROCTABLE 10104 // mirrors: winerror.h
#define WSAEINVALIDPROVIDER 10105 // mirrors: winerror.h
#define WSAEPROVIDERFAILEDINIT 10106 // mirrors: winerror.h
#define WSASYSCALLFAILURE 10107 // mirrors: winerror.h
#define WSASERVICE_NOT_FOUND 10108 // mirrors: winerror.h
#define WSA_E_NO_MORE 10110 // mirrors: winerror.h
#define WSA_E_CANCELLED 10111 // mirrors: winerror.h
#define WSAEREFUSED 10112 // mirrors: winerror.h

// MARK: - Families, types and protocols

#define AF_UNIX 1 // mirrors: ws2def.h
#define PF_UNSPEC AF_UNSPEC // mirrors: ws2def.h
#define PF_UNIX AF_UNIX // mirrors: ws2def.h
#define PF_INET AF_INET // mirrors: ws2def.h
#define PF_INET6 AF_INET6 // mirrors: ws2def.h

#define SOCK_STREAM 1 // mirrors: winsock2.h
#define SOCK_DGRAM 2 // mirrors: winsock2.h
#define SOCK_RAW 3 // mirrors: winsock2.h
#define SOCK_RDM 4 // mirrors: winsock2.h
#define SOCK_SEQPACKET 5 // mirrors: winsock2.h

// IPPROTO_IP is a macro; the others are enumerators of IPPROTO, which
// imports as a struct, so Swift code reads them as IPPROTO_TCP.rawValue.
#define IPPROTO_IP 0 // mirrors: ws2def.h
typedef enum : int { // mirrors: ws2def.h
  IPPROTO_HOPOPTS = 0,
  IPPROTO_ICMP = 1,
  IPPROTO_IGMP = 2,
  IPPROTO_IPV4 = 4,
  IPPROTO_TCP = 6,
  IPPROTO_UDP = 17,
  IPPROTO_IPV6 = 41,
  IPPROTO_ICMPV6 = 58,
  IPPROTO_RAW = 255,
} IPPROTO;

// MARK: - Socket flags and messages

#define WSA_FLAG_OVERLAPPED 0x01 // mirrors: winsock2.h
#define WSA_FLAG_NO_HANDLE_INHERIT 0x80 // mirrors: winsock2.h

#define MSG_OOB 0x1 // mirrors: ws2def.h
#define MSG_PEEK 0x2 // mirrors: ws2def.h
#define MSG_DONTROUTE 0x4 // mirrors: ws2def.h
#define MSG_WAITALL 0x8 // mirrors: ws2def.h
#define MSG_PUSH_IMMEDIATE 0x20 // mirrors: ws2def.h
#define MSG_TRUNC 0x0100 // mirrors: ws2def.h
#define MSG_CTRUNC 0x0200 // mirrors: ws2def.h

#define SD_RECEIVE 0x00 // mirrors: winsock2.h
#define SD_SEND 0x01 // mirrors: winsock2.h
#define SD_BOTH 0x02 // mirrors: winsock2.h

// MARK: - Options

#define SOL_SOCKET 0xffff // mirrors: winsock2.h
#define SO_DEBUG 0x0001 // mirrors: winsock2.h
#define SO_ACCEPTCONN 0x0002 // mirrors: winsock2.h
#define SO_REUSEADDR 0x0004 // mirrors: winsock2.h
#define SO_KEEPALIVE 0x0008 // mirrors: winsock2.h
#define SO_DONTROUTE 0x0010 // mirrors: winsock2.h
#define SO_BROADCAST 0x0020 // mirrors: winsock2.h
#define SO_LINGER 0x0080 // mirrors: winsock2.h
#define SO_OOBINLINE 0x0100 // mirrors: winsock2.h
// SO_DONTLINGER and SO_EXCLUSIVEADDRUSE are ((int)(~SO_LINGER)) and
// ((int)(~SO_REUSEADDR)), which don't import.
#define SO_SNDBUF 0x1001 // mirrors: winsock2.h
#define SO_RCVBUF 0x1002 // mirrors: winsock2.h
#define SO_SNDTIMEO 0x1005 // mirrors: winsock2.h
#define SO_RCVTIMEO 0x1006 // mirrors: winsock2.h
#define SO_ERROR 0x1007 // mirrors: winsock2.h
#define SO_TYPE 0x1008 // mirrors: winsock2.h
#define SO_REUSE_UNICASTPORT 0x3007 // mirrors: ws2def.h

#define TCP_NODELAY 0x0001 // mirrors: ws2def.h
#define TCP_KEEPALIVE 3 // mirrors: ws2ipdef.h
#define TCP_MAXSEG 4 // mirrors: ws2ipdef.h
#define TCP_KEEPCNT 16 // mirrors: ws2ipdef.h
#define TCP_KEEPIDLE TCP_KEEPALIVE // mirrors: ws2ipdef.h
#define TCP_KEEPINTVL 17 // mirrors: ws2ipdef.h

#define IP_HDRINCL 2 // mirrors: ws2ipdef.h
#define IP_TOS 3 // mirrors: ws2ipdef.h
#define IP_TTL 4 // mirrors: ws2ipdef.h
#define IP_MULTICAST_IF 9 // mirrors: ws2ipdef.h
#define IP_MULTICAST_TTL 10 // mirrors: ws2ipdef.h
#define IP_MULTICAST_LOOP 11 // mirrors: ws2ipdef.h
#define IP_ADD_MEMBERSHIP 12 // mirrors: ws2ipdef.h
#define IP_DROP_MEMBERSHIP 13 // mirrors: ws2ipdef.h
#define IP_PKTINFO 19 // mirrors: ws2ipdef.h
#define IP_RECVTCLASS 40 // mirrors: ws2ipdef.h
#define IP_RECVTOS 40 // mirrors: ws2ipdef.h

#define IPV6_UNICAST_HOPS 4 // mirrors: ws2ipdef.h
#define IPV6_MULTICAST_IF 9 // mirrors: ws2ipdef.h
#define IPV6_MULTICAST_HOPS 10 // mirrors: ws2ipdef.h
#define IPV6_MULTICAST_LOOP 11 // mirrors: ws2ipdef.h
#define IPV6_ADD_MEMBERSHIP 12 // mirrors: ws2ipdef.h
#define IPV6_JOIN_GROUP IPV6_ADD_MEMBERSHIP // mirrors: ws2ipdef.h
#define IPV6_DROP_MEMBERSHIP 13 // mirrors: ws2ipdef.h
#define IPV6_LEAVE_GROUP IPV6_DROP_MEMBERSHIP // mirrors: ws2ipdef.h
#define IPV6_PKTINFO 19 // mirrors: ws2ipdef.h
#define IPV6_V6ONLY 27 // mirrors: ws2ipdef.h
#define IPV6_TCLASS 39 // mirrors: ws2ipdef.h
#define IPV6_RECVTCLASS 40 // mirrors: ws2ipdef.h

// MARK: - Addresses

// inaddr.h's s_addr is a macro for S_un.S_addr, which doesn't import.
typedef struct _winsock_model_in_addr { // mirrors: inaddr.h
  union {
    struct {
      UCHAR s_b1, s_b2, s_b3, s_b4;
    } S_un_b;
    struct {
      USHORT s_w1, s_w2;
    } S_un_w;
    ULONG S_addr;
  } S_un;
} IN_ADDR, *PIN_ADDR, *LPIN_ADDR;

// in6addr.h's s6_addr is a macro for u.Byte, which doesn't import.
typedef struct _winsock_model_in6_addr { // mirrors: in6addr.h
  union {
    UCHAR Byte[16];
    USHORT Word[8];
  } u;
} IN6_ADDR, *PIN6_ADDR, *LPIN6_ADDR;

typedef struct _winsock_model_sockaddr_in { // mirrors: ws2def.h
  ADDRESS_FAMILY sin_family;
  USHORT sin_port;
  IN_ADDR sin_addr;
  CHAR sin_zero[8];
} SOCKADDR_IN, *PSOCKADDR_IN;

// The SDK's SCOPE_ID splits Value into Zone and Level bit-fields.
typedef struct { // mirrors: ws2def.h
  ULONG Value;
} SCOPE_ID, *PSCOPE_ID;

typedef struct _winsock_model_sockaddr_in6 { // mirrors: ws2ipdef.h
  ADDRESS_FAMILY sin6_family;
  USHORT sin6_port;
  ULONG sin6_flowinfo;
  IN6_ADDR sin6_addr;
  union {
    ULONG sin6_scope_id;
    SCOPE_ID sin6_scope_struct;
  };
} SOCKADDR_IN6_LH, *PSOCKADDR_IN6_LH, SOCKADDR_IN6, *PSOCKADDR_IN6;

typedef struct _winsock_model_sockaddr_storage { // mirrors: ws2def.h
  ADDRESS_FAMILY ss_family;
  CHAR __ss_pad1[6];
  long long __ss_align;
  CHAR __ss_pad2[112];
} SOCKADDR_STORAGE_LH, *PSOCKADDR_STORAGE_LH, SOCKADDR_STORAGE, *PSOCKADDR_STORAGE;

#define INET_ADDRSTRLEN 22 // mirrors: ws2ipdef.h
#define INET6_ADDRSTRLEN 65 // mirrors: ws2ipdef.h

typedef struct _winsock_model_linger { // mirrors: winsock2.h
  u_short l_onoff;
  u_short l_linger;
} LINGER, *PLINGER, *LPLINGER;

typedef struct _winsock_model_ip_mreq { // mirrors: ws2ipdef.h
  IN_ADDR imr_multiaddr;
  IN_ADDR imr_interface;
} IP_MREQ, *PIP_MREQ;

typedef struct _winsock_model_ipv6_mreq { // mirrors: ws2ipdef.h
  IN6_ADDR ipv6mr_multiaddr;
  ULONG ipv6mr_interface;
} IPV6_MREQ, *PIPV6_MREQ;

// MARK: - Polling

typedef struct _winsock_model_pollfd { // mirrors: winsock2.h
  SOCKET fd;
  SHORT events;
  SHORT revents;
} WSAPOLLFD, *PWSAPOLLFD, *LPWSAPOLLFD;

#define POLLRDNORM 0x0100 // mirrors: winsock2.h
#define POLLRDBAND 0x0200 // mirrors: winsock2.h
#define POLLIN (POLLRDNORM | POLLRDBAND) // mirrors: winsock2.h
#define POLLPRI 0x0400 // mirrors: winsock2.h
#define POLLWRNORM 0x0010 // mirrors: winsock2.h
#define POLLOUT (POLLWRNORM) // mirrors: winsock2.h
#define POLLWRBAND 0x0020 // mirrors: winsock2.h
#define POLLERR 0x0001 // mirrors: winsock2.h
#define POLLHUP 0x0002 // mirrors: winsock2.h
#define POLLNVAL 0x0004 // mirrors: winsock2.h

// MARK: - Messages and overlapped I/O

typedef struct _WSABUF { // mirrors: ws2def.h
  ULONG len;
  CHAR *buf;
} WSABUF, *LPWSABUF;

typedef struct _WSAMSG { // mirrors: ws2def.h
  LPSOCKADDR name;
  INT namelen;
  LPWSABUF lpBuffers;
  ULONG dwBufferCount;
  WSABUF Control;
  ULONG dwFlags;
} WSAMSG, *PWSAMSG, *LPWSAMSG;

typedef struct _WSACMSGHDR { // mirrors: ws2def.h
  SIZE_T cmsg_len;
  INT cmsg_level;
  INT cmsg_type;
} WSACMSGHDR, *PWSACMSGHDR, *LPWSACMSGHDR;

// WSAOVERLAPPED is a macro for OVERLAPPED, which WinSDK.h declares.
typedef struct _OVERLAPPED *LPWSAOVERLAPPED; // mirrors: winsock2.h
typedef void (*LPWSAOVERLAPPED_COMPLETION_ROUTINE)(DWORD dwError, DWORD cbTransferred, // mirrors: winsock2.h
                                                   LPWSAOVERLAPPED lpOverlapped, DWORD dwFlags);

// Overlapped operations' codes, which are the Win32 codes WinSDK.h has.
#define WSA_IO_PENDING (ERROR_IO_PENDING) // mirrors: winsock2.h
#define WSA_IO_INCOMPLETE (ERROR_IO_INCOMPLETE) // mirrors: winsock2.h

int WSASend(SOCKET s, LPWSABUF lpBuffers, DWORD dwBufferCount, LPDWORD lpNumberOfBytesSent, // mirrors: winsock2.h
            DWORD dwFlags, LPWSAOVERLAPPED lpOverlapped,
            LPWSAOVERLAPPED_COMPLETION_ROUTINE lpCompletionRoutine);
int WSARecv(SOCKET s, LPWSABUF lpBuffers, DWORD dwBufferCount, LPDWORD lpNumberOfBytesRecvd, // mirrors: winsock2.h
            LPDWORD lpFlags, LPWSAOVERLAPPED lpOverlapped,
            LPWSAOVERLAPPED_COMPLETION_ROUTINE lpCompletionRoutine);
BOOL WSAGetOverlappedResult(SOCKET s, LPWSAOVERLAPPED lpOverlapped, LPDWORD lpcbTransfer, // mirrors: winsock2.h
                            BOOL fWait, LPDWORD lpdwFlags);

// The IOC_ macros; _WSAIORW and the SIO_ codes built from it are
// function-like, so they don't import.
#define IOC_OUT 0x40000000 // mirrors: winsock2.h
#define IOC_IN 0x80000000 // mirrors: winsock2.h
#define IOC_INOUT (IOC_IN | IOC_OUT) // mirrors: winsock2.h
#define IOC_WS2 0x08000000 // mirrors: winsock2.h

int WSAIoctl(SOCKET s, DWORD dwIoControlCode, LPVOID lpvInBuffer, DWORD cbInBuffer, // mirrors: winsock2.h
             LPVOID lpvOutBuffer, DWORD cbOutBuffer, LPDWORD lpcbBytesReturned,
             LPWSAOVERLAPPED lpOverlapped, LPWSAOVERLAPPED_COMPLETION_ROUTINE lpCompletionRoutine);

// MARK: - Functions

// The SDK's WSAPROTOCOL_INFOW is a complete structure, which this model
// leaves incomplete; the code passes only nil for it.
typedef struct _WSAPROTOCOL_INFOW WSAPROTOCOL_INFOW, *LPWSAPROTOCOL_INFOW; // mirrors: winsock2.h

SOCKET WSASocketW(int af, int type, int protocol, LPWSAPROTOCOL_INFOW lpProtocolInfo, // mirrors: winsock2.h
                  GROUP g, DWORD dwFlags);
int closesocket(SOCKET s); // mirrors: winsock2.h
int shutdown(SOCKET s, int how); // mirrors: winsock2.h
int bind(SOCKET s, const SOCKADDR *name, int namelen); // mirrors: winsock2.h
int listen(SOCKET s, int backlog); // mirrors: winsock2.h
SOCKET accept(SOCKET s, SOCKADDR *addr, int *addrlen); // mirrors: winsock2.h
int connect(SOCKET s, const SOCKADDR *name, int namelen); // mirrors: winsock2.h
int send(SOCKET s, const char *buf, int len, int flags); // mirrors: winsock2.h
int recv(SOCKET s, char *buf, int len, int flags); // mirrors: winsock2.h
int sendto(SOCKET s, const char *buf, int len, int flags, const SOCKADDR *to, int tolen); // mirrors: winsock2.h
int recvfrom(SOCKET s, char *buf, int len, int flags, SOCKADDR *from, int *fromlen); // mirrors: winsock2.h
int getsockopt(SOCKET s, int level, int optname, char *optval, int *optlen); // mirrors: winsock2.h
int setsockopt(SOCKET s, int level, int optname, const char *optval, int optlen); // mirrors: winsock2.h
int getsockname(SOCKET s, SOCKADDR *name, int *namelen); // mirrors: winsock2.h
int getpeername(SOCKET s, SOCKADDR *name, int *namelen); // mirrors: winsock2.h
// cmd is a long, 32 bits on Windows.
int ioctlsocket(SOCKET s, int cmd, u_long *argp); // mirrors: winsock2.h
// Windows Vista and later.
int WSAPoll(LPWSAPOLLFD fdArray, ULONG fds, INT timeout); // mirrors: winsock2.h
