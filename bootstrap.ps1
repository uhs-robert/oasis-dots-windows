# Runs on stock Windows PowerShell 5.1 and on pwsh.
#   irm https://raw.githubusercontent.com/uhs-robert/oasis-dots-windows/main/bootstrap.ps1 | iex
# `irm | iex` cannot take parameters: pass install.ps1 flags through the
# OASIS_DOTS_WINDOWS_ARGS environment variable (e.g. '-unattended'), or run
# install.ps1 directly. A local copy forwards its own arguments as well.

# The body runs in its own scope so that, under `irm | iex`, preferences and helper
# functions do not leak into the caller's interactive session.
& {
  $ErrorActionPreference = 'Stop'
  [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

  $repo_url = 'https://github.com/uhs-robert/oasis-dots-windows.git'

  function Write-Step([string] $message) { Write-Host "==> $message" -ForegroundColor Cyan }

  function Update-SessionPath {
    $scoop_root = if ($env:SCOOP) { $env:SCOOP } else { Join-Path $HOME 'scoop' }
    $registry_paths = foreach ($scope in 'Machine', 'User') { [Environment]::GetEnvironmentVariable('Path', $scope) }
    $parts = @(Join-Path $scoop_root 'shims') + ($registry_paths -join ';' -split ';') + ($env:Path -split ';')
    $env:Path = ($parts | Where-Object { $_ } | Select-Object -Unique) -join ';'
  }

  # Scoop runs in this process; under 'Stop' any harmless non-terminating error inside it would abort the bootstrap.
  function Invoke-Scoop([scriptblock] $scoop_call) {
    $ErrorActionPreference = 'Continue'
    & $scoop_call
  }

  function Test-Elevated {
    $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  }

  Write-Step 'Execution policy'
  try {
    Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
  } catch {
    Write-Warning "could not set execution policy (group policy?): $_"
  }

  Update-SessionPath

  if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    Write-Step 'Installing Scoop'
    $scoop_installer = Invoke-RestMethod -Uri 'https://get.scoop.sh'
    # Scoop's installer refuses an elevated session unless told otherwise.
    $scoop_install = [scriptblock]::Create($scoop_installer)
    Invoke-Scoop { if (Test-Elevated) { & $scoop_install -RunAsAdmin } else { & $scoop_install } }
    Update-SessionPath
  }

  foreach ($app in 'git', 'pwsh') {
    if (-not (Get-Command $app -ErrorAction SilentlyContinue)) {
      Write-Step "Installing $app"
      Invoke-Scoop { scoop install "main/$app" }
      Update-SessionPath
    }
  }

  $local_root = if ($PSScriptRoot) { $PSScriptRoot } else { $null }
  if ($local_root -and (Test-Path (Join-Path $local_root 'install.ps1'))) {
    $repo_dir = $local_root
  } else {
    $repo_dir = if ($env:OASIS_DOTS_WINDOWS) { $env:OASIS_DOTS_WINDOWS } else { Join-Path $HOME 'oasis-dots-windows' }
  }

  Write-Step "Repo at $repo_dir"
  if (Test-Path (Join-Path $repo_dir '.git')) {
    git -C $repo_dir pull --ff-only
    if ($LASTEXITCODE -ne 0) { Write-Warning 'pull failed, continuing with the current checkout' }
  } elseif (-not (Test-Path (Join-Path $repo_dir 'install.ps1'))) {
    git clone $repo_url $repo_dir
    if ($LASTEXITCODE -ne 0) { throw 'git clone failed' }
  }

  $install_args = @($args)
  if ($env:OASIS_DOTS_WINDOWS_ARGS) {
    $install_args += @($env:OASIS_DOTS_WINDOWS_ARGS -split '\s+' | Where-Object { $_ })
  }

  Write-Step 'Running install.ps1'
  & pwsh -NoProfile -File (Join-Path $repo_dir 'install.ps1') @install_args
} @args
