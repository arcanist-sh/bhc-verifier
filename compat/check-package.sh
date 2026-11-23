#!/usr/bin/env bash
# Build one Hackage package (its newest normal version) with bhc through hx,
# and print one JSON object describing the result on stdout.
#
#   compat/check-package.sh <package> [<work-dir>]
#
# Needs `hx`, `bhc`, `curl` and `jq` on PATH. Progress and the build log go to
# <work-dir>/<package>.log; nothing but the JSON goes to stdout.
#
# Results:
#   pass        the library (and any executables) compiled with bhc
#   fail        a module of the package itself did not compile
#   dependency  a dependency did not compile; `blocked_by` names it
#   unresolved  hx could not resolve or fetch the dependencies
#   builtin     bhc ships its own implementation of the package
#   timeout     the build took longer than BUILD_TIMEOUT seconds
#   error       the package could not be fetched or imported
set -uo pipefail

pkg="$1"
work="${2:-$(mktemp -d)}"
mkdir -p "$work"
log="$work/$pkg.log"
: > "$log"
BUILD_TIMEOUT="${BUILD_TIMEOUT:-900}"
HACKAGE="${HACKAGE:-https://hackage.haskell.org}"
start=$(date +%s)

# Packages bhc implements itself (hx's builtin list): building them from
# Hackage would not test anything.
BUILTINS=" base ghc-prim integer-gmp text bytestring containers transformers mtl array deepseq directory filepath stm "

emit() { # result version blocked_by error
  jq -cn --arg package "$pkg" --arg version "$2" --arg result "$1" \
    --arg blocked_by "$3" --arg error "$4" --argjson seconds "$(( $(date +%s) - start ))" \
    '{package: $package, version: $version, result: $result, seconds: $seconds}
     + (if $blocked_by == "" then {} else {blocked_by: $blocked_by} end)
     + (if $error == "" then {} else {error: $error} end)'
  exit 0
}

# The first line of a message, trimmed and capped, for the table.
short() { head -n 1 | sed -E 's/^[[:space:]]+//' | cut -c1-400; }

version=$(curl -fsS -H 'Accept: application/json' "$HACKAGE/package/$pkg/preferred" 2>>"$log" \
  | jq -r '."normal-version"[0] // empty')
[ -n "$version" ] || emit error "" "" "no released version on Hackage"

case "$BUILTINS" in *" $pkg "*) emit builtin "$version" "" "" ;; esac

cd "$work" || emit error "$version" "" "no work directory"
rm -rf "$pkg-$version"
if ! curl -fsS -o "$pkg.tar.gz" "$HACKAGE/package/$pkg-$version/$pkg-$version.tar.gz" 2>>"$log"; then
  emit error "$version" "" "could not download the package"
fi
tar -xzf "$pkg.tar.gz" 2>>"$log" || emit error "$version" "" "could not unpack the package"
cd "$pkg-$version" || emit error "$version" "" "unexpected archive layout"

if ! hx import --from cabal >>"$log" 2>&1; then
  emit error "$version" "" "$(grep -m1 -E '^error' "$log" | short)"
fi
if ! hx lock >>"$log" 2>&1; then
  emit unresolved "$version" "" "$(grep -m1 -iE 'error|could not' "$log" | short)"
fi

echo "=== hx build --backend bhc --native" >>"$log"
timeout "$BUILD_TIMEOUT" hx build --backend bhc --native >"$work/$pkg.build" 2>&1
status=$?
cat "$work/$pkg.build" >>"$log"
out="$work/$pkg.build"

[ $status -eq 0 ] && emit pass "$version" "" ""
[ $status -eq 124 ] && emit timeout "$version" "" "the build took longer than ${BUILD_TIMEOUT}s"

# A dependency that failed: "<dep>: compilation failed: [build failed for <dep>-<ver>: ]<reasons>"
dep_line=$(grep -m1 -E '^[A-Za-z0-9-]+: compilation failed: ' "$out")
if [ -n "$dep_line" ]; then
  dep="${dep_line%%:*}"
  reason=$(sed -E 's/^[^:]+: compilation failed: (build failed for [^:]+: )?//; s/; .*//' <<<"$dep_line" | cut -c1-400)
  emit dependency "$version" "$dep" "$reason"
fi
if grep -qE 'Could not fetch dependencies|no cached resolution|Could not plan the dependency build' "$out"; then
  emit unresolved "$version" "" "$(grep -m1 -E 'Could not|no cached' "$out" | short)"
fi

# The package's own module: "<Module.Name>: <bhc's message>", else bhc's first error.
reason=$(grep -m1 -E '^[A-Z][A-Za-z0-9_]*(\.[A-Z][A-Za-z0-9_]*)*: ' "$out" | short)
[ -n "$reason" ] || reason=$(grep -m1 -E '^error' "$out" | short)
[ -n "$reason" ] || reason="hx exited with status $status"
emit fail "$version" "" "$reason"
