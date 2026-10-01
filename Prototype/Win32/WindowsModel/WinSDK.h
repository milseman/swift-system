// A model of the Windows SDK declarations that System's Win32 namespace and
// its tests use, for Prototype/Win32/check-windows.sh to compile that code
// on macOS. It declares only what the code uses, with the types Swift gives
// them on 64-bit Windows:
// - Windows is LLP64, so the SDK's `long` types (DWORD, LONG, ULONG,
//   HRESULT) are 32 bits here, and `L`-suffixed macros are `int`s.
// - WCHAR is 16 bits.
// - Swift imports Windows' BOOL as WindowsBool, which it bridges to Bool in
//   function signatures. On macOS the importer does the same for a BOOL that
//   is `bool`, as ObjCBool, and WinSDK.swift aliases WindowsBool to it.
// - C enums are `int`, as MSVC makes them.
// - No pointer carries a nullability annotation, as in the SDK, so pointers
//   in signatures import as implicitly unwrapped optionals.
// The function signatures follow the Win32 documentation, and the constant
// values match the SDK headers (checked against the Windows metadata that
// Rust's standard library bindings are generated from).

#include <stdarg.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

typedef bool BOOL;
typedef unsigned char BYTE;
typedef BYTE BOOLEAN;
typedef unsigned short WORD;
typedef unsigned int DWORD;
typedef int LONG;
typedef unsigned int ULONG;
typedef long long LONGLONG;
typedef unsigned long long ULONGLONG;
typedef long long INT_PTR;
typedef unsigned long long ULONG_PTR;
typedef ULONG_PTR DWORD_PTR;
typedef unsigned int UINT;
typedef unsigned short WCHAR;
typedef char CHAR;

typedef void *PVOID;
typedef void *LPVOID;
typedef const void *LPCVOID;
typedef void *HANDLE;
typedef HANDLE *PHANDLE;
typedef HANDLE *LPHANDLE;
typedef HANDLE HLOCAL;
typedef PVOID PSECURITY_DESCRIPTOR;
typedef PVOID PSID;
typedef DWORD *LPDWORD;
typedef DWORD *PDWORD;
typedef ULONG *PULONG;
typedef WCHAR *LPWSTR;
typedef WCHAR *PWSTR;
typedef const WCHAR *LPCWSTR;
typedef const WCHAR *PCWSTR;
typedef const CHAR *LPCSTR;
typedef LONG HRESULT;
typedef LONG NTSTATUS;
typedef DWORD ACCESS_MASK;

struct HINSTANCE__ { int unused; };
typedef struct HINSTANCE__ *HINSTANCE;
typedef HINSTANCE HMODULE;
typedef INT_PTR (*FARPROC)(void);

#define MAX_PATH 260

// winnt.h

typedef union _LARGE_INTEGER {
  struct {
    DWORD LowPart;
    LONG HighPart;
  };
  struct {
    DWORD LowPart;
    LONG HighPart;
  } u;
  LONGLONG QuadPart;
} LARGE_INTEGER, *PLARGE_INTEGER;

#define DELETE 0x00010000
#define READ_CONTROL 0x00020000
#define WRITE_DAC 0x00040000
#define WRITE_OWNER 0x00080000
#define SYNCHRONIZE 0x00100000
#define MAXIMUM_ALLOWED 0x02000000
#define GENERIC_READ 0x80000000U
#define GENERIC_WRITE 0x40000000
#define GENERIC_EXECUTE 0x20000000
#define GENERIC_ALL 0x10000000

#define FILE_READ_DATA 0x0001
#define FILE_LIST_DIRECTORY 0x0001
#define FILE_WRITE_DATA 0x0002
#define FILE_ADD_FILE 0x0002
#define FILE_APPEND_DATA 0x0004
#define FILE_ADD_SUBDIRECTORY 0x0004
#define FILE_READ_EA 0x0008
#define FILE_WRITE_EA 0x0010
#define FILE_EXECUTE 0x0020
#define FILE_TRAVERSE 0x0020
#define FILE_DELETE_CHILD 0x0040
#define FILE_READ_ATTRIBUTES 0x0080
#define FILE_WRITE_ATTRIBUTES 0x0100

#define FILE_SHARE_READ 0x00000001
#define FILE_SHARE_WRITE 0x00000002
#define FILE_SHARE_DELETE 0x00000004

