#Requires -Version 7
<#
.SYNOPSIS
Removes the links, user environment variables and Startup shortcuts this repo created, restoring backups.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
foreach ($module in 'Log', 'Manifest') {
  Import-Module (Join-Path $PSScriptRoot "lib/$module.psm1") -Force
}

$manifest = Read-Manifest (Join-Path $PSScriptRoot 'manifest.psd1')
$context = New-ManifestContext $manifest $PSScriptRoot

Write-Step 'Removing links'
foreach ($link in $manifest.links) { Remove-ManifestLink $link $context }

Write-Step 'Clearing environment variables'
foreach ($entry in $manifest.environment) { Remove-ManifestEnvironmentVariable $entry }

Write-Step 'Removing Startup shortcuts'
foreach ($shortcut_name in 'GlazeWM', 'oasis-win-key') {
  $shortcut_path = Join-Path ([Environment]::GetFolderPath('Startup')) "$shortcut_name.lnk"
  if (Test-Path -LiteralPath $shortcut_path) {
    Remove-Item -LiteralPath $shortcut_path
    Write-Ok "removed $shortcut_name.lnk"
  }
}

Write-Step 'Done'
Write-Host 'Packages are left installed. To remove them: scoop uninstall <app>  (list them with: scoop list)'
