# One-time install: Arch Linux from the live ISO onto a blank disk, following mjkstra's "Modern Arch linux installation
# guide" (https://gist.github.com/mjkstra/96ce7a5689d753e7a6bdd92cdc169bae) up to, not including, its automatic
# snapshot boot entries: a GPT disk with an EFI system partition at /efi and a btrfs root with @ and @home
# subvolumes (zstd), the guide's packages, then the system set up from arch-chroot with GRUB. See Installing Arch from
# the live ISO in README.md.
#
# Every setting is asked for up front, and checked against the live ISO, unless set in the environment:
#   DOTFILES_ARCH_DISK: the disk to install onto, e.g. /dev/vda (erased unless an earlier run laid it out)
#   DOTFILES_ARCH_TIMEZONE (America/New_York), DOTFILES_ARCH_LOCALE (en_US.UTF-8), DOTFILES_ARCH_KEYMAP (us)
#   DOTFILES_ARCH_HOSTNAME (arch), DOTFILES_ARCH_USER: the new system's hostname and user (in wheel, with sudo)
# Passwords are always typed. Settings and passwords an earlier run left in /mnt aren't asked again.

ARCH_CHROOT_ROOT=/mnt
# Bigger than the guide's 512M, to leave room for another OS's boot loader and kernels when dual booting later.
ARCH_CHROOT_ESP_SIZE=2GiB
ARCH_CHROOT_MOUNT_OPTIONS="compress=zstd"
ARCH_CHROOT_SUBVOLUMES="@ @home"
# The guide's packages, with neovim in place of vim; the CPU's microcode is added (see arch_chroot_packages).
ARCH_CHROOT_PACKAGES="base base-devel linux linux-firmware git btrfs-progs grub efibootmgr grub-btrfs inotify-tools
  timeshift neovim networkmanager pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber reflector zsh
  zsh-completions zsh-autosuggestions openssh man sudo"
ARCH_CHROOT_SERVICES="NetworkManager.service systemd-timesyncd.service"
ARCH_CHROOT_SUDOERS=/etc/sudoers.d/wheel
# What the live ISO has, to check answers against.
ARCH_CHROOT_ZONEINFO=/usr/share/zoneinfo
ARCH_CHROOT_LOCALES=/usr/share/i18n/SUPPORTED
ARCH_CHROOT_KEYMAPS=/usr/share/kbd/keymaps

# Sets _description for --help.
oti_config_arch_chroot() {
  _description="install Arch Linux from the live ISO onto a blank disk (btrfs, GRUB), asking everything up front"
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

# Print the packages to install for CPU vendor $1 (vendor_id in /proc/cpuinfo): the guide's and the CPU's microcode.
arch_chroot_packages() {
  local vendor="$1" packages
  packages="$(printf '%s ' $ARCH_CHROOT_PACKAGES)"
  case "$vendor" in
    AuthenticAMD) packages+="amd-ucode " ;;
    GenuineIntel) packages+="intel-ucode " ;;
  esac
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

# --- Reading the live system ---

# Return 0 if $1 is a whole disk with nothing on it mounted (so not the live medium).
arch_chroot_valid_disk() {
  [[ -b "$1" && "$(lsblk -dno TYPE "$1" 2>/dev/null)" == disk ]] && ! lsblk -nro MOUNTPOINTS "$1" | grep -q .
}

# Return 0 if disk $1 has the guide's layout already: a FAT32 first partition and a btrfs second one.
arch_chroot_laid_out() {
  local disk="$1"
  [[ "$(probe blkid -o value -s TYPE "$(arch_chroot_partition "$disk" 1)" || true)" == vfat \
    && "$(probe blkid -o value -s TYPE "$(arch_chroot_partition "$disk" 2)" || true)" == btrfs ]]
}

