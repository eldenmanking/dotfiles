#!/usr/bin/env bash

################################################################################
# Program: install.sh
# Description: Installs essential packages for configuration and creates
#              symlinks in the proper locations. Installs for an OS, profile
#              and machine (see install/os/, install/profiles/ and the
#              variants naming an OS and profile in install/variants/) and
#              toggles features with flags.
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

# Source install/lib, features, OSes, profiles and variants. They only define functions and constants, so their
# globals stay global.
load_install_deps() {
  local f
  for f in "$INSTALL_DIR"/lib/*.sh "$INSTALL_DIR"/features/*.sh "$INSTALL_DIR"/features/*/*.sh \
    "$INSTALL_DIR"/os/*.sh "$INSTALL_DIR"/profiles/*.sh "$INSTALL_DIR"/variants/*.sh; do
    # shellcheck source=/dev/null
    source "$f"
  done
}

# Print feature $1's --help line, with the machines it is for and the features it requires.
usage_feature() {
  f_write_args feature_requirements _machine _os _gui _requires -- "$1"
  [[ "$_machine" != any ]] || _machine=""
  printf '  --%-14s %s%s%s\n' "$1" "$(feature_description "$1")" "${_machine:+ (machine: $_machine)}" \
    "${_requires:+ (requires: --${_requires// / --})}"
}

# Print the variants, OSes and profiles, then the options of OS $1 with profile $2 on machine $3 if they can run.
usage() {
  local os="$1" profile="$2" machine="${3:-generic}" v features optional other="" uninstallable=""
  cat <<EOF
Usage: $(basename "$0") [--variant NAME | --os NAME --profile NAME] [--machine NAME] [--infer] [OPTIONS]

dotfiles installation and configuration script. All operations are idempotent.
An install is for an OS, a profile (how the machine is used) and a machine
(the hardware, default generic). --variant names an OS and profile, which
--os and --profile override; --infer guesses whichever isn't given from this
system. Run with them and --help to list their options. Without them,
DOTFILES_VARIANT, DOTFILES_OS, DOTFILES_PROFILE and DOTFILES_MACHINE name
them; without options, DOTFILES_FEATURES lists them (feature names, or all
for --all). Set them in the environment or in $INSTALL_CONFIG.
See README.md for more information.

Variants:
EOF
  for v in $(available_names variants); do
    f_write_args variant_config _os _profile -- "$v"
    printf '  %-10s --os %s --profile %s\n' "$v" "$_os" "$_profile"
  done
  printf '\nOSes (profiles; machines):\n'
  for v in $(available_names os); do
    f_write_args os_config _description _machines -- "$v"
    printf '  %-10s %s (%s; %s)\n' "$v" "$_description" "$(os_profiles "$v")" "$_machines"
  done
  printf '\nProfiles:\n'
  for v in $(available_names profiles); do
    f_write_args profile_config _description -- "$v"
    printf '  %-10s %s\n' "$v" "$_description"
  done
  os_supports_profile "$os" "$profile" || return 0

  f_write_args os_profile_config _features _optional -- "$os" "$profile"
  features="$_features"
  optional="$_optional"
  cat <<EOF

Options for OS '$os' with profile '$profile' on machine '$machine':
  --variant NAME   select an OS and profile
  --os NAME        select the OS
  --profile NAME   select the profile
  --machine NAME   select the machine (the hardware)
  --infer          infer the OS, profile or machine not given from this system
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

# Warn with message $1, print usage (of OS $2 with profile $3 on machine $4, if given) and exit.
usage_error() {
  local message="$1" os="${2:-}" profile="${3:-}" machine="${4:-}"
  warn "$message"
  usage "$os" "$profile" "$machine" >&2
  exit 1
}

parse_args() {
  local variant="" os="" profile="" machine="" infer=false flags=" " mode=install all=false dry_run=false help=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --variant|--os|--profile|--machine)
        [[ $# -ge 2 ]] || usage_error "$1 requires a value"
        case "$1" in
          --variant) variant="$2" ;;
          --os)      os="$2" ;;
          --profile) profile="$2" ;;
          --machine) machine="$2" ;;
        esac
        shift 2
        ;;
      --variant=*) variant="${1#--variant=}"; shift ;;
      --os=*)      os="${1#--os=}"; shift ;;
      --profile=*) profile="${1#--profile=}"; shift ;;
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
  _os="$os"
  _profile="$profile"
  _machine="$machine"
  _infer="$infer"
  _flags="$flags"
  _mode="$mode"
  _all="$all"
  _dry_run="$dry_run"
  _help="$help"
}

# Outputs: _default_variant, _default_os, _default_profile, _default_machine and _default_features, from
# DOTFILES_VARIANT, DOTFILES_OS, DOTFILES_PROFILE, DOTFILES_MACHINE and DOTFILES_FEATURES in the environment or, for
# each one unset there, in config file $1. The file is sourced in a subshell so it can't change this shell's state.
load_install_defaults() {
  local conf="$1" file_variant="" file_os="" file_profile="" file_machine="" file_features=""
  if [[ -f "$conf" ]]; then
    { IFS= read -r -d '' file_variant && IFS= read -r -d '' file_os && IFS= read -r -d '' file_profile \
      && IFS= read -r -d '' file_machine && IFS= read -r -d '' file_features; } < <(
      unset DOTFILES_VARIANT DOTFILES_OS DOTFILES_PROFILE DOTFILES_MACHINE DOTFILES_FEATURES
      # shellcheck source=/dev/null
      source "$conf" >&2 || exit 1
      printf '%s\0%s\0%s\0%s\0%s\0' "${DOTFILES_VARIANT:-}" "${DOTFILES_OS:-}" "${DOTFILES_PROFILE:-}" \
        "${DOTFILES_MACHINE:-}" "${DOTFILES_FEATURES:-}"
    ) || error "Could not read $conf"
  fi
  _default_variant="${DOTFILES_VARIANT:-$file_variant}"
  _default_os="${DOTFILES_OS:-$file_os}"
  _default_profile="${DOTFILES_PROFILE:-$file_profile}"
  _default_machine="${DOTFILES_MACHINE:-$file_machine}"
  _default_features="${DOTFILES_FEATURES:-$file_features}"
}

# Outputs: _os and _profile, OS $2 and profile $3, with each one left empty filled in from variant $1 (if given).
variant_dimensions() {
  local variant="$1" os="$2" profile="$3"
  if [[ -n "$variant" ]]; then
    variant_exists "$variant" \
      || usage_error "Unknown variant '$variant'. Available variants: $(available_names variants)"
    f_write_args variant_config _os _profile -- "$variant"
    [[ -n "$os" ]] || os="$_os"
    [[ -n "$profile" ]] || profile="$_profile"
  fi
  _os="$os"
  _profile="$profile"
}

# Outputs: _flags and _all, flags $1 and --all $2 with default features $4 (feature names, and all for --all) added
# when the command line selects none, unless mode $3 is uninstall or the OS and profile to install for ($5, $6) aren't
# the ones the defaults name ($7, $8; both empty when the defaults name none).
apply_default_features() {
  local flags="$1" all="$2" mode="$3" default_features="$4" os="$5" profile="$6" default_os="$7"
  local default_profile="$8" word
  if [[ "$flags" == " " ]] && ! $all && [[ "$mode" != uninstall ]] \
    && [[ -z "$default_os$default_profile" || "$os $profile" == "$default_os $default_profile" ]]; then
    for word in $default_features; do
      word="${word#--}"
      if [[ "$word" == all ]]; then all=true; else flags+="$word "; fi
    done
  fi
  _flags="$flags"
  _all="$all"
}

# Outputs: _os, _profile and _machine to install for: OS $1, profile $2 and machine $3 as given (by options or
# defaults), with each one left empty inferred from this system when $4 (--infer) is true, to suit the given ones:
# an OS that lacks the given profile becomes portable if that has it (portable runs anywhere), and a machine the OS
# doesn't support becomes generic. Without --infer, an empty machine is generic and an empty OS or profile stays
# empty, for exit_with_usage_unless_runnable to report.
resolve_dimensions() {
  local os="$1" profile="$2" machine="$3" infer="$4" inferred=""
  if $infer && [[ -z "$os" || -z "$profile" || -z "$machine" ]]; then
    f_write_args infer_system _os _machine _coder _reason
    if [[ -z "$os" ]]; then
      [[ -n "$_os" ]] || error "Could not infer an OS for this system ($_reason); pass --os or --variant"
      os="$_os"
      if [[ -n "$profile" ]] && ! os_supports_profile "$os" "$profile" && os_supports_profile portable "$profile"; then
        os=portable
      fi
      inferred+="OS '$os'"
    fi
    if [[ -z "$profile" ]]; then
      profile="$(profile_for_system "$os" "$_coder")"
      inferred+="${inferred:+, }profile '$profile'"
    fi
    if [[ -z "$machine" ]]; then
      machine="$_machine"
      if os_exists "$os"; then
        f_write_args os_config _machines -- "$os"
        list_contains "$_machines" "$machine" || machine=generic
      fi
      inferred+="${inferred:+, }machine '$machine'"
    fi
    info "Inferred $inferred from: $_reason"
  fi
  _os="$os"
  _profile="$profile"
  _machine="${machine:-generic}"
}

# Print usage and exit unless OS $5 with profile $6 can run on machine $7: with no OS and profile, or with no
# features selected ($1 flags, $2 --all) or --help ($3). Without an OS and profile this is an error unless --help was
# given or there were no arguments ($4), as is an OS, profile or machine that doesn't exist or doesn't go together.
exit_with_usage_unless_runnable() {
  local flags="$1" all="$2" help="$3" no_args="$4" os="$5" profile="$6" machine="$7"
  list_contains "$MACHINES" "$machine" || usage_error "Unknown machine '$machine'. Available machines: $MACHINES"
  if [[ -z "$os" && -z "$profile" ]]; then
    $help || $no_args || usage_error "--variant, or --os and --profile, is required (or --infer)"
    usage "" "" "$machine"
    exit 0
  fi
  [[ -z "$os" ]] || os_exists "$os" || usage_error "Unknown OS '$os'. Available OSes: $(available_names os)"
  [[ -z "$profile" ]] || profile_exists "$profile" \
    || usage_error "Unknown profile '$profile'. Available profiles: $(available_names profiles)"
  [[ -n "$os" ]] || usage_error "--profile $profile needs --os (or --infer)"
  [[ -n "$profile" ]] || usage_error "--os $os needs --profile, one of: $(os_profiles "$os") (or --infer)"
  os_supports_profile "$os" "$profile" \
    || usage_error "OS '$os' has no profile '$profile'; it has: $(os_profiles "$os")"
  f_write_args os_config _machines -- "$os"
  list_contains "$_machines" "$machine" \
    || usage_error "OS '$os' doesn't support machine '$machine'; it supports: $_machines"
  if $help || { [[ "$flags" == " " ]] && ! $all; }; then
    usage "$os" "$profile" "$machine"
    exit 0
  fi
}

# Outputs: _enabled, the selected features of OS $1 with profile $2 on machine $6. --all leaves out optional features
# and those whose @machine doesn't suit $6; named features run either way (with a warning for the latter). Under
# --uninstall, features without an uninstall function are dropped (with a warning if named).
resolve_features() {
  local os="$1" profile="$2" flags="$3" all="$4" mode="$5" machine="$6" features optional enabled=" " k default

  f_write_args os_profile_config _features _optional -- "$os" "$profile"
  features="$_features"
  optional="$_optional"

  for k in $flags; do
    list_contains "$features" "$k" \
      || usage_error "Unknown option for OS '$os' with profile '$profile': --$k" "$os" "$profile" "$machine"
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

# Run the enabled features in the order of OS $1 with profile $2: install runs feature_<name>, reinstall runs
# uninstall_feature_<name> (if defined) then feature_<name>, and uninstall runs uninstall_feature_<name> in reverse
# order. Each gets the OS, the profile and the enabled features.
run_features() {
  local os="$1" profile="$2" enabled="$3" mode="$4" machine="$5" features feature

  f_write_args os_profile_config _features -- "$os" "$profile"
  features="$_features"
  if [[ "$mode" == uninstall ]]; then
    features="$(reverse_words "$features")"
  fi

  info "Beginning dotfiles $mode (os: $os, profile: $profile, machine: $machine)..."
  for feature in $features; do
    list_contains "$enabled" "$feature" || continue
    if [[ "$mode" != install ]] && feature_uninstallable "$feature"; then
      info "Uninstalling feature: $feature"
      "$(uninstall_function "$feature")" "$os" "$profile" "$enabled"
    fi
    [[ "$mode" != uninstall ]] || continue
    if $DRY_RUN && ! list_contains "$DRY_RUN_FEATURES" "$feature"; then
      info "[dry-run] would run feature: $feature"
      continue
    fi
    "$(feature_function "$feature")" "$os" "$profile" "$enabled"
  done
  info "dotfiles $mode complete."
}

main() {
  bootstrap "$@"
  load_install_deps

  local os profile machine default_os default_profile
  f_write_args parse_args _variant _os _profile _machine _infer _flags _mode _all _dry_run _help -- "$@"
  readonly DRY_RUN="$_dry_run"
  f_write_args variant_dimensions _os _profile -- "$_variant" "$_os" "$_profile"
  os="$_os"
  profile="$_profile"
  machine="$_machine"

  # Each dimension the command line leaves out comes from the defaults, where DOTFILES_OS and DOTFILES_PROFILE override
  # DOTFILES_VARIANT's.
  f_write_args load_install_defaults _default_variant _default_os _default_profile _default_machine _default_features \
    -- "$INSTALL_CONFIG"
  f_write_args variant_dimensions _os _profile -- "$_default_variant" "$_default_os" "$_default_profile"
  default_os="$_os"
  default_profile="$_profile"
  os="${os:-$default_os}"
  profile="${profile:-$default_profile}"
  machine="${machine:-$_default_machine}"
  f_write_args apply_default_features _flags _all -- \
    "$_flags" "$_all" "$_mode" "$_default_features" "$os" "$profile" "$default_os" "$default_profile"

  # Copied out of _os, _profile and _machine, which feature_requirements and infer_system write too.
  f_write_args resolve_dimensions _os _profile _machine -- "$os" "$profile" "$machine" "$_infer"
  os="$_os"
  profile="$_profile"
  machine="$_machine"
  exit_with_usage_unless_runnable "$_flags" "$_all" "$_help" "$([[ $# -eq 0 ]] && echo true || echo false)" \
    "$os" "$profile" "$machine"

  f_write_args resolve_features _enabled -- "$os" "$profile" "$_flags" "$_all" "$_mode" "$machine"
  enter_dotfiles_root
  run_features "$os" "$profile" "$_enabled" "$_mode" "$machine"
}

main "$@"
