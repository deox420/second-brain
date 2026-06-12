#!/usr/bin/env bash
# build-site.sh — construye el sitio web del wiki con Quartz 4.
#
# Lo usa Vercel (ver vercel.json): clona jackyzha0/quartz (rama v4), copia
# publish/quartz.config.ts y wiki/ como content/, construye y deja el resultado
# en ./public (lo que Vercel sirve). También sirve para previsualizar en local:
#   bash scripts/build-site.sh && npx serve public
#
# El repo NO es un proyecto Quartz: Quartz es solo el generador, se clona al vuelo.
# Privacidad: wiki/sessions/ y wiki/inbox/ no se publican; las notas con
# `publish: false` las filtra la config de Quartz. Ver docs/publicacion.md.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QUARTZ_REF="${QUARTZ_REF:-v4}"
BUILD="$REPO/.quartz-build"

cd "$REPO"
rm -rf "$BUILD" public
git clone --depth 1 -b "$QUARTZ_REF" https://github.com/jackyzha0/quartz "$BUILD"

cp publish/quartz.config.ts "$BUILD/quartz.config.ts"

# baseUrl real desde el dominio que Vercel inyecta en el build (si existe).
if [ -n "${VERCEL_PROJECT_PRODUCTION_URL:-}" ]; then
  sed -i "s|baseUrl: \".*\"|baseUrl: \"${VERCEL_PROJECT_PRODUCTION_URL}\"|" "$BUILD/quartz.config.ts"
fi

# Contenido = wiki/ sin las carpetas privadas (sessions e inbox).
rm -rf "$BUILD/content"
mkdir -p "$BUILD/content"
cp -r wiki/. "$BUILD/content/"
rm -rf "$BUILD/content/sessions" "$BUILD/content/inbox"

cd "$BUILD"
npm ci
npx quartz build

cd "$REPO"
rm -rf public
cp -r "$BUILD/public" public

# Verificación de privacidad: nada de sessions/ ni inbox/ en el sitio.
if find public -path '*sessions*' -o -path '*inbox*' | grep -q .; then
  echo "ERROR: una carpeta privada se ha colado en el sitio publicado" >&2
  exit 1
fi
echo "✓ Sitio construido en ./public ($(find public -name '*.html' | wc -l) páginas HTML)"
