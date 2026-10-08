# Shortest repeat delay and fastest repeat rate. Takes effect at next sign-in.
# Emits $true when it changed something.
$key_path = 'HKCU:\Control Panel\Keyboard'
$settings = @{ KeyboardDelay = '0'; KeyboardSpeed = '31' }

$changed = $false
foreach ($name in $settings.Keys) {
  $current = (Get-ItemProperty -Path $key_path -Name $name -ErrorAction SilentlyContinue).$name
  if ($current -eq $settings[$name]) { continue }

  Set-ItemProperty -Path $key_path -Name $name -Type String -Value $settings[$name]
  $changed = $true
}
$changed
