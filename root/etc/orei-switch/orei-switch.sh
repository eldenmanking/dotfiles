#!/bin/bash
# Hand the OREI HDMI switch to another input on sleep and back to this laptop on wake. Installed into /etc/orei-switch
# by the orei_switch feature of ~/dotfiles/install.sh, and run by orei-switch.service.
#
# The OREI ignores CEC and only switches on a fresh HDMI +5V edge, or falls back to another live input once the
# selected input's 5V stays gone. Cutting power to the left PD controller (ports 2 and 3, including the HDMI card on
# port 2) drops 5V for the whole sleep, and restoring it on wake makes a new edge. A charger on port 3 is cut too, so
# keep it on the right side.
FWT=/etc/orei-switch/framework_tool
PD=1      # left PD controller (ports 2,3); right is 0
UCSI=/sys/kernel/debug/usb/ucsi/USBC000:00
CONN=3    # UCSI connector for the HDMI card (typec port2 + 1)

log() { logger -t orei-switch "$*"; }

external_connected() { grep -qx connected /sys/class/drm/card*-DP-*/status 2>/dev/null; }

# Reset the HDMI card's connector, a software replug.
ucsi_reset() {
  printf '0x%x\n' $(( 0x03 | (CONN << 16) )) > "$UCSI/command"
  cat "$UCSI/response" >/dev/null
}

case "$1" in
  sleep)
    log "disabling PD $PD"
    "$FWT" --pd-disable "$PD"
    sleep 1
    ;;
  wake)
    log "enabling PD $PD"
    "$FWT" --pd-enable "$PD"
    sleep 10
    # The first reset makes the OREI switch, the second gives a clean hotplug so video comes up.
    if ! external_connected; then
      log "fallback UCSI resets"
      ucsi_reset
      sleep 10
      ucsi_reset
    fi
    ;;
  *)
    echo "usage: $0 sleep|wake" >&2
    exit 2
    ;;
esac
