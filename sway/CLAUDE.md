# CLAUDE.md — sway package

Charter for `sway/` (stowed to `~/.config/sway`), and the coordinating
charter for the desktop suite — waybar, swaylock, mako, wofi each carry their
own small charter for what binds when their files are touched. Records:
`DECISIONS.md` items 5 and 6, and the entry of 2026-09-28.

**Sway runs on both machines:** fedxps, and bigfed on trial since 2026-09-28,
on its two monitors. One config serves both, so **before changing anything,
tell him what it does on fedxps**—he decides with that in hand (his standing
requirement, 2026-09-28). Lines keyed to a monitor's make, model and serial
apply only where that monitor is plugged in (a line naming an absent one is
ignored, tested); bindings and global settings – gaps, orientation, borders,
fonts – reach both, and a bigfed-only global would need a per-machine include
that does not exist yet. Either machine may be in GNOME or Sway: **check which
compositor is live before testing** (`pgrep -x gnome-shell` /
`pgrep -x sway`; `swaymsg` fails confusingly under GNOME). Most work here can
be done against `sway --validate` plus a headless nested sway (below)—
everything except what needs a real seat (locking, lid behaviour, cursor- and
notification-related work).

## The config

- **Binding grammar**: stated at the top of `config` itself, an explicit law
  since 2026-08-22—the modifier names what the action acts on (you / the
  focused window / the enclosures and the session / the workspaces as the
  monitors stand), with key-family overrides and a closed promotion list.
  Read it before adding a binding. Every motion is bound for both vim keys and
  arrows, deliberately. The tree tier returned 2026-09-28 on keys that follow
  upstream where upstream fits the grammar: `$mod+a`/`$mod+z` focus
  parent/child, `$mod+v` splitv as a toggle (`bin/sway-split`, with a
  marker in Waybar), `$mod+Ctrl+r` rotate. splith and
  tabbed/stacking stay unbound on purpose, and the declined alternatives are
  listed in `DECISIONS.md` 2026-09-28—don't re-propose them. The app menu is
  `$mod+d`, parting from GNOME's Super+A on purpose.
- **`README.md`** is a hand-maintained quick-reference card — a courtesy, not
  a contract: `config` is authoritative, the card may lag or be deleted at
  will, and the suite deliberately does not check the two against each other
  (drift check offered and declined 2026-08-22).
- **The two bars don't share an accent, on purpose**: sway's focused border
  is dodger blue (`$accent #0088FF`), Waybar's active workspace forest green.
  `$forest #228B22` sits unused in `config` so the old accent can be swapped
  back in one word — don't clean it up.
- **The split cue is white**: `client.focused`'s indicator, which sway paints
  on the edge where the next window will open while the focused window sits
  alone in its container—the bottom edge after `$mod+v`, the right edge after
  `$mod+Ctrl+r`. It matched the border until 2026-09-28, which hid the state;
  the unfocused classes keep indicators equal to their borders.
- **A sway session's PATH lacks `~/bin` and `~/.local/bin`**: GDM starts
  sway with no login shell, so `20-path.sh` never runs (measured
  2026-09-28). Bindings name homegrown scripts by path (`~/bin/…`); the gap
  itself is `TODO.md` item 29.
- **The move bindings start with `split none`**, so one press moves a window
  set with `$mod+v`, dropping its pending split; on any other window the
  prefix fails harmlessly and the move is unchanged (measured 2026-09-28).
  It looks redundant and is not.
- **One urgent colour across the desktop**: `#d08770` in four places and four
  config languages — sway `client.urgent`, Waybar's urgent workspace +
  `#battery.critical`, mako's `[urgency=critical]` border, swaylock's
  wrong-password ring. Deliberately not derived from one another; changing it
  means changing all four. The suite holds the wiring in place.
