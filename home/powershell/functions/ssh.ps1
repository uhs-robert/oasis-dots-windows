# Concrete host aliases from ~/.ssh/config; wildcard, negated and option-like patterns are skipped.
function Get-SshHost {
  $config_path = Join-Path $HOME '.ssh\config'
  if (-not (Test-Path $config_path)) { return }
  Get-Content $config_path |
    ForEach-Object { ($_ -replace '#.*', '').Trim() } |
    Where-Object { $_ -match '^(?i)host(\s+|\s*=\s*)(.+)$' } |
    ForEach-Object { $Matches[2] -split '\s+' } |
    ForEach-Object { $_.Trim('"', "'") } |
    Where-Object { $_ -and $_ -notmatch '[!*?\[]' -and $_ -notmatch '^-' } |
    Sort-Object -Unique
}

# Fuzzy-pick an ssh host and connect, passing any extra arguments through.
function s {
  $selected_host = Get-SshHost | fzf --prompt='SSH > ' --height=60% --layout=reverse
  if ($selected_host) { ssh $selected_host @args }
}
