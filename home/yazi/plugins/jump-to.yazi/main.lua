-- Env- and git-derived go-to targets; `cd` in keymap.toml cannot expand these.
local M = {}

local function env_or(name, fallback)
  local value = os.getenv(name)
  if value and value ~= "" then
    return value
  end
  return fallback
end

-- `cx` only exists in sync context; plugin entries run async.
local current_cwd = ya.sync(function() return tostring(cx.active.current.cwd) end)

local function git_root()
  local output = Command("git")
    :arg({ "rev-parse", "--show-toplevel" })
    :cwd(current_cwd())
    :stdout(Command.PIPED)
    :stderr(Command.NULL)
    :output()
  if not output or not output.status.success then
    return nil
  end
  return (output.stdout:gsub("%s+$", ""))
end

local function user_profile()
  return env_or("USERPROFILE", os.getenv("HOME"))
end

local targets = {
  temp = function() return env_or("TEMP", env_or("TMP", nil)) end,
  appdata = function() return os.getenv("APPDATA") end,
  local_appdata = function() return os.getenv("LOCALAPPDATA") end,
  development = function() return env_or("GITHUB_DIR", user_profile() .. "\\Development") end,
  dotfiles = function() return env_or("DOTFILES_WINDOWS", user_profile() .. "\\dotfiles-windows") end,
  yazi_config = function() return env_or("YAZI_CONFIG_HOME", os.getenv("APPDATA") .. "\\yazi\\config") end,
  git_root = git_root,
}

function M:entry(job)
  local resolve = targets[job.args[1]]
  local path = resolve and resolve()
  if not path then
    ya.notify({ title = "jump-to", content = "No target for " .. tostring(job.args[1]), timeout = 3, level = "warn" })
    return
  end
  ya.emit("cd", { path, raw = true })
end

return M
