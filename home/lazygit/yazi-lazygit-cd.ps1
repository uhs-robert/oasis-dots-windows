# Port of rob-bin's yazi-lazygit-cd: open lazygit from yazi, then move yazi to the repo
# lazygit last had open, read from the top of `recentrepos` in lazygit's state.yml.
lazygit

# Where lazygit keeps state.yml on Windows varies with how it was set up, so the
# first one that exists wins; the jesseduffield path is lazygit's legacy location.
$state_file_candidates = @(
  if ($env:XDG_STATE_HOME) { Join-Path $env:XDG_STATE_HOME 'lazygit\state.yml' }
  Join-Path $env:LOCALAPPDATA 'lazygit\state.yml'
  Join-Path $env:APPDATA 'jesseduffield\lazygit\state.yml'
)
$state_file = $state_file_candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $state_file) { exit 0 }

$in_recent_repos = $false
$last_repo = foreach ($line in Get-Content -LiteralPath $state_file) {
  if ($line -match '^recentrepos:\s*$') { $in_recent_repos = $true; continue }
  if (-not $in_recent_repos) { continue }
  if ($line -match '^\s*-\s+(.+)$') { $Matches[1].Trim().Trim('"', "'"); break }
  if ($line -match '^\S') { break }
}

if ($last_repo -and (Test-Path -LiteralPath $last_repo -PathType Container)) {
  ya emit cd $last_repo
}
exit 0
