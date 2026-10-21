# Linstar's dotfiles
This repository contains configuration files for my linux workspace. The following shows a tree of the 'dotfiles' repository, along with details describing the role of each file.

```
. (~/dotfiles)
├── .claude                          ---
│   └── CLAUDE.md                    --- Claude Code instructions for working in this repo
├── .gitignore                       ---
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
└── steamos                          --- webterm and home-units (formerly the steamos-config repo)
    ├── .gitignore                   ---
    ├── LICENSE                      --- MIT license for this directory
    ├── README.md                    --- webterm and home-units documentation
    ├── bin                          ---
    │   ├── home-units-start         --- starts units in an encrypted home once dirlock unlocks it
    │   ├── webterm-index            --- builds ttyd's page with the tab-key script appended
    │   ├── webterm-shell            --- login shell ttyd runs for each connection
    │   └── webterm-ttyd             --- runs ttyd with the built page, if any
    ├── systemd                      ---
    │   ├── home-units.keep.conf     --- SteamOS keep list so home-units survives updates
    │   ├── home-units.service       --- system-wide user unit installed into /etc/systemd/user
    │   ├── webterm-ttyd.service.temp--- ttyd on a private UNIX socket
    │   ├── webterm.service.template --- systemd-socket-proxyd, exits when idle
    │   └── webterm.socket           --- listens on 127.0.0.1:3000
    ├── test                         ---
    │   └── smoke.py                 --- smoke test for the ttyd and socket proxy chain
    └── web                          ---
        └── tab-keys.html            --- passes browser tab shortcuts through xterm.js
```

## Installation
`install.sh` is the single entry point. Choose a platform with `--variant` (`coder`, `arch`, `steamos`, `portable`) and toggle features with flags; run `./install.sh --variant <name> --help` to list the features of a variant, and `--all` to enable all of them. With no arguments it prints usage. Features that can be undone also accept `--uninstall`, which removes them, and `--reinstall`, which removes then installs them again; both apply to every selected feature that supports them (listed by `--help`), and the rest are skipped or just installed. For example, `--distrobox --reinstall` asks before deleting the `arch` distrobox, then recreates and enters it. Each variant lives in `install/variants/`, each feature in `install/features/`, and the files each variant links are listed in `install/features/link.sh`. Files under `home/` are linked into `$HOME` and files under `root/` into `/`; everything else at the top level stays in the repo.

The repo must live at `~/dotfiles`. On a fresh machine, `install.sh` can be run straight from GitHub: when it isn't inside a checkout, it clones the repo to `~/dotfiles` (unless already there) and re-runs that copy with the same arguments. Set `DOTFILES_REPO` to clone a different URL and `DOTFILES_REF` to check out a branch or tag.
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/eldenmanking/dotfiles/main/install.sh)" -- --variant coder --all
```

The `steamos` variant installs everything per-user, since the SteamOS root filesystem is read-only. Its `webterm` feature serves a shell in the browser on localhost, started on demand by systemd; see [steamos/README.md](steamos/README.md) and [docs/steamos-setup.md](docs/steamos-setup.md).

Variants that don't symlink whole files (e.g. `coder`) instead write into a single `# Managed by dotfiles` ... `# /Managed by dotfiles` section of each managed file (`~/.profile`, `~/.zprofile`, `~/.bash_profile` if present, `~/.bashrc`, `~/.zshrc`, `~/git/.claude/CLAUDE.md`). Each feature owns a `# feature <name>` subblock inside it and rewrites only that subblock on re-run. Shell startup file subblocks only source files under `home/.config/sh` and `home/.config/zsh`, which the linked startup files (on `arch` and `steamos`) source too. Edit the files outside the section freely.

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
The `--claude` feature installs Claude Code configuration from one or more tools repos, by default just [eldenmanking/tools](https://github.com/eldenmanking/tools) cloned to `~/tools`. From each repo it inserts `claude/CLAUDE.md` into `~/git/.claude/CLAUDE.md` (all repos' files joined, in order, into its `# feature claude` subblock), symlinks each entry of `claude/skills` and `claude/scripts` into `~/.claude`, and deep-merges `claude/settings.json` into `~/.claude/settings.json`. Existing checkouts are fast-forwarded on each run.

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
