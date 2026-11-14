#!/usr/bin/env python3
"""Check the doc comment of every top-level function (`name() {` or `name () {` at the start of a line): a
description, then a Usage line showing how to call it, optionally followed by one line per argument:

    # Print the paths that copy_system_files would copy each file in <src_dir> matching <glob> to in <dst_dir>.
    # Usage: system_file_targets <src_dir> <glob> <dst_dir>
    #   <glob>: a shell pattern, matched against file names only

A function that returns values with f_return (install/lib/fn.sh) is called with f_call, so its Usage line is the
f_call, and a Returns line follows, optionally followed by one line per returned name:

    # Copy each file in <src_dir> matching <glob> into <dst_dir> with sudo, replacing any old symlink.
    # Usage: f_call copy_system_files changed -- <src_dir> <glob> <dst_dir>
    #   <glob>: a shell pattern, matched against file names only
    # Returns: changed
    #   changed: the space-separated targets that were copied (empty if all were up to date)
    #     (a longer entry continues on lines indented two more spaces)

A Usage or Returns line too long for one line continues onto the next after a backslash, as in shell.

It fails unless the comment has a description before its Usage line, and the Usage line starts with the function's
name, or for one that calls f_return, is f_call <function>, the names it returns, then (if it takes any) -- and its
arguments, with a Returns line listing the same names in the same order, exactly the names its f_return calls return.
(A function that passes on what another returns, without calling f_return itself, may have an f_call Usage line and a
Returns line too.) Each entry names an argument from the Usage line or a name from the Returns line, and the entries
come last. feature_<name>, uninstall_feature_<name> and capture_feature_<name> in install/features are left out:
install.sh calls them all the same way (<os> <profile> <enabled>), and tests/validation/features.sh checks a feature's
doc, which ends with tags.

Shell is only tokenized here, not parsed: quotes (across lines too), comments, here-documents and backslash
continuations are understood, which is enough for the functions in this repo. Run by `make lint` with the shell files
to check.
"""

import re
import sys

