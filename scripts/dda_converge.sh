#!/usr/bin/env bash
# DDA convergence grid (PRD-BOT-06) in parallel: player d x {on, off}, one headless Godot each.
# Usage: scripts/dda_converge.sh [matches=100] [out=analysis/reports/dda_converge.csv] [player d...]
set -euo pipefail
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."
matches="${1:-100}"
out="${2:-analysis/reports/dda_converge.csv}"
shift $(( $# > 2 ? 2 : $# ))
points=("$@")
if [ ${#points[@]} -eq 0 ]; then points=(0.1 0.3 0.5 0.7 0.9); fi
tmp="$(mktemp -d)"
for p in "${points[@]}"; do
  for v in on off; do
    "$GODOT" --headless --path . -s res://scripts/dda_converge.gd -- \
      --player-d="$p" --variant="$v" --matches="$matches" --out="$tmp/$p-$v.csv" >/dev/null 2>&1 &
  done
done
wait
head -1 "$tmp/${points[0]}-on.csv" > "$out"
for p in "${points[@]}"; do tail -n +2 "$tmp/$p-on.csv"; tail -n +2 "$tmp/$p-off.csv"; done >> "$out"
rm -rf "$tmp"
cat "$out"
