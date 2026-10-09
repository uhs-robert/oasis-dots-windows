# Installer reference

Everything the installer does, for when the [README](../README.md) is not enough.

## Bootstrap

`bootstrap.ps1` runs on the stock Windows PowerShell 5.1. It installs Scoop, git and pwsh if they are missing, clones this repo to `$HOME\oasis-dots-windows` (or to `$OASIS_DOTS_WINDOWS` if set), and runs `install.ps1`.

`irm | iex` cannot take parameters. To pass `install.ps1` flags, set `OASIS_DOTS_WINDOWS_ARGS` first:

```powershell
$env:OASIS_DOTS_WINDOWS_ARGS = '-mode headless -unattended'
irm https://raw.githubusercontent.com/uhs-robert/oasis-dots-windows/main/bootstrap.ps1 | iex
```

To test a branch other than `main` (a PR, for example), set `OASIS_DOTS_WINDOWS_BRANCH` and fetch that branch's `bootstrap.ps1`:

```powershell
$env:OASIS_DOTS_WINDOWS_BRANCH = 'my-branch'
irm https://raw.githubusercontent.com/uhs-robert/oasis-dots-windows/my-branch/bootstrap.ps1 | iex
```

Or run the installer directly from a clone:

```powershell
cd $HOME\oasis-dots-windows
./install.ps1                       # full install, picker included
./install.ps1 -select media,dev-js  # skip the picker, use these groups
```

## Installer flags

| Flag               | Effect                                                                               |
| ------------------ | ------------------------------------------------------------------------------------ |
| `-mode <mode>`     | `desktop` or `headless`. Saved and reused; asked on the first run if omitted.        |
| `-select <tokens>` | Use these optional-package tokens (comma separated), save them, skip the picker.     |
| `-unattended`      | Reuse the saved selection and mode and never prompt.                                 |
| `-reselect`        | Show the picker even with `-unattended`.                                             |
| `-only <steps>`    | Run only these steps: `repos`, `packages`, `links`, `environment`, `system`, `post`. |

## Modes

The mode is chosen on the first run and saved to `$HOME\.local\state\oasis-dots-windows\mode.txt`. `./install.ps1 -mode desktop` (or `headless`) overrides and saves it, and re-runs reuse it. With `-unattended` and no saved mode the installer stops and asks for `-mode`. Switching a machine from desktop to headless removes the desktop-only links, variables and the GlazeWM Startup shortcut on the next run.

Configs that port unchanged are not copied. They are read from the upstream repos, which are cloned into `repos/`:

- `oasis-dots`: starship, git, bat, lazygit, yazi plugins, Claude Code and Codex skills
- `oasis.nvim`: theme files for WezTerm, PSReadLine and Yazi
- `neovim`: the Neovim config

## Packages

Packages come from Scoop, winget or the PowerShell Gallery. Their definitions are in `packages/`.
The `gui-` files are only read in desktop mode.

**Required** are always installed:

- `packages/required.ini` (both modes): installer (git, 7zip, fzf, just), shell (pwsh, starship,
  zoxide, lsd, bat, less, fd, ripgrep, gsudo, PSReadLine, PSFzf), editor (neovim, mingw, tree-sitter), git
  (lazygit, delta, difftastic, mergiraf, gh) and files (yazi, ffmpeg, poppler, imagemagick, jq).
- `packages/gui-required.ini` (desktop only): desktop (GlazeWM, Zebar, WezTerm, Flow Launcher,
  JetBrainsMono Nerd Font, AutoHotkey for the Windows-key script).

**Optional** are picked at install time. `packages/optional.ini` is offered in both modes:

| Group        | Contents                                           |
| ------------ | -------------------------------------------------- |
| `shells`     | nu (Nushell)                                       |
| `coreutils`  | uutils-coreutils, grep, sed, gawk                  |
| `monitoring` | btop, fastfetch, dust, duf, gdu                    |
| `network`    | xh, doggo, gping, aria2, rclone, yt-dlp            |
| `utilities`  | tealdeer, qalculate, topgrade                      |
| `dev-js`     | nodejs-lts, pnpm, bun, deno                        |
| `dev-go-py`  | go, python, uv, pipx                               |
| `dev-lint`   | lua, luarocks, stylua, luacheck, shellcheck, shfmt |
| `ai`         | claude-code, codex                                 |

