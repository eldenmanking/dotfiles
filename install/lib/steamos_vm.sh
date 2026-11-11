# The SteamOS test VM, shared by the steamos_vm feature (install/features/steamos_vm.sh), which installs it, and
# home/.local/bin/steamos-vm, which starts, stops and repairs it. See SteamOS test VM in README.md.
#
# The VM runs under the virt-manager Flatpak's libvirt session (qemu:///session) with QEMU from its QEMU extension:
# GNOME Boxes' QEMU is too old for DRM native context, which Game Mode needs (gamescope wants Vulkan, and native
# context gives the guest the host's real AMD driver). Everything here runs virsh, qemu-img and socat from inside that
# Flatpak, so files the VM uses live under the Flatpak's data and cache directories, which its sandbox can see.

STEAMOS_VM_NAME="steamos"
# Runs Valve's recovery image once to install SteamOS onto the disk, then goes away (a transient domain).
STEAMOS_VM_INSTALLER="steamos-install"
STEAMOS_VM_APP="org.virt_manager.virt-manager"
STEAMOS_VM_QEMU_EXT="org.virt_manager.virt_manager.Extension.Qemu"
STEAMOS_VM_QEMU_EXT_REF="runtime/$STEAMOS_VM_QEMU_EXT/x86_64/stable"
STEAMOS_VM_URI="qemu:///session"
STEAMOS_VM_DISK_SIZE="64G"
STEAMOS_VM_MEMORY_MIB=6144
STEAMOS_VM_VCPUS=8
# Valve's latest recovery image, which redirects to the dated file.
STEAMOS_VM_RECOVERY_URL="https://steamdeck-images.steamos.cloud/recovery/steamdeck-repair-latest.img.bz2"
STEAMOS_VM_DOWNLOADS="$HOME/Downloads"
STEAMOS_VM_APP_DIR="$HOME/.var/app/$STEAMOS_VM_APP"
STEAMOS_VM_DIR="$STEAMOS_VM_APP_DIR/data/steamos-vm"
STEAMOS_VM_CACHE="$STEAMOS_VM_APP_DIR/cache/steamos-vm"
STEAMOS_VM_DISK="$STEAMOS_VM_DIR/disk.qcow2"
# The recovery image, decompressed (kept across --reinstall), and the kernel, initramfs and efi-A partition UUID taken
# out of it, to boot it with a serial console and an install command (see steamos_vm_installer_xml).
STEAMOS_VM_RECOVERY="$STEAMOS_VM_DIR/recovery.img"
STEAMOS_VM_BOOT_DIR="$STEAMOS_VM_DIR/recovery-boot"
# Throwaway files for one install: a copy-on-write overlay over the recovery image (whose installer writes to its home
# partition) and the setup script as a raw disk.
STEAMOS_VM_OVERLAY="$STEAMOS_VM_DIR/recovery-overlay.qcow2"
STEAMOS_VM_SETUP="$STEAMOS_VM_DIR/setup.img"
STEAMOS_VM_XML="$STEAMOS_VM_CACHE/$STEAMOS_VM_NAME.xml"
STEAMOS_VM_INSTALLER_XML="$STEAMOS_VM_CACHE/$STEAMOS_VM_INSTALLER.xml"
STEAMOS_VM_INSTALL_LOG="$STEAMOS_VM_CACHE/install.log"
STEAMOS_VM_SERIAL="$STEAMOS_VM_CACHE/serial.sock"
STEAMOS_VM_SERIAL_LOG="$STEAMOS_VM_CACHE/serial.log"
# The host end of the guest agent's virtio-serial port (see steamos_vm_setup_script).
STEAMOS_VM_AGENT="$STEAMOS_VM_CACHE/agent.sock"
STEAMOS_VM_AGENT_PORT="org.dotfiles.steamos-vm.0"
STEAMOS_VM_NVRAM="$STEAMOS_VM_APP_DIR/config/libvirt/qemu/nvram/${STEAMOS_VM_NAME}_VARS.fd"
STEAMOS_VM_INSTALLER_NVRAM="$STEAMOS_VM_APP_DIR/config/libvirt/qemu/nvram/${STEAMOS_VM_INSTALLER}_VARS.fd"
# Where libvirt saves a defined domain; it is there exactly while virsh knows the VM.
STEAMOS_VM_DEFINITION="$STEAMOS_VM_APP_DIR/config/libvirt/qemu/$STEAMOS_VM_NAME.xml"
# Printed by the setup script when SteamOS is installed and set up.
STEAMOS_VM_DONE_MARKER="STEAMOS-VM-INSTALLED"
# virsh in the sandbox can hang (e.g. while libvirtd starts), so bound every call.
STEAMOS_VM_TIMEOUT=120

