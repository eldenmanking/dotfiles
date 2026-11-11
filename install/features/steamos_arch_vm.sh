# Feature: a GNOME Boxes VM for testing Arch installs (steamos). It has two disks: the Arch ISO itself, attached
# read-only and booted like an install stick, and a blank one to install onto. The Boxes Flatpak bundles virsh and qemu-img, so
# nothing is needed on the read-only rootfs. See Arch install test VM in README.md.

ARCH_VM_NAME="arch-install"
ARCH_VM_TARGET_SIZE="40G"
ARCH_VM_MEMORY_MIB=6144
ARCH_VM_VCPUS=8
ARCH_VM_ISO_URL="https://geo.mirror.pkgbuild.com/iso/latest"
ARCH_VM_ISO_NAME="archlinux-x86_64.iso"
ARCH_VM_ISO="$HOME/Downloads/$ARCH_VM_ISO_NAME"
ARCH_VM_BOXES_APP="org.gnome.Boxes"
# Under the Flatpak's data and cache directories, which are the paths the sandboxed virsh and qemu can see.
ARCH_VM_BOXES_DIR="$HOME/.var/app/$ARCH_VM_BOXES_APP"
ARCH_VM_IMAGES_DIR="$ARCH_VM_BOXES_DIR/data/gnome-boxes/images"
ARCH_VM_TARGET="$ARCH_VM_IMAGES_DIR/$ARCH_VM_NAME-target.qcow2"
ARCH_VM_NVRAM="$ARCH_VM_BOXES_DIR/config/libvirt/qemu/nvram/${ARCH_VM_NAME}_VARS.fd"
ARCH_VM_XML="$ARCH_VM_BOXES_DIR/cache/$ARCH_VM_NAME.xml"
# Where libvirt saves a defined domain; it is there exactly while virsh knows the VM.
ARCH_VM_DEFINITION="$ARCH_VM_BOXES_DIR/config/libvirt/qemu/$ARCH_VM_NAME.xml"
# virsh in the sandbox can hang (e.g. `list --all`), so bound every call.
ARCH_VM_TIMEOUT=60

# Run a command from the Boxes Flatpak (virsh or qemu-img) with its arguments, giving up after ARCH_VM_TIMEOUT.
#   $1: command
arch_vm_boxes() {
  local cmd="$1"
  shift
  timeout "$ARCH_VM_TIMEOUT" flatpak run --command="$cmd" "$ARCH_VM_BOXES_APP" "$@"
}

# Return 0 if the VM is defined in Boxes' libvirt session. Reads libvirt's saved definition instead of asking virsh,
# since running the Flatpak writes state into the home even under --dry-run.
arch_vm_defined() {
  [[ -f "$ARCH_VM_DEFINITION" ]]
}

# Print the libvirt domain XML: UEFI without Secure Boot (the Arch ISO isn't signed), the ISO as a read-only removable
# USB disk that boots first (it is a hybrid image, made to be written to a stick as is), and the target as a virtio
# disk. Serials tell the disks apart inside the guest.
#   $1: ISO, $2: target image, $3: NVRAM file
arch_vm_domain_xml() {
  local medium="$1" target="$2" nvram="$3"
  cat <<EOF
<domain type='kvm'>
  <name>$ARCH_VM_NAME</name>
  <title>$ARCH_VM_NAME</title>
  <memory unit='MiB'>$ARCH_VM_MEMORY_MIB</memory>
  <vcpu placement='static'>$ARCH_VM_VCPUS</vcpu>
  <os firmware='efi'>
    <type arch='x86_64' machine='q35'>hvm</type>
    <firmware>
      <feature enabled='no' name='enrolled-keys'/>
      <feature enabled='no' name='secure-boot'/>
    </firmware>
    <loader readonly='yes' type='pflash'>/app/share/qemu/edk2-x86_64-code.fd</loader>
    <nvram template='/app/share/qemu/edk2-i386-vars.fd'>$nvram</nvram>
    <bootmenu enable='yes'/>
  </os>
  <features><acpi/><apic/><smm state='on'/></features>
  <cpu mode='host-passthrough' check='none'/>
  <clock offset='utc'/>
  <on_poweroff>destroy</on_poweroff>
  <on_reboot>restart</on_reboot>
  <on_crash>destroy</on_crash>
  <devices>
    <emulator>/app/bin/qemu-system-x86_64</emulator>
    <disk type='file' device='disk'>
      <driver name='qemu' type='raw'/>
      <source file='$medium'/>
      <target dev='sda' bus='usb' removable='on'/>
      <readonly/>
      <serial>ARCHMEDIUM</serial>
      <boot order='1'/>
    </disk>
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2'/>
      <source file='$target'/>
      <target dev='vda' bus='virtio'/>
      <serial>ARCHTARGET</serial>
    </disk>
    <controller type='usb' model='qemu-xhci'/>
    <interface type='user'><model type='virtio'/></interface>
    <graphics type='spice'><listen type='none'/><image compression='off'/></graphics>
    <video><model type='virtio'/></video>
    <channel type='spicevmc'><target type='virtio' name='com.redhat.spice.0'/></channel>
    <input type='tablet' bus='usb'/>
    <rng model='virtio'><backend model='random'>/dev/urandom</backend></rng>
  </devices>
</domain>
EOF
}

