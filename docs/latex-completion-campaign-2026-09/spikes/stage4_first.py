#!/usr/bin/env python3
r"""Stage 4, measurement 3 (corrected): the first keystrokes of a session, and memory.  blink asks
LuaSnip whether a snippet is expandable on every insert-mode event, and that asks the loader for the
buffer's filetypes, so the closure loads on the first insert-mode keystroke of the session, whatever
it is.  Open the fixture, park on a scratch line in normal mode, then time each keystroke to its
redraw: `a` (enter insert), space, backslash, `f` (the first completion request, to the menu); the
in-process first-call costs after each; memory (Lua heap after a full collect, RSS) before and
after; then a second ` \f` request.  Both trees, fresh instances.  Hooks installed without entering
insert mode (blink loads on require through lazy.nvim)."""
import sys, time, statistics
from stage4lib import Nvim, BEFORE, HOOKS, mem, wait_menu

REPS = int(sys.argv[1]) if len(sys.argv) > 1 else 3
LIVE_ONLY = "live" in sys.argv[2:]
WAIT = "wait" in sys.argv[2:]  # wait for the loader's idle pre-warm before the first keystroke


def park(v, last):
    v.lua("local l = ...; vim.api.nvim_buf_set_lines(0, l - 1, l, false, { 'Scratch.' }); "
          "vim.api.nvim_win_set_cursor(0, { l, 0 }); vim.cmd('normal! $')", last)
    v.cmd("redraw")


def key(v, k, to_menu=False):
    t0 = time.perf_counter()
    v.nvim.input(k); v.cmd("redraw")
    t_redraw = (time.perf_counter() - t0) * 1000
    t_menu = wait_menu(v, t0) * 1000 if to_menu else -1
    time.sleep(0.5)
    acc = v.lua("return _G.ACC")
    return t_redraw, t_menu, acc


def run(tree, label):
    v = Nvim(config_home=tree).open_fixture()
    try:
        pid = v.lua("return vim.uv.os_getpid()")
        last = v.eval("line('$')")
        park(v, last)
        v.lua(HOOKS)
        if WAIT:
            t0 = time.time()
            while time.time() - t0 < 20 and not v.lua("local p = (require('snippets.loader').prewarm or {})[vim.api.nvim_get_current_buf()] return (p and p.done) and true or false"):
                time.sleep(0.05)
            print(f"   (pre-warm done after {time.time()-t0:.1f} s of waiting: {v.lua('local p = require(\"snippets.loader\").prewarm[vim.api.nvim_get_current_buf()] return p and (p.files .. \" files in \" .. math.floor(p.ms) .. \" ms\") or \"no\"')})")
        h0, r0 = mem(v, pid)
        seq = []
        for k, name, menu in (("a", "a (enter insert)", False), (" ", "space", False), ("\\", "backslash", False), ("f", "f (first request)", True)):
            rd, m, acc = key(v, k, menu)
            seq.append((name, rd, m, acc))
        n1 = v.lua("return #(require('blink.cmp.completion.list').items or {})")
        v.escape()
        h1, r1 = mem(v, pid)
        park(v, last)
        v.nvim.input("a"); v.cmd("redraw"); time.sleep(0.3)
        for k in (" ", "\\"):
            v.nvim.input(k); v.cmd("redraw"); time.sleep(0.3)
        a = v.lua("return _G.ACC")
        rd2, m2, b = key(v, "f", True)
        v.escape()
        parts = []
        for name, rd, m, acc in seq:
            parts.append(f"{name}: {rd:.0f} ms" + (f" (menu at {m:.0f} ms)" if m >= 0 else ""))
        acc = seq[-1][3]
        print(f"{label}: " + "; ".join(parts) + f"; {n1} rows")
        print(f"   first calls: ft_func {acc['first_ft']:.0f} ms, source {acc['first_src']:.0f} ms, transform {acc['first_xform']:.1f} ms, "
              f"fuzzy {acc['first_fuzzy']:.1f} ms; ft_func calls so far {acc['nft']} ({acc['ft']:.0f} ms), fuzzy calls {acc['nfz']}")
        print(f"   second ` \\f` request: f {rd2:.0f} ms (menu at {m2:.0f} ms); source {b['src']-a['src']:.1f} ms, transform {b['xform']-a['xform']:.2f} ms, fuzzy {b['fuzzy']-a['fuzzy']:.1f} ms")
        print(f"   memory: Lua heap {h0:.0f} -> {h1:.0f} MB after a full collect, RSS {r0:.0f} -> {r1:.0f} MB")
        sys.stdout.flush()
        return seq[0][1], seq[3][2], m2, h1 - h0, r1 - r0
    finally:
        v.close()


res = {"before": [], "after": []}
for i in range(REPS):
    if not LIVE_ONLY:
        res["before"].append(run(BEFORE, f"before #{i+1}"))
    res["after"].append(run(None, f"after  #{i+1}"))
print("\nsummary (medians): first insert keystroke ms, first request ms to menu, second request, heap delta MB, RSS delta MB")
for k in (("after",) if LIVE_ONLY else ("before", "after")):
    cols = list(zip(*res[k]))
    print(f"  {k:7s} " + "  ".join(f"{statistics.median(c):.0f}" for c in cols))
