# Command execution helpers that honor DRY_RUN.

# Detect whether a controlling terminal is actually usable (open succeeds).
# `[[ -r /dev/tty ]]` is unreliable: the file exists in non-interactive
# environments but fails to open with ENXIO.
has_tty() {
  (: < /dev/tty) 2>/dev/null
}

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
  if has_tty; then
    run "$@" < /dev/tty
  else
    run "$@"
  fi
}

# Prompt the user for a yes/no answer, returning 0 only for "y" or "Y" (reads
# from the controlling terminal so it works even when stdin is redirected).
confirm() {
  local reply
  read -p "$1 [y/N] " -r reply < /dev/tty
  [[ "$reply" =~ ^[Yy]$ ]]
}

# Replace ^pattern$ with replace in file (with backup) after user confirmation.
# Fourth arg is an optional sudo-style prefix for the copy.
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
      local tmp
      tmp="$(mktemp)"
      sed -E "s@^${pattern}\$@${replace}@" "$file" > "$tmp"
      ${user:+"$user"} cp "$tmp" "$file"
      rm -f "$tmp"
    fi
  elif ! grep -Eq "^${replace}\$" "$file"; then
    warn "Neither '$pattern' nor '$replace' were found in $file."
  fi
}

# Error unless every given command is available.
require_commands() {
  local cmd missing=""
  for cmd in "$@"; do
    command -v "$cmd" >/dev/null || missing+="${missing:+ }$cmd"
  done
  [[ -z "$missing" ]] || error "missing commands: $missing"
}

# --- Shown commands, for one-time installs (install/oti), which print every command they run ---

# Print args $@ as one shell command line, single-quoting the words that need it.
shell_words() {
  local word q="'" line=""
  for word in "$@"; do
    case "$word" in
      "" | *[!A-Za-z0-9_./:=@%+,-]*) word="$q${word//$q/$q\\$q$q}$q" ;;
    esac
    line+="${line:+ }$word"
  done
  printf '%s' "$line"
}

# Print command line $1 as [run], or as [dry-run] under --dry-run.
show_command() {
  if $DRY_RUN; then
    printf '\033[36m[dry-run]\033[0m %s\n' "$1"
  else
    printf '\033[36m[run]\033[0m %s\n' "$1"
  fi
}

# Print command $@, then run it (under --dry-run, only print it).
run_shown() {
  show_command "$(shell_words "$@")"
  $DRY_RUN || "$@"
}

# Like run_shown, with $1 (and a newline) as the command's input, shown as a here-document.
run_shown_input() {
  local input="$1"
  shift
  show_command "$(shell_words "$@") <<'EOF'"$'\n'"$input"$'\n'"EOF"
  $DRY_RUN || printf '%s\n' "$input" | "$@"
}

# Like run_shown_input with secret input $1, shown as $2 instead.
run_shown_secret() {
  local input="$1" shown="$2"
  shift 2
  show_command "$(shell_words "$@") <<< $(shell_words "$shown")"
  $DRY_RUN || printf '%s\n' "$input" | "$@"
}

# Like run_shown, with the command's output written to file $1.
run_shown_to() {
  local file="$1"
  shift
  show_command "$(shell_words "$@") > $(shell_words "$file")"
  $DRY_RUN || "$@" > "$file"
}

# Write $2 (and a newline) to file $1, shown as the cat that does it.
write_shown() {
  local file="$1" content="$2"
  show_command "cat > $(shell_words "$file") <<'EOF'"$'\n'"$content"$'\n'"EOF"
  $DRY_RUN || printf '%s\n' "$content" > "$file"
}

# Append $2 (and a newline) to file $1, shown as the cat that does it.
append_shown() {
  local file="$1" content="$2"
  show_command "cat >> $(shell_words "$file") <<'EOF'"$'\n'"$content"$'\n'"EOF"
  $DRY_RUN || printf '%s\n' "$content" >> "$file"
}

# Print read-only command $@ as [check] on stderr, so callers can capture its output, then run it, under --dry-run
# too. Its own errors are dropped: a failing check is an answer, not a problem.
probe() {
  printf '\033[2m[check] %s\033[0m\n' "$(shell_words "$@")" >&2
  "$@" 2>/dev/null
}
