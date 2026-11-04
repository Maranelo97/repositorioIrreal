# Compatible with Windows PowerShell 5.1. Keep this file ASCII.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.IO.Compression

function Write-UpdateJson {
    param([string]$Path, $Value)
    $temporary = "$Path.$([guid]::NewGuid().ToString('N')).tmp"
    try {
        [IO.File]::WriteAllText($temporary, ($Value | ConvertTo-Json -Depth 12), [Text.UTF8Encoding]::new($false))
        if ([IO.File]::Exists($Path)) { [IO.File]::Replace($temporary, $Path, [NullString]::Value) }
        else { [IO.File]::Move($temporary, $Path) }
    } finally {
        if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force }
    }
}

function Read-UpdateJson {
    param([string]$Path)
    Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Test-UpdateGamePath {
    param([string]$Path)
    # Only game data, never programs, personal settings or the test mutator.
    $parts = $Path.Split('/')
    if ($parts.Count -ne 2) { return $false }
    $name = $parts[1]
    if ($name -match '[\\/:*?"<>|\x00-\x1f]' -or $name -match '[. ]$' -or
        $name -match '^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])\.' -or $name -match '^IrrealTest\.') { return $false }
    $extensions = @{
        System = @('.u', '.ucl', '.int', '.est')
        Maps = @('.ut2'); Textures = @('.utx'); Sounds = @('.uax')
        Animations = @('.ukx'); StaticMeshes = @('.usx'); Music = @('.ogg')
    }
    if ($Path -ieq 'System/MyInvasionMut.ini') { return $true }
    return ($extensions.ContainsKey($parts[0]) -and [IO.Path]::GetExtension($name) -in $extensions[$parts[0]])
}

function Get-UpdateGameFile {
    param([string]$GamePath, [string]$RelativePath)
    if (-not (Test-UpdateGamePath $RelativePath)) { throw "Ruta de juego no permitida: $RelativePath" }
    $target = Join-Path $GamePath ($RelativePath.Replace('/', [IO.Path]::DirectorySeparatorChar))
    foreach ($path in @((Split-Path $target -Parent), $target)) {
        if (Test-Path -LiteralPath $path) {
            if ((Get-Item -LiteralPath $path -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
                throw "No se actualizan enlaces o junctions: $path"
            }
        }
    }
    return $target
}

function Get-RadminUpdateState {
    param([string]$AdapterPattern = 'Radmin|Famatech')
    $service = Get-Service -Name RvControlSvc -ErrorAction SilentlyContinue
    $adapters = @([Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces() | Where-Object {
        $_.Name -match $AdapterPattern -or $_.Description -match $AdapterPattern
    } | ForEach-Object {
        $addresses = @($_.GetIPProperties().UnicastAddresses | Where-Object {
            $_.Address.AddressFamily -eq [Net.Sockets.AddressFamily]::InterNetwork -and
            $_.Address.ToString() -notmatch '^(0\.|127\.|169\.254\.)'
        } | ForEach-Object { $_.Address.ToString() })
        [pscustomobject]@{ Name = $_.Name; Status = $_.OperationalStatus.ToString(); IPv4 = $addresses }
    })
    $serviceRunning = $null -ne $service -and $service.Status -eq 'Running'
    [pscustomobject]@{
        Ready = ($serviceRunning -and @($adapters | Where-Object { $_.Status -eq 'Up' -and $_.IPv4.Count -gt 0 }).Count -gt 0)
        ServiceRunning = $serviceRunning
        Adapters = $adapters
    }
}

function Test-UTGameRunning {
    return @((Get-Process -ErrorAction Stop) | Where-Object { $_.ProcessName -match '^(ut2004|ucc)($|[-.])' }).Count -gt 0
}

function Get-UpdateHeaders {
    param([string]$StatePath, [string]$Accept = 'application/vnd.github+json')
    $headers = @{ Accept = $Accept; 'User-Agent' = 'UT2004-Friends-Updater'; 'X-GitHub-Api-Version' = '2022-11-28' }
    $token = $env:UT2004_GITHUB_TOKEN
    $credentialPath = Join-Path $StatePath 'github-token.clixml'
    if (-not $token -and (Test-Path -LiteralPath $credentialPath)) {
        $credential = Import-Clixml -LiteralPath $credentialPath
        $token = $credential.GetNetworkCredential().Password
    }
    if ($token) { $headers.Authorization = "Bearer $token" }
    return $headers
}

function Get-UpdateRelease {
    param([string]$Repository, [string]$StatePath)
    if ($Repository -notmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') { throw 'Repositorio invalido; usar propietario/repositorio.' }
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-RestMethod -Uri "https://api.github.com/repos/$Repository/releases/latest" `
        -Headers (Get-UpdateHeaders $StatePath) -TimeoutSec 60 -UseBasicParsing
}

function Save-UpdateAsset {
    param([string]$Repository, [string]$StatePath, $Asset, [string]$Destination)
    if ([long]$Asset.id -le 0) { throw 'ID de archivo invalido.' }
    # Construct the API URL ourselves. Never send credentials to a URL from a manifest.
    Invoke-WebRequest -Uri "https://api.github.com/repos/$Repository/releases/assets/$($Asset.id)" `
        -Headers (Get-UpdateHeaders $StatePath 'application/octet-stream') `
        -OutFile $Destination -TimeoutSec 1800 -UseBasicParsing | Out-Null
}

function Assert-UpdateManifest {
    param($Manifest)
    if ($Manifest.schema -ne 1 -or $Manifest.version -notmatch '^ut2004-[A-Za-z0-9.-]+$' -or
        $Manifest.archive -cne 'UT2004-update.zip' -or $Manifest.sha256 -notmatch '^[a-fA-F0-9]{64}$') {
        throw 'Formato de manifiesto no compatible.'
    }
    $files = @($Manifest.files)
    if ($files.Count -lt 4 -or $files.Count -gt 10000) { throw 'Cantidad de archivos invalida.' }
    $seen = @{}
    foreach ($file in $files) {
        if (-not (Test-UpdateGamePath $file.path) -or $seen.ContainsKey($file.path) -or
            $file.sha256 -notmatch '^[a-fA-F0-9]{64}$' -or [long]$file.size -le 0) {
            throw "Entrada de manifiesto invalida: $($file.path)"
        }
        $seen[$file.path] = $true
    }
    foreach ($extension in @('u', 'ucl', 'int', 'est')) {
        if (-not $seen.ContainsKey("System/MyInvasionMut.$extension")) { throw "Falta MyInvasionMut.$extension en el paquete." }
    }
}

function Expand-VerifiedUpdate {
    param([string]$ArchivePath, $Manifest, [string]$StagePath)
    Assert-UpdateManifest $Manifest
    if ((Get-FileHash -LiteralPath $ArchivePath -Algorithm SHA256).Hash -ine $Manifest.sha256) { throw 'El SHA-256 del ZIP no coincide.' }
    $expected = @{}
    foreach ($file in $Manifest.files) { $expected[$file.path] = $file }
    $seen = @{}
    $archive = [IO.Compression.ZipFile]::OpenRead($ArchivePath)
    try {
        foreach ($entry in $archive.Entries) {
            $path = $entry.FullName
            if (-not (Test-UpdateGamePath $path) -or -not $expected.ContainsKey($path) -or $seen.ContainsKey($path)) {
                throw "Entrada ZIP no permitida: $path"
            }
            $file = $expected[$path]
            if ($entry.Length -ne [long]$file.size) { throw "Tamano incorrecto: $path" }
            $target = Get-UpdateGameFile $StagePath $path
            New-Item -ItemType Directory -Path (Split-Path $target -Parent) -Force | Out-Null
            [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $target, $true)
            if ((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ine $file.sha256) { throw "SHA-256 incorrecto: $path" }
            $seen[$path] = $true
        }
        if ($seen.Count -ne $expected.Count) { throw 'El ZIP esta incompleto.' }
    } finally { $archive.Dispose() }
}

function Install-VerifiedUpdate {
    param([string]$GamePath, [string]$StagePath, [string]$StatePath, $Manifest, [long]$ReleaseId, [string]$Repository)
    Assert-UpdateManifest $Manifest
    if (Test-UTGameRunning) { return 'Deferred' }
    $changes = @()
    foreach ($file in $Manifest.files) {
        $source = Get-UpdateGameFile $StagePath $file.path
        if ((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -ine $file.sha256) { throw "Archivo preparado corrupto: $($file.path)" }
        $target = Get-UpdateGameFile $GamePath $file.path
        if (-not (Test-Path -LiteralPath $target -PathType Leaf) -or
            (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ine $file.sha256) {
            $changes += [pscustomobject]@{ Path = $file.path; Source = $source; Target = $target }
        }
    }
    $backupRoot = Join-Path $StatePath ("backups/" + $Manifest.version + '-' + [guid]::NewGuid().ToString('N'))
    $opened = [Collections.Generic.List[object]]::new()
    $committed = $false
    try {
        # Lock every changed destination before writing any data. A launch during
        # installation cannot read a partially written package.
        foreach ($change in $changes) {
            New-Item -ItemType Directory -Path (Split-Path $change.Target -Parent) -Force | Out-Null
            $existed = Test-Path -LiteralPath $change.Target -PathType Leaf
            $mode = if ($existed) { [IO.FileMode]::Open } else { [IO.FileMode]::CreateNew }
            $stream = [IO.File]::Open($change.Target, $mode, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
            $record = [pscustomobject]@{ Change = $change; Stream = $stream; Existed = $existed; Backup = $null; Written = $false }
            $opened.Add($record)
            if ($existed) {
                $record.Backup = Join-Path $backupRoot $change.Path
                New-Item -ItemType Directory -Path (Split-Path $record.Backup -Parent) -Force | Out-Null
                $backup = [IO.File]::Create($record.Backup)
                try { $stream.CopyTo($backup) } finally { $backup.Dispose(); $stream.Position = 0 }
            }
        }
        if (Test-UTGameRunning) { return 'Deferred' }
        foreach ($record in $opened) {
            $record.Written = $true
            $record.Stream.SetLength(0)
            $source = [IO.File]::OpenRead($record.Change.Source)
            try { $source.CopyTo($record.Stream); $record.Stream.Flush($true) } finally { $source.Dispose() }
        }
        Write-UpdateJson (Join-Path $StatePath 'installed.json') ([ordered]@{
            releaseId = $ReleaseId; version = $Manifest.version; commit = $Manifest.commit
            gamePath = [IO.Path]::GetFullPath($GamePath); repository = $Repository
            installedAt = [DateTime]::UtcNow.ToString('o'); files = @($Manifest.files)
        })
        $committed = $true
        return 'Installed'
    } finally {
        $rollbackErrors = @()
        foreach ($record in $opened) {
            try {
                if (-not $committed -and $record.Written -and $record.Existed) {
                    $record.Stream.Position = 0
                    $record.Stream.SetLength(0)
                    $backup = [IO.File]::OpenRead($record.Backup)
                    try { $backup.CopyTo($record.Stream); $record.Stream.Flush($true) } finally { $backup.Dispose() }
                }
            } catch { $rollbackErrors += $_.Exception.Message }
            finally { $record.Stream.Dispose() }
            if (-not $committed -and -not $record.Existed) {
                try { Remove-Item -LiteralPath $record.Change.Target -Force } catch { $rollbackErrors += $_.Exception.Message }
            }
        }
        if ($rollbackErrors.Count -gt 0) { throw "Fallo la recuperacion; conservar backups en $backupRoot. $($rollbackErrors -join '; ')" }
    }
}

function Invoke-UTUpdate {
    param($Config, [string]$StatePath)
    $release = Get-UpdateRelease $Config.Repository $StatePath
    if ([long]$release.id -le 0) { throw 'ID de release invalido.' }
    if ($release.draft -or $release.prerelease -or $release.tag_name -notmatch '^ut2004-[A-Za-z0-9.-]+$') {
        throw 'La ultima release no corresponde a una actualizacion estable de UT2004.'
    }
    $installedPath = Join-Path $StatePath 'installed.json'
    if (Test-Path -LiteralPath $installedPath) {
        $installed = Read-UpdateJson $installedPath
        if ($installed.releaseId -eq $release.id -and $installed.repository -ieq $Config.Repository -and
            $installed.gamePath -ieq [IO.Path]::GetFullPath($Config.GamePath)) { return 'Current' }
    }
    $assets = @{}
    foreach ($name in @('UT2004-manifest.json', 'UT2004-update.zip')) {
        $matches = @($release.assets | Where-Object { $_.name -ceq $name -and $_.state -eq 'uploaded' })
        if ($matches.Count -ne 1) { throw "Release incompleta: $name" }
        $assets[$name] = $matches[0]
    }
    $cache = Join-Path $StatePath "downloads/$($release.id)"
    New-Item -ItemType Directory -Path $cache -Force | Out-Null
    $manifestPath = Join-Path $cache 'manifest.json'
    if (-not (Test-Path -LiteralPath $manifestPath)) {
        $partial = "$manifestPath.partial"
        Save-UpdateAsset $Config.Repository $StatePath $assets['UT2004-manifest.json'] $partial
        $candidate = Read-UpdateJson $partial
        Assert-UpdateManifest $candidate
        if ($candidate.version -cne $release.tag_name) { throw 'La version del manifiesto no coincide con la release.' }
        Move-Item -LiteralPath $partial -Destination $manifestPath -Force
    }
    $manifest = Read-UpdateJson $manifestPath
    Assert-UpdateManifest $manifest
    if ($manifest.version -cne $release.tag_name) { throw 'Version de cache incorrecta.' }
    $archivePath = Join-Path $cache 'update.zip'
    if (-not (Test-Path -LiteralPath $archivePath) -or
        (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash -ine $manifest.sha256) {
        $partial = "$archivePath.partial"
        Save-UpdateAsset $Config.Repository $StatePath $assets['UT2004-update.zip'] $partial
        if ((Get-FileHash -LiteralPath $partial -Algorithm SHA256).Hash -ine $manifest.sha256) { throw 'Descarga corrupta; se reintentara.' }
        Move-Item -LiteralPath $partial -Destination $archivePath -Force
    }
    $stage = Join-Path $cache 'stage'
    Expand-VerifiedUpdate $archivePath $manifest $stage
    Install-VerifiedUpdate $Config.GamePath $stage $StatePath $manifest ([long]$release.id) $Config.Repository
}
