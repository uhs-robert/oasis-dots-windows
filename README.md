<p align="center">
  <img
    src="https://raw.githubusercontent.com/uhs-robert/oasis-dots/assets/logo.png"
    width="auto" height="128" alt="Oasis logo" />
</p>
<h1 align="center">dotfiles-windows</h1>
<p align="center">
  <a href="https://github.com/uhs-robert/dotfiles-windows/stargazers"><img src="https://img.shields.io/github/stars/uhs-robert/dotfiles-windows?colorA=192330&colorB=khaki&style=for-the-badge&cacheSeconds=4300" alt="Stargazers"></a>
  <a href="https://github.com/uhs-robert/dotfiles-windows/issues"><img src="https://img.shields.io/github/issues/uhs-robert/dotfiles-windows?colorA=192330&colorB=skyblue&style=for-the-badge&cacheSeconds=4300" alt="Issues"></a>
  <a href="https://github.com/uhs-robert/dotfiles-windows/graphs/contributors"><img src="https://img.shields.io/github/contributors/uhs-robert/dotfiles-windows?colorA=192330&colorB=8FD1C7&style=for-the-badge&cacheSeconds=4300" alt="Contributors"></a>
  <a href="https://github.com/uhs-robert/dotfiles-windows/network/members"><img src="https://img.shields.io/github/forks/uhs-robert/dotfiles-windows?colorA=192330&colorB=C799FF&style=for-the-badge&cacheSeconds=4300" alt="Forks"></a>
  <a href="https://discord.gg/b7y5CGVGTB"><img src="https://img.shields.io/discord/1554625284068741140?label=discord&logo=discord&logoColor=white&colorA=192330&colorB=5865F2&style=for-the-badge&cacheSeconds=4300" alt="Discord"></a>
</p>
<p align="center">Windows counterpart to <a href="oasis-dots](https://github.com/uhs-robert">oasis-dots</a>, the Arch Linux dotfiles.</p>

One command on a fresh Windows 10/11 machine installs the tools and links the configs.

The desktop is GlazeWM (tiling, Alt leader) with a Zebar bar and Flow Launcher. The terminal is
WezTerm running PowerShell 7 by default, with Nushell as an optional shell. The theme is Oasis
Moonlight (dark).

Configs that port unchanged are not copied. They are read from the upstream repos, which are cloned
into `repos/`:

- `oasis-dots`: starship, git, bat, lazygit, yazi plugins, Claude Code and Codex skills
- `oasis.nvim`: theme files for WezTerm, PSReadLine and Yazi
- `neovim`: the Neovim config

## Quick start

Run this in PowerShell on the Windows machine:

```powershell
irm https://raw.githubusercontent.com/uhs-robert/dotfiles-windows/main/bootstrap.ps1 | iex
```

`bootstrap.ps1` installs Scoop, git and pwsh if they are missing, clones this repo to
`$HOME\dotfiles-windows` (or to `$DOTFILES_WINDOWS` if set), and runs `install.ps1`.

`irm | iex` cannot take parameters. To pass `install.ps1` flags, set `DOTFILES_WINDOWS_ARGS` first:

```powershell
$env:DOTFILES_WINDOWS_ARGS = '-unattended'
irm https://raw.githubusercontent.com/uhs-robert/dotfiles-windows/main/bootstrap.ps1 | iex
```

Or run the installer directly from a clone:

```powershell
cd $HOME\dotfiles-windows
./install.ps1                       # full install, picker included
./install.ps1 -select media,dev-js  # skip the picker, use these groups
```

## Installer flags

| Flag               | Effect                                                                               |
| ------------------ | ------------------------------------------------------------------------------------ |
| `-select <tokens>` | Use these optional-package tokens (comma separated), save them, skip the picker.     |
| `-unattended`      | Reuse the saved selection and never prompt.                                          |
| `-reselect`        | Show the picker even with `-unattended`.                                             |
| `-only <steps>`    | Run only these steps: `repos`, `packages`, `links`, `environment`, `system`, `post`. |

## Packages

Packages come from Scoop, winget or the PowerShell Gallery. Their definitions are in `packages/`.

**Required** (`packages/required.ini`) are always installed. They are grouped as installer (git, 7zip,
fzf, just), desktop (GlazeWM, Zebar, WezTerm, Flow Launcher, JetBrainsMono Nerd Font), shell (pwsh,
starship, zoxide, lsd, bat, less, fd, ripgrep, PSReadLine, PSFzf), editor (neovim, zig, tree-sitter),
git (lazygit, delta, difftastic, mergiraf, gh) and files (yazi, ffmpeg, poppler, imagemagick, jq).

