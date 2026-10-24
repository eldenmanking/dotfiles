#!/usr/bin/env bash
# Exercise install.sh in scratch home directories: usage, --dry-run for every variant, real rootless installs and
# their idempotency, and the resulting shell startup files. Run via `make test`. INSTALL_BASH picks the bash that runs
# install.sh (CI sets /bin/bash on macOS to test bash 3.2).

set -euo pipefail

# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

INSTALL_BASH="${INSTALL_BASH:-bash}"
SCRATCH="$(mktemp -d)"
LOG="$SCRATCH/install.log"
# Features that check for a live host even under --dry-run: webterm needs a systemd user session.
DRY_RUN_SKIP=" webterm "

FAILURES=0
trap 'rm -rf "$SCRATCH"' EXIT

# Report a passed check.
pass() {
  printf '  \033[32mok\033[0m   %s\n' "$*"
}

# Report a failed check and keep going, so one run reports every failure.
fail() {
  printf '  \033[31mFAIL\033[0m %s\n' "$*" >&2
  FAILURES=$((FAILURES + 1))
}

# Report check $1 as passed if the remaining args, run as a command, succeed.
check() {
  local description="$1"
  shift
  if "$@"; then pass "$description"; else fail "$description"; fi
}

# Outputs: _home, a new scratch home holding a dotfiles symlink to this checkout, as install.sh requires.
new_home() {
  local home
  home="$(mktemp -d "$SCRATCH/home.XXXXXX")"
  ln -s "$REPO_ROOT" "$home/dotfiles"
  _home="$home"
}

# Run install.sh with home $1 and the remaining args, in a clean environment with no terminal. Its output goes to
# LOG. Returns install.sh's status.
run_install() {
  local home="$1"
  shift
  env -i HOME="$home" PATH="$PATH" TERM=dumb "$INSTALL_BASH" "$home/dotfiles/install.sh" "$@" </dev/null >"$LOG" 2>&1
}

# Run install.sh like run_install and report it as a check that it succeeds, showing its output if not.
install_ok() {
  local home="$1"
  shift
  if run_install "$home" "$@"; then
    pass "install.sh${*:+ $*}"
  else
    fail "install.sh${*:+ $*}"
    sed 's/^/       | /' "$LOG" >&2
    return 1
  fi
}

# Run install.sh like run_install and report it as a check that it refuses.
install_refused() {
  local home="$1"
  shift
  if run_install "$home" "$@"; then fail "install.sh${*:+ $*} (should be refused)"; else pass "install.sh${*:+ $*} (refused)"; fi
}

# Outputs: _features and _link_paths of variant $1, read from its definition the same way install.sh does, and
# _dry_run_features, the features that honor --dry-run (install.sh only announces the others).
variant_info() {
  local variant="$1" out
  out="$(
    set +u
    for f in "$REPO_ROOT"/install/lib/*.sh "$REPO_ROOT"/install/features/*.sh "$REPO_ROOT/install/variants/$variant.sh"; do
      # shellcheck source=/dev/null
      source "$f"
    done
    "variant_$variant"
    printf '%s\n%s\n%s\n' "$_features" "$_link_paths" "$DRY_RUN_FEATURES"
  )"
  _features="${out%%$'\n'*}"
  out="${out#*$'\n'}"
  _link_paths="${out%%$'\n'*}"
  _dry_run_features="${out#*$'\n'}"
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

# Report check $1: snapshot $3 must equal snapshot $2, or the lines that differ are shown.
check_unchanged() {
  local description="$1" before="$2" after="$3"
  if [[ "$before" == "$after" ]]; then
    pass "$description"
  else
    fail "$description; changed (- before, + after):"
    diff <(printf '%s\n' "$before") <(printf '%s\n' "$after") | grep '^[<>]' | sed 's/^</       -/; s/^>/       +/' >&2 || true
  fi
}

repo_status() {
  # --ignored too, since backups would land in the ignored dotfiles/.backup.
  git -C "$REPO_ROOT" status --porcelain --untracked-files=all --ignored
}

# Print the name of every variant in install/variants.
all_variants() {
  local f names=""
  for f in "$REPO_ROOT"/install/variants/*.sh; do
    f="${f##*/}"
    names+="${names:+ }${f%.sh}"
  done
  printf '%s' "$names"
}

