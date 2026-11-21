# Features for every OS

These run on every OS and profile (`@os any`), or on Linux and macOS alike.



## `link`
Symlinks the OS and profile's `link_paths` (`install/features/link.sh`): `home/` into `$HOME` and `root/` into `/` (with sudo). See [Layout](../layout.md) for what is linked and what is copied.

## `info`
Prints the settings in `dump/` that must be imported by hand.

Only `dump/dconf` is loaded by `--desktop_settings`; the other `dump/` directories (Insync, Okular, VS Code, Keychron, Chrome, Steam artwork, Windows Terminal) are manual imports, which `--info` lists.

## `shell`
Writes managed blocks into the profiles, `.bashrc` and `.zshrc` that source the shared config in `home/.config/sh` and `home/.config/zsh`; see [Shell startup files](../shell.md) and [Managed files](../features.md#managed-files).

## `starship`
Installs starship to `~/.local/bin` if missing and starts it from `.bashrc` and `.zshrc`.

## `zsh`
Clones popular zsh plugins into `~/.zsh/plugins` and sources `plugins.zsh` (which loads them) from `.zshrc`. It needs no package manager or root.

## `gitconfig`
Sets global git defaults (excludes file, pull, push and fetch behavior, credential store).

## `tmux`
Clones tpm and installs the tmux plugins listed in the linked `~/.tmux.conf`, then loads it once more so it can set up the plugins it installed. Requires `link`.

It also patches a plugin, which `.tmux.conf` sets up once the plugins are installed:

 - **~/.tmux/plugins/tmux-resurrect/strategies/nvim_obsession.sh**: symlinked from `home/.tmux/resurrect/strategies` by `.tmux.conf`, which the `tmux` feature loads once after installing the plugins
   - Restores nvim with `vi -S` on its obsession session: the absolute `-S` path recorded by `vis`, otherwise `Session.vim` in the pane's cwd. The stock `session` strategy only checks the pane's cwd, which follows nvim's cwd (e.g. after `:CdToFile`), so it often restarted nvim without the session.

## `binaries`
Installs neovim (prebuilt) and tmux (built from source) into `~/.local` when they aren't already on the `PATH`. Linux and macOS.

## `neovim`
Installs just neovim (prebuilt) into `~/.local`, for installs whose tmux comes from elsewhere (building it needs gcc). Linux and macOS.

## `gng`
Clones gng (a Gradle wrapper launcher, run as `gw`) at a pinned commit into `~/.local/gng` and runs its installer with sudo.

## `tre`
Builds tre (a `tree` alternative) from a pinned commit with cargo and installs it to `~/.local/bin`.

## `claude`
Installs Claude Code config (`CLAUDE.md`, skills, scripts and settings) from one or more tools repos; see [Claude Code](claude.md).