# Run a command from the virt-manager Flatpak (virsh, qemu-img, socat) with its arguments, giving up after
# STEAMOS_VM_TIMEOUT. The QEMU tools are in the extension's bin directory.
#   $1: command
steamos_vm_flatpak() {
  local cmd="$1"
  shift
  case "$cmd" in
    qemu-img|socat) cmd="/app/lib/extensions/bin/$cmd" ;;
  esac
  timeout "$STEAMOS_VM_TIMEOUT" flatpak run --user --command="$cmd" "$STEAMOS_VM_APP" "$@"
}

# Run virsh on the session connection.
steamos_vm_virsh() {
  steamos_vm_flatpak virsh -c "$STEAMOS_VM_URI" "$@"
}

# Return 0 if virt-manager and its QEMU extension are installed.
steamos_vm_app_installed() {
  command -v flatpak &>/dev/null && flatpak info "$STEAMOS_VM_APP" &>/dev/null \
    && flatpak info "$STEAMOS_VM_QEMU_EXT" &>/dev/null
}

# Return 0 if the VM is defined. Reads libvirt's saved definition instead of asking virsh, which is slow to start.
steamos_vm_defined() {
  [[ -f "$STEAMOS_VM_DEFINITION" ]]
}

# Print a domain's state as virsh names it ("running", "shut off", "pmsuspended", "paused", ...), or nothing when it
# doesn't exist.
#   $1: domain name
steamos_vm_state() {
  steamos_vm_virsh domstate "$1" 2>/dev/null | head -1
}

# Print the render node the guest's GPU work runs on: the lowest-numbered amdgpu one. virglrenderer's DRM native
# context opens its device with libdrm's drmOpenWithType("amdgpu"), which tries renderD128 upward and takes the first
# match; QEMU's rendernode setting only picks the GPU SPICE draws with. So with an eGPU that came up first it is the
# eGPU, and the display has to use the same one, or every frame crosses between GPUs. Prints nothing without one.
steamos_vm_render_node() {
  local minor node driver
  for minor in $(seq 128 191); do
    node="/dev/dri/renderD$minor"
    [[ -e "$node" ]] || continue
    driver="$(readlink "/sys/class/drm/renderD$minor/device/driver" 2>/dev/null)"
    if [[ "${driver##*/}" == amdgpu ]]; then
      echo "$node"
      return
    fi
  done
}

