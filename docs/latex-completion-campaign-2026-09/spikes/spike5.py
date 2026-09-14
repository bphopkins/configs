# Harness probe, build chat 3 (2026-09-13): :SnippetsReload keeps counts and a hand-local row shadows a generated twin; both now pinned by the latency suite.
import os, sys, time
sys.path.insert(0, os.path.expanduser("~/Desktop/configs/tests/nvim-latency"))
from harness import Nvim
v = Nvim().open_fixture()
try:
    scratch = v.eval("line('$')")
    def rows(label):
        return v.lua("""
          local label = ...
          local l = require('blink.cmp.completion.list'); local out = {}
          for _, it in ipairs(l.items or {}) do
            if it.label == label then out[#out+1] = { it.label, (it.labelDetails and it.labelDetails.description) or '', it.data and it.data.snip_id or -1 } end
          end
          return out""", label)
    # 1. a first request registers the closure
    v.reset_tail(scratch, "Scratch."); v.type(" \\frac", settle=1.5)
    print("\\frac rows before shadow:", rows("\\frac"))
    v.escape()
    counts_before = v.lua("local ls = require('luasnip') return { tex = #ls.get_snippets('pkg-tex'), core = #ls.get_snippets('pkg-french-logic-core'), hand = #ls.get_snippets('hand-local'), all = #ls.get_snippets('pkg-latex-document') }")
    print("counts before reload:", counts_before)
    # 2. :SnippetsReload must leave counts unchanged (invalidated rows cleaned) and raise nothing
    v.lua("vim.cmd('silent! messages clear')")
    t0 = time.time(); v.cmd("SnippetsReload"); dt = time.time() - t0
    counts_after = v.lua("local ls = require('luasnip') return { tex = #ls.get_snippets('pkg-tex'), core = #ls.get_snippets('pkg-french-logic-core'), hand = #ls.get_snippets('hand-local'), all = #ls.get_snippets('pkg-latex-document') }")
    print("counts after reload:", counts_after, "in %.2f s" % dt)
    print("messages after reload:", repr(v.lua("return vim.trim(vim.fn.execute('messages'))"))[:300])
    v.reset_tail(scratch, "Scratch."); v.type(" \\frac", settle=1.5)
    print("\\frac rows after reload (one row, fresh id):", rows("\\frac"))
    v.escape()
    # 3. a hand-local row with the same label and description shadows the generated one
    hand_id = v.lua("""
      local ls = require('luasnip'); local s, t, i = ls.snippet, ls.text_node, ls.insert_node
      local sn = s({ trig = '\\\\frac', dscr = '{num}{den}' }, { t('\\\\frac{HAND}{'), i(1), t('}') })
      ls.add_snippets('hand-local', { sn }, { key = 'hand-local' })
      return sn.id""")
    v.reset_tail(scratch, "Scratch."); v.type(" \\frac", settle=1.5)
    r = rows("\\frac"); print("\\frac rows with a hand twin:", r, "hand id:", hand_id, "-> shadowed:", len(r) == 1 and r[0][2] == hand_id)
    v.nvim.input("<CR>"); v.cmd("redraw"); time.sleep(0.8)
    print("accepted:", repr(v.eval("getline('.')")))
    v.escape()
    print("report after all:", v.lua("return vim.fn.execute('SnippetsReport')").split("\n")[-3:])
finally:
    v.close()
