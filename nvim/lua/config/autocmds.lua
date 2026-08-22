-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- vim.o.autowriteall = true
--
-- Aggressive auto-save, deliberately.  Note it is NOT insert-mode-only:
-- InsertLeavePre fires on leaving insert, and TextChanged fires on every
-- *normal-mode* change too — so x, dd, p and u each write the file as well.
-- For *.lua that write also runs LazyVim's format-on-save (stylua), which
-- measured 190 ms on this repo's largest Lua file.
--
-- The augroup is the only thing added here (2026-08-22): without one, these
-- autocmds are anonymous, so anything that re-sources this file — `:source`,
-- a LazyVim config reload — registers a *second* identical copy rather than
-- replacing the first, and every change then writes twice, then three times.
-- `clear = true` makes re-sourcing idempotent.  No behaviour change otherwise.
vim.api.nvim_create_autocmd({ "InsertLeavePre", "TextChanged" }, {
  group = vim.api.nvim_create_augroup("bph_autosave", { clear = true }),
  pattern = { "*.html", "*.tex", "*.sty", "*.bib*", "*.cls", "*.css", "*.lua", "*.md" },
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
