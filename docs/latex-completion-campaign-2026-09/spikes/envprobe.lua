-- Read-only probe, build chat 3 (2026-09-13): what VimTeX's env completer offers a document at \begin{, and what a parse of it costs.
-- Run: NVIM_NOSESSION=1 nvim --headless FILE.tex +"lua dofile('envprobe.lua')" +qa!  (one instance per file)
-- Read-only probe: what VimTeX's env completer knows, and what a document parse costs.
local ok = vim.wait(20000, function() return vim.b.vimtex ~= nil end, 100)
if not ok then print("FAIL: no b:vimtex"); vim.cmd("cq") end
local st = vim.b.vimtex
local pk = vim.fn.sort(vim.fn.keys(st.packages))
local units = 0
for _, p in ipairs(pk) do if p:match("^french%-logic%-") then units = units + 1 end end
print(string.format("main=%s class=%s packages=%d french-logic units in table=%d", st.tex, st.documentclass or "?", #pk, units))
local function envs(input)
  local t0 = vim.uv.hrtime()
  local r = vim.fn["vimtex#complete#complete"]("env", input, "\\begin{")
  local names = {}
  for i, c in ipairs(r) do if i <= 6 then names[#names + 1] = type(c) == "table" and c.word or c end end
  return string.format("env(%q): %d in %.1f ms [%s]", input, #r, (vim.uv.hrtime() - t0) / 1e6, table.concat(names, " "))
end
print(envs("")); print(envs(""))
for _, q in ipairs({ "hilb", "proofsk", "axiomp", "itemli", "block", "ali", "enum", "cases" }) do print(envs(q)) end
local t0 = vim.uv.hrtime()
local lines = vim.fn["vimtex#parser#tex"](st.tex, { detailed = 0 })
print(string.format("vimtex#parser#tex whole project: %d lines in %.1f ms", #lines, (vim.uv.hrtime() - t0) / 1e6))
t0 = vim.uv.hrtime()
local pre = vim.fn["vimtex#parser#preamble"](st.tex, { root = st.root })
print(string.format("vimtex#parser#preamble: %d lines in %.1f ms", #pre, (vim.uv.hrtime() - t0) / 1e6))
t0 = vim.uv.hrtime()
local main = vim.fn.readfile(st.tex)
print(string.format("readfile(main): %d lines in %.2f ms", #main, (vim.uv.hrtime() - t0) / 1e6))
t0 = vim.uv.hrtime()
local ft = st.getftime and vim.fn["vimtex#util#undefined"] or nil
local ok2, ftime = pcall(function() return vim.fn.eval("b:vimtex.getftime()") end)
print(string.format("b:vimtex.getftime(): %s in %.2f ms (sources=%d)", tostring(ftime), (vim.uv.hrtime() - t0) / 1e6, #vim.fn.eval("b:vimtex.get_sources()")))
