# CLAUDE.md — waybar package

Charter for `waybar/` (`config` JSON + `style.css`), stowed to
`~/.config/waybar`. Waybar runs as sway's bar — so **a CSS parse error
removes the whole bar**: Waybar exits with status 1 and sway does not bring it
back until `$mod+Ctrl+c`. The error is logged (`[error] style.css:51:32 Junk
at end of value …`) on Waybar's stdout, which the journal files under
`gdm-wayland-session`, not `waybar`: `journalctl --user -b _COMM=waybar` finds
it (corrected 2026-09-30). ⚠ **Parse-check before reloading** (needs no
display, no bar):

```bash
python3 -c 'import gi;gi.require_version("Gtk","3.0");from gi.repository import Gtk;Gtk.CssProvider().load_from_data(open("waybar/style.css","rb").read())'
```

Silence means it parses. Waybar is GTK3 and its CSS dialect is narrower than
the web's (measured): `font-feature-settings: "tnum"` accepted, the CSS-spec
`"tnum" 1` rejected ("Junk at end of value"), `font-variant-numeric` not a
property at all, and `min-width` takes px/em/rem but **rejects `ch`**. A width
in characters is a module option instead, `min-length` with `align`, in every
module's man page (waybar-battery(5) and the rest); nothing here uses one.

Conventions carrying the bar's behavior:

- **The bar is monospace** (Source Code Pro, matching the terminals; adopted
  2026-08-13 — the bar is almost entirely numbers, and aligning with the
  terminals is a more useful allegiance than with GTK apps). Reverting is
  deleting one `font-family` line — the `tnum` on `#clock` is kept redundant
  precisely so that revert is safe: tabular figures alone stopped the
  once-a-second clock jitter (proportional digits changed the string's width;
  `modules-center` turns width change into movement). The size is pinned at
  11 pt since 2026-09-30: unnamed, it followed GNOME's interface-font setting
  on each machine, and the bar's 24 px with it.
- **One box spaces the whole bar** (2026-09-30): the shared rule at the top of
  `style.css` – inset 2 px, padding 8 px, radius 4 px, GTK's button minimums
  zeroed, since Adwaita gives every button 16 px of content width and a
  one-digit workspace was 32 px wide rather than 25 – is applied to the
  workspace buttons, the split marker and, by position, every slot in
  `modules-right`, so a module added there gets it unnamed. The cells are 20 px
  apart between any two neighbours in both corners and 10 px from either edge
  of the screen; the ink inside measures 21-23 and 10-11 px, the glyphs' own
  bearings, by screenshotting the strip and clustering its ink columns
  (annotated 2026-09-30). One deliberate break in that rhythm (2026-10-01):
  a 16 px margin after the workspace buttons sets the state pills that follow
  them, the split marker and the binding mode, apart from the row.
  Values take their natural width: the fixed `{capacity:>3}` fields of
  2026-08-13 put blank 9 px cells inside the label, and the visible gaps swung
  with the digit count. A value crossing a digit boundary moves the modules to
  its left by one cell, once; the clock, centred as its own widget, stays. The
  tray's `spacing` is 20 for the same rhythm, and its icons are 14 px rather
  than the usual 16: beside 10 px digits a full-bleed icon stood 1.6 times
  their height, and at 14 the network glyph draws 9 px tall on the digits'
  baseline (measured). Adwaita's own `button:hover` shadows and 500 ms
  transition are zeroed in the sheet: they showed through on the filled
  pills (rendered 2026-09-30).
- **Tray order** (2026-09-30): Waybar is its own tray watcher, keeps its list
  newest-first, replays it at every style reload and appends live
  registrations at the right, so no option pins an item's place.
  `reverse-direction` puts the first registrant, nm-applet's Wi-Fi icon
  (started by `sway/config`), rightmost at login; after a SIGUSR2 reload the
  order flips until the next login. nm-applet turns its icon on by itself on
  any non-X11 display, so an icon-less applet is not a route. Record: the
  audit of 2026-09-30.
- **`"interval": 1` on the clock is load-bearing** whenever the format shows
  seconds — the default is 60, polling on the minute, which renders `%T`'s
  seconds as a permanently frozen `00`.
