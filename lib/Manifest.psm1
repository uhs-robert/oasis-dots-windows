Import-Module (Join-Path $PSScriptRoot 'Log.psm1')

# A manifest path may use {tokens}, a leading ~ and %VAR%. Tokens are
# resolved first so a token's value can itself start with ~ or hold %VAR%.

function Test-Elevated {
  $principal = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
  $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-StateDir {
  Join-Path $HOME '.local/state/oasis-dots-windows'
}

function Get-LocalPackageFile {
  Join-Path $HOME '.config/oasis-dots-windows/packages.ini'
}

function Get-ScoopRoot {
  if ($env:SCOOP) { $env:SCOOP } else { Join-Path $HOME 'scoop' }
}

function Read-Manifest([string] $path) {
  Import-PowerShellDataFile -LiteralPath $path
}

function New-ManifestContext($manifest, [string] $repo_root) {
  $repos_dir = Join-Path $repo_root 'repos'
  $tokens = @{
    repo      = $repo_root
    repos     = $repos_dir
    theme     = $manifest.theme
    scoop     = Get-ScoopRoot
    documents = [Environment]::GetFolderPath('MyDocuments')
  }
  foreach ($repo in $manifest.repos) { $tokens[$repo.name] = Join-Path $repos_dir $repo.name }

  $state_dir = Get-StateDir
  @{
    tokens     = $tokens
    repo_root  = $repo_root
    repos_dir  = $repos_dir
    state_dir  = $state_dir
    backup_dir = Join-Path $state_dir "backups/$(Get-Date -Format 'yyyyMMdd-HHmmss')"
  }
}

function Expand-ManifestPath([string] $path, $context) {
  $expanded = [regex]::Replace($path, '\{([^{}]+)\}', {
    param($match)
    $name = $match.Groups[1].Value
    if (-not $context.tokens.ContainsKey($name)) { throw "unknown manifest token {$name} in '$path'" }
    $context.tokens[$name]
  })
  if ($expanded -match '^~(?=[\\/]|$)') { $expanded = $HOME + $expanded.Substring(1) }
  [Environment]::ExpandEnvironmentVariables($expanded)
}

# `when` names either a group ("ai") or one package ("ai/claude-code").
# `mode` limits an entry to one install mode; without it the entry applies in every mode.
function Test-ManifestCondition($entry, [string[]] $active_names, [string] $install_mode) {
  (-not $entry.when -or $entry.when -in $active_names) -and (-not $entry.mode -or $entry.mode -eq $install_mode)
}

function Sync-Repo($repo, $context) {
  $destination = Join-Path $context.repos_dir $repo.name
  $global:LASTEXITCODE = 0

  if (Test-Path -LiteralPath (Join-Path $destination '.git')) {
    git -C $destination pull --ff-only --quiet
    if ($LASTEXITCODE -ne 0) { Write-Warn "$($repo.name): pull failed (local changes?), keeping current checkout"; return }
    Write-Ok "$($repo.name) up to date"
    return
  }

  New-Item -ItemType Directory -Path $context.repos_dir -Force | Out-Null
  git clone --quiet $repo.url $destination
  if ($LASTEXITCODE -ne 0) { Write-Fail "$($repo.name): clone of $($repo.url) failed"; return }
  Write-Ok "$($repo.name) cloned"
}

# Targets we wrote as plain files (jq output, or the copy fallback) look like
# user files on disk, so they are remembered here to tell them apart.
function Get-OwnedFileList($context) { Join-Path $context.state_dir 'owned-files.txt' }

function Get-OwnedFiles($context) {
  $list = Get-OwnedFileList $context
  if (Test-Path -LiteralPath $list) { @(Get-Content -LiteralPath $list | Where-Object { $_ }) } else { @() }
}

function Add-OwnedFile([string] $target, $context) {
  if ($target -in (Get-OwnedFiles $context)) { return }
  New-Item -ItemType Directory -Path $context.state_dir -Force | Out-Null
  Add-Content -LiteralPath (Get-OwnedFileList $context) -Value $target
}

function Remove-OwnedFile([string] $target, $context) {
  $remaining = @(Get-OwnedFiles $context | Where-Object { $_ -ne $target })
  Set-Content -LiteralPath (Get-OwnedFileList $context) -Value $remaining
}

function Get-NormalizedPath([string] $path) {
  [IO.Path]::GetFullPath($path).TrimEnd('\', '/')
}

function Get-LinkItem([string] $path) {
  Get-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
}

function Get-LinkDestination($item) {
  if ($item.LinkType -notin 'SymbolicLink', 'Junction') { return $null }
  $raw = @($item.Target)[0]
  if (-not [IO.Path]::IsPathRooted($raw)) { $raw = Join-Path (Split-Path $item.FullName) $raw }
  Get-NormalizedPath $raw
}

function Test-PathInside([string] $path, [string] $folder) {
  (Get-NormalizedPath $path).StartsWith((Get-NormalizedPath $folder) + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)
}

function Remove-LinkOrFile($item) {
  # Delete() on a directory link removes only the link; Remove-Item -Recurse could walk into the source.
  if ($item.PSIsContainer) { $item.Delete() } else { Remove-Item -LiteralPath $item.FullName -Force }
}

# Keeps the path relative to $HOME so a restore knows where each file belongs.
function Get-BackupRelativePath([string] $target) {
  $home_prefix = (Get-NormalizedPath $HOME) + [IO.Path]::DirectorySeparatorChar
  if ($target.StartsWith($home_prefix, [StringComparison]::OrdinalIgnoreCase)) { return $target.Substring($home_prefix.Length) }
  $target -replace '^([A-Za-z]):', '$1' -replace '^[\\/]+', ''
}

function Move-ToBackup($item, $context) {
  $backup_path = Join-Path $context.backup_dir (Get-BackupRelativePath $item.FullName)
  New-Item -ItemType Directory -Path (Split-Path $backup_path) -Force | Out-Null
  Move-Item -LiteralPath $item.FullName -Destination $backup_path -Force
  Write-Warn "backed up $($item.FullName) -> $backup_path"
}

function Restore-LatestBackup([string] $target, $context) {
  $backups_root = Join-Path $context.state_dir 'backups'
  if (-not (Test-Path -LiteralPath $backups_root)) { return }

  $relative_path = Get-BackupRelativePath $target
  $latest = Get-ChildItem -LiteralPath $backups_root -Directory | Sort-Object Name -Descending |
    Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName $relative_path) } | Select-Object -First 1
  if (-not $latest) { return }

  New-Item -ItemType Directory -Path (Split-Path $target) -Force | Out-Null
  Move-Item -LiteralPath (Join-Path $latest.FullName $relative_path) -Destination $target
  Write-Ok "restored $target from backup $($latest.Name)"
}

