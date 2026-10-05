# Command execution helpers that honor dry_run.

# Detect whether a controlling terminal is actually usable (open succeeds).
# `[[ -r /dev/tty ]]` is unreliable: the file exists in non-interactive
# environments but fails to open with ENXIO.
has_tty() {
  (: < /dev/tty) 2>/dev/null
}

# Execute a command, or just announce it under --dry-run.
run() {
  local dry_run="$1"
  shift
  if $dry_run; then
    printf '\033[36m[dry-run]\033[0m %s\n' "$*"
  else
    "$@"
  fi
}

# Like run, but routes stdin from the controlling terminal when one exists.
# Used for commands like `pacman` that may prompt for confirmation; falls
# back to inherited stdin in non-interactive contexts (CI, nested scripts).
run_tty() {
  local dry_run="$1"
  shift
  if has_tty; then
    run "$dry_run" "$@" < /dev/tty
  else
    run "$dry_run" "$@"
  fi
}

# Prompt the user for a yes/no answer (reads from the controlling terminal so
# it works even when stdin is redirected).
confirm() {
  local reply
  read -p "$1 [Y/n] " -r reply < /dev/tty
  [[ "$reply" =~ ^[Yy]$ ]]
}

# Replace ^pattern$ with replace in file (with backup) after user confirmation.
# Fifth arg is an optional sudo-style prefix for the copy.
confirmsed() {
  local dry_run="$1" file="$2" pattern="$3" replace="$4" user="${5:-}"

  if [[ ! -f "$file" ]]; then
    warn "$file does not exist."
    return
  fi

  if grep -Eq "^${pattern}\$" "$file"; then
    if $dry_run; then
      info "[dry-run] would replace '$pattern' with '$replace' in $file"
      return
    fi
    if confirm "Edit $file to replace '$pattern' with '$replace'?"; then
      mkdir -pv "$(dirname "$BACKUPS_ROOT$file")"
      cp -nvi "$file" "$BACKUPS_ROOT$file" < /dev/tty
      local tmp
      tmp="$(mktemp)"
      sed -E "s@^${pattern}\$@${replace}@" "$file" > "$tmp"
      $user cp "$tmp" "$file"
      rm -f "$tmp"
    fi
  elif ! grep -Eq "^${replace}\$" "$file"; then
    warn "Neither '$pattern' nor '$replace' were found in $file."
  fi
}
