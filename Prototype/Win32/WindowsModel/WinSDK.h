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

// Only the compiler's own headers: the macOS SDK's would bring its C
// library's declarations, such as gmtime_r, into every file that imports
// this module.
#include <stdarg.h>
#include <stdbool.h>
#include <stddef.h>

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
typedef ULONG_PTR *PULONG_PTR;
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
#define ERROR_NOT_ENOUGH_MEMORY 8
#define ERROR_NOT_SAME_DEVICE 17
#define ERROR_DIR_NOT_EMPTY 145
#define ERROR_PRIVILEGE_NOT_HELD 1314
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
#define PIPE_ACCEPT_REMOTE_CLIENTS 0x00000000
#define PIPE_REJECT_REMOTE_CLIENTS 0x00000008
#define FILE_FLAG_FIRST_PIPE_INSTANCE 0x00080000
#define ERROR_PIPE_CONNECTED 535
#define ERROR_PIPE_LISTENING 536

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
BOOL DisconnectNamedPipe(HANDLE hNamedPipe);
BOOL PeekNamedPipe(HANDLE hNamedPipe, LPVOID lpBuffer, DWORD nBufferSize, LPDWORD lpBytesRead,
                   LPDWORD lpTotalBytesAvail, LPDWORD lpBytesLeftThisMessage);
BOOL SetNamedPipeHandleState(HANDLE hNamedPipe, LPDWORD lpMode, LPDWORD lpMaxCollectionCount,
                             LPDWORD lpCollectDataTimeout);
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
  PATHCCH_FORCE_ENABLE_LONG_NAME_PROCESS = 0x02,
  PATHCCH_FORCE_DISABLE_LONG_NAME_PROCESS = 0x04,
  PATHCCH_DO_NOT_NORMALIZE_SEGMENTS = 0x08,
  PATHCCH_ENSURE_IS_EXTENDED_LENGTH_PATH = 0x10,
  PATHCCH_ENSURE_TRAILING_SLASH = 0x20,
} PATHCCH_OPTIONS;

#define PATHCCH_MAX_CCH 0x8000

HRESULT PathAllocCanonicalize(PCWSTR pszPathIn, ULONG dwFlags, PWSTR *ppszPathOut);
HRESULT PathCchStripPrefix(PWSTR pszPath, size_t cchPath);

// winerror.h, as the SDK spells them, less the L suffixes. Swift imports
// S_OK and S_FALSE, and none of the failures: the function-like macro is
// unsupported, and a negative HRESULT's literal overflows.
#define _HRESULT_TYPEDEF_(_sc) ((HRESULT)_sc)
#define S_OK ((HRESULT)0)
#define S_FALSE ((HRESULT)1)
#define E_NOTIMPL _HRESULT_TYPEDEF_(0x80004001)
#define E_NOINTERFACE _HRESULT_TYPEDEF_(0x80004002)
#define E_POINTER _HRESULT_TYPEDEF_(0x80004003)
#define E_ABORT _HRESULT_TYPEDEF_(0x80004004)
#define E_FAIL _HRESULT_TYPEDEF_(0x80004005)
#define E_UNEXPECTED _HRESULT_TYPEDEF_(0x8000FFFF)
#define E_ACCESSDENIED _HRESULT_TYPEDEF_(0x80070005)
#define E_HANDLE _HRESULT_TYPEDEF_(0x80070006)
#define E_OUTOFMEMORY _HRESULT_TYPEDEF_(0x8007000E)
#define E_INVALIDARG _HRESULT_TYPEDEF_(0x80070057)
#define FACILITY_NULL 0
#define ERROR_OUTOFMEMORY 14

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
BOOL SwitchToThread(void);
HRESULT SetThreadDescription(HANDLE hThread, PCWSTR lpThreadDescription);
HRESULT GetThreadDescription(HANDLE hThread, PWSTR *ppszThreadDescription);
void GetCurrentThreadStackLimits(PULONG_PTR LowLimit, PULONG_PTR HighLimit);

#define STACK_SIZE_PARAM_IS_A_RESERVATION 0x00010000

// fibersapi.h, winbase.h, winnt.h: fiber-local storage

typedef void (*PFLS_CALLBACK_FUNCTION)(PVOID lpFlsData);

#define FLS_OUT_OF_INDEXES ((DWORD)0xFFFFFFFF)

DWORD FlsAlloc(PFLS_CALLBACK_FUNCTION lpCallback);
BOOL FlsFree(DWORD dwFlsIndex);
PVOID FlsGetValue(DWORD dwFlsIndex);
BOOL FlsSetValue(DWORD dwFlsIndex, PVOID lpFlsData);
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

// minwinbase.h, synchapi.h, winnt.h: critical sections

