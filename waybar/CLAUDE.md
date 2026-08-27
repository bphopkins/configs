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
- `"device": "intel_backlight"` is hardcoded — harmless, sway is fedxps-only.
- The urgent workspace and `#battery.critical` use `#d08770` — one of the
  four coupled urgent-colour sites (`sway/CLAUDE.md`).

Run `tests/desktop/run.sh` after any edit here.
