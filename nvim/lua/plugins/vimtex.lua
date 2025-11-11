return {
  "lervag/vimtex",
  lazy = false,
  ft = { "tex", "plaintex", "latex" },

  init = function()
    -- Viewer / compiler
    vim.g.vimtex_view_method = "general"
    vim.g.vimtex_view_general_viewer = "okular"
    vim.g.vimtex_view_general_options = "--unique file:@pdf\\#src:@line@tex"
    vim.g.vimtex_view_automatic = 1
    vim.g.vimtex_compiler_method = "latexmk"
    vim.g.vimtex_compiler_progname = "nvr"

    -- Project root & include scanning
    vim.g.vimtex_root_markers = { "dissertation.tex", ".latexmkrc", ".git" }
    vim.g.vimtex_include_search_enabled = 1
    vim.g.vimtex_include_search_paths = { ".", "..", "../..", "article" }
    vim.g.vimtex_includegraphics_search_paths = { ".", "figures", "imgs", "img", "graphics" }

    -- Completion (leave braces + use filetype intelligence)
    vim.g.vimtex_complete_enabled = 1
    vim.g.vimtex_complete_close_braces = 1
    vim.g.vimtex_complete_recursive_bib = 1
    -- Let '=' reindent be a bit smarter in TeX files (helps with environments)
    vim.g.vimtex_indent_enabled = 1

    -- Quickfix noise (keep off unless you want auto-open)
    vim.g.vimtex_quickfix_mode = 0

    -- Syntax & conceal (you prefer raw source, keep conceal off)
    vim.g.vimtex_syntax_conceal_disable = 1

    -- Teach VimTeX about a few custom commands/environments for syntax highlighting.
    -- (Optional but nice: makes them “look” first-class; does not harm completion.)
    -- Add yours here as you wish:
    -- vim.g.vimtex_syntax_custom_cmds = {
    --   -- plain names are fine; add dicts later if you need arg-specific rules
    --   "proofsetl",
    -- }
    vim.g.vimtex_syntax_custom_envs = {
      -- "hilbertlist", "proofsketch",
    }
  end,
}
