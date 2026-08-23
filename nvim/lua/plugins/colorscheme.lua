return {
  -- Configure the theme's variant BEFORE it is loaded
  {
    "folke/tokyonight.nvim",
    opts = { style = "night" }, -- <- pick the "night" variant
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
