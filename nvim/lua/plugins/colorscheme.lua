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
}