#define FILE_ATTRIBUTE_READONLY 0x00000001
#define FILE_ATTRIBUTE_HIDDEN 0x00000002
#define FILE_ATTRIBUTE_SYSTEM 0x00000004
#define FILE_ATTRIBUTE_DIRECTORY 0x00000010
#define FILE_ATTRIBUTE_ARCHIVE 0x00000020
#define FILE_ATTRIBUTE_NORMAL 0x00000080
#define FILE_ATTRIBUTE_TEMPORARY 0x00000100
#define FILE_ATTRIBUTE_OFFLINE 0x00001000
#define FILE_ATTRIBUTE_ENCRYPTED 0x00004000

#define FILE_CASE_SENSITIVE_SEARCH 0x00000001
#define FILE_CASE_PRESERVED_NAMES 0x00000002
#define FILE_UNICODE_ON_DISK 0x00000004
#define FILE_PERSISTENT_ACLS 0x00000008
#define FILE_FILE_COMPRESSION 0x00000010
#define FILE_VOLUME_QUOTAS 0x00000020
#define FILE_SUPPORTS_SPARSE_FILES 0x00000040
#define FILE_SUPPORTS_REPARSE_POINTS 0x00000080
#define FILE_SUPPORTS_REMOTE_STORAGE 0x00000100
#define FILE_RETURNS_CLEANUP_RESULT_INFO 0x00000200
#define FILE_SUPPORTS_POSIX_UNLINK_RENAME 0x00000400
#define FILE_SUPPORTS_BYPASS_IO 0x00000800
#define FILE_SUPPORTS_STREAM_SNAPSHOTS 0x00001000
#define FILE_SUPPORTS_CASE_SENSITIVE_DIRS 0x00002000
#define FILE_VOLUME_IS_COMPRESSED 0x00008000
#define FILE_SUPPORTS_OBJECT_IDS 0x00010000
#define FILE_SUPPORTS_ENCRYPTION 0x00020000
#define FILE_NAMED_STREAMS 0x00040000
#define FILE_READ_ONLY_VOLUME 0x00080000
#define FILE_SEQUENTIAL_WRITE_ONCE 0x00100000
#define FILE_SUPPORTS_TRANSACTIONS 0x00200000
#define FILE_SUPPORTS_HARD_LINKS 0x00400000
#define FILE_SUPPORTS_EXTENDED_ATTRIBUTES 0x00800000
#define FILE_SUPPORTS_OPEN_BY_FILE_ID 0x01000000
#define FILE_SUPPORTS_USN_JOURNAL 0x02000000
#define FILE_SUPPORTS_INTEGRITY_STREAMS 0x04000000
#define FILE_SUPPORTS_BLOCK_REFCOUNTING 0x08000000
#define FILE_SUPPORTS_SPARSE_VDL 0x10000000
#define FILE_DAX_VOLUME 0x20000000
#define FILE_SUPPORTS_GHOSTING 0x40000000

#define DUPLICATE_CLOSE_SOURCE 0x00000001
#define DUPLICATE_SAME_ACCESS 0x00000002

// winerror.h

#define ERROR_SUCCESS 0
#define ERROR_INVALID_FUNCTION 1
#define ERROR_FILE_NOT_FOUND 2
#define ERROR_PATH_NOT_FOUND 3
#define ERROR_ACCESS_DENIED 5
#define ERROR_INVALID_HANDLE 6
#define ERROR_NOT_READY 21
#define ERROR_CRC 23
#define ERROR_WRITE_FAULT 29
#define ERROR_SHARING_VIOLATION 32
#define ERROR_LOCK_VIOLATION 33
#define ERROR_HANDLE_EOF 38
#define ERROR_NOT_SUPPORTED 50
#define ERROR_FILE_EXISTS 80
#define ERROR_INVALID_PARAMETER 87
#define ERROR_BROKEN_PIPE 109
#define ERROR_DISK_FULL 112
#define ERROR_INSUFFICIENT_BUFFER 122
#define ERROR_INVALID_NAME 123
#define ERROR_MOD_NOT_FOUND 126
#define ERROR_PROC_NOT_FOUND 127
#define ERROR_NEGATIVE_SEEK 131
#define ERROR_NOT_LOCKED 158
#define ERROR_BAD_PATHNAME 161
#define ERROR_ALREADY_EXISTS 183
#define ERROR_FILE_TOO_LARGE 223
#define ERROR_PIPE_BUSY 231
#define ERROR_NO_DATA 232
#define ERROR_PIPE_NOT_CONNECTED 233
#define ERROR_MORE_DATA 234
#define ERROR_DIRECTORY 267
#define ERROR_OPERATION_ABORTED 995
#define ERROR_IO_PENDING 997
#define ERROR_USER_MAPPED_FILE 1224
#define ERROR_CANT_RESOLVE_FILENAME 1921
#define FACILITY_WIN32 7

