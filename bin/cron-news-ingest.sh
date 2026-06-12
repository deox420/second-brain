#!/usr/bin/env bash
# cron-news-ingest.sh — recolector de noticias del segundo cerebro (capa propia).
#
# Qué hace:
#   1. Lee las fuentes RSS de bin/news-feeds.txt.
#   2. Descarga cada feed y delega el parseo en bin/parse-feed.py, que vuelca los
#      items recientes (últimas ~28h) como Markdown crudo en .raw/news/YYYY-MM-DD/
#      (uno por item, con frontmatter), deduplicando contra .vault-meta/news-seen.txt
#      para que un item no se repita entre días consecutivos.
#   3. Invoca `claude -p "Procesa las noticias de hoy"` en el vault, que dispara la
#      skill wiki-news (ver skills/wiki-news/SKILL.md y CLAUDE.md §4).
#
# Este script NO escribe en wiki/: solo deja material crudo y llama a Claude. El filtrado,
# resumen, deduplicado temático y la nota diaria los hace la skill wiki-news.
#
# Requisitos: bash >= 4 (mapfile; este proyecto asume Linux), curl, python3 (stdlib).
# 'claude' (Claude Code CLI) en el PATH para el paso 3.
#
# Uso manual:   bash bin/cron-news-ingest.sh
# Solo recolectar (sin llamar a Claude):   NO_CLAUDE=1 bash bin/cron-news-ingest.sh
# Variables opcionales:
#   FEEDS_FILE  ruta alternativa a la lista de feeds (para tests)
#   SEEN_FILE   ruta alternativa al registro de items vistos (para tests)
#   NEWS_MODEL  modelo para la sesión headless (por defecto: haiku, barato)
#
# Automatización: en este equipo corre como timer de systemd de usuario
# (~/.config/systemd/user/second-brain-news.timer, diario 07:30, Persistent=true).
# Equivalente crontab si se prefiere cron:
#   30 7 * * *  cd /ruta/al/vault && bash bin/cron-news-ingest.sh >> .vault-meta/news-cron.log 2>&1

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAULT="$(dirname "$SCRIPT_DIR")"
FEEDS="${FEEDS_FILE:-$VAULT/bin/news-feeds.txt}"
SEEN="${SEEN_FILE:-$VAULT/.vault-meta/news-seen.txt}"
DATE="$(date +%Y-%m-%d)"
RAW_DIR="$VAULT/.raw/news/$DATE"
LOG="$VAULT/.vault-meta/news-cron.log"

cd "$VAULT"

# Rotación simple del log: conservar las últimas 2000 líneas.
if [ -f "$LOG" ] && [ "$(wc -l < "$LOG")" -gt 2000 ]; then
  tail -n 1000 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
fi

if [ ! -f "$FEEDS" ]; then
  echo "No existe $FEEDS. Crea la lista de feeds (formato nombre|url)." >&2
  exit 1
fi

# Feeds activos (ignora comentarios y líneas vacías).
mapfile -t LINES < <(grep -vE '^\s*(#|$)' "$FEEDS" || true)
if [ "${#LINES[@]}" -eq 0 ]; then
  echo "No hay feeds activos en $FEEDS. Descomenta o añade alguno (nombre|url)." >&2
  exit 1
fi

mkdir -p "$RAW_DIR" "$(dirname "$SEEN")"
echo "[$DATE $(date '+%H:%M')] Recolectando noticias en $RAW_DIR"

ok=0
fail=0
for line in "${LINES[@]}"; do
  name="${line%%|*}"
  url="${line#*|}"
  name="$(echo "$name" | sed 's/^ *//;s/ *$//')"
  url="$(echo "$url" | sed 's/^ *//;s/ *$//')"
  [ -z "$url" ] && continue

  echo "  · $name"
  xml="$(curl -fsSL --max-time 30 -A 'second-brain-news/1.0' "$url" 2>/dev/null || true)"
  if [ -z "$xml" ]; then
    echo "    (sin respuesta, se omite)"
    fail=$((fail + 1))
    continue
  fi

  # Parseo RSS/Atom en bin/parse-feed.py (testeable de forma aislada).
  # NOTA: nada de heredoc con `python3 -` aquí — pisaría la tubería (bug histórico B1).
  if printf '%s' "$xml" | FEED_NAME="$name" RAW_DIR="$RAW_DIR" SEEN_FILE="$SEEN" \
       python3 "$VAULT/bin/parse-feed.py" "$DATE"; then
    ok=$((ok + 1))
  else
    echo "    (error de parseo, se omite)"
    fail=$((fail + 1))
  fi
done

n_items="$(find "$RAW_DIR" -type f -name '*.md' | wc -l | tr -d ' ')"
echo "Feeds OK: $ok | fallidos: $fail | items crudos del día: $n_items"

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

echo "Invocando Claude para procesar el radar del día (modelo: ${NEWS_MODEL:-haiku})..."
# Permisos headless (B7): sin estos flags, una sesión -p no puede escribir y el
# radar moriría en silencio. Write/Edit quedan confinados al vault porque es el
# cwd de la sesión (escribir fuera del proyecto exige aprobación aparte, que en
# headless se deniega). Las reglas Bash son prefijos exactos: lock, limpieza de
# .raw/news/ y lectura.
claude -p "Procesa las noticias de hoy" --model "${NEWS_MODEL:-haiku}" \
  --allowedTools "Write" "Edit" \
    "Bash(bash scripts/wiki-lock.sh *)" \
    "Bash(rm -rf .raw/news/*)" "Bash(rm .raw/news/*)" \
    "Bash(ls *)" "Bash(find .raw *)" "Bash(find wiki *)" \
    "Bash(cat *)" "Bash(grep *)" "Bash(wc *)"

# Persistencia determinista: si el radar escribió la nota del día, se commitea y
# se sube aquí (no se delega en el modelo ni en hooks, que en headless no corren).
# El push alimenta la publicación web (workflow de Pages); si falla (sin red,
# sin credenciales) no rompe el cron: quedará pendiente para el día siguiente.
NOTE="wiki/sources/news/$DATE.md"
if [ -f "$NOTE" ] && [ -d .git ]; then
  git add wiki/ 2>/dev/null || true
  if ! git diff --cached --quiet -- wiki/ 2>/dev/null; then
    git commit -q -m "radar: noticias $DATE" -- wiki/ || true
    git push -q origin "$(git rev-parse --abbrev-ref HEAD)" 2>/dev/null \
      || echo "Aviso: push no realizado (se reintentará en el próximo run)."
  fi
  # Limpieza de crudos solo tras confirmar que la nota del día existe.
  rm -rf ".raw/news/$DATE"
fi
