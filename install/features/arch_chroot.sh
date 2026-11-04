# Feature: install Arch Linux onto a disk from the live ISO (archiso), after
# https://gist.github.com/mjkstra/96ce7a5689d753e7a6bdd92cdc169bae: GPT with an EFI partition and btrfs (@ and @home
# subvolumes), GRUB with grub-btrfs boot entries for timeshift snapshots. The desktop is left to --variant arch, run
# as the new user after rebooting.

# Where the new system is mounted while it is installed.
ARCH_CHROOT_ROOT=/mnt
# Size of the EFI system partition, mounted at /efi so the kernels in /boot stay in the @ snapshots.
ARCH_CHROOT_EFI_SIZE=512MiB
ARCH_CHROOT_BTRFS_OPTIONS=compress=zstd
# The drop-ins copied into the new system, under root/.
ARCH_CHROOT_SYSTEM_FILES=(
  etc/systemd/system/grub-btrfsd.service.d/timeshift.conf
  etc/sudoers.d/wheel
)
# Services enabled in the new system.
ARCH_CHROOT_SERVICES=(NetworkManager systemd-timesyncd grub-btrfsd)

# Packages pacstrap installs, the guide's list. The CPU's microcode is added to them (see microcode_package).
ARCH_CHROOT_PACKAGES=(
  "base"                                                        # base system
  "base-devel"                                                  # makepkg and build tools (yay needs them)
  "linux"                                                       # kernel
  "linux-firmware"                                              # .
  "git"                                                         # install.sh
  "btrfs-progs"                                                 # btrfs tools
  "grub"                                                        # bootloader
  "efibootmgr"                                                  # grub-install on UEFI
  "grub-btrfs"                                                  # boot entries for btrfs snapshots
  "inotify-tools"                                               # grub-btrfsd watches for new snapshots
  "timeshift"                                                   # btrfs snapshots
  "vim"                                                         # editor
  "networkmanager"                                              # network
  "pipewire"                                                    # audio
  "pipewire-alsa"                                               # .
  "pipewire-pulse"                                              # .
  "pipewire-jack"                                               # .
  "wireplumber"                                                 # pipewire session manager
  "reflector"                                                   # pacman mirror lists
  "zsh"                                                         # login shell of the new user
  "zsh-completions"                                             # .
  "zsh-autosuggestions"                                         # .
  "openssh"                                                     # ssh
  "man"                                                         # manual
  "sudo"                                                        # sudo for the wheel group
)

# --- Pure helpers ---

# Print partition $2 of disk $1: /dev/sda 1 -> /dev/sda1, /dev/nvme0n1 1 -> /dev/nvme0n1p1.
partition_path() {
  local disk="$1" n="$2"
  if [[ "$disk" =~ [0-9]$ ]]; then
    printf '%sp%s' "$disk" "$n"
  else
    printf '%s%s' "$disk" "$n"
  fi
}

# Print the microcode package for CPU vendor $1 (vendor_id in /proc/cpuinfo), or nothing for other vendors.
microcode_package() {
  case "$1" in
    AuthenticAMD) printf 'amd-ucode' ;;
    GenuineIntel) printf 'intel-ucode' ;;
  esac
}

# Print the sfdisk script for the layout: a GPT with an EFI system partition of $1, then a Linux partition with the
# rest of the disk.
partition_table() {
  printf 'label: gpt\nsize=%s, type=uefi\ntype=linux\n' "$1"
}

# Print /etc/hosts for hostname $1.
hosts_file() {
  printf '127.0.0.1 localhost\n::1 localhost\n127.0.1.1 %s\n' "$1"
}

# Return 0 if $1 is a valid hostname (lowercase, a single label).
valid_hostname() {
  [[ "$1" =~ ^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$ ]]
}

