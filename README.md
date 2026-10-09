<p align="center">
  <img
    src="https://raw.githubusercontent.com/uhs-robert/oasis-dots/assets/logo.png"
    width="auto" height="128" alt="Oasis logo" />
</p>
<h1 align="center">oasis-dots-windows</h1>
<p align="center">
  <a href="https://github.com/uhs-robert/oasis-dots-windows/stargazers"><img src="https://img.shields.io/github/stars/uhs-robert/oasis-dots-windows?colorA=192330&colorB=khaki&style=for-the-badge&cacheSeconds=4300" alt="Stargazers"></a>
  <a href="https://github.com/uhs-robert/oasis-dots-windows/issues"><img src="https://img.shields.io/github/issues/uhs-robert/oasis-dots-windows?colorA=192330&colorB=skyblue&style=for-the-badge&cacheSeconds=4300" alt="Issues"></a>
  <a href="https://github.com/uhs-robert/oasis-dots-windows/graphs/contributors"><img src="https://img.shields.io/github/contributors/uhs-robert/oasis-dots-windows?colorA=192330&colorB=8FD1C7&style=for-the-badge&cacheSeconds=4300" alt="Contributors"></a>
  <a href="https://github.com/uhs-robert/oasis-dots-windows/network/members"><img src="https://img.shields.io/github/forks/uhs-robert/oasis-dots-windows?colorA=192330&colorB=C799FF&style=for-the-badge&cacheSeconds=4300" alt="Forks"></a>
  <a href="https://discord.gg/b7y5CGVGTB"><img src="https://img.shields.io/discord/1554625284068741140?label=discord&logo=discord&logoColor=white&colorA=192330&colorB=5865F2&style=for-the-badge&cacheSeconds=4300" alt="Discord"></a>
</p>
<p align="center">A keyboard-driven Linux workflow for Windows: tiling, a real package manager and your dotfiles.</p>

<img width="1393" height="1045" alt="screenshot-2026-10-09_14h33m27s" src="https://github.com/user-attachments/assets/36eda190-7de1-4d28-b67d-2263f248cd1e" />

## 🖥️ Overview

If you live in Linux, Windows is a hostile place to work: no tiling window manager, no package manager you'd trust with your setup, a shell that fights your muscle memory, and none of your configs. But sooner or later, you end up there anyway thanks to some reason or another (client, family computer, that one app you need, etc).

oasis-dots-windows makes that machine feel a bit more like `~`. It's a keyboard-driven tiling desktop with a package manager for Windows, set up with the same tools, keybinds and themes as your Linux side, and it links your configs straight from your Linux dotfiles, so an edit on either system is an edit on both. One command installs it, whichever way you're using Windows:

| You're on...                                   | Mode       | You get                                                                       |
| ---------------------------------------------- | ---------- | ----------------------------------------------------------------------------- |
| A server you SSH into                          | `headless` | pwsh 7 as your SSH shell, nvim, yazi, lazygit and the CLI toolset             |
| A desktop you remote into (RDP, NinjaOne, ...) | `desktop`  | All of the above, plus GlazeWM tiling, a Zebar bar, Flow Launcher and WezTerm |
| Your own machine, as an alternative to Linux   | `desktop`  | The same, with optional groups for browsers, media, gaming and everyday apps  |

## 📦 Install

In PowerShell on the Windows machine (run as Admin if you can for symlinks and system tweaks):

```powershell
irm https://raw.githubusercontent.com/uhs-robert/oasis-dots-windows/main/bootstrap.ps1 | iex
```

