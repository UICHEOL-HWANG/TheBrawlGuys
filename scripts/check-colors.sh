#!/usr/bin/env bash
# Fails if any GDScript/scene/resource outside tokens.gd / debug panel defines colors directly (design.md DS-GOV-01).
set -euo pipefail
cd "$(dirname "$0")/.."
pattern='Color\(|Color8\(|Color\.[A-Z_]+|Color\.(html|from_hsv|from_rgba8|from_string)\(|"#[0-9A-Fa-f]{6}|"#[0-9A-Fa-f]{3}"'
hits=$(grep -rnE --include='*.gd' --include='*.tscn' --include='*.tres' "$pattern" src \
  | grep -vE '^src/ui/theme/tokens\.gd:|^src/debug/config_panel\.gd:|^src/ui/theme/forest_theme\.tres:' || true)
if [ -n "$hits" ]; then
  echo "$hits"
  echo "FAIL: hardcoded colors — use DS tokens"
  exit 1
fi
echo "OK: no hardcoded colors"
