return {
  -- Completion stack for LaTeX:
  --   - VimTeX builds semantic completion data (labels, cites, macros, etc.)
  --   - cmp-vimtex exposes that data as an nvim-cmp source named "vimtex"
  --   - blink.compat lets blink.cmp consume that nvim-cmp source
  --   - blink.cmp merges it with LuaSnip snippets, with snippets ranked higher

  -- 0) blink.compat: bridge between blink.cmp and nvim-cmp sources (like cmp-vimtex)
  {
    "saghen/blink.compat",
    lazy = true,
    opts = {}, -- required so blink.compat runs its setup and registers the compat provider
    -- optional, but recommended if you want to pin:
    -- version = "2.*",
  },

  -- 1) VimTeX completion source (nvim-cmp style) that will be proxied via blink.compat
  {
    "micangl/cmp-vimtex",
    ft = { "tex", "plaintex", "latex" }, -- load only where VimTeX is active
    -- Optional: explicit setup; not strictly required, but harmless and future‑proof.
    -- This plugin reads completion info that VimTeX exposes (controlled in vimtex.lua) and
    -- registers a nvim-cmp source called "vimtex".
    config = function()
      require("cmp_vimtex").setup({})
    end,
  },

  -- 2) blink.cmp: extend its config to integrate cmp-vimtex via blink.compat
  {
    "saghen/blink.cmp",
    dependencies = {
      "saghen/blink.compat", -- compat layer that knows how to call nvim-cmp sources
      "micangl/cmp-vimtex", -- provides the "vimtex" source that compat will wrap
    },
    opts = function(_, opts)
      -- Make sure nested tables exist so we can safely extend them, even if LazyVim
      -- (or another plugin) has not initialized these fields yet.
      opts.snippets = opts.snippets or {}
      opts.sources = opts.sources or {}
      opts.sources.providers = opts.sources.providers or {}
      opts.sources.per_filetype = opts.sources.per_filetype or {}

      ------------------------------------------------------------------
      -- Snippet engine: use LuaSnip
      --
      -- This tells blink.cmp to use LuaSnip as its snippet backend, so
      -- all your custom snippet domains (configured in snippets.lua)
      -- are available as completion items.
      ------------------------------------------------------------------
      opts.snippets.preset = "luasnip"

      ------------------------------------------------------------------
      -- VimTeX provider via blink.compat
      --
      -- This is the blink.cmp "provider" that proxies the nvim-cmp
      -- source called "vimtex" through blink.compat.
      -- The actual data still comes from VimTeX (configured in vimtex.lua),
      -- which cmp-vimtex reads and exposes.
      ------------------------------------------------------------------
      opts.sources.providers.vimtex =
        vim.tbl_deep_extend("force", opts.sources.providers.vimtex or {}, {
          -- IMPORTANT: this name must match the nvim-cmp source name
          -- (cmp-vimtex registers itself as { name = "vimtex" }).
          name = "vimtex",
          module = "blink.compat.source",

          -- Keep vimtex suggestions useful but below snippets.
          -- (Higher score_offset -> higher priority in the menu.)
          score_offset = 5,

          -- Only enable this provider in TeX-ish filetypes so it
          -- never runs in e.g. Lua/Markdown buffers.
          enabled = function()
            local ft = vim.bo.filetype
            return ft == "tex" or ft == "plaintex" or ft == "latex" or ft == "bib" or ft == "bibtex"
          end,
        })

      ------------------------------------------------------------------
      -- Snippets: bump priority so they beat vimtex (and other sources)
      --
      -- This keeps your own LuaSnip templates at the top of the menu, even
      -- when VimTeX could offer something with the same prefix.
      ------------------------------------------------------------------
      opts.sources.providers.snippets =
        vim.tbl_deep_extend("force", opts.sources.providers.snippets or {}, {
          -- Higher than vimtex (5) so snippet items float to the top.
          score_offset = 10,
        })

      ------------------------------------------------------------------
      -- Per-filetype source lists
      --
      -- For TeX-related filetypes we *disable* the global defaults and
      -- use only:
      --   - "snippets" (your LuaSnip stuff, tuned for TeX)
      --   - "vimtex"  (citations, refs, macros from VimTeX via cmp-vimtex)
      --   - "path"    (for \includegraphics, \input, etc.)
      --
      -- This keeps the completion menu focused and avoids generic buffer/LSP
      -- suggestions that tend to be noisy in large LaTeX projects.
      ------------------------------------------------------------------
      local tex_sources = {
        inherit_defaults = false,
        "snippets",
        "vimtex",
        "path",
      }

      -- Apply the same source set to all TeX-ish filetypes.
      opts.sources.per_filetype.tex = tex_sources
      opts.sources.per_filetype.latex = tex_sources
      opts.sources.per_filetype.plaintex = tex_sources
      opts.sources.per_filetype.bib = tex_sources
      opts.sources.per_filetype.bibtex = tex_sources

      return opts
    end,
  },
}
