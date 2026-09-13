local ok = vim.wait(20000, function() return vim.b.vimtex ~= nil and vim.b.vimtex_syntax_did_postinit == 1 end, 100)
if not ok then print("FAIL: vimtex never initialised"); vim.cmd("cq") end
local function show(kind, input, ctx, n)
  local t0 = vim.uv.hrtime()
  local res = vim.fn["vimtex#complete#complete"](kind, input, ctx)
  local ms = (vim.uv.hrtime() - t0) / 1e6
  print(string.format("--- %s  input=%q  -> %d candidates in %.1f ms", kind, input, #res, ms))
  for i = 1, math.min(n or 5, #res) do
    local c = res[i]
    print(string.format("   word=%-28s menu=%s", c.word, tostring(c.menu or c.kind or "")))
  end
end
show("bib", "lewis", "\\cite{")
show("bib", "Counterfactuals", "\\cite{", 3)
show("bib", "deontic", "\\tcite{", 4)
show("ref", "thm", "\\cref{")
show("ref", "def:", "\\cref{", 4)
show("env", "ali", "\\begin{", 6)
show("pck", "ams", "\\usepackage{", 6)
show("cmd", "cne", "\\", 6)