# Download the latest Arch ISO to $ARCH_VM_ISO unless it is there, checking it against the mirror's sha256sums.txt.
# Delete it to get a newer one on the next run.
# That file comes from the same mirror, so it catches corruption, not tampering; verify the signature by hand for that.
download_arch_iso() {
  local dir sums
  if [[ -f "$ARCH_VM_ISO" ]]; then
    info "Using $ARCH_VM_ISO"
    return
  fi
  if $DRY_RUN; then
    info "[dry-run] would download $ARCH_VM_ISO_URL/$ARCH_VM_ISO_NAME to $ARCH_VM_ISO"
    return
  fi
  dir="$(dirname "$ARCH_VM_ISO")"
  mkdir -p "$dir"
  info "Downloading $ARCH_VM_ISO_URL/$ARCH_VM_ISO_NAME..."
  sums="$(curl -fsSL "$ARCH_VM_ISO_URL/sha256sums.txt")" || { warn "Could not fetch the ISO checksums."; return 1; }
  # -C - resumes a partial download left by an earlier run.
  curl -fSL --retry 3 -C - -o "$ARCH_VM_ISO.part" "$ARCH_VM_ISO_URL/$ARCH_VM_ISO_NAME" \
    || { warn "Could not download the ISO; rerun to resume."; return 1; }
  if ! (cd "$dir" && mv "$ARCH_VM_ISO_NAME.part" "$ARCH_VM_ISO_NAME.checking" \
      && grep " $ARCH_VM_ISO_NAME\$" <<< "$sums" | sed "s/ $ARCH_VM_ISO_NAME\$/ $ARCH_VM_ISO_NAME.checking/" \
      | sha256sum -c --status); then
    warn "$ARCH_VM_ISO_NAME checksum mismatch"
    rm -f "$ARCH_VM_ISO.checking"
    return 1
  fi
  mv "$ARCH_VM_ISO.checking" "$ARCH_VM_ISO"
}

# Create the blank target disk, a thin qcow2 of ARCH_VM_TARGET_SIZE.
create_arch_vm_target() {
  if [[ -e "$ARCH_VM_TARGET" ]]; then
    info "$ARCH_VM_TARGET already exists (use --reinstall to recreate it)"
    return
  fi
  info "Creating $ARCH_VM_TARGET ($ARCH_VM_TARGET_SIZE)..."
  run mkdir -p "$ARCH_VM_IMAGES_DIR"
  run arch_vm_boxes qemu-img create -q -f qcow2 "$ARCH_VM_TARGET" "$ARCH_VM_TARGET_SIZE"
}

# Define the VM in Boxes' libvirt session. The XML goes under the Flatpak's cache directory, as the sandbox can't see
# /tmp.
define_arch_vm() {
  if arch_vm_defined; then
    info "VM '$ARCH_VM_NAME' already defined (use --reinstall to recreate it)"
    return
  fi
  info "Defining VM '$ARCH_VM_NAME'..."
  run mkdir -p "$(dirname "$ARCH_VM_XML")"
  arch_vm_domain_xml "$ARCH_VM_ISO" "$ARCH_VM_TARGET" "$ARCH_VM_NVRAM" | write_file "$ARCH_VM_XML"
  run arch_vm_boxes virsh define "$ARCH_VM_XML"
}

# Create a GNOME Boxes VM with the Arch ISO as a read-only USB install medium and a blank 40G target disk to install
# Arch onto. Start it from Boxes.
#
# @machine any
# @os steamos
# @gui desktop
# @requires flatpak
feature_steamos_arch_vm() {
  if ! command -v flatpak &>/dev/null || ! flatpak info "$ARCH_VM_BOXES_APP" &>/dev/null; then
    $DRY_RUN || { warn "$ARCH_VM_BOXES_APP is not installed (run --flatpak first), skipping."; return; }
    info "[dry-run] $ARCH_VM_BOXES_APP is not installed; the commands below would fail without it."
  fi

  download_arch_iso || { warn "Could not download the Arch ISO."; return 1; }
  create_arch_vm_target
  define_arch_vm
  info "Start '$ARCH_VM_NAME' from GNOME Boxes: the installer boots from the medium, and /dev/vda is the target."
}

# Remove the VM, its NVRAM and the target disk, after asking, since the target may hold a test install. The ISO is
# kept, so --reinstall resets the VM to a blank target without downloading anything.
uninstall_feature_steamos_arch_vm() {
  if ! arch_vm_defined && [[ ! -e "$ARCH_VM_TARGET" && ! -e "$ARCH_VM_XML" && ! -e "$ARCH_VM_NVRAM" ]]; then
    info "VM '$ARCH_VM_NAME' does not exist"
    return
  fi
  if $DRY_RUN; then
    info "[dry-run] would ask to remove VM '$ARCH_VM_NAME' and its target disk"
  elif ! has_tty; then
    warn "No terminal to confirm removing VM '$ARCH_VM_NAME'; keeping it"
    return
  elif ! confirm "Remove VM '$ARCH_VM_NAME' and its target disk, including anything installed on it?"; then
    info "Keeping VM '$ARCH_VM_NAME'"
    return
  fi
  info "Removing VM '$ARCH_VM_NAME'..."
  if arch_vm_defined; then
    # A running VM must be stopped first; destroy fails harmlessly when it is already off.
    run arch_vm_boxes virsh destroy "$ARCH_VM_NAME" &>/dev/null || true
    # Boxes saves a VM's state when it closes; --managed-save drops that too, or undefine refuses.
    run arch_vm_boxes virsh undefine --nvram --managed-save "$ARCH_VM_NAME"
  fi
  run rm -f "$ARCH_VM_TARGET" "$ARCH_VM_XML" "$ARCH_VM_NVRAM"
}
