# Shell startup files
Which files a shell reads depends on whether it is a **login** shell (ssh, console login, the desktop session, tmux panes) and whether it is **interactive**:

 - bash login shells read the first of .bash_profile, .bash_login and .profile; interactive non-login bash shells read .bashrc
 - zsh login shells read .zprofile; interactive zsh shells (login or not) read .zshrc

Environment variables are inherited, so they only need setting at login; aliases, functions and shell settings are not, so every interactive shell needs them. The files are split accordingly:

 - `home/.config/sh/env.sh` holds environment variables. It is POSIX sh and safe to source more than once. The profiles (.profile, .bash_profile, .zprofile) source it, and so do the rc files, for interactive shells with no login shell above them (e.g. code-server terminals).
 - Everything else in `home/.config/sh` and `home/.config/zsh` is interactive-only and is sourced from .bashrc and .zshrc.
 - .bash_profile also sources .bashrc when interactive, since bash login shells don't read it on their own. Nothing else sources another startup file.

The `shell` feature writes these sources into managed blocks of startup files it doesn't link (see [Managed files](features.md#managed-files)).
