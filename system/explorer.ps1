# Show file extensions and hidden files; keep web results out of Start search.
# Emits $true when it changed something. Open Explorer windows pick this up on refresh.
$settings = @(
  @{ path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; name = 'HideFileExt'; value = 0 }
  @{ path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; name = 'Hidden'; value = 1 }
  @{ path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'; name = 'BingSearchEnabled'; value = 0 }
  @{ path = 'HKCU:\Software\Policies\Microsoft\Windows\Explorer'; name = 'DisableSearchBoxSuggestions'; value = 1 }
)

$changed = $false
foreach ($setting in $settings) {
  $current = (Get-ItemProperty -Path $setting.path -Name $setting.name -ErrorAction SilentlyContinue).($setting.name)
  if ($current -eq $setting.value) { continue }

  if (-not (Test-Path $setting.path)) { New-Item -Path $setting.path -Force | Out-Null }
  Set-ItemProperty -Path $setting.path -Name $setting.name -Type DWord -Value $setting.value
  $changed = $true
}
$changed
