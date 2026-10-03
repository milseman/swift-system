#!/usr/bin/env python3
"""Lists what the adopters' Windows code takes from Windows' C modules.

For each package in ../adopters, at its checkout's branch (committed content
only, read with git), it finds the Swift files that import WinSDK, ucrt, CRT
or visualc, keeps the lines each file compiles on Windows (with the #if
evaluator of Utilities/adopter-coverage/scripts/platforms.py, which counts a
line that's active in some Windows configurations as active), and lists the
names on those lines that look like C names: ALL_CAPS names, names that
begin with an underscore, and other names that nothing in Swift declares
(the adopters, swift-system, and the standard library, Foundation,
Dispatch, XCTest and swift-testing, as the macOS SDK's interfaces declare
them).

    survey-windows-imports.py names          # every name, with its files and packages, as JSON
    survey-windows-imports.py rank [NAMES]   # the ranking, as Markdown, from `names` output or a new survey
    survey-windows-imports.py files [NAMES]  # per package, the files System's API covers

It reads nothing but git objects, the macOS SDK, and Rust's bindings. The
classes, at the end of this file, are judgments: see Prototype/Win32/REPORT.md.
"""

import collections
import json
import os
import re
import subprocess
import sys

# The tools it imports live in tracked directories; leave no bytecode there.
sys.dont_write_bytecode = True
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ADOPTERS = os.path.abspath(os.path.join(ROOT, "..", "adopters"))
sys.path.insert(0, os.path.join(ROOT, "Utilities", "adopter-coverage", "scripts"))
sys.path.insert(0, os.path.join(ROOT, "Utilities", "api-delta", "scripts"))
import platforms  # noqa: E402
import scan_sources as ss  # noqa: E402

MODULES = ("WinSDK", "ucrt", "CRT", "visualc")
# Flags the packages test that are decided on Windows: Apple-internal build
# flags and swift-foundation's opt-outs are off, and SwiftPM defines
# SWIFT_PACKAGE. Every other flag is unknown, so its lines count.
FLAGS = {flag: {p: platforms.F for p in platforms.PLATFORMS if p != "Darwin"}
         for flag in ("FOUNDATION_FRAMEWORK", "LLBUILD_FRAMEWORK", "DATA_LEGACY_ABI", "NO_FILESYSTEM",
                      "NO_CSHIMS", "NO_PROCESS", "NO_FORMATTERS", "NO_TZFILE")}
FLAGS["SWIFT_PACKAGE"] = {p: platforms.T for p in platforms.PLATFORMS}
MODEL = platforms.model(flags=FLAGS)
IMPORT_RE = re.compile(
    r"^\s*(?:@\w+(?:\([^)]*\))?\s+)*(?:(?:public|package|internal|fileprivate|private)\s+)?"
    r"import\s+(?:(?:struct|class|enum|protocol|typealias|func|var|let)\s+)?"
    r"(" + "|".join(MODULES) + r")\b")
IDENTIFIER = re.compile(r"(?<![\w.$@])(?:\.)?([A-Za-z_][A-Za-z0-9_]*)")
ATTRIBUTE_ARGUMENT = re.compile(r"@\w+\([^)]*\)")
KEYWORDS = set("""
associatedtype class deinit enum extension fileprivate func import init inout internal let open operator
private precedencegroup protocol public rethrows static struct subscript typealias var break case catch
continue default defer do else fallthrough for guard if in repeat return throw switch where while as Any
false is nil self Self super throws true try await async some any consuming borrowing mutating nonmutating
package macro actor nonisolated isolated indirect lazy weak unowned optional required convenience dynamic
final override get set willSet didSet discard copy consume each repeat Type
""".split())
DECLARATION = re.compile(
    r"\b(?:func|var|let|struct|class|enum|protocol|typealias|case|associatedtype|actor|macro)\s+"
    r"(?:`)?([A-Za-z_][A-Za-z0-9_]*)")
PARAMETER = re.compile(r"[(,]\s*(?:_\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*:")


def git(repo, *args):
    return subprocess.run(["git", "-C", repo, *args], capture_output=True, text=True,
                          errors="replace").stdout


def packages():
    for name in sorted(os.listdir(ADOPTERS)):
        repo = os.path.join(ADOPTERS, name)
        if not os.path.exists(os.path.join(repo, ".git")):
            continue
        branch = git(repo, "rev-parse", "--abbrev-ref", "HEAD").strip()
        commit = git(repo, "rev-parse", "--short", branch).strip()
        yield name, repo, branch, commit


def swift_files(repo, branch):
    for path in git(repo, "ls-tree", "-r", "--name-only", branch).splitlines():
        if path.endswith(".swift") and "/.build/" not in path and not path.startswith(".build/"):
            yield path


def sdk_names():
    """Names the macOS SDK's Swift interfaces declare for the standard
    library and the frameworks Swift code on Windows also has."""
    sdk = subprocess.run(["xcrun", "--sdk", "macosx", "--show-sdk-path"], capture_output=True,
                         text=True).stdout.strip()
    names = set()
    for module in ("Swift", "Foundation", "FoundationEssentials", "Dispatch", "_Concurrency",
                   "Synchronization", "XCTest", "Testing", "_StringProcessing", "RegexBuilder",
                   "Observation", "Distributed", "System"):
        for base in (os.path.join(sdk, "usr", "lib", "swift"),
                     os.path.join(sdk, "System", "Library", "Frameworks")):
            directory = os.path.join(base, module + ".swiftmodule")
            if not os.path.isdir(directory):
                directory = os.path.join(base, module + ".framework", "Modules",
                                         module + ".swiftmodule")
            if not os.path.isdir(directory):
                continue
            for entry in os.listdir(directory):
                if entry.endswith(".swiftinterface") and "arm64" in entry:
                    text = open(os.path.join(directory, entry), errors="replace").read()
                    names.update(DECLARATION.findall(text))
                    names.update(PARAMETER.findall(text))
                    break
    return names


