#!/usr/bin/env bash
# check-feeds.sh — verifica que los feeds de bin/news-feeds.txt responden y parsean.
#
# Comprueba cada feed (también los comentados, con --all) descargándolo y pasándolo por
# bin/parse-feed.py en modo seco (RAW_DIR temporal, sin SEEN_FILE), y reporta el resultado.
# Úsalo antes de activar un feed nuevo y cuando el radar venga vacío varios días.
#
# Uso:  bash bin/check-feeds.sh          (solo feeds activos)
#       bash bin/check-feeds.sh --all    (también los comentados de ejemplo)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAULT="$(dirname "$SCRIPT_DIR")"
FEEDS="$VAULT/bin/news-feeds.txt"
ALL="${1:-}"

if [ ! -f "$FEEDS" ]; then
  echo "No existe $FEEDS." >&2
  exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

ok=0
fail=0

while IFS= read -r line || [ -n "$line" ]; do
  trimmed="$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  if [ -z "$trimmed" ]; then continue; fi
  case "$trimmed" in
    \#*)
      if [ "$ALL" != "--all" ]; then continue; fi
      # Quita el '#' inicial y reintenta como línea normal; descarta comentarios sin '|'.
      trimmed="$(echo "$trimmed" | sed 's/^#[[:space:]]*//')"
      case "$trimmed" in *\|http*) ;; *) continue ;; esac
      ;;
  esac

  name="${trimmed%%|*}"
  url="${trimmed#*|}"
  name="$(echo "$name" | sed 's/^ *//;s/ *$//')"
  url="$(echo "$url" | sed 's/^ *//;s/ *$//')"
  if [ -z "$url" ] || [ "$url" = "$name" ]; then continue; fi

  printf '  · %-20s ' "$name"
  xml="$(curl -fsSL --max-time 20 -A 'second-brain-news/1.0' "$url" 2>/dev/null || true)"
  if [ -z "$xml" ]; then
    echo "FALLO (sin respuesta HTTP)"
    fail=$((fail + 1))
    continue
  fi
  out="$(printf '%s' "$xml" | FEED_NAME="$name" RAW_DIR="$TMP" python3 "$VAULT/bin/parse-feed.py" "$(date +%Y-%m-%d)")"
  case "$out" in
    *"XML inválido"*)
      echo "FALLO (no es RSS/Atom válido)"
      fail=$((fail + 1))
      ;;
    *)
      echo "OK ($(echo "$out" | sed 's/^[[:space:]]*//'))"
      ok=$((ok + 1))
      ;;
  esac
  rm -f "$TMP"/*.md 2>/dev/null || true
done < "$FEEDS"

echo "Resultado: $ok OK | $fail con fallo"
if [ $((ok + fail)) -eq 0 ]; then
  echo "(No había feeds que comprobar; usa --all para incluir los ejemplos comentados.)"
fi
[ "$fail" -eq 0 ]
