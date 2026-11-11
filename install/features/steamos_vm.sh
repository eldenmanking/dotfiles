# Feature: a SteamOS VM for testing dotfiles and SteamOS changes (steamos). It installs SteamOS onto a blank disk from
# Valve's recovery image, unattended, and defines a virt-manager VM with GPU acceleration for Game Mode. Shared code is
# in install/lib/steamos_vm.sh; home/.local/bin/steamos-vm starts and stops it. See SteamOS test VM in README.md.

# How long the unattended install may take before it counts as stuck; it takes about a minute.
STEAMOS_VM_INSTALL_TIMEOUT=1200

# Install virt-manager and its QEMU extension per-user from flathub, unless installed.
install_steamos_vm_app() {
  if steamos_vm_app_installed; then
    return
  fi
  info "Installing virt-manager and its QEMU extension from flathub..."
  run flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
  run_tty flatpak install --user -y flathub "$STEAMOS_VM_APP" "$STEAMOS_VM_QEMU_EXT_REF"
}

# Point virt-manager at the session connection the VM is on. Without a saved connection it looks for the system one,
# finds no libvirtd, and says "Could not detect a default hypervisor".
configure_steamos_vm_app() {
  local key value="['$STEAMOS_VM_URI']"
  for key in uris autoconnect; do
    if [[ "$(flatpak run --user --command=gsettings "$STEAMOS_VM_APP" get org.virt-manager.virt-manager.connections \
        "$key" 2>/dev/null)" != "$value" ]]; then
      run flatpak run --user --command=gsettings "$STEAMOS_VM_APP" set org.virt-manager.virt-manager.connections \
        "$key" "$value"
    fi
  done
}

# Print the newest Valve recovery image in ~/Downloads (steamdeck-*repair*.img.bz2), or nothing.
find_steamos_vm_recovery_download() {
  local f newest=""
  for f in "$STEAMOS_VM_DOWNLOADS"/steamdeck-*repair*.img.bz2; do
    if [[ -f "$f" && ( -z "$newest" || "$f" -nt "$newest" ) ]]; then
      newest="$f"
    fi
  done
  echo "$newest"
}

# Download Valve's latest recovery image into ~/Downloads under its dated name, and print its path. Valve publishes no
# checksums; bzip2 checks its own CRCs when it is decompressed.
download_steamos_vm_recovery() {
  local name
  name="$(curl -fsSIL -o /dev/null -w '%{url_effective}' "$STEAMOS_VM_RECOVERY_URL")" || return 1
  name="${name##*/}"
  info "Downloading $name (about 3.4 GB)..." >&2
  mkdir -p "$STEAMOS_VM_DOWNLOADS"
  curl -fL -o "$STEAMOS_VM_DOWNLOADS/$name.part" "$STEAMOS_VM_RECOVERY_URL" >&2 || return 1
  mv "$STEAMOS_VM_DOWNLOADS/$name.part" "$STEAMOS_VM_DOWNLOADS/$name"
  echo "$STEAMOS_VM_DOWNLOADS/$name"
}

# Decompress the recovery image to $STEAMOS_VM_RECOVERY, from ~/Downloads or downloaded, unless it is there. Delete it
# to use a newer image on the next install.
prepare_steamos_vm_recovery() {
  local source
  if [[ -f "$STEAMOS_VM_RECOVERY" ]]; then
    info "Using $STEAMOS_VM_RECOVERY"
    return
  fi
  source="$(find_steamos_vm_recovery_download)"
  if $DRY_RUN; then
    info "[dry-run] would decompress ${source:-$STEAMOS_VM_RECOVERY_URL} to $STEAMOS_VM_RECOVERY"
    return
  fi
  [[ -n "$source" ]] || source="$(download_steamos_vm_recovery)" || return 1
  info "Decompressing $source..."
  mkdir -p "$STEAMOS_VM_DIR"
  bzip2 -dc "$source" > "$STEAMOS_VM_RECOVERY.part" || { rm -f "$STEAMOS_VM_RECOVERY.part"; return 1; }
  mv "$STEAMOS_VM_RECOVERY.part" "$STEAMOS_VM_RECOVERY"
  rm -rf "$STEAMOS_VM_BOOT_DIR"
}

