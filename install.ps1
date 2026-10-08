#Requires -Version 7
<#
.SYNOPSIS
Installs packages, links configs and applies Windows tweaks.

.PARAMETER select
Optional-package picker tokens (group or group/name, comma separated). Skips the picker.

.PARAMETER mode
desktop (GUI and CLI) or headless (CLI only, for SSH). Saved for later runs; asked on the first run.

.PARAMETER unattended
Reuse the saved selection and mode and never prompt. Fails on a first run without -mode.

.PARAMETER reselect
Show the picker even with -unattended.

.PARAMETER only
Run just these steps: repos, packages, links, environment, system, post.
#>
[CmdletBinding()]
param(
  [ValidateSet('desktop', 'headless')]
  [string] $mode,
  [string[]] $select,
  [switch] $unattended,
  [switch] $reselect,
  [ValidateSet('repos', 'packages', 'links', 'environment', 'system', 'post')]
  [string[]] $only = @('repos', 'packages', 'links', 'environment', 'system', 'post')
)

$ErrorActionPreference = 'Stop'
foreach ($module in 'Log', 'Packages', 'Picker', 'Manifest') {
  Import-Module (Join-Path $PSScriptRoot "lib/$module.psm1") -Force
}

$manifest = Read-Manifest (Join-Path $PSScriptRoot 'manifest.psd1')
$context = New-ManifestContext $manifest $PSScriptRoot
$is_elevated = Test-Elevated
$selection_file = Join-Path $context.state_dir 'selection.txt'
$mode_file = Join-Path $context.state_dir 'mode.txt'

function Test-StepEnabled([string] $step) { $step -in $only }

# Scoop installs update the registry PATH, which this process never sees.
function Update-SessionPath {
  $registry_paths = foreach ($scope in 'Machine', 'User') { [Environment]::GetEnvironmentVariable('Path', $scope) }
  $shims = Join-Path (Get-ScoopRoot) 'shims'
  $env:Path = (@($shims) + ($registry_paths -join ';' -split ';') + ($env:Path -split ';') |
      Where-Object { $_ } | Select-Object -Unique) -join ';'
}

function Read-SavedSelection {
  if (-not (Test-Path -LiteralPath $selection_file)) { return @() }
  @(Get-Content -LiteralPath $selection_file | ForEach-Object Trim | Where-Object { $_ })
}

function Save-Selection([string[]] $tokens) {
  New-Item -ItemType Directory -Path $context.state_dir -Force | Out-Null
  Set-Content -LiteralPath $selection_file -Value $tokens
}

function Resolve-InstallMode {
  if ($mode) {
    New-Item -ItemType Directory -Path $context.state_dir -Force | Out-Null
    Set-Content -LiteralPath $mode_file -Value $mode
    return $mode
  }

  $saved = if (Test-Path -LiteralPath $mode_file) { "$(Get-Content -LiteralPath $mode_file -TotalCount 1)".Trim() }
  if ($saved -in 'desktop', 'headless') { return $saved }
  if ($unattended) { throw 'No install mode saved yet: pass -mode desktop or -mode headless.' }

  $picked = Select-InstallMode
  if (-not $picked) { throw 'No install mode chosen: pass -mode desktop or -mode headless.' }
  New-Item -ItemType Directory -Path $context.state_dir -Force | Out-Null
  Set-Content -LiteralPath $mode_file -Value $picked
  $picked
}

function Get-SelectionTokens($optional_entries) {
  $previous = Read-SavedSelection

  if ($select) {
    $tokens = @($select -split ',' | ForEach-Object Trim | Where-Object { $_ })
    Save-Selection $tokens
    return $tokens
  }
  if ($unattended -and -not $reselect) { return $previous }
  if (-not (Get-Command fzf -ErrorAction SilentlyContinue)) {
    Write-Warn 'fzf not found, keeping the previous optional selection'
    return $previous
  }

  $picked = Select-OptionalPackages $optional_entries $previous
  if ($null -eq $picked) {
    Write-Skip 'picker cancelled, keeping the previous selection'
    return $previous
  }
  Save-Selection $picked
  $picked
}

function Invoke-SystemScript([string] $name) {
  $changed = & (Join-Path $PSScriptRoot "system/$name.ps1")
  if ($changed) { Write-Ok "$name applied" } else { Write-Skip "$name already set" }
}

$install_mode = Resolve-InstallMode
$is_desktop = $install_mode -eq 'desktop'
Write-Step "Install mode: $install_mode"

$required_entries = @(Read-PackageIni (Join-Path $PSScriptRoot 'packages/required.ini'))
$optional_entries = @(Read-PackageIni (Join-Path $PSScriptRoot 'packages/optional.ini'))
if ($is_desktop) {
  $required_entries += @(Read-PackageIni (Join-Path $PSScriptRoot 'packages/gui-required.ini'))
  $optional_entries += @(Read-PackageIni (Join-Path $PSScriptRoot 'packages/gui-optional.ini'))
}
$optional_entries += @(Read-LocalPackageIni (Get-LocalPackageFile))

if ((Test-StepEnabled 'repos') -or (Test-StepEnabled 'links') -or (Test-StepEnabled 'post')) {
  Write-Step 'Syncing repos'
  if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Update-SessionPath }
  foreach ($repo in $manifest.repos) { Sync-Repo $repo $context }
}

if (Test-StepEnabled 'packages') {
  Write-Step 'Installing required packages'
  if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) { Update-SessionPath }
  if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    throw 'Scoop is not installed. Run bootstrap.ps1 first.'
  }
  foreach ($entry in $required_entries) { Install-Package $entry }
  Update-SessionPath
}

