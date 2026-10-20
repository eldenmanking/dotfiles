#!/bin/zsh

bindkey -e                                                      # EMACS emulation default keymap
bindkey '^[[A' history-substring-search-up                      # Up key
bindkey '^[[B' history-substring-search-down                    # Down key
bindkey '^[[3~' delete-char                                     # Delete key
bindkey '^[u' undo                                              # Alt+u to undo last action
bindkey '^[r' redo                                              # Alt+r to redo last action
bindkey \^U backward-kill-line                                  # ctrl+u to delete from cursor to beginning of line
