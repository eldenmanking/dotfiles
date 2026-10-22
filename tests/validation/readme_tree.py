#!/usr/bin/env python3
"""Check that the file tree in README.md matches the files tracked by git.

Every tracked file must appear in the tree (or under a directory the tree lists
without expanding), and every entry in the tree must exist. Names too long for
the tree's name column are cut off right before the "---" separator; those
match any tracked name they are a prefix of.
"""
import os
import subprocess
import sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
BRANCHES = ("├── ", "└── ")


def tree_lines(readme):
    """Yield the lines of the first fenced block, after its root line."""
    with open(readme, encoding="utf-8") as f:
        lines = f.read().split("\n")
    start = lines.index("```") + 1
    end = lines.index("```", start)
    return lines[start + 1:end]


def parse_tree(lines):
    """Return {path: truncated} for every entry in the tree."""
    entries, stack = {}, []
    for lineno, line in enumerate(lines, 2):
        pos = min((line.find(b) for b in BRANCHES if b in line), default=-1)
        if pos < 0 or pos % 4:
            sys.exit(f"README.md tree line {lineno}: can't parse: {line!r}")
        rest = line[pos + 4:]
        sep = rest.find("---")
        name = (rest if sep < 0 else rest[:sep]).rstrip()
        # A name that runs (almost) into the separator may have been cut off.
        truncated = sep >= 0 and sep - len(name) <= 1
        del stack[pos // 4:]
        stack.append(name)
        entries["/".join(stack)] = truncated
    return entries


def main():
    files = subprocess.run(["git", "-C", REPO, "ls-files"], capture_output=True, text=True,
                           check=True).stdout.split()
    dirs = {os.path.dirname(f) for f in files}
    dirs |= {d[:i] for d in dirs for i in range(len(d)) if d[i] == "/"}
    entries = parse_tree(tree_lines(os.path.join(REPO, "README.md")))

    def resolve(entry, truncated):
        if entry in dirs or entry in files:
            return entry
        if truncated:
            matches = [p for p in files + sorted(dirs) if p.startswith(entry)
                       and "/" not in p[len(entry):]]
            if len(matches) == 1:
                return matches[0]
        return None

    errors, listed = [], set()
    for entry, truncated in entries.items():
        path = resolve(entry, truncated)
        if path is None:
            errors.append(f"listed in README.md but not tracked: {entry}")
        else:
            listed.add(path)
    leaf_dirs = {p for p in listed if p in dirs
                 and not any(q.startswith(p + "/") for q in listed)}
    for f in files:
        if f not in listed and not any(f.startswith(d + "/") for d in leaf_dirs):
            errors.append(f"tracked but missing from the README.md tree: {f}")

    for e in errors:
        print(e)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
