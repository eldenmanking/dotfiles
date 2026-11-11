# One-time install: Arch Linux from the live ISO onto a blank disk, following mjkstra's "Modern Arch linux installation
# guide" (https://gist.github.com/mjkstra/96ce7a5689d753e7a6bdd92cdc169bae) up to, not including, its automatic
# snapshot boot entries: a GPT disk with an EFI system partition at /efi and a btrfs root with @ and @home
# subvolumes (zstd) and an optional swap file in @swap, the guide's packages, then the system set up from
# arch-chroot with GRUB. See Installing Arch from the live ISO in README.md.
#
# Every setting is asked for up front, and checked against the live ISO, unless set in the environment:
#   DOTFILES_ARCH_DISK: the disk to install onto, e.g. /dev/vda (erased unless an earlier run laid it out), or
#     partitions to install onto partitions prepared beforehand, e.g. beside Windows for dual booting:
#     DOTFILES_ARCH_EFI (an EFI system partition, kept when it's FAT32 already), DOTFILES_ARCH_ROOT (formatted btrfs)
#     and DOTFILES_ARCH_SWAP_PART (a swap partition, or none)
#   DOTFILES_ARCH_TIMEZONE (America/New_York), DOTFILES_ARCH_LOCALE (en_US.UTF-8), DOTFILES_ARCH_KEYMAP (us)
#   DOTFILES_ARCH_HOSTNAME (arch), DOTFILES_ARCH_USER: the new system's hostname and user (in wheel, with sudo)
#   DOTFILES_ARCH_SWAP_SIZE (0): on a whole disk, the swap file's size in GiB, 0 for no swap
# Passwords are always typed. Settings and passwords an earlier run left in /mnt aren't asked again.

ARCH_CHROOT_ROOT=/mnt
# Bigger than the guide's 512M, to leave room for another OS's boot loader and kernels when dual booting later.
ARCH_CHROOT_ESP_SIZE=2GiB
ARCH_CHROOT_MOUNT_OPTIONS="compress=zstd"
ARCH_CHROOT_SUBVOLUMES="@ @home"
# The swap file, in its own subvolume (@swap) so snapshots of @ leave it out.
ARCH_CHROOT_SWAP_DIR=/swap
ARCH_CHROOT_SWAPFILE=/swap/swapfile
# Where the top level of the btrfs filesystem is mounted to create subvolumes, apart from /mnt.
ARCH_CHROOT_TOP=/run/dotfiles-btrfs
# The guide's packages, with neovim in place of vim; the CPU's microcode is added (see arch_chroot_packages).
ARCH_CHROOT_PACKAGES="base base-devel linux linux-firmware git btrfs-progs grub efibootmgr grub-btrfs inotify-tools
  timeshift neovim networkmanager pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber reflector zsh
  zsh-completions zsh-autosuggestions openssh man sudo"
ARCH_CHROOT_SERVICES="NetworkManager.service systemd-timesyncd.service"
ARCH_CHROOT_SUDOERS=/etc/sudoers.d/wheel
# The GPT partition type of an EFI system partition.
ARCH_CHROOT_ESP_TYPE=c12a7328-f81f-11d2-ba4b-00a0c93ec93b
# What the live ISO has, to check answers against.
ARCH_CHROOT_ZONEINFO=/usr/share/zoneinfo
ARCH_CHROOT_LOCALES=/usr/share/i18n/SUPPORTED
ARCH_CHROOT_KEYMAPS=/usr/share/kbd/keymaps

# Returns description for --help.
oti_config_arch_chroot() {
  f_return \
    description="install Arch Linux from the live ISO onto a blank disk (btrfs, GRUB), asking everything up front"
}

# --- Pure helpers ---

# Print partition $2 of disk $1, as the kernel names it: a p goes between a disk name ending in a digit and the number
# (/dev/nvme0n1p1), and nothing otherwise (/dev/vda1).
arch_chroot_partition() {
  local disk="$1" n="$2"
  case "$disk" in
    *[0-9]) printf '%sp%s' "$disk" "$n" ;;
    *)      printf '%s%s' "$disk" "$n" ;;
  esac
}

# Print the sfdisk script for the guide's layout: GPT, an EFI system partition, then Linux on the rest.
arch_chroot_sfdisk_script() {
  printf '%s\n' "label: gpt" "size=$ARCH_CHROOT_ESP_SIZE, type=uefi" "type=linux"
}

# Print the packages to install for CPU vendor $1 (vendor_id in /proc/cpuinfo), with $2 true when dual booting: the
# guide's, the CPU's microcode, and os-prober to list the other OSes in GRUB.
arch_chroot_packages() {
  local vendor="$1" dual="$2" packages
  packages="$(printf '%s ' $ARCH_CHROOT_PACKAGES)"
  case "$vendor" in
    AuthenticAMD) packages+="amd-ucode " ;;
    GenuineIntel) packages+="intel-ucode " ;;
  esac
  [[ "$dual" != true ]] || packages+="os-prober "
  printf '%s' "${packages% }"
}

