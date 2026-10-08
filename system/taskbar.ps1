# Auto-hide the taskbar so Zebar owns the top edge.
# Emits $true when it changed something (and restarts Explorer to apply it).
$key_path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3'
$auto_hide_byte = 8
$auto_hide_bit = 0x01

$settings = (Get-ItemProperty -Path $key_path -Name Settings -ErrorAction SilentlyContinue).Settings
if (-not $settings) { return $false }
if ($settings[$auto_hide_byte] -band $auto_hide_bit) { return $false }

$settings[$auto_hide_byte] = $settings[$auto_hide_byte] -bor $auto_hide_bit
Set-ItemProperty -Path $key_path -Name Settings -Value $settings
Stop-Process -Name explorer -Force
$true
