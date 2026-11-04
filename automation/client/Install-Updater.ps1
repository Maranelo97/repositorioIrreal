[CmdletBinding()]
param(
    [string]$GamePath,
    [ValidatePattern('^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$')][string]$Repository = 'Maranelo97/repositorioIrreal',
    [switch]$PrivateRepository,
    [ValidateRange(10, 300)][int]$PollSeconds = 30,
    [ValidateRange(120, 3600)][int]$CheckSeconds = 300
)
. "$PSScriptRoot/Update.Common.ps1"
if (-not $GamePath) { $GamePath = (Read-Host 'Carpeta raiz de UT2004 (por ejemplo C:\Games\UT2004)').Trim('"') }
$GamePath = (Resolve-Path -LiteralPath $GamePath).Path
if (-not (Test-Path -LiteralPath (Join-Path $GamePath 'System/UT2004.exe') -PathType Leaf)) {
    throw 'No se encontro System/UT2004.exe en esa carpeta.'
}
# Check write access as the current user, without changing game files.
$probe = Join-Path (Join-Path $GamePath 'System') ([guid]::NewGuid().ToString('N') + '.tmp')
try { [IO.File]::WriteAllText($probe, '') } finally { if (Test-Path -LiteralPath $probe) { Remove-Item -LiteralPath $probe } }
$installPath = Join-Path $env:LOCALAPPDATA 'UT2004Updater'
New-Item -ItemType Directory -Path $installPath -Force | Out-Null
$taskName = 'UT2004-Mod-Updater-' + [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
$existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($existing) { Stop-ScheduledTask -TaskName $taskName }
foreach ($name in @('Update.Common.ps1', 'Start-Update.ps1', 'Uninstall-Updater.ps1')) {
    $source = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot $name))
    $target = Join-Path $installPath $name
    if ($source -ine $target) { Copy-Item -LiteralPath $source -Destination $target -Force }
}
Write-UpdateJson (Join-Path $installPath 'config.json') ([ordered]@{
    Repository = $Repository; GamePath = $GamePath; PollSeconds = $PollSeconds
    CheckSeconds = $CheckSeconds; AdapterPattern = 'Radmin|Famatech'
})
if ($PrivateRepository) {
    $secureToken = Read-Host 'Token propio de GitHub, solo Contents: read para este repositorio' -AsSecureString
    [pscredential]::new('github', $secureToken) | Export-Clixml -LiteralPath (Join-Path $installPath 'github-token.clixml')
}
$identity = [Security.Principal.WindowsIdentity]::GetCurrent().Name
$powershell = Join-Path $env:WINDIR 'System32/WindowsPowerShell/v1.0/powershell.exe'
$arguments = '-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + (Join-Path $installPath 'Start-Update.ps1') + '"'
$action = New-ScheduledTaskAction -Execute $powershell -Argument $arguments -WorkingDirectory $installPath
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $identity
$principal = New-ScheduledTaskPrincipal -UserId $identity -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -ExecutionTimeLimit ([TimeSpan]::Zero) `
    -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable `
    -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
Start-ScheduledTask -TaskName $taskName
Write-Host "Instalado. Se inicia con tu sesion de Windows. Estado y registros: $installPath"
Write-Host 'No se aplican actualizaciones mientras UT2004 este abierto.'
