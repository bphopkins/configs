return {
  "iamcco/markdown-preview.nvim",
  ft = { "markdown" },
  build = function()
    vim.fn["mkdp#util#install"]()
  end,
  init = function()
    vim.g.mkdp_auto_start = 0
    vim.g.mkdp_auto_close = 0
    vim.g.mkdp_refresh_slow = 0
    vim.g.mkdp_theme = "dark"
  end,
  keys = {
    {
      "<localleader>mp",
      "<cmd>MarkdownPreviewToggle<CR>",
      ft = "markdown",
      desc = "Toggle markdown-it preview",
    },
    {
      "<localleader>mh",
      function()
        require("config.pandoc").to_html()
      end,
      ft = "markdown",
      desc = "Pandoc → HTML",
    },
    {
      "<localleader>mP",
      function()
        require("config.pandoc").to_pdf()
      end,
      ft = "markdown",
      desc = "Pandoc → PDF",
    },
  },
}
