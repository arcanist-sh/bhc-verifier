#!/usr/bin/env bash
# Regenerate compat/packages.txt: the packages most depended on across
# Hackage, counted from Hackage's package index by compat/rank-packages.py.
#
#   compat/select-packages.sh [count] [index]
#
# count defaults to 250; index is a local 01-index.tar.gz, downloaded from
# Hackage (about 140 MB) when not given.
set -euo pipefail
count="${1:-250}"
index="${2:-}"
cd "$(dirname "$0")"
if [ -z "$index" ]; then
  index="$(mktemp -d)/01-index.tar.gz"
  curl -fsSL -o "$index" https://hackage.haskell.org/01-index.tar.gz
fi
{
  echo "# The $count packages most depended on across Hackage (direct reverse"
  echo "# dependencies of each package's newest release), from Hackage's index on"
  echo "# $(date -u +%Y-%m-%d). Regenerate with compat/select-packages.sh."
  python3 -I rank-packages.py "$index" "$count" | awk '{print $2}'
} > packages.txt
echo "wrote $(grep -cv '^#' packages.txt) packages to compat/packages.txt"
