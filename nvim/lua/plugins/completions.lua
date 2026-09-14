return {
  -- Completion stack for LaTeX (rebuilt on TeXstudio's model 2026-09-13, stage 3 of the
  -- campaign in configs/docs/latex-completion-campaign-2026-09; PLAN.md carries the
  -- decisions, DECISIONS.md the record):
  --   - blink.cmp draws the menu; in TeX buffers it runs three sources, LuaSnip snippets,
  --     VimTeX's completers through blink's built-in omni provider, and paths
  --   - the snippets are one generated file per package (lua/snippets/pkg, from TeXstudio's
  --     completion word lists; lua/snippets/sty, from the french-logic package), registered
  --     per buffer by lua/snippets/loader.lua from VimTeX's package table, so every command
  --     row carries its arguments as placeholders and its shape in the description column
  --   - VimTeX's completers serve the argument half of the model: citation keys, labels,
  --     environment names, packages, files.  Its command completer never fires: the omni
  --     provider is enabled only inside a command's braces, and the snippets provider only
  --     while a command name is being typed, so the two never overlap (the 2026-09-12 drop of
  --     the vimtex source stands; the bare-name rows it offered are still not wanted)
  --   - inside \begin{ the omni rows become TeXstudio's environment template (name, a body
  --     line, \end), and the loaded files' environment names join VimTeX's, which depend on a
  --     fresh .fls (decided 2026-09-13: the root's .fls was stale, the fixture has none)

  -- friendly-snippets ships as a blink.cmp dependency, but with snippets.preset = "luasnip"
  -- below and no vscode loader anywhere in this config, nothing ever reads it — the tex menu
  -- is entirely the generated libraries in lua/snippets (verified 2026-08-22).  Disabled so
  -- it is not cloned, checked, or updated for nothing; delete this line to re-enable.
  { "rafamadriz/friendly-snippets", enabled = false },

  -- The adapter chain that carried VimTeX's completer into blink (cmp-vimtex, an nvim-cmp
  -- source, proxied through blink.compat) stays parked: enabled = false fragments, so nothing
  -- is cloned, checked or updated for a source no filetype lists.  VimTeX's completers reach
  -- the menu through blink's own omni provider now; the chain is not needed for that.
  { "saghen/blink.compat", enabled = false },
  { "micangl/cmp-vimtex", enabled = false },

  -- blink.cmp: LuaSnip as the snippet engine, TeX-only source lists, the two gates and the
  -- two transforms
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
      ------------------------------------------------------------------
      opts.snippets.preset = "luasnip"

      ------------------------------------------------------------------
      -- snippets.active: LuaSnip's trigger scan stays off the keystroke path
      --
      -- blink's luasnip preset answers active() with is_hidden_snippet()
      -- first, "is the text before the cursor an expandable snippet?",
      -- which LuaSnip settles by matching every registered trigger of the
      -- buffer's snippet filetypes against the line.  blink asks on every
      -- InsertCharPre and TextChangedI and discards the answer there
      -- (completion.trigger.show_in_snippet is true), so with the ~105
      -- pseudo-filetypes and ~7,800 rows a TeX buffer reaches it cost
      -- 3.5 ms per prose keystroke at the end of the fixture's longest
      -- line (23 -> 19 ms, measured 2026-09-13, stage 4 of the campaign)
      -- and put the closure load on the first insert-mode keystroke of a
      -- session rather than on the first completion request.  The check
      -- is kept where it does something: <Tab>/<S-Tab> ask with a
      -- direction, and a fully typed trigger with the menu closed still
      -- expands on <Tab>.  Pinned by the latency suite: prose keystrokes
      -- never reach the loader's ft_func, and that expansion still works.
      ------------------------------------------------------------------
      opts.snippets.active = function(filter)
        local ls = require("luasnip")
        if filter and filter.direction then
          return ls.jumpable(filter.direction)
            or (
              not require("blink.cmp").is_visible()
              and not ls.locally_jumpable(1)
              and ls.expandable()
            )
        end
        return ls.locally_jumpable(1)
      end

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
      -- The two gates
      --
      -- blink queries every enabled provider on every keystroke, and the
      -- snippets source is heavy (about 7,800 rows reachable from the
      -- latency fixture, 9,300 from the dissertation).  Measured on fedxps
      -- 2026-08-22, unguarded: ~33 ms per keystroke of running prose, where
      -- it could offer nothing.  So each source runs only where its rows
      -- make sense, in a bounded look-behind:
      --   snippets  part-way through a \command name (a lone backslash too)
      --   omni      inside the braces that follow a command, unless a new
      --             command name is being typed there (\textbf{\al is a
      --             snippets context, not an omni one), so VimTeX's command
      --             completer never fires and its citation, label,
      --             environment, package and file completers decide for
      --             themselves which braces yield rows (they return nothing
      --             inside \textbf{)
      -- Non-TeX filetypes are untouched: both gates return stock behaviour.
      ------------------------------------------------------------------
      local TEX = { tex = true, latex = true, plaintex = true }

      local function before_cursor()
        local col = vim.api.nvim_win_get_cursor(0)[2]
        -- Bounded look-behind: never scan the whole paragraph.  The bound
        -- must comfortably exceed a real *argument*, not just a command
        -- name: at the original 60, \cite{ fell out of the window once a
        -- key list or prenote ran past ~60 chars, and the sources went dead
        -- mid-argument (found by direct probe 2026-08-22 — the short
        -- arguments in the test suite never noticed).  300 still costs
        -- microseconds; it was the sources that were expensive, never this
        -- scan.
        return vim.api.nvim_get_current_line():sub(math.max(1, col - 300), col)
      end

      -- typing a command:            \cn|      \begin|      \|
      local function command_context(before)
        return before:match("\\%a*$") ~= nil
      end

      -- inside a command's argument: \cite{che|    \ref{sec:|    \begin{ali|
      --                              \includegraphics[width=3cm]{fig|
      local function brace_context(before)
        return (before:match("\\%a+%*?%b[]{[^{}]*$") or before:match("\\%a+%*?{[^{}]*$")) ~= nil
      end

      local function in_command_context()
        if not TEX[vim.bo.filetype] then
          return true -- every other filetype keeps stock behaviour
        end
        return command_context(before_cursor())
      end

      local function in_brace_context()
        if not TEX[vim.bo.filetype] then
          return true
        end
        local before = before_cursor()
        return brace_context(before) and not command_context(before)
      end

      ------------------------------------------------------------------
      -- The snippets provider: offset, description column, sink, dedupe
      --
      -- Rows sit above path (0).  TeXstudio's "unusual" rows (cwl #*,
      -- priority 900 in the generated files) are sunk by a small constant
      -- subtracted from the provider's offset, never an absolute offset: a
      -- per-item score_offset replaces the provider's, and a replaced
      -- offset of -50 buried the row below unrelated matches (spike,
      -- 2026-09-13).  Stage 4 measures the constant against frecency;
      -- until then 5.  The transform also drops a repeated (label,
      -- description) pair, keeping the first: the core file's row over its
      -- twin in a package file, and a hand row over a generated one, by
      -- the loader's filetype order.  Both are table lookups per row,
      -- memoised per snippet id (blink shallow-copies every cached row per
      -- request and the transform runs over the full result), and both
      -- are idempotent: blink re-applies a transform when it resolves an
      -- item for the documentation window.
      ------------------------------------------------------------------
      local SNIPPETS_OFFSET = 10
      local SINK = 5

      local function snippets_transform(_, items)
        local L = require("snippets.loader")
        local keys, sink = L.memo.key, L.memo.sink
        local get = require("luasnip").get_id_snippet
        local seen, out, dropped = {}, {}, 0
        for _, it in ipairs(items) do
          local id = it.data and it.data.snip_id
          local key = id and keys[id]
          if not key then
            key = (it.label or "")
              .. "\1"
              .. ((it.labelDetails and it.labelDetails.description) or "")
            if id then
              keys[id] = key
            end
          end
          if seen[key] then
            dropped = dropped + 1
          else
            seen[key] = true
            if id then
              local off = sink[id]
              if off == nil then
                local sn = get(id)
                off = (sn and (sn.effective_priority or 1000) < 1000) and (SNIPPETS_OFFSET - SINK)
                  or false
                sink[id] = off
              end
              if off then
                it.score_offset = off
              end
            end
            out[#out + 1] = it
          end
        end
        if #items > 1 or dropped > 0 then
          L.stats.dedupe = dropped
        end
        return out
      end

      opts.sources.providers.snippets =
        vim.tbl_deep_extend("force", opts.sources.providers.snippets or {}, {
          score_offset = SNIPPETS_OFFSET,
          enabled = in_command_context,
          opts = { use_label_description = true },
          transform_items = snippets_transform,
        })

      ------------------------------------------------------------------
      -- The omni provider: VimTeX's completers, and the \begin{ template
      --
      -- blink's built-in omni provider calls 'omnifunc', which VimTeX sets.
      -- Its transform (1) drops a repeated label (VimTeX returns amsmath
      -- twice from two trees) and (2) inside \begin{ rewrites every row into
      -- a snippet-format edit, `name}` + a body line + `\end{name}`, with
      -- \item in the body for a list environment, extended over an
      -- auto-paired `}` so no stray brace survives (the measured breakage of
      -- 2026-09-12, comparison 2.7); then it appends the environment names
      -- of the buffer's loaded files that VimTeX did not return.  VimTeX
      -- knows an environment only from its own data, the project's own
      -- \newenvironments, and a scan of the packages a fresh .fls names;
      -- the loaded files know 212 names on the fixture against VimTeX's
      -- 125, and every french-logic environment is among the 87 it lacks
      -- (decided 2026-09-13).  The template is TeXstudio's: in its
      -- environment mode the row is truncated to \begin{name} and
      -- expandCode adds content and \end.
      ------------------------------------------------------------------
      local function omni_transform(ctx, items)
        local seen, out = {}, {}
        for _, it in ipairs(items) do
          local label = it.label or ""
          if not seen[label] then
            seen[label] = true
            out[#out + 1] = it
          end
        end
        local before = ctx.line:sub(1, ctx.cursor[2])
        local typed = before:match("\\begin{([^{}]*)$")
        if not typed then
          return out
        end
        -- a resolve re-applies the transform to one already-rewritten row
        if #items == 1 and items[1].data and items[1].data.envtpl then
          return out
        end
        local envs = require("snippets.loader").envs(ctx.bufnr)
        local after = ctx.line:sub(ctx.cursor[2] + 1, ctx.cursor[2] + 1)
        local row = ctx.cursor[1] - 1
        local range = {
          start = { line = row, character = ctx.cursor[2] - #typed },
          ["end"] = { line = row, character = ctx.cursor[2] + (after == "}" and 1 or 0) },
        }
        local Snippet = vim.lsp.protocol.InsertTextFormat.Snippet
        local function template(name)
          local body = envs.lists[name] and "\\item " or ""
          return name .. "}\n\t" .. body .. "$0\n\\end{" .. name .. "}"
        end
        for _, it in ipairs(out) do
          if not (it.data and it.data.envtpl) then
            local name = ((it.textEdit and it.textEdit.newText) or it.label or ""):gsub("}$", "")
            it.insertTextFormat = Snippet
            it.textEdit = { range = range, newText = template(name) }
            it.data = { envtpl = true }
          end
        end
        -- The appended rows carry what blink stamps on a provider's own rows before the
        -- transform runs (source_id, source_name, cursor_column, score_offset, kind): the
        -- accept path looks the provider up by source_id and adjusts the edit by
        -- cursor_column, and a row without them errors inside blink (found 2026-09-13).
        local stamp = out[1]
          or {
            source_id = "omni",
            source_name = "omni",
            score_offset = 0,
            cursor_column = ctx.cursor[2],
          }
        local kind = require("blink.cmp.types").CompletionItemKind.Snippet
        for _, name in ipairs(envs.names) do
          if not seen[name] then
            seen[name] = true
            out[#out + 1] = {
              label = name,
              kind = kind,
              insertTextFormat = Snippet,
              textEdit = { range = range, newText = template(name) },
              labelDetails = { detail = "[env: snippets]" },
              data = { envtpl = true },
              source_id = stamp.source_id,
              source_name = stamp.source_name,
              score_offset = stamp.score_offset or 0,
              cursor_column = stamp.cursor_column or ctx.cursor[2],
            }
          end
        end
        return out
      end

      opts.sources.providers.omni =
        vim.tbl_deep_extend("force", opts.sources.providers.omni or {}, {
          enabled = in_brace_context,
          transform_items = omni_transform,
        })

      ------------------------------------------------------------------
      -- Per-filetype source lists
      --
      -- For TeX-related filetypes we *disable* the global defaults and
      -- use only:
      --   - "snippets" (the generated libraries, gated to command names)
      --   - "omni"     (VimTeX's completers, gated to a command's braces)
      --   - "path"     (for \includegraphics, \input, etc.)
      --
      -- This keeps the completion menu focused and avoids generic buffer/LSP
      -- suggestions that tend to be noisy in large LaTeX projects.
      ------------------------------------------------------------------
      ------------------------------------------------------------------
      -- The description column: 45 cells (blink's default is 30)
      --
      -- The column carries a row's shape ({num}{den}, [options]{package} and
      -- the unusual-row marker)
      -- and VimTeX's `year, author, type` for a citation key, right-aligned
      -- and cut with an ellipsis at the maximum.  On the completeness
      -- chapter's closure 9.9% of the 7,834 rows exceed 30 cells and 2.3%
      -- exceed 45 (p90 is exactly 30, p99 54, the longest 116), and the
      -- marker of an unusual row is the last character, so a cut removes
      -- it first.  Decided 2026-09-13 with the menu in front of him
      -- (stage 4); pinned by the latency suite.
      ------------------------------------------------------------------
      opts.completion = vim.tbl_deep_extend("force", opts.completion or {}, {
        menu = { draw = { components = { label_description = { width = { max = 45 } } } } },
      })

      local tex_sources = {
        inherit_defaults = false,
        "snippets",
        "omni",
        "path",
      }

      -- bib gets snippets (the hand file of entry templates, hand/bibtex.lua)
      -- and path.  Neither gate touches non-tex filetypes, so snippets stay
      -- available everywhere in a bib file, which is what entry templates
      -- want.
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