# Copy the recovery image's kernel and initramfs out of its rootfs-A partition (btrfs, read without mounting by btrfs
# restore) into $STEAMOS_VM_BOOT_DIR, and save its efi-A partition UUID there, unless they are there. The initrd is
# AMD's microcode followed by the initramfs, as GRUB loads them.
extract_steamos_vm_boot() {
  local dir="$STEAMOS_VM_BOOT_DIR" tmp extent f kernel="" initramfs=""
  if [[ -f "$dir/vmlinuz" && -f "$dir/initrd" && -s "$dir/efi-uuid" ]]; then
    return
  fi
  if $DRY_RUN; then
    info "[dry-run] would extract the recovery image's kernel and initramfs to $dir"
    return
  fi
  info "Extracting the recovery image's kernel and initramfs..."
  tmp="$STEAMOS_VM_DIR/rootfs-extract"
  rm -rf "$tmp" && mkdir -p "$tmp/out" "$dir"
  extent="$(steamos_vm_rootfs_extent "$STEAMOS_VM_RECOVERY")"
  if ! dd if="$STEAMOS_VM_RECOVERY" of="$tmp/rootfs.img" bs=512 skip="${extent% *}" count="${extent#* }" status=none \
      || ! btrfs restore --path-regex '^/(|boot(|/.*))$' "$tmp/rootfs.img" "$tmp/out" >/dev/null; then
    rm -rf "$tmp"
    warn "Could not read the recovery image's root partition."
    return 1
  fi
  for f in "$tmp"/out/boot/vmlinuz-linux-*; do
    [[ ! -f "$f" ]] || kernel="$f"
  done
  for f in "$tmp"/out/boot/initramfs-linux-*.img; do
    [[ ! -f "$f" || "$f" == *-fallback.img ]] || initramfs="$f"
  done
  if [[ -z "$kernel" || -z "$initramfs" ]]; then
    rm -rf "$tmp"
    warn "No kernel or initramfs in the recovery image's /boot."
    return 1
  fi
  cp "$kernel" "$dir/vmlinuz"
  cat "$tmp"/out/boot/amd-ucode.img "$initramfs" > "$dir/initrd" 2>/dev/null || cp "$initramfs" "$dir/initrd"
  steamos_vm_efi_uuid "$STEAMOS_VM_RECOVERY" > "$dir/efi-uuid"
  rm -rf "$tmp"
}

# Install SteamOS onto a new blank disk, unattended: boot the recovery image as a transient domain that runs the setup
# script (steamos_vm_setup_script) and powers off, then check its serial log for the done marker. Takes about a minute;
# the log is $STEAMOS_VM_INSTALL_LOG.
install_steamos_vm_disk() {
  local end size
  if [[ -f "$STEAMOS_VM_DISK" ]]; then
    info "$STEAMOS_VM_DISK already exists (use --reinstall to recreate it)"
    return
  fi
  if $DRY_RUN; then
    info "[dry-run] would install SteamOS onto a new $STEAMOS_VM_DISK_SIZE disk $STEAMOS_VM_DISK from the recovery image"
    return
  fi
  if [[ -n "$(steamos_vm_state "$STEAMOS_VM_INSTALLER")" ]]; then
    warn "An install is already running ($STEAMOS_VM_INSTALLER); wait for it, or stop it with: steamos-vm stop"
    return 1
  fi
  info "Installing SteamOS onto $STEAMOS_VM_DISK (about a minute; log: $STEAMOS_VM_INSTALL_LOG)..."
  mkdir -p "$STEAMOS_VM_CACHE"
  rm -f "$STEAMOS_VM_OVERLAY" "$STEAMOS_VM_SETUP" "$STEAMOS_VM_INSTALL_LOG"
  if ! steamos_vm_flatpak qemu-img create -q -f qcow2 "$STEAMOS_VM_DISK.part" "$STEAMOS_VM_DISK_SIZE" \
      || ! steamos_vm_flatpak qemu-img create -q -f qcow2 -F raw -b "$STEAMOS_VM_RECOVERY" "$STEAMOS_VM_OVERLAY"; then
    rm -f "$STEAMOS_VM_DISK.part" "$STEAMOS_VM_OVERLAY"
    return 1
  fi
  # A raw disk holding the script, padded to whole sectors.
  steamos_vm_setup_script > "$STEAMOS_VM_SETUP"
  size="$(wc -c < "$STEAMOS_VM_SETUP")"
  truncate -s $(( (size + 511) / 512 * 512 )) "$STEAMOS_VM_SETUP"
  # The installer writes the disk under its final name; .part only marks it unfinished until the marker shows up.
  mv "$STEAMOS_VM_DISK.part" "$STEAMOS_VM_DISK"
  steamos_vm_installer_xml "$(cat "$STEAMOS_VM_BOOT_DIR/efi-uuid")" > "$STEAMOS_VM_INSTALLER_XML"
  if ! steamos_vm_virsh create "$STEAMOS_VM_INSTALLER_XML" >/dev/null; then
    rm -f "$STEAMOS_VM_DISK" "$STEAMOS_VM_OVERLAY" "$STEAMOS_VM_SETUP"
    return 1
  fi
  end=$(( SECONDS + STEAMOS_VM_INSTALL_TIMEOUT ))
  while [[ -n "$(steamos_vm_state "$STEAMOS_VM_INSTALLER")" ]]; do
    if (( SECONDS >= end )); then
      steamos_vm_virsh destroy "$STEAMOS_VM_INSTALLER" &>/dev/null
      break
    fi
    sleep 5
  done
  # The installer's UEFI variables, kept by libvirt, would carry its boot entries into the next install.
  rm -f "$STEAMOS_VM_OVERLAY" "$STEAMOS_VM_SETUP" "$STEAMOS_VM_INSTALLER_NVRAM"
  # systemd prefixes the line with the kernel time and bash[pid]: on the console.
  if ! grep -aq ": $STEAMOS_VM_DONE_MARKER" "$STEAMOS_VM_INSTALL_LOG"; then
    rm -f "$STEAMOS_VM_DISK"
    warn "The SteamOS install failed; see $STEAMOS_VM_INSTALL_LOG"
    return 1
  fi
}

