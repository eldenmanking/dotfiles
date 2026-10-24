#!/usr/bin/env bash
# Validate install.sh's generated pin block: it is exactly what `make pin` (scripts/pin.sh) writes, names this repo (the
# one CI runs in, or origin locally), and pins a commit that exists and is an ancestor of HEAD, so a curl install gets
# a commit that has been on main. Run via `make validate`; CI checks out full history so the commit can be found.

set -euo pipefail

# shellcheck source=../lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

PIN_SH="$REPO_ROOT/scripts/pin.sh"

# Print the pin block of file $1: the lines from its BEGIN GENERATED PIN line to its END GENERATED PIN line.
current_block() {
  sed -n '/^# BEGIN GENERATED PIN/,/^# END GENERATED PIN$/p' "$1"
}

# Print the value assigned to variable $1 in block $2, or nothing.
block_value() {
  sed -n "s/^$1=\"\\(.*\\)\"\$/\\1/p" <<< "$2"
}

# Print the repo the pin must name: the GitHub repo CI runs in, else origin's URL, normalized.
expected_repo() {
  if [[ -n "${GITHUB_REPOSITORY:-}" ]]; then
    printf '%s/%s.git' "${GITHUB_SERVER_URL:-https://github.com}" "$GITHUB_REPOSITORY"
  else
    "$PIN_SH" --origin 2>/dev/null || true
  fi
}

main() {
  local failed=0 block repo commit expected
  block="$(current_block "$REPO_ROOT/install.sh")"
  repo="$(block_value PINNED_REPO "$block")"
  commit="$(block_value PINNED_COMMIT "$block")"

  if [[ "$block" != "$("$PIN_SH" --print "$repo" "$commit")" ]]; then
    warn "install.sh's pin block isn't what 'make pin' writes; run 'make pin'. It is:"
    printf '%s\n' "$block" >&2
    return 1
  fi
  [[ "$commit" =~ ^[0-9a-f]{40}$ ]] || { warn "PINNED_COMMIT '$commit' is not a full commit hash"; failed=1; }

  expected="$(expected_repo)"
  if [[ -z "$expected" ]]; then
    [[ -z "${CI:-}" ]] || { warn "can't tell which repo CI runs in"; failed=1; }
    warn "no origin remote; skipping the check that PINNED_REPO is this repo"
  elif [[ "$repo" != "$expected" ]]; then
    warn "PINNED_REPO is $repo, but this repo is $expected; run 'make pin'"
    failed=1
  fi

  if ! git -C "$REPO_ROOT" cat-file -e "$commit^{commit}" 2>/dev/null; then
    if [[ -z "${CI:-}" && "$(git -C "$REPO_ROOT" rev-parse --is-shallow-repository)" == true ]]; then
      warn "PINNED_COMMIT $commit isn't in this shallow clone; skipping its checks (git fetch --unshallow to run them)"
    else
      warn "PINNED_COMMIT $commit doesn't exist in this repo; run 'make pin'"
      failed=1
    fi
  elif ! git -C "$REPO_ROOT" merge-base --is-ancestor "$commit" HEAD; then
    warn "PINNED_COMMIT $commit is not an ancestor of HEAD; run 'make pin'"
    failed=1
  fi
  return "$failed"
}

main "$@"
