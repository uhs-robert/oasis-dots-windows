# Linked to Documents\PowerShell\Microsoft.PowerShell_profile.ps1; startup cost matters, so every
# optional tool is probed with Get-Command before use.

$is_interactive = [Environment]::UserInteractive -and -not [Console]::IsInputRedirected -and -not [Console]::IsOutputRedirected

function Test-Command {
  param([string] $name)
  [bool](Get-Command $name -ErrorAction SilentlyContinue)
}

# Environment

$env:EDITOR = 'nvim'
$env:VISUAL = 'nvim'
$env:GIT_EDITOR = 'nvim'
$env:PAGER = 'less -RF --mouse'
$env:FZF_DEFAULT_COMMAND = 'fd --type f --hidden --follow --exclude .git'
$env:FZF_DEFAULT_OPTS = "--height=80% --layout=reverse --border --preview 'bat --style=numbers --color=always {}' --preview-window=right:60%:border-left --bind=ctrl-p:toggle-preview"

# Functions

# The profile is a symlink, so $PSScriptRoot points into Documents, not the repo.
$repo_root = $env:DOTFILES_WINDOWS
if (-not $repo_root) {
  $profile_target = (Get-Item $PSCommandPath -ErrorAction SilentlyContinue).Target
  if ($profile_target) { $repo_root = Split-Path (Split-Path (Split-Path ([string]$profile_target))) }
}
if ($repo_root) {
  $functions_dir = Join-Path $repo_root 'home\powershell\functions'
  if (Test-Path $functions_dir) {
    foreach ($function_file in Get-ChildItem $functions_dir -Filter *.ps1) { . $function_file.FullName }
  }
}

# GNU coreutils (uutils)

if (Test-Command coreutils) {
  # Built-in aliases outrank Application commands, so they must go for the GNU tools to win.
  foreach ($alias_name in 'cat', 'cp', 'mv', 'rm', 'rmdir', 'sort', 'tee') {
    Remove-Item "alias:$alias_name" -Force -ErrorAction SilentlyContinue
  }
  # System32 precedes the user PATH, so its sort.exe would still shadow the Scoop shim.
  $scoop_shims = Join-Path ($env:SCOOP ?? "$HOME\scoop") 'shims'
  if (Test-Path $scoop_shims) { $env:PATH = "$scoop_shims;$env:PATH" }
}

# Aliases

if (Test-Command lsd) {
  # `ls` is a built-in alias and aliases outrank functions.
  Remove-Item alias:ls -Force -ErrorAction SilentlyContinue
  function ls { lsd @args }
  function l { lsd -l @args }
  function la { lsd -a @args }
  function lla { lsd -la @args }
  function lt { lsd --tree @args }
}

# Prompt and navigation

if (Test-Command starship) { Invoke-Expression (& starship init powershell) }
if (Test-Command zoxide) { zoxide init powershell | Out-String | Invoke-Expression }

# Line editing

if ($is_interactive) {
  Set-PSReadLineOption -EditMode Vi
  Set-PSReadLineOption -PredictionSource History -PredictionViewStyle InlineView
  Set-PSReadLineOption -HistoryNoDuplicates -MaximumHistoryCount 10000 -HistorySearchCursorMovesToEnd
  Set-PSReadLineOption -BellStyle None

  Set-PSReadLineOption -ViModeIndicator Script -ViModeChangeHandler {
    param($mode)
    $cursor_shape = if ($mode -eq 'Command') { "`e[2 q" } else { "`e[6 q" }
    [Console]::Write($cursor_shape)
  }

  foreach ($vi_mode in 'Insert', 'Command') {
    Set-PSReadLineKeyHandler -ViMode $vi_mode -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -ViMode $vi_mode -Key DownArrow -Function HistorySearchForward
  }
  Set-PSReadLineKeyHandler -ViMode Insert -Key Tab -Function MenuComplete

  if (Get-Module -ListAvailable PSFzf) {
    Import-Module PSFzf
    Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
    Set-PSReadLineKeyHandler -ViMode Insert -Key Tab -ScriptBlock { Invoke-FzfTabCompletion }
  }

  $oasis_theme = $env:OASIS_THEME ?? 'moonlight'
  if ($env:DOTFILES_WINDOWS) {
    $psreadline_theme = Join-Path $env:DOTFILES_WINDOWS "repos\oasis.nvim\extras\psreadline\themes\dark\oasis_${oasis_theme}_dark.ps1"
    if (Test-Path $psreadline_theme) { . $psreadline_theme }
  }
}

# Machine-local additions kept outside the repo
$local_profile = Join-Path $HOME '.config\powershell\local.ps1'
if (Test-Path $local_profile) { . $local_profile }
