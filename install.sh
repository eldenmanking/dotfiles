#!/usr/bin/env bash

################################################################################
# Program: install.sh
# Description: Installs essential packages for configuration and creates
#              symlinks in the proper locations. Supports several variants
#              (see install/variants/) and toggles features with flags.
# Location: ~/dotfiles/install.sh
################################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" && pwd)"
INSTALL_DIR="$SCRIPT_DIR/install"
DOTFILES_ROOT="$HOME/dotfiles"
BACKUPS_ROOT="$DOTFILES_ROOT/.backup"
LOCAL_PREFIX="$HOME/.local"
LOCAL_BIN="$LOCAL_PREFIX/bin"
INSTALL_CONFIG="${DOTFILES_INSTALL_CONFIG:-$HOME/.config/dotfiles/install.conf}"
# A directory of downloads named by SHA-256, read and filled by download_verified (see Download Cache in README.md).
DOWNLOAD_CACHE="${DOTFILES_DOWNLOAD_CACHE:-}"

# install.sh only runs from a dotfiles checkout, beside its install/ directory; to install from scratch, use the
# bootstrap on the repo's install branch (see README.md). From a git checkout elsewhere, clone_checkout_to_root moves
# the install to $DOTFILES_ROOT. Runs before install/lib is loaded, so it prints its own messages.
bootstrap() {
  if [[ ! -f "$INSTALL_DIR/lib/fn.sh" ]]; then
    printf '[error] install.sh must run from a dotfiles checkout. To install from scratch, use the install.sh on\n' >&2
    printf '        the install branch instead (see Installation in README.md).\n' >&2
    exit 1
  fi
  clone_checkout_to_root "$@"
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
  for f in "$INSTALL_DIR"/lib/*.sh "$INSTALL_DIR"/features/*.sh "$INSTALL_DIR"/features/*/*.sh \
    "$INSTALL_DIR"/variants/*.sh; do
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

# Print feature $1's --help line, with the machines it is for and the features it requires.
usage_feature() {
  f_write_args feature_requirements _machine _os _gui _requires -- "$1"
  [[ "$_machine" != any ]] || _machine=""
  printf '  --%-14s %s%s%s\n' "$1" "$(feature_description "$1")" "${_machine:+ (machine: $_machine)}" \
    "${_requires:+ (requires: --${_requires// / --})}"
}

usage() {
  local variant="$1" machine="${2:-generic}" v features optional other="" uninstallable=""
  cat <<EOF
Usage: $(basename "$0") [--variant NAME] [--machine NAME] [--infer] [OPTIONS]

dotfiles installation and configuration script. All operations are idempotent.
Run '$(basename "$0") --variant NAME --help' to list the options of a variant.
--variant picks the OS and --machine the hardware (default: generic); --infer
guesses whichever of them isn't given from this system. Without them,
DOTFILES_VARIANT and DOTFILES_MACHINE name them; without options,
DOTFILES_FEATURES lists them (feature names, or all for --all). Set them in
the environment or in $INSTALL_CONFIG.
See README.md for more information.

Variants:
EOF
  for v in $(available_variants); do
    f_write_args variant_config _description -- "$v"
    printf '  %-10s %s\n' "$v" "$_description"
  done
  printf '\nMachines: %s\n' "$MACHINES"
  variant_exists "$variant" || return 0

  f_write_args variant_config _features _optional -- "$variant"
  features="$_features"
  optional="$_optional"
  cat <<EOF

Options for variant '$variant' on machine '$machine':
  --variant NAME   select the variant (the OS)
  --machine NAME   select the machine (the hardware)
  --infer          infer the variant or machine not given from this system
  --all            install all default options
EOF
  for v in $features; do
    feature_uninstallable "$v" && uninstallable+="${uninstallable:+ }$v"
    f_write_args feature_requirements _machine _os _gui _requires -- "$v"
    if list_contains "$optional" "$v"; then
      continue
    elif machine_supported "$_machine" "$machine"; then
      usage_feature "$v"
    else
      other+="${other:+ }$v"
    fi
  done
  if [[ -n "$optional" ]]; then
    printf '\nOptional (not included in --all):\n'
    for v in $optional; do
      usage_feature "$v"
    done
  fi
  if [[ -n "$other" ]]; then
    printf "\nFor other machines (not included in --all on '%s'):\n" "$machine"
    for v in $other; do
      usage_feature "$v"
    done
  fi
  [[ -z "$optional$other" ]] || echo
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
  local variant="" machine="" infer=false flags=" " mode=install all=false dry_run=false help=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --variant)
        [[ $# -ge 2 ]] || usage_error "--variant requires a value"
        variant="$2"
        shift 2
        ;;
      --variant=*) variant="${1#--variant=}"; shift ;;
      --machine)
        [[ $# -ge 2 ]] || usage_error "--machine requires a value"
        machine="$2"
        shift 2
        ;;
      --machine=*) machine="${1#--machine=}"; shift ;;
      --infer)     infer=true; shift ;;
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
  _machine="$machine"
  _infer="$infer"
  _flags="$flags"
  _mode="$mode"
  _all="$all"
  _dry_run="$dry_run"
  _help="$help"
}

# Outputs: _default_variant, _default_machine and _default_features, from DOTFILES_VARIANT, DOTFILES_MACHINE and
# DOTFILES_FEATURES in the environment or, for each one unset there, in config file $1. The file is sourced in a
# subshell so it can't change this shell's state.
load_install_defaults() {
  local conf="$1" file_variant="" file_machine="" file_features=""
  if [[ -f "$conf" ]]; then
    { IFS= read -r -d '' file_variant && IFS= read -r -d '' file_machine && IFS= read -r -d '' file_features; } < <(
      unset DOTFILES_VARIANT DOTFILES_MACHINE DOTFILES_FEATURES
      # shellcheck source=/dev/null
      source "$conf" >&2 || exit 1
      printf '%s\0%s\0%s\0' "${DOTFILES_VARIANT:-}" "${DOTFILES_MACHINE:-}" "${DOTFILES_FEATURES:-}"
    ) || error "Could not read $conf"
  fi
  _default_variant="${DOTFILES_VARIANT:-$file_variant}"
  _default_machine="${DOTFILES_MACHINE:-$file_machine}"
  _default_features="${DOTFILES_FEATURES:-$file_features}"
}

# Outputs: _variant, _machine, _flags and _all, the parsed variant $1, machine $7, flags $2 and --all $3 with the
# defaults applied. Default variant $5 is used when no --variant was given, and default machine $8 when no --machine
# was. Default features $6 (feature names, and all for --all) are used when the command line selects none, unless
# mode $4 is uninstall or the command line names a variant other than $5.
apply_install_defaults() {
  local variant="$1" flags="$2" all="$3" mode="$4" default_variant="$5" default_features="$6" machine="$7"
  local default_machine="$8" word
  [[ -n "$variant" ]] || variant="$default_variant"
  [[ -n "$machine" ]] || machine="$default_machine"
  if [[ "$flags" == " " ]] && ! $all && [[ "$mode" != uninstall ]] \
    && [[ -z "$default_variant" || "$variant" == "$default_variant" ]]; then
    for word in $default_features; do
      word="${word#--}"
      if [[ "$word" == all ]]; then all=true; else flags+="$word "; fi
    done
  fi
  _variant="$variant"
  _machine="$machine"
  _flags="$flags"
  _all="$all"
}

# Outputs: _variant and _machine to install for: variant $1 and machine $2 as given (by options or defaults), with
# each one left empty inferred from this system when $3 (--infer) is true. Without --infer, an empty machine is
# generic and an empty variant stays empty, for exit_with_usage_unless_runnable to report.
resolve_dimensions() {
  local variant="$1" machine="$2" infer="$3" inferred=""
  if $infer && [[ -z "$variant" || -z "$machine" ]]; then
    f_write_args infer_system _variant _machine _reason
    if [[ -z "$variant" ]]; then
      [[ -n "$_variant" ]] || error "Could not infer a variant for this system ($_reason); pass --variant"
      variant="$_variant"
      inferred+="variant '$variant'"
    fi
    if [[ -z "$machine" ]]; then
      machine="$_machine"
      inferred+="${inferred:+ and }machine '$machine'"
    fi
    info "Inferred $inferred from: $_reason"
  fi
  _variant="$variant"
  _machine="${machine:-generic}"
}

# Print usage and exit unless variant $1 can run on machine $6: with no variant, or with no features selected ($2
# flags, $3 --all) or --help ($4). Without a variant this is an error unless --help was given or there were no
# arguments ($5).
exit_with_usage_unless_runnable() {
  local variant="$1" flags="$2" all="$3" help="$4" no_args="$5" machine="$6"
  list_contains "$MACHINES" "$machine" || usage_error "Unknown machine '$machine'. Available machines: $MACHINES"
  if [[ -z "$variant" ]]; then
    $help || $no_args || usage_error "--variant (or --infer) is required"
    usage "" "$machine"
    exit 0
  fi
  variant_exists "$variant" \
    || usage_error "Unknown variant '$variant'. Available variants: $(available_variants)"
  if $help || { [[ "$flags" == " " ]] && ! $all; }; then
    usage "$variant" "$machine"
    exit 0
  fi
}

# Outputs: _enabled, the selected features of variant $1 on machine $5. --all leaves out optional features and those
# whose @machine doesn't suit $5; named features run either way (with a warning for the latter). Under --uninstall,
# features without an uninstall function are dropped (with a warning if named).
resolve_features() {
  local variant="$1" flags="$2" all="$3" mode="$4" machine="$5" features optional enabled=" " k default

  f_write_args variant_config _features _optional -- "$variant"
  features="$_features"
  optional="$_optional"

  for k in $flags; do
    list_contains "$features" "$k" \
      || usage_error "Unknown option for variant '$variant': --$k" "$variant"
  done
  for k in $features; do
    f_write_args feature_requirements _machine _os _gui _requires -- "$k"
    default=false
    if ! list_contains "$optional" "$k" && machine_supported "$_machine" "$machine"; then
      default=true
    elif list_contains "$flags" "$k" && ! list_contains "$optional" "$k"; then
      warn "--$k is for machine $_machine, not $machine; running it since it was named"
    fi
    if list_contains "$flags" "$k" || { $all && $default; }; then
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
  local variant="$1" enabled="$2" mode="$3" machine="$4" features feature

  f_write_args variant_config _features -- "$variant"
  features="$_features"
  if [[ "$mode" == uninstall ]]; then
    features="$(reverse_words "$features")"
  fi

  info "Beginning dotfiles $mode (variant: $variant, machine: $machine)..."
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

  local variant machine
  f_write_args parse_args _variant _machine _infer _flags _mode _all _dry_run _help -- "$@"
  readonly DRY_RUN="$_dry_run"

  f_write_args load_install_defaults _default_variant _default_machine _default_features -- "$INSTALL_CONFIG"
  f_write_args apply_install_defaults _variant _machine _flags _all -- \
    "$_variant" "$_flags" "$_all" "$_mode" "$_default_variant" "$_default_features" "$_machine" "$_default_machine"
  f_write_args resolve_dimensions _variant _machine -- "$_variant" "$_machine" "$_infer"
  # Copied out of _variant and _machine, which feature_requirements and infer_system write too.
  variant="$_variant"
  machine="$_machine"
  exit_with_usage_unless_runnable "$variant" "$_flags" "$_all" "$_help" \
    "$([[ $# -eq 0 ]] && echo true || echo false)" "$machine"

  f_write_args resolve_features _enabled -- "$variant" "$_flags" "$_all" "$_mode" "$machine"
  enter_dotfiles_root
  run_features "$variant" "$_enabled" "$_mode" "$machine"
}

main "$@"
