#!/bin/bash
#
# ~/.bash_profile
#

# shellcheck source=.config/sh/env.sh
source ~/dotfiles/home/.config/sh/env.sh
# shellcheck source=.bashrc
[[ $- == *i* ]] && source ~/.bashrc                              # Login shells don't read .bashrc on their own
