#!/usr/bin/env python3
"""Measure insert-mode keystroke latency, and attribute it.

This is a measurement tool, not a pass/fail gate — timings depend on the
machine, the power profile and whatever else is running, so nothing here is
asserted.  `verify.py` guards the structure; this tells you the numbers.

    ./bench.py                     # cost vs. logical line length, on the fixture
    ./bench.py --ablate            # attribute the cost to each subsystem
    ./bench.py --file FILE.tex     # measure a real document instead
    ./bench.py --config DIR        # measure a different Neovim config tree

How it measures: feed one character, then a synchronous `redraw`, which
returns only once Neovim has processed the input and painted.  A gap is left
between keystrokes so that deferred work triggered by one character is paid
before the next is timed — and because a pause is when a slow-ramping CPU
governor bites, which is how prose actually gets written.

Reference numbers, fedxps (i7-7700HQ, tuned `powersave`), 2026-08-22, median
ms per keystroke.  On the real `dissertation/completeness/completeness.tex`:

    line length      585   1001   1417   1860
    before the fix    44     82    262    218
    after             13     23     84     54

On this suite's own fixture, which is deliberately denser in math and
french-logic macros than real prose, so the absolutes run higher while the
ratio holds:

    line length      837   1251   1665   2079
    before the fix   169    273    315    390
    after             64     99    119    149

For scale: `nvim -u NONE` on the same 1860-char line is 3.6 ms.  Compare
against that, not against zero.
"""

import argparse
import os
import shutil
import statistics
import sys
import tempfile
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from harness import Nvim

TEXT = "the quick brown fox jumps over the lazy dog and more words follow "
DEL = "local function del(n) pcall(vim.api.nvim_del_augroup_by_name, n) end\n"

ABLATIONS = [
    ("baseline (config as it is)", {}, ""),
    ("- VimTeX matchparen", {"vimtex_matchparen_enabled": 0}, ""),
    ("- builtin matchparen", {"loaded_matchparen": 1}, DEL + "del('matchparen')"),
    ("- blink entirely", {}, "vim.g.completion=false; vim.b.completion=false"),
    ("- custom syntax cmds", {"vimtex_syntax_custom_cmds": []}, ""),
    ("- all syntax", {}, "vim.cmd('syntax off')"),
]


def measure(v, lnum, n, gap):
    v.goto_end_of(lnum)
    v.insert()
    out = []
    for i in range(n):
        time.sleep(gap)
        t = time.perf_counter()
        v.nvim.input(TEXT[i % len(TEXT)])
        v.cmd("redraw")
        out.append((time.perf_counter() - t) * 1000)
    v.escape()
    v.cmd("silent! undo")
    return out


def open_target(args, gvars=None, post=""):
    v = Nvim(config_home=args.config, gvars=gvars or {})
    if args.file:
        v.cmd("edit " + os.path.abspath(args.file))
        v.cmd("redraw")
    else:
        v.open_fixture()
    if post:
        v.lua(post)
    return v


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ablate", action="store_true",
                    help="attribute the cost subsystem by subsystem")
    ap.add_argument("--file",
                    help="measure this document instead of the fixture "
                         "(a throwaway copy of it — the original is never opened)")
    ap.add_argument("--config", help="a different Neovim config tree (XDG_CONFIG_HOME)")
    ap.add_argument("-n", type=int, default=14, help="keystrokes per sample")
    ap.add_argument("--gap", type=float, default=0.4,
                    help="seconds between keystrokes (0.4 ~ thoughtful prose)")
    args = ap.parse_args()

    # Measure a COPY, never the file itself.  measure() types characters into
    # the buffer and undoes them afterwards, but the undo does not reach disk:
    # an auto-save on InsertLeavePre has already written the typed text, so a
    # run against a real document leaves the filler string on every long line
    # it visits — and an interrupted run leaves it with no undo at all.  The
    # copy keeps the content, the line lengths and the .tex filetype, so the
    # numbers are unchanged, while nothing can reach the original.
    if args.file:
        src = os.path.abspath(args.file)
        with tempfile.TemporaryDirectory(prefix="nvim-latency-") as td:
            dst = os.path.join(td, os.path.basename(src))
            shutil.copyfile(src, dst)
            args.file = dst
            return _run(args)
    return _run(args)


def _run(args):
    if args.ablate:
        v = open_target(args)
        lnum = v.para_lines()[-1][0]
        length = v.goto_end_of(lnum)
        v.close()
        print(f"attribution at the end of a {length}-char logical line "
              f"({args.n} keystrokes, {args.gap * 1000:.0f} ms apart)\n")
        print(f"{'configuration':32s} {'p50':>7s} {'p90':>7s} {'mean':>7s}")
        print("-" * 56)
        for label, gvars, post in ABLATIONS:
            v = open_target(args, gvars, post)
            try:
                ln = v.para_lines()[-1][0]
                s = measure(v, ln, args.n, args.gap)
            finally:
                v.close()
            ss = sorted(s)
            print(f"{label:32s} {statistics.median(s):7.0f} "
                  f"{ss[int(len(ss) * 0.9)]:7.0f} {statistics.mean(s):7.0f}")
            sys.stdout.flush()
        print("\nNote: these do not sum. Turning off syntax also removes the\n"
              "syntax lookups matchparen and completion perform.")
        return

    v = open_target(args)
    try:
        paras = v.para_lines()
        print(f"keystroke latency by logical line length "
              f"({args.n} keystrokes, {args.gap * 1000:.0f} ms apart)\n")
        print(f"{'line length':>12s} {'p50 ms':>8s} {'p90 ms':>8s} {'mean ms':>8s}")
        print("-" * 40)
        for lnum, _ in paras:
            s = measure(v, lnum, args.n, args.gap)
            ss = sorted(s)
            length = v.goto_end_of(lnum)
            print(f"{length:12d} {statistics.median(s):8.0f} "
                  f"{ss[int(len(ss) * 0.9)]:8.0f} {statistics.mean(s):8.0f}")
            sys.stdout.flush()
    finally:
        v.close()


if __name__ == "__main__":
    main()