struct _RTL_CRITICAL_SECTION_DEBUG;
typedef struct _RTL_CRITICAL_SECTION {
  struct _RTL_CRITICAL_SECTION_DEBUG *DebugInfo;
  LONG LockCount;
  LONG RecursionCount;
  HANDLE OwningThread;
  HANDLE LockSemaphore;
  ULONG_PTR SpinCount;
} RTL_CRITICAL_SECTION, *PRTL_CRITICAL_SECTION;
typedef RTL_CRITICAL_SECTION CRITICAL_SECTION, *PCRITICAL_SECTION, *LPCRITICAL_SECTION;

void InitializeCriticalSection(LPCRITICAL_SECTION lpCriticalSection);
void EnterCriticalSection(LPCRITICAL_SECTION lpCriticalSection);
BOOL TryEnterCriticalSection(LPCRITICAL_SECTION lpCriticalSection);
void LeaveCriticalSection(LPCRITICAL_SECTION lpCriticalSection);
void DeleteCriticalSection(LPCRITICAL_SECTION lpCriticalSection);
BOOL SleepConditionVariableCS(PCONDITION_VARIABLE ConditionVariable,
                              PCRITICAL_SECTION CriticalSection, DWORD dwMilliseconds);

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
BOOL AttachConsole(DWORD dwProcessId);
BOOL FreeConsole(void);
BOOL AllocConsole(void);
BOOL GenerateConsoleCtrlEvent(DWORD dwCtrlEvent, DWORD dwProcessGroupId);

// As the SDK spells it.
#define ATTACH_PARENT_PROCESS ((DWORD)-1)

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

typedef PVOID DLL_DIRECTORY_COOKIE, *PDLL_DIRECTORY_COOKIE;
DLL_DIRECTORY_COOKIE AddDllDirectory(PCWSTR NewDirectory);
BOOL RemoveDllDirectory(DLL_DIRECTORY_COOKIE Cookie);
BOOL SetDefaultDllDirectories(DWORD DirectoryFlags);

#define ERROR_ENVVAR_NOT_FOUND 203

typedef WCHAR *LPWCH;

BOOL SetEnvironmentVariableW(LPCWSTR lpName, LPCWSTR lpValue);
LPWCH GetEnvironmentStringsW(void);
BOOL FreeEnvironmentStringsW(LPWCH penv);

// fileapi.h, minwinbase.h, winbase.h, winnt.h: file information

#define FILE_ATTRIBUTE_DEVICE 0x00000040
#define FILE_ATTRIBUTE_SPARSE_FILE 0x00000200
#define FILE_ATTRIBUTE_REPARSE_POINT 0x00000400
#define FILE_ATTRIBUTE_COMPRESSED 0x00000800
#define FILE_ATTRIBUTE_NOT_CONTENT_INDEXED 0x00002000
#define FILE_ATTRIBUTE_INTEGRITY_STREAM 0x00008000
#define FILE_ATTRIBUTE_NO_SCRUB_DATA 0x00020000
#define FILE_ATTRIBUTE_RECALL_ON_OPEN 0x00040000
#define FILE_ATTRIBUTE_PINNED 0x00080000
#define FILE_ATTRIBUTE_UNPINNED 0x00100000
#define FILE_ATTRIBUTE_RECALL_ON_DATA_ACCESS 0x00400000

#define IO_REPARSE_TAG_MOUNT_POINT 0xA0000003
#define IO_REPARSE_TAG_SYMLINK 0xA000000C
#define IO_REPARSE_TAG_APPEXECLINK 0x8000001B
#define IO_REPARSE_TAG_AF_UNIX 0x80000023

typedef struct _BY_HANDLE_FILE_INFORMATION {
  DWORD dwFileAttributes;
  FILETIME ftCreationTime;
  FILETIME ftLastAccessTime;
  FILETIME ftLastWriteTime;
  DWORD dwVolumeSerialNumber;
  DWORD nFileSizeHigh;
  DWORD nFileSizeLow;
  DWORD nNumberOfLinks;
  DWORD nFileIndexHigh;
  DWORD nFileIndexLow;
} BY_HANDLE_FILE_INFORMATION, *PBY_HANDLE_FILE_INFORMATION, *LPBY_HANDLE_FILE_INFORMATION;

typedef struct _FILE_BASIC_INFO {
  LARGE_INTEGER CreationTime;
  LARGE_INTEGER LastAccessTime;
  LARGE_INTEGER LastWriteTime;
  LARGE_INTEGER ChangeTime;
  DWORD FileAttributes;
} FILE_BASIC_INFO, *PFILE_BASIC_INFO;

