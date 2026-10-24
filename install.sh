#!/usr/bin/env bash

################################################################################
# Program: install.sh
# Description: Installs essential packages for configuration and creates
#              symlinks in the proper locations. Supports several variants
#              (see install/variants/) and toggles features with flags.
# Location: ~/dotfiles/install.sh
################################################################################

set -euo pipefail

# The repo and commit cloned when install.sh runs outside a checkout (e.g. with curl), unless DOTFILES_REPO or
# DOTFILES_REF is set. PINNED_COMMIT is already on main, since a file can't name the commit that adds it.
# BEGIN GENERATED PIN: run 'make pin' to update; checked by 'make validate'
PINNED_REPO="https://github.com/eldenmanking/dotfiles.git"
PINNED_COMMIT="0bbd5caa343b1ac80d7cf81416fa43840d1577eb"
# END GENERATED PIN

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" && pwd)"
INSTALL_DIR="$SCRIPT_DIR/install"
DOTFILES_ROOT="$HOME/dotfiles"
DOTFILES_REPO="${DOTFILES_REPO:-$PINNED_REPO}"
BACKUPS_ROOT="$DOTFILES_ROOT/.backup"
LOCAL_PREFIX="$HOME/.local"
LOCAL_BIN="$LOCAL_PREFIX/bin"
INSTALL_CONFIG="${DOTFILES_INSTALL_CONFIG:-$HOME/.config/dotfiles/install.conf}"

# When run without its install/ directory beside it (e.g. fetched with curl), clone the repo to $DOTFILES_ROOT unless
# it is already there, then re-run its install.sh with the same arguments. A clone of PINNED_REPO without DOTFILES_REF
# checks out PINNED_COMMIT on the default branch, so it can still be pulled (detached if the repo's HEAD is detached,
# as in a CI checkout). Runs before install/lib is loaded, so it
# prints its own messages. Stdin is reattached to the terminal when it isn't one (as with 'curl ... | bash -s -- ARGS'),
# so features that prompt still can.
bootstrap() {
  local pinned=false branch checkout_args
  if [[ -f "$INSTALL_DIR/lib/fn.sh" ]]; then
    clone_checkout_to_root "$@"
    return 0
  fi

  if [[ ! -e "$DOTFILES_ROOT" ]]; then
    command -v git >/dev/null || { printf '[error] git is required to clone %s\n' "$DOTFILES_REPO" >&2; exit 1; }
    [[ -n "${DOTFILES_REF:-}" || "$DOTFILES_REPO" != "$PINNED_REPO" ]] || pinned=true
    printf '[info] Cloning %s%s into %s\n' "$DOTFILES_REPO" \
      "$($pinned && printf ' at %s' "$PINNED_COMMIT")${DOTFILES_REF:+ at $DOTFILES_REF}" "$DOTFILES_ROOT"
    git -c advice.detachedHead=false clone --quiet ${DOTFILES_REF:+--branch "$DOTFILES_REF"} "$DOTFILES_REPO" "$DOTFILES_ROOT"
    if $pinned; then
      branch="$(git -C "$DOTFILES_ROOT" symbolic-ref --short -q HEAD || true)"
      checkout_args=(--detach)
      [[ -z "$branch" ]] || checkout_args=(-B "$branch")
      git -C "$DOTFILES_ROOT" checkout --quiet "${checkout_args[@]}" "$PINNED_COMMIT" \
        || { printf '[error] %s has no commit %s\n' "$DOTFILES_REPO" "$PINNED_COMMIT" >&2; exit 1; }
    fi
  fi
  [[ -f "$DOTFILES_ROOT/install.sh" ]] \
    || { printf '[error] %s exists but has no install.sh; move it aside and re-run.\n' "$DOTFILES_ROOT" >&2; exit 1; }

  if [[ ! -t 0 ]] && { : </dev/tty; } 2>/dev/null; then
    exec bash "$DOTFILES_ROOT/install.sh" "$@" </dev/tty
  fi
  exec bash "$DOTFILES_ROOT/install.sh" "$@"
}

