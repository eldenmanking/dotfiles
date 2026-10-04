#!/bin/zsh

export HISTFILE=~/.zhistory
export HISTSIZE=10000
export SAVEHIST=10000
export WORDCHARS=${WORDCHARS//\/[&.;]}                          # Don't consider certain characters as words
export ZLE_RPROMPT_INDENT=0                                     # No space after right prompt
typeset -U path                                                 # Remove duplicates in path/PATH
