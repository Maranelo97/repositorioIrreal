# Actualizaciones de UT2004 al activar Radmin

El objetivo es publicar los archivos compilados al pushear a `production`, y que cada amigo los descargue automáticamente cuando su PC tenga Radmin activo. **No hay PC host de distribución ni servidor dedicado.**

GitHub conserva una release completa. Un agente en cada PC compara la última release con su estado local. Si estuvo apagada durante varias publicaciones, instala directamente la última, sin tener que reproducir cada actualización intermedia. Eso implementa la actualización pendiente; no es un job de GitHub esperando a que un amigo se conecte.

Radmin es el disparador local. Los paquetes se descargan de GitHub mediante HTTPS, por Internet. No pasan por el túnel Radmin: transferirlos por ese túnel requeriría que otra PC conectada sirviera los archivos. Esta implementación no necesita esa dependencia.

## Qué hace cada parte

- `.github/workflows/publish-production.yml`: se activa con push a `production` o `Production`. Usen una sola de las dos ramas. Valida los scripts, empaqueta y publica una release con tres adjuntos. También admite ejecución manual desde esa rama.
- `automation/Build-Update.ps1`: prepara ZIP completo, manifiesto SHA-256 e instalador para los amigos. Trabaja con archivos ya compilados; no compila UnrealScript.
- `automation/client/Start-Update.ps1`: agente de Windows que espera Radmin, busca novedades y aplica el paquete con UT2004 cerrado.
- `automation/client/Install-Updater.ps1`: instala el agente como tarea al iniciar la sesión del usuario, sin pedir una contraseña de Windows ni configurar un servicio elevado.

El workflow usa el `GITHUB_TOKEN` de Actions con `contents: write`; no requiere un token personal para publicar. Se suben todos los adjuntos a una release en borrador antes de hacerla visible. Si ya existe un push más reciente antes de empezar a publicar, la ejecución anterior deja que ese push publique la versión actual.

## Preparación de quienes publican

El repositorio actual contiene fuentes y textos, pero **faltan `System/MyInvasionMut.u` y `System/MyInvasionMut.ucl`**. Compilarlos fuera de Actions, probarlos y agregar los cuatro archivos de la misma versión:

```text
System/MyInvasionMut.u
System/MyInvasionMut.ucl
System/MyInvasionMut.int
System/MyInvasionMut.est
```

Los dos archivos de idioma ya están en el repositorio y conservan sus bytes Latin-1. No se convierten al empaquetar ni al instalar. El empaquetado falla si falta un archivo obligatorio o si encuentra un puntero Git LFS sin descargar.

También se publican los archivos ubicados directamente en `Maps/*.ut2`, `Textures/*.utx`, `Sounds/*.uax`, `Animations/*.ukx`, `StaticMeshes/*.usx`, `Music/*.ogg` y `System/*.{u,ucl,int,est}`. La configuración `System/MyInvasionMut.ini` es opcional. Para distribuir configuraciones de otros mods, agregarlas explícitamente a `Test-UpdateGamePath` y actualizar los agentes. No subir una instalación completa del juego.

Quedan afuera fuentes `.uc`, documentación, ejecutables, scripts, `IrrealTest.*`, `User.ini`, `UT2004.ini` y demás archivos `.ini`. No se recorren subcarpetas de contenido.

