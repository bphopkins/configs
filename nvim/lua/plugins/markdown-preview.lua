return {
  "iamcco/markdown-preview.nvim",
  ft = { "markdown" }, -- load only for markdown files
  build = function()
    -- This installs the local npm dependencies for the plugin
    vim.fn["mkdp#util#install"]()
  end,
  init = function()
    -- Do NOT auto-start preview when you open a markdown file
    vim.g.mkdp_auto_start = 0

    -- Close the preview window when leaving the markdown buffer
    vim.g.mkdp_auto_close = 0

    -- Live-ish refresh (0 = update on TextChanged; 1 = only on save)
    vim.g.mkdp_refresh_slow = 0

    -- Use dark theme in browser by default
    vim.g.mkdp_theme = "dark"

    -- (Optional) If you want a specific browser:
    -- vim.g.mkdp_browser = "firefox"
  end,
  keys = {
    {
      "<localleader>mp",
      "<cmd>MarkdownPreviewToggle<CR>",
      ft = "markdown",
      desc = "Toggle Markdown Preview",
    },
  },
}