**Optional** (`packages/optional.ini`) are picked at install time:

| Group        | Contents                                           |
| ------------ | -------------------------------------------------- |
| `shells`     | nu (Nushell)                                       |
| `coreutils`  | uutils-coreutils, grep, sed, gawk                  |
| `desktop`    | hunt-and-peck, sharex                              |
| `monitoring` | btop, fastfetch, dust, duf, gdu                    |
| `network`    | xh, doggo, gping, aria2, rclone, yt-dlp            |
| `utilities`  | tealdeer, qalculate, topgrade                      |
| `browsers`   | firefox, qutebrowser                               |
| `comms`      | slack, discord, betterbird                         |
| `docs`       | sumatrapdf, libreoffice                            |
| `media`      | mpv, vlc, gimp, inkscape                           |
| `dev-js`     | nodejs-lts, pnpm, bun, deno                        |
| `dev-go-py`  | go, python, uv, pipx                               |
| `dev-lint`   | lua, luarocks, stylua, luacheck, shellcheck, shfmt |
| `docker`     | Docker Desktop (winget)                            |
| `ai`         | claude-code, codex                                 |

### The picker

The picker is one fzf tree of groups and packages:

- A `[group]` line selects the whole group.
- An indented `group/app` line selects a single package.
- The `(none)` line confirms with nothing selected.
- TAB toggles a line, ENTER confirms, Esc cancels.

Selected tokens are saved to `$HOME\.local\state\dotfiles-windows\selection.txt`. Re-running the
installer starts with that selection already marked. Saved tokens are group names or `group/app`
keys, so a group picked once also picks up packages added to it later.

Tokens for `-select` use the same form, for example `-select media,dev-js/nodejs-lts`. Unknown tokens
are ignored with a warning. If fzf is missing or the picker is cancelled, the previous selection is kept.

## What gets linked and set

`manifest.psd1` is the single list of links and environment variables. Links marked with `when` only
apply when that group or package is selected.

| Target                                                                                     | Source                                  | Condition        |
| ------------------------------------------------------------------------------------------ | --------------------------------------- | ---------------- |
| `~\.config\starship.toml`, `~\.config\git\config`, `~\.config\git\ignore`, `%APPDATA%\bat` | oasis-dots                              | always           |
| `~\.config\wezterm`                                                                        | this repo `home\wezterm`                | always           |
| `Documents\PowerShell\Microsoft.PowerShell_profile.ps1`                                    | this repo `home\powershell\profile.ps1` | always           |
| `%APPDATA%\nushell\config.nu`, `env.nu`                                                    | this repo `home\nushell`                | `shells/nu`      |
| `~\.glzr\zebar\settings.json`, `~\.glzr\zebar\oasis`                                       | this repo `home\zebar`                  | always           |
| `%APPDATA%\yazi\config\*` (keymap, yazi, theme, package, init) and plugins                 | this repo `home\yazi`, oasis-dots       | always           |
| `%APPDATA%\yazi\config\flavors\oasis-moonlight-dark.yazi`                                  | oasis.nvim                              | always           |
| `%LOCALAPPDATA%\nvim`                                                                      | neovim repo                             | always           |
| `~\.claude\skills`, `~\.claude\keybindings.json`, `~\.claude\settings.json`                | oasis-dots                              | `ai/claude-code` |
| `~\.codex\skills`                                                                          | oasis-dots                              | `ai/codex`       |

The Claude Code `settings.json` is a jq-filtered copy (`del(.hooks)`), because the Linux settings
reference hooks that do not exist on Windows. It is not a symlink.

Environment variables are set at user scope:

| Name                  | Value                                                      |
| --------------------- | ---------------------------------------------------------- |
| `DOTFILES_WINDOWS`    | this repo's path                                           |
| `OASIS_THEME`         | `moonlight`                                                |
| `GLAZEWM_CONFIG_PATH` | `home\glazewm\config.yaml` (no link needed)                |
| `LG_CONFIG_FILE`      | oasis-dots lazygit config, then `home\lazygit\windows.yml` |
| `YAZI_FILE_ONE`       | Git's `file.exe` (Yazi's preview helper)                   |

