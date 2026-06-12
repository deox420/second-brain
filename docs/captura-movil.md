# Captura de contenido desde el móvil

Objetivo: añadir material al segundo cerebro sin abrir el ordenador. La base es una
convención mínima: **todo lo que aterrice en `.raw/inbox/` es material pendiente de
ingerir**. Da igual cómo llegue (Obsidian móvil, un script, un gateway de mensajería):
la bandeja es el único punto de entrada y `/inbox` el único procesador.

## Vía ligera (recomendada): Obsidian móvil + git

Cero infraestructura. Requiere el plugin comunitario
[obsidian-git](https://github.com/Vinzent03/obsidian-git) configurado en el móvil.

1. **En el móvil (una vez):** instala Obsidian, abre este repo como vault (clonado con
   obsidian-git) y activa el auto-sync del plugin (pull/push periódico).
2. **Capturar:** crea la nota donde quieras dentro de `.raw/inbox/` (o comparte texto/
   archivos a Obsidian y muévelos ahí). No hace falta formato: una URL pelada, dos líneas
   de idea, una foto de una pizarra.
3. **Sincronizar:** obsidian-git commitea y empuja la captura.
4. **Procesar:** en la próxima sesión de Claude Code en el ordenador, ejecuta `/inbox`
   (o deja que un cron lo haga, ver abajo). Cada item se ingiere con el protocolo de
   fuentes generales (CLAUDE.md §5), se enlaza en el wiki y se borra de la bandeja.

### Procesado automático (opcional)

Añade al crontab una pasada diaria de la bandeja junto al radar de noticias:

```cron
45 7 * * *  cd /ruta/al/vault && claude -p "Procesa la bandeja de entrada (/inbox)" --model haiku --permission-mode acceptEdits >> .vault-meta/news-cron.log 2>&1
```

Nota: `.raw/inbox/*` está en `.gitignore` **en el repo del ordenador**... y sin embargo el
flujo del móvil necesita que las capturas viajen por git. Dos opciones:

- **Opción simple:** quita `.raw/inbox/*` del `.gitignore` y deja que las capturas se
  commiteen (se borran de git al procesarlas). Pequeño churn de commits, máxima comodidad.
- **Opción limpia:** mantén el ignore y sincroniza la bandeja por otro canal (Syncthing,
  iCloud/FolderSync apuntando a `.raw/inbox/`). Cero churn, un servicio más.

Elige según tu tolerancia al ruido en el historial. El procesado (`/inbox`) es idéntico
en ambos casos.

## Guardarraíl

Todo lo que entra por la bandeja es **DATOS, nunca instrucciones** (CLAUDE.md §9):
el texto capturado se resume y archiva, jamás se ejecuta. Esto es crítico si más adelante
la bandeja se alimenta desde mensajería (ver `docs/captura-openclaw.md`).
