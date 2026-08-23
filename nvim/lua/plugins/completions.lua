return {
  -- Completion stack for LaTeX:
  --   - VimTeX builds semantic completion data (labels, cites, macros, etc.)
  --   - cmp-vimtex exposes that data as an nvim-cmp source named "vimtex"
  --   - blink.compat lets blink.cmp consume that nvim-cmp source
  --   - blink.cmp merges it with LuaSnip snippets, with snippets ranked higher

  -- friendly-snippets ships as a blink.cmp dependency, but with
  -- snippets.preset = "luasnip" below and no vscode loader anywhere in this
  -- config, nothing ever reads it — the tex menu is entirely the two
  -- generated libraries in lua/snippets (verified 2026-08-22).  Disabled so
  -- it is not cloned, checked, or updated for nothing; delete this line to
  -- re-enable.
  { "rafamadriz/friendly-snippets", enabled = false },

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
      -- Where the LaTeX sources are allowed to run
      --
      -- blink queries every enabled provider on every keystroke.  In a TeX
      -- buffer the two heavy ones are "snippets" (1063 snippets reachable
      -- from tex) and "vimtex" (an nvim-cmp source proxied through
      -- blink.compat, which calls VimTeX's own completer).  Measured on
      -- fedxps, 2026-08-22, at the end of an 1860-char paragraph line:
      -- ~33 ms and ~26 ms per keystroke respectively — paid on every
      -- character of running prose, where neither can offer anything.
      --
      -- So gate them on being somewhere a LaTeX completion makes sense:
      -- part-way through a \command, or inside the braces that follow one.
      -- Verified that \cnec, \cite{che and \ref{sec all still complete,
      -- and that non-TeX filetypes are untouched.
      ------------------------------------------------------------------
      local function in_latex_context()
        local ft = vim.bo.filetype
        if ft ~= "tex" and ft ~= "latex" and ft ~= "plaintex" then
          return true -- every other filetype keeps stock behaviour
        end
        local col = vim.api.nvim_win_get_cursor(0)[2]
        -- Bounded look-behind: never scan the whole paragraph.  The bound
        -- must comfortably exceed a real *argument*, not just a command
        -- name: at the original 60, \cite{ fell out of the window once a
        -- key list or prenote ran past ~60 chars, and both sources went
        -- dead mid-argument (found by direct probe 2026-08-22 — the short
        -- arguments in the test suite never noticed).  300 still costs
        -- microseconds; it was the sources that were expensive, never this
        -- scan.
        local before = vim.api.nvim_get_current_line():sub(math.max(1, col - 300), col)
        -- typing a command:            \cn|      \begin|
        if before:match("\\%a*$") then
          return true
        end
        -- inside a command's argument: \cite{che|    \ref{sec:|
        if before:match("\\%a+%*?%b[]{[^{}]*$") or before:match("\\%a+%*?{[^{}]*$") then
          return true
        end
        return false
      end

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
          -- never runs in e.g. Lua/Markdown buffers — and, within those,
          -- only where a LaTeX completion is plausible (see above).
          enabled = function()
            -- bib/bibtex used to be listed here too, but the source is not
            -- offered in those filetypes any more (see the per-filetype
            -- lists below), so the gate matches: tex-proper only.
            local ft = vim.bo.filetype
            local texish = ft == "tex" or ft == "plaintex" or ft == "latex"
            return texish and in_latex_context()
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
          -- In TeX, only where a LaTeX completion is plausible; elsewhere
          -- in_latex_context() returns true, so nothing else changes.
          enabled = in_latex_context,
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

      -- bib gets snippets (the latex-workshop entry templates) and path,
      -- but not the vimtex source: cmp-vimtex completes citations, labels
      -- and commands *for tex buffers* and has nothing to offer while
      -- authoring entries — and in a bib-only session the plugin (ft-gated
      -- to tex) was never even loaded, leaving the provider half-wired
      -- (2026-08-22).  in_latex_context() doesn't gate non-tex filetypes,
      -- so snippets stay available everywhere in a bib file, which is what
      -- entry templates want.
      local bib_sources = {
        inherit_defaults = false,
        "snippets",
        "path",
      }

      opts.sources.per_filetype.tex = tex_sources
      opts.sources.per_filetype.latex = tex_sources
      opts.sources.per_filetype.plaintex = tex_sources
      opts.sources.per_filetype.bib = bib_sources
      opts.sources.per_filetype.bibtex = bib_sources

      return opts
    end,
  },
}
