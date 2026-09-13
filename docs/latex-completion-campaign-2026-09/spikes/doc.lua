vim.wait(3000, function() return package.loaded["luasnip"] ~= nil end, 50)
local ls = require("luasnip")
local function find(ft, trig)
  for _, s in ipairs(ls.get_snippets(ft) or {}) do if s.trigger == trig then return s end end
end
for _, pair in ipairs({ { "latex-workshop", "\\frac~" }, { "latex-workshop", "\\chapter*~" }, { "latex-workshop", "\\parbox~" }, { "french-logic", "\\proofsketch~" }, { "french-logic", "\\cought~" } }) do
  local s = find(pair[1], pair[2])
  if s then
    local doc = s:get_docstring(); if type(doc) == "table" then doc = table.concat(doc, "\n") end
    print(string.format("%-16s dscr=%-14s docstring(on-highlight window)=%s", pair[2], vim.inspect(s.dscr), doc))
  else print(pair[2], "not found") end
end
local ok, cfg = pcall(require, "blink.cmp.config")
if ok then
  print("documentation auto_show:", vim.inspect(cfg.completion.documentation.auto_show), " delay:", cfg.completion.documentation.auto_show_delay_ms)
  print("menu columns:", vim.inspect(cfg.completion.menu.draw.columns))
  print("snippets provider opts:", vim.inspect(cfg.sources.providers.snippets.opts))
end
