# Gaming Mode screenshots
The `--gamescope_screenshot` feature (on `steamos`) saves a screenshot of Gaming Mode when you press **Print Screen** (the Framework 16's screenshot key) or **Shift+Meta+4** (macOS's Cmd+Shift+4, which a Keychron in Mac mode sends from its screenshot key) on any keyboard. Steam's own shortcut, Steam + R1, needs a controller, and its F12 key only works while Steam's window has focus. Gaming Mode has no other place to bind a key to a command: gamescope has no keybinding config (its `Super+S` only works when nested in a window), and no hotkey daemon ships with SteamOS.

- `gamescope-screenshot` (linked into `~/.local/bin` by the feature) runs `gamescopectl screenshot <path>`; gamescope writes the PNG to `~/Pictures/Screenshots/<date>_<time>.png` itself, and the script waits for it (gamescopectl exits 0 even when it can't reach gamescope) and plays the freedesktop shutter sound. Run it by hand, e.g. over ssh, for one screenshot; an optional argument picks gamescope's screenshot type (1, the focused app, the default; 2, with overlays; 3, every layer; 4, the screen buffer).
- `gamescope-screenshot --watch` runs `evtest` (in the base image) on each keyboard in `/dev/input/by-id/*-event-kbd`, line-buffered into one `awk` that runs the screenshot. `evtest` only reads and never grabs the devices, so games still get the keys, and logind gives the session's user access to them, so no `input` group is needed. With three keyboards it's 5 processes and about 14 MB, idle unless a key is pressed. It exits when a keyboard goes away, and systemd restarts it with the keyboards connected then.
- `gamescope-screenshot.service` runs the watch with `gamescope-session.target`, so only in Gaming Mode. `keyboard-rescan.path` watches `/dev/input/by-id` (systemd's inotify, so nothing polls) and starts `keyboard-rescan.service`, which waits 1 s for a new keyboard's links to settle and restarts the watch, so keyboards plugged in later are watched too.
- The units are copied into `/etc/systemd/user` and enabled with `systemctl --global enable` (with sudo), so the units and their links in `gamescope-session.target.wants` are all outside an encrypted home and the user manager sees them from boot. A `## feature gamescope_screenshot` subblock in the keep list `/etc/atomic-update.conf.d/dotfiles.conf` keeps them across SteamOS updates.

Screenshots land in `~/Pictures/Screenshots`, not in Steam's Media tab: Steam only imports screenshots it requested itself, and its client has no call to add one. `--uninstall` stops the watch and removes the units, their links and the keep-list subblock, and keeps the screenshots. `journalctl --user -u gamescope-screenshot.service` shows the keyboards it watches and each screenshot.

To check hotplug on the Framework 16 without touching a cable, cut the power to the right USB-C PD controller (`0`, ports 0 and 1, where the Keychron receiver is plugged in) with the `framework_tool` the `orei_switch` feature installs, then restore it. The watch restarts without the receiver, then again with it (`watching ... Keychron ...`); `framework_tool --pd-info` shows each controller's enabled ports:

```sh
sudo /etc/dotfiles/bin/framework_tool --pd-disable 0
sudo /etc/dotfiles/bin/framework_tool --pd-enable 0
journalctl --user -u gamescope-screenshot.service -u keyboard-rescan.service -n 20
```
