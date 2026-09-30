#!/usr/bin/env bash
# Exports the mobile and web builds (PRD-PLT-01/03). iOS is an unsigned Xcode project (context F11).
set -euo pipefail
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."
mkdir -p build/android build/ios build/web
# build/ sits under res://: without .gdignore Godot imports and packs the exports themselves.
touch build/.gdignore
"$GODOT" --headless --path . --import >/dev/null
"$GODOT" --headless --path . --export-debug "Android" build/android/forest-brawl.apk
"$GODOT" --headless --path . --export-debug "iOS" build/ios/ForestBrawl.xcodeproj
"$GODOT" --headless --path . --export-release "Web" build/web/index.html
echo "build_all: android, ios, web exported"