// minwinbase.h, fileapi.h, handleapi.h, winbase.h

typedef struct _SECURITY_ATTRIBUTES {
  DWORD nLength;
  LPVOID lpSecurityDescriptor;
  BOOL bInheritHandle;
} SECURITY_ATTRIBUTES, *PSECURITY_ATTRIBUTES, *LPSECURITY_ATTRIBUTES;

typedef struct _OVERLAPPED {
  ULONG_PTR Internal;
  ULONG_PTR InternalHigh;
  union {
    struct {
      DWORD Offset;
      DWORD OffsetHigh;
    };
    PVOID Pointer;
  };
  HANDLE hEvent;
} OVERLAPPED, *LPOVERLAPPED;

typedef enum _FILE_INFO_BY_HANDLE_CLASS : int {
  FileBasicInfo,
  FileStandardInfo,
  FileNameInfo,
  FileRenameInfo,
  FileDispositionInfo,
  FileAllocationInfo,
  FileEndOfFileInfo,
  FileStreamInfo,
  FileCompressionInfo,
  FileAttributeTagInfo,
  FileIdBothDirectoryInfo,
  FileIdBothDirectoryRestartInfo,
  FileIoPriorityHintInfo,
  FileRemoteProtocolInfo,
  FileFullDirectoryInfo,
  FileFullDirectoryRestartInfo,
  FileStorageInfo,
  FileAlignmentInfo,
  FileIdInfo,
  FileIdExtdDirectoryInfo,
  FileIdExtdDirectoryRestartInfo,
  FileDispositionInfoEx,
  FileRenameInfoEx,
  FileCaseSensitiveInfo,
  FileNormalizedNameInfo,
  MaximumFileInfoByHandleClass
} FILE_INFO_BY_HANDLE_CLASS;

typedef struct _FILE_STANDARD_INFO {
  LARGE_INTEGER AllocationSize;
  LARGE_INTEGER EndOfFile;
  DWORD NumberOfLinks;
  BOOLEAN DeletePending;
  BOOLEAN Directory;
} FILE_STANDARD_INFO, *PFILE_STANDARD_INFO;

typedef struct _FILE_END_OF_FILE_INFO {
  LARGE_INTEGER EndOfFile;
} FILE_END_OF_FILE_INFO, *PFILE_END_OF_FILE_INFO;

#define CREATE_NEW 1
#define CREATE_ALWAYS 2
#define OPEN_EXISTING 3
#define OPEN_ALWAYS 4
#define TRUNCATE_EXISTING 5

#define FILE_FLAG_WRITE_THROUGH 0x80000000U
#define FILE_FLAG_OVERLAPPED 0x40000000
#define FILE_FLAG_NO_BUFFERING 0x20000000
#define FILE_FLAG_RANDOM_ACCESS 0x10000000
#define FILE_FLAG_SEQUENTIAL_SCAN 0x08000000
#define FILE_FLAG_DELETE_ON_CLOSE 0x04000000
#define FILE_FLAG_BACKUP_SEMANTICS 0x02000000
#define FILE_FLAG_POSIX_SEMANTICS 0x01000000
#define FILE_FLAG_SESSION_AWARE 0x00800000
#define FILE_FLAG_OPEN_REPARSE_POINT 0x00200000
#define FILE_FLAG_OPEN_NO_RECALL 0x00100000

#define FILE_TYPE_UNKNOWN 0x0000
#define FILE_TYPE_DISK 0x0001
#define FILE_TYPE_CHAR 0x0002
#define FILE_TYPE_PIPE 0x0003

#define FILE_BEGIN 0
#define FILE_CURRENT 1
#define FILE_END 2

#define LOCKFILE_FAIL_IMMEDIATELY 0x00000001
#define LOCKFILE_EXCLUSIVE_LOCK 0x00000002

#define HANDLE_FLAG_PROTECT_FROM_CLOSE 0x00000002

#define VOLUME_NAME_DOS 0x0
#define VOLUME_NAME_GUID 0x1
#define VOLUME_NAME_NT 0x2
#define VOLUME_NAME_NONE 0x4
#define FILE_NAME_NORMALIZED 0x0
#define FILE_NAME_OPENED 0x8

#define MOVEFILE_REPLACE_EXISTING 0x00000001

