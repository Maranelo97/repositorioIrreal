[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$taskName = 'UT2004-Mod-Updater-' + [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
    Stop-ScheduledTask -TaskName $taskName
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
}
Write-Host 'Actualizador detenido y tarea eliminada. Los archivos del juego no se modificaron.'
Write-Host 'Las credenciales, descargas y backups siguen en %LOCALAPPDATA%\UT2004Updater; podes borrar esa carpeta.'
