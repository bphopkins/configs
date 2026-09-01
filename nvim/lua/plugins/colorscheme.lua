return {
  -- Configure the theme's variant BEFORE it is loaded
  {
    "folke/tokyonight.nvim",
    opts = {
      style = "night", -- <- pick the "night" variant
      on_highlights = function(hl, _)
        -- Subtle cursorline: the theme's #292e42 (1.27:1 against the bg)
        -- is loud enough to distort colour judgements of the LaTeX
        -- highlight scheme (2026-08-28).  1.08:1 is a whisper — present
        -- when sought, invisible when reading.  Dials: #212439 (1.12:1)
        -- for a bit more, #1d1e2c (1.04:1) for barely-there.
        hl.CursorLine = { bg = "#1f2132" }
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
