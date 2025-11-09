return {
  "lervag/vimtex",
  lazy = false, -- we don't want to lazy load VimTeX
  ft = { "tex", "plaintex", "latex" },
  init = function()
    vim.g.vimtex_view_method = "general"
    vim.g.vimtex_view_general_viewer = "okular"
    vim.g.vimtex_view_general_options = "--unique file:@pdf\\#src:@line@tex"
    vim.g.vimtex_view_automatic = 1
    vim.g.vimtex_compiler_method = "latexmk"
    vim.g.vimtex_compiler_progname = "nvr"
    vim.g.vimtex_quickfix_mode = 0
    vim.g.vimtex_complete_enabled = 1
    vim.g.vimtex_complete_close_braces = 1
    vim.g.vimtex_complete_recursive_bib = 1
    vim.g.vimtex_include_search_enabled = 1

    -- Disable concealment
    vim.g.vimtex_syntax_conceal_disable = 1
    -- Or if you want more granular control:
    -- vim.g.vimtex_syntax_conceal = {
    --   accents = 0,
    --   ligatures = 0,
    --   cites = 0,
    --   fancy = 0,
    --   spacing = 0,
    --   greek = 0,
    --   math_bounds = 0,
    --   math_delimiters = 0,
    --   math_fracs = 0,
    --   math_super_sub = 0,
    --   math_symbols = 0,
    --   sections = 0,
    --   styles = 0,
    -- }
  end,
}
