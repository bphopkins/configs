# CLAUDE.md — sway package

Charter for `sway/` (stowed to `~/.config/sway`), and the coordinating
charter for the desktop suite — waybar, swaylock, mako, wofi, rofi each carry
their own small charter for what binds when their files are touched. Records:
`DECISIONS.md` items 5 and 6, the entries of 2026-09-28 and 2026-09-29, and
the audit of 2026-09-30.

**Sway runs on both machines:** fedxps, and bigfed on trial since 2026-09-28,
on its two monitors. One config serves both, so **before changing anything,
tell him what it does on fedxps**—he decides with that in hand (his standing
requirement, 2026-09-28). Lines keyed to a monitor's make, model and serial
apply only where that monitor is plugged in (a line naming an absent one is
ignored, at start and at reload, tested); bindings and global settings – gaps,
orientation, borders, fonts – reach both; a global one machine alone should
have goes in that machine's layer, `hosts/<hostname>.conf`, included after
every setting (silent when missing; the suite checks this machine's is linked
and validates each layer inlined, since `sway --validate` passes an error
inside an include; 2026-09-30). Either machine may be in GNOME or Sway:
**check which compositor is live before testing** (`pgrep -x gnome-shell` /
`pgrep -x sway`; `swaymsg` fails confusingly under GNOME). Most work here can
be done against `sway --validate` plus a headless nested sway (below)—
everything except what needs a real seat (locking, lid behaviour, cursor- and
notification-related work).

## Per-machine setup, once

- `stow-all` after the pull that brings `hosts/` (2026-09-30); on the machine
  that created it nothing prompts this, so run it in the same sitting.
- Default apps: `ln -s /usr/share/applications/gnome-mimeapps.list
  ~/.local/share/applications/sway-mimeapps.list`. GNOME's system list applies
  only where the desktop name says GNOME; without the link, under sway,
  images opened in Brave or GIMP and fonts in FontForge (34 of 237 defaults
  differed, measured 2026-09-30). `~/.config/mimeapps.list` still wins. Done
  on both machines 2026-09-30.
- The session file: `sudo install -D -m 0644
  ~/Desktop/configs/sway/wayland-session.desktop
  /usr/local/share/wayland-sessions/sway.desktop`, so GDM starts sway from a
  login shell and the session inherits the personal PATH (`TODO.md` item 29;
  the file's header has the reasoning and the undo). Installed on fedxps
  2026-09-30, to take effect at its next login; bigfed pending.

## The config

- **Binding grammar**: stated at the top of `config` itself, an explicit law
  since 2026-08-22—the modifier names what the action acts on (you / the
  focused window / the enclosures and the session / the workspaces as the
  monitors stand), with key-family overrides (Escape, Print, XF86, and since
  2026-09-30 the mouse), a closed promotion list and, since 2026-09-29, a
  clause lending Shift to a second launcher on a letter. Read it before
  adding a binding. Every motion is bound for both vim keys and arrows,
  deliberately. **One-shot bindings carry `--no-repeat`** (2026-09-30): a held
  key re-runs its binding at the repeat rate, and a held `$mod+q` closed
  window after window; the rule under `### Key bindings` says which repeat.
  The tree tier returned 2026-09-28 on keys that follow upstream where
  upstream fits the grammar: `$mod+a`/`$mod+z` focus parent/child (focus
  motions, so bare-tier whatever their frequency, settled 2026-09-29),
  `$mod+Ctrl+r` rotate. The shaping verbs sit on the Shift tier since
  2026-09-29, as window verbs: `$mod+Shift+v` below and `$mod+Shift+b`
  beside, each a toggle (`bin/sway-split`, with a marker in Waybar),
  `$mod+Shift+s` tabs. The terminal is `$mod+Return` alone; `v`, `s` and `t`
  are free on the bare tier; `$mod+n` clears a notification (2026-09-30).
  Stacking stays unbound on purpose, and the declined alternatives are
  listed in `DECISIONS.md` 2026-09-28 and 2026-09-29—don't re-propose them.
  The app menu is `$mod+d`, a toggle, parting from GNOME's Super+A on
  purpose: rofi since 2026-09-30 (`rofi/`), with wofi behind it on
  `$mod+Shift+d`. `$mod+q` closes only a window: with a column, fold or workspace
  selected it does nothing (a guard, 2026-09-30). `$mod+r` toggles the
  resize mode in and out, and Waybar shows `resize` while it holds the keys.
- **`README.md`** is a hand-maintained quick-reference card — a courtesy, not
  a contract: `config` is authoritative, the card may lag or be deleted at
  will, and the suite deliberately does not check the two against each other
  (drift check offered and declined 2026-08-22).
- **One accent across the desktop** (2026-09-29): sway's `$accent #0088FF`
  is Waybar's, wofi's, rofi's, mako's border and swaylock's ring too (mako
  and swaylock blue since 2026-08-13, rofi since 2026-09-30), meaning where
  you are or what is selected; the suite pins all six sites (2026-09-30).
  `#d08770` keeps meaning needs-you. `$forest #228B22` sits unused in
  `config`, and `@forest` in the three launcher and bar sheets, so the old
  green can be swapped back in one word — don't clean them up; mako and
  swaylock would need the same swap by hand. The bar's split marker is white,
  as sway's edge cue for the same state is.
