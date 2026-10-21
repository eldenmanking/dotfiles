#!/bin/sh

# defaults
alias ls="ls --color=auto"                                      #
alias la="ls -la"                                               # list all with filesizes in MB
alias cp="cp -i"                                                # Confirm before overwriting something
alias df='df -h'                                                # Human-readable sizes
alias free='free -m'                                            # Show sizes in MB

# shortcuts
alias py=python3                                                # Python shortcut
alias activate=". venv/bin/activate"                            # Python virtual environment activation shortcut
alias vi=nvim                                                   #
alias vis="source vis"                                          # Allow vis to use the vi alias
alias gitu='git pull && git add -u && git commit && git push'   #
alias tt="gio trash"                                            # move file to trash

# git shortcuts
alias gs="git status"
alias gsn="git status -uno"
alias gd="git diff"
alias gds="git diff --staged"
alias gr="git restore --staged"
alias gc="git checkout"
alias ga="git add"
alias gam="ga -u && gm"
alias ghp="git stash push -u"
alias ghl="git stash list"
alias gmb="git merge-base"
alias gp="git push"
alias gnb="git rebase --no-verify --no-gpg-sign -i"
gfc () {
  git fetch origin "$1" && gc "$1"
}
gg() {
  cd "$(git rev-parse --show-toplevel)" || return
}
gm() {
  if [ -z "$1" ]; then
    git commit -S
  else
    git commit -S -m "$1"
  fi
} 
gmp() { gm "$1" && git push; }
gamp() { gam "$1" && git push; }
gn() { ga . && git commit --no-verify --no-gpg-sign -m "${1:-unsigned-wip}"; }
gnp() { ga . && git commit --no-verify --no-gpg-sign -m "${1:-unsigned-wip}" && git push; }
# Functions that need local variables run their body in a subshell (POSIX sh
# has no 'local'), so their variables don't leak into the interactive shell.
gb() (
  remote="$(git remote show)"
  rebase=""

  # The first *positional* argument (i.e. one that doesn't start with '-') is
  # still the rebase target, exactly as before. Everything else is treated as
  # pass-through options for `git rebase`, so `gb` behaves like a normal git
  # command: `gb --no-gpg-sign`, `gb main --autosquash`, `gb main --no-gpg-sign`
  # all work. A leading flag (e.g. `gb --no-gpg-sign`) leaves the target unset,
  # so the gh/HEAD detection below still computes it.
  if [ -n "$1" ] && [ "${1#-}" = "$1" ]; then
    rebase="$1"
    shift
  fi
  # Remaining "$@" is now the pass-through option list.

  command gh >/dev/null && target="$(gh pr view --json baseRefName -q '.baseRefName')"
  if [ -z "$target" ]; then
    echo "Could not use 'gh' to determine target branch."
  fi

  if [ -n "$rebase" ]; then
    echo "Using provided branch '$rebase' as rebase target."
  elif [ -n "$target" ]; then
    rebase="$target"
    echo "Using remote PR target branch '$rebase' as rebase target."
  else
    rebase="$(git rev-parse --abbrev-ref "$remote"/HEAD | sed "s@$remote/@@")"
    echo "Using remote HEAD '$rebase' as rebase target."
  fi

  if [ "$rebase" != "$target" ]; then
    echo "Warning: Remote target branch ('$target') is not the same as provided rebase branch ('$rebase')."
  fi

  if [ -z "$rebase" ]; then
    echo "Rebase branch could not be found."
    return 1
  fi

  # Pass-through options go AFTER the built-in `-S -i` so they can override the
  # defaults (e.g. `--no-gpg-sign` wins over `-S`); the upstream ref stays last.
  shown=""
  [ "$#" -gt 0 ] && shown=" $*"
  echo "Command to run: git fetch $remote $rebase && git rebase -S -i${shown} $remote/$rebase"
  # Wait for a single keypress (like bash 'read -n 1' / zsh 'read -k 1').
  stty -icanon min 1 time 0 2>/dev/null
  dd bs=1 count=1 >/dev/null 2>&1
  stty icanon 2>/dev/null
  echo "Running command..."
  git fetch "$remote" "$rebase" && git rebase -S -i "$@" "$remote/$rebase"
)
gbg() (
  if [ -n "$1" ]; then
    base="$1"
  else
    base="$(git log -50 --format='%H %G?' | awk '$2 ~ /^[GUEX]$/ {print $1; exit}')"
  fi
  if [ -z "$base" ]; then
    echo "No signed parent commit found."
    return 1
  fi
  echo "Rebasing onto: $(git log --oneline -1 "$base")"
  git rebase --exec 'git commit --amend --no-edit -n -S --allow-empty' "$base"
)
gu() (
  branch="$(git rev-parse --abbrev-ref @)"
  remote="$(git remote show)"
  git fetch "$remote" "$branch"
  git reset --hard "$remote/$branch"
)
gal() (
  host=$(gh auth status --json hosts --jq '.hosts | keys[0]') || return 1
  dir=$(mktemp -d)
  cat >"$dir/xclip" <<EOF
#!/bin/sh
PATH="\${PATH#$dir:}"   # drop shim dir so clip doesn't re-invoke this wrapper
exec clip > /dev/tty    # gh discards the helper's stdout — send clip's OSC 52 to the real terminal
EOF
  chmod +x "$dir/xclip"
  PATH="$dir:$PATH" gh auth login -h "$host" -c -p https < /dev/null
  rm -rf "$dir"
)


# miscellaneous software shortcuts
alias dnuke='docker kill $(docker ps -aq); docker rm -fv $(docker ps -aq)'
