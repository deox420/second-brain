---
description: Procesa el lote de noticias del día. Lee los items crudos de .raw/news/<fecha>/, filtra por los temas de interés, deduplica, resume en español y escribe la nota diaria del radar en wiki/sources/news/<fecha>.md.
---

Lee la skill `wiki-news`. Luego ejecuta el protocolo de ingesta diaria de noticias.

Uso:
- `/news` — procesa las noticias de **hoy** (`.raw/news/<hoy>/`).
- `/news YYYY-MM-DD` — procesa el lote de esa fecha.

Antes de empezar, lee los TEMAS DE INTERÉS en `CLAUDE.md` (§7): son el filtro que decide qué
noticia entra y qué se descarta. Respeta `prioridad_alta` (nunca se descarta) y `exclusiones`
(siempre se ignora).

Si no existe la carpeta `.raw/news/<fecha>/` o está vacía, di: "No hay items de noticias para
<fecha>." y termina. No inventes noticias.

Al terminar, actualiza `wiki/sources/news/_index.md`, `wiki/index.md`, `wiki/log.md` y
`wiki/hot.md`, y limpia `.raw/news/<fecha>/` solo tras confirmar que la nota diaria quedó escrita.

Reporta: cuántos items crudos había, cuántos sobrevivieron al filtro y qué temas se trataron.
