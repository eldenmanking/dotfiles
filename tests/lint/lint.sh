#!/usr/bin/env bash
# Lint the code: shell, zsh, Python and TOML syntax, shellcheck and actionlint. Run via `make lint`.

set -euo pipefail

# shellcheck source=../lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

# Print the tracked files matching the git pathspecs $@ (all with none), one per line, but symlinks: those are checked
# through their targets, and fixtures' after/ holds links into the containers' homes, which don't exist here.
tracked_files() {
  git ls-files -s -- "$@" | awk -F '\t' '$1 !~ /^120000 / { print $2 }'
}

# Outputs: _sh, _bash, _sourced, _zsh and _python, newline-separated tracked files of each language. Files under
# install/ without a shebang are sourced by install.sh, and fixtures' case.sh by tests/fixtures.sh, so they are bash.
classify_files() {
  local sh="" bash="" sourced="" zsh="" python="" file first
  while IFS= read -r file; do
    first=""
    [[ -f "$file" ]] && IFS= read -r first < "$file" || true
    case "$first" in
      '#!'*/sh|'#!'*' sh') sh+="$file"$'\n' ;;
      '#!'*bash*)          bash+="$file"$'\n' ;;
      '#!'*zsh*)           zsh+="$file"$'\n' ;;
      '#!'*python*)        python+="$file"$'\n' ;;
      *)
        case "$file" in
          install/*.sh|tests/fixtures/*/case.sh) sourced+="$file"$'\n' ;;
          *.zsh)        zsh+="$file"$'\n' ;;
          *.py)         python+="$file"$'\n' ;;
        esac
        ;;
    esac
  done < <(cd "$REPO_ROOT" && tracked_files)
  _sh="$sh"
  _bash="$bash"
  _sourced="$sourced"
  _zsh="$zsh"
  _python="$python"
}

# Run "$@" <file> for each file in newline-separated list $1, reporting each failure. Returns 1 if any failed.
each_file() {
  local files="$1" file failed=0
  shift
  while IFS= read -r file; do
    [[ -n "$file" ]] || continue
    "$@" "$file" || { warn "failed: $* $file"; failed=1; }
  done <<< "$files"
  return "$failed"
}

python_syntax() {
  python3 -c 'import ast, sys; ast.parse(open(sys.argv[1]).read(), sys.argv[1])' "$1"
}

toml_syntax() {
  python3 -c 'import sys, tomllib; tomllib.load(open(sys.argv[1], "rb"))' "$1"
}

main() {
  local failed=0 shellcheck actionlint
  cd "$REPO_ROOT"
  # .shellcheckrc finds the startup files' "$HOME/dotfiles/..." sources through the checkout's parent (make validate
  # checks this too, but shellcheck's errors would not say why).
  [[ "$(basename "$(pwd -P)")" == dotfiles ]] || error "the checkout must be a directory named dotfiles, as install.sh requires"
  f_write_args classify_files _sh _bash _sourced _zsh _python

  info "Syntax (sh -n, bash -n, zsh -n)"
  each_file "$_sh" sh -n || failed=1
  each_file "$_bash$_sourced" bash -n || failed=1
  if have_or_skip zsh "zsh syntax checks"; then
    each_file "$_zsh" zsh -n || failed=1
  fi
  if have_or_skip python3 "Python and TOML syntax checks"; then
    each_file "$_python" python_syntax || failed=1
    each_file "$(tracked_files '*.toml')" toml_syntax || failed=1
  fi

  info "shellcheck $SHELLCHECK_VERSION"
  f_write_args pinned_tool _path -- shellcheck
  shellcheck="$_path"
  # Scripts with a shebang pick their dialect from it; sourced files have none.
  each_file "$_sh$_bash" "$shellcheck" || failed=1
  each_file "$_sourced" "$shellcheck" -s bash || failed=1

  if [[ -n "$(git ls-files .github/workflows)" ]]; then
    info "actionlint $ACTIONLINT_VERSION"
    f_write_args pinned_tool _path -- actionlint
    actionlint="$_path"
    "$actionlint" -shellcheck "$shellcheck" || failed=1
  fi

  [[ "$failed" == 0 ]] || error "lint failed"
  info "lint passed"
}

main "$@"
