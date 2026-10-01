# CLAUDE.md — wofi package

Charter for `wofi/` (`config` + `style.css`), stowed to `~/.config/wofi`;
the second launcher since 2026-09-30: `$mod+Shift+d` runs `wofi --show drun`
as a toggle — `pkill -x wofi || …`, so a second press closes the menu the
first opened (2026-09-29; before that each press opened another copy). It
was the menu on `$mod+d` until rofi took that key (`rofi/CLAUDE.md`); d for
drun; `$mod+a`, GNOME's app-grid key, until 2026-09-28. wofi has no
single-instance option of its own (`wofi --help`).

wofi is GTK3 — the same narrow CSS dialect as Waybar (no `ch` units, no
`font-variant-numeric`, `"tnum" 1` rejected) and the same parse-check before
trusting a change:

```bash
python3 -c 'import gi;gi.require_version("Gtk","3.0");from gi.repository import Gtk;Gtk.CssProvider().load_from_data(open("wofi/style.css","rb").read())'
```

Four behavioural keys matter more than the styling, each fixing a real
annoyance in bare wofi: **`matching=multi-contains` + `insensitive=true`**
(every space-separated word must appear, in any case; drun's search text
starts with the name, so the named app ranks first — `fuzzy`, a subsequence
over drun's metadata, ranked Neovim above Files for "files" and Enter ran it,
measured 2026-09-30; `gimp` still finds GIMP, since its executable is in the
text); **`sort_order=alphabetical`** (the default lists the most-launched
entries first, reordering with use; 2026-09-30); **`no_actions=true`**
(per-app `.desktop` actions roughly triple the list); **`hide_scroll=true`**
(removes a gutter that otherwise shifts the text; keyboard scrolling
unaffected). **`layer=overlay`** (2026-09-30) shows the menu over a fullscreen
window, where the default top layer drew it beneath one while still taking
the keyboard.

Styling deliberately matches Waybar — black, the desktop's one `@accent`,
sway's dodger blue since 2026-09-29 (forest green before, kept as `@forest`
for a one-word swap), Source Code Pro, and a 3px border echoing sway's
`default_border pixel 3`. No icons (`allow_images=false`; no icon font
installed); `image_size` is set anyway so enabling them is a one-word change.
Every key was validated against wofi(5)'s documented options; the CSS node
names (`#window`, `#input`, `#entry`, `#text`, …) come from wofi(5)'s CSS
SELECTORS section — `tests/desktop/run.sh` validates the keys and, since
2026-09-30, the `#id` selectors (GTK accepts any id, and a misspelt one
silently styles nothing).

wofi reads its config at launch, so there is nothing to reload — just run it
again.
