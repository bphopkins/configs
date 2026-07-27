-- Headless regression check for the french-logic VimTeX syntax layer.
-- Run via run.sh; expects test.tex to be the current buffer.
--
-- Guards the three failure modes found (and fixed) on 2026-07-26:
--   * cmdre entries without `name` are silently dropped by VimTeX
--   * argstyle can't carry highlight groups (arglink() mechanism)
--   * env-name family matches in after/syntax/tex.lua
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

local function group_at(pattern)
  -- find pattern in the buffer, return the resolved syntax group at its
  -- first character (through highlight links, to the final colour group)
  local lnum = vim.fn.search(pattern, "nw")
  if lnum == 0 then
    return "NOTFOUND"
  end
  local col = vim.fn.match(vim.fn.getline(lnum), pattern) + 1
  return vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.synID(lnum, col, 1)), "name")
end

local checks = {
  -- { search pattern, expected group, label }
  -- environment-name families (after/syntax/tex.lua)
  { [[\<theorem\>]], "texEnvArgNameThm", "begin{theorem} name" },
  { [[\<definition\>]], "texEnvArgNameThm", "begin{definition} name" },
  { [[\<proof\>]], "texEnvArgNameProof", "begin{proof} name" },
  { [[\<proofsketch\>]], "texEnvArgNameProof", "begin{proofsketch} name" },
  { [[\<hilbertlist\>]], "texEnvArgName", "begin{hilbertlist} default" },
  -- one representative per command family (pattern registrations)
  { [[\\cax\>]], "texCmdAxiom", "\\cax axiom (axfam pattern)" },
  { [[\\Rup\>]], "texCmdFrameCond", "\\Rup order condition" },
  { [[\\Kfour\>]], "texCmdLogicSys", "\\Kfour system" },
  { [[\\EN\>]], "texCmdLogicSys", "\\EN system" },
  { [[\\Rlog\>]], "texCmdSemantic", "\\Rlog canonical model" },
  { [[\\mlnot\>]], "texCmdSemantic", "\\mlnot metalang" },
  { [[\\mland\>]], "texCmdSemantic", "\\mland metalang" },
  { [[\\af\>]], "texCmdModalOp", "\\af affirm" },
  { [[\\deland\>]], "texCmdModalOp", "\\deland de-family" },
  { [[\\precedes\>]], "texCmdModalOp", "\\precedes temporal" },
  { [[\\mprule\>]], "texCmdRule", "\\mprule rule" },
  { [[\\by\>]], "texCmdRule", "\\by justification" },
  { [[\\close\>]], "texCmdRule", "\\close helper" },
  { [[\\infr\>]], "texCmdRule", "\\infr helper" },
  { [[\\qed\>]], "texCmdRule", "\\qed marker" },
  { [[\\tuple\>]], "texCmdNotation", "\\tuple notation" },
  -- pattern anchoring: the de-family must NOT swallow \defby
  { [[\\defby\>]], "texCmdNotation", "\\defby untouched by de-pattern" },
  -- argument-group links (arglink mechanism)
  { [[ZZ]], "texArgSemantic", "\\truthset arg link" },
  { [[QQ]], "texCmdRule", "\\hyp arg link" },
}

local fails = 0
for _, c in ipairs(checks) do
  local got = group_at(c[1])
  if got ~= c[2] then
    fails = fails + 1
    print(string.format("FAIL %-34s got=%s want=%s", c[3], got, c[2]))
  else
    print(string.format("ok   %-34s %s", c[3], got))
  end
end
if fails > 0 then
  print(fails .. " failure(s)")
  vim.cmd("cq")
else
  print("ALL PASS (" .. #checks .. " checks)")
end