# Print the libvirt domain XML of the VM: UEFI without Secure Boot, the disk on NVMe as on a Steam Deck (SteamOS's
# installer and tools expect /dev/nvme0n1), virtio-gpu with DRM native context on the given render node, a serial
# console and the guest agent's virtio-serial port. It keeps QEMU's own DMI identity rather than the host's: with the
# Framework's, framework_tool (orei_switch) polls for an embedded controller the VM doesn't have, and the boot waits on
# it. No CPU topology: 2 threads per core would need the topoext CPU feature, which QEMU warns AMD hosts don't pass
# through.
#   $1: render node
steamos_vm_domain_xml() {
  local render="$1"
  cat <<EOF
<domain type='kvm' xmlns:qemu='http://libvirt.org/schemas/domain/qemu/1.0'>
  <name>$STEAMOS_VM_NAME</name>
  <title>SteamOS</title>
  <memory unit='MiB'>$STEAMOS_VM_MEMORY_MIB</memory>
  <memoryBacking><source type='memfd'/><access mode='shared'/></memoryBacking>
  <vcpu placement='static'>$STEAMOS_VM_VCPUS</vcpu>
  <os firmware='efi'>
    <type arch='x86_64' machine='q35'>hvm</type>
    <firmware>
      <feature enabled='no' name='enrolled-keys'/>
      <feature enabled='no' name='secure-boot'/>
    </firmware>
    <bootmenu enable='yes'/>
  </os>
  <features><acpi/><apic/></features>
  <cpu mode='host-passthrough' check='none'/>
  <clock offset='utc'/>
  <on_poweroff>destroy</on_poweroff>
  <on_reboot>restart</on_reboot>
  <on_crash>destroy</on_crash>
  <devices>
    <emulator>/app/lib/extensions/bin/qemu-system-x86_64</emulator>
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2' discard='unmap'/>
      <source file='$STEAMOS_VM_DISK'/>
      <target dev='nvme0n1' bus='nvme'/>
      <serial>STEAMOS</serial>
      <boot order='1'/>
    </disk>
    <controller type='usb' model='qemu-xhci'/>
    <interface type='user'><model type='virtio'/></interface>
    <serial type='unix'>
      <source mode='bind' path='$STEAMOS_VM_SERIAL'/>
      <log file='$STEAMOS_VM_SERIAL_LOG' append='on'/>
      <target port='0'/>
    </serial>
    <console type='unix'>
      <source mode='bind' path='$STEAMOS_VM_SERIAL'/>
      <target type='serial' port='0'/>
    </console>
    <channel type='unix'>
      <source mode='bind' path='$STEAMOS_VM_AGENT'/>
      <target type='virtio' name='$STEAMOS_VM_AGENT_PORT'/>
    </channel>
    <channel type='spicevmc'><target type='virtio' name='com.redhat.spice.0'/></channel>
    <input type='tablet' bus='usb'/>
    <input type='keyboard' bus='usb'/>
    <graphics type='spice'>
      <listen type='none'/>
      <gl enable='yes' rendernode='$render'/>
    </graphics>
    <sound model='ich9'/>
    <audio id='1' type='spice'/>
    <video><model type='virtio' heads='1' primary='yes'><acceleration accel3d='yes'/></model></video>
    <memballoon model='none'/>
    <rng model='virtio'><backend model='random'>/dev/urandom</backend></rng>
  </devices>
  <qemu:override>
    <qemu:device alias='video0'>
      <qemu:frontend>
        <qemu:property name='blob' type='bool' value='true'/>
        <qemu:property name='drm_native_context' type='bool' value='true'/>
        <qemu:property name='hostmem' type='unsigned' value='4294967296'/>
      </qemu:frontend>
    </qemu:device>
  </qemu:override>
</domain>
EOF
}

# Print the transient domain that installs SteamOS: Valve's recovery image, booted straight into its kernel (its GRUB
# draws only on screen, with no timeout to interrupt), with a serial console and systemd.run= set to run the setup
# script from its own disk with bash, then power off. The kernel arguments are GRUB's for the image, plus what its steamenv
# module adds (steamos.efi=, the efi-A partition the initramfs finds the rest by) and minus quiet and splash.
#   $1: efi-A partition UUID
steamos_vm_installer_xml() {
  local efi="$1"
  cat <<EOF
<domain type='kvm'>
  <name>$STEAMOS_VM_INSTALLER</name>
  <memory unit='MiB'>4096</memory>
  <vcpu>$STEAMOS_VM_VCPUS</vcpu>
  <os firmware='efi'>
    <type arch='x86_64' machine='q35'>hvm</type>
    <firmware>
      <feature enabled='no' name='enrolled-keys'/>
      <feature enabled='no' name='secure-boot'/>
    </firmware>
    <kernel>$STEAMOS_VM_BOOT_DIR/vmlinuz</kernel>
    <initrd>$STEAMOS_VM_BOOT_DIR/initrd</initrd>
    <cmdline>console=tty1 console=ttyS0,115200 rd.luks=0 rd.lvm=0 rd.md=0 rd.dm=0 rd.systemd.gpt_auto=no amd_iommu=off audit=0 loglevel=5 steamos.efi=PARTUUID=$efi systemd.run="/usr/bin/bash /dev/disk/by-id/virtio-STEAMOS-VM-SETUP" systemd.run_success_action=poweroff systemd.run_failure_action=poweroff</cmdline>
  </os>
  <features><acpi/><apic/></features>
  <cpu mode='host-passthrough' check='none'/>
  <on_poweroff>destroy</on_poweroff>
  <on_reboot>destroy</on_reboot>
  <devices>
    <emulator>/app/lib/extensions/bin/qemu-system-x86_64</emulator>
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2' discard='unmap'/>
      <source file='$STEAMOS_VM_DISK'/>
      <target dev='nvme0n1' bus='nvme'/>
      <serial>STEAMOS</serial>
    </disk>
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2'/>
      <source file='$STEAMOS_VM_OVERLAY'/>
      <target dev='vda' bus='virtio'/>
      <serial>STEAMOS-VM-RECOVERY</serial>
    </disk>
    <disk type='file' device='disk'>
      <driver name='qemu' type='raw'/>
      <source file='$STEAMOS_VM_SETUP'/>
      <target dev='vdb' bus='virtio'/>
      <readonly/>
      <serial>STEAMOS-VM-SETUP</serial>
    </disk>
    <interface type='user'><model type='virtio'/></interface>
    <serial type='file'>
      <source path='$STEAMOS_VM_INSTALL_LOG'/>
      <target port='0'/>
    </serial>
    <graphics type='spice'><listen type='none'/></graphics>
    <video><model type='virtio'/></video>
    <memballoon model='none'/>
    <rng model='virtio'><backend model='random'>/dev/urandom</backend></rng>
  </devices>
</domain>
EOF
}

