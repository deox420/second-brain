# Instalación en Windows (WSL2)

Guía para poner en marcha el segundo cerebro en Windows usando **WSL2 (Ubuntu)**.
Es la vía recomendada: todos los scripts (`bash` + `python3`), los hooks de Claude Code
y el cron de noticias funcionan **sin cambios**, porque corren dentro de Linux.

> Idea clave: **Obsidian** se ejecuta en Windows (app nativa), pero **Claude Code y los
> scripts se ejecutan dentro de WSL**, donde vive el vault. Obsidian accede al vault a
> través de la ruta de red de WSL (`\\wsl.localhost\...`).

---

## 1. Instalar WSL2 + Ubuntu

Abre **PowerShell como administrador** y ejecuta:

```powershell
wsl --install -d Ubuntu
```

Reinicia si te lo pide. Al abrir Ubuntu por primera vez, crea tu usuario y contraseña de Linux.

Comprueba que es WSL **2** (no 1):

```powershell
wsl -l -v
```

Si la versión es 1, conviértela:

```powershell
wsl --set-version Ubuntu 2
```

---

## 2. Dependencias dentro de Ubuntu

Todo lo siguiente se ejecuta **dentro de la terminal de Ubuntu** (no en PowerShell).

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y git curl python3 cron
```

Instala **Node.js** (necesario para Claude Code CLI). Lo más limpio es con `nvm`:

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
# cierra y reabre la terminal, o:  source ~/.bashrc
nvm install --lts
```

Instala **Claude Code**:

```bash
npm install -g @anthropic-ai/claude-code
claude --version   # verifica que 'claude' está en el PATH
```

---

## 3. Clonar el vault (dentro del sistema de archivos de WSL)

Clónalo en tu **home de Linux** (`~`), **no** en `/mnt/c/...`. El sistema de archivos de
Linux es mucho más rápido para git/scripts y evita problemas de saltos de línea.

```bash
cd ~
git clone https://github.com/deox420/second-brain
cd second-brain
```

Prepara el vault y los permisos mínimos del cron headless:

```bash
bash bin/setup-vault.sh
cp .claude/settings.json.example .claude/settings.json
```

---

## 4. Abrir el vault en Obsidian (desde Windows)

1. Instala **Obsidian** en Windows desde [obsidian.md](https://obsidian.md).
2. En Obsidian: **Manage Vaults → Open folder as vault**.
3. En el selector de carpeta, pega esta ruta (ajusta el usuario de Linux):

   ```
   \\wsl.localhost\Ubuntu\home\TU_USUARIO\second-brain
   ```

   (En versiones antiguas de Windows: `\\wsl$\Ubuntu\home\TU_USUARIO\second-brain`.)

4. Habilita los plugins de la comunidad cuando lo pida. Recomendados:
   **Dataview**, **Templater**, **Obsidian Git**.

> Para saber tu usuario y ruta exacta, en Ubuntu ejecuta:  `echo \\\\wsl.localhost\\Ubuntu$(pwd | sed 's:/:\\:g')`

> Nota: el aviso de cambios de archivos a través de la frontera WSL↔Windows puede tardar
> un par de segundos en reflejarse en Obsidian. Es normal.

---

## 5. Usar Claude Code

Ejecuta Claude Code **siempre desde dentro de Ubuntu**, en la carpeta del vault:

```bash
cd ~/second-brain
claude
```

Así los hooks (`hooks/hooks.json`, que usan sintaxis POSIX) y los scripts funcionan tal cual.
No lances `claude` desde PowerShell para este vault.

Comandos del día a día: `/wiki`, `/news`, `ingest [archivo]`, `¿qué sé de X?`.

---

## 6. Personalizar antes del primer radar de noticias

```bash
# Edita tus temas de interés (el filtro de qué noticia entra):
#   CLAUDE.md §7
# Activa/edita tus fuentes RSS y verifica que responden:
bash bin/check-feeds.sh
```

---

## 7. Automatizar el radar diario (cron en WSL2)

En WSL2 el demonio cron **no arranca solo**. Hazlo persistente con systemd:

1. Edita `/etc/wsl.conf`:

   ```bash
   sudo nano /etc/wsl.conf
   ```

   Añade:

   ```ini
   [boot]
   systemd=true
   ```

2. Desde **PowerShell**, reinicia WSL para aplicarlo:

   ```powershell
   wsl --shutdown
   ```

   Reabre Ubuntu y activa cron:

   ```bash
   sudo systemctl enable --now cron
   ```

   > Alternativa sin systemd: en `/etc/wsl.conf` usa `command="service cron start"` bajo
   > `[boot]`, o arranca cron a mano en cada sesión con `sudo service cron start`.

3. Instala las tareas programadas del segundo cerebro (idempotente):

   ```bash
   bash bin/install-cron.sh
   ```

   Esto programa:
   - **Radar diario** de noticias a las 07:30.
   - **Lint semanal** del vault los domingos a las 08:00.
   - **Radar semanal** de noticias los domingos a las 08:30.

   Comprueba con `crontab -l`. Para ver qué instalaría sin tocar nada: `bash bin/install-cron.sh --show`.
   Para quitarlo: `bash bin/install-cron.sh --remove`.

   Puedes cambiar las horas con variables de entorno, p. ej.:
   ```bash
   NEWS_TIME="0 9 * * *" bash bin/install-cron.sh
   ```

> Importante: el cron solo se ejecuta mientras WSL esté **en marcha**. Con systemd activado,
> WSL arranca en segundo plano al iniciar sesión en Windows (o cuando abres cualquier terminal
> de Ubuntu). Si apagas el equipo por la noche, el radar de las 07:30 correrá cuando enciendas
> y WSL levante cron. Si quieres garantías de ejecución a una hora fija aunque WSL no esté
> abierto, usa el **Programador de tareas de Windows** lanzando
> `wsl -d Ubuntu -e bash -lc "cd ~/second-brain && bash bin/cron-news-ingest.sh"`.

---

## 8. Verificación rápida

```bash
# Recolecta noticias sin llamar a Claude (deja los crudos en .raw/news/<fecha>/):
NO_CLAUDE=1 bash bin/cron-news-ingest.sh

# Procesa el radar a mano:
claude -p "Procesa las noticias de hoy" --permission-mode acceptEdits
```

Si ambos funcionan, el segundo cerebro está listo en Windows.

---

## Problemas frecuentes

| Problema | Causa / arreglo |
|----------|-----------------|
| `claude: command not found` en cron | El cron usa un PATH mínimo. `install-cron.sh` ya envuelve los comandos en `bash -lc` para cargar tu PATH de login (nvm). Asegúrate de que `claude --version` funciona en una terminal nueva. |
| El cron no se ejecuta nunca | El demonio cron no está corriendo. Ver §7 (systemd o `sudo service cron start`). Confírmalo con `pgrep -x cron`. |
| Obsidian no ve los cambios al instante | Latencia normal del puente WSL↔Windows. Espera unos segundos o recarga. |
| Scripts lentos o errores raros de saltos de línea | Clonaste en `/mnt/c/...`. Clona en `~` (home de Linux). Ver §3. |
| `wsl --install` falla | Actualiza Windows, habilita virtualización en la BIOS, o instala WSL desde Microsoft Store. |
