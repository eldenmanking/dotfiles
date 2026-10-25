# Migrations
`install.sh` doesn't clean up after changes to the repo's layout: a feature only installs the current layout and
never removes what an older one left behind. When a change on `main` leaves stale files on machines that installed
an older version, it is listed here, oldest first, with the steps to fix it by hand.

## For agents
You are updating a machine whose `~/dotfiles` checkout was just pulled, or is about to be.

1. Find the commit the machine was on before the pull: `git -C ~/dotfiles reflog` (the entry before the latest
   `pull`/`merge`/`reset`), or `ORIG_HEAD` right after a pull. If you can't tell, treat it as older than every
   entry: each one has a check that is safe to run on any machine.
2. Resolve each entry's commit on `main`. Entries name the squash-merged PR, so look it up with
   `git -C ~/dotfiles log --oneline --grep='(#<number>)' origin/main` (the hash is given too, once known).
   An entry applies if its commit is not an ancestor of the old commit:
   `! git -C ~/dotfiles merge-base --is-ancestor <commit> <old commit>`.
3. Work through the entries that apply in order. For each step, run its **Check** first and skip the step if it
   finds nothing; only then run **Fix**, and confirm with **Verify**. Steps that run `sudo` or delete files: show
   the user what will change and ask first.
4. Report which steps you ran, skipped (and why), and anything that did not verify.

Don't add migration code to `install.sh` or the features for these; when a change needs one, add an entry here
instead (newest last) in the same shape. The `update-migrations` skill (`.claude/skills/update-migrations`) says when
an entry is needed, how to write one, and how to fill in its commit once it merges.

## Merge steamos-config into dotfiles (#18, 9e2f895)
The standalone steamos-config repo moved into `~/dotfiles/steamos`, and `home_units` started installing its files
under names after `dotfiles`. Applies to SteamOS machines that ran steamos-config's installer.

### Old home-units files in /etc
- **Check:** `ls -d /etc/steamos-config /etc/atomic-update.conf.d/steamos-config.conf /etc/atomic-update.conf.d/home-units.conf 2>/dev/null`
- **Fix:** run `~/dotfiles/install.sh --variant steamos --home_units` first, so the new files are in place, then
  `sudo rm -f /etc/steamos-config/home-units-start /etc/atomic-update.conf.d/steamos-config.conf /etc/atomic-update.conf.d/home-units.conf`
  and `sudo rmdir /etc/steamos-config`.
- **Verify:** the check prints nothing, and `systemctl --user cat home-units.service` shows `ExecStart=/etc/dotfiles/home-units-start`.

### Old webterm units
- **Check:** `grep -l steamos-config ~/.config/systemd/user/webterm*.service 2>/dev/null`
- **Fix:** `~/dotfiles/install.sh --variant steamos --link --webterm`. Once the check prints nothing, a leftover
  standalone checkout (e.g. `~/steamos-config`) can be deleted, after asking the user.
- **Verify:** the check prints nothing and the URL `--webterm` prints answers.

## Move steamos/ into home/ and root/ (#46, ac0512a)
webterm's scripts, page and units moved from `steamos/` into `home/` (ttyd now downloads to `~/.local/bin/ttyd`),
home-units and hdmi-audio-fix files moved under `root/etc/`, and `LINK_DESKTOP_PATHS` stopped linking `root/etc`
and `root/usr` as whole directories.

### webterm units still point into steamos/ (steamos)
- **Check:** `grep -l 'dotfiles/steamos' ~/.config/systemd/user/webterm*.service 2>/dev/null`
- **Fix:** `~/dotfiles/install.sh --variant steamos --link --webterm` (`--link` first: the units now run the scripts
  it links into `~/.local/bin`).
- **Verify:** the check prints nothing, `~/.local/bin/ttyd` exists, and the URL `--webterm` prints answers.

### Old ttyd download in the checkout (steamos)
Once `steamos/.gitignore` is gone, git shows the old download as untracked.
- **Check:** `git -C ~/dotfiles status --short --ignored -- steamos`
- **Fix:** only after the step above verified, `rm -rf ~/dotfiles/steamos` if the check lists nothing but
  `steamos/bin/ttyd` and `__pycache__` directories; otherwise show the user what else is there and ask.
- **Verify:** the check prints nothing.

### Links into /etc that are now copied, or no longer linked (arch)
`root/etc` used to be linked as a whole, which also linked files their features copy instead (the udev rule and the
tmpfiles config).
- **Check:** `sudo find /etc /usr/local /usr/share/kbd -type l -lname "$HOME/dotfiles/root/*"`, then compare each
  link with `LINK_DESKTOP_PATHS` in `~/dotfiles/install/features/link.sh`: a link whose repo path is not listed
  there is stale.
- **Fix:** on a Framework 16, `~/dotfiles/install.sh --variant arch --udev --tmpfiles`, which replaces those links
  with copies. Otherwise, after asking, `sudo rm` each stale link (only links, never regular files), then
  `sudo udevadm control --reload` if a udev rule was removed.
- **Verify:** rerunning the check lists only paths in `LINK_DESKTOP_PATHS`.

## Install webterm's units into /etc/systemd/user (#51, 21beb51)
webterm's units moved from `home/.config/systemd/user` to `root/etc/systemd/user`, and `--webterm` now copies them
into `/etc/systemd/user` (with sudo), so `home-units-start` can start them after an encrypted home is unlocked
without a `daemon-reload`.

