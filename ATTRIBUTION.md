# Atribuciones

Este vault (segundo cerebro personal) se construye sobre la base de **claude-obsidian** y
reutiliza varios patrones, herramientas y snippets de terceros. La maquinaria (skills,
comandos, agentes, hooks, scripts, plantillas y configuración de Obsidian) procede de
claude-obsidian; la **capa de ingesta diaria de noticias** (`skills/wiki-news/`,
`commands/news.md`, `bin/cron-news-ingest.sh`, `bin/news-feeds.txt`, `_templates/noticia.md`) y
el contenido del wiki son propios.

---

## claude-obsidian (base)

**Autor:** AgriciDaniel / AI Marketing Hub
**Licencia:** MIT (ver [LICENSE](LICENSE))
**Repositorio:** https://github.com/AgriciDaniel/claude-obsidian
**Uso:** base del vault y del plugin (estructura wiki, skills `/wiki`, `/wiki-ingest`,
`/wiki-query`, `/wiki-lint`, `/save`, `/autoresearch`, `/canvas`, etc., agentes, hooks y
scripts). Distribuido bajo MIT; se conserva el aviso de licencia.

---

## Patrón LLM Wiki

**Autor:** Andrej Karpathy
**Fuente:** https://github.com/karpathy
**Uso:** la arquitectura central (usar un LLM para construir y mantener un wiki estructurado a
partir de fuentes crudas) se basa en el patrón LLM Wiki que Karpathy describió públicamente.

---

## Snippets CSS ITS

**Autor:** SlRvb
**Fuente:** https://github.com/SlRvb/Obsidian--ITS-Theme
**Licencia:** GPL-2.0
**Archivos:** `.obsidian/snippets/ITS-Dataview-Cards.css`, `.obsidian/snippets/ITS-Image-Adjustments.css`

Distribuidos bajo GPL-2.0. Cualquier modificación de estos archivos debe publicarse también bajo GPL-2.0.

---

## Plugins de Obsidian (preinstalados)

Los siguientes plugins de la comunidad se incluyen como binarios preinstalados para reducir
fricción de configuración. Son propiedad de sus respectivos autores; verifica las licencias en
sus repositorios.

| Plugin | Autor | Repositorio |
|--------|-------|-------------|
| Calendar | Liam Cain | https://github.com/liamcain/obsidian-calendar-plugin |
| Thino | Boninall (Quorafind) | https://github.com/Quorafind/Obsidian-Thino |
| Obsidian Excalidraw | Zsolt Viczian | https://github.com/zsviczian/obsidian-excalidraw-plugin |
| Obsidian Banners | Danny Hernandez | https://github.com/noatpad/obsidian-banners |

`obsidian-excalidraw-plugin/main.js` **no** se incluye en el repositorio: lo descarga
`bin/setup-vault.sh` desde las releases oficiales del plugin.
