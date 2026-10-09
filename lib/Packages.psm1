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
$script:failed_scoop_apps = $null
$script:known_buckets = $null
$script:healthy_buckets = @()

# An install that died partway (a dropped download) still appears in `scoop list`, flagged
# "Install failed" under Info. Counting it as installed made every later run skip it for good.
function Read-ScoopList {
  $apps = @(scoop list 6>$null)
  $script:failed_scoop_apps = @($apps | Where-Object { "$($_.Info)" -match 'Install failed' } | ForEach-Object Name)
  $script:installed_scoop_apps = @($apps | ForEach-Object Name | Where-Object { $_ -notin $script:failed_scoop_apps })
}

function Get-InstalledScoopApps {
  if ($null -eq $script:installed_scoop_apps) { Read-ScoopList }
  $script:installed_scoop_apps
}

function Get-FailedScoopApps {
  if ($null -eq $script:failed_scoop_apps) { Read-ScoopList }
  $script:failed_scoop_apps
}

function Get-ScoopRootDir {
  if ($env:SCOOP) { $env:SCOOP } else { Join-Path $HOME 'scoop' }
}

function Get-ScoopBucketDir([string] $bucket) {
  Join-Path (Get-ScoopRootDir) "buckets/$bucket"
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

# Client networks have dropped large downloads mid-transfer (Firefox, zig), so a
# failed install is retried a few times before it is reported.
$max_install_attempts = 3
$retry_delay_seconds = 5

# Returns $null on success, otherwise why the attempt failed. Installer output
# goes to the host so it is shown, not mistaken for the return value.
function Invoke-PackageInstall($entry) {
  # Native installers report failure only through the exit code, and a stale
  # code from an earlier command would otherwise read as this one failing.
  $global:LASTEXITCODE = 0

  switch ($entry.source) {
    'scoop' { scoop install "$($entry.bucket)/$($entry.id)" | Out-Host }
    'winget' { winget install --exact --id $entry.id --silent --accept-package-agreements --accept-source-agreements | Out-Host }
    'psgallery' {
      try {
        Install-Module -Name $entry.id -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
      } catch {
        return "$_"
      }
    }
  }
  if ($global:LASTEXITCODE -ne 0) { "exit $global:LASTEXITCODE" }
}

# A failed download can leave a partial file in Scoop's cache, or a half-installed
# app folder that makes the next `scoop install` refuse to run.
function Reset-FailedScoopInstall($entry) {
  scoop cache rm $entry.id 6>$null | Out-Null
  if (Test-Path -LiteralPath (Join-Path (Get-ScoopRootDir) "apps/$($entry.id)")) {
    scoop uninstall $entry.id 6>$null | Out-Null
  }
}

function Install-Package($entry) {
  if (Test-PackageInstalled $entry) {
    Write-Skip "$($entry.key) already installed"
    return
  }
  if ($entry.source -eq 'winget' -and -not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Warn "$($entry.key) skipped: winget is not available on this machine"
    return
  }
  if ($entry.source -eq 'scoop') {
    Add-ScoopBucket $entry.bucket
    # `scoop install` refuses to run over a failed install's leftovers.
    if ($entry.id -in (Get-FailedScoopApps)) {
      Write-Warn "$($entry.key) has a failed install left over, clearing it first"
      Reset-FailedScoopInstall $entry
    }
  }

  for ($attempt = 1; $attempt -le $max_install_attempts; $attempt++) {
    $failure = Invoke-PackageInstall $entry
    if (-not $failure) {
      if ($entry.source -eq 'scoop') {
        $script:installed_scoop_apps += $entry.id
        $script:failed_scoop_apps = @($script:failed_scoop_apps | Where-Object { $_ -ne $entry.id })
      }
      Write-Ok $entry.key
      return
    }
    if ($attempt -lt $max_install_attempts) {
      Write-Warn "$($entry.key) failed ($failure), retrying in ${retry_delay_seconds}s (attempt $($attempt + 1) of $max_install_attempts)"
      if ($entry.source -eq 'scoop') { Reset-FailedScoopInstall $entry }
      Start-Sleep -Seconds $retry_delay_seconds
    }
  }
  Write-Fail "$($entry.key) failed to install after $max_install_attempts attempts ($failure)"
}

Export-ModuleMember -Function Read-PackageIni, Read-LocalPackageIni, Install-Package, Test-PackageInstalled
