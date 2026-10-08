# Remote access

The Windows machine is reached from an Arch Linux host running Hyprland, either as a remote desktop
(RDP, NinjaOne or any other tool) or over SSH.

## Remote desktop

Use desktop mode. The goal is that Alt combos and the Windows key reach the remote session instead of
being used by Hyprland. The keyboard grab advice below applies to any remote desktop tool, not only RDP.

### RDP client

FreeRDP 3 (`xfreerdp3`, package `freerdp` in Arch) is the client used here. Fullscreen with dynamic
resolution and clipboard sharing:

```sh
xfreerdp3 /v:HOST /u:USER /f /dynamic-resolution +clipboard
```

- `/v:` the host, `/u:` the user. Add `/p:` only if you do not want a prompt.
- `/f` starts fullscreen. FreeRDP grabs the keyboard in fullscreen by default (verify on your build).
- `+toggle-fullscreen` (the default `Ctrl+Alt+Enter`) toggles fullscreen at runtime (verify).
- `/kbd:` sets the keyboard layout. If the remote layout is wrong, check it with `/kbd-list` (verify).
- Key remapping on the client can be done with `/kbd:remap:` (verify the exact syntax with `xfreerdp3 /help`).

Remmina (the GUI client) has a "Grab all keyboard events" toggle for the same purpose. Turn it on for
the connection so that keys are sent to the remote session while the session window has focus (verify
the label in your Remmina version).

### Why Alt is the GlazeWM leader

GlazeWM uses Alt as its leader (see [keybinds.md](keybinds.md)), remote or local. Alt combos work over
a remote desktop even without keyboard grabbing: the client forwards them as ordinary key presses.
Win+L is reserved by Windows and cannot be overridden, so a Windows-key leader is not an option.

Some keys are still taken by the local desktop unless the grab is on. Alt+Tab and similar window
switching are captured by Hyprland on Arch. Turn the grab on (fullscreen, or Remmina's toggle) if these
should reach Windows.

### Remaps on the Arch side

The Arch host uses keyd for remaps (`system/etc/keyd/default.conf` in oasis-dots: Caps Lock tap sends Esc,
hold sends Ctrl, and holding Tab enters a vim-lite layer). These are applied before the key reaches the RDP client, so the remote side
receives the already-remapped keys. No remapper is needed on Windows for this.

### Windows key

The Windows key is forwarded as the Super key when grabbing is on (verify). Hyprland uses Super for its
own binds, so the grab is needed for Windows-key shortcuts to reach Windows.

### Checklist

- Connect with fullscreen and the keyboard grab on.
- Check that Alt+h/j/k/l moves focus in GlazeWM.
- Check that Alt+Enter opens WezTerm.
- If Alt+Tab goes to Hyprland, enable the grab.

## SSH

Use headless mode (`./install.ps1 -mode headless`). It installs the CLI tools and configs only.

Windows' OpenSSH Server drops SSH logins into cmd.exe by default. In headless mode, an elevated run
sets the `DefaultShell` registry value to the real `pwsh.exe` under Scoop (not the shim), so SSH
logins land in PowerShell 7 with the profile loaded. This only happens when OpenSSH Server is already
installed; the installer does not install or enable sshd. Re-run `./install.ps1 -only system` from an
elevated PowerShell after installing it.