$selection_tokens = @()
if ((Test-StepEnabled 'packages') -or (Test-StepEnabled 'links') -or (Test-StepEnabled 'environment') -or (Test-StepEnabled 'post')) {
  if (Test-StepEnabled 'packages') { Write-Step 'Choosing optional packages' }
  $selection_tokens = @(Get-SelectionTokens $optional_entries)
}
$selected_entries = @(Resolve-Selection $optional_entries $selection_tokens)

if (Test-StepEnabled 'packages') {
  Write-Step 'Installing optional packages'
  if ($selected_entries.Count -eq 0) { Write-Skip 'nothing selected' }
  foreach ($entry in $selected_entries) { Install-Package $entry }
  Update-SessionPath
}

# Re-checked rather than tracked per install: a failure scrolls past among hundreds of lines of Scoop output.
$missing_entries = @()
if (Test-StepEnabled 'packages') {
  $missing_entries = @($required_entries + $selected_entries | Where-Object { -not (Test-PackageInstalled $_) })
}

$installed_entries = $required_entries + $selected_entries
$active_names = @($installed_entries.group) + @($installed_entries.key)

# Symlinks need Developer Mode, so it is switched on ahead of the links step.
$developer_mode_done = $false
if ($is_elevated -and ((Test-StepEnabled 'links') -or (Test-StepEnabled 'system'))) {
  Write-Step 'Enabling Developer Mode'
  Invoke-SystemScript 'developer-mode'
  $developer_mode_done = $true
}

if (Test-StepEnabled 'links') {
  Write-Step 'Linking configs'
  foreach ($link in $manifest.links) {
    if (Test-ManifestCondition $link $active_names $install_mode) { Install-ManifestLink $link $context | Out-Null }
    # A package deselected or a mode switched since the last run leaves its link behind; only links into this repo are removed.
    else { Remove-ManifestLink $link $context }
  }
}

if (Test-StepEnabled 'environment') {
  Write-Step 'Setting environment variables'
  foreach ($entry in $manifest.environment) {
    if (Test-ManifestCondition $entry $active_names $install_mode) { Set-ManifestEnvironmentVariable $entry $context }
    elseif ($entry.mode -and $entry.mode -ne $install_mode) { Remove-ManifestEnvironmentVariable $entry }
  }
}

if (Test-StepEnabled 'system') {
  Write-Step 'Applying system tweaks'
  $system_scripts = if ($is_desktop) { @('developer-mode', 'explorer', 'taskbar', 'keyboard', 'wlan-service') } else { @('developer-mode', 'explorer', 'ssh-default-shell') }
  if ($is_elevated) {
    foreach ($name in $system_scripts | Where-Object { -not ($developer_mode_done -and $_ -eq 'developer-mode') }) {
      Invoke-SystemScript $name
    }
  } else {
    Write-Warn "not elevated, skipped: $($system_scripts -join ', ')"
    Write-Warn 're-run from an elevated PowerShell with: ./install.ps1 -only system'
  }
}

if (Test-StepEnabled 'post') {
  Write-Step 'Post-install steps'

  if (Get-Command bat -ErrorAction SilentlyContinue) {
    bat cache --build | Out-Null
    Write-Ok 'bat cache built'
  }

  $yazi_config_dir = Join-Path $env:APPDATA 'yazi/config'
  if ((Get-Command ya -ErrorAction SilentlyContinue) -and (Test-Path (Join-Path $yazi_config_dir 'package.toml'))) {
    $env:YAZI_CONFIG_HOME = $yazi_config_dir
    ya pkg install
  }

  $identity_file = Join-Path $HOME '.config/git/identity'
  if (-not (Test-Path -LiteralPath $identity_file)) {
    if ($unattended) {
      Write-Warn "git identity missing: create $identity_file with [user] name and email"
    } else {
      $git_name = Read-Host 'git user.name'
      $git_email = Read-Host 'git user.email'
      if ($git_name -and $git_email) {
        New-Item -ItemType Directory -Path (Split-Path $identity_file) -Force | Out-Null
        Set-Content -LiteralPath $identity_file -Value "[user]`n`tname = $git_name`n`temail = $git_email"
        Write-Ok "wrote $identity_file"
      } else {
        Write-Skip 'git identity skipped'
      }
    }
  }

  $glazewm_exe = Join-Path (Get-ScoopRoot) 'apps/glazewm/current/glazewm.exe'
  $shortcut_path = Join-Path ([Environment]::GetFolderPath('Startup')) 'GlazeWM.lnk'
  # A machine switched to headless would otherwise keep starting GlazeWM at sign-in.
  if (-not $is_desktop -and (Test-Path -LiteralPath $shortcut_path)) {
    Remove-Item -LiteralPath $shortcut_path
    Write-Ok 'removed GlazeWM from Startup'
  }
  if ($is_desktop -and (Test-Path -LiteralPath $glazewm_exe)) {
    if (-not (Test-Path -LiteralPath $shortcut_path)) {
      $shortcut = (New-Object -ComObject WScript.Shell).CreateShortcut($shortcut_path)
      $shortcut.TargetPath = $glazewm_exe
      $shortcut.WorkingDirectory = Split-Path $glazewm_exe
      $shortcut.Save()
      Write-Ok 'GlazeWM added to Startup'
    }
    if (-not $unattended -and -not (Get-Process glazewm -ErrorAction SilentlyContinue)) {
      if ((Read-Host 'Start GlazeWM now? (y/N)') -match '^y') { Start-Process $glazewm_exe }
    }
  }
}

if ($missing_entries.Count -gt 0) {
  Write-Step "Done, but $($missing_entries.Count) package(s) did not install"
  foreach ($entry in $missing_entries) { Write-Fail $entry.key }
  Write-Warn 'fix the cause above, then re-run: ./install.ps1 -unattended'
  exit 1
}

Write-Step 'Done'
