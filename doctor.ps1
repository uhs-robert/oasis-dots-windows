#Requires -Version 7
<#
.SYNOPSIS
Checks this machine's setup without changing anything.

.DESCRIPTION
Covers packages, the commands configs rely on, config links, environment variables, the cloned
repos and (in desktop mode) startup items. Each problem comes with the command that fixes it.
Exits 1 when any check fails, 0 when only warnings remain.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
foreach ($module in 'Log', 'Packages', 'Picker', 'Manifest') {
  Import-Module (Join-Path $PSScriptRoot "lib/$module.psm1") -Force
}

$manifest = Read-Manifest (Join-Path $PSScriptRoot 'manifest.psd1')
$context = New-ManifestContext $manifest $PSScriptRoot
$failure_count = 0
$warning_count = 0

function Write-Problem([string] $message, [string] $fix) {
  Write-Fail $message
  if ($fix) { Write-Host "       fix: $fix" -ForegroundColor DarkGray }
  $script:failure_count++
}

function Write-Caution([string] $message, [string] $fix) {
  Write-Warn $message
  if ($fix) { Write-Host "       fix: $fix" -ForegroundColor DarkGray }
  $script:warning_count++
}

# This process inherits the PATH of whatever started it, which for a terminal opened from GlazeWM
# can predate the last install. The registry holds what a fresh sign-in would see.
function Find-InRegistryPath([string] $command) {
  $directories = foreach ($scope in 'Machine', 'User') { [Environment]::GetEnvironmentVariable('Path', $scope) -split ';' }
  foreach ($directory in $directories | Where-Object { $_ }) {
    foreach ($extension in '.exe', '.cmd', '.bat', '.ps1') {
      $candidate = Join-Path ([Environment]::ExpandEnvironmentVariables($directory)) "$command$extension"
      if (Test-Path -LiteralPath $candidate) { return $candidate }
    }
  }
}

$mode_file = Join-Path $context.state_dir 'mode.txt'
$install_mode = if (Test-Path -LiteralPath $mode_file) { "$(Get-Content -LiteralPath $mode_file -TotalCount 1)".Trim() }
if ($install_mode -notin 'desktop', 'headless') {
  Write-Problem 'no install mode saved: this machine has not been installed yet' './install.ps1'
  exit 1
}
$is_desktop = $install_mode -eq 'desktop'
Write-Step "Install mode: $install_mode"

$required_entries = @(Read-PackageIni (Join-Path $PSScriptRoot 'packages/required.ini'))
$optional_entries = @(Read-PackageIni (Join-Path $PSScriptRoot 'packages/optional.ini'))
if ($is_desktop) {
  $required_entries += @(Read-PackageIni (Join-Path $PSScriptRoot 'packages/gui-required.ini'))
  $optional_entries += @(Read-PackageIni (Join-Path $PSScriptRoot 'packages/gui-optional.ini'))
}
$optional_entries += @(Read-LocalPackageIni (Get-LocalPackageFile))
$selection_file = Join-Path $context.state_dir 'selection.txt'
$selection_tokens = @(if (Test-Path -LiteralPath $selection_file) { Get-Content -LiteralPath $selection_file | ForEach-Object Trim | Where-Object { $_ } })
$selected_entries = @(Resolve-Selection $optional_entries $selection_tokens)
$installed_entries = $required_entries + $selected_entries
$active_names = @($installed_entries.group) + @($installed_entries.key)

Write-Step 'Packages'
# Test-PackageInstalled asks each package manager, so entries whose manager is missing are
# reported here instead.
$checkable_entries = @($installed_entries)
foreach ($manager in 'scoop', 'winget') {
  if (Get-Command $manager -ErrorAction SilentlyContinue) { continue }
  $unchecked_entries = @($checkable_entries | Where-Object source -EQ $manager)
  $checkable_entries = @($checkable_entries | Where-Object source -NE $manager)
  if ($manager -eq 'scoop') { Write-Problem 'scoop not found' './bootstrap.ps1' }
  elseif ($unchecked_entries) { Write-Caution "winget not found, so $($unchecked_entries.Count) winget package(s) were not checked" }
}
$missing_entries = @($checkable_entries | Where-Object { -not (Test-PackageInstalled $_) })
if ($missing_entries) {
  Write-Problem "$($missing_entries.Count) package(s) not installed: $($missing_entries.key -join ', ')" './install.ps1 -unattended -only packages'
} elseif ($checkable_entries) {
  Write-Ok "all $($checkable_entries.Count) checked packages installed"
}

