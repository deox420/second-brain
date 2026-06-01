#!/usr/bin/env bash
# cron-news-ingest.sh — recolector de noticias del segundo cerebro (capa propia).
#
# Qué hace:
#   1. Lee las fuentes RSS de bin/news-feeds.txt.
#   2. Descarga cada feed y vuelca los items recientes (últimas ~28h) como archivos
#      Markdown crudos en .raw/news/YYYY-MM-DD/ (uno por item, con frontmatter).
#   3. Invoca `claude -p "Procesa las noticias de hoy"` en el vault, que dispara la
#      skill wiki-news (ver skills/wiki-news/SKILL.md y CLAUDE.md §4).
#
# Este script NO escribe en wiki/: solo deja material crudo y llama a Claude. El filtrado,
# resumen, deduplicado y la nota diaria los hace la skill wiki-news.
#
# Requisitos: bash, curl, python3 (xml stdlib). 'claude' (Claude Code CLI) en el PATH.
#
# Uso manual:   bash bin/cron-news-ingest.sh
# Solo recolectar (sin llamar a Claude):   NO_CLAUDE=1 bash bin/cron-news-ingest.sh
#
# Ejemplo de crontab (todos los días a las 07:30, y el lint semanal los domingos a las 08:00):
#   30 7 * * *  cd /ruta/al/vault && /usr/bin/bash bin/cron-news-ingest.sh >> .vault-meta/news-cron.log 2>&1
#   0  8 * * 0  cd /ruta/al/vault && claude -p "Ejecuta el lint semanal del vault" >> .vault-meta/lint-cron.log 2>&1

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAULT="$(dirname "$SCRIPT_DIR")"
FEEDS="$VAULT/bin/news-feeds.txt"
DATE="$(date +%Y-%m-%d)"
RAW_DIR="$VAULT/.raw/news/$DATE"

cd "$VAULT"

if [ ! -f "$FEEDS" ]; then
  echo "No existe $FEEDS. Crea la lista de feeds (ver CLAUDE.md §8)." >&2
  exit 1
fi

# Feeds activos (ignora comentarios y líneas vacías).
mapfile -t LINES < <(grep -vE '^\s*(#|$)' "$FEEDS" || true)
if [ "${#LINES[@]}" -eq 0 ]; then
  echo "No hay feeds activos en $FEEDS. Descomenta o añade alguno (nombre|url)." >&2
  exit 1
fi

mkdir -p "$RAW_DIR"
echo "Recolectando noticias en $RAW_DIR ($(date '+%H:%M'))"

count=0
for line in "${LINES[@]}"; do
  name="${line%%|*}"
  url="${line#*|}"
  name="$(echo "$name" | sed 's/^ *//;s/ *$//')"
  url="$(echo "$url" | sed 's/^ *//;s/ *$//')"
  [ -z "$url" ] && continue

  echo "  · $name"
  xml="$(curl -fsSL --max-time 30 -A 'second-brain-news/1.0' "$url" 2>/dev/null || true)"
  [ -z "$xml" ] && { echo "    (sin respuesta, se omite)"; continue; }

  # Parseo de RSS/Atom con python3 (stdlib). Emite un archivo por item reciente.
  printf '%s' "$xml" | FEED_NAME="$name" RAW_DIR="$RAW_DIR" python3 - "$DATE" <<'PY'
import os, sys, re, html, hashlib, datetime as dt
import xml.etree.ElementTree as ET

date_str = sys.argv[1]
feed = os.environ.get("FEED_NAME", "fuente")
raw_dir = os.environ["RAW_DIR"]
data = sys.stdin.read()

def strip_ns(tag): return tag.split('}')[-1].lower()
def text(el): return (el.text or "").strip() if el is not None else ""

try:
    root = ET.fromstring(data)
except ET.ParseError:
    sys.exit(0)

# Recolecta items (RSS <item>) y entries (Atom <entry>).
items = [e for e in root.iter() if strip_ns(e.tag) in ("item", "entry")]

now = dt.datetime.now(dt.timezone.utc)
window = dt.timedelta(hours=28)
written = 0

def parse_date(s):
    s = s.strip()
    for fmt in ("%a, %d %b %Y %H:%M:%S %z", "%a, %d %b %Y %H:%M:%S %Z",
                "%Y-%m-%dT%H:%M:%S%z", "%Y-%m-%dT%H:%M:%SZ", "%Y-%m-%d"):
        try:
            d = dt.datetime.strptime(s.replace("GMT", "+0000"), fmt)
            if d.tzinfo is None: d = d.replace(tzinfo=dt.timezone.utc)
            return d
        except ValueError:
            continue
    return None

for it in items:
    title = link = pub = desc = ""
    for ch in it:
        t = strip_ns(ch.tag)
        if t == "title" and not title: title = text(ch)
        elif t == "link" and not link:
            link = text(ch) or ch.attrib.get("href", "")
        elif t in ("pubdate", "published", "updated", "date") and not pub:
            pub = text(ch)
        elif t in ("description", "summary", "content") and not desc:
            desc = text(ch)
    if not title:
        continue
    # Filtro temporal: si hay fecha y es vieja, se descarta; sin fecha, se acepta.
    d = parse_date(pub) if pub else None
    if d is not None and (now - d) > window:
        continue
    desc = re.sub(r"<[^>]+>", " ", html.unescape(desc))
    desc = re.sub(r"\s+", " ", desc).strip()[:1200]
    slug = re.sub(r"[^a-z0-9]+", "-", title.lower()).strip("-")[:60] or "item"
    h = hashlib.sha1((link or title).encode()).hexdigest()[:8]
    path = os.path.join(raw_dir, f"{slug}-{h}.md")
    if os.path.exists(path):
        continue
    with open(path, "w", encoding="utf-8") as f:
        f.write("---\n")
        f.write(f'titulo: "{title.replace(chr(34), chr(39))}"\n')
        f.write(f"fuente: {feed}\n")
        f.write(f"url: {link}\n")
        f.write(f"fecha: {date_str}\n")
        f.write(f"publicado: {pub}\n")
        f.write("---\n\n")
        f.write(f"# {title}\n\n{desc}\n")
    written += 1

print(f"    {written} items")
PY
  count=$((count + 1))
done

n_items="$(find "$RAW_DIR" -type f -name '*.md' | wc -l | tr -d ' ')"
echo "Feeds procesados: $count | items crudos: $n_items"

if [ "${NO_CLAUDE:-0}" = "1" ]; then
  echo "NO_CLAUDE=1: no se invoca Claude. Lanza /news manualmente cuando quieras."
  exit 0
fi

if ! command -v claude >/dev/null 2>&1; then
  echo "Aviso: 'claude' no está en el PATH. Items crudos listos en $RAW_DIR." >&2
  echo "Procesa luego con:  claude -p \"Procesa las noticias de hoy\"" >&2
  exit 0
fi

if [ "$n_items" -eq 0 ]; then
  echo "Sin items nuevos hoy; no se invoca a Claude."
  exit 0
fi

echo "Invocando Claude para procesar el radar del día..."
claude -p "Procesa las noticias de hoy"
