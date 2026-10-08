# Zebar links against wlanapi.dll, which Windows Server leaves out unless the Wireless LAN
# Service feature is installed; without it Zebar fails to start ("wlanapi.dll was not found").
# Installing the feature only adds the DLL and its service, and does not enable Wi-Fi.
# Needs an elevated session. Emits $true when it changed something.
Import-Module (Join-Path $PSScriptRoot '../lib/Log.psm1')

# ProductType 1 is a workstation (Windows 10/11); 2 and 3 are domain controller and server.
$is_windows_server = (Get-CimInstance Win32_OperatingSystem).ProductType -ne 1
$has_wlanapi = Test-Path -LiteralPath (Join-Path $env:SystemRoot 'System32\wlanapi.dll')
if (-not $is_windows_server -or $has_wlanapi) { return $false }

$feature_result = Install-WindowsFeature Wireless-Networking
if (-not $feature_result.Success) {
  Write-Warn 'wlan-service: installing Wireless-Networking failed, Zebar will not start'
  return $false
}
if ("$($feature_result.RestartNeeded)" -eq 'Yes') {
  Write-Warn 'wlan-service: restart Windows before Zebar can start'
}
$true
