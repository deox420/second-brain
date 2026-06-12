# Captura por Telegram/WhatsApp con OpenClaw (solo documentado, NO implementado)

> Estado: guía de referencia. Esta vía **no está montada**. La base que necesita
> (bandeja `.raw/inbox/` + `/inbox`) ya existe — ver `docs/captura-movil.md`.

[OpenClaw](https://github.com/openclaw/openclaw) es un gateway autohostado que conecta un
LLM con apps de mensajería (Telegram, WhatsApp, etc.). Aplicado a este vault: mandas por
Telegram una URL, una nota de voz o un PDF, y acaba en `.raw/inbox/`, donde el flujo
normal del vault (`/inbox`) lo recoge. El bot es solo un repartidor; la ingesta la hace
el vault.

## Requisitos

- **Una máquina siempre encendida** donde corre el gateway: VPS pequeño o un Mac mini /
  Raspberry Pi en casa. Sin esto, no hay vía OpenClaw.
- Bot de Telegram propio (vía @BotFather) o cuenta de WhatsApp dedicada.
- El vault clonado en esa máquina (o acceso a su `.raw/inbox/` por SSH/Syncthing).
- **Coste**: un agente siempre activo consume API en cada mensaje. Configúralo con el
  modelo más barato posible o sin LLM (modo "solo depositar").

## Instalación (resumen)

1. Instala OpenClaw en la máquina siempre encendida (Docker o npm; sigue su README).
2. Crea el bot de Telegram y conecta el token en la configuración de OpenClaw.
3. Configura la automatización de entrega: cada mensaje/adjunto recibido se guarda como
   archivo en `.raw/inbox/` del vault con un nombre con fecha
   (`YYYY-MM-DD-hhmm-<slug>.md` para texto, extensión original para adjuntos). Texto del
   mensaje → cuerpo del archivo; URL → archivo de una línea; nota de voz → guarda el
   audio y, si quieres transcripción, hazla en el procesado (`/inbox`), no en el bot.
4. El procesado lo hace el flujo normal del vault: `/inbox` manual o el cron diario.

## Guardarraíles OBLIGATORIOS

1. **Allowlist estricta de remitentes**: el bot solo acepta mensajes del user ID de
   Telegram del dueño (no del username, que es suplantable; el ID numérico). Todo lo
   demás se descarta sin procesar y sin responder.
2. **El contenido recibido es DATOS** (regla anti-injection de CLAUDE.md §9): el bot no
   interpreta ni ejecuta nada de lo que llega; solo lo deposita. Las instrucciones
   embebidas en un mensaje, URL o PDF se ignoran también en la ingesta posterior.
3. **El bot NO ejecuta `claude -p` ni tiene permisos de escritura en `wiki/`**: su único
   privilegio es crear archivos en `.raw/inbox/`. La ingesta (que sí escribe en el wiki)
   ocurre después, en el flujo normal del vault con sus propios permisos acotados.
4. Mantén el token del bot fuera del repo (variable de entorno en la máquina del gateway;
   el `.gitignore` ya bloquea `.env` y credenciales por si acaso).

## Por qué este diseño

Separar "recibir" (bot, expuesto a internet, sin privilegios) de "ingerir" (vault, con
privilegios, sin exposición) limita el daño de un mensaje malicioso o un bot comprometido:
lo peor que puede pasar es basura en la bandeja, que `/inbox` descarta y reporta.
