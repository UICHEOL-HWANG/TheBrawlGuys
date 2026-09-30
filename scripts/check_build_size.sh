#!/usr/bin/env bash
# Build size budget (PRD-NFR-05): mobile <= 150 MB, web initial load (pck + wasm) <= 40 MB.
set -euo pipefail
cd "$(dirname "$0")/.."
MB=$((1024 * 1024))
apk=$(stat -f%z build/android/forest-brawl.apk)
web=$(( $(stat -f%z build/web/index.pck) + $(stat -f%z build/web/index.wasm) ))
printf "android apk: %d MB (budget 150)\nweb pck+wasm: %d MB (budget 40)\n" $((apk / MB)) $((web / MB))
fail=0
[ "$apk" -le $((150 * MB)) ] || { echo "FAIL: apk over budget"; fail=1; }
[ "$web" -le $((40 * MB)) ] || { echo "FAIL: web over budget"; fail=1; }
[ -d build/ios/ForestBrawl.xcodeproj ] || [ -e build/ios/ForestBrawl.xcodeproj ] || { echo "FAIL: iOS project missing"; fail=1; }
exit $fail
