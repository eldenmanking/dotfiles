# Feature: webterm, a browser shell served by ttyd and started on demand by systemd socket activation (steamos).
# The units go into /etc/systemd/user, outside an encrypted home, so the user manager sees them from boot and
# home-units-start can start them after the unlock without a daemon-reload. See Webterm in README.md.

WEBTERM_UNITS_SRC="$DOTFILES_ROOT/root/etc/systemd/user"
WEBTERM_SOCKET="$WEBTERM_UNITS_SRC/webterm.socket"
WEBTERM_SERVICES=(webterm.service webterm-ttyd.service)
WEBTERM_UNITS=(webterm.socket "${WEBTERM_SERVICES[@]}")
# The link 'systemctl --user enable webterm.socket' makes, from its WantedBy=sockets.target.
WEBTERM_ENABLED_LINK="$HOME/.config/systemd/user/sockets.target.wants/webterm.socket"
WEBTERM_STATE_DIR="$HOME/.local/state/webterm"
WEBTERM_CONF_DIR="$HOME/.config/webterm"
WEBTERM_ENV="$WEBTERM_CONF_DIR/env"
WEBTERM_TOKEN_FILE="$WEBTERM_CONF_DIR/token"
# webterm.service runs this; it ships with systemd.
WEBTERM_PROXYD=/usr/lib/systemd/systemd-socket-proxyd

TTYD_VERSION=1.7.7
TTYD_BIN="$LOCAL_BIN/ttyd"

# Pinned static ttyd release asset and its SHA-256 for this machine.
ttyd_asset() {
  case "$(uname -m)" in
    x86_64)  _asset=ttyd.x86_64  _sha256=8a217c968aba172e0dbf3f34447218dc015bc4d5e59bf51db2f2cd12b7be4f55 ;;
    aarch64) _asset=ttyd.aarch64 _sha256=b38acadd89d1d396a0f5649aa52c539edbad07f4bc7348b27b4f4b7219dd4165 ;;
    *)       error "no ttyd build pinned for $(uname -m)" ;;
  esac
}

# Download the pinned ttyd to ~/.local/bin/ttyd, next to the linked webterm scripts, unless it is already there.
install_ttyd() {
  f_write_args ttyd_asset _asset _sha256
  local asset="$_asset" sha256="$_sha256"

  if [[ -x "$TTYD_BIN" ]] && sha256_matches "$TTYD_BIN" "$sha256"; then
    info "ttyd $TTYD_VERSION already present: $TTYD_BIN"
    return
  fi

  info "Downloading ttyd $TTYD_VERSION ($asset)"
  local tmp
  run mkdir -p "$LOCAL_BIN"
  tmp="$(mktemp "$TTYD_BIN.XXXXXX")"
  download_verified "https://github.com/tsl0922/ttyd/releases/download/$TTYD_VERSION/$asset" \
    "$sha256" "$tmp" ttyd || { rm -f "$tmp"; error "could not download ttyd"; }
  run chmod +x "$tmp"
  run mv "$tmp" "$TTYD_BIN"
  rm -f "$tmp"
  info "Installed $TTYD_BIN"
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
# that start it on demand (see Webterm in README.md).
#
# @machine any
# @os linux
# @gui any
# @requires link
feature_webterm() {
  local token url
  require_commands curl sha256sum systemctl
  systemctl --user show-environment >/dev/null 2>&1 \
    || error "no systemd user session (log in graphically or via ssh, not su/sudo)"
  [[ -x "$WEBTERM_PROXYD" ]] || error "$WEBTERM_PROXYD not found"
  [[ -f "$WEBTERM_ENV" ]] || $DRY_RUN || error "$WEBTERM_ENV not found; run with --link first"

  install_ttyd
  run "$LOCAL_BIN/webterm-index" \
    || warn "could not build the webterm page; ttyd will serve its stock page"
  token="$(webterm_token)"
  save_token "$token"
  f_write_args install_user_units _changed -- "$WEBTERM_UNITS_SRC" "${WEBTERM_UNITS[@]}"
  # SteamOS's default keep list covers nothing in /etc/systemd/user.
  keep_across_steamos_updates webterm "${WEBTERM_UNITS[@]/#/$USER_UNITS_DIR/}"

  run systemctl --user enable --now webterm.socket
  # If it's running, restart it so the new units and settings apply right away.
  # Open tabs reconnect on their own (their shells are restarted).
  run systemctl --user try-restart "${WEBTERM_SERVICES[@]}"

  url="$(webterm_url "$token")"
  info "Installed. Open $url"
  info "(server starts on first visit, exits when idle)"
  check_socket_activation "$url"
}

# Stop webterm and remove its units, its enable link, ttyd and the page it built. The URL token is kept.
uninstall_feature_webterm() {
  local unit session=false installed=false
  systemctl --user show-environment >/dev/null 2>&1 && session=true
  for unit in "${WEBTERM_UNITS[@]}"; do
    [[ -e "$USER_UNITS_DIR/$unit" ]] && installed=true
  done
  # Stopping units that aren't loaded fails, so only while their files are there.
  if $installed && $session; then
    run systemctl --user stop "${WEBTERM_UNITS[@]}"
  elif $installed; then
    info "No systemd user session: webterm keeps running until the next login"
  fi
  if [[ -L "$WEBTERM_ENABLED_LINK" ]]; then
    run rm -f "$WEBTERM_ENABLED_LINK"
  fi
  for unit in "${WEBTERM_UNITS[@]}"; do
    if [[ -e "$USER_UNITS_DIR/$unit" || -L "$USER_UNITS_DIR/$unit" ]]; then
      info "Removing $USER_UNITS_DIR/$unit..."
      run sudo rm -f "$USER_UNITS_DIR/$unit"
    fi
  done
  forget_across_steamos_updates webterm
  if [[ -e "$TTYD_BIN" ]]; then
    run rm -f "$TTYD_BIN"
  fi
  if [[ -d "$WEBTERM_STATE_DIR" ]]; then
    run rm -rf "$WEBTERM_STATE_DIR"
  fi
  if $session; then
    run systemctl --user daemon-reload
  fi
  info "Removed webterm. Your URL token stays in $WEBTERM_TOKEN_FILE."
}