# When run from a git checkout elsewhere (e.g. Coder's ~/.config/coderv2/dotfiles) and $DOTFILES_ROOT doesn't exist,
# clone that checkout's current commit to $DOTFILES_ROOT, point its origin at the checkout's origin, then re-run its
# install.sh with the same arguments. Uncommitted changes aren't copied. Anything else is left to enter_dotfiles_root.
clone_checkout_to_root() {
  local top head branch origin
  [[ ! -e "$DOTFILES_ROOT" && ! -L "$DOTFILES_ROOT" ]] || return 0
  command -v git >/dev/null || return 0
  top="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)" || return 0
  [[ "$(cd "$top" && pwd -P)" == "$(cd "$SCRIPT_DIR" && pwd -P)" ]] || return 0

  head="$(git -C "$SCRIPT_DIR" rev-parse HEAD)"
  branch="$(git -C "$SCRIPT_DIR" symbolic-ref --short -q HEAD || true)"
  origin="$(git -C "$SCRIPT_DIR" remote get-url origin 2>/dev/null || true)"
  [[ -z "$(git -C "$SCRIPT_DIR" status --porcelain)" ]] \
    || printf '[warn] %s has uncommitted changes, which are not copied to %s\n' "$SCRIPT_DIR" "$DOTFILES_ROOT" >&2
  printf '[info] Cloning %s (%s) into %s\n' "$SCRIPT_DIR" "${branch:-${head:0:12}}" "$DOTFILES_ROOT"
  git -c advice.detachedHead=false clone --quiet --no-checkout "$SCRIPT_DIR" "$DOTFILES_ROOT"
  if [[ -n "$branch" ]]; then
    git -C "$DOTFILES_ROOT" checkout --quiet -B "$branch" "$head"
  else
    git -C "$DOTFILES_ROOT" checkout --quiet --detach "$head"
  fi
  [[ -z "$origin" ]] || git -C "$DOTFILES_ROOT" remote set-url origin "$origin"
  exec bash "$DOTFILES_ROOT/install.sh" "$@"
}

