-- Brandon's own TeX snippets, hand-kept and loaded first in every TeX buffer, so a row here
-- shadows a generated row with the same label and description (the request-time dedupe in
-- completions.lua keeps the first).  The shape is that of the generated files; a row looks like
--   s({ trig = "\\mycmd", dscr = "{arg}" }, { t("\\mycmd{"), i(1, "arg"), t("}") }),
-- with `local s, t, i = ls.snippet, ls.text_node, ls.insert_node` above the table.  Nothing
-- regenerates this file.
return {
  package = "hand-local",
  includes = {},
  lists = {},
  snippets = {},
}
