#!/usr/bin/env bash
# Fails if src/sim references engine nodes, rendering, physics, input, or determinism
# breakers (global RNG, clocks, resource loading) (PRD §5.2-1).
set -euo pipefail
cd "$(dirname "$0")/.."
pattern='extends Node|\bNode\b|Node2D|Node3D|SceneTree|get_tree|get_node|RenderingServer|PhysicsServer|DisplayServer|InputEvent|(^|[^A-Za-z])Input\.'
pattern+='|(^|[^._A-Za-z0-9])rand(i|f)(_range)?\(|randomize\(|\bTime\.|\bOS\.|\bEngine\.|(^|[^._A-Za-z0-9])load\(|ResourceLoader'
fail=0
if grep -rnE "$pattern" src/sim | grep -vE ':[[:space:]]*(#|##)'; then
  fail=1
fi
# RandomNumberGenerator may only be constructed in world.gd (the seeded sim RNG).
if grep -rnE 'RandomNumberGenerator\.new\(\)' src/sim | grep -v '^src/sim/world\.gd:' | grep -vE ':[[:space:]]*(#|##)'; then
  fail=1
fi
if [ "$fail" -ne 0 ]; then
  echo "FAIL: sim purity violation"
  exit 1
fi
echo "OK: sim purity"