#define PIPE_ACCESS_INBOUND 0x00000001
#define PIPE_ACCESS_OUTBOUND 0x00000002
#define PIPE_ACCESS_DUPLEX 0x00000003
#define PIPE_WAIT 0x00000000
#define PIPE_NOWAIT 0x00000001
#define PIPE_READMODE_BYTE 0x00000000
#define PIPE_READMODE_MESSAGE 0x00000002
#define PIPE_TYPE_BYTE 0x00000000
#define PIPE_TYPE_MESSAGE 0x00000004
#define PIPE_UNLIMITED_INSTANCES 255

#define FORMAT_MESSAGE_ALLOCATE_BUFFER 0x00000100
#define FORMAT_MESSAGE_IGNORE_INSERTS 0x00000200
#define FORMAT_MESSAGE_FROM_SYSTEM 0x00001000

DWORD GetLastError(void);
void SetLastError(DWORD dwErrCode);

BOOL CloseHandle(HANDLE hObject);
HANDLE CreateFileW(LPCWSTR lpFileName, DWORD dwDesiredAccess, DWORD dwShareMode,
                   LPSECURITY_ATTRIBUTES lpSecurityAttributes,
                   DWORD dwCreationDisposition, DWORD dwFlagsAndAttributes,
                   HANDLE hTemplateFile);
HANDLE ReOpenFile(HANDLE hOriginalFile, DWORD dwDesiredAccess, DWORD dwShareMode,
                  DWORD dwFlagsAndAttributes);
BOOL DeleteFileW(LPCWSTR lpFileName);
BOOL CreateDirectoryW(LPCWSTR lpPathName, LPSECURITY_ATTRIBUTES lpSecurityAttributes);
HANDLE GetCurrentProcess(void);
BOOL DuplicateHandle(HANDLE hSourceProcessHandle, HANDLE hSourceHandle,
                     HANDLE hTargetProcessHandle, LPHANDLE lpTargetHandle,
                     DWORD dwDesiredAccess, BOOL bInheritHandle, DWORD dwOptions);
BOOL GetHandleInformation(HANDLE hObject, LPDWORD lpdwFlags);
BOOL SetHandleInformation(HANDLE hObject, DWORD dwMask, DWORD dwFlags);
DWORD GetFileType(HANDLE hFile);
BOOL GetFileInformationByHandleEx(HANDLE hFile,
                                  FILE_INFO_BY_HANDLE_CLASS FileInformationClass,
                                  LPVOID lpFileInformation, DWORD dwBufferSize);
BOOL SetFileInformationByHandle(HANDLE hFile,
                                FILE_INFO_BY_HANDLE_CLASS FileInformationClass,
                                LPVOID lpFileInformation, DWORD dwBufferSize);
BOOL ReadFile(HANDLE hFile, LPVOID lpBuffer, DWORD nNumberOfBytesToRead,
              LPDWORD lpNumberOfBytesRead, LPOVERLAPPED lpOverlapped);
BOOL WriteFile(HANDLE hFile, LPCVOID lpBuffer, DWORD nNumberOfBytesToWrite,
               LPDWORD lpNumberOfBytesWritten, LPOVERLAPPED lpOverlapped);
BOOL SetFilePointerEx(HANDLE hFile, LARGE_INTEGER liDistanceToMove,
                      PLARGE_INTEGER lpNewFilePointer, DWORD dwMoveMethod);
BOOL FlushFileBuffers(HANDLE hFile);
BOOL GetFileSizeEx(HANDLE hFile, PLARGE_INTEGER lpFileSize);
BOOL SetEndOfFile(HANDLE hFile);
BOOL LockFileEx(HANDLE hFile, DWORD dwFlags, DWORD dwReserved,
                DWORD nNumberOfBytesToLockLow, DWORD nNumberOfBytesToLockHigh,
                LPOVERLAPPED lpOverlapped);
BOOL UnlockFileEx(HANDLE hFile, DWORD dwReserved, DWORD nNumberOfBytesToUnlockLow,
                  DWORD nNumberOfBytesToUnlockHigh, LPOVERLAPPED lpOverlapped);
BOOL GetVolumeInformationByHandleW(HANDLE hFile, LPWSTR lpVolumeNameBuffer,
                                   DWORD nVolumeNameSize,
                                   LPDWORD lpVolumeSerialNumber,
                                   LPDWORD lpMaximumComponentLength,
                                   LPDWORD lpFileSystemFlags,
                                   LPWSTR lpFileSystemNameBuffer,
                                   DWORD nFileSystemNameSize);