# Print /etc/hosts for hostname $1.
arch_chroot_hosts() {
  printf '%s\n' "127.0.0.1 localhost" "::1 localhost" "127.0.1.1 $1"
}

# Return 0 if the account $2 in shadow file $1 has a password set.
arch_chroot_has_password() {
  local shadow="$1" user="$2" hash
  hash="$(awk -F: -v u="$user" '$1 == u { print $2 }' "$shadow" 2>/dev/null)"
  [[ -n "$hash" && "$hash" != "!"* && "$hash" != "*" ]]
}

# Print the fstab line for swap $1: the swap file's path, or a swap partition's UUID=... .
arch_chroot_swap_fstab() {
  printf '%s none swap defaults 0 0\n' "$1"
}

# Return 0 if $1 is a swap file size in GiB, a whole number from 0 (no swap) up to $2.
arch_chroot_valid_swap_size() {
  [[ "$1" =~ ^(0|[1-9][0-9]*)$ ]] && (( $1 <= $2 ))
}

# Return 0 if $1 is a valid hostname label.
arch_chroot_valid_hostname() {
  [[ "$1" =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?$ ]]
}

# Return 0 if $1 is a valid new user name: lowercase, starting with a letter or _, at most 32 characters, not root.
arch_chroot_valid_user() {
  [[ "$1" =~ ^[a-z_][a-z0-9_-]{0,31}$ && "$1" != root ]]
}

# Return 0 if $1 names a time zone file under zoneinfo directory $2 (e.g. America/New_York).
arch_chroot_valid_timezone() {
  [[ "$1" != /* && "$1" != *..* && -f "$2/$1" ]]
}

# Return 0 if $1 is a locale listed in supported-locales file $2 (e.g. en_US.UTF-8).
arch_chroot_valid_locale() {
  awk -v l="$1" '$1 == l { found = 1 } END { exit !found }' "$2" 2>/dev/null
}

# Return 0 if $1 is a console keymap under keymaps directory $2 (e.g. us).
arch_chroot_valid_keymap() {
  [[ "$1" != */* && -n "$(find "$2" \( -name "$1.map.gz" -o -name "$1.map" \) 2>/dev/null | head -1)" ]]
}

# Print the blkid tag (UUID=... or LABEL=...) archiso found its medium by, from kernel command line $1; nothing when
# there is neither archisosearchuuid nor archisolabel.
arch_chroot_live_tag() {
  local word uuid="" label=""
  for word in $1; do
    case "$word" in
      archisosearchuuid=*) uuid="${word#*=}" ;;
      archisolabel=*) label="${word#*=}" ;;
    esac
  done
  if [[ -n "$uuid" ]]; then
    echo "UUID=$uuid"
  elif [[ -n "$label" ]]; then
    echo "LABEL=$label"
  fi
}

# --- Reading the live system ---

# Print the disk the live ISO booted from (e.g. /dev/sda), or nothing when it can't be found (e.g. PXE). Checking for
# mounts isn't enough: with copytoram, archiso copies the ISO into RAM and unmounts the medium.
arch_chroot_live_disk() {
  local tag dev parent
  tag="$(arch_chroot_live_tag "$(cat /proc/cmdline 2>/dev/null || true)")"
  [[ -n "$tag" ]] || return 0
  dev="$(blkid -t "$tag" -o device 2>/dev/null | head -1 || true)"
  [[ -n "$dev" ]] || return 0
  parent="$(lsblk -dno PKNAME "$dev" 2>/dev/null || true)"
  if [[ -n "$parent" ]]; then
    echo "/dev/$parent"
  else
    echo "$dev"
  fi
}

# Return 0 if $1 is partitions, or a whole disk that isn't the live medium $2 (none when empty) and has nothing on it
# mounted.
arch_chroot_valid_disk() {
  [[ "$1" == partitions ]] && return 0
  [[ -b "$1" && "$(lsblk -dno TYPE "$1" 2>/dev/null)" == disk && "$1" != "$2" ]] \
    && ! lsblk -nro MOUNTPOINTS "$1" | grep -q .
}

# Return 0 if $1 is a partition with nothing mounted and not on the live medium $2 (none when empty), of GPT type $3
# (any when empty), that isn't one of $4 (the partitions chosen already). With $5 true, it must not be an EFI system
# partition.
arch_chroot_valid_partition() {
  local part="$1" live="$2" type="$3" taken="$4" not_esp="${5:-false}" parttype
  [[ -b "$part" && "$(lsblk -dno TYPE "$part" 2>/dev/null)" == part ]] || return 1
  [[ -z "$live" || "/dev/$(lsblk -dno PKNAME "$part" 2>/dev/null)" != "$live" ]] || return 1
  ! lsblk -nro MOUNTPOINTS "$part" | grep -q . || return 1
  ! list_contains "$taken" "$part" || return 1
  parttype="$(lsblk -dno PARTTYPE "$part" 2>/dev/null)"
  [[ -z "$type" || "$parttype" == "$type" ]] || return 1
  [[ "$not_esp" != true || "$parttype" != "$ARCH_CHROOT_ESP_TYPE" ]]
}

