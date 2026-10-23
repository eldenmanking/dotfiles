# OREI HDMI switch handoff (Framework 16)
The `orei_switch` feature (`./install.sh --variant steamos --orei_switch`) makes an OREI 4K 3-input HDMI switch (auto
mode) follow a Framework 16's sleep and wake, and turns the projector off on sleep and poweroff and back on on wake. It
installs `/etc/orei-switch/orei-switch.sh`, a pinned `framework_tool` (Framework's EC tool) beside it,
`orei-switch.service` (enabled, wanted by `sleep.target`), `orei-switch-poweroff.service` (wanted by `poweroff.target`,
so not on reboot) and a SteamOS keep list for `/etc/orei-switch`, without which an OS update deletes the script and
binary.

## Setup
- Framework 16 (AMD iGPU) on SteamOS. HDMI expansion card on USB-C port 2 (left), the DRM connector `card0-DP-4` and
  `/dev/cec0`, into OREI input 1. A Nintendo Switch is on input 2 and an Apple TV on input 3, and the OREI feeds a projector.
- Gamescope drives one display: with the external display connected, the laptop screen is blank.

## Problem
1. Waking or booting the laptop doesn't make the OREI switch to it: the laptop shows on its own screen and DP-4 reports
   disconnected. The OREI apparently only presents HPD/EDID on the selected input, so the laptop never sees a display.
2. While the laptop sleeps, turning on the Apple TV doesn't take the OREI away from it (the Nintendo Switch does).

## Findings
- The OREI ignores CEC entirely (Active Source, Set Stream Path and Image View On from either device do nothing).
- It switches on a fresh HDMI +5V edge (a new source arriving), and falls back to another live input only when the
  current input's 5V stays gone. The Apple TV keeps 5V on in standby, so it never makes an edge.
- These did not keep 5V off: forcing `/sys/class/drm/card0-DP-4/status` off/on; toggling
  `/sys/class/typec/port2/port2.0/active` (DP alt mode); a single UCSI connector reset (the blip is too short and the
  controller re-enters DP mode within seconds).
- A UCSI connector reset works as a software replug for wake:
  `echo 0x30003 > /sys/kernel/debug/usb/ucsi/USBC000:00/command` (connector 3 = typec port 2 + 1). It takes two resets
  ~10s apart: the first makes the OREI switch, the second gives a clean hotplug so video comes up.
- `framework_tool --pd-disable 1` cuts power to the whole left PD controller (ports 2 and 3), which lets the Apple TV take
  over; `--pd-enable 1` restores it, and the fresh edge switches the OREI back with a picture. Granularity is left
  (PD 1) and right (PD 0) only, so **a charger on port 3 is cut during sleep: keep it on the right side** (check with
  `framework_tool --pdports`).

- The projector (a Nebula Cosmos, CEC vendor ID `mtk`) is reachable over CEC through the OREI as the TV (0.0.0.0), and
  the Apple TV answers as Playback Device 1 (1.2.0.0) with its power state. The projector acknowledges `<Standby>`, sent
  to it or broadcast, even after an `<Active Source>`, but ignores it. It does turn off on the remote's Power Off key:
  `cec-ctl -D amdgpu --to 0 --user-control-pressed ui-cmd=power-off-function`, then `--user-control-released`.
- The kernel re-registers the CEC adapter on each resume, alternating between `/dev/cec0` and `/dev/cec1`, so the
  script finds it by driver (`cec-ctl -D amdgpu`). SteamOS's `cecd` configures it (OSD name `steamdeck`).
- The laptop's CEC adapter needs HPD, so it can only talk on the bus while the OREI shows the laptop, and not at all
  while it sleeps. It can't watch for another device turning on during sleep.

On sleep the script presses the projector's Power Off key over CEC (only while the OREI shows the laptop, so it never
turns off another input's picture), then disables the PD controller. On wake it re-enables it, waits up to 15s for an
external display (polling `/sys/class/drm/card*-DP-*/status`), and otherwise does up to two UCSI resets, each followed by
a 6s wait. It logs which step brought the display up; tune `PD_WAIT` and `RESET_WAIT` from those timings
(`journalctl -t orei-switch -b -o short-precise`). In the first real suspend/resume, the display connected 5.4s after the
PD enable, with no resets (9.5s in a later one). Once the display is connected it wakes the projector with `<Image View
On>`, which works where SteamOS's `cecd` wake on resume does not. CEC calls first wait up to 5s for `cecd` to claim a
logical address after resume. On poweroff it only turns the projector off.

## Operating
- Logs: `journalctl -t orei-switch -b`
- Recovery, if the left ports stay dead: `sudo /etc/orei-switch/framework_tool --pd-enable 1` (or reboot)
- Remove: `./install.sh --variant steamos --orei_switch --uninstall`

## Open questions
- Verify a real poweroff, and the UCSI reset fallback on wake. (Suspend/resume, including turning the projector off and
  on, works.) Accidental wakes turning the projector on are fine.
- Boot: maybe run the wake logic at boot too. The projector shows a blank screen on boot if connected, and the
  encrypted home needs a desktop-mode login first.
