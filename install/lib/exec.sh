# TODO(andywang): add comment

# Detect whether a controlling terminal is actually usable (open succeeds).
# `[[ -r /dev/tty ]]` is unreliable: the file exists in non-interactive
# environments but fails to open with ENXIO.
if (: < /dev/tty) 2>/dev/null; then
  HAS_TTY=true
else
  HAS_TTY=false
fi

# Execute a command, or just announce it under --dry-run.
run() {
  if $DRY_RUN; then
    printf '\033[36m[dry-run]\033[0m %s\n' "$*"
  else
    "$@"
  fi
}

# Like run, but routes stdin from the controlling terminal when one exists.
# Used for commands like `pacman` that may prompt for confirmation; falls
# back to inherited stdin in non-interactive contexts (CI, nested scripts).
run_tty() {
  if $HAS_TTY; then
    run "$@" < /dev/tty
  else
    run "$@"
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
# Fourth arg is an optional sudo-style prefix for the sed call.
confirmsed() {
  local file="$1" pattern="$2" replace="$3" user="${4:-}"

  if [[ ! -f "$file" ]]; then
    warn "$file does not exist."
    return
  fi

  if grep -Eq "^${pattern}\$" "$file"; then
    if $DRY_RUN; then
      info "[dry-run] would replace '$pattern' with '$replace' in $file"
      return
    fi
    if confirm "Edit $file to replace '$pattern' with '$replace'?"; then
      mkdir -pv "$(dirname "$BACKUPS_ROOT$file")"
      cp -nvi "$file" "$BACKUPS_ROOT$file" < /dev/tty
      $user sed -Ei "s@^${pattern}\$@${replace}@" "$file"
    fi
  elif ! grep -Eq "^${replace}\$" "$file"; then
    warn "Neither '$pattern' nor '$replace' were found in $file."
  fi
}