# Return 0 if $1 is an EFI system partition to install GRUB on: nothing mounted, not on the live medium $2, and FAT32
# or not formatted yet.
arch_chroot_valid_esp() {
  local fstype
  arch_chroot_valid_partition "$1" "$2" "$ARCH_CHROOT_ESP_TYPE" "" || return 1
  fstype="$(lsblk -dno FSTYPE "$1" 2>/dev/null)"
  [[ -z "$fstype" || "$fstype" == vfat ]]
}

# Return 0 if $1 is a partition for the root filesystem, not on the live medium $2, apart from EFI system partition $3.
arch_chroot_valid_root() {
  arch_chroot_valid_partition "$1" "$2" "" "$3" true
}

# Return 0 if $1 is none or a partition for swap, not on the live medium $2, apart from the EFI system and root
# partitions $3 and $4.
arch_chroot_valid_swap_part() {
  [[ "$1" == none ]] || arch_chroot_valid_partition "$1" "$2" "" "$3 $4" true
}

# Return 0 if disk $1 has the guide's layout already: a FAT32 first partition and a btrfs second one.
arch_chroot_laid_out() {
  local disk="$1"
  [[ "$(probe blkid -o value -s TYPE "$(arch_chroot_partition "$disk" 1)" || true)" == vfat \
    && "$(probe blkid -o value -s TYPE "$(arch_chroot_partition "$disk" 2)" || true)" == btrfs ]]
}