# Print the script the installer runs as root in the recovery image (systemd.run= runs it straight from its disk, so
# it ends with exit and the padding after it is never read). It runs Valve's repair_device.sh to wipe /dev/nvme0n1 and
# install SteamOS, then writes what the VM needs into /etc of both A/B slots (SteamOS boots B first), through the
# overlay upper directories on their var partitions:
# - a serial console login on ttyS0, which steamos-vm console and debugging use;
# - steamos-vm-agent.service, which answers ping, runs poweroff or reboot, and runs scripts (exec) from the host over
#   virtio-serial (Game Mode treats the ACPI power button as suspend, so virsh shutdown can't stop the VM; steamos-vm
#   run and sync use exec);
# - a systemd-suspend.service drop-in that makes suspend a no-op: after a guest suspend (S3 or s2idle alike), the
#   virtio-gpu native context loses its host-side state, so processes using the GPU hang in the kernel and the next
#   shutdown takes minutes. It sorts after light-sleep's drop-in, so it wins in the VM.
#   Steam's idle suspend still runs the sleep hooks (e.g. orei-switch), and "wakes" at once;
# - steamos-vm-wifi.service, which loads mac80211_hwsim for a virtual Wi-Fi radio: when Steam starts it sets the Wi-Fi
#   backend through steamos-manager, which stops NetworkManager, creates wlan0 on phy0 with iw when it is missing, and
#   gives up before starting NetworkManager again when that fails, as it does without a Wi-Fi device. That left the
#   VM offline after every Steam start.
# System units, their links and .service drop-ins survive SteamOS updates. REBOOTPROMPT makes the installer's final
# reboot prompt unconditional; with no display, it fails and returns instead of rebooting, so the setup can follow.
steamos_vm_setup_script() {
  cat <<'EOF'
#!/bin/bash
# Installs SteamOS for the steamos-vm VM; see steamos_vm_setup_script in ~/dotfiles/install/lib/steamos_vm.sh.
set -u
NOPROMPT=1 REBOOTPROMPT=1 /home/deck/tools/repair_device.sh all </dev/null
mount /dev/nvme0n1p1 /mnt && test -f /mnt/efi/steamos/steamcl.efi || { echo "SteamOS install failed"; exit 1; }
umount /mnt
for var in /dev/disk/by-partlabel/var-A /dev/disk/by-partlabel/var-B; do
  mount "$var" /mnt || exit 1
  etc=/mnt/lib/overlays/etc/upper
  mkdir -p /mnt/lib/overlays/etc/work "$etc/systemd/system/getty.target.wants" \
    "$etc/systemd/system/multi-user.target.wants" "$etc/systemd/system/systemd-suspend.service.d"
  ln -sfn /usr/lib/systemd/system/serial-getty@.service "$etc/systemd/system/getty.target.wants/serial-getty@ttyS0.service"
  cat > "$etc/systemd/system/steamos-vm-agent.service" <<'UNIT'
[Unit]
Description=Answer the steamos-vm host: ping, poweroff, reboot, exec (virtio-serial)
StartLimitIntervalSec=0

[Service]
# One command per line: ping, poweroff, reboot, or exec and a base64 script, which runs as root and answers with its
# exit status and base64 output. read gets end-of-file at once while the host end isn't connected, so retry each
# second rather than exit. ($$ and %% are systemd's escapes for $ and %.)
ExecStart=/usr/bin/bash -c '\
  exec 3<>/dev/virtio-ports/org.dotfiles.steamos-vm.0; \
  while :; do \
    read -r cmd arg <&3 || { sleep 1; continue; }; \
    case $$cmd in \
      ping) echo pong >&3 ;; \
      poweroff|reboot) echo ok >&3; systemctl $$cmd ;; \
      exec) out=$$(base64 -d <<< "$$arg" | bash 2>&1); rc=$$?; \
        printf "%%s %%s\\n" "$$rc" "$$(printf "%%s" "$$out" | base64 -w0)" >&3 ;; \
    esac; \
  done'
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
UNIT
  ln -sfn /etc/systemd/system/steamos-vm-agent.service "$etc/systemd/system/multi-user.target.wants/steamos-vm-agent.service"
  cat > "$etc/systemd/system/steamos-vm-wifi.service" <<'UNIT'
[Unit]
Description=A virtual Wi-Fi radio (mac80211_hwsim), which SteamOS's Wi-Fi backend switch needs (steamos-vm)
Before=NetworkManager.service

[Service]
Type=oneshot
ExecStart=/usr/bin/modprobe mac80211_hwsim radios=1
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
UNIT
  ln -sfn /etc/systemd/system/steamos-vm-wifi.service "$etc/systemd/system/multi-user.target.wants/steamos-vm-wifi.service"
  cat > "$etc/systemd/system/systemd-suspend.service.d/zz-steamos-vm.conf" <<'UNIT'
# steamos-vm: suspend is a no-op in this VM, since the GPU doesn't survive a guest suspend.
[Service]
ExecStart=
ExecStart=/usr/bin/true
UNIT
  umount /mnt
done
echo STEAMOS-VM-INSTALLED
exit 0
EOF
}

