# CLAUDE.md — wofi package

Charter for `wofi/` (`config` + `style.css`), stowed to `~/.config/wofi`;
`$mod+a` runs `wofi --show drun`.

wofi is GTK3 — the same narrow CSS dialect as Waybar (no `ch` units, no
`font-variant-numeric`, `"tnum" 1` rejected) and the same parse-check before
trusting a change:

```bash
python3 -c 'import gi;gi.require_version("Gtk","3.0");from gi.repository import Gtk;Gtk.CssProvider().load_from_data(open("wofi/style.css","rb").read())'
```

Three behavioural keys matter more than the styling, each fixing a real
annoyance in bare wofi: **`matching=fuzzy` + `insensitive=true`** (the
default is a literal, case-*sensitive* substring match — `gimp` will not find
"GNU Image Manipulation Program" without this); **`no_actions=true`**
(per-app `.desktop` actions roughly triple the list); **`hide_scroll=true`**
(removes a gutter that otherwise shifts the text; keyboard scrolling
unaffected).

Styling deliberately matches Waybar — black, the forest-green `@accent` (not
sway's blue), Source Code Pro, and a 3px border echoing sway's
`default_border pixel 3`. No icons (`allow_images=false`; no icon font
installed); `image_size` is set anyway so enabling them is a one-word change.
Every key was validated against wofi(5)'s documented options; the CSS node
names (`#window`, `#input`, `#entry`, `#text`, …) come from its CSS SELECTORS
section — `tests/desktop/run.sh` re-validates both after edits.

wofi reads its config at launch, so there is nothing to reload — just run it
again.