`packages/gui-optional.ini` is added in desktop mode:

| Group           | Contents                             |
| --------------- | ------------------------------------ |
| `desktop-tools` | hunt-and-peck, sharex, everything    |
| `browsers`      | firefox, qutebrowser                 |
| `comms`         | slack, discord, betterbird           |
| `docs`          | sumatrapdf, libreoffice              |
| `media`         | mpv, vlc, gimp, inkscape, obs-studio |
| `gaming`        | steam, epic, gog, playnite           |
| `editors`       | vscode                               |
| `docker`        | Docker Desktop (winget)              |

Group names are unique across all package files, because `when` and the saved selection match on them.

### Per-machine packages

Entries in `$HOME\.config\oasis-dots-windows\packages.ini` are added to the optional picker in both
modes. The format is the same as `packages/optional.ini`. Each `[section]` becomes a group named
`local-<section>`; entries before any section go in the group `local`. The file is not part of this
repo, and the installer does not check whether its packages suit the mode.

```ini
[work]
main/slack-cli
extras/zoom
```

Neovim's language support follows what is installed: a language whose Mason tools need Node,
Python, Go, Ruby or Rust only loads when that toolchain is on PATH, so picking `dev-js` is what
brings in TypeScript, Astro and the other Node-based languages. To turn one off on this machine
anyway, create `%LOCALAPPDATA%\nvim\lua\config\machine.lua`:

```lua
return { disabled_extras = { "lang.astro" } }
```

The neovim repo's README lists the extras and what each one needs.

### The picker

The picker is one fzf tree of groups and packages:

- A `[group]` line selects the whole group.
- An indented `group/app` line selects a single package.
- The `(none)` line confirms with nothing selected.
- TAB toggles a line, ENTER confirms, Esc cancels.

Selected tokens are saved to `$HOME\.local\state\oasis-dots-windows\selection.txt`. Re-running the
installer starts with that selection already marked. Saved tokens are group names or `group/app`
keys, so a group picked once also picks up packages added to it later.

Tokens for `-select` use the same form, for example `-select media,dev-js/nodejs-lts`. Unknown tokens
are ignored with a warning. If fzf is missing or the picker is cancelled, the previous selection is kept.

## What gets linked and set

`manifest.psd1` is the single list of links and environment variables. Links marked with `when` only
apply when that group or package is selected. Entries with `mode = 'desktop'` are skipped in headless
mode. Those are the WezTerm and Zebar links and `GLAZEWM_CONFIG_PATH`.

| Target                                                                                     | Source                                  | Condition        |
| ------------------------------------------------------------------------------------------ | --------------------------------------- | ---------------- |
| `~\.config\starship.toml`, `~\.config\git\config`, `~\.config\git\ignore`, `%APPDATA%\bat` | oasis-dots                              | always           |
| `~\.config\wezterm`                                                                        | this repo `home\wezterm`                | always           |
| `Documents\PowerShell\Microsoft.PowerShell_profile.ps1`                                    | this repo `home\powershell\profile.ps1` | always           |
| `%APPDATA%\nushell\config.nu`, `env.nu`                                                    | this repo `home\nushell`                | `shells/nu`      |
| `~\.glzr\zebar\settings.json` (a copy, since Zebar rewrites it), `~\.glzr\zebar\oasis`          | this repo `home\zebar`                  | desktop          |
| `%APPDATA%\yazi\config\*` (keymap, yazi, theme, package, init) and plugins                 | this repo `home\yazi`, oasis-dots       | always           |
| `%APPDATA%\yazi\config\flavors\oasis-moonlight-dark.yazi`                                  | oasis.nvim                              | always           |
| `%LOCALAPPDATA%\nvim`                                                                      | neovim repo                             | always           |
| `%APPDATA%\topgrade.toml`                                                                  | this repo `home\topgrade`               | `utilities/topgrade` |
| `~\.claude\skills`, `~\.claude\keybindings.json`, `~\.claude\settings.json`                | oasis-dots                              | `ai/claude-code` |
| `~\.codex\skills`                                                                          | oasis-dots                              | `ai/codex`       |

