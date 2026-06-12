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
# Requisitos: bash >= 3.2 (compatible con el bash de macOS), curl, python3 (stdlib).
# 'claude' (Claude Code CLI) en el PATH para el paso 3.
# El parseo RSS/Atom vive en bin/parse-feed.py (testeable de forma aislada).
#
# Permisos en headless: la invocación usa --permission-mode acceptEdits y se apoya en la
# allowlist de .claude/settings.json (escritura solo en wiki/ y .vault-meta/, limpieza de
# crudos vía scripts/clean-raw-news.sh). Ver CLAUDE.md §4.
#
# Uso manual:                              bash bin/cron-news-ingest.sh
# Solo recolectar (sin llamar a Claude):   NO_CLAUDE=1 bash bin/cron-news-ingest.sh
# Modelo del radar (barato por defecto):   NEWS_MODEL=haiku  (exporta otro si lo prefieres)
#
# Ejemplo de crontab (todos los días a las 07:30, y el lint semanal los domingos a las 08:00):
#   30 7 * * *  cd /ruta/al/vault && bash bin/cron-news-ingest.sh >> .vault-meta/news-cron.log 2>&1
#   0  8 * * 0  cd /ruta/al/vault && claude -p "Ejecuta el lint semanal del vault" --permission-mode acceptEdits >> .vault-meta/lint-cron.log 2>&1

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAULT="$(dirname "$SCRIPT_DIR")"
FEEDS="$VAULT/bin/news-feeds.txt"
DATE="$(date +%Y-%m-%d)"
RAW_DIR="$VAULT/.raw/news/$DATE"
# Registro persistente de items vistos: evita duplicados entre días consecutivos
# (la ventana de frescura de ~28h solapa con el día anterior). Lo gestiona parse-feed.py.
SEEN_FILE="$VAULT/.vault-meta/news-seen.txt"
LOG_FILE="$VAULT/.vault-meta/news-cron.log"
NEWS_MODEL="${NEWS_MODEL:-haiku}"

cd "$VAULT"

# Rotación simple del log del cron: si supera ~2000 líneas, conserva las últimas 1000.
# Truncado en sitio (cat >) para no romper el fd en append que abrió el crontab.
if [ -f "$LOG_FILE" ] && [ "$(wc -l < "$LOG_FILE")" -gt 2000 ]; then
  tail -n 1000 "$LOG_FILE" > "$LOG_FILE.rot.tmp" && cat "$LOG_FILE.rot.tmp" > "$LOG_FILE" && rm -f "$LOG_FILE.rot.tmp"
fi

if [ ! -f "$FEEDS" ]; then
  echo "No existe $FEEDS. Crea la lista de feeds (ver CLAUDE.md §8)." >&2
  exit 1
fi

# ¿Hay algún feed activo? (ignora comentarios y líneas vacías)
if ! grep -vE '^[[:space:]]*(#|$)' "$FEEDS" | grep -q .; then
  echo "No hay feeds activos en $FEEDS. Descomenta o añade alguno (nombre|url)." >&2
  exit 1
fi

mkdir -p "$RAW_DIR"
echo "Recolectando noticias en $RAW_DIR ($(date '+%H:%M'))"

feeds_ok=0
feeds_fail=0
tot_nuevos=0
tot_dup=0
tot_old=0

# Bucle portable (sin mapfile, compatible con bash 3.2 de macOS).
while IFS= read -r line || [ -n "$line" ]; do
  # Ignora comentarios y líneas vacías (con o sin indentación).
  trimmed="$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  if [ -z "$trimmed" ]; then continue; fi
  case "$trimmed" in \#*) continue ;; esac

  name="${trimmed%%|*}"
  url="${trimmed#*|}"
  name="$(echo "$name" | sed 's/^ *//;s/ *$//')"
  url="$(echo "$url" | sed 's/^ *//;s/ *$//')"
  if [ -z "$url" ] || [ "$url" = "$name" ]; then
    echo "  · línea mal formada (se esperaba nombre|url): $trimmed" >&2
    feeds_fail=$((feeds_fail + 1))
    continue
  fi

  echo "  · $name"
  xml="$(curl -fsSL --max-time 30 -A 'second-brain-news/1.0' "$url" 2>/dev/null || true)"
  if [ -z "$xml" ]; then
    echo "    (sin respuesta, se omite)"
    feeds_fail=$((feeds_fail + 1))
    continue
  fi

  # Parseo de RSS/Atom con el parser externo (bin/parse-feed.py).
  # NOTA: no usar heredoc aquí — pisaría el pipe de stdin (bug histórico B1).
  out="$(printf '%s' "$xml" | FEED_NAME="$name" RAW_DIR="$RAW_DIR" SEEN_FILE="$SEEN_FILE" python3 "$VAULT/bin/parse-feed.py" "$DATE")"
  echo "$out"
  case "$out" in
    *"XML inválido"*)
      feeds_fail=$((feeds_fail + 1))
      ;;
    *)
      feeds_ok=$((feeds_ok + 1))
      n="$(printf '%s' "$out" | sed -n 's/.*nuevos=\([0-9]*\).*/\1/p')"
      d="$(printf '%s' "$out" | sed -n 's/.*duplicados=\([0-9]*\).*/\1/p')"
      o="$(printf '%s' "$out" | sed -n 's/.*antiguos=\([0-9]*\).*/\1/p')"
      tot_nuevos=$((tot_nuevos + ${n:-0}))
      tot_dup=$((tot_dup + ${d:-0}))
      tot_old=$((tot_old + ${o:-0}))
      ;;
  esac
done < "$FEEDS"

echo "Resumen: feeds OK: $feeds_ok | feeds fallidos: $feeds_fail | items nuevos: $tot_nuevos | duplicados: $tot_dup | antiguos: $tot_old"

if [ "${NO_CLAUDE:-0}" = "1" ]; then
  echo "NO_CLAUDE=1: no se invoca Claude. Lanza /news manualmente cuando quieras."
  exit 0
fi

if ! command -v claude >/dev/null 2>&1; then
  echo "Aviso: 'claude' no está en el PATH. Items crudos listos en $RAW_DIR." >&2
  echo "Procesa luego con:  claude -p \"Procesa las noticias de hoy\" --permission-mode acceptEdits" >&2
  exit 0
fi

if [ "$tot_nuevos" -eq 0 ]; then
  echo "Sin items nuevos hoy; no se invoca a Claude."
  exit 0
fi

echo "Invocando Claude para procesar el radar del día (modelo: $NEWS_MODEL)..."
claude -p "Procesa las noticias de hoy" --model "$NEWS_MODEL" --permission-mode acceptEdits
