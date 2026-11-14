# Command execution helpers that honor DRY_RUN.

# Detect whether a controlling terminal is actually usable (open succeeds).
# `[[ -r /dev/tty ]]` is unreliable: the file exists in non-interactive
# environments but fails to open with ENXIO.
# Usage: has_tty
has_tty() {
  (: < /dev/tty) 2>/dev/null
}

# Execute a command, or just announce it under --dry-run.
# Usage: run <command> [<arg>...]
run() {
  if $DRY_RUN; then
    show_command "$(shell_words "$@")"
  else
    "$@"
  fi
}

# Like run, but routes stdin from the controlling terminal when one exists.
# Used for commands like `pacman` that may prompt for confirmation; falls
# back to inherited stdin in non-interactive contexts (CI, nested scripts).
# Usage: run_tty <command> [<arg>...]
run_tty() {
  if has_tty; then
    run "$@" < /dev/tty
  else
    run "$@"
  fi
}

# Prompt the user for a yes/no answer, returning 0 only for "y" or "Y" (reads
# from the controlling terminal so it works even when stdin is redirected).
# Usage: confirm <prompt>
confirm() {
  local reply
  read -p "$1 [y/N] " -r reply < /dev/tty
  [[ "$reply" =~ ^[Yy]$ ]]
}

# Error unless every given command is available.
# Usage: require_commands <command>...
require_commands() {
  local cmd missing=""
  for cmd in "$@"; do
    command -v "$cmd" >/dev/null || missing+="${missing:+ }$cmd"
  done
  [[ -z "$missing" ]] || error "missing commands: $missing"
}

# --- Shown commands, for one-time installs (install/oti), which print every command they run ---

# Print args $@ as one shell command line, single-quoting the words that need it.
# Usage: shell_words [<word>...]
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

# Print "[info] [dry-run] would $*": what a --dry-run skipped, as a sentence rather than a command.
# Usage: info_dry_run <words>...
info_dry_run() {
  info "[dry-run] would $*"
}

# Print command line $1 as [run], or as [dry-run] under --dry-run.
# Usage: show_command <command_line>
show_command() {
  if $DRY_RUN; then
    printf '\033[36m[dry-run]\033[0m %s\n' "$1"
  else
    printf '\033[36m[run]\033[0m %s\n' "$1"
  fi
}

# Print command $@, then run it (under --dry-run, only print it).
# Usage: run_shown <command> [<arg>...]
run_shown() {
  show_command "$(shell_words "$@")"
  $DRY_RUN || "$@"
}

# Like run_shown, with $1 (and a newline) as the command's input, shown as a here-document.
# Usage: run_shown_input <input> <command> [<arg>...]
run_shown_input() {
  local input="$1"
  shift
  show_command "$(shell_words "$@") <<'EOF'"$'\n'"$input"$'\n'"EOF"
  $DRY_RUN || printf '%s\n' "$input" | "$@"
}

# Like run_shown_input with secret input $1, shown as $2 instead.
# Usage: run_shown_secret <input> <shown> <command> [<arg>...]
run_shown_secret() {
  local input="$1" shown="$2"
  shift 2
  show_command "$(shell_words "$@") <<< $(shell_words "$shown")"
  $DRY_RUN || printf '%s\n' "$input" | "$@"
}

# Like run_shown, with the command's output written to file $1.
# Usage: run_shown_to <file> <command> [<arg>...]
run_shown_to() {
  local file="$1"
  shift
  show_command "$(shell_words "$@") > $(shell_words "$file")"
  $DRY_RUN || "$@" > "$file"
}

# Write $2 (and a newline) to file $1, shown as the cat that does it.
# Usage: write_shown <file> <content>
write_shown() {
  local file="$1" content="$2"
  show_command "cat > $(shell_words "$file") <<'EOF'"$'\n'"$content"$'\n'"EOF"
  $DRY_RUN || printf '%s\n' "$content" > "$file"
}

# Append $2 (and a newline) to file $1, shown as the cat that does it.
# Usage: append_shown <file> <content>
append_shown() {
  local file="$1" content="$2"
  show_command "cat >> $(shell_words "$file") <<'EOF'"$'\n'"$content"$'\n'"EOF"
  $DRY_RUN || printf '%s\n' "$content" >> "$file"
}

# Print read-only command $@ as [check] on stderr, so callers can capture its output, then run it, under --dry-run
# too. Its own errors are dropped: a failing check is an answer, not a problem.
# Usage: probe <command> [<arg>...]
probe() {
  printf '\033[2m[check] %s\033[0m\n' "$(shell_words "$@")" >&2
  "$@" 2>/dev/null
}
