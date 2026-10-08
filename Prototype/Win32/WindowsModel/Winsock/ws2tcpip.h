// The ws2tcpip.h declarations of the Winsock model; see winsock2.h.

#include "winsock2.h"

typedef int socklen_t; // mirrors: ws2tcpip.h

// Windows Vista and later. inet_ntop's buffer size is a size_t, where
// POSIX's is a socklen_t.
INT inet_pton(INT Family, PCSTR pszAddrString, PVOID pAddrBuf); // mirrors: ws2tcpip.h
PCSTR inet_ntop(INT Family, const void *pAddr, PSTR pStringBuf, size_t StringBufSize); // mirrors: ws2tcpip.h