def windows_names():
    """Names the SDK and the UCRT declare, as far as this can tell without
    them: WindowsModel's headers and overlay, and the Win32 bindings of
    Rust's standard library, where installed."""
    names = set()
    model = os.path.join(ROOT, "Prototype", "Win32", "WindowsModel")
    for name in ("WinSDK.h", "ucrt.h", "WinSDK.swift"):
        text = open(os.path.join(model, name)).read()
        names.update(re.findall(r"#define\s+(\w+)", text))
        names.update(re.findall(r"\b(\w+)\s*\(", text))
        names.update(re.findall(r"typedef\b[^;]*?\b(\w+)\s*;", text))
        names.update(re.findall(r"\}\s*(\w+)", text))
        names.update(re.findall(r"public (?:var|typealias) (\w+)", text))
    sysroot = subprocess.run(["rustc", "--print", "sysroot"], capture_output=True,
                             text=True).stdout.strip()
    bindings = os.path.join(sysroot, "lib", "rustlib", "src", "rust", "library", "std", "src", "sys",
                            "pal", "windows", "c", "windows_sys.rs")
    if sysroot and os.path.exists(bindings):
        text = open(bindings).read()
        names.update(re.findall(r"\bfn (\w+)\s*\(", text))
        names.update(re.findall(r"\bpub (?:const|type|struct|union) (\w+)", text))
    return {n for n in names if len(n) > 1 and not n[0].islower()}


def declared_names(texts):
    names = set()
    for text in texts:
        code = ss.strip_comments_and_strings(text)[0]
        names.update(DECLARATION.findall(code))
        names.update(PARAMETER.findall(code))
        # Closure parameters and bound names.
        names.update(re.findall(r"\{\s*\(?\s*([a-z_][A-Za-z0-9_]*)(?:\s*,\s*[a-z_]\w*)*\s*\)?\s+in\b", code))
    return names


# Frameworks whose names Swift code on Windows sees through Foundation and
# Dispatch, which the SDK's Swift interfaces don't all declare.
FRAMEWORK_PREFIXES = ("NS", "CF", "Dispatch", "XCT", "os_")


# Lowercase C names are indistinguishable from Swift's lexically, so only
# these count: the C library interfaces the coverage lane's mapping names,
# and the C runtime's common ones it doesn't.
C_LOWERCASE_EXTRA = set("""
errno strlen strcmp strncmp strcpy strncpy strcat strchr strrchr strstr strerror strerror_s strtol strtoul
strtoull strtod atoi atol wcslen wcscpy wcsncpy wcscmp wcsncmp wcsnlen wcschr wcsrchr wmemcpy wmemset
wcstombs mbstowcs fflush fputs fwrite fread fgets fgetc fprintf printf puts putchar stdout stderr stdin
getenv putenv time localtime gmtime mktime strftime difftime clock system exit abort atexit qsort bsearch
isatty setlocale localeconv tolower toupper isspace isdigit isalpha memchr calloc free malloc realloc
memcmp memcpy memmove memset rand srand signal raise vsnprintf snprintf sprintf sscanf
""".split())


def c_lowercase():
    import configparser
    parser = configparser.RawConfigParser(strict=False)
    parser.optionxform = str
    parser.read(os.path.join(ROOT, "Utilities", "adopter-coverage", "mapping.ini"))
    names = set(C_LOWERCASE_EXTRA)
    for section in parser.sections():
        for symbol in parser.get(section, "symbols", fallback=section).split():
            if re.fullmatch(r"[a-z][a-z0-9_]*", symbol):
                names.add(symbol)
    # Words the mapping lists that are Swift's as often as C's.
    return names - {"description", "config", "bool", "index", "remove", "round", "floor", "ceil",
                    "log2", "pow", "modf", "frexp", "fabs", "link", "kill", "assert"}


def looks_like_c(name, swift_names, modules, lowercase=(), local=()):
    if name in KEYWORDS or name in modules:
        return False
    if re.fullmatch(r"[a-z][a-z0-9_]*", name):
        return name in lowercase and name not in local
    # Windows' constants and macros, even where a package redeclares them.
    if re.fullmatch(r"[A-Z][A-Z0-9]*(?:_[A-Z0-9]+)+", name):
        return True
    if name in swift_names or name.startswith(FRAMEWORK_PREFIXES):
        return False
    if name.startswith("_"):
        return True
    return not re.fullmatch(r"[a-z]\w*|\$\w*", name)


