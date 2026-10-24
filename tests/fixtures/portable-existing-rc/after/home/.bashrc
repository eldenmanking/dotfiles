#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '

export EDITOR=vim

## Managed by dotfiles

## feature shell
. ~/dotfiles/home/.config/sh/env.sh
. ~/dotfiles/home/.config/sh/aliases.sh

## feature starship
. ~/dotfiles/home/.config/sh/starship.sh

## /Managed by dotfiles
