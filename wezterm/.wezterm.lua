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

-- Finally, return the configuration to wezterm:
return config
