#!/usr/bin/env python3
"""Rank Hackage packages by how many other packages depend on them.

Reads Hackage's package index (01-index.tar or .tar.gz), takes the newest
release of every package, and counts, for each package name, how many
packages list it in a build-depends field. Prints "<count> <name>" lines,
most depended-on first.

    compat/rank-packages.py <01-index.tar.gz> [limit]

The count is approximate (conditionals are not evaluated; every
build-depends field in the .cabal file counts), which is enough to rank.
"""
import re
import sys
import tarfile
from collections import Counter

NAME = re.compile(r"[A-Za-z][A-Za-z0-9-]*")
FIELD = re.compile(r"^\s*build-depends\s*:(.*)$", re.IGNORECASE)


def version_key(v):
    return tuple(int(p) if p.isdigit() else 0 for p in v.split("."))


def depends(cabal):
    """Package names in the build-depends fields of a .cabal file."""
    names = set()
    lines = cabal.splitlines()
    i = 0
    while i < len(lines):
        m = FIELD.match(lines[i])
        if not m:
            i += 1
            continue
        indent = len(lines[i]) - len(lines[i].lstrip())
        text = [m.group(1)]
        i += 1
        # Continuation lines are indented deeper than the field name.
        while i < len(lines) and (
            not lines[i].strip() or len(lines[i]) - len(lines[i].lstrip()) > indent
        ):
            text.append(lines[i])
            i += 1
        body = re.sub(r"--.*", "", " ".join(text))
        for item in body.split(","):
            m2 = NAME.search(item)
            if m2:
                names.add(m2.group(0).split(":")[0])
    return names


def main():
    path = sys.argv[1]
    limit = int(sys.argv[2]) if len(sys.argv) > 2 else None
    newest = {}  # package -> (version, member name)
    with tarfile.open(path) as tar:
        for member in tar:
            parts = member.name.split("/")
            if len(parts) != 3 or not parts[2].endswith(".cabal"):
                continue
            pkg, ver = parts[0], parts[1]
            if pkg not in newest or version_key(ver) >= version_key(newest[pkg][0]):
                newest[pkg] = (ver, member.name)
        wanted = {name for _, name in newest.values()}
    counts = Counter()
    with tarfile.open(path) as tar:
        for member in tar:
            if member.name not in wanted:
                continue
            pkg = member.name.split("/")[0]
            text = tar.extractfile(member).read().decode("utf-8", "replace")
            for dep in depends(text) - {pkg}:
                counts[dep] += 1
    ranked = [(n, p) for p, n in counts.items() if p in newest]
    ranked.sort(key=lambda t: (-t[0], t[1]))
    for n, p in ranked[:limit]:
        print(n, p)


if __name__ == "__main__":
    main()
