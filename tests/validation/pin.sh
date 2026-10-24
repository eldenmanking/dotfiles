#!/usr/bin/env bash
# Validate install.sh's generated pin block: it is exactly what `make pin` (scripts/pin.sh) writes, names this repo (the
# one CI runs in, or origin locally), and pins either what main had before this change (the change leaves the pin alone)
# or main's tip before it (`make pin`, as the pin workflow commits after every push to main). See base_commit. Run via
# `make validate`; CI checks out full history so the commits can be found.

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

# Print main's tip before this change. In CI that is HEAD's first parent, the base tip of the merge commit a pull
# request is tested as, or main's previous tip on a push to main. Locally it is where HEAD meets origin/main, unless
# that is HEAD itself with nothing uncommitted (HEAD is the change, already on main), then HEAD's first parent. Prints
# nothing if that commit isn't here.
base_commit() {
  local base=""
  if [[ -z "${GITHUB_ACTIONS:-}" ]]; then
    base="$(git -C "$REPO_ROOT" merge-base HEAD origin/main 2>/dev/null || true)"
    if [[ "$base" == "$(git -C "$REPO_ROOT" rev-parse HEAD)" && -z "$(git -C "$REPO_ROOT" status --porcelain)" ]]; then
      base=""
    fi
  fi
  git -C "$REPO_ROOT" rev-parse --verify --quiet "${base:-HEAD^1}^{commit}" || true
}

main() {
  local failed=0 block repo commit expected base base_pin
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
  else
    base="$(base_commit)"
    if [[ -z "$base" ]]; then
      [[ -z "${CI:-}" ]] || { warn "can't find main's tip before HEAD"; failed=1; }
      warn "can't find main's tip before HEAD; skipping the check that PINNED_COMMIT is up to date"
    else
      base_pin="$(block_value PINNED_COMMIT "$(git -C "$REPO_ROOT" show "$base:install.sh" | current_block /dev/stdin)")"
      if [[ "$commit" != "$base_pin" && "$commit" != "$base" ]]; then
        warn "PINNED_COMMIT is $commit; leave it as main has it ($base_pin) or run 'make pin' ($base)"
        failed=1
      fi
    fi
  fi
  return "$failed"
}

main "$@"
