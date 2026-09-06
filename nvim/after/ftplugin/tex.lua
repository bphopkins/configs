-- after/ftplugin/tex.lua
-- Custom LaTeX highlighting for VimTeX syntax groups on TokyoNight (night).
--
-- INSTALLATION:  ~/.config/nvim/after/ftplugin/tex.lua
--
-- Requires:
--   1. Treesitter highlighting disabled for tex (treesitter-tex.lua)
--   2. VimTeX as primary syntax engine (default)
--   3. Custom commands registered via g:vimtex_syntax_custom_cmds (vimtex.lua)
--   4. Environment-name matches from after/syntax/tex.lua (groups 23)
--   5. TokyoNight "night" active
--
-- DESIGN — the register taxonomy.  Full theory, per-species table,
-- channel contract, borderline ledger, and revisit dials live in
-- docs/latex-register-taxonomy.md (living contract — edit that file,
-- not ad-hoc comments here).  The short of it:
--   HUE = genus and side: warm gold = proof theory + object language,
--     cool blue = semantics + metasemantics, warm-tan = the material,
--     gray = the level-neutral mathematical medium, green = the entire
--     document dimension AS A SPECTRUM (landmarks > loaded envs >
--     containers > scaffolding, with deixis the same family), magenta =
--     register boundaries ($, qed), red = preamble machinery.
--   SATURATION = markedness (unmarked workhorses desaturate to gray),
--   LIGHTNESS = salience (relations > objects > names),
--   BOLD = names and anchors,  ITALIC = material and arguments.
--   Loadedness is a RUNG of the document spectrum, not a borrowed
--   side-colour (borrowing tried and retired 2026-08-28: hilbertlist
--   in the warm name colour failed the glance test).

local hl = function(group, opts)
  vim.api.nvim_set_hl(0, group, opts)
end

------------------------------------------------------------------------
-- TokyoNight (night) palette reference
------------------------------------------------------------------------
local C = {
  fg = "#c0caf5",
  fg_dim = "#a9b1d6",
  fg_muted = "#737aa2",
  bg = "#1a1b26",
  blue = "#7aa2f7",
  cyan = "#7dcfff",
  teal = "#1abc9c",
  green = "#9ece6a", -- document landmarks (bold) and deixis (regular)
  green_loaded = "#4fd6b0", -- loaded-structure rung of the document spectrum
  -- Deixis dims one rung for the KEY, as names do throughout the scheme
  -- (blue_obj -> blue_dim for names of semantic objects).  The \cite
  -- command is the deictic act and keeps the landmark hue; the key is the
  -- name of the work pointed at.  Derived, not chosen: the house dim step
  -- is dL -8.0 / dC -9.4 in LCh (mean of blue_obj->blue_dim and
  -- gold_mid->gold_dim), giving dE00 6.5 from green -- inside the house
  -- band (gold 6.5, blue 8.2).  Clear of the other green rungs by 18.6
  -- (green_loaded) and 19.0 (teal), so it cannot impersonate them;
  -- contrast 7.4 on bg.
  green_dim = "#8fb665", -- deixis: the key, one rung below the command
  magenta = "#bb9af7",
  red = "#f7768e",
  yellow = "#e0af68",
  comment = "#565f89",
  dark5 = "#737aa2",
  -- Extended palette
  blue5 = "#89ddff", -- aqua: semantic relations ⊨ ⊩
  -- Derived tones
  -- The material: warm tan, the "exactly in between α and β" verdict
  -- on formula unity (2026-08-28).  Letters remain material — light,
  -- italic, no per-letter sort convention — but the material leans
  -- toward what it mostly composes, the object language, so formulas
  -- cohere as warm wholes and cool machinery visibly crosses INTO
  -- them.  dE00 vs prose 28.7 (the boundary problem is gone for
  -- good), vs each warm token family 11.7–12.3, vs azure 34.8.
  -- Escalation if formulas still fragment: the β sort convention
  -- (sentence letters full warm, worlds/sets cool) — ledgered in
  -- docs/latex-register-taxonomy.md, deliberately not built.
  math_fg = "#c6ab90", -- warm-tan material: math body, variables, formula
  -- args — and, in roman, the object-language connectives (the warm bank)
  -- Semantic objects sit on a clean azure, pushed off the violet
  -- material (dE00 13.8 -> 15.8) after the periwinkle read as a
  -- "warm blue" clashing inside formulas (2026-08-28).  Next notch
  -- away from violet: #6ea6f2 (costs distance to the condition names).
  blue_obj = "#74acf5", -- azure: semantic objects
  blue_dim = "#7396c2", -- muted blue: names of semantic objects
  gold_bright = "#eec584", -- ⊢ family: derivability relations
  gold_mid = "#d9aa5e", -- intensional operators of the object language
  gold_dim = "#bd9750", -- syntactic objects + their names (bold)
  steel = "#8f99c9", -- metalanguage glue; also stock math commands
  arg_fg = "#9aa5ce", -- muted foreground for generic arguments
  delim = "#545c7e", -- subtle brace/bracket colour
}

