#!/usr/bin/env python3
"""List the lines of Swift sources that import Darwin or name common Darwin and libc interfaces.

Usage: dgrep.py [--via Foundation,XCTest] [--no-darwin] [--files] [--all-platforms] PATH...

For each Swift file under the PATHs (directories are listed as git lists them, without ignored
files; outside a checkout, every file but .build's), prints `file:line: [hits] source` for each line
that imports Darwin (any form), a module that re-exports it (TSCLibc, MachO), or names a Darwin or
libc function, type, constant or errno. Comments and string literals are skipped, but the code in
a string's interpolation isn't (`"\\(String(cString: strerror(errno)))"`). Names the file declares
itself (a method, a local, a case, a parameter or argument label) don't count, and neither does code in an `#if` branch that a
macOS build certainly doesn't compile (`#if os(Linux)`, `#elseif canImport(Glibc)`, the `#else` of
`#if canImport(Darwin)`), unless --all-platforms; a branch that depends on a flag or the compiler's
version counts.

It's the quick way to find Darwin names reached through another module's re-export, without a
build: `--via Foundation,XCTest` keeps only files that import one of those modules, and
`--no-darwin` only files that don't import Darwin themselves. It can miss a name that isn't in its
lists (darwin_audit.py reads the compiler's index instead), and it flags a package's own function
that shares a C name, so it's a starting point for reading, not a verdict. --files prints each
file's count of hits instead of the lines.
"""

import argparse
import os
import re
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common  # noqa: E402

FUNCS = '''errno strerror strerror_r perror open openat close read pread write pwrite lseek fsync ftruncate stat lstat fstat
fstatat mkdir rmdir unlink unlinkat rename renameat symlink readlink realpath getcwd chdir fchdir chmod fchmod chown access
umask utimes futimes utimensat opendir fdopendir readdir closedir rewinddir dirfd fopen fdopen fclose fwrite fread fputs
fprintf printf fflush ftell fseek fgets getline fileno setvbuf flockfile funlockfile popen pclose mkdtemp mkstemp mkstemps
mktemp tmpfile getenv setenv unsetenv putenv free malloc calloc realloc strdup strndup memcpy memmove memset memcmp bzero
strlen strcmp strncmp strcpy strncpy strchr strrchr strstr strtol strtoul strtoll strtoull strtod strtof atoi atol qsort
dup dup2 pipe socketpair kill killpg raise signal sigaction sigemptyset sigfillset sigaddset sigdelset sigprocmask
pthread_sigmask waitpid wait4 waitid fork vfork execv execvp execve execl execlp _exit exit atexit abort isatty ttyname
ioctl tcgetattr tcsetattr cfmakeraw openpty sysconf pathconf confstr sysctl sysctlbyname uname gethostname getpid
getppid getuid geteuid getgid getegid getpwuid getpwuid_r getpwnam getpwnam_r getlogin setsid setpgid getpgid usleep
nanosleep sleep clock_gettime gettimeofday time localtime localtime_r gmtime gmtime_r strftime mktime timegm dlopen dlsym
dlclose dlerror dladdr flock fcntl poll select kqueue kevent epoll_create epoll_ctl epoll_wait inotify_init
inotify_init1 inotify_add_watch inotify_rm_watch mmap munmap madvise getrusage getrlimit setrlimit sched_yield random
srandom rand getentropy copyfile clonefile fclonefileat statfs fstatfs getattrlist setxattr getxattr listxattr
removexattr fsetxattr fgetxattr syslog openlog socket bind listen accept connect send recv sendto recvfrom getaddrinfo
freeaddrinfo inet_pton inet_ntop htons ntohs htonl ntohl setlocale newlocale uselocale freelocale wcslen sin cos tan
sqrt pow exp log log2 log10 floor ceil round trunc fabs fmod lround isnan isinf posix_openpt grantpt unlockpt
ptsname mkfifo readpassphrase getpass'''.split()
NAMES = '''FILE DIR mode_t off_t pid_t uid_t gid_t dev_t ino_t nlink_t ssize_t size_t time_t clock_t useconds_t socklen_t
in_addr in6_addr timespec timeval tm rusage rlimit winsize termios utsname passwd dirent siginfo_t sigset_t fd_set pollfd
stdin stdout stderr __stdinp __stdoutp __stderrp environ PATH_MAX NAME_MAX MAXPATHLEN FD_CLOEXEC STDIN_FILENO
STDOUT_FILENO STDERR_FILENO TIOCGWINSZ R_OK W_OK X_OK F_OK INT_MAX UINT_MAX CHAR_BIT RAND_MAX DBL_MAX FLT_MAX M_PI
POSIXErrorCode Darwin TSCLibc EXIT_SUCCESS EXIT_FAILURE SEEK_SET SEEK_CUR SEEK_END errno'''.split()
PREFIXES = (r'(?:pthread_[a-z_]+|mach_[a-z_]+|task_[a-z_]+|os_unfair_lock[a-z_]*|posix_spawn[a-z_]*|fts_[a-z]+'
            r'|arc4random[a-z_]*|sockaddr[a-z_0-9]*|kevent[a-z0-9_]*|iconv[a-z_]*|S_I[A-Z]+|O_[A-Z]+|E[A-Z0-9]{2,}'
            r'|SIG[A-Z0-9]+|SIG_(?:DFL|IGN|ERR)|SA_[A-Z]+'
            r'|W(?:NOHANG|UNTRACED|EXITSTATUS|IFEXITED|IFSIGNALED|TERMSIG|IFSTOPPED|STOPSIG)|AT_[A-Z_]+|F_[A-Z_]+'
            r'|LOCK_(?:EX|SH|NB|UN)|RTLD_[A-Z]+|POSIX_SPAWN_[A-Z_]+|TCSA[A-Z]+|_SC_[A-Z_0-9]+|_PC_[A-Z_0-9]+'
            r'|CLOCK_[A-Z_]+|DT_[A-Z]+|IN_[A-Z_]+'
            r'|(?:AF|PF|SOCK|IPPROTO|INADDR|SOL|SO|MSG|TCP|IP|IPV6|EAI|NI|RUSAGE|RLIMIT|PRIO|MAP|PROT|MS|UF|SF|XATTR'
            r'|COPYFILE|CLONE|ATTR|VOL|KERN|CTL|HW|NOTE|EV|EVFILT|POLL|P|CLD|TIOC|FIO|PTHREAD|SEEK|MADV|MCL|TCI|TCO|VM'
            r'|MNT|FSOPT|DIR)_[A-Z0-9_]+'
            r'|_IO[NLF]BF|FD_(?:SET|ZERO|ISSET|CLR)|hostent|addrinfo|ifaddrs|getifaddrs|freeifaddrs|sig_atomic_t'
            r'|ucontext_t|uuid_t|in_port_t|sa_family_t)')