# Outputs what an earlier run left in $ARCH_CHROOT_ROOT, each empty when it isn't there: _disk (the disk mounted
# there), _timezone, _locale, _keymap, _hostname, _user (uid 1000); and
# _root_password and _user_password, true when set.
arch_chroot_installed() {
  local root="$ARCH_CHROOT_ROOT" disk="" source="" tz="" user="" root_pw=false user_pw=false
  if mountpoint -q "$root" 2>/dev/null; then
    source="$(findmnt -no SOURCE "$root" 2>/dev/null || true)"
    source="${source%%\[*}"
    [[ -z "$source" ]] || disk="$(lsblk -no PKNAME "$source" 2>/dev/null || true)"
    disk="${disk:+/dev/$disk}"
  fi
  tz="$(readlink "$root/etc/localtime" 2>/dev/null || true)"
  [[ "$tz" == /usr/share/zoneinfo/* ]] && tz="${tz#/usr/share/zoneinfo/}" || tz=""
  user="$(awk -F: '$3 == 1000 { print $1; exit }' "$root/etc/passwd" 2>/dev/null || true)"
  ! arch_chroot_has_password "$root/etc/shadow" root || root_pw=true
  [[ -z "$user" ]] || ! arch_chroot_has_password "$root/etc/shadow" "$user" || user_pw=true
  _disk="$disk"
  _timezone="$tz"
  _locale="$(sed -n 's/^LANG=//p' "$root/etc/locale.conf" 2>/dev/null || true)"
  _keymap="$(sed -n 's/^KEYMAP=//p' "$root/etc/vconsole.conf" 2>/dev/null || true)"
  _hostname="$(cat "$root/etc/hostname" 2>/dev/null || true)"
  _user="$user"
  _root_password="$root_pw"
  _user_password="$user_pw"
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

# Print what the install will do: disk $1 (erased when $2 is true), then the settings $3 to $8 (time zone, locale,
# keymap, hostname, user) and whether the passwords are set already ($8, $9).
arch_chroot_summary() {
  local disk="$1" erase="$2" size model
  size="$(lsblk -dno SIZE "$disk" 2>/dev/null | tr -d ' ' || true)"
  model="$(lsblk -dno MODEL "$disk" 2>/dev/null | sed 's/ *$//' || true)"
  printf '\nArch Linux will be installed with:\n'
  printf '  %-10s %s%s\n' disk "$disk" "${size:+ ($size${model:+, $model})}"
  if [[ "$erase" == true ]]; then
    printf '  %-10s %s\n' "" "ERASED: GPT, $ARCH_CHROOT_ESP_SIZE FAT32 EFI at /efi, btrfs @ and @home on the rest"
  else
    printf '  %-10s %s\n' "" "kept: it has the layout already, so an earlier install is resumed"
  fi
  printf '  %-10s %s\n' "time zone" "$3" locale "$4" keymap "$5" hostname "$6" user "$7 (in wheel, with sudo)"
  printf '  %-10s %s\n' passwords "root: $([[ "$8" == true ]] && echo already set || echo as typed)," \
    "" "$7: $([[ "$9" == true ]] && echo already set || echo as typed)"
  lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINTS "$disk" 2>/dev/null | sed 's/^/  /' || true
  echo
}

# --- Steps: each checks what is done first, so a run that stopped partway resumes ---

# Mount the guide's layout from disk $1 at $ARCH_CHROOT_ROOT, partitioning and formatting it first when $2 is true:
# the @ and @home subvolumes with compression, and the EFI system partition at /efi (not /boot, so the kernels stay
# in @ and its snapshots). Subvolumes an interrupted run left out are created.
arch_chroot_disk() {
  local disk="$1" erase="$2" root="$ARCH_CHROOT_ROOT" esp btrfs sub
  esp="$(arch_chroot_partition "$disk" 1)"
  btrfs="$(arch_chroot_partition "$disk" 2)"
  if [[ "$erase" == true ]]; then
    run_shown wipefs --all "$disk"
    run_shown_input "$(arch_chroot_sfdisk_script)" sfdisk --quiet "$disk"
    run_shown udevadm settle
    run_shown mkfs.fat -F 32 "$esp"
    run_shown mkfs.btrfs --force --quiet "$btrfs"
  fi
  if probe mountpoint -q "$root"; then
    info "$root is already mounted"
  else
    # The top level of the filesystem, which holds the subvolumes.
    run_shown mount -o subvolid=5 "$btrfs" "$root"
    for sub in $ARCH_CHROOT_SUBVOLUMES; do
      if ! $DRY_RUN && [[ -d "$root/$sub" ]]; then
        info "Subvolume $sub exists"
      else
        run_shown btrfs subvolume create "$root/$sub"
      fi
    done
    run_shown umount "$root"
    run_shown mount -o "$ARCH_CHROOT_MOUNT_OPTIONS,subvol=@" "$btrfs" "$root"
  fi
  run_shown mkdir -p "$root/home" "$root/efi"
  probe mountpoint -q "$root/home" \
    || run_shown mount -o "$ARCH_CHROOT_MOUNT_OPTIONS,subvol=@home" "$btrfs" "$root/home"
  probe mountpoint -q "$root/efi" || run_shown mount "$esp" "$root/efi"
}

# Install the packages into $ARCH_CHROOT_ROOT with pacstrap, unless they all are, then write its fstab
# from what is mounted there. The keyring is only set up (-K) the first time.
arch_chroot_pacstrap() {
  local root="$ARCH_CHROOT_ROOT" vendor packages keyring="" fstab
  vendor="$(awk -F': ' '/^vendor_id/ { print $2; exit }' /proc/cpuinfo 2>/dev/null || true)"
  packages="$(arch_chroot_packages "$vendor")"
  if ! $DRY_RUN && probe pacman --root "$root" -Q $packages >/dev/null; then
    info "All packages are installed in $root"
  else
    [[ -d "$root/etc/pacman.d/gnupg" ]] || keyring=-K
    run_shown pacstrap $keyring "$root" --needed $packages
  fi
  if ! $DRY_RUN; then
    fstab="$(genfstab -U "$root")"
    if [[ -f "$root/etc/fstab" && "$(cat "$root/etc/fstab")" == "$fstab" ]]; then
      info "/etc/fstab is up to date"
      return
    fi
  fi
  run_shown_to "$root/etc/fstab" genfstab -U "$root"
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
# hostname $4 and user $5, and the root and user passwords $6 and $7 (empty to leave them): the clock, the locale and
# keymap, hostname and hosts, the root password, the user in wheel with sudo, GRUB on the EFI system
# partition (also at the removable fallback path, for firmware that forgets its boot entries), and NetworkManager
# and time sync enabled.
arch_chroot_system() {
  local timezone="$1" locale="$2" keymap="$3" hostname="$4" user="$5" root_pw="$6" user_pw="$7"
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
  if [[ -f "$root/efi/EFI/BOOT/BOOTX64.EFI" ]]; then
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
# Asks every question up front, shows what it will do and asks once before changing anything, then runs unattended,
# printing each command. A run that stopped partway resumes where it stopped.
oti_arch_chroot() {
  local disk timezone locale keymap hostname user root_has user_has root_pw user_pw erase=false
  arch_chroot_preflight || return 1

  f_write_args arch_chroot_installed _disk _timezone _locale _keymap _hostname _user _root_password \
    _user_password
  disk="$_disk" timezone="$_timezone" locale="$_locale" keymap="$_keymap" hostname="$_hostname" user="$_user"
  root_has="$_root_password" user_has="$_user_password"

  [[ -n "$disk" ]] || $DRY_RUN || lsblk -d -o NAME,SIZE,MODEL,SERIAL,TYPE
  disk="$(arch_chroot_ask DOTFILES_ARCH_DISK "$disk" "Disk to install onto (e.g. /dev/vda)" "" \
    "not a whole disk, or something on it is mounted (the live medium?)" arch_chroot_valid_disk)" || return 1
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

  if ! probe mountpoint -q "$ARCH_CHROOT_ROOT" && ! arch_chroot_laid_out "$disk"; then
    erase=true
  fi
  arch_chroot_summary "$disk" "$erase" "$timezone" "$locale" "$keymap" "$hostname" "$user" "$root_has" \
    "$user_has"
  if $DRY_RUN; then
    info "[dry-run] would ask to go ahead"
  elif [[ "$erase" == true ]] && ! confirm "Erase $disk and install Arch Linux onto it?"; then
    info "Nothing was changed."
    return 1
  elif [[ "$erase" != true ]] && ! confirm "Resume the install on $disk?"; then
    info "Nothing was changed."
    return 1
  fi

  run_shown timedatectl set-ntp true
  arch_chroot_disk "$disk" "$erase"
  arch_chroot_pacstrap
  arch_chroot_system "$timezone" "$locale" "$keymap" "$hostname" "$user" "$root_pw" "$user_pw"
  arch_chroot_dotfiles "$user"
  $DRY_RUN || info "Arch Linux is installed."
  info "Next: umount -R $ARCH_CHROOT_ROOT, reboot, remove the install medium, log in as $user and run:" \
    "cd ~/dotfiles && ./install.sh --variant arch --all"
}
