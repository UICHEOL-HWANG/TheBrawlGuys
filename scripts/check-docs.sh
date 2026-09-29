#!/usr/bin/env bash
# Traceability checks between docs (docs/README.md R3, R4).
# Optional env: PHASES_FILE overrides docs/PHASES.md (used to test the checker).
set -euo pipefail
cd "$(dirname "$0")/../docs"
phases="${PHASES_FILE:-PHASES.md}"
fail=0

# R4: every DS/GD ID used in PHASES.md is defined in design.md.
for id in $(grep -oE '(DS|GD)-[A-Z0-9]+-[0-9]+' "$phases" | sort -u); do
  grep -q "$id" design.md || { echo "undefined in design.md: $id"; fail=1; }
done

# R3: every PRD ID in PRD.md is covered by the PHASES.md appendix coverage table.
# Only table rows after the "PRD 요구사항 커버리지" heading are read; ranges
# (PRD-A-01~04) and slash lists (PRD-A-01 / 02) are expanded to whole IDs.
covered=$(awk '
  /^#+ .*PRD 요구사항 커버리지/ { on = 1; next }
  on && /^#/ { on = 0 }
  on && /^\|/ { print }
' "$phases" | perl -ne '
  while (/(PRD-[A-Z]+)-(\d+)(?:~(\d+)| \/ (\d+))?/g) {
    my ($a, $lo, $hi, $alt) = ($1, $2, $3, $4);
    if (defined $hi) { printf "%s-%02d\n", $a, $_ for $lo .. $hi }
    else { print "$a-$lo\n"; printf "%s-%02d\n", $a, $alt if defined $alt }
  }' | sort -u)
if [ -z "$covered" ]; then
  echo "no PRD coverage table found in $phases (heading 'PRD 요구사항 커버리지')"
  exit 1
fi
required=$(grep -oE '^\| PRD-[A-Z]+-[0-9]+' PRD.md | tr -d '| ' | sort -u || true)
if [ -z "$required" ]; then
  echo "no PRD IDs found in PRD.md (expected table rows '| PRD-AREA-NN')"
  exit 1
fi
for id in $required; do
  grep -qxF "$id" <<<"$covered" || { echo "not assigned to a phase: $id"; fail=1; }
done

if [ "$fail" -ne 0 ]; then exit 1; fi
echo "OK: docs traceability"
