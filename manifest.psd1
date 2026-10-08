# Tokens: {repo} {repos} {theme} {scoop} {documents} and {<repo-name>} for each repo below.
# Also a leading ~ and %VAR%. `when` is a package group ("ai") or key ("ai/claude-code").
# `mode = 'desktop'` limits an entry to desktop installs; without `mode` it applies in every mode.
# `filter` is a jq expression: the target becomes a filtered copy instead of a symlink.
@{
  theme = 'moonlight'

  repos = @(
    @{ name = 'oasis-dots'; url = 'https://github.com/uhs-robert/oasis-dots.git' }
    @{ name = 'oasis.nvim'; url = 'https://github.com/uhs-robert/oasis.nvim.git' }
    @{ name = 'neovim'; url = 'https://github.com/uhs-robert/neovim.git' }
  )

  links = @(
    @{ source = '{oasis-dots}\home\starship\.config\starship.toml'; target = '~\.config\starship.toml' }
    @{ source = '{oasis-dots}\home\git\.config\git\config'; target = '~\.config\git\config' }
    @{ source = '{oasis-dots}\home\git\.config\git\ignore'; target = '~\.config\git\ignore' }
    @{ source = '{oasis-dots}\home\bat\.config\bat'; target = '%APPDATA%\bat' }
    @{ source = '{repo}\home\wezterm'; target = '~\.config\wezterm'; mode = 'desktop' }
    @{ source = '{repo}\home\powershell\profile.ps1'; target = '{documents}\PowerShell\Microsoft.PowerShell_profile.ps1' }
    @{ source = '{repo}\home\nushell\config.nu'; target = '%APPDATA%\nushell\config.nu'; when = 'shells/nu' }
    @{ source = '{repo}\home\nushell\env.nu'; target = '%APPDATA%\nushell\env.nu'; when = 'shells/nu' }
    @{ source = '{repo}\home\zebar\settings.json'; target = '~\.glzr\zebar\settings.json'; mode = 'desktop' }
    @{ source = '{repo}\home\zebar\oasis'; target = '~\.glzr\zebar\oasis'; mode = 'desktop' }
    @{ source = '{repo}\home\yazi\keymap.toml'; target = '%APPDATA%\yazi\config\keymap.toml' }
    @{ source = '{repo}\home\yazi\yazi.toml'; target = '%APPDATA%\yazi\config\yazi.toml' }
    @{ source = '{repo}\home\yazi\theme.toml'; target = '%APPDATA%\yazi\config\theme.toml' }
    @{ source = '{repo}\home\yazi\package.toml'; target = '%APPDATA%\yazi\config\package.toml' }
    @{ source = '{repo}\home\yazi\init.lua'; target = '%APPDATA%\yazi\config\init.lua' }
    @{ source = '{oasis-dots}\home\yazi\.config\yazi\plugins\folder-rules.yazi'; target = '%APPDATA%\yazi\config\plugins\folder-rules.yazi' }
    @{ source = '{oasis-dots}\home\yazi\.config\yazi\plugins\lazygit.yazi'; target = '%APPDATA%\yazi\config\plugins\lazygit.yazi' }
    @{ source = '{repo}\home\yazi\plugins\jump-to.yazi'; target = '%APPDATA%\yazi\config\plugins\jump-to.yazi' }
    @{ source = '{oasis.nvim}\extras\yazi\themes\dark\flavors\oasis-{theme}-dark.yazi'; target = '%APPDATA%\yazi\config\flavors\oasis-{theme}-dark.yazi' }
    @{ source = '{neovim}'; target = '%LOCALAPPDATA%\nvim' }
    @{ source = '{oasis-dots}\home\claude\.claude\skills'; target = '~\.claude\skills'; when = 'ai/claude-code' }
    @{ source = '{oasis-dots}\home\claude\.claude\keybindings.json'; target = '~\.claude\keybindings.json'; when = 'ai/claude-code' }
    # The Linux settings carry keeptabs hooks that do not exist on Windows.
    @{ source = '{oasis-dots}\home\claude\.claude\settings.json'; target = '~\.claude\settings.json'; when = 'ai/claude-code'; filter = 'del(.hooks)' }
    @{ source = '{oasis-dots}\home\codex\.codex\skills'; target = '~\.codex\skills'; when = 'ai/codex' }
  )

  environment = @(
    @{ name = 'OASIS_DOTS_WINDOWS'; value = '{repo}' }
    @{ name = 'OASIS_THEME'; value = '{theme}' }
    @{ name = 'GLAZEWM_CONFIG_PATH'; value = '{repo}\home\glazewm\config.yaml'; mode = 'desktop' }
    # lazygit merges comma-separated files, later wins.
    @{ name = 'LG_CONFIG_FILE'; value = '{oasis-dots}\home\lazygit\.config\lazygit\config.yml,{repo}\home\lazygit\windows.yml' }
    @{ name = 'YAZI_FILE_ONE'; value = '{scoop}\apps\git\current\usr\bin\file.exe' }
  )
}
