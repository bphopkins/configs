local ok = vim.wait(20000, function() return vim.b.vimtex ~= nil and vim.b.vimtex_syntax_did_postinit == 1 end, 100)
if not ok then print("FAIL"); vim.cmd("cq") end
local function t(kind, input, ctx)
  local t0 = vim.uv.hrtime(); local r = vim.fn["vimtex#complete#complete"](kind, input, ctx)
  return string.format("%s(%q): %d in %.0f ms", kind, input, #r, (vim.uv.hrtime() - t0) / 1e6)
end
print(t("env", "ali", "\\begin{")); print(t("env", "ali", "\\begin{")); print(t("env", "th", "\\begin{"))
print(t("cmd", "cne", "\\")); print(t("cmd", "fr", "\\"))
print(t("bib", "lewis", "\\cite{")); print(t("bib", "hans", "\\cite{"))
print(t("ref", "def:", "\\cref{")); print(t("ref", "thm:", "\\cref{"))
print(t("pck", "ams", "\\usepackage{")); print(t("pck", "ams", "\\usepackage{"))
