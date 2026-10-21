#!/usr/bin/env bash
# Exercise install.sh in scratch home directories: usage, --dry-run for every variant, real rootless installs and
# their idempotency, and the resulting shell startup files. Run via `make test`. INSTALL_BASH picks the bash that runs
# install.sh (CI sets /bin/bash on macOS to test bash 3.2).

set -euo pipefail

# shellcheck source=test/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

INSTALL_BASH="${INSTALL_BASH:-bash}"
SCRATCH="$(mktemp -d)"
LOG="$SCRATCH/install.log"
# Features that check for a live host even under --dry-run: webterm needs a systemd user session.
DRY_RUN_SKIP=" webterm "

FAILURES=0
trap 'rm -rf "$SCRATCH"' EXIT

# Record a failed check and keep going, so one run reports every failure.
fail() {
  warn "FAIL: $*"
  FAILURES=$((FAILURES + 1))
}

# Outputs: _home, a new scratch home holding a dotfiles symlink to this checkout, as install.sh requires.
new_home() {
  local home
  home="$(mktemp -d "$SCRATCH/home.XXXXXX")"
  ln -s "$REPO_ROOT" "$home/dotfiles"
  _home="$home"
}

# Run install.sh with home $1 and the remaining args, in a clean environment with no terminal. Its output goes to
# LOG, and is shown on failure. Returns install.sh's status.
run_install() {
  local home="$1" status=0
  shift
  env -i HOME="$home" PATH="$PATH" TERM=dumb "$INSTALL_BASH" "$home/dotfiles/install.sh" "$@" \
    </dev/null >"$LOG" 2>&1 || status=$?
  if [[ "$status" != 0 ]]; then
    sed 's/^/    | /' "$LOG" >&2
  fi
  return "$status"
}

# Outputs: _features and _link_paths of variant $1, read from its definition the same way install.sh does.
variant_info() {
  local variant="$1" out
  out="$(
    set +u
    for f in "$REPO_ROOT"/install/lib/*.sh "$REPO_ROOT"/install/features/*.sh "$REPO_ROOT/install/variants/$variant.sh"; do
      # shellcheck source=/dev/null
      source "$f"
    done
    "variant_$variant"
    printf '%s\n%s\n' "$_features" "$_link_paths"
  )"
  _features="${out%%$'\n'*}"
  _link_paths="${out#*$'\n'}"
}

# Print one line per entry under home $1 (outside dotfiles): its type, path, and symlink target or checksum.
snapshot() {
  local home="$1" path
  (cd "$home" && find . -path ./dotfiles -prune -o -print | LC_ALL=C sort) | while IFS= read -r path; do
    if [[ -L "$home/$path" ]]; then
      printf 'L %s -> %s\n' "$path" "$(readlink "$home/$path")"
    elif [[ -d "$home/$path" ]]; then
      printf 'D %s\n' "$path"
    else
      printf 'F %s %s\n' "$path" "$(cksum < "$home/$path")"
    fi
  done
}

repo_status() {
  # --ignored too, since backups would land in the ignored dotfiles/.backup.
  git -C "$REPO_ROOT" status --porcelain --untracked-files=all --ignored
}

# Outputs: _variants, the name of every variant in install/variants.
all_variants() {
  local f names=""
  for f in "$REPO_ROOT"/install/variants/*.sh; do
    f="${f##*/}"
    names+="${names:+ }${f%.sh}"
  done
  _variants="$names"
}

test_usage() {
  local variants="$1" variant
  info "usage"
  new_home
  run_install "$_home" || fail "install.sh with no arguments"
  for variant in $variants; do
    run_install "$_home" --variant "$variant" --help || fail "--variant $variant --help"
    grep -q -- '--link' "$LOG" || fail "--variant $variant --help does not list --link"
  done
  ! run_install "$_home" --variant nope >/dev/null 2>&1 || fail "unknown variant accepted"
  ! run_install "$_home" --variant coder --nope >/dev/null 2>&1 || fail "unknown option accepted"
}

# --dry-run must succeed and leave the home untouched, for install, reinstall and uninstall.
test_dry_run() {
  local variant="$1" flags="" feature mode before
  info "dry run: $variant"
  variant_info "$variant"
  for feature in $_features; do
    list_contains "$DRY_RUN_SKIP" "$feature" || flags+=" --$feature"
  done
  new_home
  before="$(snapshot "$_home")"
  for mode in "" --reinstall --uninstall; do
    # shellcheck disable=SC2086 # $flags and $mode are lists of options
    run_install "$_home" --variant "$variant" --dry-run $mode $flags || fail "$variant --dry-run${mode:+ $mode} failed"
  done
  [[ "$(snapshot "$_home")" == "$before" ]] || fail "$variant --dry-run changed the home"
}

