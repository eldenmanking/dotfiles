#!/bin/bash
# Hand the OREI HDMI switch to another input on sleep and back to this laptop on wake, and turn the projector off on
# sleep and poweroff and back on on wake and boot. Installed into /etc/orei-switch by the orei_switch feature of
# ~/dotfiles/install.sh, and run by orei-switch.service (sleep, wake), orei-switch-boot.service (boot) and
# orei-switch-poweroff.service (poweroff). See docs/orei-switch.md.
#
# The OREI ignores CEC and only switches on a fresh HDMI +5V edge, or falls back to another live input once the
# selected input's 5V stays gone. Cutting power to the left PD controller (ports 2 and 3, including the HDMI card on
# port 2) drops 5V for the whole sleep, and restoring it on wake makes a new edge. A charger on port 3 is cut too, so
# keep it on the right side.
#
# Only a CEC TV is touched: a TV answers CEC at logical address 0, and ordinary monitors don't. The ports are only cut
# when the TV is behind a switch (this laptop's physical address is two levels deep, like 1.1.0.0), so sleeping away
# from the projector, or on a TV without a switch, leaves them on.
FWT=/etc/orei-switch/framework_tool
PD=1      # left PD controller (ports 2,3); right is 0
UCSI=/sys/kernel/debug/usb/ucsi/USBC000:00
CONN=3    # UCSI connector for the HDMI card (typec port2 + 1)
CEC_DRIVER=amdgpu  # find the CEC adapter by driver: it is re-registered on each resume, as /dev/cec0 or /dev/cec1
PD_WAIT=15    # seconds to wait for the display after enabling PD (5.4s and 9.5s when tested)
RESET_WAIT=6  # seconds to wait for the display after each UCSI reset
ON_WAIT=60    # seconds to keep trying to turn the projector on, e.g. while it finishes shutting down
# Set when sleep cut the ports. Kept in /var so boot re-enables them if the laptop never woke (a dead battery or a
# forced poweroff), since the EC keeps running.
PD_MARKER=/var/lib/orei-switch/pd-disabled
# Set when sleep turned the projector off, so wake only turns on a projector it turned off.
OFF_MARKER=/run/orei-switch/projector-off

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

# Wait up to $1 seconds for a CEC logical address. SteamOS's cecd claims one about half a second after the adapter
# appears on resume; claim a playback address only if it hasn't, rather than race it. Returns 1 without a CEC adapter.
cec_ready() {
  local i
  for (( i = 0; i < $1 * 4; i++ )); do
    cec-ctl -D "$CEC_DRIVER" 2>/dev/null | grep -Eq 'Logical Address +:' && return 0
    sleep 0.25
  done
  cec-ctl -D "$CEC_DRIVER" >/dev/null 2>&1 || return 1
  log "no CEC logical address; claiming one"
  cec-ctl -s -D "$CEC_DRIVER" --playback >/dev/null
}

# Print the TV's power state (on, standby, to-on or to-standby), or nothing if no TV answers.
tv_power() {
  cec-ctl -s -D "$CEC_DRIVER" --to 0 --give-device-power-status 2>/dev/null | sed -n 's/.*pwr-state: \([a-z-]*\).*/\1/p'
}

# Return 0 if an external display is connected and is a CEC TV, waiting up to $1 seconds for CEC.
tv_present() {
  external_connected && cec_ready "$1" && [[ -n "$(tv_power)" ]]
}

# Return 0 if this laptop's CEC physical address is at least two levels deep, i.e. behind a switch.
behind_switch() {
  cec-ctl -D "$CEC_DRIVER" 2>/dev/null | grep -Eq 'Physical Address +: [1-9a-f]\.[1-9a-f]\.'
}

# Press the projector's Power Off key over CEC: it ignores <Standby>.
projector_off() {
  log "turning the projector off"
  if ! cec-ctl -s -D "$CEC_DRIVER" --to 0 --user-control-pressed ui-cmd=power-off-function >/dev/null \
    || ! cec-ctl -s -D "$CEC_DRIVER" --to 0 --user-control-released >/dev/null; then
    log "CEC power off failed"
  fi
}

# Wake the projector with <Image View On> (SteamOS's cecd also tries on resume, but the projector doesn't respond to
# it), and keep trying for up to $ON_WAIT seconds until it reports on: one still shutting down may ignore it.
projector_on() {
  local i state
  log "turning the projector on"
  for (( i = 0; i < ON_WAIT / 3; i++ )); do
    state="$(tv_power)"
    case "$state" in
      on) log "projector on"; return ;;
      to-on) ;;
      *) cec-ctl -s -D "$CEC_DRIVER" --to 0 --image-view-on >/dev/null 2>&1 ;;
    esac
    sleep 3
  done
  log "projector still ${state:-not answering} after ${ON_WAIT}s"
}

# Enable the PD controller, then wait for the display, falling back to UCSI resets. The first reset makes the OREI
# switch, the second gives a clean hotplug so video comes up. Returns 1 if no display came up.
reconnect() {
  local step secs
  log "enabling PD $PD"
  "$FWT" --pd-enable "$PD"
  rm -f "$PD_MARKER"
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
      return 0
    fi
  done
  log "no display after $step"
  return 1
}

case "$1" in
  sleep)
    rm -f "$OFF_MARKER"
    if ! tv_present 1; then
      log "no CEC TV; leaving the projector and ports alone"
      exit 0
    fi
    projector_off
    mkdir -p "${OFF_MARKER%/*}" && touch "$OFF_MARKER"
    if behind_switch; then
      log "disabling PD $PD"
      mkdir -p "${PD_MARKER%/*}" && touch "$PD_MARKER"
      "$FWT" --pd-disable "$PD"
      sleep 1
    fi
    ;;
  wake)
    if [[ -e "$PD_MARKER" ]]; then
      reconnect || { rm -f "$OFF_MARKER"; exit 0; }
    fi
    if [[ -e "$OFF_MARKER" ]]; then
      rm -f "$OFF_MARKER"
      wait_connected "$RESET_WAIT" && cec_ready 5 && projector_on
    fi
    ;;
  boot)
    if [[ -e "$PD_MARKER" ]]; then
      log "PD $PD was left disabled"
      reconnect
    fi
    # cecd may start after this, so give it longer to claim an address.
    if wait_connected "$PD_WAIT" && tv_present 15; then
      projector_on
    fi
    ;;
  poweroff)
    if tv_present 1; then
      projector_off
    fi
    ;;
  *)
    echo "usage: $0 sleep|wake|boot|poweroff" >&2
    exit 2
    ;;
esac
