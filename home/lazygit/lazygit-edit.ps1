param(
  [Parameter(Mandatory)][string]$file,
  [string]$line
)

# Inside a Neovim terminal ($env:NVIM is the parent's server pipe) reuse that instance instead of nesting.
$nvim_server_alive = $env:NVIM -and (nvim --server $env:NVIM --remote-expr '1' 2>$null) -eq '1'

if ($nvim_server_alive) {
  # Vim's :edit treats backslash, space and a few others as special in a path.
  $escaped_file = [regex]::Replace($file, '([\\ %#|"])', '\$1')
  $goto_line = if ($line) { ":$line<CR>" } else { '' }
  nvim --server $env:NVIM --remote-send "<C-\><C-N>:close<CR>:edit $escaped_file<CR>$goto_line"
  return
}

$env:NVIM = $null
if ($line) {
  nvim "+$line" $file
} else {
  nvim $file
}
