# Layout
The tree below shows the files in the repository and the role of each one. `make validate` checks that it lists exactly the files tracked by git (`tests/validation/layout_tree.py`).

```
. (~/dotfiles)
├── .claude                          ---
│   ├── CLAUDE.md                    --- Claude Code instructions for working in this repo
│   └── skills                       ---
│       ├── debug-steamos-vm         ---
│       │   └── SKILL.md             --- skill: diagnose the SteamOS test VM, with the causes already found
│       ├── test-in-steamos-vm       ---
│       │   └── SKILL.md             --- skill: test a dotfiles change on SteamOS in the steamos_vm VM
│       └── update-migrations        ---
│           └── SKILL.md             --- skill: add docs/migrations.md entries and fill in their commits after merging
├── .github                          ---
│   ├── dependabot.yml               --- keeps the workflows' pinned actions current
│   └── workflows                    ---
│       ├── ci.yml                   --- validate, lint, fixtures, and install tests on Arch Linux, Ubuntu and macOS (bash 3.2; skipped when nothing it tests changed)
│       └── install-branch.yml       --- points the install branch's bootstrap at each commit of main that passes CI
├── .gitignore                       ---
├── .shellcheckrc                    --- shellcheck settings for the repo
├── Makefile                         --- make validate, lint, test and check (see Testing)
├── README.md                        --- overview: quick start, the OS table and a table of contents for docs/
├── Sessionx.vim                     --- useful vim options for maintaining dotfiles
├── bootstrap                        ---
│   └── install.sh                   --- template of the install branch's install.sh, which clones main at one commit
├── docs                             ---
│   ├── features                     ---
│   │   ├── arch.md                  --- arch features
│   │   ├── claude.md                --- the claude feature: Claude Code config from the tools repos
│   │   ├── common.md                --- features for every OS
│   │   ├── framework16.md           --- Framework 16 and laptop fixes
│   │   ├── gamescope-screenshot.md  --- Gaming Mode screenshots from the keyboard
│   │   ├── gnome.md                 --- GNOME features on arch
│   │   ├── kde.md                   --- KDE features (desktop_settings on steamos)
│   │   ├── linux.md                 --- features for any Linux
│   │   ├── steamos.md               --- steamos features
│   │   ├── test-vms.md              --- the Arch install and SteamOS test VMs
│   │   └── webterm.md               --- a shell in the browser on localhost (ttyd, systemd socket activation)
│   ├── features.md                  --- what the features do, grouped by OS, GUI and machine, and their requirements table
│   ├── framework16-sleep.md         --- Framework 16 sleep battery drain diagnosis and fix
│   ├── install-database.md          --- design proposal: record what features install, to undo it and restore what it replaced
│   ├── installation.md              --- install.sh's options, the bootstrap and install branch, --infer, defaults, the download cache
│   ├── layout.md                    --- this tree: every tracked file and its role
│   ├── light-sleep.md               --- light sleep instead of suspend with an eGPU on the Framework 16 bay or on external power
│   ├── migrations.md                --- manual steps after pulling changes that leave stale files behind
│   ├── one-time-installs            --- installing and setting up an OS on a machine, once
│   │   ├── arch-install.md          --- installing Arch: the arch-chroot one-time install from the live ISO, and by hand
│   │   ├── arch-setup.md            --- notes on setting up an Arch desktop by hand (NTFS, trash, LaTeX, optional packages)
│   │   ├── bootloader.md            --- portable bootloader: Ventoy for several bootable ISOs, VeraCrypt rescue disks
│   │   ├── mac-os-setup.md          ---
│   │   ├── steamos-setup.md         --- SteamOS install, Steam settings, encryption and Windows VMs
│   │   ├── windows-setup.md         ---
│   │   └── wsl-setup.md             ---
│   ├── orei-switch.md               --- OREI HDMI switch sleep/wake handoff: findings and the orei_switch feature
│   ├── shell.md                     --- which startup files each shell reads, and how the shell config is split between them
│   ├── testing                      ---
│   │   ├── ci.md                    --- which checks run where, and the install branch
│   │   ├── fixtures.md              --- make fixtures: what installs do to existing files, in containers
│   │   ├── lint.md                  --- make lint: syntax, shellcheck, function docs, portability
│   │   ├── tests.md                 --- make test: install.sh in scratch homes
│   │   └── validation.md            --- make validate: the structure that must hold
│   ├── testing.md                   --- the kinds of checks, with a page for each in testing/
│   ├── upstream-sync.md             --- plan for rewriting and merging with the upstream repo this was forked from
│   └── writing-features.md          --- how OSes, profiles and features are defined, and what make validate checks
├── dump                             --- exported application settings; only dconf/ is loaded by --desktop_settings, the rest are imported by hand (see the --info output)
│   ├── dconf                        ---
│   │   └── arch.dconf               --- GNOME settings, written by --capture --desktop_settings from the keys DCONF_CAPTURE selects
│   ├── google-chrome                --- Google Chrome extension settings (manual import)
│   │   └── vimium.conf              --- configuration for chrome vimium extension
│   ├── insync                       --- Insync settings (manual import)
│   │   └── ignorerules              --- Insync ignore rules: paste into Account Settings > Ignore Rules
│   ├── keychron                     --- Keychron keyboard exports (manual import)
│   │   └── k3-ultra-8k-ansi.json    --- Keychron Launcher keymap export for the K3 Ultra 8K
│   ├── okular                       --- Okular settings (manual import)
│   │   └── default.shortcuts        --- Okular keyboard shortcut scheme: import under Configure Keyboard Shortcuts > Manage Schemes
│   ├── steamgrid                    --- Steam library artwork for the Chrome and Discord shortcuts (copied by --steamgrid)
│   │   ├── 2293441873_hero.png      --- Google Chrome hero (1920x620)
│   │   ├── 2293441873p.png          --- Google Chrome portrait capsule (600x900)
│   │   ├── 2333229111_hero.png      --- Discord hero (3840x1240)
│   │   └── 2333229111p.png          --- Discord portrait capsule (600x900)
│   ├── vscode                       --- Visual Studio Code settings (manual import)
│   │   └── keybindings.json         --- VS Code keybindings
│   └── windows                      --- Windows-only settings (manual import)
│       └── terminal                 --- Windows Terminal settings
│           └── settings.json        --- Windows Terminal settings.json (manual import)
├── home                             --- files linked into $HOME (home/X -> ~/X)
│   ├── .bash_profile                --- bash login interactive startup file
│   ├── .bashrc                      --- bash non-login interactive startup file
│   ├── .config                      ---
│   │   ├── alacritty                ---
│   │   │   └── alacritty.toml       --- alacritty terminal emulator configuration file
│   │   ├── git                      ---
│   │   │   └── ignore               --- default ignored git files
│   │   ├── kcminputrc               --- KDE input settings (keyboard repeat), merged by desktop_settings (not linked)
│   │   ├── kxkbrc                   --- KDE keyboard layout settings (no XKB options), merged by desktop_settings (not linked)
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
│   │   ├── powerdevilrc             --- KDE power settings (lid action on AC), merged by desktop_settings (not linked)
│   │   ├── sh                       ---
│   │   │   ├── aliases.sh           --- default shell aliases
│   │   │   ├── env.sh               ---
│   │   │   └── starship.sh          --- starts the starship prompt in bash or zsh
│   │   ├── starship.toml            ---
│   │   ├── webterm                  ---
│   │   │   └── env                  --- webterm settings (shell, font), linked on steamos and arch
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
│   │   │   ├── steamos-vm           --- starts, stops and repairs the SteamOS test VM (linked on steamos)
│   │   │   ├── vis                  --- resume or start an obsession session in cwd
│   │   │   ├── vm-usb               --- attaches USB devices to a running GNOME Boxes VM; see vm-usb --help (linked on steamos and arch)
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
│   │       ├── claude_save.sh       --- post-save hook resuming Claude panes on restore
│   │       ├── saferestore.sh       --- safe restore script for tmux resurrect
│   │       └── strategies           ---
│   │           └── nvim_obsession.s ---
│   ├── .tmux.conf                   --- tmux configuration file
│   ├── .vimrc                       --- Vim main configuration file (deprecated)
│   ├── .zprofile                    --- zshell login startup file
│   └── .zshrc                       --- zshell interactive startup file
├── install                          --- pieces of the install script (lib, features, os, profiles, variants)
├── install.sh                       --- dotfiles install script
├── root                             ---
│   ├── etc                          ---
│   │   ├── dotfiles                 ---
│   │   │   ├── bin                  ---
│   │   │   │   ├── light-sleep      --- suspends, or idles with the displays off with an eGPU or on external power (copied by light_sleep)
│   │   │   │   ├── orei-switch      --- hands an OREI HDMI switch to another input on sleep, back on wake (Framework 16; copied by orei_switch)
│   │   │   │   ├── sddm-xsetup      --- mirrors the boot login screen onto the projector (copied by orei_switch)
│   │   │   │   ├── sddm-xstop       --- redoes the VT switch to the session that the login screen's exit dropped (copied by orei_switch)
│   │   │   │   └── vpower-filter    --- copies vpower's state to /run/vpower for Steam, with a slow charger shown as connected (copied by quiet_slow_charger)
│   │   │   └── steamos-manager      ---
│   │   │       └── devices          ---
│   │   │           └── framework-lap--- the Framework 16's charge limit method, laid over steamos-manager's device files (copied by charge_limit)
│   │   ├── logid.cfg                --- logid configuration file for Logitech peripherals (copied by logiops)
│   │   ├── modprobe.d               ---
│   │   │   ├── framework-charge-cont--- lets cros_charge_control take over the Framework 16's charge limit (copied by charge_limit)
│   │   │   └── hid_apple.conf       --- NuPhy Air75 fix for function keys (copied by console)
│   │   ├── sddm.conf.d              ---
│   │   │   └── orei-switch.conf     --- runs sddm-xsetup and sddm-xstop for the X11 login screen (copied by orei_switch)
│   │   ├── systemd                  ---
│   │   │   ├── logind.conf.d        ---
│   │   │   │   └── lid.conf         --- don't suspend on lid close while on external power (copied by logind)
│   │   │   └── system               ---
│   │   │       ├── hdmi-audio-fix.se--- keeps the Framework 16 780M SoC clock up for HDMI audio (copied by hdmi_audio_fix)
│   │   │       ├── orei-switch-boot.--- re-enables the left ports and turns the projector on at boot (copied by orei_switch)
│   │   │       ├── orei-switch-power--- turns the projector off over CEC on poweroff (copied by orei_switch)
│   │   │       ├── orei-switch.servi--- runs orei-switch around sleep (copied by orei_switch)
│   │   │       ├── systemd-suspend.s--- light-sleep.conf: suspends through light-sleep (copied by light_sleep)
│   │   │       ├── usr-share-steamos--- puts the Framework 16's device file among steamos-manager's (copied by charge_limit)
│   │   │       ├── vpower-filter.ser--- runs vpower-filter alongside vpower (copied by quiet_slow_charger)
│   │   │       └── vpower.service.d --- vpower-filter.conf: vpower writes /run/vpower-raw and starts vpower-filter (copied by quiet_slow_charger)
│   │   ├── tmpfiles.d               ---
│   │   │   └── ec-no-wakeup.conf    --- stop the embedded controller (ACPI GPE 0x0B) from waking the laptop from s2idle (copied, not linked)
│   │   ├── udev                     ---
│   │   │   └── rules.d              ---
│   │   │       ├── 90-egpu-no-runpm.--- keep an eGPU on the Framework 16 expansion bay powered while idle: it is often lost waking from BACO (copied, not linked; see docs/light-sleep.md)
│   │   │       └── 90-touchpad-nowak--- stop I2C devices (Framework 16 touchpad) from waking the laptop (copied, not linked; candidate for removal, see docs/framework16-sleep.md)
│   │   ├── systemd                  ---
│   │   │   └── user                 ---
│   │   │       ├── gamescope-screens--- runs gamescope-screenshot --watch in Gaming Mode (copied by gamescope_screenshot)
│   │   │       ├── keyboard-rescan.p--- restarts the screenshot watch when input devices come or go (copied by gamescope_screenshot)
│   │   │       ├── keyboard-rescan.s--- the restart, after a 1 s pause (copied by gamescope_screenshot)
│   │   │       ├── webterm-ttyd.serv--- ttyd on a private UNIX socket (copied by webterm)
│   │   │       ├── webterm.service  --- systemd-socket-proxyd, exits when idle (copied by webterm)
│   │   │       └── webterm.socket   --- listens on 127.0.0.1:7681 (copied by webterm)
│   │   └── vconsole.conf            --- Linux virtual console configuration file (copied by console only where none exists)
│   └── usr                          ---
│       ├── local                    ---
│       │   └── bin                  ---
│       │       ├── cmus-reload      --- repopulates cmus library and playlists
│       │       └── colortest        --- prints 256 terminal colors
│       └── share                    ---
│           └── kbd                  ---
│               └── keymaps          ---
│                   └── us-caps.map  --- keymap for linux console remapping caps to escape (copied by console)
├── scripts                          ---
│   └── bootstrap.sh                 --- fills in bootstrap/install.sh's pin; --publish commits it to the install branch
└── tests                            --- behavior tests, plus lint and validation (see Testing)
    ├── fixtures                     --- before and after files of install.sh, one directory per case (see Testing)
    │   ├── arch-dconf               --- --desktop_settings loading the GNOME settings into an empty dconf, under a session bus
    │   ├── arch-existing-rc         --- arch install over an existing .bashrc, .bash_profile and .zshrc
    │   ├── portable-existing-rc     --- portable install over the same files
    │   ├── portable-old-markers     --- portable install over files with an older version's single-# section
    │   ├── steamos-existing-rc      --- steamos install over the same files
    │   ├── steamos-kde-config       --- --desktop_settings merging keyboard repeat, XKB options and the lid action into KDE config
    │   ├── steamos-steam            --- --steam replacing the Game Mode hotkeys in an existing localconfig.vdf
    │   ├── steamos-uninstall        --- --uninstall (twice) and --reinstall of the steamos features that can be undone in a container
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
    │   ├── function_docs.py         --- checks every function's doc comment: its Usage and Returns lines
    │   ├── lint.sh                  --- make lint: syntax, shellcheck, actionlint and TOML checks
    │   └── oti_commands.sh          --- make lint: bare state-changing commands in install/oti
    ├── validation                   ---
    │   ├── features.sh              --- checks feature docs, and that each OS and profile suits and orders its features
    │   ├── os_table.sh              --- checks the OS, Profile and Machine table against the code
    │   ├── layout_tree.py           --- checks this tree against the files tracked by git
    │   └── validate.sh              --- make validate: checkout name, layout tree, checksums, features
    ├── versions.env                 --- pinned versions and checksums of shellcheck and actionlint
    └── webterm_smoke.py             --- smoke test for the ttyd and socket proxy chain
```

Each OS lives in `install/os/`, each profile in `install/profiles/`, each variant in `install/variants/` and each feature in `install/features/`, and the files each OS and profile link are listed in `install/features/link.sh`. Files under `home/` are installed into `$HOME` and files under `root/` into `/`, at the same path: most are linked, while some are copied by the feature that needs them (e.g. udev rules, which are read before an encrypted home is mounted, or systemd units). Paths under `root/` are linked one file at a time, never as a whole directory, so a copied file can't get linked too; `make validate` checks this. Everything else at the top level stays in the repo.
