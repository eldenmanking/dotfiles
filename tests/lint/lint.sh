#!/usr/bin/env bash
# Lint the code: shell, zsh, Python and TOML syntax, shellcheck, one-time installs' bare commands and actionlint. Run via `make lint`.

set -euo pipefail

# shellcheck source=../lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

# Print the tracked files matching the git pathspecs $@ (all with none), one per line, but symlinks: those are checked
# through their targets, and fixtures' after/ holds links into the containers' homes, which don't exist here.
tracked_files() {
  git ls-files -s -- "$@" | awk -F '\t' '$1 !~ /^120000 / { print $2 }'
}

# Outputs: sh, bash, sourced, zsh and python, newline-separated tracked files of each language. Files under
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
  f_return sh bash sourced zsh python
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

# Print the names that f_return statements in file $1 return bare (f_return name), one per line, joining lines continued
# with a backslash. Each reads the variable of that name, which shellcheck doesn't see. This approximates shell syntax:
# a quoted value that spans lines hides the names after it, which then fail lint as unused.
bare_returns() {
  awk '
    { line = (cont ? cont " " : "") $0; cont = "" }
    sub(/\\$/, "", line) { cont = line; next }
    line ~ /^[[:space:]]*#/ { next }
    line ~ /f_return/ {
      # Drop quoted values first, so that words in them are not taken for names, then comments, then split the
      # commands apart. A quoted value leaves "" behind, so that the stray words of a nested one stay glued to it.
      gsub(/"([^"\\]|\\.)*"/, "\"\"", line)
      gsub(/\047[^\047]*\047/, "", line)
      sub(/(^|[[:space:]])#.*/, "", line)
      n = split(line, commands, /;|&&|\|\||[|&]/)
      for (c = 1; c <= n; c++) {
        if (!sub(/^.*(^|[[:space:]{(])f_return[[:space:]]+/, "", commands[c])) continue
        m = split(commands[c], words, /[[:space:]]+/)
        for (i = 1; i <= m; i++) if (words[i] ~ /^[a-z][a-z0-9_]*$/) print words[i]
      }
    }
  ' "$1"
}

# Report unused variables (shellcheck's SC2034) in a file, leaving out two kinds that only look unused:
#  - UPPER_CASE globals, which other files read (shellcheck checks one file at a time).
#  - Variables an f_return returns by bare name (f_return name reads $name, which shellcheck can't see).
# .shellcheckrc turns SC2034 off for those reasons, so this runs shellcheck with --norc to turn it back on;
# "# shellcheck disable=SC2034" comments in the file still apply.
# Usage: unused_variables <shellcheck> [shellcheck options...] <file>
unused_variables() {
  local shellcheck="$1" file="${*: -1}" found="" line name returned
  shift
  returned=" $(bare_returns "$file" | tr '\n' ' ')"
  while IFS= read -r line; do
    [[ "$line" =~ :\ warning:\ ([A-Za-z0-9_]+)\ appears\ unused ]] || continue
    name="${BASH_REMATCH[1]}"
    [[ "$name" == [A-Z]* && "$name" != *[a-z]* ]] && continue
    [[ "$returned" == *" $name "* ]] && continue
    found+="$line"$'\n'
  done < <("$shellcheck" --norc -i SC2034 -f gcc "$@" || true)
  [[ -z "$found" ]] || { printf '%s' "$found"; return 1; }
}

python_syntax() {
  python3 -c 'import ast, sys; ast.parse(open(sys.argv[1]).read(), sys.argv[1])' "$1"
}

toml_syntax() {
  python3 -c 'import sys, tomllib; tomllib.load(open(sys.argv[1], "rb"))' "$1"
}

main() {
  local failed=0 shellcheck actionlint sh bash sourced zsh python
  cd "$REPO_ROOT"
  # .shellcheckrc finds the startup files' "$HOME/dotfiles/..." sources through the checkout's parent (make validate
  # checks this too, but shellcheck's errors would not say why).
  [[ "$(basename "$(pwd -P)")" == dotfiles ]] || error "the checkout must be a directory named dotfiles, as install.sh requires"
  f_call classify_files sh bash sourced zsh python

  info "Syntax (sh -n, bash -n, zsh -n)"
  each_file "$sh" sh -n || failed=1
  each_file "$bash$sourced" bash -n || failed=1
  if have_or_skip zsh "zsh syntax checks"; then
    each_file "$zsh" zsh -n || failed=1
  fi
  if have_or_skip python3 "Python and TOML syntax checks"; then
    each_file "$python" python_syntax || failed=1
    each_file "$(tracked_files '*.toml')" toml_syntax || failed=1
  fi

  info "shellcheck $SHELLCHECK_VERSION"
  f_call pinned_tool shellcheck=path -- shellcheck
  # Scripts with a shebang pick their dialect from it; sourced files have none.
  each_file "$sh$bash" "$shellcheck" || failed=1
  each_file "$sourced" "$shellcheck" -s bash || failed=1
  info "shellcheck: unused variables (but UPPER_CASE globals)"
  each_file "$sh$bash" unused_variables "$shellcheck" || failed=1
  each_file "$sourced" unused_variables "$shellcheck" -s bash || failed=1

  tests/lint/oti_commands.sh || failed=1

  if [[ -n "$(git ls-files .github/workflows)" ]]; then
    info "actionlint $ACTIONLINT_VERSION"
    f_call pinned_tool actionlint=path -- actionlint
    "$actionlint" -shellcheck "$shellcheck" || failed=1
  fi

  [[ "$failed" == 0 ]] || error "lint failed"
  info "lint passed"
}

main "$@"