- **Low-battery notifications come from Waybar itself**, not a daemon: the
  battery module's `events` object (`on-discharging-warning` /
  `on-discharging-critical`) — the module was already polling, so there is no
  timer or background process to maintain. Critical fires at
  `urgency=critical`, which mako keeps on screen until dismissed. `{icon}` in
  any format requires a `format-icons` array — this bar is deliberately all
  plain text (no icon font installed), so `{icon}` was dropped rather than
  fed. **The charge state is a tint on the value** (2026-09-30): pale red on
  battery, pale green on the mains — Waybar's status classes `charging`,
  `discharging`, `full` and `plugged`, its own word for a battery holding at
  fedxps's 80 percent cap, where the old `+` mark vanished. The warning and
  critical colours apply while discharging only, as the notifications do. A
  reload (sway's or Waybar's SIGUSR2) re-fires the low-battery notification.
  Waybar 0.15.0 also prints the status word to stdout on every update, a
  debug leftover removed upstream after the release: about 120 journal lines
  an hour under `gdm-wayland-session`, nothing to fix here.
- **`sway/mode`** (2026-09-30): a `resize` pill in the urgent fill while
  `$mod+r`'s mode holds the keys, hidden otherwise; it learns the mode from
  mode events alone, so a Waybar started while a mode is on shows nothing
  until the next change. **`reload_style_on_change`** is inert here: Waybar
  resolves stow's relative symlink against its own cwd and watches a path that
  does not exist; keep SIGUSR2.
- `"device": "intel_backlight"` is hardcoded—harmless on bigfed, where the
  backlight and battery modules disable themselves at start (Waybar's log
  says so).
- **One bar on bigfed** (2026-09-28): `output` excludes the MSI by make,
  model and serial, so the bar sits on the Samsung alone and every other
  screen, fedxps's included, keeps its own. `all-outputs` lets the one bar
  list both monitors' workspaces, and `button.visible` marks the one showing
  on the other screen; on fedxps with a second screen attached, each bar then
  lists every workspace (accepted). Two bars cost something: the focused
  button's 3-px underline makes its bar 27 px tall and the other 24, so the
  bars traded heights whenever focus crossed monitors and every tiled window
  re-laid. The underline went 2026-09-29 – the focused button is filled
  instead, and a bar is 24 px whichever workspace is focused (measured on
  fedxps) – but the one bar stays.
- **The split marker** (`custom/split`, 2026-09-28; the keys `$mod+Shift+v`
  and `$mod+Shift+b` since 2026-09-29): `~/bin/sway-split watch` prints
  `↓ below` or `→ beside` while the focused window is set for the next one
  to open below or beside it, and nothing otherwise, which hides the module.
  It re-reads sway's tree on window, workspace, binding and tick events,
  titles filtered out, and the keys send the tick. It fills in the urgent
  colour, as the `resize` pill and sway's split edge do (2026-10-01; white
  before, matching the then-white edge): a pending split waits on you before
  you go on. The word joined the arrow the same day: a lone glyph in a box
  the size of a workspace button read as one more workspace. Waybar stops a
  continuous module by signalling the script alone (measured), so the
  script's trap stops its own event stream; without it, every reload left
  one behind. Suite: `tests/sway-split/run.sh`. Record: `DECISIONS.md`,
  2026-10-01.
- **The pointer marker** (`custom/pointer`, 2026-10-03): `~/bin/sway-pointer
  watch` prints `pointer off` while every pointing device is off after
  `$mod+m`, and nothing otherwise, which hides the module. It re-reads sway's
  device list at start and on every sway input event, so a Waybar started
  while off shows it and a reload, which turns the devices back on, clears
  it. First in `modules-right`: anchored there, the group grows into the
  empty middle when the marker appears and nothing already showing moves,
  the reason `sway/mode` is last on the left. The urgent fill, as the
  `resize` pill and the split marker: a state to leave. Same trap as
  sway-split's, for the same reason. Suite: `tests/sway-pointer/run.sh`.
  Record: `DECISIONS.md`, 2026-10-03.
- The urgent workspace, `#battery.critical`, the `resize` pill, the split
  marker and the pointer marker use `#d08770`; this sheet is one of the four
  coupled urgent-colour configs (`sway/CLAUDE.md`).
- **Seeing a change before it goes live** (2026-10-01): start Waybar
  yourself in a caged, headless nested sway (`sway/CLAUDE.md`, "The whole
  file", bar block stripped as it says), with a minimal config of its own:
  the left modules and the clock, no tray, a `custom/split` whose `exec`
  prints a fixed marker, and `-s` naming this `style.css`. Watch its RSS and
  stop it well short of the cage's 512M: the 9.2 GB nested Waybar of
  2026-08-13 ran the full config, spawned by the bar block, uncaged, and no
  cause is on record. Five starts this way, in three runs, peaked at
  56-59 MiB. Bars given as a JSON array stack down the output, one per
  variant, each bar's `name` a class on `window#waybar` for its overrides; a
  background one step off black per bar (`#000001`, `#000002`) is invisible
  and lets one `grim` capture be cut into strips.

Run `tests/desktop/run.sh` after any edit here (caged since 2026-09-30).
