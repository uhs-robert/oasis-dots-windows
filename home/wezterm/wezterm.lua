local wezterm = require("wezterm")

-- The config dir is a symlink target; adding it explicitly keeps require("lua.x") working
-- regardless of wezterm's default package.path.
package.path = wezterm.config_dir .. "/?.lua;" .. package.path

local config = wezterm.config_builder()

local function command_exists(name)
  local separator = package.config:sub(1, 1) == "\\" and ";" or ":"
  for dir in (os.getenv("PATH") or ""):gmatch("[^" .. separator .. "]+") do
    local file = io.open(dir .. "/" .. name .. (separator == ";" and ".exe" or ""), "r")
    if file then
      file:close()
      return true
    end
  end
  return false
end

local launch_menu = {
  { label = "PowerShell 7", args = { "pwsh", "-NoLogo" } },
  { label = "Command Prompt", args = { "cmd" } },
  { label = "Windows PowerShell", args = { "powershell", "-NoLogo" } },
}
if command_exists("nu") then
  table.insert(launch_menu, 2, { label = "Nushell", args = { "nu" } })
end

config.default_prog = { "pwsh", "-NoLogo" }
config.launch_menu = launch_menu
config.font = wezterm.font_with_fallback({ "JetBrainsMono Nerd Font", "JetBrains Mono" })
config.font_size = 12.0
config.scrollback_lines = 5000
config.audible_bell = "Disabled"
-- GlazeWM owns window placement; keep only the resize border.
config.window_decorations = "RESIZE"
config.window_padding = { left = 6, right = 6, top = 4, bottom = 4 }

require("lua.theme").apply(config)
require("lua.keys").apply(config)
require("lua.status").apply()

return config