test_usage() {
  local variants="$1" variant
  info "usage"
  new_home
  install_ok "$_home" || true
  for variant in $variants; do
    install_ok "$_home" --variant "$variant" --help && check "  ...lists --link" grep -q -- '--link' "$LOG"
  done
  install_refused "$_home" --variant nope
  install_refused "$_home" --variant coder --nope
}

# Write install.conf in home $1 with the remaining args as its lines.
write_install_conf() {
  local home="$1"
  shift
  mkdir -p "$home/.config/dotfiles"
  printf '%s\n' "$@" > "$home/.config/dotfiles/install.conf"
}

# DOTFILES_VARIANT and DOTFILES_FEATURES, from the environment or ~/.config/dotfiles/install.conf, stand in for
# --variant and the feature options when the command line leaves them out.
test_defaults() {
  local out
  info "defaults: DOTFILES_VARIANT and DOTFILES_FEATURES from install.conf or the environment"
  new_home
  write_install_conf "$_home" "DOTFILES_VARIANT=coder"
  install_ok "$_home" && check "  ...lists the default variant's options" grep -q "Options for variant 'coder'" "$LOG"

  write_install_conf "$_home" "DOTFILES_VARIANT=coder" "DOTFILES_FEATURES=all"
  install_ok "$_home" --dry-run && check "  ...runs --all" grep -q "would run feature: binaries" "$LOG"
  install_ok "$_home" --variant arch && check "  ...ignores the features for another variant" \
    grep -q "Options for variant 'arch'" "$LOG"
  install_ok "$_home" --dry-run --uninstall \
    && check "  ...ignores the features under --uninstall" grep -q "Options for variant 'coder'" "$LOG"
  install_ok "$_home" --dry-run --gitconfig && check "  ...lets options override the features" \
    sh -c '! grep -q "would run feature: binaries" "$1"' sh "$LOG"
  if out="$(env -i HOME="$_home" PATH="$PATH" TERM=dumb DOTFILES_VARIANT=portable DOTFILES_FEATURES=gitconfig \
    "$INSTALL_BASH" "$_home/dotfiles/install.sh" --dry-run </dev/null 2>&1)" \
    && grep -q "variant: portable" <<< "$out" && grep -q "git config --global" <<< "$out"; then
    pass "the environment overrides install.conf"
  else
    fail "the environment overrides install.conf: $out"
  fi

  write_install_conf "$_home" "DOTFILES_VARIANT=coder" "DOTFILES_FEATURES=gitconfig"
  install_ok "$_home" && check "  ...installs with no arguments" grep -q "excludesFile" "$_home/.gitconfig"

  write_install_conf "$_home" 'DOTFILES_VARIANT="$UNSET_VARIABLE"'
  install_refused "$_home" --dry-run
  write_install_conf "$_home" "DOTFILES_VARIANT=nope"
  install_refused "$_home"
}

# Run install.sh at $1 with home $2 and expect it to refuse, with a message matching $3. $4 describes the case.
expect_refused() {
  local script="$1" home="$2" pattern="$3" description="$4" out
  if out="$(env -i HOME="$home" PATH="$PATH" "$INSTALL_BASH" "$script" --variant coder --gitconfig </dev/null 2>&1)"; then
    fail "install.sh ran from $script with HOME=$home"
  elif ! grep -q -- "$pattern" <<< "$out"; then
    fail "install.sh from $script: expected '$pattern', got: $out"
  else
    pass "refused $description"
  fi
}