------------------------------------------------------------------------
-- 1. BASE COMMANDS  —  fallback for any \command not caught below
------------------------------------------------------------------------
hl("texCmd", { fg = C.blue })
hl("texCmdType", { fg = C.blue })

------------------------------------------------------------------------
-- 2. SECTIONING
------------------------------------------------------------------------
hl("texCmdPart", { fg = C.green, bold = true })
hl("texPartArgTitle", { fg = C.green, bold = true })

------------------------------------------------------------------------
-- 3. ENVIRONMENT DELIMITERS
------------------------------------------------------------------------
hl("texCmdEnv", { fg = C.teal })
-- Default env names join the scaffold teal: the whole structural
-- register (lists, tables, generic envs) is one green family, so
-- math never shares a hue with list machinery.
hl("texEnvArgName", { fg = C.teal, bold = true })

------------------------------------------------------------------------
-- 4. MATH  —  delimiters, body, commands, and symbols
------------------------------------------------------------------------
hl("texMathDelim", { fg = C.magenta })
hl("texMathDelimZone", { fg = C.magenta })
hl("texMathCmdParen", { fg = C.magenta })

hl("texMathZone", { fg = C.math_fg, italic = true })
hl("texMathZoneLi", { fg = C.math_fg, italic = true })
hl("texMathZoneLd", { fg = C.math_fg, italic = true })
hl("texMathZoneEnv", { fg = C.math_fg, italic = true })
hl("texMathZoneTi", { fg = C.math_fg, italic = true })
hl("texMathZoneTd", { fg = C.math_fg, italic = true })

-- Stock math commands sit on the glue-and-terms rung: \in, \subseteq,
-- \neg, \land, \cap ... share one tone with the .sty's \to, \union, \M,
-- so a connective's colour never depends on which file defined it.
hl("texMathCmd", { fg = C.steel })

hl("texMathSuperSub", { fg = C.dark5 })
hl("texMathOper", { fg = C.steel })

------------------------------------------------------------------------
-- 5. CITATIONS AND REFERENCES
------------------------------------------------------------------------
hl("texCmdRef", { fg = C.green })
hl("texRefArg", { fg = C.green_dim, italic = true })

------------------------------------------------------------------------
-- 6. PREAMBLE / PACKAGES
------------------------------------------------------------------------
hl("texCmdPackage", { fg = C.red })
hl("texCmdClass", { fg = C.red })
hl("texFileArg", { fg = C.red, italic = true })
hl("texFileOpt", { fg = C.dark5 })

