---
type: meta
title: "Primeros pasos"
updated: 2026-06-01
tags:
  - meta
  - onboarding
status: evergreen
related:
  - "[[index]]"
  - "[[overview]]"
---

# Primeros pasos

Este vault es tu segundo cerebro: una base de conocimiento persistente que crece con cada
sesión. Cada fuente que añades se procesa en varias páginas wiki cruzadas; cada pregunta que
haces se responde a partir de todo lo ingerido. Todo en español.

---

## Inicio rápido en tres pasos

### 1. Suelta una fuente
Pon cualquier documento en `.raw/` (PDF, markdown, transcripción, artículo) o pega una URL.

### 2. Ingiérela
En una sesión de Claude Code, di:

```
ingest [archivo]
```

Claude lee la fuente, crea páginas bajo `wiki/`, cruza referencias y actualiza
`wiki/index.md`, `wiki/log.md` y `wiki/hot.md`.

### 3. Pregunta
```
¿qué sé de [tema]?
```

Claude lee la caché reciente (`hot.md`), recorre el índice, entra en las páginas relevantes
y responde sintetizando y **citando páginas concretas** del vault.

---

## La caché reciente (`hot.md`)

`wiki/hot.md` es un resumen (~500 palabras) del contexto reciente. Se carga al inicio de cada
sesión (hook `SessionStart`). No necesitas recapitular. Refréscala con: `update hot cache`.

---

## Comandos clave

| Tú dices | Claude hace |
|----------|-------------|
| `ingest [archivo]` | Crea páginas wiki desde una fuente |
| `¿qué sé de X?` | Consulta el wiki y cita páginas |
| `/news` o "Procesa las noticias de hoy" | Procesa el radar de noticias del día |
| `/autoresearch [tema]` | Investiga en la web y archiva resultados |
| `/save` | Archiva esta conversación como nota |
| `lint the wiki` | Revisión de salud: huérfanos, enlaces rotos |
| `update hot cache` | Refresca el resumen de contexto |

---

## Antes de la primera ingesta de noticias

1. Edita los **TEMAS DE INTERÉS** en `CLAUDE.md` (§7): son el filtro que decide qué noticia entra.
2. Rellena las **FUENTES RSS** en `bin/news-feeds.txt` (§8 de `CLAUDE.md`).
3. Programa `bin/cron-news-ingest.sh` (ejemplo de cron dentro del propio script).

---

*Construido sobre el patrón [LLM Wiki](https://github.com/karpathy) de Andrej Karpathy.*
