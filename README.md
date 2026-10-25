# Linstar's dotfiles
This repository contains configuration files for my linux workspace. The following shows a tree of the 'dotfiles' repository, along with details describing the role of each file.

```
. (~/dotfiles)
├── .claude                          ---
│   ├── CLAUDE.md                    --- Claude Code instructions for working in this repo
│   └── skills                       ---
│       └── update-migrations        ---
│           └── SKILL.md             --- skill: add docs/migrations.md entries and fill in their commits after merging
├── .github                          ---
│   ├── dependabot.yml               --- keeps the workflows' pinned actions current
│   └── workflows                    ---
│       ├── ci.yml                   --- lint, and install tests on Arch Linux and Ubuntu
│       ├── install-branch.yml       --- points the install branch's bootstrap at each commit of main that passes CI
│       └── macos.yml                --- install tests on macOS (bash 3.2), when the files they test change
├── .gitignore                       ---
├── .shellcheckrc                    --- shellcheck settings for the repo
├── Makefile                         --- make validate, lint, test and check (see Testing)
├── README.md                        --- dotfiles overview
├── Sessionx.vim                     --- useful vim options for maintaining dotfiles
├── bootstrap                        ---
│   └── install.sh                   --- template of the install branch's install.sh, which clones main at one commit
├── docs                             ---
│   ├── bootloader.md                ---
│   ├── framework16-sleep.md         --- Framework 16 sleep battery drain diagnosis and fix
│   ├── mac-os-setup.md              ---
│   ├── migrations.md                --- manual steps after pulling changes that leave stale files behind
│   ├── orei-switch.md               --- OREI HDMI switch sleep/wake handoff: findings and the orei_switch feature
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
│   │   │   ├── gamescope-screenshot --- saves a Gaming Mode screenshot to ~/Pictures/Screenshots; --watch takes one on Print Screen or Shift+Meta+4 (linked on steamos)
│   │   │   ├── squidpdf             --- pdf splitter for Squid notes
│   │   │   ├── vis                  --- resume or start an obsession session in cwd
│   │   │   ├── vm-usb               ---
│   │   │   ├── webterm-index        --- builds ttyd's page with the tab-key script appended
│   │   │   ├── webterm-shell        --- login shell ttyd runs for each connection
│   │   │   └── webterm-ttyd         --- runs ~/.local/bin/ttyd with the built page, if any
│   │   └── share                    ---
│   │       ├── applications         ---
│   │       │   └── Alacritty.deskto --- custom launch settings for Wayland
│   │       ├── backgrounds          ---
│   │       │   └── GH2.jpg          --- placeholder background
│   │       └── webterm              ---
│   │           └── tab-keys.html    --- passes browser tab shortcuts through xterm.js
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
│   │   ├── dotfiles                 ---
│   │   │   └── bin                  ---
│   │   │       ├── orei-switch      --- hands an OREI HDMI switch to another input on sleep, back on wake (Framework 16; copied by orei_switch)
│   │   │       └── sddm-xsetup      --- mirrors the boot login screen onto the projector (copied by orei_switch)
│   │   ├── logid.cfg                --- logid configuration file for Logitech peripherals
│   │   ├── modprobe.d               ---
│   │   │   └── hid_apple.conf       --- NuPhy Air75 fix for function keys
│   │   ├── sddm.conf.d              ---
│   │   │   └── orei-switch.conf     --- runs sddm-xsetup for the X11 login screen (copied by orei_switch)
│   │   ├── systemd                  ---
│   │   │   └── system               ---
│   │   │       ├── hdmi-audio-fix.se--- keeps the Framework 16 780M SoC clock up for HDMI audio (copied by hdmi_audio_fix)
│   │   │       ├── orei-switch-boot.--- re-enables the left ports and turns the projector on at boot (copied by orei_switch)
│   │   │       ├── orei-switch-power--- turns the projector off over CEC on poweroff (copied by orei_switch)
│   │   │       └── orei-switch.servi--- runs orei-switch around sleep (copied by orei_switch)
│   │   ├── tmpfiles.d               ---
│   │   │   └── ec-no-wakeup.conf    --- stop the embedded controller (ACPI GPE 0x0B) from waking the laptop from s2idle (copied, not linked)
│   │   ├── udev                     ---
│   │   │   └── rules.d              ---
│   │   │       └── 90-touchpad-nowak--- stop I2C devices (Framework 16 touchpad) from waking the laptop (copied, not linked; candidate for removal, see docs/framework16-sleep.md)
│   │   ├── systemd                  ---
│   │   │   └── user                 ---
│   │   │       ├── gamescope-screens--- runs gamescope-screenshot --watch in Gaming Mode (copied by gamescope_screenshot)
│   │   │       ├── keyboard-rescan.p--- restarts the screenshot watch when input devices come or go (copied by gamescope_screenshot)
│   │   │       ├── keyboard-rescan.s--- the restart, after a 1 s pause (copied by gamescope_screenshot)
│   │   │       ├── webterm-ttyd.serv--- ttyd on a private UNIX socket (copied by webterm)
│   │   │       ├── webterm.service  --- systemd-socket-proxyd, exits when idle (copied by webterm)
│   │   │       └── webterm.socket   --- listens on 127.0.0.1:3000 (copied by webterm)
│   │   └── vconsole.conf            --- Linux virtual console configuration file
│   └── usr                          ---
│       ├── local                    ---
│       │   └── bin                  ---
│       │       ├── cmus-reload      --- repopulates cmus library and playlists
│       │       └── colortest        --- prints 256 terminal colors
│       └── share                    ---
│           └── kbd                  ---
│               └── keymaps          ---
│                   └── us-caps.map  --- keymap for linux console remapping caps to escape
├── scripts                          ---
│   └── bootstrap.sh                 --- fills in bootstrap/install.sh's pin; --publish commits it to the install branch
└── tests                            --- behavior tests, plus lint and validation (see Testing)
    ├── fixtures                     --- before and after files of install.sh, one directory per case (see Testing)
    │   ├── arch-dconf               --- --dconf loading the GNOME settings into an empty dconf, under a session bus
    │   ├── arch-existing-rc         --- arch install over an existing .bashrc, .bash_profile and .zshrc
    │   ├── portable-existing-rc     --- portable install over the same files
    │   ├── portable-old-markers     --- portable install over files with an older version's single-# section
    │   ├── steamos-existing-rc      --- steamos install over the same files
    │   ├── steamos-kde-config       --- --kde merging keyboard repeat into an existing kcminputrc
    │   ├── steamos-steam            --- --steam replacing the Game Mode hotkeys in an existing localconfig.vdf
    │   └── steamos-update           --- steamos install with the Framework 16 fixes surviving a (mock) SteamOS update
    ├── fixtures.sh                  --- make fixtures: runs each fixture in its container image and compares after/
    ├── images                       --- container images for the fixtures
    │   ├── arch                     ---
    │   │   └── Dockerfile           --- Arch Linux, pinned to the same image and snapshot as CI, with dconf and D-Bus
    │   └── steamos                  ---
    │       ├── Dockerfile           --- SteamOS stand-in: the Arch image with KDE's kconfig, a deck user and the mocks below
    │       ├── atomic-update-keep.conf--- stand-in for SteamOS's default keep list of /etc files
    │       ├── bin                  --- stand-ins for udevadm, systemd-tmpfiles and systemctl
    │       ├── example-additional-keep-list.conf---
    │       └── steamos-update       --- mock SteamOS update: resets /etc but for keep lists, drops new /usr files
    ├── install.sh                   --- make test: install.sh in scratch homes: --dry-run, rootless installs, idempotency
    ├── lib.sh                       --- shared helpers, including the pinned tool downloader
    ├── lint                         ---
    │   └── lint.sh                  --- make lint: syntax, shellcheck, actionlint and TOML checks
    ├── validation                   ---
    │   ├── features.sh              --- checks feature docs, and that variants suit and order their features
    │   ├── readme_tree.py           --- checks this tree against the files tracked by git
    │   └── validate.sh              --- make validate: checkout name, README tree, checksums, features
    ├── versions.env                 --- pinned versions and checksums of shellcheck and actionlint
    └── webterm_smoke.py             --- smoke test for the ttyd and socket proxy chain
```

