function Write-Step([string] $message) { Write-Host "==> $message" -ForegroundColor Cyan }
function Write-Ok([string] $message) { Write-Host "  ok $message" -ForegroundColor Green }
function Write-Skip([string] $message) { Write-Host "  -- $message" -ForegroundColor DarkGray }
function Write-Warn([string] $message) { Write-Host "  !! $message" -ForegroundColor Yellow }
function Write-Fail([string] $message) { Write-Host "  xx $message" -ForegroundColor Red }

Export-ModuleMember -Function Write-Step, Write-Ok, Write-Skip, Write-Warn, Write-Fail
