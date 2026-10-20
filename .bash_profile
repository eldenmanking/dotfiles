#
# ~/.bash_profile
#

source ~/dotfiles/.config/sh/env.sh
[[ $- == *i* ]] && source ~/.bashrc                              # Login shells don't read .bashrc on their own