## Installation
`install.sh` is the single entry point. Choose a platform with `--variant` (`coder`, `arch`, `steamos`, `portable`) and toggle features with flags; run `./install.sh --variant <name> --help` to list the features of a variant, and `--all` to enable all of its default ones. Optional features (listed under "Optional" in `--help`, e.g. `--printer` on `arch`) are skipped by `--all` and run only when named. With no arguments it prints usage, unless defaults are set (see [Defaults](#defaults)). Features that can be undone also accept `--uninstall`, which removes them, and `--reinstall`, which removes then installs them again; both apply to every selected feature that supports them (listed by `--help`), and the rest are skipped or just installed. For example, `--distrobox --reinstall` asks before deleting the `arch` distrobox, then recreates and enters it. Each variant lives in `install/variants/`, each feature in `install/features/`, and the files each variant links are listed in `install/features/link.sh`. Files under `home/` are installed into `$HOME` and files under `root/` into `/`, at the same path: most are linked, while some are copied by the feature that needs them (e.g. udev rules, which are read before an encrypted home is mounted, or systemd units). Paths under `root/` are linked one file at a time, never as a whole directory, so a copied file can't get linked too; `make validate` checks this. Everything else at the top level stays in the repo.

The repo must live at `~/dotfiles`, since everything `install.sh` links points there, and `install.sh` refuses to run from any other checkout. `~/dotfiles` may be a symlink, but the checkout itself must be a directory named `dotfiles`, which lint relies on. When run from a git checkout elsewhere (such as the one Coder clones to `~/.config/coderv2/dotfiles`) and `~/dotfiles` doesn't exist, `install.sh` clones that checkout's current commit to `~/dotfiles`, sets the clone's `origin` to the checkout's, and re-runs from the clone with the same arguments; uncommitted changes aren't copied. `install.sh` doesn't clean up after layout changes, so after pulling, follow [docs/migrations.md](docs/migrations.md) for any changes that left stale files behind (it is written so an agent can work through it). `install.sh` doesn't run on its own: it refuses without its `install/` directory beside it.

On a fresh machine, install from the `install` branch instead. It holds a single file, a bootstrap `install.sh` that names one commit of `main` (`PINNED_REPO` and `PINNED_COMMIT`): it clones the repo at that commit to `~/dotfiles`, on the default branch so later pulls still work, and runs the clone's `install.sh` with the same arguments. If `~/dotfiles` already exists, it runs that as it is. Each commit on the `install` branch pins exactly one commit of `main`, so a URL naming an `install` branch commit instead of `install` always installs the same version.

The bootstrap is generated from its template, `bootstrap/install.sh`, by `scripts/bootstrap.sh` (`scripts/bootstrap.sh --commit <rev>` prints it). After CI passes on a push to `main`, the install branch workflow (`.github/workflows/install-branch.yml`) runs `scripts/bootstrap.sh --publish install`, which commits a bootstrap pinning that commit onto the `install` branch; it never moves the branch to an older commit, and can also be run by hand from the Actions tab. If the `install` branch is protected, let `github-actions` bypass the rules that would block its push. A fork's workflow pins the fork itself, and creates its `install` branch on its first run.
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/eldenmanking/dotfiles/install/install.sh)" -- --variant coder --all
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

#### Download Cache
Features download their pinned binaries (ttyd, framework_tool, the Nerd Font) with `download_verified`, which checks each against its SHA-256. Set `DOTFILES_DOWNLOAD_CACHE` in the environment to a directory to reuse them: a file there named by the SHA-256 is used instead of downloading (and still checked), and each download is stored there. `make fixtures` shares one between its containers.

#### Feature Requirements
Each `feature_<name>` function has a doc comment directly above it: a brief description, a bare `#` line, then tags naming the machines, OS and GUI it works on and the features it requires (`@requires` is optional):

```bash
# Serve a shell in the browser on localhost: download ttyd and install systemd user units that start it on
# demand (see Webterm in README.md).
#
# @machine any
# @os linux
# @gui any
# @requires link
feature_webterm() {
```

Each variant declares the `_os` and `_gui` it targets. `tests/validation/features.sh` (run by `make validate`) scans `install/features` for `feature_<name>` functions and fails if any lacks a `feature_description` entry, a description, the bare `#` line or the `@machine`, `@os` or `@gui` tag, has text after its tags, or uses a value outside the lists in `install/lib/features.sh`. It also checks that every feature in a variant suits the variant's OS and GUI and runs after the features it requires; `--help` lists each feature's requirements. Machines aren't checked against variants, since variants don't pick hardware: `udev`, `tmpfiles` and `hdmi_audio_fix` hold Framework 16 fixes. On SteamOS, the features that write into `/etc` also name the files SteamOS's default keep list doesn't cover in the keep list `/etc/atomic-update.conf.d/dotfiles.conf`, each in its own subblock, with `keep_across_steamos_updates`, so OS updates keep them. It does nothing where `/etc/atomic-update.conf.d` doesn't exist, so features call it on every OS. The default list keeps system services, sockets and mounts with their enablement links, so `hdmi_audio_fix` has nothing to add, but it keeps nothing in `/etc/systemd/user`.

Features copy the systemd units they install, never link them, with the helpers in `install/lib/systemd.sh`. `install_system_units` copies units into `/etc/systemd/system`, then reenables and restarts those that changed (`--no-start` skips the restart); `install_user_units --global` or `--user` copies them into `/etc/systemd/user`, where every user manager sees them from boot even with an encrypted home, and reenables those that changed, for every user or just this one. Both only copy units without an `[Install]` section, which another unit starts. `uninstall_system_units` and `uninstall_user_units` undo them. `unit_keep_paths` lists what a feature must add to its keep list subblock: units in `/etc/systemd/user` with their enablement links, and in `/etc/systemd/system` only units that aren't services, sockets or mounts, such as timers. Scripts and binaries that system units or the login screen run go into `/etc/dotfiles/bin` (`root/etc/dotfiles/bin` in the repo), copied with `copy_system_file` (`install/lib/fs.sh`), since the home may still be locked when they run.

| Feature | Machine | OS | GUI | Requires |
|---|---|---|---|---|
| `pacman`, `terminal`, `printer`, `logiops` | any | arch | any | |
| `yay` | any | arch | gnome | |
| `font`, `services`, `manual`, `distrobox` | any | linux | any | |
| `link`, `info`, `shell`, `starship`, `zsh`, `gng`, `tre`, `claude`, `gitconfig` | any | any | any | |
| `dconf` | any | linux | gnome | |
| `xdg` | any | linux | gnome | `pacman` |
| `tmux` | any | any | any | `link` |
| `binaries`, `neovim` | any | linux, macos | any | |
| `flatpak` | any | linux | desktop | |
| `udev`, `tmpfiles`, `hdmi_audio_fix` | framework16 | linux | any | |
| `orei_switch` | framework16 | linux | any | |
| `steamos_xclip` | any | steamos | desktop | |
| `webterm` | any | linux | any | `link` |
| `steam` | any | steamos | any | |
| `gamescope_screenshot` | any | steamos | any | `link` |
| `kde` | any | linux | kde | |

`linux` covers `arch` and `steamos`; GUI `any` also works headless, and `desktop` needs some graphical session. The variants target: `arch` (arch, gnome), `steamos` (steamos, kde), `coder` (linux, no GUI) and `portable` (linux and macos, no GUI).

The `steamos` variant installs everything per-user, since the SteamOS root filesystem is read-only; its `neovim` feature, for example, downloads the release binary into `~/.local`. Its `kde` feature merges partial KDE config files such as `home/.config/kcminputrc` (keyboard repeat rate) into their `~/.config` counterparts key by key with `kwriteconfig6`, rather than linking them, since KDE rewrites its config files and would break symlinks; keys not in the repo file are left alone. Add more files to `KDE_CONFIG_FILES` in `install/features/kde.sh`. Its `steam` feature sets Game Mode settings such as the main menu and quick access hotkeys in each Steam user's `localconfig.vdf`, replacing only keys Steam already wrote and only while Steam is closed, since Steam rewrites that file on exit; add more to `STEAM_SETTINGS` in `install/features/steam.sh`. Its `orei_switch` feature, another Framework 16 fix, makes an OREI HDMI switch hand over to another input while the laptop sleeps; see [docs/orei-switch.md](docs/orei-switch.md). Its `webterm` feature serves a shell in the browser on localhost, started on demand by systemd from user units it copies into `/etc/systemd/user` and enables for all users (with sudo), so they start from boot even with an encrypted home; see [Webterm](#webterm) and [docs/steamos-setup.md](docs/steamos-setup.md). Its `gamescope_screenshot` feature takes Game Mode screenshots from the keyboard; see [Gaming Mode screenshots](#gaming-mode-screenshots). Its `hdmi_audio_fix` feature, a Framework 16 fix like `udev` and `tmpfiles`, copies `root/etc/systemd/system/hdmi-audio-fix.service` into `/etc/systemd/system` (with sudo). At boot and after every resume it sets the 780M to the `manual` level and gives its SoC clock a 720 MHz floor (`pp_dpm_socclk` levels 2 to 7), leaving the graphics, memory and fabric clocks free. At idle `socclk` otherwise drops to 400 MHz and HDMI audio stutters; games aren't capped (PipeWire buffer settings don't help: it reports no underruns); `--uninstall` removes it and sets the level back to `auto`.

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

#### Webterm
The `--webterm` feature (on `steamos`) gives you a real shell in the browser on localhost. It runs [ttyd](https://github.com/tsl0922/ttyd), a single static binary (about 1.3 MB) that serves an [xterm.js](https://xtermjs.org/) page and connects it to your shell. systemd starts it the first time you open the page and stops it once no browser has been connected for 30 s. There is nothing to compile and no Node, npm or Python needed, which is handy on SteamOS, where the root filesystem is read-only. The only files outside your home directory are the three units, which go into `/etc` with sudo.

```
browser ⇄ 127.0.0.1:3000 ──► webterm.socket            (always listening)
                              │ first connection starts
                              ▼
                             webterm.service          systemd-socket-proxyd
                              │ --exit-idle-time=30s
                              ▼ $XDG_RUNTIME_DIR/webterm.sock
                             webterm-ttyd.service     ttyd ⇄ pty ⇄ your shell
```

- **`webterm.socket`** listens on `127.0.0.1:3000`. It's the only part that runs all the time, and systemd itself does the listening.
- **`webterm.service`** runs `systemd-socket-proxyd`, which ships with systemd. ttyd can't take over a socket that systemd opened, so the proxy takes it and forwards each connection to ttyd. After 30 s with no open connections, the proxy exits. That covers both a closed tab and a page that never connected.
- **`webterm-ttyd.service`** runs ttyd on a UNIX socket in your private runtime directory, so other local users can't reach it. It has `StopWhenUnneeded=yes`, so it stops when the proxy exits. The socket keeps listening, so your next visit starts everything again.
- ttyd pings each browser every 10 s, so dead connections (a browser crash, a laptop suspend) get closed and the idle timer can run.

A backend is needed because a web page can't start processes; only a local program can start a shell and attach it to a terminal. It needs Linux with systemd (including `/usr/lib/systemd/systemd-socket-proxyd`), `curl` and `sha256sum`, on x86_64 or aarch64 (the CPU types ttyd publishes static builds for), all of which come with a stock SteamOS or Arch install; `tmux` is optional, to [keep work running](#keeping-work-with-tmux).

```sh
~/dotfiles/install.sh --variant steamos --link --font --webterm
~/dotfiles/install.sh --variant steamos --webterm   # just ttyd and the units
```

`--all` installs these along with the rest of the `steamos` variant. When it finishes, it prints your URL, which looks like `http://localhost:3000/<token>/`. Bookmark it; the token is explained in [Security](#security). To update, `git pull` in `~/dotfiles` and run the installer again, after the steps in [docs/migrations.md](docs/migrations.md) for any changes it pulled in. What gets installed:

- **Scripts and settings** (`--link`): `home/.local/bin/webterm-{index,shell,ttyd}`, `home/.local/share/webterm/tab-keys.html` and `home/.config/webterm/env` are linked into place.
- **Font** (`--font`): installs JetBrainsMono Nerd Font (Nerd Fonts v3.4.0) into `~/.local/share/fonts/JetBrainsMonoNerdFont/`, after checking its SHA-256. It does nothing if `fc-list` already lists the font.
- **ttyd and units** (`--webterm`): downloads ttyd 1.7.7 to `~/.local/bin/ttyd`, checks it against a pinned SHA-256, and copies the units in `root/etc/systemd/user/` into `/etc/systemd/user/` with sudo (copied, not linked: systemd treats symlinked unit files as "linked" units, which enable and disable handle differently). There the user manager sees them from boot, even with an [encrypted home](#encrypted-home-directory-dirlock). They are user units; `--webterm` enables them for every user with `systemctl --global enable`, so their links are in `/etc/systemd/user` too. On SteamOS it also names them in its own subblock of the keep list `/etc/atomic-update.conf.d/dotfiles.conf`, since updates otherwise drop everything in `/etc/systemd/user`.

`--dry-run` prints what would change. To remove webterm, including `~/.local/bin/ttyd`, the page in `~/.local/state/webterm` and (with sudo) the units in `/etc`:

```sh
~/dotfiles/install.sh --variant steamos --webterm --uninstall
```

Your URL token stays in `~/.config/webterm/token`.

##### Configuration
| Setting      | Where                                                         | Default            |
| ------------ | ------------------------------------------------------------- | ------------------ |
| Idle timeout | `WEBTERM_IDLE` in `webterm.service`                           | `30s`              |
| Shell        | `SHELL` in the env file                                       | `/usr/bin/zsh`     |
| Font         | `WEBTERM_FONT` in the env file                                | JetBrainsMono Nerd Font Mono |
| URL token    | `WEBTERM_TOKEN` in `~/.config/webterm/token`                  | random, 32 hex     |
| Port         | `ListenStream` in `root/etc/systemd/user/webterm.socket`      | `127.0.0.1:3000`   |

The env file, `~/.config/webterm/env`, is linked from `home/.config/webterm/env` by the `link` feature, so settings there are kept in git; run `--link` before `--webterm`, which needs it. The token gets its own unlinked file (mode 600), which `--webterm` creates if it's missing, so it never lands in the repo. Change the environment settings with a drop-in, for example `systemctl --user edit webterm.service` with `[Service] Environment=WEBTERM_IDLE=5min`. That drop-in lives in `~/.config/systemd/user/`, so with an encrypted home the user manager doesn't see it after a reboot until something reloads it (rerunning `--webterm` does); for one that holds from boot, use `sudo systemctl --global edit webterm.service`, and on SteamOS add it to a keep list too. To change the port, edit `root/etc/systemd/user/webterm.socket`.

After any change, run `~/dotfiles/install.sh --variant steamos --webterm` again. You don't need to close the browser. It copies the units that changed into `/etc/systemd/user` (so edits and a `git pull` take effect) and reloads systemd, then restarts the proxy and ttyd, but only if they're running; if they aren't, the next visit starts them with the new settings anyway. `~/.config/webterm/env` and `~/.config/webterm/token` are read again on every start, so changes there apply too. Open tabs show "Reconnecting..." and come back by themselves with the new settings (font, title and so on), without a page reload. Each tab gets a **fresh shell**, so anything running in a bare shell ends; tmux sessions survive (see [Keeping work with tmux](#keeping-work-with-tmux)). The exception is the token: after changing it, open the new URL, since tabs still on the old one can't reconnect.

##### Font
The terminal uses **JetBrainsMono Nerd Font Mono** by default. The Mono variant draws Nerd Font icons one cell wide, so prompts line up in the grid. ttyd's `-t key=value` passes any option straight to xterm.js, so the unit runs `-t "fontFamily=${WEBTERM_FONT}"`; no custom build is needed. The page only names the font: the browser draws it from fonts installed on the machine it runs on, which is the Deck here, so the `font` feature installs it. Flatpak browsers (the default on SteamOS) should also see `~/.local/share/fonts`. If the browser was already open when the font was installed, restart it; until then it uses the next font in the list.

To use a different font, change `WEBTERM_FONT` in `home/.config/webterm/env`, for example to `WEBTERM_FONT=JetBrainsMonoNL Nerd Font Mono, monospace`, then rerun `--webterm`; open tabs switch fonts when they reconnect. The value can be any CSS font list without an `=`. Run `fc-list : family | grep -i nerd` to see the exact names that are installed.

##### Browser tab shortcuts
xterm.js turns most Ctrl combos into terminal input and stops the browser from handling them. Chrome keeps some tab shortcuts for itself, but in fullscreen (F11) it lets the page handle every shortcut first, so the terminal would eat them. webterm hands these back to the browser: <kbd>Ctrl</kbd>+<kbd>Tab</kbd> and <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>Tab</kbd>, <kbd>Ctrl</kbd>+<kbd>1</kbd> to <kbd>Ctrl</kbd>+<kbd>9</kbd>, <kbd>Ctrl</kbd>+<kbd>PgUp</kbd> and <kbd>Ctrl</kbd>+<kbd>PgDn</kbd>, and <kbd>F11</kbd>, so it leaves fullscreen instead of reaching the shell. Every other key, like <kbd>Ctrl</kbd>+<kbd>W</kbd> or <kbd>Ctrl</kbd>+<kbd>R</kbd>, still goes to the shell.

- ttyd has no option for this, but `-I` serves a custom `index.html`. The repo keeps only the script to add, `home/.local/share/webterm/tab-keys.html`. It listens for keys before xterm.js does and stops them from reaching it, without cancelling the browser's own handling.
- The stock page bundles ttyd's browser client, which must match the ttyd binary. So `--webterm` runs `webterm-index`, which starts a throwaway ttyd on a temporary UNIX socket, fetches its page, appends the script and writes `~/.local/state/webterm/index-<sha256 of ~/.local/bin/ttyd>.html`.
- `webterm-ttyd.service` runs ttyd through `webterm-ttyd`, which hashes `~/.local/bin/ttyd` on every start and adds `-I` only if a page for that hash exists. If not, ttyd serves its stock page: the terminal works, but without the tab shortcuts in fullscreen. `journalctl --user -u webterm-ttyd.service` then shows a warning, and rerunning `--webterm` builds the page again.

After changing `tab-keys.html`, rerun `--webterm` and reload open tabs.

##### Encrypted home directory (dirlock)
With an encrypted home directory, the user manager (`systemd --user`) starts before dirlock unlocks the home, so for the rest of the boot it doesn't see anything in `~/.config/systemd/user`: units and enable links there are skipped. So webterm keeps both outside the home: `--webterm` copies its units into `/etc/systemd/user` and enables them with `sudo systemctl --global enable`, which links them in `/etc/systemd/user/sockets.target.wants/`. Every user manager sees those from boot, so `webterm.socket` listens as soon as you log in; after a reboot, `systemctl --user status webterm.socket` should be `active (listening)`. The services read `~/.config/webterm` and run scripts in `~/.local/bin` only when they start, so a visit before the home is unlocked fails, and the next one after works.

The socket is enabled for every user on the machine, so where several users log in, only the first gets port 3000. A unit you enable yourself with `systemctl --user enable` gets its link in `~/.config/systemd/user` and doesn't start after a reboot with an encrypted home; put its file in `/etc/systemd/user` and enable it with `sudo systemctl --global enable` instead, and on SteamOS name both in a keep list.

##### Security
**This is a full shell running as your user.** Anyone who can use the page can do anything you can.

- It only listens on `127.0.0.1`, and ttyd itself sits on a UNIX socket that only your user can open.
- ttyd's `-O` rejects WebSocket connections whose `Origin` doesn't match the page's own host.
- `-O` alone doesn't stop DNS rebinding, where a malicious site's domain resolves to 127.0.0.1 so the browser treats it as the same origin. That's what the random URL token is for. ttyd only serves the terminal under `/<token>/` and answers 404 everywhere else, so such a page can't find it. Keep the token private, like a password. Setting `WEBTERM_TOKEN=` (empty) in the token or env file turns this protection off.
- Don't expose it beyond localhost (port forwarding, reverse proxy, `0.0.0.0`) without real authentication and TLS. Authentication beyond the URL token, TLS and multi-user support are out of scope for now.

##### Keeping work with tmux
Bare shells are disposable: one ends when you close its tab, when webterm stops on idle, and when you rerun `--webterm`. To keep something running, start `tmux` in the terminal. The tmux server survives all three, and you reattach with `tmux attach` on your next visit. Everything started from webterm, including a tmux server, belongs to `webterm-ttyd.service`, and by default systemd kills all of a service's processes when it stops. The unit sets `KillMode=process`, so on stop systemd signals only ttyd, which hangs up its shells; tmux detaches and keeps running. When the service next starts, systemd logs a "left-over process" notice about the tmux server. That's expected.

##### Smoke test
`python3 tests/webterm_smoke.py` needs `~/.local/bin/ttyd`, which `--webterm` downloads, but no running systemd: `systemd-socket-activate` stands in for `webterm.socket`, and the real ttyd and `systemd-socket-proxyd` do the rest, running the scripts and `tab-keys.html` from this checkout. It checks that the page is only served under the token, a cross-origin WebSocket is rejected, the page is the stock page with `tab-keys.html` appended, a shell command round-trips, and the proxy exits once idle. It doesn't cover `webterm-ttyd.service` stopping with the proxy, because that step needs a real systemd. ttyd is MIT-licensed by its authors and is downloaded from its GitHub releases, not stored in this repo.

#### Gaming Mode screenshots
The `--gamescope_screenshot` feature (on `steamos`) saves a screenshot of Gaming Mode when you press **Print Screen** (the Framework 16's screenshot key) or **Shift+Meta+4** (macOS's Cmd+Shift+4, which a Keychron in Mac mode sends from its screenshot key) on any keyboard. Steam's own shortcut, Steam + R1, needs a controller, and its F12 key only works while Steam's window has focus. Gaming Mode has no other place to bind a key to a command: gamescope has no keybinding config (its `Super+S` only works when nested in a window), and no hotkey daemon ships with SteamOS.

- `gamescope-screenshot` (linked into `~/.local/bin`) runs `gamescopectl screenshot <path>`; gamescope writes the PNG to `~/Pictures/Screenshots/<date>_<time>.png` itself, and the script waits for it (gamescopectl exits 0 even when it can't reach gamescope) and plays the freedesktop shutter sound. Run it by hand, e.g. over ssh, for one screenshot; an optional argument picks gamescope's screenshot type (1, the focused app, the default; 2, with overlays; 3, every layer; 4, the screen buffer).
- `gamescope-screenshot --watch` runs `evtest` (in the base image) on each keyboard in `/dev/input/by-id/*-event-kbd`, line-buffered into one `awk` that runs the screenshot. `evtest` only reads and never grabs the devices, so games still get the keys, and logind gives the session's user access to them, so no `input` group is needed. With three keyboards it's 5 processes and about 14 MB, idle unless a key is pressed. It exits when a keyboard goes away, and systemd restarts it with the keyboards connected then.
- `gamescope-screenshot.service` runs the watch with `gamescope-session.target`, so only in Gaming Mode. `keyboard-rescan.path` watches `/dev/input/by-id` (systemd's inotify, so nothing polls) and starts `keyboard-rescan.service`, which waits 1 s for a new keyboard's links to settle and restarts the watch, so keyboards plugged in later are watched too.
- The units are copied into `/etc/systemd/user` and enabled with `systemctl --global enable` (with sudo), so the units and their links in `gamescope-session.target.wants` are all outside an encrypted home and the user manager sees them from boot. A `## feature gamescope_screenshot` subblock in the keep list `/etc/atomic-update.conf.d/dotfiles.conf` keeps them across SteamOS updates.

Screenshots land in `~/Pictures/Screenshots`, not in Steam's Media tab: Steam only imports screenshots it requested itself, and its client has no call to add one. `--uninstall` stops the watch and removes the units, their links and the keep-list subblock, and keeps the screenshots. `journalctl --user -u gamescope-screenshot.service` shows the keyboards it watches and each screenshot.

To check hotplug on the Framework 16 without touching a cable, cut the power to the right USB-C PD controller (`0`, ports 0 and 1, where the Keychron receiver is plugged in) with the `framework_tool` the `orei_switch` feature installs, then restore it. The watch restarts without the receiver, then again with it (`watching ... Keychron ...`); `framework_tool --pd-info` shows each controller's enabled ports:

```sh
sudo /etc/dotfiles/bin/framework_tool --pd-disable 0
sudo /etc/dotfiles/bin/framework_tool --pd-enable 0
journalctl --user -u gamescope-screenshot.service -u keyboard-rescan.service -n 20
```

## Testing
Checks come in three kinds, each with a make target; `make check` runs all three. Fixtures (`make fixtures`) are a fourth, kept out of `make check` since they need docker and network access.

- **Validation** (`make validate`, `tests/validation/`) enforces the repo's structure, which has to keep holding as files are added, moved or removed: the checkout is a directory named `dotfiles`, the tree above matches the files tracked by git, `tests/versions.env` pins a SHA-256 for every tool on every platform, every feature is documented and suits the variants that use it (see Feature Requirements), every link path exists, naming single files under `root/`, and `install.sh` pins this repo at a commit on `main` (see Installation; CI's validate job checks out full history for this).
- **Lint** (`make lint`, `tests/lint/`) checks code quality: the syntax of every shell, zsh, Python and TOML file, shellcheck and actionlint. The shellcheck and actionlint versions are pinned in `tests/versions.env`; `make lint` downloads them into `~/.cache/dotfiles-test` on first use and refuses any download that doesn't match its pinned SHA-256.
- **Tests** (`make test`, `tests/install.sh`) check behavior, so changes don't break what already works. They run `install.sh` in scratch home directories, without touching your own: `--help` and `--dry-run` (plus `--reinstall` and `--uninstall`) for every variant, which must leave the home unchanged; a real `--link --gitconfig` install (plus `--shell` for managed variants) for every variant that only links under `$HOME`, which a second run must not change; and login and interactive bash and zsh loading the resulting startup files. Set `INSTALL_BASH` to test `install.sh` under another bash, e.g. `INSTALL_BASH=/bin/bash make test` for bash 3.2 on macOS. `tests/webterm_smoke.py` is a separate smoke test for webterm, run by hand (see [Webterm](#smoke-test)).
- **Fixtures** (`make fixtures`, `tests/fixtures.sh`, needs docker) show and pin exactly what an install does to existing files. Each case in `tests/fixtures/<name>/` has a `case.sh` that names a container image from `tests/images/` (`IMAGE`) and the `install.sh` arguments (`ARGS`), and optionally the paths under `~` whose files `after/` shows in full (`FILES`, by default the shell startup files), the paths outside `~` to compare (`ROOT_FILES`), a command to run after installing (`AFTER_INSTALL`), and a command to run `install.sh` under (`RUN_WITH`, e.g. `dbus-run-session --` for the session bus `dconf load` needs). Next to it, `before/` holds a `home/` tree (for `~`) and a `root/` tree (for `/`), like the repo's own, copied into an otherwise empty home and into `/`. `after/` holds the results once `install.sh` and `AFTER_INSTALL` have run: `manifest`, one line for every entry under `~` (except `~/dotfiles`, but for the `.backup` where `install.sh` moves what it replaces) and under `ROOT_FILES`, with its type, mode, owner, symlink target and the start of its SHA-256; and `home/` and `root/` trees with every symlink the manifest lists, to show the layout the install leaves, and the regular files under `FILES`, `~/dotfiles/.backup` and `ROOT_FILES`, for readable diffs. Each manifest line starts with what the install did to the entry, against a manifest taken just before it (after `before/` is copied in): `new`, `changed` (ending with `(was ...)` and what it was), `kept` (there before and untouched, like the image's own files), or `removed`. Paths and symlink targets under `~` start with `~`, so a manifest doesn't depend on the image's user. Each git clone (zsh plugins, tmux plugins, tools repos) is one line with its remote, followed by its untracked and changed files, since its contents follow upstream; for the same reason the files the `claude` feature builds from the tools repos are listed without a hash. A symlink that doesn't resolve fails the case, as does a `FILES` path inside a symlinked directory (name the symlink instead). Each case runs in a fresh container from a copy of the checkout, and runs `install.sh` again at the end, which must change nothing anywhere under `~` or `ROOT_FILES`: the install is idempotent, and `AFTER_INSTALL` didn't undo any of it. After changing what an install writes, run `tests/fixtures.sh --update [name...]` to rewrite `after/`, and review the change with `git diff`. SteamOS has no container image, so `tests/images/steamos` stands in for it: the same Arch image (SteamOS is built on Arch) with KDE's kconfig tools for `--kde`, stand-ins for `udevadm`, `systemd-tmpfiles` and the parts of `systemctl` that need a running systemd, and a mock `steamos-update`. Like a real SteamOS update since 3.6, the mock moves every change to `/etc` that no keep list names into `/etc/previous` and restores the original, and it drops files added to `/usr`; its default keep list is reconstructed from a deck's (`tests/images/steamos/atomic-update-keep.conf`), and like SteamOS's its entries are globs. The `steamos-update` case runs it after installing the Framework 16 fixes (`udev`, `tmpfiles`, `hdmi_audio_fix`, `orei_switch`) and `gamescope_screenshot`, so it fails if an update would wipe anything `install.sh` put in `/etc`, while its `before/root/etc/dummy.conf` shows an unlisted file being wiped. Both images have neovim, starship and tmux installed so the features don't download them, so fixtures only need GitHub (zsh plugins, tpm, tools repos). Features that need a real desktop (pacman, systemd) or a download are left out of the cases.

zsh and python3 checks are skipped with a warning when those are missing, except in CI. CI (`.github/workflows/`) runs `make validate`, `make lint` and `make fixtures` on Ubuntu (and then points the `install` branch at the commit, see Installation), and `make test` on Arch Linux (in a container whose packages are pinned to an Arch Linux Archive snapshot), Ubuntu and macOS (only when the files it tests change). Actions are pinned to commit SHAs and kept current by Dependabot; container images, runner labels and `tests/versions.env` are bumped by hand.

## Manual Fixes
I try to avoid modifying plugin files directly, but the following have been changed to suit my needs. These changes are done automatically with the `install.sh` script.

 - **~/.tmux/plugins/tmux-resurrect/strategies/nvim_obsession.sh**: symlinked from `home/.tmux/resurrect/strategies` by `.tmux.conf`, which the `tmux` feature loads once after installing the plugins
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
