# second-brain

Segundo cerebro personal en **Obsidian + Claude Code**: el conocimiento del usuario más un
**radar diario de noticias**. Todo en español, en Markdown plano que tú controlas.

Construido sobre la base de [`claude-obsidian`](https://github.com/AgriciDaniel/claude-obsidian)
(patrón [LLM Wiki](https://github.com/karpathy) de Karpathy, MIT — ver [ATTRIBUTION.md](ATTRIBUTION.md))
con una **capa propia de ingesta diaria de noticias**.

## Qué hace

- **Ingiere** fuentes (PDFs, artículos, URLs, imágenes) y las convierte en páginas wiki cruzadas.
- **Responde** "¿qué sé de X?" sintetizando y **citando** páginas del vault, no el modelo.
- **Investiga** temas en la web de forma autónoma (`/autoresearch`).
- **Radar de noticias**: un cron recoge RSS y Claude escribe un resumen diario filtrado por tus
  temas de interés.

## Estructura

| Ruta | Contenido |
|------|-----------|
| `wiki/` | Base de conocimiento generada: `concepts/`, `entities/`, `sources/`, `sources/news/`, `sessions/` + `index.md`, `hot.md`, `log.md`, `overview.md`. |
| `.raw/` | Fuentes crudas (inmutables). `.raw/news/<fecha>/` para el cron de noticias. |
| `skills/`, `commands/`, `agents/`, `hooks/`, `scripts/` | Maquinaria del plugin (base + skill `wiki-news`). |
| `_templates/` | Plantillas de Obsidian (Templater), incl. `noticia.md`. |
| `bin/` | `setup-vault.sh` y el cron de noticias (`cron-news-ingest.sh`, `news-feeds.txt`). |
| `docs/` | Guías de la base (compound vault, modos, retrieval). |
| `CLAUDE.md` | Reglas del proyecto (idioma, convenciones, protocolo de noticias, guardarraíles). |

## Requisitos

- **Linux** con `bash` ≥ 4, `curl` y `python3` (solo stdlib; el parser de feeds no
  instala nada). El cron usa `mapfile`, así que macOS con bash 3.2 no está soportado.
- **Claude Code CLI** (`claude`) en el PATH para procesar noticias y consultas.
- **Obsidian** con los plugins Dataview, Templater y (opcional) Obsidian Git.

## Puesta en marcha

1. **Configura Obsidian:**
   ```bash
   bash bin/setup-vault.sh
   ```
   Es idempotente (no machaca configs existentes). Luego abre esta carpeta como
   vault en Obsidian y habilita los plugins de la comunidad.

2. **Personaliza** (importante antes de la primera ingesta de noticias):
   - Edita los **TEMAS DE INTERÉS** en `CLAUDE.md` §7 (el filtro de qué noticia entra).
   - Rellena las **FUENTES RSS** en `bin/news-feeds.txt` (formato `nombre|url`,
     única fuente de verdad). Verifica con `curl` que cada feed responde.

3. **Usa el día a día** (en Claude Code, dentro de esta carpeta):
   - `ingest [archivo]` — ingiere una fuente.
   - `¿qué sé de X?` — consulta el wiki.
   - `/news` o "Procesa las noticias de hoy" — procesa el radar del día.
   - `/news-semana` — sintetiza los radares de la semana.
   - `/inbox` — procesa la bandeja de captura (móvil).
   - `/autoresearch [tema]` — investiga y archiva.
   - `/save` — archiva la sesión actual.

4. **Automatiza el radar.** En este equipo (Arch) corre con **timers de systemd de
   usuario** (sobreviven a reinicios y se ponen al día si el portátil estaba
   apagado a la hora prevista):
   - `second-brain-news.timer` — radar diario a las 07:30.
   - `second-brain-lint.timer` — lint del vault los domingos a las 08:00.

   Comprobar: `systemctl --user list-timers 'second-brain-*'`. Las unidades viven
   en `~/.config/systemd/user/`. Si prefieres `cron`, el equivalente es:
   ```bash
   30 7 * * *  cd /ruta/al/vault && bash bin/cron-news-ingest.sh >> .vault-meta/news-cron.log 2>&1
   ```
   El modelo del radar headless se fija con `NEWS_MODEL` (por defecto `haiku`, barato).

## Seguridad

El contenido de `.raw/` (RSS, bandeja de entrada) es **entrada no confiable**: el
sistema lo trata siempre como datos a resumir, nunca como instrucciones. Una orden
embebida en un feed se ignora y se reporta (ver `CLAUDE.md` §9 y
`skills/wiki-news/SKILL.md` §Seguridad). La sesión del radar corre sin acceso web.

## Sitio web (opcional)

`wiki/` puede publicarse como sitio estático con Quartz 4 en GitHub Pages: cada push
a `main` que toque `wiki/` lo despliega. Es **opt-in** (hay que habilitar Pages una
vez). `wiki/sessions/`, `wiki/inbox/` y cualquier nota con `publish: false` no se
publican. Guía y migración a Cloudflare Pages: `docs/publicacion.md`.

## Captura desde el móvil

Suelta notas en `wiki/inbox/` desde Obsidian móvil (con Obsidian Git) y procésalas
con `/inbox`. Detalle y vía Telegram/WhatsApp: `docs/captura-movil.md`.

## Reglas del proyecto

Ver [CLAUDE.md](CLAUDE.md). Resumen: español siempre; citar páginas del vault; `kebab-case` sin
tildes; ante duda de relevancia, descartar; no borrar notas sin confirmación; no enviar el vault
a APIs externas sin consentimiento.
