# Publicación del wiki como sitio web (Quartz 4)

El vault se publica como sitio estático con [Quartz 4](https://quartz.jzhao.xyz/)
(generador diseñado para vaults de Obsidian: wikilinks, backlinks, grafo, búsqueda).

**Método principal: Vercel.** GitHub Pages queda como alternativa manual (más abajo).

## Vercel (método activo)

El repo **no** es un proyecto Quartz: `scripts/build-site.sh` clona `jackyzha0/quartz`
(rama `v4`), copia `wiki/` como `content/`, inyecta `publish/quartz.config.ts` y construye
el sitio en `public/`. `vercel.json` le dice a Vercel que ejecute ese script y sirva
`public/`. En cada push a `main`, Vercel reconstruye y despliega solo.

Como el radar diario se auto-commitea y se pushea, **la nota de cada mañana se publica
sola** sin tocar nada.

### Activación (una sola vez)

Opción A — desde el dashboard (recomendada, no necesita CLI):
1. [vercel.com](https://vercel.com) → **Add New → Project → Import** el repo
   `deox420/second-brain`.
2. Vercel detecta `vercel.json`; no cambies nada (framework "Other", build y output ya
   definidos). **Deploy**.
3. Quedará en `https://<proyecto>.vercel.app`. Cada push a `main` redepliega.

Opción B — desde la CLI (en tu terminal, dentro del repo):
```bash
npx vercel login        # una vez
npx vercel --prod       # despliega; sigue las preguntas (link al repo)
```

`baseUrl` se ajusta solo en el build a partir de la variable `VERCEL_PROJECT_PRODUCTION_URL`
que Vercel inyecta; no hay que tocar nada al cambiar de dominio.

### Previsualizar en local
```bash
bash scripts/build-site.sh && npx serve public
```

## GitHub Pages (alternativa manual)

El workflow `.github/workflows/publish.yml` quedó como `workflow_dispatch` (solo manual).
Si algún día quieres publicar también en Pages: Settings → Pages → Source "GitHub Actions",
y lánzalo desde la pestaña Actions → *Run workflow*. Quedaría en
`https://deox420.github.io/second-brain/`. Actualiza `baseUrl` en
`publish/quartz.config.ts` si lo usas.

## Privacidad (convención de CLAUDE.md §3)

- **Toda nota de `wiki/` es publicable salvo que diga lo contrario.**
- Una nota con `publish: false` en el frontmatter **no se publica** (filtro
  `RemoveUnpublished` en `publish/quartz.config.ts`).
- **`wiki/sessions/` no se publica nunca** (está en `ignorePatterns` y el workflow además
  falla si detecta `sessions` en la salida — cinturón y tirantes).
- Recuerda: aunque una nota no se publique en el sitio, **sí está en el repo**; mientras el
  repo sea público, cualquiera puede leerla en GitHub. Lo realmente privado no debe
  commitearse o el repo debe pasar a privado.

## Migración futura a repo privado (decisión ya tomada)

GitHub Pages gratuito exige repo público. Cuando el repo pase a privado, migrar a
**Cloudflare Pages** (gratis con repos privados):

1. Crea una cuenta en Cloudflare → **Workers & Pages → Create → Pages →
   Connect to Git** y autoriza el repo `deox420/second-brain`.
2. Configuración del build (reproduce lo que hace nuestro workflow):
   - **Build command:**
     `git clone --depth 1 -b v4 https://github.com/jackyzha0/quartz /tmp/q && rm -rf /tmp/q/content && mkdir /tmp/q/content && cp -r wiki/. /tmp/q/content/ && cp publish/quartz.config.ts /tmp/q/quartz.config.ts && cd /tmp/q && npm ci && npx quartz build && cp -r public "$CF_PAGES_BUILD_OUTPUT_DIR"`
     (o, más mantenible, mueve esa lógica a `bin/build-site.sh` y llama al script).
   - **Build output directory:** `public` (ajusta según el comando final).
   - **Variable de entorno:** `NODE_VERSION=22`.
3. Actualiza `baseUrl` en `publish/quartz.config.ts` al dominio que te dé Cloudflare
   (`<proyecto>.pages.dev` o tu dominio propio).
4. Desactiva el workflow de GitHub Pages (`publish.yml`): bórralo o restringe su trigger.
5. (Opcional) **Cloudflare Access** delante del dominio para exigir login y que el sitio
   solo lo veas tú: Zero Trust → Access → Applications → Add an application → Self-hosted,
   con una política de allowlist por email.

Nota de Quartz: GitHub Pages no redirige `ruta/` → `ruta.html`; Cloudflare Pages sí. La
migración no rompe enlaces internos (el sitio usa rutas sin barra final), pero los enlaces
externos antiguos con barra final funcionarán mejor en Cloudflare.

## Verificación tras cada cambio grande

- La portada carga y la búsqueda funciona.
- Una nota nueva del radar aparece tras el push de la mañana.
- Una nota con `publish: false` y cualquier cosa en `wiki/sessions/` **no** aparecen
  (el paso "Verificar exclusiones de privacidad" del workflow lo comprueba en cada build).
- El sitio se ve bien en móvil (tema por defecto de Quartz es responsive).
