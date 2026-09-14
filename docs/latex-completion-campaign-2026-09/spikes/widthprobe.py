# Read-only probe on the harness's throwaway fixture: does an in-place change of
# blink's label_description width redraw the menu?  Prints the rendered menu lines.
import sys, os, time
sys.path.insert(0, os.path.expanduser("~/Desktop/configs/tests/nvim-latency"))
from harness import Nvim
v = Nvim(); v.open_fixture()
last = v.lua("return vim.api.nvim_buf_line_count(0)")
MENU = """
  local ok, menu = pcall(require, 'blink.cmp.completion.windows.menu')
  if not ok or not menu.win then return { 'no menu module' } end
  local buf = menu.win.buf or (menu.win.get_buf and menu.win:get_buf())
  if not buf or not vim.api.nvim_buf_is_valid(buf) then return { 'no menu buf' } end
  return vim.api.nvim_buf_get_lines(buf, 0, 4, false)
"""
def show(tag):
    v.reset_tail(last, "Probe line.")
    v.type("\\DeclareFontSh", per=0.25, settle=1.5)
    print(tag, "visible:", v.menu_visible())
    for l in v.lua(MENU): print("   |" + l + "|")
    v.escape()
show("width 30 (default)")
print("set:", v.lua("local c = require('blink.cmp.config').completion.menu.draw.components.label_description; c.width.max = 60; return c.width.max"))
show("width 60 (in place)")
print("reset:", v.lua("require('blink.cmp.config').completion.menu.draw.components.label_description.width.max = 30; return 30"))
show("width 30 again")
v.close()