typedef struct _FILE_ID_128 {
  BYTE Identifier[16];
} FILE_ID_128, *PFILE_ID_128;

typedef struct _FILE_ID_INFO {
  ULONGLONG VolumeSerialNumber;
  FILE_ID_128 FileId;
} FILE_ID_INFO, *PFILE_ID_INFO;

typedef struct _FILE_ATTRIBUTE_TAG_INFO {
  DWORD FileAttributes;
  DWORD ReparseTag;
} FILE_ATTRIBUTE_TAG_INFO, *PFILE_ATTRIBUTE_TAG_INFO;

typedef struct _WIN32_FILE_ATTRIBUTE_DATA {
  DWORD dwFileAttributes;
  FILETIME ftCreationTime;
  FILETIME ftLastAccessTime;
  FILETIME ftLastWriteTime;
  DWORD nFileSizeHigh;
  DWORD nFileSizeLow;
} WIN32_FILE_ATTRIBUTE_DATA, *LPWIN32_FILE_ATTRIBUTE_DATA;

typedef enum _GET_FILEEX_INFO_LEVELS : int {
  GetFileExInfoStandard,
  GetFileExMaxInfoLevel
} GET_FILEEX_INFO_LEVELS;

BOOL GetFileInformationByHandle(HANDLE hFile,
                                LPBY_HANDLE_FILE_INFORMATION lpFileInformation);
BOOL GetFileAttributesExW(LPCWSTR lpFileName, GET_FILEEX_INFO_LEVELS fInfoLevelId,
                          LPVOID lpFileInformation);
BOOL SetFileAttributesW(LPCWSTR lpFileName, DWORD dwFileAttributes);

// fileapi.h, winbase.h, minwinbase.h, winnt.h: path operations

#define MOVEFILE_COPY_ALLOWED 0x00000002
#define MOVEFILE_DELAY_UNTIL_REBOOT 0x00000004
#define MOVEFILE_WRITE_THROUGH 0x00000008
#define MOVEFILE_CREATE_HARDLINK 0x00000010
#define MOVEFILE_FAIL_IF_NOT_TRACKABLE 0x00000020

#define COPY_FILE_FAIL_IF_EXISTS 0x00000001
#define COPY_FILE_RESTARTABLE 0x00000002
#define COPY_FILE_OPEN_SOURCE_FOR_WRITE 0x00000004
#define COPY_FILE_ALLOW_DECRYPTED_DESTINATION 0x00000008
#define COPY_FILE_DIRECTORY 0x00000080
#define COPY_FILE_COPY_SYMLINK 0x00000800
#define COPY_FILE_NO_BUFFERING 0x00001000
#define COPY_FILE_NO_OFFLOAD 0x00040000
#define COPY_FILE_OPEN_AND_COPY_REPARSE_POINT 0x00200000

#define SYMBOLIC_LINK_FLAG_DIRECTORY 0x1
#define SYMBOLIC_LINK_FLAG_ALLOW_UNPRIVILEGED_CREATE 0x2

#define FILE_DISPOSITION_FLAG_DO_NOT_DELETE 0x00000000
#define FILE_DISPOSITION_FLAG_DELETE 0x00000001
#define FILE_DISPOSITION_FLAG_POSIX_SEMANTICS 0x00000002
#define FILE_DISPOSITION_FLAG_FORCE_IMAGE_SECTION_CHECK 0x00000004
#define FILE_DISPOSITION_FLAG_ON_CLOSE 0x00000008
#define FILE_DISPOSITION_FLAG_IGNORE_READONLY_ATTRIBUTE 0x00000010

#define FILE_RENAME_FLAG_REPLACE_IF_EXISTS 0x00000001
#define FILE_RENAME_FLAG_POSIX_SEMANTICS 0x00000002
#define FILE_RENAME_FLAG_SUPPRESS_PIN_STATE_INHERITANCE 0x00000004
#define FILE_RENAME_FLAG_IGNORE_READONLY_ATTRIBUTE 0x00000040

typedef struct _FILE_DISPOSITION_INFO_EX {
  DWORD Flags;
} FILE_DISPOSITION_INFO_EX, *PFILE_DISPOSITION_INFO_EX;

// The union is anonymous, as DUMMYUNIONNAME leaves it by default.
typedef struct _FILE_RENAME_INFO {
  union {
    BOOLEAN ReplaceIfExists;
    DWORD Flags;
  };
  HANDLE RootDirectory;
  DWORD FileNameLength;
  WCHAR FileName[1];
} FILE_RENAME_INFO, *PFILE_RENAME_INFO;

// The progress routine's message is a union of structs, which nothing here
// reads.
typedef int (*PCOPYFILE2_PROGRESS_ROUTINE)(const void *pMessage, PVOID pvCallbackContext);

