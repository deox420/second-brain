#!/usr/bin/env bash
# clean-raw-news.sh — borra la carpeta de items crudos de una fecha, tras escribir el radar.
#
# Existe para que la sesión headless del cron pueda limpiar .raw/news/<fecha>/ con un
# permiso de Bash acotado a este script (ver .claude/settings.json), en lugar de conceder
# un 'rm -rf' genérico. Valida que el argumento sea una fecha y solo toca .raw/news/.
#
# Uso: bash scripts/clean-raw-news.sh YYYY-MM-DD

set -euo pipefail

d="${1:-}"
case "$d" in
  [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) ;;
  *) echo "Uso: bash scripts/clean-raw-news.sh YYYY-MM-DD" >&2; exit 1 ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAULT="$(dirname "$SCRIPT_DIR")"
target="$VAULT/.raw/news/$d"

if [ ! -d "$target" ]; then
  echo "No existe $target (nada que limpiar)."
  exit 0
fi

rm -rf "$target"
echo "Limpio: .raw/news/$d/"
