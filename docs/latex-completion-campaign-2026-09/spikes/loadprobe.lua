-- Read-only probe, build chat 3 (2026-09-13): the cost of loading a buffer's closure of generated files into LuaSnip, parse split from construction, heap after a full GC (throwaway instance).
-- Run: NVIM_NOSESSION=1 nvim --headless FILE.tex +"lua dofile('loadprobe.lua')" +qa!
local ok = vim.wait(20000, function() return vim.b.vimtex ~= nil end, 100)
if not ok then print("FAIL"); vim.cmd("cq") end
local root = vim.fn.stdpath("config") .. "/lua/snippets"
local ls = require("luasnip")
package.preload["snippets.helpers"] = function()
  local f = ls.function_node
  return {
    mathwrap = function(nodes) local o = { f(function() return "$" end) } for _, n in ipairs(nodes) do o[#o+1] = n end o[#o+1] = f(function() return "$" end) return o end,
    in_env = function(_) return function() return true end end,
  }
end
local function path(name)
  for _, d in ipairs({ "pkg", "sty" }) do local p = root .. "/" .. d .. "/" .. name .. ".lua"; if vim.uv.fs_stat(p) then return p end end
end
collectgarbage("collect")
local base = collectgarbage("count") / 1024
local roots = { "tex", "latex-document", "latex-dev", "class-" .. (vim.b.vimtex.documentclass or "") }
for _, p in ipairs(vim.fn.sort(vim.fn.keys(vim.b.vimtex.packages))) do roots[#roots+1] = p end
local seen, order, chunks = {}, {}, {}
local queue = vim.deepcopy(roots)
local t0 = vim.uv.hrtime()
-- pass 1: closure by reading only the includes line (cheap), like the loader could
while #queue > 0 do
  local n = table.remove(queue, 1)
  if not seen[n] then
    seen[n] = true
    local p = path(n)
    if p then
      order[#order+1] = p
      for line in io.lines(p) do
        local inc = line:match("^  includes = {(.*)},$")
        if inc then for name in inc:gmatch('"([^"]+)"') do queue[#queue+1] = name end break end
      end
    end
  end
end
local t_walk = (vim.uv.hrtime() - t0) / 1e6
t0 = vim.uv.hrtime()
for i, p in ipairs(order) do chunks[i] = assert(loadfile(p)) end
local t_parse = (vim.uv.hrtime() - t0) / 1e6
t0 = vim.uv.hrtime()
local rows = 0
for i, chunk in ipairs(chunks) do local tbl = chunk(); rows = rows + #tbl.snippets; ls.add_snippets("pkg-" .. i, tbl.snippets, { key = "pkg-" .. i }) end
local t_exec = (vim.uv.hrtime() - t0) / 1e6
local dirty = collectgarbage("count") / 1024
collectgarbage("collect")
local clean = collectgarbage("count") / 1024
print(string.format("files=%d rows=%d | includes walk %.0f ms | loadfile (parse+compile) %.0f ms | execute+add %.0f ms | heap base %.0f MB, after load %.0f MB, after full GC %.0f MB",
  #order, rows, t_walk, t_parse, t_exec, base, dirty, clean))
-- per-snippet construction cost, isolated
local s, t, i = ls.snippet, ls.text_node, ls.insert_node
t0 = vim.uv.hrtime()
for k = 1, 2000 do local _ = s({ trig = "\\x" .. k, dscr = "{a}{b}" }, { t("\\x{"), i(1, "a"), t("}{"), i(2, "b"), t("}") }) end
print(string.format("ls.snippet() x2000 (2 placeholders): %.1f us each", (vim.uv.hrtime() - t0) / 1e3 / 2000))
