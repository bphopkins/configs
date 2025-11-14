return {
  -- 0) blink.compat: lets blink.cmp use nvim-cmp sources (like cmp-vimtex)
  {
    "saghen/blink.compat",
    lazy = true,
    opts = {}, -- required so blink.compat runs its setup :contentReference[oaicite:0]{index=0}
    -- optional, but recommended if you want to pin:
    -- version = "2.*",
  },

  -- 1) VimTeX completion source (nvim-cmp style) that will be proxied via blink.compat
  {
    "micangl/cmp-vimtex",
    ft = { "tex", "plaintex", "latex" },
  },

  -- 2) blink.cmp: extend its config to turn on cmp-vimtex via compat
  {
    "saghen/blink.cmp",
    dependencies = {
      "saghen/blink.compat",
      "micangl/cmp-vimtex",
    },
    opts = function(_, opts)
      opts.sources = opts.sources or {}

      -- Tell blink to use LuaSnip as the snippet engine
      opts.snippets = opts.snippets or {}
      opts.snippets.preset = "luasnip"

      -- enable the compat source named "vimtex"
      -- opts.sources.compat = opts.sources.compat or {}
      -- if not vim.tbl_contains(opts.sources.compat, "vimtex") then
      --   table.insert(opts.sources.compat, "vimtex")
      -- end

      -- prefer vimtex (plus defaults) in TeX-ish filetypes
      opts.sources.per_filetype = opts.sources.per_filetype or {}
      local tex_sources = {
        inherit_defaults = false,
        "snippets",
        -- "path", -- testing off
        -- "vimtex", -- trying to offload onto LuaSnip
        -- "buffer", -- clutters with word recommendations
        -- "lsp", -- if I ever decide to use texlab
      }

      opts.sources.per_filetype.tex = tex_sources
      opts.sources.per_filetype.latex = tex_sources
      opts.sources.per_filetype.plaintex = tex_sources
      opts.sources.per_filetype.bib = tex_sources
      opts.sources.per_filetype.bibtex = tex_sources

      return opts
    end,
  },
}
