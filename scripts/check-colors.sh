#!/usr/bin/env bash
# Fails if any GDScript outside tokens.gd / debug panel defines colors directly (design.md DS-GOV-01).
set -euo pipefail
cd "$(dirname "$0")/.."
pattern='Color\(|Color\.[A-Z_]+|"#[0-9A-Fa-f]{6}'
hits=$(grep -rnE --include='*.gd' "$pattern" src \
  | grep -vE '^src/ui/theme/tokens\.gd:|^src/debug/config_panel\.gd:' || true)
if [ -n "$hits" ]; then
  echo "$hits"
  echo "FAIL: hardcoded colors — use DS tokens"
  exit 1
fi
echo "OK: no hardcoded colors"
