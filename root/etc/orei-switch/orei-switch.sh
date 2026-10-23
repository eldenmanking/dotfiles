#!/bin/bash
# Hand the OREI HDMI switch to another input on sleep and back to this laptop on wake, and turn the projector off on
# sleep and poweroff and back on on wake. Installed into /etc/orei-switch by the orei_switch feature of
# ~/dotfiles/install.sh, and run by orei-switch.service (sleep, wake) and orei-switch-poweroff.service (poweroff). See
# docs/orei-switch.md.
#
# The OREI ignores CEC and only switches on a fresh HDMI +5V edge, or falls back to another live input once the
# selected input's 5V stays gone. Cutting power to the left PD controller (ports 2 and 3, including the HDMI card on
# port 2) drops 5V for the whole sleep, and restoring it on wake makes a new edge. A charger on port 3 is cut too, so
# keep it on the right side.
FWT=/etc/orei-switch/framework_tool
PD=1      # left PD controller (ports 2,3); right is 0
UCSI=/sys/kernel/debug/usb/ucsi/USBC000:00
CONN=3    # UCSI connector for the HDMI card (typec port2 + 1)
CEC_DRIVER=amdgpu  # find the CEC adapter by driver: it is re-registered on each resume, as /dev/cec0 or /dev/cec1
PD_WAIT=10    # seconds to wait for the display after enabling PD (5.4s when tested)
RESET_WAIT=6  # seconds to wait for the display after each UCSI reset

log() { logger -t orei-switch "$*"; }

external_connected() { grep -qx connected /sys/class/drm/card*-DP-*/status 2>/dev/null; }

# Return 0 once an external display is connected, or 1 after $1 seconds.
wait_connected() {
  local i
  for (( i = 0; i < $1 * 4; i++ )); do
    external_connected && return 0
    sleep 0.25
  done
  return 1
}

# Reset the HDMI card's connector, a software replug.
ucsi_reset() {
  printf '0x%x\n' $(( 0x03 | (CONN << 16) )) > "$UCSI/command"
  cat "$UCSI/response" >/dev/null
}

# Press the projector's Power Off key over CEC: it ignores <Standby>. CEC needs HPD, so this only reaches the projector
# while the OREI shows this laptop, which also keeps it from turning off another input's picture.
projector_off() {
  if ! external_connected; then
    log "no external display; leaving the projector alone"
    return
  fi
  cec_ready
  log "turning the projector off"
  if ! cec-ctl -s -D "$CEC_DRIVER" --to 0 --user-control-pressed ui-cmd=power-off-function >/dev/null \
    || ! cec-ctl -s -D "$CEC_DRIVER" --to 0 --user-control-released >/dev/null; then
    log "CEC power off failed"
  fi
}

# Wake the projector with <Image View On>. SteamOS's cecd also tries on resume, but the projector doesn't respond to it.
projector_on() {
  cec_ready
  log "turning the projector on"
  cec-ctl -s -D "$CEC_DRIVER" --to 0 --image-view-on >/dev/null || log "CEC power on failed"
}

# Wait up to 5s for a CEC logical address. SteamOS's cecd claims one about half a second after the adapter appears on
# resume; claim a playback address only if it hasn't, rather than race it.
cec_ready() {
  local i
  for (( i = 0; i < 20; i++ )); do
    cec-ctl -D "$CEC_DRIVER" 2>/dev/null | grep -Eq 'Logical Address +:' && return
    sleep 0.25
  done
  log "no CEC logical address; claiming one"
  cec-ctl -s -D "$CEC_DRIVER" --playback >/dev/null
}

case "$1" in
  sleep)
    projector_off
    log "disabling PD $PD"
    "$FWT" --pd-disable "$PD"
    sleep 1
    ;;
  wake)
    log "enabling PD $PD"
    "$FWT" --pd-enable "$PD"
    # The first reset makes the OREI switch, the second gives a clean hotplug so video comes up.
    for step in "PD enable" "UCSI reset 1" "UCSI reset 2"; do
      secs="$RESET_WAIT"
      if [[ "$step" == "PD enable" ]]; then
        secs="$PD_WAIT"
      else
        log "$step"
        ucsi_reset
      fi
      if wait_connected "$secs"; then
        log "display connected after $step"
        projector_on
        exit 0
      fi
    done
    log "no display after $step"
    ;;
  poweroff)
    projector_off
    ;;
  *)
    echo "usage: $0 sleep|wake|poweroff" >&2
    exit 2
    ;;
esac
