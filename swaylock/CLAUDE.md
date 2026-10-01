# CLAUDE.md — swaylock package

Charter for `swaylock/config`, stowed to `~/.config/swaylock`.

⚠ **An unrecognised key ends the config file at that line.** swaylock 1.8.6
prints its usage to stderr (the session journal) and locks anyway, with every
later line ignored (`load_config` in `main.c` stops at the bad line and
returns 0; so every release since 1.4, read 2026-09-30 — the earlier "no lock
at all" was wrong). What the lock loses depends on where the line sits: above
`color=` the screen turns light grey, above the ring lines the ring turns
green, above `indicator-idle-visible` the ring hides until a key is pressed.
A flag with a trailing space is unrecognised too, and a colour of the wrong
length silently becomes opaque white. The one line that means no lock is
`version`, which exits. Every key here was checked against `man 1 swaylock`
(54 documented long options); re-check after a swaylock upgrade —
`tests/desktop/run.sh` validates every key, value and trailing space against
the installed man page, so it tracks the installed version rather than a
snapshot.

The package exists so the two call sites — the `$mod+Ctrl+l` binding and the
before-sleep and lock hooks, all in `sway/config` — can each be a bare
`swaylock -f`, with everything cosmetic here; inline flags would drift. The
wrong-password ring is `#d08770`, one of the four coupled urgent-colour sites
(`sway/CLAUDE.md`). PAM is already correct on Fedora (`/etc/pam.d/swaylock`
is `auth include login`; password unlock verified live; `pam_faildelay` 2 s,
no `pam_faillock`, so failed attempts cannot lock the account). No clock on
the lock screen, deliberately: `--clock`/`--timestr`/`--datestr` belong to
the swaylock-effects fork, so a real clock means replacing the packaged
binary — `indicator-idle-visible` answers the actual question ("is the lock
up, or is the machine off?") without one. Username and session detail are
deliberately not displayed. Since 2026-09-30: `ignore-empty-password` (an
empty Enter no longer costs 2 s and a failed attempt), `indicator-caps-lock`
(without it five of the six Caps Lock colours never applied), and "Cleared"
in white (it was black on black).

**Locked out: the way back.** If the lock screen turns **solid red**,
swaylock died while the session was locked and sway kept the lock (sway
`lock.c`, `handle_abandon`); nothing on screen will answer. On fedxps close
the lid, or press the sleep key, and open it again: the before-sleep
swaylock replaces the dead lock, and you unlock as usual. Otherwise switch
to a text console (Ctrl+Alt+F3), log in, and start a new locker, which sway
lets replace an abandoned lock; then return to the session's VT
(Ctrl+Alt+F2):

```bash
swaymsg -s "/run/user/$(id -u)/sway-ipc.$(id -u).$(pidof -s sway).sock" exec 'swaylock -f'
```

If the screen turns red again at once, the password checker itself cannot
start (PAM), and ending the session is the way out: the same `swaymsg -s …`
with `exit`. If a **correct password is refused**, unlock from the console
with `pkill -USR1 -x swaylock` (man 1 swaylock, SIGNALS). The same commands
work over SSH from the other machine, and `loginctl lock-session` from there
replaces a dead lock too (2026-09-30).
