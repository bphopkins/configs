import os, sys, time
sys.path.insert(0, os.path.expanduser("~/Desktop/configs/tests/nvim-latency"))
from harness import Nvim
v = Nvim().open_fixture()
try:
    scratch = v.eval("line('$')")
    def keys(*ks, settle=0.6):
        for k in ks:
            v.nvim.input(k); v.cmd("redraw"); time.sleep(settle)
    def items():
        return v.lua("""
          local ok, list = pcall(require, 'blink.cmp.completion.list')
          if not ok then return {'no-list-module'} end
          local out = {}
          for i, it in ipairs(list.items or {}) do
            if i > 8 then break end
            out[#out+1] = (it.label or '?') .. ' <' .. (it.source_id or it.source_name or '?') .. '>'
          end
          return out
        """)
    # 1. environment row accepted inside \begin{
    v.reset_tail(scratch, "Scratch.")
    v.type(" \\begin{ali")
    print("menu visible after \\begin{ali:", v.menu_visible())
    print("rows:", items())
    keys("<CR>", settle=1.0)
    print("after <CR>:", repr(v.eval("getline('.')")), "| next lines:", v.eval("getline(line('.')+1, line('.')+2)"))
    v.escape()
    # 2. the same row reached from a bare backslash
    v.reset_tail(scratch, "Scratch.")
    v.type(" \\alig")
    print("rows after \\alig:", items())
    keys("<CR>", settle=1.0)
    print("after <CR>:", repr(v.eval("getline('.')")), "| next lines:", v.eval("getline(line('.')+1, line('.')+2)"))
    v.escape()
    # 3. inside \cite{ today
    v.reset_tail(scratch, "Scratch.")
    v.type(" \\cite{che")
    print("menu visible inside \\cite{che:", v.menu_visible(), "| first rows:", items()[:5], "| count:",
          v.lua("local ok,l=pcall(require,'blink.cmp.completion.list'); return ok and #(l.items or {}) or -1"))
    v.escape()
finally:
    v.close()
