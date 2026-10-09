local wezterm = require("wezterm")

local M = {}

local function active_mode(window)
  if window:leader_is_active() then
    return "LEADER"
  end
  local key_table = window:active_key_table()
  if key_table == "copy_mode" then
    return "COPY"
  elseif key_table == "search_mode" then
    return "SEARCH"
  end
  return key_table and key_table:upper() or nil
end

function M.apply()
  -- Same "{index} :{title}" shape as the kitty tab bar.
  wezterm.on("format-tab-title", function(tab)
    return string.format(" %d :%s ", tab.tab_index + 1, tab.active_pane.title)
  end)

  -- update-status fires every second. Without a GPU every redraw is software rendered, so the
  -- palette is resolved once per window (effective_config() rebuilds the whole config) and the
  -- status is only set when its text changed, since set_right_status repaints the tab bar.
  local palette_by_window = {}
  local status_by_window = {}

  wezterm.on("update-status", function(window, _)
    local window_id = window:window_id()
    local palette = palette_by_window[window_id]
    if not palette then
      palette = window:effective_config().resolved_palette
      palette_by_window[window_id] = palette
    end

    local mode = active_mode(window)
    local cells = {}
    if mode then
      table.insert(cells, { Background = { Color = palette.ansi[4] } })
      table.insert(cells, { Foreground = { Color = palette.background } })
      table.insert(cells, { Attribute = { Intensity = "Bold" } })
      table.insert(cells, { Text = " " .. mode .. " " })
      table.insert(cells, "ResetAttributes")
    end
    table.insert(cells, { Foreground = { Color = palette.ansi[5] } })
    table.insert(cells, { Text = "  " .. window:active_workspace() .. " " })

    local status = wezterm.format(cells)
    if status_by_window[window_id] == status then
      return
    end
    status_by_window[window_id] = status
    window:set_right_status(status)
  end)

  -- A reload can change the theme, so cached palettes and statuses are dropped with it.
  wezterm.on("window-config-reloaded", function(window)
    palette_by_window[window:window_id()] = nil
    status_by_window[window:window_id()] = nil
  end)
end

return M
