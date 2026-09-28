#!/usr/bin/env bash
# Fails if src/sim references engine nodes, rendering, physics or input (PRD §5.2-1).
set -euo pipefail
cd "$(dirname "$0")/.."
pattern='extends Node|Node2D|Node3D|SceneTree|get_tree|RenderingServer|PhysicsServer|DisplayServer|InputEvent|(^|[^A-Za-z])Input\.'
if grep -rnE "$pattern" src/sim | grep -vE ':[[:space:]]*(#|##)'; then
  echo "FAIL: sim purity violation"
  exit 1
fi
echo "OK: sim purity"
