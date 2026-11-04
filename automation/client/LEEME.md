# Actualizador de UT2004 para los amigos

Una sola vez: descomprimí **todo** `UT2004-updater.zip`, ejecutá `Instalar.cmd` e indicá la carpeta raíz del juego (por ejemplo `C:\Games\UT2004`, donde está `System`). Usá tu usuario habitual de Windows. La carpeta del juego debe permitirte escribir sin elevar permisos.

Si el repositorio es privado, respondé `s`: necesitás acceso al repositorio y un token **propio**, de tipo fine-grained, limitado a ese repositorio y con `Contents: read`. El instalador lo pide oculto y Windows lo cifra para tu usuario y tu PC. Nunca pegues el token en un archivo del repositorio ni lo compartas. Si vence, ejecutá otra vez el instalador.

Después, el actualizador arranca solo al iniciar tu sesión de Windows. Comprueba cada 30 segundos si el servicio y el adaptador de Radmin están activos y tienen IPv4. En ese momento busca la última actualización en GitHub; mientras Radmin siga activo, vuelve a consultar cada 5 minutos. No necesitás Git, Git LFS ni una PC host.

Radmin funciona como condición para descargar. **Los archivos vienen de GitHub por HTTPS**, por tu conexión a Internet. Abrir o cerrar la ventana de Radmin no necesariamente conecta o desconecta su servicio. Esta primera versión detecta el estado de Windows del adaptador; no puede confirmar que ingresaste a una red específica de Radmin. Probá una vez el botón de encendido y el diagnóstico de abajo en tu PC. Si el driver deja el adaptador activo aun con el botón apagado, esa detección requiere un ajuste antes de usarlo como disparador exacto.

Si UT2004 está abierto, puede descargar el paquete, pero espera para instalarlo hasta una nueva comprobación con el juego cerrado (hasta 5 minutos). Cerrá también cualquier servidor dedicado o compilador `ucc`.

Cada actualización contiene la versión completa de los mods: si estuviste varios días sin conectarte, instalás directamente la última. Se verifica SHA-256 y se guardan backups de los archivos reemplazados. No se borran archivos viejos del juego ni se cambian tus `User.ini` o `UT2004.ini`. Una instalación fallida intenta restaurar los archivos anteriores. Si abrís el juego justo durante la copia, Windows puede rechazar su apertura: esperá el mensaje de instalación terminada antes de volver a abrirlo.

Estado y diagnóstico, desde PowerShell:

```powershell
Get-Content "$env:LOCALAPPDATA\UT2004Updater\updater.log" -Tail 20
& "$env:LOCALAPPDATA\UT2004Updater\Start-Update.ps1" -Diagnose
Get-Content "$env:LOCALAPPDATA\UT2004Updater\installed.json"
```

Para hacer una comprobación manual, primero detené la tarea; la opción `-Once` también respeta Radmin:

```powershell
$task = Get-ScheduledTask -TaskName 'UT2004-Mod-Updater-*' | Where-Object TaskName -like "*$([Security.Principal.WindowsIdentity]::GetCurrent().User.Value)"
$task | Stop-ScheduledTask
& "$env:LOCALAPPDATA\UT2004Updater\Start-Update.ps1" -Once
$task | Start-ScheduledTask
```

Sin Internet, permisos de GitHub o una primera release publicada, queda esperando y registra el error para volver a intentar. No muestra una ventana emergente: mirá `updater.log` antes de la primera partida. Una PC ya configurada descarga sola; cada usuario instala el agente una sola vez.

Para desinstalar:

```powershell
& "$env:LOCALAPPDATA\UT2004Updater\Uninstall-Updater.ps1"
```

El desinstalador detiene la tarea. Podés borrar `%LOCALAPPDATA%\UT2004Updater` después; ahí quedan el token cifrado, los backups y la caché. Las descargas y backups se conservan, así que conviene revisar su espacio periódicamente. Esta versión configura una instalación de UT2004 por usuario de Windows; reinstalar cambia la carpeta y el repositorio para ese usuario.
