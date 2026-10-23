#!/bin/bash
# TODO(andywang): add comment

[ -n "$TMUX_PANE" ] || exit 0

session_id=$(jq -r '.session_id // empty')
[ -n "$session_id" ] || exit 0

tmux set-option -p -t "$TMUX_PANE" @claude_session_id "$session_id" 2>/dev/null
exit 0
