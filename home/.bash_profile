#!/bin/bash
#
# ~/.bash_profile
#

source "$HOME/dotfiles/home/.config/sh/env.sh"
[[ $- == *i* ]] && source "$HOME/.bashrc"                        # Login shells don't read .bashrc on their own