# Check that every file under the variant's link paths is linked into home $1.
check_links() {
  local variant="$1" home="$2" file target
  variant_info "$variant"
  # shellcheck disable=SC2086 # $_link_paths is a list of paths
  while IFS= read -r file; do
    target="$home/${file#home/}"
    [[ -L "$target" && "$(readlink "$target")" == "$home/dotfiles/$file" ]] \
      || fail "$variant: $target is not a link to $home/dotfiles/$file"
  done < <(git -C "$REPO_ROOT" ls-files -- $_link_paths)
}

# Check the managed startup files in home $1 source env.sh and keep the user's own lines.
check_managed_blocks() {
  local variant="$1" home="$2" file
  for file in .profile .zprofile .bashrc .zshrc; do
    grep -q '^\. ~/dotfiles/home/\.config/sh/env\.sh$' "$home/$file" 2>/dev/null \
      || fail "$variant: $file does not source env.sh"
  done
  grep -q '^# user line$' "$home/.bashrc" || fail "$variant: the shell feature dropped the user's .bashrc lines"
}

# Check login and interactive bash and zsh load the startup files in home $1 without errors.
check_shells_load() {
  local variant="$1" home="$2" shell err
  # bash prints job control warnings when interactive without a terminal.
  for shell in "bash -lic" "bash -ic" "zsh -lic" "zsh -ic"; do
    have_or_skip "${shell%% *}" "sourcing the $variant startup files with $shell" || continue
    # shellcheck disable=SC2086 # $shell is a command and its options
    err="$(env -i HOME="$home" PATH=/usr/bin:/bin TERM=dumb $shell true 2>&1 </dev/null \
      | grep -vE 'cannot set terminal process group|no job control in this shell' || true)"
    [[ -z "$err" ]] || fail "$variant: $shell printed: $err"
  done
}

# A real install of the rootless features, then the same install again, which must change nothing. Variants that
# link anything under root/ need sudo, so only their --dry-run is tested.
test_install() {
  local variant="$1" flags="--link --gitconfig" managed=false repo_before first
  variant_info "$variant"
  case " $_link_paths" in *" root/"*) return ;; esac
  # Variants with the shell feature write managed blocks into the startup files instead of linking them.
  list_contains "$_features" shell && managed=true
  info "install: $variant"
  new_home
  if $managed; then
    flags+=" --shell"
    # The shell feature must keep what is already there. (Linked variants would back it up into the checkout.)
    printf '# user line\n' > "$_home/.bashrc"
  fi
  repo_before="$(repo_status)"

  # shellcheck disable=SC2086 # $flags is a list of options
  run_install "$_home" --variant "$variant" $flags || { fail "$variant install failed"; return; }
  check_links "$variant" "$_home"
  if $managed; then
    check_managed_blocks "$variant" "$_home"
  fi
  check_shells_load "$variant" "$_home"
  [[ "$(git config --file "$_home/.gitconfig" core.excludesFile)" == "$_home/dotfiles/home/.config/git/ignore" ]] \
    || fail "$variant: core.excludesFile not set in .gitconfig"

  first="$(snapshot "$_home")"
  # shellcheck disable=SC2086
  run_install "$_home" --variant "$variant" $flags || fail "$variant second install failed"
  [[ "$(snapshot "$_home")" == "$first" ]] || fail "$variant: a second install changed the home"
  [[ "$(repo_status)" == "$repo_before" ]] || fail "$variant: install wrote into the checkout"
}

# env.sh must be POSIX and safe to source more than once: a second source leaves PATH as it was.
test_env_sh() {
  local shell env_sh="$REPO_ROOT/home/.config/sh/env.sh"
  info "env.sh"
  for shell in sh bash zsh; do
    have_or_skip "$shell" "sourcing env.sh with $shell" || continue
    # shellcheck disable=SC2016 # expanded by $shell
    env -i HOME="$SCRATCH" PATH=/usr/bin:/bin "$shell" -c \
      '. "$1"; first=$PATH; . "$1"; [ "$PATH" = "$first" ]' sh "$env_sh" \
      || fail "sourcing env.sh twice with $shell changed PATH or failed"
  done
}

main() {
  local variants variant
  # shellcheck disable=SC2016 # expanded by $INSTALL_BASH
  info "install.sh runs under $("$INSTALL_BASH" -c 'echo "bash $BASH_VERSION"')"
  f_write_args all_variants _variants
  variants="$_variants"
  test_usage "$variants"
  for variant in $variants; do
    test_dry_run "$variant"
    test_install "$variant"
  done
  test_env_sh

  [[ "$FAILURES" == 0 ]] || error "$FAILURES check(s) failed"
  info "all install tests passed"
}

main "$@"