DWORD GetFinalPathNameByHandleW(HANDLE hFile, LPWSTR lpszFilePath, DWORD cchFilePath,
                                DWORD dwFlags);
DWORD GetFullPathNameW(LPCWSTR lpFileName, DWORD nBufferLength, LPWSTR lpBuffer,
                       LPWSTR *lpFilePart);
BOOL CreatePipe(PHANDLE hReadPipe, PHANDLE hWritePipe,
                LPSECURITY_ATTRIBUTES lpPipeAttributes, DWORD nSize);
DWORD GetFileAttributesW(LPCWSTR lpFileName);
BOOL RemoveDirectoryW(LPCWSTR lpPathName);
BOOL MoveFileExW(LPCWSTR lpExistingFileName, LPCWSTR lpNewFileName, DWORD dwFlags);
HANDLE CreateEventW(LPSECURITY_ATTRIBUTES lpEventAttributes, BOOL bManualReset,
                    BOOL bInitialState, LPCWSTR lpName);
HANDLE CreateNamedPipeW(LPCWSTR lpName, DWORD dwOpenMode, DWORD dwPipeMode,
                        DWORD nMaxInstances, DWORD nOutBufferSize,
                        DWORD nInBufferSize, DWORD nDefaultTimeOut,
                        LPSECURITY_ATTRIBUTES lpSecurityAttributes);
BOOL ConnectNamedPipe(HANDLE hNamedPipe, LPOVERLAPPED lpOverlapped);
DWORD GetCurrentProcessId(void);
HLOCAL LocalFree(HLOCAL hMem);
DWORD FormatMessageW(DWORD dwFlags, LPCVOID lpSource, DWORD dwMessageId,
                     DWORD dwLanguageId, LPWSTR lpBuffer, DWORD nSize,
                     va_list *Arguments);
HMODULE GetModuleHandleW(LPCWSTR lpModuleName);
FARPROC GetProcAddress(HMODULE hModule, LPCSTR lpProcName);

// pathcch.h

typedef enum PATHCCH_OPTIONS : int {
  PATHCCH_NONE = 0x0,
  PATHCCH_ALLOW_LONG_PATHS = 0x01,
} PATHCCH_OPTIONS;

HRESULT PathAllocCanonicalize(PCWSTR pszPathIn, ULONG dwFlags, PWSTR *ppszPathOut);

// sddl.h

#define SDDL_REVISION_1 1

BOOL ConvertStringSecurityDescriptorToSecurityDescriptorW(
    LPCWSTR StringSecurityDescriptor, DWORD StringSDRevision,
    PSECURITY_DESCRIPTOR *SecurityDescriptor, PULONG SecurityDescriptorSize);

// winternl.h

typedef struct _IO_STATUS_BLOCK {
  union {
    NTSTATUS Status;
    PVOID Pointer;
  };
  ULONG_PTR Information;
} IO_STATUS_BLOCK, *PIO_STATUS_BLOCK;

typedef enum _FILE_INFORMATION_CLASS : int {
  FileDirectoryInformation = 1
} FILE_INFORMATION_CLASS;

#define FILE_SYNCHRONOUS_IO_ALERT 0x00000010
#define FILE_SYNCHRONOUS_IO_NONALERT 0x00000020

// processthreadsapi.h, synchapi.h, winbase.h, winnt.h: processes and waiting

#define PROCESS_TERMINATE 0x0001
#define PROCESS_CREATE_THREAD 0x0002
#define PROCESS_VM_OPERATION 0x0008
#define PROCESS_VM_READ 0x0010
#define PROCESS_VM_WRITE 0x0020
#define PROCESS_DUP_HANDLE 0x0040
#define PROCESS_CREATE_PROCESS 0x0080
#define PROCESS_SET_QUOTA 0x0100
#define PROCESS_SET_INFORMATION 0x0200
#define PROCESS_QUERY_INFORMATION 0x0400
#define PROCESS_SUSPEND_RESUME 0x0800
#define PROCESS_QUERY_LIMITED_INFORMATION 0x1000
#define PROCESS_SET_LIMITED_INFORMATION 0x2000
#define STANDARD_RIGHTS_REQUIRED 0x000F0000
#define PROCESS_ALL_ACCESS (STANDARD_RIGHTS_REQUIRED | SYNCHRONIZE | 0xFFFF)

