local ls = require("luasnip"); local s, t, i = ls.snippet, ls.text_node, ls.insert_node
math.randomseed(1); local letters = "abcdefghijklmnopqrstuvwxyz"; local snips = {}
for k = 1, 8000 do
  local n = ""; for _ = 1, 5 + (k % 6) do local r = math.random(#letters); n = n .. letters:sub(r, r) end
  snips[#snips + 1] = s({ trig = "\\" .. n, dscr = "{a}" .. ((k % 5 == 0) and " *" or ""), priority = (k % 5 == 0) and 900 or 1000 }, { t("\\" .. n) })
end
ls.add_snippets("pkg-bulk", snips, { key = "pkg-bulk" })
-- items shaped like blink's luasnip source builds them
local items = {}
for _, ft in ipairs({ "latex-workshop", "french-logic", "pkg-bulk" }) do
  for _, sn in ipairs(ls.get_snippets(ft)) do
    items[#items + 1] = { label = sn.trigger, labelDetails = { description = sn.dscr and table.concat(sn.dscr, " ") or "" }, data = { snip_id = sn.id }, score_offset = 10 }
  end
end
local memo = {}
local function transform(its)
  local seen, out = {}, {}
  for _, it in ipairs(its) do
    local id = it.data.snip_id; local m = memo[id]
    if not m then
      local sn = ls.get_id_snippet(id)
      m = { key = it.label .. "|" .. (it.labelDetails.description or ""), sink = (sn.effective_priority and sn.effective_priority < 1000) and 3 or 0 }
      memo[id] = m
    end
    if not seen[m.key] then seen[m.key] = true; if m.sink > 0 then it.score_offset = it.score_offset - m.sink end; out[#out + 1] = it end
  end
  return out
end
local function timeit(label, n)
  local t0 = vim.uv.hrtime(); local out; for _ = 1, n do out = transform(items) end
  print(string.format("%-34s %.2f ms per call, %d -> %d items", label, (vim.uv.hrtime() - t0) / n / 1e6, #items, #out))
end
timeit("transform, cold memo (first call)", 1)
timeit("transform, warm memo (x20)", 20)
local t0 = vim.uv.hrtime(); local copies = {}; for _ = 1, 5 do copies = {}; for _, it in ipairs(items) do local c = {}; for k, v in pairs(it) do c[k] = v end; copies[#copies + 1] = c end end
print(string.format("%-34s %.2f ms per call (what blink's source does per request)", "shallow-copy of every item", (vim.uv.hrtime() - t0) / 5 / 1e6))
