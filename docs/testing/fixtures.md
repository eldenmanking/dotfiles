# Fixtures
`make fixtures` (`tests/fixtures.sh`, needs docker or podman) shows and pins exactly what an install does to existing files. It isn't part of `make check`, since it needs a container runtime and network access.

## Cases
- Each case in `tests/fixtures/<name>/` has a `case.sh` that names a container image from `tests/images/` (`IMAGE`) and the `install.sh` arguments (`ARGS`), and optionally the paths under `~` whose files `after/` shows in full (`FILES`, by default the shell startup files), the paths outside `~` to compare (`ROOT_FILES`), a command to run after installing (`AFTER_INSTALL`), and a command to run `install.sh` under (`RUN_WITH`, e.g. `dbus-run-session --` for the session bus `dconf load` needs).
- Next to it, `before/` holds a `home/` tree (for `~`) and a `root/` tree (for `/`), like the repo's own, copied into an otherwise empty home and into `/`.
- `after/` holds the results once `install.sh` and `AFTER_INSTALL` have run: `manifest`, one line for every entry under `~` (except `~/dotfiles`, but for the `.backup` where `install.sh` moves what it replaces) and under `ROOT_FILES`, with its type, mode, owner, symlink target and the start of its SHA-256; and `home/` and `root/` trees with every symlink the manifest lists, to show the layout the install leaves, and the regular files under `FILES`, `~/dotfiles/.backup` and `ROOT_FILES`, for readable diffs.
- Each manifest line starts with what the install did to the entry, against a manifest taken just before it (after `before/` is copied in): `new`, `changed` (ending with `(was ...)` and what it was), `kept` (there before and untouched, like the image's own files), or `removed`.
- Paths and symlink targets under `~` start with `~`, so a manifest doesn't depend on the image's user.
- Each git clone (zsh plugins, tmux plugins, tools repos) is one line with its remote, followed by its untracked and changed files, since its contents follow upstream; for the same reason the files the `claude` feature builds from the tools repos are listed without a hash.
- A symlink that doesn't resolve fails the case, as does a `FILES` path inside a symlinked directory (name the symlink instead).
- Each case runs in a fresh container from a copy of the checkout, and runs `install.sh` again at the end, which must change nothing anywhere under `~` or `ROOT_FILES`: the install is idempotent, and `AFTER_INSTALL` didn't undo any of it.

## Updating
After changing what an install writes, run `tests/fixtures.sh --update [name...]` to rewrite `after/`, and review the change with `git diff`.

## The SteamOS image
SteamOS has no container image, so `tests/images/steamos` stands in for it: the same Arch image (SteamOS is built on Arch) with KDE's kconfig tools for `--desktop_settings`, stand-ins for `udevadm`, `systemd-tmpfiles` and the parts of `systemctl` that need a running systemd, and a mock `steamos-update`. Like a real SteamOS update since 3.6, the mock moves every change to `/etc` that no keep list names into `/etc/previous` and restores the original, and it drops files added to `/usr`; its default keep list is reconstructed from a deck's (`tests/images/steamos/atomic-update-keep.conf`), and like SteamOS's its entries are globs. The `steamos-update` case runs it after installing the Framework 16 fixes (`udev`, `tmpfiles`, `hdmi_audio_fix`, `orei_switch`) and `gamescope_screenshot`, so it fails if an update would wipe anything `install.sh` put in `/etc`, while its `before/root/etc/dummy.conf` shows an unlisted file being wiped. The `steamos-update` case installs `light_sleep` too, and the `steamos-uninstall` case runs `--uninstall` twice and then `--reinstall` for the features that can be undone there, checking that their files are gone in between.

## What the images hold
Both images have neovim, starship and tmux installed so the features don't download them, so fixtures only need GitHub (zsh plugins, tpm, tools repos). Features that need a real desktop (pacman, systemd) or a download are left out of the cases.
