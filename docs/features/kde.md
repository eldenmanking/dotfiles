# KDE features

These run on Linux with KDE (`@gui kde`: `steamos` with the `desktop` profile).

## `desktop_settings`
The KDE implementation (`linux_kde/desktop_settings.sh`) merges partial KDE config files such as `home/.config/kcminputrc` (keyboard repeat rate) and `home/.config/kxkbrc` (clears XKB options like `caps:escape`, since the Keychron's firmware already swaps Caps Lock and Escape) and `home/.config/powerdevilrc` (closing the lid on external power does nothing; PowerDevil keeps the lid switch from logind, so the `logind` feature's `lid.conf` doesn't reach Desktop Mode) into their `~/.config` counterparts key by key with `kwriteconfig6`, rather than linking them, since KDE rewrites its config files and would break symlinks; keys not in the repo file are left alone. Add more files to `KDE_CONFIG_FILES` in `install/features/linux_kde/desktop_settings.sh`. After changing those settings in System Settings, `--capture --desktop_settings` copies them back into the repo's files (see [Capturing settings](../installation.md#capturing-settings)).

`--capture` works as on [GNOME](gnome.md#desktop_settings), on KDE's config files, which have the same layout: it writes each file in `KDE_CONFIG_FILES` from its `~/.config` counterpart, keeping only what `KDE_CAPTURE` (`install/features/linux_kde/desktop_settings.sh`) selects.
- Entries are written as `<file>/<group>/<key>` (e.g. `kcminputrc/Keyboard/` for the whole `[Keyboard]` group).
