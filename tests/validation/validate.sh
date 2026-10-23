#!/usr/bin/env bash
# Validate the repo's structure, which must keep holding as files are added, moved or removed: the checkout is named
# dotfiles, the README tree matches the tracked files, and tests/versions.env pins a SHA-256 for every tool on every
# platform. Run via `make validate`.

set -euo pipefail

# shellcheck source=../lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

# Platforms pinned_tool downloads for, as detect_os_arch names them.
PLATFORMS="linux_x86_64 linux_arm64 macos_x86_64 macos_arm64"

# Print each <TOOL>_SHA256_<platform> that tests/versions.env is missing or that isn't a SHA-256, for every tool it
# pins a <TOOL>_VERSION of.
missing_checksums() {
  local tool platform var
  while IFS= read -r tool; do
    for platform in $PLATFORMS; do
      var="${tool}_SHA256_$platform"
      [[ "${!var:-}" =~ ^[0-9a-f]{64}$ ]] || printf '%s\n' "$var"
    done
  done < <(sed -n 's/^\([A-Z]*\)_VERSION=.*/\1/p' "$TEST_DIR/versions.env")
}

main() {
  local failed=0 missing
  cd "$REPO_ROOT"

  info "checkout is a directory named dotfiles"
  if [[ "$(basename "$(pwd -P)")" != dotfiles ]]; then
    warn "the checkout is $(pwd -P); install.sh and lint require a directory named dotfiles"
    failed=1
  fi

  info "README.md tree matches the tracked files"
  if have_or_skip python3 "the README.md tree check"; then
    python3 tests/validation/readme_tree.py || failed=1
  fi

  info "tests/versions.env pins a SHA-256 for every tool and platform"
  missing="$(missing_checksums)"
  if [[ -n "$missing" ]]; then
    warn "missing or not a SHA-256: ${missing//$'\n'/ }"
    failed=1
  fi

  info "features suit their variants and run after the features they require"
  tests/validation/features.sh || failed=1

  [[ "$failed" == 0 ]] || error "validation failed"
  info "validation passed"
}

main "$@"
