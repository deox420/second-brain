#!/usr/bin/env bash
# smoke-cron.sh — test de humo end-to-end del recolector de noticias.
# Levanta un servidor HTTP local con un feed RSS de prueba, ejecuta
# bin/cron-news-ingest.sh con NO_CLAUDE=1 en un vault temporal y comprueba
# que se escribe exactamente 1 item con el slug normalizado.
# Uso: bash tests/smoke-cron.sh   (exit 0 = OK)

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"
PORT=8799
trap 'kill "$SERVER_PID" 2>/dev/null || true; rm -rf "$T"' EXIT

mkdir -p "$T/vault/bin" "$T/vault/.vault-meta" "$T/www"
cp "$REPO/bin/cron-news-ingest.sh" "$REPO/bin/parse-feed.py" "$T/vault/bin/"

FRESH="$(date -R 2>/dev/null || date -u '+%a, %d %b %Y %H:%M:%S +0000')"
cat > "$T/www/rss.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0"><channel>
<item><title>España: prueba de humo del cron</title>
<link>https://ejemplo.es/humo</link>
<pubDate>$FRESH</pubDate>
<description>Item de prueba.</description></item>
</channel></rss>
EOF

printf 'Humo|http://127.0.0.1:%s/rss.xml\n' "$PORT" > "$T/feeds.txt"
(cd "$T/www" && python3 -m http.server "$PORT" >/dev/null 2>&1) &
SERVER_PID=$!
sleep 1

cd "$T/vault"
NO_CLAUDE=1 FEEDS_FILE="$T/feeds.txt" bash bin/cron-news-ingest.sh

n="$(find .raw/news -type f -name '*.md' | wc -l | tr -d ' ')"
[ "$n" = "1" ] || { echo "FALLO: se esperaba 1 item, hay $n" >&2; exit 1; }
find .raw/news -name 'espana-prueba-de-humo-del-cron-*.md' | grep -q . \
  || { echo "FALLO: slug sin normalizar (tildes rotas)" >&2; exit 1; }

echo "Smoke test OK: 1 item escrito con slug correcto."
