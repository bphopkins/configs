
-- lua/plugins/orgmode.lua (or wherever you keep plugin specs)
return {
  "nvim-orgmode/orgmode",
  event = "VeryLazy", -- keep this so agenda/capture mappings are global
  config = function()
    local orgmode = require("orgmode")

    -- Optional but nice: use org's custom Tree‑sitter grammar if you have nvim-treesitter
    -- orgmode.setup_ts_grammar()

    orgmode.setup({
      ------------------------------------------------------------------
      -- Core files & directories
      ------------------------------------------------------------------
      -- Your “one big org repo”:
      org_agenda_files = { "~/Desktop/org/**/*" },
      -- Default inbox / refile target:
      org_default_notes_file = "~/Desktop/org/refile.org",

      ------------------------------------------------------------------
      -- TODO states & logging
      ------------------------------------------------------------------
      -- A simple but useful GTD-ish sequence
      org_todo_keywords = {
        "TODO(t)",   -- generic todo
        "NEXT(n)",   -- next action
        "WAIT(w)",   -- waiting on someone/something
        "|",
        "DONE(d)",
        "CANCELLED(c)",
      },

      -- When you mark something DONE, automatically add a CLOSED timestamp
      org_log_done = "time",
      -- And record LAST_REPEAT for scheduled repeating tasks
      org_log_repeat = "time",
      -- Put all that logging into a LOGBOOK drawer instead of cluttering the body
      org_log_into_drawer = "LOGBOOK",

      ------------------------------------------------------------------
      -- Look & feel
      ------------------------------------------------------------------
      -- Week starts Monday
      calendar_week_start_day = 1,
      -- Start with a bit of structure visible, not fully folded
      org_startup_folded = "content",
      -- Visual indentation + hiding stars, so it feels more outline-y
      org_startup_indented = true,
      org_indent_mode_turns_on_hiding_stars = true,
      -- Keep real indentation under headings (adjust later if you dislike it)
      org_adapt_indentation = true,
      -- Highlight LaTeX fragments like $…$ and \[ … \]
      org_highlight_latex_and_related = "entities",

      ------------------------------------------------------------------
      -- Capture templates
      --
      -- <leader>oc → choose one of these by key: t, n, m, j
      ------------------------------------------------------------------
      org_capture_templates = {
        t = {
          description = "Todo",
          -- %?  = cursor
          -- %u  = inactive timestamp [YYYY-MM-DD …]
          template = "* TODO %?\n  %u",
          target = "~/Desktop/org/refile.org",
        },

        n = {
          description = "Note",
          template = "* %?\n  %u",
          target = "~/Desktop/org/notes.org",
        },

        m = {
          description = "Meeting",
          -- %u inactive timestamp; you can change to %U if you prefer active
          template = table.concat({
            "* MEETING with %? :meeting:",
            "  %u",
            "** Context",
            "  - ",
            "** Notes",
            "  - ",
          }, "\n"),
          target = "~/Desktop/org/meetings.org",
        },

        j = {
          description = "Journal",
          -- %<…> = strftime format (date on heading, time in body)
          template = table.concat({
            "* %<%Y-%m-%d %A>",
            "  %U",
            "",
            "  %?",
          }, "\n"),
          target = "~/Desktop/org/journal.org",
        },

        l = {
          description = "Link to current location",
          template = "* TODO %?\n  %u\n  %a",
          target = "~/Desktop/org/inbox.org",
        },

      },
    })
  end,
}
