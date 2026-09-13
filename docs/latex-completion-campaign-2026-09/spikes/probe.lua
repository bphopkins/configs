local ok = vim.wait(20000, function()
  return vim.b.current_syntax == "tex" and vim.b.vimtex_syntax_did_postinit == 1
end, 100)
if not ok then print("FAIL: syntax never loaded"); vim.cmd("cq") end
local function at(pattern, off)
  local pat = "\\C" .. pattern
  local lnum = vim.fn.search(pat, "nw")
  if lnum == 0 then return pattern .. " NOTFOUND" end
  local col = vim.fn.match(vim.fn.getline(lnum), pat) + 1 + (off or 0)
  local id = vim.fn.synID(lnum, col, 1)
  local tid = vim.fn.synIDtrans(id)
  local bold = vim.fn.synIDattr(tid, "bold") == "1" and " bold" or ""
  local ital = vim.fn.synIDattr(tid, "italic") == "1" and " italic" or ""
  local bg = vim.fn.synIDattr(tid, "bg#")
  return string.format("%-22s raw=%-24s final=%-20s fg=%s%s%s%s", pattern .. (off and off > 0 and ("+" .. off) or ""),
    vim.fn.synIDattr(id, "name"), vim.fn.synIDattr(tid, "name"), vim.fn.synIDattr(tid, "fg#"), bg ~= "" and (" bg=" .. bg) or "", bold, ital)
end
local probes = {
  { "\\\\text{word", 6 }, { "&= b", 0 }, { "x & y", 2 }, { "\\\\left(", 0 }, { "\\\\alpha", 0 },
  { "\\\\text{inner", 6 }, { "%TODO", 0 }, { "%TODO", 6 }, { "|raw|", 1 }, { "\\[label\\]", 1 },
  { "\\\\ref{eq", 5 }, { "\\\\cite{key", 6 }, { "Title here", 0 }, { "hyperfootnotes", 0 },
  { "{\\\\foo}", 2 }, { "\\\\toprule", 0 }, { "\\\\section", 0 }, { "\\\\begin{align}", 7 }, { "\\\\item\\[", 0 },
  { "b \\\\label", 0 }, { "\\\\\\\\$", 0 }, { "Prose \\$", 6 }, { "#1", 0 },
}
print("=== probe.tex ===")
for _, p in ipairs(probes) do print(at(p[1], p[2])) end
local targets = { "Statement", "Type", "Identifier", "Special", "PreCondit", "Delimiter", "Comment", "Todo", "String", "Number", "Operator", "SpecialChar", "Include", "Underlined" }
local seen, n = {}, 0
for _, g in ipairs(targets) do local c = vim.fn.synIDattr(vim.fn.hlID(g), "fg#"); if c ~= "" and not seen[c] then seen[c] = true; n = n + 1 end end
print("VimTeX's 14 default link targets resolve to " .. n .. " distinct fg colours under TokyoNight")
-- audit: groups resolving to a colour the ftplugin never assigned
local palette = {}
for _, c in ipairs({ "#c6ab90","#9ece6a","#1abc9c","#f7768e","#bd9750","#bb9af7","#8f99c9","#545c7e","#737aa2","#7aa2f7","#8fb665","#9aa5ce","#c0caf5","#74acf5","#565f89","#a9b1d6","#7dcfff","#89ddff","#eec584","#d9aa5e","#7396c2","#4fd6b0" }) do palette[c] = true end
local stray, groups, seen2, n2 = {}, 0, {}, 0
for _, g in ipairs(vim.fn.getcompletion("tex", "highlight")) do
  groups = groups + 1
  local tid = vim.fn.synIDtrans(vim.fn.hlID(g))
  local c = vim.fn.synIDattr(tid, "fg#")
  if c ~= "" and not seen2[c] then seen2[c] = true; n2 = n2 + 1 end
  if c ~= "" and not palette[c] then
    local fin = vim.fn.synIDattr(tid, "name")
    stray[fin] = stray[fin] or { c = c, gs = {} }
    table.insert(stray[fin].gs, g)
  end
end
print(groups .. " tex* groups defined resolve to " .. n2 .. " distinct fg colours; those outside the ftplugin's palette:")
for fin, v in pairs(stray) do print(string.format("  -> %-14s %s  via %d groups: %s", fin, v.c, #v.gs, table.concat(v.gs, " "))) end
print("in_mathzone available: " .. vim.fn.exists("*vimtex#syntax#in_mathzone"))