# Commit to repo $1 with message $2, as a test user.
test_commit() {
  git -C "$1" -c user.name=test -c user.email=test@example.com -c commit.gpgsign=false \
    commit --quiet --allow-empty -m "$2"
}

# Clone this checkout to $1 on branch main, as a GitHub repo would be (CI checks out a detached HEAD), and commit the
# working tree's install.sh and install/ there, so tests that clone it test them rather than the last commit.
clone_working_tree() {
  local src="$1"
  git -c advice.detachedHead=false clone --quiet "$REPO_ROOT" "$src"
  git -C "$src" checkout --quiet -B main
  cp -R "$REPO_ROOT/install.sh" "$REPO_ROOT/install" "$src/"
  git -C "$src" add -A
  test_commit "$src" "working tree"
}

# Run from a git checkout elsewhere with no ~/dotfiles, install.sh clones that checkout's commit to ~/dotfiles, keeps
# its origin, and installs from the clone.
test_clone_checkout() {
  local home src
  info "checkout location: install.sh clones a checkout elsewhere to ~/dotfiles"
  home="$(mktemp -d "$SCRATCH/home.XXXXXX")"
  src="$SCRATCH/coder-checkout"
  clone_working_tree "$src"
  git -C "$src" remote set-url origin https://example.com/dotfiles.git
  printf 'local change\n' > "$src/uncommitted"
  if env -i HOME="$home" PATH="$PATH" TERM=dumb "$INSTALL_BASH" "$src/install.sh" --variant coder --gitconfig \
    </dev/null >"$LOG" 2>&1; then
    pass "install.sh from $src"
  else
    fail "install.sh from $src"
    sed 's/^/       | /' "$LOG" >&2
    return
  fi
  check "  ...cloned the same commit" \
    test "$(git -C "$home/dotfiles" rev-parse HEAD)" = "$(git -C "$src" rev-parse HEAD)"
  check "  ...kept the origin" test "$(git -C "$home/dotfiles" remote get-url origin)" = https://example.com/dotfiles.git
  check "  ...warned about uncommitted changes" grep -q "uncommitted changes" "$LOG"
  check "  ...installed from the clone" grep -q "$home/dotfiles/home/.config/git/ignore" "$home/.gitconfig"
}

# Run on its own (as with curl), install.sh clones PINNED_REPO at PINNED_COMMIT, on the default branch so it can be
# pulled; with DOTFILES_REPO naming another repo it clones that repo's tip instead.
test_bootstrap_pin() {
  local src pinned script home
  info "bootstrap: install.sh on its own clones its pinned commit to ~/dotfiles"
  src="$SCRATCH/pinned-repo"
  clone_working_tree "$src"
  pinned="$(git -C "$src" rev-parse HEAD)"
  test_commit "$src" "after the pin"
  mkdir "$SCRATCH/standalone"
  script="$SCRATCH/standalone/install.sh"
  sed -e "s#^PINNED_REPO=.*#PINNED_REPO=\"$src\"#" -e "s#^PINNED_COMMIT=.*#PINNED_COMMIT=\"$pinned\"#" \
    "$REPO_ROOT/install.sh" > "$script"

  home="$(mktemp -d "$SCRATCH/home.XXXXXX")"
  if env -i HOME="$home" PATH="$PATH" TERM=dumb "$INSTALL_BASH" "$script" --variant coder --gitconfig \
    </dev/null >"$LOG" 2>&1; then
    pass "install.sh on its own"
    check "  ...checked out the pinned commit" test "$(git -C "$home/dotfiles" rev-parse HEAD)" = "$pinned"
    check "  ...on the default branch" test -n "$(git -C "$home/dotfiles" symbolic-ref -q HEAD)"
  else
    fail "install.sh on its own"
    sed 's/^/       | /' "$LOG" >&2
  fi

  # A repo whose HEAD is detached gets the pinned commit detached.
  git -C "$src" checkout --quiet --detach
  home="$(mktemp -d "$SCRATCH/home.XXXXXX")"
  if env -i HOME="$home" PATH="$PATH" TERM=dumb "$INSTALL_BASH" "$script" --variant coder --gitconfig \
    </dev/null >"$LOG" 2>&1; then
    pass "install.sh on its own, from a repo with a detached HEAD"
    check "  ...checked out the pinned commit" test "$(git -C "$home/dotfiles" rev-parse HEAD)" = "$pinned"
  else
    fail "install.sh on its own, from a repo with a detached HEAD"
    sed 's/^/       | /' "$LOG" >&2
  fi
  git -C "$src" checkout --quiet main

  home="$(mktemp -d "$SCRATCH/home.XXXXXX")"
  if env -i HOME="$home" PATH="$PATH" TERM=dumb DOTFILES_REPO="file://$src" "$INSTALL_BASH" "$script" \
    --variant coder --gitconfig </dev/null >"$LOG" 2>&1; then
    pass "install.sh on its own with DOTFILES_REPO"
    check "  ...checked out that repo's tip" \
      test "$(git -C "$home/dotfiles" rev-parse HEAD)" = "$(git -C "$src" rev-parse HEAD)"
  else
    fail "install.sh on its own with DOTFILES_REPO"
    sed 's/^/       | /' "$LOG" >&2
  fi
}

