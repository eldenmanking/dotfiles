# Features: install Arch Linux from the live ISO onto a blank disk, following mjkstra's "Modern Arch linux installation
# guide" (https://gist.github.com/mjkstra/96ce7a5689d753e7a6bdd92cdc169bae) up to, not including, its automatic
# snapshot boot entries: a GPT disk with a 512M EFI system partition at /efi and a btrfs root with @ and @home
# subvolumes (zstd), the guide's packages, then the system set up from arch-chroot with GRUB. See Installing Arch from
# the live ISO in README.md.
#
# Settings come from the environment, and are asked for when unset (under --dry-run, placeholders are used instead):
#   DOTFILES_ARCH_DISK: the disk to install onto, e.g. /dev/vda (erased, after asking)
#   DOTFILES_ARCH_HOSTNAME, DOTFILES_ARCH_USER: the new system's hostname and user (in wheel, with sudo)
#   DOTFILES_ARCH_TIMEZONE (e.g. America/New_York), DOTFILES_ARCH_LOCALE (en_US.UTF-8), DOTFILES_ARCH_KEYMAP (us)

ARCHISO_ROOT=/mnt
ARCHISO_ESP_SIZE=512MiB
ARCHISO_MOUNT_OPTIONS="compress=zstd"
# The guide's packages, with neovim in place of vim; the CPU's microcode is added (see archiso_ucode).
ARCHISO_PACKAGES=(base base-devel linux linux-firmware git btrfs-progs grub efibootmgr grub-btrfs inotify-tools
  timeshift neovim networkmanager pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber reflector zsh
  zsh-completions zsh-autosuggestions openssh man sudo)
ARCHISO_SERVICES=(NetworkManager.service systemd-timesyncd.service)
ARCHISO_SUDOERS="/etc/sudoers.d/wheel"

# Print partition $2 of disk $1, as the kernel names it: a p goes between a disk name ending in a digit and the number
# (/dev/nvme0n1p1), and nothing otherwise (/dev/vda1).
archiso_partition() {
  local disk="$1" n="$2"
  case "$disk" in
    *[0-9]) printf '%sp%s' "$disk" "$n" ;;
    *)      printf '%s%s' "$disk" "$n" ;;
  esac
}

# Print the sfdisk script for the guide's layout: GPT, an EFI system partition, then Linux on the rest.
archiso_sfdisk_script() {
  printf '%s\n' "label: gpt" "size=$ARCHISO_ESP_SIZE, type=uefi" "type=linux"
}

# Print the microcode package for CPU vendor $1 (vendor_id in /proc/cpuinfo), or nothing for others.
archiso_ucode() {
  case "$1" in
    AuthenticAMD) echo amd-ucode ;;
    GenuineIntel) echo intel-ucode ;;
  esac
}

# Print /etc/hosts for hostname $1.
archiso_hosts() {
  printf '%s\n' "127.0.0.1 localhost" "::1 localhost" "127.0.1.1 $1"
}

# Print setting $1 (a variable name) from the environment, or else ask for it with prompt $2, offering default $3 when
# given. Under --dry-run nothing is asked: the default is used, or <$1> when there is none.
archiso_setting() {
  local name="$1" prompt="$2" default="${3:-}" value
  value="$(printenv "$name" || true)"
  if [[ -z "$value" ]] && $DRY_RUN; then
    value="${default:-<$name>}"
  fi
  while [[ -z "$value" ]]; do
    read -r -p "$prompt${default:+ [$default]}: " value < /dev/tty
    value="${value:-$default}"
  done
  printf '%s' "$value"
}

# Return 0 if this is the Arch live ISO, which is the only place these features may run: they erase a disk and write
# to $ARCHISO_ROOT. Warns otherwise. Under --dry-run, which changes nothing, it never refuses.
archiso_live() {
  if [[ -d /run/archiso ]] || $DRY_RUN; then
    return 0
  fi
  warn "Not running from the Arch live ISO (no /run/archiso), skipping."
  return 1
}

# Return 0 if $ARCHISO_ROOT holds the new system's root, warning otherwise.
archiso_root_mounted() {
  mountpoint -q "$ARCHISO_ROOT" && return 0
  $DRY_RUN && return 0
  warn "$ARCHISO_ROOT is not mounted (run --archiso_disk first), skipping."
  return 1
}

# Return 0 if the account $2 in shadow file $1 has a password set.
archiso_has_password() {
  local shadow="$1" user="$2" hash
  hash="$(awk -F: -v u="$user" '$1 == u { print $2 }' "$shadow" 2>/dev/null)"
  [[ -n "$hash" && "$hash" != "!"* && "$hash" != "*" ]]
}

