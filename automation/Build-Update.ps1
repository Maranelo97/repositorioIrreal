[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidatePattern('^ut2004-[A-Za-z0-9.-]+$')][string]$Version,
    [Parameter(Mandatory = $true)][string]$Commit,
    [string]$SourcePath = (Split-Path $PSScriptRoot -Parent),
    [string]$OutputPath = (Join-Path (Split-Path $PSScriptRoot -Parent) 'build/release')
)
. "$PSScriptRoot/client/Update.Common.ps1"
$SourcePath = (Resolve-Path -LiteralPath $SourcePath).Path
$OutputPath = [IO.Path]::GetFullPath($OutputPath)
if ((Test-Path -LiteralPath $OutputPath) -and @(Get-ChildItem -LiteralPath $OutputPath -Force).Count -gt 0) {
    throw 'Usar una carpeta de salida vacia; no se borran salidas anteriores.'
}
foreach ($extension in @('u', 'ucl', 'int', 'est')) {
    $required = Join-Path $SourcePath "System/MyInvasionMut.$extension"
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Falta System/MyInvasionMut.$extension. Subir los compilados antes de publicar."
    }
}
$files = @()
foreach ($directory in @('System', 'Maps', 'Textures', 'Sounds', 'Animations', 'StaticMeshes', 'Music')) {
    $folder = Join-Path $SourcePath $directory
    if (-not (Test-Path -LiteralPath $folder -PathType Container)) { continue }
    foreach ($item in @(Get-ChildItem -LiteralPath $folder -File | Sort-Object Name)) {
        $relative = "$directory/$($item.Name)"
        if (-not (Test-UpdateGamePath $relative)) { continue }
        $null = Get-UpdateGameFile $SourcePath $relative
        if ($item.Length -eq 0) { throw "Archivo vacio: $relative" }
        $stream = $item.OpenRead()
        try {
            $prefix = New-Object byte[] 128
            $count = $stream.Read($prefix, 0, $prefix.Length)
            if ([Text.Encoding]::ASCII.GetString($prefix, 0, $count).StartsWith('version https://git-lfs.github.com/spec/v1')) {
                throw "Hay un puntero LFS sin descargar: $relative. Ejecutar git lfs pull."
            }
        } finally { $stream.Dispose() }
        $files += [pscustomobject]@{ path = $relative; size = $item.Length; sha256 = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash.ToLowerInvariant() }
    }
}
New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
$zipPath = Join-Path $OutputPath 'UT2004-update.zip'
$zip = [IO.Compression.ZipFile]::Open($zipPath, [IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($file in $files) {
        [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, (Join-Path $SourcePath $file.path), $file.path) | Out-Null
    }
} finally { $zip.Dispose() }
$manifest = [ordered]@{
    schema = 1; version = $Version; commit = $Commit; createdAt = [DateTime]::UtcNow.ToString('o')
    archive = 'UT2004-update.zip'; sha256 = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
    files = @($files)
}
Assert-UpdateManifest ([pscustomobject]$manifest)
Write-UpdateJson (Join-Path $OutputPath 'UT2004-manifest.json') $manifest
$clientZip = [IO.Compression.ZipFile]::Open((Join-Path $OutputPath 'UT2004-updater.zip'), [IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($name in @('Update.Common.ps1', 'Start-Update.ps1', 'Install-Updater.ps1', 'Uninstall-Updater.ps1', 'Instalar.cmd', 'LEEME.md')) {
        [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($clientZip, (Join-Path "$PSScriptRoot/client" $name), $name) | Out-Null
    }
} finally { $clientZip.Dispose() }
Write-Host "Paquete $Version preparado: $($files.Count) archivos. Salida: $OutputPath"
