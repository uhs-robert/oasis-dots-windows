-- init.lua
---@diagnostic disable: undefined-global, redundant-parameter

-- Plugins
-- Full border around the window
require("full-border"):setup({
  -- Available values: ui.Border.PLAIN, ui.Border.ROUNDED
  type = ui.Border.PLAIN,
})

-- Folder Rules
require("folder-rules"):setup()

-- Git integration
require("git"):setup()
require("githead"):setup({
  branch_prefix = "on",
  branch_borders = "()",
  branch_symbol = " ",
  branch_color = "blue",
  remote_branch_color = "cyan",

  tag_symbol = "󰓼 ",
  tag_color = "magenta",
  commit_symbol = " ",
  commit_color = "bright magenta",
  stashes_symbol = " ",
  stashes_color = "red",
  state_symbol = "󱐋 ",
  state_color = "bright yellow",

  staged_symbol = " ",
  staged_color = "green",
  unstaged_symbol = " ",
  unstaged_color = "yellow",
  untracked_color = "bright blue",
  untracked_symbol = " ",
})

-- Relative Motion
require("relative-motions"):setup({
  show_numbers = "relative",
})

require("restore"):setup()

-- Show symlink in status bar
Status:children_add(function(self)
  local h = self._current.hovered
  if h and h.link_to then
    return " -> " .. tostring(h.link_to)
  else
    return ""
  end
end, 3300, Status.LEFT)

-- Show username and hostname in header
-- ya.user_name/host_name are unix-only, so Windows reads the environment instead.
Header:children_add(function()
  local user = os.getenv("USERNAME") or os.getenv("USER")
  local host = os.getenv("COMPUTERNAME") or os.getenv("HOSTNAME")
  if not user or not host then
    return ""
  end
  return ui.Span(user .. "@" .. host .. ":"):fg("blue")
end, 500, Header.LEFT)
