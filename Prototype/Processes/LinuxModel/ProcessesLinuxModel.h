// A model of the C declarations that System's Linux-only process and signal
// code uses and Darwin lacks, for Prototype/Processes/check-linux.sh to
// typecheck that code on macOS: the CSystem shims that CSystemLinux.h
// declares under __linux__, SIGPWR, and _NSIG. It declares only what the
// code uses, with the types that CSystemLinux.h and glibc 2.35 give them.

#define SIGPWR 30

// Linux's C libraries declare _NSIG, and System uses theirs on Linux.
#define _NSIG 65

extern int csystem_pidfd_open(int pid, unsigned int flags);
extern int csystem_pidfd_send_signal(int pidfd, int sig, void *info, unsigned int flags);
extern int csystem_close_range(unsigned int first, unsigned int last, unsigned int flags);
extern int csystem_signalfd(int fd, const void *mask, int flags);

struct csystem_signalfd_siginfo {
  unsigned int ssi_signo;
  int ssi_errno;
  int ssi_code;
  unsigned int ssi_pid;
  unsigned int ssi_uid;
  int ssi_fd;
  unsigned int ssi_tid;
  unsigned int ssi_band;
  unsigned int ssi_overrun;
  unsigned int ssi_trapno;
  int ssi_status;
  int ssi_int;
  unsigned long long ssi_ptr;
  unsigned long long ssi_utime;
  unsigned long long ssi_stime;
  unsigned long long ssi_addr;
  unsigned short ssi_addr_lsb;
  unsigned short __pad2;
  int ssi_syscall;
  unsigned long long ssi_call_addr;
  unsigned int ssi_arch;
  unsigned char __pad[28];
};
