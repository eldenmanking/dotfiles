#!/usr/bin/env bash
# Write the repo and commit that install.sh clones when run outside a checkout (e.g. with curl) into its generated pin
# block. Run via `make pin`, then commit install.sh. The pinned commit must already be on main, since a file can't name
# the commit that adds it: by default it is origin/main's tip, fetched first. tests/validation/pin.sh (make validate)
# checks the block.
#
# Usage: scripts/pin.sh [--commit REV] [--repo URL]   write the block (repo defaults to origin, normalized)
#        scripts/pin.sh --print REPO COMMIT           print the block for REPO and COMMIT
#        scripts/pin.sh --origin                      print origin's URL, normalized

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_SH="$REPO_ROOT/install.sh"
PIN_BEGIN="# BEGIN GENERATED PIN: run 'make pin' to update; checked by 'make validate'"
PIN_END="# END GENERATED PIN"

# shellcheck source=../install/lib/output.sh
source "$REPO_ROOT/install/lib/output.sh"

# Print git URL $1 as https://<host>/<path>.git, so the ssh and https forms of a repo compare equal.
normalize_repo_url() {
  local url="${1%/}"
  url="${url%.git}"
  case "$url" in
    *://*) url="${url#*://}"; url="${url#*@}" ;;
    *@*:*) url="${url#*@}"; url="${url/://}" ;;
    *)     printf '%s' "$1"; return ;;
  esac
  printf 'https://%s.git' "$url"
}

# Print the pin block for repo $1 and commit $2.
pin_block() {
  printf '%s\n' "$PIN_BEGIN"
  printf 'PINNED_REPO="%s"\n' "$1"
  printf 'PINNED_COMMIT="%s"\n' "$2"
  printf '%s\n' "$PIN_END"
}

# Replace the pin block in file $1 with the one for repo $2 and commit $3.
write_pin_block() {
  local file="$1" tmp
  [[ "$(grep -cxF "$PIN_BEGIN" "$file")" == 1 && "$(grep -cxF "$PIN_END" "$file")" == 1 ]] \
    || error "$file needs exactly one pin block ('$PIN_BEGIN' ... '$PIN_END')"
  tmp="$(mktemp)"
  awk -v begin="$PIN_BEGIN" -v end="$PIN_END" -v block="$(pin_block "$2" "$3")" '
    $0 == begin { print block; skip = 1; next }
    $0 == end { skip = 0; next }
    !skip
  ' "$file" > "$tmp"
  cat "$tmp" > "$file"
  rm -f "$tmp"
}

main() {
  local repo="" rev="" commit
  case "${1:-}" in
    --print)  [[ $# -eq 3 ]] || error "usage: $0 --print REPO COMMIT"; pin_block "$2" "$3"; return ;;
    --origin) normalize_repo_url "$(git -C "$REPO_ROOT" remote get-url origin)"; return ;;
  esac
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --commit) [[ $# -ge 2 ]] || error "--commit requires a value"; rev="$2"; shift 2 ;;
      --repo)   [[ $# -ge 2 ]] || error "--repo requires a value"; repo="$2"; shift 2 ;;
      *)        error "Unexpected argument: $1" ;;
    esac
  done

  [[ -n "$repo" ]] || repo="$(normalize_repo_url "$(git -C "$REPO_ROOT" remote get-url origin)")"
  if [[ -z "$rev" ]]; then
    git -C "$REPO_ROOT" fetch --quiet origin main || warn "could not fetch origin main; using the local origin/main"
    rev=origin/main
  fi
  commit="$(git -C "$REPO_ROOT" rev-parse --verify --quiet "$rev^{commit}")" || error "no such commit: $rev"
  git -C "$REPO_ROOT" merge-base --is-ancestor "$commit" HEAD \
    || warn "$commit is not an ancestor of HEAD; make validate will fail until HEAD contains it"

  write_pin_block "$INSTALL_SH" "$repo" "$commit"
  info "install.sh pins $repo at $commit"
}

main "$@"