// As the SDK spells them, casts and all, less the L suffixes.
#define STATUS_WAIT_0 ((DWORD)0x00000000)
#define STATUS_ABANDONED_WAIT_0 ((DWORD)0x00000080)
#define STATUS_PENDING ((DWORD)0x00000103)
#define WAIT_OBJECT_0 ((STATUS_WAIT_0) + 0)
#define WAIT_ABANDONED ((STATUS_ABANDONED_WAIT_0) + 0)
#define WAIT_TIMEOUT 258
#define WAIT_FAILED ((DWORD)0xFFFFFFFF)
#define STILL_ACTIVE STATUS_PENDING

#define CREATE_SUSPENDED 0x00000004
#define CREATE_NO_WINDOW 0x08000000

typedef BYTE *LPBYTE;

typedef struct _STARTUPINFOW {
  DWORD cb;
  LPWSTR lpReserved;
  LPWSTR lpDesktop;
  LPWSTR lpTitle;
  DWORD dwX;
  DWORD dwY;
  DWORD dwXSize;
  DWORD dwYSize;
  DWORD dwXCountChars;
  DWORD dwYCountChars;
  DWORD dwFillAttribute;
  DWORD dwFlags;
  WORD wShowWindow;
  WORD cbReserved2;
  LPBYTE lpReserved2;
  HANDLE hStdInput;
  HANDLE hStdOutput;
  HANDLE hStdError;
} STARTUPINFOW, *LPSTARTUPINFOW;

typedef struct _PROCESS_INFORMATION {
  HANDLE hProcess;
  HANDLE hThread;
  DWORD dwProcessId;
  DWORD dwThreadId;
} PROCESS_INFORMATION, *PPROCESS_INFORMATION, *LPPROCESS_INFORMATION;

BOOL CreateProcessW(LPCWSTR lpApplicationName, LPWSTR lpCommandLine,
                    LPSECURITY_ATTRIBUTES lpProcessAttributes,
                    LPSECURITY_ATTRIBUTES lpThreadAttributes, BOOL bInheritHandles,
                    DWORD dwCreationFlags, LPVOID lpEnvironment,
                    LPCWSTR lpCurrentDirectory, LPSTARTUPINFOW lpStartupInfo,
                    LPPROCESS_INFORMATION lpProcessInformation);
HANDLE OpenProcess(DWORD dwDesiredAccess, BOOL bInheritHandle, DWORD dwProcessId);
DWORD GetProcessId(HANDLE Process);
BOOL GetExitCodeProcess(HANDLE hProcess, LPDWORD lpExitCode);
BOOL TerminateProcess(HANDLE hProcess, UINT uExitCode);
DWORD WaitForSingleObject(HANDLE hHandle, DWORD dwMilliseconds);

// processthreadsapi.h, processenv.h, stringapiset.h, winnt.h: threads and
// creating processes

#define THREAD_TERMINATE 0x0001
#define THREAD_SUSPEND_RESUME 0x0002
#define THREAD_GET_CONTEXT 0x0008
#define THREAD_SET_CONTEXT 0x0010
#define THREAD_SET_INFORMATION 0x0020
#define THREAD_QUERY_INFORMATION 0x0040
#define THREAD_SET_THREAD_TOKEN 0x0080
#define THREAD_IMPERSONATE 0x0100
#define THREAD_DIRECT_IMPERSONATION 0x0200
#define THREAD_SET_LIMITED_INFORMATION 0x0400
#define THREAD_QUERY_LIMITED_INFORMATION 0x0800
#define THREAD_RESUME 0x1000
#define THREAD_ALL_ACCESS (STANDARD_RIGHTS_REQUIRED | SYNCHRONIZE | 0xFFFF)

#define DEBUG_PROCESS 0x00000001
#define DETACHED_PROCESS 0x00000008
#define CREATE_NEW_CONSOLE 0x00000010
#define CREATE_NEW_PROCESS_GROUP 0x00000200
#define CREATE_UNICODE_ENVIRONMENT 0x00000400
#define EXTENDED_STARTUPINFO_PRESENT 0x00080000
#define CREATE_BREAKAWAY_FROM_JOB 0x01000000
#define CREATE_DEFAULT_ERROR_MODE 0x04000000
#define STARTF_USESTDHANDLES 0x00000100

// As the SDK spells them.
#define STD_INPUT_HANDLE ((DWORD)-10)
#define STD_OUTPUT_HANDLE ((DWORD)-11)
#define STD_ERROR_HANDLE ((DWORD)-12)

#define CSTR_LESS_THAN 1
#define CSTR_EQUAL 2
#define CSTR_GREATER_THAN 3

typedef ULONG_PTR SIZE_T, *PSIZE_T;
typedef const WCHAR *LPCWCH;