# Return 0 if $1 is a valid username for useradd.
valid_username() {
  [[ "$1" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]
}

# --- Inputs ---

# Print the value for setting $1 ($2 describes it): $3 if set (from the environment), else the answer to a prompt with
# default $4. Under --dry-run nothing is asked, and the default (or <$1> without one) stands in.
arch_chroot_value() {
  local name="$1" description="$2" given="$3" default="$4" reply
  if [[ -n "$given" ]]; then
    printf '%s' "$given"
  elif $DRY_RUN; then
    printf '%s' "${default:-<$name>}"
  else
    has_tty || error "no terminal to ask for the $description; set $name"
    read -p "$description${default:+ [$default]}: " -r reply < /dev/tty
    printf '%s' "${reply:-$default}"
  fi
}

# Error unless this is the live ISO, as root, booted in UEFI mode, on x86_64; under --dry-run, only warn.
arch_chroot_check_system() {
  local problems="" problem
  [[ "$(id -u)" == 0 ]] || problems+="must run as root; "
  [[ -d /run/archiso ]] || problems+="must run from the Arch Linux live ISO (no /run/archiso); "
  [[ -e /sys/firmware/efi/fw_platform_size ]] || problems+="must boot in UEFI mode; "
  [[ "$(uname -m)" == x86_64 ]] || problems+="must run on x86_64; "
  [[ -n "$problems" ]] || return 0
  problem="--arch_chroot ${problems%; }"
  if $DRY_RUN; then warn "$problem"; else error "$problem"; fi
}

# Error unless $1 is a whole disk with nothing on it mounted, then ask for it to be typed again before it is wiped.
arch_chroot_confirm_disk() {
  local disk="$1" reply
  $DRY_RUN && return 0
  [[ -b "$disk" && "$(lsblk -dno TYPE "$disk")" == disk ]] || error "$disk is not a disk; see lsblk"
  [[ -z "$(lsblk -nro MOUNTPOINTS "$disk" | tr -d '[:space:]')" ]] \
    || error "$disk is in use (something on it is mounted); is it the install medium?"
  lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MODEL "$disk"
  warn "Everything on $disk will be erased."
  read -p "Type $disk to erase it and install Arch Linux: " -r reply < /dev/tty
  [[ "$reply" == "$disk" ]] || error "not confirmed; nothing was changed"
}

# --- Steps ---

# Partition and format disk $1, then mount the new system's subvolumes and EFI partition at ARCH_CHROOT_ROOT.
arch_chroot_prepare_disk() {
  local disk="$1" efi root
  efi="$(partition_path "$disk" 1)"
  root="$(partition_path "$disk" 2)"
  if command -v mountpoint >/dev/null && mountpoint -q "$ARCH_CHROOT_ROOT"; then
    info "Unmounting $ARCH_CHROOT_ROOT, left from an earlier run..."
    run umount -R "$ARCH_CHROOT_ROOT"
  fi
  info "Partitioning $disk..."
  partition_table "$ARCH_CHROOT_EFI_SIZE" | run sfdisk --wipe always --wipe-partitions always "$disk"
  run udevadm settle
  info "Formatting $efi (EFI) and $root (btrfs)..."
  run mkfs.fat -F 32 -n EFI "$efi"
  run mkfs.btrfs -f -L arch "$root"
  run mount "$root" "$ARCH_CHROOT_ROOT"
  run btrfs subvolume create "$ARCH_CHROOT_ROOT/@"
  run btrfs subvolume create "$ARCH_CHROOT_ROOT/@home"
  run umount "$ARCH_CHROOT_ROOT"
  info "Mounting the new system at $ARCH_CHROOT_ROOT..."
  run mount -o "$ARCH_CHROOT_BTRFS_OPTIONS,subvol=@" "$root" "$ARCH_CHROOT_ROOT"
  run mount --mkdir -o "$ARCH_CHROOT_BTRFS_OPTIONS,subvol=@home" "$root" "$ARCH_CHROOT_ROOT/home"
  run mount --mkdir "$efi" "$ARCH_CHROOT_ROOT/efi"
}

# Run the remaining args as a command inside the new system.
in_chroot() {
  run arch-chroot "$ARCH_CHROOT_ROOT" "$@"
}

# Set time zone $1, locale $2, console keymap $3 and hostname $4 in the new system.
arch_chroot_localize() {
  local timezone="$1" locale="$2" keymap="$3" hostname="$4" root="$ARCH_CHROOT_ROOT"
  info "Setting the time zone ($timezone), locale ($locale), keymap ($keymap) and hostname ($hostname)..."
  in_chroot ln -sf "/usr/share/zoneinfo/$timezone" /etc/localtime
  in_chroot hwclock --systohc
  run sed -i "s/^#\(${locale//./\\.} \)/\1/" "$root/etc/locale.gen"
  in_chroot locale-gen
  printf 'LANG=%s\n' "$locale" | write_file "$root/etc/locale.conf"
  printf 'KEYMAP=%s\n' "$keymap" | write_file "$root/etc/vconsole.conf"
  printf '%s\n' "$hostname" | write_file "$root/etc/hostname"
  hosts_file "$hostname" | write_file "$root/etc/hosts"
}

# Create user $1 (in wheel, with zsh) and set the root and user passwords, asking again after a mistyped one.
arch_chroot_users() {
  local user="$1" account
  if [[ -d "$ARCH_CHROOT_ROOT/home/$user" ]] && grep -q "^$user:" "$ARCH_CHROOT_ROOT/etc/passwd" 2>/dev/null; then
    info "User $user already exists"
  else
    info "Creating user $user..."
    in_chroot useradd -m -G wheel -s /bin/zsh "$user"
  fi
  for account in root "$user"; do
    info "Set the password for $account:"
    until run_tty arch-chroot "$ARCH_CHROOT_ROOT" passwd "$account"; do
      warn "Password not set; try again."
    done
  done
}

# Copy ARCH_CHROOT_SYSTEM_FILES into the new system, then check the sudoers drop-in.
arch_chroot_system_files() {
  local file mode
  for file in "${ARCH_CHROOT_SYSTEM_FILES[@]}"; do
    mode=644
    [[ "$file" != etc/sudoers.d/* ]] || mode=440
    run install -Dvm "$mode" "$DOTFILES_ROOT/root/$file" "$ARCH_CHROOT_ROOT/$file"
  done
  in_chroot visudo -cf /etc/sudoers.d/wheel
}

# Install GRUB to the EFI partition and write its config (which picks up the microcode).
arch_chroot_bootloader() {
  info "Installing GRUB..."
  in_chroot grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=GRUB
  in_chroot grub-mkconfig -o /boot/grub/grub.cfg
}

# Copy this checkout into user $1's home in the new system, for --variant arch after rebooting.
arch_chroot_copy_dotfiles() {
  local user="$1" dest="$ARCH_CHROOT_ROOT/home/$1/dotfiles"
  if [[ -e "$dest" ]]; then
    info "$dest already exists"
  else
    info "Copying dotfiles to $dest..."
    run cp -a "$DOTFILES_ROOT/." "$dest"
  fi
  in_chroot chown -R "$user:$user" "/home/$user/dotfiles"
}

# Install Arch Linux onto a disk from the live ISO, after the mjkstra guide: GPT with EFI and btrfs (@, @home), the
# guide's packages, locale, user and GRUB with grub-btrfs. Asks for each of ARCH_CHROOT_DISK, ARCH_CHROOT_HOSTNAME,
# ARCH_CHROOT_USER, ARCH_CHROOT_TIMEZONE, ARCH_CHROOT_LOCALE and ARCH_CHROOT_KEYMAP not set, and for the passwords.
# Erases the disk after it is typed again, so each run is a fresh install.
#
# @machine any
# @os archiso
# @gui any
feature_arch_chroot() {
  local disk hostname user timezone locale keymap vendor="" microcode

  arch_chroot_check_system
  disk="$(arch_chroot_value ARCH_CHROOT_DISK "Disk to install onto (erased; see lsblk)" "${ARCH_CHROOT_DISK:-}" "")"
  hostname="$(arch_chroot_value ARCH_CHROOT_HOSTNAME "Hostname" "${ARCH_CHROOT_HOSTNAME:-}" arch)"
  user="$(arch_chroot_value ARCH_CHROOT_USER "Username" "${ARCH_CHROOT_USER:-}" "")"
  timezone="$(arch_chroot_value ARCH_CHROOT_TIMEZONE "Time zone (e.g. America/New_York)" "${ARCH_CHROOT_TIMEZONE:-}" UTC)"
  locale="$(arch_chroot_value ARCH_CHROOT_LOCALE "Locale" "${ARCH_CHROOT_LOCALE:-}" en_US.UTF-8)"
  keymap="$(arch_chroot_value ARCH_CHROOT_KEYMAP "Console keymap" "${ARCH_CHROOT_KEYMAP:-}" us)"
  if ! $DRY_RUN; then
    valid_hostname "$hostname" || error "invalid hostname '$hostname'"
    valid_username "$user" || error "invalid username '$user'"
    [[ -f "/usr/share/zoneinfo/$timezone" ]] || error "unknown time zone '$timezone' (see /usr/share/zoneinfo)"
    grep -q "^${locale//./\\.} " /usr/share/i18n/SUPPORTED || error "unknown locale '$locale' (see /usr/share/i18n/SUPPORTED)"
  fi

  [[ ! -r /proc/cpuinfo ]] || vendor="$(sed -n 's/^vendor_id[[:space:]]*: *//p' /proc/cpuinfo | head -1)"
  microcode="$(microcode_package "$vendor")"
  [[ -n "$microcode" ]] || warn "No microcode for CPU vendor '${vendor:-unknown}'; installing without it"

  arch_chroot_confirm_disk "$disk"
  run loadkeys "$keymap"
  run timedatectl set-ntp true
  arch_chroot_prepare_disk "$disk"

  info "Installing the base system (pacstrap)..."
  run pacstrap -K "$ARCH_CHROOT_ROOT" "${ARCH_CHROOT_PACKAGES[@]}" $microcode
  info "Writing $ARCH_CHROOT_ROOT/etc/fstab..."
  run_to_file "$ARCH_CHROOT_ROOT/etc/fstab" genfstab -U "$ARCH_CHROOT_ROOT"

  arch_chroot_localize "$timezone" "$locale" "$keymap" "$hostname"
  arch_chroot_users "$user"
  arch_chroot_system_files
  arch_chroot_bootloader
  in_chroot systemctl enable "${ARCH_CHROOT_SERVICES[@]}"
  arch_chroot_copy_dotfiles "$user"

  run umount -R "$ARCH_CHROOT_ROOT"
  info "Arch Linux is installed on $disk. Reboot, remove the install medium, log in as $user and run:"
  info "  ~/dotfiles/install.sh --variant arch --all"
}
