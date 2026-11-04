# The Arch Linux live ISO, run as root to install Arch onto a disk.
os_archiso() {
  _description="the Arch Linux live ISO (archiso), as root: installs Arch Linux onto a disk"
  _platforms="archiso"
  _machines="generic framework16"
}

# Install the base system the arch desktop is then set up on, with --variant arch as the new user after rebooting.
os_archiso_desktop() {
  _features="arch_chroot"
  _gui="none"
  _optional=""
  _link_paths=""
}
