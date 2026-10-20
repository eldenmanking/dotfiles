#
# ~/.bashrc
#

! (shopt -q login_shell) && . "$HOME/.bash_profile"             # Source profile if not a login shell
[[ $- != *i* ]] && return                                       # Leave if shell is not interactive (for safety)

# Shell settings
export PROMPT_DIRTRIM=3 # Only show last three directories in filepath
export PS1="\[\e[32m\]\h:\w\\[\e[0m\]$ " # Shell prompt format

# Aliases
source ~/dotfiles/.config/sh/aliases.sh

