// A model of the Universal C Runtime declarations that System's Win32
// namespace and its tests use, for Prototype/Win32/check-windows.sh. See
// WinSDK.h. The declarations follow the UCRT's <io.h>, <fcntl.h>, and
// <stdlib.h>.

// Only the compiler's own headers, as in WinSDK.h: the macOS SDK's
// <stdint.h> and <wchar.h> would bring its C library's declarations, such
// as gmtime_r and a struct tm with tm_gmtoff, into every file that imports
// this module. wchar_t is 16 bits on Windows, so it's spelled as one here.
#include <stddef.h>

typedef __INTPTR_TYPE__ intptr_t;
typedef __UINTPTR_TYPE__ uintptr_t;

typedef void (*_invalid_parameter_handler)(const unsigned short *,
                                           const unsigned short *,
                                           const unsigned short *, unsigned int,
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

// direct.h. wchar_t is 16 bits on Windows, and 32 on macOS, so the model
// spells it as WinSDK.h's WCHAR.
unsigned short *_wgetcwd(unsigned short *_DstBuf, int _SizeInWords);
int _wchdir(const unsigned short *_Path);

// stdlib.h, with wchar_t spelled as WinSDK.h's WCHAR.
typedef int errno_t;
errno_t _wputenv_s(const unsigned short *_Name, const unsigned short *_Value);
unsigned short *_wgetenv(const unsigned short *_VarName);

// process.h. The start routine is __stdcall, which is the one calling
// convention on x64 and ARM64.
typedef unsigned (*_beginthreadex_proc_type)(void *);
uintptr_t _beginthreadex(void *_Security, unsigned _StackSize,
                         _beginthreadex_proc_type _StartAddress, void *_ArgList,
                         unsigned _InitFlag, unsigned *_ThrdAddr);

// time.h, as the UCRT declares its 64-bit functions. Its struct tm has no
// tm_gmtoff or tm_zone, and long is 32 bits on Windows, so it's int here.
// The tag isn't tm, which the macOS SDK's struct tm has, with the members
// Windows lacks: the files that import WinSDK see it too, through the
// ObjectiveC module that WindowsBool needs, and Clang rejects two
// definitions of one tag. So Swift code spells the UCRT's as `ucrt.tm`.
typedef struct _ucrt_model_tm {
  int tm_sec;
  int tm_min;
  int tm_hour;
  int tm_mday;
  int tm_mon;
  int tm_year;
  int tm_wday;
  int tm_yday;
  int tm_isdst;
} tm;

errno_t _gmtime64_s(tm *_Tm, const __time64_t *_Time);
errno_t _localtime64_s(tm *_Tm, const __time64_t *_Time);
__time64_t _mkgmtime64(tm *_Tm);
__time64_t _mktime64(tm *_Tm);
void _tzset(void);
errno_t _get_timezone(int *_TimeZone);
errno_t _get_dstbias(int *_DaylightSavingsBias);
errno_t _get_tzname(size_t *_ReturnValue, char *_Buffer, size_t _SizeInBytes, int _Index);
size_t strftime(char *_Buffer, size_t _SizeInBytes, const char *_Format, const tm *_Tm);

// errno.h
#define EINVAL 22
#define ERANGE 34
#define EOVERFLOW 132

// stdlib.h and process.h: ending the process. _exit and exit don't return.
#define EXIT_SUCCESS 0
#define EXIT_FAILURE 1
__attribute__((noreturn)) void exit(int _Code);
__attribute__((noreturn)) void _exit(int _Code);
int atexit(void (*_Function)(void));

// stdio.h. As for tm, the tag isn't macOS's, whose FILE the files that
// import WinSDK see too; Swift code spells the UCRT's names as `ucrt.FILE`
// and the like.
typedef struct _ucrt_model_iobuf { void *_Placeholder; } FILE;
#define _IOFBF 0x0000
#define _IOLBF 0x0040
#define _IONBF 0x0004
#define EOF (-1)
FILE *__acrt_iob_func(unsigned _Ix);
FILE *_wfopen(const unsigned short *_FileName, const unsigned short *_Mode);
FILE *_fdopen(int _FileHandle, const char *_Mode);
int fclose(FILE *_Stream);
int fflush(FILE *_Stream);
size_t fwrite(const void *_Buffer, size_t _ElementSize, size_t _ElementCount, FILE *_Stream);
size_t fread(void *_Buffer, size_t _ElementSize, size_t _ElementCount, FILE *_Stream);
int fputs(const char *_Buffer, FILE *_Stream);
int fputc(int _Character, FILE *_Stream);
int fgetc(FILE *_Stream);
int _fileno(FILE *_Stream);
int _fseeki64(FILE *_Stream, long long _Offset, int _Origin);
long long _ftelli64(FILE *_Stream);
int setvbuf(FILE *_Stream, char *_Buffer, int _Mode, size_t _Size);
int ferror(FILE *_Stream);
int feof(FILE *_Stream);
void clearerr(FILE *_Stream);
void _lock_file(FILE *_Stream);
void _unlock_file(FILE *_Stream);
