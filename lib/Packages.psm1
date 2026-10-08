Import-Module (Join-Path $PSScriptRoot 'Log.psm1')

<#
.SYNOPSIS
Reads a packages/*.ini file into one entry per package.

.DESCRIPTION
Each entry carries its [group], a short name for display and selection, and
where it installs from. Scoop entries are written `bucket/app`; other sources
use a `source:id` prefix. `name = source:id` overrides the display name.
`group_prefix` is prepended to every [group]; `default_group` names entries
that appear before any [group] header.
#>
function Read-PackageIni([string] $path, [string] $group_prefix = '', [string] $default_group = $null) {
  $group = $default_group
  foreach ($raw_line in Get-Content -LiteralPath $path) {
    $line = ($raw_line -replace '[#;].*$', '').Trim()
    if (-not $line) { continue }

    if ($line -match '^\[(.+)\]$') {
      $group = $group_prefix + $Matches[1]
      continue
    }

    $name, $spec = if ($line -match '^([^=]+)=(.+)$') {
      $Matches[1].Trim(), $Matches[2].Trim()
    } else {
      $null, $line
    }

    $entry = if ($spec -match '^(winget|psgallery):(.+)$') {
      [pscustomobject]@{ source = $Matches[1]; bucket = $null; id = $Matches[2] }
    } elseif ($spec -match '^([^/]+)/(.+)$') {
      [pscustomobject]@{ source = 'scoop'; bucket = $Matches[1]; id = $Matches[2] }
    } else {
      throw "${path}: '$spec' needs a bucket/ or source: prefix"
    }

    $entry | Add-Member name ($name ?? $entry.id)
    $entry | Add-Member group $group
    $entry | Add-Member key "$group/$($entry.name)"
    $entry
  }
}

# A per-machine file in the same format as packages/*.ini. Its groups are
# prefixed with `local-` so they cannot collide with the repo's groups.
function Read-LocalPackageIni([string] $path) {
  if (-not (Test-Path -LiteralPath $path)) { return @() }
  Read-PackageIni $path -group_prefix 'local-' -default_group 'local'
}

$script:installed_scoop_apps = $null
$script:known_buckets = $null
$script:healthy_buckets = @()

function Get-InstalledScoopApps {
  if ($null -eq $script:installed_scoop_apps) {
    $script:installed_scoop_apps = @(scoop list 6>$null | ForEach-Object Name)
  }
  $script:installed_scoop_apps
}

function Get-ScoopBucketDir([string] $bucket) {
  $scoop_root = if ($env:SCOOP) { $env:SCOOP } else { Join-Path $HOME 'scoop' }
  Join-Path $scoop_root "buckets/$bucket"
}

# Scoop installed before git existed downloads buckets as plain folders, and `scoop update`
# then skips them ("is not a git repository"), so a listed bucket can still be empty or stale.
function Test-ScoopBucketHealthy([string] $bucket) {
  Test-Path -LiteralPath (Join-Path (Get-ScoopBucketDir $bucket) '.git')
}

function Add-ScoopBucket([string] $bucket) {
  if ($null -eq $script:known_buckets) {
    $script:known_buckets = @(scoop bucket list 6>$null | ForEach-Object Name)
  }
  if ($bucket -in $script:healthy_buckets) { return }

  if ($bucket -in $script:known_buckets -and -not (Test-ScoopBucketHealthy $bucket)) {
    Write-Warn "bucket '$bucket' is not a git checkout, re-adding it"
    scoop bucket rm $bucket | Out-Null
    $script:known_buckets = @($script:known_buckets | Where-Object { $_ -ne $bucket })
  }
  if ($bucket -notin $script:known_buckets) {
    scoop bucket add $bucket | Out-Null
    $script:known_buckets += $bucket
  }
  $script:healthy_buckets += $bucket
}

function Test-PackageInstalled($entry) {
  switch ($entry.source) {
    'scoop' { $entry.id -in (Get-InstalledScoopApps) }
    'winget' { [bool] (winget list --exact --id $entry.id --accept-source-agreements 2>$null | Select-String -SimpleMatch $entry.id) }
    'psgallery' { [bool] (Get-Module -ListAvailable -Name $entry.id) }
  }
}

function Install-Package($entry) {
  if (Test-PackageInstalled $entry) {
    Write-Skip "$($entry.key) already installed"
    return
  }

  # Native installers report failure only through the exit code, and a stale
  # code from an earlier command would otherwise read as this one failing.
  $global:LASTEXITCODE = 0

  switch ($entry.source) {
    'scoop' {
      Add-ScoopBucket $entry.bucket
      scoop install "$($entry.bucket)/$($entry.id)"
      if ($global:LASTEXITCODE -eq 0) { $script:installed_scoop_apps += $entry.id }
    }
    'winget' {
      if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Warn "$($entry.key) skipped: winget is not available on this machine"
        return
      }
      winget install --exact --id $entry.id --silent --accept-package-agreements --accept-source-agreements
    }
    'psgallery' {
      try {
        Install-Module -Name $entry.id -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
      } catch {
        Write-Fail "$($entry.key) failed to install: $_"
        return
      }
    }
  }

  if ($global:LASTEXITCODE -ne 0) {
    Write-Fail "$($entry.key) failed to install (exit $global:LASTEXITCODE)"
  } else {
    Write-Ok $entry.key
  }
}

Export-ModuleMember -Function Read-PackageIni, Read-LocalPackageIni, Install-Package, Test-PackageInstalled
