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

## Puesta en marcha

1. **Configura Obsidian:**
   ```bash
   bash bin/setup-vault.sh
   ```
   Luego abre esta carpeta como vault en Obsidian y habilita los plugins de la comunidad.

2. **Personaliza** (importante antes de la primera ingesta de noticias):
   - Edita los **TEMAS DE INTERÉS** en `CLAUDE.md` §7 (el filtro de qué noticia entra).
   - Rellena las **FUENTES RSS** en `bin/news-feeds.txt` (formato `nombre|url`).

3. **Usa el día a día** (en Claude Code, dentro de esta carpeta):
   - `ingest [archivo]` — ingiere una fuente.
   - `¿qué sé de X?` — consulta el wiki.
   - `/news` o "Procesa las noticias de hoy" — procesa el radar del día.
   - `/autoresearch [tema]` — investiga y archiva.
   - `/save` — archiva la sesión actual.

4. **Automatiza el radar** (ejemplo de crontab, en español dentro del script):
   ```bash
   30 7 * * *  cd /ruta/al/vault && bash bin/cron-news-ingest.sh >> .vault-meta/news-cron.log 2>&1
   ```

## Reglas del proyecto

Ver [CLAUDE.md](CLAUDE.md). Resumen: español siempre; citar páginas del vault; `kebab-case` sin
tildes; ante duda de relevancia, descartar; no borrar notas sin confirmación; no enviar el vault
a APIs externas sin consentimiento.