typedef struct COPYFILE2_EXTENDED_PARAMETERS {
  DWORD dwSize;
  DWORD dwCopyFlags;
  BOOL *pfCancel;
  PCOPYFILE2_PROGRESS_ROUTINE pProgressRoutine;
  PVOID pvCallbackContext;
} COPYFILE2_EXTENDED_PARAMETERS;

HRESULT CopyFile2(PCWSTR pwszExistingFileName, PCWSTR pwszNewFileName,
                  COPYFILE2_EXTENDED_PARAMETERS *pExtendedParameters);
BOOLEAN CreateSymbolicLinkW(LPCWSTR lpSymlinkFileName, LPCWSTR lpTargetFileName,
                            DWORD dwFlags);
BOOL CreateHardLinkW(LPCWSTR lpFileName, LPCWSTR lpExistingFileName,
                     LPSECURITY_ATTRIBUTES lpSecurityAttributes);

// ioapiset.h, minwinbase.h, winerror.h: overlapped I/O and completion ports

#define ERROR_IO_INCOMPLETE 996
#define ERROR_NOT_FOUND 1168
#define ERROR_ABANDONED_WAIT_0 735

BOOL GetOverlappedResult(HANDLE hFile, LPOVERLAPPED lpOverlapped,
                         LPDWORD lpNumberOfBytesTransferred, BOOL bWait);
BOOL GetOverlappedResultEx(HANDLE hFile, LPOVERLAPPED lpOverlapped,
                           LPDWORD lpNumberOfBytesTransferred, DWORD dwMilliseconds,
                           BOOL bAlertable);
BOOL CancelIoEx(HANDLE hFile, LPOVERLAPPED lpOverlapped);
HANDLE CreateIoCompletionPort(HANDLE FileHandle, HANDLE ExistingCompletionPort,
                              ULONG_PTR CompletionKey, DWORD NumberOfConcurrentThreads);
BOOL PostQueuedCompletionStatus(HANDLE CompletionPort, DWORD dwNumberOfBytesTransferred,
                                ULONG_PTR dwCompletionKey, LPOVERLAPPED lpOverlapped);
BOOL GetQueuedCompletionStatus(HANDLE CompletionPort, LPDWORD lpNumberOfBytesTransferred,
                               PULONG_PTR lpCompletionKey, LPOVERLAPPED *lpOverlapped,
                               DWORD dwMilliseconds);

// sysinfoapi.h, winnt.h, winbase.h: system information

typedef unsigned short USHORT;

typedef struct _SYSTEM_INFO {
  union {
    DWORD dwOemId;
    struct {
      WORD wProcessorArchitecture;
      WORD wReserved;
    };
  };
  DWORD dwPageSize;
  LPVOID lpMinimumApplicationAddress;
  LPVOID lpMaximumApplicationAddress;
  DWORD_PTR dwActiveProcessorMask;
  DWORD dwNumberOfProcessors;
  DWORD dwProcessorType;
  DWORD dwAllocationGranularity;
  WORD wProcessorLevel;
  WORD wProcessorRevision;
} SYSTEM_INFO, *LPSYSTEM_INFO;

#define PROCESSOR_ARCHITECTURE_INTEL 0
#define PROCESSOR_ARCHITECTURE_ARM 5
#define PROCESSOR_ARCHITECTURE_IA64 6
#define PROCESSOR_ARCHITECTURE_AMD64 9
#define PROCESSOR_ARCHITECTURE_ARM64 12
#define PROCESSOR_ARCHITECTURE_UNKNOWN 0xFFFF
#define ALL_PROCESSOR_GROUPS 0xffff

typedef enum _LOGICAL_PROCESSOR_RELATIONSHIP : int {
  RelationProcessorCore,
  RelationNumaNode,
  RelationCache,
  RelationProcessorPackage,
  RelationGroup,
  RelationAll = 0xffff
} LOGICAL_PROCESSOR_RELATIONSHIP;

typedef enum _PROCESSOR_CACHE_TYPE : int {
  CacheUnified,
  CacheInstruction,
  CacheData,
  CacheTrace
} PROCESSOR_CACHE_TYPE;

typedef struct _CACHE_DESCRIPTOR {
  BYTE Level;
  BYTE Associativity;
  WORD LineSize;
  DWORD Size;
  PROCESSOR_CACHE_TYPE Type;
} CACHE_DESCRIPTOR, *PCACHE_DESCRIPTOR;

