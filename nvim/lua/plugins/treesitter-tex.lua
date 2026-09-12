-- lua/plugins/treesitter-tex.lua
-- Keep Treesitter HIGHLIGHTING off for TeX buffers so that VimTeX's syntax
-- engine is the sole highlighter.
--
-- This is a second lock, not the first.  LazyVim's default parser set has
-- no latex parser, and its FileType hook returns before reading this
-- disable list whenever no parser is installed, so today the entry is
-- inert.  It starts doing work only if a latex parser ever arrives
-- (`:TSInstall latex`, or the LazyVim tex extra), and even then it blocks
-- highlighting only: folding would switch to the tree, and the flash and
-- mini.ai tree-based keys would wake up.  Indent would stay VimTeX's,
-- because LazyVim declines to override an indentexpr that a plugin set.
-- The port itself was measured and declined 2026-09-12: the pinned grammar
-- rejects `\item[(\Kax)]`-style labels, 313 of them in the dissertation.
--
-- This overrides LazyVim's default treesitter config additively.

return {
  "nvim-treesitter/nvim-treesitter",
  opts = function(_, opts)
    -- Ensure the highlight.disable table exists, then add "latex"
    opts.highlight = opts.highlight or {}
    opts.highlight.disable = opts.highlight.disable or {}
    table.insert(opts.highlight.disable, "latex")
  end,
}
