// V16k: on Darwin, pthread_cond_timedwait_relative_np waits forever for a relative timeout whose tv_sec is negative, while a zero timeout times out at once (ETIMEDOUT, 60) and a negative tv_nsec is rejected (EINVAL, 22). An absolute pthread_cond_timedwait deadline in the past times out. Expected on macOS 26.3: "rz" and "r1" print 60, "rnn" prints 22, "an" prints 60, and "rn" is killed by the 3-second alarm (exit status 142). So PThread.Condition.wait(on:timeout:) clamps a negative Duration to zero.
// Run: swiftc V16k_darwin_relative_wait_negative.swift -o /tmp/V16k && for c in rz rn rnn an r1; do /tmp/V16k $c; echo "  exit $?"; done
import Darwin

setvbuf(stdout, nil, _IONBF, 0)
alarm(3)
var mutex = pthread_mutex_t(); pthread_mutex_init(&mutex, nil)
var condition = pthread_cond_t(); pthread_cond_init(&condition, nil)
pthread_mutex_lock(&mutex)
var ts: timespec
switch CommandLine.arguments.dropFirst().first ?? "" {
case "rz":
  ts = timespec(tv_sec: 0, tv_nsec: 0)
  print("relative zero:", pthread_cond_timedwait_relative_np(&condition, &mutex, &ts))
case "rn":
  ts = timespec(tv_sec: -1, tv_nsec: 0)
  print("relative negative:", pthread_cond_timedwait_relative_np(&condition, &mutex, &ts))
case "rnn":
  ts = timespec(tv_sec: 0, tv_nsec: -5)
  print("relative negative nsec:", pthread_cond_timedwait_relative_np(&condition, &mutex, &ts))
case "an":
  ts = timespec(tv_sec: -1, tv_nsec: 0)
  print("absolute negative:", pthread_cond_timedwait(&condition, &mutex, &ts))
case "r1":
  ts = timespec(tv_sec: 0, tv_nsec: 1)
  print("relative 1ns:", pthread_cond_timedwait_relative_np(&condition, &mutex, &ts))
default:
  print("usage: V16k rz|rn|rnn|an|r1")
}