- **The split cue is white**: `client.focused`'s indicator, which sway paints
  on the edge where the next window will open while the focused window sits
  alone in its container—the bottom edge after `$mod+Shift+v`, the right
  edge after `$mod+Shift+b` or `$mod+Ctrl+r`. It matched the border until
  2026-09-28, which hid the state; the unfocused classes keep indicators
  equal to their borders. Borders are 2 px, stated so since 2026-09-30 (a
  trailing comment had voided the configured 3 since the first commit, and
  he kept the 2 he had looked at).
- **A fold's strip is the only title bar here**: `font` and the background
  and text fields of `client.*` draw nowhere else, so a change to them shows
  only inside tabs and stacks. Preview one as the 2026-09-29 entry did – a
  headless nested sway with the palette lines copied in, `grim` run inside
  it, the strip cropped and looked at – before it reaches the live config.
  A fold made on a window sitting straight on the workspace forgets the
  split it came from (a column unfolds as a row; one `$mod+Ctrl+r` restores
  it), accepted 2026-09-30.
- **A sway session's PATH lacks `~/bin` and `~/.local/bin`** until the session
  file above is installed: GDM starts sway with no login shell, so
  `20-path.sh` never runs (measured on bigfed 2026-09-28 and on fedxps
  2026-09-29). Bindings name homegrown scripts by path (`~/bin/…`) and keep
  doing so; the gap itself is `TODO.md` item 29.
- **The move bindings start with `split none`**, so one press moves a window
  set with `$mod+Shift+v` or `b`, dropping its pending split; on any other
  window the prefix fails harmlessly and the move is unchanged (measured
  2026-09-28). It looks redundant and is not.
