-- Syntax-layer cost gauge (read-only).  Run via perf.sh with a real
-- .tex file; measures a full-file synID sweep with the custom command
-- layer, then strips the layer in the same session and re-measures.
-- The delta is the whole semantic apparatus's cost on this machine.
--
-- A W325 swapfile notice just means the file is open in another nvim;
-- the sweep reads syntax state only and writes nothing.
--
-- Baseline for orientation (bigfed, 2026-08-28, completeness.tex,
-- 572 lines): 402 ms with / 137 ms without = 0.46 ms/line custom cost.
-- Per keystroke only the current line re-evaluates, so anything under
-- ~2 ms/line is imperceptible in insert mode.

local ok = vim.wait(20000, function()
  return vim.b.current_syntax == "tex" and vim.b.vimtex_syntax_did_postinit == 1
end, 100)
if not ok then
  print("FAIL: tex syntax / vimtex postinit never loaded")
  vim.cmd("cq")
end

local function sweep()
  local n = vim.api.nvim_buf_line_count(0)
  local t0 = vim.uv.hrtime()
  for l = 1, n do
    local len = #vim.fn.getline(l)
    if len > 0 then
      vim.fn.synID(l, len, 1)
    end
  end
  return (vim.uv.hrtime() - t0) / 1e6, n
end

vim.cmd("syntime on")
local with_ms, n = sweep()
vim.cmd("syntime off")

vim.g.vimtex_syntax_custom_cmds = {}
vim.cmd("edit!")
vim.wait(20000, function()
  return vim.b.current_syntax == "tex" and vim.b.vimtex_syntax_did_postinit == 1
end, 100)
local without_ms = sweep()

local delta = with_ms - without_ms
print(string.format("file lines:        %d", n))
print(string.format("with custom layer: %.0f ms   without: %.0f ms", with_ms, without_ms))
print(string.format("CUSTOM LAYER COST: %.0f ms full file = %.2f ms/line", delta, delta / n))
if delta / n < 2.0 then
  print("VERDICT: ok — imperceptible per keystroke (one line re-evaluates)")
else
  print("VERDICT: hot — run ':syntime report' interactively and prune the top patterns")
end
