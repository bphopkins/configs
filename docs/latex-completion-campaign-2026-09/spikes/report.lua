-- Read-only probe, build chat 3 (2026-09-13): the first ft_func cost and :SnippetsReport on a document, headless.
-- Run: NVIM_NOSESSION=1 nvim --headless FILE.tex +"lua dofile('report.lua')" +qa!
local ok = vim.wait(20000, function() return vim.b.vimtex ~= nil end, 100)
if not ok then print("FAIL: no b:vimtex"); vim.cmd("cq") end
print("messages at open: " .. vim.trim(vim.fn.execute("messages")))
local t0 = vim.uv.hrtime()
local fts = require("luasnip.util.util").get_snippet_filetypes()
print(string.format("first ft_func: %.0f ms, %d filetypes", (vim.uv.hrtime() - t0) / 1e6, #fts))
t0 = vim.uv.hrtime()
fts = require("luasnip.util.util").get_snippet_filetypes()
print(string.format("second ft_func: %.2f ms", (vim.uv.hrtime() - t0) / 1e6))
print(vim.fn.execute("SnippetsReport"))
print("messages at end: " .. vim.trim(vim.fn.execute("messages")))