# install.sh must run from ~/dotfiles (or a link to it), and the checkout must be named dotfiles.
test_checkout_location() {
  local home other
  info "checkout location: install.sh refuses to run from anywhere but a checkout named dotfiles at ~/dotfiles"
  home="$(mktemp -d "$SCRATCH/home.XXXXXX")"
  # A copy that isn't a git checkout, so it can't be cloned to ~/dotfiles.
  other="$SCRATCH/not-dotfiles"
  mkdir "$other"
  cp -R "$REPO_ROOT/install.sh" "$REPO_ROOT/install" "$other/"
  expect_refused "$other/install.sh" "$home" "must be checked out at $home/dotfiles" \
    "with no ~/dotfiles, from a copy that isn't a git checkout"
  mkdir "$home/dotfiles"
  expect_refused "$REPO_ROOT/install.sh" "$home" "is not $home/dotfiles" "from a checkout other than ~/dotfiles"
  rmdir "$home/dotfiles"
  # The copy, linked as ~/dotfiles.
  ln -s "$other" "$home/dotfiles"
  expect_refused "$home/dotfiles/install.sh" "$home" "must be a directory named dotfiles" \
    "with ~/dotfiles linked to a checkout named not-dotfiles"
}

# --dry-run must succeed and leave the home untouched, for install, reinstall and uninstall.
test_dry_run() {
  local variant="$1" flags=() feature mode before skipped="" announced=""
  variant_info "$variant"
  for feature in $_features; do
    if list_contains "$DRY_RUN_SKIP" "$feature"; then
      skipped+=" $feature"
      continue
    fi
    flags+=("--$feature")
    list_contains "$_dry_run_features" "$feature" || announced+=" $feature"
  done
  info "$variant: dry run of every feature${skipped:+ except$skipped (needs a live systemd user session)}"
  [[ -z "$announced" ]] || info "  (without --dry-run support, so only announced:$announced)"
  new_home
  before="$(snapshot "$_home")"
  for mode in "" --reinstall --uninstall; do
    install_ok "$_home" --variant "$variant" --dry-run ${mode:+"$mode"} "${flags[@]}" || true
  done
  check_unchanged "home unchanged" "$before" "$(snapshot "$_home")"
}

# Check that every file under the variant's link paths is linked into home $1.
check_links() {
  local variant="$1" home="$2" file target count=0 bad=0 paths
  variant_info "$variant"
  read -r -a paths <<< "$_link_paths"
  while IFS= read -r file; do
    target="$home/${file#home/}"
    count=$((count + 1))
    if [[ ! -L "$target" || "$(readlink "$target")" != "$home/dotfiles/$file" ]]; then
      fail "link missing or wrong: ~/${file#home/} should point to ~/dotfiles/$file"
      bad=$((bad + 1))
    fi
  done < <(git -C "$REPO_ROOT" ls-files -- "${paths[@]}")
  [[ "$bad" != 0 ]] || pass "all $count files under the link paths are linked into ~"
}

