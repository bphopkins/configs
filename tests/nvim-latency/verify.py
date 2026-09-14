#!/usr/bin/env python3
"""Deterministic regression checks for the 2026-08-22 insert-mode latency work and the
2026-09-13 completion rebuild (stage 3 of the LaTeX completion campaign).

Timings are load- and machine-dependent, so nothing here asserts milliseconds
— that is `bench.py`'s job.  These checks assert the *structure* the speed-up
rests on, plus the behaviour it must not have broken:

  * VimTeX's matchparen is live in normal mode and gone during insert
  * the two gates: blink's snippets provider runs only while a \\command name
    is typed, its omni provider (VimTeX's completers) only inside a command's
    braces, and neither in running prose, where blink used to fire on every
    char; \\cite{ and \\ref{ are omni contexts now (flipped 2026-09-13; they
    were snippets contexts while VimTeX's rows were out of the menu)
  * the rows: a snippet row carries its description column; a math-only row
    is wrapped in $…$ in prose and bare in math; an environment-restricted row
    hides outside its environment; the fixture, which has no .fls, reaches
    amsmath through the french-logic hub's includes; the fixture's own
    \\newcommand completes with its arity and refreshes when the file changes
  * \\begin{: VimTeX's names and the loaded files' names become TeXstudio's
    environment template, with no stray brace (the 2026-09-12 breakage)
  * <Tab> and <S-Tab> jump between LuaSnip placeholders, in insert and select
    mode (LazyVim's own <Tab> entry knew only native snippets, 2026-09-12)
  * non-TeX filetypes are untouched
  * the auto-save autocmd is in an augroup, so re-sourcing cannot duplicate it
  * bench.py leaves the document it measures byte-identical

Each is a thing that silently regresses: nothing errors if the gate stops
working, you just quietly pay 130 ms a keystroke again.
"""

import hashlib
import os
import shutil
import subprocess
import sys
import tempfile
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from harness import Nvim, Checks

c = Checks()
v = Nvim().open_fixture()

try:
    c.check("fixture opens as filetype tex", v.eval("&filetype"), "tex")
    c.check("VimTeX omnifunc still wired for <C-x><C-o> (source dropped 2026-09-12)",
            v.eval("&omnifunc"), "vimtex#complete#omnifunc")
    c.check("VimTeX syntax is the highlighter (no treesitter)",
            v.lua("return vim.treesitter.highlighter.active"
                  "[vim.api.nvim_get_current_buf()] ~= nil"), False)

    paras = v.para_lines()
    c.check("fixture has 4 long paragraph lines", len(paras), 4)
    longest = paras[-1][0]

    # ---- matchparen: normal mode keeps it, insert mode does not ----------
    def vimtex_mp_hooks():
        return v.lua("""
          local b = vim.api.nvim_get_current_buf()
          local ok, l = pcall(vim.api.nvim_get_autocmds,
            { group = 'vimtex_matchparen' .. b, event = 'CursorMovedI' })
          return ok and #l or 0
        """)

    c.check("vimtex_matchparen_enabled left at 1 (not blanket-disabled)",
            v.eval("g:vimtex_matchparen_enabled"), 1)
    c.check("VimTeX matchparen hooked in normal mode", vimtex_mp_hooks() > 0, True)
    v.goto_end_of(longest)
    v.insert()
    c.check("VimTeX matchparen unhooked during insert", vimtex_mp_hooks(), 0)
    v.escape()
    c.check("VimTeX matchparen restored after insert", vimtex_mp_hooks() > 0, True)
    c.check("entering insert raises no error", v.lua("""
      vim.cmd('silent! messages clear')
      return true"""), True)
    v.insert()
    v.escape()
    c.check("...and none after a full insert/leave cycle",
            v.lua("return vim.trim(vim.fn.execute('messages'))"), "")
finally:
    v.close()

# A separate instance: with the feature switched off, VimTeX never creates its
# per-buffer augroup, and disable() would raise E216 on every InsertEnter.
# This fired for real before the guard went in.
v = Nvim(gvars={"vimtex_matchparen_enabled": 0}).open_fixture()
try:
    v.goto_end_of(v.para_lines()[-1][0])
    v.lua("vim.cmd('silent! messages clear')")
    v.insert()
    v.escape()
    c.check("vimtex_matchparen_enabled=0 raises no error on insert",
            v.lua("return vim.trim(vim.fn.execute('messages'))"), "")
