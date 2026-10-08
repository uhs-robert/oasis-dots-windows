#Requires -Version 7
<#
.SYNOPSIS
Installs packages, links configs and applies Windows tweaks.

.PARAMETER select
Optional-package picker tokens (group or group/name, comma separated). Skips the picker.

.PARAMETER unattended
Reuse the saved selection and never prompt.

.PARAMETER reselect
Show the picker even with -unattended.

.PARAMETER only
Run just these steps: repos, packages, links, environment, system, post.
#>
[CmdletBinding()]
param(
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

$required_entries = @(Read-PackageIni (Join-Path $PSScriptRoot 'packages/required.ini'))
$optional_entries = @(Read-PackageIni (Join-Path $PSScriptRoot 'packages/optional.ini'))

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
    if (Test-ManifestCondition $link $active_names) { Install-ManifestLink $link $context | Out-Null }
    else { Write-Skip "$($link.target) (needs $($link.when))" }
  }
}

if (Test-StepEnabled 'environment') {
  Write-Step 'Setting environment variables'
  foreach ($entry in $manifest.environment) {
    if (Test-ManifestCondition $entry $active_names) { Set-ManifestEnvironmentVariable $entry $context }
  }
}

if (Test-StepEnabled 'system') {
  Write-Step 'Applying system tweaks'
  $system_scripts = @('developer-mode', 'explorer', 'taskbar', 'keyboard')
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
  if (Test-Path -LiteralPath $glazewm_exe) {
    $shortcut_path = Join-Path ([Environment]::GetFolderPath('Startup')) 'GlazeWM.lnk'
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

Write-Step 'Done'
