local ok = vim.wait(20000, function()
  return vim.b.current_syntax == "tex" and vim.b.vimtex_syntax_did_postinit == 1
end, 100)
if not ok then print("FAIL: syntax never loaded"); vim.cmd("cq") end
local function desc(lnum, col)
  local id = vim.fn.synID(lnum, col, 1); local tid = vim.fn.synIDtrans(id)
  return string.format("line %-5d raw=%-24s final=%-20s fg=%s%s", lnum, vim.fn.synIDattr(id, "name"), vim.fn.synIDattr(tid, "name"), vim.fn.synIDattr(tid, "fg#"), vim.fn.synIDattr(tid, "bold") == "1" and " bold" or "")
end
local function at(pattern, off, from)
  vim.fn.cursor(from or 1, 1)
  local lnum = vim.fn.search("\\C" .. pattern, "nW")
  if lnum == 0 then return pattern .. " NOTFOUND" end
  local col = vim.fn.match(vim.fn.getline(lnum), "\\C" .. pattern) + 1 + (off or 0)
  return string.format("%-16s %s", pattern, desc(lnum, col))
end
-- an & inside the first align-family environment
vim.fn.cursor(1, 1)
local al = vim.fn.search("\\\\begin{align", "nW")
if al > 0 then
  local amp = vim.fn.search("&", "nW")
  vim.fn.cursor(al, 1); amp = vim.fn.search("&", "nW")
  print("align at line " .. al .. "; first & after it: " .. (amp > 0 and desc(amp, vim.fn.match(vim.fn.getline(amp), "&") + 1) or "none"))
else print("no align env in this chapter") end
for _, p in ipairs({ { "\\\\left", 0 }, { "\\\\\\\\$", 0 }, { "\\$\\\\", 0 }, { "\\\\mathbb", 0 }, { "\\\\begin{gentzen}", 7 }, { "\\\\text{", 6 }, { "\\\\hyp{", 5 }, { "\\\\frac{", 0 }, { "\\\\textcite{", 0 } }) do print(at(p[1], p[2])) end
