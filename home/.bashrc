#!/bin/bash
#
# ~/.bashrc
#

source "$HOME/dotfiles/home/.config/sh/env.sh"                       # For shells with no login shell above them
[[ $- != *i* ]] && return                                       # Leave if shell is not interactive

source "$HOME/dotfiles/home/.config/sh/aliases.sh"