typedef struct _SYSTEM_LOGICAL_PROCESSOR_INFORMATION {
  ULONG_PTR ProcessorMask;
  LOGICAL_PROCESSOR_RELATIONSHIP Relationship;
  union {
    struct {
      BYTE Flags;
    } ProcessorCore;
    struct {
      DWORD NodeNumber;
    } NumaNode;
    CACHE_DESCRIPTOR Cache;
    ULONGLONG Reserved[2];
  };
} SYSTEM_LOGICAL_PROCESSOR_INFORMATION, *PSYSTEM_LOGICAL_PROCESSOR_INFORMATION;

typedef enum _COMPUTER_NAME_FORMAT : int {
  ComputerNameNetBIOS,
  ComputerNameDnsHostname,
  ComputerNameDnsDomain,
  ComputerNameDnsFullyQualified,
  ComputerNamePhysicalNetBIOS,
  ComputerNamePhysicalDnsHostname,
  ComputerNamePhysicalDnsDomain,
  ComputerNamePhysicalDnsFullyQualified,
  ComputerNameMax
} COMPUTER_NAME_FORMAT;

typedef struct _OSVERSIONINFOEXW {
  DWORD dwOSVersionInfoSize;
  DWORD dwMajorVersion;
  DWORD dwMinorVersion;
  DWORD dwBuildNumber;
  DWORD dwPlatformId;
  WCHAR szCSDVersion[128];
  WORD wServicePackMajor;
  WORD wServicePackMinor;
  WORD wSuiteMask;
  BYTE wProductType;
  BYTE wReserved;
} OSVERSIONINFOEXW, *POSVERSIONINFOEXW, RTL_OSVERSIONINFOEXW, *PRTL_OSVERSIONINFOEXW;

#define VER_NT_WORKSTATION 0x0000001
#define VER_NT_DOMAIN_CONTROLLER 0x0000002
#define VER_NT_SERVER 0x0000003

void GetSystemInfo(LPSYSTEM_INFO lpSystemInfo);
void GetNativeSystemInfo(LPSYSTEM_INFO lpSystemInfo);
DWORD GetActiveProcessorCount(WORD GroupNumber);
BOOL GetLogicalProcessorInformation(PSYSTEM_LOGICAL_PROCESSOR_INFORMATION Buffer,
                                    PDWORD ReturnedLength);
BOOL GetPhysicallyInstalledSystemMemory(PULONGLONG TotalMemoryInKilobytes);
BOOL GetComputerNameExW(COMPUTER_NAME_FORMAT NameType, LPWSTR lpBuffer, LPDWORD nSize);

// shellapi.h: splitting a command line, as the C runtime does.
LPWSTR *CommandLineToArgvW(LPCWSTR lpCmdLine, int *pNumArgs);

// winnt.h, securitybaseapi.h, processthreadsapi.h, winbase.h, sddl.h,
// secext.h, userenv.h and lmcons.h: access tokens, security identifiers and
// accounts.
#define TOKEN_ASSIGN_PRIMARY (0x0001)
#define TOKEN_DUPLICATE (0x0002)
#define TOKEN_IMPERSONATE (0x0004)
#define TOKEN_QUERY (0x0008)
#define TOKEN_QUERY_SOURCE (0x0010)
#define TOKEN_ADJUST_PRIVILEGES (0x0020)
#define TOKEN_ADJUST_GROUPS (0x0040)
#define TOKEN_ADJUST_DEFAULT (0x0080)
#define TOKEN_ADJUST_SESSIONID (0x0100)
#define SID_MAX_SUB_AUTHORITIES (15)
#define SID_REVISION (1)
#define UNLEN 256
#define ERROR_NO_TOKEN 1008
#define ERROR_NONE_MAPPED 1332
#define ERROR_INVALID_SID 1337
#define ERROR_NO_SUCH_DOMAIN 1355

typedef BOOL *PBOOL;

typedef struct _SID_AND_ATTRIBUTES {
  PSID Sid;
  DWORD Attributes;
} SID_AND_ATTRIBUTES, *PSID_AND_ATTRIBUTES;

typedef struct _TOKEN_USER {
  SID_AND_ATTRIBUTES User;
} TOKEN_USER, *PTOKEN_USER;

typedef struct _TOKEN_ELEVATION {
  DWORD TokenIsElevated;
} TOKEN_ELEVATION, *PTOKEN_ELEVATION;

typedef enum _TOKEN_INFORMATION_CLASS : int {
  TokenUser = 1,
  TokenGroups,
  TokenPrivileges,
  TokenOwner,
  TokenPrimaryGroup,
  TokenDefaultDacl,
  TokenSource,
  TokenType,
  TokenImpersonationLevel,
  TokenStatistics,
  TokenRestrictedSids,
  TokenSessionId,
  TokenGroupsAndPrivileges,
  TokenSessionReference,
  TokenSandBoxInert,
  TokenAuditPolicy,
  TokenOrigin,
  TokenElevationType,
  TokenLinkedToken,
  TokenElevation,
} TOKEN_INFORMATION_CLASS;

