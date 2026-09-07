return {
  -- Configure the theme's variant BEFORE it is loaded
  {
    "folke/tokyonight.nvim",
    opts = {
      style = "night", -- <- pick the "night" variant
      on_highlights = function(hl, _)
-- Cursorline settled 2026-09-07.  The theme's #292e42 bar (1.27:1
        -- against the bg #1a1b26) distorted colour judgements of the LaTeX
        -- highlight scheme (2026-08-28); a 1.08:1 whisper replaced it, then
        -- darker-than-bg beat lighter, then no bar at all beat both.  The
        -- bar is off in config/options.lua; this value survives because it
        -- still paints the *unfocused* snacks picker list (list.lua:544)
        -- and is the settled value should the bar ever come back.
        -- Darker dials: #16161e (1.05:1), #0f1019 (1.12:1).
        hl.CursorLine = { bg = "#121320" }

        -- CursorLineNr is the surviving cue: with cursorlineopt = "number"
        -- it marks the current line without a bar.  The theme's bold
        -- #ff9e64 is 4.83:1 against LineNr (#3b4261) plus a hue shift —
        -- too poppy for a feature used deliberately, not scanned for.
        -- #737aa2 (dark5) is 2.35:1: a clear step out of the gutter family
        -- without leaving it.  Dials, all vs LineNr: #a9b1d6 (4.65:1, as
        -- findable as the orange but by brightness alone), #565f89
        -- (comment, 1.59:1), #545c7e (dark3, 1.50:1).
        hl.CursorLineNr = { fg = "#737aa2", bold = false }
      end,
    },
  },

  -- Tell LazyVim to use TokyoNight
  {
    "LazyVim/LazyVim",
    opts = { colorscheme = "tokyonight" },
  },

  -- LazyVim ships catppuccin as its alternative scheme; TokyoNight is locked
  -- in above and every LazyVim reference to catppuccin is optional=true, so
  -- disabling it just drops an unused install (2026-08-22).  The
  -- name="catppuccin" is load-bearing: LazyVim registers the plugin under
  -- that name, and without it this fragment would define (and disable) a
  -- different plugin called "nvim".  Delete the line to re-enable.
  { "catppuccin/nvim", name = "catppuccin", enabled = false },
}