### Old webterm units in the home (steamos)
Units in `~/.config/systemd/user` override the ones in `/etc/systemd/user`, so the old copies must go.
- **Check:** `ls ~/.config/systemd/user/webterm.socket ~/.config/systemd/user/webterm.service ~/.config/systemd/user/webterm-ttyd.service 2>/dev/null`
- **Fix:** `systemctl --user disable webterm.socket`, then
  `rm -f ~/.config/systemd/user/webterm.socket ~/.config/systemd/user/webterm.service ~/.config/systemd/user/webterm-ttyd.service`,
  then `~/dotfiles/install.sh --variant steamos --link --webterm --home_units` (`--home_units` reinstalls the
  `home-units-start` that no longer reloads).
- **Verify:** the check prints nothing, `systemctl --user cat webterm.socket` starts with
  `# /etc/systemd/user/webterm.socket`, `readlink ~/.config/systemd/user/sockets.target.wants/webterm.socket` is
  `/etc/systemd/user/webterm.socket`, and the URL `--webterm` prints answers.

## Use the eldenmanking/tmux-resurrect fork (#58, 4a5e0b5)
`.tmux.conf` now installs tmux-resurrect from the eldenmanking fork, which keeps panes with an empty title from
restoring in the wrong directory. tpm skips plugins whose directory exists, so machines that installed the upstream
plugin keep it, and tpm updates keep pulling from upstream.

### tmux-resurrect still cloned from upstream (all)
- **Check:** `git -C ~/.tmux/plugins/tmux-resurrect remote get-url origin 2>/dev/null | grep -v eldenmanking`
- **Fix:** if `git -C ~/.tmux/plugins/tmux-resurrect status --short` lists anything but
  `strategies/nvim_obsession.sh` (linked by `.tmux.conf`), show the user and ask first. Then
  `git -C ~/.tmux/plugins/tmux-resurrect remote set-url origin https://github.com/eldenmanking/tmux-resurrect`,
  `git -C ~/.tmux/plugins/tmux-resurrect fetch origin` and
  `git -C ~/.tmux/plugins/tmux-resurrect reset --hard origin/master`.
- **Verify:** the check prints nothing, and `grep -c '\\037' ~/.tmux/plugins/tmux-resurrect/scripts/restore.sh`
  prints a nonzero count.

## Remove auto-suspend (#60, 91fa967)
The auto-suspend timer, its service and `auto-suspend` script are gone: `--link` no longer links them and
`--services` now only enables bluetooth. Applies to arch machines that ran `--link --services`.

### Leftover auto-suspend links (arch)
- **Check:** `ls -l /etc/systemd/system/auto-suspend.service /etc/systemd/system/auto-suspend.timer /usr/local/bin/auto-suspend 2>/dev/null`
- **Fix:** after asking, `sudo systemctl disable --now auto-suspend.timer`, then remove each path the check listed
  with `sudo rm` if it is a symlink into `~/dotfiles` (only links, never regular files), then
  `sudo systemctl daemon-reload`.
- **Verify:** the check prints nothing and `systemctl list-timers --all | grep auto-suspend` prints nothing.

## Enable webterm globally and remove home_units (#62)
`--webterm` now enables its units for all users (`systemctl --global enable`), so their enable links are in
`/etc/systemd/user` with the units and start from boot even with an encrypted home. The `home_units` feature, which
started units enabled in the home once dirlock unlocked it, is gone. Applies to SteamOS machines that ran
`--webterm` or `--home_units`.

### Old home-units files in /etc (steamos)
- **Check:** `ls /etc/systemd/user/home-units.service /etc/systemd/user/default.target.wants/home-units.service /etc/dotfiles/home-units-start 2>/dev/null; grep -x '## feature home_units' /etc/atomic-update.conf.d/dotfiles.conf 2>/dev/null`
- **Fix:** after asking, `sudo systemctl --global disable home-units.service`, then
  `sudo rm -f /etc/systemd/user/home-units.service /etc/dotfiles/home-units-start` and
  `sudo sed -i '/^## feature home_units$/,/^$/d' /etc/atomic-update.conf.d/dotfiles.conf`.
- **Verify:** the check prints nothing, and `ls /etc/dotfiles` still lists `orei-switch` if `--orei_switch` ran.

### webterm still enabled per user (steamos)
- **Check:** `ls ~/.config/systemd/user/sockets.target.wants/webterm.socket 2>/dev/null`
- **Fix:** if it is a symlink, `rm ~/.config/systemd/user/sockets.target.wants/webterm.socket`, then
  `~/dotfiles/install.sh --variant steamos --webterm`.
- **Verify:** the check prints nothing, `readlink /etc/systemd/user/sockets.target.wants/webterm.socket` is
  `/etc/systemd/user/webterm.socket`, and after a reboot the URL `--webterm` prints answers once you log in.

## Move service scripts into /etc/dotfiles/bin (#62)
The scripts and binaries that system units and the login screen run moved into `/etc/dotfiles/bin`:
`/etc/dotfiles/orei-switch/orei-switch.sh` is now `/etc/dotfiles/bin/orei-switch`, and `framework_tool` and
`sddm-xsetup` moved beside it. The units and the SDDM config point at the new paths.

### Old orei-switch directory (framework16)
- **Check:** `ls -d /etc/dotfiles/orei-switch 2>/dev/null`
- **Fix:** `~/dotfiles/install.sh --variant steamos --orei_switch` first, so the new files and units are in place;
  once `systemctl cat orei-switch.service` shows `ExecStart=/etc/dotfiles/bin/orei-switch sleep`, after asking,
  `sudo rm -rf /etc/dotfiles/orei-switch`.
- **Verify:** the check prints nothing, `/etc/dotfiles/bin/framework_tool --version` runs, and
  `grep DisplayCommand /etc/sddm.conf.d/orei-switch.conf` shows `/etc/dotfiles/bin/sddm-xsetup`.
