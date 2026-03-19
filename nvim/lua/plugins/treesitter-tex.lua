-- lua/plugins/treesitter-tex.lua
-- Disable Treesitter HIGHLIGHTING for TeX files so that VimTeX's syntax
-- engine is the sole highlighter.  Other Treesitter features (indent,
-- textobjects, incremental selection) remain available.
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
