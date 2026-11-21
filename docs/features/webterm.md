# Webterm
The `--webterm` feature (on `steamos` and `arch`) gives you a real shell in the browser on localhost. It runs [ttyd](https://github.com/tsl0922/ttyd), a single static binary (about 1.3 MB) that serves an [xterm.js](https://xtermjs.org/) page and connects it to your shell. systemd starts it the first time you open the page and stops it once no browser has been connected for 30 s. There is nothing to compile and no Node, npm or Python needed, which is handy on SteamOS, where the root filesystem is read-only. The only files outside your home directory are the three units, which go into `/etc` with sudo.

```
browser ⇄ 127.0.0.1:7681 ──► webterm.socket            (always listening)
                              │ first connection starts
                              ▼
                             webterm.service          systemd-socket-proxyd
                              │ --exit-idle-time=30s
                              ▼ $XDG_RUNTIME_DIR/webterm.sock
                             webterm-ttyd.service     ttyd ⇄ pty ⇄ your shell
```

- **`webterm.socket`** listens on `127.0.0.1:7681` (ttyd's default port, which dev servers rarely take). It's the only part that runs all the time, and systemd itself does the listening.
- **`webterm.service`** runs `systemd-socket-proxyd`, which ships with systemd. ttyd can't take over a socket that systemd opened, so the proxy takes it and forwards each connection to ttyd. After 30 s with no open connections, the proxy exits. That covers both a closed tab and a page that never connected.
- **`webterm-ttyd.service`** runs ttyd on a UNIX socket in your private runtime directory, so other local users can't reach it. It has `StopWhenUnneeded=yes`, so it stops when the proxy exits. The socket keeps listening, so your next visit starts everything again.
- Both services run in their own `webterm.slice`, along with the shells and any tmux started from them, so the Framework 16's `light_sleep` feature can freeze the graphical session around them; see [light-sleep.md](../light-sleep.md).
- ttyd pings each browser every 10 s, so dead connections (a browser crash, a laptop suspend) get closed and the idle timer can run.

A backend is needed because a web page can't start processes; only a local program can start a shell and attach it to a terminal. It needs Linux with systemd (including `/usr/lib/systemd/systemd-socket-proxyd`), `curl` and `sha256sum`, on x86_64 or aarch64 (the CPU types ttyd publishes static builds for), all of which come with a stock SteamOS or Arch install; `tmux` is optional, to [keep work running](#keeping-work-with-tmux).

```sh
~/dotfiles/install.sh --variant steamos --link --font --webterm   # or --variant arch
~/dotfiles/install.sh --variant steamos --webterm   # just ttyd and the units
```

`--all` installs these along with the rest of the `steamos` and `arch` variants. When it finishes, it prints your URL, which looks like `http://localhost:7681/<token>/`. Bookmark it; the token is explained in [Security](#security). To update, `git pull` in `~/dotfiles` and run the installer again, after the steps in [migrations.md](../migrations.md) for any changes it pulled in. What gets installed:

- **Scripts and settings** (`--link`): `home/.local/bin/webterm-{index,shell,ttyd}`, `home/.local/share/webterm/tab-keys.html` and `home/.config/webterm/env` are linked into place.
- **Font** (`--font`): installs JetBrainsMono Nerd Font (Nerd Fonts v3.4.0) into `~/.local/share/fonts/JetBrainsMonoNerdFont/`, after checking its SHA-256. It does nothing if `fc-list` already lists the font.
- **ttyd and units** (`--webterm`): downloads ttyd 1.7.7 to `~/.local/bin/ttyd`, checks it against a pinned SHA-256, and copies the units in `root/etc/systemd/user/` into `/etc/systemd/user/` with sudo (copied, not linked: systemd treats symlinked unit files as "linked" units, which enable and disable handle differently). There the user manager sees them from boot, even with an [encrypted home](#encrypted-home-directory-dirlock). They are user units; `--webterm` enables them for every user with `systemctl --global enable`, so their links are in `/etc/systemd/user` too. On SteamOS it also names them in its own subblock of the keep list `/etc/atomic-update.conf.d/dotfiles.conf`, since updates otherwise drop everything in `/etc/systemd/user`.

`--dry-run` prints what would change. To remove webterm, including `~/.local/bin/ttyd`, the page in `~/.local/state/webterm` and (with sudo) the units in `/etc`:

```sh
~/dotfiles/install.sh --variant steamos --webterm --uninstall
```

Your URL token stays in `~/.config/webterm/token`.

### Configuration
| Setting      | Where                                                         | Default            |
| ------------ | ------------------------------------------------------------- | ------------------ |
| Idle timeout | `WEBTERM_IDLE` in `webterm.service`                           | `30s`              |
| Shell        | `SHELL` in the env file                                       | `/usr/bin/zsh`     |
| Font         | `WEBTERM_FONT` in the env file                                | JetBrainsMono Nerd Font Mono |
| URL token    | `WEBTERM_TOKEN` in `~/.config/webterm/token`                  | random, 32 hex     |
| Port         | `ListenStream` in `root/etc/systemd/user/webterm.socket`      | `127.0.0.1:7681`   |

The env file, `~/.config/webterm/env`, is linked from `home/.config/webterm/env` by the `link` feature, so settings there are kept in git; run `--link` before `--webterm`, which needs it. The token gets its own unlinked file (mode 600), which `--webterm` creates if it's missing, so it never lands in the repo. Change the environment settings with a drop-in, for example `systemctl --user edit webterm.service` with `[Service] Environment=WEBTERM_IDLE=5min`. That drop-in lives in `~/.config/systemd/user/`, so with an encrypted home the user manager doesn't see it after a reboot until something reloads it (rerunning `--webterm` does); for one that holds from boot, use `sudo systemctl --global edit webterm.service`, and on SteamOS add it to a keep list too. To change the port, edit `root/etc/systemd/user/webterm.socket`.

After any change, run `~/dotfiles/install.sh --variant steamos --webterm` (or `--variant arch`) again. You don't need to close the browser. It copies the units that changed into `/etc/systemd/user` (so edits and a `git pull` take effect) and reloads systemd, restarts the socket if its unit changed (so a new port applies), then restarts the proxy and ttyd, but only if they're running; if they aren't, the next visit starts them with the new settings anyway. `~/.config/webterm/env` and `~/.config/webterm/token` are read again on every start, so changes there apply too. Open tabs show "Reconnecting..." and come back by themselves with the new settings (font, title and so on), without a page reload. Each tab gets a **fresh shell**, so anything running in a bare shell ends; tmux sessions survive (see [Keeping work with tmux](#keeping-work-with-tmux)). The exception is the token: after changing it, open the new URL, since tabs still on the old one can't reconnect.

### Font
The terminal uses **JetBrainsMono Nerd Font Mono** by default. The Mono variant draws Nerd Font icons one cell wide, so prompts line up in the grid. ttyd's `-t key=value` passes any option straight to xterm.js, so the unit runs `-t "fontFamily=${WEBTERM_FONT}"`; no custom build is needed. The page only names the font: the browser draws it from fonts installed on the machine it runs on, which is the one webterm runs on, so the `font` feature installs it. Flatpak browsers (the default on SteamOS) should also see `~/.local/share/fonts`. If the browser was already open when the font was installed, restart it; until then it uses the next font in the list.

To use a different font, change `WEBTERM_FONT` in `home/.config/webterm/env`, for example to `WEBTERM_FONT=JetBrainsMonoNL Nerd Font Mono, monospace`, then rerun `--webterm`; open tabs switch fonts when they reconnect. The value can be any CSS font list without an `=`. Run `fc-list : family | grep -i nerd` to see the exact names that are installed.

### Browser tab shortcuts
xterm.js turns most Ctrl combos into terminal input and stops the browser from handling them. Chrome keeps some tab shortcuts for itself, but in fullscreen (F11) it lets the page handle every shortcut first, so the terminal would eat them. webterm hands these back to the browser: <kbd>Ctrl</kbd>+<kbd>Tab</kbd> and <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>Tab</kbd>, <kbd>Ctrl</kbd>+<kbd>1</kbd> to <kbd>Ctrl</kbd>+<kbd>9</kbd>, <kbd>Ctrl</kbd>+<kbd>PgUp</kbd> and <kbd>Ctrl</kbd>+<kbd>PgDn</kbd>, and <kbd>F11</kbd>, so it leaves fullscreen instead of reaching the shell. Every other key, like <kbd>Ctrl</kbd>+<kbd>W</kbd> or <kbd>Ctrl</kbd>+<kbd>R</kbd>, still goes to the shell.

- ttyd has no option for this, but `-I` serves a custom `index.html`. The repo keeps only the script to add, `home/.local/share/webterm/tab-keys.html`. It listens for keys before xterm.js does and stops them from reaching it, without cancelling the browser's own handling.
- The stock page bundles ttyd's browser client, which must match the ttyd binary. So `--webterm` runs `webterm-index`, which starts a throwaway ttyd on a temporary UNIX socket, fetches its page, appends the script and writes `~/.local/state/webterm/index-<sha256 of ~/.local/bin/ttyd>.html`.
- `webterm-ttyd.service` runs ttyd through `webterm-ttyd`, which hashes `~/.local/bin/ttyd` on every start and adds `-I` only if a page for that hash exists. If not, ttyd serves its stock page: the terminal works, but without the tab shortcuts in fullscreen. `journalctl --user -u webterm-ttyd.service` then shows a warning, and rerunning `--webterm` builds the page again.

After changing `tab-keys.html`, rerun `--webterm` and reload open tabs.

### Encrypted home directory (dirlock)
With an encrypted home directory, the user manager (`systemd --user`) starts before dirlock unlocks the home, so for the rest of the boot it doesn't see anything in `~/.config/systemd/user`: units and enable links there are skipped. So webterm keeps both outside the home: `--webterm` copies its units into `/etc/systemd/user` and enables them with `sudo systemctl --global enable`, which links them in `/etc/systemd/user/sockets.target.wants/`. Every user manager sees those from boot, so `webterm.socket` listens as soon as you log in; after a reboot, `systemctl --user status webterm.socket` should be `active (listening)`. The services read `~/.config/webterm` and run scripts in `~/.local/bin` only when they start, so a visit before the home is unlocked fails, and the next one after works.

The socket is enabled for every user on the machine, so where several users log in, only the first gets port 7681. A unit you enable yourself with `systemctl --user enable` gets its link in `~/.config/systemd/user` and doesn't start after a reboot with an encrypted home; put its file in `/etc/systemd/user` and enable it with `sudo systemctl --global enable` instead, and on SteamOS name both in a keep list.

### Security
**This is a full shell running as your user.** Anyone who can use the page can do anything you can.

- It only listens on `127.0.0.1`, and ttyd itself sits on a UNIX socket that only your user can open.
- ttyd's `-O` rejects WebSocket connections whose `Origin` doesn't match the page's own host.
- `-O` alone doesn't stop DNS rebinding, where a malicious site's domain resolves to 127.0.0.1 so the browser treats it as the same origin. That's what the random URL token is for. ttyd only serves the terminal under `/<token>/` and answers 404 everywhere else, so such a page can't find it. Keep the token private, like a password. Setting `WEBTERM_TOKEN=` (empty) in the token or env file turns this protection off.
- Don't expose it beyond localhost (port forwarding, reverse proxy, `0.0.0.0`) without real authentication and TLS. Authentication beyond the URL token, TLS and multi-user support are out of scope for now.

### Keeping work with tmux
Bare shells are disposable: one ends when you close its tab, when webterm stops on idle, and when you rerun `--webterm`. To keep something running, start `tmux` in the terminal. The tmux server survives all three, and you reattach with `tmux attach` on your next visit. Everything started from webterm belongs to `webterm-ttyd.service`, and stopping it would take a tmux server started there with it: tmux 3.7 puts each pane in its own systemd scope that is `PartOf=` the server's unit, so even with the unit's `KillMode=process` (which spares the server itself), systemd stops every pane. So the `tmux` shell function (`home/.config/sh/aliases.sh`, in every bash and zsh) starts a new server in a scope of its own in `tmux.slice`, outside webterm. A server it didn't start, such as one from `/usr/bin/tmux` or a script, still loses its panes when webterm stops. The same goes for tmux started from Konsole, whose panes would otherwise end with the window. A light sleep doesn't freeze `tmux.slice` either, since it only freezes the graphical session's slices. The server then belongs to your systemd user manager, which stops when your last login session ends unless lingering is on, taking the server with it (e.g. ssh in, start tmux, detach and log out, with no other session open). Check with `loginctl show-user "$USER" -p Linger`, and turn it on with `loginctl enable-linger`; on SteamOS the autologin session keeps the manager running anyway.

### Smoke test
`python3 tests/webterm_smoke.py` needs `~/.local/bin/ttyd`, which `--webterm` downloads, but no running systemd: `systemd-socket-activate` stands in for `webterm.socket`, and the real ttyd and `systemd-socket-proxyd` do the rest, running the scripts and `tab-keys.html` from this checkout. It checks that the page is only served under the token, a cross-origin WebSocket is rejected, the page is the stock page with `tab-keys.html` appended, a shell command round-trips, and the proxy exits once idle. It doesn't cover `webterm-ttyd.service` stopping with the proxy, because that step needs a real systemd. ttyd is MIT-licensed by its authors and is downloaded from its GitHub releases, not stored in this repo.
