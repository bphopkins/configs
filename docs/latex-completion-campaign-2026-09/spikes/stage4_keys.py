#!/usr/bin/env python3
r"""Stage 4, measurement 1 (build chat 4, 2026-09-13): per-keystroke cost inside a command name and
in prose, spike4's method (one character, synchronous redraw, 0.4 s gaps, the end of the fixture's
longest line), on the live tree and on the scratch copy of the committed pre-campaign tree (HEAD
1bb69b1: latex-workshop.lua + french-logic.lua, 1,054 snippets), interleaved repetitions, with
in-process attribution per request (luasnip source, fuzzy, the live transform).  The first request
is warmed untimed; stage4_first.py measures it apart.  Harness only, read-only."""
import sys, time, statistics
from stage4lib import Nvim, BEFORE, install_hooks, pct

GAP = 0.4
WORDS = ("frac", "alpha", "subseteq", "begin", "textit", "mathcal")
PROSE = "the quick brown fox jumps"
REPS = int(sys.argv[1]) if len(sys.argv) > 1 else 3


def timed(v, untimed, timed_keys):
    out = []
    for k in untimed:
        v.nvim.input(k); v.cmd("redraw"); time.sleep(GAP)
    for k in timed_keys:
        time.sleep(GAP)
        t = time.perf_counter(); v.nvim.input(k); v.cmd("redraw")
        out.append((time.perf_counter() - t) * 1000)
    return out


def run(tree, label):
    v = Nvim(config_home=tree).open_fixture()
    try:
        longest = v.para_lines()[-1][0]
        orig = v.eval("getline(%d)" % longest)
        def restore():
            v.lua("local l, t = ...; vim.api.nvim_buf_set_lines(0, l - 1, l, false, { t })", longest, orig)
        impl = install_hooks(v)
        n0 = v.goto_end_of(longest); v.insert()
        timed(v, [" ", "\\", "f", "r"], []); v.escape(); restore()  # warm-up, untimed
        v.lua("_G.ACC = _G.newacc()")
        n1 = v.goto_end_of(longest); v.insert()
        cmd = []
        for w in WORDS:
            cmd += timed(v, [" ", "\\"], list(w))
        v.escape(); restore()
        a = v.lua("return _G.ACC")
        v.lua("_G.ACC = _G.newacc()")
        n2 = v.goto_end_of(longest); v.insert()
        prose = timed(v, [" "], list(PROSE))
        v.escape(); restore()
        p = v.lua("return _G.ACC")
        nrows = v.lua("local ls = require('luasnip'); local n = 0 "
                      "for _, ft in ipairs(require('luasnip.util.util').get_snippet_filetypes()) do n = n + #ls.get_snippets(ft) end "
                      "return n")
        req = max(a["n"], 1)
        print(f"{label}: {nrows} rows reachable, fuzzy={impl}, line {n0}/{n1}/{n2} chars")
        print(f"  command-name keystrokes ({len(cmd)}): median {statistics.median(cmd):.1f} ms, "
              f"p90 {pct(cmd, 0.9):.1f}, max {max(cmd):.1f}   per request: source {a['src']/req:.1f} ms, "
              f"fuzzy {a['fuzzy']/max(a['nfz'],1):.1f} ms/call ({a['nfz']} calls), transform {a['xform']/max(a['nx'],1):.2f} ms "
              f"({a['n']} requests, ft_func {a['ft']/max(a['nft'],1):.2f} ms x{a['nft']})")
        print(f"  prose keystrokes ({len(prose)}):       median {statistics.median(prose):.1f} ms, "
              f"p90 {pct(prose, 0.9):.1f}, max {max(prose):.1f}   (snippet requests: {p['n']}, fuzzy calls: {p['nfz']}, ft_func calls: {p['nft']} = {p['ft']:.2f} ms)")
        sys.stdout.flush()
        return cmd, prose
    finally:
        v.close()


res = {"before": [], "after": []}
for i in range(REPS):
    res["before"].append(run(BEFORE, f"before #{i+1}"))
    res["after"].append(run(None, f"after  #{i+1}"))
print("\nsummary (median over repetitions of each repetition's median / p90):")
for k in ("before", "after"):
    cm = [statistics.median(c) for c, _ in res[k]]; cp = [pct(c, 0.9) for c, _ in res[k]]
    pm = [statistics.median(p) for _, p in res[k]]; pp = [pct(p, 0.9) for _, p in res[k]]
    print(f"  {k:7s} command-name median {statistics.median(cm):.0f} (p90 {statistics.median(cp):.0f})   "
          f"prose median {statistics.median(pm):.0f} (p90 {statistics.median(pp):.0f})")
