# SteamOS stand-in for tests/fixtures.sh. SteamOS 3 is built on Arch Linux and has no container image, so this is the
# Arch image CI tests on (same pins as tests/images/arch; make validate checks they match CI's) with KDE's kconfig
# tools (kwriteconfig6, for the kde feature). It also comes with the tools install.sh would otherwise download
# (neovim, starship, tmux), so fixtures only reach GitHub (tpm, tools repos).
FROM archlinux:base-20261018.0.612668@sha256:52dfbd5afb23a220d5ee92dafcb4c788d96c026ed04179890c23adef4c897fa0

ARG ARCH_ARCHIVE_DATE=2026/10/18
RUN echo "Server = https://archive.archlinux.org/repos/$ARCH_ARCHIVE_DATE/\$repo/os/\$arch" > /etc/pacman.d/mirrorlist \
  && pacman -Syu --noconfirm --needed diffutils git python sudo tar kconfig neovim starship tmux \
  && pacman -Scc --noconfirm

# The deck user, with sudo as on a deck once it has a password. The home starts empty (no /etc/skel files), so it holds
# only a fixture's before/ files.
RUN mkdir /etc/skel.empty && useradd --create-home --skel /etc/skel.empty deck \
  && echo 'deck ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/deck

# Stand-ins for what a container lacks (udev, /sys settings, an encrypted home, a running systemd), each printing what it
# was asked to do.
COPY bin/ /usr/local/bin/
# The mock update (see steamos-update), with a stand-in default keep list and SteamOS's keep list directory.
COPY steamos-update /usr/bin/steamos-update
COPY atomic-update-keep.conf /usr/lib/rauc/atomic-update-keep.conf
COPY example-additional-keep-list.conf /etc/atomic-update.conf.d/example-additional-keep-list.conf
# Last, so an update resets everything after this point.
RUN steamos-update --snapshot

USER deck
WORKDIR /home/deck
