# Hooks: features that declare their changes instead of making them (see Hooks in docs/install-database.md).
#
# A declared feature defines declare_<name> <os> <profile> <enabled> in place of feature_<name>. It calls the hook_*
# functions below and changes nothing: it may read the disk, but never write it. install.sh collects every selected
# feature's entries into one plan, checks that no two entries claim the same path, then applies each feature's
# entries in feature order, then runs each trigger (daemon-reload, udev reload, ...) once for every path the run
# changed, then enables and starts the units, then calls post_<name> <os> <profile> <enabled> <changed> where defined,
# for steps that need the changes made. --uninstall undoes every entry of a declared feature, newest first, then calls
# post_uninstall_<name> <os> <profile> <enabled> <removed> where defined.
#
# On SteamOS, each declared feature's files and units under /etc that SteamOS's default keep list doesn't cover go
# into its subblock of the dotfiles keep list (see keep_across_steamos_updates), so declared features never name them.
#
# Entries are lines of tab-separated fields, the declaring feature first:
#   <feature> link <src> <target>
#   <feature> file <mode> <src> <dest>
#   <feature> download <mode> <url> <sha256> <dest>
#   <feature> block <file> <content, with \, newlines and tabs escaped as \\, \n and \t>
#   <feature> unit <scope: system or user> <src_dir> <unit> <flags: comma-separated, or ->
# Paths and other fields can't hold tabs or newlines.

# What a run's changed paths trigger, as "<pattern>|<function>": each function runs once, after every feature is
# applied (or undone), with the changed paths that match its pattern. Unit removals reload systemd themselves (see
# uninstall_system_units), so they trigger nothing. Literal paths, since install/lib/systemd.sh loads after this file.
HOOK_TRIGGERS=(
  "/etc/systemd/system/*|hook_trigger_system_units"
  "/etc/systemd/user/*|hook_trigger_user_units"
  "/etc/udev/rules.d/*|hook_trigger_udev"
  "/etc/tmpfiles.d/*|hook_trigger_tmpfiles"
  "/etc/systemd/logind.conf.d/*|hook_trigger_logind"
)

# Print the name of feature <feature>'s declare function.
# Usage: declare_function <feature>
declare_function() {
  fn_name declare_ "$1"
}

# Return 0 if feature <feature> declares its changes (defines declare_<name>).
# Usage: feature_declared <feature>
feature_declared() {
  fn_defined "$(declare_function "$1")"
}

# --- Declaring (call these only from declare_<name>) ---

# Error unless each <field> is a single entry field: not empty, with no tab or newline.
# Usage: _hook_check_fields <field>...
_hook_check_fields() {
  local field
  for field in "$@"; do
    [[ -n "$field" && "$field" != *$'\t'* && "$field" != *$'\n'* ]] \
      || error "hooks: '$field' can't be empty or hold a tab or newline"
  done
}

# Write an entry made of <field>s to the plan, on fd 3, which install.sh opens while it runs a declare_<name>.
# Usage: _hook_emit <kind> <field>...
_hook_emit() {
  local line="" field
  _hook_check_fields "$@"
  { true >&3; } 2>/dev/null || error "hooks: hook_$1 called outside a declare_<name> function"
  for field in "$@"; do
    line+="${line:+$'\t'}$field"
  done
  printf '%s\n' "$line" >&3
}

