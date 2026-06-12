---
type: meta
title: "Registro de operaciones"
updated: 2026-06-01
tags:
  - meta
  - log
status: evergreen
related:
  - "[[index]]"
  - "[[hot]]"
  - "[[overview]]"
---

# Registro de operaciones

Navegación: [[index]] | [[hot]] | [[overview]]

Solo se añade. Las entradas nuevas van ARRIBA. Nunca edites entradas pasadas.

Formato: `## [YYYY-MM-DD] operación | Título`

Leer entradas recientes: `grep "^## \[" wiki/log.md | head -10`

---

## [2026-06-12] ingest | Ingesta diaria de noticias (día 1)
- Tipo: wiki-news (skill de ingesta de radar)
- Fuente: `.raw/news/2026-06-12/` (cron + fuentes RSS)
- Items procesados: ~200 items crudos
- Filtrados y archivados: 10 noticias + hilos a vigilar (prioridad: ciberseguridad, ia, linux, ciencia)
- Nota: [[2026-06-12|Radar — 2026-06-12]]
- Temas dominantes: ciberseguridad (AUR hijacking, 8 exploits/campañas), IA (infraestructura China, agentes comprometidos), ciencia (CRISPR cancer)
- Observación: Alta actividad de ciberataques contra herramientas IA y componentes Linux. Patrón: actores chinos enfocados en IA y Linux.

## [2026-06-01] setup | Creación del vault
- Tipo: scaffolding
- Base: `claude-obsidian` (patrón LLM Wiki de Karpathy), MIT — ver [[../ATTRIBUTION]].
- Capa propia: protocolo de ingesta diaria de noticias (skill `wiki-news`, comando `/news`, `bin/cron-news-ingest.sh`).
- Estructura: `wiki/{concepts,entities,sources,sources/news,sessions}` + `.raw/news/`.
- Pendiente del usuario: personalizar TEMAS DE INTERÉS (CLAUDE.md §7) y FUENTES RSS (`bin/news-feeds.txt`).
