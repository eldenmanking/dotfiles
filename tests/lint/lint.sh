#!/usr/bin/env bash
# Lint the code: shell, zsh, Python and TOML syntax, function doc comments, shellcheck, one-time installs' bare
# commands, portability of the installer and actionlint. Run via `make lint`.

set -euo pipefail

# shellcheck source=../lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

# Print the tracked files matching the git pathspecs $@ (all with none), one per line, but symlinks: those are checked
# through their targets, and fixtures' after/ holds links into the containers' homes, which don't exist here.
# Usage: tracked_files [<pathspec>...]
tracked_files() {
  git ls-files -s -- "$@" | awk -F '\t' '$1 !~ /^120000 / { print $2 }'
}

# Sort the tracked files by language, as newline-separated lists. Files under install/ without a shebang are
# sourced by install.sh, and fixtures' case.sh by tests/fixtures.sh, so they are bash.
# Usage: f_call classify_files sh bash sourced zsh python
# Returns: sh bash sourced zsh python
#   sourced: bash files without a shebang (the install tree, tests/lib.sh and fixtures' case.sh)
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
          install/*.sh|tests/lib.sh|tests/fixtures/*/case.sh) sourced+="$file"$'\n' ;;
          *.zsh)        zsh+="$file"$'\n' ;;
          *.py)         python+="$file"$'\n' ;;
        esac
        ;;
    esac
  done < <(cd "$REPO_ROOT" && tracked_files)
  f_return sh bash sourced zsh python
}

# Run "$@" <file> for each file in newline-separated list $1, reporting each failure. Returns 1 if any failed.
# Usage: each_file <files> <command> [<arg>...]
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
# Usage: bare_returns <file>
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

# Check the syntax of Python file <file>.
# Usage: python_syntax <file>
python_syntax() {
  python3 -c 'import ast, sys; ast.parse(open(sys.argv[1]).read(), sys.argv[1])' "$1"
}

# Check the syntax of TOML file <file>.
# Usage: toml_syntax <file>
toml_syntax() {
  python3 -c 'import sys, tomllib; tomllib.load(open(sys.argv[1], "rb"))' "$1"
}

# Bash 3.2 (macOS) lacks these, and BSD tools lack GNU-only flags, so none may appear in shell run by install.sh. The
# one-time installs in install/oti run on a live ISO, so are exempt.
PORTABILITY_PATTERN='mapfile|readarray|declare -A|local -n|declare -n|readlink -f|grep -P|\$\{[A-Za-z_][A-Za-z0-9_]*(\^\^|,,)'

# Report each use of a construct bash 3.2 or BSD tools lack in the tracked shell files of install/, install.sh and
# scripts/ (but install/oti/), skipping comment lines. Returns 1 if there are any.
# Usage: portability
portability() {
  local found
  found="$(cd "$REPO_ROOT" && tracked_files install install.sh scripts | grep -v '^install/oti/' \
    | xargs grep -nE -- "$PORTABILITY_PATTERN" | grep -vE '^[^:]*:[0-9]+:[[:space:]]*#' || true)"
  [[ -z "$found" ]] || { warn "not portable to bash 3.2 and macOS (install/oti is exempt):"; printf '%s\n' "$found" >&2; return 1; }
}

# Report each call of a _-prefixed function in a file that doesn't define it: those helpers are private to their file.
# Functions of the same name in two files each stay private to theirs. Returns 1 if there are any.
# Usage: private_helpers
private_helpers() {
  local files file name defs failed=0
  files="$(cd "$REPO_ROOT" && tracked_files install install.sh scripts | grep -v '^install/oti/' || true)"
  # Each defined name with the file defining it, "name file".
  defs="$(cd "$REPO_ROOT" && for file in $files; do
    sed -n "s|^\(_[a-z][a-z0-9_]*\)() *{.*|\1 $file|p" "$file"
  done)"
  while read -r name file; do
    [[ -n "$name" ]] || continue
    while IFS= read -r user; do
      [[ "$user" == "$file" ]] && continue
      grep -qE "^$name\(\)" "$REPO_ROOT/$user" && continue
      warn "$user calls $name, which is private to $file"
      failed=1
    done < <(cd "$REPO_ROOT" && grep -lwE -- "$name" $files || true)
  done <<< "$defs"
  return "$failed"
}

# Run every lint check, then fail if any failed.
# Usage: main
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

  info "Function doc comments (Usage lines, and Returns lines for f_return)"
  if have_or_skip python3 "the function doc comment check"; then
    python3 tests/lint/function_docs.py $(printf '%s' "$sh$bash$sourced") || failed=1
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
  info "portability: no bash 4 features or GNU-only flags in install/, install.sh and scripts/"
  portability || failed=1
  info "_-prefixed helpers are called only from the file defining them"
  private_helpers || failed=1

  if [[ -n "$(git ls-files .github/workflows)" ]]; then
    info "actionlint $ACTIONLINT_VERSION"
    f_call pinned_tool actionlint=path -- actionlint
    "$actionlint" -shellcheck "$shellcheck" || failed=1
  fi

  [[ "$failed" == 0 ]] || error "lint failed"
  info "lint passed"
}

main "$@"