struct _PROC_THREAD_ATTRIBUTE_LIST;
typedef struct _PROC_THREAD_ATTRIBUTE_LIST *PPROC_THREAD_ATTRIBUTE_LIST,
    *LPPROC_THREAD_ATTRIBUTE_LIST;

typedef struct _STARTUPINFOEXW {
  STARTUPINFOW StartupInfo;
  LPPROC_THREAD_ATTRIBUTE_LIST lpAttributeList;
} STARTUPINFOEXW, *LPSTARTUPINFOEXW;

BOOL InitializeProcThreadAttributeList(LPPROC_THREAD_ATTRIBUTE_LIST lpAttributeList,
                                       DWORD dwAttributeCount, DWORD dwFlags,
                                       PSIZE_T lpSize);
BOOL UpdateProcThreadAttribute(LPPROC_THREAD_ATTRIBUTE_LIST lpAttributeList,
                               DWORD dwFlags, DWORD_PTR Attribute, PVOID lpValue,
                               SIZE_T cbSize, PVOID lpPreviousValue,
                               PSIZE_T lpReturnSize);
void DeleteProcThreadAttributeList(LPPROC_THREAD_ATTRIBUTE_LIST lpAttributeList);
HANDLE GetStdHandle(DWORD nStdHandle);
BOOL SetStdHandle(DWORD nStdHandle, HANDLE hHandle);
int CompareStringOrdinal(LPCWCH lpString1, int cchCount1, LPCWCH lpString2,
                         int cchCount2, BOOL bIgnoreCase);

HANDLE GetCurrentThread(void);
DWORD GetCurrentThreadId(void);
HANDLE OpenThread(DWORD dwDesiredAccess, BOOL bInheritHandle, DWORD dwThreadId);
DWORD GetThreadId(HANDLE Thread);
BOOL GetExitCodeThread(HANDLE hThread, LPDWORD lpExitCode);
DWORD ResumeThread(HANDLE hThread);
DWORD SuspendThread(HANDLE hThread);

// processenv.h: environment variables

DWORD GetEnvironmentVariableW(LPCWSTR lpName, LPWSTR lpBuffer, DWORD nSize);

// minwinbase.h, sysinfoapi.h, realtimeapiset.h, profileapi.h, synchapi.h:
// clocks and sleeping

typedef ULONGLONG *PULONGLONG;

typedef struct _FILETIME {
  DWORD dwLowDateTime;
  DWORD dwHighDateTime;
} FILETIME, *PFILETIME, *LPFILETIME;

void GetSystemTimePreciseAsFileTime(LPFILETIME lpSystemTimeAsFileTime);
void GetSystemTimeAsFileTime(LPFILETIME lpSystemTimeAsFileTime);
ULONGLONG GetTickCount64(void);
void QueryInterruptTimePrecise(PULONGLONG lpInterruptTimePrecise);
void QueryUnbiasedInterruptTimePrecise(PULONGLONG lpUnbiasedInterruptTimePrecise);
BOOL QueryPerformanceCounter(LARGE_INTEGER *lpPerformanceCount);
BOOL QueryPerformanceFrequency(LARGE_INTEGER *lpFrequency);
void Sleep(DWORD dwMilliseconds);

// synchapi.h, winnt.h: SRW locks and condition variables

typedef struct _RTL_SRWLOCK {
  PVOID Ptr;
} RTL_SRWLOCK, *PRTL_SRWLOCK;
typedef RTL_SRWLOCK SRWLOCK, *PSRWLOCK;

typedef struct _RTL_CONDITION_VARIABLE {
  PVOID Ptr;
} RTL_CONDITION_VARIABLE, *PRTL_CONDITION_VARIABLE;
typedef RTL_CONDITION_VARIABLE CONDITION_VARIABLE, *PCONDITION_VARIABLE;

#define CONDITION_VARIABLE_LOCKMODE_SHARED 0x1
#define ERROR_TIMEOUT 1460

void InitializeSRWLock(PSRWLOCK SRWLock);
void AcquireSRWLockExclusive(PSRWLOCK SRWLock);
void AcquireSRWLockShared(PSRWLOCK SRWLock);
BOOLEAN TryAcquireSRWLockExclusive(PSRWLOCK SRWLock);
BOOLEAN TryAcquireSRWLockShared(PSRWLOCK SRWLock);
void ReleaseSRWLockExclusive(PSRWLOCK SRWLock);
void ReleaseSRWLockShared(PSRWLOCK SRWLock);
void InitializeConditionVariable(PCONDITION_VARIABLE ConditionVariable);
BOOL SleepConditionVariableSRW(PCONDITION_VARIABLE ConditionVariable, PSRWLOCK SRWLock,
                               DWORD dwMilliseconds, ULONG Flags);
