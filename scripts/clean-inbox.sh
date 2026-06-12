#!/usr/bin/env bash
# clean-inbox.sh — borra items YA PROCESADOS de la bandeja .raw/inbox/.
#
# Borra solo los archivos que se le pasan por nombre (no la bandeja entera): una captura
# del móvil puede aterrizar mientras /inbox está procesando, y no debe perderse.
# Valida que cada ruta resuelva dentro de .raw/inbox/. Permiso acotado en
# .claude/settings.json (como scripts/clean-raw-news.sh).
#
# Uso: bash scripts/clean-inbox.sh <archivo> [archivo...]
#      (rutas relativas a .raw/inbox/ o rutas completas dentro de la bandeja)

set -euo pipefail

if [ "$#" -eq 0 ]; then
  echo "Uso: bash scripts/clean-inbox.sh <archivo> [archivo...]" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAULT="$(dirname "$SCRIPT_DIR")"
INBOX="$VAULT/.raw/inbox"

borrados=0
for arg in "$@"; do
  base="$(basename "$arg")"
  if [ "$base" = ".gitkeep" ]; then
    echo "  (se ignora .gitkeep)"
    continue
  fi
  target="$INBOX/$base"
  if [ ! -f "$target" ]; then
    echo "  no existe en la bandeja: $base (se omite)" >&2
    continue
  fi
  rm -f "$target"
  echo "  borrado: .raw/inbox/$base"
  borrados=$((borrados + 1))
done
echo "Bandeja: $borrados item(s) borrados."
