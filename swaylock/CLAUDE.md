# CLAUDE.md — swaylock package

Charter for `swaylock/config`, stowed to `~/.config/swaylock`.

⚠ **An unrecognised key makes swaylock exit — which means *no lock at all***,
a fail-open direction that is easy to miss. Every key here was checked
against `man 1 swaylock` (54 documented long options); re-check after a
swaylock upgrade — `tests/desktop/run.sh` validates every key against the
installed man page, so it tracks the installed version rather than a
snapshot.

The package exists so the two call sites — the `$mod+Ctrl+l` binding and the
before-sleep hook, both in `sway/config` — can each be a bare `swaylock -f`,
with everything cosmetic here; inline flags would drift. The wrong-password
ring is `#d08770`, one of the four coupled urgent-colour sites
(`sway/CLAUDE.md`). PAM is already correct on Fedora (`/etc/pam.d/swaylock`
is `auth include login`; password unlock verified live). No clock on the lock
screen, deliberately: `--clock`/`--timestr`/`--datestr` belong to the
swaylock-effects fork, so a real clock means replacing the packaged binary —
`indicator-idle-visible` answers the actual question ("is the lock up, or is
the machine off?") without one. Username and session detail are deliberately
not displayed.
