# Installing Arch
## One-time installs
`./install.sh --oti <name>` runs a one-time install from `install/oti/<name>.sh`: it sets up a machine once, such as installing Arch from its live ISO, rather than configuring the machine `install.sh` runs on. So it takes no `--variant`, OS, profile, machine or features, ignores the defaults from `install.conf`, and has no `--uninstall`, since what it does (like erasing a disk) can't be undone. `--help` lists the one-time installs. Each one:
 - asks all its questions up front, checks each answer, then shows a summary and asks once before changing anything, so the rest runs unattended;
 - prints every command it runs: `[run]` for changes, with input it feeds a command shown as a here-document (passwords masked) and files it writes shown as the `cat > file` that writes them, and `[check]` for the read-only commands that decide what to do. Under `--dry-run` the changes are printed as `[dry-run]` and not run, so a dry run lists exactly the commands a real run would;
 - is idempotent: each step checks what is done first, so running it again resumes where a run that stopped left off, and asks only what isn't settled yet.

How to write one is in [Writing features](writing-features.md#one-time-installs).

## Installing Arch from the live ISO
The `arch-chroot` one-time install puts Arch Linux on a blank disk from the live ISO, following mjkstra's [Modern Arch linux installation guide](https://gist.github.com/mjkstra/96ce7a5689d753e7a6bdd92cdc169bae) up to, not including, its automatic snapshot boot entries. Boot the ISO in UEFI mode (a Ventoy USB holding several ISOs works; see [bootloader.md](bootloader.md)), connect to the internet (`iwctl` for Wi-Fi), install `git` (the live ISO has none), then run the bootstrap, which clones the repo to `/root/dotfiles`:
```bash
pacman -Sy --noconfirm git
bash -c "$(curl -fsSL https://raw.githubusercontent.com/eldenmanking/dotfiles/install/install.sh)" -- --oti arch-chroot
```
It first checks that it runs as root on the live ISO, booted in UEFI mode, at a terminal and online. Then it asks, checking each answer against the live ISO, and skipping any set in the environment:

| Question | Environment | Default | Checked |
|---|---|---|---|
| Disk to install onto, or `partitions` | `DOTFILES_ARCH_DISK` | | `partitions`, or a whole disk with nothing mounted that isn't the live medium (found by the `archisosearchuuid` it booted with, since `copytoram` unmounts it) |
| With `partitions`: the EFI system partition | `DOTFILES_ARCH_EFI` | | an EFI system partition, FAT32 or unformatted, with nothing mounted |
| With `partitions`: the root partition | `DOTFILES_ARCH_ROOT` | | a partition with nothing mounted, not the EFI system partition |
| With `partitions`: the swap partition | `DOTFILES_ARCH_SWAP_PART` | `none` | `none`, or another partition with nothing mounted |
| Time zone | `DOTFILES_ARCH_TIMEZONE` | `America/New_York` | under `/usr/share/zoneinfo` |
| Locale | `DOTFILES_ARCH_LOCALE` | `en_US.UTF-8` | in `/usr/share/i18n/SUPPORTED` |
| Console keymap | `DOTFILES_ARCH_KEYMAP` | `us` | under `/usr/share/kbd/keymaps` |
| Hostname | `DOTFILES_ARCH_HOSTNAME` | `arch` | a valid host name |
| User name | `DOTFILES_ARCH_USER` | | a valid user name, not `root` |
| On a whole disk: swap file size in GiB | `DOTFILES_ARCH_SWAP_SIZE` | `0` (no swap) | a whole number, at most half the disk |
| root's and the user's passwords | | | typed twice, hidden |

It installs onto either:
 - **a whole disk**, which it erases: GPT with a 2G FAT32 EFI system partition (the guide uses 512M; the extra room is for another OS's boot loader and kernels when dual booting later) and btrfs on the rest (`wipefs`, `sfdisk`, `mkfs.fat`, `mkfs.btrfs`). Swap is an optional swap file at `/swap/swapfile`, made with `btrfs filesystem mkswapfile` in its own `@swap` subvolume (mounted at `/mnt/swap`) so snapshots of `@` leave it out;
 - **`partitions` you prepared** beforehand (e.g. with `cfdisk`, in space freed beside Windows), for dual booting: an EFI system partition, usually the one Windows already uses, which is kept as it is when it is FAT32 and only formatted when it has no filesystem; a root partition, formatted btrfs; and an optional swap partition, formatted with `mkswap` and added to fstab by UUID. Nothing else on the disk is touched. GRUB is installed beside the other OS's boot loader (in `EFI/GRUB`), `os-prober` is installed and enabled in `/etc/default/grub` so GRUB's menu lists the other OS, and the removable fallback path is left to whichever OS owns it. os-prober often finds nothing from the live ISO's chroot, so if GRUB's menu lacks the other OS, run `sudo grub-mkconfig -o /boot/grub/grub.cfg` once the new system is up.

Hibernation isn't set up either way. A value from the environment that fails its check stops the install. It then shows the disk or partitions, what happens to each (`ERASED`, `FORMATTED` or `kept`), the disks' current partitions and every answer, and asks once before running, unattended:
 - the disk: what is marked above, then the `@` and `@home` subvolumes (and `@swap` for a swap file), mounted with `compress=zstd` at `/mnt` and `/mnt/home`, and the EFI system partition at `/mnt/efi` (not `/boot`, so the kernels stay in `@` and its snapshots);
 - the guide's packages with `pacstrap` (with `neovim` instead of `vim`, `amd-ucode` or `intel-ucode` for the CPU, and `os-prober` when dual booting), then `/mnt/etc/fstab` from `genfstab -U`, plus the swap's line;
 - from `arch-chroot`: the time zone and hardware clock, the locale, keymap, hostname and `/etc/hosts`, the passwords (with `chpasswd`), the user in `wheel` with sudo (a drop-in, `/etc/sudoers.d/wheel`, checked with `visudo -c`), GRUB on the EFI system partition (on a whole disk also at the removable fallback path `/EFI/BOOT/BOOTX64.EFI`, for firmware that forgets its boot entries), and NetworkManager and `systemd-timesyncd` enabled (what the guide's `timedatectl set-ntp true` after the reboot does);
 - the repo, at the commit the bootstrap cloned, into the new user's `~/dotfiles`, so after `umount -R /mnt`, a reboot and logging in, `~/dotfiles/install.sh --variant arch --all` sets up the rest.

Run it again after it stops partway and it resumes: it reads the partitions and settings an earlier run left in `/mnt` instead of asking, asks "Resume the install?" instead of erasing a disk or root partition that already has the layout, creates subvolumes and installs packages that are missing, and skips what is done. On SteamOS, the `steamos_arch_vm` feature makes a VM for trying it out ([Arch install test VM](features/test-vms.md#arch-install-test-vm)).

## Manual installation
To install Arch with this repo's choices, see [Installing Arch from the live ISO](#installing-arch-from-the-live-iso). To setup a new computer, install Arch Linux using the [installation guide](https://wiki.archlinux.org/title/installation_guide), or use the `archinstall` utility available in live ISO's. Useful packages to install while chroot'ed using the live ISO include:
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