def survey():
    swift_names = sdk_names()
    everything = []
    for name, repo, branch, commit in packages():
        paths = list(swift_files(repo, branch))
        texts = {}
        for path in paths:
            text = git(repo, "show", f"{branch}:{path}")
            texts[path] = text
        everything.append((name, repo, branch, commit, texts))
    # Names any Swift code here declares: System's libraries (not its samples,
    # whose Win32 stand-ins declare Windows' names) and the adopters.
    for path in subprocess.run(["git", "-C", ROOT, "ls-files", "Sources/System/*.swift",
                                "Sources/SystemSockets/*.swift"], capture_output=True,
                               text=True).stdout.splitlines():
        try:
            swift_names |= declared_names([open(os.path.join(ROOT, path), errors="replace").read()])
        except OSError:
            pass
    modules = set()
    for _, _, _, _, texts in everything:
        swift_names |= declared_names(texts.values())
        for text in texts.values():
            modules.update(re.findall(r"^\s*(?:@\w+\s+)*(?:\w+\s+)?import\s+(?:\w+\s+)?(\w+)", text,
                                      re.MULTILINE))
    # Windows' own names are C names even where a package redeclares one,
    # as a stand-in off Windows or a shim on it.
    swift_names -= windows_names()
    lowercase = c_lowercase()
    result = {"packages": [], "names": {}}
    for name, repo, branch, commit, texts in everything:
        package = {"name": name, "branch": branch, "commit": commit, "files": []}
        for path, text in sorted(texts.items()):
            if not any(m in text for m in MODULES):
                continue
            code = ss.strip_comments_and_strings(text)[0].split("\n")
            imports = set()
            try:
                states, _, _ = platforms.swift_line_states(code, MODEL)
            except ValueError as error:
                package["files"].append({"path": path, "error": str(error)})
                continue
            scoped = collections.Counter()
            for index, line in enumerate(code):
                match = IMPORT_RE.match(line)
                if match and "Windows" in states[index]:
                    imports.add(match.group(1))
                    # `import struct WinSDK.socklen_t` names what it uses.
                    symbol = re.search(r"\b(?:" + "|".join(MODULES) + r")\.(\w+)", line)
                    if symbol:
                        scoped[symbol.group(1)] += 1
            if not imports:
                continue
            names = collections.Counter(scoped)
            local = set(DECLARATION.findall("\n".join(code)))
            for index, line in enumerate(code):
                if "Windows" not in states[index] or line.lstrip().startswith(("#", "import ")):
                    continue
                if IMPORT_RE.match(line):
                    continue
                line = ATTRIBUTE_ARGUMENT.sub(" ", line)
                # A module-qualified name, such as WinSDK.FILE_SHARE_READ.
                line = re.sub(r"\b(?:" + "|".join(MODULES) + r")\.(?=[A-Za-z_])", " ", line)
                for match in IDENTIFIER.finditer(line):
                    token = match.group(1)
                    member = match.group(0).startswith(".")
                    if member:
                        continue
                    if re.fullmatch(r"[a-z][a-z0-9_]*", token):
                        # A lowercase C name counts as a call, a bare global,
                        # or a type (`_t`).
                        after = line[match.end():].lstrip()
                        if not (after.startswith("(") or token.endswith("_t")
                                or token in ("errno", "stdout", "stderr", "stdin")):
                            continue
                    if looks_like_c(token, swift_names, modules, lowercase, local):
                        names[token] += 1
            kind = "test" if re.search(r"(^|/)(Tests?|Fixtures)/", path) else "source"
            package["files"].append({"path": path, "imports": sorted(imports), "kind": kind,
                                     "names": dict(names)})
            for token, count in names.items():
                entry = result["names"].setdefault(token, {"files": 0, "packages": set(), "uses": 0,
                                                           "source_files": 0})
                entry["files"] += 1
                entry["uses"] += count
                entry["packages"].add(name)
                if kind == "source":
                    entry["source_files"] += 1
        result["packages"].append(package)
    for entry in result["names"].values():
        entry["packages"] = sorted(entry["packages"])
    return result




