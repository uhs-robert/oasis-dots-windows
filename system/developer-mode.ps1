# Lets non-admin processes create symlinks. Needs an elevated session.
# Emits $true when it changed something.
Import-Module (Join-Path $PSScriptRoot '../lib/Log.psm1')

$key_path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock'
$name = 'AllowDevelopmentWithoutDevLicense'

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Write-Warn 'developer-mode needs an elevated session'
  return $false
}

$current = (Get-ItemProperty -Path $key_path -Name $name -ErrorAction SilentlyContinue).$name
if ($current -eq 1) { return $false }

if (-not (Test-Path $key_path)) { New-Item -Path $key_path -Force | Out-Null }
Set-ItemProperty -Path $key_path -Name $name -Type DWord -Value 1
$true
