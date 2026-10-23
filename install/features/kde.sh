# Feature: KDE Plasma settings (steamos desktop mode). KDE rewrites its config files, which would break symlinks, so
# each file listed here is merged into its ~/.config counterpart key by key with kwriteconfig, leaving other keys alone.

# Partial KDE config files, home/-relative like the link paths. Nested groups ([A][B]) are supported.
KDE_CONFIG_FILES=(
  home/.config/kcminputrc
)

# Resolve the kwriteconfig/kreadconfig pair for the installed Plasma (6, else 5), or empty when neither exists.
kde_config_tools() {
  local v
  _write=""
  _read=""
  for v in 6 5; do
    if command -v "kwriteconfig$v" >/dev/null && command -v "kreadconfig$v" >/dev/null; then
      _write="kwriteconfig$v"
      _read="kreadconfig$v"
      return
    fi
  done
}

# Parse INI file $1 into newline-separated "group<TAB>key<TAB>value" entries, where group keeps nested groups as
# "A][B". Skips blank lines, # and ; comments, and keys outside a group.
kde_parse_ini() {
  local file="$1" line group="" key value entries=""
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    case "$line" in
      ''|'#'*|';'*) ;;
      '['*']') group="${line#[}"; group="${group%]}" ;;
      *=*)
        [[ -n "$group" ]] || continue
        key="${line%%=*}"
        key="${key%"${key##*[![:space:]]}"}"
        value="${line#*=}"
        value="${value#"${value%%[![:space:]]*}"}"
        entries+="$group"$'\t'"$key"$'\t'"$value"$'\n'
        ;;
    esac
  done < "$file"
  _entries="$entries"
}

# Merge each partial KDE config file in KDE_CONFIG_FILES into its ~/.config counterpart with kwriteconfig.
#
# @machine any
# @os linux
# @gui kde
feature_kde() {
  local writer reader rel file entries group key value rest group_args
  f_write_args kde_config_tools _write _read --
  writer="$_write"
  reader="$_read"
  if [[ -z "$writer" ]]; then
    warn "kwriteconfig not found, skipping KDE settings."
    return
  fi

  for rel in "${KDE_CONFIG_FILES[@]}"; do
    file="$HOME/${rel#home/}"
    f_write_args kde_parse_ini _entries -- "$DOTFILES_ROOT/$rel"
    entries="$_entries"
    while IFS=$'\t' read -r group key value; do
      [[ -n "$key" ]] || continue
      # "A][B" becomes --group A --group B.
      group_args=()
      rest="$group"
      while [[ "$rest" == *']['* ]]; do
        group_args+=(--group "${rest%%][*}")
        rest="${rest#*][}"
      done
      group_args+=(--group "$rest")
      if [[ "$("$reader" --file "$file" "${group_args[@]}" --key "$key")" == "$value" ]]; then
        info "KDE ${rel##*/} [$group] $key already $value"
        continue
      fi
      info "Setting KDE ${rel##*/} [$group] $key=$value"
      # --notify lets running Plasma/KWin pick up the change; otherwise it applies at the next login.
      run "$writer" --notify --file "$file" "${group_args[@]}" --key "$key" "$value"
    done <<< "$entries"
  done
}
