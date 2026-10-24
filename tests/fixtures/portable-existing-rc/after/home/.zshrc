# My own zsh setup
HISTFILE=~/.histfile
HISTSIZE=1000
SAVEHIST=1000
bindkey -v

export EDITOR=vim

## Managed by dotfiles

## feature zsh
. ~/dotfiles/home/.config/zsh/plugins.zsh

## feature shell
. ~/dotfiles/home/.config/sh/env.sh
. ~/dotfiles/home/.config/sh/aliases.sh
. ~/dotfiles/home/.config/zsh/keybindings.zsh
. ~/dotfiles/home/.config/zsh/settings.zsh
. ~/dotfiles/home/.config/zsh/external.zsh

## feature starship
. ~/dotfiles/home/.config/sh/starship.sh

## /Managed by dotfiles
