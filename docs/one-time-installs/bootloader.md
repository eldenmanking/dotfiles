# Bootloader
## Portable bootloader
* [Ventoy](https://ventoy.net/en/index.html) can be used to manage several bootable isos
    * Download Ventoy
    * Install Ventoy onto USB (this will format the USB; you can choose the amount storage space to preserve in a separate partition)
    * Copy iso directly onto Ventoy partition
* [Veracrypt rescue disks](https://veracrypt.io/en/VeraCrypt%20Rescue%20Disk.html)
    * You can reserve a partition during the Ventoy install for Veracrypt rescue disks
    * Extract contents of Veracrypt rescue disk directly to root of a FAT/FAT32 partition of USB
    * Optional: You can put files in other directories on the same partition (e.g. if you want to keep multiple recovery disks in the same partition)
