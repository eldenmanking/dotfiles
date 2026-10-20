# Start the starship prompt in bash or zsh, if installed.
command -v starship >/dev/null 2>&1 || return 0
if [ -n "${ZSH_VERSION:-}" ]; then
  eval "$(starship init zsh)"
elif [ -n "${BASH_VERSION:-}" ]; then
  eval "$(starship init bash)"
fi
