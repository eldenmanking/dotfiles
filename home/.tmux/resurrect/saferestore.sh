#!/bin/sh

usage() { echo "$0 [last|prev]"; }
cd $(dirname $0)

# delete empty tmux_resurrect files
find . -maxdepth 1 -size 0 -regex "^\./tmux_resurrect_.*\.txt$" -delete

case "$1" in
  last | "" )
    ;;
  prev )
    last=$(ls | grep -E "^tmux_resurrect_.*\.txt" | awk '$0=="'$(basename $(realpath last))'"{print f; exit} {f=$0}')
    ;;
  * )
    usage
    exit 1;
    ;;
esac

# if last is empty, try to give it a resurrect file
if [ -z $last ]; then
  last=$(ls | grep -E "^tmux_resurrect_.*\.txt$" | tail -n 1)
fi

# if unable to find a resurrect file, then exit.
if [ -z $last ]; then
  echo "No tmux_resurrect_*.txt files available."
  exit 2
else
  ln -sf $last last
fi

# replace process with tmux-resurrect restore script
restore="$HOME/.tmux/plugins/tmux-resurrect/scripts/restore.sh"
if ! [ -f $restore ]; then
  echo "tmux-resurrect restore.sh script not found."
  exit 3
else
  exec "$restore"
fi
