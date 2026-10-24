# My own zsh setup
bindkey -v

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

# A line after the section
alias ll="ls -l"
