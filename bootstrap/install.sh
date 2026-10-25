#!/usr/bin/env bash

################################################################################
# Program: install.sh (bootstrap)
# Description: Clones the dotfiles repo at the commit pinned below into
#              ~/dotfiles, unless that exists, then runs its install.sh with
#              the same arguments. The install branch holds this script with
#              the pin filled in by scripts/bootstrap.sh; this copy on main is
#              its template, with an empty pin. See README.md, Installation.
# Usage: bash -c "$(curl -fsSL <raw URL of install.sh on the install branch>)" -- ARGS
################################################################################

set -euo pipefail

# BEGIN GENERATED PIN: written by scripts/bootstrap.sh
PINNED_REPO=""
PINNED_COMMIT=""
# END GENERATED PIN

DOTFILES_ROOT="$HOME/dotfiles"

# Print an error and exit.
die() {
  printf '[error] %s\n' "$*" >&2
  exit 1
}

# Clone PINNED_REPO into $DOTFILES_ROOT and check out PINNED_COMMIT, on the repo's default branch so it can be pulled
# later (detached if the repo's HEAD is).
clone_pinned() {
  local branch checkout_args=(--detach)
  command -v git >/dev/null || die "git is required to clone $PINNED_REPO"
  printf '[info] Cloning %s at %s into %s\n' "$PINNED_REPO" "$PINNED_COMMIT" "$DOTFILES_ROOT"
  git -c advice.detachedHead=false clone --quiet "$PINNED_REPO" "$DOTFILES_ROOT"
  branch="$(git -C "$DOTFILES_ROOT" symbolic-ref --short -q HEAD || true)"
  [[ -z "$branch" ]] || checkout_args=(-B "$branch")
  git -C "$DOTFILES_ROOT" checkout --quiet "${checkout_args[@]}" "$PINNED_COMMIT" \
    || die "$PINNED_REPO has no commit $PINNED_COMMIT"
}

# Stdin is reattached to the terminal when it isn't one (as with 'curl ... | bash -s -- ARGS'), so features that prompt
# still can.
main() {
  [[ -n "$PINNED_REPO" && -n "$PINNED_COMMIT" ]] \
    || die "this is the bootstrap's template; use the install.sh on the install branch (see README.md)"
  if [[ -e "$DOTFILES_ROOT" || -L "$DOTFILES_ROOT" ]]; then
    printf '[info] %s already exists; running its install.sh as it is\n' "$DOTFILES_ROOT"
  else
    clone_pinned
  fi
  [[ -f "$DOTFILES_ROOT/install.sh" ]] || die "$DOTFILES_ROOT exists but has no install.sh; move it aside and re-run."

  if [[ ! -t 0 ]] && { : </dev/tty; } 2>/dev/null; then
    exec bash "$DOTFILES_ROOT/install.sh" "$@" </dev/tty
  fi
  exec bash "$DOTFILES_ROOT/install.sh" "$@"
}

main "$@"