# Source install/lib, features and variants. They only define functions and constants, so their globals stay global.
load_install_deps() {
  local f
  for f in "$INSTALL_DIR"/lib/*.sh "$INSTALL_DIR"/features/*.sh "$INSTALL_DIR"/variants/*.sh; do
    # shellcheck source=/dev/null
    source "$f"
  done
}

available_variants() {
  local f names=""
  for f in "$INSTALL_DIR"/variants/*.sh; do
    f="$(basename "$f" .sh)"
    names+="${names:+ }$f"
  done
  printf '%s' "$names"
}

# Print feature $1's --help line, with the features it requires.
usage_feature() {
  f_write_args feature_requirements _machine _os _gui _requires -- "$1"
  printf '  --%-14s %s%s\n' "$1" "$(feature_description "$1")" "${_requires:+ (requires: --${_requires// / --})}"
}

usage() {
  local variant="$1" v features optional uninstallable=""
  cat <<EOF
Usage: $(basename "$0") [--variant NAME] [OPTIONS]

dotfiles installation and configuration script. All operations are idempotent.
Run '$(basename "$0") --variant NAME --help' to list the options of a variant.
Without --variant, DOTFILES_VARIANT names the variant; without options,
DOTFILES_FEATURES lists them (feature names, or all for --all). Set them in
the environment or in $INSTALL_CONFIG.
See README.md for more information.

Variants:
EOF
  for v in $(available_variants); do
    f_write_args variant_config _description -- "$v"
    printf '  %-10s %s\n' "$v" "$_description"
  done
  variant_exists "$variant" || return 0

  f_write_args variant_config _features _optional -- "$variant"
  features="$_features"
  optional="$_optional"
  cat <<EOF

Options for variant '$variant':
  --variant NAME   select the variant
  --all            install all default options
EOF
  for v in $features; do
    feature_uninstallable "$v" && uninstallable+="${uninstallable:+ }$v"
    list_contains "$optional" "$v" || usage_feature "$v"
  done
  if [[ -n "$optional" ]]; then
    printf '\nOptional (not included in --all):\n'
    for v in $optional; do
      usage_feature "$v"
    done
    echo
  fi
  if [[ -n "$uninstallable" ]]; then
    printf '  --%-14s %s (%s)\n' reinstall "uninstall the selected options, then install them" "$uninstallable"
    printf '  --%-14s %s (%s)\n' uninstall "uninstall the selected options" "$uninstallable"
  fi
  cat <<EOF
  --dry-run        print what would happen without making changes
  --help           show this help page
EOF
}

usage_error() {
  local message="$1" variant="${2:-}"
  warn "$message"
  usage "$variant" >&2
  exit 1
}

parse_args() {
  local variant="" flags=" " mode=install all=false dry_run=false help=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --variant)
        [[ $# -ge 2 ]] || usage_error "--variant requires a value"
        variant="$2"
        shift 2
        ;;
      --variant=*) variant="${1#--variant=}"; shift ;;
      --all)       all=true; shift ;;
      --dry-run)   dry_run=true; shift ;;
      --reinstall|--uninstall)
        [[ "$mode" == install || "$mode" == "${1#--}" ]] \
          || usage_error "--reinstall and --uninstall are mutually exclusive"
        mode="${1#--}"
        shift
        ;;
      --help|-h)   help=true; shift ;;
      --?*)        flags+="${1#--} "; shift ;;
      *)           usage_error "Unexpected argument: $1" ;;
    esac
  done

  _variant="$variant"
  _flags="$flags"
  _mode="$mode"
  _all="$all"
  _dry_run="$dry_run"
  _help="$help"
}

# Outputs: _default_variant and _default_features, from DOTFILES_VARIANT and DOTFILES_FEATURES in the environment or,
# for each one unset there, in config file $1. The file is sourced in a subshell so it can't change this shell's state.
load_install_defaults() {
  local conf="$1" file_variant="" file_features=""
  if [[ -f "$conf" ]]; then
    { IFS= read -r -d '' file_variant && IFS= read -r -d '' file_features; } < <(
      unset DOTFILES_VARIANT DOTFILES_FEATURES
      # shellcheck source=/dev/null
      source "$conf" >&2 || exit 1
      printf '%s\0%s\0' "${DOTFILES_VARIANT:-}" "${DOTFILES_FEATURES:-}"
    ) || error "Could not read $conf"
  fi
  _default_variant="${DOTFILES_VARIANT:-$file_variant}"
  _default_features="${DOTFILES_FEATURES:-$file_features}"
}

# Outputs: _variant, _flags and _all, the parsed variant $1, flags $2 and --all $3 with the defaults applied. Default
# variant $5 is used when no --variant was given. Default features $6 (feature names, and all for --all) are used when
# the command line selects none, unless mode $4 is uninstall or the command line names a variant other than $5.
apply_install_defaults() {
  local variant="$1" flags="$2" all="$3" mode="$4" default_variant="$5" default_features="$6" word
  [[ -n "$variant" ]] || variant="$default_variant"
  if [[ "$flags" == " " ]] && ! $all && [[ "$mode" != uninstall ]] \
    && [[ -z "$default_variant" || "$variant" == "$default_variant" ]]; then
    for word in $default_features; do
      word="${word#--}"
      if [[ "$word" == all ]]; then all=true; else flags+="$word "; fi
    done
  fi
  _variant="$variant"
  _flags="$flags"
  _all="$all"
}

# Print usage and exit unless variant $1 can run: with no variant, or with no features selected ($2 flags, $3 --all)
# or --help ($4). Without a variant this is an error unless --help was given or there were no arguments ($5).
exit_with_usage_unless_runnable() {
  local variant="$1" flags="$2" all="$3" help="$4" no_args="$5"
  if [[ -z "$variant" ]]; then
    $help || $no_args || usage_error "--variant is required"
    usage ""
    exit 0
  fi
  variant_exists "$variant" \
    || usage_error "Unknown variant '$variant'. Available variants: $(available_variants)"
  if $help || { [[ "$flags" == " " ]] && ! $all; }; then
    usage "$variant"
    exit 0
  fi
}

# Outputs: _enabled, the selected features. Under --uninstall, features
# without an uninstall function are dropped (with a warning if named).
resolve_features() {
  local variant="$1" flags="$2" all="$3" mode="$4" features optional enabled=" " k

  f_write_args variant_config _features _optional -- "$variant"
  features="$_features"
  optional="$_optional"

  for k in $flags; do
    list_contains "$features" "$k" \
      || usage_error "Unknown option for variant '$variant': --$k" "$variant"
  done
  for k in $features; do
    if list_contains "$flags" "$k" || { $all && ! list_contains "$optional" "$k"; }; then
      if [[ "$mode" != install ]] && ! feature_uninstallable "$k"; then
        if list_contains "$flags" "$k"; then
          if [[ "$mode" == uninstall ]]; then
            warn "--$k has no uninstall step; skipping it"
          else
            warn "--$k has no uninstall step; installing it without uninstalling first"
          fi
        fi
        [[ "$mode" == uninstall ]] && continue
      fi
      enabled+="$k "
    fi
  done

  _enabled="$enabled"
}

# Print why install.sh in $1 can't install from $2, or nothing if it can. Everything it links points into $2, so it
# must run from that checkout ($2 may be a symlink to it), and the checkout must be named dotfiles, which the startup
# files and lint (.shellcheckrc) rely on.
explain_checkout_problem() {
  local script_dir="$1" root="$2" script_real root_real
  script_real="$(cd "$script_dir" && pwd -P)"
  if [[ ! -d "$root" ]]; then
    printf 'dotfiles must be checked out at %s' "$root"
    return
  fi
  root_real="$(cd "$root" && pwd -P)"
  if [[ "$script_real" != "$root_real" ]]; then
    printf 'this checkout (%s) is not %s (%s); run %s/install.sh instead' "$script_real" "$root" "$root_real" "$root"
  elif [[ "${root_real##*/}" != dotfiles ]]; then
    printf "the checkout must be a directory named dotfiles, not '%s' (%s links to %s)" \
      "${root_real##*/}" "$root" "$root_real"
  fi
}

