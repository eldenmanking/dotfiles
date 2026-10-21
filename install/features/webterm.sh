# Feature: webterm, a browser shell served by ttyd and started on demand by systemd socket activation (steamos).
# See steamos/README.md.

WEBTERM_DIR="$DOTFILES_ROOT/steamos"
WEBTERM_UNIT_DIR="$HOME/.config/systemd/user"
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

# Path of systemd-socket-proxyd, or empty if it isn't installed.
find_proxyd() {
  local p
  _proxyd=""
  for p in /usr/lib/systemd/systemd-socket-proxyd /lib/systemd/systemd-socket-proxyd; do
    [[ -x "$p" ]] && _proxyd="$p" && break
  done
}

# URL the socket serves the terminal on, under the secret token if there is one.
webterm_url() {
  local token="$1" listen
  listen="$(sed -n 's/^ListenStream=//p' "$WEBTERM_SOCKET")"
  _url="http://$listen/${token:+$token/}"
}

# Secret URL path: keeps other sites (incl. DNS rebinding) from finding the shell.
# Kept in its own file, not env, so the settings in env can be linked from the repo.
ensure_token() {
  local token
  if [[ -f "$WEBTERM_TOKEN_FILE" ]]; then
    token="$(sed -n 's/^WEBTERM_TOKEN=//p' "$WEBTERM_TOKEN_FILE")"
  else
    token="$(od -An -N16 -tx1 /dev/urandom | tr -d ' \n')"
    run mkdir -p "$WEBTERM_CONF_DIR"
    (umask 077 && printf 'WEBTERM_TOKEN=%s\n' "$token" | write_file "$WEBTERM_TOKEN_FILE")
  fi
  _token="$token"
}

# Render the unit templates into ~/.config/systemd/user.
install_webterm_units() {
  local proxyd="$1"
  run mkdir -p "$WEBTERM_UNIT_DIR"
  render_template "$WEBTERM_DIR/systemd/webterm.service.template" "PROXYD=$proxyd" \
    | write_file "$WEBTERM_UNIT_DIR/webterm.service"
  render_template "$WEBTERM_DIR/systemd/webterm-ttyd.service.template" "WEBTERM_DIR=$WEBTERM_DIR" \
    | write_file "$WEBTERM_UNIT_DIR/webterm-ttyd.service"
  run cp "$WEBTERM_SOCKET" "$WEBTERM_UNIT_DIR/webterm.socket"
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

# Serve a shell in the browser on localhost: download ttyd and install systemd user units that start it on
# demand (see steamos/README.md).
#
# @machine any
# @os linux
# @gui any
# @requires link
feature_webterm() {
  require_commands curl sha256sum systemctl
  systemctl --user show-environment >/dev/null 2>&1 \
    || error "no systemd user session (log in graphically or via ssh, not su/sudo)"
  f_write_args find_proxyd _proxyd
  [[ -n "$_proxyd" ]] || error "systemd-socket-proxyd not found"
  [[ -f "$WEBTERM_ENV" ]] || $DRY_RUN || error "$WEBTERM_ENV not found; run with --link first"

  install_ttyd
  run "$WEBTERM_DIR/bin/webterm-index" \
    || warn "could not build the webterm page; ttyd will serve its stock page"
  f_write_args ensure_token _token
  install_webterm_units "$_proxyd"

  run systemctl --user daemon-reload
  run systemctl --user enable --now webterm.socket
  # If it's running, restart it so the new units and settings apply right away.
  # Open tabs reconnect on their own (their shells are restarted).
  run systemctl --user try-restart "${WEBTERM_SERVICES[@]}"

  f_write_args webterm_url _url -- "$_token"
  info "Installed. Open $_url"
  info "(server starts on first visit, exits when idle)"
  check_socket_activation "$_url"
}
