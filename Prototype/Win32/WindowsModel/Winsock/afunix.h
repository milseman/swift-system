// The afunix.h declarations of the Winsock model; see winsock2.h. Windows 10
// version 1803 and later have Unix domain stream sockets.

#include "winsock2.h"

#define UNIX_PATH_MAX 108 // mirrors: afunix.h

// macOS's C library has a sockaddr_un too, so the tag is private.
typedef struct _winsock_model_sockaddr_un { // mirrors: afunix.h
  ADDRESS_FAMILY sun_family;
  char sun_path[UNIX_PATH_MAX];
} SOCKADDR_UN, *PSOCKADDR_UN;
