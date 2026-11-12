---
name: debug-steamos-vm
description: Diagnose the steamos_vm VM when it misbehaves - won't start or answer, a boot hangs, Game Mode shows the TianoCore logo or nothing, the network is down, sudo stopped accepting the password, a reboot or shutdown takes minutes, or steamos-vm commands time out. Lists the causes already found, so they aren't rediscovered.
---

# Debug the SteamOS VM
Work from the outside in, and check the known causes below before digging further. Commands are `steamos-vm` (see
SteamOS test VM in `README.md`) and, on the host, virsh from the virt-manager Flatpak:
`flatpak run --user --command=virsh org.virt_manager.virt-manager -c qemu:///session <args>` (bound it with
`timeout`: it can hang for minutes while libvirtd starts).

## Triage
1. `steamos-vm status`: the domain state, whether the agent answers, and the render node it uses.
   - `shut off`: `steamos-vm start --no-view`.
   - `paused`, `pmsuspended`, or running without an answer: `steamos-vm start` repairs these (resume, power cycle,
     or force a restart after 2 minutes without an answer). Don't wait out a hang: `steamos-vm restart --force`.
2. The agent answers: look inside with `steamos-vm run` / `run --root` (no terminal; nothing may prompt).
3. The agent doesn't answer: `steamos-vm console`, log in as `deck`. The serial console works when the display,
   network and agent don't. `~/.var/app/org.virt_manager.virt-manager/cache/steamos-vm/serial.log` has everything the
   console printed.
4. Nothing at all: the host side (below).

## Inside the guest
- A boot that doesn't finish: `systemctl is-system-running` (`starting` = stuck), `systemctl list-jobs` names the job
  everything waits on (`running` one); then `journalctl -b -u <unit>` and `ps -eo pid,etime,stat,args` for what it
  runs.
- Which slot: `findmnt -n -o SOURCE /` (`nvme0n1p4` is A, `p5` is B); `sudo steamos-bootconf this-image`.
- The previous boot: `journalctl -b -1` (system) and `journalctl -b -1 --user`; a forced power-off can leave the user
  journal unreadable (`*.journal~`).
- Processes stuck in the kernel: `ps -eo stat,pid,wchan:30,comm | grep '^D'`. With anything holding the GPU, it is the
  wedged virtio-gpu native context: power cycle.
- The GPU in use: `vulkaninfo --summary | grep deviceName` (as deck).
- Game Mode's screen: `steamos-vm screenshot f.png`; gamescope's own log: `journalctl -b --user -u gamescope-session`.

## On the host
- Leftover agent clients: QEMU takes one client per socket at a time. `pgrep -af agent.sock` should be empty between
  calls; kill strays.
- `virsh list --all` should show `steamos` and no `steamos-install` (an install in progress, or one that died: destroy
  it, and rerun the feature).
- `~/.var/app/org.virt_manager.virt-manager/cache/libvirt/qemu/log/steamos.log` has QEMU's own errors (device
  conflicts, missing render node).
- The definition: `steamos-vm start` redefines the VM when its XML for this host (render node included) differs
  from `cache/steamos-vm/steamos.xml`. A domain redefined by hand (virsh define) isn't detected: undefine with
  `--keep-nvram` and define that file again.
- An install that failed: `cache/steamos-vm/install.log` is the installer's serial console; it ends with
  `STEAMOS-VM-INSTALLED` on success.

## Causes already found
| Symptom | Cause | What to do |
|---|---|---|
| Reboot or shutdown takes 2-3 minutes; processes stuck in D state | The guest suspended (S3 or s2idle), which wedges the virtio-gpu native context | Power cycle. The VM's suspend drop-in should prevent it: check `systemctl cat systemd-suspend.service` ends with `ExecStart=/usr/bin/true`. |
| Network down after Steam starts | steamos-manager's `SetWifiBackend` stops NetworkManager, fails `iw ... add wlan0` without a Wi-Fi device, never restarts it | `steamos-vm-wifi.service` (mac80211_hwsim) should be active; `systemctl start NetworkManager` as a stopgap. |
| `virsh shutdown` suspends instead | Game Mode maps the ACPI power button to suspend | `steamos-vm stop`. |
| Boot stuck before the login screen | A oneshot unit with no timeout waiting on hardware (e.g. `framework_tool` with Framework DMI) | `systemctl list-jobs`; the VM keeps QEMU's DMI identity to avoid this. |
| `/etc` changes and the deck password gone, journal has one boot | SteamOS fell back to the other A/B slot after boots that never reached the login screen | Check the slot. `install.sh --reinstall --steamos_vm` for a clean start, or redo the changes. |
| Screen shows the TianoCore logo | gamescope isn't drawing: Game Mode hasn't started (see a stuck boot), or the viewer can't import the GPU's frames | `steamos-vm screenshot`: if that shows Game Mode, the viewer is the problem, not the guest. `virsh screenshot` never works with GPU acceleration ("no surface"). |
| Guest renders on the eGPU | virglrenderer opens the lowest-numbered amdgpu render node | Expected; `steamos-vm start` points the display at the same node. |
| `steamos-vm` calls time out | A stray client holds the agent socket, or the agent isn't running | `pgrep -af agent.sock`; in the guest `systemctl status steamos-vm-agent`. |
| `Cannot open log file ... busy` on start | libvirt still holds the last run's serial log | `steamos-vm start` retries; wait a few seconds. |
