#!/usr/bin/env bash
# Merge the per-package results (JSON lines from check-package.sh) into the
# index's JSON document on stdout.
#
#   compat/summarize.sh <bhc-version> <hx-revision> <run-url> <results.jsonl>...
#
# Packages keep the order of compat/packages.txt (most depended on first).
set -euo pipefail
bhc_version="$1"; hx_revision="$2"; run_url="$3"; shift 3
order=$(grep -v '^#' "$(dirname "$0")/packages.txt" | jq -R . | jq -sc .)
cat "$@" | jq -s \
  --arg bhc "$bhc_version" --arg hx "$hx_revision" --arg run "$run_url" \
  --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --argjson order "$order" '
  ($order | to_entries | map({key: .value, value: (.key + 1)}) | from_entries) as $rank
  | map(. + {rank: ($rank[.package] // 9999)}) | sort_by(.rank) as $pkgs
  | ($pkgs | map(select(.result != "builtin"))) as $tested
  | {
      generated_at: $now,
      bhc_version: $bhc,
      hx_revision: $hx,
      run_url: $run,
      tested: ($tested | length),
      passing: ($tested | map(select(.result == "pass")) | length),
      counts: ($pkgs | group_by(.result) | map({key: .[0].result, value: length}) | from_entries),
      # The packages whose own failure blocks the most others: a package
      # blocks itself when it fails, and each package that names it.
      blockers: (
        $tested
        | map(if .result == "dependency" then .blocked_by elif .result == "fail" then .package else empty end)
        | group_by(.) | map({package: .[0], blocks: length})
        | sort_by(-.blocks, .package) | .[:20]
        | map(. as $b | . + {error: (($pkgs | map(select(.package == $b.package and .result == "fail")) | .[0].error)
                                    // ($pkgs | map(select(.blocked_by == $b.package)) | .[0].error))})
      ),
      packages: $pkgs
    }'
