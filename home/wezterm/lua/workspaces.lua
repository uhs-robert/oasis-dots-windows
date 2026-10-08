local wezterm = require("wezterm")
local act = wezterm.action

local M = {}

M.switcher = act.ShowLauncherArgs({ flags = "FUZZY|WORKSPACES" })

M.new = act.PromptInputLine({
  description = "New workspace name",
  action = wezterm.action_callback(function(window, pane, line)
    if line and line ~= "" then
      window:perform_action(act.SwitchToWorkspace({ name = line }), pane)
    end
  end),
})

M.rename = act.PromptInputLine({
  description = "Rename workspace",
  action = wezterm.action_callback(function(_, _, line)
    if line and line ~= "" then
      wezterm.mux.rename_workspace(wezterm.mux.get_active_workspace(), line)
    end
  end),
})

return M
