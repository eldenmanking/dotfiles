# Install database (design proposal)
Status: proposal, nothing here is implemented yet.

`install.sh` features are convergent: each checks the current state and fixes it, and remembers nothing. So nothing
knows what an older version installed. Stale files need hand-written steps in `docs/migrations.md`, and each
`uninstall_feature_<name>` has to work out again what its feature did. Package managers solve this with a database of
what each package installed (pacman's `/var/lib/pacman/local`, dpkg's `/var/lib/dpkg`), and this proposal does the same
for features: the shared helpers record every change a feature makes, with the state it replaced, so a later run can
undo what a feature no longer does and an uninstall can restore what was there before.

## Goals
- Undo, generically: remove what a feature installed, restoring what it replaced, without per-feature code.
- Upgrade by diff: after a feature runs, undo what it did last time but not this time, as pacman does for files dropped
  from a package. This replaces most `docs/migrations.md` entries.
- Uninstall features that are no longer in the selection's feature list, or no longer in the repo.
- Never destroy a change the user made after install without asking.
- Change the format without losing what older installs recorded: major and minor versions, with a bridge release
  for each major version.

Features declare their changes through hooks (see Hooks), so the runner sees every change before making any: that
gives one `daemon-reload` for the whole run and a conflict pre-check before anything is changed.

## Layout
The database lives in the checkout, ignored by git, next to everything else `install.sh` owns:

```
~/dotfiles/.state/
├── manifest                   --- every feature's entries, as of each feature's last run
├── manifest.next              --- present only while a bridge run converts the manifest to a new major version
├── backups/<feature>/<path>   --- files and links an entry replaced, at their original path
└── lock                       --- present while install.sh runs, so two runs can't interleave
```

- `.state` goes in `.gitignore`. Old commits' `.gitignore` doesn't list it, but git leaves untracked paths alone on
  checkout, so checking out an older commit doesn't disturb it.
- Entries outside `$HOME` (system files, system units, packages) are recorded here too. That gives no new power to
  anyone who can write the checkout: they can already change the code `install.sh` runs with sudo.
- Backups of files outside `$HOME` are written with sudo and keep their owner and mode, under a root-owned
  `backups/<feature>/` directory, so a root-only file doesn't become readable by copying it into the home.
- Deleting the checkout deletes the database, as it already deletes `.backup`. A fresh clone starts with no
  database, so it behaves like a machine that installed before the database existed.
- Encrypted homes are not a concern: the database is read only when `install.sh` runs, never at boot.

## Manifest format
The manifest is one text file with one record per line and fields separated by tabs. bash 3.2 can read it with
`IFS=$'\t' read -r`. Its first line is the format version (see Versioning the format), then each installed feature
has a header line followed by its entries:

```
version	1.0
feature	<name>	<sha of the checkout its last run used>	<os>	<profile>	<machine>
<name>	<kind>	<key...>	<written>	<prior>
...
```

Each feature keeps its own commit, since runs can install a subset of features (`--tmux`) or fail partway, and
`refs/dotfiles/installed/<feature>` points at it so git never garbage-collects it (e.g. after a squash merge removes
the branch it was on). The commit is there for diagnosis and for migration steps that need the old code. A feature's
entries appear in the order they were made, and are undone in reverse. A path containing a tab or newline is an error.

| Kind | Made by | Key | `written` | `prior` |
|---|---|---|---|---|
| `link` | `make_symlink` | target | link destination | `-` (absent), `file` or `link:<dest>` (backed up) |
| `file` | `copy_system_file(s)`, `write_file`, `download_verified`, git clones | path | sha256, or `dir` | `-` or `file` (backed up) |
| `block` | `upsert_block`, `upsert_sources`, `keep_across_steamos_updates` | file, block name | sha256 of block | `-` (file absent) or `file` |
| `unit` | `install_system_units`, `install_user_units` | scope (`system`/`user`), unit | `enabled` or `installed` | `-`, `installed` or `enabled` |
| `package` | package installs (pacman, yay, apt, flatpak, brew) | manager, name | `installed` | `-` or `installed` |
| `setting` | `kwriteconfig`, `dconf` | tool, key | value | value, or `-` (unset) |

