return {
  "lervag/vimtex",
  lazy = false, -- load eagerly; VimTeX manages its own on-demand behaviour
  ft = { "tex", "plaintex", "latex" }, -- still helpful for some plugin UIs

  init = function()
    --------------------------------------------------------------------
    -- VIEWER / COMPILER
    --
    -- These options control how compiled PDFs are viewed, and how the
    -- LaTeX compiler is invoked. They are independent of completion,
    -- but tightly coupled to your OS-level tooling (Okular + latexmk).
    --------------------------------------------------------------------
    vim.g.vimtex_view_method = "general"
    vim.g.vimtex_view_general_viewer = "okular"
    vim.g.vimtex_view_general_options = "--unique file:@pdf\\#src:@line@tex"
    vim.g.vimtex_view_automatic = 1
    vim.g.vimtex_compiler_method = "latexmk"
    vim.g.vimtex_compiler_progname = "nvr" -- use Neovim remote for callbacks

    --------------------------------------------------------------------
    -- PROJECT ROOT / INCLUDE SCANNING
    --
    -- Root markers tell VimTeX how to find the project root. Include
    -- scanning + include paths support \input, \include, \includegraphics, etc.
    --------------------------------------------------------------------
    vim.g.vimtex_root_markers = { "dissertation.tex", ".latexmkrc", ".git" }
    vim.g.vimtex_include_search_enabled = 1

    -- Help VimTeX find custom packages in your personal TEXMF tree.
    vim.g.vimtex_texmf_home = vim.fn.expand("~/texmf")

    -- Search paths for \includegraphics; relative to the TeX project root.
    vim.g.vimtex_includegraphics_search_paths = { ".", "figures", "imgs", "img", "graphics" }

    --------------------------------------------------------------------
    -- COMPLETION SETTINGS
    --
    -- These control what completion information VimTeX *provides*.
    -- The actual UI and ranking of completion items is handled by
    -- blink.cmp + cmp-vimtex in completions.lua.
    --------------------------------------------------------------------
    vim.g.vimtex_complete_enabled = 1 -- VimTeX builds completion data (used by cmp-vimtex)
    -- NOTE: LuaSnip is still the snippet engine; this toggle affects only
    -- VimTeX's semantic completions (labels, cites, macros), not snippet expansion.

    vim.g.vimtex_complete_close_braces = 1 -- auto-close some braces in completions (e.g. \cite{...})
    vim.g.vimtex_complete_recursive_bib = 1 -- recurse into \bibliography / \addbibresource files

    -- Where VimTeX should look for TeX package files when building completion data.
    vim.g.vimtex_complete_input_paths = {
      vim.fn.expand("~/texmf/tex/latex"),
    }

    -- Scan includes a bit deeper for custom commands and environments; this
    -- helps completion find macros defined in subfiles.
    vim.g.vimtex_complete_scan_files_depth = 3 -- Scan deeper for commands

    --------------------------------------------------------------------
    -- INDENTATION / KEYMAPS / UI TWEAKS
    --------------------------------------------------------------------
    vim.g.vimtex_indent_enabled = 1

    -- Disable VimTeX's insert-mode mappings ("imaps"). This keeps it from
    -- adding its own $...$, \left...\right, etc. and lets your autopairs /
    -- snippet setup handle delimiters instead.
    vim.g.vimtex_imaps_enabled = 0

    -- Don't automatically open quickfix windows; let you decide when to inspect errors.
    vim.g.vimtex_quickfix_mode = 0

    -- Disable syntax conceal so you always see the raw TeX source (no prettified
    -- symbols that can obscure the actual tokens).
    vim.g.vimtex_syntax_conceal_disable = 1

    --------------------------------------------------------------------
    -- TEX FLAVOUR / INCLUDE SEARCH PATHS
    --------------------------------------------------------------------
    -- Make sure VimTeX treats these files as LaTeX (not plain TeX).
    vim.g.tex_flavor = "latex"

    -- Additional search paths for \input, \include, and friends. This mirrors
    -- your project layout and custom TEXMF tree, so VimTeX can jump and search
    -- across local and personal package locations.
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
