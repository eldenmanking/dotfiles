# A steamos install with the Framework 16 fixes, then a SteamOS update: the update resets /etc except what keep lists
# name, so it moves before/root/etc/dummy.conf into /etc/previous, but the installed files must all survive (the
# second install checks that nothing needed restoring). The image's dirlock reports an encrypted home, so home_units
# installs too. See tests/images/steamos/steamos-update.
IMAGE=steamos
ARGS="--variant steamos --link --udev --tmpfiles --home_units"
AFTER_INSTALL="sudo steamos-update"
ROOT_FILES="/etc/atomic-update.conf.d /etc/udev/rules.d /etc/tmpfiles.d /etc/systemd/user /etc/dotfiles /etc/previous"
ROOT_FILES="$ROOT_FILES /etc/dummy.conf"
