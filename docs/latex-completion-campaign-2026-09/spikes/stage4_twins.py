#!/usr/bin/env python3
r"""Sink 0 against 5 on triggers that carry both a typical and an unusual row: does blink's sort text
(priority-derived) already put the typical row first at sink 0?  Rows at ` \Autocit`, ` \RequirePack`
and ` \addtocoun` with label, description, score and offset, under each sink (emulated as in
stage4_sink.py), fresh XDG_STATE_HOME."""
import os, sys, time, tempfile, shutil
from stage4lib import Nvim, rows

WRAP = open("stage4_sink.py").read().split('WRAP = r"""')[1].split('"""')[0]
for sink in (0, 5):
    state = tempfile.mkdtemp(prefix="stage4-twins-")
    os.environ["XDG_STATE_HOME"] = state
    v = Nvim().open_fixture()
    try:
        last = v.eval("line('$')")
        v.insert(); v.escape(); v.lua(WRAP, sink)
        print(f"sink {sink}:")
        for typed in (" \\Autocit", " \\RequirePack", " \\addtocoun"):
            v.reset_tail(last, "Scratch."); v.type(typed, settle=1.2)
            for i, r in enumerate(rows(v, 6), 1):
                print(f"   {typed.strip():14s} {i}. {r[0]:18s} {r[2]:42s} score {r[3]:.0f} offset {r[4]}")
            v.escape()
    finally:
        v.close(); os.environ.pop("XDG_STATE_HOME", None); shutil.rmtree(state, ignore_errors=True)
