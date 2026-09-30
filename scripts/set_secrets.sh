#!/usr/bin/env bash
# Prompt for public client keys and write them to config/secrets.local.cfg (gitignored).
# Input is hidden and never echoed. Empty input keeps the current value.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FILE="$ROOT/config/secrets.local.cfg"
mkdir -p "$ROOT/config"

current() { # section key
	[ -f "$FILE" ] || return 0
	awk -v s="[$1]" -v k="$2" '
		$0 == s { in_s = 1; next }
		/^\[/ { in_s = 0 }
		in_s && index($0, k "=") == 1 { v = substr($0, length(k) + 2); gsub(/^"|"$/, "", v); print v; exit }
	' "$FILE"
}

ask() { # label section key secret(0/1)
	local label="$1" section="$2" key="$3" secret="$4" old value
	old="$(current "$section" "$key")"
	if [ -n "$old" ]; then label="$label (Enter = 기존 값 유지)"; fi
	if [ "$secret" = 1 ]; then
		read -r -s -p "$label: " value; echo >&2
	else
		read -r -p "$label: " value
	fi
	value="${value//[[:space:]]/}"
	[ -z "$value" ] && value="$old"
	printf '%s' "$value"
}

echo "== TheBrawlGuys 클라이언트 키 입력 (공개 키만, service_role 금지) =="
AMP="$(ask 'Amplitude API Key' amplitude api_key 1)"
SB_URL="$(ask 'Supabase Project URL (https://xxxx.supabase.co)' supabase url 0)"
SB_ANON="$(ask 'Supabase anon/publishable key' supabase anon_key 1)"
REDIRECT="$(current auth redirect_web)"
PORT="$(current auth loopback_port)"; PORT="${PORT:-54321}"

if [[ -n "$SB_URL" && ! "$SB_URL" =~ ^https://[a-z0-9-]+\.supabase\.co/?$ ]]; then
	echo "경고: Supabase URL 형식이 예상과 다릅니다 ($SB_URL)" >&2
fi
if [[ "$SB_ANON" == *service_role* || "$SB_ANON" == sb_secret_* ]]; then
	echo "오류: service_role/secret 키는 넣으면 안 됩니다. anon/publishable 키를 넣어주세요." >&2
	exit 1
fi
SB_URL="${SB_URL%/}"

umask 077
cat > "$FILE" <<EOF
; Public client keys only. NEVER put the Supabase service_role key here.
; Written by scripts/set_secrets.sh

[amplitude]
api_key="$AMP"

[supabase]
url="$SB_URL"
anon_key="$SB_ANON"

[auth]
redirect_web="$REDIRECT"
loopback_port=$PORT
EOF

mask() { local v="$1"; [ -z "$v" ] && { echo "(비어 있음)"; return; }; echo "${v:0:4}…${v: -4} (${#v}자)"; }
echo
echo "저장됨: $FILE"
echo "  amplitude.api_key  $(mask "$AMP")"
echo "  supabase.url       ${SB_URL:-(비어 있음)}"
echo "  supabase.anon_key  $(mask "$SB_ANON")"
