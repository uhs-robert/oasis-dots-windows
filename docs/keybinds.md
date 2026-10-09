# Keybinds

Keybinds for GlazeWM, WezTerm, PowerShell and Yazi, taken from the config files in `home/`.
`Alt` is the GlazeWM leader and `Ctrl+a` is the WezTerm leader. These apply in desktop mode (headless installs no GUI). See
[remote-access.md](remote-access.md) for how they reach a remote session.

## GlazeWM

Source: `home/glazewm/config.yaml`. The leader is Alt everywhere, including on a local machine:
Win+L is reserved by Windows and cannot be overridden. If an app needs the Alt combos itself, pause
GlazeWM with `Alt+Shift+p`.

### Global

| Key | Action |
| --- | --- |
| `Alt+h/j/k/l` (or arrows) | Focus left/down/up/right |
| `Alt+Shift+h/j/k/l` (or arrows) | Move window left/down/up/right |
| `Alt+1` to `Alt+9` | Focus workspace 1 to 9 (1 to 5 always show in the bar) |
| `Alt+Shift+1` to `Alt+Shift+9` | Move window to workspace and focus it |
| `Alt+Ctrl+h` / `Alt+Ctrl+l` | Previous / next open workspace |
| `Alt+Ctrl+j` / `Alt+Ctrl+k` | Move the window to the previous / next open workspace, and follow it |
| `Alt+Ctrl+Shift+h/j/k/l` | Move the whole workspace to the monitor in that direction |
| `Alt+.` / `Alt+,` | Next / previous active workspace |
| `Alt+d` | Recent workspace |
| `Alt+Enter` | New WezTerm window |
| `Alt+y` | Yazi in a new WezTerm window |
| `Alt+v` | Toggle tiling direction |
| `Alt+t` | Toggle tiling |
| `Alt+Shift+Space` | Toggle floating (centered) |
| `Alt+f` | Toggle fullscreen |
| `Alt+m` | Toggle minimized |
| `Alt+x` or `Alt+Shift+q` | Close window |
| `Alt+o` | Windows Run dialog (same as `Win+R`) |
| `Alt+Shift+p` | Pause or resume GlazeWM |
| `Alt+Shift+r` | Reload config |
| `Alt+Shift+w` | Redraw |
| `Alt+Shift+e` | Exit GlazeWM |
| `Alt+r` | Enter resize mode |
| `Alt+a` | Enter apps mode |
| `Alt+g` | Enter go mode |
| `Alt+Shift+/` | Show this global list in the which-key popup (leave with `Esc`, `Enter` or `Alt+Shift+/`) |

### Resize mode (`Alt+r`)

| Key | Action |
| --- | --- |
| `h` / `left` | Width -2% |
| `l` / `right` | Width +2% |
| `k` / `up` | Height +2% |
| `j` / `down` | Height -2% |
| `Shift` + the same keys | Same, in 10% steps |
| `Esc` / `Enter` / `Alt+r` | Leave resize mode |

### Apps mode (`Alt+a`)

Each key starts an app and leaves the mode.

| Key | App |
| --- | --- |
| `b` | Firefox |
| `q` | qutebrowser |
| `e` | Neovim in a WezTerm window |
| `f` | Yazi in a WezTerm window |
| `m` | Betterbird |
| `s` | Slack |
| `d` | Discord |
| `c` | Qalculate (floats, in WezTerm) |
| `g` | GIMP |
| `i` | Inkscape |
| `w` | LibreOffice Writer |
| `x` | LibreOffice Calc |
| `u` | gdu (disk usage, in WezTerm) |
| `t` | btop (task manager, in WezTerm) |
| `a` | WezTerm as Administrator, so its pwsh is elevated (asks UAC) |
| `p` | PowerShell in its own console window, a fallback for when WezTerm misbehaves |
| `h` | xh (HTTP client), typed at a floating WezTerm prompt for its arguments |
| `D` | doggo (DNS), same |
| `G` | gping, same |
| `S` | Steam |
| `Esc` / `Alt+a` | Leave apps mode |

### Go mode (`Alt+g`)

Each key focuses the app's window, or starts it when none is open. Leaves the mode afterwards.

| Key | Target |
| --- | --- |
| `t` | WezTerm |
| `b` | Firefox |
| `q` | qutebrowser |
| `f` | Yazi window (matched by WezTerm title) |
| `m` | Betterbird |
| `s` | Slack |
| `d` | Discord |
| `c` | Neovim window in the dotfiles repo (matched by WezTerm title) |
| `Tab` | Recent workspace |
| `Esc` / `Alt+g` | Leave go mode |

A Zebar which-key popup (bottom center of the primary monitor) lists the active mode's keys, and the bar
shows the mode name, so the modes can be used without memorizing them. The apps and go lists show only
the apps that are installed (`install.ps1` writes `home/zebar/oasis/installed.json`, and the popup shows
everything when that file is missing). While a mode is active, GlazeWM applies only that mode's binds.
The full list is this page.

