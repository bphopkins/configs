#!/usr/bin/env python3
r"""The backslash keystroke.  At the end of the fixture's longest line, closure in place (the
pre-warm waited for where it exists), ten backslashes each followed by a space, both timed, with
the in-process counters: does a lone backslash cost a completion request?  Both trees."""
import time, statistics
from stage4lib import Nvim, BEFORE, install_hooks, pct

GAP = 0.4


def run(tree, label):
    v = Nvim(config_home=tree).open_fixture()
    try:
        longest = v.para_lines()[-1][0]
        orig = v.eval("getline(%d)" % longest)
        restore = lambda: v.lua("local l, t = ...; vim.api.nvim_buf_set_lines(0, l - 1, l, false, { t })", longest, orig)
        install_hooks(v)
        t0 = time.time()
        while not tree and time.time() - t0 < 15 and not v.lua("local ok, L = pcall(require, 'snippets.loader'); local p = ok and L.prewarm and L.prewarm[vim.api.nvim_get_current_buf()]; return (p and p.done) and true or false"):
            time.sleep(0.1)
        v.goto_end_of(longest); v.insert()
        for k in " \\fr":
            v.nvim.input(k); v.cmd("redraw"); time.sleep(GAP)
        v.escape(); restore()
        v.lua("_G.ACC = _G.newacc()")
        v.goto_end_of(longest); v.insert()
        v.nvim.input(" "); v.cmd("redraw"); time.sleep(GAP)
        bs, sp = [], []
        for _ in range(10):
            t = time.perf_counter(); v.nvim.input("\\"); v.cmd("redraw"); bs.append((time.perf_counter() - t) * 1000)
            time.sleep(GAP)
            t = time.perf_counter(); v.nvim.input(" "); v.cmd("redraw"); sp.append((time.perf_counter() - t) * 1000)
            time.sleep(GAP)
        a = v.lua("return _G.ACC")
        v.escape(); restore()
        print(f"{label}: backslash median {statistics.median(bs):.0f} ms (p90 {pct(bs, 0.9):.0f}), the space after it {statistics.median(sp):.0f} ms; "
              f"over the 20 keystrokes: {a['n']} snippet requests ({a['src']:.0f} ms), {a['nfz']} fuzzy calls ({a['fuzzy']:.0f} ms), transform {a['xform']:.1f} ms, ft_func {a['nft']} calls")
        print("   menu visible after a lone backslash:", v.lua("return require('blink.cmp').is_visible()"))
    finally:
        v.close()


run(BEFORE, "before")
run(None, "after ")
