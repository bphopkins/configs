return {
  "lervag/vimtex",
  lazy = false,
  ft = { "tex", "plaintex", "latex" },

  init = function()
    -- Viewer / compiler (your existing config is good)
    vim.g.vimtex_view_method = "general"
    vim.g.vimtex_view_general_viewer = "okular"
    vim.g.vimtex_view_general_options = "--unique file:@pdf\\#src:@line@tex"
    vim.g.vimtex_view_automatic = 1
    vim.g.vimtex_compiler_method = "latexmk"
    vim.g.vimtex_compiler_progname = "nvr"

    -- Project root & include scanning
    vim.g.vimtex_root_markers = { "dissertation.tex", ".latexmkrc", ".git" }
    vim.g.vimtex_include_search_enabled = 1

    -- ADD THIS to help VimTeX find your custom packages
    vim.g.vimtex_texmf_home = vim.fn.expand("~/texmf")

    -- Expand search paths to include parent directories
    vim.g.vimtex_includegraphics_search_paths = { ".", "figures", "imgs", "img", "graphics" }

    -- Completion settings
    vim.g.vimtex_complete_enabled = 1
    vim.g.vimtex_complete_close_braces = 1 -- 0 was fine too
    vim.g.vimtex_complete_recursive_bib = 1
    vim.g.vimtex_complete_input_paths = {
      vim.fn.expand("~/texmf/tex/latex"),
    }

    -- ADD THIS for better custom command detection
    vim.g.vimtex_complete_scan_files_depth = 3 -- Scan deeper for commands

    vim.g.vimtex_indent_enabled = 1
    vim.g.vimtex_imaps_enabled = 0
    vim.g.vimtex_quickfix_mode = 0
    vim.g.vimtex_syntax_conceal_disable = 1

    -- Critical for extensive custom commands
    vim.g.tex_flavor = "latex"

    -- Tell VimTeX about your custom package location
    vim.g.vimtex_include_search_paths = {
      ".",
      "..",
      "../..",
      "article",
      vim.fn.expand("~/texmf/tex/latex"),
      vim.fn.expand("~/texmf/tex/latex/local"),
    }
  end,
}