# Outputs what an earlier run left in $ARCH_CHROOT_ROOT, each empty when it isn't there: root_part and esp (the
# partitions mounted at it and at its /efi), swap_part and swap_size (the swap partition, or none, and the swap
# file's size in GiB, 0 for none; settled once its fstab is written), timezone, locale, keymap, hostname and user
# (uid 1000); and root_password and user_password, true when set.
arch_chroot_installed() {
  local root="$ARCH_CHROOT_ROOT" root_part="" esp="" swap_part="" swap_size="" swap_uuid tz="" user="" root_pw=false
  local user_pw=false
  if mountpoint -q "$root" 2>/dev/null; then
    root_part="$(findmnt -no SOURCE "$root" 2>/dev/null || true)"
    root_part="${root_part%%\[*}"
    esp="$(findmnt -no SOURCE "$root/efi" 2>/dev/null || true)"
    if [[ -f "$root/etc/fstab" ]]; then
      swap_size=0
      swap_part=none
      swap_uuid="$(awk '$3 == "swap" && $1 ~ /^UUID=/ { sub(/^UUID=/, "", $1); print $1; exit }' "$root/etc/fstab")"
      [[ -z "$swap_uuid" ]] || swap_part="$(blkid -U "$swap_uuid" 2>/dev/null || echo none)"
    fi
  fi
  [[ ! -f "$root$ARCH_CHROOT_SWAPFILE" ]] \
    || swap_size="$(( $(stat -c %s "$root$ARCH_CHROOT_SWAPFILE") / 1073741824 ))"
  tz="$(readlink "$root/etc/localtime" 2>/dev/null || true)"
  [[ "$tz" == /usr/share/zoneinfo/* ]] && tz="${tz#/usr/share/zoneinfo/}" || tz=""
  user="$(awk -F: '$3 == 1000 { print $1; exit }' "$root/etc/passwd" 2>/dev/null || true)"
  ! arch_chroot_has_password "$root/etc/shadow" root || root_pw=true
  [[ -z "$user" ]] || ! arch_chroot_has_password "$root/etc/shadow" "$user" || user_pw=true
  f_return \
    root_part \
    esp \
    swap_part \
    swap_size \
    timezone="$tz" \
    locale="$(sed -n 's/^LANG=//p' "$root/etc/locale.conf" 2>/dev/null || true)" \
    keymap="$(sed -n 's/^KEYMAP=//p' "$root/etc/vconsole.conf" 2>/dev/null || true)" \
    hostname="$(cat "$root/etc/hostname" 2>/dev/null || true)" \
    user \
    root_password="$root_pw" \
    user_password="$user_pw"
}

# --- Asking ---

# Print setting $1 (a DOTFILES_ARCH_* name): $2 when an earlier run left it, else the environment's value, else one
# asked for with prompt $3 and default $4 until validator $6 (called with the value and the remaining args) accepts
# it, warning $5 otherwise. A value from the environment that the validator rejects is an error. Under --dry-run
# nothing is asked or checked: the environment's value, the default, or <$1> stands in.
arch_chroot_ask() {
  local name="$1" earlier="$2" prompt="$3" default="$4" hint="$5" validator="$6" value
  shift 6
  if [[ -n "$earlier" ]]; then
    printf '%s' "$earlier"
    return
  fi
  value="$(printenv "$name" || true)"
  if $DRY_RUN; then
    printf '%s' "${value:-${default:-<$name>}}"
    return
  fi
  if [[ -n "$value" ]]; then
    "$validator" "$value" "$@" || { warn "$name=$value: $hint"; return 1; }
    printf '%s' "$value"
    return
  fi
  while true; do
    read -r -p "$prompt${default:+ [$default]}: " value < /dev/tty
    value="${value:-$default}"
    [[ -n "$value" ]] && "$validator" "$value" "$@" && break
    warn "$hint"
  done
  printf '%s' "$value"
}

# Print a password for $1, typed twice at the terminal without echo; nothing when $2 is true (it has one already) or
# under --dry-run.
arch_chroot_ask_password() {
  local who="$1" has="$2" password again
  if [[ "$has" == true ]] || $DRY_RUN; then
    return
  fi
  while true; do
    read -r -s -p "Password for $who: " password < /dev/tty
    echo >&2
    read -r -s -p "Password for $who (again): " again < /dev/tty
    echo >&2
    [[ -n "$password" && "$password" == "$again" ]] && break
    warn "The passwords are empty or don't match; try again."
  done
  printf '%s' "$password"
}

# Return 0 if this is the Arch live ISO booted in UEFI mode, as root, at a terminal and online; warn what is missing
# otherwise. Under --dry-run, which changes nothing, it passes.
arch_chroot_preflight() {
  $DRY_RUN && return 0
  [[ -d /run/archiso ]] || { warn "Not running from the Arch live ISO (no /run/archiso)."; return 1; }
  [[ "$EUID" == 0 ]] || { warn "Run this as root."; return 1; }
  [[ -e /sys/firmware/efi/fw_platform_size ]] || { warn "Not booted in UEFI mode, which this layout needs."; return 1; }
  has_tty || { warn "No terminal to ask the questions at."; return 1; }
  command -v git >/dev/null || { warn "git is missing; install it with: pacman -Sy git"; return 1; }
  # curl rather than ping, since some networks (and QEMU's user networking) drop ICMP.
  probe curl -fsS --max-time 10 -o /dev/null https://archlinux.org \
    || { warn "archlinux.org is unreachable; connect to the internet (e.g. iwctl) first."; return 1; }
}

# Print what partition $1 holds now, for the summary, e.g. ' (previously ntfs "Windows", 407.2G)'; nothing when it
# can't be read (under --dry-run).
arch_chroot_previously() {
  local fstype label size
  size="$(lsblk -dno SIZE "$1" 2>/dev/null | tr -d ' ')" || return 0
  [[ -n "$size" ]] || return 0
  fstype="$(lsblk -dno FSTYPE "$1" 2>/dev/null | tr -d ' ')"
  label="$(lsblk -dno LABEL "$1" 2>/dev/null | sed 's/ *$//')"
  printf ' (previously %s%s, %s)' "${fstype:-unformatted}" "${label:+ \"$label\"}" "$size"
}

# Print what the install will do: whole disk $1 (repartitioned when $2 is true; empty for chosen partitions), EFI
# system partition $3 (formatted when $4 is true), root partition $5 (formatted when $6 is true), swap partition $7
# (none; formatted when $8 is true) or swap file size $9 (GiB, 0 for none), then the time zone, locale, keymap,
# hostname and user (${10} to ${14}) and whether the passwords are set already (${15}, ${16}).
arch_chroot_summary() {
  local disk="$1" wipe="$2" esp="$3" format_esp="$4" root_part="$5" format_root="$6" swap_part="$7"
  local format_swap="$8" swap_size="$9" size model disks p
  shift 9
  printf '\nArch Linux will be installed with:\n'
  if [[ -n "$disk" ]]; then
    size="$(lsblk -dno SIZE "$disk" 2>/dev/null | tr -d ' ' || true)"
    model="$(lsblk -dno MODEL "$disk" 2>/dev/null | sed 's/ *$//' || true)"
    printf '  %-10s %s%s\n' disk "$disk" "${size:+ ($size${model:+, $model})}"
    if [[ "$wipe" == true ]]; then
      printf '  %-10s %s\n' "" "ERASED: GPT, $ARCH_CHROOT_ESP_SIZE FAT32 EFI at /efi, btrfs @ and @home on the rest"
    else
      printf '  %-10s %s\n' "" "kept: it has the layout already, so an earlier install is resumed"
    fi
  else
    printf '  %-10s %s\n' disk "the partitions below; nothing else is touched"
    if [[ "$format_esp" == true ]]; then
      printf '  %-10s %s: %s%s\n' efi "$esp" "FORMATTED FAT32" "$(arch_chroot_previously "$esp")"
    else
      printf '  %-10s %s: %s\n' efi "$esp" "kept as it is (FAT32; GRUB installed to EFI/GRUB)"
    fi
    if [[ "$format_root" == true ]]; then
      printf '  %-10s %s: %s\n' root "$root_part" \
        "ERASED$(arch_chroot_previously "$root_part"): formatted btrfs with @ and @home"
    else
      printf '  %-10s %s: %s\n' root "$root_part" "kept: btrfs already, so an earlier install is resumed"
    fi
  fi
  if [[ "$swap_part" != none && -n "$swap_part" ]]; then
    if [[ "$format_swap" == true ]]; then
      printf '  %-10s %s: %s\n' swap "$swap_part" "ERASED$(arch_chroot_previously "$swap_part"): formatted as swap"
    else
      printf '  %-10s %s: %s\n' swap "$swap_part" "kept: swap already"
    fi
  elif [[ "$swap_size" != 0 && -n "$swap_size" ]]; then
    printf '  %-10s %s\n' swap "$swap_size GiB swap file at $ARCH_CHROOT_SWAPFILE (in subvolume @swap)"
  else
    printf '  %-10s %s\n' swap none
  fi
  [[ -n "$disk" ]] || printf '  %-10s %s\n' "dual boot" "os-prober lists the other OSes in GRUB"
  printf '  %-10s %s\n' "time zone" "$1" locale "$2" keymap "$3" hostname "$4" user "$5 (in wheel, with sudo)"
  printf '  %-10s %s\n' passwords "root: $([[ "$6" == true ]] && echo already set || echo as typed)," \
    "" "$5: $([[ "$7" == true ]] && echo already set || echo as typed)"
  echo
  # The disks involved, as they are now.
  disks="$disk"
  [[ -n "$disks" ]] || disks="$(for p in $esp $root_part ${swap_part#none}; do
    lsblk -no PKNAME "$p" 2>/dev/null | sed 's|^|/dev/|' || true; done | sort -u | tr '\n' ' ')"
  [[ -z "${disks// /}" ]] || lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINTS $disks 2>/dev/null | sed 's/^/  /' || true
  echo
}

# --- Steps: each checks what is done first, so a run that stopped partway resumes ---

# Lay out and mount the system at $ARCH_CHROOT_ROOT: repartition disk $1 when $2 is true (GPT, the EFI system
# partition, then btrfs), format EFI system partition $3 (FAT32), root partition $5 (btrfs) and swap partition $7 when
# $4, $6 and $8 are true, then mount the @ and @home subvolumes with compression and the EFI system partition at /efi
# (not /boot, so the kernels stay in @ and its snapshots). With swap size $9 (GiB) above 0, also @swap at /swap, holding
# a swap file of that size. Subvolumes an interrupted run left out are created; a swap file that exists is kept.
arch_chroot_disk() {
  local disk="$1" wipe="$2" esp="$3" format_esp="$4" btrfs="$5" format_root="$6" swap_part="$7" format_swap="$8"
  local swap_size="$9" root="$ARCH_CHROOT_ROOT" top="$ARCH_CHROOT_TOP" sub subvolumes="$ARCH_CHROOT_SUBVOLUMES"
  [[ "$swap_size" == 0 ]] || subvolumes+=" @swap"
  if [[ "$wipe" == true ]]; then
    run_shown wipefs --all "$disk"
    run_shown_input "$(arch_chroot_sfdisk_script)" sfdisk --quiet "$disk"
    run_shown udevadm settle
  fi
  [[ "$format_esp" != true ]] || run_shown mkfs.fat -F 32 "$esp"
  [[ "$format_root" != true ]] || run_shown mkfs.btrfs --force --quiet "$btrfs"
  [[ "$format_swap" != true ]] || run_shown mkswap "$swap_part"

  # The top level of the filesystem, which holds the subvolumes, mounted apart from /mnt so this works either way.
  run_shown mkdir -p "$top"
  run_shown mount -o subvolid=5 "$btrfs" "$top"
  for sub in $subvolumes; do
    if ! $DRY_RUN && [[ -d "$top/$sub" ]]; then
      info "Subvolume $sub exists"
    else
      run_shown btrfs subvolume create "$top/$sub"
    fi
  done
  run_shown umount "$top"

  probe mountpoint -q "$root" || run_shown mount -o "$ARCH_CHROOT_MOUNT_OPTIONS,subvol=@" "$btrfs" "$root"
  run_shown mkdir -p "$root/home" "$root/efi"
  probe mountpoint -q "$root/home" \
    || run_shown mount -o "$ARCH_CHROOT_MOUNT_OPTIONS,subvol=@home" "$btrfs" "$root/home"
  probe mountpoint -q "$root/efi" || run_shown mount "$esp" "$root/efi"
  [[ "$swap_size" != 0 ]] || return 0
  run_shown mkdir -p "$root$ARCH_CHROOT_SWAP_DIR"
  probe mountpoint -q "$root$ARCH_CHROOT_SWAP_DIR" \
    || run_shown mount -o subvol=@swap "$btrfs" "$root$ARCH_CHROOT_SWAP_DIR"
  if ! $DRY_RUN && [[ -f "$root$ARCH_CHROOT_SWAPFILE" ]]; then
    info "$ARCH_CHROOT_SWAPFILE exists"
  else
    run_shown btrfs filesystem mkswapfile --size "${swap_size}g" "$root$ARCH_CHROOT_SWAPFILE"
  fi
}

# Install the packages into $ARCH_CHROOT_ROOT with pacstrap (os-prober too when $1 is true, for dual booting), unless
# they all are, then write its fstab from what is mounted there, adding swap partition $2 (or none) or the swap file
# when swap size $3 is above 0. The keyring is only set up (-K) the first time.
arch_chroot_pacstrap() {
  local dual="$1" swap_part="$2" swap_size="$3" root="$ARCH_CHROOT_ROOT" vendor packages keyring="" swap_line=""
  local fstab uuid
  vendor="$(awk -F': ' '/^vendor_id/ { print $2; exit }' /proc/cpuinfo 2>/dev/null || true)"
  packages="$(arch_chroot_packages "$vendor" "$dual")"
  if ! $DRY_RUN && probe pacman --root "$root" -Q $packages >/dev/null; then
    info "All packages are installed in $root"
  else
    [[ -d "$root/etc/pacman.d/gnupg" ]] || keyring=-K
    run_shown pacstrap $keyring "$root" --needed $packages
  fi
  if [[ "$swap_part" != none ]]; then
    uuid="$(probe blkid -s UUID -o value "$swap_part" || true)"
    swap_line="$(arch_chroot_swap_fstab "UUID=${uuid:-<UUID of $swap_part>}")"
  elif [[ "$swap_size" != 0 ]]; then
    swap_line="$(arch_chroot_swap_fstab "$ARCH_CHROOT_SWAPFILE")"
  fi
  if ! $DRY_RUN; then
    # Compared without blank lines, which genfstab puts after each entry.
    fstab="$({ genfstab -U "$root"; printf '%s\n' "$swap_line"; } | grep -v '^$')"
    if [[ -f "$root/etc/fstab" && "$(grep -v '^$' "$root/etc/fstab")" == "$fstab" ]]; then
      info "/etc/fstab is up to date"
      return
    fi
  fi
  run_shown_to "$root/etc/fstab" genfstab -U "$root"
  [[ -z "$swap_line" ]] || append_shown "$root/etc/fstab" "$swap_line"
}

# Write $2 to file $1 in $ARCH_CHROOT_ROOT, unless it already holds exactly that.
arch_chroot_write() {
  local path="$ARCH_CHROOT_ROOT$1" content="$2"
  if [[ -f "$path" && "$(cat "$path")" == "$content" ]]; then
    info "$1 is up to date"
  else
    write_shown "$path" "$content"
  fi
}

# Set up the system in $ARCH_CHROOT_ROOT from arch-chroot, as the guide does, with time zone $1, locale $2, keymap $3,
# hostname $4 and user $5, and the root and user passwords $6 and $7 (empty to leave them), dual booting when $8 is
# true: the clock, the locale and keymap, hostname and hosts, the root password, the user in wheel with sudo, GRUB on
# the EFI system partition (with os-prober when dual booting; else also at the removable fallback path, for firmware
# that forgets its boot entries), and NetworkManager and time sync enabled.
arch_chroot_system() {
  local timezone="$1" locale="$2" keymap="$3" hostname="$4" user="$5" root_pw="$6" user_pw="$7" dual="$8"
  local root="$ARCH_CHROOT_ROOT" service
  if [[ "$(readlink "$root/etc/localtime" 2>/dev/null)" == "/usr/share/zoneinfo/$timezone" ]]; then
    info "Time zone is already $timezone"
  else
    run_shown arch-chroot "$root" ln -sf "/usr/share/zoneinfo/$timezone" /etc/localtime
  fi
  run_shown arch-chroot "$root" hwclock --systohc

  if grep -q "^$locale " "$root/etc/locale.gen" 2>/dev/null && [[ -f "$root/usr/lib/locale/locale-archive" ]]; then
    info "$locale is already generated"
  else
    run_shown sed -i "s/^#\\($locale \\)/\\1/" "$root/etc/locale.gen"
    run_shown arch-chroot "$root" locale-gen
  fi
  arch_chroot_write /etc/locale.conf "LANG=$locale"
  arch_chroot_write /etc/vconsole.conf "KEYMAP=$keymap"
  arch_chroot_write /etc/hostname "$hostname"
  arch_chroot_write /etc/hosts "$(arch_chroot_hosts "$hostname")"

  [[ -z "$root_pw" ]] || run_shown_secret "root:$root_pw" "root:********" arch-chroot "$root" chpasswd
  if grep -q "^$user:" "$root/etc/passwd" 2>/dev/null; then
    info "User $user already exists"
  else
    run_shown arch-chroot "$root" useradd -m -G wheel "$user"
  fi
  [[ -z "$user_pw" ]] || run_shown_secret "$user:$user_pw" "$user:********" arch-chroot "$root" chpasswd
  # A drop-in instead of uncommenting the wheel line in /etc/sudoers with visudo; visudo -c checks it the same way.
  arch_chroot_write "$ARCH_CHROOT_SUDOERS" "%wheel ALL=(ALL:ALL) ALL"
  run_shown chmod 0440 "$root$ARCH_CHROOT_SUDOERS"
  run_shown arch-chroot "$root" visudo -c -q -f "$ARCH_CHROOT_SUDOERS"

  if [[ -f "$root/efi/EFI/GRUB/grubx64.efi" ]]; then
    info "GRUB is already on the EFI system partition"
  else
    run_shown arch-chroot "$root" grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=GRUB
  fi
  if [[ "$dual" == true ]]; then
    # The fallback path belongs to whichever OS put it there; leave it. os-prober is off by default.
    if grep -q '^GRUB_DISABLE_OS_PROBER=false' "$root/etc/default/grub" 2>/dev/null; then
      info "os-prober is already enabled in /etc/default/grub"
    else
      run_shown sed -i 's/^#\?GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=false/' "$root/etc/default/grub"
    fi
  elif [[ -f "$root/efi/EFI/BOOT/BOOTX64.EFI" ]]; then
    info "GRUB is already at the removable fallback path"
  else
    run_shown arch-chroot "$root" grub-install --target=x86_64-efi --efi-directory=/efi --removable
  fi
  run_shown arch-chroot "$root" grub-mkconfig -o /boot/grub/grub.cfg

  for service in $ARCH_CHROOT_SERVICES; do
    if ! $DRY_RUN && probe arch-chroot "$root" systemctl is-enabled --quiet "$service"; then
      info "$service is already enabled"
    else
      run_shown arch-chroot "$root" systemctl enable --quiet "$service"
    fi
  done
}

# Clone this checkout's commit (the one the install branch pinned) into the new user $1's ~/dotfiles, on its branch
# and with its origin, so the first login can run ~/dotfiles/install.sh. Uncommitted changes aren't copied.
arch_chroot_dotfiles() {
  local user="$1" target="$ARCH_CHROOT_ROOT/home/$1/dotfiles" head branch origin
  if [[ -e "$target" ]] && ! $DRY_RUN; then
    info "/home/$user/dotfiles already exists"
    return
  fi
  head="$(probe git -C "$DOTFILES_ROOT" rev-parse HEAD)"
  branch="$(probe git -C "$DOTFILES_ROOT" symbolic-ref --short -q HEAD || true)"
  origin="$(probe git -C "$DOTFILES_ROOT" remote get-url origin || true)"
  [[ -z "$(probe git -C "$DOTFILES_ROOT" status --porcelain)" ]] \
    || warn "$DOTFILES_ROOT has uncommitted changes, which are not copied"
  run_shown git -c advice.detachedHead=false clone --quiet --no-checkout "$DOTFILES_ROOT" "$target"
  if [[ -n "$branch" ]]; then
    run_shown git -C "$target" checkout --quiet -B "$branch" "$head"
  else
    run_shown git -C "$target" checkout --quiet --detach "$head"
  fi
  [[ -z "$origin" ]] || run_shown git -C "$target" remote set-url origin "$origin"
  run_shown arch-chroot "$ARCH_CHROOT_ROOT" chown -R "$user:$user" "/home/$user/dotfiles"
}

# Install Arch Linux from the live ISO, as mjkstra's install guide does up to its automatic snapshot boot entries.
# It goes onto a whole disk, erased and laid out, or onto partitions prepared beforehand (an EFI system partition,
# possibly shared with another OS, a root partition and an optional swap partition), for dual booting. Asks every
# question up front, shows what it will do and asks once before changing anything, then runs unattended, printing each
# command. A run that stopped partway resumes where it stopped.
oti_arch_chroot() {
  local disk="" esp root_part swap_part swap_size timezone locale keymap hostname user root_has user_has root_pw
  local user_pw wipe=false format_esp=false format_root=false format_swap=false dual=false max_swap=0 fstype live
  arch_chroot_preflight || return 1
  live="$(arch_chroot_live_disk)"

  f_call arch_chroot_installed root_part esp swap_part swap_size timezone locale keymap hostname user \
    root_has=root_password user_has=user_password

  if [[ -n "$root_part" ]]; then
    # Resuming with the system mounted: it was a whole disk if that holds just the EFI system and root partitions.
    disk="/dev/$(lsblk -no PKNAME "$root_part")"
    if [[ "$esp" != "$(arch_chroot_partition "$disk" 1)" || "$root_part" != "$(arch_chroot_partition "$disk" 2)" \
      || "$(lsblk -nro TYPE "$disk" | grep -c part)" != 2 ]]; then
      disk=""
    fi
  else
    $DRY_RUN || lsblk -o NAME,SIZE,TYPE,FSTYPE,PARTTYPENAME,LABEL,MODEL
    disk="$(arch_chroot_ask DOTFILES_ARCH_DISK "" \
      "Disk to erase and install onto (e.g. /dev/vda), or partitions to pick partitions you prepared" "" \
      "not partitions, or a whole disk with nothing on it mounted that isn't the live medium${live:+ ($live)}" \
      arch_chroot_valid_disk "$live")" \
      || return 1
    if [[ "$disk" == partitions ]]; then
      disk=""
      esp="$(arch_chroot_ask DOTFILES_ARCH_EFI "" "EFI system partition (shared with other OSes is fine)" "" \
        "not an EFI system partition that is FAT32 or unformatted, with nothing mounted, off the live medium" \
        arch_chroot_valid_esp "$live")" \
        || return 1
      root_part="$(arch_chroot_ask DOTFILES_ARCH_ROOT "" "Root partition (erased)" "" \
        "not a partition with nothing mounted, off the live medium, apart from the EFI system partition" \
        arch_chroot_valid_root "$live" "$esp")" \
        || return 1
      # A dry run shows a first run: a shared EFI system partition kept, the root partition formatted.
      format_root=true
      if ! $DRY_RUN; then
        [[ -n "$(lsblk -dno FSTYPE "$esp")" ]] || format_esp=true
        [[ "$(lsblk -dno FSTYPE "$root_part")" != btrfs ]] || format_root=false
      fi
    else
      esp="$(arch_chroot_partition "$disk" 1)"
      root_part="$(arch_chroot_partition "$disk" 2)"
      if ! arch_chroot_laid_out "$disk"; then
        wipe=true format_esp=true format_root=true
      fi
    fi
  fi
  if [[ -z "$disk" ]]; then
    dual=true
    swap_size=0
    swap_part="$(arch_chroot_ask DOTFILES_ARCH_SWAP_PART "$swap_part" "Swap partition (none for no swap)" none \
      "not none, or a partition with nothing mounted, off the live medium, apart from the EFI and root partitions" \
      arch_chroot_valid_swap_part "$live" "$esp" "$root_part")" || return 1
    if [[ "$swap_part" != none ]]; then
      fstype=""
      $DRY_RUN || fstype="$(lsblk -dno FSTYPE "$swap_part")"
      [[ "$fstype" == swap ]] || format_swap=true
    fi
  else
    swap_part=none
    # Up to half the disk.
    $DRY_RUN || max_swap="$(( $(lsblk -bdno SIZE "$disk") / 1073741824 / 2 ))"
    swap_size="$(arch_chroot_ask DOTFILES_ARCH_SWAP_SIZE "$swap_size" "Swap file size in GiB (0 for none)" 0 \
      "a whole number of GiB from 0 to $max_swap (half the disk)" arch_chroot_valid_swap_size "$max_swap")" \
      || return 1
  fi
  timezone="$(arch_chroot_ask DOTFILES_ARCH_TIMEZONE "$timezone" "Time zone (e.g. Europe/London)" America/New_York \
    "no such time zone under $ARCH_CHROOT_ZONEINFO" arch_chroot_valid_timezone "$ARCH_CHROOT_ZONEINFO")" || return 1
  locale="$(arch_chroot_ask DOTFILES_ARCH_LOCALE "$locale" "Locale" en_US.UTF-8 \
    "not a locale in $ARCH_CHROOT_LOCALES" arch_chroot_valid_locale "$ARCH_CHROOT_LOCALES")" || return 1
  keymap="$(arch_chroot_ask DOTFILES_ARCH_KEYMAP "$keymap" "Console keymap" us \
    "no such keymap (list them with: localectl list-keymaps)" arch_chroot_valid_keymap "$ARCH_CHROOT_KEYMAPS")" \
    || return 1
  hostname="$(arch_chroot_ask DOTFILES_ARCH_HOSTNAME "$hostname" "Hostname" arch \
    "use letters, digits and inner hyphens, up to 63" arch_chroot_valid_hostname)" || return 1
  user="$(arch_chroot_ask DOTFILES_ARCH_USER "$user" "User name" "" \
    "use lowercase letters, digits, _ and -, starting with a letter, up to 32; not root" arch_chroot_valid_user)" \
    || return 1
  root_pw="$(arch_chroot_ask_password root "$root_has")"
  user_pw="$(arch_chroot_ask_password "$user" "$user_has")"

  arch_chroot_summary "$disk" "$wipe" "$esp" "$format_esp" "$root_part" "$format_root" "$swap_part" "$format_swap" \
    "$swap_size" "$timezone" "$locale" "$keymap" "$hostname" "$user" "$root_has" "$user_has"
  if $DRY_RUN; then
    info "[dry-run] would ask to go ahead"
  elif [[ "$wipe$format_esp$format_root$format_swap" == *true* ]]; then
    confirm "Erase and format what is marked above, and install Arch Linux?" \
      || { info "Nothing was changed."; return 1; }
  else
    confirm "Resume the install?" || { info "Nothing was changed."; return 1; }
  fi

  run_shown timedatectl set-ntp true
  arch_chroot_disk "$disk" "$wipe" "$esp" "$format_esp" "$root_part" "$format_root" "$swap_part" "$format_swap" \
    "$swap_size"
  arch_chroot_pacstrap "$dual" "$swap_part" "$swap_size"
  arch_chroot_system "$timezone" "$locale" "$keymap" "$hostname" "$user" "$root_pw" "$user_pw" "$dual"
  arch_chroot_dotfiles "$user"
  $DRY_RUN || info "Arch Linux is installed."
  info "Next: umount -R $ARCH_CHROOT_ROOT, reboot, remove the install medium, log in as $user and run:" \
    "cd ~/dotfiles && ./install.sh --variant arch --all"
  # os-prober often finds nothing from the live ISO's chroot, but does once the new system runs.
  [[ "$dual" != true ]] || info "If GRUB's menu lacks the other OS, run in the new system:" \
    "sudo grub-mkconfig -o /boot/grub/grub.cfg"
}
