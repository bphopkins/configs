-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- vim.o.autowriteall = true
vim.api.nvim_create_autocmd({ "InsertLeavePre", "TextChanged" }, {
  pattern = { "*.html", "*.tex", "*.sty", "*.bib*", "*.cls", "*.css", "*.lua" },
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
