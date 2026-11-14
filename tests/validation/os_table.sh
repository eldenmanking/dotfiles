#!/usr/bin/env bash
# Validate that the README's OS, Profile and Machine table lists exactly the combinations the code defines: for each
# OS in install/os, the profiles it supports (os_profiles), the machines it supports (os_config) and the variants
# naming it with their profiles (variant_config), so a new OS, profile, machine or variant can't be left out of the
# table. Run via `make validate`.

set -euo pipefail

# shellcheck source=../lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

INSTALL_DIR="$REPO_ROOT/install"
# Feature files read these at load time; point them at this checkout.
DOTFILES_ROOT="$REPO_ROOT"
BACKUPS_ROOT="$DOTFILES_ROOT/.backup"
LOCAL_PREFIX="$HOME/.local"
LOCAL_BIN="$LOCAL_PREFIX/bin"
DRY_RUN=true

for f in "$INSTALL_DIR"/lib/*.sh "$INSTALL_DIR"/features/*.sh "$INSTALL_DIR"/features/*/*.sh \
  "$INSTALL_DIR"/os/*.sh "$INSTALL_DIR"/profiles/*.sh "$INSTALL_DIR"/variants/*.sh; do
  # shellcheck source=/dev/null
  source "$f"
done

# Print the words of $1, one per line and sorted.
# Usage: sorted_words <words>
sorted_words() {
  local word
  for word in $1; do
    printf '%s\n' "$word"
  done | sort
}

# Print the table's rows from README.md, one per OS: the cells of each row separated by '|', with backticks removed
# and surrounding spaces trimmed, e.g. "arch|desktop, minimal|generic, framework16|arch (desktop)".
# Usage: table_rows
table_rows() {
  awk -F'|' '
    /^\| OS \| Profiles/ { in_table = 1; next }
    in_table && /^\|---/ { next }
    in_table && /^\| `/ {
      row = ""
      for (i = 2; i < NF; i++) {
        cell = $i
        gsub(/`/, "", cell)
        gsub(/^ +| +$/, "", cell)
        row = row (i > 2 ? "|" : "") cell
      }
      print row
      next
    }
    in_table { exit }
  ' "$REPO_ROOT/README.md"
}

# Find the variants of OS <os>.
# Usage: f_call os_variants variants -- <os>
# Returns: variants
#   variants: space-separated "name:profile" words
os_variants() {
  local os="$1" variants="" variant v_os v_profile
  for variant in $(available_names variants); do
    f_call variant_config v_os=os v_profile=profile -- "$variant"
    [[ "$v_os" != "$os" ]] || variants+="${variants:+ }$variant:$v_profile"
  done
  f_return variants
}

# Turn a README variants cell like "`portable` (minimal), `coder` (workspace)" (backticks already removed) into
# space-separated "name:profile" words.
# Usage: cell_variants <cell>
cell_variants() {
  printf '%s' "$1" | sed 's/ (\([a-z]*\))/:\1/g; s/, / /g'
}

# Check that column <column> of OS <os>'s README row lists the words <listed> the code defines, <defined>.
# Usage: f_call check_column problems -- <os> <column> <listed> <defined>
# Returns: problems
#   problems: a line if it doesn't
check_column() {
  local problems=""
  if [[ "$(sorted_words "$3")" != "$(sorted_words "$4")" ]]; then
    problems="README.md: OS table row '$1', $2: has '$3', but the code defines '$4'"$'\n'
  fi
  f_return problems
}

# Check README row <row> of OS <os> against the code.
# Usage: f_call check_row problems -- <os> <row>
#   <row>: empty if the table has no row for it
# Returns: problems
#   problems: a line for each way it differs
check_row() {
  local os="$1" row="$2" problems="" profiles="" machines="" variants="" found machines_want variants_want
  if [[ -z "$row" ]]; then
    f_return problems="README.md: the OS table has no row for '$os'"$'\n'
    return
  fi
  IFS='|' read -r _ profiles machines variants <<< "$row"
  f_call os_config machines_want=machines -- "$os"
  f_call os_variants variants_want=variants -- "$os"

  f_call check_column found=problems -- "$os" profiles "${profiles//,/}" "$(os_profiles "$os")"
  problems+="$found"
  f_call check_column found=problems -- "$os" machines "${machines//,/}" "$machines_want"
  problems+="$found"
  f_call check_column found=problems -- "$os" variants "$(cell_variants "$variants")" "$variants_want"
  problems+="$found"
  f_return problems
}

# Check the README's OS table against every OS, then fail with the problems found, if any.
# Usage: main
main() {
  local os row rows problems="" found listed
  rows="$(table_rows)"
  for os in $(available_names os); do
    row="$(printf '%s\n' "$rows" | awk -F'|' -v os="$os" '$1 == os')"
    f_call check_row found=problems -- "$os" "$row"
    problems+="$found"
  done
  while IFS='|' read -r listed _; do
    [[ -z "$listed" ]] || list_contains "$(available_names os)" "$listed" \
      || problems+="README.md: the OS table lists '$listed', which has no install/os/$listed.sh"$'\n'
  done <<< "$rows"

  if [[ -n "$problems" ]]; then
    printf '%s' "$problems" | while IFS= read -r line; do warn "$line"; done
    error "the README OS table is out of date"
  fi
  info "The README OS table matches the OSes, profiles, machines and variants."
}

main "$@"
