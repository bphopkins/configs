#!/usr/bin/env python3
r"""Stage 4, the cold package cache.  The live tree with VimTeX's cache root pointed at an empty scratch
directory: wall time to the menu for ` \begin{a` and ` \usepackage{a`, first and second in the
session; a second instance on the same root (cross-session warm); then vimtex-warm run on a scratch
copy of the fixture into a third root, and an instance on that root."""
import os, subprocess, sys, tempfile, time, shutil
from stage4lib import Nvim, S, wait_menu

FIXDIR = tempfile.mkdtemp(prefix="stage4-fix-")
for _f in ("fixture.tex", "fixture.bib"):
    shutil.copy2(os.path.expanduser("~/Desktop/configs/tests/nvim-latency/" + _f), FIXDIR)
FIX = os.path.join(FIXDIR, "fixture.tex")


def menu_time(v, last, untimed, key):
    v.reset_tail(last, "Scratch.")
    for k in untimed:
        v.nvim.input(k); v.cmd("redraw"); time.sleep(0.3)
    t0 = time.perf_counter()
    v.nvim.input(key); v.cmd("redraw")
    t = wait_menu(v, t0, limit=120)
    time.sleep(0.5)
    n = v.lua("return #(require('blink.cmp.completion.list').items or {})")
    v.escape()
    return t * 1000, n


def session(root, label):
    v = Nvim(cache_root=root).open_fixture()
    try:
        last = v.eval("line('$')")
        pk = v.lua("return vim.b.vimtex and vim.tbl_count(vim.b.vimtex.packages) or -1")
        out = [f"{label} ({pk} packages in VimTeX's table)"]
        for name, keys in (("\\begin{a", (" ", "\\", "b", "e", "g", "i", "n", "{")), ("\\usepackage{a", tuple(" \\usepackage{"))):
            for i in (1, 2):
                ms, n = menu_time(v, last, list(keys), "a")
                out.append(f"   {name} #{i}: {ms:.0f} ms to the menu, {n} rows")
        print("\n".join(out)); sys.stdout.flush()
    finally:
        v.close()


def listing(root):
    return ", ".join(f"{f} {os.path.getsize(os.path.join(root, f))//1024} KB" for f in sorted(os.listdir(root)))


cold = tempfile.mkdtemp(prefix="stage4-cache-cold-")
session(cold, "cold root, instance 1")
print("   cache after:", listing(cold))
session(cold, "same root, instance 2")
warmed = tempfile.mkdtemp(prefix="stage4-cache-warmed-")
t0 = time.time()
r = subprocess.run(["bash", os.path.expanduser("~/Desktop/configs/bin/vimtex-warm"), FIX],
                   env=dict(os.environ, VIMTEX_CACHE=warmed), capture_output=True, text=True)
print(f"vimtex-warm on the fixture copy into a fresh root: {time.time()-t0:.0f} s, exit {r.returncode}\n   " + r.stdout.strip().replace("\n", "\n   "))
print("   cache after:", listing(warmed))
session(warmed, "vimtex-warm'd root, instance 3")
for d in (cold, warmed, FIXDIR):
    shutil.rmtree(d, ignore_errors=True)