------------------------------------------------------------------------
-- 7. MACRO DEFINITIONS
-- Red keyword (preamble machinery, like packages); the macro NAME being
-- defined is a syntax-side name, so it takes the name-family gold.
------------------------------------------------------------------------
hl("texCmdDef", { fg = C.red, bold = true })
hl("texDefArgName", { fg = C.gold_dim })

------------------------------------------------------------------------
-- 8. INPUT / INCLUDE
------------------------------------------------------------------------
hl("texCmdInput", { fg = C.red })

------------------------------------------------------------------------
-- 9. FOOTNOTES
------------------------------------------------------------------------
-- A footnote opens a subordinate document space, so it belongs to the
-- document spectrum at the container/scaffolding rung, beside \begin,
-- \item and the proof-tree helpers -- not to prose inflection, which is
-- the voice modulating itself inside a sentence (\emph, \textit).
-- The old gray sat dE00 10.6 from `comment` at contrast 4.1, so footnotes
-- read as commented-out text; teal is 41.8 from comment at contrast 7.1,
-- and 21.2 / 19.0 clear of texCmdRef / texRefArg, which share the line
-- constantly. Not italic: that channel is material and argument content.
hl("texCmdFootnote", { fg = C.teal })

------------------------------------------------------------------------
-- 10. TITLE / AUTHOR
------------------------------------------------------------------------
hl("texCmdTitle", { fg = C.green, bold = true })
hl("texCmdAuthor", { fg = C.green })

------------------------------------------------------------------------
-- 11. ARGUMENTS AND DELIMITERS
------------------------------------------------------------------------
hl("texArg", { fg = C.arg_fg })
hl("texOpt", { fg = C.dark5 })
hl("texDelim", { fg = C.delim })
hl("texGroupDelim", { fg = C.delim })

------------------------------------------------------------------------
-- 12. COMMENTS
------------------------------------------------------------------------
hl("texComment", { fg = C.comment, italic = true })

------------------------------------------------------------------------
-- 13. TEXT STYLE COMMANDS
-- The \emph/\textit tokens themselves are plumbing — muted like other
-- supporting material; the STYLED CONTENT keeps full body weight.
------------------------------------------------------------------------
hl("texCmdStyle", { fg = C.arg_fg, italic = true })
hl("texStyleItal", { fg = C.fg, italic = true })
hl("texStyleBold", { fg = C.fg, bold = true })

------------------------------------------------------------------------
-- 14. MISCELLANEOUS BUILT-IN
------------------------------------------------------------------------
hl("texCmdItem", { fg = C.teal })
hl("texCmdVerb", { fg = C.green })
hl("texVerbZone", { fg = C.fg_dim })
hl("texCmdSpacing", { fg = C.delim })
hl("texCmdLayout", { fg = C.delim })
hl("texCmdHyperref", { fg = C.cyan, underline = true })

------------------------------------------------------------------------
-- CUSTOM GROUPS  —  populated by g:vimtex_syntax_custom_cmds
------------------------------------------------------------------------

-- 15. SEMANTIC RELATIONS  (\trues, \models, negations, \bisim)
-- Satisfaction: the bright pole of the cool side.
hl("texCmdTurnstileSem", { fg = C.blue5 })

-- 16. DERIVABILITY RELATIONS  (\proves family, \seq, signed forces)
-- The bright pole of the warm side — ⊢ against ⊨, correspondence as
-- temperature.
hl("texCmdTurnstileSyn", { fg = C.gold_bright })

-- 17. INTENSIONAL OPERATORS  (\ought, \cobs, \cnecs, \nec, stit, ...)
-- Object-language operators are warm: the logics themselves are the
-- far pole of the formality gradient.
hl("texCmdIntension", { fg = C.gold_mid })

-- 18. SEMANTIC OBJECTS  (\M, \flog, \truthset, valuations, STIT
-- structures, truth values) — the interpreting machinery, cool blue;
-- arguments read as part of the construction.
hl("texCmdSemObj", { fg = C.blue_obj })
hl("texArgSemObj", { fg = C.blue_obj, italic = true })

