#!/usr/bin/env bash
# sync.sh — sincroniza el vault con GitHub para que Windows, Arch y el móvil vean lo mismo.
#
# Qué hace, en orden seguro:
#   1. Commitea cualquier cambio local pendiente (notas a mano, capturas, radar del cron).
#   2. Trae lo remoto rebasando lo local encima (pull --rebase --autostash): historial limpio.
#   3. Empuja a origin. Eso, de paso, dispara el rebuild de la web (Vercel/Pages).
#
# Pensado para el HOST CEREBRO (el portátil Arch) y para Windows (WSL/Git Bash). En el móvil
# no hace falta: el plugin obsidian-git ya sincroniza solo. Ver docs/sincronizacion.md.
#
# Uso:
#   bash bin/sync.sh                 # commitea pendiente, pull --rebase y push
#   bash bin/sync.sh "mensaje"       # usa ese mensaje de commit
#   PULL_ONLY=1 bash bin/sync.sh     # solo baja cambios (no commitea ni empuja)
#
# Lo llama bin/cron-news-ingest.sh al terminar (desactívalo con NO_SYNC=1).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAULT="$(dirname "$SCRIPT_DIR")"
cd "$VAULT"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "sync: esto no es un repositorio git." >&2; exit 1
fi
if ! git remote get-url origin >/dev/null 2>&1; then
  echo "sync: no hay remoto 'origin' configurado; nada que sincronizar." >&2; exit 0
fi

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
MSG="${1:-vault: sync $(date '+%Y-%m-%d %H:%M:%S')}"

# 1. Commitear lo pendiente (todo lo no ignorado: wiki, capturas procesadas, etc.).
if [ "${PULL_ONLY:-0}" != "1" ]; then
  git add -A
  if ! git diff --cached --quiet; then
    git -c user.name="${GIT_AUTHOR_NAME:-second-brain}" \
        -c user.email="${GIT_AUTHOR_EMAIL:-second-brain@local}" \
        commit -q -m "$MSG"
    echo "sync: commit local creado."
  fi
fi

# 2. Traer remoto rebasando lo local encima. Si hay conflicto, abortar limpio.
if ! git pull --rebase --autostash origin "$BRANCH" 2>/tmp/sync-pull.err; then
  if git rebase --abort >/dev/null 2>&1; then :; fi
  echo "sync: conflicto al integrar lo remoto (rebase abortado, sin cambios destructivos)." >&2
  echo "      Resuélvelo a mano: git pull --rebase origin $BRANCH" >&2
  sed 's/^/      /' /tmp/sync-pull.err >&2 || true
  exit 2
fi

# 3. Empujar (salvo modo solo-bajada).
if [ "${PULL_ONLY:-0}" = "1" ]; then
  echo "sync: PULL_ONLY=1, no se empuja."
  exit 0
fi

if git push origin "$BRANCH" 2>/tmp/sync-push.err; then
  echo "sync: push OK ($BRANCH)."
else
  echo "sync: el push falló (¿sin red o sin credenciales?). Los commits quedan locales." >&2
  sed 's/^/      /' /tmp/sync-push.err >&2 || true
  exit 3
fi
