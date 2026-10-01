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
- **rofi's parser is silent**: an unknown option, a missing theme file and a
  theme syntax error all exit 0 with no message (measured 2026-09-30). So
  `tests/desktop/run.sh` checks every option in `config.rasi` against
  `rofi -dump-config`'s own list, and looks for the sheet's colour names in
  `rofi -dump-theme`'s output, which falls back to the built-in theme on any
  failure. Neither needs a display. Run the suite after edits.
- rofi reads its files at launch; nothing to reload. `disable-history` keeps
  the empty list A-Z, as wofi's is, instead of floating the most-launched
  entries to the top.
- Fedora 44's rofi 2.0.0 carries the Wayland backend merged upstream in
  2025-09; its release notes admit a redraw flicker at start and that a click
  outside may not close it. Neither seen yet; record it here if one shows.
