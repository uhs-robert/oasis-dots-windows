# Start a Scoop app through its Start Menu shortcut, for apps whose Scoop shim
# is missing or is the console build. -shortcut is a wildcard on the shortcut
# name; use `*` for spaces because GlazeWM splits commands on whitespace.
[CmdletBinding(PositionalBinding = $false)]
param(
  [Parameter(Mandatory)][string] $shortcut,
  [string] $start_menu_root = (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Scoop Apps')
)

$link = Get-ChildItem -Path $start_menu_root -Filter '*.lnk' -Recurse -ErrorAction SilentlyContinue |
  Where-Object { $_.BaseName -like $shortcut } |
  Select-Object -First 1

if ($link) { Start-Process -FilePath $link.FullName }
