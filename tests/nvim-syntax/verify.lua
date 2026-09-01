-- Headless regression check for the french-logic VimTeX syntax layer.
-- Run via run.sh; expects test.tex to be the current buffer.
--
-- Guards the failure modes found on 2026-07-26 and 2026-08-28:
--   * cmdre entries without `name` are silently dropped by VimTeX
--   * argstyle can't carry highlight groups (arglink() mechanism)
--   * env-name family matches in after/syntax/tex.lua
--   * Vim group names are CASE-INSENSITIVE: a lowercase family slug
--     that matches an uppercase one merges their groups and the first
--     `hi def link` wins (\cmr rendered as an Axiom for months)
--   * VimTeX's default arg machinery emits a zero-width match that
--     blocks a custom command DIRECTLY after another one
--     (\omega\trues, \to\may) — pinned by the adjacency checks
-- plus one representative command per registered family.  If a VimTeX
-- update changes any of this, checks here go red before your documents
-- go blue.

local ok = vim.wait(15000, function()
  return vim.b.current_syntax == "tex" and vim.b.vimtex_syntax_did_postinit == 1
end, 100)
if not ok then
  print("FAIL: tex syntax / vimtex postinit never loaded")
  vim.cmd("cq")
end

local function fg_of(group)
  -- a matched group must also carry a defined foreground: a rename that
  -- desyncs vimtex.lua from the ftplugin leaves the link chain intact
  -- but colourless, which the name pins alone cannot see
  return vim.fn.synIDattr(vim.fn.hlID(group), "fg#")
end

local function group_at(pattern)
  -- find pattern in the buffer, return the resolved syntax group at its
  -- first character (through highlight links, to the final colour group).
  -- \C forces case-sensitive search: the config sets 'ignorecase', under
  -- which a lowercase pattern like \cmr\> would find \CMr first and the
  -- collision pin would test the wrong token.
  local pat = [[\C]] .. pattern
  local lnum = vim.fn.search(pat, "nw")
  if lnum == 0 then
    return "NOTFOUND"
  end
  local col = vim.fn.match(vim.fn.getline(lnum), pat) + 1
  return vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.synID(lnum, col, 1)), "name")
end

local checks = {
  -- { search pattern, expected group, label [, neq = true] }
  -- environment-name families (after/syntax/tex.lua)
  { [[\<theorem\>]], "texEnvArgNameThm", "begin{theorem} name" },
  { [[\<definition\>]], "texEnvArgNameThm", "begin{definition} name" },
  { [[\<proof\>]], "texEnvArgNameLoaded", "begin{proof} name" },
  { [[\<proofsketch\>]], "texEnvArgNameLoaded", "begin{proofsketch} name" },
  { [[\<hilbertlist\>]], "texEnvArgNameLoaded", "begin{hilbertlist} loaded rung" },
  { [[\<tabular\>]], "texEnvArgName", "begin{tabular} default" },
  -- names of syntactic objects
  { [[\\cax\>]], "texCmdNameSyn", "\\cax axiom (axfam pattern)" },
  { [[\\CMr\>]], "texCmdNameSyn", "\\CMr schema (CCMfam)" },
  { [[\\Kfour\>]], "texCmdNameSyn", "\\Kfour system" },
  { [[\\EN\>]], "texCmdNameSyn", "\\EN system" },
  { [[\\mprule\>]], "texCmdNameSyn", "\\mprule rule name" },
  -- names of semantic objects; \cmr also pins the group-name-collision
  -- fix (slug ccmcond, NOT ccmfam ≅ CCMfam)
  { [[\\cmr\>]], "texCmdNameSem", "\\cmr condition (collision pin)" },
  { [[\\Rup\>]], "texCmdNameSem", "\\Rup order condition" },
  -- metalinguistic relations; \trues sits DIRECTLY after \omega and
  -- \proves directly after \logic — the adjacency pins
  { [[\\trues\>]], "texCmdTurnstileSem", "\\trues (adjacency pin)" },
  { [[\\proves\>]], "texCmdTurnstileSyn", "\\proves (adjacency pin)" },
  { [[\\defby\>]], "texCmdGround", "\\defby untouched by de-pattern" },
  -- intensional operators; \may sits directly after \to
  { [[\\ought\>]], "texCmdIntension", "\\ought deontic" },
  { [[\\may\>]], "texCmdIntension", "\\may (adjacency pin)" },
  { [[\\cnecs\>]], "texCmdIntension", "\\cnecs conditional" },
  { [[\\deland\>]], "texCmdIntension", "\\deland de-family" },
  { [[\\af\>]], "texCmdIntension", "\\af affirm" },
  -- glue and terms
  { [[\\to\>]], "texCmdConnective", "\\to object connective" },
  { [[\\land\>]], "texCmdConnective", "\\land stock boolean (stockbool)" },
  { [[\\M\>]], "texCmdSemObj", "\\M structure letter" },
  { [[\\Rlog\>]], "texCmdSemObj", "\\Rlog canonical model" },
  { [[\\mlnot\>]], "texCmdGround", "\\mlnot metalang" },
  { [[\\mland\>]], "texCmdGround", "\\mland metalang" },
  { [[\\tuple\>]], "texCmdGround", "\\tuple notation" },
  { [[\\truthset\>]], "texCmdSemObj", "\\truthset semantic object" },
  { [[\\proofsetl\>]], "texCmdSynObj", "\\proofsetl syntactic object" },
  { [[\\logic\>]], "texCmdSynObj", "\\logic is proof-theoretic" },
  { [[\\langd\>]], "texCmdSynObj", "\\langd language (langfam)" },
  { [[\\langle\>]], "texCmdGround", "\\langle NOT in langfam", neq = true },
  -- variables
  { [[\\omega\>]], "texCmdVariable", "\\omega variable (greekfam)" },
  { [[\\pzero\>]], "texCmdVariable", "\\pzero atom = variable" },
  -- scaffolding; \midrule pins the booktabs carve-out from rulefam
  { [[\\by\>]], "texCmdScaffold", "\\by justification" },
  { [[\\close\>]], "texCmdScaffold", "\\close helper" },
  { [[\\infr\>]], "texCmdScaffold", "\\infr helper" },
  { [[\\midrule\>]], "texCmdScaffold", "\\midrule booktabs (not a Rule)" },
  { [[\\qed\>]], "texCmdQed", "\\qed marker" },
  -- argument-group links (arglink mechanism)
  { [[ZZ]], "texArgSemObj", "\\truthset arg link" },
  { [[YY]], "texArgSynObj", "\\proofsetl arg link" },
  { [[QQ]], "texArgFormula", "\\hyp arg link" },
  { [[PP]], "texArgName", "\\parent arg link" },
  { [[RR]], "texArgName", "\\by arg link" },
}

local fails = 0
for _, c in ipairs(checks) do
  local got = group_at(c[1])
  local bad = c.neq and (got == c[2]) or (not c.neq and got ~= c[2])
  if bad then
    fails = fails + 1
    print(string.format("FAIL %-36s got=%s %s=%s", c[3], got, c.neq and "forbade" or "want", c[2]))
  elseif not c.neq and fg_of(got) == "" then
    fails = fails + 1
    print(string.format("FAIL %-36s group %s has no colour", c[3], got))
  else
    print(string.format("ok   %-36s %s", c[3], got))
  end
end
if fails > 0 then
  print(fails .. " failure(s)")
  vim.cmd("cq")
else
  print("ALL PASS (" .. #checks .. " checks)")
end
