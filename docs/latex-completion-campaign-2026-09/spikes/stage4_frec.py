#!/usr/bin/env python3
r"""Does blink's frecency record and score an accepted snippet row?  Fresh XDG_STATE_HOME (variant
A: nothing pre-created; variant B: nvim/blink/cmp created first); blink's fuzzy.access wrapped to
count calls; at ` \AmS` accept \AmSfont (rank 2: <C-n>, <CR>) twice, reading scores after each; then
has_init_db, the store path, whether the file exists and its size."""
import os, sys, time, tempfile, shutil
from stage4lib import Nvim, S, rows

for variant in ("A: bare state dir", "B: nvim/blink/cmp pre-created"):
    state = tempfile.mkdtemp(prefix="stage4-frec-")
    if variant.startswith("B"):
        os.makedirs(os.path.join(state, "nvim", "blink", "cmp"))
    os.environ["XDG_STATE_HOME"] = state
    v = Nvim().open_fixture()
    try:
        last = v.eval("line('$')")
        v.insert(); v.escape()
        v.lua(r"""
          local fz = require('blink.cmp.fuzzy'); local oa = fz.access; _G.ACCESS = {}
          fz.access = function(item) _G.ACCESS[#_G.ACCESS + 1] = item.label or '?'; return oa(item) end
        """)
        def snap():
            v.reset_tail(last, "Scratch."); v.type(" \\AmS", settle=1.2)
            r = rows(v, 10)
            return {x[0]: (i, x[3]) for i, x in enumerate(r, 1) if x[0] in ("\\AmS", "\\AmSfont")}
        out = [f"{variant}: fresh {snap()}"]
        v.escape()
        for k in (1, 2):
            v.reset_tail(last, "Scratch."); v.type(" \\AmS", settle=1.2)
            v.nvim.input("<C-n>"); v.cmd("redraw"); time.sleep(0.3)
            v.nvim.input("<CR>"); v.cmd("redraw"); time.sleep(0.8)
            line = v.eval("getline('.')"); v.escape()
            out.append(f"   accept {k}: line {line!r}; access calls so far {v.lua('return _G.ACCESS')}; then {snap()}")
            v.escape()
        info = v.lua(r"""
          local fz = require('blink.cmp.fuzzy'); local cfg = require('blink.cmp.config')
          local p = cfg.fuzzy.frecency.path
          return { has_init_db = fz.has_init_db and true or false, enabled = cfg.fuzzy.frecency.enabled, path = p,
                   exists = vim.fn.filereadable(p) == 1, size = vim.fn.getfsize(p), impl = fz.implementation_type,
                   state = vim.fn.stdpath('state') }
        """)
        out.append(f"   {info}")
        print("\n".join(out)); sys.stdout.flush()
    finally:
        v.close()
        os.environ.pop("XDG_STATE_HOME", None)
        print("   state dir after close:", [os.path.join(dp[len(state):], f) for dp, _, fs in os.walk(state) for f in fs][:12])
        shutil.rmtree(state, ignore_errors=True)
