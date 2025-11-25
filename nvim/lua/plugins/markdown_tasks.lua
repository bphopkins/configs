
-- lua/plugins/markdown_tasks.lua
return {
  -- We piggy-back on plenary just to have a plugin spec to attach keys to.
  "nvim-lua/plenary.nvim",
  ft = "markdown",
  keys = {
    -- (a) Toggle checkbox only
    {
      "<localleader>mt",
      function()
        require("config.markdown_tasks").toggle_checkbox()
      end,
      ft = "markdown",
      mode = "n",
      desc = "Toggle checkbox [-] [x]",
    },

    -- (b) Toggle @done(...)
    {
      "<localleader>md",
      function()
        require("config.markdown_tasks").toggle_done_tag()
      end,
      ft = "markdown",
      mode = "n",
      desc = "Toggle @done(...) tag",
    },

    -- (c) Toggle @started(...)
    {
      "<localleader>ms",
      function()
        require("config.markdown_tasks").toggle_started_tag()
      end,
      ft = "markdown",
      mode = "n",
      desc = "Toggle @started(...) tag",
    },

    -- (d) Combined checkbox + @done(...) (original behavior)
    {
      "<localleader>mD",
      function()
        require("config.markdown_tasks").toggle_checkbox_and_done()
      end,
      ft = "markdown",
      mode = "n",
      desc = "Toggle checkbox + @done(...)",
    },

    -- New: insert "- [ ] " at the cursor
    {
      "<localleader>mc",
      function()
        require("config.markdown_tasks").insert_checkbox_at_cursor()
      end,
      ft = "markdown",
      mode = "n",
      desc = "Insert '- [ ] ' at cursor",
    },

    -- New: smart <CR> in insert mode for checkbox lines
    {
      "<CR>",
      function()
        return require("config.markdown_tasks").checkbox_cr()
      end,
      ft = "markdown",
      mode = "i",
      expr = true, -- because we return a string of keys
      desc = "Smart newline for markdown checkboxes",
    },
  },
}