Write-Step 'Commands on PATH'
# The commands configs call by name; a package can be installed and still not resolve here.
$expected_commands = [ordered]@{
  git           = 'repo sync and updates'
  nvim          = 'the editor'
  gcc           = 'nvim-treesitter builds its parsers with it'
  'tree-sitter' = 'nvim-treesitter builds its parsers with it'
  rg            = 'searching in nvim and yazi'
  fd            = 'file finding in nvim, yazi and fzf'
  fzf           = 'the package picker and shell completion'
  jq            = 'filtered config copies'
  gsudo         = 'sudo in pwsh'
}
foreach ($command in $expected_commands.Keys) {
  if (Get-Command $command -ErrorAction SilentlyContinue) { Write-Ok $command; continue }
  $registry_hit = Find-InRegistryPath $command
  if ($registry_hit) {
    Write-Problem "$command is installed ($registry_hit) but this session's PATH predates it" 'sign out and back in (GlazeWM and the apps it launches keep the PATH they started with)'
  } else {
    Write-Problem "$command not found ($($expected_commands[$command]))" './install.ps1 -unattended -only packages'
  }
}

Write-Step 'Config links'
$link_problem_count = 0
foreach ($link in $manifest.links | Where-Object { Test-ManifestCondition $_ $active_names $install_mode }) {
  $link_state = Get-ManifestLinkState $link $context
  # 'linked' and 'copied' are both healthy.
  switch ($link_state.state) {
    'missing' { Write-Problem "$($link_state.target) is missing" 'just link'; $link_problem_count++ }
    'unmanaged' { Write-Problem "$($link_state.target) is not linked to $($link_state.source)" 'just link (the current file is backed up first)'; $link_problem_count++ }
    'no-source' { Write-Problem "source $($link_state.source) is missing" 'just update (a repo may have failed to clone)'; $link_problem_count++ }
  }
}
if ($link_problem_count -eq 0) { Write-Ok 'every config is linked or copied' }

Write-Step 'Environment variables'
foreach ($entry in $manifest.environment | Where-Object { Test-ManifestCondition $_ $active_names $install_mode }) {
  $expected_value = Expand-ManifestPath $entry.value $context
  if ([Environment]::GetEnvironmentVariable($entry.name, 'User') -ne $expected_value) {
    Write-Problem "$($entry.name) is not set to $expected_value" 'just link'
  } elseif ([Environment]::GetEnvironmentVariable($entry.name, 'Process') -ne $expected_value) {
    Write-Caution "$($entry.name) is set, but not yet in this session" 'sign out and back in'
  } else {
    Write-Ok $entry.name
  }
}

Write-Step 'Repos'
foreach ($repo in $manifest.repos) {
  $checkout = Join-Path $context.repos_dir $repo.name
  if (-not (Test-Path -LiteralPath (Join-Path $checkout '.git'))) {
    Write-Problem "$($repo.name) is not cloned" 'just update'
    continue
  }
  # Local edits make every later `just update` skip this repo's pull.
  $changed_files = @(git -C $checkout status --porcelain | ForEach-Object { $_.Substring(3) })
  if ($changed_files) {
    Write-Problem "$($repo.name) has local changes, so updates skip it: $($changed_files -join ', ')" "keep them with git -C $checkout commit, or drop them with git -C $checkout checkout -- <file>"
    continue
  }
  if ((Test-Path -LiteralPath (Join-Path $checkout '.githooks')) -and (git -C $checkout config --local core.hooksPath) -ne '.githooks') {
    Write-Caution "$($repo.name) ships git hooks that are not enabled" 'just update'
    continue
  }
  Write-Ok $repo.name
}

if ($is_desktop) {
  Write-Step 'Desktop'
  $startup_dir = [Environment]::GetFolderPath('Startup')
  foreach ($shortcut_name in 'GlazeWM', 'oasis-win-key') {
    if (Test-Path -LiteralPath (Join-Path $startup_dir "$shortcut_name.lnk")) { Write-Ok "$shortcut_name starts at sign-in" }
    else { Write-Problem "$shortcut_name does not start at sign-in" './install.ps1 -unattended -only post' }
  }
  foreach ($process_name in 'glazewm', 'zebar') {
    if (Get-Process $process_name -ErrorAction SilentlyContinue) { Write-Ok "$process_name is running" }
    else { Write-Caution "$process_name is not running" 'sign out and back in, or start it from the Start menu' }
  }
  if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'home/zebar/oasis/installed.json'))) {
    Write-Caution 'the which-key popup has no installed.json, so it lists every app' './install.ps1 -unattended -only post'
  }
}

Write-Step 'Git'
if (Test-Path -LiteralPath (Join-Path $HOME '.config/git/identity')) { Write-Ok 'identity file present' }
else { Write-Caution 'no git identity, so commits will ask for a name and email' './install.ps1 -only post' }

Write-Host ''
if ($failure_count -gt 0) {
  Write-Step "$failure_count problem(s), $warning_count warning(s)"
  exit 1
}
Write-Step $(if ($warning_count -gt 0) { "No problems, $warning_count warning(s)" } else { 'No problems' })
