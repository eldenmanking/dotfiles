# macOS setup notes
* keyboard
    * Switch caps <-> esc, fn <-> ctrl
    * input sources -> edit -> disable spelling, capitalization, period, smart quotes
    * Set repeat rate (see here), disable special character insertion (see here)
* Invert scroll
* Finder
    * view -> show path bar
    * view -> show as columns
* enable app expose (trackpad)
* Contexts
* chrome guest
* Install vimium, Adblock, bitwarden
    * Configure vimium: import vimium.conf from dotfiles; uncheck smooth scrolling; check ignore keyboard layout
* Setup useful search shortcuts
* Move dock to side and hide
* Disable automatically rearrange spaces based on most recent use
* Setup terminal
    * Clone dotfiles
    * Install brew -> powerlevel-10k
    * Install iterm2
    * Install tmux
    * Install nvim
    * Configure dotfiles
        * .config/nvim
        * .vimrc
        * .tmux.config
        * .tmux + install tpm -> ctrl-b+I
        * .zshrc aliases + .zprofile patpath extension
        * visx 
    * Configure iterm
        * tango dark
        * tmux/lunarvim color compatibility: background/foreground, green, blue, yellow (use onedark/palette.lua for reference)
        * silence bell
        * send Esc+ with left option
