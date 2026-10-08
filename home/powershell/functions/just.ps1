Set-Alias j just

# Run recipes from the global justfile against $HOME.
function jg {
  $global_justfile = Join-Path $HOME '.config\just\justfile'
  if (-not (Test-Path $global_justfile)) { Write-Error "no global justfile at $global_justfile"; return }
  just --justfile $global_justfile --working-directory $HOME @args
}
