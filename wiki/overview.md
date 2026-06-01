---
type: overview
title: "Resumen del vault"
created: 2026-06-01
updated: 2026-06-01
tags:
  - meta
  - overview
status: developing
related:
  - "[[index]]"
  - "[[hot]]"
  - "[[log]]"
  - "[[getting-started]]"
---

# Resumen del vault

Navegación: [[index]] | [[hot]] | [[log]] | [[getting-started]]

---

## Propósito

Segundo cerebro personal: el conocimiento del usuario + un radar de lo que le rodea.
Construido sobre el patrón [LLM Wiki](https://github.com/karpathy) de Andrej Karpathy
(base [`claude-obsidian`](https://github.com/AgriciDaniel/claude-obsidian), MIT) más una
**capa propia de ingesta diaria de noticias**.

Todo se escribe en español. Las páginas se citan entre sí con `[[wikilinks]]`; las respuestas
citan páginas del vault, nunca el conocimiento de entrenamiento.

---

## Cómo se usa

- **Ingerir una fuente:** suelta un archivo en `.raw/` y di `ingest [archivo]` (o pega una URL).
- **Preguntar:** "¿qué sé de X?" → Claude lee `hot` → `index` → páginas y sintetiza con citas.
- **Investigar:** `/autoresearch [tema]` para una investigación web autónoma archivada en el wiki.
- **Noticias del día:** el cron deja items en `.raw/news/YYYY-MM-DD/` y luego `/news` (o
  "Procesa las noticias de hoy") escribe el radar en `wiki/sources/news/YYYY-MM-DD.md`.
- **Archivar una sesión:** `/save` guarda la conversación como nota en `wiki/sessions/`.
- **Mantenimiento:** "lint the wiki" cada 10-15 ingestas para detectar huérfanos y enlaces rotos.

---

## Estructura

```
.raw/              fuentes crudas (inmutables); .raw/news/<fecha>/ para el cron de noticias
wiki/concepts/     conceptos, ideas, marcos
wiki/entities/     personas, organizaciones, productos, herramientas
wiki/sources/      resúmenes de fuentes ingeridas
wiki/sources/news/ notas diarias del radar de noticias
wiki/sessions/     conversaciones archivadas con /save
_templates/        plantillas de Obsidian (Templater)
```

---

## Estado actual

- Fuentes ingeridas: 0
- Páginas del wiki: 0
- Última actividad: 2026-06-01 (creación del vault)
