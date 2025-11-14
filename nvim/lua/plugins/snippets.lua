return {
  {
    "L3MON4D3/LuaSnip",
    opts = function(_, opts)
      local ls = require("luasnip")

      -- Load all Lua snippet modules from ~/.config/nvim/lua/snippets
      require("luasnip.loaders.from_lua").lazy_load({
        paths = vim.fn.stdpath("config") .. "/lua/snippets",
      })

      -- Each file in lua/snippets is treated as its own "filetype":
      --   french-logic.lua    -> "french-logic"
      --   latex-workshop.lua  -> "latex-workshop"
      --
      -- Make those snippet-sets visible when editing TeX / LaTeX.
      ls.filetype_extend("tex", { "latex-workshop", "french-logic" })

      -- Typical LaTeX setup: latex/plaintex share the tex snippets.
      ls.filetype_extend("latex", { "tex" })
      ls.filetype_extend("plaintex", { "tex" })

      return opts
    end,
  },
}
