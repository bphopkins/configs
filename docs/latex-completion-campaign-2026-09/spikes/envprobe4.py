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
          local out = {}
          for i, it in ipairs(list.items or {}) do
            if i > n then break end
            out[#out+1] = (it.label or '?') .. ' <' .. (it.source_id or '?') .. '>'
          end
          return out
        """, n)
    print("packages VimTeX knows in the fixture:", v.eval("sort(keys(b:vimtex.packages))"))
    v.lua("require('blink.cmp.config').sources.per_filetype.tex = { 'omni', 'snippets', 'path' }")
    for probe in (" \\begin{enum", " \\begin{cent", " \\begin{descr"):
        v.reset_tail(scratch, "Scratch.")
        v.type(probe, settle=1.5)
        print("rows after", repr(probe.strip()), "->", items(8))
        v.escape()
finally:
    v.close()