# Check the managed startup files in home $1 source env.sh and keep the user's own lines.
check_managed_blocks() {
  local variant="$1" home="$2" file
  for file in .profile .zprofile .bashrc .zshrc; do
    check "managed block in ~/$file sources env.sh" grep -q '^\. ~/dotfiles/home/\.config/sh/env\.sh$' "$home/$file"
  done
  check "user's own line in ~/.bashrc kept" grep -q '^# user line$' "$home/.bashrc"
}

# Check login and interactive bash and zsh load the startup files in home $1 without errors.
check_shells_load() {
  local variant="$1" home="$2" shell opts err
  for shell in bash zsh; do
    have_or_skip "$shell" "sourcing the $variant startup files with $shell" || continue
    for opts in -lic -ic; do
      # bash prints job control warnings when interactive without a terminal.
      err="$(env -i HOME="$home" PATH=/usr/bin:/bin TERM=dumb "$shell" "$opts" true 2>&1 </dev/null \
        | grep -vE 'cannot set terminal process group|no job control in this shell' || true)"
      if [[ -z "$err" ]]; then
        pass "$shell $opts loads the startup files without errors"
      else
        fail "$shell $opts printed: $err"
      fi
    done
  done
}

# A real install of the rootless features, then the same install again, which must change nothing. Variants that
# link anything under root/ need sudo, so only their --dry-run is tested.
test_install() {
  local variant="$1" flags=(--link --gitconfig) managed=false repo_before first
  variant_info "$variant"
  case " $_link_paths" in
    *" root/"*)
      info "$variant: no real install (its links include root/, which needs sudo)"
      return
      ;;
  esac
  # Variants with the shell feature write managed blocks into the startup files instead of linking them.
  list_contains "$_features" shell && managed=true
  $managed && flags+=(--shell)
  info "$variant: real install of ${flags[*]} (the other features download, build or need root)"
  new_home
  if $managed; then
    # The shell feature must keep what is already there. (Linked variants would back it up into the checkout.)
    printf '# user line\n' > "$_home/.bashrc"
  fi
  repo_before="$(repo_status)"

  install_ok "$_home" --variant "$variant" "${flags[@]}" || return
  check_links "$variant" "$_home"
  if $managed; then
    check_managed_blocks "$variant" "$_home"
  fi
  check_shells_load "$variant" "$_home"
  check "core.excludesFile set in ~/.gitconfig" \
    [ "$(git config --file "$_home/.gitconfig" core.excludesFile)" = "$_home/dotfiles/home/.config/git/ignore" ]

  first="$(snapshot "$_home")"
  install_ok "$_home" --variant "$variant" "${flags[@]}" || true
  check_unchanged "  ...the second install changed nothing" "$first" "$(snapshot "$_home")"
  check_unchanged "nothing was written into the checkout" "$repo_before" "$(repo_status)"
}

# env.sh must be POSIX and safe to source more than once: a second source leaves PATH as it was.
test_env_sh() {
  local shell env_sh="$REPO_ROOT/home/.config/sh/env.sh"
  info "env.sh: sourcing it twice leaves PATH unchanged"
  for shell in sh bash zsh; do
    have_or_skip "$shell" "sourcing env.sh with $shell" || continue
    check "$shell" env -i HOME="$SCRATCH" PATH=/usr/bin:/bin "$shell" -c \
      '. "$1"; first=$PATH; . "$1"; [ "$PATH" = "$first" ]' sh "$env_sh"
  done

  # The gnome Qt theme overrides other desktops' themes (e.g. Plasma's icons and colors), so only gnome gets it.
  info "env.sh: sets QT_QPA_PLATFORMTHEME only in gnome"
  check "set in gnome" env -i HOME="$SCRATCH" PATH=/usr/bin:/bin XDG_CURRENT_DESKTOP=ubuntu:GNOME sh -c \
    '. "$1"; [ "${QT_QPA_PLATFORMTHEME:-}" = gnome ]' sh "$env_sh"
  check "unset in KDE" env -i HOME="$SCRATCH" PATH=/usr/bin:/bin XDG_CURRENT_DESKTOP=KDE sh -c \
    '. "$1"; [ -z "${QT_QPA_PLATFORMTHEME:-}" ]' sh "$env_sh"
}