function Write-FilteredCopy([string] $source, [string] $target, [string] $filter) {
  # jq writes UTF-8 but pwsh decodes native output with the console code page.
  $previous_encoding = [Console]::OutputEncoding
  [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
  try {
    $global:LASTEXITCODE = 0
    $filtered = & jq $filter $source
    if ($LASTEXITCODE -ne 0) { throw "jq '$filter' failed on $source" }
  } finally {
    [Console]::OutputEncoding = $previous_encoding
  }
  [IO.File]::WriteAllText($target, (($filtered -join "`n") + "`n"), [Text.UTF8Encoding]::new($false))
}

function New-LinkOrFallback([string] $source, [string] $target, $context) {
  try {
    New-Item -ItemType SymbolicLink -Path $target -Target $source -ErrorAction Stop | Out-Null
    return 'linked'
  } catch {
    $symlink_error = $_.Exception.Message
  }

  if (Test-Path -LiteralPath $source -PathType Container) {
    New-Item -ItemType Junction -Path $target -Target $source -ErrorAction Stop | Out-Null
    Write-Warn "symlink not permitted ($symlink_error); used a junction for $target"
    return 'junction'
  }

  Copy-Item -LiteralPath $source -Destination $target -Force
  Add-OwnedFile $target $context
  Write-Warn "symlink not permitted ($symlink_error); copied $target, enable Developer Mode and re-run to link it"
  'copied'
}

function Install-ManifestLink($link, $context) {
  $source = Expand-ManifestPath $link.source $context
  $target = Expand-ManifestPath $link.target $context

  if (-not (Test-Path -LiteralPath $source)) { Write-Warn "source missing, skipped: $source"; return 'missing' }

  $existing = Get-LinkItem $target
  $is_filtered = [bool] $link.filter
  $is_copied = [bool] $link.copy
  $is_owned_file = $existing -and ($target -in (Get-OwnedFiles $context))

  if ($existing -and -not ($is_filtered -or $is_copied) -and (Get-LinkDestination $existing) -eq (Get-NormalizedPath $source)) {
    Write-Skip "$target already linked"
    return 'skipped'
  }

  if ($existing) {
    if ($is_owned_file) {
      Remove-LinkOrFile $existing
      Remove-OwnedFile $target $context
    } else {
      Move-ToBackup $existing $context
    }
  }
  New-Item -ItemType Directory -Path (Split-Path $target) -Force | Out-Null

  if ($is_filtered) {
    Write-FilteredCopy $source $target $link.filter
    Add-OwnedFile $target $context
    Write-Ok "$target (filtered copy: $($link.filter))"
    return 'filtered'
  }

  if ($is_copied) {
    Copy-Item -LiteralPath $source -Destination $target -Force
    Add-OwnedFile $target $context
    Write-Ok "$target (copy of $source)"
    return 'copied'
  }

  $result = New-LinkOrFallback $source $target $context
  if ($result -ne 'copied') { Write-Ok "$target -> $source" }
  $result
}

function Remove-ManifestLink($link, $context) {
  $target = Expand-ManifestPath $link.target $context
  $existing = Get-LinkItem $target

  if ($existing) {
    $destination = Get-LinkDestination $existing
    $points_into_repo = $destination -and ((Test-PathInside $destination $context.repo_root) -or (Test-PathInside $destination $context.repos_dir))
    $is_owned_file = $target -in (Get-OwnedFiles $context)

    if (-not ($points_into_repo -or $is_owned_file)) { Write-Skip "$target is not managed by this repo, left alone"; return }
    Remove-LinkOrFile $existing
    if ($is_owned_file) { Remove-OwnedFile $target $context }
    Write-Ok "removed $target"
  }
  Restore-LatestBackup $target $context
}

function Set-ManifestEnvironmentVariable($entry, $context) {
  $value = Expand-ManifestPath $entry.value $context
  if ([Environment]::GetEnvironmentVariable($entry.name, 'User') -eq $value) {
    Write-Skip "$($entry.name) already set"
  } else {
    [Environment]::SetEnvironmentVariable($entry.name, $value, 'User')
    Write-Ok "$($entry.name)=$value"
  }
  [Environment]::SetEnvironmentVariable($entry.name, $value, 'Process')
}

function Remove-ManifestEnvironmentVariable($entry) {
  if ($null -eq [Environment]::GetEnvironmentVariable($entry.name, 'User')) { return }
  [Environment]::SetEnvironmentVariable($entry.name, $null, 'User')
  Write-Ok "cleared $($entry.name)"
}

Export-ModuleMember -Function Test-Elevated, Get-StateDir, Get-LocalPackageFile, Get-ScoopRoot, Read-Manifest, New-ManifestContext,
  Expand-ManifestPath, Test-ManifestCondition, Sync-Repo, Install-ManifestLink, Remove-ManifestLink,
  Set-ManifestEnvironmentVariable, Remove-ManifestEnvironmentVariable
