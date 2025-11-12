-- Pull in the wezterm API
local wezterm = require("wezterm")

-- This will hold the configuration.
local config = wezterm.config_builder()

-- This is where you actually apply your config choices.
config.initial_cols = 100
config.initial_rows = 40
config.enable_tab_bar = true
config.hide_tab_bar_if_only_one_tab = true
config.font_size = 12
config.font = wezterm.font("Source Code Pro")
config.color_scheme = "tokyonight_night" -- alts: tokyonight, tokyonight_night, tokyonight_storm, Wez

-- Finally, return the configuration to wezterm:
return config
