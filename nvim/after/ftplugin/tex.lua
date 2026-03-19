-- after/ftplugin/tex.lua
-- Custom LaTeX highlighting for VimTeX syntax groups on TokyoNight (night).
--
-- INSTALLATION:  ~/.config/nvim/after/ftplugin/tex.lua
--
-- Requires:
--   1. Treesitter highlighting disabled for tex (treesitter-tex.lua)
--   2. VimTeX as primary syntax engine (default)
--   3. Custom commands registered via g:vimtex_syntax_custom_cmds (vimtex.lua)
--   4. TokyoNight "night" active

local hl = function(group, opts)
  vim.api.nvim_set_hl(0, group, opts)
end

------------------------------------------------------------------------
-- TokyoNight (night) palette reference
------------------------------------------------------------------------
local C = {
  fg        = "#c0caf5",
  fg_dim    = "#a9b1d6",
  fg_muted  = "#737aa2",
  bg        = "#1a1b26",
  blue      = "#7aa2f7",
  cyan      = "#7dcfff",
  teal      = "#1abc9c",
  green     = "#9ece6a",
  magenta   = "#bb9af7",
  orange    = "#ff9e64",
  red       = "#f7768e",
  yellow    = "#e0af68",
  comment   = "#565f89",
  dark5     = "#737aa2",
  -- Extended palette
  blue5     = "#89ddff",   -- aqua
  green1    = "#73daca",   -- teal-green
  -- Derived tones
  math_fg   = "#c3c1f5",  -- violet tint for math body
  math_cmd  = "#89b4fa",  -- periwinkle for math commands/symbols
  arg_fg    = "#9aa5ce",   -- muted foreground for arguments
  delim     = "#545c7e",   -- subtle brace/bracket colour
  -- Custom group tones
  gold      = "#ffc777",   -- bright warm gold for axiom labels
  gold_dim  = "#c9a048",   -- muted amber for frame conditions
  rose      = "#d4879c",   -- soft rose for semantic notation
}


------------------------------------------------------------------------
-- 1. BASE COMMANDS  —  fallback for any \command not caught below
------------------------------------------------------------------------
hl("texCmd",              { fg = C.blue })
hl("texCmdType",          { fg = C.blue })


------------------------------------------------------------------------
-- 2. SECTIONING
------------------------------------------------------------------------
hl("texCmdPart",          { fg = C.orange, bold = true })
hl("texPartArgTitle",     { fg = C.orange, bold = true })


------------------------------------------------------------------------
-- 3. ENVIRONMENT DELIMITERS
------------------------------------------------------------------------
hl("texCmdEnv",           { fg = C.teal })
hl("texEnvArgName",       { fg = C.cyan, bold = true })


------------------------------------------------------------------------
-- 4. MATH  —  delimiters, body, commands, and symbols
------------------------------------------------------------------------
hl("texMathDelim",        { fg = C.magenta })
hl("texMathDelimZone",    { fg = C.magenta })
hl("texMathCmdParen",     { fg = C.magenta })

hl("texMathZone",         { fg = C.math_fg, italic = true })
hl("texMathZoneLi",       { fg = C.math_fg, italic = true })
hl("texMathZoneLd",       { fg = C.math_fg, italic = true })
hl("texMathZoneEnv",      { fg = C.math_fg, italic = true })
hl("texMathZoneTi",       { fg = C.math_fg, italic = true })
hl("texMathZoneTd",       { fg = C.math_fg, italic = true })

-- Math commands — periwinkle, distinct from generic texCmd blue
hl("texMathCmd",          { fg = C.math_cmd })

hl("texMathSuperSub",     { fg = C.dark5 })
hl("texMathOper",         { fg = C.fg_dim })


------------------------------------------------------------------------
-- 5. CITATIONS AND REFERENCES
------------------------------------------------------------------------
hl("texCmdRef",           { fg = C.green })
hl("texRefArg",           { fg = C.green, italic = true })


