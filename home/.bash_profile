#
# ~/.bash_profile
#

source ~/dotfiles/home/.config/sh/env.sh
[[ $- == *i* ]] && source ~/.bashrc                              # Login shells don't read .bashrc on their own
