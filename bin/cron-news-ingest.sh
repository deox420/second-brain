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
# Requisitos: bash >= 4 (mapfile), curl, python3 (stdlib). 'claude' (Claude Code CLI) en el PATH.
# El parseo RSS/Atom vive en bin/parse-feed.py (testeable de forma aislada).
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
# Registro persistente de items vistos: evita duplicados entre días consecutivos
# (la ventana de frescura de ~28h solapa con el día anterior). Lo gestiona parse-feed.py.
SEEN_FILE="$VAULT/.vault-meta/news-seen.txt"

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

  # Parseo de RSS/Atom con el parser externo (bin/parse-feed.py).
  # NOTA: no usar heredoc aquí — pisaría el pipe de stdin (bug histórico B1).
  printf '%s' "$xml" | FEED_NAME="$name" RAW_DIR="$RAW_DIR" SEEN_FILE="$SEEN_FILE" python3 "$VAULT/bin/parse-feed.py" "$DATE"
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
