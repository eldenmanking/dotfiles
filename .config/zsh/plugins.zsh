#!/bin/zsh

# Source each plugin from ~/.zsh/plugins (cloned by the zsh install feature) or
# /usr/share/zsh/plugins (pacman). Order matters: syntax-highlighting must
# precede history-substring-search.
for plugin in zsh-autosuggestions zsh-syntax-highlighting zsh-history-substring-search; do
  for dir in ~/.zsh/plugins /usr/share/zsh/plugins; do
    if [[ -r $dir/$plugin/$plugin.zsh ]]; then
      source $dir/$plugin/$plugin.zsh
      break
    fi
  done
done
unset plugin dir