Settings are the one kind whose prior state must be read before writing. For `dconf load` that means dumping the
tree it loads into first.

## Recording
- Helpers record entries. Features don't call the database directly, so a feature written with the helpers gets a
  manifest for free.
- A key is owned by one feature. Recording a key the manifest gives another feature is an error, the same as a pacman
  file conflict.
- `prior` is captured when a feature first takes ownership of a key. It is carried forward unchanged while the key stays
  in the manifest, so it always describes the state before dotfiles, never dotfiles' own earlier output. A key that is
  dropped (undone) and later recorded again captures a fresh `prior`.
- `written` is what the entry last wrote. If the current state differs from it, the user has changed it since.
- A feature's entries are collected in a temporary file. When the feature finishes, the whole manifest is rewritten
  with that feature's section replaced, to a temporary file that is then moved into place, so a crash never leaves
  half a manifest behind.
- `--dry-run` never writes the database. It reports the entries it would record and undo.

## Install and reinstall
For each selected feature, in `_features` order:
1. Read the feature's section. A manifest of another version is handled as Versioning the format describes.
2. Run the feature, recording entries.
3. If it succeeded, undo the old entries whose keys weren't recorded this run, newest first, and write the new
   manifest. If it failed, write the old entries plus the new ones and undo nothing, so the next run can still clean up.

Features in the manifest that this run doesn't select:
- With `--all`, once every selected feature has run, each feature in the manifest that the selected OS and profile
  don't list in `_features` is undone, in reverse manifest order. That covers features since dropped from the list or
  deleted from the repo, and those of an OS or profile the machine used before. Optional features the list names stay
  installed, since `--all` never selects them. Their entries are only undone by `--uninstall` with their flag.
- Without `--all`, they are left alone, since a run that names features changes only those. The run ends by listing
  the features in the manifest that the selected OS and profile don't list in `_features`, each with its OS, profile
  and recorded commit, and how to remove them: `--all`, or `--uninstall` with their flags. Features the list does
  name but this run didn't select aren't listed: they're still part of the install.

`--uninstall` with a feature's flag removes it even if the feature has since been deleted from the repo.

