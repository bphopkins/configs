#!/usr/bin/env python3
"""Minimal `script(1)` replacement -- util-linux's script is not installed on
Fedora 44 here. Runs a command in a pty sized to the *current* terminal and
tees its output to a file.

The stdin forwarding is the point: nvim probes the terminal at startup with
DECRQM (`CSI ? 2026 $ p` and friends), and those probes have to reach the real
terminal and be answered, or the capture comes out without synchronized-output
framing and is not representative of a real session.

    ptytee.py CAPTURE_FILE COMMAND [ARGS...]
"""
import os, pty, sys, tty, termios, fcntl, struct, select

cap, cmd = sys.argv[1], sys.argv[2:]
cols, rows = os.get_terminal_size(0)
pid, fd = pty.fork()
if pid == 0:
    os.execvp(cmd[0], cmd)
# pty.fork() does not inherit the winsize; set it explicitly or the captured
# stream is laid out for an 80x24 grid and will not replay correctly.
fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack('HHHH', rows, cols, 0, 0))
out = open(cap, 'wb')
old = termios.tcgetattr(0)
tty.setraw(0)
try:
    while True:
        r, _, _ = select.select([0, fd], [], [])
        if 0 in r:
            d = os.read(0, 1024)
            if d:
                os.write(fd, d)
        if fd in r:
            try:
                d = os.read(fd, 65536)
            except OSError:
                break
            if not d:
                break
            out.write(d); out.flush()   # so a killed run still leaves its capture
            os.write(1, d)
finally:
    termios.tcsetattr(0, termios.TCSAFLUSH, old)
    out.close()
os.waitpid(pid, 0)
