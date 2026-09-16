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

-- CTRL-D / CTRL-U step, in DISPLAY rows (2026-09-15).
--
-- 'scroll' is what CTRL-D and CTRL-U move by, and under 'smoothscroll' --
-- which LazyVim sets -- it counts *display* rows, not buffer lines.  That
-- matters here because the prose in this tree is soft-wrapped, one paragraph
-- per buffer line (completeness.tex averages 153 characters and peaks at
-- 1841, twenty screen rows at a 106-column window), so a step counted in
-- buffer lines would land somewhere different on every press.  Measured with
-- smoothscroll on, the step is exact: 'scroll'=10 moves ten rows, every time.
--
-- Vim's default is half the window, 27 rows here, which overshoots what the
-- eye can follow.  Ten is his.
--
-- The autocmd is the mechanism because 'scroll' is **window-local and Vim
-- resets it to half the window height on every size change** -- a plain
-- `vim.opt.scroll = 10` in options.lua sets the first window and is then
-- silently clobbered by the next resize or split (measured: 10 -> 19 after a
-- resize to 40 rows, 13 in a new :split).  So it is re-applied on the events
-- that reset it, to every window rather than just the current one, since a
-- resize changes them all at once.
--
-- The height guard is load-bearing, not housekeeping.  Setting 'scroll'
-- larger than its window raises E49: Invalid scroll size, and this fires on
-- WinNew, so without the guard every short-lived small window -- a completion
-- menu, a popup -- throws on creation.  Verified by mutation 2026-09-15:
-- dropping the guard does not fail a check, it aborts the whole latency suite
-- on the first WinNew.  It is also right on the merits: in a window of ten
-- rows or fewer a ten-row step is a whole page, and Vim's half-window default
-- is the better answer there.  Failure direction stays safe either way -- if
-- the autocmd never fires, 'scroll' is simply Vim's default again.
--
-- To tune: change SCROLL.  To revert: delete this block.
local SCROLL = 10
vim.api.nvim_create_autocmd({ "VimEnter", "WinEnter", "WinNew", "VimResized", "WinResized" }, {
  group = vim.api.nvim_create_augroup("bph_scroll_step", { clear = true }),
  callback = function()
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_height(win) > SCROLL then
        vim.wo[win].scroll = SCROLL
      end
    end
  end,
})
