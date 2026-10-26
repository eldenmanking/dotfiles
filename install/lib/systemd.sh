# systemd helpers: system units copied into /etc/systemd/system, and user units copied into /etc/systemd/user.

SYSTEM_UNITS_DIR="/etc/systemd/system"
USER_UNITS_DIR="/etc/systemd/user"
# Where 'systemctl --user enable' links the units a user enables.
USER_UNITS_HOME_DIR="$HOME/.config/systemd/user"

# Return 0 if unit file $1 has an [Install] section, so it can be enabled. Units without one are started by another
# unit (a timer, a path or socket unit, a dependency), so the helpers below only copy them.
_unit_has_install() {
  grep -q '^\[Install\]' "$1"
}

# Return 0 if this process can reach a systemd user manager (not under su or sudo, or before a login).
has_user_session() {
  systemctl --user show-environment >/dev/null 2>&1
}

# Print the paths of units $3... (from $2) in units dir $1 that SteamOS's default keep list doesn't cover, one per
# line, for keep_across_steamos_updates. In /etc/systemd/system that list keeps services, sockets and mounts with
# their enablement links, so only other units (timers, paths, ...) are printed. It keeps nothing in /etc/systemd/user,
# so there each unit is printed with the links 'systemctl --global enable' makes for its WantedBy= and RequiredBy=.
# The paths are exact, never globs: callers split the output unquoted, which would expand a glob that matches.
# Usage: unit_keep_paths <units_dir> <src_dir> <unit>...
unit_keep_paths() {
  local dir="$1" src_dir="$2" unit line suffix target
  shift 2
  for unit in "$@"; do
    if [[ "$dir" == "$SYSTEM_UNITS_DIR" ]]; then
      case "$unit" in
        *.service|*.socket|*.mount) ;;
        *) printf '%s\n' "$dir/$unit" ;;
      esac
      continue
    fi
    printf '%s\n' "$dir/$unit"
    while IFS= read -r line; do
      case "$line" in
        WantedBy=*) suffix=wants ;;
        RequiredBy=*) suffix=requires ;;
        *) continue ;;
      esac
      # One line can name several targets.
      for target in ${line#*=}; do
        printf '%s\n' "$dir/$target.$suffix/$unit"
      done
    done < "$src_dir/$unit"
  done
}

# Copy system units $2... from $1 into /etc/systemd/system with sudo (copied, not linked: see copy_system_files),
# then reload systemd and reenable and restart each unit that changed or isn't enabled yet, so a oneshot service
# runs again. Units without an [Install] section are only copied. With --no-start, only reenable them: for units
# whose start does something unwanted right away, like one wanted by sleep.target. Outputs: _changed, the
# space-separated units that were copied or (re)enabled (empty if all were up to date).
# On SteamOS, also name unit_keep_paths "$SYSTEM_UNITS_DIR" <src_dir> <unit>... on the keep list: timers and the like aren't
# on the default one.
# Usage: f_write_args install_system_units _changed -- [--no-start] <src_dir> <unit>...
install_system_units() {
  local start=true src_dir unit changed="" enable=""
  if [[ "$1" == --no-start ]]; then
    start=false
    shift
  fi
  src_dir="$1"
  shift
  for unit in "$@"; do
    [[ -e "$src_dir/$unit" ]] || error "install_system_units: $src_dir/$unit does not exist"
    f_write_args copy_system_files _changed -- "$src_dir" "$SYSTEM_UNITS_DIR" "$unit"
    if _unit_has_install "$src_dir/$unit"; then
      if [[ -n "$_changed" ]] || ! systemctl is-enabled --quiet "$unit" 2>/dev/null; then
        enable+="${enable:+ }$unit"
      fi
    fi
    if [[ -n "$_changed" || " $enable " == *" $unit "* ]]; then
      changed+="${changed:+ }$unit"
    fi
  done
  if [[ -n "$changed" ]]; then
    run sudo systemctl daemon-reload
    for unit in $enable; do
      run sudo systemctl reenable "$unit"
      ! $start || run sudo systemctl restart "$unit"
    done
  fi
  _changed="$changed"
}

# Stop, disable and remove system units $1... from /etc/systemd/system with sudo, then reload systemd. Units that
# aren't installed are skipped. Outputs: _removed, the space-separated units that were removed.
# Usage: f_write_args uninstall_system_units _removed -- <unit>...
uninstall_system_units() {
  local unit removed=""
  for unit in "$@"; do
    if [[ ! -e "$SYSTEM_UNITS_DIR/$unit" && ! -L "$SYSTEM_UNITS_DIR/$unit" ]]; then
      info "$SYSTEM_UNITS_DIR/$unit does not exist"
      continue
    fi
    info "Removing $SYSTEM_UNITS_DIR/$unit..."
    run sudo systemctl disable --now "$unit"
    run sudo rm -f "$SYSTEM_UNITS_DIR/$unit"
    removed+="${removed:+ }$unit"
  done
  [[ -z "$removed" ]] || run sudo systemctl daemon-reload
  _removed="$removed"
}

