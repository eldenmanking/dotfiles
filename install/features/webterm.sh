# Feature: webterm, a browser shell served by ttyd and started on demand by systemd socket activation (steamos).
# The unit files go into /etc/systemd/user, outside an encrypted home, so the user manager sees them from boot and
# home-units-start can start them after the unlock without a daemon-reload. See steamos/README.md.

WEBTERM_DIR="$DOTFILES_ROOT/steamos"
WEBTERM_UNIT_DIR="/etc/systemd/user"
# Where the units used to be installed, and where the per-user enable links still go.
WEBTERM_HOME_UNIT_DIR="$HOME/.config/systemd/user"
WEBTERM_UNITS=(webterm.socket webterm.service webterm-ttyd.service)
# The link 'systemctl --user enable webterm.socket' makes, from its WantedBy=sockets.target.
WEBTERM_ENABLED_LINK="$WEBTERM_HOME_UNIT_DIR/sockets.target.wants/webterm.socket"
WEBTERM_STATE_DIR="$HOME/.local/state/webterm"
WEBTERM_CONF_DIR="$HOME/.config/webterm"
WEBTERM_ENV="$WEBTERM_CONF_DIR/env"
WEBTERM_TOKEN_FILE="$WEBTERM_CONF_DIR/token"
WEBTERM_SOCKET="$WEBTERM_DIR/systemd/webterm.socket"
WEBTERM_SERVICES=(webterm.service webterm-ttyd.service)

TTYD_VERSION=1.7.7
TTYD_BIN="$WEBTERM_DIR/bin/ttyd"

# Pinned static ttyd release asset and its SHA-256 for this machine.
ttyd_asset() {
  case "$(uname -m)" in
    x86_64)  _asset=ttyd.x86_64  _sha256=8a217c968aba172e0dbf3f34447218dc015bc4d5e59bf51db2f2cd12b7be4f55 ;;
    aarch64) _asset=ttyd.aarch64 _sha256=b38acadd89d1d396a0f5649aa52c539edbad07f4bc7348b27b4f4b7219dd4165 ;;
    *)       error "no ttyd build pinned for $(uname -m)" ;;
  esac
}

# Download the pinned ttyd to steamos/bin/ttyd (git ignores it), unless it is already there.
install_ttyd() {
  f_write_args ttyd_asset _asset _sha256
  local asset="$_asset" sha256="$_sha256"

  if [[ -x "$TTYD_BIN" ]] && sha256_matches "$TTYD_BIN" "$sha256"; then
    info "ttyd $TTYD_VERSION already present: $TTYD_BIN"
    return
  fi

  info "Downloading ttyd $TTYD_VERSION ($asset)"
  local tmp
  tmp="$(mktemp "$TTYD_BIN.XXXXXX")"
  download_verified "https://github.com/tsl0922/ttyd/releases/download/$TTYD_VERSION/$asset" \
    "$sha256" "$tmp" ttyd || { rm -f "$tmp"; error "could not download ttyd"; }
  run chmod +x "$tmp"
  run mv "$tmp" "$TTYD_BIN"
  rm -f "$tmp"
  info "Installed $TTYD_BIN"
}

# Print the path of systemd-socket-proxyd, or nothing if it isn't installed.
find_proxyd() {
  local p
  for p in /usr/lib/systemd/systemd-socket-proxyd /lib/systemd/systemd-socket-proxyd; do
    if [[ -x "$p" ]]; then
      printf '%s' "$p"
      return
    fi
  done
}

# Print the URL the socket serves the terminal on, under the secret token $1 if there is one.
webterm_url() {
  local token="$1" listen
  listen="$(sed -n 's/^ListenStream=//p' "$WEBTERM_SOCKET")"
  printf '%s' "http://$listen/${token:+$token/}"
}

# Print the saved token (the secret URL path), or a new random one if none is saved yet. The token keeps other sites
# (incl. DNS rebinding) from finding the shell. It is kept in its own file, not env, so env can be linked from the repo.
webterm_token() {
  if [[ -f "$WEBTERM_TOKEN_FILE" ]]; then
    sed -n 's/^WEBTERM_TOKEN=//p' "$WEBTERM_TOKEN_FILE"
  else
    od -An -N16 -tx1 /dev/urandom | tr -d ' \n'
  fi
}

# Save token $1 to the token file, unless one is saved already.
save_token() {
  local token="$1"
  [[ ! -f "$WEBTERM_TOKEN_FILE" ]] || return 0
  run mkdir -p "$WEBTERM_CONF_DIR"
  (umask 077 && printf 'WEBTERM_TOKEN=%s\n' "$token" | write_file "$WEBTERM_TOKEN_FILE")
}

# Render the units into directory $2, for systemd-socket-proxyd at $1.
render_webterm_units() {
  local proxyd="$1" dir="$2"
  render_template "$WEBTERM_DIR/systemd/webterm.service.template" "PROXYD=$proxyd" >"$dir/webterm.service"
  render_template "$WEBTERM_DIR/systemd/webterm-ttyd.service.template" "WEBTERM_DIR=$WEBTERM_DIR" \
    >"$dir/webterm-ttyd.service"
  cp "$WEBTERM_SOCKET" "$dir/webterm.socket"
}

