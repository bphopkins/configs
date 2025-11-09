return {
  "brianhuster/live-preview.nvim",
  -- optional: lazy-load only for relevant filetypes
  ft = { "html", "markdown", "asciidoc", "svg" },

  config = function()
    require("live-preview").setup({
      -- defaults are fine; these are just common tweaks:

      -- force a specific browser (otherwise it uses your system default)
      -- browser = 'firefox',

      -- port = 5500,        -- default
      -- sync_scroll = false, -- you can turn this on for MD/AsciiDoc
      -- autokill = false,    -- whether to auto-kill server on quit
    })
  end,
}
