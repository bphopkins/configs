import os, sys, time
sys.path.insert(0, os.path.expanduser("~/Desktop/configs/tests/nvim-latency"))
from harness import Nvim
v = Nvim().open_fixture()
try:
    scratch = v.eval("line('$')")
    def keys(*ks, settle=0.8):
        for k in ks:
            v.nvim.input(k); v.cmd("redraw"); time.sleep(settle)
    def rows(n=6):
        return v.lua("""
          local n = ...
          local l = require('blink.cmp.completion.list'); local out = {}
          for i, it in ipairs(l.items or {}) do if i > n then break end; out[#out+1] = (it.label or '?') .. ' <' .. (it.source_id or '?') .. '>' end
          return out""", n)
    print(v.lua("""
      local cfg = require('blink.cmp.config')
      -- (a) omni provider: turn a bare environment name completed inside \\begin{ into a template snippet item
      cfg.sources.per_filetype.tex = { 'omni', 'snippets', 'path' }
      cfg.sources.providers.omni.transform_items = function(ctx, its)
        local before = ctx.line:sub(1, ctx.cursor[2])
        if not before:match('\\\\begin{[%w*]*$') then return its end
        local after = ctx.line:sub(ctx.cursor[2] + 1, ctx.cursor[2] + 1)
        local out = {}
        for _, it in ipairs(its) do
          local name = (it.textEdit and it.textEdit.newText or it.label):gsub('}$', '')
          it.insertTextFormat = vim.lsp.protocol.InsertTextFormat.Snippet
          it.textEdit.newText = name .. '}\\n\\t$0\\n\\\\end{' .. name .. '}'
          if after == '}' then it.textEdit.range['end'].character = it.textEdit.range['end'].character + 1 end
          out[#out+1] = it
        end
        return out
      end
      -- (b) a regTrig environment snippet that also serves after a bare backslash, with a callback eating the auto-paired brace
      local ls = require('luasnip'); local s, t, i = ls.snippet, ls.text_node, ls.insert_node
      local events = require('luasnip.util.events')
      ls.add_snippets('pkg-spike3', {
        s({ trig = '\\\\begin{[%w*]*', regTrig = true, name = '\\\\spikeenv', dscr = 'env (regTrig)' },
          { t({ '\\\\begin{spikeenv}', '\\t' }), i(1), t({ '', '\\\\end{spikeenv}' }) },
          { callbacks = { [-1] = { [events.pre_expand] = function(snip, args)
              local row, col = args.expand_pos[1], args.expand_pos[2]
              local line = vim.api.nvim_buf_get_lines(0, row, row + 1, false)[1] or ''
              if line:sub(col + 1, col + 1) == '}' then
                vim.api.nvim_buf_set_text(0, row, col, row, col + 1, {})
              end
            end } } }),
        s({ trig = '\\\\spikeplain', dscr = 'env (plain)' }, { t({ '\\\\begin{spikeplain}', '\\t' }), i(1), t({ '', '\\\\end{spikeplain}' }) }),
      }, { key = 'pkg-spike3' })
      require('luasnip.session').config.ft_func = function()
        if vim.bo.filetype == 'tex' then return { 'tex', 'pkg-spike3' } end
        return vim.split(vim.bo.filetype, '.', { plain = true })
      end
      return 'injected'
    """))
    # (a) omni template at \begin{
    v.reset_tail(scratch, "Scratch.")
    v.type(" \\begin{enum", settle=1.5)
    print("(a) rows:", rows(4))
    keys("<CR>", settle=1.0)
    l = v.eval("line('.')")
    print("(a) omni row accepted inside \\begin{ :", v.eval("getline(%d, %d)" % (l - 1, l + 1))); v.escape()
    # (b) regTrig snippet inside \begin{  -- its label is the snippet name
    v.reset_tail(scratch, "Scratch.")
    v.type(" \\begin{spikee", settle=1.0)
    print("(b) rows:", rows(4))
    keys("<CR>", settle=1.0)
    l = v.eval("line('.')")
    print("(b) regTrig row accepted inside \\begin{ :", v.eval("getline(%d, %d)" % (l - 1, l + 1))); v.escape()
    # (b') the same regTrig snippet from a bare backslash
    v.reset_tail(scratch, "Scratch.")
    v.type(" \\spikee", settle=1.0)
    print("(b') rows after bare \\spikee:", rows(4))
    keys("<CR>", settle=1.0)
    l = v.eval("line('.')")
    print("(b') accepted from bare backslash:", v.eval("getline(%d, %d)" % (l - 1, l + 1))); v.escape()
    # \end{ via omni: VimTeX's matching-environment row
    v.reset_tail(scratch, "Scratch.")
    v.lua("vim.api.nvim_buf_set_lines(0, -1, -1, false, { '\\\\begin{itemize}', '  \\\\item x', '' })")
    v.cmd("normal! G"); v.nvim.input("A"); v.cmd("redraw"); time.sleep(0.3)
    v.type("\\end{", settle=1.5)
    print("\\end{ rows:", rows(3))
    keys("<CR>", settle=1.0)
    print("\\end{ accepted:", repr(v.eval("getline('.')"))); v.escape()
finally:
    v.close()
