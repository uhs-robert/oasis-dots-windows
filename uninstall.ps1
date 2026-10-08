#Requires -Version 7
<#
.SYNOPSIS
Removes the links, user environment variables and Startup shortcut this repo created, restoring backups.
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

Write-Step 'Removing Startup shortcut'
$shortcut_path = Join-Path ([Environment]::GetFolderPath('Startup')) 'GlazeWM.lnk'
if (Test-Path -LiteralPath $shortcut_path) {
  Remove-Item -LiteralPath $shortcut_path
  Write-Ok 'removed GlazeWM.lnk'
}

Write-Step 'Done'
Write-Host 'Packages are left installed. To remove them: scoop uninstall <app>  (list them with: scoop list)'
