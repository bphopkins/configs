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
          local out = {}
          for i, it in ipairs(list.items or {}) do
            if i > n then break end
            out[#out+1] = (it.label or '?') .. ' <' .. (it.source_id or '?') .. '>' .. ((it.labelDetails and it.labelDetails.description) and (' [' .. it.labelDetails.description .. ']') or '') .. (it.score_offset and (' off=' .. it.score_offset) or '')
          end
          return out
        """, n)
    # --- inject BEFORE any completion request: provider opts + transform + snippets + ft_func
    print(v.lua("""
      local cfg = require('blink.cmp.config')
      cfg.sources.providers.snippets.opts = { use_label_description = true }
      cfg.sources.providers.snippets.transform_items = function(ctx, its)
        local ls = require('luasnip')
        local seen, out = {}, {}
        for _, it in ipairs(its) do
          local key = (it.label or '') .. '|' .. ((it.labelDetails and it.labelDetails.description) or '')
          if not seen[key] then
            seen[key] = true
            local sn = it.data and it.data.snip_id and ls.get_id_snippet(it.data.snip_id)
            if sn and sn.effective_priority and sn.effective_priority < 1000 then it.score_offset = -50 end
            out[#out+1] = it
          end
        end
        return out
      end
      local ls = require('luasnip')
      local s, t, i = ls.snippet, ls.text_node, ls.insert_node
      ls.add_snippets('pkg-spike', {
        s({ trig = '\\\\spikeone', dscr = '{a}{b}' }, { t('\\\\spikeone{'), i(1, 'a'), t('}{'), i(2, 'b'), t('}') }),
        s({ trig = '\\\\spikeone', dscr = '[opt]{a}' }, { t('\\\\spikeone['), i(1, 'opt'), t(']{'), i(2, 'a'), t('}') }),
        s({ trig = '\\\\spikeone', dscr = '{a}{b}' }, { t('\\\\spikeone{'), i(1, 'a'), t('}{'), i(2, 'b'), t('}') }),
        s({ trig = '\\\\spiketwo', dscr = 'never shown', show_condition = function() return false end }, { t('\\\\spiketwo') }),
        s({ trig = '\\\\spikethree', dscr = 'sunk', priority = 900 }, { t('\\\\spikethree') }),
        s({ trig = '\\\\spikeonx', dscr = 'typical' }, { t('\\\\spikeonx') }),
      }, { key = 'pkg-spike' })
      require('luasnip.session').config.ft_func = function()
        local ft = vim.bo.filetype
        if ft == 'tex' then return { 'tex', 'pkg-spike' } end
        return vim.split(ft, '.', { plain = true })
      end
      local c = cfg.completion.menu.draw.columns
      return 'injected; columns=' .. (type(c) == 'function' and vim.inspect(c({})) or vim.inspect(c))
    """))
    v.reset_tail(scratch, "Scratch.")
    v.type(" \\spike")
    print("rows after \\spike:", items(10))
    v.escape()
    v.reset_tail(scratch, "Scratch.")
    v.type(" \\spikeone")
    keys("<CR>", settle=0.8)
    print("full trigger accepted:", repr(v.eval("getline('.')")))
    v.escape()
    v.reset_tail(scratch, "Scratch.")
    v.type(" \\spikeo")
    keys("<CR>", settle=0.8)
    print("partial trigger accepted:", repr(v.eval("getline('.')")))
    v.escape()
    # lua buffer untouched?
    v.cmd("enew"); v.cmd("set filetype=lua")
    print("lua buffer snippet fts:", v.lua("return require('luasnip.util.util').get_snippet_filetypes()"))
    # per-request cost of the transform with ~1,000 rows today
    v.cmd("bprevious")
    v.reset_tail(scratch, "Scratch.")
    v.type(" \\a")
    print("rows after \\a (count):", v.lua("local l=require('blink.cmp.completion.list'); return #(l.items or {})"))
    print("transform cost for that list:", v.lua("""
      local cfg = require('blink.cmp.config'); local l = require('blink.cmp.completion.list')
      local its = vim.deepcopy(l.items or {})
      local t0 = vim.uv.hrtime(); cfg.sources.providers.snippets.transform_items(nil, its); return string.format('%.2f ms for %d items', (vim.uv.hrtime()-t0)/1e6, #its)
    """))
    v.escape()
finally:
    v.close()
