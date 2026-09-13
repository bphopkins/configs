import os, sys, time
sys.path.insert(0, os.path.expanduser("~/Desktop/configs/tests/nvim-latency"))
from harness import Nvim
v = Nvim().open_fixture()
try:
    scratch = v.eval("line('$')")
    def keys(*ks, settle=0.7):
        for k in ks:
            v.nvim.input(k); v.cmd("redraw"); time.sleep(settle)
    print(v.lua("""
      local ls = require('luasnip')
      local s, t, i, f = ls.snippet, ls.text_node, ls.insert_node, ls.function_node
      local events = require('luasnip.util.events')
      local function in_math() return vim.fn['vimtex#syntax#in_mathzone']() == 1 end
      local wrap = function() return in_math() and '' or '$' end
      -- env snippet with a pre_expand callback that eats a preceding \\begin{ and a following auto-paired }
      local function envsnip(name)
        return s({ trig = '\\\\' .. name, dscr = 'env' }, {
          t({ '\\\\begin{' .. name .. '}', '\\t' }), i(1), t({ '', '\\\\end{' .. name .. '}' }) }, {
          callbacks = { [-1] = { [events.pre_expand] = function(snip, args)
            local row, col = args.expand_pos[1], args.expand_pos[2]
            local line = vim.api.nvim_buf_get_lines(0, row, row + 1, false)[1] or ''
            local before, after = line:sub(1, col), line:sub(col + 1)
            local m = before:match('\\\\begin{$')
            if m then
              local newbefore = before:sub(1, #before - #m)
              local newafter = after:sub(1, 1) == '}' and after:sub(2) or after
              vim.api.nvim_buf_set_lines(0, row, row + 1, false, { newbefore .. newafter })
              vim.api.nvim_win_set_cursor(0, { row + 1, #newbefore })
              return { }
            end
          end } } })
      end
      ls.add_snippets('pkg-spike2', {
        s({ trig = '\\\\spikealpha', dscr = 'math-only' }, { f(wrap), t('\\\\alpha'), f(wrap) }),
        envsnip('spikeenv'),
      }, { key = 'pkg-spike2' })
      require('luasnip.session').config.ft_func = function()
        if vim.bo.filetype == 'tex' then return { 'tex', 'pkg-spike2' } end
        return vim.split(vim.bo.filetype, '.', { plain = true })
      end
      local sn
      for _, x in ipairs(ls.get_snippets('pkg-spike2')) do if x.trigger == '\\\\spikealpha' then sn = x end end
      return 'docstring of the wrapped snippet: ' .. table.concat(sn:get_docstring(), '|')
    """))
    v.reset_tail(scratch, "Scratch.")
    v.type(" \\spikealpha"); keys("<CR>")
    print("prose:", repr(v.eval("getline('.')"))); v.escape()
    v.reset_tail(scratch, "Scratch.")
    v.type(" $x \\spikealpha"); keys("<CR>")
    print("inside $:", repr(v.eval("getline('.')"))); v.escape()
    v.reset_tail(scratch, "Scratch.")
    v.type(" \\begin{spikee"); keys("<CR>", settle=1.0)
    l = v.eval("line('.')")
    print("env row accepted inside \\begin{ :", v.eval("getline(%d, %d)" % (l - 1, l + 1))); v.escape()
    v.reset_tail(scratch, "Scratch.")
    v.type(" \\spikee"); keys("<CR>", settle=1.0)
    l = v.eval("line('.')")
    print("env row accepted from bare backslash:", v.eval("getline(%d, %d)" % (l - 1, l + 1))); v.escape()
finally:
    v.close()
