# Arch features

The `arch` variant is designed to work for Arch Linux (or other Arch-based distributions). Essential packages and applications can be installed using `./install.sh --variant arch` as a user. This variant attempts to setup the following (the GNOME parts are [GNOME features](gnome.md)):
 - yay
 - zshell (theme, completions, font)
 - tmux
 - Neovim
 - LaTeX
 - Gnome (desktop environment, the GDM login screen enabled from the next boot, theme)
 - dconf configuration
 - Audiovisual media viewers and basic editors
 - Insync
 - Logiops

A basic Arch installation along with `install.sh` requires ~15gb of drive space.

These features run only on `arch` (`@os arch`), with any GUI or none; to install Arch itself, see [Installing Arch](../one-time-installs/arch-install.md), and for other notes, [Arch setup](../one-time-installs/arch-setup.md).

## `terminal`
Installs only the terminal packages, unless `--pacman` already covers them.

## `printer`
Optional (`--all` skips it). Installs CUPS and the HP printer drivers and enables the cups service.

The `hplip` package is used to install drivers for specific HP printers, whereas `cups` and `system-config-printer` are more general. To install the drivers for a physically connected printer, execute `hp-setup -i` in the terminal (`-i` for CLI interactive mode) and follow the prompts. See this [Stack Exchange post](https://unix.stackexchange.com/questions/359531/installing-hp-printer-driver-for-arch-linux) for more information.

## `logiops`
Builds logiops (Logitech mouse and keyboard daemon) from a pinned release, copies `root/etc/logid.cfg` (not linked: `logid.service` reads it at boot) and enables `logid.service`.

## `manual`
Edits files that can't be symlinked in place:

 - **/etc/bluetooth/main.conf**: `#Autoenable=false` changed to `Autoenable=true`
   - Allows bluetooth to start automatically on boot and after suspend. `main.conf` must be a normal file, rather than a symlink.

## `console`
Copies the us-caps console keymap and the `hid_apple` module option, and `root/etc/vconsole.conf` (which selects the keymap) only where there is none or it is a link from an older install: one that is there already may hold the keymap chosen when installing Arch, which this leaves alone. Not symlinked, since they are read at boot.