# Print where repo path <repo path> (under home/ or root/) is installed.
# Usage: _hook_install_path <repo path>
_hook_install_path() {
  case "$1" in
    home/*) printf '%s' "$HOME/${1#home/}" ;;
    root/*) printf '%s' "/${1#root/}" ;;
    *) error "hooks: $1 is not under home/ or root/" ;;
  esac
}

# Link each repo path $@ (under home/ or root/) to its install path, like the link feature: a directory links every
# file under it.
# Usage: hook_link <repo path>...
hook_link() {
  local rel file
  for rel in "$@"; do
    [[ -e "$DOTFILES_ROOT/$rel" ]] || error "hook_link: $DOTFILES_ROOT/$rel does not exist"
    while IFS= read -r -d '' file; do
      file="${file#./}"
      _hook_emit link "$DOTFILES_ROOT/$file" "$(_hook_install_path "$file")"
    done < <(cd "$DOTFILES_ROOT" && find "./$rel" -type f -print0)
  done
}

# Copy repo file $2 (under root/) to its install path with mode $1, replacing any old symlink. For files read or run
# while an encrypted home may still be locked, which a symlink into it can't serve.
# Usage: hook_file <mode> <root/path>
hook_file() {
  local mode="$1" rel="$2"
  [[ -f "$DOTFILES_ROOT/$rel" ]] || error "hook_file: $DOTFILES_ROOT/$rel does not exist"
  _hook_emit file "$mode" "$DOTFILES_ROOT/$rel" "$(_hook_install_path "$rel")"
}

# Copy each file in repo directory $2 matching glob $4 into directory $3 with mode $1, as hook_file does.
# Usage: hook_files <mode> <repo dir> <dest dir> <glob>
hook_files() {
  local mode="$1" src_dir="$DOTFILES_ROOT/$2" dst_dir="$3" glob="$4" file
  [[ -d "$src_dir" ]] || error "hook_files: $src_dir does not exist"
  for file in "$src_dir"/$glob; do
    [[ -f "$file" ]] || continue
    _hook_emit file "$mode" "$file" "$dst_dir/${file##*/}"
  done
}

# Download $3, check it against SHA-256 $4 and install it at $2 with mode $1, unless $2 already matches $4.
# Usage: hook_download <mode> <dest> <url> <sha256>
hook_download() {
  _hook_emit download "$1" "$3" "$4" "$2"
}

# Set this feature's subblock of the dotfiles section in file $1 to $2 (see upsert_block).
# Usage: hook_block <file> <content>
hook_block() {
  local file="$1" content="$2"
  [[ -n "$content" ]] || error "hook_block: no content for $file"
  content="${content//\\/\\\\}"
  content="${content//$'\n'/\\n}"
  content="${content//$'\t'/\\t}"
  _hook_emit block "$file" "$content"
}

# Set this feature's subblock in shell startup file $1 to source each repo path $2... (see upsert_sources).
# Usage: hook_sources <file> <repo path>...
hook_sources() {
  local file="$1" content="" rel
  shift
  for rel in "$@"; do
    [[ -f "$DOTFILES_ROOT/$rel" ]] || error "hook_sources: $DOTFILES_ROOT/$rel does not exist"
    content+="${content:+$'\n'}. ~/dotfiles/$rel"
  done
  hook_block "$file" "$content"
}

# Copy systemd units $3... from repo directory $2, copied and never linked (see install_system_units): system ones
# into /etc/systemd/system, user ones into /etc/systemd/user, where every user manager sees them from boot. Each unit
# with an [Install] section that changed or isn't enabled is then reenabled: system ones system-wide, user ones for
# every user (systemctl --global). System units are restarted too, unless --no-start. With --restart-on-change, user
# units that changed are restarted if they are running.
# Usage: hook_units system|user [--no-start] [--restart-on-change] <repo dir> <unit>...
hook_units() {
  local scope="$1" flags="" src_dir unit
  shift
  case "$scope" in
    system|user) ;;
    *) error "hook_units: expected system or user, got '$scope'" ;;
  esac
  while [[ "${1:-}" == --* ]]; do
    case "$1" in
      --no-start) [[ "$scope" == system ]] || error "hook_units: --no-start is for system units" ;;
      --restart-on-change) [[ "$scope" != system ]] || error "hook_units: --restart-on-change is for user units" ;;
      *) error "hook_units: unknown option $1" ;;
    esac
    flags+="${flags:+,}${1#--}"
    shift
  done
  src_dir="$DOTFILES_ROOT/$1"
  shift
  for unit in "$@"; do
    [[ -f "$src_dir/$unit" ]] || error "hook_units: $src_dir/$unit does not exist"
    _hook_emit unit "$scope" "$src_dir" "$unit" "${flags:--}"
  done
}

# --- Planning ---

# Print the entries of the declared features among <features> (in the order given), each prefixed with its feature,
# one per line. A declare_<name> function's output goes to stderr, so its messages show.
# Usage: collect_plan <features> <os> <profile> <enabled>
collect_plan() {
  local features="$1" os="$2" profile="$3" enabled="$4" feature entries line
  for feature in $features; do
    feature_declared "$feature" || continue
    # Command substitutions don't inherit set -e, so stop on a declare_<name> that failed (e.g. called error).
    entries="$("$(declare_function "$feature")" "$os" "$profile" "$enabled" 3>&1 >&2)" || exit 1
    [[ -n "$entries" ]] || continue
    while IFS= read -r line; do
      printf '%s\t%s\n' "$feature" "$line"
    done <<< "$entries"
  done
}

