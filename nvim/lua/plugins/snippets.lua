return {
  {
    "L3MON4D3/LuaSnip",
    opts = function(_, opts)
      local ls = require("luasnip")

      -- Load Lua snippets from ~/.config/nvim/lua/snippets
      require("luasnip.loaders.from_lua").lazy_load({
        paths = vim.fn.stdpath("config") .. "/lua/snippets",
      })

      -- Let latex/plaintex see tex snippets
      ls.filetype_extend("latex", { "tex" })
      ls.filetype_extend("plaintex", { "tex" })
    end,
  },
}
