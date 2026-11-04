# Offline integration tests. No game, credentials, scheduled tasks or network required.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/../client/Update.Common.ps1"
$root = [IO.Path]::GetFullPath((Join-Path "$PSScriptRoot/../../build/tests" ([guid]::NewGuid().ToString('N'))))
New-Item -ItemType Directory -Path $root -Force | Out-Null
$script:checks = 0
function Assert([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "FAIL: $Message" }
    $script:checks++
}
function Assert-Throws([scriptblock]$Action, [string]$Message) {
    $caught = $false
    try { & $Action | Out-Null } catch { $caught = $true }
    Assert $caught $Message
}
function Put([string]$Path, [string]$Text) {
    New-Item -ItemType Directory -Path (Split-Path $Path -Parent) -Force | Out-Null
    [IO.File]::WriteAllText($Path, $Text)
}
function Clone-Manifest($Value) { $Value | ConvertTo-Json -Depth 12 | ConvertFrom-Json }
function Test-UTGameRunning { return $script:gameRunning }
$script:gameRunning = $false
try {
    foreach ($path in @('../evil.u', 'System/../evil.u', 'System\evil.u', '/System/evil.u', 'System/evil.exe',
        'System/UT2004.ini', 'System/User.ini', 'System/IrrealTest.u', 'System/evil.u:stream', 'System/NUL.u', 'Maps/evil.ut2.')) {
        Assert (-not (Test-UpdateGamePath $path)) "Se rechaza $path"
    }
    foreach ($path in @('System/MyInvasionMut.u', 'System/MyInvasionMut.ini', 'Maps/DM-Amigos.ut2', 'Textures/Amigos.utx')) {
        Assert (Test-UpdateGamePath $path) "Se admite $path"
    }
    $source = Join-Path $root 'source'
    foreach ($ext in @('u', 'ucl', 'int', 'est')) { Put "$source/System/MyInvasionMut.$ext" "version 2 $ext" }
    $latinBytes = [byte[]]@(0xE1, 0xE9, 0xED, 0xF3, 0xFA, 0xF1)
    [IO.File]::WriteAllBytes("$source/System/MyInvasionMut.est", $latinBytes)
    Put "$source/Maps/DM-Amigos.ut2" 'map version 2'
    Put "$source/Textures/Amigos.utx" 'texture version 2'
    Put "$source/System/MyInvasionMut.ini" '[mod settings]'
    Put "$source/System/User.ini" 'personal settings'
    Put "$source/System/UT2004.ini" 'personal game config'
    Put "$source/System/IrrealTest.u" 'do not distribute'
    Put "$source/System/payload.ps1" 'do not distribute'
    Put "$source/MyInvasionMut/Classes/Example.uc" 'source code only'
    $output = Join-Path $root 'release'
    & "$PSScriptRoot/../Build-Update.ps1" -Version ut2004-test-2 -Commit ('a' * 40) -SourcePath $source -OutputPath $output
    $manifest = Read-UpdateJson "$output/UT2004-manifest.json"
    Assert ($manifest.files.Count -eq 7) 'Solo se empaquetan los archivos de juego permitidos'
    Assert (@($manifest.files | Where-Object path -match 'User.ini|UT2004.ini|IrrealTest|payload|Example').Count -eq 0) 'Sin configuracion personal, fuentes ni mutador de prueba'
    $stage = Join-Path $root 'stage'
    Expand-VerifiedUpdate "$output/UT2004-update.zip" $manifest $stage
    Assert ([Convert]::ToBase64String([IO.File]::ReadAllBytes("$stage/System/MyInvasionMut.est")) -eq [Convert]::ToBase64String($latinBytes)) 'Se preserva Latin-1 byte por byte'
    $clientZip = [IO.Compression.ZipFile]::OpenRead("$output/UT2004-updater.zip")
    try { Assert ($clientZip.Entries.Count -eq 6) 'El ZIP para los amigos incluye instalador e instrucciones' } finally { $clientZip.Dispose() }

    $game = Join-Path $root 'game'
    $state = Join-Path $root 'state'
    New-Item -ItemType Directory -Path $state -Force | Out-Null
    Put "$game/System/MyInvasionMut.u" 'version 1'
    Put "$game/System/User.ini" 'keep my keys'
    Put "$game/System/UT2004.ini" 'keep my config'
    Put "$game/System/OldMod.u" 'unmanaged file'
    $before = (Get-FileHash "$game/System/MyInvasionMut.u").Hash
    $script:gameRunning = $true
    Assert ((Install-VerifiedUpdate $game $stage $state $manifest 20) -eq 'Deferred') 'Se difiere con UT2004 abierto'
    Assert ((Get-FileHash "$game/System/MyInvasionMut.u").Hash -eq $before) 'No se cambia el juego abierto'
    Assert (-not (Test-Path "$state/installed.json")) 'Una descarga no se marca instalada'
    $script:gameRunning = $false

    # A locked later file must prevent all writes and remove newly created placeholders.
    $locked = [IO.File]::Open("$game/System/MyInvasionMut.u", 'Open', 'ReadWrite', 'None')
    try { Assert-Throws { Install-VerifiedUpdate $game $stage $state $manifest 20 } 'Falla si un paquete esta bloqueado' }
    finally { $locked.Dispose() }
    Assert ((Get-FileHash "$game/System/MyInvasionMut.u").Hash -eq $before) 'El archivo bloqueado sigue intacto'
    Assert (-not (Test-Path "$game/System/MyInvasionMut.est")) 'No se dejan archivos nuevos vacios tras un error'

    # Fail the final state write after copying the payload: every replacement must roll back.
    New-Item -ItemType Directory -Path "$state/installed.json" | Out-Null
    Assert-Throws { Install-VerifiedUpdate $game $stage $state $manifest 20 } 'Se detecta el fallo al guardar el estado'
    Assert ((Get-FileHash "$game/System/MyInvasionMut.u").Hash -eq $before) 'Rollback restaura el paquete anterior'
    Assert (-not (Test-Path "$game/Maps/DM-Amigos.ut2")) 'Rollback elimina archivos que antes no existian'
    Remove-Item -LiteralPath "$state/installed.json"
    Assert ((Install-VerifiedUpdate $game $stage $state $manifest 20) -eq 'Installed') 'Instala con el juego cerrado'
    Assert ((Read-UpdateJson "$state/installed.json").releaseId -eq 20) 'Guarda la release instalada'
    Assert ((Get-Content "$game/System/User.ini" -Raw) -eq 'keep my keys') 'Conserva teclas del usuario'
    Assert ((Get-Content "$game/System/UT2004.ini" -Raw) -eq 'keep my config') 'Conserva UT2004.ini'
    Assert (Test-Path "$game/System/OldMod.u") 'No borra archivos ajenos al paquete'
    Assert (@(Get-ChildItem "$state/backups" -Recurse -File).Count -ge 1) 'Guarda backups'
    $time = (Get-Item "$game/System/MyInvasionMut.u").LastWriteTimeUtc
    Install-VerifiedUpdate $game $stage $state $manifest 20 | Out-Null
    Assert ((Get-Item "$game/System/MyInvasionMut.u").LastWriteTimeUtc -eq $time) 'No reescribe archivos que ya coinciden'

    $bad = Clone-Manifest $manifest
    $bad.files[0].path = 'System/../outside.u'
    Assert-Throws { Expand-VerifiedUpdate "$output/UT2004-update.zip" $bad "$root/bad-stage" } 'Rechaza traversal del manifiesto'
    $bad = Clone-Manifest $manifest
    $bad.files[0].sha256 = '0' * 64
    Assert-Throws { Expand-VerifiedUpdate "$output/UT2004-update.zip" $bad "$root/bad-hash" } 'Rechaza contenido que no coincide con el hash'
    $bad = Clone-Manifest $manifest
    $bad.files += $bad.files[0]
    Assert-Throws { Assert-UpdateManifest $bad } 'Rechaza entradas duplicadas'
    Copy-Item "$output/UT2004-update.zip" "$root/corrupt.zip"
    [IO.File]::AppendAllText("$root/corrupt.zip", 'corruption')
    Assert-Throws { Expand-VerifiedUpdate "$root/corrupt.zip" $manifest "$root/corrupt-stage" } 'Rechaza ZIP corrupto antes de tocar el juego'

    # A valid archive hash must not allow unlisted or unsafe ZIP entries.
    $unsafeZip = [IO.Compression.ZipFile]::Open("$root/unsafe.zip", [IO.Compression.ZipArchiveMode]::Create)
    try { [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($unsafeZip, "$source/System/MyInvasionMut.u", '../outside.u') | Out-Null }
    finally { $unsafeZip.Dispose() }
    $bad = Clone-Manifest $manifest
    $bad.sha256 = (Get-FileHash "$root/unsafe.zip").Hash
    Assert-Throws { Expand-VerifiedUpdate "$root/unsafe.zip" $bad "$root/unsafe-stage" } 'Rechaza traversal dentro del ZIP'
    Assert (-not (Test-Path "$root/outside.u")) 'No escribe fuera del destino'

    # Mock the transport, keeping release parsing, cache, checksums and installation real.
    $script:downloads = 0
    $script:offline = $false
    $script:release = [pscustomobject]@{
        id = 30; tag_name = 'ut2004-test-2'; draft = $false; prerelease = $false
        assets = @(
            [pscustomobject]@{ id = 1; name = 'UT2004-manifest.json'; state = 'uploaded' },
            [pscustomobject]@{ id = 2; name = 'UT2004-update.zip'; state = 'uploaded' }
        )
    }
    function Get-UpdateRelease { param($Repository, $StatePath); if ($script:offline) { throw 'Sin Internet' }; return $script:release }
    function Save-UpdateAsset {
        param($Repository, $StatePath, $Asset, $Destination)
        $script:downloads++
        Copy-Item -LiteralPath (Join-Path $output $Asset.name) -Destination $Destination -Force
    }
    $config = [pscustomobject]@{ Repository = 'example/friends'; GamePath = $game }
    $script:gameRunning = $true
    Assert ((Invoke-UTUpdate $config $state) -eq 'Deferred') 'El flujo descarga mientras el juego esta abierto'
    Assert ($script:downloads -eq 2) 'Descarga manifiesto y ZIP de la misma release'
    $script:gameRunning = $false
    Assert ((Invoke-UTUpdate $config $state) -eq 'Installed') 'Una comprobacion posterior instala la descarga pendiente'
    Assert ($script:downloads -eq 2) 'Se reutiliza la descarga preparada'
    Assert ((Invoke-UTUpdate $config $state) -eq 'Current') 'No repite una version ya instalada'
    Assert ($script:downloads -eq 2) 'No descarga paquetes cuando ya esta actualizado'
    $config.GamePath = Join-Path $root 'other-game'
    Assert ((Invoke-UTUpdate $config $state) -eq 'Installed') 'Cambiar la carpeta del juego instala aun si la release ya estaba descargada'
    Assert (Test-Path "$($config.GamePath)/System/MyInvasionMut.u") 'La segunda carpeta recibe los archivos'
    Assert ($script:downloads -eq 2) 'Cambiar de carpeta reutiliza la cache verificada'
    Assert ((Read-UpdateJson "$state/installed.json").gamePath -eq $config.GamePath) 'El estado corresponde a la carpeta configurada'
    $script:offline = $true
    Assert-Throws { Invoke-UTUpdate $config $state } 'Una desconexion genera un fallo recuperable'
    Assert ((Read-UpdateJson "$state/installed.json").releaseId -eq 30) 'El fallo de red conserva el estado instalado'
    $script:offline = $false
    $script:release.id = 40
    $script:release.assets = @($script:release.assets | Where-Object name -ne 'UT2004-update.zip')
    Assert-Throws { Invoke-UTUpdate $config $state } 'No instala releases incompletas'
    Assert ($script:downloads -eq 2) 'No empieza una descarga incompleta'

    Remove-Item -LiteralPath "$source/System/MyInvasionMut.u"
    Assert-Throws { & "$PSScriptRoot/../Build-Update.ps1" -Version ut2004-missing -Commit test -SourcePath $source -OutputPath "$root/missing" } 'No publica si faltan compilados'
    Put "$source/System/MyInvasionMut.u" "version https://git-lfs.github.com/spec/v1`noid sha256:abc"
    Assert-Throws { & "$PSScriptRoot/../Build-Update.ps1" -Version ut2004-lfs -Commit test -SourcePath $source -OutputPath "$root/lfs" } 'No publica punteros de Git LFS'
    Write-Host "OK: $script:checks comprobaciones de integracion (PowerShell $($PSVersionTable.PSVersion))."
} finally {
    # Only remove this test's verified absolute directory, inside the repository build folder.
    $allowed = [IO.Path]::GetFullPath((Join-Path "$PSScriptRoot/../../build" 'tests')) + [IO.Path]::DirectorySeparatorChar
    if ($root.StartsWith($allowed, [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $root)) {
        Remove-Item -LiteralPath $root -Recurse -Force
    }
}
