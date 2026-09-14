import os, sys, time, statistics
sys.path.insert(0, os.path.expanduser("~/Desktop/configs/tests/nvim-latency"))
from harness import Nvim
GAP = 0.4
v = Nvim().open_fixture()
try:
    longest = v.para_lines()[-1][0]
    # in-process attribution: wrap the LuaSnip source, the fuzzy matcher and (later) the transform
    v.lua("""
      _G.ACC = { src = 0, fuzzy = 0, xform = 0, n = 0 }
      local ls_src = require('blink.cmp.sources.snippets.luasnip')
      local orig = ls_src.get_completions
      ls_src.get_completions = function(self, ctx, cb)
        local t0 = vim.uv.hrtime()
        return orig(self, ctx, function(res) _G.ACC.src = _G.ACC.src + (vim.uv.hrtime() - t0) / 1e6; _G.ACC.n = _G.ACC.n + 1; cb(res) end)
      end
      local fz = require('blink.cmp.fuzzy'); local of = fz.fuzzy
      fz.fuzzy = function(...) local t0 = vim.uv.hrtime(); local a, b = of(...); _G.ACC.fuzzy = _G.ACC.fuzzy + (vim.uv.hrtime() - t0) / 1e6; return a, b end
    """)
    def timed(keys_untimed, keys_timed):
        out = []
        for k in keys_untimed:
            v.nvim.input(k); v.cmd("redraw"); time.sleep(GAP)
        for k in keys_timed:
            time.sleep(GAP)
            t = time.perf_counter(); v.nvim.input(k); v.cmd("redraw"); out.append((time.perf_counter() - t) * 1000)
        return out
    def phase(label):
        v.lua("_G.ACC = { src = 0, fuzzy = 0, xform = 0, n = 0 }")
        v.goto_end_of(longest); v.insert()
        cmd = []
        for word in ("frac", "alpha", "subseteq", "begin", "textit", "mathcal"):
            cmd += timed([" ", "\\"], list(word))
        v.escape(); v.cmd("silent! undo"); v.lua("vim.cmd('silent! undo')")
        acc_cmd = v.lua("return _G.ACC")
        v.lua("_G.ACC = { src = 0, fuzzy = 0, xform = 0, n = 0 }")
        v.goto_end_of(longest); v.insert()
        prose = timed([" "], list("the quick brown fox jumps"))
        v.escape(); v.cmd("silent! undo")
        acc_prose = v.lua("return _G.ACC")
        rows = v.lua("return #(require('luasnip').get_snippets('latex-workshop')) + #(require('luasnip').get_snippets('french-logic')) + #(require('luasnip').get_snippets('pkg-bulk') or {})")
        print(f"{label}: {rows} snippets reachable")
        print(f"  command-name keystrokes ({len(cmd)}): median {statistics.median(cmd):.1f} ms, p90 {sorted(cmd)[int(len(cmd)*0.9)]:.1f} ms, max {max(cmd):.1f} ms"
              f"   in-process per request: luasnip source {acc_cmd['src']/max(acc_cmd['n'],1):.1f} ms, fuzzy {acc_cmd['fuzzy']/max(acc_cmd['n'],1):.1f} ms, transform {acc_cmd['xform']/max(acc_cmd['n'],1):.1f} ms ({acc_cmd['n']} requests)")
        print(f"  prose keystrokes ({len(prose)}):       median {statistics.median(prose):.1f} ms, p90 {sorted(prose)[int(len(prose)*0.9)]:.1f} ms   (snippet requests: {acc_prose['n']})")
    phase("A. today")
    # B. inject 8,000 synthetic rows (named placeholders, descriptions, 40% 'unusual') plus the planned transform
    v.lua("""
      local ls = require('luasnip'); local s, t, i = ls.snippet, ls.text_node, ls.insert_node
      math.randomseed(1)
      local letters = 'abcdefghijklmnopqrstuvwxyz'
      local snips = {}
      for k = 1, 8000 do
        local n = ''; for _ = 1, 5 + (k % 6) do local r = math.random(#letters); n = n .. letters:sub(r, r) end
        local nodes = { t('\\\\' .. n) }; local sig = ''
        for a = 1, (k % 4) do nodes[#nodes + 1] = t('{'); nodes[#nodes + 1] = i(a, 'arg' .. a); nodes[#nodes + 1] = t('}'); sig = sig .. '{arg' .. a .. '}' end
        snips[#snips + 1] = s({ trig = '\\\\' .. n, dscr = sig .. ((k % 5 == 0) and ' *' or ''), priority = (k % 5 == 0) and 900 or 1000 }, nodes)
      end
      ls.add_snippets('pkg-bulk', snips, { key = 'pkg-bulk' })
      require('luasnip.session').config.ft_func = function()
        if vim.bo.filetype == 'tex' then return { 'tex', 'pkg-bulk' } end
        return vim.split(vim.bo.filetype, '.', { plain = true })
      end
      local cfg = require('blink.cmp.config')
      cfg.sources.providers.snippets.opts = { use_label_description = true }
      local memo = {}
      cfg.sources.providers.snippets.transform_items = function(ctx, its)
        local t0 = vim.uv.hrtime()
        local lsn = require('luasnip'); local seen, out = {}, {}
        for _, it in ipairs(its) do
          local id = it.data and it.data.snip_id
          local m = id and memo[id]
          if id and not m then
            local sn = lsn.get_id_snippet(id)
            m = { key = (it.label or '') .. '|' .. ((it.labelDetails and it.labelDetails.description) or ''), sink = (sn and sn.effective_priority and sn.effective_priority < 1000) and 3 or 0 }
            memo[id] = m
          end
          if m then
            if not seen[m.key] then seen[m.key] = true; if m.sink > 0 then it.score_offset = (it.score_offset or 0) - m.sink end; out[#out + 1] = it end
          else out[#out + 1] = it end
        end
        _G.ACC.xform = _G.ACC.xform + (vim.uv.hrtime() - t0) / 1e6
        return out
      end
    """)
    # warm blink's per-filetype cache once, untimed
    v.goto_end_of(longest); v.insert(); timed([" ", "\\", "f"], []); v.escape(); v.cmd("silent! undo")
    phase("B. plus 8,000 synthetic rows and the planned transform")
finally:
    v.close()
