# Publicación web del wiki (Quartz 4)

El wiki se publica como sitio estático en **GitHub Pages** mediante
`.github/workflows/publish.yml`: cada push a `main` que toque `wiki/` clona
[Quartz 4](https://github.com/jackyzha0/quartz), copia `wiki/` como contenido,
construye y despliega. El radar de cada mañana se publica solo, porque el cron
commitea y pushea la nota diaria.

URL del sitio: `https://deox420.github.io/second-brain/`

## Activación (un paso manual, una sola vez)

Publicar es **opt-in**: hasta que no habilites Pages, el workflow se salta el
despliegue (sin fallar). Para activarlo, elige una:

- Web: repo → **Settings → Pages → Source: GitHub Actions**.
- Terminal: `gh api repos/deox420/second-brain/pages -X POST -f build_type=workflow`

Después lanza el primer build con `gh workflow run publish.yml` (o espera al
siguiente push que toque `wiki/`). Ten presente que el sitio será **público e
indexable**: revisa antes que nada sensible viva en `wiki/` sin `publish: false`.

## Qué se publica y qué no

| Regla | Efecto |
|-------|--------|
| Por defecto | Toda nota de `wiki/` es publicable |
| `wiki/sessions/` | **Nunca** se publica (se excluye en el workflow) |
| `publish: false` en el frontmatter | Esa nota queda fuera del build |

La convención está también en `CLAUDE.md` §3. No hay un "modo privado" más fino:
si algo es sensible, `publish: false` o no lo metas en `wiki/`.

## Mantenimiento

- **Título / idioma / URL** se inyectan por `sed` en el paso "Configurar Quartz"
  del workflow; edítalos ahí.
- **Analytics**: Quartz trae Plausible por defecto. Para desactivarlo, añade al
  paso de configuración: `sed -i 's|provider: "plausible".*|provider: null,|' quartz.config.ts`
  (o fija `analytics: null`).
- Quartz se clona de su rama `v4`; si un build rompe por un cambio upstream,
  fija un tag concreto en el paso "Checkout de Quartz 4" (`ref: v4.x.y`).

## Migración futura a repo privado (decisión ya tomada)

GitHub Pages gratuito exige repo público. Cuando `second-brain` pase a privado:

1. **Cloudflare Pages** (gratis con repos privados):
   - Crea cuenta en Cloudflare → Workers & Pages → "Create" → "Pages" →
     conecta GitHub y selecciona `deox420/second-brain`.
   - No uses su build automático (el repo no es un proyecto Quartz). En su lugar,
     usa "Direct Upload" desde CI: sustituye en `publish.yml` los tres pasos de
     Pages (`configure-pages`, `upload-pages-artifact`, `deploy-pages`) por:
     ```yaml
     - name: Desplegar a Cloudflare Pages
       uses: cloudflare/wrangler-action@v3
       with:
         apiToken: ${{ secrets.CLOUDFLARE_API_TOKEN }}
         accountId: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
         command: pages deploy quartz/public --project-name=second-brain
     ```
   - Secretos necesarios (Settings → Secrets → Actions): `CLOUDFLARE_API_TOKEN`
     (token con permiso "Cloudflare Pages — Edit") y `CLOUDFLARE_ACCOUNT_ID`.
   - Cambia el `baseUrl` del paso de configuración a la URL de Cloudflare
     (`second-brain.pages.dev` o tu dominio).
2. **Acceso restringido (opcional)**: Cloudflare Access permite poner login
   (Google/GitHub) delante del sitio gratis hasta 50 usuarios: Zero Trust →
   Access → Applications → tu dominio de Pages.
3. El resto del workflow (build de Quartz, exclusiones de privacidad) no cambia.
