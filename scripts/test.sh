#!/usr/bin/env bash
# Runs GUT unit tests headlessly. Extra args are passed to GUT (e.g. -gselect=test_world).
set -euo pipefail
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."
"$GODOT" --headless --path . --import >/dev/null
"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit,res://tests/replay -ginclude_subdirs -gexit "$@"
