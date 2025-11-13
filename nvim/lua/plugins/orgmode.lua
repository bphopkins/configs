return {
  "nvim-orgmode/orgmode",
  event = "VeryLazy",
  config = function()
    require("orgmode").setup({
      org_agenda_files = "~/Desktop/orgfiles/**/*",
      org_default_notes_file = "~/Desktop/orgfiles/refile.org",
    })
  end,
}
