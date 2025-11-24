-- lua/config/markdown-tasks.lua
local M = {}

local function append_tag(tag)
  local line = vim.api.nvim_get_current_line()
  -- don't duplicate tag
  if line:match("@" .. tag .. "%(") then
    return
  end
  local stamp = os.date("%Y-%m-%d %H:%M")
  line = line .. " @" .. tag .. "(" .. stamp .. ")"
  vim.api.nvim_set_current_line(line)
end

local function toggle_checkbox()
  local line = vim.api.nvim_get_current_line()

  -- try to toggle - [ ] -> - [x]
  local new, n = line:gsub("%- %[ %]", "- [x]", 1)
  if n == 0 then
    -- or - [x] -> - [ ]
    new, n = line:gsub("%- %[x%]", "- [ ]", 1)
  end

  return line, new, n
end

function M.mark_started()
  append_tag("started")
end

function M.toggle_done()
  local before, after, toggled = toggle_checkbox()
  if toggled == 0 then
    -- not a checkbox line, do nothing
    return
  end

  vim.api.nvim_set_current_line(after)

  if after:match("%- %[x%]") then
    -- now checked: add @done(...)
    append_tag("done")
  else
    -- now unchecked: strip any @done(...) annotation
    local cleaned = after:gsub("%s*@done%([^)]*%)", "")
    vim.api.nvim_set_current_line(cleaned)
  end
end

return M