typedef enum _SID_NAME_USE : int {
  SidTypeUser = 1,
  SidTypeGroup,
  SidTypeDomain,
  SidTypeAlias,
  SidTypeWellKnownGroup,
  SidTypeDeletedAccount,
  SidTypeInvalid,
  SidTypeUnknown,
  SidTypeComputer,
  SidTypeLabel,
  SidTypeLogonSession
} SID_NAME_USE, *PSID_NAME_USE;

typedef enum WELL_KNOWN_SID_TYPE : int {
  WinNullSid = 0,
  WinWorldSid = 1,
  WinLocalSid = 2,
  WinCreatorOwnerSid = 3,
  WinCreatorGroupSid = 4,
  WinCreatorOwnerServerSid = 5,
  WinCreatorGroupServerSid = 6,
  WinNtAuthoritySid = 7,
  WinDialupSid = 8,
  WinNetworkSid = 9,
  WinBatchSid = 10,
  WinInteractiveSid = 11,
  WinServiceSid = 12,
  WinAnonymousSid = 13,
  WinProxySid = 14,
  WinEnterpriseControllersSid = 15,
  WinSelfSid = 16,
  WinAuthenticatedUserSid = 17,
  WinRestrictedCodeSid = 18,
  WinTerminalServerSid = 19,
  WinRemoteLogonIdSid = 20,
  WinLogonIdsSid = 21,
  WinLocalSystemSid = 22,
  WinLocalServiceSid = 23,
  WinNetworkServiceSid = 24,
  WinBuiltinDomainSid = 25,
  WinBuiltinAdministratorsSid = 26,
  WinBuiltinUsersSid = 27,
  WinBuiltinGuestsSid = 28,
  WinAccountAdministratorSid = 38,
} WELL_KNOWN_SID_TYPE;

typedef enum EXTENDED_NAME_FORMAT : int {
  NameUnknown = 0,
  NameFullyQualifiedDN = 1,
  NameSamCompatible = 2,
  NameDisplay = 3,
  NameUniqueId = 6,
  NameCanonical = 7,
  NameUserPrincipal = 8,
  NameCanonicalEx = 9,
  NameServicePrincipal = 10,
  NameDnsDomain = 12,
  NameGivenName = 13,
  NameSurname = 14
} EXTENDED_NAME_FORMAT, *PEXTENDED_NAME_FORMAT;

BOOL OpenProcessToken(HANDLE ProcessHandle, DWORD DesiredAccess, PHANDLE TokenHandle);
BOOL GetTokenInformation(HANDLE TokenHandle, TOKEN_INFORMATION_CLASS TokenInformationClass,
                         LPVOID TokenInformation, DWORD TokenInformationLength,
                         PDWORD ReturnLength);
BOOL CheckTokenMembership(HANDLE TokenHandle, PSID SidToCheck, PBOOL IsMember);
BOOL GetUserNameW(LPWSTR lpBuffer, LPDWORD pcbBuffer);
BOOLEAN GetUserNameExW(EXTENDED_NAME_FORMAT NameFormat, LPWSTR lpNameBuffer, PULONG nSize);
BOOL GetUserProfileDirectoryW(HANDLE hToken, LPWSTR lpProfileDir, LPDWORD lpcchSize);
BOOL LookupAccountNameW(LPCWSTR lpSystemName, LPCWSTR lpAccountName, PSID Sid, LPDWORD cbSid,
                        LPWSTR ReferencedDomainName, LPDWORD cchReferencedDomainName,
                        PSID_NAME_USE peUse);
BOOL LookupAccountSidW(LPCWSTR lpSystemName, PSID Sid, LPWSTR Name, LPDWORD cchName,
                       LPWSTR ReferencedDomainName, LPDWORD cchReferencedDomainName,
                       PSID_NAME_USE peUse);
BOOL ConvertSidToStringSidW(PSID Sid, LPWSTR *StringSid);
BOOL ConvertStringSidToSidW(LPCWSTR StringSid, PSID *Sid);
BOOL CreateWellKnownSid(WELL_KNOWN_SID_TYPE WellKnownSidType, PSID DomainSid, PSID pSid,
                        DWORD *cbSid);

