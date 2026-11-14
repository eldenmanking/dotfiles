# systemd helpers: system units copied into /etc/systemd/system, and user units copied into /etc/systemd/user.

SYSTEM_UNITS_DIR="/etc/systemd/system"
USER_UNITS_DIR="/etc/systemd/user"

# Return 0 if unit file $1 has an [Install] section, so it can be enabled. Units without one are started by another
# unit (a timer, a path or socket unit, a dependency), so the helpers below only copy them.
# Usage: _unit_has_install <unit_file>
_unit_has_install() {
  grep -q '^\[Install\]' "$1"
}

# Return 0 if this process can reach a systemd user manager (not under su or sudo, or before a login).
# Usage: has_user_session
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

# Copy units <unit>... from <src_dir> into <units_dir> with sudo, and work out which to (re)enable: those with an
# [Install] section that were copied or aren't enabled yet, as 'systemctl <scope> is-enabled' tells.
# Usage: f_call _copy_units changed enable -- <units_dir> <scope> <src_dir> <unit>...
#   <scope>: empty for system units, --global for user ones
# Returns: changed enable
#   changed: the space-separated units that were copied or will be (re)enabled
#   enable: the space-separated units to (re)enable
_copy_units() {
  local dir="$1" scope="$2" src_dir="$3" unit copied changed="" enable=""
  shift 3
  for unit in "$@"; do
    [[ -e "$src_dir/$unit" ]] || error "$src_dir/$unit does not exist"
    f_call copy_system_files copied=changed -- "$src_dir" "$unit" "$dir"
    if _unit_has_install "$src_dir/$unit"; then
      if [[ -n "$copied" ]] || ! systemctl ${scope:+"$scope"} is-enabled --quiet "$unit" 2>/dev/null; then
        enable+="${enable:+ }$unit"
      fi
    fi
    if [[ -n "$copied" || " $enable " == *" $unit "* ]]; then
      changed+="${changed:+ }$unit"
    fi
  done
  f_return changed enable
}

# Copy system units $2... from $1 into /etc/systemd/system with sudo (copied, not linked: see copy_system_files),
# then reload systemd and reenable and restart each unit that changed or isn't enabled yet, so a oneshot service
# runs again. Units without an [Install] section are only copied. With --no-start, only reenable them: for units
# whose start does something unwanted right away, like one wanted by sleep.target.
# On SteamOS, also name unit_keep_paths "$SYSTEM_UNITS_DIR" <src_dir> <unit>... on the keep list: timers and the like
# aren't on the default one.
# Usage: f_call install_system_units changed -- [--no-start] <src_dir> <unit>...
# Returns: changed
#   changed: the space-separated units that were copied or (re)enabled (empty if all were up to date)
install_system_units() {
  local start=true src_dir unit changed enable
  if [[ "$1" == --no-start ]]; then
    start=false
    shift
  fi
  src_dir="$1"
  shift
  f_call _copy_units changed enable -- "$SYSTEM_UNITS_DIR" "" "$src_dir" "$@"
  if [[ -n "$changed" ]]; then
    run sudo systemctl daemon-reload
    for unit in $enable; do
      run sudo systemctl reenable "$unit"
      ! $start || run sudo systemctl restart "$unit"
    done
  fi
  f_return changed
}

# Stop, disable and remove system units $1... from /etc/systemd/system with sudo, then reload systemd. Units that
# aren't installed are skipped.
# Usage: f_call uninstall_system_units removed -- <unit>...
# Returns: removed
#   removed: the space-separated units that were removed
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
  f_return removed
}

# Copy user units <unit>... from <src_dir> into /etc/systemd/user with sudo, reload this user's manager if any changed
# and there is a user session, then reenable each unit that changed or isn't enabled yet for every user (links in
# /etc/systemd/user, which needs no session). Units without an [Install] section are only copied. Starting them is
# left to the caller. Every user manager sees the units and their links from boot, even with an encrypted home, so
# they start without waiting for the unlock. They are copied, not linked: systemd treats a symlinked unit file as a
# "linked" unit, which enable and disable handle differently.
# On SteamOS, also name unit_keep_paths "$USER_UNITS_DIR" <src_dir> <unit>... on the keep list: the default one keeps
# nothing in /etc/systemd/user.
# Usage: f_call install_user_units changed -- <src_dir> <unit>...
# Returns: changed
#   changed: the space-separated units that were copied or (re)enabled (empty if all were up to date)
install_user_units() {
  local src_dir="$1" unit changed enable
  shift
  f_call _copy_units changed enable -- "$USER_UNITS_DIR" --global "$src_dir" "$@"
  [[ -z "$changed" ]] || ! has_user_session || run systemctl --user daemon-reload
  for unit in $enable; do
    run sudo systemctl --global reenable "$unit"
  done
  f_return changed
}

# Stop user units <unit>... if there is a user session, remove their enablement links from /etc/systemd/user and then
# the units, with sudo, and reload this user's manager. Units that aren't installed are skipped. Works without a
# session too, but running units then keep running until the next login.
# Usage: f_call uninstall_user_units removed -- <unit>...
# Returns: removed
#   removed: the space-separated units that were removed
uninstall_user_units() {
  local unit link installed="" session=false
  has_user_session && session=true
  for unit in "$@"; do
    if [[ -e "$USER_UNITS_DIR/$unit" || -L "$USER_UNITS_DIR/$unit" ]]; then
      installed+="${installed:+ }$unit"
    else
      info "$USER_UNITS_DIR/$unit does not exist"
    fi
  done
  if [[ -z "$installed" ]]; then
    f_return removed=""
    return 0
  fi
  # Stopping units that aren't loaded fails, so only those whose files are there.
  if $session; then
    run systemctl --user stop $installed
  else
    info "No systemd user session: $installed keep running until the next login"
  fi
  for unit in $installed; do
    for link in "$USER_UNITS_DIR"/*.wants/"$unit" "$USER_UNITS_DIR"/*.requires/"$unit"; do
      [[ -L "$link" ]] || continue
      run sudo rm -f "$link"
    done
    info "Removing $USER_UNITS_DIR/$unit..."
    run sudo rm -f "$USER_UNITS_DIR/$unit"
  done
  ! $session || run systemctl --user daemon-reload
  f_return removed="$installed"
}
