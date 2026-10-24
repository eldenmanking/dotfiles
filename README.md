# Linstar's dotfiles
This repository contains configuration files for my linux workspace. The following shows a tree of the 'dotfiles' repository, along with details describing the role of each file.

```
. (~/dotfiles)
├── .claude                          ---
│   └── CLAUDE.md                    --- Claude Code instructions for working in this repo
├── .github                          ---
│   ├── dependabot.yml               --- keeps the workflows' pinned actions current
│   └── workflows                    ---
│       ├── ci.yml                   --- lint, and install tests on Arch Linux and Ubuntu
│       └── macos.yml                --- install tests on macOS (bash 3.2), when the files they test change
├── .gitignore                       ---
├── .shellcheckrc                    --- shellcheck settings for the repo
├── Makefile                         --- make validate, lint, test and check (see Testing)
├── README.md                        --- dotfiles overview
├── Sessionx.vim                     --- useful vim options for maintaining dotfiles
├── docs                             ---
│   ├── bootloader.md                ---
│   ├── framework16-sleep.md         --- Framework 16 sleep battery drain diagnosis and fix
│   ├── mac-os-setup.md              ---
│   ├── steamos-setup.md             --- SteamOS install, Steam settings, encryption and Windows VMs
│   ├── windows-setup.md             ---
│   └── wsl-setup.md                 ---
├── dump                             --- exported configuration settings
│   ├── dconf                        ---
│   │   └── arch.dconf               --- selected entries from 'dconf dump /' in Arch
│   ├── google-chrome                ---
│   │   └── vimium.conf              --- configuration for chrome vimium extension
│   ├── insync                       ---
│   │   └── ignorerules              ---
│   ├── okular                       ---
│   │   └── default.shortcuts        ---
│   ├── vscode                       ---
│   │   └── keybindings.json         ---
│   ├── wallpaper                    ---
│   │   └── GH2.jpg                  ---
│   └── windows                      ---
│       └── terminal                 ---
│           └── settings.json        ---
├── home                             --- files linked into $HOME (home/X -> ~/X)
│   ├── .bash_profile                --- bash login interactive startup file
│   ├── .bashrc                      --- bash non-login interactive startup file
│   ├── .config                      ---
│   │   ├── alacritty                ---
│   │   │   └── alacritty.toml       --- alacritty terminal emulator configuration file
│   │   ├── git                      ---
│   │   │   └── ignore               --- default ignored git files
│   │   ├── kcminputrc               --- KDE input settings (keyboard repeat), merged by the kde feature (not linked)
│   │   ├── nvim                     ---
│   │   │   ├── core                 ---
│   │   │   │   ├── autocommands.vim --- global autocommands
│   │   │   │   ├── commands.vim     --- global command and function definitions
│   │   │   │   ├── filetypes.vim    --- filetype specific settings and autocommands
│   │   │   │   ├── mappings.vim     --- 
│   │   │   │   ├── options.vim      ---
│   │   │   │   ├── plugins.vim      --- default neovim plugins and settings
│   │   │   │   └── plugmaps.vim     --- mappings for neovim plugins
│   │   │   └── init.vim             --- Neovim main configuration file (sources 'core')
│   │   ├── sh                       ---
│   │   │   ├── aliases.sh           --- default shell aliases
│   │   │   ├── env.sh               ---
│   │   │   └── starship.sh          --- starts the starship prompt in bash or zsh
│   │   ├── starship.toml            ---
│   │   ├── webterm                  ---
│   │   │   └── env                  --- webterm settings (shell, font), linked on steamos
│   │   ├── yapf                     ---
│   │   │   └── style                --- yapf python formatter global configuration file
│   │   └── zsh                      ---
│   │       ├── external.zsh         --- setup for external packages (e.g. opam)
│   │       ├── keybindings.zsh      --- default zsh keybindings
│   │       ├── plugins.zsh          --- loads zsh plugins from ~/.zsh/plugins or /usr/share/zsh/plugins
│   │       └── settings.zsh         ---
│   ├── .ideavimrc                   ---
│   ├── .local                       ---
│   │   ├── bin                      ---
│   │   │   ├── clip                 ---
│   │   │   ├── squidpdf             --- pdf splitter for Squid notes
│   │   │   ├── vis                  --- resume or start an obsession session in cwd
│   │   │   └── vm-usb               ---
│   │   └── share                    ---
│   │       ├── applications         ---
│   │       │   └── Alacritty.deskto --- custom launch settings for Wayland
│   │       └── backgrounds          ---
│   │           └── GH2.jpg          --- placeholder background
│   ├── .ocamlformat                 ---
│   ├── .profile                     --- sh-compatible login startup file
│   ├── .pylintrc                    --- pylint global configuration file
│   ├── .tmux                        ---
│   │   └── resurrect                ---
│   │       ├── saferestore.sh       --- safe restore script for tmux resurrect
│   │       └── strategies           ---
│   │           └── nvim_obsession.s ---
│   ├── .tmux.conf                   --- tmux configuration file
│   ├── .vimrc                       --- Vim main configuration file (deprecated)
│   ├── .zprofile                    --- zshell login startup file
│   └── .zshrc                       --- zshell interactive startup file
├── install                          --- pieces of the install script (lib, features, variants)
├── install.sh                       --- dotfiles install script
├── root                             ---
│   ├── etc                          ---
│   │   ├── logid.cfg                --- logid configuration file for Logitech peripherals
│   │   ├── modprobe.d               ---
│   │   │   └── hid_apple.conf       --- NuPhy Air75 fix for function keys
│   │   ├── systemd                  ---
│   │   │   └── system               ---
│   │   │       ├── auto-suspend.serv--- laptop auto-suspend service to prevent death
│   │   │       └── auto-suspend.time--- auto-suspend timer to check if battery is low
│   │   ├── tmpfiles.d               ---
│   │   │   └── ec-no-wakeup.conf    --- stop the embedded controller (ACPI GPE 0x0B) from waking the laptop from s2idle (copied, not linked)
│   │   ├── udev                     ---
│   │   │   └── rules.d              ---
│   │   │       └── 90-touchpad-nowak--- stop I2C devices (Framework 16 touchpad) from waking the laptop (copied, not linked; candidate for removal, see docs/framework16-sleep.md)
│   │   └── vconsole.conf            --- Linux virtual console configuration file
│   └── usr                          ---
│       ├── local                    ---
│       │   └── bin                  ---
│       │       ├── auto-suspend     --- suspends computer if battery is low
│       │       ├── cmus-reload      --- repopulates cmus library and playlists
│       │       └── colortest        --- prints 256 terminal colors
│       └── share                    ---
│           └── kbd                  ---
│               └── keymaps          ---
│                   └── us-caps.map  --- keymap for linux console remapping caps to escape
├── scripts                          ---
│   └── pin.sh                       --- make pin: writes the repo and commit install.sh's bootstrap clones
├── steamos                          --- webterm and home-units (formerly the steamos-config repo)
│   ├── .gitignore                   ---
│   ├── LICENSE                      --- MIT license for this directory
│   ├── README.md                    --- webterm and home-units documentation
│   ├── bin                          ---
│   │   ├── home-units-start         --- starts units in an encrypted home once dirlock unlocks it
│   │   ├── webterm-index            --- builds ttyd's page with the tab-key script appended
│   │   ├── webterm-shell            --- login shell ttyd runs for each connection
│   │   └── webterm-ttyd             --- runs ttyd with the built page, if any
│   ├── systemd                      ---
│   │   ├── hdmi-audio-fix.service   --- keeps the Framework 16 780M SoC clock up for HDMI audio, installed into /etc/systemd/system
│   │   ├── home-units.service       --- system-wide user unit installed into /etc/systemd/user
│   │   ├── webterm-ttyd.service.temp--- ttyd on a private UNIX socket
│   │   ├── webterm.service.template --- systemd-socket-proxyd, exits when idle
│   │   └── webterm.socket           --- listens on 127.0.0.1:3000
│   └── web                          ---
│       └── tab-keys.html            --- passes browser tab shortcuts through xterm.js
└── tests                            --- behavior tests, plus lint and validation (see Testing)
    ├── fixtures                     --- before and after files of install.sh, one directory per case (see Testing)
    │   ├── arch-existing-rc         --- arch install over an existing .bashrc, .bash_profile and .zshrc
    │   ├── portable-existing-rc     --- portable install over the same files
    │   ├── portable-old-markers     --- portable install over files with an older version's single-# section
    │   ├── steamos-existing-rc      --- steamos install over the same files
    │   ├── steamos-kde-config       --- --kde merging keyboard repeat into an existing kcminputrc
    │   └── steamos-update           --- steamos install with the Framework 16 fixes surviving a (mock) SteamOS update
    ├── fixtures.sh                  --- make fixtures: runs each fixture in its container image and compares after/
    ├── images                       --- container images for the fixtures
    │   ├── arch                     ---
    │   │   └── Dockerfile           --- Arch Linux, pinned to the same image and snapshot as CI
    │   └── steamos                  ---
    │       ├── Dockerfile           --- SteamOS stand-in: the Arch image with KDE's kconfig, a deck user and the mocks below
    │       ├── atomic-update-keep.conf--- stand-in for SteamOS's default keep list of /etc files
    │       ├── bin                  --- stand-ins for udevadm, systemd-tmpfiles, dirlock and systemctl
    │       ├── example-additional-keep-list.conf---
    │       └── steamos-update       --- mock SteamOS update: resets /etc but for keep lists, drops new /usr files
    ├── install.sh                   --- make test: install.sh in scratch homes: --dry-run, rootless installs, idempotency
    ├── lib.sh                       --- shared helpers, including the pinned tool downloader
    ├── lint                         ---
    │   └── lint.sh                  --- make lint: syntax, shellcheck, actionlint and TOML checks
    ├── validation                   ---
    │   ├── features.sh              --- checks feature docs, and that variants suit and order their features
    │   ├── pin.sh                   --- checks install.sh's pin block names this repo and a commit on main
    │   ├── readme_tree.py           --- checks this tree against the files tracked by git
    │   └── validate.sh              --- make validate: checkout name, README tree, checksums, features, pin
    ├── versions.env                 --- pinned versions and checksums of shellcheck and actionlint
    └── webterm_smoke.py             --- smoke test for the ttyd and socket proxy chain
```