finally:
    v.close()

v = Nvim().open_fixture()
try:
    # ---- blink source gating --------------------------------------------
    # Ask the providers directly: this is what blink calls per keystroke.
    def provider_enabled(name):
        return v.lua("""
          local name = ...
          local ok, cfg = pcall(require, 'blink.cmp.config')
          if not ok then return 'blink-not-loaded' end
          local p = cfg.sources.providers[name]
          if not p then return 'no-such-provider' end
          local e = p.enabled
          if e == nil then return true end
          if type(e) == 'function' then return e() and true or false end
          return e and true or false
        """, name)

    def rows(n=400):
        """(label, source_id, description) of blink's current rows, first n."""
        return v.lua("""
          local n = ...
          local ok, list = pcall(require, 'blink.cmp.completion.list')
          if not ok then return {} end
          local out = {}
          for i, it in ipairs(list.items or {}) do
            if i > n then break end
            out[#out + 1] = { it.label or '', it.source_id or '',
                              (it.labelDetails and it.labelDetails.description) or '' }
          end
          return out
        """, n)

    def has_row(label, source=None):
        return any(r[0] == label and (source is None or r[1] == source) for r in rows())

    def keys(*ks, settle=0.5):
        for k in ks:
            v.nvim.input(k)
            v.cmd("redraw")
            time.sleep(settle)

    scratch = v.eval("line('$')")

    # ---- the idle pre-warm (stage 4, 2026-09-13) -------------------------
    # After VimTeX initialises a TeX buffer the loader registers its closure
    # one file per timer tick, so the first request finds it in place instead
    # of paying 660 to 750 ms.  Pinned before any keystroke: the pre-warm
    # reports done, a french-logic unit is registered, and no request was
    # made (the loader's filetypes function, the request path, never ran).
    v.lua("""
      local L = require('snippets.loader'); _G.FT_CALLS = 0
      if not _G.FT_WRAPPED then
        _G.FT_WRAPPED = true
        local orig = L.filetypes
        L.filetypes = function(...) _G.FT_CALLS = _G.FT_CALLS + 1; return orig(...) end
      end
    """)
    t0 = time.time()
    while time.time() - t0 < 20 and not v.lua(
            "local p = require('snippets.loader').prewarm[vim.api.nvim_get_current_buf()] "
            "return (p and p.done) and true or false"):
        time.sleep(0.1)
    c.check("idle pre-warm registers the closure before any keystroke, with no request made",
            v.lua("local p = require('snippets.loader').prewarm[vim.api.nvim_get_current_buf()] "
                  "return (p and p.done) and #require('luasnip').get_snippets('pkg-french-logic-core') > 0 "
                  "and _G.FT_CALLS == 0"), True)

    v.reset_tail(scratch)
    v.type(" \\cnec")
    c.check("snippets provider enabled after '\\cnec'", provider_enabled("snippets"), True)
    c.check("omni provider closed after a bare '\\cnec' (VimTeX's command completer never fires)",
            provider_enabled("omni"), False)
    c.check("no vimtex provider (source dropped 2026-09-12)",
            provider_enabled("vimtex"), "no-such-provider")
    c.check("no TeX source list names vimtex",
            v.lua("local pf = require('blink.cmp.config').sources.per_filetype "
                  "for _, ft in ipairs({ 'tex', 'latex', 'plaintex', 'bib', 'bibtex' }) do "
                  "  for _, src in ipairs(pf[ft] or {}) do "
                  "    if src == 'vimtex' then return ft end end end "
                  "return 'none'"), "none")
    c.check("every TeX source list names omni (2026-09-13)",
            v.lua("local pf = require('blink.cmp.config').sources.per_filetype "
                  "for _, ft in ipairs({ 'tex', 'latex', 'plaintex' }) do "
                  "  if not vim.tbl_contains(pf[ft] or {}, 'omni') then return ft end end "
                  "return 'all'"), "all")
    c.check("menu shown after '\\cnec'", v.menu_visible(), True)
    c.check("the \\cnecs row comes from a french-logic unit (hub-implies header, no .fls)",
            has_row("\\cnecs", "snippets"), True)

    v.reset_tail(scratch)
    v.type(" \\cite{che")
    c.check("snippets closed inside '\\cite{' (flipped 2026-09-13)", provider_enabled("snippets"), False)
    c.check("omni open inside '\\cite{'", provider_enabled("omni"), True)

    v.reset_tail(scratch)
    v.type(" \\ref{sec")
    c.check("snippets closed inside '\\ref{' (flipped 2026-09-13)", provider_enabled("snippets"), False)
    c.check("omni open inside '\\ref{'", provider_enabled("omni"), True)

    # A command name typed inside another command's braces is a snippets context: without
    # this branch VimTeX's bare-name command rows would return through omni.
    v.reset_tail(scratch)
    v.type(" \\textbf{\\al")
    c.check("nested '\\textbf{\\al': snippets open", provider_enabled("snippets"), True)
    c.check("nested '\\textbf{\\al': omni closed", provider_enabled("omni"), False)

    v.reset_tail(scratch)
    v.type(" ordinary prose words")
    c.check("snippets provider OFF in plain prose", provider_enabled("snippets"), False)
    c.check("omni provider OFF in plain prose", provider_enabled("omni"), False)
    c.check("menu NOT shown in plain prose", v.menu_visible(), False)

    # Non-vacuity: the same probe must flip back on within the same buffer,
    # otherwise "OFF in prose" could be passing because the probe is broken.
    v.type("\\th")
    c.check("gate re-opens on the next backslash (probe is not stuck)",
            provider_enabled("snippets"), True)

    # ---- long arguments stay inside the gate window ----------------------
    # With the original 60-char look-behind, \cite{ fell out of the window
    # once a key list or prenote ran past ~60 chars, and both sources went
    # dead mid-argument (found by direct probe 2026-08-22 — the short
    # arguments above never noticed).  The window is 300 now; these pin it
    # on the gate that serves \cite{ today, the omni one.
    def park_at_eol(text):
        v.escape()
        v.lua("""
          local l, t = ...
          vim.api.nvim_buf_set_lines(0, l - 1, l, false, { t })
          vim.api.nvim_win_set_cursor(0, { l, 0 })
          vim.cmd('normal! $')
        """, scratch, text)
        v.insert()

    park_at_eol(" \\cite{vonwright1951,hansson1969,lewis1973,"
                "chellas1974,aqvist1984,tomberlin")
    c.check("omni gate open deep in a 75-char \\cite key list",
            provider_enabled("omni"), True)
    park_at_eol(" \\cite[see the extended discussion in chapter four "
                "of the second essay]{vonw")
    c.check("omni gate open after a long optional argument",
            provider_enabled("omni"), True)
    v.escape()

    c.check("the core file pkg-tex is registered",
            v.lua("return #require('luasnip').get_snippets('pkg-tex') > 0"), True)
    c.check("the french-logic unit pkg-french-logic-core is registered (through the hub's includes)",
            v.lua("return #require('luasnip').get_snippets('pkg-french-logic-core') > 0"), True)
    c.check("the retired french-logic filetype is empty",
            v.lua("return #require('luasnip').get_snippets('french-logic')"), 0)

    # ---- omni rows: VimTeX's citation keys from fixture.bib -------------
    v.reset_tail(scratch)
    v.type(" \\cite{fixt", settle=1.5)
    c.check("omni: '\\cite{fixt' offers the fixture.bib key through VimTeX",
            has_row("fixture2026", "omni"), True)
    v.escape()

    # ---- \begin{: TeXstudio's environment template ----------------------
    # VimTeX's bare environment names, and the loaded files' names VimTeX does
    # not know (every french-logic environment here: the fixture has no .fls),
    # become `\begin{name}` + a body line + `\end{name}`, the auto-paired `}`
    # consumed (the 2026-09-12 breakage wrote `\begin{\begin{align*}` /
    # `\end{align*}}`).
    def begin_accept(typed):
        v.reset_tail(scratch, "Scratch.")
        v.type(" \\begin{" + typed, settle=1.5)
        keys("<CR>", settle=1.0)
        lnum = v.eval("line('.')")
        got = v.eval("getline(%d, %d)" % (lnum - 1, lnum + 1))
        v.escape()
        v.lua("vim.api.nvim_buf_set_lines(0, %d, -1, false, {})" % scratch)
        # always three strings, so a row that never appeared fails its check instead of
        # raising (a mutation run must reach its full failure set)
        return (got + ["", "", ""])[:3]

    got = begin_accept("enum")
    c.check("\\begin{enum accepted: \\begin{enumerate}, an indented \\item line, \\end{enumerate}",
            [got[0], got[1].strip(), got[2]] == ["Scratch. \\begin{enumerate}", "\\item", "\\end{enumerate}"]
            and got[1] != got[1].strip(), True)
    c.check("...and no stray brace", "}}" in "".join(got) or "{\\begin" in "".join(got), False)
    got = begin_accept("hilbertl")
    c.check("\\begin{hilbertl: a french-logic list environment VimTeX does not know here (union, 2026-09-13)",
            [got[0], got[1].strip(), got[2]] == ["Scratch. \\begin{hilbertlist}", "\\item", "\\end{hilbertlist}"], True)
    got = begin_accept("proofsk")
    c.check("\\begin{proofsk: a non-list environment gets an empty indented body line",
            [got[0], got[1].strip(), got[2]] == ["Scratch. \\begin{proofsketch}", "", "\\end{proofsketch}"], True)

    # ---- the rows: description, math wrap, environment restriction ------
    v.reset_tail(scratch, "Scratch.")
    v.type(" \\frac")
    c.check("a snippet row carries its description column (\\frac: {num}{den})",
            any(r[0] == "\\frac" and r[2] == "{num}{den}" for r in rows()), True)
    c.check("the description column is 45 cells wide (decided 2026-09-13; blink's default 30 cut a tenth of the rows)",
            v.lua("return require('blink.cmp.config').completion.menu.draw.components.label_description.width.max"), 45)
    v.escape()

    v.reset_tail(scratch, "Scratch.")
    v.type(" \\alpha")
    keys("<CR>", settle=0.8)
    c.check("\\alpha accepted in prose is wrapped: $\\alpha$", v.eval("getline('.')"), "Scratch. $\\alpha$")
    v.escape()
    v.reset_tail(scratch, "Scratch.")
    v.type(" $x \\alpha")
    keys("<CR>", settle=0.8)
    c.check("\\alpha accepted inside math stays bare", v.eval("getline('.')"), "Scratch. $x \\alpha")
    v.escape()

    v.reset_tail(scratch, "Scratch.")
    v.type(" \\TextFi")
    c.check("environment-restricted row hidden in prose (\\TextField, hyperref /Form)",
            has_row("\\TextField"), False)
    v.escape()
    v.lua("""
      local l = ...
      vim.api.nvim_buf_set_lines(0, l - 1, -1, false, { '\\\\begin{Form}', 'Scratch.', '\\\\end{Form}' })
      vim.api.nvim_win_set_cursor(0, { l + 1, 0 })
      vim.cmd('normal! $')
    """, scratch)
    v.insert()
    v.type(" \\TextFi")
    c.check("environment-restricted row shown inside its environment",
            has_row("\\TextField"), True)
    v.escape()
    v.lua("vim.api.nvim_buf_set_lines(0, %d, -1, false, {})" % scratch)

    # ---- the hub-implies header and the document's own commands ---------
    v.reset_tail(scratch, "Scratch.")
    v.type(" \\alig")
    c.check("\\align offered from a bare backslash: amsmath through the hub-implies header (no .fls)",
            has_row("\\align", "snippets"), True)
    v.escape()

    v.reset_tail(scratch, "Scratch.")
    v.type(" \\fixturec")
    keys("<CR>", settle=0.8)
    c.check("a \\newcommand in the fixture's preamble completes with its arity",
            v.eval("getline('.')"), "Scratch. \\fixturecmd{}{}")
    v.escape()

    # ---- snippet placeholder jumps ---------------------------------------
    # LazyVim's blink spec adds its own <Tab> entry whenever the user's keymap
    # has none, and that entry jumps *native* vim.snippet sessions only; under
    # snippets.preset = "luasnip" it never fired, so <Tab> inside an expanded
    # snippet inserted whitespace (found 2026-09-12: \frac{A  B}{}).
    # completions.lua now names <Tab> as blink's own snippet_forward, which
    # follows the preset; <S-Tab> is the preset's own snippet_backward.  Pinned
    # through the real path -- the menu row accepted with <CR>, then the keys
    # -- in insert mode and, for <Tab>, from select mode too (blink maps the
    # snippet commands there separately, and LazyVim's entry was never one).
    # Since 2026-09-13 the \frac row is TeXstudio's, math-only with named
    # placeholders, so it expands to $\frac{num}{den}$ in prose and the typed
    # letters replace the selected placeholder text.
    v.reset_tail(scratch, "Scratch.")
    v.type(" \\frac")
    keys("<CR>", settle=0.8)
    c.check("snippet: <CR> on the \\frac row opens a LuaSnip session",
            v.eval("getline('.')") == "Scratch. $\\frac{num}{den}$"
            and bool(v.lua("return require('luasnip').jumpable(1)")), True)
    keys("A", "<Tab>", "B")
    c.check("snippet: <Tab> jumps to the second placeholder",
            v.eval("getline('.')"), "Scratch. $\\frac{A}{B}$")
    keys("<S-Tab>", "C")
    c.check("snippet: <S-Tab> jumps back and the placeholder text is replaced",
            v.eval("getline('.')"), "Scratch. $\\frac{C}{B}$")
    keys("<Tab>", "<Tab>", "E")
    c.check("snippet: <Tab> from select mode reaches the end of the snippet",
            v.eval("getline('.')"), "Scratch. $\\frac{C}{B}$E")

    # ---- the per-keystroke snippet check (stage 4, 2026-09-13) -----------
    # blink's luasnip preset answered snippets.active() with LuaSnip's
    # expandable(), a scan of every registered trigger of the buffer's snippet
    # filetypes, on every InsertCharPre and TextChangedI, where the answer is
    # discarded (show_in_snippet is true): 3.5 ms per prose keystroke at the
    # end of the fixture's longest line, and the closure load on the first
    # insert-mode keystroke of a session.  completions.lua keeps the scan for
    # <Tab>/<S-Tab> only.  Two pins: prose keystrokes never reach the loader's
    # ft_func (the scan begins by asking for the buffer's filetypes), and the
    # one thing the scan served still works, a fully typed trigger expanding
    # on <Tab> with the menu closed.
    v.escape()
    v.lua("""
      local ls = require('luasnip')
      for _ = 1, 5 do
        if ls.jumpable(1) or ls.jumpable(-1) then pcall(ls.unlink_current) else break end
      end
      require('luasnip.session').current_nodes[vim.api.nvim_get_current_buf()] = nil
      local L = require('snippets.loader'); _G.FT_CALLS = 0
      if not _G.FT_WRAPPED then
        _G.FT_WRAPPED = true
        local orig = L.filetypes
        L.filetypes = function(...) _G.FT_CALLS = _G.FT_CALLS + 1; return orig(...) end
      end
    """)
    v.reset_tail(scratch, "Scratch.")
    v.type(" plain words")
    c.check("prose keystrokes never reach the loader's ft_func (no trigger scan per keystroke)",
            v.lua("return _G.FT_CALLS"), 0)
    v.escape()
    v.reset_tail(scratch, "Scratch.")
    v.type(" \\frac")
    keys("<C-e>", settle=0.5)
    keys("<Tab>", settle=0.8)
    c.check("a fully typed trigger with the menu closed still expands on <Tab>",
            v.eval("getline('.')"), "Scratch. $\\frac{num}{den}$")
    v.escape()
    v.escape()

    # ---- :SnippetsReload and the hand file's precedence --------------------
    # Reload re-reads every registered file under its key and cleans LuaSnip's
    # invalidated rows, so counts stay put and no row is listed twice (a keyed
    # re-add leaves the old rows invalidated but listed until clean_invalidated
    # runs -- spike, 2026-09-13).  A hand row (hand/local.lua) with the same
    # label and description as a generated row shadows it: the loader lists
    # hand-local before the generated files and the transform keeps the first.
    before = v.lua("return #require('luasnip').get_snippets('pkg-tex')")
    v.lua("vim.cmd('silent! messages clear')")
    v.cmd("SnippetsReload")
    c.check(":SnippetsReload keeps the registered row count and raises nothing",
            v.lua("return #require('luasnip').get_snippets('pkg-tex')") == before
            and v.lua("return vim.trim(vim.fn.execute('messages'))") == "", True)
    hand_id = v.lua("""
      local ls = require('luasnip')
      local sn = ls.snippet({ trig = '\\\\frac', dscr = '{num}{den}' },
        { ls.text_node('\\\\frac{HAND}{'), ls.insert_node(1), ls.text_node('}') })
      ls.add_snippets('hand-local', { sn }, { key = 'hand-local' })
      return sn.id""")
    v.reset_tail(scratch, "Scratch.")
    v.type(" \\frac")
    frac_rows = [r for r in v.lua("""
      local l = require('blink.cmp.completion.list'); local out = {}
      for _, it in ipairs(l.items or {}) do
        if it.label == '\\\\frac' then out[#out + 1] = it.data and it.data.snip_id or -1 end
      end
      return out""")]
    c.check("a hand row with the same label and description shadows the generated one",
            frac_rows == [hand_id], True)
    v.escape()

    # ---- the document's definitions refresh when the main file changes --
    # The loader re-reads the main file on an mtime change (one stat per
    # request), so a definition added to the preamble and saved is offered at
    # the next request without a compile.  Last in this instance: it shifts
    # every line below the preamble by one.
    v.lua("vim.api.nvim_buf_set_lines(0, 7, 7, false, { '\\\\newcommand{\\\\fixturelate}[1]{#1}' })")
    v.cmd("silent write")
    time.sleep(0.3)
    v.reset_tail(v.eval("line('$')"), "Scratch.")
    v.type(" \\fixturel")
    keys("<CR>", settle=0.8)
    c.check("a definition added to the main file and saved is offered at the next request",
            v.eval("getline('.')"), "Scratch. \\fixturelate{}")
    v.escape()

    # ---- other filetypes keep stock behaviour ----------------------------
    v.cmd("enew")
    v.cmd("set filetype=lua")
    v.lua("vim.api.nvim_buf_set_lines(0, 0, -1, false, {'local xyz_abc = 1', ''})"
          "vim.api.nvim_win_set_cursor(0, {2, 0})")
    v.insert()
    v.type("xyz")
    c.check("lua buffer: snippets provider still enabled", provider_enabled("snippets"), True)
    c.check("lua buffer: menu still auto-shows", v.menu_visible(), True)
    v.escape()

    # ---- auto-save is in an augroup and is re-source idempotent ----------
    def autosave_grouped():
        return v.lua("""
          local n = 0
          for _, a in ipairs(vim.api.nvim_get_autocmds(
              { event = { 'InsertLeavePre', 'TextChanged' } })) do
            if a.group_name == 'bph_autosave' then n = n + 1 end
          end
          return n
        """)

    def autosave_total():
        # Counted regardless of group: an ungrouped duplicate must be visible
        # here, or the idempotency check below would pass vacuously against
        # the pre-fix code (verified — it did, until this was split out).
        return v.lua("""
          local n = 0
          for _, a in ipairs(vim.api.nvim_get_autocmds(
              { event = { 'InsertLeavePre', 'TextChanged' } })) do
            if a.pattern and tostring(a.pattern):match('%.tex') then n = n + 1 end
          end
          return n
        """)

    c.check("auto-save autocmds live in the bph_autosave group",
            autosave_grouped() > 0, True)
    before = autosave_total()
    c.check("no auto-save autocmd is left ungrouped", v.lua("""
      local n = 0
      for _, a in ipairs(vim.api.nvim_get_autocmds(
          { event = { 'InsertLeavePre', 'TextChanged' } })) do
        if a.group_name == nil and a.pattern and tostring(a.pattern):match('%.tex') then
          n = n + 1
        end
      end
      return n
    """), 0)
    v.lua("dofile(vim.fn.stdpath('config') .. '/lua/config/autocmds.lua')")
    c.check("re-sourcing autocmds.lua does not duplicate them",
            autosave_total(), before)

    # ---- auto-save failures are loud (once); successes stay silent -------
    # `silent! write` used to swallow a failed write entirely: modified
    # buffer, nothing shown, v:errmsg empty (demonstrated 2026-08-22 — the
    # ENOSPC class).  Now: readonly buffers are skipped, a disk-level
    # failure notifies once per buffer, repeats stay quiet, and recovery
    # notes once.  vim.notify is captured here, so nothing is displayed.
    v.lua("_G.bph_test_notes = {} _G.bph_orig_notify = vim.notify "
          "vim.notify = function(m, ...) "
          "table.insert(_G.bph_test_notes, tostring(m)) end")

    def notes(substr):
        return v.lua(
            "local n, s = 0, select(1, ...) "
            "for _, m in ipairs(_G.bph_test_notes) do "
            "if m:find(s, 1, true) then n = n + 1 end end "
            "return n", substr)

    ro = os.path.join(v.tmp, "autosave-ro.tex")
    with open(ro, "w") as fh:
        fh.write("alpha beta\n")
    os.chmod(ro, 0o444)
    v.cmd("edit " + ro)  # nvim marks the buffer readonly from the file mode
    v.nvim.input("x")
    v.cmd("redraw")
    time.sleep(0.4)
    c.check("readonly buffer: auto-save skips silently", notes("auto-save"), 0)

    rw = os.path.join(v.tmp, "autosave-fail.tex")
    with open(rw, "w") as fh:
        fh.write("gamma delta\n")
    v.cmd("edit " + rw)
    os.chmod(rw, 0o444)  # buffer believes it is writable; the disk says no
    for _ in range(2):
        v.nvim.input("x")
        v.cmd("redraw")
        time.sleep(0.4)
    c.check("disk failure: auto-save notifies", notes("auto-save FAILED") >= 1, True)
    c.check("disk failure: exactly once across repeated failures",
            notes("auto-save FAILED"), 1)
    os.chmod(rw, 0o644)
    v.nvim.input("x")
    v.cmd("redraw")
    time.sleep(0.4)
    c.check("recovery: buffer saved once writable again", v.eval("&modified"), 0)
    c.check("recovery: noted once", notes("saving again"), 1)
    v.lua("vim.notify = _G.bph_orig_notify")

    # ---- markdown <CR>: blink enter-accept and checkbox continuation -----
    # These coexist because blink applies its own buffer-local <CR> and
    # snapshots the pre-existing checkbox mapping as its fallback — keymap
    # behaviour nothing upstream documents (verified live 2026-08-22).  Pin
    # both halves: a blink update that changes keymap application would
    # break one of them silently.
    v.cmd("enew")
    v.cmd("setfiletype markdown")
    time.sleep(0.6)
    c.check("markdown: buffer-local insert <CR> mapping present",
            v.lua("for _, m in ipairs(vim.api.nvim_buf_get_keymap(0, 'i')) do "
                  "if m.lhs == '<CR>' then return true end end return false"),
            True)
    v.lua("vim.api.nvim_buf_set_lines(0, 0, -1, false, "
          "{ 'checkbook checkpoint checkers', '' }) "
          "vim.api.nvim_win_set_cursor(0, { 2, 0 })")
    v.insert()
    v.type("check", per=0.25, settle=1.0)
    c.check("markdown: menu opens on a buffer word", v.menu_visible(), True)
    v.nvim.input("<C-n>")
    v.cmd("redraw")
    time.sleep(0.5)
    v.nvim.input("<CR>")
    v.cmd("redraw")
    time.sleep(0.8)
    v.escape()
    got = v.lua("return vim.api.nvim_buf_get_lines(0, 0, -1, false)")
    c.check("markdown: <CR> accepts the selected completion (no stray newline)",
            len(got) == 2 and got[1].startswith("check") and len(got[1]) > 5,
            True)
    v.lua("vim.api.nvim_buf_set_lines(0, 0, -1, false, { '- [ ] alpha' }) "
          "vim.api.nvim_win_set_cursor(0, { 1, 0 }) vim.cmd('normal! $')")
    v.insert()
    v.nvim.input("<CR>")
    v.cmd("redraw")
    time.sleep(0.5)
    v.escape()
    got = v.lua("return vim.api.nvim_buf_get_lines(0, 0, -1, false)")
    c.check("markdown: <CR> continues a checkbox list",
            len(got) >= 2 and got[1].strip() == "- [ ]", True)
finally:
    v.close()

# ---- bench.py must not write to the document it measures -----------------
# measure() types characters in and undoes them, but the undo never reaches
# disk: the auto-save autocmd has already written on InsertLeavePre.  Pointed
# at a real file, the old code left its filler string on every long line it
# visited, and an interrupted run left it with no undo at all.  --file now
# measures a throwaway copy; this pins that, because the damage is invisible
# in the tool's own output — it prints timings either way.
HERE = os.path.dirname(os.path.abspath(__file__))
with tempfile.TemporaryDirectory(prefix="nvim-latency-selftest-") as _td:
    _target = os.path.join(_td, "fixture.tex")
    shutil.copyfile(os.path.join(HERE, "fixture.tex"), _target)
    _before = hashlib.sha256(open(_target, "rb").read()).hexdigest()
    try:
        subprocess.run(
            [sys.executable, os.path.join(HERE, "bench.py"),
             "--file", _target, "-n", "2", "--gap", "0.02"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=240,
        )
        _after = hashlib.sha256(open(_target, "rb").read()).hexdigest()
    except subprocess.TimeoutExpired:
        _after = "bench.py timed out"
c.check("bench.py --file leaves the target byte-identical", _after, _before)

sys.exit(c.report())