- **One urgent colour across the desktop**: `#d08770` in four configs and four
  config languages — sway `client.urgent` (border and, since 2026-09-30, an
  urgent tab's fill), Waybar's urgent workspace, `#battery.critical` and the
  `resize` mode pill, mako's `[urgency=critical]` border, swaylock's
  wrong-password ring. Deliberately not derived from one another; changing it
  means changing all four. The suite pins the drawn keys.
- **Waybar is launched as sway's bar** (`bar { swaybar_command waybar }`) — a
  reload replaces it rather than duplicating it, but sway does not restart
  it if it dies: a Waybar that exits stays gone until `$mod+Ctrl+c` (sway
  1.11 `sway/config/bar.c`, 2026-09-30). The command is exec'd without a
  shell, so it takes no arguments. Price: sway's own bar settings in that
  block are **dead config** (Waybar reads its own files and, with its `ipc`
  option off, ignores the bar protocol), so anything added there silently
  does nothing. `$mod+w` toggles the bar via `killall -SIGUSR1 waybar`, not
  sway's `mode hide`. Sway appends `-b bar-0`; Waybar ignores it.

## Locking and power (swaylock + swayidle + logind)

`config`'s startup block carries `exec swayidle -w before-sleep 'swaylock -f'
lock 'swaylock -f'` — **before-sleep and logind's Lock signal only, no
`timeout` clause**, so it structurally cannot blank or lock during work (idle
timers and blanking are standing declines on both machines, recorded with the
other deliberate omissions in the config itself; bigfed's posture confirmed
2026-09-30). It closes the measured lid hole: suspend-then-reopen used to land
on an unlocked desktop. Facts that must survive edits:

- `-w` (swayidle) with `-f` (swaylock) is the pairing the man page
  prescribes, and both halves are load-bearing: the suspend inhibitor is held
  until the screen is actually locked (logind caps the wait at
  `InhibitDelayMaxSec`, 5 s here; swaylock comes up in about 0.2 s).
- **`exec`, not `exec_always`** — a reload must not spawn a second swayidle.
  Consequence: `swaymsg reload` does **not** start it; after editing,
  re-login or run it by hand for the current session.
- **swayidle is the lid's only lock, and nothing restarts it.** It exits on
  its own if its D-Bus connection drops, and a lid close then suspends at
  once, unlocked. Gauge: `systemd-inhibit --list` names swayidle (sleep,
  delay). Restore: `swaymsg exec "swayidle -w before-sleep 'swaylock -f' lock
  'swaylock -f'"`. A systemd unit was studied and declined 2026-09-30: with
  the default KillMode a restart while locked kills the running swaylock and
  turns the lock screen solid red.
- **The power button opens the machine nag**, the same one as
  `$mod+Shift+Escape`. `config` holds logind's handle-power-key inhibitor
  for exactly the session's life (`systemd-inhibit … swaymsg -t subscribe
  '["shutdown"]'`); before 2026-09-30 one press powered either machine off,
  since only gnome-settings-daemon had held it. logind honours the lock only
  while this session is the active one. Gauge: `systemd-inhibit --list`
  names sway (handle-power-key, block).
- Lock on demand is `$mod+Ctrl+l` — `$mod+l` is `$right`. GNOME's lock on
  fedxps answers to `Super+Ctrl+l` as well since 2026-09-30, so the one habit
  locks in both desktops (`Super+l` in GNOME still locks too).
- swaylock is invoked bare (`swaylock -f`) from **every** call site, with
  everything cosmetic in `swaylock/config`, so they cannot drift. The
  unknown-key hazard (a truncated look, not a missing lock) and the way back
  from a lockout live in `swaylock/CLAUDE.md`.

## When a piece goes missing

sway starts each of these once and restarts none of them. Restores run from
any terminal in the session; `swaymsg exec` makes the process sway's child
again, in the session's scope and environment, where a plain `&` would tie it
to that terminal (2026-09-30).

| gone | costs | shows as | restore |
|---|---|---|---|
| Waybar, split marker | clock, battery, workspaces | no bar; `$mod+w` does nothing | `$mod+Ctrl+c` |
| swaybg | the wallpaper (seen only on an empty workspace) | black there | `$mod+Ctrl+c` |
| swayidle | the lock before suspend: a shut lid reopens unlocked | no swayidle line in `systemd-inhibit --list` | `swaymsg exec "swayidle -w before-sleep 'swaylock -f' lock 'swaylock -f'"` |
| the power-key holder | the button powers off at a press | no sway line in `systemd-inhibit --list` | `swaymsg exec "systemd-inhibit --what=handle-power-key --mode=block --who=sway --why=powerkey swaymsg -t subscribe '[\"shutdown\"]'"` |
| nm-applet | the Wi-Fi icon, and the agent the 802.1x network's password comes from | the icon leaves the tray | `swaymsg exec 'nm-applet --indicator'` |
| assign-cgroups.py | new apps' own scopes | nothing | `swaymsg exec /usr/libexec/sway-systemd/assign-cgroups.py` |
| mako | notifications then on screen | nothing | none: the next notification starts it (D-Bus) |
| swaylock, while locked | nothing: the session stays locked | a solid red screen | `swaylock/CLAUDE.md`, "Locked out" |

`$mod+Ctrl+c` restarts Waybar and swaybg even when they are running, turns a
touchpad disabled with `$mod+m` back on, and re-fires the low-battery
notification below 20 percent.

## Verifying a change

**`sway --validate` does not check `bindsym` command bodies** — measured; a
typo there fails silently at runtime — **and passes an error inside an included
file** (2026-09-30). Validate does cover everything else, including stat-ing
the `output bg` path. **A reload does not refuse a config with errors**
(measured 2026-09-30): it skips each line it cannot parse, applies the rest,
and raises sway's own red nag, whose *Exit sway* button ends the session at
one click; only an unreadable file is refused. So validate first, and close
the body gap:

- **One command**: `swaymsg -- '<cmd>'`, discriminating real errors from
  state complaints **after JSON-decoding** — the raw reply escapes the slash
  (`Unknown\/invalid command`), so a raw grep passes vacuously forever, and
  `parse_error: true` accompanies pure state failures too (`Scratchpad is
  empty` arrives with it set). Sway rewrites a body before sh sees it (the
  header's Caution paragraph): a body with a backslash behaves differently
  through swaymsg than from a key.

  ```bash
  swaymsg -- '<cmd>' | jq -r 'any(.[]?; (.error // "") | test("Unknown/invalid command"))'
  ```
- **The whole file**: a headless nested sway, in a cage, on a short socket —
  the pattern of `tests/sway-split/run.sh`. From a GNOME session too:

  ```bash
  cd <workdir>   # a short path: sway and swaymsg truncate SWAYSOCK at 107 bytes
  export SWAYSOCK=s.sock
  systemd-run --user --scope --collect -p MemoryMax=512M -p MemorySwapMax=0 -p TasksMax=256 -p RuntimeMaxSec=120 -p OOMPolicy=continue -- \
    env WLR_BACKENDS=headless WLR_HEADLESS_OUTPUTS=1 WLR_LIBINPUT_NO_DEVICES=1 WLR_RENDERER=pixman sway -c test.conf &
  swaymsg -t get_version | jq -r .loaded_config_file_name   # must print test.conf's path
  swaymsg -t get_tree                                        # then swaymsg exit
  ```

  ⚠ Strip six things from the test copy first: every `exec` and
  `exec_always` line, every `include` but the relative `hosts/` one (`/etc`'s
  runs a script that rewrites the **live** session's systemd/D-Bus
  environment; the power-key line would take a real system-wide inhibitor),
  the **`bar {}` block** — a nested Waybar attached to a headless compositor
  once grew to 9.2 GB RSS and the OOM kill tore down the terminal's whole
  systemd scope — and prepend `swaynag_command -`, `swaybg_command -` and
  `xwayland disable`, or the copy's `output * bg` line starts a real swaybg
  (with an image-loader sandbox) and any X client an Xwayland. A test that
  starts a compositor starts everything that compositor's config starts. A
  long SWAYSOCK is silently truncated and two nested sways then share one
  socket and answer each other's commands (measured 2026-09-30): keep it
  short, and check `loaded_config_file_name` before trusting a reply.
- **swaynag buttons**: only `-z`/`-Z` dismiss; `-b`/`-B` run their action and
  leave the bar on screen — a working Cancel is `-s 'Cancel'` (renames the
  built-in dismiss). Prefer `-B` over `-b`, which routes through `$TERMINAL`
  when that variable is set.

**Regression suite:** `tests/desktop/run.sh` (caged since 2026-09-30; its
header counts its checks, 51 today; about 4 s) — validates the config and each
machine layer inlined, rejects duplicate chords mode-aware and with sorted
modifiers, checks every binary a binding names (inside `sh -c` bodies too),
executes every non-exec binding command against a nested sway and fails if
that sway stops answering, parses both GTK3 stylesheets and the Waybar JSON,
runs mako's own parser, validates every swaylock/mako/wofi key and wofi's
selectors against the installed man pages, and pins the cross-config wiring at
the keys that draw it: the `#d08770` urgent sites, the `#0088FF` accent in
all five files, the exact swayidle line, the bare `swaylock -f` call sites,
the MSI identifier in both configs, and agreement between the two
`60-stow.sh` arrays, and rofi's options and theme against rofi's own
dumps, since its parser is silent. Run it after editing **any** of the six
desktop configs or a machine layer.