- **Waybar is launched as sway's bar** (`bar { swaybar_command waybar }`) —
  sway respawns it if it dies, and reload can't duplicate it. Price: sway's
  own bar settings in that block are **dead config** (Waybar ignores sway's
  bar protocol and reads its own files), so anything added there silently
  does nothing. `$mod+w` toggles the bar via `killall -SIGUSR1 waybar`, not
  sway's `mode hide`. Sway appends `-b bar-0`; Waybar ignores it (verified).

## Locking (swaylock + swayidle)

`config` ends with `exec swayidle -w before-sleep 'swaylock -f'` —
**before-sleep only, no `timeout` clause**, so it structurally cannot blank
or lock during work (idle timers and blanking are standing declines, recorded
with the other deliberate omissions in the config itself). It closes the
measured lid hole: suspend-then-reopen used to land on an unlocked desktop.
Facts that must survive edits:

- `-w` (swayidle) with `-f` (swaylock) is the pairing the man page
  prescribes, and both halves are load-bearing: the suspend inhibitor is held
  until the screen is actually locked (logind caps the wait at
  `InhibitDelayMaxSec`, 5 s here; swaylock comes up well inside it).
- **`exec`, not `exec_always`** — a reload must not spawn a second swayidle.
  Consequence: `swaymsg reload` does **not** start it; after editing,
  re-login or run it by hand for the current session.
- Lock on demand is `$mod+Ctrl+l` — `$mod+l` is `$right`.
- swaylock is invoked bare (`swaylock -f`) from **both** call sites, with
  everything cosmetic in `swaylock/config`, so the two cannot drift. The
  fail-open hazard lives in `swaylock/CLAUDE.md`.

## Verifying a change

**`sway --validate` does not check `bindsym` command bodies** — measured; a
typo there fails silently at runtime. Validate does cover everything else,
including stat-ing the `output bg` path. Close the gap:

- **One command**: `swaymsg -- '<cmd>'`, discriminating real errors from
  state complaints **after JSON-decoding** — the raw reply escapes the slash
  (`Unknown\/invalid command`), so a raw grep passes vacuously forever, and
  `parse_error: true` accompanies pure state failures too (`Scratchpad is
  empty` arrives with it set):

  ```bash
  swaymsg -- '<cmd>' | jq -r 'any(.[]?; (.error // "") | test("Unknown/invalid command"))'
  ```
- **The whole file**: a headless nested sway, which works from a GNOME
  session:

  ```bash
  WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1 SWAYSOCK=/tmp/sway-test.sock \
    sway -c /path/to/test.conf &
  SWAYSOCK=/tmp/sway-test.sock swaymsg -t get_tree     # then swaymsg exit
  ```

  ⚠ Strip three things from the test copy first: `include
  /etc/sway/config.d/*` (it runs a script that rewrites the **live**
  session's systemd/D-Bus environment), startup `exec` lines, and the
  **`bar {}` block** — a nested Waybar attached to a headless compositor once
  grew to 9.2 GB RSS and the OOM kill tore down the terminal's whole systemd
  scope. A test that starts a compositor starts everything that compositor's
  config starts; assert the copy contains no `swaybar_command` and that no
  processes leak (the suite does both).
- **swaynag buttons**: only `-z`/`-Z` dismiss; `-b`/`-B` run their action and
  leave the bar on screen — a working Cancel is `-s 'Cancel'` (renames the
  built-in dismiss). Prefer `-B` over `-b`, which routes through `$TERMINAL`
  when that variable is set.

**Regression suite:** `tests/desktop/run.sh` (24 checks, ~10 s) — validates
the config, rejects duplicate chords, checks every binary a binding names,
executes every non-exec binding command against a nested sway, parses both
GTK3 stylesheets and the Waybar JSON, validates every swaylock/mako/wofi key
against the installed man pages, and pins the cross-config wiring: the
`#d08770` urgent quad, the two identical `swaylock -f` call sites, the
timeout-less swayidle line, and agreement between the two `60-stow.sh`
arrays. Run it after editing **any** of the five desktop configs.
