@echo off
setlocal
cd /d "%~dp0"
echo Instalador del actualizador de UT2004
echo Para un repositorio privado, cada amigo necesita acceso de lectura en GitHub.
set "PRIVATE="
set /p "PRIVATE=El repositorio es privado? [s/N]: "
if /i "%PRIVATE%"=="s" (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-Updater.ps1" -PrivateRepository
) else (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-Updater.ps1"
)
if errorlevel 1 echo No se pudo instalar. Revisa el mensaje de arriba.
pause