enter_dotfiles_root() {
  local problem
  problem="$(explain_checkout_problem "$SCRIPT_DIR" "$DOTFILES_ROOT")"
  [[ -z "$problem" ]] || error "$problem"
  # No subshell, so the cwd persists.
  cd "$DOTFILES_ROOT"
}

# Print the words of $1 in reverse order.
reverse_words() {
  local word reversed=""
  for word in $1; do
    reversed="$word${reversed:+ $reversed}"
  done
  printf '%s' "$reversed"
}

# Run the enabled features in variant order: install runs feature_<name>,
# reinstall runs uninstall_feature_<name> (if defined) then feature_<name>, and
# uninstall runs uninstall_feature_<name> in reverse order.
run_features() {
  local variant="$1" enabled="$2" mode="$3" features feature

  f_write_args variant_config _features -- "$variant"
  features="$_features"
  if [[ "$mode" == uninstall ]]; then
    features="$(reverse_words "$features")"
  fi

  info "Beginning dotfiles $mode (variant: $variant)..."
  for feature in $features; do
    list_contains "$enabled" "$feature" || continue
    if [[ "$mode" != install ]] && feature_uninstallable "$feature"; then
      info "Uninstalling feature: $feature"
      "$(uninstall_function "$feature")" "$variant" "$enabled"
    fi
    [[ "$mode" != uninstall ]] || continue
    if $DRY_RUN && ! list_contains "$DRY_RUN_FEATURES" "$feature"; then
      info "[dry-run] would run feature: $feature"
      continue
    fi
    "$(feature_function "$feature")" "$variant" "$enabled"
  done
  info "dotfiles $mode complete."
}

main() {
  bootstrap "$@"
  load_install_deps

  f_write_args parse_args _variant _flags _mode _all _dry_run _help -- "$@"
  readonly DRY_RUN="$_dry_run"

  f_write_args load_install_defaults _default_variant _default_features -- "$INSTALL_CONFIG"
  f_write_args apply_install_defaults _variant _flags _all -- \
    "$_variant" "$_flags" "$_all" "$_mode" "$_default_variant" "$_default_features"
  exit_with_usage_unless_runnable "$_variant" "$_flags" "$_all" "$_help" "$([[ $# -eq 0 ]] && echo true || echo false)"

  f_write_args resolve_features _enabled -- "$_variant" "$_flags" "$_all" "$_mode"
  enter_dotfiles_root
  run_features "$_variant" "$_enabled" "$_mode"
}

main "$@"