# Print the directory that units of scope <scope> (system or user) are installed into.
# Usage: _hook_unit_dir <scope>
_hook_unit_dir() {
  case "$1" in
    system) printf '%s' "$SYSTEM_UNITS_DIR" ;;
    *) printf '%s' "$USER_UNITS_DIR" ;;
  esac
}

# Print "<key>\t<feature>" for each entry of <plan>: the path it installs, or for a block its file and feature.
# Usage: _hook_keys <plan>
_hook_keys() {
  local feature kind a b c d
  while IFS=$'\t' read -r feature kind a b c d <&4; do
    case "$kind" in
      link) printf '%s\t%s\n' "$b" "$feature" ;;
      file) printf '%s\t%s\n' "$c" "$feature" ;;
      download) printf '%s\t%s\n' "$d" "$feature" ;;
      block) printf '%s (block %s)\t%s\n' "$a" "$feature" "$feature" ;;
      unit) printf '%s/%s\t%s\n' "$(_hook_unit_dir "$a")" "$c" "$feature" ;;
      *) error "hooks: unknown entry kind '$kind' from $feature" ;;
    esac
  done 4<<< "$1"
}

# Error if two entries of <plan> install the same path, naming the features that declared them.
# Usage: check_plan <plan>
check_plan() {
  local plan="$1" conflicts
  [[ -n "$plan" ]] || return 0
  conflicts="$(_hook_keys "$plan" | LC_ALL=C sort | awk -F '\t' '
    $1 == key { owners = owners ", " $2; dup = 1; next }
    { if (dup) print key " (" owners ")"; key = $1; owners = $2; dup = 0 }
    END { if (dup) print key " (" owners ")" }
  ')"
  [[ -z "$conflicts" ]] || error "hooks: more than one entry installs:"$'\n'"$conflicts"
}

# Print the entries of <feature> in <plan>, in the order declared.
# Usage: plan_entries <feature> <plan>
plan_entries() {
  awk -F '\t' -v f="$1" '$1 == f' <<< "$2"
}

# --- Applying ---

# Print "sudo" if <path> is outside the home, where writing it needs root.
# Usage: _hook_sudo <path>
_hook_sudo() {
  [[ "$1" == "$HOME/"* ]] || printf 'sudo'
}

# Copy file <src> to <dest> with mode <mode> (with sudo outside the home), replacing any symlink, unless it is
# already up to date.
# Usage: f_call _hook_copy updated -- <mode> <src> <dest>
# Returns: updated
#   updated: true if it copied, false if <dest> was already up to date
_hook_copy() {
  local mode="$1" src="$2" dest="$3" sudo_cmd
  if [[ ! -L "$dest" ]] && cmp -s "$src" "$dest"; then
    info "$dest already up to date"
    f_return updated=false
    return
  fi
  sudo_cmd="$(_hook_sudo "$dest")"
  info "Copying $src to $dest..."
  run ${sudo_cmd:+"$sudo_cmd"} rm -f "$dest"
  run ${sudo_cmd:+"$sudo_cmd"} install -Dvm "$mode" "$src" "$dest"
  f_return updated=true
}

# Download <url>, check it against <sha256> and install it at <dest> with mode <mode>, unless <dest> already matches.
# Usage: f_call _hook_download updated -- <mode> <url> <sha256> <dest>
# Returns: updated
#   updated: true if it installed, false if <dest> already matched
_hook_download() {
  local mode="$1" url="$2" sha256="$3" dest="$4" sudo_cmd tmp
  if sha256_matches "$dest" "$sha256"; then
    info "$dest already up to date"
    f_return updated=false
    return
  fi
  sudo_cmd="$(_hook_sudo "$dest")"
  info "Downloading $url"
  tmp="$(mktemp)"
  download_verified "$url" "$sha256" "$tmp" "${dest##*/}" || { rm -f "$tmp"; error "could not download $url"; }
  run ${sudo_cmd:+"$sudo_cmd"} install -Dvm "$mode" "$tmp" "$dest"
  rm -f "$tmp"
  f_return updated=true
}

# Return 0 if unit <unit> of scope <scope> (system, or user for every user) is enabled.
# Usage: _hook_unit_enabled <scope> <unit>
_hook_unit_enabled() {
  case "$1" in
    system) systemctl is-enabled --quiet "$2" 2>/dev/null ;;
    user) systemctl --global is-enabled --quiet "$2" 2>/dev/null ;;
  esac
}

