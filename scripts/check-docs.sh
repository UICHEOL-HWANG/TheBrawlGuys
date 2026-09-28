#!/usr/bin/env bash
# Traceability checks between docs (docs/README.md R3, R4).
set -euo pipefail
cd "$(dirname "$0")/../docs"
fail=0
for id in $(grep -oE '(DS|GD)-[A-Z0-9]+-[0-9]+' PHASES.md | sort -u); do
  grep -q "$id" design.md || { echo "undefined in design.md: $id"; fail=1; }
done
for id in $(grep -oE '^\| PRD-[A-Z]+-[0-9]+' PRD.md | tr -d '| '); do
  area=${id%-*}
  grep -qE "$id|$area-[0-9]+~" PHASES.md || { echo "not assigned to a phase: $id"; fail=1; }
done
if [ "$fail" -ne 0 ]; then exit 1; fi
echo "OK: docs traceability"
