#!/usr/bin/env bash
# smoke-cron.sh — test de humo end-to-end del recolector de noticias.
#
# Levanta un servidor HTTP local con fixtures RSS/Atom frescas, monta un vault
# temporal con los scripts reales y ejecuta bin/cron-news-ingest.sh con NO_CLAUDE=1
# dos veces (la segunda no debe escribir nada nuevo). Este patrón es el que
# habría detectado el bug B1 (heredoc pisando el pipe → 0 items siempre).
#
# Uso: bash tests/smoke-cron.sh

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
PORT="${SMOKE_PORT:-8941}"
SRV_PID=""
trap '[ -n "$SRV_PID" ] && kill "$SRV_PID" 2>/dev/null; rm -rf "$WORK"' EXIT

# Fixtures con fechas frescas generadas al vuelo.
mkdir -p "$WORK/web" "$WORK/vault/bin" "$WORK/vault/.vault-meta"
python3 - "$WORK/web" <<'EOF'
import sys, datetime as dt
from email.utils import format_datetime
web = sys.argv[1]
now = dt.datetime.now(dt.timezone.utc)
fresh = format_datetime(now - dt.timedelta(hours=2))
old = format_datetime(now - dt.timedelta(hours=40))
iso = (now - dt.timedelta(hours=3)).strftime("%Y-%m-%dT%H:%M:%S.123+0000")
open(f"{web}/rss.xml", "w").write(f'''<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0"><channel><title>Test</title>
<item><title>España aprueba la ley de año nuevo</title><link>https://x.es/a</link>
<pubDate>{fresh}</pubDate><description>fresca</description></item>
<item><title>Vieja</title><link>https://x.es/v</link>
<pubDate>{old}</pubDate><description>antigua</description></item>
</channel></rss>''')
open(f"{web}/atom.xml", "w").write(f'''<?xml version="1.0"?>
<feed xmlns="http://www.w3.org/2005/Atom"><title>t</title>
<entry><title>Entrada Atom</title>
<link rel="self" href="https://feed.example/self.xml"/>
<link rel="alternate" href="https://x.es/articulo"/>
<published>{iso}</published><summary>s</summary></entry></feed>''')
EOF

cp "$REPO/bin/cron-news-ingest.sh" "$REPO/bin/parse-feed.py" "$WORK/vault/bin/"
printf 'RSS|http://127.0.0.1:%s/rss.xml\nAtom|http://127.0.0.1:%s/atom.xml\n' "$PORT" "$PORT" \
  > "$WORK/vault/bin/news-feeds.txt"

(cd "$WORK/web" && exec python3 -m http.server "$PORT" >/dev/null 2>&1) &
SRV_PID=$!
sleep 1

echo "== Pasada 1 (debe escribir 2 items) =="
out1="$(NO_CLAUDE=1 bash "$WORK/vault/bin/cron-news-ingest.sh")"
echo "$out1"
echo "$out1" | grep -q "items nuevos: 2" || { echo "FALLO: se esperaban 2 items nuevos"; exit 1; }
echo "$out1" | grep -q "antiguos: 1" || { echo "FALLO: se esperaba 1 item antiguo descartado"; exit 1; }

DATE="$(date +%Y-%m-%d)"
ls "$WORK/vault/.raw/news/$DATE/" | grep -q '^espana-aprueba-la-ley-de-ano-nuevo-' \
  || { echo "FALLO: slug sin normalizar tildes"; exit 1; }
grep -q 'url: "https://x.es/articulo"' "$WORK/vault/.raw/news/$DATE/"entrada-atom-*.md \
  || { echo "FALLO: el link Atom no es el rel=alternate"; exit 1; }

echo "== Pasada 2 (no debe duplicar) =="
out2="$(NO_CLAUDE=1 bash "$WORK/vault/bin/cron-news-ingest.sh")"
echo "$out2"
echo "$out2" | grep -q "items nuevos: 0" || { echo "FALLO: la segunda pasada duplicó items"; exit 1; }
echo "$out2" | grep -q "duplicados: 2" || { echo "FALLO: contador de duplicados incorrecto"; exit 1; }

echo "✓ Smoke test del cron OK"