# The steam feature replaces the hotkeys Steam already wrote, keeps the other settings, warns about missing keys
# instead of adding them, backs up the file and changes nothing on a second run.
test_steam() {
  local userdata vdf_a vdf_b b_before first
  info "steam: hotkeys replaced in localconfig.vdf"
  if pgrep -x steam >/dev/null 2>&1; then
    warn "Steam is running; skipping the steam feature test"
    return
  fi
  new_home
  userdata="$_home/.local/share/Steam/userdata"
  vdf_a="$userdata/1/config/localconfig.vdf"
  vdf_b="$userdata/2/config/localconfig.vdf"
  mkdir -p "${vdf_a%/*}" "${vdf_b%/*}"
  printf '"UserLocalConfigStore"\n{\n\t"Gamescope"\n\t{\n\t\t"GameResolutionGlobal"\t\t"Default"\n' > "$vdf_a"
  printf '\t\t"GuideKeyboardHotkey"\t\t"Ctrl\tWin\tKEY_TAB"\n\t\t"QAMKeyboardHotkey"\t\t"Shift\tKEY_TAB"\n' >> "$vdf_a"
  printf '\t}\n}\n' >> "$vdf_a"
  printf '"UserLocalConfigStore"\n{\n\t"friends"\t\t"1"\n}\n' > "$vdf_b"
  b_before="$(cat "$vdf_b")"

  install_ok "$_home" --variant steamos --steam || return
  check "main menu hotkey replaced" grep -qx $'\t\t"GuideKeyboardHotkey"\t\t"Win\tKEY_TAB"' "$vdf_a"
  check "quick access hotkey replaced" grep -qx $'\t\t"QAMKeyboardHotkey"\t\t"Shift\tWin\tKEY_TAB"' "$vdf_a"
  check "other settings kept" grep -q '"GameResolutionGlobal"' "$vdf_a"
  check "missing keys not added" [ "$(cat "$vdf_b")" = "$b_before" ]
  check "  ...but warned about" grep -q "$vdf_b has no GuideKeyboardHotkey QAMKeyboardHotkey" "$LOG"
  check "original backed up" grep -q '"Ctrl' "$REPO_ROOT/.backup$vdf_a"
  first="$(snapshot "$_home")"
  install_ok "$_home" --variant steamos --steam || true
  check_unchanged "  ...the second install changed nothing" "$first" "$(snapshot "$_home")"
  # Backups land in the checkout (the scratch home links to it).
  rm -rf "$REPO_ROOT/.backup$SCRATCH"
  rmdir -p "$(dirname "$REPO_ROOT/.backup$SCRATCH")" 2>/dev/null || true
}

main() {
  local variants variant
  info "install.sh runs under $("$INSTALL_BASH" -c 'echo "bash $BASH_VERSION"')"
  variants="$(all_variants)"
  test_usage "$variants"
  test_defaults
  test_checkout_location
  test_clone_checkout
  test_bootstrap_pin
  for variant in $variants; do
    test_dry_run "$variant"
    test_install "$variant"
  done
  test_steam
  test_env_sh

  [[ "$FAILURES" == 0 ]] || error "$FAILURES check(s) failed"
  info "all install tests passed"
}

main "$@"
