#!/usr/bin/env bash
# setup-vault.sh — prepara el vault del segundo cerebro para Obsidian.
# Ejecútalo UNA vez antes de abrir Obsidian por primera vez.
#
# Uso: bash bin/setup-vault.sh [opcional: /ruta/al/vault]
# Por defecto usa la carpeta donde vive este script (la raíz del vault).
#
# Este script NO sobrescribe configuración ya versionada (.obsidian/*.json):
# solo crea lo que falte. Es seguro ejecutarlo varias veces.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAULT="${1:-$(dirname "$SCRIPT_DIR")}"
OBSIDIAN="$VAULT/.obsidian"

echo "Preparando el vault del segundo cerebro en: $VAULT"

# ── 1. Carpetas (estructura de CLAUDE.md §3) ─────────────────────────────────
mkdir -p "$OBSIDIAN/snippets"
mkdir -p "$VAULT/.raw/news" "$VAULT/.raw/inbox"
mkdir -p "$VAULT/wiki/concepts" "$VAULT/wiki/entities" \
         "$VAULT/wiki/sources/news" "$VAULT/wiki/sessions"
mkdir -p "$VAULT/_templates"
mkdir -p "$VAULT/.vault-meta"

# ── 2. Configuración de Obsidian: solo si falta (no machacar lo versionado) ──
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
    { "query": "path:wiki/sources/news", "color": { "a": 1, "rgb": 16744576 } },
    { "query": "path:wiki/sources",      "color": { "a": 1, "rgb": 6986069  } },
    { "query": "path:wiki/sessions",     "color": { "a": 1, "rgb": 10066329 } },
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
  echo "  · graph.json creado"
else
  echo "  · graph.json ya existe (no se toca)"
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
    "_templates/",
    "README.md",
    "CLAUDE.md",
    "ATTRIBUTION.md",
    "LICENSE"
  ]
}
EOF
  echo "  · app.json creado"
else
  echo "  · app.json ya existe (no se toca)"
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
  echo "  · appearance.json creado"
else
  echo "  · appearance.json ya existe (no se toca)"
fi

# ── 3. Excalidraw main.js (8MB, fuera de git) ────────────────────────────────
EXCALIDRAW="$OBSIDIAN/plugins/obsidian-excalidraw-plugin"
if [ -f "$EXCALIDRAW/manifest.json" ] && [ ! -f "$EXCALIDRAW/main.js" ]; then
  echo "Descargando Excalidraw main.js (~8MB)..."
  curl -sS -L \
    "https://github.com/zsviczian/obsidian-excalidraw-plugin/releases/latest/download/main.js" \
    -o "$EXCALIDRAW/main.js"
  echo "  · Excalidraw main.js descargado"
elif [ -f "$EXCALIDRAW/main.js" ]; then
  echo "  · Excalidraw main.js ya presente"
fi

echo ""
echo "✓ Vault listo."
echo ""
echo "Siguientes pasos:"
echo "  1. Abre Obsidian → Manage Vaults → Open folder as vault → selecciona: $VAULT"
echo "  2. Habilita los plugins de la comunidad cuando lo pida"
echo "     (Calendar, Thino, Excalidraw y Banners vienen preinstalados)."
echo "  3. Recomendados: Dataview, Templater, Obsidian Git (Settings → Community Plugins)."
echo ""
echo "Antes de la primera ingesta de noticias:"
echo "  - Edita los TEMAS DE INTERÉS en CLAUDE.md §7."
echo "  - Activa tus fuentes RSS en bin/news-feeds.txt (verifícalas con bin/check-feeds.sh)."
echo "  - Para el cron diario: bash bin/install-cron.sh (instala radar diario + semanal y lint)."
echo ""
case "$(uname -r 2>/dev/null)" in
  *microsoft*|*WSL*)
    echo "Windows/WSL2 detectado: guía completa en docs/instalacion-windows.md"
    echo "  (incluye cómo activar cron en WSL y abrir el vault en Obsidian)."
    echo ""
    ;;
esac
echo "En Claude Code, dentro de esta carpeta:"
echo "  /wiki         — scaffold y enrutado del wiki"
echo "  /news         — procesa el radar de noticias del día"
echo "  ingest [x]    — ingiere una fuente"
echo "  ¿qué sé de X? — consulta el vault"
