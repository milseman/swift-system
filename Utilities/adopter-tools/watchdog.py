#!/usr/bin/env python3
"""Run a command with its output appended to a log, and stop it if it hangs.

Usage: watchdog.py LOG IDLE_SECONDS LIMIT_SECONDS COMMAND [ARGS...]

Runs COMMAND in a process group of its own, with stdout and stderr appended to LOG. If LOG gets
no new output for IDLE_SECONDS, or COMMAND runs longer than LIMIT_SECONDS, it sends SIGTERM to
that process group only, then SIGKILL 20 seconds later, and appends a line starting "WATCHDOG:"
that says why. When COMMAND ends, whatever it left running in its group (a build service, a test
helper) is killed too. Exits with COMMAND's status, or 124 when it was stopped, as timeout(1) does.

For test suites that hang as a whole, such as swift-build's: tests-by-target.sh runs each test
target (or suite) this way.
"""

import os
import signal
import subprocess
import sys
import time


def kill_group(pgid, sig):
    try:
        os.killpg(pgid, sig)
    except (ProcessLookupError, PermissionError):
        pass


def main():
    if len(sys.argv) < 5 or sys.argv[1] in ("-h", "--help"):
        sys.exit(__doc__)
    log, idle, limit, cmd = sys.argv[1], float(sys.argv[2]), float(sys.argv[3]), sys.argv[4:]
    with open(log, "ab", buffering=0) as out:
        try:
            p = subprocess.Popen(cmd, stdout=out, stderr=subprocess.STDOUT, start_new_session=True)
        except OSError as e:
            sys.exit(f"watchdog.py: {cmd[0]}: {e.strerror}")
        start = last = time.time()
        size = os.path.getsize(log)
        why = None
        while why is None:
            try:
                p.wait(timeout=5)
                break
            except subprocess.TimeoutExpired:
                pass
            now = time.time()
            s = os.path.getsize(log)
            if s != size:
                size, last = s, now
            if now - last > idle:
                why = f"no output for {int(now - last)} s"
            elif now - start > limit:
                why = f"ran over {int(limit)} s"
        if why:
            kill_group(p.pid, signal.SIGTERM)
            try:
                p.wait(timeout=20)
            except subprocess.TimeoutExpired:
                kill_group(p.pid, signal.SIGKILL)
                p.wait()
        # What outlived the command in its group (a build service) goes too.
        kill_group(p.pid, signal.SIGKILL)
        if why:
            out.write(f"\nWATCHDOG: stopped ({why})\n".encode())
            sys.exit(124)
    sys.exit(p.returncode if p.returncode >= 0 else 128 - p.returncode)


if __name__ == "__main__":
    main()
