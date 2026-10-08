# Focus a window of the given process, or start it when none is open.
# Runs unchanged on Windows PowerShell 5.1 and pwsh; GlazeWM invokes it with pwsh.
# -shortcut starts a Scoop Start Menu shortcut (see launch.ps1) instead of a raw command.
# Positional binding is off so the launch command is not mistaken for -title_pattern.
[CmdletBinding(PositionalBinding = $false)]
param(
  [Parameter(Mandatory)][string] $process_name,
  [string] $title_pattern = '',
  [string] $shortcut = '',
  [Parameter(ValueFromRemainingArguments)][string[]] $launch_command
)

$wanted_process = $process_name -replace '\.exe$', ''

try {
  # The IPC reply is an envelope: { success, data: { windows: [...] } }.
  $reply = glazewm query windows | ConvertFrom-Json
  $matching_windows = @($reply.data.windows | Where-Object {
      ($_.processName -replace '\.exe$', '') -ieq $wanted_process -and $_.title -match $title_pattern
    })
} catch {
  $matching_windows = @()
}

# Preferring an unfocused window makes a second press switch to another window of the same app.
$window_to_focus = $matching_windows | Where-Object { -not $_.hasFocus } | Select-Object -First 1
if (-not $window_to_focus) { $window_to_focus = $matching_windows | Select-Object -First 1 }

if ($window_to_focus) {
  glazewm command focus --container-id $window_to_focus.id | Out-Null
} elseif ($shortcut) {
  & (Join-Path $PSScriptRoot 'launch.ps1') -shortcut $shortcut
} elseif ($launch_command) {
  $launch_arguments = @($launch_command | Select-Object -Skip 1)
  if ($launch_arguments.Count -gt 0) {
    Start-Process -FilePath $launch_command[0] -ArgumentList $launch_arguments
  } else {
    Start-Process -FilePath $launch_command[0]
  }
}
