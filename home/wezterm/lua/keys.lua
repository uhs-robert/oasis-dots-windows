local wezterm = require("wezterm")
local workspaces = require("lua.workspaces")
local act = wezterm.action

local M = {}

local directions = { h = "Left", j = "Down", k = "Up", l = "Right" }

local function is_nvim(pane)
  local ok, name = pcall(function()
    return pane:get_foreground_process_name()
  end)
  return ok and name ~= nil and name:lower():match("n?vim[^\\/]*$") ~= nil
end

-- Ctrl+hjkl reaches nvim (its own split navigation) when it is in the foreground, else moves panes.
local function nvim_aware_pane_focus(key, direction)
  return wezterm.action_callback(function(window, pane)
    if is_nvim(pane) then
      window:perform_action(act.SendKey({ key = key, mods = "CTRL" }), pane)
    else
      window:perform_action(act.ActivatePaneDirection(direction), pane)
    end
  end)
end

local copy_or_interrupt = wezterm.action_callback(function(window, pane)
  if window:get_selection_text_for_pane(pane) ~= "" then
    window:perform_action(act.CopyTo("Clipboard"), pane)
    window:perform_action(act.ClearSelection, pane)
  else
    window:perform_action(act.SendKey({ key = "c", mods = "CTRL" }), pane)
  end
end)

local function leader_keys()
  local keys = {
    { key = "a", mods = "LEADER|CTRL", action = act.SendKey({ key = "a", mods = "CTRL" }) },
    { key = "Escape", mods = "LEADER", action = act.Multiple({}) },
    -- tabs (tmux windows)
    { key = "c", mods = "LEADER", action = act.SpawnTab("CurrentPaneDomain") },
    { key = "h", mods = "LEADER", action = act.ActivateTabRelative(-1) },
    { key = "l", mods = "LEADER", action = act.ActivateTabRelative(1) },
    { key = "a", mods = "LEADER", action = act.ActivateLastTab },
    {
      key = ",",
      mods = "LEADER",
      action = act.PromptInputLine({
        description = "Rename tab",
        action = wezterm.action_callback(function(window, _, line)
          if line then
            window:active_tab():set_title(line)
          end
        end),
      }),
    },
    { key = "&", mods = "LEADER|SHIFT", action = act.CloseCurrentTab({ confirm = true }) },
    -- panes
    {
      key = "V",
      mods = "LEADER|SHIFT",
      action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }),
    },
    {
      key = "S",
      mods = "LEADER|SHIFT",
      action = act.SplitVertical({ domain = "CurrentPaneDomain" }),
    },
    { key = "z", mods = "LEADER", action = act.TogglePaneZoomState },
    { key = "x", mods = "LEADER", action = act.CloseCurrentPane({ confirm = true }) },
    {
      key = "Enter",
      mods = "LEADER",
      action = act.PaneSelect({ mode = "SwapWithActiveKeepFocus" }),
    },
    { key = "H", mods = "LEADER|SHIFT", action = act.AdjustPaneSize({ "Left", 5 }) },
    { key = "J", mods = "LEADER|SHIFT", action = act.AdjustPaneSize({ "Down", 5 }) },
    { key = "K", mods = "LEADER|SHIFT", action = act.AdjustPaneSize({ "Up", 5 }) },
    { key = "L", mods = "LEADER|SHIFT", action = act.AdjustPaneSize({ "Right", 5 }) },
    -- workspaces (tmux sessions)
    { key = "w", mods = "LEADER", action = workspaces.switcher },
    { key = "j", mods = "LEADER", action = act.SwitchWorkspaceRelative(-1) },
    { key = "k", mods = "LEADER", action = act.SwitchWorkspaceRelative(1) },
    { key = "n", mods = "LEADER", action = workspaces.new },
    { key = "R", mods = "LEADER|SHIFT", action = workspaces.rename },
    -- modes and misc
    { key = "v", mods = "LEADER", action = act.ActivateCopyMode },
    { key = "q", mods = "LEADER", action = act.QuickSelect },
    { key = "/", mods = "LEADER", action = act.Search("CurrentSelectionOrEmptyString") },
    { key = "r", mods = "LEADER", action = act.ReloadConfiguration },
    { key = "m", mods = "LEADER", action = act.ShowLauncher },
  }
  for tab_number = 1, 9 do
    table.insert(keys, {
      key = tostring(tab_number),
      mods = "LEADER",
      action = act.ActivateTab(tab_number - 1),
    })
  end
  return keys
end

local function kitty_keys()
  local keys = {
    { key = "c", mods = "CTRL", action = copy_or_interrupt },
    { key = "v", mods = "CTRL", action = act.PasteFrom("Clipboard") },
    { key = "Y", mods = "CTRL|SHIFT", action = copy_or_interrupt },
    { key = "T", mods = "CTRL|SHIFT", action = act.SpawnTab("CurrentPaneDomain") },
    { key = "W", mods = "CTRL|SHIFT", action = act.CloseCurrentTab({ confirm = true }) },
    { key = "]", mods = "CTRL|SHIFT", action = act.ActivateTabRelative(1) },
    { key = "[", mods = "CTRL|SHIFT", action = act.ActivateTabRelative(-1) },
    { key = "U", mods = "CTRL|SHIFT", action = act.ScrollByPage(-1) },
    { key = "D", mods = "CTRL|SHIFT", action = act.ScrollByPage(1) },
    { key = "G", mods = "CTRL|SHIFT", action = act.ScrollToTop },
    { key = "P", mods = "CTRL|SHIFT", action = act.ActivateCopyMode },
  }
  for key, direction in pairs(directions) do
    table.insert(keys, {
      key = key:upper(),
      mods = "CTRL|SHIFT",
      action = act.ActivatePaneDirection(direction),
    })
    table.insert(keys, { key = key, mods = "CTRL", action = nvim_aware_pane_focus(key, direction) })
    table.insert(keys, {
      key = key:upper(),
      mods = "CTRL|SHIFT|ALT",
      action = act.AdjustPaneSize({ direction, 3 }),
    })
  end
  return keys
end

function M.apply(config)
  config.leader = { key = "a", mods = "CTRL", timeout_milliseconds = 1500 }
  config.disable_default_key_bindings = false

  local keys = leader_keys()
  for _, binding in ipairs(kitty_keys()) do
    table.insert(keys, binding)
  end
  config.keys = keys
end

return M
