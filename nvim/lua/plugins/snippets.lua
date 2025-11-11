return {
  {
    "L3MON4D3/LuaSnip",
    opts = function(_, opts)
      local ls = require("luasnip")

      -- 1) VSCode-style snippets
      -- keep any bundled/friendly-snippets:
      require("luasnip.loaders.from_vscode").lazy_load()
      -- add your custom path (where tex.json is generated):
      require("luasnip.loaders.from_vscode").lazy_load({
        paths = { vim.fn.expand("~/.config/nvim/snippets") },
      })

      -- 2) Your Lua snippets (as you had)
      require("luasnip.loaders.from_lua").lazy_load({
        paths = vim.fn.stdpath("config") .. "/lua/snippets",
      })

      -- 3) Make 'latex' and 'plaintex' see 'tex' snippets
      ls.filetype_extend("latex", { "tex" })
      ls.filetype_extend("plaintex", { "tex" })

      -- (optional) enable autosnippets if you like
      -- ls.config.setup({ enable_autosnippets = true })
    end,
  },
}
