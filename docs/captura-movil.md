# Captura desde el móvil

Meta: añadir material al segundo cerebro sin abrir el ordenador. Cero
infraestructura: bandeja de entrada + git.

## La bandeja `.raw/inbox/`

Convención: **cualquier archivo que aterrice en `.raw/inbox/` es material
pendiente de ingerir**. Una nota rápida, una URL pegada en un .md, un PDF…
El comando `/inbox` (en Claude Code, dentro del vault) procesa todo lo que haya,
crea/actualiza las páginas wiki correspondientes y vacía la bandeja.

La bandeja no se versiona (`.gitignore`): su contenido es efímero. Lo valioso
acaba en `wiki/`, que sí se versiona.

## Flujo con Obsidian móvil + obsidian-git

1. **En el móvil**: instala Obsidian y abre este repo como vault (clónalo con la
   app, o usa una carpeta sincronizada). Instala el plugin comunitario
   **obsidian-git** y configura pull/push automático (p. ej. cada 10 min con
   auto-commit).
   - Necesitarás un token de GitHub (Settings → Developer settings →
     Fine-grained token con permiso de contents sobre `second-brain`).
2. **Captura**: crea la nota donde quieras… pero si es material "para ingerir",
   guárdala en `.raw/inbox/`. Ojo: como la bandeja está en `.gitignore`, para que
   viaje por git obsidian-git debe añadirla con fuerza, así que la alternativa
   práctica es una carpeta `inbox/` visible en la raíz del vault del móvil…

   **Convención recomendada (la que funciona sin pelearse con .gitignore):**
   escribe las capturas del móvil en `wiki/inbox/` (carpeta normal, versionada,
   viaja por git sin fricción). `/inbox` procesa **ambas** bandejas:
   `.raw/inbox/` (local) y `wiki/inbox/` (móvil), y las vacía al terminar.
3. **En el PC**: la próxima vez que trabajes en el vault, lanza `/inbox` (o deja
   que el cron diario lo haga: añade `claude -p "Procesa la bandeja de entrada"`
   tras el radar si quieres automatizarlo).

## Alternativas sin Obsidian móvil

- **Termux (Android)**: `git clone` del repo y un script de 3 líneas que haga
  `echo "$1" > wiki/inbox/nota-$(date +%s).md && git add -A && git commit -qm inbox && git push`.
- **GitHub móvil / web**: crear el archivo directamente en `wiki/inbox/` desde la
  interfaz de GitHub (vale para URLs y notas cortas).
- **Telegram/WhatsApp → bandeja**: ver `docs/captura-openclaw.md` (documentado,
  no montado: requiere una máquina siempre encendida).
