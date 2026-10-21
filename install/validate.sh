#!/usr/bin/env bash

################################################################################
# Program: install/validate.sh
# Description: Checks the feature and variant registry without installing
#              anything: every variant's features exist, are documented, suit
#              the variant's OS and GUI, and come after the features they
#              require. Exits non-zero on any problem. Run in CI.
################################################################################

set -euo pipefail

INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Feature files read these at load time; point them at this checkout.
DOTFILES_ROOT="$(dirname "$INSTALL_DIR")"
BACKUPS_ROOT="$DOTFILES_ROOT/.backup"
LOCAL_PREFIX="$HOME/.local"
LOCAL_BIN="$LOCAL_PREFIX/bin"
DRY_RUN=true

for f in "$INSTALL_DIR"/lib/*.sh "$INSTALL_DIR"/features/*.sh "$INSTALL_DIR"/variants/*.sh; do
  # shellcheck source=/dev/null
  source "$f"
done

# Outputs: _problems, one line per problem with feature $2 in variant $1, which targets $3 and $4. $5 is the
# variant's features that run before this one.
check_feature() {
  local variant="$1" feature="$2" variant_os="$3" variant_gui="$4" earlier="$5" nl=$'\n' problems="" v dep

  declare -F "$(feature_function "$feature")" >/dev/null \
    || problems+="$variant: --$feature has no $(feature_function "$feature") function$nl"
  [[ -n "$(feature_description "$feature")" ]] \
    || problems+="$variant: --$feature has no feature_description entry$nl"

  f_write_args feature_requirements _machine _os _gui _requires -- "$feature"
  for v in $variant_os; do
    os_supported "$_os" "$v" || problems+="$variant: --$feature supports os '$_os', not '$v'$nl"
  done
  for v in $variant_gui; do
    gui_supported "$_gui" "$v" || problems+="$variant: --$feature supports gui '$_gui', not '$v'$nl"
  done
  for dep in $_requires; do
    list_contains "$earlier" "$dep" || problems+="$variant: --$feature requires --$dep earlier in _features$nl"
  done

  _problems="$problems"
}

# Outputs: _problems, one line per problem with variant $1.
check_variant() {
  local variant="$1" problems="" earlier=" " feature k
  f_write_args variant_config _features _optional _os _gui -- "$variant"
  local features="$_features" optional="$_optional" variant_os="$_os" variant_gui="$_gui"

  for feature in $features; do
    f_write_args check_feature _problems -- "$variant" "$feature" "$variant_os" "$variant_gui" "$earlier"
    problems+="$_problems"
    earlier+="$feature "
  done
  for k in $optional; do
    list_contains "$features" "$k" || problems+="$variant: _optional names unknown feature '$k'"$'\n'
  done

  _problems="$problems"
}

main() {
  local f variant problems="" known=" " k
  for f in "$INSTALL_DIR"/variants/*.sh; do
    variant="$(basename "$f" .sh)"
    f_write_args check_variant _problems -- "$variant"
    problems+="$_problems"
    f_write_args variant_config _features -- "$variant"
    known+="$_features "
  done
  for k in $DRY_RUN_FEATURES; do
    list_contains "$known" "$k" || problems+="DRY_RUN_FEATURES names unknown feature '$k'"$'\n'
  done

  if [[ -n "$problems" ]]; then
    printf '%s' "$problems" | while IFS= read -r line; do warn "$line"; done
    error "validation failed"
  fi
  info "All variants and features are valid."
}

main "$@"
