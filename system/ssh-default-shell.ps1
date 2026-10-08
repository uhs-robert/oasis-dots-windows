# Makes SSH logins start pwsh 7 instead of cmd.exe, when OpenSSH Server is installed.
# Does not install or enable sshd. Emits $true when it changed something.
Import-Module (Join-Path $PSScriptRoot '../lib/Log.psm1')
Import-Module (Join-Path $PSScriptRoot '../lib/Manifest.psm1')

if (-not (Test-Elevated)) {
  Write-Warn 'ssh-default-shell needs an elevated session'
  return $false
}

$sshd_key_path = 'HKLM:\SOFTWARE\OpenSSH'
if (-not ((Test-Path $sshd_key_path) -or (Get-Service sshd -ErrorAction SilentlyContinue))) { return $false }

# The Scoop shim is a launcher stub that may not behave as a login shell, so point at the real exe.
$pwsh_exe = Join-Path (Get-ScoopRoot) 'apps\pwsh\current\pwsh.exe'
if (-not (Test-Path -LiteralPath $pwsh_exe)) {
  Write-Warn "ssh-default-shell: $pwsh_exe not found, install pwsh first"
  return $false
}

$current = (Get-ItemProperty -Path $sshd_key_path -Name DefaultShell -ErrorAction SilentlyContinue).DefaultShell
if ($current -eq $pwsh_exe) { return $false }

if (-not (Test-Path $sshd_key_path)) { New-Item -Path $sshd_key_path -Force | Out-Null }
Set-ItemProperty -Path $sshd_key_path -Name DefaultShell -Type String -Value $pwsh_exe
$true
