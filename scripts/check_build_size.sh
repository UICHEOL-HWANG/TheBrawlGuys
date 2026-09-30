#!/usr/bin/env bash
# Build size budget (PRD-NFR-05): mobile apk <= 150 MB; web initial load <= 40 MB.
# Rule: the web budget is what the browser downloads, i.e. the gzip -9 compressed size of
# index.pck + index.wasm (Cloudflare Pages serves them compressed). Raw sizes are printed for reference.
set -euo pipefail
cd "$(dirname "$0")/.."
MB=$((1024 * 1024))
apk=$(stat -f%z build/android/the-brawl-guys.apk)
web_raw=$(( $(stat -f%z build/web/index.pck) + $(stat -f%z build/web/index.wasm) ))
web_gz=$(( $(gzip -9 -c build/web/index.pck | wc -c) + $(gzip -9 -c build/web/index.wasm | wc -c) ))
printf "android apk: %d MB (budget 150)\nweb pck+wasm raw: %d MB (reference)\nweb pck+wasm gzip -9: %d MB (budget 40)\n" \
	$((apk / MB)) $((web_raw / MB)) $((web_gz / MB))
fail=0
[ "$apk" -le $((150 * MB)) ] || { echo "FAIL: apk over budget"; fail=1; }
[ "$web_gz" -le $((40 * MB)) ] || { echo "FAIL: web compressed size over budget"; fail=1; }
[ -d build/ios/TheBrawlGuys.xcodeproj ] || [ -e build/ios/TheBrawlGuys.xcodeproj ] || { echo "FAIL: iOS project missing"; fail=1; }
exit $fail