## Undo
Entries are undone in one of two modes:
- Stale undo, the default: every install undoes the entries a feature no longer records, and under `--all` the
  features the selection no longer lists (see Install and reinstall). It is conservative. It skips an entry whose
  current state differs from `written`, since the user changed it (like pacman's `.pacsave`), and an entry the
  generic undo can't remove (see Escape hatch in Follow-ups). Both are reported and stay in the manifest, so
  `--uninstall` can still remove them.
- `--uninstall`, as today: removes everything a feature recorded, so the machine returns to its state before the
  feature. It also removes the entries stale undo skips: it asks before overwriting or deleting a change the user made,
  and runs the feature's own code for entries the generic undo can't remove. `--reinstall` is `--uninstall` and
  then an install, as today.

Packages are asked about in both modes (see Packages).

Each kind has one generic undo:

| Kind | Undo |
|---|---|
| `link` | if it still points at `written`, remove it and restore the backup |
| `file` | if its hash matches `written`, remove it and restore the backup (a `dir` is removed only if unchanged since it was cloned) |
| `block` | `remove_block`; if `prior` is `-` and the file is now empty, remove the file |
| `unit` | disable and remove it, or return it to `prior` |
| `package` | if `prior` is `-`, ask before removing it (see Packages); if `prior` is `installed`, leave it |
| `setting` | restore `prior`, or unset it |

`--uninstall` undoes every entry of a feature, newest first, then removes its section and its backups. Entries the
user declines to remove (a package, or a file they changed) stay in the section, and the section goes once they are
gone. `uninstall_feature_<name>` still runs first for anything entries can't express, and becomes rare. For a feature
deleted from the repo, that code is gone too: its generic entries are still undone, and the rest are reported with
the feature's recorded commit, whose code can remove them.

### Packages
A package is never removed without asking, whichever path undoes it: `--uninstall`, a package dropped from a
feature's list, or a feature undone under `--all`.
- Only packages whose `prior` is `-` are offered for removal. A package that was installed before dotfiles is left
  alone and its entry dropped.
- Each feature asks once, listing its packages for that package manager, and removes them through it (e.g.
  `pacman -Rs`, `flatpak uninstall --user`). The package manager still refuses to remove a package that others
  depend on.
- A package the user declines, or any package when there is no terminal to ask on, is kept and reported. Its entry
  stays in the manifest, so a later run asks again. `--dry-run` reports what it would ask.

## Hooks
Features declare what they want instead of making changes themselves. The runner collects every feature's
declarations into one plan, checks it, applies it, and records it in the manifest. That makes a feature mostly data,
like a pacman package, and gives `--dry-run`, the conflict pre-check and the manifest diff the same input: the plan.

### Phases
For one run of `install.sh`:

1. **Declare.** For each selected feature, in `_features` order, call `declare_<name>`. It calls `hook_*`
   functions and changes nothing. It may read the disk (which Steam users exist, whether `kwriteconfig6` is present),
   but never write it. Each hook call adds an entry, tagged with the declaring feature, to the plan.
2. **Plan.** Compare the plan with the manifest and the disk:
   - a key declared by two features, or owned in the manifest by a feature not being reinstalled, is an error;
   - a target that exists and isn't what an entry would write gets its `prior` recorded (and is backed up on apply);
   - manifest entries of the selected features that the plan no longer has are marked for undo.

   `--dry-run` prints the plan (entries to apply, entries to undo, triggers that would fire) and stops here.
3. **Apply.** Apply entries by kind, then by feature order within a kind: `package`, `file` (copies and
   downloads), `link`, `block`, `setting`, `unit`. Packages come first because they provide the tools later kinds use;
   units last because they reference files. Then undo the entries marked in step 2, newest first.
4. **Triggers.** Run each trigger whose paths any applied or undone entry touched, once (see below).
5. **Post.** For each feature, in `_features` order, call `post_<name>` if it exists: steps that need the changes
   made and loaded, like checking that webterm answers.
6. **Record.** Write the manifest, as in Recording.

A feature that fails in apply stops the run. As in Install and reinstall, its old entries plus the ones applied so far
are written and nothing is undone. A failing `post_<name>` marks its feature as failed but leaves its entries applied
and recorded.

### Hook functions

| Hook | Kind | Replaces |
|---|---|---|
| `hook_link <repo path>...` | `link` | `_link_paths` / `LINK_*_PATHS`, `make_symlink` |
| `hook_file <src dir> <dest dir> <glob>` | `file` | `copy_system_file(s)` |
| `hook_download <dest> <url> <sha256> [--mode m]` | `file` | `download_verified`, `install_ttyd` |
| `hook_block <file> <name> <content> [--before <line>]` | `block` | `upsert_block` |
| `hook_sources <file> <name> <repo path>...` | `block` | `upsert_sources` |
| `hook_unit system\|user\|global <src dir> <unit>... [--start\|--no-start] [--restart-on-change]` | `unit` | `install_*_units`, hand-written `restart`/`try-restart` |
| `hook_package <manager> <name>...` | `package` | `pacman -S`, `yay -S`, `flatpak install` |
| `hook_setting <tool> <key> <value>` | `setting` | `kwriteconfig`, `dconf`, `xdg-mime` |
| `hook_note <text>` | none | `info` lines meant for the end ("restart the browser"), printed together after Post |

The block name defaults to the feature name, so `shell`, `starship` and `zsh` each own their own block in `.zshrc`,
and the runner writes each file once with all its blocks in feature order.

`hook_package` installs one batch per manager (`pacman -S --needed a b c`), and records `prior` as whether each package
was installed before.

### Triggers
A trigger maps paths to an action that runs once per run, after apply and undo, like an ALPM hook:

| Paths | Action |
|---|---|
| `/etc/systemd/system/*` | `sudo systemctl daemon-reload` |
| `/etc/systemd/user/*` | `systemctl --user daemon-reload` (if there is a user session) |
| `/etc/udev/rules.d/*` | `sudo udevadm control --reload`, then `udevadm trigger` |
| `/etc/tmpfiles.d/*` | `sudo systemd-tmpfiles --create <changed files>` |
| `/etc/systemd/logind.conf.d/*` | `sudo systemctl reload systemd-logind` |
| `~/.local/share/fonts/*` | `fc-cache -f` |
| `~/.local/share/applications/*` | `update-desktop-database` |

Units are enabled, started and restarted after the reloads, as their `hook_unit` flags say.

The SteamOS keep list is not a hook features call. The runner derives it from every `file` and `unit` entry under
`/etc` that the default keep list doesn't cover (`unit_keep_paths`), and writes `dotfiles.conf` once. No feature can
forget it, and `keep_across_steamos_updates` goes away.

### Examples
`udev` today copies, adds to the keep list and reloads by hand. Declared:

```bash
declare_udev() {
  hook_file "$UDEV_RULES_SRC" /etc/udev/rules.d '*.rules'
}
```

`webterm` declares its own links (from `LINK_WEBTERM_PATHS`), so it no longer needs `@requires link`:

```bash
declare_webterm() {
  hook_link home/.config/webterm home/.local/bin/webterm-{index,shell,ttyd} home/.local/share/webterm
  hook_download "$TTYD_BIN" "$(ttyd_url)" "$(ttyd_sha256)" --mode 755
  hook_unit global "$WEBTERM_UNITS_SRC" webterm.socket --start
  hook_unit global "$WEBTERM_UNITS_SRC" webterm.service webterm-ttyd.service --no-start --restart-on-change
}

post_webterm() {
  run "$LOCAL_BIN/webterm-index" || warn "could not build the webterm page; ttyd will serve its stock page"
  save_token "$(webterm_token)"
  check_socket_activation "$(webterm_url "$(webterm_token)")"
}
```

`link` disappears as a feature once every path is declared by the feature it belongs to; paths that belong to no
other feature (`home/.vimrc`, `home/.config/alacritty`, ...) move to a `dotfiles` feature per profile.

### Migrating
`feature_<name>` keeps working, so features move one at a time. A feature with `feature_<name>` and no
`declare_<name>` runs in apply, in feature order, after the declared entries of its kind are applied; its helpers
record entries and queue paths for the triggers as they run. It can't take part in the conflict pre-check, which
reports it as unchecked. When the last feature is converted, the imperative path is removed.

### Open questions
- `hook_setting` needs the per-tool accessors in Follow-ups (`vdf`, `dconf` per key, ...). Until a tool has one,
  its feature keeps writing it from `post_<name>`, with no manifest entries.
- Trigger arguments: `udev` triggers only the `i2c` subsystem today. Either triggers take arguments from the entries
  that fired them, or the trigger re-applies every subsystem.
- Distrobox features run inside a container. They stay imperative (`post_<name>`) until there's a kind for them.

## Versioning the format
The manifest's first line holds its format version, `<major>.<minor>`, starting at `1.0`. The code has a version too,
the one it writes.

- **Minor bump** (`1.1` to `1.2`): a change newer code can read older manifests through unchanged, such as adding a
  kind or a field older manifests simply don't have. A manifest of an earlier minor version is a valid manifest of the
  later one, so code reads any manifest of its major version up to its own minor, and rewrites it at its own version.
- **Major bump** (`1.x` to `2.0`): any other change, such as removing or renaming a kind, or changing what a field
  means.
- **Bridge release:** each major version's `.0` reads both the previous major version (every minor of it) and its own.
  Run on an older manifest, it reads the old entries with the old version's rules and undoes them with the old undo
  for any kind it dropped. It writes the new format, carrying `prior` and the backups over for keys it records again.
  It writes the new sections to `.state/manifest.next` and replaces `manifest` with it only once every feature has
  succeeded, so a run that fails partway leaves the old manifest whole. Rerunning the bridge picks up both files, and
  every run other than the bridge's `--all` is refused while `manifest.next` exists. Later minors (`2.1` on) may drop
  the old major's code. A bridge release is tagged `manifest-v<major>.0`, and the major bump lands in two steps: the
  bridge first, then the first change that needs the new format.

What a run does with the manifest it finds:

| Manifest | Code | Run |
|---|---|---|
| same major, same or earlier minor | any | as normal |
| previous major | the bridge (`.0`) | only `--all`, which converts the whole manifest; partial runs are refused |
| previous major | a later minor (`2.1`) | refused: run `--all` from the bridge first |
| older still, e.g. `1.x` for `3.y` code | any | refused: run `--all` from each bridge in turn (`2.0`, then `3.0`) |
| newer (later minor, or later major) | any | refused: older code can't read it |

So going from `1.1` to `2.1` is two runs: `--all` from `manifest-v2.0`, which moves the manifest to `2.0`, then
`--all` from `2.1`, which reads `2.0` as an earlier minor. A refused run names both versions and prints the commands, e.g.
`git -C ~/dotfiles checkout manifest-v2.0 && ~/dotfiles/install.sh --all`, then the same from the branch it started
on. Each major bump also adds a `docs/migrations.md` entry (with the `update-migrations` skill) giving these steps, so
the migration checklist covers it, and a fixture case that runs the bridge over a manifest of the previous major
version.

Going back to older code across a version that changed the manifest isn't supported. Uninstall with the newer code
first, then install with the older.

## Relation to existing pieces
- `BACKUPS_ROOT` (`~/dotfiles/.backup`) is replaced by `.state/backups`. Backups recorded in `prior` are restorable,
  and a later backup can't overwrite an earlier one.
- The fixtures leave `~/dotfiles` out of the files they compare, except `.backup`. They would include `.state` in its
  place, with the commit in the manifest normalized, so each case pins what its install records.
- `uninstall_feature_<name>` stays for steps entries can't express.
- `docs/migrations.md` stays for machines installed before the database, for changes outside any entry, and to list
  the bridge runs for each major version bump.

## Follow-ups
From an audit of what the current features change that the kinds above don't yet cover:
- Directory trees: a `dir` kind that records the tree's file list, for the font, git clones (zsh plugins, tpm and its
  plugins, the tools repos) and extracted releases. A git checkout is removed only if it has no local changes or
  unpushed commits; otherwise it is kept and reported.