The Claude Code `settings.json` is a jq-filtered copy (`del(.hooks)`), because the Linux settings
reference hooks that do not exist on Windows. It is not a symlink.

Environment variables are set at user scope:

| Name                  | Value                                                      |
| --------------------- | ---------------------------------------------------------- |
| `OASIS_DOTS_WINDOWS`    | this repo's path                                           |
| `OASIS_THEME`         | `moonlight`                                                |
| `GLAZEWM_CONFIG_PATH` | `home\glazewm\config.yaml` (no link needed)                |
| `LG_CONFIG_FILE`      | oasis-dots lazygit config, then `home\lazygit\windows.yml` |
| `SCOOP`               | the Scoop root (GlazeWM and the bar launch Flow Launcher from it) |
| `YAZI_FILE_ONE`       | Git's `file.exe` (Yazi's preview helper)                   |

`EDITOR` and `VISUAL` are set in the shell profiles, not as user variables.

Before a link replaces an existing file or folder that this repo did not create, the original is moved
to `$HOME\.local\state\oasis-dots-windows\backups\<timestamp>\`.

## Admin and non-admin

- **Symlinks** need Developer Mode. An elevated run switches it on before linking. Without it:
  - a linked folder falls back to a junction;
  - a linked file falls back to a copy, with a warning. Enable Developer Mode and re-run to make it a link.
- **System tweaks** only run when elevated. Otherwise the installer prints a warning and skips them.
  Run `./install.ps1 -only system` from an elevated PowerShell later. The tweaks are:
  - Explorer (both modes): show file extensions and hidden files, keep web results out of Start search.
  - Taskbar (desktop): auto-hide, so Zebar owns the top edge.
  - Keyboard (desktop): shortest repeat delay and fastest repeat rate (takes effect at next sign-in).
  - Windows Server (desktop, Server only): installs the `Wireless-Networking` feature when `wlanapi.dll`
    is missing and the Evergreen WebView2 runtime when it is missing, both of which Zebar needs to start,
    stops Server Manager opening at sign-in, and switches your user to "Adjust for best performance"
    (no animations, transparency or shadows; there is no GPU, and a remote session re-sends every frame).
  - SSH default shell (headless): if OpenSSH Server is installed, make pwsh 7 the login shell. It does
    not install or enable sshd.
- Scoop and PowerShell Gallery packages, repo sync, the links and the user environment variables do not
  need admin. Some winget packages (Docker Desktop) may still ask for it.

## Updating

```powershell
just update    # git pull this repo, pull repos/*, topgrade (or scoop update *), then install.ps1 -unattended
```

| Recipe               | Does                                                            |
| -------------------- | --------------------------------------------------------------- |
| `just install *args` | Full install, picker included. Extra args go to `install.ps1`.  |
| `just update`        | Pull everything, update packages and re-apply, without prompts. |
| `just pick`          | Re-open the optional package picker (`-reselect`).              |
| `just link`          | Re-apply links and environment variables only.                  |
| `just uninstall`     | Run `uninstall.ps1`.                                            |
| `just lint`          | Run PSScriptAnalyzer over the scripts, if installed.            |

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
packages/              required.ini, optional.ini, gui-required.ini, gui-optional.ini
lib/                   PowerShell modules: Log, Manifest, Packages, Picker
system/                Windows tweaks: developer-mode, explorer, taskbar, keyboard, windows-server, ssh-default-shell
home/
  glazewm/             config.yaml, scripts/ (focus-or-launch, launch)
  zebar/               settings.json, oasis/ (bar, styles, zpack)
  wezterm/             wezterm.lua, lua/ (keys, theme, status, workspaces)
  powershell/          profile.ps1, functions/ (y, f, s, j, jg, ff, ssh, ...)
  nushell/             config.nu, env.nu
  yazi/                keymap, yazi, theme, package, init, plugins/jump-to.yazi
  lazygit/             windows.yml, lazygit-edit.ps1, yazi-lazygit-cd.ps1
docs/
  remote-access.md     RDP and other remote desktops, SSH
  keybinds.md          all keybinds by app
repos/                 created by the installer, git-ignored
```
