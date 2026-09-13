import os, sys, time
sys.path.insert(0, os.path.expanduser("~/Desktop/configs/tests/nvim-latency"))
from harness import Nvim
v = Nvim().open_fixture()
try:
    scratch = v.eval("line('$')")
    def items(n=8):
        return v.lua("""
          local n = ...
          local ok, list = pcall(require, 'blink.cmp.completion.list')
          if not ok then return {'no-list-module'} end
          local out = {}
          for i, it in ipairs(list.items or {}) do
            if i > n then break end
            out[#out+1] = (it.label or '?') .. ' <' .. (it.source_id or '?') .. '>'
          end
          return out
        """, n)
    v.lua("require('blink.cmp.config').sources.per_filetype.tex = { 'omni', 'snippets', 'path' }")
    for attempt in (1, 2):
        v.reset_tail(scratch, "Scratch.")
        v.type(" \\begin{ali", settle=4.0)
        print("attempt", attempt, "rows after \\begin{ali:", items(12))
        t0 = time.time()
        start = v.eval("vimtex#complete#omnifunc(1, '')")
        res = v.eval("vimtex#complete#omnifunc(0, 'ali')")
        print("   raw omnifunc: start col", start, "->", len(res), "items in %.0f ms" % ((time.time() - t0) * 1000), [r.get('word') for r in res[:4]])
        v.escape()
finally:
    v.close()
