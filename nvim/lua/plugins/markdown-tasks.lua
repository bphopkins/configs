-- lua/plugins/markdown-tasks.lua
return {
  -- this isn't a real plugin; it's just here to register keymaps for markdown
  "nvim-lua/plenary.nvim", -- any always-present dependency is fine
  ft = "markdown",
  keys = {
    {
      "<localleader>ms",
      function()
        require("config.markdown-tasks").mark_started()
      end,
      ft = "markdown",
      desc = "Mark @started(...)",
    },
    {
      "<localleader>md",
      function()
        require("config.markdown-tasks").toggle_done()
      end,
      ft = "markdown",
      desc = "Toggle [ ]/[x] and @done(...)",
    },
  },
}
