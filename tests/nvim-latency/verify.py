#!/usr/bin/env python3
"""Deterministic regression checks for the 2026-08-22 insert-mode latency work.

Timings are load- and machine-dependent, so nothing here asserts milliseconds
— that is `bench.py`'s job.  These checks assert the *structure* the speed-up
rests on, plus the behaviour it must not have broken:

  * VimTeX's matchparen is live in normal mode and gone during insert
  * blink still completes after \\command, \\cite{ and \\ref{
  * blink stays quiet in running prose, where it used to fire on every char
  * non-TeX filetypes are untouched
  * the auto-save autocmd is in an augroup, so re-sourcing cannot duplicate it

Each is a thing that silently regresses: nothing errors if the gate stops
working, you just quietly pay 130 ms a keystroke again.
"""

import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from harness import Nvim, Checks

c = Checks()
v = Nvim().open_fixture()

try:
    c.check("fixture opens as filetype tex", v.eval("&filetype"), "tex")
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

    scratch = v.eval("line('$')")

    v.reset_tail(scratch)
    v.type(" \\cnec")
    c.check("snippets provider enabled after '\\cnec'", provider_enabled("snippets"), True)
    c.check("vimtex provider enabled after '\\cnec'", provider_enabled("vimtex"), True)
    c.check("menu shown after '\\cnec'", v.menu_visible(), True)

    v.reset_tail(scratch)
    v.type(" \\cite{che")
    c.check("vimtex provider enabled inside '\\cite{'", provider_enabled("vimtex"), True)
    c.check("menu shown inside '\\cite{'", v.menu_visible(), True)

    v.reset_tail(scratch)
    v.type(" \\ref{sec")
    c.check("vimtex provider enabled inside '\\ref{'", provider_enabled("vimtex"), True)

    v.reset_tail(scratch)
    v.type(" ordinary prose words")
    c.check("snippets provider OFF in plain prose", provider_enabled("snippets"), False)
    c.check("vimtex provider OFF in plain prose", provider_enabled("vimtex"), False)
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
    # arguments above never noticed).  The window is 300 now; these pin it.
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
    c.check("vimtex provider enabled deep in a 75-char \\cite key list",
            provider_enabled("vimtex"), True)
    park_at_eol(" \\cite[see the extended discussion in chapter four "
                "of the second essay]{vonw")
    c.check("vimtex provider enabled after a long optional argument",
            provider_enabled("vimtex"), True)
    v.escape()

    c.check("LuaSnip french-logic snippets still loaded",
            v.lua("local t = require('luasnip').get_snippets('french-logic') "
                  "return (t and #t or 0) > 0"), True)
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

sys.exit(c.report())