# Mount the guide's layout from disk $1 at $ARCHISO_ROOT: the @ and @home subvolumes with compression, and the EFI
# system partition at /efi (not /boot, so the kernels stay in @ and its snapshots).
archiso_mount() {
  local disk="$1" esp root
  esp="$(archiso_partition "$disk" 1)"
  root="$(archiso_partition "$disk" 2)"
  mountpoint -q "$ARCHISO_ROOT" \
    || run mount -o "$ARCHISO_MOUNT_OPTIONS,subvol=@" "$root" "$ARCHISO_ROOT"
  run mkdir -p "$ARCHISO_ROOT/home" "$ARCHISO_ROOT/efi"
  mountpoint -q "$ARCHISO_ROOT/home" \
    || run mount -o "$ARCHISO_MOUNT_OPTIONS,subvol=@home" "$root" "$ARCHISO_ROOT/home"
  mountpoint -q "$ARCHISO_ROOT/efi" || run mount "$esp" "$ARCHISO_ROOT/efi"
}

# Partition and format disk $1 for the guide's layout, after asking, since it erases the disk: GPT with a FAT32 EFI
# system partition and a btrfs partition holding the @ and @home subvolumes.
archiso_format() {
  local disk="$1" esp root top
  esp="$(archiso_partition "$disk" 1)"
  root="$(archiso_partition "$disk" 2)"
  lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS "$disk" 2>/dev/null || true
  if $DRY_RUN; then
    info "[dry-run] would ask to erase $disk"
  elif ! has_tty || ! confirm "Erase $disk and install Arch Linux onto it?"; then
    warn "Leaving $disk as it is"
    return 1
  fi
  info "Partitioning $disk..."
  run wipefs --all "$disk"
  archiso_sfdisk_script | run sfdisk --quiet "$disk"
  run udevadm settle
  info "Formatting $esp (FAT32) and $root (btrfs)..."
  run mkfs.fat -F 32 "$esp"
  run mkfs.btrfs --force --quiet "$root"

  info "Creating the @ and @home subvolumes..."
  top="$(mktemp -d)"
  run mount "$root" "$top"
  run btrfs subvolume create "$top/@"
  run btrfs subvolume create "$top/@home"
  run umount "$top"
  rmdir "$top"
}

# Partition, format and mount a disk as the Arch install guide does: a 512M EFI system partition at /efi and a btrfs
# root with @ and @home subvolumes (zstd compression) at /mnt. Asks before erasing the disk; a disk already laid out
# that way is mounted without formatting.
#
# @machine any
# @os archiso
# @gui any
feature_archiso_disk() {
  local disk
  archiso_live || return 0
  if ! $DRY_RUN && [[ ! -e /sys/firmware/efi/fw_platform_size ]]; then
    warn "Not booted in UEFI mode, which this layout needs; skipping."
    return
  fi
  if mountpoint -q "$ARCHISO_ROOT"; then
    info "$ARCHISO_ROOT is already mounted"
    return
  fi
  $DRY_RUN || lsblk -d -o NAME,SIZE,MODEL,SERIAL,TYPE
  disk="$(archiso_setting DOTFILES_ARCH_DISK "Disk to erase and install onto (e.g. /dev/vda)")"
  if ! $DRY_RUN && [[ ! -b "$disk" ]]; then
    warn "$disk is not a block device, skipping."
    return
  fi
  if ! $DRY_RUN && lsblk -nro MOUNTPOINTS "$disk" | grep -q .; then
    warn "$disk has mounted partitions (is it the live medium?), skipping."
    return
  fi

  info "Turning on time synchronization..."
  run timedatectl set-ntp true

  if [[ "$(blkid -o value -s TYPE "$(archiso_partition "$disk" 1)" 2>/dev/null):$(blkid -o value -s TYPE \
      "$(archiso_partition "$disk" 2)" 2>/dev/null)" == vfat:btrfs ]]; then
    info "$disk already has an EFI system partition and a btrfs partition; mounting them without formatting"
  else
    archiso_format "$disk" || return 0
  fi
  archiso_mount "$disk"
}

# Install the guide's packages into /mnt with pacstrap (with the CPU's microcode), then write /mnt/etc/fstab from what
# is mounted there.
#
# @machine any
# @os archiso
# @gui any
# @requires archiso_disk
feature_archiso_pacstrap() {
  local ucode packages=("${ARCHISO_PACKAGES[@]}")
  archiso_live && archiso_root_mounted || return 0

  if [[ -x "$ARCHISO_ROOT/usr/bin/pacman" ]]; then
    info "$ARCHISO_ROOT already holds a system (use pacman inside it to add packages)"
  else
    ucode="$(archiso_ucode "$(awk -F': ' '/^vendor_id/ { print $2; exit }' /proc/cpuinfo 2>/dev/null)")"
    [[ -z "$ucode" ]] || packages+=("$ucode")
    # curl rather than ping, since some networks (and QEMU's user networking) drop ICMP.
    if ! $DRY_RUN && ! curl -fsS --max-time 10 -o /dev/null https://archlinux.org; then
      warn "archlinux.org is unreachable; connect to the internet (e.g. iwctl) first. Skipping."
      return
    fi
    info "Installing ${packages[*]} into $ARCHISO_ROOT..."
    run_tty pacstrap -K "$ARCHISO_ROOT" "${packages[@]}"
  fi

  info "Writing $ARCHISO_ROOT/etc/fstab..."
  if $DRY_RUN; then
    info "[dry-run] would write genfstab -U $ARCHISO_ROOT to $ARCHISO_ROOT/etc/fstab"
  else
    genfstab -U "$ARCHISO_ROOT" | write_file "$ARCHISO_ROOT/etc/fstab"
  fi
}