Para probar antes de subir:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File automation/tests/Test-Update.ps1
./automation/Build-Update.ps1 -Version ut2004-local-1 -Commit (git rev-parse HEAD) -OutputPath build/local-1
```

La carpeta de salida debe estar vacía o no existir. Una vez agregados los compilados y los archivos de automatización, crear la rama si todavía no existe:

```powershell
git switch -c production
git add .
git commit -m "Configurar actualizaciones automaticas de UT2004"
git push -u origin production
```

Si la rama ya existe, usar su flujo habitual de merge/push; no recrearla. No hace falta cambiar la rama predeterminada `main`. En GitHub, habilitar Actions y permitir que el workflow publique releases según las políticas del repositorio. El primer push sin compilados fallará con un mensaje explícito y no publicará una actualización incompleta.

Git LFS puede usarse para archivos grandes. No se activa automáticamente ni se migra el historial. Antes de agregar un archivo grande por primera vez, instalar Git LFS y registrar las extensiones necesarias, por ejemplo `git lfs track "*.ut2" "*.utx" "*.uax" "*.ukx" "*.usx" "*.u"`. El checkout del workflow descarga LFS. Sus cuotas siguen siendo las de GitHub; esta solución distribuye las releases sin que cada amigo clone el repositorio.

## Configuración de los amigos

Compartir el enlace a Releases del repositorio. Cada amigo descarga **`UT2004-updater.zip`**, lo descomprime y ejecuta **`Instalar.cmd`** una vez. Ver las instrucciones completas en [client/LEEME.md](client/LEEME.md).

Con un repositorio privado, cada amigo necesita acceso de lectura y un token propio con `Contents: read`, limitado al repositorio. Se cifra con DPAPI mediante `Export-Clixml` y se guarda en `%LOCALAPPDATA%\UT2004Updater`. Un token de lectura no puede publicar cambios. No repartir el token del administrador. En un repositorio público, no se necesita token. El repositorio predeterminado es `Maranelo97/repositorioIrreal`; si cambia, usar `Install-Updater.ps1 -Repository propietario/repositorio`.

## Detección de Radmin y prueba real pendiente

La primera versión exige servicio `RvControlSvc` en ejecución y un adaptador cuyo nombre o descripción contenga `Radmin` o `Famatech`, con estado `Up` e IPv4 válida. Se consulta con las APIs de red de .NET y el servicio de Windows. No se hace ping a un administrador ni se depende de que un amigo esté conectado.

**No equivale a confirmar membresía o conectividad con una red específica de Radmin.** La GUI puede cerrarse dejando el servicio conectado. El estado del adaptador al usar el botón de encendido puede variar según el driver. Antes de dar por validado el disparador, ejecutar `Start-Update.ps1 -Diagnose` con Radmin encendido y apagado en una PC real. Si Windows informa `Up` en ambos casos, este detector necesita un ajuste: no se debe afirmar que reconoce el botón exacto. No se incluyen lecturas de protocolos o registro interno de Radmin sin una interfaz documentada.

Cada 30 segundos se observa la interfaz. Al pasar a activa se consulta GitHub enseguida; luego cada 5 minutos mientras esté activa. Los errores de red/autenticación se registran y vuelven a intentar. Una descarga interrumpida se reinicia; una descarga terminada se reutiliza. Si UT2004 está abierto, la instalación queda pendiente hasta una comprobación posterior con el juego cerrado. Los paquetes se verifican antes de tocar el juego y los destinos se bloquean durante la copia.

Para probar el ciclo real: publicar una versión de prueba válida, configurar una PC, activar Radmin, revisar `updater.log` y `installed.json`, y comprobar los SHA-256 de los cuatro archivos. Repetir con UT2004 abierto y con la PC desconectada durante dos publicaciones. Una vez que vuelva, debe instalar la última versión. El repositorio reserva la release marcada como **Latest** para este canal; publicar otra release ajena como Latest hace que el agente la rechace hasta restaurar una release UT2004.

## Alcance y práctica de redes

Esta base permite practicar detección de interfaces, IPv4, cliente/servidor HTTPS, publicación, reintentos y consistencia de archivos. Como siguiente etapa, puede agregarse una caché entre pares sobre las IPs Radmin: un amigo que ya descargó sirve el paquete y los demás lo verifican contra el manifiesto de GitHub. GitHub sigue siendo el origen disponible cuando no hay pares en línea. Esa capa requiere descubrimiento, autenticación, firewall y un servidor local en cada par; no está implementada en esta versión.

La actualización conserva archivos que dejaron de estar en la release y backups/caché de cada versión. No implementa eliminaciones remotas, descarga diferencial por archivo, autoactualización del agente ni un bloqueo del arranque del juego. Si cambia el agente, volver a ejecutar el instalador nuevo. El log es local y no hay panel central de quién instaló qué. El instalador no se ejecutó en las PCs de los amigos ni se publicó una release desde esta sesión.

## Referencias

- [Radmin VPN: red local virtual](https://www.radmin-vpn.com/)
- [Radmin: servicio, GUI y driver](https://radmin-club.com/radmin-vpn/installing-vpn-as-a-service/)
- [GitHub: descargar assets de una release y permisos de lectura](https://docs.github.com/en/rest/releases/assets#get-a-release-asset)
- [GitHub CLI: creación de releases](https://cli.github.com/manual/gh_release_create)
- [Microsoft: cifrado de credenciales con Export-Clixml](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/export-clixml)
