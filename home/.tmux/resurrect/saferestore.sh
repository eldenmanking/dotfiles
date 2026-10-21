#!/bin/sh

usage() { echo "$0 [last|prev]"; }
# Print the resurrect files, oldest first (their names end in a timestamp).
resurrect_files() {
  for file in tmux_resurrect_*.txt; do
    [ -e "$file" ] && printf '%s\n' "$file"
  done
}
cd "$(dirname "$0")" || exit

# delete empty tmux_resurrect files
find . -maxdepth 1 -size 0 -regex "^\./tmux_resurrect_.*\.txt$" -delete

case "$1" in
  last | "" )
    ;;
  prev )
    last=$(resurrect_files | awk -v cur="$(basename "$(realpath last)")" '$0 == cur {print f; exit} {f = $0}')
    ;;
  * )
    usage
    exit 1;
    ;;
esac

# if last is empty, try to give it a resurrect file
if [ -z "$last" ]; then
  last=$(resurrect_files | tail -n 1)
fi

# if unable to find a resurrect file, then exit.
if [ -z "$last" ]; then
  echo "No tmux_resurrect_*.txt files available."
  exit 2
else
  ln -sf "$last" last
fi

# replace process with tmux-resurrect restore script
restore="$HOME/.tmux/plugins/tmux-resurrect/scripts/restore.sh"
if ! [ -f "$restore" ]; then
  echo "tmux-resurrect restore.sh script not found."
  exit 3
else
  exec "$restore"
fi
