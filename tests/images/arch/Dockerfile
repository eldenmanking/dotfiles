# Arch Linux image for tests/fixtures.sh: the image CI tests on, with packages pinned to the same Arch Linux Archive
# snapshot. It comes with the tools install.sh would otherwise download (neovim, starship, tmux), so fixtures only
# reach GitHub (zsh plugins, tpm, tools repos), and with dconf and D-Bus for the arch-dconf case. Bump the tag, digest and ARCH_ARCHIVE_DATE together with
# .github/workflows/ci.yml and tests/images/steamos (make validate checks they match).
FROM archlinux:base-20261018.0.612668@sha256:52dfbd5afb23a220d5ee92dafcb4c788d96c026ed04179890c23adef4c897fa0

ARG ARCH_ARCHIVE_DATE=2026/10/18
RUN echo "Server = https://archive.archlinux.org/repos/$ARCH_ARCHIVE_DATE/\$repo/os/\$arch" > /etc/pacman.d/mirrorlist \
  && pacman -Syu --noconfirm --needed dbus dconf diffutils git python sudo tar neovim starship tmux zsh \
  && pacman -Scc --noconfirm

# install.sh runs as a normal user, with sudo for the links into /. The home starts empty (no /etc/skel files), so it
# holds only a fixture's before/ files.
RUN mkdir /etc/skel.empty && useradd --create-home --skel /etc/skel.empty me && echo 'me ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/me
USER me
WORKDIR /home/me