# Copy user units $3... from $2 into /etc/systemd/user with sudo, reload this user's manager if any changed and there
# is a user session, then reenable each unit that changed or isn't enabled yet: with --global for every user (links
# in /etc/systemd/user, which needs no session), with --user for this one (links in ~/.config/systemd/user, which
# needs a session). Units without an [Install] section are only copied. Starting them is left to the caller.
# Every user manager sees the units from boot, even with an encrypted home, and with --global their links too, so
# they start without waiting for the unlock. They are copied, not linked: systemd treats a symlinked unit file as a "linked" unit,
# which enable and disable handle differently. Outputs: _changed, the space-separated units that were copied or
# (re)enabled (empty if all were up to date).
# On SteamOS, also name unit_keep_paths "$USER_UNITS_DIR" <src_dir> <unit>... on the keep list: the default one keeps nothing
# in /etc/systemd/user.
# Usage: f_write_args install_user_units _changed -- --global|--user <src_dir> <unit>...
install_user_units() {
  local scope="$1" src_dir="$2" unit changed="" enable=""
  shift 2
  case "$scope" in
    --global|--user) ;;
    *) error "install_user_units: expected --global or --user, got '$scope'" ;;
  esac
  for unit in "$@"; do
    [[ -e "$src_dir/$unit" ]] || error "install_user_units: $src_dir/$unit does not exist"
    f_write_args copy_system_files _changed -- "$src_dir" "$USER_UNITS_DIR" "$unit"
    if _unit_has_install "$src_dir/$unit"; then
      if [[ -n "$_changed" ]] || ! systemctl "$scope" is-enabled --quiet "$unit" 2>/dev/null; then
        enable+="${enable:+ }$unit"
      fi
    fi
    if [[ -n "$_changed" || " $enable " == *" $unit "* ]]; then
      changed+="${changed:+ }$unit"
    fi
  done
  [[ -z "$changed" ]] || ! has_user_session || run systemctl --user daemon-reload
  for unit in $enable; do
    if [[ "$scope" == --global ]]; then
      run sudo systemctl --global reenable "$unit"
    else
      run systemctl --user reenable "$unit"
    fi
  done
  _changed="$changed"
}

# Stop user units $2... if there is a user session, remove their enablement links (--global: from /etc/systemd/user,
# --user: from ~/.config/systemd/user) and then the units in /etc/systemd/user, with sudo, and reload this user's
# manager. Units that aren't installed are skipped. Works without a session too, but running units then keep
# running until the next login. Outputs: _removed, the space-separated units that were removed.
# Usage: f_write_args uninstall_user_units _removed -- --global|--user <unit>...
uninstall_user_units() {
  local scope="$1" unit link links_dir sudo_cmd="" installed="" session=false
  shift
  case "$scope" in
    --global) links_dir="$USER_UNITS_DIR" sudo_cmd=sudo ;;
    --user) links_dir="$USER_UNITS_HOME_DIR" ;;
    *) error "uninstall_user_units: expected --global or --user, got '$scope'" ;;
  esac
  has_user_session && session=true
  for unit in "$@"; do
    if [[ -e "$USER_UNITS_DIR/$unit" || -L "$USER_UNITS_DIR/$unit" ]]; then
      installed+="${installed:+ }$unit"
    else
      info "$USER_UNITS_DIR/$unit does not exist"
    fi
  done
  if [[ -z "$installed" ]]; then
    _removed=""
    return 0
  fi
  # Stopping units that aren't loaded fails, so only those whose files are there.
  if $session; then
    run systemctl --user stop $installed
  else
    info "No systemd user session: $installed keep running until the next login"
  fi
  for unit in $installed; do
    for link in "$links_dir"/*.wants/"$unit" "$links_dir"/*.requires/"$unit"; do
      [[ -L "$link" ]] || continue
      run ${sudo_cmd:+"$sudo_cmd"} rm -f "$link"
    done
    info "Removing $USER_UNITS_DIR/$unit..."
    run sudo rm -f "$USER_UNITS_DIR/$unit"
  done
  ! $session || run systemctl --user daemon-reload
  _removed="$installed"
}
