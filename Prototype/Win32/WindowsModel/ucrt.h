// A model of the Universal C Runtime declarations that System's Win32
// namespace and its tests use, for Prototype/Win32/check-windows.sh. See
// WinSDK.h. The declarations follow the UCRT's <io.h>, <fcntl.h>, and
// <stdlib.h>.

#include <stdint.h>
#include <wchar.h>

typedef void (*_invalid_parameter_handler)(const wchar_t *, const wchar_t *,
                                           const wchar_t *, unsigned int,
                                           uintptr_t);
_invalid_parameter_handler
_set_thread_local_invalid_parameter_handler(_invalid_parameter_handler _Handler);

intptr_t _get_osfhandle(int _FileHandle);
int _open_osfhandle(intptr_t _OSFileHandle, int _Flags);
int _setmode(int _FileHandle, int _Mode);
int _close(int _FileHandle);
int _read(int _FileHandle, void *_DstBuf, unsigned int _MaxCharCount);
int _write(int _FileHandle, const void *_Buf, unsigned int _MaxCharCount);

#define _O_RDONLY 0x0000
#define _O_WRONLY 0x0001
#define _O_RDWR 0x0002
#define _O_APPEND 0x0008
#define _O_NOINHERIT 0x0080
#define _O_TEXT 0x4000
#define _O_BINARY 0x8000
#define _O_WTEXT 0x10000
#define _O_U16TEXT 0x20000
#define _O_U8TEXT 0x40000

#define _MAX_PATH 260

// time.h
typedef long long __time64_t;
__time64_t _time64(__time64_t *_Time);

// io.h
int _isatty(int _FileHandle);
