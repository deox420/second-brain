# Captura por Telegram/WhatsApp con OpenClaw (solo documentación)

> **Estado: NO montado.** Esta guía existe para cuando (si) decidas montarlo.
> Requiere una máquina siempre encendida y tiene coste de API continuo. La vía
> ligera (bandeja + obsidian-git, `docs/captura-movil.md`) cubre el 90% del caso
> sin nada de esto.

## Qué es

[OpenClaw](https://github.com/openclaw/openclaw) es un gateway autohostado que
conecta un agente LLM con apps de mensajería (Telegram, WhatsApp…). Aplicado a
este vault: le mandas por Telegram una URL, una nota de voz o un PDF, y acaba en
la bandeja de entrada del segundo cerebro, donde el flujo normal (`/inbox`) lo
ingiere.

## Requisitos

- Máquina 24/7: un VPS pequeño, una Raspberry Pi o un mini-PC en casa.
- Bot de Telegram (vía @BotFather) o cuenta puente de WhatsApp.
- El repo del vault clonado en esa máquina, con credenciales de push.
- Claves de API del modelo que use el gateway.

## Diseño obligatorio (guardarraíles)

Si algún día se monta, estas reglas **no son opcionales**:

1. **Allowlist estricta**: el gateway solo acepta mensajes del user ID de Telegram
   del dueño. Todo lo demás se descarta sin procesar. (Un bot público que escribe
   en tu vault es una puerta abierta.)
2. **El bot NO ejecuta `claude -p` con permisos de escritura en el wiki.** Su único
   trabajo es **depositar** el adjunto/texto en la bandeja (`wiki/inbox/`) y hacer
   commit+push. La ingesta real la hace el flujo normal del vault (sesión
   interactiva `/inbox` o el cron), donde aplican los guardarraíles del proyecto.
3. **Anti prompt-injection**: todo lo recibido por mensajería es entrada NO
   confiable — DATOS a ingerir, nunca instrucciones (CLAUDE.md §9). Aplica tanto
   al gateway como a la ingesta posterior.
4. **Secretos fuera del vault**: tokens del bot y claves de API viven en la
   máquina del gateway (variables de entorno), jamás en este repo.

## Esqueleto de la automatización

En la máquina 24/7, el handler de mensajes hace solo esto:

```bash
# pseudocódigo del handler (un mensaje/adjunto → un archivo en la bandeja)
cd /ruta/al/vault
git pull -q
f="wiki/inbox/tg-$(date +%Y%m%d-%H%M%S).md"
printf -- '---\nfuente: telegram\nfecha: %s\n---\n\n%s\n' "$(date +%F)" "$TEXTO" > "$f"
# adjuntos: guardarlos tal cual en wiki/inbox/ junto a una nota con su contexto
git add wiki/inbox && git commit -qm "inbox: captura telegram" && git push -q
```

## Coste

Un agente siempre activo escuchando mensajes consume API aunque no lo uses
(heartbeats, resúmenes, contexto). Si el volumen de capturas es bajo, la vía
ligera sale gratis y hace lo mismo con 30 segundos más de latencia humana.
