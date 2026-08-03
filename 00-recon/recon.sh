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

echo; echo "### INFO-06  Routes ###"
for p in / /projects /forum /newsletter /agenda /login /logout /redirect \
         /admin /staff /backup /internal/config /api/grades /register; do
  echo "$p -> $(curl -s -o /dev/null -w '%{http_code}' "$BASE$p")"
done

echo; echo "### PocketBase ($PB) ###"
curl -s "$PB/api/health"; echo
for p in /_/ /api/collections; do
  echo "$p -> $(curl -s -o /dev/null -w '%{http_code}' "$PB$p")"
done
