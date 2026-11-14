#!/usr/bin/env bash
# Lint the one-time installs in install/oti: every command that changes state (sed -i, mkdir, mount, ln, chmod,
# systemctl enable, mkfs, tee, > and >> redirects, ...) must go through the shown-command helpers of install/lib/exec.sh
# (run_shown, write_shown, ...), so it is printed and honors --dry-run. A bare one is reported unless its line ends in
# "# oti-ok: <reason>". Quoted text, [[ ]] and (( )) conditions and comments are not searched. This is a heuristic on
# the text, not a shell parser. Run via `make lint`.

set -euo pipefail

# shellcheck source=../lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

# Print "file:line: text" for each bare state-changing command in file $1.
# Usage: bare_state_changes <file>
bare_state_changes() {
  awk -v file="$1" '
    # Commands that change state, when they start a command (or follow sudo).
    BEGIN {
      cmds = "(sed[[:space:]]+(-[a-zA-Z]*i|--in-place)|mkdir|rmdir|mount|umount|swapon|swapoff|ln|chmod|chown|rm|mv|cp|"
      cmds = cmds "touch|tee|truncate|dd|mkfs[.a-z0-9]*|mkswap|wipefs|sfdisk|sgdisk|parted|partprobe|udevadm|pacstrap|"
      cmds = cmds "genfstab[[:space:]]+[^|;]*>|useradd|chpasswd|passwd|hwclock|timedatectl|locale-gen|grub-install|"
      cmds = cmds "grub-mkconfig|visudo|arch-chroot|btrfs[[:space:]]+(subvolume|filesystem)[[:space:]]+(create|mkswapfile)|"
      cmds = cmds "systemctl[[:space:]]+(enable|disable|start|stop|restart|mask|unmask)|git[[:space:]]+(clone|checkout|"
      cmds = cmds "remote[[:space:]]+set-url))"
      start = "(^|[;&|({]|[[:space:]](then|do|else)|&&|\\|\\|)[[:space:]]*(sudo[[:space:]]+)?"
    }
    /^[[:space:]]*#/ { next }
    {
      line = $0
      if (line ~ /#[[:space:]]*oti-ok:/) next
      gsub(/\$\{[^}]*\}/, "", line)
      # Drop quoted values, so that words in messages are not taken for commands, then trailing comments.
      gsub(/"([^"\\]|\\.)*"/, "\"\"", line)
      gsub(/\047[^\047]*\047/, "\047\047", line)
      sub(/(^|[[:space:]])#.*/, "", line)
      # Conditions compare with > and <, and $(( )) divides.
      gsub(/\[\[[^]]*\]\]/, "", line)
      gsub(/\$\(\([^)]*\)\)/, "", line)
      # Redirects that discard or duplicate output change nothing.
      gsub(/[0-9&]?>>?[[:space:]]*\/dev\/null/, "", line)
      gsub(/[0-9]?>&[0-9]/, "", line)
      gsub(/<<</, "", line)
      gsub(/>\(/, "", line)
      if (line ~ start cmds "([[:space:]]|$)" || line ~ />/) print file ":" FNR ": " $0
    }
  ' "$1"
}

# Check every one-time install, then fail if any has a bare state-changing command.
# Usage: main
main() {
  local failed=0 file found
  cd "$REPO_ROOT"
  info "One-time installs: state-changing commands go through the shown-command helpers"
  for file in install/oti/*.sh; do
    found="$(bare_state_changes "$file")"
    if [[ -n "$found" ]]; then
      warn "bare state-changing command (use run_shown, write_shown, ...; or end the line with '# oti-ok: <reason>'):"
      printf '%s\n' "$found" >&2
      failed=1
    fi
  done
  [[ "$failed" == 0 ]] || error "oti lint failed"
}

main "$@"