It installs [Scoop](https://scoop.sh), asks whether this is a `desktop` or `headless` machine, and opens an fzf picker for optional apps, where you can take a whole group or single packages. Re-running is safe: anything it would overwrite is backed up first, and `uninstall.ps1` puts it all back.

Run it from an elevated PowerShell if you can. Admin turns on Developer Mode, so configs become real symlinks, and applies a few system tweaks. Without admin everything still installs per user, using junctions and copies instead.

> [!NOTE]
> Flags, unattended installs, and the full list of what gets linked are in [docs/install.md](docs/install.md).

## ⌨️ Getting Started, Your First Keys

GlazeWM tiles every window, driven by Alt:

| Keys                | Does                                                            |
| ------------------- | --------------------------------------------------------------- |
| `Alt+Enter`         | Open WezTerm                                                    |
| `Alt+Space`         | Flow Launcher: apps, files, calculator                          |
| `Alt+h/j/k/l`       | Focus left, down, up, right (`Alt+Shift+h/j/k/l` moves)         |
| `Alt+1..9`, `Alt+0` | Switch workspace (`Alt+Shift+` the same sends the window there) |
| `Alt+a`, then a key | Launch an app: `b` browser, `e` nvim, `f` yazi, `s` Slack       |
| `Alt+g`, then a key | Jump to an app's window, launching it if it isn't open          |
| `Alt+Shift+/`       | Show every global bind in a popup (`Esc` closes it)             |

While a mode like `Alt+a` is active, a Zebar popup lists its keys (only for installed apps). In WezTerm, `Ctrl+a` is a tmux-style leader for tabs, splits and workspaces. Every bind is in [docs/keybinds.md](docs/keybinds.md).

### Why is Alt the leader key?

Windows reserves `Win+L` to lock the screen and nothing can take it over, so a Hyprland-style `Win+l` would never work. Alt also gets through remote desktop clients without grabbing the keyboard. When an app needs its own Alt shortcuts, `Alt+Shift+P` pauses GlazeWM. Pressing the Windows key on its own no longer opens Start (a small AutoHotkey script stops it, so Super habits from Linux don't keep popping it open), while combinations like `Win+L` still work.

## 🧰 What's Inside

- **Desktop:** [GlazeWM](https://github.com/glzr-io/glazewm) with i3/Hyprland-style modes, a [Zebar](https://github.com/glzr-io/zebar) bar (workspaces, stats and the system tray) and Flow Launcher in place of rofi.
- **Terminal:** WezTerm standing in for both kitty and tmux.
- **Shell:** PowerShell 7 set up to feel like zsh (vi mode, fzf completion, starship, zoxide, your functions), with Nushell as an option.
- **Tools:** nvim, yazi, lazygit, ripgrep, fd, bat, delta and friends, always installed.
- **Themes:** [Oasis](https://github.com/uhs-robert/oasis.nvim) across the terminal, prompt, bar, file manager and editor.

### Optional Packages

Picked at install time, or later with `just pick`. Desktop-only groups are hidden in headless mode.

| Group           | Contents                                           | Desktop only |
| --------------- | -------------------------------------------------- | :----------: |
| `shells`        | Nushell                                            |              |
| `coreutils`     | uutils coreutils, grep, sed, gawk                  |              |
| `monitoring`    | btop, fastfetch, dust, duf, gdu                    |              |
| `network`       | xh, doggo, gping, aria2, rclone, yt-dlp            |              |
| `utilities`     | tealdeer, qalculate, topgrade                      |              |
| `dev-js`        | Node.js LTS, pnpm, bun, deno                       |              |
| `dev-go-py`     | Go, Python, uv, pipx                               |              |
| `dev-lint`      | lua, luarocks, stylua, luacheck, shellcheck, shfmt |              |
| `ai`            | Claude Code, Codex                                 |              |
| `desktop-tools` | Hunt and Peck, ShareX, Everything                  |      x       |
| `browsers`      | Firefox, qutebrowser                               |      x       |
| `comms`         | Slack, Discord, Betterbird                         |      x       |
| `docs`          | SumatraPDF, LibreOffice                            |      x       |
| `media`         | mpv, VLC, GIMP, Inkscape, OBS                      |      x       |
| `gaming`        | Steam, Epic, GOG Galaxy, Playnite                  |      x       |
| `editors`       | VS Code                                            |      x       |
| `docker`        | Docker Desktop                                     |      x       |

Apps specific to one machine can go in `~/.config/oasis-dots-windows/packages.ini`, which joins the picker without touching the repo.

## 🛠️ Everyday Use

```powershell
just update      # pull everything, update all packages (topgrade if installed), re-apply
just pick        # re-open the optional package picker
just doctor      # check this machine's setup and print a fix for each problem
just link        # re-apply links and environment variables only
just uninstall   # remove links and variables, restore backups
```

## 🔗 Make It Yours

This repo points at my Linux dotfiles. To use your own, fork it, then:

1. Change `$repo_url` in `bootstrap.ps1` and the `irm` URL above to your fork.
2. Point `repos` in `manifest.psd1` at your Linux dotfiles, and update each link's `source` to where those configs live in your repo.
3. Adjust the Windows-only configs in `home/` (GlazeWM, Zebar, WezTerm, the pwsh profile) to taste.

Like it? Give it a star, or [buy me a coffee](https://ko-fi.com/uphillsolutions).

## 🌐 Remote Access

On a remote desktop, GlazeWM's Alt binds work without any client setup, but the Windows key and `Alt+Tab` only reach Windows when the client grabs the keyboard. For SSH, use `headless` mode. Both are covered in [docs/remote-access.md](docs/remote-access.md).

## ⚠️ Known Limitations

- **Binds do nothing while an admin window has focus.** Windows hides keystrokes in elevated windows from non-elevated apps like GlazeWM. Close the admin PowerShell you installed from, or click another window first.
- **Windows Server needs admin for the bar.** Zebar needs `wlanapi.dll` and the WebView2 runtime, which Windows Server leaves out. An elevated install adds both; without admin, Zebar fails to start.
- **Paths with spaces break GlazeWM launches.** GlazeWM splits commands on whitespace, so a repo path containing a space breaks the launch binds.
