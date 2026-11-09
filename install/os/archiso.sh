# The Arch Linux live ISO, installing Arch onto another disk.
os_archiso() {
  _description="the Arch Linux live ISO: installs Arch onto a blank disk, from arch-chroot"
  _platforms="archiso"
  _machines="generic framework16"
}

# A base Arch system with a terminal only, laid out and set up as mjkstra's install guide does.
os_archiso_minimal() {
  _features="archiso_disk archiso_pacstrap archiso_system"
  _gui="none"
  _optional=""
  _link_paths=""
}