# ---------------------------------------------------------------- the classes
#
# Every name the survey finds is in one concept. A concept is one of:
#   new       covered by this lane's Win32 API (Sources/System/Win32)
#   existing  covered by API System already has on Windows
#   gap       needs new System API
#   other     not System's: another library's, or the C library's
#   types     Windows' currency types, which go when the calls that take them go
#   ignore    not a Windows or C runtime interface: the package's own names,
#             other C modules' shims, Darwin names on lines Windows also compiles
# A name is an exact name or `re:` and a pattern. The first concept that names
# a name has it.
CONCEPTS = [
    # ---- new: this lane's API
    ("new", "Error codes, messages and last error", "Win32.Error, its description, Errno(approximating:)",
     ["GetLastError", "SetLastError", "FormatMessageW", "FORMAT_MESSAGE_ALLOCATE_BUFFER",
      "FORMAT_MESSAGE_FROM_SYSTEM", "FORMAT_MESSAGE_IGNORE_INSERTS", "LANG_NEUTRAL", "SUBLANG_DEFAULT",
      "NO_ERROR", "re:^ERROR_[A-Z0-9_]+$", "CNIOWindows_FormatGetLastError"]),
    ("new", "Opening and closing files", "Win32.FileHandle.open, openOrCreate, close(); DirectoryHandle.open",
     ["CreateFileW", "CloseHandle", "INVALID_HANDLE_VALUE", "GENERIC_READ", "GENERIC_WRITE", "DELETE",
      "SYNCHRONIZE", "FILE_SHARE_READ", "FILE_SHARE_WRITE", "FILE_SHARE_DELETE", "OPEN_EXISTING",
      "OPEN_ALWAYS", "CREATE_ALWAYS", "CREATE_NEW", "FILE_FLAG_BACKUP_SEMANTICS",
      "FILE_FLAG_OPEN_REPARSE_POINT", "FILE_ATTRIBUTE_NORMAL", "FILE_LIST_DIRECTORY", "SECURITY_ATTRIBUTES"]),
    ("new", "Reading, writing, size and flush", "Win32.FileHandle read, readFully, write, append, size(), flush(), resize(to:)",
     ["ReadFile", "WriteFile", "GetFileSizeEx", "FlushFileBuffers", "SetFileInformationByHandle",
      "FILE_END_OF_FILE_INFO", "FileEndOfFileInfo"]),
    ("new", "File type", "Win32.FileHandle.fileType()",
     ["GetFileType", "FILE_TYPE_DISK", "FILE_TYPE_PIPE", "FILE_TYPE_CHAR", "FILE_TYPE_UNKNOWN"]),
    ("new", "Duplicating handles and inheritance", "duplicate(access:inheritable:), setInheritable(_:)",
     ["DuplicateHandle", "DUPLICATE_SAME_ACCESS", "SetHandleInformation",
      "HANDLE_FLAG_INHERIT"]),
    ("new", "Descriptor and handle bridges", "FileDescriptor.withWin32HandleIfAvailable(_:), init(adopting:translation:append:)",
     ["_get_osfhandle", "_open_osfhandle", "_O_BINARY", "_O_APPEND", "_O_NOINHERIT"]),
    ("new", "Byte-range locks", "withLock(byteRange:mode:_:), withLockIfAvailable",
     ["LockFileEx", "UnlockFileEx", "LOCKFILE_EXCLUSIVE_LOCK"]),
    ("new", "Final path of a handle", "finalPath(volumeName:normalized:)",
     ["GetFinalPathNameByHandleW", "VOLUME_NAME_DOS", "FILE_NAME_NORMALIZED"]),
    ("new", "Volume information", "volumeInformation(), through a handle to the volume's root",
     ["GetVolumeInformationW"]),

    # ---- existing: System's API on Windows before this lane
    ("existing", "Descriptor I/O", "FileDescriptor open, close, read, write, seek, duplicate, pipe, resize",
     ["_close", "_read", "_write", "_lseek", "_lseeki64", "_dup", "_dup2", "_chsize_s", "_sopen_s",
      "_wsopen_s", "_SH_DENYNO", "_O_RDONLY", "_O_RDWR", "_O_WRONLY", "O_CREAT", "O_EXCL", "O_RDONLY",
      "O_RDWR", "O_WRONLY", "SEEK_SET", "SEEK_CUR", "SEEK_END", "close", "fcntl", "off_t", "STDOUT_FILENO"]),
    ("existing", "Permissions for new files", "FilePermissions, through FileDescriptor.open",
     ["_S_IREAD", "_S_IWRITE", "_S_IEXEC"]),
    ("existing", "errno and its values", "Errno, Errno.current, Errno.description",
     ["errno", "_get_errno", "_set_errno", "strerror", "strerror_s", "_wcserror_s",
      "re:^E[A-Z0-9]+$"]),
    ("existing", "Path syntax", "FilePath: root, isAbsolute, isRelative, lastComponent, extension, removingLastComponent",
     ["PathCchIsRoot", "PathCchRemoveFileSpec", "PathCchSkipRoot", "PathCchStripToRoot", "PathFindExtensionW",
      "PathIsRelativeW", "PathIsSameRootW", "PathStripPathW"]),

    # ---- gaps
    ("gap", "SRW locks and condition variables", "Synchronization.Mutex covers the lock",
     ["SRWLOCK", "InitializeSRWLock", "AcquireSRWLockExclusive", "ReleaseSRWLockExclusive",
      "AcquireSRWLockShared", "ReleaseSRWLockShared", "TryAcquireSRWLockExclusive", "CONDITION_VARIABLE",
      "InitializeConditionVariable", "WakeConditionVariable", "WakeAllConditionVariable",
      "SleepConditionVariableSRW", "SleepConditionVariableCS", "CRITICAL_SECTION",
      "InitializeCriticalSection", "EnterCriticalSection", "LeaveCriticalSection", "DeleteCriticalSection"]),
    ("gap", "Creating, waiting for and ending processes", "Processes and RawSpawn are POSIX-only",
     ["CreateProcessW", "CreateProcessWithLogonW", "LOGON_WITH_PROFILE", "STARTUPINFOW", "STARTUPINFOEXW",
      "PROCESS_INFORMATION", "re:^CREATE_(SUSPENDED|NEW_PROCESS_GROUP|NEW_CONSOLE|UNICODE_ENVIRONMENT)$",
      "DETACHED_PROCESS", "EXTENDED_STARTUPINFO_PRESENT", "STARTF_USESTDHANDLES", "STARTF_USESHOWWINDOW",
      "re:^SW_[A-Z]+$", "InitializeProcThreadAttributeList", "UpdateProcThreadAttribute",
      "DeleteProcThreadAttributeList", "LPPROC_THREAD_ATTRIBUTE_LIST",
      "_subprocess_PROC_THREAD_ATTRIBUTE_HANDLE_LIST", "ResumeThread", "TerminateProcess", "OpenProcess",
      "re:^PROCESS_(TERMINATE|QUERY_INFORMATION|QUERY_LIMITED_INFORMATION|SET_INFORMATION)$",
      "GetExitCodeProcess", "WaitForSingleObject", "WaitForMultipleObjects", "WAIT_OBJECT_0",
      "WAIT_TIMEOUT", "WAIT_FAILED", "RegisterWaitForSingleObject", "GetCurrentProcess", "UnregisterWait", "UnregisterWaitEx",
      "WT_EXECUTEONLYONCE", "WT_EXECUTELONGFUNCTION", "WAITORTIMERCALLBACK", "GetCurrentProcessId",
      "getpid", "pid_t", "SetPriorityClass", "re:^[A-Z_]+_PRIORITY_CLASS$", "GenerateConsoleCtrlEvent",
      "CTRL_C_EVENT", "CTRL_BREAK_EVENT", "STATUS_DLL_INIT_FAILED", "NTSTATUS", "CreateToolhelp32Snapshot",
      "Process32FirstW", "Process32NextW", "PROCESSENTRY32W", "TH32CS_SNAPPROCESS", "K32GetProcessMemoryInfo",
      "PROCESS_MEMORY_COUNTERS", "GetProcessHandleCount", "CompareObjectHandles", "EXIT_SUCCESS",
      "EXIT_FAILURE"]),
    ("gap", "Job objects", "the Windows counterpart of process groups",
     ["CreateJobObjectW", "CreateJobObjectA", "AssignProcessToJobObject", "SetInformationJobObject",
      "TerminateJobObject", "IsProcessInJob", "JOBOBJECT_EXTENDED_LIMIT_INFORMATION",
      "JOBOBJECT_ASSOCIATE_COMPLETION_PORT", "re:^JOB_OBJECT_[A-Z_]+$", "JobObjectExtendedLimitInformation",
      "JobObjectAssociateCompletionPortInformation"]),
    ("gap", "Threads and thread-local storage", "Threads (PThread) is POSIX-only",
     ["GetCurrentThread", "GetCurrentThreadId", "_beginthreadex", "SetThreadDescription",
      "GetThreadDescription", "SwitchToThread", "FlsAlloc", "FlsFree", "FlsGetValue", "FlsSetValue",
      "TF_USE_KERNEL_APC"]),
    ("gap", "Events", "an owner for event handles",
     ["CreateEventW", "SetEvent"]),
    ("gap", "Anonymous and named pipes", "SYS-0011's future directions; FileDescriptor.pipe() makes C runtime pipes",
     ["CreatePipe", "CreateNamedPipeW", "re:^PIPE_[A-Z_]+$", "FILE_FLAG_FIRST_PIPE_INSTANCE", "PeekNamedPipe",
      "SetNamedPipeHandleState"]),
    ("gap", "Overlapped I/O and completion ports", "SYS-0011 and SYS-0013's future directions",
     ["CreateIoCompletionPort", "GetQueuedCompletionStatus", "PostQueuedCompletionStatus",
      "GetOverlappedResult", "CancelIoEx", "OVERLAPPED", "LPOVERLAPPED", "_OVERLAPPED", "FILE_FLAG_OVERLAPPED"]),
    ("gap", "Querying and setting file information", "SYS-0010's roadmap: GetFileInformationByHandleEx and SetFileInformationByHandle's other classes",
     ["GetFileAttributesW", "GetFileAttributesExW", "GetFileExInfoStandard", "WIN32_FILE_ATTRIBUTE_DATA",
      "SetFileAttributesW", "INVALID_FILE_ATTRIBUTES", "re:^FILE_ATTRIBUTE_(DIRECTORY|REPARSE_POINT|READONLY)$",
      "GetFileInformationByHandle", "BY_HANDLE_FILE_INFORMATION", "GetFileInformationByHandleEx",
      "FILE_BASIC_INFO", "FileBasicInfo", "FILE_ATTRIBUTE_TAG_INFO", "FileAttributeTagInfo", "FILE_ID_INFO",
      "FileIdInfo", "_FILE_ID_128", "FILETIME", "SetFileTime", "ULARGE_INTEGER"]),
    ("gap", "Creating, removing, renaming, copying and linking files", "FilePathOperations is POSIX-only",
     ["CreateDirectoryW", "RemoveDirectoryW", "DeleteFileW", "MoveFileExW", "re:^MOVEFILE_[A-Z_]+$",
      "CopyFileW", "CopyFile2", "COPYFILE2_EXTENDED_PARAMETERS", "re:^COPY_FILE_[A-Z_]+$",
      "CreateSymbolicLinkW", "re:^SYMBOLIC_LINK_FLAG_[A-Z_]+$", "FILE_RENAME_INFO", "FileRenameInfoEx",
      "re:^FILE_RENAME_FLAG_[A-Z_]+$", "FILE_DISPOSITION_INFO_EX", "FileDispositionInfoEx",
      "re:^FILE_DISPOSITION_FLAG_[A-Z_]+$", "_mkdir", "_mktemp_s", "_commit"]),
    ("gap", "Directory enumeration", "SYS-0011's future directions (DirectoryHandle)",
     ["FindFirstFileExW", "FindNextFileW", "FindClose", "WIN32_FIND_DATAW", "FindExInfoBasic",
      "FindExSearchNameMatch", "re:^FIND_FIRST_EX_[A-Z_]+$", "opendir", "closedir"]),
    ("gap", "Reparse points", "SYS-0016's future directions: DeviceIoControl with FSCTL_GET_REPARSE_POINT",
     ["DeviceIoControl", "FSCTL_GET_REPARSE_POINT", "REPARSE_DATA_BUFFER", "MAXIMUM_REPARSE_DATA_BUFFER_SIZE",
      "re:^IO_REPARSE_TAG_[A-Z_]+$", "CNIOWindows_REPARSE_DATA_BUFFER",
      "_ioshims_reparse_data_buffer_mountpointreparsebuffer_pathbuffer_offset",
      "_ioshims_reparse_data_buffer_symboliclinkreparsebuffer_pathbuffer_offset"]),
    ("gap", "Directory change notification", "SYS-0011's future directions (DirectoryHandle)",
     ["ReadDirectoryChangesW", "re:^FILE_NOTIFY_[A-Z_]+$", "FILE_NOTIFY_INFORMATION"]),
    ("gap", "Long paths and canonicalization", "System canonicalizes internally; nothing public",
     ["GetFullPathNameW", "PathAllocCanonicalize", "PATHCCH_ALLOW_LONG_PATHS",
      "PATHCCH_ENSURE_IS_EXTENDED_LENGTH_PATH", "PathCchStripPrefix"]),
    ("gap", "HRESULT", "SYS-0010's future directions: Win32.HResult",
     ["HRESULT", "HRESULT_CODE", "HRESULT_FACILITY", "WIN32_FROM_HRESULT", "SUCCEEDED", "FACILITY_WIN32",
      "S_OK", "S_FALSE"]),
    ("gap", "The current, temporary, Windows and executable directories", "SystemPaths and Executable are POSIX-only",
     ["GetCurrentDirectoryW", "SetCurrentDirectoryW", "GetTempPathW", "GetTempPath2W", "GetWindowsDirectoryW",
      "GetSystemDirectoryW", "GetModuleFileNameW", "getcwd"]),
    ("gap", "Environment variables", "ProcessEnvironment is POSIX-only",
     ["GetEnvironmentVariableW", "SetEnvironmentVariableW", "GetEnvironmentStringsW", "FreeEnvironmentStringsW",
      "LPWCH", "_putenv", "_putenv_s", "_wputenv_s", "_dupenv_s"]),
    ("gap", "Dynamic loading", "DynamicLibrary is POSIX-only",
     ["LoadLibraryW", "FreeLibrary", "GetProcAddress", "GetModuleHandleW", "GetModuleHandleA", "HMODULE"]),
    ("gap", "Consoles and standard handles", "Terminal is POSIX-only; SYS-0011 and SYS-0012's future directions",
     ["GetStdHandle", "re:^STD_(INPUT|OUTPUT|ERROR)_HANDLE$", "GetConsoleMode", "SetConsoleMode",
      "re:^ENABLE_[A-Z_]+$", "GetConsoleScreenBufferInfo", "CONSOLE_SCREEN_BUFFER_INFO",
      "SetConsoleCtrlHandler", "AttachConsole", "FreeConsole", "GetConsoleWindow", "ReadConsoleA", "isatty",
      "signal"]),
    ("gap", "Clocks, sleeping and time zones", "ClockTime, Sleep and BrokenDownTime are POSIX-only",
     ["GetTickCount64", "QueryPerformanceCounter", "QueryPerformanceFrequency",
      "QueryUnbiasedInterruptTimePrecise", "GetSystemTimePreciseAsFileTime", "GetSystemTimeAsFileTime",
      "GetTimeZoneInformation", "TIME_ZONE_INFORMATION", "TIME_ZONE_ID_INVALID", "Sleep", "usleep",
      "__time64_t", "_time64", "_gmtime64_s", "_localtime64_s", "time", "strftime", "timeval"]),
    ("gap", "System and processor information", "SystemConfig and uname are POSIX-only",
     ["GetSystemInfo", "SYSTEM_INFO", "GetLogicalProcessorInformation", "SYSTEM_LOGICAL_PROCESSOR_INFORMATION",
      "RelationProcessorCore", "GetPhysicallyInstalledSystemMemory", "GetComputerNameExW",
      "ComputerNameDnsHostname", "RTL_OSVERSIONINFOEXW", "VER_NT_WORKSTATION", "VER_SUITE_WH_SERVER",
      "re:^IMAGE_FILE_MACHINE_[A-Z0-9]+$", "MAX_HOSTNAME_LENGTH"]),
    ("gap", "Users, tokens and security identifiers", "UserDatabase and ProcessCredentials are POSIX-only; SYS-0011's future directions",
     ["GetUserNameW", "GetUserNameExW", "NameDisplay", "UNLEN", "GetUserProfileDirectoryW", "OpenProcessToken",
      "GetTokenInformation", "TOKEN_QUERY", "TokenElevation", "TOKEN_ELEVATION", "CheckTokenMembership",
      "AllocateAndInitializeSid", "FreeSid", "ConvertSidToStringSidW", "LookupAccountNameW",
      "SID_IDENTIFIER_AUTHORITY", "SID_NAME_USE", "SidTypeUnknown", "PSID", "DOMAIN_ALIAS_RID_ADMINS",
      "SECURITY_BUILTIN_DOMAIN_RID"]),
    ("gap", "Memory-mapped files", "MemoryMapping is POSIX-only",
     ["CreateFileMappingW", "MapViewOfFile", "UnmapViewOfFile", "FILE_MAP_READ", "PAGE_READONLY"]),
    ("gap", "Free space and volume paths", "SYS-0015's future directions",
     ["GetDiskFreeSpaceExW", "GetVolumePathNameW"]),
    ("gap", "Winsock sockets", "SystemSockets is Unix-only",
     ["re:^WSA[A-Za-z0-9_]*$", "LPFN_WSARECVMSG", "LPFN_WSASENDMSG", "LPWSAMSG", "SOCKET", "INVALID_SOCKET",
      "SOCKET_ERROR", "TransmitFile", "GetAddrInfoW", "FreeAddrInfoW", "ADDRINFOW", "InetPtonW",
      "re:^SOCKADDR(_[A-Z0-9]+)?$", "re:^(AF|PF)_[A-Z0-9]+$", "ADDRESS_FAMILY", "re:^SOCK_[A-Z]+$",
      "SOL_SOCKET", "SOL_UDP", "re:^SO_[A-Z_]+$", "LINGER", "re:^IPPROTO_[A-Z0-9]+$", "re:^IP_[A-Z_]+$",
      "re:^IPV6_[A-Z0-9_]+$", "re:^IPTOS_[A-Z0-9_]+$", "TCP_NODELAY", "IN_ADDR", "IN6_ADDR", "INADDR_ANY",
      "INET_ADDRSTRLEN", "INET6_ADDRSTRLEN", "re:^SHUT_[A-Z]+$", "re:^SD_[A-Z]+$", "FIONBIO",
      "re:^IOC_[A-Z0-9]+$", "SIO_GET_EXTENSION_FUNCTION_POINTER", "re:^POLL[A-Z]+$", "UIO_MAXIOV",
      "closesocket", "ioctlsocket", "accept", "listen", "recv", "send", "inet_pton", "inet_ntop", "socklen_t",
      "bind", "connect", "getpeername", "getsockname", "shutdown", "socket", "sockaddr", "u_long",
      "gai_strerrorA",
      "sockaddr_in", "sockaddr_in6", "sockaddr_storage", "sockaddr_un", "sa_family_t", "in_addr", "in6_addr",
      "in_port_t", "ip_mreq", "ipv6_mreq", "linger", "msghdr", "pollfd", "u_short",
      "re:^CNIOWindows_(CMSG_[A-Z_]+|getsockopt|setsockopt|recv|recvmmsg|send|mmsghdr)$"]),
    ("gap", "Network interfaces", "NetworkInterfaces is POSIX-only",
     ["GetAdaptersAddresses", "IP_ADAPTER_ADDRESSES", "IP_ADAPTER_UNICAST_ADDRESS", "NETWORK_PREFIX"]),

    # ---- other: not System's
    ("other", "Shell and COM: known folders, file info, MIME types", "the Shell; not System's",
     ["SHGetKnownFolderPath", "KNOWNFOLDERID", "re:^FOLDERID_[A-Za-z0-9]+$", "KF_FLAG_DEFAULT", "CoTaskMemFree",
      "SHGetFileInfoW", "SHGFI_EXETYPE", "FindMimeFromData", "FMFD_URLASFILENAME", "SaferiIsExecutableFileType",
      "_GUID"]),
    ("other", "The registry", "advapi32's registry; not System's",
     ["RegGetValueW", "RRF_RT_REG_SZ", "HKEY_LOCAL_MACHINE"]),
    ("other", "Hashing", "bcrypt's hashes; swift-crypto's",
     ["re:^BCRYPT_[A-Z_]+$", "re:^BCrypt[A-Za-z]+$"]),
    ("other", "User accounts (tests)", "netapi32; test set-up",
     ["NetUserAdd", "NetUserDel", "USER_INFO_1", "re:^UF_[A-Z_]+$", "USER_PRIV_USER", "NERR_Success"]),
    ("other", "The C library: strings, memory, stdio, locales", "Swift's standard library and Foundation",
     ["free", "realloc", "memcmp", "memcpy", "memmove", "strlen", "wcslen", "strdup", "_strdup", "_strnicmp_l",
      "_strtod_l", "_strtof_l", "_create_locale", "_locale_t", "setlocale", "LC_ALL", "stderr", "stdout",
      "stdin", "fclose", "fopen", "fread", "fwrite", "fputs", "fflush", "putc", "setvbuf", "fileno", "_fileno",
      "_fdopen", "_wfopen", "_IOFBF", "_IONBF", "FILE", "_lock_file", "_unlock_file", "atexit", "_amkrtemp"]),

    # ---- types
    ("types", "Windows' currency types and constants, and LocalFree", "follow the calls that take or return them",
     ["LocalFree", "INFINITE", "MAX_PATH", "PATH_MAX", "MAX_PATH_SIZE", "LARGE_INTEGER", "DWORD", "WORD", "HANDLE", "WCHAR", "ULONG", "LONG", "UINT", "USHORT", "ULONGLONG", "ULONG_PTR",
      "SIZE_T", "SSIZE_T", "CHAR", "UINT8", "PWSTR", "LPWSTR", "LPCWSTR", "PCWSTR", "WindowsBool", "intptr_t",
      "size_t", "wchar_t", "errno_t"]),

    # ---- ignore
    ("ignore", "Darwin names on lines Windows also compiles", "#if conditions the evaluator can't decide",
     ["ATTR_BIT_MAP_COUNT", "ATTR_CMN_DATA_PROTECT_FLAGS", "FSOPT_NOFOLLOW", "F_GETPROTECTIONCLASS",
      "F_SETPROTECTIONCLASS", "MNT_CPROTECT", "MNT_LOCAL", "MNT_REMOVABLE", "DIR", "XPCPrivate",
      "QUASI_PID_START", "statfs"]),
    ("ignore", "Other C modules' names", "CoreFoundation's and Foundation's shims, sourcekitd, swiftScan, llbuild",
     ["re:^_?_CF[A-Za-z]+$", "re:^_NS[A-Za-z]+$", "_foundation_sandbox_check", "_platform_shims__environ",
      "re:^SOURCEKITD_API_[A-Z0-9_]+$", "re:^SWIFTSCAN_[A-Z_]+$", "SWIFT_FRONTEND_EXEC", "SWIFT_SCANNER_LIB",
      "LLBUILD_C_API_VERSION", "re:^_subprocess_windows_[a-z_]+$", "CNIOWindows_errno",
      "CONNECT_DELAYER", "CONNECT_RECORDER", "NSEC_PER_SEC", "EXIT_NO_TESTS_FOUND", "MAX_DEPTH"]),
    ("ignore", "Swift names the survey can't see declared", "the packages' own types, and their dependencies'",
     ["ASN1OctetString", "AtomicValue", "BaseNameType", "re:^Build[A-Za-z]+$", "ByteCollection",
      "ChannelInitializerResult", "CommandResult", "CommandStatusKind", "ConditionTrait", "ConvertibleFromBytes",
      "CycleAction", "DateFormatter", "Deque", "DestinationType", "DiscoveredDependencyKind", "HTTPURLResponse",
      "In", "InputElement", "InputString", "re:^LanguageServerProtocol[A-Za-z]*$", "ManagedAtomic", "ObjCBool",
      "Out", "PLACEHOLDER_TOKEN_USER", "RuleRunReason", "SIG_FIG", "SymbolGraph", "TX", "TargetEncoding",
      "TargetStream", "URLResponse", "UnsafeAtomic", "ToolsProtocolsSwiftExtensions", "SKLogging"]),
]


