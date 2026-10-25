# --dconf on a home with no dconf settings yet: the empty settings are backed up to ~/dotfiles/.backup, then
# dump/dconf/arch.dconf is loaded. dconf load writes through dconf-service, so install.sh runs with a session bus.
# AFTER_INSTALL dumps the result as text to compare; the second install must keep the first backup, not overwrite it.
IMAGE=arch
ARGS="--variant arch --dconf"
RUN_WITH="dbus-run-session --"
AFTER_INSTALL="dconf dump / > ~/dconf-dump.ini"
FILES="dconf-dump.ini"
