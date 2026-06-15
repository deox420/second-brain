# Sincronización entre dispositivos (Windows + Arch Linux + Android)

Objetivo: que el vault esté **igual en los tres sitios**, usando **git con GitHub como única
fuente de verdad** (gratis, sin servicios extra). El móvil consulta y captura; el procesado
pesado (ingesta, radar, `/autoresearch`) vive en el ordenador.

## Modelo y roles

```
                         ┌──────────────────────┐
            push/pull     │   GitHub (origin)    │     push/pull
        ┌───────────────►│  deox420/second-brain │◄───────────────┐
        │                 └──────────┬───────────┘                 │
        │                            │ push (radar) dispara         │
        │                            ▼ rebuild web (Vercel)         │
┌───────┴────────┐         ┌─────────────────┐            ┌────────┴────────┐
│ Arch (portátil)│         │  Sitio web       │            │ Android (móvil) │
│ HOST CEREBRO   │         │  (solo lectura)  │            │ Obsidian +      │
│ Claude Code,   │         └─────────────────┘            │ obsidian-git    │
│ cron, bin/sync │                                         │ (pull/push)     │
└────────────────┘                                         └─────────────────┘
        ▲
        │ push/pull (Obsidian-git o bin/sync.sh)
┌───────┴────────┐
│ Windows (PC)   │
│ Obsidian +     │
│ obsidian-git   │
└────────────────┘
```

| Dispositivo | Rol | Cómo sincroniza |
|-------------|-----|-----------------|
| **Arch (portátil)** | **Host cerebro.** Corre Claude Code, el cron de noticias y la bandeja. | `bin/sync.sh` (lo llama el cron) + git nativo. |
| **Windows** | Lectura y edición. Opcionalmente segundo host (vía WSL2). | Plugin *obsidian-git* en Obsidian, o `bin/sync.sh` en WSL/Git Bash. |
| **Android** | Captura (`.raw/inbox/`) y consulta. | Plugin *obsidian-git* en Obsidian móvil. |

> Regla de oro: **un solo dispositivo escribe a la vez.** Edita en uno, deja que sincronice, y
> entonces sigue en otro. Git resuelve la mayoría de choques con rebase, pero editar la misma
> nota en dos sitios sin sincronizar entremedias es la única forma fiable de crear conflictos.

---

## 1. Autenticación (una vez por dispositivo)

GitHub ya no acepta contraseña; necesitas **clave SSH** (ordenadores) o **token** (móvil).

### Arch y Windows — clave SSH (recomendado)
```bash
ssh-keygen -t ed25519 -C "tu-correo"          # Enter en todo
cat ~/.ssh/id_ed25519.pub                       # copia esto
# Pégalo en GitHub → Settings → SSH and GPG keys → New SSH key
ssh -T git@github.com                            # debe saludar con tu usuario
```
Cambia el remoto a SSH (en cada ordenador, dentro del repo):
```bash
git remote set-url origin git@github.com:deox420/second-brain.git
```
En **Windows** lo más cómodo es **WSL2** (Ubuntu): ahí tienes git, bash, python3 y cron reales,
y todos los scripts del repo (`bin/*.sh`, hooks) funcionan tal cual. Alternativa sin WSL:
**Git Bash** para los scripts y el **Programador de tareas** en vez de `cron`.

### Android — token de acceso personal (PAT)
El plugin obsidian-git usa HTTPS + token:
1. GitHub → Settings → Developer settings → **Fine-grained tokens** → *Generate*.
2. Repository access: **Only select repositories → second-brain**.
3. Permisos: **Contents: Read and write**. Caduca a tu gusto (renuévalo cuando toque).
4. Copia el token (empieza por `github_pat_…`); lo pegarás en obsidian-git como contraseña.

---

## 2. Arch (host cerebro)

Es el ordenador que hace el trabajo. Ya tienes el repo clonado. Solo asegura el flujo:

1. **Permisos headless del cron** (si no lo hiciste): `cp .claude/settings.json.example .claude/settings.json`.
2. **Programa el cron** (ver README). El cron, al terminar de procesar el radar, llama solo a
   `bin/sync.sh`, que hace `commit + pull --rebase + push`. Así el radar de la mañana llega a
   Windows y al móvil y dispara el rebuild de la web.
3. **Sincroniza a mano** cuando quieras: `bash bin/sync.sh`.

Alternativa a `cron`: un *timer* de systemd (sobrevive mejor a suspensión del portátil):
```ini
# ~/.config/systemd/user/second-brain-news.service
[Service]
Type=oneshot
WorkingDirectory=%h/ruta/al/vault
ExecStart=/usr/bin/bash bin/cron-news-ingest.sh

# ~/.config/systemd/user/second-brain-news.timer
[Timer]
OnCalendar=*-*-* 07:30:00
Persistent=true
[Install]
WantedBy=timers.target
```
```bash
systemctl --user enable --now second-brain-news.timer
```
(`Persistent=true` lo lanza al despertar si la hora pasó con el portátil suspendido.)

