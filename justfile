set shell := ["pwsh", "-NoProfile", "-Command"]

# Full install, picker included.
install *args:
  ./install.ps1 {{args}}

# Pull this repo and the cloned config repos, update Scoop apps, re-apply.
update:
  git pull --ff-only
  Get-ChildItem repos -Directory -ErrorAction SilentlyContinue | ForEach-Object { git -C $_.FullName pull --ff-only }
  scoop update *
  ./install.ps1 -unattended

# Re-open the optional package picker.
pick:
  ./install.ps1 -reselect

# Re-apply links and environment variables only.
link:
  ./install.ps1 -unattended -only links,environment

uninstall:
  ./uninstall.ps1

lint:
  if (Get-Module -ListAvailable PSScriptAnalyzer) { Get-ChildItem -Recurse -Include *.ps1,*.psm1,*.psd1 | Where-Object { $_.FullName -notmatch '[\\/](repos|\.git)[\\/]' } | ForEach-Object { Invoke-ScriptAnalyzer -Path $_.FullName -Settings ./PSScriptAnalyzerSettings.psd1 } } else { Write-Warning 'PSScriptAnalyzer is not installed: Install-Module PSScriptAnalyzer -Scope CurrentUser' }
