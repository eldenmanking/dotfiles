# SteamOS features

The `steamos` variant installs everything per-user, since the SteamOS root filesystem is read-only; its `neovim` feature, for example, downloads the release binary into `~/.local`. These features run only on `steamos` (`@os steamos`); the Linux features ([Linux](linux.md)) run there too, its desktop settings are [KDE features](kde.md), and its Framework 16 fixes are [Framework 16 features](framework16.md). For setting up SteamOS itself, see [SteamOS setup](../one-time-installs/steamos-setup.md).

## `steam`
Sets Game Mode settings such as the main menu and quick access hotkeys in each Steam user's `localconfig.vdf`, replacing only keys Steam already wrote and only while Steam is closed, since Steam rewrites that file on exit; add more to `STEAM_SETTINGS` in `install/features/steam.sh`.

## `steamgrid`
Optional (`--all` skips it). Copies the artwork in `dump/steamgrid` into every Steam user's `config/grid`, for the apps in `STEAMGRID_APPS` (`install/features/steamgrid.sh`, each an app id and a name; add an app by putting its `<appid>p.png` and `<appid>_hero.png` in `dump/steamgrid` and listing it). It copies whether or not the user has the shortcut yet: Steam shows the artwork once the shortcut exists. A file that differs from one already there replaces it, after the first copy of the old one is backed up under `.backup`. Steam reads the artwork when it starts, so restart it afterwards.

`dump/steamgrid` holds custom Steam artwork for the Chrome and Discord shortcuts, named by each shortcut's app id (`<appid>p.png` portrait capsule, `<appid>_hero.png` hero): `--steamgrid` (SteamOS, optional) copies them into each Steam user's `config/grid`, or copy them into `~/.steam/steam/userdata/<user id>/config/grid/` by hand, then restart Steam. A shortcut's app id depends on its name and executable, so check `shortcuts.vdf` or the file names Steam writes in that folder when you set artwork by hand, and rename these to match.

## `steamos_make`
Installs make to `~/.local/bin` by copying it out of the `arch` distrobox (created if missing, then kept), since the SteamOS rootfs is read-only. Requires `distrobox`.

## `steamos_xclip`
Installs xclip to `~/.local/bin` the same way, out of the `arch` distrobox. Needs a desktop session; requires `distrobox`.

## `gamescope_screenshot`
Takes Game Mode screenshots from the keyboard; see [Gaming Mode screenshots](gamescope-screenshot.md). Requires `link`.

## `steamos_arch_vm`
Optional (`--all` skips it), on the `desktop` profile. Creates a GNOME Boxes VM for trying out Arch installs; see [Arch install test VM](test-vms.md#arch-install-test-vm). Requires `flatpak`.

## `steamos_vm`
Optional (`--all` skips it), on the `desktop` profile. Creates a virt-manager VM running SteamOS, for trying out changes; see [SteamOS test VM](test-vms.md#steamos-test-vm). Requires `flatpak`.
