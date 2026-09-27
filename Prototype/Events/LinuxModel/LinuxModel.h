// A model of the C declarations that System's Linux event notification code
// calls, for Prototype/Events/check-linux.sh to typecheck that code on macOS.
// It declares only what the code uses. The function types follow glibc 2.35's
// <sys/epoll.h> and <sys/eventfd.h>, and CSystemLinux.h's timerfd shims. With MODEL_BIONIC, the
// pointers carry Bionic's nullability, which changes how Swift imports them.
// The constants aren't modeled: System spells out their values.

#include <stdint.h>
#include <signal.h>
#include <time.h>

#ifdef MODEL_BIONIC
#define MODEL_NONNULL _Nonnull
#define MODEL_NULLABLE _Nullable
#else
#define MODEL_NONNULL
#define MODEL_NULLABLE
#endif

typedef union epoll_data {
  void *ptr;
  int fd;
  uint32_t u32;
  uint64_t u64;
} epoll_data_t;

// Packed on x86_64 only, in glibc, musl, and Bionic.
struct epoll_event {
  uint32_t events;
  epoll_data_t data;
} __attribute__((__packed__));

int epoll_create1(int flags);
int epoll_ctl(int epfd, int op, int fd, struct epoll_event *event);
int epoll_wait(
  int epfd, struct epoll_event *MODEL_NONNULL events, int maxevents, int timeout);
int epoll_pwait(
  int epfd, struct epoll_event *MODEL_NONNULL events, int maxevents, int timeout,
  const sigset_t *MODEL_NULLABLE sigmask);

typedef uint64_t eventfd_t;
int eventfd(unsigned int count, int flags);

struct itimerspec {
  struct timespec it_interval;
  struct timespec it_value;
};

// CSystemLinux.h's timerfd shims, which take the itimerspec untyped.
int csystem_timerfd_create(int clockid, int flags);
int csystem_timerfd_settime(int fd, int flags, const void *new_value, void *old_value);
int csystem_timerfd_gettime(int fd, void *curr_value);
