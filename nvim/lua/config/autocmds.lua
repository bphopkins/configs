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
-- The augroup (2026-08-22): without one, these autocmds are anonymous, so
-- anything that re-sources this file — `:source`, a LazyVim config reload —
-- registers a *second* identical copy rather than replacing the first, and
-- every change then writes twice, then three times.  `clear = true` makes
-- re-sourcing idempotent.
--
-- The failure path (later the same day): this used to be `silent! write`,
-- which swallows a FAILED write entirely — modified buffer, nothing shown,
-- even v:errmsg empty — so on a full disk (the bigfed ENOSPC class) the
-- invariant "normal mode ⟹ saved" failed without a word, indefinitely.
-- Successful saves are exactly as silent as before; what changed is that
-- the first failure per buffer raises one WARN, repeats stay quiet, and a
-- save succeeding again notes once at INFO — never a stream of messages.
-- Readonly/nomodifiable buffers are skipped outright: they are outside the
-- invariant, not something to fight or shout about.  (`:wqa` remains the
-- quit-time backstop — it refuses to quit over a failing write — this
-- covers the mid-session window where editing continued on a dead disk.)
vim.api.nvim_create_autocmd({ "InsertLeavePre", "TextChanged" }, {
  group = vim.api.nvim_create_augroup("bph_autosave", { clear = true }),
  pattern = { "*.html", "*.tex", "*.sty", "*.bib*", "*.cls", "*.css", "*.lua", "*.md" },
  callback = function(ev)
    local bo = vim.bo[ev.buf]
    if not bo.modifiable or bo.readonly then
      return
    end
    -- LazyVim sets 'confirm', under which a failing :write does not error —
    -- it pops a modal dialog ("file is read-only — override?") and blocks.
    -- An autosave must never prompt (the old `silent!` suppressed the
    -- dialog along with everything else), so drop confirm for the write:
    -- failures then raise catchable errors instead.
    local confirm = vim.o.confirm
    vim.o.confirm = false
    local ok, err = pcall(vim.cmd, "silent write")
    vim.o.confirm = confirm
    local was_failing = vim.b[ev.buf].bph_autosave_failed
    if ok then
      if was_failing then
        vim.b[ev.buf].bph_autosave_failed = nil
        vim.notify(
          "auto-save: "
            .. vim.fn.fnamemodify(vim.api.nvim_buf_get_name(ev.buf), ":t")
            .. " is saving again",
          vim.log.levels.INFO
        )
      end
    elseif not was_failing then
      vim.b[ev.buf].bph_autosave_failed = true
      vim.notify(
        "auto-save FAILED — buffer NOT on disk: " .. tostring(err):gsub("^Vim%(%a+%):", ""),
        vim.log.levels.WARN
      )
    end
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
