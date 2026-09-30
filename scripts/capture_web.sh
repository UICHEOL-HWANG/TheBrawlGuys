#!/usr/bin/env bash
# Captures the web (Compatibility) build with headless Chrome (PRD-PLT-05 toon look check).
# Virtual time never finishes loading the wasm, so a wall-clock --timeout is used instead.
# Needs build/web from scripts/build_all.sh.
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="${1:-dev/done/phase-3/evidence/web-toon.png}"
CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
python3 -m http.server 8060 -d build/web >/dev/null 2>&1 &
SERVER=$!
trap 'kill $SERVER' EXIT
sleep 1
"$CHROME" --headless=new --use-angle=swiftshader --enable-unsafe-swiftshader --window-size=1280,720 \
  --timeout="${TIMEOUT_MS:-120000}" --screenshot="$PWD/$OUT" http://localhost:8060/index.html
echo "capture_web: $OUT"
