# Targets Nushell >= 0.100. `ls` stays Nushell's structured builtin; lsd is reachable through the short aliases.

$env.config.show_banner = false
$env.config.edit_mode = "vi"
$env.config.cursor_shape.vi_insert = "line"
$env.config.cursor_shape.vi_normal = "block"
$env.config.history.file_format = "sqlite"
$env.config.history.max_size = 10000
$env.config.completions.algorithm = "fuzzy"
$env.config.completions.case_sensitive = false

alias l = ^lsd -l
alias la = ^lsd -a
alias lla = ^lsd -la
alias lt = ^lsd --tree
alias j = just

# Starts yazi and changes into the directory it was left in (official yazi wrapper).
def --env y [...args] {
  let cwd_file = (mktemp -t "yazi-cwd.XXXXXX")
  yazi ...$args --cwd-file $cwd_file
  let last_dir = (open $cwd_file)
  if $last_dir != "" and $last_dir != $env.PWD {
    cd $last_dir
  }
  rm -fp $cwd_file
}

# Run recipes from the global justfile against the home directory.
def jg [...args] {
  just --justfile ($nu.home-dir | path join ".config" "just" "justfile") --working-directory $nu.home-dir ...$args
}

# Fuzzy-pick a file and open it in $env.EDITOR.
def f [] {
  let selected_file = (fzf | str trim)
  if $selected_file != "" {
    run-external $env.EDITOR "--" $selected_file
  }
}
