-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Trying to achieve tasteful word-wrap:
vim.opt.wrap = true
vim.opt.linebreak = true
vim.opt.breakindent = true

-- No cursorline *bar* (2026-09-07): tried lighter, darker, and off; off won
-- outright — the cursor is enough.  But `cursorline` is one switch over two
-- features, and turning it off also drops CursorLineNr, the highlighted
-- current-line number that anchors relative-number jumps.  `cursorlineopt`
-- separates them: "number" keeps the anchor and draws no background at all.
-- LazyVim's own options.lua sets cursorline = true and loads before this
-- file, so this is the override.  Snacks' picker and preview windows set the
-- option window-locally and remap CursorLine inside themselves, so their
-- selection bars are unaffected either way.
-- To go fully bare instead, set cursorline = false and drop the opt line.
vim.opt.cursorline = true
vim.opt.cursorlineopt = "number"