NAME = r"[A-Za-z][A-Za-z0-9_]*"
FUNCTION = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*) ?\(\) *\{")
FEATURE = re.compile(r"^(uninstall_|capture_)?feature_[a-z0-9_]+$")
COMMAND_SEP = re.compile(r";|&&|\|\||[|&(){}]")


HEREDOC = re.compile(r"<<(-?)\s*(['\"]?)([A-Za-z_][A-Za-z0-9_]*)\2")


def code_lines(text):
    """Return the lines of text with quoted strings replaced by "", and comments and here-documents removed, so
    only code is left. A command continued over several lines (a backslash, or a quote spanning lines) is joined onto
    its first line, and the lines it took up are left empty, so that line numbers still match the file."""
    out, line, i, n = [], [], 0, len(text)
    joined = 0  # newlines inside the current line, to add back as empty lines after it
    heredocs = []  # (strip tabs, delimiter) of here-documents that start after the current line
    while i < n:
        c = text[i]
        if c == "\\" and i + 1 < n:
            if text[i + 1] == "\n":
                joined += 1
            else:
                line.append("x")
            i += 2
        elif c in "'\"":
            j = i + 1
            while j < n and text[j] != c:
                j += 2 if c == '"' and text[j] == "\\" else 1
            line.append('""')
            joined += text.count("\n", i, j)
            i = j + 1
        elif c == "#" and (not line or line[-1] in " \t;|&("):
            while i < n and text[i] != "\n":
                i += 1
        elif text.startswith("<<", i) and not text.startswith("<<<", i) and HEREDOC.match(text, i):
            match = HEREDOC.match(text, i)
            heredocs.append((match.group(1) == "-", match.group(3)))
            line.append("<<")
            i = match.end()
        elif c == "\n":
            out.append("".join(line))
            out.extend([""] * joined)
            line, joined = [], 0
            i += 1
            for strip_tabs, delimiter in heredocs:
                while i < n:
                    end = text.find("\n", i)
                    end = n if end < 0 else end
                    body_line = text[i:end]
                    i = end + 1
                    out.append("")
                    if (body_line.lstrip("\t") if strip_tabs else body_line) == delimiter:
                        break
            heredocs = []
        else:
            line.append(c)
            i += 1
    out.append("".join(line))
    out.extend([""] * joined)
    return out


def returned_names(body):
    """Return the names the f_return calls in code lines body return, in order of first use."""
    names = []
    for line in body:
        for command in COMMAND_SEP.split(line):
            words = command.split()
            if not words or words[0] != "f_return":
                continue
            for word in words[1:]:
                name = word.split("=", 1)[0]
                if re.fullmatch(NAME, name) and name not in names:
                    names.append(name)
    return names


def functions(lines, code):
    """Yield (line number, name, doc comment lines, returned names) for each top-level function."""
    for start, line in enumerate(code):
        match = FUNCTION.match(line)
        if not match:
            continue
        # Quotes are gone, so the braces left balance: ${...} expansions open and close on one line.
        end, depth = start, 0
        while end < len(code):
            depth += code[end].count("{") - code[end].count("}")
            if depth <= 0:
                break
            end += 1
        names = returned_names(code[start:end + 1])
        doc_start = start
        while doc_start > 0 and lines[doc_start - 1].startswith("#") and not lines[doc_start - 1].startswith("#!"):
            doc_start -= 1
        doc = [re.sub(r"^# ?", "", doc_line) for doc_line in lines[doc_start:start]]
        yield start + 1, match.group(1), doc, names


def check_entries(entries, known, what, where):
    """Return problems with the entry lines after a Usage or Returns line: each `  key: text` names one of known."""
    problems, in_entry = [], False
    for entry in entries:
        match = re.match(r"^  (\S+): \S", entry)
        if match:
            in_entry = True
            if match.group(1) not in known:
                problems.append(f"{where}: entry '{match.group(1)}' under {what} is not one of: {' '.join(known)}")
        elif in_entry and re.match(r"^    \S", entry):
            continue
        else:
            problems.append(f"{where}: '{entry}' after {what}; only '  <name>: text' entries and their indented"
                            f" continuations may follow it")
            break
    return problems


def joined(doc, i):
    """Return doc line i joined with the lines it continues onto (each ending in a backslash), and the index after."""
    line = doc[i]
    i += 1
    while line.endswith("\\") and i < len(doc):
        line = line[:-1] + " " + doc[i].strip()
        i += 1
    return line, i


def arg_keys(args):
    """Return the keys an entry may name for Usage arguments args: each word, with any [ ] or ... around it dropped."""
    return [part for arg in args for part in re.sub(r"[\[\]]|\.\.\.", " ", arg).replace("|", " ").split()]


def check_plain_doc(name, doc, where):
    """Return the problems with doc comment doc of function name, which doesn't call f_return."""
    usage = [i for i, line in enumerate(doc) if line.startswith("Usage:")]
    if len(usage) != 1:
        return [f"{where}: {name} needs a doc comment ending with one '# Usage: {name} [<args>...]' line"]
    u = usage[0]
    usage_line, u_end = joined(doc, u)
    words = usage_line[len("Usage:"):].split()
    if words[:2] == ["f_call", name]:
        # A function passing on what another returns.
        return check_doc(name, doc, None, where)
    problems = []
    if not any(line.strip() for line in doc[:u]):
        problems.append(f"{where}: {name} needs a description before its Usage line")
    if words[:1] != [name]:
        problems.append(f"{where}: {name}'s Usage line must start with '{name}', not '{' '.join(words)}'")
    problems += check_entries(doc[u_end:], arg_keys(words[1:]), "the Usage line", where)
    return problems


def check_doc(name, doc, names, where):
    """Return the problems with doc comment doc of function name, which returns names with f_return (None for one that
    passes on what another returns, whose Usage and Returns lines must only agree)."""
    usage = [i for i, line in enumerate(doc) if line.startswith("Usage:")]
    returns = [i for i, line in enumerate(doc) if line.startswith("Returns:")]
    expected = " ".join(names or ["<names>..."])
    if len(usage) != 1 or len(returns) != 1 or usage[0] > returns[0]:
        return [f"{where}: {name} returns values with f_return, so its doc comment must end with"
                f" '# Usage: f_call {name} {expected} [-- <args>...]' then '# Returns: {expected}'"]
    u, r = usage[0], returns[0]
    usage_line, u_end = joined(doc, u)
    returns_line, r_end = joined(doc, r)
    problems = []
    if not any(line.strip() for line in doc[:u]):
        problems.append(f"{where}: {name} needs a description before its Usage line")

    words = usage_line[len("Usage:"):].split()
    outs, args = words[2:], []
    if "--" in outs:
        args = outs[outs.index("--") + 1:]
        outs = outs[:outs.index("--")]
    if names is None:
        names = outs
    if words[:2] != ["f_call", name] or outs != names:
        problems.append(f"{where}: {name}'s Usage line must start 'f_call {name} {expected}', the names it returns"
                        f" with f_return, not '{' '.join(words)}'")
    returned = returns_line[len("Returns:"):].split()
    if returned != names:
        problems.append(f"{where}: {name}'s Returns line must be 'Returns: {expected}', the names it returns with"
                        f" f_return, not 'Returns: {' '.join(returned)}'")

    problems += check_entries(doc[u_end:r], arg_keys(args), "the Usage line", where)
    problems += check_entries(doc[r_end:], names, "the Returns line", where)
    return problems


def main(paths):
    problems = []
    for path in paths:
        with open(path, encoding="utf-8") as f:
            text = f.read()
        lines = text.split("\n")
        for number, name, doc, names in functions(lines, code_lines(text)):
            where = f"{path}:{number}"
            if path.startswith("install/features/") and FEATURE.match(name):
                continue
            problems += check_doc(name, doc, names, where) if names else check_plain_doc(name, doc, where)
    for problem in problems:
        print(problem, file=sys.stderr)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