- Installers: audit each installer that writes files without listing them (tmux's and logiops' `make install`, gng's
  and starship's install scripts, tpm's `install_plugins`, neovim's `cp -r` into `~/.local`), and sandbox them: run
  each into a staging directory (`DESTDIR`, a temporary prefix, an extract to a temporary directory) and install the
  result through the helpers, so every file is recorded.
- Escape hatch: whatever the generic undo can't remove (e.g. the distrobox container, the webterm token that
  uninstall keeps) is still recorded as an entry, with its prior state, and undone by the feature's own code.
  Stale undo keeps such an entry and reports it, but `--uninstall` should almost always have a clean way to remove
  it.
- Side effects: temporary ones (`udevadm` reloads, service restarts, `fc-cache`) aren't recorded. Permanent ones
  are, with their prior state where it can be read: e.g. the paths `systemd-tmpfiles --create` makes, and what
  installers like gng's write outside their own files.
- Settings: give `setting` an accessor per tool, each able to read (for `prior`), write and unset: `git-config`,
  `kconfig`, `dconf` (per key), `xdg-mime`, `json` (key path, for `settings.json`), `vdf` (Steam) and `line` (a file
  plus a pattern, for `confirmsed`). The flathub remote is a `flatpak-remote` setting.
- Helpers for what features now do directly: enabling a unit dotfiles didn't install (`unit` with `prior`
  `installed`, undone by disabling only), `git clone`, `cp` and `sudo install`. A check in `tests/lint/` then
  flags direct writes in `install/features/`, so new code can't bypass the manifest.