`EDITOR` and `VISUAL` are set in the shell profiles, not as user variables.

Before a link replaces an existing file or folder that this repo did not create, the original is moved
to `$HOME\.local\state\dotfiles-windows\backups\<timestamp>\`.

## Admin and non-admin

- **Symlinks** need Developer Mode. An elevated run switches it on before linking. Without it:
  - a linked folder falls back to a junction;
  - a linked file falls back to a copy, with a warning. Enable Developer Mode and re-run to make it a link.
- **System tweaks** only run when elevated. Otherwise the installer prints a warning and skips them.
  Run `./install.ps1 -only system` from an elevated PowerShell later. The tweaks are:
  - Explorer: show file extensions and hidden files, keep web results out of Start search.
  - Taskbar: auto-hide, so Zebar owns the top edge.
  - Keyboard: shortest repeat delay and fastest repeat rate (takes effect at next sign-in).
- Scoop and PowerShell Gallery packages, repo sync, the links and the user environment variables do not
  need admin. Some winget packages (Docker Desktop) may still ask for it.

## Updating

```powershell
just update    # git pull this repo, pull repos/*, scoop update *, then install.ps1 -unattended
```

| Recipe               | Does                                                           |
| -------------------- | -------------------------------------------------------------- |
| `just install *args` | Full install, picker included. Extra args go to `install.ps1`. |
| `just update`        | Pull everything and re-apply, without prompts.                 |
| `just pick`          | Re-open the optional package picker (`-reselect`).             |
| `just link`          | Re-apply links and environment variables only.                 |
| `just uninstall`     | Run `uninstall.ps1`.                                           |
| `just lint`          | Run PSScriptAnalyzer over the scripts, if installed.           |

## Uninstall

```powershell
just uninstall   # or ./uninstall.ps1
```

This removes:

- every link this repo created, and restores the latest backup for each target;
- the user environment variables listed in `manifest.psd1`;
- the GlazeWM Startup shortcut.

Targets that are not managed by this repo are left alone.

It does not remove packages. To remove them, use `scoop uninstall <app>` (`scoop list` shows what is
installed). It also leaves the cloned `repos\`, the state directory (selection and backups), Developer
Mode, the system tweaks and the git identity file.

## Layout

```
bootstrap.ps1          one-line entry point (Windows PowerShell 5.1 or pwsh)
install.ps1            installer: repos, packages, links, environment, system, post
uninstall.ps1          removes links, env vars and the Startup shortcut
manifest.psd1          repos, links, environment variables, theme
justfile               update, pick, link, lint and friends
packages/              required.ini, optional.ini
lib/                   PowerShell modules: Log, Manifest, Packages, Picker
system/                Windows tweaks: developer-mode, explorer, taskbar, keyboard
home/
  glazewm/             config.yaml, scripts/ (focus-or-launch, launch)
  zebar/               settings.json, oasis/ (bar, styles, zpack)
  wezterm/             wezterm.lua, lua/ (keys, theme, status, workspaces)
  powershell/          profile.ps1, functions/ (y, f, s, j, jg, ff, ssh, ...)
  nushell/             config.nu, env.nu
  yazi/                keymap, yazi, theme, package, init, plugins/jump-to.yazi
  lazygit/             windows.yml, lazygit-edit.ps1
docs/
  rdp.md               connecting from Arch Linux over RDP
  keybinds.md          all keybinds by app
repos/                 created by the installer, git-ignored
```

## Known limitations

- **Paths with spaces break GlazeWM launches.** GlazeWM splits `shell-exec` commands on whitespace, so
  a repo path with a space (for example a `DOTFILES_WINDOWS` override) breaks the launch commands in
  `config.yaml`. `launch.ps1` works around this for shortcut names by using `*` for spaces.
- **lazygit.yazi does not change directory on exit on Windows.** The plugin comes from oasis-dots. Its
  directory check shells out to `test -d`, which Windows does not provide. That is the likely cause (not
  confirmed).
- **Only partly verified on real Windows.** The configs were written and checked without a Windows
  machine. The GlazeWM, WezTerm, Yazi and Nushell behaviour has not been run on Windows yet.

## More

- [docs/rdp.md](docs/rdp.md): connecting from Arch Linux so Alt combos and the Windows key reach the
  remote session.
- [docs/keybinds.md](docs/keybinds.md): keybinds for GlazeWM, WezTerm, PowerShell and Yazi.
