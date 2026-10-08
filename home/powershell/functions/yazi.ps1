# Starts yazi and changes into the directory it was left in (official yazi wrapper).
function y {
  if (-not (Get-Command yazi -ErrorAction SilentlyContinue)) { Write-Error 'yazi not found'; return }
  $cwd_file = (New-TemporaryFile).FullName
  yazi @args --cwd-file="$cwd_file"
  $last_dir = Get-Content -Path $cwd_file -Encoding UTF8
  if ($last_dir -and $last_dir -ne $PWD.Path -and (Test-Path -LiteralPath $last_dir -PathType Container)) {
    Set-Location -LiteralPath (Resolve-Path -LiteralPath $last_dir).Path
  }
  Remove-Item -Path $cwd_file
}