def classify(name):
    for kind, concept, api, names in CONCEPTS:
        for entry in names:
            if entry.startswith("re:"):
                if re.fullmatch(entry[3:], name):
                    return kind, concept, api
            elif entry == name:
                return kind, concept, api
    return None


def rank(data):
    """The ranking, as Markdown: concepts by packages, then files."""
    files_of = collections.defaultdict(set)
    for package in data["packages"]:
        for f in package["files"]:
            for name in f.get("names", {}):
                files_of[name].add((package["name"], f["path"], f.get("kind")))
    concepts = collections.OrderedDict()
    unclassified = []
    for name, entry in data["names"].items():
        found = classify(name)
        if not found:
            unclassified.append(name)
            continue
        key = found
        c = concepts.setdefault(key, {"names": collections.Counter(), "files": set()})
        c["names"][name] += entry["uses"]
        c["files"] |= files_of[name]
    rows = []
    for (kind, concept, api), c in concepts.items():
        packages = sorted({p for p, _, _ in c["files"]})
        sources = {(p, f) for p, f, k in c["files"] if k == "source"}
        rows.append((kind, concept, api, packages, len(c["files"]), len(sources), c["names"]))
    return rows, sorted(unclassified)


def print_ranking(data):
    rows, unclassified = rank(data)
    order = {"gap": 0, "new": 1, "existing": 2, "other": 3, "types": 4, "ignore": 5}
    rows.sort(key=lambda r: (order[r[0]], -len(r[3]), -r[4], r[1]))
    print("| class | concept | packages | files (sources) | names, by uses | System, or owner |")
    print("|---|---|---|---|---|---|")
    for kind, concept, api, packages, files, sources, names in rows:
        top = ", ".join(f"`{n}`" for n, _ in names.most_common(6))
        more = len(names) - 6
        if more > 0:
            top += f" and {more} more"
        print(f"| {kind} | {concept} | {len(packages)}: {', '.join(packages)} | {files} ({sources}) | {top} | {api} |")
    if unclassified:
        print("\nUnclassified:", " ".join(unclassified))




