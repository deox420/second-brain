---
name: wiki-news
description: "Ingesta diaria de noticias para el segundo cerebro. Lee los items crudos que el cron deja en .raw/news/YYYY-MM-DD/, filtra por los TEMAS DE INTERÉS de CLAUDE.md (§7), deduplica, resume en español y escribe la nota diaria del radar en wiki/sources/news/YYYY-MM-DD.md. Triggers on: /news, procesa las noticias de hoy, ingesta de noticias, radar de noticias, noticias del día, procesa el radar."
---

# wiki-news: Ingesta diaria de noticias

Capa propia del segundo cerebro, **en español**. Procesa el lote de noticias del día y escribe
una sola nota: el "Radar". Esta skill complementa a `wiki-ingest` (que es para fuentes
generales); aquí el flujo es por lotes, neutral y con techo de ruido.

Lee primero el orden de eficiencia de tokens: `wiki/hot.md` → `wiki/index.md` → sub-índices →
páginas concretas. Para cuando tengas suficiente.

---

## Disparador

Un cron externo (`bin/cron-news-ingest.sh`) deja los items crudos en
`.raw/news/YYYY-MM-DD/` (un archivo por item, con frontmatter `titulo/fuente/url/fecha`) y
luego invoca `claude -p "Procesa las noticias de hoy"`. También puedes lanzarlo a mano con
`/news` o `/news YYYY-MM-DD`.

Determina la fecha objetivo: el argumento si se pasó, si no la de hoy. Si no existe
`.raw/news/<fecha>/` o está vacía, dilo y termina (no inventes noticias).

---

## Protocolo (CLAUDE.md §4)

1. **Lee** todos los items crudos de `.raw/news/<fecha>/`.
2. **Filtra** por los TEMAS DE INTERÉS (CLAUDE.md §7). Descarta lo que no encaje. Respeta
   `prioridad_alta` (nunca se descarta) y `exclusiones` (siempre se ignora). Si dudas de la
   relevancia, **descártalo**. No inventes relevancia.
3. **Deduplica**: si varias fuentes cubren lo mismo, fúndelo en una sola entrada y cita las
   fuentes que aporten algo distinto.
4. **Resume** cada item superviviente en 2–3 líneas, en español, neutral, sin opinión. No
   reproduzcas párrafos enteros con copyright: resume con tus palabras.
5. **Etiqueta y enlaza**: asigna tags de la §7 y conecta con `[[wikilinks]]` a páginas que ya
   existan (entidades, conceptos). Comprueba el índice antes de enlazar para no crear enlaces
   rotos. Si una entidad recurrente aún no tiene página y aparece **≥3 veces en la semana**,
   créala en `wiki/entities/` (revisa las notas diarias previas para contar apariciones).
6. **Escribe** la nota diaria en `wiki/sources/news/<fecha>.md` con el formato de abajo. Plantilla
   base: `_templates/noticia.md`.
7. **Actualiza** `wiki/sources/news/_index.md` (añade la línea del día), `wiki/index.md`
   (sección Noticias), `wiki/log.md` (entrada nueva ARRIBA) y `wiki/hot.md`.
8. **Limpia** `.raw/news/<fecha>/` **solo tras confirmar** que la nota diaria está escrita,
   con `bash scripts/clean-raw-news.sh <fecha>` (es el único borrado permitido en headless;
   ver `.claude/settings.json`).

### Regla de ruido
Máximo **~10 entradas** por día. Si hay más, prioriza por relevancia para los temas de interés
y agrupa el resto en una línea de "también hoy".

---

## Formato de la nota diaria

```markdown
---
tipo: noticia
fecha: YYYY-MM-DD
tags: [daily-news]
---
# Radar — YYYY-MM-DD

## [tema]
- **Titular en una frase.** Resumen de 2–3 líneas. Por qué importa (1 línea).
  Fuente: [nombre](URL). Conecta con: [[pagina-relacionada]]

## Hilos a vigilar
- Temas que aún no son noticia pero conviene seguir.
```

Agrupa las entradas por tema (los de la §7). Usa los tags de §7 en el frontmatter además de
`daily-news` cuando aporten (p. ej. `tags: [daily-news, ia, economia]`).

---

## Entrada en el log

Añade ARRIBA en `wiki/log.md`:

```markdown
## [YYYY-MM-DD] news | Radar del día
- Items crudos: N | Sobrevivieron: M | Descartados: N-M
- Temas: [lista]
- Nota: [[YYYY-MM-DD]]
- Entidades nuevas: [[...]] (si las hubo)
```

---

## Transporte y concurrencia

Sigue la política estándar del vault: consulta `.vault-meta/transport.json` antes de escribir
(ver `skills/wiki-ingest/SKILL.md` §Transport) y guarda cada escritura con
`bash scripts/wiki-lock.sh acquire <ruta>` / `release` (ver §Concurrency de wiki-ingest). El
suelo siempre disponible es la herramienta `Write`/`Edit` con ruta absoluta del vault.

---

## Qué NO hacer

- No inventes hechos ni atribuciones. Si una fuente no es fiable, omítela y dilo.
- No reproduzcas párrafos con copyright: resume.
- No borres `.raw/news/<fecha>/` antes de confirmar la escritura de la nota.
- No superes el techo de ~10 entradas; ante duda de relevancia, descarta.
- No envíes el contenido del vault a APIs externas sin consentimiento explícito.

---

## Cómo pensar (mapeo de 10 principios)

| # | Principio | Aplicación aquí |
|---|-----------|-------------------|
| 1 | OBSERVE (ext) | Lee TODOS los items crudos del día antes de filtrar. |
| 2 | OBSERVE (int) | ¿Estoy colando ruido o sesgando hacia un tema? Respeta §7 al pie de la letra. |
| 3 | LISTEN | El filtro de intereses del usuario es la voz a escuchar: prioridad_alta y exclusiones mandan. |
| 4 | THINK | Qué fundir (dedup), qué tema asignar, con qué páginas existentes conectar. |
| 5 | CONNECT (lat) | Cruza el titular con entidades/conceptos ya en el wiki; cuenta apariciones para la regla ≥3. |
| 6 | CONNECT (sys) | transport.json + wiki-lock + actualizar index/log/hot + _index de noticias. |
| 7 | FEEL | Una nota útil dentro de un mes, no un volcado. Señal sobre volumen: techo de ~10. |
| 8 | ACCEPT | No todo entra. Ante duda, descartar y preguntar es correcto, no un fallo. |
| 9 | CREATE | La nota diaria del radar + entidades nuevas solo si recurren (≥3/semana). |
| 10 | GROW | "Hilos a vigilar" alimenta los próximos días; el radar es incremental. |