# Define the VM, unless it is. steamos-vm start redefines it when its XML for this host changes (e.g. the render node).
define_steamos_vm() {
  if steamos_vm_defined; then
    info "VM '$STEAMOS_VM_NAME' already defined (use --reinstall to recreate it)"
    return
  fi
  info "Defining VM '$STEAMOS_VM_NAME'..."
  steamos_vm_define
}

# Create a virt-manager VM running SteamOS, installed unattended from Valve's recovery image onto a blank 64G NVMe
# disk, with DRM native context GPU acceleration for Game Mode. Start it with steamos-vm.
#
# @machine any
# @os steamos
# @gui desktop
# @requires flatpak
feature_steamos_vm() {
  if ! command -v flatpak &>/dev/null; then
    warn "flatpak is not installed, skipping."
    return
  fi
  if [[ -z "$(steamos_vm_render_node)" ]]; then
    warn "No AMD GPU render node: the VM's GPU acceleration needs one (amdgpu), skipping."
    return
  fi
  install_steamos_vm_app
  if ! $DRY_RUN && ! steamos_vm_app_installed; then
    warn "virt-manager or its QEMU extension didn't install, skipping."
    return
  fi
  configure_steamos_vm_app
  prepare_steamos_vm_recovery || { warn "Could not get the SteamOS recovery image."; return; }
  extract_steamos_vm_boot || return
  install_steamos_vm_disk || return
  define_steamos_vm
  info "Start it with: steamos-vm (user deck has no password; set one with passwd in the VM)"
}

# Stop and remove the VM, its UEFI variables and its disk, after asking, since the disk holds the install. Keeps
# virt-manager and the recovery image, so --reinstall installs a fresh SteamOS without downloading anything.
uninstall_feature_steamos_vm() {
  if ! steamos_vm_defined && [[ ! -e "$STEAMOS_VM_DISK" && ! -e "$STEAMOS_VM_XML" && ! -e "$STEAMOS_VM_NVRAM" ]]; then
    info "VM '$STEAMOS_VM_NAME' does not exist"
    return
  fi
  if $DRY_RUN; then
    info "[dry-run] would ask to remove VM '$STEAMOS_VM_NAME' and its disk"
  elif ! has_tty; then
    warn "No terminal to confirm removing VM '$STEAMOS_VM_NAME'; keeping it"
    return
  elif ! confirm "Remove VM '$STEAMOS_VM_NAME' and its disk, including everything installed in it?"; then
    info "Keeping VM '$STEAMOS_VM_NAME'"
    return
  fi
  info "Removing VM '$STEAMOS_VM_NAME'..."
  if steamos_vm_defined; then
    # A running VM must be stopped first; destroy fails harmlessly when it is already off.
    run steamos_vm_virsh destroy "$STEAMOS_VM_NAME" &>/dev/null || true
    run steamos_vm_virsh undefine --nvram --managed-save "$STEAMOS_VM_NAME"
  fi
  run rm -f "$STEAMOS_VM_DISK" "$STEAMOS_VM_XML" "$STEAMOS_VM_NVRAM" "$STEAMOS_VM_SERIAL_LOG"
}
