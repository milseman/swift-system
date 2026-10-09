// The ws2tcpip.h declarations of the Winsock model; see winsock2.h.

#include "winsock2.h"

typedef int socklen_t; // mirrors: ws2tcpip.h

// Windows Vista and later. inet_ntop's buffer size is a size_t, where
// POSIX's is a socklen_t.
INT inet_pton(INT Family, PCSTR pszAddrString, PVOID pAddrBuf); // mirrors: ws2tcpip.h
PCSTR inet_ntop(INT Family, const void *pAddr, PSTR pStringBuf, size_t StringBufSize); // mirrors: ws2tcpip.h

// MARK: - Name resolution

typedef struct addrinfoW { // mirrors: ws2def.h
  int ai_flags;
  int ai_family;
  int ai_socktype;
  int ai_protocol;
  size_t ai_addrlen;
  PWSTR ai_canonname;
  SOCKADDR *ai_addr;
  struct addrinfoW *ai_next;
} ADDRINFOW, *PADDRINFOW;

#define AI_PASSIVE 0x00000001 // mirrors: ws2def.h
#define AI_CANONNAME 0x00000002 // mirrors: ws2def.h
#define AI_NUMERICHOST 0x00000004 // mirrors: ws2def.h
#define AI_NUMERICSERV 0x00000008 // mirrors: ws2def.h
#define AI_ALL 0x00000100 // mirrors: ws2def.h
#define AI_ADDRCONFIG 0x00000400 // mirrors: ws2def.h
#define AI_V4MAPPED 0x00000800 // mirrors: ws2def.h

#define NI_NOFQDN 0x01 // mirrors: ws2def.h
#define NI_NUMERICHOST 0x02 // mirrors: ws2def.h
#define NI_NAMEREQD 0x04 // mirrors: ws2def.h
#define NI_NUMERICSERV 0x08 // mirrors: ws2def.h
#define NI_DGRAM 0x10 // mirrors: ws2def.h
#define NI_MAXHOST 1025 // mirrors: ws2def.h
#define NI_MAXSERV 32 // mirrors: ws2def.h

// The resolver's codes, which EAI_NONAME and its kin name.
#define WSAHOST_NOT_FOUND 11001 // mirrors: winerror.h
#define WSATRY_AGAIN 11002 // mirrors: winerror.h
#define WSANO_RECOVERY 11003 // mirrors: winerror.h
#define WSANO_DATA 11004 // mirrors: winerror.h
#define WSATYPE_NOT_FOUND 10109 // mirrors: winerror.h
#define EAI_NONAME WSAHOST_NOT_FOUND // mirrors: ws2tcpip.h
#define EAI_AGAIN WSATRY_AGAIN // mirrors: ws2tcpip.h
#define EAI_FAIL WSANO_RECOVERY // mirrors: ws2tcpip.h
#define EAI_SERVICE WSATYPE_NOT_FOUND // mirrors: ws2tcpip.h

INT GetAddrInfoW(PCWSTR pNodeName, PCWSTR pServiceName, const ADDRINFOW *pHints, // mirrors: ws2tcpip.h
                 PADDRINFOW *ppResult);
void FreeAddrInfoW(PADDRINFOW pAddrInfo); // mirrors: ws2tcpip.h
INT GetNameInfoW(const SOCKADDR *pSockaddr, socklen_t SockaddrLength, WCHAR *pNodeBuffer, // mirrors: ws2tcpip.h
                 DWORD NodeBufferSize, WCHAR *pServiceBuffer, DWORD ServiceBufferSize, INT Flags);