# Print the efi-A partition UUID of a recovery image, in lower case as GRUB passes it.
#   $1: image
steamos_vm_efi_uuid() {
  sfdisk -d "$1" | sed -n 's/.*uuid=\([0-9A-Fa-f-]*\), name="efi-A".*/\1/p' | tr '[:upper:]' '[:lower:]'
}

# Print "start size" in sectors of a recovery image's rootfs-A partition.
#   $1: image
steamos_vm_rootfs_extent() {
  sfdisk -d "$1" | sed -n 's/.*start= *\([0-9]*\), size= *\([0-9]*\),.*name="rootfs-A".*/\1 \2/p'
}

# Print the VM's domain XML for this host as it is now, with its render node (see steamos_vm_render_node).
steamos_vm_current_xml() {
  steamos_vm_domain_xml "$(steamos_vm_render_node)"
}

# Define the VM with its domain XML for this host (steamos_vm_current_xml), replacing an earlier definition.
# The XML has no UUID, so libvirt would refuse it as a second domain of the same name: undefine the old one first,
# keeping its UEFI variables. Takes effect on the next start.
steamos_vm_define() {
  local new="$STEAMOS_VM_XML.new"
  run mkdir -p "$STEAMOS_VM_CACHE"
  steamos_vm_current_xml | write_file "$new"
  if steamos_vm_defined; then
    run steamos_vm_virsh undefine --keep-nvram "$STEAMOS_VM_NAME" >/dev/null || return 1
  fi
  # Saved only once defined, since steamos-vm compares it with what the VM should be.
  run steamos_vm_virsh define "$new" >/dev/null && run mv "$new" "$STEAMOS_VM_XML"
}

# Print the render node the defined VM uses, from libvirt's saved definition.
steamos_vm_defined_render_node() {
  sed -n "s/.*rendernode='\([^']*\)'.*/\1/p" "$STEAMOS_VM_DEFINITION" 2>/dev/null | head -1
}
