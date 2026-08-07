#!/usr/bin/env bash
#
# Darkly — reconnaissance (WSTG Information Gathering). Own script, curl only.
# Usage: ./recon.sh [BASE_URL] [PB_URL]
#        defaults: http://localhost:4942 (web app), http://localhost:8090 (PocketBase)
#
BASE="${1:-http://localhost:4942}"
PB="${2:-http://localhost:8090}"

echo "### INFO-02  Fingerprint web server ###"
curl -s -D - -o /dev/null "$BASE/"      # GET headers (HEAD returns 405); shows server + versions + x-*
curl -s -X POST "$BASE/newsletter" -H 'Content-Type: application/json' -d '{}'; echo  # 422 array detail -> FastAPI + leaks Pydantic ver

echo; echo "### INFO-03  Metafiles ###"
curl -s "$BASE/robots.txt"
curl -s "$BASE/sitemap.xml"

echo; echo "### INFO-05  Page content ###"
for p in / /projects /forum /newsletter /login /staff; do
  echo "--- comments on $p ---"; curl -s "$BASE$p" | grep -oE '<!--.*-->'
done
curl -s "$BASE/" | grep -oiE 'src="[^"]*\.js"'   # external JS (review console_eggs.js by hand)

echo; echo "### INFO-06  Entry points ###"
echo "-- routes (code / redirect) --"
for p in / /projects /forum /newsletter /agenda /login /logout /redirect \
         /admin /staff /backup /internal/config /api/grades /projects/download \
         /api/docs-internal /api/profile /api/telemetry/heartbeat /register; do
  h=$(curl -s -D - -o /dev/null "$BASE$p")
  code=$(printf '%s' "$h" | head -1 | awk '{print $2}')
  loc=$(printf '%s' "$h" | awk 'tolower($1)=="location:"{print $2}' | tr -d '\r')
  allow=$(printf '%s' "$h" | awk 'tolower($1)=="allow:"{sub(/^[^ ]* /,"");print}' | tr -d '\r')
  echo "$p -> ${code:-000}${loc:+ -> $loc}${allow:+  [Allow: $allow]}"
done
echo "-- form fields (POST/GET input) --"
for p in /login /newsletter /forum; do
  echo "  $p:"
  curl -s "$BASE$p" | grep -oiE '<form[^>]*>|<input[^>]*>|<textarea[^>]*>' \
    | grep -oiE 'method="[^"]*"|action="[^"]*"|name="[^"]*"' | sed 's/^/    /'
done
echo "-- custom headers + session cookie --"
curl -s -D - -o /dev/null "$BASE/" | grep -iE '^x-' | tr -d '\r'
curl -s -D - -o /dev/null "$BASE/logout" | grep -i '^set-cookie' | tr -d '\r'

echo; echo "### PocketBase ($PB) ###"
curl -s "$PB/api/health"; echo
for p in /_/ /api/collections; do
  echo "$p -> $(curl -s -o /dev/null -w '%{http_code}' "$PB$p")"
done
