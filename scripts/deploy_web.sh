#!/usr/bin/env bash
# Export the Web build and deploy it to Vercel (project "thebrawlguys", domain thebrawlguys.cloud).
# Vercel cannot run Godot, so the build happens here and only the static output is uploaded.
# Usage: scripts/deploy_web.sh [--preview]   (default: production)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/build/web"
PROJECT="thebrawlguys"
TARGET="--prod"
[ "${1:-}" = "--preview" ] && TARGET=""

if [ ! -f "$ROOT/config/secrets.local.cfg" ]; then
	echo "config/secrets.local.cfg 없음 — scripts/set_secrets.sh 먼저 실행" >&2
	exit 1
fi

mkdir -p "$OUT"
touch "$ROOT/build/.gdignore"
godot --headless --path "$ROOT" --export-release "Web" "$OUT/index.html"
rm -f "$OUT"/*.import
cp "$ROOT/deploy/vercel.json" "$OUT/vercel.json"
cp "$ROOT/deploy/vercelignore" "$OUT/.vercelignore"

cd "$OUT"
if [ ! -f .vercel/project.json ]; then
	npx --yes vercel link --yes --project "$PROJECT"
fi
npx --yes vercel deploy $TARGET --yes
