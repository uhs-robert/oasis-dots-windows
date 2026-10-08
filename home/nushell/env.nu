# Targets Nushell >= 0.100 (vendor autoload directories, `$env.config.<key>` assignment style).

$env.EDITOR = "nvim"
$env.VISUAL = "nvim"
$env.GIT_EDITOR = "nvim"
$env.PAGER = "less -RF --mouse"
$env.FZF_DEFAULT_COMMAND = "fd --type f --hidden --follow --exclude .git"
$env.FZF_DEFAULT_OPTS = "--height=80% --layout=reverse --border --preview 'bat --style=numbers --color=always {}' --preview-window=right:60%:border-left --bind=ctrl-p:toggle-preview"

# Generated init scripts land in the vendor autoload dir, which Nushell sources after config.nu.
# Regenerated every start so tool upgrades are picked up; both generators are fast.
# Machine-local additions can be dropped into the same directory as any *.nu file.
let autoload_dir = ($nu.data-dir | path join "vendor" "autoload")
mkdir $autoload_dir

if (which starship | is-not-empty) {
  starship init nu | save -f ($autoload_dir | path join "starship.nu")
}

if (which zoxide | is-not-empty) {
  zoxide init nushell | save -f ($autoload_dir | path join "zoxide.nu")
}
