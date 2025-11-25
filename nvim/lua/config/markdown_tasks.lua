-- lua/config/markdown_tasks.lua
local M = {}

-----------------------------------------------------------------------
-- Tag helpers
-----------------------------------------------------------------------

-- Append a tag with a timestamp, but don't duplicate it.
local function append_tag(tag)
  local line = vim.api.nvim_get_current_line()

  -- already has this tag? do nothing
  if line:match("@" .. tag .. "%(") then
    return
  end

  local stamp = os.date("%Y-%m-%d %H:%M")
  line = line .. " @" .. tag .. "(" .. stamp .. ")"
  vim.api.nvim_set_current_line(line)
end

-- Toggle presence of a tag: add with timestamp if missing, remove if present.
local function toggle_tag(tag)
  local line = vim.api.nvim_get_current_line()

  if line:match("@" .. tag .. "%(") then
    -- remove the first occurrence of this tag (with any leading whitespace)
    line = line:gsub("%s*@" .. tag .. "%([^)]*%)", "", 1)
    vim.api.nvim_set_current_line(line)
  else
    append_tag(tag)
  end
end

-----------------------------------------------------------------------
-- Checkbox helpers
-----------------------------------------------------------------------

-- Pure checkbox toggling on a single line.
local function toggle_checkbox_in_line(line)
  -- try to toggle "- [ ]" -> "- [x]"
  local new, n = line:gsub("%- %[ %]", "- [x]", 1)
  if n == 0 then
    -- or "- [x]" -> "- [ ]"
    new, n = line:gsub("%- %[x%]", "- [ ]", 1)
  end
  return new, n
end

-----------------------------------------------------------------------
-- Public API: line toggles
-----------------------------------------------------------------------

-- (a) Toggle a checkbox only: - [ ] <-> - [x]
function M.toggle_checkbox()
  local line = vim.api.nvim_get_current_line()
  local new, n = toggle_checkbox_in_line(line)

  -- not a checkbox line, do nothing
  if n == 0 then
    return
  end

  vim.api.nvim_set_current_line(new)
end

-- (b) Toggle @done(...) only
function M.toggle_done_tag()
  toggle_tag("done")
end

-- (c) Toggle @started(...) only
function M.toggle_started_tag()
  toggle_tag("started")
end

-- (d) Toggle checkbox AND keep @done(...) in sync
-- This is your original "toggle_done" behavior.
function M.toggle_checkbox_and_done()
  local line = vim.api.nvim_get_current_line()
  local new, toggled = toggle_checkbox_in_line(line)

  -- not a checkbox line, do nothing
  if toggled == 0 then
    return
  end

  vim.api.nvim_set_current_line(new)

  if new:match("%- %[x%]") then
    -- now checked: ensure @done(...) is present
    append_tag("done")
  else
    -- now unchecked: strip any @done(...) annotation
    local cleaned = new:gsub("%s*@done%([^)]*%)", "", 1)
    vim.api.nvim_set_current_line(cleaned)
  end
end

-----------------------------------------------------------------------
-- New: insert helpers
-----------------------------------------------------------------------

-- <localleader>mc: insert "- [ ] " at the cursor (normal mode)
function M.insert_checkbox_at_cursor()
  local pos = vim.api.nvim_win_get_cursor(0)
  local row, col = pos[1], pos[2]
  local text = "- [ ] "

  -- insert text at {row-1, col} (buffer coords are 0-based)
  vim.api.nvim_buf_set_text(0, row - 1, col, row - 1, col, { text })

  -- move cursor to just after the inserted checkbox
  vim.api.nvim_win_set_cursor(0, { row, col + #text })
end

-- Smart <CR> in insert mode:
-- If the current line is a checkbox, create a new checkbox line
-- at the same indent. Otherwise, just insert a normal newline.
function M.checkbox_cr()
  local line = vim.api.nvim_get_current_line()

  -- match lines like: "  - [ ] ...", "  - [x] ..."
  if line:match("^%s*%- %[ %]") or line:match("^%s*%- %[x%]") then
    -- let Vim handle indentation; we just add "- [ ] " on the new line
    return "\r- [ ] "
  end

  return "\r"
end

-----------------------------------------------------------------------
-- Backwards-compatible aliases
-----------------------------------------------------------------------

-- Old name still works; it now toggles @started(...)
M.mark_started = M.toggle_started_tag

-- Old combined checkbox+done function name
M.toggle_done = M.toggle_checkbox_and_done

return M
