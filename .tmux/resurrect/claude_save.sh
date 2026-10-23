#!/bin/bash
# TODO(andywang): add comment

resurrect_file="$1"
[ -f "$resurrect_file" ] || exit 0

strip_resume_args() {
  local -a out=()
  while [ $# -gt 0 ]; do
    case "$1" in
      -c|--continue) ;;
      -r|--resume|--session-id) [[ "$2" != -* ]] && shift ;;
      --resume=*|--session-id=*) ;;
      *) out+=("$1") ;;
    esac
    shift
  done
  echo "${out[*]}"
}

session_exists() {
  compgen -G "$HOME/.claude/projects/*/$1.jsonl" >/dev/null
}

tmp="$(mktemp)"
while IFS= read -r line; do
  full_command="${line##*$'\t'}"
  if [[ "$line" == pane$'\t'* && "$full_command" =~ ^:claude(\ |$) ]]; then
    target="$(cut -f2 <<<"$line"):$(cut -f3 <<<"$line").$(cut -f6 <<<"$line")"
    session_id="$(tmux show-options -pqv -t "$target" @claude_session_id 2>/dev/null)"
    if [ -n "$session_id" ] && session_exists "$session_id"; then
      read -ra args <<<"${full_command#:claude}"
      rest="$(strip_resume_args "${args[@]}")"
      line="${line%$'\t'*}"$'\t'":claude --resume ${session_id}${rest:+ $rest}"
    fi
  fi
  printf '%s\n' "$line"
done <"$resurrect_file" >"$tmp"
cat "$tmp" >"$resurrect_file"
rm -f "$tmp"