# Modules whose import brings Darwin's names: Darwin itself and modules that re-export it.
DARWINISH = {"Darwin", "TSCLibc", "MachO"}
FN = re.compile(r'(?<![\w.])(' + '|'.join(map(re.escape, FUNCS)) + r')\s*\(')
DECL = re.compile(r'\b(?:func|case|var|let)\s+$')
NAME = re.compile(r'(?<![\w.])(' + '|'.join(map(re.escape, NAMES)) + '|' + PREFIXES + r')(?![\w])')
MEMBER = re.compile(r'(?<=\.)(E[A-Z0-9]{3,}|SIG[A-Z]{3,})\b')
LOCAL = re.compile(r'\b(?:func|var|let|case)\s+`?(\w+)`?')
LABEL = re.compile(r'\b(\w+):(?!:)')      # argument labels and parameter names (not a ternary's ` : `)
DIRECTIVE = re.compile(r'\s*#(?:if|elseif)\b')


def files(args):
    for a in args:
        if os.path.isdir(a):
            for f in common.swift_files(a):
                yield os.path.join(a, f)
        elif os.path.isfile(a):
            yield a
        else:
            print(f"dgrep.py: {a}: no such file or directory", file=sys.stderr)


def hits_of(text, via, no_darwin, all_platforms=False):
    code = common.blank_swift(text)
    lines = code.split("\n")
    compiled = common.macos_lines(text) if not all_platforms else [True] * len(lines)
    imports = common.imports(text, code)
    modules = {im.module for im in imports}
    if via and not modules & via:
        return []
    if no_darwin and "Darwin" in modules:
        return []
    local = set(LOCAL.findall(code)) | set(LABEL.findall(code))
    import_lines = {im.line: im for im in imports}
    out = []
    for i, line in enumerate(lines):
        if DIRECTIVE.match(line) or not compiled[i]:
            continue            # `#if canImport(Darwin)` names a module; `#if os(Linux)` code isn't macOS's
        hits = []
        im = import_lines.get(i + 1)
        if im and im.module in DARWINISH:
            hits.append("import:" + im.module)
        for m in FN.finditer(line):
            if DECL.search(line[:m.start()]) or m.group(1) in local:
                continue
            hits.append(m.group(1))
        if not im:
            for m in NAME.finditer(line):
                if m.group(1) not in local:
                    hits.append(m.group(1))
            hits += ["." + m.group(1) for m in MEMBER.finditer(line)]
        if hits:
            out.append((i + 1, list(dict.fromkeys(hits))))
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("paths", nargs="+", metavar="PATH")
    ap.add_argument("--via", default="", help="only files that import one of these modules (comma-separated)")
    ap.add_argument("--no-darwin", action="store_true", help="only files that don't import Darwin")
    ap.add_argument("--files", action="store_true", help="print each file's number of hits instead of the lines")
    ap.add_argument("--all-platforms", action="store_true",
                    help="also lines in #if branches a macOS build doesn't compile (#if os(Linux))")
    a = ap.parse_args()
    via = {m for m in a.via.split(",") if m}
    total = 0
    for p in sorted(set(files(a.paths))):
        try:
            with open(p, encoding="utf-8", errors="replace") as h:
                raw = h.read()
        except OSError:
            continue
        found = hits_of(raw, via, a.no_darwin, a.all_platforms)
        if not found:
            continue
        total += 1
        if a.files:
            names = list(dict.fromkeys(n for _, hs in found for n in hs))
            print(f"{p}: {len(found)} lines: {' '.join(names)}")
            continue
        orig = raw.split("\n")
        for ln, hs in found:
            print(f"{p}:{ln}: [{','.join(hs)}] {orig[ln - 1].strip()[:160]}")
    if a.files:
        print(f"--- {total} files")


if __name__ == "__main__":
    main()
