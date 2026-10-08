# Fills the gaps Windows Server has compared to Windows 10/11 for the desktop setup.
# Does nothing on a workstation. Needs an elevated session. Emits $true when it changed something.
Import-Module (Join-Path $PSScriptRoot '../lib/Log.psm1')

# ProductType 1 is a workstation (Windows 10/11); 2 and 3 are domain controller and server.
if ((Get-CimInstance Win32_OperatingSystem).ProductType -eq 1) { return $false }

# Zebar links against wlanapi.dll, which Server only ships with the Wireless LAN Service
# feature. Installing it adds the DLL and its service; it does not enable Wi-Fi.
function Add-WlanApi {
  if (Test-Path -LiteralPath (Join-Path $env:SystemRoot 'System32\wlanapi.dll')) { return $false }

  $feature_result = Install-WindowsFeature Wireless-Networking
  if (-not $feature_result.Success) {
    Write-Warn 'windows-server: installing Wireless-Networking failed, Zebar will not start'
    return $false
  }
  if ("$($feature_result.RestartNeeded)" -eq 'Yes') {
    Write-Warn 'windows-server: restart Windows before Zebar can start'
  }
  $true
}

# Zebar draws with WebView2, which Windows 11 ships and Server does not. This installs the
# Evergreen runtime machine-wide, which keeps itself updated. Scoop's extras/webview2 was
# skipped on purpose: it pins a fixed version and forces every WebView2 app to use it.
$webview2_client_id = '{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}'
$webview2_bootstrapper_url = 'https://go.microsoft.com/fwlink/p/?LinkId=2124703'

function Test-WebView2Installed {
  $version_keys = @(
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\$webview2_client_id"
    "HKLM:\SOFTWARE\Microsoft\EdgeUpdate\Clients\$webview2_client_id"
    "HKCU:\Software\Microsoft\EdgeUpdate\Clients\$webview2_client_id"
  )
  foreach ($key in $version_keys) {
    $version = (Get-ItemProperty -Path $key -Name pv -ErrorAction SilentlyContinue).pv
    if ($version -and $version -ne '0.0.0.0') { return $true }
  }
  $false
}

function Add-WebView2 {
  if (Test-WebView2Installed) { return $false }

  $bootstrapper = Join-Path $env:TEMP 'MicrosoftEdgeWebview2Setup.exe'
  try {
    Invoke-WebRequest -Uri $webview2_bootstrapper_url -OutFile $bootstrapper -UseBasicParsing -ErrorAction Stop
    $process = Start-Process -FilePath $bootstrapper -ArgumentList '/silent', '/install' -Wait -PassThru
  } catch {
    Write-Warn "windows-server: WebView2 download failed ($_), Zebar will not start"
    return $false
  } finally {
    Remove-Item -LiteralPath $bootstrapper -Force -ErrorAction SilentlyContinue
  }
  if ($process.ExitCode -ne 0) {
    Write-Warn "windows-server: WebView2 installer exited with $($process.ExitCode), Zebar will not start"
    return $false
  }
  $true
}

# Per-user, so the client's other admins keep their Server Manager.
function Disable-ServerManagerAtLogon {
  $key_path = 'HKCU:\Software\Microsoft\ServerManager'
  $value_name = 'DoNotOpenServerManagerAtLogon'
  if ((Get-ItemProperty -Path $key_path -Name $value_name -ErrorAction SilentlyContinue).$value_name -eq 1) { return $false }

  if (-not (Test-Path $key_path)) { New-Item -Path $key_path -Force | Out-Null }
  Set-ItemProperty -Path $key_path -Name $value_name -Type DWord -Value 1
  $true
}

# Each step runs even when an earlier one changed something.
$changes = @(Add-WlanApi; Add-WebView2; Disable-ServerManagerAtLogon)
$changes -contains $true
