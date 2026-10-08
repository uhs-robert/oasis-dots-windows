# Fuzzy-pick a file and open it in $env:EDITOR.
function f {
  $selected_file = fzf
  if ($selected_file) { & ($env:EDITOR ?? 'nvim') -- $selected_file }
}
