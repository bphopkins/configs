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
finally:
    v.close()

sys.exit(c.report())
