local ls = require("luasnip"); local s, t = ls.snippet, ls.text_node
ls.add_snippets("pkg-kt", { s({ trig = "\\kt-one" }, { t("1") }), s({ trig = "\\kt-two" }, { t("2") }) }, { key = "pkg-kt" })
ls.add_snippets("pkg-kt", { s({ trig = "\\kt-three" }, { t("3") }) }, { key = "pkg-kt" })
local function state()
  local out = {}
  for _, sn in ipairs(ls.get_snippets("pkg-kt")) do out[#out + 1] = sn.trigger .. (sn.invalidated and "(invalid)" or "") end
  return table.concat(out, " ")
end
print("after re-add:            " .. state())
ls.clean_invalidated({ inv_limit = 0 })
print("after clean_invalidated: " .. state())
-- what blink would list (it filters only `hidden`)
local n = 0; for _, sn in ipairs(ls.get_snippets("pkg-kt", { type = "snippets" })) do if not sn.hidden then n = n + 1 end end
print("rows blink would list now: " .. n)
