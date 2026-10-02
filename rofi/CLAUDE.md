# CLAUDE.md — rofi package

Charter for `rofi/` (`config.rasi` + `theme.rasi`), stowed to `~/.config/rofi`;
the app menu since 2026-09-30 (`$mod+d`, a toggle: `pkill -x rofi || rofi
-show drun`), chosen over wofi after one use for what it can grow into — a
window switcher, an ssh mode, `-dmenu` for scripts — none of it bound yet.
wofi stays on `$mod+Shift+d` as the second launcher, in the same palette.

- **`theme.rasi` is the whole sheet**: `@theme "theme"` in `config.rasi`
  discards rofi's built-in theme first. A partial sheet laid over the
  built-in one bled through as cream rows, striped lines and a dashed rule,
  since its per-widget colours outrank a `*` rule (rendered 2026-09-30). So
  every widget rofi draws is named there, and a change is judged by
  rendering: a caged nested sway, rofi started on its display, `grim`, the
  image read back — the recipe in `sway/CLAUDE.md`, "Verifying a change".
  A probe rofi takes its own `-pid`: the default pid file is the live
  menu's, and rofi exits while another copy holds its lock (2026-10-01).
- **rofi's parser is silent**: an unknown option, a missing theme file and a
  theme syntax error all exit 0 with no message (measured 2026-09-30). So
  `tests/desktop/run.sh` checks every option in `config.rasi` against
  `rofi -dump-config`'s own list, and looks for the sheet's colour names in
  `rofi -dump-theme`'s output, which falls back to the built-in theme on any
  failure. Neither needs a display. Run the suite after edits.
- rofi reads its files at launch; nothing to reload. `disable-history` keeps
  the empty list A-Z, as wofi's is, instead of floating the most-launched
  entries to the top.
- **`sort: true` with `sorting-method: "fzf"` is what ranks a query**
  (2026-10-01). rofi's sort is off by default, and a query then only
  filters, keeping the empty list's A-Z order: "system" kept 18 entries,
  most through a `System` category, with System Monitor 15th, off screen,
  and Alacritty under Enter. fzf scores the name, so the app named by the
  query leads; levenshtein, the default method, favours short names. Only
  a typed query is sorted, so the empty list stays A-Z. The suite pins
  both lines. `matching: "fuzzy"` is on trial from the same day, his
  choice; `"normal"` (whole words) is the one-word way back if it
  misleads, and its first known stray is "pdf", which ranks Rygel
  Preferences above Document Viewer. Record: `DECISIONS.md`, 2026-10-01.
- Fedora 44's rofi 2.0.0 carries the Wayland backend merged upstream in
  2025-09; its release notes admit a redraw flicker at start and that a click
  outside may not close it. Neither seen yet; record it here if one shows.
