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
- Uninstall features that are no longer in the variant, or no longer in the repo.
- Never destroy a change the user made after install.
- A fallback for anything the current code can't undo: the commit that installed it.

Not in scope for now: transaction-level hooks (one `daemon-reload` for the whole run), and a conflict pre-check
before any feature runs (see Later).

## Layout
- `~/.local/state/dotfiles/`: entries for paths under `$HOME` and per-user state (user units, settings).
- `/var/lib/dotfiles/` (root-owned): entries for paths outside `$HOME` and system state (system units, packages).
  SteamOS updates replace `/etc` but keep `/var`. This needs confirming with the `steamos-update` fixture.

Both have the same shape:

```
<db>/
├── features/<name>/manifest   --- entries for <name>, as of its last run
├── backups/<name>/<path>      --- files and links an entry replaced, at their original path
└── fallback                   --- present only while a commit fallback is in progress
```

## Manifest format
A manifest is a text file with one record per line and fields separated by tabs. bash 3.2 can read it with
`IFS=$'\t' read -r`. The header comes first:

```
version	1
commit	<sha of the checkout that wrote it>
variant	<variant>
```

Each later line is an entry: `<kind>	<key...>	<written>	<prior>`. Entries appear in the order they were made, and
are undone in reverse. A path containing a tab or newline is an error.

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
- A key is owned by one feature. Recording a key another feature's manifest holds is an error, the same as a pacman
  file conflict.
- `prior` is captured when a feature first takes ownership of a key. It is carried forward unchanged while the key stays
  in the manifest, so it always describes the state before dotfiles, never dotfiles' own earlier output. A key that is
  dropped (undone) and later recorded again captures a fresh `prior`.
- `written` is what the entry last wrote. If the current state differs from it, the user has changed it since.
- The new manifest is written to a temporary file and moved into place when the feature finishes, so a crash never
  leaves half a manifest behind.
- `--dry-run` never writes the database. It reports the entries it would record and undo.

## Install and reinstall
For each selected feature, in `_features` order:
1. Read its manifest. If the manifest's `version` isn't the current one, or it holds a kind this code doesn't know, take
   the commit fallback for it (below) before going on. Never undo part of a manifest.
2. Run the feature, recording entries.
3. If it succeeded, undo the old entries whose keys weren't recorded this run, newest first, and write the new
   manifest. If it failed, write the old entries plus the new ones and undo nothing, so the next run can still clean up.

Features that have a manifest but aren't selected are reported as installed but not selected; `--uninstall` with
their flag removes them, even if they have since been deleted from the repo.

## Undo
Each kind has one generic undo. An entry whose current state differs from `written` was changed by the user: it is kept
and reported, never overwritten or deleted (like pacman's `.pacsave`).

| Kind | Undo |
|---|---|
| `link` | if it still points at `written`, remove it and restore the backup |
| `file` | if its hash matches `written`, remove it and restore the backup (a `dir` is removed only if unchanged since it was cloned) |
| `block` | `remove_block`; if `prior` is `-` and the file is now empty, remove the file |
| `unit` | disable and remove it, or return it to `prior` |
| `package` | report only; never removed automatically (see Open questions) |
| `setting` | restore `prior`, or unset it |

`--uninstall` undoes every entry in a feature's manifest, newest first, then removes the manifest and its backups.
`uninstall_feature_<name>` still runs first for anything entries can't express, and becomes rare.

## Versioning the format
The manifest format has one integer version. Bump it on any change a reader must understand: removing or renaming a
kind, changing what a field means, or adding a kind, since older code can't undo it. Fields a reader may ignore can
be added without a bump. Readers accept only their own version. A mismatch is never converted in code. It takes the
commit fallback, which runs the code that wrote the manifest and so understands it. Dropping a kind therefore needs no
compatibility code: machines with old manifests take the fallback once.

## Commit fallback
Each manifest records the commit that wrote it, and `refs/dotfiles/installed/<feature>` points at it so git never
garbage-collects it (e.g. after a squash merge removes the branch it was on). To undo a feature the current code can't:

1. Refuse if `~/dotfiles` has uncommitted changes.
2. Write `<db>/fallback` with the current branch or commit and the features being undone.
3. Group the features by recorded commit. For each commit: `git checkout --detach <commit>`, then
   `./install.sh --uninstall --variant <variant> --<feature>...`. Before the database existed, this runs the old
   `uninstall_feature_<name>`; after, the old code's own generic undo.
4. Check out the branch or commit from step 2 again, remove `<db>/fallback`, and continue the install.

A run that finds `<db>/fallback` was interrupted. It restores the checkout before doing anything else. The checkout
happens in place because `install.sh` only runs from `~/dotfiles`, and linked config points into it.

Because old commits are invoked this way, `./install.sh --uninstall --variant <v> --<feature>` is a compatibility
contract: later versions must keep accepting it.

## Relation to existing pieces
- `BACKUPS_ROOT` (`~/dotfiles/.backup`) is replaced by `<db>/backups`. Backups recorded in `prior` are restorable, and a
  later backup can't overwrite an earlier one.
- `uninstall_feature_<name>` stays for steps entries can't express.
- `docs/migrations.md` stays for machines installed before the database, and for changes outside any entry.

## Later
- Conflict pre-check: plan every selected feature (a dry run that records entries) and check the keys against the
  disk and other features' manifests before changing anything.
- Transaction-level hooks.

## Open questions
- Packages: should uninstall ever remove a package whose `prior` is `-`? The proposal records and reports them only.
- Unselected features: report them (proposed), or uninstall them automatically on install?