# Copy the rendered units into /etc/systemd/user with sudo, and remove the copies older versions installed into
# ~/.config/systemd/user, which would shadow them. Keep them across SteamOS updates, whose default keep list
# covers nothing in /etc/systemd/user.
install_webterm_units() {
  local proxyd="$1" rendered unit
  rendered="$(mktemp -d)"
  render_webterm_units "$proxyd" "$rendered"
  f_write_args copy_system_files _changed -- "$rendered" "$WEBTERM_UNIT_DIR" "webterm*"
  rm -rf "$rendered"
  for unit in "${WEBTERM_UNITS[@]}"; do
    if [[ -e "$WEBTERM_HOME_UNIT_DIR/$unit" || -L "$WEBTERM_HOME_UNIT_DIR/$unit" ]]; then
      info "Removing $WEBTERM_HOME_UNIT_DIR/$unit (now in $WEBTERM_UNIT_DIR)"
      run rm -f "$WEBTERM_HOME_UNIT_DIR/$unit"
    fi
  done
  keep_across_steamos_updates webterm "${WEBTERM_UNITS[@]/#/$WEBTERM_UNIT_DIR/}"
}

# Poke the socket once to prove activation works (it exits again when idle)
check_socket_activation() {
  local url="$1"
  if $DRY_RUN; then
    info "[dry-run] would check that $url answers"
  elif curl -fsS --noproxy '*' -o /dev/null --max-time 10 "$url"; then
    info "Check: $url answered, socket activation works."
  else
    warn "$url did not answer; see: journalctl --user -u webterm.service -u webterm-ttyd.service"
  fi
}

# Serve a shell in the browser on localhost: download ttyd and install systemd user units into /etc (needs sudo)
# that start it on demand (see steamos/README.md).
#
# @machine any
# @os linux
# @gui any
# @requires link
feature_webterm() {
  local proxyd token url
  require_commands curl sha256sum systemctl
  systemctl --user show-environment >/dev/null 2>&1 \
    || error "no systemd user session (log in graphically or via ssh, not su/sudo)"
  proxyd="$(find_proxyd)"
  [[ -n "$proxyd" ]] || error "systemd-socket-proxyd not found"
  [[ -f "$WEBTERM_ENV" ]] || $DRY_RUN || error "$WEBTERM_ENV not found; run with --link first"

  install_ttyd
  run "$WEBTERM_DIR/bin/webterm-index" \
    || warn "could not build the webterm page; ttyd will serve its stock page"
  token="$(webterm_token)"
  save_token "$token"
  install_webterm_units "$proxyd"

  run systemctl --user daemon-reload
  # reenable, so an enable link left pointing at the old copy in ~/.config/systemd/user points at the new one.
  run systemctl --user reenable webterm.socket
  run systemctl --user start webterm.socket
  # If it's running, restart it so the new units and settings apply right away.
  # Open tabs reconnect on their own (their shells are restarted).
  run systemctl --user try-restart "${WEBTERM_SERVICES[@]}"

  url="$(webterm_url "$token")"
  info "Installed. Open $url"
  info "(server starts on first visit, exits when idle)"
  check_socket_activation "$url"
}

# Stop webterm and remove its units, its enable link and the page it built. The URL token is kept.
uninstall_feature_webterm() {
  local unit session=false installed=false
  systemctl --user show-environment >/dev/null 2>&1 && session=true
  for unit in "${WEBTERM_UNITS[@]}"; do
    [[ -e "$WEBTERM_UNIT_DIR/$unit" || -e "$WEBTERM_HOME_UNIT_DIR/$unit" ]] && installed=true
  done
  # Stopping units that aren't loaded fails, so only while their files are there.
  if $installed && $session; then
    run systemctl --user stop webterm.socket "${WEBTERM_SERVICES[@]}"
  elif $installed; then
    info "No systemd user session: webterm keeps running until the next login"
  fi
  if [[ -L "$WEBTERM_ENABLED_LINK" ]]; then
    run rm -f "$WEBTERM_ENABLED_LINK"
  fi
  for unit in "${WEBTERM_UNITS[@]}"; do
    if [[ -e "$WEBTERM_HOME_UNIT_DIR/$unit" || -L "$WEBTERM_HOME_UNIT_DIR/$unit" ]]; then
      run rm -f "$WEBTERM_HOME_UNIT_DIR/$unit"
    fi
    if [[ -e "$WEBTERM_UNIT_DIR/$unit" || -L "$WEBTERM_UNIT_DIR/$unit" ]]; then
      info "Removing $WEBTERM_UNIT_DIR/$unit..."
      run sudo rm -f "$WEBTERM_UNIT_DIR/$unit"
    fi
  done
  forget_across_steamos_updates webterm
  if [[ -d "$WEBTERM_STATE_DIR" ]]; then
    run rm -rf "$WEBTERM_STATE_DIR"
  fi
  if $session; then
    run systemctl --user daemon-reload
  fi
  info "Removed webterm. Your URL token stays in $WEBTERM_TOKEN_FILE."
}
