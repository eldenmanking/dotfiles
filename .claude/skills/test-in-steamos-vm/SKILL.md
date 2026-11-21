---
name: test-in-steamos-vm
description: Test a dotfiles change on a real SteamOS in the steamos_vm VM - copy the checkout in with steamos-vm sync, run install.sh features there, check units, logs and Game Mode screenshots. Use when a change touches SteamOS-specific features (/etc files, systemd units, the login screen, Game Mode, steam, kde, flatpak, distrobox) and needs checking on SteamOS itself rather than in make test's scratch homes, or when asked to try something in the SteamOS VM.
---

# Test in the SteamOS VM
The `steamos_vm` feature installs SteamOS into a virt-manager VM named `steamos`, and `steamos-vm` runs it (see
SteamOS test VM in `README.md`). This skill is the loop for checking a change there. Everything goes through
`steamos-vm`; never use virt-manager's window, `virsh shutdown` or a guest-side reboot to drive it.

`steamos-vm` loads `$HOME/dotfiles/install/lib`. To test a worktree whose `steamos-vm` or `install/lib/steamos_vm.sh`
changed, run a copy with `LIB_DIR` pointed at the worktree:
`sed "s|^LIB_DIR=.*|LIB_DIR=$PWD/install/lib|" home/.local/bin/steamos-vm > <scratchpad>/steamos-vm`.

## 1. Get a VM
- No VM yet (`steamos-vm status` says so): `~/dotfiles/install.sh --steamos_vm`, about a minute plus decompressing the
  recovery image the first time. It asks nothing until `--uninstall`.
- Need a clean SteamOS (earlier tests left state behind, or the VM is on the wrong A/B slot; see
  `debug-steamos-vm`): `~/dotfiles/install.sh --reinstall --steamos_vm` and answer `y`. That erases everything in
  the VM, so ask first if the user set it up by hand (signed into Steam, their own password).
- `steamos-vm start --no-view` boots it and waits for its agent (about 20 s); `--no-view` keeps virt-manager's window
  off the user's screen.

## 2. Copy the change in
`steamos-vm sync [CHECKOUT]` (default `~/dotfiles`) copies the checkout as it is, uncommitted and untracked files
included, into the VM's `~/dotfiles` on the same branch, in about 7 s. It overwrites changes made in the VM's copy, so
make changes on the host and sync again.

## 3. Run features
`steamos-vm run COMMAND` runs as `deck` in a login shell and prints the output; `--root` runs as root. Each call takes
about 2 s. There is no terminal:
- Features without sudo run directly: `steamos-vm run 'cd ~/dotfiles && ./install.sh --variant steamos --link'`.
- Features that need sudo (anything writing `/etc`) would prompt for a password, and sudo can't cache one without a
  terminal (its cache is tied to the parent process, which install.sh's sudo doesn't share). In this throwaway VM,
  give `deck` passwordless sudo once instead:
  `steamos-vm run --root 'echo "deck ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/zz-steamos-vm-test && chmod 440 /etc/sudoers.d/zz-steamos-vm-test'`,
  then `steamos-vm run 'cd ~/dotfiles && ./install.sh --variant steamos --machine framework16 --udev'`. It is in
  `/etc` of the running A/B slot only, and goes with `--reinstall`. For logging in on `console`, set a password with
  `steamos-vm run --root 'echo deck:testpass123 | chpasswd'` (also per slot).
- Features that enter a shell (`distrobox` enters the container at the end) or need answers to `confirm` prompts need
  `steamos-vm console` (log in as deck; `Ctrl+]` leaves).
- The VM is a `generic` machine to `--infer`: pass `--machine framework16` for the Framework's features. Their
  services install and then find no hardware (orei-switch, light-sleep, hdmi-audio-fix do nothing).

## 4. Check the result
- Files and units: `steamos-vm run 'systemctl status <unit> --no-pager'`, `steamos-vm run --root 'ls -la /etc/...'`.
- Logs: `steamos-vm run 'journalctl -b -u <unit> --no-pager'`; user units with `journalctl --user`.
- Boot-time behavior (units ordered before the login screen, SteamOS update keep lists): `steamos-vm restart
  --no-view`, then `journalctl -b`. A restart is a full power cycle; that's deliberate.
- Game Mode: `steamos-vm screenshot <file>.png` saves what's on screen (gamescope takes it in the VM; then Read the
  PNG), and `steamos-vm key KEY_...` presses keys (`KEY_ENTER`, `KEY_DOWN`, chords like `KEY_LEFTMETA KEY_S`). A
  fresh VM sits at Steam's first-run screens; Enter picks the highlighted option. Signing into Steam (which `--steam`
  needs) takes the user's account: leave that to them.
- Idempotency: run the same `install.sh` command twice and check the second changes nothing.
- Power source: `steamos-vm power ac|battery` plugs in or unplugs the VM's fake charger (`test_power`'s `test_ac`, a
  `Mains` supply like the Framework's `ACAD`); `steamos-vm power` prints which it is on.
- Sleep: with `light_sleep` installed (`--machine framework16 --light_sleep`) and on AC, `steamos-vm run --root
  'systemctl suspend'` takes a real light sleep through logind, as Steam's sleep does; `steamos-vm key KEY_LEFTSHIFT`
  wakes it, and `journalctl -t light-sleep -b` lists what it froze. Don't take a screenshot while it sleeps: gamescope
  is frozen, so it hangs until the wake.
- SSH: `steamos-vm run --root 'systemctl start sshd'`, then give deck a key for itself (`ssh-keygen -t ed25519 -N ""
  -f ~/.ssh/id_vmtest`, appended to `~/.ssh/authorized_keys`), and `ssh -i ~/.ssh/id_vmtest localhost ...` from
  `steamos-vm run` is a real sshd login, with its own logind session, as one from another machine would be. The VM's
  user networking can't be reached from the host.

## 5. Finish
- `steamos-vm stop` powers it off through its agent (it falls back to forcing it off).
- Report what ran in the VM and what was checked, and what couldn't be (hardware, Steam sign-in, Desktop Mode, which
  screenshots don't cover). "Compared with the Framework 16" under SteamOS test VM in `README.md` lists what the VM
  matches and where it differs; keep it in sync when a change brings the VM closer.

## Things that look like bugs but aren't
- Suspend never reaches the VM's kernel (the GPU doesn't survive a guest suspend): sleep hooks run, and then either
  `light-sleep` takes a light sleep (on AC with `light_sleep` installed) or nothing sleeps. VMs installed before
  `steamos-vm-power.service` have no fake charger, so suspend is always a no-op there; `--reinstall --steamos_vm`.
- `virsh shutdown` makes Game Mode suspend instead; use `steamos-vm stop`.
- There is a virtual Wi-Fi radio (`mac80211_hwsim`) with no networks; the VM's network is the wired `enp1s0`.
- `/etc` (with the `deck` password) is per A/B slot. If a boot fails to reach the login screen a few times, SteamOS
  switches slots, and earlier `/etc` changes and the password seem gone. See `debug-steamos-vm`.
- A SteamOS update (`steamos-vm run --root steamos-update`, then `steamos-vm restart`) keeps the VM's own units and
  dotfiles' files, but moves files no keep list names into `/etc/previous`, such as the passwordless sudo file: add it
  again.
- The guest renders on the eGPU when one is attached (the lowest-numbered amdgpu render node), not the 780M.