def file_status(names, covered):
    """What stands between a file and dropping its Windows imports: nothing
    the survey can see (`nothing`), only Windows' types (`types`), names
    System covers (`covered`), a gap, or names that aren't System's (`other`)."""
    kinds = set()
    for name in names:
        found = classify(name)
        kinds.add(found[0] if found else "gap")
    kinds.discard("ignore")
    if not kinds:
        return "nothing"
    if kinds == {"types"}:
        return "types"
    kinds.discard("types")
    kinds -= covered
    if not kinds:
        return "covered"
    return "gap" if ("gap" in kinds or "new" in kinds) else "other"


def print_files(data):
    """Per package, what its Windows-importing files use: nothing the survey
    sees, only types, names System covers before this lane (`existing`) and
    with it (`existing` and `new`), a gap, or only other libraries' names."""
    print("| package | files (sources, tests) | nothing seen | only types | covered before | covered now "
          "| need a gap | need only other libraries |")
    print("|---|---|---|---|---|---|---|---|")
    keys = ("files", "sources", "tests", "nothing", "types", "before", "after", "gap", "other")
    totals = collections.Counter()
    for package in data["packages"]:
        files = [f for f in package["files"] if "names" in f]
        if not files:
            continue
        before = collections.Counter(file_status(f["names"], {"existing"}) for f in files)
        after = collections.Counter(file_status(f["names"], {"existing", "new"}) for f in files)
        sources = sum(1 for f in files if f["kind"] == "source")
        row = (len(files), sources, len(files) - sources, after["nothing"], after["types"], before["covered"],
               after["covered"], after["gap"], after["other"])
        totals.update(dict(zip(keys, row)))
        print(f"| {package['name']} | {row[0]} ({row[1]}, {row[2]}) | " + " | ".join(map(str, row[3:])) + " |")
    print(f"| all | {totals['files']} ({totals['sources']}, {totals['tests']}) | "
          + " | ".join(str(totals[k]) for k in keys[3:]) + " |")


if __name__ == "__main__":
    command = sys.argv[1] if len(sys.argv) > 1 else ""
    if command == "names":
        json.dump(survey(), sys.stdout, indent=1, sort_keys=True)
    elif command in ("rank", "files"):
        data = json.load(open(sys.argv[2])) if len(sys.argv) > 2 else survey()
        (print_ranking if command == "rank" else print_files)(data)
    else:
        print(__doc__)
        sys.exit(1)
