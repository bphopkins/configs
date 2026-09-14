#!/usr/bin/env python3
r"""Stage 4, follow-up to measurement 1: who calls the loader's ft_func per keystroke in prose, and
what the pseudo-filetype set costs there.  Live tree: prose keystrokes at the end of the longest
fixture line with the closure warm, the first three ft_func call stacks captured; then the same with
ft_func returning {'tex'} alone (ablation), then restored; then the pre-campaign tree for reference."""
import time, statistics
from stage4lib import Nvim, BEFORE, install_hooks, pct

GAP = 0.4
TEXT = "the quick brown fox jumps"


def prose(v, longest):
    v.goto_end_of(longest); v.insert()
    v.nvim.input(" "); v.cmd("redraw"); time.sleep(GAP)
    out = []
    for ch in TEXT:
        time.sleep(GAP); t = time.perf_counter(); v.nvim.input(ch); v.cmd("redraw")
        out.append((time.perf_counter() - t) * 1000)
    v.escape()
    return out


def report(label, xs, acc):
    print(f"{label}: prose median {statistics.median(xs):.1f} ms, p90 {pct(xs, 0.9):.1f}; ft_func calls {acc['nft']} "
          f"({acc['ft']:.2f} ms in all), snippet requests {acc['n']}, fuzzy calls {acc['nfz']}")


v = Nvim().open_fixture()
try:
    longest = v.para_lines()[-1][0]
    orig = v.eval("getline(%d)" % longest)
    restore = lambda: v.lua("local l, t = ...; vim.api.nvim_buf_set_lines(0, l - 1, l, false, { t })", longest, orig)
    install_hooks(v)
    v.goto_end_of(longest); v.insert()
    for k in " \\fr":
        v.nvim.input(k); v.cmd("redraw"); time.sleep(GAP)
    v.escape(); restore()
    v.lua(r"""
      local L = require('snippets.loader'); local of = L.filetypes; _G.TB = {}
      L.filetypes = function(...) if #_G.TB < 3 then _G.TB[#_G.TB + 1] = debug.traceback('', 2) end; return of(...) end
      local S = require('luasnip.session'); local oft = S.config.ft_func; _G.NFT = 0
      S.config.ft_func = function(...) _G.NFT = _G.NFT + 1; return oft(...) end
    """)
    v.lua("_G.ACC = _G.newacc()")
    xs = prose(v, longest); acc = v.lua("return _G.ACC"); restore()
    report("live", xs, acc)
    print("   LuaSnip's ft_func called", v.lua("return _G.NFT"), "times")
    for i, tb in enumerate(v.lua("return _G.TB"), 1):
        lines = [l.strip() for l in tb.split("\n") if l.strip() and "stage4" not in l]
        print(f"   call stack {i}: " + " <- ".join(l.replace("/home/bph/.local/share/nvim/lazy/", "").replace("/home/bph/Desktop/configs/nvim/", "") for l in lines[1:9]))
    v.lua("require('luasnip.session').config.ft_func = function() return { 'tex' } end; _G.ACC = _G.newacc()")
    xs = prose(v, longest); acc = v.lua("return _G.ACC"); restore()
    report("ablation, ft_func -> {'tex'} only", xs, acc)
    v.lua("require('luasnip.session').config.ft_func = require('snippets.loader').ft_func; _G.ACC = _G.newacc()")
    xs = prose(v, longest); acc = v.lua("return _G.ACC"); restore()
    report("live again", xs, acc)
finally:
    v.close()
v = Nvim(config_home=BEFORE).open_fixture()
try:
    longest = v.para_lines()[-1][0]
    orig = v.eval("getline(%d)" % longest)
    install_hooks(v)
    v.lua(r"""local S = require('luasnip.session'); local oft = S.config.ft_func; _G.NFT = 0
      S.config.ft_func = function(...) _G.NFT = _G.NFT + 1; return oft(...) end""")
    v.lua("_G.ACC = _G.newacc()")
    xs = prose(v, longest); acc = v.lua("return _G.ACC")
    v.lua("local l, t = ...; vim.api.nvim_buf_set_lines(0, l - 1, l, false, { t })", longest, orig)
    report("before tree", xs, acc)
    print("   LuaSnip's ft_func called", v.lua("return _G.NFT"), "times")
finally:
    v.close()
