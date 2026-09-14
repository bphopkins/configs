#!/usr/bin/env python3
r"""Stage 4: the per-keystroke snippet check.  blink's luasnip preset answers `snippets.active()` by
asking LuaSnip whether the text before the cursor is an expandable snippet (`is_hidden_snippet`),
on every InsertCharPre and TextChangedI; LuaSnip matches every registered trigger of the buffer's
pseudo-filetypes against the line.  Measured here on the live tree at the end of the fixture's
longest line, closure warm: prose keystrokes as shipped, then with a candidate `active` that keeps
the expandable check for <Tab>/<S-Tab> only (a filter with a direction), then `ls.expandable()`
alone; and the one corner the check serves, <Tab> after a fully typed trigger with the menu closed,
under both."""
import time, statistics
from stage4lib import Nvim, install_hooks, pct

GAP = 0.4
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


def prose(v, longest):
    v.goto_end_of(longest); v.insert()
    v.nvim.input(" "); v.cmd("redraw"); time.sleep(GAP)
    out = []
    for ch in "the quick brown fox jumps":
        time.sleep(GAP); t = time.perf_counter(); v.nvim.input(ch); v.cmd("redraw")
        out.append((time.perf_counter() - t) * 1000)
    v.escape()
    return out


def tab_corner(v, last):
    v.reset_tail(last, "Scratch.")
    v.type(" \\frac", settle=1.0)
    vis = v.menu_visible()
    v.nvim.input("<C-e>"); v.cmd("redraw"); time.sleep(0.5)
    hidden = not v.menu_visible()
    v.nvim.input("<Tab>"); v.cmd("redraw"); time.sleep(0.8)
    line = v.eval("getline('.')")
    v.escape()
    v.reset_tail(last, "Scratch.")
    v.nvim.input("<Tab>"); v.cmd("redraw"); time.sleep(0.5)
    plain = v.eval("getline('.')")
    v.escape()
    return vis, hidden, line, plain


v = Nvim().open_fixture()
try:
    longest = v.para_lines()[-1][0]
    last = v.eval("line('$')")
    orig = v.eval("getline(%d)" % longest)
    restore = lambda: v.lua("local l, t = ...; vim.api.nvim_buf_set_lines(0, l - 1, l, false, { t })", longest, orig)
    install_hooks(v)
    v.goto_end_of(longest); v.insert()
    for k in " \\fr":
        v.nvim.input(k); v.cmd("redraw"); time.sleep(GAP)
    v.escape(); restore()
    v.lua("_G.ACC = _G.newacc()")
    xs = prose(v, longest); a = v.lua("return _G.ACC"); restore()
    print(f"as shipped:        prose median {statistics.median(xs):.1f} ms, p90 {pct(xs, 0.9):.1f}; ft_func calls {a['nft']}")
    exp = v.lua(r"""
      local l = ...
      vim.api.nvim_win_set_cursor(0, { l, 0 }); vim.cmd('normal! $')
      local ls = require('luasnip')
      local t0 = vim.uv.hrtime(); local r
      for _ = 1, 20 do r = ls.expandable() end
      return { (vim.uv.hrtime() - t0) / 20e6, r }
    """, longest)
    print(f"ls.expandable() alone at the end of the longest line: {exp[0]:.2f} ms per call (expandable={exp[1]})")
    print("corner as shipped (menu visible, <C-e> hides, <Tab> after \\frac; then <Tab> on a plain line):", tab_corner(v, last))
    v.lua(OVERRIDE); v.lua("_G.ACC = _G.newacc()")
    xs = prose(v, longest); a = v.lua("return _G.ACC"); restore()
    print(f"candidate active(): prose median {statistics.median(xs):.1f} ms, p90 {pct(xs, 0.9):.1f}; ft_func calls {a['nft']}")
    print("corner with the candidate:", tab_corner(v, last))
    # <Tab> inside an expanded snippet still jumps
    v.reset_tail(last, "Scratch."); v.type(" \\frac", settle=1.0); v.nvim.input("<CR>"); v.cmd("redraw"); time.sleep(0.8)
    v.nvim.input("A"); v.cmd("redraw"); time.sleep(0.3); v.nvim.input("<Tab>"); v.cmd("redraw"); time.sleep(0.5); v.nvim.input("B"); v.cmd("redraw"); time.sleep(0.5)
    print("accept \\frac, type A, <Tab>, type B with the candidate:", repr(v.eval("getline('.')")))
    v.escape()
finally:
    v.close()
