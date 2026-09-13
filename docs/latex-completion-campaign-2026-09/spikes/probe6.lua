local ok = vim.wait(20000, function() return vim.b.vimtex ~= nil and vim.b.vimtex_syntax_did_postinit == 1 end, 100)
if not ok then print("FAIL"); vim.cmd("cq") end
local function time(label, n, fn)
  local t0 = vim.uv.hrtime(); for _ = 1, n do fn() end
  print(string.format("%-58s %.3f ms per call", label, (vim.uv.hrtime() - t0) / n / 1e6))
end
time("vim.b.vimtex.packages (converts the whole b:vimtex dict)", 50, function() local _ = vim.b.vimtex.packages end)
time("vim.fn.eval('keys(b:vimtex.packages)')", 200, function() local _ = vim.fn.eval("keys(b:vimtex.packages)") end)
time("vim.fn.eval('len(b:vimtex.packages)')  (change signal)", 200, function() local _ = vim.fn.eval("len(b:vimtex.packages)") end)
time("vim.fn['vimtex#syntax#in_mathzone']() at cursor", 50, function() local _ = vim.fn["vimtex#syntax#in_mathzone"]() end)
-- re-registration under a fixed key
local ls = require("luasnip")
local s, t = ls.snippet, ls.text_node
ls.add_snippets("pkg-keytest", { s({ trig = "\\kt-one" }, { t("1") }), s({ trig = "\\kt-two" }, { t("2") }) }, { key = "pkg-keytest" })
ls.add_snippets("pkg-keytest", { s({ trig = "\\kt-three" }, { t("3") }) }, { key = "pkg-keytest" })
local trigs = {}
for _, sn in ipairs(ls.get_snippets("pkg-keytest")) do trigs[#trigs + 1] = sn.trigger end
print("after re-adding under the same key, registered triggers: " .. table.concat(trigs, " "))
print("b:vimtex dict size (keys): " .. #vim.tbl_keys(vim.b.vimtex) .. "; packages: " .. #vim.tbl_keys(vim.b.vimtex.packages))
