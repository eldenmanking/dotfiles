# Linstar's dotfiles
This repository contains configuration files for my Linux workspace, and `install.sh`, which links them into place and installs tools.

## Quick start
On a fresh machine, run the bootstrap on the `install` branch, which clones the repo to `~/dotfiles` and runs its `install.sh` (see [Installation](docs/installation.md)):
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/eldenmanking/dotfiles/install/install.sh)" -- --variant coder --all
```

In a checkout at `~/dotfiles`, `./install.sh --variant <name> --help` lists the features and `--all` installs the default ones.

## OS, Profile and Machine
An install is for an OS (`--os`), a profile (`--profile`), how the machine is used, and a machine (`--machine`), the hardware; a variant (`--variant`) names an OS and profile. Only these combinations exist (see [Installation](docs/installation.md#os-profile-and-machine)):

| OS | Profiles | Machines | Variants |
|---|---|---|---|
| `arch` | `desktop`, `minimal` | `generic`, `framework16` | `arch` (desktop) |
| `steamos` | `desktop`, `minimal` | `generic`, `framework16` | `steamos` (desktop) |
| `portable` | `minimal`, `workspace` | `generic` | `portable` (minimal), `coder` (workspace) |

## Contents
Using it:
- [Installation](docs/installation.md): `install.sh`'s options, the bootstrap, `--infer`, defaults and the download cache
- [Features](docs/features.md): what each feature does, by OS, GUI and machine
- [Migrations](docs/migrations.md): manual steps after pulling changes that leave stale files behind
- [Shell startup files](docs/shell.md): which files each shell reads, and how the config is split between them

Setting up a machine:
- [Installing Arch](docs/arch-install.md): the `arch-chroot` one-time install from the live ISO, and installing by hand
- [Arch setup notes](docs/arch-setup.md): NTFS, trash on data partitions, LaTeX, optional packages
- [SteamOS](docs/steamos-setup.md), [macOS](docs/mac-os-setup.md), [Windows](docs/windows-setup.md) and [WSL](docs/wsl-setup.md) setup
- [Bootloader](docs/bootloader.md): Ventoy for several bootable ISOs, VeraCrypt rescue disks
- Framework 16: [sleep battery drain](docs/framework16-sleep.md), [light sleep with an eGPU](docs/light-sleep.md), [OREI HDMI switch](docs/orei-switch.md)

Working on the repo:
- [Layout](docs/layout.md): every file in the repo and what it is for
- [Writing features](docs/writing-features.md): OSes, profiles, feature implementations, doc tags, systemd units
- [Testing](docs/testing.md): `make check`, fixtures and CI
- [Install database](docs/install-database.md) and [upstream sync](docs/upstream-sync.md): design proposals
