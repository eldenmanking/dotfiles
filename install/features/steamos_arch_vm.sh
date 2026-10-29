# Feature: a GNOME Boxes VM for testing Arch installs (steamos). It has two disks: a small one holding the Arch ISO,
# booted like an install stick, and a blank one to install onto. The Boxes Flatpak bundles virsh and qemu-img, so
# nothing is needed on the read-only rootfs. See Arch install test VM in README.md.

ARCH_VM_NAME="arch-install"
ARCH_VM_MEDIUM_SIZE="5G"
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
ARCH_VM_MEDIUM="$ARCH_VM_IMAGES_DIR/$ARCH_VM_NAME-medium.img"
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

# Print the libvirt domain XML: UEFI without Secure Boot (the Arch ISO isn't signed), the medium as a removable USB
# disk that boots first, and the target as a virtio disk. Serials tell the disks apart inside the guest.
#   $1: medium image, $2: target image, $3: NVRAM file
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
  curl -fSL -o "$ARCH_VM_ISO.part" "$ARCH_VM_ISO_URL/$ARCH_VM_ISO_NAME" || { rm -f "$ARCH_VM_ISO.part"; return 1; }
  if ! (cd "$dir" && mv "$ARCH_VM_ISO_NAME.part" "$ARCH_VM_ISO_NAME.checking" \
      && grep " $ARCH_VM_ISO_NAME\$" <<< "$sums" | sed "s/ $ARCH_VM_ISO_NAME\$/ $ARCH_VM_ISO_NAME.checking/" \
      | sha256sum -c --status); then
    warn "$ARCH_VM_ISO_NAME checksum mismatch"
    rm -f "$ARCH_VM_ISO.checking"
    return 1
  fi
  mv "$ARCH_VM_ISO.checking" "$ARCH_VM_ISO"
}

# Create the install medium image: a sparse file of ARCH_VM_MEDIUM_SIZE with the ISO written to its start. The Arch ISO
# is a hybrid image, so the VM boots it as a disk, and the free space after it stays available. Built under a
# temporary name so an interrupted run isn't mistaken for a finished medium.
create_arch_vm_medium() {
  if [[ -e "$ARCH_VM_MEDIUM" ]]; then
    info "$ARCH_VM_MEDIUM already exists (use --reinstall to recreate it)"
    return
  fi
  download_arch_iso || return 1
  info "Writing $ARCH_VM_ISO to $ARCH_VM_MEDIUM ($ARCH_VM_MEDIUM_SIZE)..."
  run mkdir -p "$ARCH_VM_IMAGES_DIR"
  run truncate -s "$ARCH_VM_MEDIUM_SIZE" "$ARCH_VM_MEDIUM.part"
  run dd if="$ARCH_VM_ISO" of="$ARCH_VM_MEDIUM.part" conv=notrunc status=none
  run mv "$ARCH_VM_MEDIUM.part" "$ARCH_VM_MEDIUM"
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
# other paths such as /tmp.
define_arch_vm() {
  if arch_vm_defined; then
    info "VM '$ARCH_VM_NAME' already defined (use --reinstall to recreate it)"
    return
  fi
  info "Defining VM '$ARCH_VM_NAME'..."
  run mkdir -p "$(dirname "$ARCH_VM_XML")"
  arch_vm_domain_xml "$ARCH_VM_MEDIUM" "$ARCH_VM_TARGET" "$ARCH_VM_NVRAM" | write_file "$ARCH_VM_XML"
  run arch_vm_boxes virsh define "$ARCH_VM_XML"
}

# Create a GNOME Boxes VM with an install medium (the Arch ISO on a 5G USB disk) and a blank 40G target disk to
# install Arch onto. Start it from Boxes.
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

  create_arch_vm_medium || { warn "Could not create the install medium."; return; }
  create_arch_vm_target
  define_arch_vm
  info "Start '$ARCH_VM_NAME' from GNOME Boxes: the installer boots from the medium, and /dev/vda is the target."
}

# Remove the VM and both disk images, after asking, since the target may hold a test install. The downloaded ISO is
# kept.
uninstall_feature_steamos_arch_vm() {
  if ! arch_vm_defined && [[ ! -e "$ARCH_VM_MEDIUM" && ! -e "$ARCH_VM_TARGET" && ! -e "$ARCH_VM_XML" ]]; then
    info "VM '$ARCH_VM_NAME' does not exist"
    return
  fi
  if $DRY_RUN; then
    info "[dry-run] would ask to remove VM '$ARCH_VM_NAME' and its disks"
  elif ! has_tty; then
    warn "No terminal to confirm removing VM '$ARCH_VM_NAME'; keeping it"
    return
  elif ! confirm "Remove VM '$ARCH_VM_NAME' and its disk images, including anything installed on the target?"; then
    info "Keeping VM '$ARCH_VM_NAME'"
    return
  fi
  info "Removing VM '$ARCH_VM_NAME'..."
  if arch_vm_defined; then
    # A running VM must be stopped first; destroy fails harmlessly when it is already off.
    run arch_vm_boxes virsh destroy "$ARCH_VM_NAME" &>/dev/null || true
    run arch_vm_boxes virsh undefine --nvram "$ARCH_VM_NAME"
  fi
  run rm -f "$ARCH_VM_MEDIUM" "$ARCH_VM_MEDIUM.part" "$ARCH_VM_TARGET" "$ARCH_VM_XML" "$ARCH_VM_NVRAM"
}
