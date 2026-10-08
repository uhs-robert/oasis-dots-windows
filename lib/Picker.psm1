Import-Module (Join-Path $PSScriptRoot 'Log.psm1')

# A selection is a list of tokens: a bare group name ("media") takes the whole
# group, a group/name key ("media/gimp") takes one package. Storing tokens
# rather than resolved packages means a group picked once also picks up
# packages added to that group later.

# fzf returns the highlighted line when Enter is pressed with nothing marked,
# so the cursor starts here to make "confirm with nothing marked" mean nothing.
$none_line = '(none)'

function Format-PickerLines($entries) {
  $none_line
  foreach ($group in $entries | Group-Object group) {
    "[$($group.Name)]  $($group.Group.name -join ' ')"
    foreach ($entry in $group.Group) { "    $($entry.key)" }
  }
}

function ConvertFrom-PickerLine([string] $line) {
  if ($line -match '^\[(.+?)\]') { $Matches[1] } else { $line.Trim() }
}

<#
.SYNOPSIS
Shows the optional packages as one fzf tree and returns the picked tokens.

.DESCRIPTION
Lines matching `previous` start out selected, so re-running only asks for
changes. Returns $null when the picker is cancelled with Esc.
#>
function Select-OptionalPackages($entries, [string[]] $previous = @()) {
  $lines = @(Format-PickerLines $entries)

  $preselect_actions = for ($i = 0; $i -lt $lines.Count; $i++) {
    if ((ConvertFrom-PickerLine $lines[$i]) -in $previous) { "pos($($i + 1))+select" }
  }
  $load_bind = (@($preselect_actions) + 'first') -join '+'

  $picked = $lines | fzf --multi --layout=reverse --height=90% --cycle `
    --prompt 'optional> ' `
    --header 'TAB toggles, ENTER confirms. A [group] line takes the whole group.' `
    --bind "load:$load_bind"

  if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne 1) { return $null }
  @($picked | Where-Object { $_ -ne $none_line } | ForEach-Object { ConvertFrom-PickerLine $_ })
}

# Returns $null when the picker is cancelled. fzf is usually not installed
# yet on a first run, so a plain prompt is the fallback.
function Select-InstallMode {
  $mode_lines = @(
    'desktop   GlazeWM, Zebar, WezTerm, Flow Launcher and the GUI apps; for a local machine or a remote desktop'
    'headless  CLI tools and configs only; for SSH access'
  )

  if (Get-Command fzf -ErrorAction SilentlyContinue) {
    $picked = $mode_lines | fzf --layout=reverse --height=20% --prompt 'mode> ' --header 'ENTER picks the install mode'
    if ($LASTEXITCODE -ne 0 -or -not $picked) { return $null }
    return ($picked -split '\s+')[0]
  }

  Write-Host 'Install mode:'
  $mode_lines | ForEach-Object { Write-Host "  $_" }
  $answer = (Read-Host 'Mode (desktop/headless)').Trim().ToLower()
  if ($answer -in 'desktop', 'headless') { $answer } else { $null }
}

function Resolve-Selection($entries, [string[]] $tokens) {
  $known = @($entries.group) + @($entries.key)
  foreach ($unknown in $tokens | Where-Object { $_ -notin $known }) {
    Write-Warn "ignoring unknown selection '$unknown'"
  }
  $entries | Where-Object { $_.group -in $tokens -or $_.key -in $tokens }
}

Export-ModuleMember -Function Select-InstallMode, Select-OptionalPackages, Resolve-Selection
