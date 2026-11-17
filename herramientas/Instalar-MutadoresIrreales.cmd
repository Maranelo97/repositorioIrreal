@echo off
setlocal
if not exist "%~dp0Instalar-MutadoresIrreales.ps1" (
    echo Falta Instalar-MutadoresIrreales.ps1 al lado de este archivo.
    echo Extraer el zip completo a una carpeta y volver a abrir este archivo desde ahi.
    pause
    exit /b 1
)
rem Doble clic (sin argumentos): abre la ventana del instalador y cierra esta consola.
if "%~1"=="" (
    start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "%~dp0Instalar-MutadoresIrreales.ps1"
    exit /b 0
)
rem Con argumentos (por ejemplo -Consola): el instalador en esta consola.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Instalar-MutadoresIrreales.ps1" %*
if errorlevel 1 echo No se completo la instalacion. Revisa el mensaje de arriba.
pause
