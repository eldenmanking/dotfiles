# Helpers for --capture, which copies settings from this system into the repo's files.

# Print the settings file on stdin (an INI-style file: a dconf dump or a KDE config file) with only the keys that the
# entries in the arguments select, and without the groups left empty. A key's path is its group and its name joined
# with /, e.g. org/gnome/desktop/interface/color-scheme or Keyboard/RepeatDelay (KDE's nested groups, [A][B], keep
# their brackets: A][B/key). An entry ending in / selects every key whose path starts with it (for dconf, a directory with its
# subdirectories; for KDE, a group), any other entry the one key it names, and an entry starting with ! leaves out what it names, wherever it is in the list.
# Usage: capture_filter [<entry>...]
capture_filter() {
  local IFS=$'\n'
  awk -v entries="$*" '
    function selected(path,   n, i, e, list, picked) {
      n = split(entries, list, "\n")
      picked = 0
      for (i = 1; i <= n; i++) {
        e = list[i]
        if (substr(e, 1, 1) == "!") {
          if (covers(substr(e, 2), path)) return 0
        } else if (covers(e, path)) {
          picked = 1
        }
      }
      return picked
    }
    # Entry e (a directory ending in /, or a key) covers key path p.
    function covers(e, p) {
      return substr(e, length(e)) == "/" ? index(p, e) == 1 : p == e
    }
    /^\[.*\]$/ { group = substr($0, 2, length($0) - 2); header = $0; next }
    index($0, "=") > 0 {
      if (!selected(group "/" substr($0, 1, index($0, "=") - 1))) next
      if (header != "") { if (printed) print ""; print header; header = ""; printed = 1 }
      print
    }
  '
}


# Write text $2 into the repo's file $1, or under --dry-run print the change as a diff. Leaves an unchanged file alone.
# Usage: write_captured <file> <text>
write_captured() {
  local file="$1" text="$2"
  if [[ -f "$file" && "$text" == "$(cat "$file")" ]]; then
    info "${file#"$DOTFILES_ROOT/"} already matches this system"
  elif $DRY_RUN; then
    info "[dry-run] would update ${file#"$DOTFILES_ROOT/"}:"
    diff -u "$file" <(printf '%s\n' "$text") || true
  else
    printf '%s\n' "$text" > "$file"
    info "Updated ${file#"$DOTFILES_ROOT/"}; review it with: git -C $DOTFILES_ROOT diff"
  fi
}
