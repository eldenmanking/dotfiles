#!/usr/bin/env bash
# Validate the feature and variant registry without installing anything: every feature_<name> function in
# install/features is documented (a feature_description entry, and a doc comment with a description and @machine, @os
# and @gui tags), and every variant's features exist, suit the variant's OS and GUI, and come after the features they
# require. Run via `make validate`.

set -euo pipefail

# shellcheck source=../lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

INSTALL_DIR="$REPO_ROOT/install"
# Feature files read these at load time; point them at this checkout.
DOTFILES_ROOT="$REPO_ROOT"
BACKUPS_ROOT="$DOTFILES_ROOT/.backup"
LOCAL_PREFIX="$HOME/.local"
LOCAL_BIN="$LOCAL_PREFIX/bin"
DRY_RUN=true

for f in "$INSTALL_DIR"/lib/*.sh "$INSTALL_DIR"/features/*.sh "$INSTALL_DIR"/variants/*.sh; do
  # shellcheck source=/dev/null
  source "$f"
done

# Outputs: _features, every feature with a feature_<name> function in install/features.
scan_features() {
  _features="$(sed -n 's/^feature_\([a-z0-9_]*\)() *{.*/\1/p' "$INSTALL_DIR"/features/*.sh | tr '\n' ' ')"
}

# Outputs: _problems, one line per problem with value list $3 of tag @$2 on feature $1, given allowed values $4.
check_tag() {
  local feature="$1" tag="$2" values="$3" allowed="$4" nl=$'\n' problems="" v
  [[ -n "$values" ]] || problems+="--$feature: missing @$tag tag above $(feature_function "$feature")$nl"
  for v in $values; do
    list_contains "$allowed" "$v" || problems+="--$feature: @$tag '$v' is not one of: $allowed$nl"
  done
  _problems="$problems"
}

# Outputs: _problems, one line per problem with the layout of doc $2 of feature $1: description lines, a bare '#'
# line, then only tags.
check_doc_layout() {
  local feature="$1" doc="$2" nl=$'\n' problems="" line state=start
  while IFS= read -r line; do
    case "$state:$line" in
      start:)                state=start ;;
      start:@*)              problems+="--$feature: doc has no description before its tags$nl"; state=tags ;;
      start:*)               state=description ;;
      description:)          state=blank ;;
      description:@*)        problems+="--$feature: doc needs a bare '#' line between description and tags$nl"
                             state=tags ;;
      description:*|blank:)  ;;
      blank:@*)              state=tags ;;
      blank:*)               state=description ;;
      tags:@*)               ;;
      tags:*)                problems+="--$feature: doc has '$line' after its tags; tags go last$nl"; break ;;
    esac
  done <<< "$doc"
  [[ "$state" != start ]] || problems+="--$feature: no doc comment above $(feature_function "$feature")$nl"
  _problems="$problems"
}

# Outputs: _problems, one line per problem with the documentation of feature $1. $2 is every known feature.
check_feature_docs() {
  local feature="$1" known="$2" problems="" dep
  [[ -n "$(feature_description "$feature")" ]] \
    || problems+="--$feature: no feature_description entry"$'\n'

  f_write_args feature_doc _doc -- "$feature"
  f_write_args check_doc_layout _problems -- "$feature" "$_doc"
  problems+="$_problems"

  f_write_args feature_requirements _machine _os _gui _requires -- "$feature"
  local machine="$_machine" os="$_os" gui="$_gui" requires="$_requires"
  f_write_args check_tag _problems -- "$feature" machine "$machine" "$FEATURE_MACHINES"
  problems+="$_problems"
  f_write_args check_tag _problems -- "$feature" os "$os" "$FEATURE_OSES"
  problems+="$_problems"
  f_write_args check_tag _problems -- "$feature" gui "$gui" "$FEATURE_GUIS"
  problems+="$_problems"
  for dep in $requires; do
    list_contains "$known" "$dep" || problems+="--$feature: @requires '$dep' is not a feature"$'\n'
  done

  _problems="$problems"
}

# Outputs: _problems, one line per problem with feature $2 in variant $1, which targets $3 and $4. $5 is the
# variant's features that run before this one.
check_feature() {
  local variant="$1" feature="$2" variant_os="$3" variant_gui="$4" earlier="$5" nl=$'\n' problems="" v dep

  if ! declare -F "$(feature_function "$feature")" >/dev/null; then
    _problems="$variant: --$feature has no $(feature_function "$feature") function$nl"
    return
  fi

  # Missing tags are reported once by check_feature_docs.
  f_write_args feature_requirements _machine _os _gui _requires -- "$feature"
  [[ -n "$_os" ]] || variant_os=""
  [[ -n "$_gui" ]] || variant_gui=""
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
  local f variant problems="" known feature k
  f_write_args scan_features _features
  known="$_features"

  for feature in $known; do
    f_write_args check_feature_docs _problems -- "$feature" "$known"
    problems+="$_problems"
  done
  for f in "$INSTALL_DIR"/variants/*.sh; do
    variant="$(basename "$f" .sh)"
    f_write_args check_variant _problems -- "$variant"
    problems+="$_problems"
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
