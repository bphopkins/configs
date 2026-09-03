-- Pull in the wezterm API
local wezterm = require("wezterm")

-- This will hold the configuration.
local config = wezterm.config_builder()

-- Faces are pinned rather than inferred.
--
-- WezTerm picks a face for each (intensity, italic) pair. Left unstated, that
-- pick belongs to upstream, and upstream changed it: the 2026-08-29 nightly
-- began taking the *extreme* rung of the family, so Bold resolved to Black
-- (900) and Half to ExtraLight (200). Naming every face makes the choice ours,
-- and no future nightly can move it.
--
-- Source Code Pro ships ExtraLight 200, Light 300, Regular 400, Medium 500,
-- Semibold 600, Bold 700, Black 900 — there is no ExtraBold. To retune, edit
-- the three names below; `wezterm ls-fonts` prints what actually resolved.
--
-- Careful: these are WezTerm's weight names, not the font's face names, and they
-- disagree at 600 — the face is Semibold, the weight is "DemiBold". Passing
-- "Semibold" is a hard config error, which leaves the last good config running.
local FONT = "Source Code Pro"
local NORMAL = "Regular" -- 400
local BOLD = "Bold" -- 700; DemiBold 600 tried and reverted 2026-08-30, a close call
local DIM = "Light" -- 300; the nightly was handing out ExtraLight 200

local function face(weight, italic)
  return wezterm.font({ family = FONT, weight = weight, style = italic and "Italic" or "Normal" })
end

-- This is where you actually apply your config choices.
config.default_cwd = wezterm.home_dir .. "/Desktop"
config.initial_cols = 100
config.initial_rows = 40
config.enable_tab_bar = true
config.hide_tab_bar_if_only_one_tab = true
config.font_size = 12
config.font = face(NORMAL, false)
config.font_rules = {
  -- Every combination, so none is left to a default that can drift.
  { intensity = "Normal", italic = true, font = face(NORMAL, true) },
  { intensity = "Bold", italic = false, font = face(BOLD, false) },
  { intensity = "Bold", italic = true, font = face(BOLD, true) },
  { intensity = "Half", italic = false, font = face(DIM, false) },
  { intensity = "Half", italic = true, font = face(DIM, true) },
}
config.color_scheme = "tokyonight_night" -- alts: tokyonight, tokyonight_night, tokyonight_storm, Wez
-- Off deliberately: bold is a weight change and nothing else, which leaves colour
-- under manual control. True (the default) would also promote bold text to the
-- bright palette. Only affects the 8 base ANSI colours, not 256/truecolour.
config.bold_brightens_ansi_colors = false
config.check_for_updates = false -- RPM-managed; the built-in updater is noise
config.scrollback_lines = 20000 -- default is 3500; the tests/ suites overrun it

-- WezTerm delays escape-sequence processing to batch a TUI's redraw into one
-- frame, so that a program which never says where its frame ends does not tear.
-- The default is 3ms and it is charged to every reply: a CSI 6n round trip
-- costs 3588us with it and 137us without, measured 2026-09-03. That single
-- default was the whole of the 37x latency gap against Ghostty; the throughput
-- gap is separate and is real work. Full chain of evidence in
-- configs/docs/ghostty-vs-wezterm-2026-09-03.md.
--
-- Zero is safe here because the batching is a fallback for programs that do
-- not negotiate synchronized output (DEC mode 2026), and the ones that matter
-- do: nvim probes with `CSI ? 2026 $ p`, and WezTerm answers `;2` — supported.
-- A program that never asks loses the blanket and may flicker. If one ever
-- does, 1 is the middle setting; don't go straight back to 3.
--
-- Why the blanket exists at all: WezTerm reports TERM=xterm-256color, whose
-- terminfo carries no Sync capability, so anything that reads terminfo instead
-- of asking cannot discover synchronized output here. WezTerm's own `wezterm`
-- entry does carry it, but the Fedora RPM ships no terminfo at all, so
-- `config.term = "wezterm"` would name an entry this machine does not have.
config.mux_output_parser_coalesce_delay_ms = 0

-- The parser's read buffer. Swept 2026-09-03 on an otherwise idle machine, two
-- reps each, draining 200000 lines: 16K gave 1057ms, the default 970, 128K 946,
-- 1M 844, 4M 878. So the default sits near 128K, 1M is the floor, and 4M is
-- past it. 13% off the flood time for one line and a megabyte of RSS per pane.
-- It does not close the gap to Ghostty (still ~2x on sparse text, which is
-- compute), it just stops giving away the part that was configuration.
config.mux_output_parser_buffer_size = 1048576

-- Finally, return the configuration to wezterm:
return config
