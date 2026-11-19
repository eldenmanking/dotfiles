# Arch setup notes
Notes on setting up an Arch desktop by hand, beyond what the [Arch features](features/arch.md) do.

## Using NTFS Partitions with Gnome
See [here](https://wiki.archlinux.org/title/NTFS) for more information. Linux kernels &ge; 5.15 support NTFS partitions automatically, but to allow Gnome to handle mounting NTFS partitions manually, install the `ntfs-3g` package. With this package, ntfs partitions can be automatically mounted by using Gnome Disks to select the partition, "Edit mount options", and enable "Mount at System Startup".

## Enabling Trash on Data Partitions
To enable the use of "move to trash" on secondary partitions, the user must have the proper permissions to the partition. To enable the proper permissions, add the flag `uid=XXXX` (where `XXXX` is the desired user id--usually 1000 for the first user; can be confirmed with `id` in the terminal) to the mount options of the secondary partition in the fstab file (this can also be done with Gnome Disks).

## LaTeX
LaTeX works on Arch Linux with the `texlive-most` package group (and `biber` for biber support). Custom LaTeX `.sty` and `.cls` files can be provided by adding a `tex/latex` directory under `~/texmf` (see the [MiKTeX page](https://miktex.org/kb/tds) for more information).

## Optional Packages
The following is a list of packages that are not included in the base installer script, but which you can also consider installing.
 - lilypond: a CLI sheet music typesetter.
 - visual-studio-code-bin (AUR): Microsoft VSCode for Arch (supports liveshare)
 - lmms: electronic music editor
