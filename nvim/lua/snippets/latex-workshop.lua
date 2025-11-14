local ls = require("luasnip")
local s  = ls.snippet
local t  = ls.text_node
local i  = ls.insert_node

local snippets = {
  s({ trig = "\\abstract~", wordTrig = true }, { t("["), i(1, "⟨titre alternatif⟩"), t("]") }),
  s({ trig = "\\listORI~", wordTrig = true }, { t("{"), i(1, "symbol"), t("}") }),
}

return {
  tex = snippets,
}