# Write file $1 under $ARCHISO_ROOT from stdin, unless it already holds exactly that.
archiso_write() {
  local path="$ARCHISO_ROOT$1" content
  content="$(cat)"
  if [[ -f "$path" && "$(cat "$path")" == "$content" ]]; then
    info "$1 is up to date"
    return
  fi
  info "Writing $1..."
  printf '%s\n' "$content" | write_file "$path"
}

# Set the password of user $1 in the new system, unless it has one.
archiso_password() {
  local user="$1"
  if archiso_has_password "$ARCHISO_ROOT/etc/shadow" "$user"; then
    info "$user already has a password"
    return
  fi
  info "Set the password for $user:"
  until run_tty arch-chroot "$ARCHISO_ROOT" passwd "$user"; do
    $DRY_RUN && break
    warn "Try again."
  done
}

# Set up the new system in /mnt from arch-chroot, as the guide does: time zone, locale, console keymap, hostname and
# hosts, the root password, a user in wheel with sudo, GRUB on the EFI system partition, and NetworkManager and time
# sync started at boot.
#
# @machine any
# @os archiso
# @gui any
# @requires archiso_pacstrap
feature_archiso_system() {
  local timezone locale keymap hostname user service
  archiso_live && archiso_root_mounted || return 0
  if ! $DRY_RUN && [[ ! -x "$ARCHISO_ROOT/usr/bin/pacman" ]]; then
    warn "$ARCHISO_ROOT holds no system (run --archiso_pacstrap first), skipping."
    return
  fi
  timezone="$(archiso_setting DOTFILES_ARCH_TIMEZONE "Time zone (under /usr/share/zoneinfo)" UTC)"
  locale="$(archiso_setting DOTFILES_ARCH_LOCALE "Locale" en_US.UTF-8)"
  keymap="$(archiso_setting DOTFILES_ARCH_KEYMAP "Console keymap" us)"
  hostname="$(archiso_setting DOTFILES_ARCH_HOSTNAME "Hostname" arch)"
  user="$(archiso_setting DOTFILES_ARCH_USER "User name")"

  if [[ "$(readlink "$ARCHISO_ROOT/etc/localtime" 2>/dev/null)" == "/usr/share/zoneinfo/$timezone" ]]; then
    info "Time zone is already $timezone"
  else
    info "Setting the time zone to $timezone..."
    run arch-chroot "$ARCHISO_ROOT" ln -sf "/usr/share/zoneinfo/$timezone" /etc/localtime
  fi
  run arch-chroot "$ARCHISO_ROOT" hwclock --systohc

  if grep -q "^$locale " "$ARCHISO_ROOT/etc/locale.gen" 2>/dev/null; then
    info "$locale is already in /etc/locale.gen"
  else
    info "Generating the $locale locale..."
    run sed -i "s/^#\\($locale \\)/\\1/" "$ARCHISO_ROOT/etc/locale.gen"
    run arch-chroot "$ARCHISO_ROOT" locale-gen
  fi
  archiso_write /etc/locale.conf <<< "LANG=$locale"
  archiso_write /etc/vconsole.conf <<< "KEYMAP=$keymap"
  archiso_write /etc/hostname <<< "$hostname"
  archiso_hosts "$hostname" | archiso_write /etc/hosts

  archiso_password root
  if grep -q "^$user:" "$ARCHISO_ROOT/etc/passwd" 2>/dev/null; then
    info "User $user already exists"
  else
    info "Adding user $user (in wheel)..."
    run arch-chroot "$ARCHISO_ROOT" useradd -m -G wheel "$user"
  fi
  archiso_password "$user"
  # A drop-in instead of uncommenting the wheel line in /etc/sudoers with visudo; visudo -c checks it the same way.
  archiso_write "$ARCHISO_SUDOERS" <<< "%wheel ALL=(ALL:ALL) ALL"
  run chmod 0440 "$ARCHISO_ROOT$ARCHISO_SUDOERS"
  run arch-chroot "$ARCHISO_ROOT" visudo -c -q -f "$ARCHISO_SUDOERS"

  if [[ -f "$ARCHISO_ROOT/efi/EFI/GRUB/grubx64.efi" ]]; then
    info "GRUB is already on the EFI system partition"
  else
    info "Installing GRUB..."
    run arch-chroot "$ARCHISO_ROOT" grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=GRUB
  fi
  info "Writing /boot/grub/grub.cfg..."
  run arch-chroot "$ARCHISO_ROOT" grub-mkconfig -o /boot/grub/grub.cfg

  for service in "${ARCHISO_SERVICES[@]}"; do
    run arch-chroot "$ARCHISO_ROOT" systemctl enable --quiet "$service"
  done
  info "Arch Linux is installed. Run 'umount -R $ARCHISO_ROOT', then reboot and remove the install medium."
}