void WakeConditionVariable(PCONDITION_VARIABLE ConditionVariable);
void WakeAllConditionVariable(PCONDITION_VARIABLE ConditionVariable);

// consoleapi.h, consoleapi2.h, wincon.h: consoles

typedef short SHORT;

typedef struct _COORD {
  SHORT X;
  SHORT Y;
} COORD, *PCOORD;

typedef struct _SMALL_RECT {
  SHORT Left;
  SHORT Top;
  SHORT Right;
  SHORT Bottom;
} SMALL_RECT, *PSMALL_RECT;

typedef struct _CONSOLE_SCREEN_BUFFER_INFO {
  COORD dwSize;
  COORD dwCursorPosition;
  WORD wAttributes;
  SMALL_RECT srWindow;
  COORD dwMaximumWindowSize;
} CONSOLE_SCREEN_BUFFER_INFO, *PCONSOLE_SCREEN_BUFFER_INFO;

typedef BOOL (*PHANDLER_ROUTINE)(DWORD CtrlType);

#define ENABLE_PROCESSED_INPUT 0x0001
#define ENABLE_LINE_INPUT 0x0002
#define ENABLE_ECHO_INPUT 0x0004
#define ENABLE_WINDOW_INPUT 0x0008
#define ENABLE_MOUSE_INPUT 0x0010
#define ENABLE_INSERT_MODE 0x0020
#define ENABLE_QUICK_EDIT_MODE 0x0040
#define ENABLE_EXTENDED_FLAGS 0x0080
#define ENABLE_AUTO_POSITION 0x0100
#define ENABLE_VIRTUAL_TERMINAL_INPUT 0x0200
#define ENABLE_PROCESSED_OUTPUT 0x0001
#define ENABLE_WRAP_AT_EOL_OUTPUT 0x0002
#define ENABLE_VIRTUAL_TERMINAL_PROCESSING 0x0004
#define DISABLE_NEWLINE_AUTO_RETURN 0x0008
#define ENABLE_LVB_GRID_WORLDWIDE 0x0010

#define CTRL_C_EVENT 0
#define CTRL_BREAK_EVENT 1
#define CTRL_CLOSE_EVENT 2
#define CTRL_LOGOFF_EVENT 5
#define CTRL_SHUTDOWN_EVENT 6

BOOL GetConsoleMode(HANDLE hConsoleHandle, LPDWORD lpMode);
BOOL SetConsoleMode(HANDLE hConsoleHandle, DWORD dwMode);
BOOL GetConsoleScreenBufferInfo(HANDLE hConsoleOutput,
                                PCONSOLE_SCREEN_BUFFER_INFO lpConsoleScreenBufferInfo);
BOOL SetConsoleCtrlHandler(PHANDLER_ROUTINE HandlerRoutine, BOOL Add);

// libloaderapi.h, fileapi.h, sysinfoapi.h, processenv.h: well-known paths

DWORD GetModuleFileNameW(HMODULE hModule, LPWSTR lpFilename, DWORD nSize);
DWORD GetTempPathW(DWORD nBufferLength, LPWSTR lpBuffer);
UINT GetWindowsDirectoryW(LPWSTR lpBuffer, UINT uSize);
UINT GetSystemDirectoryW(LPWSTR lpBuffer, UINT uSize);
DWORD GetCurrentDirectoryW(DWORD nBufferLength, LPWSTR lpBuffer);

// libloaderapi.h: dynamic loading

#define LOAD_WITH_ALTERED_SEARCH_PATH 0x00000008
#define LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR 0x00000100
#define LOAD_LIBRARY_SEARCH_APPLICATION_DIR 0x00000200
#define LOAD_LIBRARY_SEARCH_USER_DIRS 0x00000400
#define LOAD_LIBRARY_SEARCH_SYSTEM32 0x00000800
#define LOAD_LIBRARY_SEARCH_DEFAULT_DIRS 0x00001000

HMODULE LoadLibraryW(LPCWSTR lpLibFileName);
HMODULE LoadLibraryExW(LPCWSTR lpLibFileName, HANDLE hFile, DWORD dwFlags);
BOOL FreeLibrary(HMODULE hLibModule);
BOOL GetModuleHandleExW(DWORD dwFlags, LPCWSTR lpModuleName, HMODULE *phModule);
