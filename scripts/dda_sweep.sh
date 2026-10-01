#!/usr/bin/env bash
# Difficulty dial sweep (PRD-BOT-03) in parallel: one headless Godot per d point, merged CSV.
# Usage: scripts/dda_sweep.sh [matches=200] [out=analysis/reports/dda_sweep.csv] [points...]
set -euo pipefail
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."
matches="${1:-200}"
out="${2:-analysis/reports/dda_sweep.csv}"
shift $(( $# > 2 ? 2 : $# ))
points=("$@")
if [ ${#points[@]} -eq 0 ]; then points=(0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1); fi
tmp="$(mktemp -d)"
for p in "${points[@]}"; do
  "$GODOT" --headless --path . -s res://scripts/dda_sweep.gd -- \
    --points="$p" --matches="$matches" --out="$tmp/$p.csv" >/dev/null 2>&1 &
done
wait
head -1 "$tmp/${points[0]}.csv" > "$out"
for p in "${points[@]}"; do tail -n +2 "$tmp/$p.csv"; done | sort -t, -k1,1n >> "$out"
rm -rf "$tmp"
cat "$out"
