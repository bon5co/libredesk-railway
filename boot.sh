#!/bin/sh
# Libredesk on Railway: install the schema and the System login from variables, upgrade, bind to the injected PORT, then set the
# app's public URL to the Railway domain once the server answers.
set -eu
cd /libredesk

need() { eval "v=\${$1:-}"; [ -n "$v" ] || { echo "[railway-boot] $1 is required" >&2; exit 1; }; }
for n in LIBREDESK_SYSTEM_USER_PASSWORD LIBREDESK_APP__ENCRYPTION_KEY LIBREDESK_DB__HOST LIBREDESK_DB__PASSWORD LIBREDESK_REDIS__ADDRESS; do need "$n"; done

# Railway's healthcheck and edge dial the injected PORT.
PORT="${PORT:-9000}"
export LIBREDESK_APP__SERVER__ADDRESS="0.0.0.0:$PORT"

# The database may still be starting: retry. A fatal here is a connection error, install itself exits 0 when the schema exists.
n=0
until ./libredesk --install --idempotent-install --yes; do
  n=$((n+1)); [ "$n" -le 60 ] || { echo "[railway-boot] database never became ready" >&2; exit 1; }
  sleep 3
done
./libredesk --upgrade --yes

# app.root_url lives in the settings table (default http://localhost:9000), so invite links and mails point at localhost until it is
# changed after login. Set it to the Railway domain through the app's own settings API, and only while it still holds the default,
# so a URL the deployer chose later (custom domain) is never overwritten.
if [ -n "${RAILWAY_PUBLIC_DOMAIN:-}" ]; then
  (
    base="http://127.0.0.1:$PORT"
    jar="$(mktemp)"
    i=0
    until curl -fsS -o /dev/null "$base/health" 2>/dev/null; do
      i=$((i+1)); [ "$i" -le 120 ] || { echo "[railway-boot] server never answered, root_url left alone" >&2; exit 0; }; sleep 2
    done
    login=$(jq -nc --arg v "$LIBREDESK_SYSTEM_USER_PASSWORD" '{email:"System",password:$v}')
    code=$(curl -sS -o /dev/null -w '%{http_code}' -c "$jar" -X POST "$base/api/v1/auth/login" -H 'content-type: application/json' --data "$login" || true)
    [ "$code" = "200" ] || { echo "[railway-boot] System login answered $code, root_url left alone" >&2; exit 0; }
    csrf=$(awk '$6=="csrf_token"{print $7}' "$jar")
    cur=$(curl -fsS -b "$jar" "$base/api/v1/settings/general" | jq -r '.data["app.root_url"] // empty')
    if [ "$cur" = "http://localhost:9000" ]; then
      body=$(curl -fsS -b "$jar" "$base/api/v1/settings/general" | jq -c --arg u "https://$RAILWAY_PUBLIC_DOMAIN" '.data | .["app.root_url"]=$u')
      code=$(curl -sS -o /dev/null -w '%{http_code}' -b "$jar" -X PUT "$base/api/v1/settings/general" -H "X-CSRFTOKEN: $csrf" -H 'content-type: application/json' --data "$body" || true)
      echo "[railway-boot] root_url set to https://$RAILWAY_PUBLIC_DOMAIN, settings API answered $code"
    else
      echo "[railway-boot] root_url already $cur, left alone"
    fi
    rm -f "$jar"
  ) &
fi

exec "$@"
