[CmdletBinding()]
param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot 'config.json'),
    [switch]$Once,
    [switch]$Diagnose
)
. "$PSScriptRoot/Update.Common.ps1"
$config = Read-UpdateJson $ConfigPath
$statePath = Split-Path ([IO.Path]::GetFullPath($ConfigPath)) -Parent
if ($Diagnose) {
    Get-RadminUpdateState $config.AdapterPattern | ConvertTo-Json -Depth 5
    return
}
if (-not (Test-Path -LiteralPath (Join-Path $config.GamePath 'System/UT2004.exe') -PathType Leaf)) {
    throw 'GamePath debe apuntar a la raiz de UT2004 (con System/UT2004.exe).'
}
function Write-UpdateLog([string]$Message) {
    $logPath = Join-Path $statePath 'updater.log'
    if ((Test-Path -LiteralPath $logPath) -and (Get-Item -LiteralPath $logPath).Length -gt 1MB) {
        Move-Item -LiteralPath $logPath -Destination "$logPath.1" -Force
    }
    $line = "[$([DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss'))] $Message"
    Add-Content -LiteralPath $logPath -Value $line -Encoding UTF8
    Write-Host $line
}
$lock = $null
try { $lock = [IO.File]::Open((Join-Path $statePath 'agent.lock'), [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None) }
catch [IO.IOException] { Write-Host 'El actualizador ya esta ejecutandose.'; return }
try {
    $nextCheck = [DateTime]::MinValue
    $wasReady = $false
    $lastStatus = ''
    do {
        try {
            $vpn = Get-RadminUpdateState $config.AdapterPattern
            if (-not $vpn.Ready) {
                if ($lastStatus -ne 'WaitingVpn') { Write-UpdateLog 'Esperando el adaptador Radmin activo con IPv4.'; $lastStatus = 'WaitingVpn' }
                $nextCheck = [DateTime]::MinValue
            } elseif (-not $wasReady -or [DateTime]::UtcNow -ge $nextCheck -or $Once) {
                $result = Invoke-UTUpdate $config $statePath
                if ($result -ne $lastStatus) {
                    $message = switch ($result) {
                        'Current' { 'Ya esta instalada la ultima version.' }
                        'Deferred' { 'Actualizacion descargada. Esperando que cierres UT2004 para instalarla.' }
                        'Installed' { 'Actualizacion instalada. Ya podes abrir UT2004.' }
                    }
                    Write-UpdateLog $message
                    $lastStatus = $result
                }
                $nextCheck = [DateTime]::UtcNow.AddSeconds([int]$config.CheckSeconds)
            }
            $wasReady = $vpn.Ready
        } catch {
            # Do not log HTTP request headers or tokens.
            Write-UpdateLog ("No se pudo actualizar; se reintentara: " + $_.Exception.Message)
            $lastStatus = 'Error'
            $wasReady = $true
            $nextCheck = [DateTime]::UtcNow.AddSeconds([int]$config.CheckSeconds)
            if ($Once) { throw }
        }
        if (-not $Once) { Start-Sleep -Seconds ([int]$config.PollSeconds) }
    } while (-not $Once)
} finally { $lock.Dispose() }
