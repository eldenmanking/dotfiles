# Syncing with upstream
This repo (eldenmanking/dotfiles, "the fork") was forked from professorlinstar/dotfiles ("upstream"). The fork's
history was later rewritten to scrub sensitive text, so the two no longer share commits. This is the plan for
rewriting upstream's history to match, merging the two, and then keeping a single canonical repo. It is written so
an agent with push access to upstream can carry out the upstream side.

## Background
- Git's apparent merge base is `ffa67ec` (2023-05-13), the last commit before the rewrite.
- The fork's history was rewritten and force-pushed to remove internal hostnames, internal repo names and PR/ticket
  references. They appeared in 6 files, all under `.claude/` and `tests/claude-pr-statusline/cases/` (32, 37, 39,
  40).
  - Authors, committers, dates and messages are unchanged.
  - PGP signatures were stripped, so every commit after `ffa67ec` has a new hash.
  - Author emails were left as they were: rewriting them would change every hash again.
- Upstream still has the unscrubbed history.

## Real merge base
- Upstream `b9334a8` = fork `39e1ec9` ("Fix dotfiles for coder", 2026-09-30).
- The 185 commits after `ffa67ec` map one to one, in the same order. Their trees differ only by the scrub.
- Upstream has two commits after that:
  - `8086f6e` "Continue claude in tmux + fix nvim sessions"
  - `e8ac133` "Update claude.md + remove tmux color setting"

## Rewritten upstream branches
Each upstream branch was rebuilt on the fork's copy of its base, keeping author, committer, dates and message, and
pushed to a staging branch on the fork. Upstream has no tags.

| Staging branch on the fork | Commit | Replaces upstream's |
|---|---|---|
| `rewrite/main` | `effee5a` | `main` @ `e8ac133` |
| `rewrite/andywang/termux` | `7a3ed7f` | `andywang/termux` @ `944c43c` |
| `rewrite/andywang/test` | `4a74fb4` | `andywang/test` @ `2b66ee7` |
| `rewrite/andywang/windows` | `8bb1d03` | `andywang/windows` @ `52a0ca5` |

Each staging tip has the same number of commits as the branch it replaces (381, 379, 236 and 203).

## Steps
Steps 1 and 2 are independent; step 3 needs both. PRs here are always squash-merged, so upstream's two commits
come into the fork as a port rather than a merge, and step 3 replaces upstream's `main` with the fork's.

```
After step 1, upstream main = effee5a (the scrubbed copy of its own history):

             6bf4fee ── effee5a                   upstream main; dropped in step 3
            /
… ── 39e1ec9 ── … ─────────── fork main ── P      step 2: P ports 6bf4fee (squash-merged PR)
                                           ▲
                     step 3: upstream main is force-pushed to the fork's main
```

### Step 1: force-push the rewritten branches to upstream
Run in a clone of professorlinstar/dotfiles with push access. Turn off branch protection on `main` first if it
forbids force-pushes.

1. Fetch the staging branches:
   ```sh
   git fetch https://github.com/eldenmanking/dotfiles 'refs/heads/rewrite/*:refs/remotes/staging/*'
   ```
2. Verify before pushing. Each pair must have the same commit count, and its tips may differ only by the scrub:
   `main` and `andywang/termux` in the 6 files above (28 lines changed each way), `andywang/test` and
   `andywang/windows` not at all.
   ```sh
   for b in main andywang/termux andywang/test andywang/windows; do
     echo "== $b: $(git rev-list --count origin/$b) vs $(git rev-list --count staging/$b)"
     git diff --stat origin/$b staging/$b
   done
   ```
   Stop and report if anything else differs, or if upstream's branches are no longer at the commits in the table
   (someone pushed since): the staging branches would need rebuilding.
3. Force-push, each guarded by the commit it replaces:
   ```sh
   git push --force-with-lease=main:e8ac133 origin staging/main:refs/heads/main
   git push --force-with-lease=andywang/termux:944c43c origin staging/andywang/termux:refs/heads/andywang/termux
   git push --force-with-lease=andywang/test:2b66ee7 origin staging/andywang/test:refs/heads/andywang/test
   git push --force-with-lease=andywang/windows:52a0ca5 origin staging/andywang/windows:refs/heads/andywang/windows
   ```
   Then confirm `git ls-remote origin` shows the four new commits.
4. Delete the staging branches from the fork (needs push access to it):
   ```sh
   git push https://github.com/eldenmanking/dotfiles --delete rewrite/main rewrite/andywang/termux \
     rewrite/andywang/test rewrite/andywang/windows
   ```

Caveats:
- A force-push doesn't purge the old commits: they stay reachable by SHA, through open PRs' `refs/pull/*` and
  caches, and possibly through the fork network. Fully removing them needs GitHub Support (their "removing
  sensitive data" process).
- Upstream's open PRs follow their branches to the new commits.
- Every clone of upstream must reset to the new history (`git fetch && git reset --hard origin/<branch>`, after
  saving any local work), or it will push the old commits back.

### Step 2: port upstream's two commits into the fork
Done by the PR that added this file, which ports them to the fork's layout:
- nvim: the `SessionLoadPost` autocmd running `CdToSession` is in `home/.config/nvim/core/autocommands.vim`.
- tmux: `home/.tmux/resurrect/claude_save.sh` is linked by every variant, with `@resurrect-processes 'claude'`
  and its post-save hook in `home/.tmux.conf`. The fork's `obsession` nvim strategy and `default-terminal
  tmux-256color` stay.
- The Claude `SessionStart` hook and `tmux-session-id.sh`, which `claude_save.sh` relies on, moved to
  eldenmanking/tools; merge that change before or with this one.
- Not taken: the commit-signing CLAUDE.md rule, and the `light-install.sh` change (the file no longer exists).

### Step 3: point upstream at the fork's main
Once steps 1 and 2 are done, in the clone from step 1:
1. Check that upstream's `main` is still the rewritten `effee5a` and shares the fork's history up to `39e1ec9`:
   ```sh
   git fetch origin
   git fetch https://github.com/eldenmanking/dotfiles main:refs/remotes/fork/main
   test "$(git rev-parse origin/main)" = "$(git rev-parse effee5a)"
   git merge-base --is-ancestor 39e1ec9 fork/main && echo ok
   ```
   Stop and report if upstream's `main` moved: the new commits need porting to the fork first, like step 2.
2. Replace upstream's `main`; its two commits after `39e1ec9` survive as their port in the fork:
   ```sh
   git push --force-with-lease=main:effee5a origin fork/main:refs/heads/main
   ```

Upstream then adopts the fork's whole layout: `home/` and `root/`, `install/`, the SteamOS features, Claude config
from eldenmanking/tools, and no `light-install.sh`. Its copy of `.github/workflows/install-branch.yml` creates
upstream's own `install` branch on its first CI-green push to `main`, which needs Actions enabled and
`github-actions` allowed to push the `install` branch. The README's curl URL still names the fork.

## Afterwards: one canonical repo
Treat the fork as canonical and send all work there; don't commit to upstream directly, or the two diverge again
and every change has to be merged both ways. Either archive upstream, or keep it as a mirror that only ever
fast-forwards to the fork's `main` (`git push origin fork/main:refs/heads/main`, no force). Machines whose checkout still points at upstream should switch:
`git -C ~/dotfiles remote set-url origin https://github.com/eldenmanking/dotfiles`.

## Status
- Step 1: not done.
- Step 2: this file's PR.
- Step 3: not done.

A Claude Code cloud session can't attach both repos at once, since both are named `dotfiles`. Do step 1 and step 3
in a session with only upstream attached, or in a local clone.
