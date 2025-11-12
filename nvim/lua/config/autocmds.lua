-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- vim.o.autowriteall = true
vim.api.nvim_create_autocmd({ "InsertLeavePre", "TextChanged", "TextChangedP" }, {
  pattern = { "*.html", "*.tex", "*.sty", "*.cls", "*.css" },
  callback = function()
    vim.cmd("silent! write")
  end,
})

-- Keep LaTeX word-wrapped (redundant now but explicit)
vim.api.nvim_create_autocmd("FileType", {
  pattern = "tex",
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true
    vim.opt_local.breakindent = true
  end,
})

-- Disable wrap for code where horizontal structure matters
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "python", "lua", "javascript", "c", "cpp", "rust" },
  callback = function()
    vim.opt_local.wrap = false
  end,
})

-- Auto-regenerate VSCode snippets from your macro file on save
-- do
--   local macro_file = "/home/bph/Desktop/configs/latex/french-logic/french-logic.sty" -- ← change this
--   local script = "/home/bph/Desktop/configs/nvim/snippets/generate_tex_snippets.py" -- ← change this
--
--   vim.api.nvim_create_autocmd("BufWritePost", {
--     pattern = macro_file,
--     callback = function(args)
--       vim.fn.jobstart({
--         "python3",
--         script,
--         args.file,
--         "--out",
--         vim.fn.expand("~/Desktop/configs/nvim/snippets/tex.json"),
--         "--prefix",
--         "both",
--       }, {
--         on_exit = function()
--           vim.notify("tex.json snippets regenerated")
--         end,
--       })
--     end,
--   })
-- end
