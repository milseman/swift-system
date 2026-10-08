// The mswsock.h declarations of the Winsock model; see winsock2.h.

#include "winsock2.h"

// guiddef.h's GUID, whose Data1 is an unsigned long, 32 bits on Windows.
// The model declares it here, since WinSDK.h doesn't.
typedef struct _GUID { // mirrors: guiddef.h
  unsigned int Data1;
  unsigned short Data2;
  unsigned short Data3;
  unsigned char Data4[8];
} GUID;

// The extension functions for messages, which WSAIoctl hands out by GUID.
// WSAID_WSARECVMSG and WSAID_WSASENDMSG are initializer lists, which
// don't import.
typedef INT (*LPFN_WSARECVMSG)(SOCKET s, LPWSAMSG lpMsg, LPDWORD lpdwNumberOfBytesRecvd, // mirrors: mswsock.h
                               LPWSAOVERLAPPED lpOverlapped,
                               LPWSAOVERLAPPED_COMPLETION_ROUTINE lpCompletionRoutine);
typedef INT (*LPFN_WSASENDMSG)(SOCKET s, LPWSAMSG lpMsg, DWORD dwFlags, // mirrors: mswsock.h
                               LPDWORD lpNumberOfBytesSent, LPWSAOVERLAPPED lpOverlapped,
                               LPWSAOVERLAPPED_COMPLETION_ROUTINE lpCompletionRoutine);

// The stream extension functions' options. Their LPFN_ typedefs, which
// return BOOL, the code spells itself (WinsockExtensions.swift).
#define TF_DISCONNECT 0x01 // mirrors: mswsock.h
#define TF_REUSE_SOCKET 0x02 // mirrors: mswsock.h
#define TF_WRITE_BEHIND 0x04 // mirrors: mswsock.h
#define TF_USE_DEFAULT_WORKER 0x00 // mirrors: mswsock.h
#define TF_USE_SYSTEM_THREAD 0x10 // mirrors: mswsock.h
#define TF_USE_KERNEL_APC 0x20 // mirrors: mswsock.h

#define SO_UPDATE_ACCEPT_CONTEXT 0x700B // mirrors: mswsock.h
#define SO_UPDATE_CONNECT_CONTEXT 0x7010 // mirrors: mswsock.h