// jobapi.h, jobapi2.h and winnt.h: job objects.
#define JOB_OBJECT_LIMIT_DIE_ON_UNHANDLED_EXCEPTION 0x00000400
#define JOB_OBJECT_LIMIT_BREAKAWAY_OK 0x00000800
#define JOB_OBJECT_LIMIT_SILENT_BREAKAWAY_OK 0x00001000
#define JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE 0x00002000
#define JOB_OBJECT_MSG_END_OF_JOB_TIME 1
#define JOB_OBJECT_MSG_END_OF_PROCESS_TIME 2
#define JOB_OBJECT_MSG_ACTIVE_PROCESS_LIMIT 3
#define JOB_OBJECT_MSG_ACTIVE_PROCESS_ZERO 4
#define JOB_OBJECT_MSG_NEW_PROCESS 6
#define JOB_OBJECT_MSG_EXIT_PROCESS 7
#define JOB_OBJECT_MSG_ABNORMAL_EXIT_PROCESS 8
#define JOB_OBJECT_MSG_PROCESS_MEMORY_LIMIT 9
#define JOB_OBJECT_MSG_JOB_MEMORY_LIMIT 10
#define JOB_OBJECT_MSG_NOTIFICATION_LIMIT 11

typedef enum _JOBOBJECTINFOCLASS : int {
  JobObjectBasicAccountingInformation = 1,
  JobObjectBasicLimitInformation,
  JobObjectBasicProcessIdList,
  JobObjectBasicUIRestrictions,
  JobObjectSecurityLimitInformation,
  JobObjectEndOfJobTimeInformation,
  JobObjectAssociateCompletionPortInformation,
  JobObjectBasicAndIoAccountingInformation,
  JobObjectExtendedLimitInformation,
} JOBOBJECTINFOCLASS;

typedef struct _JOBOBJECT_BASIC_LIMIT_INFORMATION {
  LARGE_INTEGER PerProcessUserTimeLimit;
  LARGE_INTEGER PerJobUserTimeLimit;
  DWORD LimitFlags;
  SIZE_T MinimumWorkingSetSize;
  SIZE_T MaximumWorkingSetSize;
  DWORD ActiveProcessLimit;
  ULONG_PTR Affinity;
  DWORD PriorityClass;
  DWORD SchedulingClass;
} JOBOBJECT_BASIC_LIMIT_INFORMATION;

typedef struct _IO_COUNTERS {
  ULONGLONG ReadOperationCount;
  ULONGLONG WriteOperationCount;
  ULONGLONG OtherOperationCount;
  ULONGLONG ReadTransferCount;
  ULONGLONG WriteTransferCount;
  ULONGLONG OtherTransferCount;
} IO_COUNTERS;

typedef struct _JOBOBJECT_EXTENDED_LIMIT_INFORMATION {
  JOBOBJECT_BASIC_LIMIT_INFORMATION BasicLimitInformation;
  IO_COUNTERS IoInfo;
  SIZE_T ProcessMemoryLimit;
  SIZE_T JobMemoryLimit;
  SIZE_T PeakProcessMemoryUsed;
  SIZE_T PeakJobMemoryUsed;
} JOBOBJECT_EXTENDED_LIMIT_INFORMATION;

typedef struct _JOBOBJECT_ASSOCIATE_COMPLETION_PORT {
  PVOID CompletionKey;
  HANDLE CompletionPort;
} JOBOBJECT_ASSOCIATE_COMPLETION_PORT;

HANDLE CreateJobObjectW(LPSECURITY_ATTRIBUTES lpJobAttributes, LPCWSTR lpName);
BOOL AssignProcessToJobObject(HANDLE hJob, HANDLE hProcess);
BOOL TerminateJobObject(HANDLE hJob, UINT uExitCode);
BOOL SetInformationJobObject(HANDLE hJob, JOBOBJECTINFOCLASS JobObjectInformationClass,
                             LPVOID lpJobObjectInformation, DWORD cbJobObjectInformationLength);
BOOL QueryInformationJobObject(HANDLE hJob, JOBOBJECTINFOCLASS JobObjectInformationClass,
                               LPVOID lpJobObjectInformation, DWORD cbJobObjectInformationLength,
                               LPDWORD lpReturnLength);
BOOL IsProcessInJob(HANDLE ProcessHandle, HANDLE JobHandle, PBOOL Result);

// winioctl.h, winnt.h and ntifs.h: reparse points. FSCTL_GET_REPARSE_POINT
// is CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 42, METHOD_BUFFERED, FILE_ANY_ACCESS),
// which doesn't import; WinSDK.swift declares it, as Swift's overlay does.
// REPARSE_DATA_BUFFER is the Driver Kit's, in ntifs.h, not the SDK's.
#define MAXIMUM_REPARSE_DATA_BUFFER_SIZE (16 * 1024)
#define SYMLINK_FLAG_RELATIVE 0x00000001
#define ERROR_NOT_A_REPARSE_POINT 4390
#define ERROR_INVALID_REPARSE_DATA 4392

