#!/bin/zsh

## Keybindings
bindkey -e                                                      # EMACS emulation default keymap
bindkey '^[[A' history-substring-search-up                      # Up key
bindkey '^[[B' history-substring-search-down                    # Down key
bindkey '^[[3~' delete-char                                     # Delete key
bindkey '^[u' undo                                              # Alt+u to undo last action
bindkey '^[r' redo                                              # Alt+r to redo last action
bindkey \^U backward-kill-line                                  # ctrl+u to delete from cursor to beginning of line

## Options section
setopt correct                                                  # Auto correct mistakes
setopt extendedglob                                             # Extended globbing. Allows using regular expressions with *
setopt nocaseglob                                               # Case insensitive globbing
setopt rcexpandparam                                            # Array expension with parameters
setopt nocheckjobs                                              # Don't warn about running processes when exiting
setopt numericglobsort                                          # Sort filenames numerically when it makes sense
setopt nobeep                                                   # No beep
setopt appendhistory                                            # Immediately append history instead of overwriting
setopt histignorealldups                                        # If a new command is a duplicate, remove the older one
setopt inc_append_history                                       # save commands are added to the history immediately, otherwise only when shell exits.
setopt histignorespace                                          # Don't save commands that start with space
setopt interactive_comments                                     # Allow comments in interactive shell

zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'       # Case insensitive tab completion
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"         # Colored completion (different colors for dirs/files/etc)
zstyle ':completion:*' rehash true                              # automatically find new executables in path

# Speed up completions
zstyle ':completion:*' accept-exact '*(N)'
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path ~/.zsh/cache