------------------------------------------------------------------------
-- 6. PREAMBLE / PACKAGES
------------------------------------------------------------------------
hl("texCmdPackage",       { fg = C.red })
hl("texCmdClass",         { fg = C.red })
hl("texFileArg",          { fg = C.red, italic = true })
hl("texFileOpt",          { fg = C.dark5 })


------------------------------------------------------------------------
-- 7. MACRO DEFINITIONS
------------------------------------------------------------------------
hl("texCmdDef",           { fg = C.yellow, bold = true })
hl("texDefArgName",       { fg = C.yellow })


------------------------------------------------------------------------
-- 8. INPUT / INCLUDE
------------------------------------------------------------------------
hl("texCmdInput",         { fg = C.red })


------------------------------------------------------------------------
-- 9. FOOTNOTES
------------------------------------------------------------------------
hl("texCmdFootnote",      { fg = C.dark5, italic = true })


------------------------------------------------------------------------
-- 10. TITLE / AUTHOR
------------------------------------------------------------------------
hl("texCmdTitle",         { fg = C.orange, bold = true })
hl("texCmdAuthor",        { fg = C.orange })


------------------------------------------------------------------------
-- 11. ARGUMENTS AND DELIMITERS
------------------------------------------------------------------------
hl("texArg",              { fg = C.arg_fg })
hl("texOpt",              { fg = C.dark5 })
hl("texDelim",            { fg = C.delim })
hl("texGroupDelim",       { fg = C.delim })


------------------------------------------------------------------------
-- 12. COMMENTS
------------------------------------------------------------------------
hl("texComment",          { fg = C.comment, italic = true })


------------------------------------------------------------------------
-- 13. TEXT STYLE COMMANDS
------------------------------------------------------------------------
hl("texCmdStyle",         { fg = C.blue, italic = true })
hl("texStyleItal",        { fg = C.fg, italic = true })
hl("texStyleBold",        { fg = C.fg, bold = true })


------------------------------------------------------------------------
-- 14. MISCELLANEOUS BUILT-IN
------------------------------------------------------------------------
hl("texCmdItem",          { fg = C.teal })
hl("texCmdVerb",          { fg = C.green })
hl("texVerbZone",         { fg = C.fg_dim })
hl("texCmdSpacing",       { fg = C.delim })
hl("texCmdLayout",        { fg = C.delim })
hl("texCmdHyperref",      { fg = C.cyan, underline = true })


------------------------------------------------------------------------
-- CUSTOM GROUPS  —  populated by g:vimtex_syntax_custom_cmds
------------------------------------------------------------------------

-- 15. AXIOM SCHEMA LABELS  (CMr, CCl, CNr, kax, dax, etc.)
hl("texCmdAxiom",         { fg = C.gold, bold = true })

-- 16. FRAME CONDITIONS  (cmr, ccl, cnr, cth, etc.)
hl("texCmdFrameCond",     { fg = C.gold_dim })

-- 17. LOGIC SYSTEM NAMES  (CE, CK, K, S4, SDL, etc.)
hl("texCmdLogicSys",      { fg = C.fg, bold = true })

-- 18. SEMANTIC NOTATION  (truthsetm, proofsetl, eclassl, trues, models)
hl("texCmdSemantic",      { fg = C.rose })
hl("texArgSemantic",      { fg = C.rose, italic = true })

-- 19. MODAL / CONDITIONAL OPERATORS  (cnecs, cposs, nec, poss, ought...)
hl("texCmdModalOp",       { fg = C.blue5 })

-- 20. DERIVATION RULES  (mprule, rerule, nrule, krule, etc.)
hl("texCmdRule",          { fg = C.dark5, italic = true })

-- 21. SET-THEORETIC / GENERAL NOTATION  (set, oset, power, defby, etc.)
hl("texCmdNotation",      { fg = C.green1 })
hl("texArgNotation",      { fg = C.green1, italic = true })

-- 22. MATH SYMBOLS  (\omega, \subseteq, \forall, etc. in math mode)
hl("texMathSymbol",       { fg = C.math_cmd })