## WezTerm

Source: `home/wezterm/lua/keys.lua`. The leader is `Ctrl+a`, with a 1.5 second timeout. It mirrors the
tmux binds from oasis-dots.

### Leader (`Ctrl+a`, then key)

| Key | Action |
| --- | --- |
| `Ctrl+a` | Send a literal Ctrl+a |
| `c` | New tab |
| `h` / `l` | Previous / next tab |
| `a` | Last tab |
| `1` to `9` | Tab 1 to 9 |
| `,` | Rename tab |
| `&` | Close tab (confirm) |
| `V` | Split horizontally |
| `S` | Split vertically |
| `z` | Zoom pane |
| `x` | Close pane (confirm) |
| `Enter` | Swap pane with active (pick target) |
| `H` / `J` / `K` / `L` | Resize pane by 5 |
| `w` | Workspace switcher |
| `j` / `k` | Previous / next workspace |
| `n` | New workspace |
| `R` | Rename workspace |
| `v` | Copy mode |
| `q` | Quick select |
| `/` | Search |
| `r` | Reload config |
| `m` | Launcher |
| `Esc` | Cancel |

### Without the leader

| Key | Action |
| --- | --- |
| `Ctrl+c` | Copy if text is selected, otherwise send Ctrl+c |
| `Ctrl+v` | Paste |
| `Ctrl+Shift+y` | Copy if text is selected, otherwise send Ctrl+c |
| `Ctrl+Shift+t` | New tab |
| `Ctrl+Shift+w` | Close tab (confirm) |
| `Ctrl+Shift+]` / `Ctrl+Shift+[` | Next / previous tab |
| `Ctrl+Shift+u` / `Ctrl+Shift+d` | Scroll page up / down |
| `Ctrl+Shift+g` | Scroll to top |
| `Ctrl+Shift+p` | Copy mode |
| `Ctrl+h/j/k/l` | Focus pane left/down/up/right; sent to Neovim when Neovim is in the foreground |
| `Ctrl+Shift+h/j/k/l` | Focus pane in that direction |
| `Ctrl+Shift+Alt+h/j/k/l` | Resize pane by 3 |

## PowerShell

Source: `home/powershell/profile.ps1` and `home/powershell/functions/*.ps1`.

### Line editing

| Key | Action |
| --- | --- |
| Vi mode | Insert and Command modes, with the cursor shape changing per mode |
| `Up` / `Down` | History search backward / forward (both modes) |
| `Tab` (insert) | Menu completion, or fzf completion when PSFzf is installed |
| `Ctrl+t` | fzf file picker (PSFzf) |
| `Ctrl+r` | fzf history search (PSFzf) |

### Functions and aliases

| Name | What it does |
| --- | --- |
| `y` | Yazi; on exit, `cd` to the directory Yazi was left in |
| `f` | fzf to pick a file, then open it in `$env:EDITOR` (Neovim) |
| `s` | fzf over the hosts in `~\.ssh\config`, then `ssh` to the pick |
| `j` | Alias for `just` |
| `jg` | Run recipes from `~\.config\just\justfile` with `$HOME` as the working directory |
| `ff` | fastfetch |
| `ls` | lsd (only when lsd is installed) |
| `l`, `la`, `lla`, `lt` | lsd `-l`, `-a`, `-la`, `--tree` (only when lsd is installed) |

Nushell (optional, `home/nushell/config.nu`) defines `y`, `f`, `jg`, `j`, `l`, `la`, `lla` and `lt`
with the same meanings. Its `ls` stays the structured builtin. Nushell uses vi edit mode.

## Yazi

Source: `home/yazi/keymap.toml`. Only the Windows go-to binds are listed here. Other binds in the same file: `i` (disk usage,
Explorer, run executable), `z u` (unzip), `T` (pane toggles), `u` (restore deleted files).

| Key | Go to |
| --- | --- |
| `g /` | `C:\` |
| `g C` | `~\Documents\Clients` |
| `g D` | `~\Documents` |
| `g d` | `~\Downloads` |
| `g n` | `~\Documents\Notes` |
| `g p` | `~\Pictures` |
| `g v` | `~\Videos` |
| `g T` | `%TEMP%` |
| `g c` | `%APPDATA%` |
| `g L` | `%LOCALAPPDATA%` |
| `g u` | Development folder (`GITHUB_DIR`, or `~\Development`) |
| `g x` | The oasis-dots-windows repo (`OASIS_DOTS_WINDOWS`) |
| `g y` | Yazi config folder |
| `g r` | Git root of the current folder |
| `g w` | Git file changes |
| `g l` | Lazygit, then cd to the repo it ended in |
