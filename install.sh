#!/usr/bin/env bash

################################################################################
# Program: install.sh
# Description: Installs essential packages for configuration and creates
#              symlinks in the proper locations. Supports several variants
#              (see install/variants/) and toggles features with flags.
# Location: ~/dotfiles/install.sh
################################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$SCRIPT_DIR/install"
DOTFILES_ROOT="$HOME/dotfiles"
BACKUPS_ROOT="$DOTFILES_ROOT/.backup"
LOCAL_PREFIX="$HOME/.local"
LOCAL_BIN="$LOCAL_PREFIX/bin"

for f in "$INSTALL_DIR"/lib/*.sh "$INSTALL_DIR"/features/*.sh "$INSTALL_DIR"/variants/*.sh; do
  # shellcheck source=/dev/null
  source "$f"
done

available_variants() {
  local f names=""
  for f in "$INSTALL_DIR"/variants/*.sh; do
    f="$(basename "$f" .sh)"
    names+="${names:+ }$f"
  done
  printf '%s' "$names"
}

usage() {
  local variant="$1" v features all_exclude
  cat <<EOF
Usage: $(basename "$0") --variant NAME [OPTIONS]

dotfiles installation and configuration script. All operations are idempotent.
Run '$(basename "$0") --variant NAME --help' to list the options of a variant.
See README.md for more information.

Variants:
EOF
  for v in $(available_variants); do
    f_with_args variant_config description -- "$v"
    printf '  %-10s %s\n' "$v" "$f_arg_description"
  done
  variant_exists "$variant" || return 0

  f_with_args variant_config features all_exclude -- "$variant"
  features="$f_arg_features"
  all_exclude="$f_arg_all_exclude"
  cat <<EOF

Options for variant '$variant':
  --variant NAME   select the variant
  --all            install all options${all_exclude:+ (except: $all_exclude)}
EOF
  for v in $features; do
    printf '  --%-14s %s\n' "$v" "$(feature_description "$v")"
  done
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
  local variant="" flags=" " all=false dry_run=false help=false

  [[ $# -gt 0 ]] || help=true
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
      --help|-h)   help=true; shift ;;
      --?*)        flags+="${1#--} "; shift ;;
      *)           usage_error "Unexpected argument: $1" ;;
    esac
  done

  f_arg_variant="$variant"
  f_arg_flags="$flags"
  f_arg_all="$all"
  f_arg_dry_run="$dry_run"
  f_arg_help="$help"
}

exit_with_usage_unless_runnable() {
  local variant="$1" flags="$2" all="$3" help="$4"
  if [[ -z "$variant" ]]; then
    $help || usage_error "--variant is required"
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

resolve_features() {
  local variant="$1" flags="$2" all="$3" features all_exclude enabled=" " k

  f_with_args variant_config features all_exclude -- "$variant"
  features="$f_arg_features"
  all_exclude="$f_arg_all_exclude"

  for k in $flags; do
    list_contains "$features" "$k" \
      || usage_error "Unknown option for variant '$variant': --$k" "$variant"
  done
  for k in $features; do
    if list_contains "$flags" "$k" || { $all && ! list_contains "$all_exclude" "$k"; }; then
      enabled+="$k "
    fi
  done

  f_arg_enabled="$enabled"
}

enter_dotfiles_root() {
  # Ensure dotfiles dir exists and switch to it (no subshell, so cwd persists).
  [[ -d "$DOTFILES_ROOT" ]] || error "dotfiles must be at $DOTFILES_ROOT."
  cd "$DOTFILES_ROOT"
}

run_features() {
  local variant="$1" enabled="$2" dry_run="$3" features feature

  f_with_args variant_config features -- "$variant"
  features="$f_arg_features"

  info "Beginning dotfiles installation (variant: $variant)..."
  for feature in $features; do
    list_contains "$enabled" "$feature" || continue
    if $dry_run && ! list_contains "$DRY_RUN_FEATURES" "$feature"; then
      info "[dry-run] would run feature: $feature"
      continue
    fi
    "$(feature_function "$feature")" "$variant" "$enabled" "$dry_run"
  done
  info "dotfiles installation complete."
}

main() {
  local variant="$1" flags="$2" all="$3" help="$4" dry_run="$5" enabled

  exit_with_usage_unless_runnable "$variant" "$flags" "$all" "$help"

  f_with_args resolve_features enabled -- "$variant" "$flags" "$all"
  enabled="$f_arg_enabled"

  enter_dotfiles_root
  run_features "$variant" "$enabled" "$dry_run"
}

f_with_args parse_args variant flags all dry_run help -- "$@"
main "$f_arg_variant" "$f_arg_flags" "$f_arg_all" "$f_arg_help" "$f_arg_dry_run"
