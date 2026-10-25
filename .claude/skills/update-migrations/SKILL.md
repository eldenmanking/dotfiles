---
name: update-migrations
description: Add or update entries in docs/migrations.md, the manual steps machines need after a change on main leaves stale files behind. Use when a change moves, renames or stops installing files that install.sh put on machines (moved files under home/ or root/, changed link paths, renamed units or /etc files), and after such a change merges, to fill in its commit hash.
---

# Update migrations
`install.sh` features install only the current layout and never clean up after an older one (see "Don't encode
migrations" in `.claude/CLAUDE.md`). When a change leaves stale files on machines that installed an earlier version,
`docs/migrations.md` gets an entry with the steps to fix them by hand, which an agent works through after a pull.
This skill covers both halves: writing the entry with the change, and filling in its commit once it is on `main`.

## Decide whether a change needs an entry
Compare what an install leaves on a machine before and after the change, not just the repo diff. It needs an entry
when a machine that ran the old version would be left with something wrong or stale after pulling and re-running
the same `install.sh` command:
- a file under `home/` or `root/` moved or was renamed, so the old link or copy stays behind (a dangling symlink,
  an outdated copy, an untracked file in the checkout);
- a path left `LINK_*_PATHS`, or a feature stopped copying a file, so the installed one is no longer managed;
- an installed file now points somewhere new (a unit's `ExecStart`, a sourced path) and the old copy points at
  something that is gone;
- a feature must be re-run, or run in a new order, for the machine to pick the change up.

It doesn't need one when re-running the same command fixes everything by itself (an idempotent feature that
rewrites its own files), or when nothing was ever installed from the changed files.

## Write an entry (in the change's own PR)
Append one `##` section at the end of `docs/migrations.md` (entries are oldest first), headed by what changed and
the PR number: `## <short description> (#<number>)`. The PR's own commit hash doesn't exist until it merges, so leave
it out; the "Fill in commits" step below adds it. Under the heading:
- One paragraph saying what changed and which machines it affects (variant, OS, or hardware).
- One `###` step per stale thing, named for the symptom and tagged with the variant it applies to, e.g.
  `### webterm units still point into steamos/ (steamos)`. Each step has:
  - **Check:** a read-only command that prints something only when the machine needs this step, so it is safe to
    run anywhere. Prefer exact paths and `2>/dev/null` over broad searches.
  - **Fix:** the commands, preferring `~/dotfiles/install.sh --variant <name> --<feature>` over hand edits. Name
    anything destructive (`rm`, `sudo`) explicitly and say to ask the user first; say what must have verified before
    a deletion, and never delete regular files where only links are expected.
  - **Verify:** what shows the fix worked, usually "the check prints nothing" plus a functional check.

Keep the steps in the order they must run. Then run `make check` (the README tree lists `docs/migrations.md`, so no
tree change is needed for a new entry).

## Fill in commits (after merging)
Entries written in a PR name only the PR number. Once it is on `main`, add the squash commit's short hash:

1. `git fetch origin main`, then list headings with no hash: `grep -nE '^## .*\(#[0-9]+\)$' docs/migrations.md`.
2. For each, find the commit: `git log --format='%h %s' --grep='(#<number>)' origin/main`. Use it only if exactly
   one commit matches and its subject ends with `(#<number>)`; otherwise leave the heading alone and report it.
3. Rewrite the heading as `## <description> (#<number>, <hash>)`, matching the existing entries.
4. Check the entry still describes what merged (the PR may have changed after the entry was written), then run
   `make check`.

Commit the result on its own branch, with a message such as `docs/migrations.md: add commits for #<number>`, and
open a PR only if the user asks for one.
