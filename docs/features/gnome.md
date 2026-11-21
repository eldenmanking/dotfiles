# GNOME features

These run on `arch` with GNOME (`@gui gnome`, the `desktop` profile).

## `pacman`
Installs the terminal, GNOME and LaTeX pacman packages.

## `yay`
Installs yay if missing, then the AUR packages (themes, Insync, Chrome, Zoom).

## `xdg`
Creates the XDG user directories and sets default apps for PDFs, images, audio and text. Requires `pacman`.

## `desktop`
Enables the desktop's system units (bluetooth, and GDM from the next boot) and boots into the graphical target. Requires `pacman`.

## `desktop_settings`
The GNOME implementation (`arch_gnome/desktop_settings.sh`) backs up the current dconf settings, then loads `dump/dconf/arch.dconf`. The first backup is kept, since later ones would hold what an earlier install loaded. `--capture --desktop_settings` writes the file back (see [Capturing settings](../installation.md#capturing-settings)).

It loads `dump/dconf/arch.dconf` with `dconf load /`, and `--capture` writes it from `dconf dump /`, keeping only the keys `DCONF_CAPTURE` (`install/features/arch_gnome/desktop_settings.sh`) selects.
- An entry ending in `/` selects a dconf directory with its subdirectories, any other entry a single key, and an entry starting with `!` leaves out what it names, for state kept beside settings (e.g. `!org/gnome/desktop/input-sources/mru-sources`).
- Select only what's worth carrying to another machine: `org/gnome/shell`, for one, also holds the Alt+F2 command history, so only its `favorite-apps` key is selected.
- Paths under the home directory are written as `${HOME}/...` (e.g. the wallpaper, `file://${HOME}/.local/share/backgrounds/GH2.jpg`) and expanded again on load.
- If none of the selected keys are set, as on an unconfigured machine, the file is left alone.
