# CLAUDE.md — waybar package

Charter for `waybar/` (`config` JSON + `style.css`), stowed to
`~/.config/waybar`. Waybar runs as sway's bar — so **a CSS parse error
removes the whole bar**: Waybar exits, sway does not bring it back, and the
journal shows only `Using CSS file …` with no error line. ⚠ **Parse-check
before reloading** (needs no display, no bar):

```bash
python3 -c 'import gi;gi.require_version("Gtk","3.0");from gi.repository import Gtk;Gtk.CssProvider().load_from_data(open("waybar/style.css","rb").read())'
```

Silence means it parses. Waybar is GTK3 and its CSS dialect is narrower than
the web's (measured): `font-feature-settings: "tnum"` accepted, the CSS-spec
`"tnum" 1` rejected ("Junk at end of value"), `font-variant-numeric` not a
property at all, and `min-width` takes px/em/rem but **rejects `ch`** — which
is why fixed widths are done in format strings, not CSS.

Conventions carrying the bar's behavior:

- **The bar is monospace** (Source Code Pro, matching the terminals; adopted
  2026-08-13 — the bar is almost entirely numbers, and aligning with the
  terminals is a more useful allegiance than with GTK apps). Reverting is
  deleting one `font-family` line — the `tnum` on `#clock` is kept redundant
  precisely so that revert is safe: tabular figures alone stopped the
  once-a-second clock jitter (proportional digits changed the string's width;
  `modules-center` turns width change into movement).
- **Fixed-width slots via libfmt width specifiers**, not CSS min-width:
  `{capacity:>3}%` right-aligns into a constant field so a value changing
  digit count can't shove its neighbours (applied to pulseaudio, backlight,
  battery, 2026-08-13).
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
  fed.
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
  re-laid.
- **The `$mod+v` marker** (`custom/split`, 2026-09-28): `~/bin/sway-split
  watch` prints ↓ or → while the focused window is set for the next one to
  open below or beside it, and nothing otherwise, which hides the module. It
  re-reads sway's tree on window, workspace, binding and tick events, titles
  filtered out, and `$mod+v` sends the tick. Waybar stops a continuous module
  by signalling the script alone (measured), so the script's trap stops its
  own event stream; without it, every reload left one behind. Suite:
  `tests/sway-split/run.sh`.
- The urgent workspace and `#battery.critical` use `#d08770` — one of the
  four coupled urgent-colour sites (`sway/CLAUDE.md`).

Run `tests/desktop/run.sh` after any edit here.
