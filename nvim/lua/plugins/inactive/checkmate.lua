return {
  "bngarren/checkmate.nvim",
  ft = "markdown",
  opts = {
    -- Activate on any markdown file (so README.md, notes.md, etc.)
    files = { "*.md" },

    -- Show plain [ ] / [x] in the editor instead of □ / ✔
    todo_states = {
      unchecked = {
        marker = "[ ]",
        order = 1,
      },
      checked = {
        marker = "[x]",
        order = 2,
      },
    },

    -- Optional: customize metadata date format and keymaps
    use_metadata_keymaps = true,
    metadata = {
      started = {
        -- When you add @started, use ISO-ish date/time
        get_value = function()
          return os.date("%Y-%m-%d %H:%M")
        end,
        key = "<leader>ms", -- your "mark started" key
      },
      done = {
        get_value = function()
          return os.date("%Y-%m-%d %H:%M")
        end,
        key = "<leader>md", -- your "mark done" key
        on_add = function(todo)
          require("checkmate").set_todo_state(todo, "checked")
        end,
        on_remove = function(todo)
          require("checkmate").set_todo_state(todo, "unchecked")
        end,
      },
    },
  },
}
