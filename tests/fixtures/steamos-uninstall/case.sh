# A steamos install of every feature there that can be undone in a container, then --uninstall twice (the second finds
# nothing to remove) and --reinstall, which AFTER_INSTALL checks as it goes: after the uninstalls the installed files
# and keep list blocks are gone, after the reinstall they are back. The reinstall leaves the state of the first
# install, so after/ shows that and the second install must change nothing. Features that need a desktop session or a
# download (webterm, steamos_xclip, steamos_arch_vm, distrobox) can't run here, and hdmi_audio_fix's uninstall writes
# to the host's GPU through /sys if the container can see one, so it is left out too.
IMAGE=steamos
FEATURES="--orei_switch --light_sleep --gamescope_screenshot"
ARGS="--variant steamos --machine framework16 --link $FEATURES"
ROOT_FILES="/etc/atomic-update.conf.d /etc/previous /etc/dotfiles/bin /etc/sddm.conf.d /etc/systemd/user"
ROOT_FILES="$ROOT_FILES /etc/systemd/system/systemd-suspend.service.d"
for unit in orei-switch orei-switch-boot orei-switch-poweroff; do
  ROOT_FILES="$ROOT_FILES /etc/systemd/system/$unit.service"
done
INSTALL="bash \$HOME/dotfiles/install.sh --variant steamos --machine framework16"
# Fail unless none of the features' files is installed.
GONE='! test -e /etc/dotfiles/bin/light-sleep && ! test -e /etc/dotfiles/bin/orei-switch'
GONE="$GONE && ! test -e /etc/systemd/system/orei-switch.service"
GONE="$GONE && ! test -e /etc/systemd/system/systemd-suspend.service.d/light-sleep.conf"
GONE="$GONE && ! test -e /etc/systemd/user/gamescope-screenshot.service"
GONE="$GONE && ! grep -q -e light_sleep -e orei_switch /etc/atomic-update.conf.d/dotfiles.conf"
AFTER_INSTALL="$INSTALL --uninstall $FEATURES && $INSTALL --uninstall $FEATURES && $GONE"
AFTER_INSTALL="$AFTER_INSTALL && $INSTALL --reinstall $FEATURES && test -x /etc/dotfiles/bin/light-sleep"
