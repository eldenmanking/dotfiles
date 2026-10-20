#
# ~/.bashrc
#

! (shopt -q login_shell) && . "$HOME/.bash_profile"             # Source profile if not a login shell
[[ $- != *i* ]] && return                                       # Leave if shell is not interactive (for safety)

# global config
source ~/dotfiles/.config/sh/aliases.sh
source ~/dotfiles/.config/sh/env.sh

