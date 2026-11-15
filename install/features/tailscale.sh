# Feature: Tailscale with Tailscale SSH, so the machine can be reached from your other devices on any network (steamos).
# tailscaled runs as a system service from boot, so its binaries go into SYSTEM_BIN_DIR, outside a possibly encrypted
# home, and its state into /var/lib/tailscale, which SteamOS updates keep. See Tailscale in README.md.

TAILSCALE_VERSION=1.104.7
TAILSCALE_UNITS_SRC="root/etc/systemd/system"
TAILSCALE_UNIT=tailscaled.service
TAILSCALE_BINARIES="tailscale tailscaled"
TAILSCALE_CLI="$SYSTEM_BIN_DIR/tailscale"
TAILSCALED="$SYSTEM_BIN_DIR/tailscaled"
# Linked into ~/.local/bin so the CLI is on PATH. sudo's secure_path leaves it out, so run it as root by its full path.
TAILSCALE_CLI_LINK="$LOCAL_BIN/tailscale"
# tailscaled.service's StateDirectory: the machine's key and login, which make it this node of your tailnet.
TAILSCALE_STATE_DIR=/var/lib/tailscale

# The pinned tarball of Tailscale's static build for this machine, and its SHA-256 (as published next to it, in
# <tarball>.sha256).
# Usage: f_call tailscale_tarball tarball sha256
# Returns: tarball sha256
#   tarball: the file name on pkgs.tailscale.com/stable
tailscale_tarball() {
  case "$(uname -m)" in
    x86_64)
      f_return tarball="tailscale_${TAILSCALE_VERSION}_amd64.tgz" \
        sha256=e56693ff74a64f2591b7e819c280635a100aae1ddfb0ef058fcd052b7cd8d16c
      ;;
    aarch64)
      f_return tarball="tailscale_${TAILSCALE_VERSION}_arm64.tgz" \
        sha256=d6bed2720310b328b861f943d7b4016c5358a9bad60575eb51e8143b79068484
      ;;
    *) error "no Tailscale build pinned for $(uname -m)" ;;
  esac
}

# Print the paths of the installed binaries, one per line.
# Usage: tailscale_binary_paths
tailscale_binary_paths() {
  local binary
  for binary in $TAILSCALE_BINARIES; do
    printf '%s\n' "$SYSTEM_BIN_DIR/$binary"
  done
}

# Download <tarball> into the temp dir <tmp>, check it against <sha256>, and install its binaries into SYSTEM_BIN_DIR
# with sudo.
# Usage: _install_tailscale_in <tarball> <sha256> <tmp>
_install_tailscale_in() {
  local tarball="$1" sha256="$2" tmp="$3" binary
  download_verified "https://pkgs.tailscale.com/stable/$tarball" "$sha256" "$tmp/$tarball" tailscale \
    || error "could not download Tailscale"
  tar -xzf "$tmp/$tarball" -C "$tmp"
  for binary in $TAILSCALE_BINARIES; do
    run sudo install -Dm755 "$tmp/${tarball%.tgz}/$binary" "$SYSTEM_BIN_DIR/$binary"
  done
}

# Download the pinned Tailscale and install its binaries into SYSTEM_BIN_DIR (sudo), unless that version is already
# there.
# Usage: f_call install_tailscale_binaries changed
# Returns: changed
#   changed: true if the binaries were (or, under --dry-run, would be) replaced, else false
install_tailscale_binaries() {
  local tarball sha256
  f_call tailscale_tarball tarball sha256
  # tailscaled --version prints the bare version on its first line.
  if [[ -x "$TAILSCALED" && -x "$TAILSCALE_CLI" ]] \
    && [[ "$("$TAILSCALED" --version 2>/dev/null | head -1)" == "$TAILSCALE_VERSION" ]]; then
    info "Tailscale $TAILSCALE_VERSION already installed"
    f_return changed=false
    return
  fi
  if $DRY_RUN; then
    info_dry_run "download Tailscale $TAILSCALE_VERSION ($tarball) and install it into $SYSTEM_BIN_DIR"
  else
    info "Downloading Tailscale $TAILSCALE_VERSION ($tarball)"
    with_tmpdir _install_tailscale_in "$tarball" "$sha256"
  fi
  f_return changed=true
}

