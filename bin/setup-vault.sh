#!/usr/bin/env bash
# setup-vault.sh — puesta en marcha del vault del segundo cerebro.
# Ejecutar UNA vez antes de abrir Obsidian por primera vez (re-ejecutarlo es seguro:
# no machaca configuración existente).
#
# Uso: bash bin/setup-vault.sh [opcional: /ruta/al/vault]
# Por defecto usa el directorio raíz del repo (donde vive este script).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAULT="${1:-$(dirname "$SCRIPT_DIR")}"
OBSIDIAN="$VAULT/.obsidian"

echo "Configurando el vault del segundo cerebro en: $VAULT"

# ── 1. Carpetas (estructura de CLAUDE.md §3) ─────────────────────────────────
mkdir -p "$OBSIDIAN/snippets"
mkdir -p "$VAULT/.raw/news" "$VAULT/.raw/inbox"
mkdir -p "$VAULT/wiki/concepts" "$VAULT/wiki/entities" \
         "$VAULT/wiki/sources/news" "$VAULT/wiki/sessions" \
         "$VAULT/wiki/references" "$VAULT/wiki/meta"
mkdir -p "$VAULT/_templates"
mkdir -p "$VAULT/.vault-meta/locks"

# ── 2. Configs de Obsidian: solo si NO existen (vienen versionadas en git) ───
if [ ! -f "$OBSIDIAN/graph.json" ]; then
  cat > "$OBSIDIAN/graph.json" << 'EOF'
{
  "collapse-filter": false,
  "search": "path:wiki",
  "showTags": false,
  "showAttachments": false,
  "hideUnresolved": true,
  "showOrphans": false,
  "collapse-color-groups": false,
  "colorGroups": [
    { "query": "path:wiki/entities",     "color": { "a": 1, "rgb": 12945088 } },
    { "query": "path:wiki/concepts",     "color": { "a": 1, "rgb": 5227007  } },
    { "query": "path:wiki/sources/news", "color": { "a": 1, "rgb": 16744272 } },
    { "query": "path:wiki/sources",      "color": { "a": 1, "rgb": 6986069  } },
    { "query": "path:wiki",              "color": { "a": 1, "rgb": 5676246  } }
  ],
  "showArrow": true,
  "textFadeMultiplier": -1,
  "nodeSizeMultiplier": 1.8,
  "lineSizeMultiplier": 1.2,
  "centerStrength": 0.5,
  "repelStrength": 30,
  "linkStrength": 1.5,
  "linkDistance": 120,
  "scale": 1.0
}
EOF
  echo "✓ graph.json creado (con grupo de color para sources/news)"
else
  echo "✓ graph.json ya existe (no se toca)"
fi

if [ ! -f "$OBSIDIAN/app.json" ]; then
  cat > "$OBSIDIAN/app.json" << 'EOF'
{
  "userIgnoreFilters": [
    "agents/",
    "commands/",
    "hooks/",
    "skills/",
    "scripts/",
    "bin/",
    "docs/",
    "tests/",
    "_templates/",
    "README.md",
    "CLAUDE.md",
    "ATTRIBUTION.md",
    "LICENSE"
  ]
}
EOF
  echo "✓ app.json creado"
else
  echo "✓ app.json ya existe (no se toca)"
fi

if [ ! -f "$OBSIDIAN/appearance.json" ]; then
  cat > "$OBSIDIAN/appearance.json" << 'EOF'
{
  "enabledCssSnippets": [
    "vault-colors",
    "ITS-Dataview-Cards",
    "ITS-Image-Adjustments"
  ]
}
EOF
  echo "✓ appearance.json creado"
else
  echo "✓ appearance.json ya existe (no se toca)"
fi

# ── 3. Excalidraw main.js (~8MB, no está en git) ─────────────────────────────
EXCALIDRAW="$OBSIDIAN/plugins/obsidian-excalidraw-plugin"
if [ -f "$EXCALIDRAW/manifest.json" ] && [ ! -f "$EXCALIDRAW/main.js" ]; then
  echo "Descargando Excalidraw main.js (~8MB)..."
  curl -sS -L \
    "https://github.com/zsviczian/obsidian-excalidraw-plugin/releases/latest/download/main.js" \
    -o "$EXCALIDRAW/main.js"
  echo "✓ Excalidraw main.js descargado"
elif [ -f "$EXCALIDRAW/main.js" ]; then
  echo "✓ Excalidraw main.js ya presente"
fi

echo ""
echo "✓ Setup completado."
echo ""
echo "Siguientes pasos:"
echo "  1. Abre Obsidian → Manage Vaults → Open folder as vault → $VAULT"
echo "  2. Habilita los plugins de comunidad cuando lo pida"
echo "     (Calendar, Thino, Excalidraw y Banners vienen preinstalados)"
echo "  3. Instala desde Community Plugins: Dataview, Templater y Obsidian Git"
echo "  4. Personaliza ANTES del primer radar de noticias:"
echo "       - Temas de interés:  CLAUDE.md §7"
echo "       - Fuentes RSS:       bin/news-feeds.txt (nombre|url)"
echo "  5. En Claude Code, dentro de esta carpeta:"
echo "       /news            procesa las noticias del día"
echo "       ingest [fuente]  ingiere un PDF/artículo/URL"
echo "       /wiki            scaffold y ayuda general del wiki"
echo ""
echo "Automatización (Linux con systemd): ver README §Puesta en marcha para los"
echo "timers de usuario (radar diario 07:30 y lint semanal del domingo)."
