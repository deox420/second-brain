#!/usr/bin/env bash
# install-cron.sh — instala (de forma idempotente) las tareas programadas del segundo
# cerebro en el crontab del usuario. Pensado para Linux, macOS y WSL2.
#
# Qué programa (horas por defecto, configurables por entorno):
#   · Radar diario de noticias        → 07:30 todos los días  (bin/cron-news-ingest.sh)
#   · Lint semanal del vault          → 08:00 los domingos     (claude -p ...)
#   · Radar semanal de noticias       → 08:30 los domingos     (/news-semana, modelo haiku)
#
# Es idempotente: escribe las tres líneas dentro de un bloque marcado y, si vuelves a
# ejecutarlo, reemplaza ese bloque sin tocar el resto de tu crontab.
#
# Uso:
#   bash bin/install-cron.sh              instala/actualiza el bloque
#   bash bin/install-cron.sh --show       muestra lo que instalaría (no toca el crontab)
#   bash bin/install-cron.sh --remove     elimina el bloque del segundo cerebro
#
# Ajustes por entorno (opcionales):
#   NEWS_TIME="30 7 * * *"     cuándo recoger noticias       (formato cron: min hora * * dow)
#   LINT_TIME="0 8 * * 0"      cuándo lanzar el lint semanal
#   WEEK_TIME="30 8 * * 0"     cuándo generar el radar semanal
#   NEWS_MODEL=haiku           modelo del radar diario (lo lee cron-news-ingest.sh)
#
# Nota WSL2: el demonio cron NO arranca solo. Este script lo detecta y te dice cómo
# activarlo (ver también docs/instalacion-windows.md).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAULT="$(dirname "$SCRIPT_DIR")"

BEGIN_MARK="# >>> second-brain cron (gestionado por bin/install-cron.sh) >>>"
END_MARK="# <<< second-brain cron <<<"

NEWS_TIME="${NEWS_TIME:-30 7 * * *}"
LINT_TIME="${LINT_TIME:-0 8 * * 0}"
WEEK_TIME="${WEEK_TIME:-30 8 * * 0}"
NEWS_MODEL_ENV="${NEWS_MODEL:-haiku}"

# Construye el bloque de cron. Usamos `bash -lc` para cargar el perfil de login del usuario
# (cron arranca con un PATH mínimo y, en WSL, `claude`/`node`/`python3` suelen vivir en
# rutas instaladas por npm/nvm que solo están en el PATH del login). Las rutas van absolutas.
build_block() {
  cat <<EOF
$BEGIN_MARK
# Editado por bin/install-cron.sh — no lo edites a mano; relánzalo para actualizar.
$NEWS_TIME bash -lc 'cd "$VAULT" && NEWS_MODEL="$NEWS_MODEL_ENV" bash bin/cron-news-ingest.sh' >> "$VAULT/.vault-meta/news-cron.log" 2>&1
$LINT_TIME bash -lc 'cd "$VAULT" && claude -p "Ejecuta el lint semanal del vault" --permission-mode acceptEdits' >> "$VAULT/.vault-meta/lint-cron.log" 2>&1
$WEEK_TIME bash -lc 'cd "$VAULT" && claude -p "Genera el radar semanal de noticias (comando /news-semana)" --model haiku --permission-mode acceptEdits' >> "$VAULT/.vault-meta/news-cron.log" 2>&1
$END_MARK
EOF
}

# Devuelve el crontab actual sin nuestro bloque (vacío si no hay crontab todavía).
current_without_block() {
  crontab -l 2>/dev/null | awk -v b="$BEGIN_MARK" -v e="$END_MARK" '
    $0 == b { skip = 1; next }
    $0 == e { skip = 0; next }
    skip != 1 { print }
  '
}

warn_wsl_cron() {
  # ¿Estamos en WSL?
  if ! grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; then
    return 0
  fi
  # ¿Está el demonio cron en marcha?
  if pgrep -x cron >/dev/null 2>&1 || pgrep -x crond >/dev/null 2>&1; then
    return 0
  fi
  cat >&2 <<'EOF'

⚠ WSL detectado y el demonio cron no parece estar corriendo.
  El crontab quedó instalado, pero no se ejecutará hasta que arranques cron. Opciones:

  A) Recomendado (systemd, persistente). Edita /etc/wsl.conf y añade:
        [boot]
        systemd=true
     Luego, desde PowerShell:  wsl --shutdown   y reabre Ubuntu. Después:
        sudo systemctl enable --now cron

  B) Rápido (sin systemd). Edita /etc/wsl.conf y añade:
        [boot]
        command="service cron start"
     O arráncalo a mano en cada sesión:  sudo service cron start

  Detalles en docs/instalacion-windows.md.
EOF
}

case "${1:-install}" in
  --show|show)
    echo "# (vista previa — no se ha tocado el crontab)"
    build_block
    ;;
  --remove|remove|--uninstall|uninstall)
    NEW="$(current_without_block || true)"
    if [ -n "$NEW" ]; then
      printf '%s\n' "$NEW" | crontab -
    else
      # crontab quedaría vacío
      crontab -r 2>/dev/null || true
    fi
    echo "✓ Bloque del segundo cerebro eliminado del crontab."
    ;;
  install|--install|"")
    mkdir -p "$VAULT/.vault-meta"
    BASE="$(current_without_block || true)"
    {
      if [ -n "$BASE" ]; then printf '%s\n' "$BASE"; fi
      build_block
    } | crontab -
    echo "✓ Tareas del segundo cerebro instaladas/actualizadas en el crontab:"
    echo "    · Radar diario   ($NEWS_TIME)"
    echo "    · Lint semanal   ($LINT_TIME)"
    echo "    · Radar semanal  ($WEEK_TIME)"
    echo "  Vault: $VAULT"
    echo "  Revisa con:  crontab -l"
    warn_wsl_cron
    ;;
  *)
    echo "Uso: bash bin/install-cron.sh [--show | --remove]" >&2
    exit 1
    ;;
esac
