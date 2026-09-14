#!/usr/bin/env python3
r"""Stage 4, measurement 2: the two transforms at the full row count, on the live tree.  Snippets:
the live transform (blink's provider object holds it) called in isolation over items shaped like
blink's luasnip source builds, every row the fixture's buffer reaches, cold memo and warm (x20), plus
blink's per-request shallow copy and the show_condition pass; then in-request timings at ` \fr`.
Omni: in-request timing at ` \begin{a` (VimTeX's rows plus the union), first and second, and
VimTeX's env completer alone."""
import time
from stage4lib import Nvim, install_hooks, rows

v = Nvim().open_fixture()
try:
    last = v.eval("line('$')")
    v.reset_tail(last, "Scratch."); v.type(" \\fr", settle=1.5); v.escape()  # registers the closure
    iso = v.lua(r"""
      local prov = require('blink.cmp.sources.lib').get_provider_by_id('snippets')
      local xf = prov.config.transform_items
      local ls = require('luasnip'); local utils = require('blink.cmp.lib.utils')
      local items = {}
      for _, ft in ipairs(require('luasnip.util.util').get_snippet_filetypes()) do
        for _, sn in ipairs(ls.get_snippets(ft, { type = 'snippets' })) do
          items[#items + 1] = { label = sn.trigger, kind = 15, source_id = 'snippets', score_offset = 10,
            labelDetails = sn.dscr and { description = table.concat(sn.dscr, ' ') } or nil,
            data = { snip_id = sn.id, show_condition = sn.show_condition } }
        end
      end
      local ctx = { line = 'Scratch. \\fr', cursor = { vim.fn.line('.'), 12 }, bufnr = vim.api.nvim_get_current_buf() }
      local function copies() local o = {}; for _, it in ipairs(items) do o[#o + 1] = utils.shallow_copy(it) end; return o end
      local L = require('snippets.loader')
      L.memo = { key = {}, sink = {} }
      local its = copies()
      local t0 = vim.uv.hrtime(); local out = xf(ctx, its); local cold = (vim.uv.hrtime() - t0) / 1e6
      local warm = 0
      for _ = 1, 20 do its = copies(); local t1 = vim.uv.hrtime(); out = xf(ctx, its); warm = warm + (vim.uv.hrtime() - t1) / 1e6 end
      local t2 = vim.uv.hrtime(); for _ = 1, 5 do its = copies() end; local copy = (vim.uv.hrtime() - t2) / 5e6
      local kept = 0
      local t3 = vim.uv.hrtime()
      for _, it in ipairs(items) do if it.data.show_condition('Scratch. \\fr') then kept = kept + 1 end end
      local cond = (vim.uv.hrtime() - t3) / 1e6
      return { n = #items, out = #out, cold = cold, warm = warm / 20, copy = copy, cond = cond, kept = kept }
    """)
    print(f"snippets transform, isolated: {iso['n']} rows -> {iso['out']} kept; cold {iso['cold']:.2f} ms, warm {iso['warm']:.2f} ms; "
          f"blink's shallow copy of every row {iso['copy']:.2f} ms; show_condition pass {iso['cond']:.2f} ms ({iso['kept']} shown)")
    install_hooks(v)
    for i in (1, 2):
        v.reset_tail(last, "Scratch."); v.type(" \\fr", settle=1.5)
        a = v.lua("local a = _G.ACC; _G.ACC = _G.newacc(); return a")
        print(f"snippets in-request #{i} at ' \\fr': source {a['src']:.1f} ms, transform {a['xform']:.2f} ms, fuzzy {a['fuzzy']:.1f} ms over {a['nfz']} calls ({a['n']} requests, ft_func {a['ft']:.2f} ms)")
        v.escape()
    for i in (1, 2):
        v.reset_tail(last, "Scratch."); v.type(" \\begin{a", settle=1.5)
        a = v.lua("local a = _G.ACC; _G.ACC = _G.newacc(); return a")
        r = rows(v, 400)
        print(f"omni in-request #{i} at ' \\begin{{a': transform {a['oxform']:.2f} ms over {a['nox']} calls, fuzzy {a['fuzzy']:.1f} ms over {a['nfz']} calls; {len(r)} rows shown")
        v.escape()
    env = v.lua(r"""
      local out = {}
      for _, q in ipairs({ '', 'a', 'a' }) do
        local t0 = vim.uv.hrtime(); local r = vim.fn['vimtex#complete#complete']('env', q, '\\begin{')
        out[#out + 1] = string.format('%q -> %d in %.1f ms', q, #r, (vim.uv.hrtime() - t0) / 1e6)
      end
      local e = require('snippets.loader').envs(vim.api.nvim_get_current_buf())
      local t1 = vim.uv.hrtime(); for _ = 1, 20 do e = require('snippets.loader').envs(vim.api.nvim_get_current_buf()) end
      out[#out + 1] = string.format('loader.envs(): %d names, %.3f ms per call', #e.names, (vim.uv.hrtime() - t1) / 20e6)
      return out
    """)
    print("VimTeX env completer alone: " + "; ".join(env))
finally:
    v.close()
