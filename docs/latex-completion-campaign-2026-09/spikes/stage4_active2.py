#!/usr/bin/env python3
r"""The <Tab> corners under the shipped `snippets.active` and under the candidate, each in a fresh
instance, LuaSnip's session cleared between corners.  A: ` \frac`, <C-e> hides the menu, <Tab>.
B: <Tab> on a plain line.  C: accept \frac with <CR>, type A, <Tab>, type B.  D: after C, <S-Tab>
then type C."""
import time
from stage4lib import Nvim

OVERRIDE = r"""
  local cfg = require('blink.cmp.config')
  cfg.snippets.active = function(filter)
    local ls = require('luasnip')
    if filter and filter.direction then
      return ls.jumpable(filter.direction)
        or (not require('blink.cmp').is_visible() and not ls.locally_jumpable(1) and ls.expandable())
    end
    return ls.locally_jumpable(1)
  end
"""
CLEAR = r"""
  local ls = require('luasnip')
  for _ = 1, 5 do if ls.in_snippet() or ls.jumpable(1) or ls.jumpable(-1) then pcall(ls.unlink_current) else break end end
  require('luasnip.session').current_nodes[vim.api.nvim_get_current_buf()] = nil
  return ls.jumpable(1)
"""


def corners(label, override):
    v = Nvim().open_fixture()
    try:
        last = v.eval("line('$')")
        v.insert(); v.escape()
        if override:
            v.lua(OVERRIDE)
        out = [label]
        def fresh():
            v.escape(); v.lua(CLEAR); v.reset_tail(last, "Scratch.")
        fresh(); v.type(" \\frac", settle=1.0)
        vis = v.menu_visible(); v.nvim.input("<C-e>"); v.cmd("redraw"); time.sleep(0.5); hid = not v.menu_visible()
        v.nvim.input("<Tab>"); v.cmd("redraw"); time.sleep(0.8)
        out.append(f"   A menu {vis}, hidden {hid}, <Tab> after \\frac: {v.eval(chr(103)+'etline(\".\")')!r}")
        fresh(); v.nvim.input("<Tab>"); v.cmd("redraw"); time.sleep(0.5)
        out.append(f"   B <Tab> on a plain line: {v.eval('getline(\".\")')!r}")
        fresh(); v.type(" \\frac", settle=1.0); v.nvim.input("<CR>"); v.cmd("redraw"); time.sleep(0.8)
        for k in ("A", "<Tab>", "B"):
            v.nvim.input(k); v.cmd("redraw"); time.sleep(0.4)
        out.append(f"   C accept, A, <Tab>, B: {v.eval('getline(\".\")')!r}")
        for k in ("<S-Tab>", "C"):
            v.nvim.input(k); v.cmd("redraw"); time.sleep(0.4)
        out.append(f"   D then <S-Tab>, C: {v.eval('getline(\".\")')!r}")
        v.escape()
        print("\n".join(out))
    finally:
        v.close()


corners("as shipped", False)
corners("candidate active()", True)