# Return 0 if tailscaled is logged in to a tailnet.
# Usage: tailscale_logged_in
tailscale_logged_in() {
  [[ -x "$TAILSCALE_CLI" ]] && "$TAILSCALE_CLI" status >/dev/null 2>&1
}

# Install Tailscale into /etc (needs sudo): its binaries and tailscaled.service, started now and at boot. Then log in
# with Tailscale SSH on, so your tailnet's devices can ssh in as allowed by its access controls (see Tailscale in
# README.md); if it is logged in already, just make sure Tailscale SSH is on.
#
# @machine any
# @os steamos
# @gui any
feature_tailscale() {
  local binaries_changed units_changed user
  user="$(id -un)"
  # The default keep list covers the unit and its link, but not the binaries.
  keep_across_steamos_updates tailscale $(tailscale_binary_paths) \
    $(unit_keep_paths "$SYSTEM_UNITS_DIR" "$DOTFILES_ROOT/$TAILSCALE_UNITS_SRC" "$TAILSCALE_UNIT")
  f_call install_tailscale_binaries binaries_changed=changed
  if [[ -e "$TAILSCALE_CLI" ]] || ! $DRY_RUN; then
    make_symlink "$TAILSCALE_CLI" "$TAILSCALE_CLI_LINK"
  else
    info_dry_run "link $TAILSCALE_CLI_LINK to $TAILSCALE_CLI"
  fi
  f_call install_system_units units_changed=changed -- --no-start "$DOTFILES_ROOT/$TAILSCALE_UNITS_SRC" \
    "$TAILSCALE_UNIT"

  # Restarting tailscaled drops connections over Tailscale, this session's too if it is one, so it comes last but for
  # the login, which only a session from elsewhere needs.
  if [[ "$binaries_changed" == true || -n "$units_changed" ]] \
    || ! systemctl is-active --quiet "$TAILSCALE_UNIT" 2>/dev/null; then
    [[ -z "${SSH_CONNECTION:-}" ]] \
      || warn "Restarting tailscaled; a session over Tailscale drops now (rerun the feature to finish)"
    run sudo systemctl restart "$TAILSCALE_UNIT"
  fi

  if tailscale_logged_in; then
    run sudo "$TAILSCALE_CLI" set --ssh
    info "Tailscale is up: $("$TAILSCALE_CLI" ip -4 2>/dev/null || echo "see $TAILSCALE_CLI status")"
  elif has_tty; then
    info "Log in to your tailnet: open the URL or scan the QR code below"
    run_tty sudo "$TAILSCALE_CLI" up --ssh --operator="$user" --qr
  else
    warn "Not logged in, and no terminal to log in from: run sudo $TAILSCALE_CLI up --ssh --operator=$user"
  fi
}

# Stop and remove tailscaled.service and the binaries. The state in /var/lib/tailscale (this machine's identity on
# your tailnet) is logged out and removed only after asking; kept, a reinstall comes back as the same machine.
uninstall_feature_tailscale() {
  local remove_state=false
  if [[ -d "$TAILSCALE_STATE_DIR" ]]; then
    if $DRY_RUN; then
      info_dry_run "ask to log out and remove $TAILSCALE_STATE_DIR"
    elif ! has_tty; then
      warn "No terminal to confirm removing $TAILSCALE_STATE_DIR; keeping it"
    elif confirm "Log out of your tailnet and remove $TAILSCALE_STATE_DIR?"; then
      remove_state=true
      # Logging out needs tailscaled, so before the unit is stopped.
      if tailscale_logged_in; then
        run sudo "$TAILSCALE_CLI" logout || warn "could not log out; remove the machine in the admin console"
      fi
    fi
  fi
  uninstall_system_units "$TAILSCALE_UNIT"
  if [[ -L "$TAILSCALE_CLI_LINK" && "$(readlink "$TAILSCALE_CLI_LINK")" == "$TAILSCALE_CLI" ]]; then
    run rm -f "$TAILSCALE_CLI_LINK"
  fi
  remove_system_files $(tailscale_binary_paths)
  forget_across_steamos_updates tailscale
  ! $remove_state || run sudo rm -rf "$TAILSCALE_STATE_DIR"
}
