#!/usr/bin/env bash
# Fails if a secret could ship (platform A1, context P3):
#  - tracked text files contain a JWT-looking token or a Supabase secret key (sb_secret_...)
#  - tracked non-doc files name the Supabase service role
#  - the local, exported config/secrets.local.cfg holds a service-role / secret key
# The role name is assembled at runtime so this script never contains it literally.
set -euo pipefail
cd "$(dirname "$0")/.."
fail=0
role='service''_role'
jwt='eyJ[A-Za-z0-9_-]{8,}\.eyJ[A-Za-z0-9_-]{8,}'
secret_key='sb_secret_[A-Za-z0-9_-]+'

if git ls-files -z | xargs -0 grep -InE "$jwt|$secret_key" --; then
  echo "FAIL: token-looking string in a tracked file"
  fail=1
fi
if git ls-files -z -- ':!*.md' ':!scripts/set_secrets.sh' | xargs -0 grep -InF "$role" --; then
  echo "FAIL: the service role is named in a tracked file"
  fail=1
fi

# The local file is gitignored but exported: it must only hold public client keys.
local_file="config/secrets.local.cfg"
if [ -f "$local_file" ]; then
  values=$(grep -vE '^[[:space:]]*[;#]' "$local_file" || true)  # comments may name the rule
  if grep -qE "$secret_key|$role" <<<"$values"; then
    echo "FAIL: $local_file holds a secret key"
    fail=1
  fi
  for token in $(grep -oE "$jwt"'\.[A-Za-z0-9_-]*' <<<"$values" || true); do
    payload=$(printf '%s' "$token" | cut -d. -f2 | tr '_-' '/+')
    while [ $(( ${#payload} % 4 )) -ne 0 ]; do payload="$payload="; done
    if printf '%s' "$payload" | base64 -d 2>/dev/null | grep -q "$role"; then
      echo "FAIL: $local_file holds a service-role JWT"
      fail=1
    fi
  done
fi

if [ "$fail" -ne 0 ]; then exit 1; fi
echo "OK: no secrets"
