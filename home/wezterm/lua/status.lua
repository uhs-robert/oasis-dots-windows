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

  wezterm.on("update-status", function(window, _)
    local palette = window:effective_config().resolved_palette
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

    window:set_right_status(wezterm.format(cells))
  end)
end

return M
