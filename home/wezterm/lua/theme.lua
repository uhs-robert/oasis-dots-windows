local wezterm = require("wezterm")

local M = {}

local function capitalized(word)
  return (word:gsub("^%l", string.upper))
end

local function oasis_scheme_dir()
  local root = os.getenv("DOTFILES_WINDOWS")
  if not root then
    return nil
  end
  return root .. "\\repos\\oasis.nvim\\extras\\wezterm\\themes\\dark"
end

function M.apply(config)
  local theme = os.getenv("OASIS_THEME") or "moonlight"
  local scheme_dir = oasis_scheme_dir()
  local scheme_file = scheme_dir and (scheme_dir .. "\\oasis_" .. theme .. "_dark.toml")

  if scheme_file and #wezterm.glob(scheme_file) > 0 then
    config.color_scheme_dirs = { scheme_dir }
    config.color_scheme = "Oasis " .. capitalized(theme) .. " Dark"
  else
    config.color_scheme = "Builtin Dark"
  end

  -- Retro bar takes its colors from the scheme's [colors.tab_bar]; the fancy bar ignores them.
  config.use_fancy_tab_bar = false
  config.tab_bar_at_bottom = false
  config.hide_tab_bar_if_only_one_tab = false
  config.tab_max_width = 32
end

return M
