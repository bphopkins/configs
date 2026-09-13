return {
  -- Completion stack for LaTeX (since 2026-09-12):
  --   - blink.cmp draws the menu; in TeX buffers it runs two sources only,
  --     LuaSnip snippets and paths
  --   - the snippets are the two libraries in lua/snippets: the generic
  --     latex-workshop set and the french-logic set generated from the
  --     package, so every command row carries its arguments as placeholders
  --   - VimTeX's own completer is no longer a menu source.  Its rows were
  --     bare names (its scanner keeps only the name of a definition, never
  --     the arity), so every command it offered duplicated a snippet with
  --     less in it; and since the package's split into hub and units it
  --     offered no french-logic command at all (it scans only the hub, and
  --     takes the package list from a per-chapter .fls that predates the
  --     split).  Dropped 2026-09-12; DECISIONS.md has the record.  VimTeX
  --     still sets 'omnifunc', so <C-x><C-o> reaches its citation and label
  --     completion by hand (pinned by the latency suite).

  -- friendly-snippets ships as a blink.cmp dependency, but with
  -- snippets.preset = "luasnip" below and no vscode loader anywhere in this
  -- config, nothing ever reads it — the tex menu is entirely the two
  -- generated libraries in lua/snippets (verified 2026-08-22).  Disabled so
  -- it is not cloned, checked, or updated for nothing; delete this line to
  -- re-enable.
  { "rafamadriz/friendly-snippets", enabled = false },

  -- The adapter chain that carried VimTeX's completer into blink (cmp-vimtex,
  -- an nvim-cmp source, proxied through blink.compat) is parked the same way:
  -- enabled = false fragments, so nothing is cloned, checked or updated for a
  -- source no filetype lists.  To bring it back, delete the two lines, re-add
  -- a "vimtex" provider (name "vimtex", module "blink.compat.source") and
  -- list it in tex_sources below.
  { "saghen/blink.compat", enabled = false },
  { "micangl/cmp-vimtex", enabled = false },
  -- blink.cmp: LuaSnip as the snippet engine, TeX-only source lists, and the
  -- latency gate on the snippets provider
  {
    "saghen/blink.cmp",
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
      -- <Tab> inside a snippet: blink's own snippet_forward
      --
      -- LazyVim's blink spec adds a <Tab> entry of its own whenever the
      -- user's keymap has none: LazyVim.cmp.actions.snippet_forward (a
      -- vim.snippet jump -- the native engine only), then its AI-accept
      -- hooks, then "fallback".  Under the luasnip preset no native session
      -- ever exists, so inside an expanded snippet <Tab> fell through to a
      -- literal tab (found 2026-09-12: \frac{A  B}{}).  Naming the entry
      -- here keeps LazyVim's hook out; blink's snippet_forward follows the
      -- preset, and this is the very entry blink's "enter" preset ships --
      -- <S-Tab> still takes the preset's snippet_backward untouched, and
      -- both are mapped in select mode as well, where LazyVim's function
      -- never was.  Pinned by the latency suite.
      --
      -- Cost: an AI extra's ghost-text accept would need
      -- LazyVim.cmp.map({ "ai_nes", "ai_accept" }) chained in before the
      -- fallback.  Declined: LazyVim's coding.luasnip extra, which swaps the
      -- action instead -- it also lazy-loads LuaSnip (moving the snippet
      -- regeneration check from startup to first use), adds a jsregexp
      -- build step, and depends on the friendly-snippets disabled above.
      ------------------------------------------------------------------
      opts.keymap = opts.keymap or {}
      opts.keymap["<Tab>"] = { "snippet_forward", "fallback" }

      ------------------------------------------------------------------
      -- Where the LaTeX sources are allowed to run
      --
      -- blink queries every enabled provider on every keystroke.  In a TeX
      -- buffer the heavy one is "snippets" (about 1,050 snippets reachable
      -- from tex); until 2026-09-12 the "vimtex" source was the other.
      -- Measured on fedxps, 2026-08-22 (power-saver mode), at the end of an
      -- 1860-char paragraph line: ~33 ms and ~26 ms per keystroke
      -- respectively — paid on every character of running prose, where
      -- neither could offer anything.
      --
      -- So gate the provider on being somewhere a LaTeX completion makes
      -- sense: part-way through a \command, or inside the braces that
      -- follow one.  The gate stays open inside \cite{ and \ref{ even
      -- though nothing lists their keys any more, so the window is still
      -- pinned by the suite; non-TeX filetypes are untouched.
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
      -- Snippets: keep them above the path source
      --
      -- This keeps your own LuaSnip templates at the top of the menu.
      ------------------------------------------------------------------
      opts.sources.providers.snippets =
        vim.tbl_deep_extend("force", opts.sources.providers.snippets or {}, {
          -- Higher than path (0) so snippet items float to the top.
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
      --   - "path"    (for \includegraphics, \input, etc.)
      -- "vimtex" sat between them until 2026-09-12 (see the header).
      --
      -- This keeps the completion menu focused and avoids generic buffer/LSP
      -- suggestions that tend to be noisy in large LaTeX projects.
      ------------------------------------------------------------------
      local tex_sources = {
        inherit_defaults = false,
        "snippets",
        "path",
      }

      -- bib gets snippets (the latex-workshop entry templates) and path.
      -- in_latex_context() doesn't gate non-tex filetypes, so snippets stay
      -- available everywhere in a bib file, which is what entry templates
      -- want.  (The vimtex source was never listed here, 2026-08-22.)
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