BOOL DeviceIoControl(HANDLE hDevice, DWORD dwIoControlCode, LPVOID lpInBuffer,
                     DWORD nInBufferSize, LPVOID lpOutBuffer, DWORD nOutBufferSize,
                     LPDWORD lpBytesReturned, LPOVERLAPPED lpOverlapped);

// synchapi.h and winnt.h: events, and waiting for several objects.
// WAIT_ABANDONED_0 is ((STATUS_ABANDONED_WAIT_0) + 0), which doesn't import.
#define MAXIMUM_WAIT_OBJECTS 64

BOOL SetEvent(HANDLE hEvent);
BOOL ResetEvent(HANDLE hEvent);
DWORD WaitForMultipleObjects(DWORD nCount, const HANDLE *lpHandles, BOOL bWaitAll,
                             DWORD dwMilliseconds);

// ws2def.h, iptypes.h, ifdef.h, ipifcons.h and iphlpapi.h: network adapters.
// The structures keep only the fields System reads, under the SDK's names,
// with the anonymous unions that put IfIndex and the address's Length first.
typedef int INT;
typedef unsigned char UINT8;
typedef unsigned short ADDRESS_FAMILY;
#define AF_UNSPEC 0
#define AF_INET 2
#define AF_INET6 23
#define MAX_ADAPTER_ADDRESS_LENGTH 8
#define GAA_FLAG_SKIP_ANYCAST 0x0002
#define GAA_FLAG_SKIP_MULTICAST 0x0004
#define GAA_FLAG_SKIP_DNS_SERVER 0x0008
#define IP_ADAPTER_NO_MULTICAST 0x0010
#define IF_TYPE_OTHER 1
#define IF_TYPE_ETHERNET_CSMACD 6
#define IF_TYPE_ISO88025_TOKENRING 9
#define IF_TYPE_PPP 23
#define IF_TYPE_SOFTWARE_LOOPBACK 24
#define IF_TYPE_ATM 37
#define IF_TYPE_IEEE80211 71
#define IF_TYPE_TUNNEL 131
#define IF_TYPE_IEEE1394 144
#define ERROR_BUFFER_OVERFLOW 111

// The SDK's tag is sockaddr, which the macOS SDK's Darwin module, which
// files that import this one see too, defines differently; Swift code
// reaches it only through LPSOCKADDR.
typedef struct _winsdk_model_sockaddr {
  ADDRESS_FAMILY sa_family;
  CHAR sa_data[14];
} SOCKADDR, *PSOCKADDR, *LPSOCKADDR;

typedef struct _SOCKET_ADDRESS {
  LPSOCKADDR lpSockaddr;
  INT iSockaddrLength;
} SOCKET_ADDRESS;

typedef enum _IF_OPER_STATUS : int {
  IfOperStatusUp = 1,
  IfOperStatusDown,
  IfOperStatusTesting,
  IfOperStatusUnknown,
  IfOperStatusDormant,
  IfOperStatusNotPresent,
  IfOperStatusLowerLayerDown
} IF_OPER_STATUS;

typedef struct _IP_ADAPTER_UNICAST_ADDRESS_LH {
  union {
    ULONGLONG Alignment;
    struct {
      ULONG Length;
      DWORD Flags;
    };
  };
  struct _IP_ADAPTER_UNICAST_ADDRESS_LH *Next;
  SOCKET_ADDRESS Address;
  UINT8 OnLinkPrefixLength;
} IP_ADAPTER_UNICAST_ADDRESS_LH, IP_ADAPTER_UNICAST_ADDRESS, *PIP_ADAPTER_UNICAST_ADDRESS;

typedef struct _IP_ADAPTER_ADDRESSES_LH {
  union {
    ULONGLONG Alignment;
    struct {
      ULONG Length;
      ULONG IfIndex;
    };
  };
  struct _IP_ADAPTER_ADDRESSES_LH *Next;
  CHAR *AdapterName;
  PIP_ADAPTER_UNICAST_ADDRESS FirstUnicastAddress;
  WCHAR *DnsSuffix;
  WCHAR *Description;
  WCHAR *FriendlyName;
  BYTE PhysicalAddress[MAX_ADAPTER_ADDRESS_LENGTH];
  ULONG PhysicalAddressLength;
  ULONG Flags;
  ULONG Mtu;
  ULONG IfType;
  IF_OPER_STATUS OperStatus;
  ULONG Ipv6IfIndex;
} IP_ADAPTER_ADDRESSES_LH, IP_ADAPTER_ADDRESSES, *PIP_ADAPTER_ADDRESSES;

ULONG GetAdaptersAddresses(ULONG Family, ULONG Flags, PVOID Reserved,
                           PIP_ADAPTER_ADDRESSES AdapterAddresses, PULONG SizePointer);
