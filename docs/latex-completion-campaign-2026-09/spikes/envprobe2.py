import os, sys, time
sys.path.insert(0, os.path.expanduser("~/Desktop/configs/tests/nvim-latency"))
from harness import Nvim
v = Nvim().open_fixture()
try:
    scratch = v.eval("line('$')")
    def keys(*ks, settle=0.6):
        for k in ks:
            v.nvim.input(k); v.cmd("redraw"); time.sleep(settle)
    def items(n=8):
        return v.lua("""
          local n = ...
          local ok, list = pcall(require, 'blink.cmp.completion.list')
          if not ok then return {'no-list-module'} end
          local out = {}
          for i, it in ipairs(list.items or {}) do
            if i > n then break end
            out[#out+1] = (it.label or '?') .. ' <' .. (it.source_id or '?') .. '>' .. (it.labelDetails and it.labelDetails.description and (' ' .. it.labelDetails.description) or '')
          end
          return out
        """, n)
    v.reset_tail(scratch, "Scratch.")
    v.type(" \\begin{ali")
    print("line as typed:", repr(v.eval("getline('.')")))
    keys("<CR>", settle=1.0)
    l = v.eval("line('.')")
    print("after accept, lines -1..+1:", v.eval("getline(%d, %d)" % (l - 1, l + 1)))
    v.escape()
    # --- enable blink's built-in omni provider for tex at runtime and look at \begin{ again
    print("omni provider module:", v.lua("return require('blink.cmp.config').sources.providers.omni and require('blink.cmp.config').sources.providers.omni.module or 'absent'"))
    v.lua("require('blink.cmp.config').sources.per_filetype.tex = { 'omni', 'snippets', 'path' }")
    v.reset_tail(scratch, "Scratch.")
    v.type(" \\begin{ali")
    print("with omni, rows after \\begin{ali:", items(10))
    v.escape()
    v.reset_tail(scratch, "Scratch.")
    v.type(" \\ref{")
    print("with omni, rows after \\ref{:", items(6))
    v.escape()
    v.reset_tail(scratch, "Scratch.")
    v.type(" \\usepackage{amsm")
    print("with omni, rows after \\usepackage{amsm:", items(6))
    v.escape()
    v.reset_tail(scratch, "Scratch.")
    v.type(" \\fra")
    print("with omni, rows after \\fra (VimTeX cmd rows would duplicate snippets):", items(6))
    v.escape()
finally:
    v.close()
