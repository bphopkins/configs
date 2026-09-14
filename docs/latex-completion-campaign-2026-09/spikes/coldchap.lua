-- Read-only probe: VimTeX's env and pck completers on the chapter with the cache root given on the
-- command line (cold on the first instance, warm on the second), each called twice.
local ok = vim.wait(20000, function() return vim.b.vimtex ~= nil end, 100)
if not ok then print("FAIL: no b:vimtex"); vim.cmd("cq") end
print(string.format("packages in table: %d, cache root: %s", vim.tbl_count(vim.b.vimtex.packages), vim.g.vimtex_cache_root))
for _, spec in ipairs({ { "env", "a", "\\begin{" }, { "env", "a", "\\begin{" }, { "pck", "a", "\\usepackage{" }, { "pck", "a", "\\usepackage{" } }) do
  local t0 = vim.uv.hrtime()
  local r = vim.fn["vimtex#complete#complete"](spec[1], spec[2], spec[3])
  print(string.format("  %s %q: %d candidates in %.0f ms", spec[1], spec[3] .. spec[2], #r, (vim.uv.hrtime() - t0) / 1e6))
end
