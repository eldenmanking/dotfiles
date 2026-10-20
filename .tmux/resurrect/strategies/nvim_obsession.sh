#!/usr/bin/env bash

################################################################################
# Program: nvim_obsession.sh
# Description: tmux-resurrect strategy that restores nvim with its vim-obsession
#              session. Uses the saved "-S <file>" argument if it is an absolute
#              path (see vis), otherwise Session.vim in the pane's directory.
# Location: ~/.tmux/plugins/tmux-resurrect/strategies/nvim_obsession.sh
################################################################################

ORIGINAL_COMMAND="$1"
DIRECTORY="${2//\\ / }"
DIRECTORY="${DIRECTORY/#\~/$HOME}"

session_from_command() {
  local args=($ORIGINAL_COMMAND) i
  for ((i = 1; i < ${#args[@]}; i++)); do
    if [[ "${args[i]}" == -S && "${args[i+1]}" == /* && -f "${args[i+1]}" ]]; then
      echo "${args[i+1]}"
      return
    fi
  done
}

session_from_directory() {
  if [[ "$DIRECTORY" == /* && -f "$DIRECTORY/Session.vim" ]]; then
    echo "${DIRECTORY%/}/Session.vim"
  fi
}

main() {
  local session="$(session_from_command)"
  [[ -z "$session" ]] && session="$(session_from_directory)"

  if [[ -n "$session" ]]; then
    # vi is aliased to the preferred editor in the pane's shell
    printf 'cd %q && vi -S %q\n' "$(dirname "$session")" "$session"
  elif [[ "$ORIGINAL_COMMAND" =~ " -S" ]]; then
    # session file is gone; "-S" alone would error
    echo "vi"
  else
    echo "$ORIGINAL_COMMAND"
  fi
}
main
