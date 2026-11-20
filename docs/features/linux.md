# Linux features

These run on any Linux OS (`@os linux`: `arch` and `steamos`).

## `font`
Installs the pinned JetBrainsMono Nerd Font to `~/.local/share/fonts`, unless it is already installed elsewhere. Webterm uses it ([Font](webterm.md#font)).

## `distrobox`
Creates an `arch` distrobox from `archlinux:latest` and enters it once to finish its setup. `--distrobox --reinstall` asks before deleting it, then recreates and enters it. On SteamOS, [`steamos_make` and `steamos_xclip`](steamos.md) copy tools out of it.

## `flatpak`
Installs the flathub apps in `FLATPAK_APPS` per-user, so no root is needed on a read-only rootfs. Needs a desktop session.

## `webterm`
Serves a shell in the browser on localhost, started on demand by systemd from user units it copies into `/etc/systemd/user` and enables for all users (with sudo), so they start from boot even with an encrypted home; see [Webterm](webterm.md) and [SteamOS setup](../one-time-installs/steamos-setup.md). Requires `link`.