# Print the paths among feature <feature>'s <entries> that its keep list subblock must name: files under /etc, and
# units that SteamOS's default keep list doesn't cover (see unit_keep_paths).
# Usage: _hook_keep_paths <feature> <entries>
_hook_keep_paths() {
  local feature kind a b c d
  while IFS=$'\t' read -r feature kind a b c d <&4; do
    case "$kind" in
      file) [[ "$c" != /etc/* ]] || printf '%s\n' "$c" ;;
      download) [[ "$d" != /etc/* ]] || printf '%s\n' "$d" ;;
      unit) unit_keep_paths "$(_hook_unit_dir "$a")" "$b" "$c" ;;
    esac
  done 4<<< "$2"
}

# Apply feature <feature>'s <entries>, in the order declared, after setting its keep list subblock.
# Usage: f_call apply_entries changed units -- <feature> <entries>
# Returns: changed units
#   changed: the paths it changed, one per line
#   units: "<scope>\t<unit>\t<flags>\t<changed>\t<enable>" for each unit, one per line, for activate_units
apply_entries() {
  local name="$1" entries="$2" changed="" units="" feature kind a b c d dest enable updated
  local nl=$'\n' tab=$'\t'
  keep_across_steamos_updates "$name" $(_hook_keep_paths "$name" "$entries")
  while IFS=$'\t' read -r feature kind a b c d <&4; do
    case "$kind" in
      link)
        if [[ ! -L "$b" || "$(readlink "$b")" != "$a" ]]; then
          make_symlink "$a" "$b" "$(_hook_sudo "$b")"
          changed+="$b$nl"
        fi
        ;;
      file)
        f_call _hook_copy updated -- "$a" "$b" "$c"
        ! $updated || changed+="$c$nl"
        ;;
      download)
        f_call _hook_download updated -- "$a" "$b" "$c" "$d"
        ! $updated || changed+="$d$nl"
        ;;
      block) upsert_block "$a" "$name" "$(printf '%b' "$b")" "" "$(_hook_sudo "$a")" ;;
      unit)
        dest="$(_hook_unit_dir "$a")/$c"
        f_call _hook_copy updated -- 644 "$b/$c" "$dest"
        ! $updated || changed+="$dest$nl"
        enable=false
        if _unit_has_install "$b/$c" && { $updated || ! _hook_unit_enabled "$a" "$c"; }; then
          enable=true
        fi
        units+="$a$tab$c$tab$d$tab$updated$tab$enable$nl"
        ;;
      *) error "hooks: unknown entry kind '$kind' from $feature" ;;
    esac
  done 4<<< "$entries"
  f_return changed="${changed%"$nl"}" units="${units%"$nl"}"
}

# Run each trigger in HOOK_TRIGGERS once, with the <paths> that match its pattern.
# Usage: run_triggers <paths>
#   <paths>: changed paths, one per line
run_triggers() {
  local paths="$1" trigger pattern fn path matched
  [[ -n "$paths" ]] || return 0
  for trigger in "${HOOK_TRIGGERS[@]}"; do
    pattern="${trigger%%|*}"
    fn="${trigger#*|}"
    matched=()
    while IFS= read -r path; do
      # shellcheck disable=SC2053 # $pattern is a glob on purpose
      [[ -z "$path" || "$path" != $pattern ]] || matched+=("$path")
    done <<< "$paths"
    [[ ${#matched[@]} -eq 0 ]] || "$fn" "${matched[@]}"
  done
}

# Reload the system manager, after system units changed.
# Usage: hook_trigger_system_units <path>...
hook_trigger_system_units() {
  run sudo systemctl daemon-reload
}

# Reload this user's manager, if there is a user session, after user units changed.
# Usage: hook_trigger_user_units <path>...
hook_trigger_user_units() {
  ! has_user_session || run systemctl --user daemon-reload
}

# Reload the udev rules, after rules changed.
# Usage: hook_trigger_udev <path>...
hook_trigger_udev() {
  info "Reloading udev rules..."
  run sudo udevadm control --reload
}

# Apply each tmpfiles config <path> that is still there (under --dry-run, each one), so no reboot is needed.
# Usage: hook_trigger_tmpfiles <path>...
hook_trigger_tmpfiles() {
  local path
  for path in "$@"; do
    $DRY_RUN || [[ -e "$path" ]] || continue
    info "Applying $path..."
    run sudo systemd-tmpfiles --create "$path"
  done
}

# Reload systemd-logind, after its drop-ins changed.
# Usage: hook_trigger_logind <path>...
hook_trigger_logind() {
  info "Reloading systemd-logind..."
  run sudo systemctl reload systemd-logind
}

# Enable and (re)start the units in <units>, after the triggers reloaded systemd.
# Usage: activate_units <units>
#   <units>: lines from apply_entries' units
activate_units() {
  local scope unit flags changed enable session=false
  has_user_session && session=true
  while IFS=$'\t' read -r scope unit flags changed enable <&4; do
    [[ -n "$scope" ]] || continue
    if $enable; then
      case "$scope" in
        system)
          run sudo systemctl reenable "$unit"
          [[ ",$flags," == *,no-start,* ]] || run sudo systemctl restart "$unit"
          ;;
        user) run sudo systemctl --global reenable "$unit" ;;
      esac
    fi
    if $changed && $session && [[ ",$flags," == *,restart-on-change,* ]]; then
      run systemctl --user try-restart "$unit"
    fi
  done 4<<< "$1"
}

# --- Undoing ---

# Print the lines of <text> in reverse order.
# Usage: _hook_reverse_lines <text>
_hook_reverse_lines() {
  awk '{ line[NR] = $0 } END { for (i = NR; i > 0; i--) print line[i] }' <<< "$1"
}

# Undo feature <feature>'s <entries>, newest first: stop, disable and remove its units, remove its blocks, files and
# links (a link only while it still points into the repo), then its keep list subblock.
# Usage: f_call undo_entries removed triggered -- <feature> <entries>
# Returns: removed triggered
#   removed: the paths it removed, one per line
#   triggered: those that triggers should see (all but units, whose helpers reload systemd)
undo_entries() {
  local name="$1" entries="$2" removed="" triggered="" feature kind a b c d scope units sudo_cmd unit_removed
  local nl=$'\n'
  for scope in system user; do
    units="$(awk -F '\t' -v s="$scope" '$2 == "unit" && $3 == s { print $5 }' <<< "$entries" | tr '\n' ' ')"
    [[ -n "${units// /}" ]] || continue
    if [[ "$scope" == system ]]; then
      f_call uninstall_system_units unit_removed=removed -- $units
    else
      f_call uninstall_user_units unit_removed=removed -- $units
    fi
    for unit in $unit_removed; do
      removed+="$(_hook_unit_dir "$scope")/$unit$nl"
    done
  done
  while IFS=$'\t' read -r feature kind a b c d <&4; do
    case "$kind" in
      link)
        [[ -L "$b" && "$(readlink "$b")" == "$a" ]] || continue
        sudo_cmd="$(_hook_sudo "$b")"
        run ${sudo_cmd:+"$sudo_cmd"} rm -f "$b"
        removed+="$b$nl"
        triggered+="$b$nl"
        ;;
      file|download)
        [[ "$kind" == file ]] || c="$d"
        [[ -e "$c" || -L "$c" ]] || continue
        if [[ "$c" == "$HOME/"* ]]; then
          run rm -f "$c"
        else
          remove_system_files "$c"
        fi
        removed+="$c$nl"
        triggered+="$c$nl"
        ;;
      block) remove_block "$a" "$name" "$(_hook_sudo "$a")" ;;
      unit) ;;
      *) error "hooks: unknown entry kind '$kind' from $feature" ;;
    esac
  done 4<<< "$(_hook_reverse_lines "$entries")"
  forget_across_steamos_updates "$name"
  f_return removed="${removed%"$nl"}" triggered="${triggered%"$nl"}"
}

# --- Post steps ---

# Call post_<name> for <feature> (post_uninstall_<name> when <mode> is uninstall), if defined.
# Usage: run_post <mode> <feature> <os> <profile> <enabled> <paths>
#   <paths>: space-separated, the paths the feature changed, or removed
run_post() {
  local fn
  if [[ "$1" == uninstall ]]; then
    fn="$(fn_name post_uninstall_ "$2")"
  else
    fn="$(fn_name post_ "$2")"
  fi
  fn_defined "$fn" || return 0
  "$fn" "$3" "$4" "$5" "$6"
}