---

## 3. Windows

1. **Obsidian:** instálalo, *Open folder as vault* sobre el repo clonado.
2. **Plugin obsidian-git:** Settings → Community plugins → Browse → *Obsidian Git* → Install → Enable.
3. **Ajustes recomendados del plugin** (Settings → Obsidian Git):
   - **Auto pull on startup:** ON (trae lo último al abrir).
   - **Pull updates on startup / Pull before push:** ON.
   - **Auto commit-and-sync interval:** p. ej. 10 min (0 = desactivado).
   - **Commit-and-sync** = add + commit + push en un paso.
4. **Si prefieres scripts** (WSL/Git Bash): `bash bin/sync.sh` hace lo mismo desde la terminal.

> En Windows, no edites notas a la vez en Obsidian (que auto-pushea) y en la terminal. Elige un
> canal por sesión.

---

## 4. Android

1. Instala **Obsidian** desde Play Store.
2. Instala el plugin **Obsidian Git** (Community plugins).
3. **Clona el repo** desde el plugin: comando *Obsidian Git: Clone an existing remote repo* →
   URL `https://github.com/deox420/second-brain.git` → usuario `deox420` → contraseña = el **PAT**.
4. **Ajustes** (igual que en Windows): auto pull on startup ON, pull before push ON, commit-and-sync
   cada 10-15 min o manual con el botón de sincronizar.
5. **Capturar sin ordenador:** crea/comparte notas dentro de `.raw/inbox/` (ver
   [captura-movil.md](captura-movil.md)). El host las procesa luego con `/inbox`.

> `.obsidian/workspace-mobile.json` está en `.gitignore`: el layout del móvil no pelea con el del
> escritorio.

---

## 5. Finales de línea (Windows ↔ Linux)

El repo trae **`.gitattributes`** con `* text=auto eol=lf`: todo se guarda con saltos de línea
LF sin importar el SO. Esto evita dos problemas clásicos:
- Que Windows convierta los `.sh`/`.py` a CRLF y **rompa el shebang/bash** en Arch.
- Diffs gigantes "fantasma" donde cambia el archivo entero solo por los saltos de línea.

No tienes que hacer nada: con clonar ya aplica. (Si clonaste antes de existir el archivo:
`git add --renormalize . && git commit -m "normaliza saltos de línea"`.)

---

## 6. Conflictos: cómo evitarlos y cómo salir

**Evitar (90% del trabajo):**
- Un dispositivo escribe a la vez. Sincroniza antes de cambiar de aparato.
- Deja que `bin/sync.sh` / obsidian-git terminen antes de seguir editando.

**Si aparece un conflicto** (rebase parado):
```bash
git status                       # ver qué archivo choca
# edita el archivo, quédate con la versión buena (quita <<<<, ====, >>>>)
git add <archivo>
git rebase --continue
git push origin <rama>
```
`bin/sync.sh` **aborta el rebase solo** si no puede integrar limpio (no deja el repo a medias):
te avisa y te toca resolverlo a mano con el comando de arriba.

### Aviso sobre `.obsidian/workspace.json`
Ese archivo (el layout de paneles del escritorio) **se versiona a propósito** para traer la
vista de grafo preconfigurada, pero **cambia cada vez que mueves un panel**, así que con varios
escritorios puede generar conflictos menores. Si te molesta, deja de versionarlo (no pierdes el
grafo, ya está configurado en tu Obsidian):
```bash
git rm --cached .obsidian/workspace.json
echo ".obsidian/workspace.json" >> .gitignore
git commit -m "no versionar workspace.json (evita conflictos multi-dispositivo)"
```

---

## 7. Cómo encajan todas las piezas

1. **07:30 (Arch):** el cron recoge RSS → `claude -p` escribe el radar en `wiki/sources/news/` →
   `bin/sync.sh` hace commit + pull --rebase + **push**.
2. **GitHub** recibe el push → **Vercel** reconstruye el sitio → la nota del día se publica sola.
3. **Windows y Android:** al abrir Obsidian, obsidian-git hace *pull* y ves el radar nuevo.
4. **Tú capturas** algo en el móvil dentro de `.raw/inbox/` → obsidian-git lo empuja → en la
   siguiente sesión en Arch, `/inbox` lo ingiere y `bin/sync.sh` lo devuelve sincronizado.

## 8. Verificación rápida
- En Arch: `bash bin/sync.sh` termina con `push OK`.
- En Windows/Android: abre Obsidian y comprueba que aparece el último cambio del host.
- Crea una nota de prueba en un dispositivo, sincroniza, y míra que aparece en los otros dos.
- Edita un `.sh` en Windows, sincroniza, y en Arch `bash -n ese.sh` no se queja (finales LF OK).