-- 19. SYNTACTIC OBJECTS  (\proofsetl, \eclassl, \cn, \logic, languages,
-- mcs, I/O out(·)) — proof-theoretic material, warm; so
-- \flog(\proofsetl{A}) shows a blue function on warm arguments.
hl("texCmdSynObj", { fg = C.gold_dim })
hl("texArgSynObj", { fg = C.gold_dim, italic = true })

-- 20a. OBJECT-LANGUAGE CONNECTIVES  (\to, \iff, \land, \neg, \top…)
-- The saddle's warm bank (2026-08-28): boolean glue of the object
-- language wears the material tan in roman — connective vs variable
-- carried by style, and formulas cohere as warm wholes.  The steel
-- read as cool-side ("as if they live on the semantics side").
hl("texCmdConnective", { fg = C.math_fg })

-- 20b. METALANGUAGE GLUE  (\set, \intersect, \in via texMathCmd,
-- ml-connectives, \defby) — the saddle's cool bank, where prose
-- shades into the formal metalanguage; same tone as stock texMathCmd,
-- so an unregistered macro lands here.
hl("texCmdGround", { fg = C.steel })

-- 21. VARIABLES  (Greek letters, atoms p0..p3)
-- The shared material of every register — body-toned violet.
hl("texCmdVariable", { fg = C.math_fg, italic = true })

-- 22. NAMES OF SYNTACTIC OBJECTS  (CMr, kax, K, S4, CE, IO, RE, MP...)
-- Mentions, not uses: the dim rung of the warm side, bold for
-- scanning, well under the landmark orange.
hl("texCmdNameSyn", { fg = C.gold_dim, bold = true })

-- 23. NAMES OF SEMANTIC OBJECTS  (cmr, ccl, cnr, cth, Rup, Ldown...)
-- The dim rung of the cool side — every CMr↔cmr pair is a visible
-- warm↔cool correspondence.
hl("texCmdNameSem", { fg = C.blue_dim })

-- 24. SCAFFOLDING  (\hypo, \infr, \by, \close, booktabs rules)
-- Proof-tree and table furniture joins the \begin/\end/\item teal.
hl("texCmdScaffold", { fg = C.teal })

-- 25. END-OF-PROOF MARKERS  (\qed)
hl("texCmdQed", { fg = C.magenta })

-- 26. MATH SYMBOLS  (\omega, \subseteq, \forall, etc. in math mode)
hl("texMathSymbol", { fg = C.steel })

-- 27. ARGUMENT CONTENT GROUPS  (targets of the arglink mechanism)
-- Formula-valued arguments read as math body; name-valued arguments
-- (\parent{\CMl}, \by{MP, 1, 2}, IO-family indices) read as names.
hl("texArgFormula", { fg = C.math_fg, italic = true })
hl("texArgName", { fg = C.gold_dim })

-- 28. ENVIRONMENT NAME FAMILIES  (matches defined in after/syntax/tex.lua)
-- The document spectrum's top rungs.  Theorem-family heads are
-- side-neutral loaded structure: landmarks, with sectioning.
hl("texEnvArgNameThm", { fg = C.green, bold = true })
-- Loaded structure (proof envs, gentzen, hilbertlist): the mint rung
-- between landmarks and plain containers
hl("texEnvArgNameLoaded", { fg = C.green_loaded, bold = true })

------------------------------------------------------------------------
-- ARGUMENT-GROUP LINKS  —  computed in lua/plugins/vimtex.lua
------------------------------------------------------------------------
-- VimTeX generates a tex[Math]C<Name>Arg group per custom command; the
-- vimtex spec records which colour group each should follow (its
-- argstyle key can't express this).  Applied here, after the
-- colorscheme, so the links survive `:hi clear`.
for group, target in pairs(vim.g.french_logic_arg_links or {}) do
  hl(group, { link = target })
end
