local S = os.getenv("SPIKES") or "."
local ok = vim.wait(20000, function() return vim.b.current_syntax == "tex" and vim.b.vimtex_syntax_did_postinit == 1 end, 100)
if not ok then print("TIMEOUT " .. vim.fn.expand("%:t")); return end
local names = {}
for line in io.lines(S .. "/m-names.txt") do local n = line:match("^(%S+)"); if n then names[#names + 1] = n end end
local CAP = 3
local seen, out = {}, {}
local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
for lnum, raw in ipairs(lines) do
  local l = raw:gsub("\\\\", "  "):gsub("([^\\])%%.*", "%1")
  for _, n in ipairs(names) do
    if (seen[n] or 0) < CAP then
      local s_ = l:find("\\" .. n:gsub("%*", "%%*") .. "%f[^%a]")
      if s_ then
        seen[n] = (seen[n] or 0) + 1
        local inm = vim.fn["vimtex#syntax#in_mathzone"](lnum, s_) == 1
        out[#out + 1] = string.format("%s\t%s\t%s:%d\t%s", n, inm and "math" or "TEXT", vim.fn.expand("%:t"), lnum, vim.trim(raw):sub(1, 70):gsub("\t", " "))
      end
    end
  end
end
for _, o in ipairs(out) do print(o) end