## Installation
`install.sh` is the single entry point. Choose a platform with `--variant` (`coder`, `arch`, `steamos`, `portable`) and toggle features with flags; run `./install.sh --variant <name> --help` to list the features of a variant, and `--all` to enable all of its default ones. Optional features (listed under "Optional" in `--help`, e.g. `--printer` on `arch`) are skipped by `--all` and run only when named. With no arguments it prints usage, unless defaults are set (see [Defaults](#defaults)). Features that can be undone also accept `--uninstall`, which removes them, and `--reinstall`, which removes then installs them again; both apply to every selected feature that supports them (listed by `--help`), and the rest are skipped or just installed. For example, `--distrobox --reinstall` asks before deleting the `arch` distrobox, then recreates and enters it. Each variant lives in `install/variants/`, each feature in `install/features/`, and the files each variant links are listed in `install/features/link.sh`. Files under `home/` are linked into `$HOME` and files under `root/` into `/`; everything else at the top level stays in the repo.

The repo must live at `~/dotfiles`, since everything `install.sh` links points there, and `install.sh` refuses to run from any other checkout. `~/dotfiles` may be a symlink, but the checkout itself must be a directory named `dotfiles`, which lint relies on. When run from a git checkout elsewhere (such as the one Coder clones to `~/.config/coderv2/dotfiles`) and `~/dotfiles` doesn't exist, `install.sh` clones that checkout's current commit to `~/dotfiles`, sets the clone's `origin` to the checkout's, and re-runs from the clone with the same arguments; uncommitted changes aren't copied. On a fresh machine, `install.sh` can be run straight from GitHub: when it isn't inside a checkout, it clones the repo to `~/dotfiles` (unless already there) and re-runs that copy with the same arguments. It clones the repo and commit pinned in its generated block (`PINNED_REPO` and `PINNED_COMMIT`), checking the commit out on the default branch so later pulls still work. Set `DOTFILES_REPO` to clone a different URL (at its default branch's tip) and `DOTFILES_REF` to check out a branch or tag instead.

The pin is generated: `make pin` writes this checkout's `origin` and the tip of `origin/main` (or `make pin COMMIT=<rev>`) into `install.sh`, and `make validate` fails unless the block is exactly what `make pin` writes, names the repo it runs in (in CI, the GitHub repo; locally, `origin`), and pins a commit that is an ancestor of `HEAD`. A file can't name the commit that adds it, so the pin always names a commit already on `main`: run `make pin` after merging and commit the result to move curl installs forward. A fork must run `make pin` once so that it pins itself.
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/eldenmanking/dotfiles/main/install.sh)" -- --variant coder --all
```

#### Defaults
To run `install.sh` without arguments (as Coder's dotfiles support does), set defaults in the environment or in `~/.config/dotfiles/install.conf`, which is sourced like a shell script (the environment wins; set `DOTFILES_INSTALL_CONFIG` to read a different file):
 - `DOTFILES_VARIANT`: the variant to use when `--variant` isn't given.
 - `DOTFILES_FEATURES`: the features to run when the command line names none, as a space-separated list of feature names, with `all` for `--all` (e.g. `all printer`). They are ignored under `--uninstall`, and when `--variant` names a different variant than `DOTFILES_VARIANT`.

```bash
# ~/.config/dotfiles/install.conf
DOTFILES_VARIANT=coder
DOTFILES_FEATURES=all
```

With that file, `./install.sh` runs `--variant coder --all`, `./install.sh --dry-run` previews it, `./install.sh --tmux` runs only `tmux` on `coder`, and `./install.sh --help` lists the `coder` options. In a Coder template, setting the two variables in the workspace agent's environment does the same without a file.

#### Feature Requirements
Each `feature_<name>` function has a doc comment directly above it: a brief description, a bare `#` line, then tags naming the machines, OS and GUI it works on and the features it requires (`@requires` is optional):

```bash
# Serve a shell in the browser on localhost: download ttyd and install systemd user units that start it on
# demand (see steamos/README.md).
#
# @machine any
# @os linux
# @gui any
# @requires link
feature_webterm() {
```

Each variant declares the `_os` and `_gui` it targets. `tests/validation/features.sh` (run by `make validate`) scans `install/features` for `feature_<name>` functions and fails if any lacks a `feature_description` entry, a description, the bare `#` line or the `@machine`, `@os` or `@gui` tag, has text after its tags, or uses a value outside the lists in `install/lib/features.sh`. It also checks that every feature in a variant suits the variant's OS and GUI and runs after the features it requires; `--help` lists each feature's requirements. Machines aren't checked against variants, since variants don't pick hardware: `services` assumes a laptop, and `udev`, `tmpfiles` and `hdmi_audio_fix` hold Framework 16 fixes. On SteamOS, the features that write into `/etc` outside what SteamOS's default keep list covers (`udev`, `tmpfiles` and `home_units`) also name those files in the keep list `/etc/atomic-update.conf.d/dotfiles.conf`, each in its own subblock, with `keep_across_steamos_updates`, so OS updates keep them. `hdmi_audio_fix` needs none: the default list keeps system services and their enablement links.

| Feature | Machine | OS | GUI | Requires |
|---|---|---|---|---|
| `pacman`, `terminal`, `printer`, `logiops` | any | arch | any | |
| `yay` | any | arch | gnome | |
| `font`, `manual`, `distrobox` | any | linux | any | |
| `link`, `info`, `shell`, `starship`, `zsh`, `gng`, `tre`, `claude`, `gitconfig` | any | any | any | |
| `services` | laptop | linux | any | `link` |
| `dconf` | any | linux | gnome | |
| `xdg` | any | linux | gnome | `pacman` |
| `tmux` | any | any | any | `link` |
| `binaries`, `neovim` | any | linux, macos | any | |
| `flatpak` | any | linux | desktop | |
| `udev`, `tmpfiles`, `hdmi_audio_fix` | framework16 | linux | any | |
| `steamos_xclip` | any | steamos | desktop | |
| `webterm` | any | linux | any | `link` |
| `home_units`, `steam` | any | steamos | any | |
| `kde` | any | linux | kde | |

`linux` covers `arch` and `steamos`; GUI `any` also works headless, and `desktop` needs some graphical session. The variants target: `arch` (arch, gnome), `steamos` (steamos, kde), `coder` (linux, no GUI) and `portable` (linux and macos, no GUI).

The `steamos` variant installs everything per-user, since the SteamOS root filesystem is read-only; its `neovim` feature, for example, downloads the release binary into `~/.local`. Its `kde` feature merges partial KDE config files such as `home/.config/kcminputrc` (keyboard repeat rate) into their `~/.config` counterparts key by key with `kwriteconfig6`, rather than linking them, since KDE rewrites its config files and would break symlinks; keys not in the repo file are left alone. Add more files to `KDE_CONFIG_FILES` in `install/features/kde.sh`. Its `steam` feature sets Game Mode settings such as the main menu and quick access hotkeys in each Steam user's `localconfig.vdf`, replacing only keys Steam already wrote and only while Steam is closed, since Steam rewrites that file on exit; add more to `STEAM_SETTINGS` in `install/features/steam.sh`. Its `webterm` feature serves a shell in the browser on localhost, started on demand by systemd; see [steamos/README.md](steamos/README.md) and [docs/steamos-setup.md](docs/steamos-setup.md). Its `hdmi_audio_fix` feature, a Framework 16 fix like `udev` and `tmpfiles`, installs `steamos/systemd/hdmi-audio-fix.service` into `/etc/systemd/system` (with sudo). At boot and after every resume it sets the 780M to the `manual` level and gives its SoC clock a 720 MHz floor (`pp_dpm_socclk` levels 2 to 7), leaving the graphics, memory and fabric clocks free. At idle `socclk` otherwise drops to 400 MHz and HDMI audio stutters; games aren't capped (PipeWire buffer settings don't help: it reports no underruns); `--uninstall` removes it and sets the level back to `auto`.

Variants that don't symlink whole files (e.g. `coder`) instead write into a single `## Managed by dotfiles` ... `## /Managed by dotfiles` section of each managed file (`~/.profile`, `~/.zprofile`, `~/.bash_profile` if present, `~/.bashrc`, `~/.zshrc`, `~/git/.claude/CLAUDE.md`, and on SteamOS the keep list `/etc/atomic-update.conf.d/dotfiles.conf`). Each feature owns a `## feature <name>` subblock inside it and rewrites only that subblock on re-run. The markers start with `##`, a comment in sh and in SteamOS keep lists alike; sections written with the older single-`#` markers are converted on the next run. Shell startup file subblocks only source files under `home/.config/sh` and `home/.config/zsh`, which the linked startup files (on `arch` and `steamos`) source too. Edit the files outside the section freely.

The `arch` variant is designed to work for Arch Linux (or other Arch-based distributions). Essential packages and applications can be installed using `./install.sh --variant arch` as a user. This variant attempts to setup the following:
 - yay
 - zshell (theme, completions, font)
 - tmux
 - Neovim
 - LaTeX
 - Gnome (desktop environment, display manager, theme)
 - dconf configuration
 - Audiovisual media viewers and basic editors
 - Insync
 - Logiops

A basic Arch installation along with `install.sh` requires ~15gb of drive space.

#### Arch Linux Installation
To setup a new computer, install Arch Linux using the [installation guide](https://wiki.archlinux.org/title/installation_guide), or use the `archinstall` utility available in live ISO's. Useful packages to install while chroot'ed using the live ISO include:
 - sudo
 - networkmanager
 - neovim
 - git
 - tmux
 - zsh
 - os-prober (for autodetecting other boot partitions with grub)
 - vi

You can install these with the command `pacman -S sudo networkmanager neovim git tmux zsh os-prober vi`. Remember to `systemctl enable NetworkManager.service` to enable NetworkManager. To enable os-prober, uncomment the following line in `/etc/default/grub`.
```
GRUB_DISABLE_OS_PROBER=false
```
Then mount the boot partitions which should be detected to `/mnt` and remake the grub configuration file with the command `grub-mkconfig -o /boot/grub/grub.cfg`. After rebooting, make a new user with the following command.
```bash
useradd -m -G wheel -s /bin/zsh *username*
```
To enable `sudo`, use the command `visudo` and uncomment `%wheel AL=(ALL:ALL) NOPASSWD: ALL`. You can login as a user with `su *username*` and set a password with `passwd`, or just with the command `login`. Then, clone dotfiles in the user home directory and run `install.sh` to setup a standard configuration. To enable the Gnome display manager, `systemctl enable gdm.service` and reboot. To disable system sounds in Gnome, go to "Settings > Sound" and zero the "System Sounds" option (if it is already zero, try increasing it and decreasing it).

#### Printer Installation
Included in the `install.sh` script are packages for HP printers--in particular, the `hplip` package is used to install drivers for specific HP printers, whereas `cups` and `system-config-printer` are more general. To install the drivers for a physically connected printer, execute `hp-setup -i` in the terminal (`-i` for CLI interactive mode) and follow the prompts. See this [Stack Exchange post](https://unix.stackexchange.com/questions/359531/installing-hp-printer-driver-for-arch-linux) for more information.

#### Claude Code
The `--claude` feature installs Claude Code configuration from one or more tools repos, by default just [eldenmanking/tools](https://github.com/eldenmanking/tools) cloned to `~/tools`. From each repo it inserts `claude/CLAUDE.md` into `~/git/.claude/CLAUDE.md` (all repos' files joined, in order, into its `## feature claude` subblock), symlinks each entry of `claude/skills` and `claude/scripts` into `~/.claude`, and deep-merges `claude/settings.json` into `~/.claude/settings.json`. Existing checkouts are fast-forwarded on each run.

Repos are listed in priority order. When two repos ship a skill or script with the same name, the earlier repo's is linked and the later one is skipped with a warning; when their settings disagree on a value, the earlier repo's value is kept (lists are unioned).

To choose the tools repos, set the following in the environment or in `~/.config/dotfiles/tools.conf` (the environment wins; set `DOTFILES_TOOLS_CONFIG` to read a different file):
 - `DOTFILES_TOOLS`: one repo per line as `<repo> [dir] [ref]`, where `repo` is a git URL, `dir` is the checkout location (default `~/<repo name>`, or `-` to keep the default while giving a ref) and `ref` is a branch or tag (default: the repo's default branch). Blank lines and `#` comments are ignored. A `dir` that exists but isn't a git checkout is used as-is. Each repo needs its own `dir`.

For a single repo, the older per-field variables still work and are used when `DOTFILES_TOOLS` is unset:
 - `DOTFILES_TOOLS_REPO`: git URL to clone (default `https://github.com/eldenmanking/tools.git`)
 - `DOTFILES_TOOLS_DIR`: checkout location (default `~/tools`)
 - `DOTFILES_TOOLS_REF`: branch or tag to check out (default: the repo's default branch)

```bash
# ~/.config/dotfiles/tools.conf
DOTFILES_TOOLS="
https://github.com/eldenmanking/tools.git            # ~/tools
git@github.com:someone/tools.git  ~/git/someone-tools  # same repo name, so give it its own dir
git@github.com:work/claude-config.git  -  stable       # ~/claude-config, on the stable branch
"
```

## Testing
Checks come in three kinds, each with a make target; `make check` runs all three. Fixtures (`make fixtures`) are a fourth, kept out of `make check` since they need docker and network access.

- **Validation** (`make validate`, `tests/validation/`) enforces the repo's structure, which has to keep holding as files are added, moved or removed: the checkout is a directory named `dotfiles`, the tree above matches the files tracked by git, `tests/versions.env` pins a SHA-256 for every tool on every platform, every feature is documented and suits the variants that use it (see Feature Requirements), and `install.sh` pins this repo at a commit on `main` (see Installation; CI's validate job checks out full history for this).
- **Lint** (`make lint`, `tests/lint/`) checks code quality: the syntax of every shell, zsh, Python and TOML file, shellcheck and actionlint. The shellcheck and actionlint versions are pinned in `tests/versions.env`; `make lint` downloads them into `~/.cache/dotfiles-test` on first use and refuses any download that doesn't match its pinned SHA-256.
- **Tests** (`make test`, `tests/install.sh`) check behavior, so changes don't break what already works. They run `install.sh` in scratch home directories, without touching your own: `--help` and `--dry-run` (plus `--reinstall` and `--uninstall`) for every variant, which must leave the home unchanged; a real `--link --gitconfig` install (plus `--shell` for managed variants) for every variant that only links under `$HOME`, which a second run must not change; and login and interactive bash and zsh loading the resulting startup files. Set `INSTALL_BASH` to test `install.sh` under another bash, e.g. `INSTALL_BASH=/bin/bash make test` for bash 3.2 on macOS. `tests/webterm_smoke.py` is a separate smoke test for webterm, run by hand.
- **Fixtures** (`make fixtures`, `tests/fixtures.sh`, needs docker) show and pin exactly what an install does to existing files. Each case in `tests/fixtures/<name>/` has a `case.sh` that names a container image from `tests/images/` (`IMAGE`) and the `install.sh` arguments (`ARGS`), and optionally the files to compare under `~` (`FILES`, by default the shell startup files) and outside it (`ROOT_FILES`), and a command to run after installing (`AFTER_INSTALL`). Next to it, `before/` and `after/` each hold a `home/` tree (for `~`) and a `root/` tree (for `/`), like the repo's own: `before/` is copied into an otherwise empty home and into `/`, and `after/` holds the compared files once `install.sh` and `AFTER_INSTALL` have run, with symlinks kept as symlinks and whatever `install.sh` moved into `~/dotfiles/.backup`. Each case runs in a fresh container from a copy of the checkout, and runs `install.sh` again at the end, which must change nothing: the install is idempotent, and `AFTER_INSTALL` didn't undo any of it. After changing what an install writes, run `tests/fixtures.sh --update [name...]` to rewrite `after/`, and review the change with `git diff`. SteamOS has no container image, so `tests/images/steamos` stands in for it: the same Arch image (SteamOS is built on Arch) with KDE's kconfig tools for `--kde`, stand-ins for `udevadm`, `systemd-tmpfiles`, `dirlock` (which reports an encrypted home, so `home_units` installs) and the parts of `systemctl` that need a running systemd, and a mock `steamos-update`. Like a real SteamOS update since 3.6, the mock moves every change to `/etc` that no keep list names into `/etc/previous` and restores the original, and it drops files added to `/usr`; its default keep list is reconstructed from a deck's (`tests/images/steamos/atomic-update-keep.conf`), and like SteamOS's its entries are globs. The `steamos-update` case runs it after installing the Framework 16 fixes (`udev`, `tmpfiles`, `hdmi_audio_fix`) and `home_units`, so it fails if an update would wipe anything `install.sh` put in `/etc`, while its `before/root/etc/dummy.conf` shows an unlisted file being wiped. Both images have neovim, starship and tmux installed so the features don't download them, so fixtures only need GitHub (zsh plugins, tpm, tools repos). Features that need a real desktop (pacman, systemd, dconf) are left out of the cases.

zsh and python3 checks are skipped with a warning when those are missing, except in CI. CI (`.github/workflows/`) runs `make validate`, `make lint` and `make fixtures` on Ubuntu, and `make test` on Arch Linux (in a container whose packages are pinned to an Arch Linux Archive snapshot), Ubuntu and macOS (only when the files it tests change). Actions are pinned to commit SHAs and kept current by Dependabot; container images, runner labels and `tests/versions.env` are bumped by hand.

## Manual Fixes
I try to avoid modifying plugin files directly, but the following have been changed to suit my needs. These changes are done automatically with the `install.sh` script.

 - **~/.tmux/plugins/tmux-resurrect/strategies/nvim_obsession.sh**: symlinked from `home/.tmux/resurrect/strategies` by `.tmux.conf`
   - Restores nvim with `vi -S` on its obsession session: the absolute `-S` path recorded by `vis`, otherwise `Session.vim` in the pane's cwd. The stock `session` strategy only checks the pane's cwd, which follows nvim's cwd (e.g. after `:CdToFile`), so it often restarted nvim without the session.
 - **/etc/bluetooth/main.conf**: `#Autoenable=false` changed to `Autoenable=true`
   - Allows bluetooth to start automatically on boot and after suspend. `main.conf` must be a normal file, rather than a symlink.

## Shell Startup Files
Which files a shell reads depends on whether it is a **login** shell (ssh, console login, the desktop session, tmux panes) and whether it is **interactive**:

 - bash login shells read the first of .bash_profile, .bash_login and .profile; interactive non-login bash shells read .bashrc
 - zsh login shells read .zprofile; interactive zsh shells (login or not) read .zshrc

Environment variables are inherited, so they only need setting at login; aliases, functions and shell settings are not, so every interactive shell needs them. The files are split accordingly:

 - `home/.config/sh/env.sh` holds environment variables. It is POSIX sh and safe to source more than once. The profiles (.profile, .bash_profile, .zprofile) source it, and so do the rc files, for interactive shells with no login shell above them (e.g. code-server terminals).
 - Everything else in `home/.config/sh` and `home/.config/zsh` is interactive-only and is sourced from .bashrc and .zshrc.
 - .bash_profile also sources .bashrc when interactive, since bash login shells don't read it on their own. Nothing else sources another startup file.

## Notes
#### Using NTFS Partitions with Gnome
See [here](https://wiki.archlinux.org/title/NTFS) for more information. Linux kernels &ge; 5.15 support NTFS partitions automatically, but to allow Gnome to handle mounting NTFS partitions manually, install the `ntfs-3g` package. With this package, ntfs partitions can be automatically mounted by using Gnome Disks to select the partition, "Edit mount options", and enable "Mount at System Startup".

#### Enabling Trash on Data Partitions
To enable the use of "move to trash" on secondary partitions, the user must have the proper permissions to the partition. To enable the proper permissions, add the flag `uid=XXXX` (where `XXXX` is the desired user id--usually 1000 for the first user; can be confirmed with `id` in the terminal) to the mount options of the secondary partition in the fstab file (this can also be done with Gnome Disks).

#### LaTeX
LaTeX works on Arch Linux with the `texlive-most` package group (and `biber` for biber support). Custom LaTeX `.sty` and `.cls` files can be provided by adding a `tex/latex` directory under `~/texmf` (see the [MiKTeX page](https://miktex.org/kb/tds) for more information).

#### Optional Packages
The following is a list of packages that are not included in the base installer script, but which you can also consider installing.
 - lilypond: a CLI sheet music typesetter.
 - visual-studio-code-bin (AUR): Microsoft VSCode for Arch (supports liveshare)
 - lmms: electronic music editor
