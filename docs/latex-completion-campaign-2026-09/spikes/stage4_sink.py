#!/usr/bin/env python3
r"""Stage 4, the sink constant against frecency.  A fresh frecency store per condition (XDG_STATE_HOME
under the scratchpad), the live tree.  At ` \AmS` the rank and score of \AmS and \AmSfont are read;
\AmSfont is accepted (selected with <C-n>, accepted with <CR>) three times, the ranks re-read after
each.  Conditions: sink 0, 3, 5 (live), 8, 10, emulated by re-assigning the sunk rows' offset after
the live transform (a sunk row leaves it at 5 = 10 - SINK)."""
import os, sys, time, tempfile, shutil
from stage4lib import Nvim, S, rows

SINKS = [int(x) for x in sys.argv[1:]] or [0, 3, 5, 8, 10]
WRAP = r"""
  local sink = ...
  local prov = require('blink.cmp.sources.lib').get_provider_by_id('snippets')
  local ot = prov.config.transform_items
  prov.config.transform_items = function(ctx, items)
    local out = ot(ctx, items)
    for _, it in ipairs(out) do
      if it.data and it.data.snip_id and (it.score_offset == 5 or it.score_offset == 10 - sink) then
        local sn = require('luasnip').get_id_snippet(it.data.snip_id)
        if sn and (sn.effective_priority or 1000) < 1000 then it.score_offset = 10 - sink end
      end
    end
    return out
  end
  return require('blink.cmp.fuzzy').implementation_type
"""


def snapshot(v, last):
    v.reset_tail(last, "Scratch."); v.type(" \\AmS", settle=1.2)
    r = rows(v, 30)
    got = {}
    for i, (label, _, _, score, off) in enumerate(r, 1):
        if label in ("\\AmS", "\\AmSfont") and label not in got:
            got[label] = (i, score, off)
    return got, r


def accept_amsfont(v, last):
    got, _ = snapshot(v, last)
    rank = got["\\AmSfont"][0]
    for _ in range(rank - 1):
        v.nvim.input("<C-n>"); v.cmd("redraw"); time.sleep(0.25)
    v.nvim.input("<CR>"); v.cmd("redraw"); time.sleep(0.8)
    line = v.eval("getline('.')")
    v.escape()
    return "\\AmSfont" in line, line


for sink in SINKS:
    state = tempfile.mkdtemp(prefix="stage4-state-")
    os.environ["XDG_STATE_HOME"] = state
    v = Nvim().open_fixture()
    try:
        last = v.eval("line('$')")
        v.insert(); v.escape()
        impl = v.lua(WRAP, sink)
        got, r = snapshot(v, last); v.escape()
        line = [f"sink {sink:2d} (fuzzy={impl}): fresh: \\AmS rank {got['\\AmS'][0]} score {got['\\AmS'][1]:.0f}, \\AmSfont rank {got['\\AmSfont'][0]} score {got['\\AmSfont'][1]:.0f} (offset {got['\\AmSfont'][2]}), rows {len(r)}, first three {[x[0] for x in r[:3]]}"]
        for k in (1, 2, 3):
            ok, text = accept_amsfont(v, last)
            got, r = snapshot(v, last); v.escape()
            line.append(f"   after accept {k} ({'ok' if ok else 'NOT ACCEPTED: ' + text}): \\AmS rank {got['\\AmS'][0]} score {got['\\AmS'][1]:.0f}, \\AmSfont rank {got['\\AmSfont'][0]} score {got['\\AmSfont'][1]:.0f}; first three {[x[0] for x in r[:3]]}")
        print("\n".join(line)); sys.stdout.flush()
    finally:
        v.close()
        os.environ.pop("XDG_STATE_HOME", None)
        shutil.rmtree(state, ignore_errors=True)
