# Features
Each feature is a flag of `install.sh` (`--<name>`); `./install.sh --variant <name> --help` lists the ones for an OS and profile, with their descriptions and requirements. The features are grouped by the OS, GUI and machine they run on:

- [Every OS](features/common.md): links, shell setup, git, tmux, neovim and other command-line tools
  - [Claude Code](features/claude.md): the `claude` feature and its tools repos
- [Linux](features/linux.md): the font, distrobox, flatpak and webterm
  - [Webterm](features/webterm.md): a shell in the browser on localhost
- [Arch](features/arch.md): the `arch` variant's packages, printer, Logitech and console setup
  - [GNOME](features/gnome.md): pacman and AUR packages, XDG defaults, GDM and dconf settings
- [SteamOS](features/steamos.md): Steam settings and artwork, tools from the distrobox, Game Mode screenshots and test VMs
  - [KDE](features/kde.md): KDE config files
  - [Gaming Mode screenshots](features/gamescope-screenshot.md)
  - [Test VMs](features/test-vms.md): VMs for trying Arch installs and SteamOS
- [Framework 16](features/framework16.md): hardware fixes for the Framework 16, and laptops in general

How to write one is in [Writing features](writing-features.md).

## Requirements
| Feature | Machine | OS | GUI | Requires |
|---|---|---|---|---|
| `terminal`, `printer`, `logiops`, `manual` | any | arch | any | |
| `pacman` | any | arch | gnome | |
| `yay` | any | arch | gnome | |
| `font`, `distrobox` | any | linux | any | |
| `link`, `info`, `shell`, `starship`, `zsh`, `gng`, `tre`, `claude`, `gitconfig` | any | any | any | |
| `desktop_settings` (`arch_gnome/`) | any | arch | gnome | |
| `xdg` | any | arch | gnome | `pacman` |
| `desktop` | any | arch | gnome | `pacman` |
| `console` | any | arch | any | |
| `tmux` | any | any | any | `link` |
| `binaries`, `neovim` | any | linux, macos | any | |
| `flatpak` | any | linux | desktop | |
| `udev`, `tmpfiles`, `hdmi_audio_fix` | framework16 | linux | any | |
| `logind` | laptop | linux | any | |
| `orei_switch`, `light_sleep`, `quiet_slow_charger`, `charge_limit` | framework16 | steamos | any | |
| `steamos_xclip` | any | steamos | desktop | `distrobox` |
| `steamos_make` | any | steamos | any | `distrobox` |
| `steamos_arch_vm`, `steamos_vm` | any | steamos | desktop | `flatpak` |
| `webterm` | any | linux | any | `link` |
| `steam` | any | steamos | any | |
| `steamgrid` | any | steamos | any | |
| `gamescope_screenshot` | any | steamos | any | `link` |
| `desktop_settings` (`linux_kde/`) | any | linux | kde | |

`linux` covers `arch` and `steamos`; GUI `any` also works headless, and `desktop` needs some graphical session. The OSes target the platforms `arch`, `steamos`, and `linux` and `macos` (`portable`); the `desktop` profile targets GNOME on `arch` and KDE on `steamos`, and the other profiles no GUI.

## Managed files
Variants that don't symlink whole files (e.g. `coder`) instead write into a single `## Managed by dotfiles` ... `## /Managed by dotfiles` section of each managed file (`~/.profile`, `~/.zprofile`, `~/.bash_profile` if present, `~/.bashrc`, `~/.zshrc`, `~/git/.claude/CLAUDE.md`, and on SteamOS the keep list `/etc/atomic-update.conf.d/dotfiles.conf`). Each feature owns a `## feature <name>` subblock inside it and rewrites only that subblock on re-run. The markers start with `##`, a comment in sh and in SteamOS keep lists alike; sections written with the older single-`#` markers are converted on the next run. Shell startup file subblocks only source files under `home/.config/sh` and `home/.config/zsh`, which the linked startup files (on `arch` and `steamos`) source too. Edit the files outside the section freely.
