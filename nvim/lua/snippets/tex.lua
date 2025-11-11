local ls = require("luasnip")
local s = ls.snippet
local i = ls.insert_node
local fmt = require("luasnip.extras.fmt").fmt

-- Add your custom LaTeX commands here (no leading backslash)
local custom_cmds = {
  "proofsetl",
}

local snips = {}
for _, name in ipairs(custom_cmds) do
  table.insert(snips, s({ trig = "\\" .. name, wordTrig = true }, fmt("\\" .. name .. "{{{}}}", { i(1) })))
end

ls.add_snippets("tex", snips)
