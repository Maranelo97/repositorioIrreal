# Instalador de los Mutadores Irreales (MutadoresIrreales, antes MyInvasionMut).
#
# Con UT2004 cerrado:
#   1. Copia en System los cuatro archivos MutadoresIrreales.* que estan al lado de este script
#      (en el zip vienen juntos). Si ya habia otros distintos, los reemplaza.
#   2. Saca los archivos viejos MyInvasionMut.* (hasta la 1.4.4) de System.
#   3. En los .ini de System (UT2004.ini, User.ini, el de un servidor dedicado...) cambia
#      MyInvasionMut por MutadoresIrreales (y las clases que cambiaron de nombre, ver $Clases):
#      las opciones de los mutadores y los mutadores elegidos en el menu se conservan.
#      Si ya habia una seccion nueva, queda la nueva. Ademas borra lo de nuestros paquetes que
#      no es parte del paquete actual (Version.txt dice que clases, mutadores y opciones trae):
#      secciones de clases que ya no existen, opciones que un mutador ya no tiene y mutadores que
#      ya no existen en las listas de elegidos. Con -SinConfiguracion (o sin tildar la opcion en
#      la ventana) no se toca ningun .ini.
#   4. Si al lado del script estan IrrealTest.u e IrrealTest.ucl (zip Pruebas-IrrealTest), los copia
#      tambien. Un IrrealTest de otra compilacion no anda con este MutadoresIrreales, asi que se
#      saca de System (Version.txt, que viene en los dos zips, dice cual corresponde).
# Con -SinRespaldo (o tildando la opcion en la ventana) no queda copia: lo que se saca se borra.
# Si no, todo lo que se reemplaza, se saca o se cambia queda en una carpeta de respaldo que se crea
# al lado de este script (Respaldo-instalacion-<fecha>).
#
# Los .ini se leen y se escriben byte por byte (Latin-1) y conservan sus fines de linea.
# Uso: doble clic en Instalar-MutadoresIrreales.cmd (abre una ventana), o en consola:
#   powershell -ExecutionPolicy Bypass -File Instalar-MutadoresIrreales.ps1 -Consola [-Carpeta <System o carpeta del juego>] [-SinConfiguracion] [-SinRespaldo] [-Si]
# El archivo se guarda en UTF-8 con BOM: sin el BOM, PowerShell 5.1 lee mal los acentos.
param(
    [string]$Carpeta,
    [switch]$Consola,   # sin ventana
    [switch]$SinConfiguracion,   # no tocar los .ini
    [switch]$SinRespaldo,        # no guardar copia de lo que se saca o se cambia
    [switch]$Si         # consola y sin preguntar antes de empezar (para pruebas)
)

$ErrorActionPreference = 'Stop'
$Viejo = 'MyInvasionMut'
$Nuevo = 'MutadoresIrreales'
$Latin1 = [Text.Encoding]::GetEncoding(28591)
# En la 2.0 tambien cambiaron de nombre algunas clases (para que coincidan con el nombre del menu).
# Las opciones se guardan con el nombre de la clase, asi que hay que pasarlas a la clase nueva.
$Clases = @{
    MutInvasionPause     = 'MutControlDePlagas'
    MutInstantRespawn    = 'MutEsTodoMuyIrreal'
    MutInvasionUltimates = 'MutMurioUnaBandaDeGente'
    MutNeedMoreBots      = 'MutNecesitamosMasBots'
    MutRadarMejorado     = 'MutSiganViendo'
}
# MyInvasionMut.Clase -> MutadoresIrreales.ClaseNueva, y el nombre del paquete solo -> el nuevo
function Convert-Nombre {
    param([string]$Texto)
    $conClase = [regex]::Replace($Texto, "(?i)\b$Viejo\.(\w+)", [Text.RegularExpressions.MatchEvaluator]{
        param($m)
        $clase = $m.Groups[1].Value
        if ($Clases.ContainsKey($clase)) { "$Nuevo.$($Clases[$clase])" } else { "$Nuevo.$clase" }
    })
    return [regex]::Replace($conClase, "(?i)\b$Viejo\b", $Nuevo)
}

function Resolve-CarpetaSystem {
    param([string]$Ruta)
    if (-not $Ruta) { return $null }
    $Ruta = $Ruta.Trim().Trim('"')
    foreach ($candidata in @($Ruta, (Join-Path $Ruta 'System'))) {
        if (Test-Path -LiteralPath (Join-Path $candidata 'UT2004.ini')) { return (Resolve-Path -LiteralPath $candidata).Path }
    }
    return $null
}

function Find-CarpetaSystem {
    # 1) La carpeta del script (si lo copiaron dentro del juego)
    $candidatas = New-Object System.Collections.ArrayList
    [void]$candidatas.Add($PSScriptRoot)
    [void]$candidatas.Add((Split-Path $PSScriptRoot -Parent))
    # 2) Bibliotecas de Steam
    try {
        $steam = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction Stop).SteamPath
        $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
        $bibliotecas = @($steam)
        if (Test-Path -LiteralPath $vdf) {
            # Formato actual: "path"  "D:\\Juegos"; formato viejo: "1"  "D:\\Juegos"
            foreach ($m in [regex]::Matches((Get-Content -LiteralPath $vdf -Raw), '"(?:path|\d+)"\s+"([^"]+)"')) {
                $ruta = $m.Groups[1].Value.Replace('\\', '\')
                if ($ruta -match '^[A-Za-z]:\\') { $bibliotecas += $ruta }
            }
        }
        foreach ($b in $bibliotecas) { [void]$candidatas.Add((Join-Path $b 'steamapps\common\Unreal Tournament 2004')) }
    } catch { }
    # 3) Instalacion de CD/DVD
    foreach ($clave in 'HKLM:\SOFTWARE\WOW6432Node\Unreal Technology\Installed Apps\UT2004',
                       'HKLM:\SOFTWARE\Unreal Technology\Installed Apps\UT2004') {
        try { [void]$candidatas.Add((Get-ItemProperty $clave -ErrorAction Stop).Folder) } catch { }
    }
    foreach ($c in $candidatas) {
        $sistema = Resolve-CarpetaSystem $c
        if ($sistema) { return $sistema }
    }
    return $null
}

# Cambia el nombre viejo por el nuevo en un .ini y, si se sabe qué trae el paquete actual ($Paquete,
# de Version.txt), borra lo que ya no es parte de él: secciones de clases que no están, opciones que un
# mutador ya no tiene y mutadores que no están en las listas de elegidos. Solo toca lo de nuestros
# paquetes (MyInvasionMut y MutadoresIrreales). Devuelve el texto nuevo y lo que hizo; si no hay nada
# que cambiar, Cambios queda vacío.
function Convert-Ini {
    param([string]$Texto, $Paquete)
    $salto = if ($Texto.Contains("`r`n")) { "`r`n" } else { "`n" }
    $lineas = $Texto -split "`r?`n"
    $palabraVieja = "(?i)\b$Viejo\b"
    $referenciaNueva = "(?i)\b$Nuevo\.(\w+)"

    # Secciones que ya existen, para no duplicarlas, y las lineas sin el nombre viejo de cada
    # seccion, para no repetir una que ya esta (por ejemplo EditPackages=MutadoresIrreales)
    $encabezados = @{}
    $lineasDeSeccion = New-Object System.Collections.ArrayList
    $actual = @{}
    [void]$lineasDeSeccion.Add($actual)
    foreach ($l in $lineas) {
        if ($l -match '^\s*\[(.+)\]\s*$') {
            $encabezados[$Matches[1].ToLowerInvariant()] = $true
            $actual = @{}
            [void]$lineasDeSeccion.Add($actual)
        } elseif ($l -notmatch $palabraVieja) {
            $actual[$l.Trim().ToLowerInvariant()] = $true
        }
    }

    $salida = New-Object System.Collections.Generic.List[string]
    $cambios = New-Object System.Collections.Generic.List[string]
    $descartando = $false
    $opcionesValidas = $null   # opciones del mutador de la sección actual (si es uno de los nuestros)
    $numeroSeccion = 0
    $enSeccion = $lineasDeSeccion[0]
    foreach ($l in $lineas) {
        if ($l -match '^\s*\[(.+)\]\s*$') {
            $nombre = $Matches[1]
            $descartando = $false
            $opcionesValidas = $null
            $numeroSeccion++
            $enSeccion = $lineasDeSeccion[$numeroSeccion]
            if ($nombre -match "(?i)^(?:$Viejo|$Nuevo)\.(\w+)$") {
                $clase = if ($Clases.ContainsKey($Matches[1])) { $Clases[$Matches[1]] } else { $Matches[1] }
                if ($Paquete -and -not $Paquete.Clases.ContainsKey($clase)) {
                    $descartando = $true
                    $cambios.Add("  [$nombre]: se borra (ya no existe en el paquete)")
                    continue
                }
                if ($Paquete -and $Paquete.Opciones.ContainsKey($clase)) { $opcionesValidas = $Paquete.Opciones[$clase] }
            }
            if ($nombre -match "(?i)^$Viejo\.(.+)$") {
                $nuevoNombre = Convert-Nombre $nombre
                if ($encabezados.ContainsKey($nuevoNombre.ToLowerInvariant())) {
                    $descartando = $true
                    $cambios.Add("  [$nombre]: ya estaba [$nuevoNombre], se deja la nueva y se borra la vieja")
                    continue
                }
                $salida.Add("[$nuevoNombre]")
                $cambios.Add("  [$nombre] -> [$nuevoNombre] (se conservan las opciones)")
                continue
            }
            $salida.Add($l)
            continue
        }
        if ($descartando) { continue }

        # Opción que el mutador ya no tiene (las listas guardan el índice: Opcion[0]= u Opcion(0)=)
        if ($null -ne $opcionesValidas -and $l -match '^\s*([^=;\s][^=]*?)\s*=') {
            $opcion = $Matches[1] -replace '\s*[\[\(]\s*\d+\s*[\]\)]$', ''
            if ($opcionesValidas -notcontains $opcion) {
                $cambios.Add("  se borra la opción que ya no existe: $opcion (en [$nombre])")
                continue
            }
        }

        $conViejo = $l -match $palabraVieja
        $nueva = if ($conViejo) { Convert-Nombre $l } else { $l }
        $quitados = @()
        if ($Paquete) { $quitados = @([regex]::Matches($nueva, $referenciaNueva) | Where-Object { -not $Paquete.Clases.ContainsKey($_.Groups[1].Value) }) }
        if (-not $conViejo -and $quitados.Count -eq 0) { $salida.Add($l); continue }

        # Listas separadas por comas (por ejemplo LastActiveMutators): sin repetidos y sin lo que ya no
        # existe en el paquete
        if ($nueva -match '^([^=]+=)(.*)$') {
            $prefijo = $Matches[1]   # se guarda antes: los -match de adentro pisan $Matches
            $valor = $Matches[2]
            $vistos = @{}
            $items = foreach ($item in $valor.Split(',')) {
                $clave = $item.Trim().ToLowerInvariant()
                if ($Paquete -and $item.Trim() -match "(?i)^$Nuevo\.(\w+)$" -and -not $Paquete.Clases.ContainsKey($Matches[1])) { continue }
                if ($clave -and $vistos.ContainsKey($clave)) { continue }
                $vistos[$clave] = $true
                $item
            }
            $nueva = $prefijo + (@($items) -join ',')
        }
        if ($conViejo) {
            $clave = $nueva.Trim().ToLowerInvariant()
            if ($enSeccion.ContainsKey($clave)) {
                $cambios.Add("  se borra la línea repetida: $($l.Trim())")
                continue
            }
            $enSeccion[$clave] = $true
        }
        $salida.Add($nueva)
        $resumen = $l.Trim(); if ($resumen.Length -gt 70) { $resumen = $resumen.Substring(0, 67) + '...' }
        $cambios.Add("  $resumen")
    }
    return [pscustomobject]@{ Texto = ($salida -join $salto); Cambios = $cambios }
}

function Get-Hash { param([string]$Ruta) (Get-FileHash -LiteralPath $Ruta -Algorithm SHA256).Hash }

function Get-Nombres { param($Lista) (@($Lista) | ForEach-Object { if ($_ -is [IO.FileInfo]) { $_.Name } else { Split-Path $_ -Leaf } }) -join ', ' }

function Test-JuegoAbierto {
    @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match '^(UT2004|ucc)$' }).Count -gt 0
}

# Paso 1: lo que hay al lado del instalador (en el zip vienen juntos)
function Get-Origen {
    $error1 = $null
    $nuevosAlLado = @($Extensiones | Where-Object { Test-Path -LiteralPath (Join-Path $PSScriptRoot "$Nuevo.$_") })
    if ($nuevosAlLado.Count -gt 0 -and $nuevosAlLado.Count -lt $Extensiones.Count) {
        $error1 = "Faltan archivos de $Nuevo al lado del instalador: tienen que estar los cuatro (.u, .ucl, .int y .est). Extraé el zip completo y volvé a intentar."
    }
    $pruebasAlLado = @('u', 'ucl' | Where-Object { Test-Path -LiteralPath (Join-Path $PSScriptRoot "IrrealTest.$_") })
    if ($pruebasAlLado.Count -eq 1) {
        $error1 = 'Falta un archivo de IrrealTest al lado del instalador: tienen que estar IrrealTest.u e IrrealTest.ucl. Extraé el zip completo y volvé a intentar.'
    }
    # Version.txt (viene en los dos zips): la versión y los hashes de MutadoresIrreales.u e IrrealTest.u
    # de la misma compilación
    # También dice qué trae el paquete (Clases= y Mutador.<Clase>=<opciones>), para limpiar la configuración
    $compilacion = @{}
    $version = $null
    $clasesPaquete = $null
    $opcionesPaquete = @{}
    $archivoVersion = Join-Path $PSScriptRoot 'Version.txt'
    if (Test-Path -LiteralPath $archivoVersion) {
        foreach ($l in Get-Content -LiteralPath $archivoVersion) {
            if ($l -match '^\s*([^=\s]+)\s*=\s*([0-9A-Fa-f]{64})\s*$') { $compilacion[$Matches[1]] = $Matches[2].ToUpperInvariant() }
            elseif ($l -match '^\s*Version\s*=\s*(\S+)\s*$') { $version = $Matches[1] }
            elseif ($l -match '^\s*Clases\s*=\s*(.*)$') {
                $clasesPaquete = @{}
                foreach ($c in $Matches[1].Split(',')) { if ($c.Trim()) { $clasesPaquete[$c.Trim()] = $true } }
            }
            elseif ($l -match '^\s*Mutador\.(\w+)\s*=\s*(.*)$') {
                $opcionesPaquete[$Matches[1]] = @($Matches[2].Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ })
            }
        }
    }
    $paquete = $null
    if ($clasesPaquete) { $paquete = [pscustomobject]@{ Clases = $clasesPaquete; Opciones = $opcionesPaquete } }
    if (-not $version -and $nuevosAlLado.Count -eq $Extensiones.Count) {
        $ver = [regex]::Match($Latin1.GetString([IO.File]::ReadAllBytes((Join-Path $PSScriptRoot "$Nuevo.int"))), '\(Ver ([0-9.]+)\)')
        if ($ver.Success) { $version = $ver.Groups[1].Value }
    }
    [pscustomobject]@{
        Error       = $error1
        HayNuevos   = $nuevosAlLado.Count -eq $Extensiones.Count
        HayPruebas  = $pruebasAlLado.Count -eq 2
        Compilacion = $compilacion
        Version     = $version
        Paquete     = $paquete
    }
}

# Paso 2: qué hay que hacer en esa carpeta System (no cambia nada)
function Get-Plan {
    param($Origen, [string]$Sistema, [bool]$ConConfiguracion = $true, [bool]$ConRespaldo = $true)
    $aCopiar = @()
    $aReemplazar = @()
    $avisos = New-Object System.Collections.Generic.List[string]
    $avisosResultado = New-Object System.Collections.Generic.List[string]   # avisos que se repiten en el resultado
    $compilacion = $Origen.Compilacion

    # No volver atrás: si en el juego hay una versión más nueva que la de este instalador, no se toca
    # nada (se reemplazarían los archivos y se borrarían las opciones de los mutadores que agregó)
    $bloqueo = $null
    $intInstalado = Join-Path $Sistema "$Nuevo.int"
    if ($Origen.Version -and (Test-Path -LiteralPath $intInstalado)) {
        $verInstalada = [regex]::Match($Latin1.GetString([IO.File]::ReadAllBytes($intInstalado)), '\(Ver ([0-9.]+)\)')
        $a = $null; $b = $null
        $textoA = if ($verInstalada.Success) { $verInstalada.Groups[1].Value } else { '' }
        $textoB = $Origen.Version
        if ($textoA -notmatch '\.') { $textoA += '.0' }
        if ($textoB -notmatch '\.') { $textoB += '.0' }
        if ([version]::TryParse($textoA, [ref]$a) -and [version]::TryParse($textoB, [ref]$b) -and $a -gt $b) {
            $bloqueo = "En el juego están instalados los Mutadores Irreales $($verInstalada.Groups[1].Value), más nuevos que los de este instalador ($($Origen.Version)). Para no volver a una versión anterior ni borrar las opciones de los mutadores nuevos, no se instala nada. Usá el instalador de la versión $($verInstalada.Groups[1].Value) o de una más nueva."
        }
    }

    # Archivos nuevos que faltan en System o que son distintos (otra versión)
    $scriptEnSystem = (Resolve-Path -LiteralPath $PSScriptRoot).Path -ieq $Sistema
    if ($Origen.HayNuevos -and -not $scriptEnSystem) {
        foreach ($ext in $Extensiones) {
            $desde = Join-Path $PSScriptRoot "$Nuevo.$ext"
            $destino = Join-Path $Sistema "$Nuevo.$ext"
            if (-not (Test-Path -LiteralPath $destino)) { $aCopiar += $desde }
            elseif ((Get-Hash $desde) -ne (Get-Hash $destino)) { $aCopiar += $desde; $aReemplazar += $destino }
        }
    } elseif (-not $Origen.HayNuevos -and -not (Test-Path -LiteralPath (Join-Path $Sistema "$Nuevo.u"))) {
        $avisos.Add("Aviso: no están los archivos de $Nuevo al lado del instalador. Solo se limpia lo viejo; después hay que instalar $Nuevo.")
    }

    # IrrealTest (mutador de pruebas): se instala si está al lado del instalador. Solo anda con el
    # MutadoresIrreales de la misma compilación (ver Version.txt)
    $hayPruebas = $Origen.HayPruebas -and -not $scriptEnSystem
    $uFinal = $null
    if ($Origen.HayNuevos -and -not $scriptEnSystem) { $uFinal = Get-Hash (Join-Path $PSScriptRoot "$Nuevo.u") }
    elseif (Test-Path -LiteralPath (Join-Path $Sistema "$Nuevo.u")) { $uFinal = Get-Hash (Join-Path $Sistema "$Nuevo.u") }
    $esLaCompilacion = $compilacion.ContainsKey("$Nuevo.u") -and $uFinal -eq $compilacion["$Nuevo.u"]
    if ($hayPruebas -and $compilacion.ContainsKey("$Nuevo.u") -and -not $esLaCompilacion) {
        if ($uFinal) { $avisosResultado.Add("Aviso: IrrealTest no se instala porque es de otra compilación que el $Nuevo instalado. Instalá primero $Nuevo de la misma versión y después volvé a correr este instalador.") }
        else { $avisosResultado.Add("Aviso: IrrealTest no se instala porque todavía no está instalado $Nuevo. Instalalo primero y después volvé a correr este instalador.") }
        foreach ($a in $avisosResultado) { $avisos.Add($a) }
        $hayPruebas = $false
    }
    if ($hayPruebas) {
        foreach ($ext in 'u', 'ucl') {
            $desde = Join-Path $PSScriptRoot "IrrealTest.$ext"
            $destino = Join-Path $Sistema "IrrealTest.$ext"
            if (-not (Test-Path -LiteralPath $destino)) { $aCopiar += $desde }
            elseif ((Get-Hash $desde) -ne (Get-Hash $destino)) { $aCopiar += $desde; $aReemplazar += $destino }
        }
    }

    # Un IrrealTest de otra versión no anda con este MutadoresIrreales: se saca de System
    $pruebasViejas = @()
    $pruebasU = Join-Path $Sistema 'IrrealTest.u'
    if (-not $hayPruebas -and (Test-Path -LiteralPath $pruebasU)) {
        $vieja = if ($esLaCompilacion -and $compilacion.ContainsKey('IrrealTest.u')) {
            (Get-Hash $pruebasU) -ne $compilacion['IrrealTest.u']
        } else {
            # Sin Version.txt solo se reconoce el de antes de la 2.0 (usa el paquete MyInvasionMut)
            $Latin1.GetString([IO.File]::ReadAllBytes($pruebasU)) -match $Viejo
        }
        if ($vieja) { $pruebasViejas = @(Get-ChildItem -LiteralPath $Sistema -File | Where-Object { $_.Name -match '^IrrealTest\.(u|ucl)$' }) }
    }

    $archivosViejos = @(Get-ChildItem -LiteralPath $Sistema -File | Where-Object { $_.Name -match "(?i)^$Viejo\.(u|ucl|int|est|ini)$" })
    # .ini que nombran nuestros paquetes y tienen algo para cambiar (nombre viejo o algo que ya no existe)
    $inis = @(Get-ChildItem -LiteralPath $Sistema -File -Filter '*.ini' | Where-Object {
        if ($_.Name -match "(?i)^$Viejo\.ini$") { return $false }
        $texto = $Latin1.GetString([IO.File]::ReadAllBytes($_.FullName))
        ($texto -match "(?i)\b(?:$Viejo|$Nuevo)\b") -and (Convert-Ini $texto $Origen.Paquete).Cambios.Count -gt 0
    })
    $configOmitida = @()
    if (-not $ConConfiguracion) { $configOmitida = $inis; $inis = @() }

    # El juego guarda un .ini en Unicode (UTF-16) si tiene caracteres que no entran en su página de códigos
    # (por ejemplo en el nombre del jugador). Esos el instalador no los cambia: avisa
    if ($ConConfiguracion) {
        foreach ($f in Get-ChildItem -LiteralPath $Sistema -File -Filter '*.ini') {
            $bytes = [IO.File]::ReadAllBytes($f.FullName)
            if ($bytes.Length -lt 2 -or -not (($bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) -or ($bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF))) { continue }
            $codificacion = if ($bytes[0] -eq 0xFF) { [Text.Encoding]::Unicode } else { [Text.Encoding]::BigEndianUnicode }
            if ($codificacion.GetString($bytes) -match "(?i)\b(?:$Viejo|$Nuevo)\b") {
                $aviso = "Aviso: $($f.Name) está guardado en Unicode y el instalador no lo cambia. Si en él había mutadores elegidos o configurados de versiones anteriores, hay que volver a elegirlos y configurarlos en el juego."
                $avisos.Add($aviso)
                $avisosResultado.Add($aviso)
            }
        }
    }

    $descripcion = New-Object System.Collections.Generic.List[string]
    if ($aCopiar.Count) {
        $descripcion.Add("Se copian en System: $(Get-Nombres $aCopiar)")
        if ($aReemplazar.Count) { $descripcion.Add($(if ($ConRespaldo) { '  (reemplazan a los que había, que son de otra versión y van al respaldo)' } else { '  (reemplazan a los que había, que son de otra versión y se borran)' })) }
    }
    $destinoViejos = if ($ConRespaldo) { 'van al respaldo' } else { 'se borran' }
    if ($archivosViejos.Count) { $descripcion.Add("Se sacan de System los archivos viejos ($destinoViejos): $(Get-Nombres $archivosViejos)") }
    if ($inis.Count) { $descripcion.Add("Se actualiza la configuración (nombres nuevos y opciones que ya no existen), conservando las opciones y los mutadores elegidos: $(Get-Nombres $inis)") }
    if ($pruebasViejas.Count) { $descripcion.Add("Se saca de System un IrrealTest de otra versión, que ya no funciona ($(if ($ConRespaldo) { 'va al respaldo' } else { 'se borra' })): $(Get-Nombres $pruebasViejas)") }
    if ($configOmitida.Count) { $descripcion.Add("No se toca la configuración: quedan nombres viejos u opciones que ya no existen en $(Get-Nombres $configOmitida), y las opciones y los mutadores elegidos de versiones anteriores no se pasan al nombre nuevo") }

    if ($bloqueo) {
        $aCopiar = @(); $aReemplazar = @(); $archivosViejos = @(); $inis = @(); $pruebasViejas = @(); $configOmitida = @()
        $descripcion.Clear(); $avisos.Clear(); $avisosResultado.Clear()
    }

    [pscustomobject]@{
        Bloqueo        = $bloqueo
        Sistema        = $Sistema
        Version        = $Origen.Version
        Paquete        = $Origen.Paquete
        ConfigOmitida  = $configOmitida
        ConRespaldo    = $ConRespaldo
        ACopiar        = $aCopiar
        AReemplazar    = $aReemplazar
        ArchivosViejos = $archivosViejos
        Inis           = $inis
        PruebasViejas  = $pruebasViejas
        Avisos         = $avisos
        AvisosResultado  = $avisosResultado
        Descripcion    = $descripcion
        NadaQueHacer   = ($aCopiar.Count + $archivosViejos.Count + $inis.Count + $pruebasViejas.Count) -eq 0
    }
}

# Paso 3: hacerlo. Devuelve lo que se hizo y la carpeta de respaldo; si no puede copiar, tira un error.
function Invoke-Plan {
    param($Plan)
    $lineas = New-Object System.Collections.Generic.List[string]
    $sistema = $Plan.Sistema

    # El respaldo queda al lado del instalador, no dentro del juego.
    # Solo la fecha; si ya hay un respaldo de hoy, se agrega -2, -3...
    # Sin respaldo se usa una carpeta temporal (para poder deshacer si falla una copia) que al final se borra.
    $respaldo = $null
    if ($Plan.AReemplazar.Count -or $Plan.ArchivosViejos.Count -or $Plan.Inis.Count -or $Plan.PruebasViejas.Count) {
        if ($Plan.ConRespaldo) {
            $base = Join-Path $PSScriptRoot ('Respaldo-instalacion-' + (Get-Date -Format 'yyyy-MM-dd'))
            $respaldo = $base
            $n = 2
            while (Test-Path -LiteralPath $respaldo) { $respaldo = "$base-$n"; $n++ }
        } else {
            $respaldo = Join-Path ([IO.Path]::GetTempPath()) ('MutadoresIrreales-instalacion-' + [guid]::NewGuid().ToString('N'))
        }
        New-Item -ItemType Directory -Path $respaldo | Out-Null
    }

    # Si algo falla, se deshace todo: se borran las copias nuevas, vuelven los archivos que se sacaron
    # y los .ini vuelven a como estaban (su copia está en la carpeta de respaldo o en la temporal)
    $movidos = New-Object System.Collections.Generic.List[string]     # rutas originales de lo que se movió
    $copiando = New-Object System.Collections.Generic.List[string]    # copias nuevas en System
    $inisTocados = New-Object System.Collections.Generic.List[string] # .ini que ya tienen su copia guardada
    $detalleInis = New-Object System.Collections.Generic.List[string]
    try {
        foreach ($f in $Plan.AReemplazar) { Move-Item -LiteralPath $f -Destination $respaldo; $movidos.Add($f) }
        foreach ($f in $Plan.ACopiar) {
            $destino = Join-Path $sistema (Split-Path $f -Leaf)
            $copiando.Add($destino)
            Copy-Item -LiteralPath $f -Destination $destino
            if ((Get-Hash $f) -ne (Get-Hash $destino)) { throw "La copia de $(Split-Path $f -Leaf) no salió igual al original." }
        }
        foreach ($f in @($Plan.ArchivosViejos) + @($Plan.PruebasViejas)) {
            Move-Item -LiteralPath $f.FullName -Destination $respaldo
            $movidos.Add($f.FullName)
        }
        foreach ($ini in $Plan.Inis) {
            $texto = $Latin1.GetString([IO.File]::ReadAllBytes($ini.FullName))
            $resultado = Convert-Ini $texto $Plan.Paquete
            Copy-Item -LiteralPath $ini.FullName -Destination $respaldo
            $inisTocados.Add($ini.FullName)
            [IO.File]::WriteAllBytes($ini.FullName, $Latin1.GetBytes($resultado.Texto))
            $detalleInis.Add('')
            $detalleInis.Add("$($ini.Name):")
            foreach ($c in $resultado.Cambios) { $detalleInis.Add($c) }
        }
    } catch {
        $motivo = $_.Exception.Message
        $sinDevolver = @()
        foreach ($c in $copiando) { Remove-Item -LiteralPath $c -Force -ErrorAction SilentlyContinue }
        foreach ($i in $inisTocados) {
            try { Copy-Item -LiteralPath (Join-Path $respaldo (Split-Path $i -Leaf)) -Destination $i -Force -ErrorAction Stop }
            catch { $sinDevolver += (Split-Path $i -Leaf) }
        }
        foreach ($m in $movidos) {
            try { Move-Item -LiteralPath (Join-Path $respaldo (Split-Path $m -Leaf)) -Destination $m -Force -ErrorAction Stop }
            catch { $sinDevolver += (Split-Path $m -Leaf) }
        }
        # Sin respaldo, la carpeta temporal ya no hace falta si todo volvió a su lugar
        if ($sinDevolver.Count -eq 0 -and -not $Plan.ConRespaldo) { Remove-Item -LiteralPath $respaldo -Recurse -Force -ErrorAction SilentlyContinue }
        $mensaje = "No se pudo completar la instalación: $motivo"
        if ($sinDevolver.Count) { $mensaje += "`r`nNo se pudieron devolver a System: $($sinDevolver -join ', '). Están en $respaldo; copialos a mano a la carpeta System." }
        else { $mensaje += "`r`nSe deshizo todo: System y la configuración quedaron como estaban." }
        throw "$mensaje`r`nRevisá que el juego esté cerrado y volvé a correr la instalación."
    }
    if ($Plan.ACopiar.Count) { $lineas.Add("Copiados en System: $(Get-Nombres $Plan.ACopiar)") }
    if ($Plan.ArchivosViejos.Count) { $lineas.Add("Sacados de System: $(Get-Nombres $Plan.ArchivosViejos)") }
    foreach ($d in $detalleInis) { $lineas.Add($d) }

    # Resumen: solo lo que corresponde a lo que se hizo
    $resumen = New-Object System.Collections.Generic.List[string]
    $copiados = @($Plan.ACopiar | ForEach-Object { Split-Path $_ -Leaf })
    $instaloMutadores = $copiados -contains "$Nuevo.u"
    $instaloPruebas = $copiados -contains 'IrrealTest.u'
    $hayMutadores = Test-Path -LiteralPath (Join-Path $sistema "$Nuevo.u")
    $ver = if ($Plan.Version) { " $($Plan.Version)" } else { '' }
    if ($instaloMutadores) { $resumen.Add("Listo: se instalaron los Mutadores Irreales$ver.") }
    if ($instaloPruebas) { $resumen.Add($(if ($instaloMutadores) { 'También' } else { 'Listo:' }) + ' se instaló IrrealTest, el mutador de pruebas. Para usarlo, activá "[Irreal_Test] PRUEBAS (no distribuir)" en el menú de mutadores.') }
    if (-not $instaloMutadores -and -not $instaloPruebas) {
        if ($hayMutadores) { $resumen.Add('Listo: se limpió lo que quedaba de versiones anteriores.') }
        else { $resumen.Add("Listo lo viejo. Falta instalar ${Nuevo}: extraé su zip y corré el instalador desde ahí.") }
    }
    if ($Plan.ArchivosViejos.Count -and $hayMutadores) { $resumen.Add('Al abrir el juego, los mutadores "[Irreal] ..." tienen que aparecer una sola vez.') }
    if ($Plan.Inis.Count) { $resumen.Add('La configuración quedó al día: se conservan las opciones de los mutadores y los que estaban elegidos en el menú.') }
    if ($Plan.ConfigOmitida.Count) { $resumen.Add('No se tocó la configuración del juego.') }
    if ($Plan.PruebasViejas.Count) { $resumen.Add('Se sacó un IrrealTest de otra versión, que ya no funcionaba. Si lo usan, instalen el zip Pruebas-IrrealTest de esta versión.') }
    if ($instaloMutadores) { $resumen.Add('El host y todos los jugadores tienen que tener la misma versión.') }
    elseif ($instaloPruebas) { $resumen.Add('Si el host activa IrrealTest, todos los jugadores tienen que tenerlo.') }
    if ($Plan.AvisosResultado.Count) { $resumen.Add(''); foreach ($a in $Plan.AvisosResultado) { $resumen.Add($a) } }
    if ($respaldo -and $Plan.ConRespaldo) { $resumen.Add(''); $resumen.Add("Respaldo (se puede borrar cuando todo ande): $respaldo") }
    if ($respaldo -and -not $Plan.ConRespaldo) {
        Remove-Item -LiteralPath $respaldo -Recurse -Force -ErrorAction SilentlyContinue
        $resumen.Add(''); $resumen.Add('No se guardó copia de respaldo: lo que se sacó se borró.')
        $respaldo = $null
    }
    [pscustomobject]@{ Detalle = $lineas; Resumen = $resumen; Respaldo = $respaldo }
}

$Extensiones = 'u', 'ucl', 'int', 'est'
$TextoAbierto = 'UT2004 (o un servidor) está abierto. Cerralo antes de instalar: si no, el juego vuelve a escribir la configuración al salir.'

# ---------------------------------------------------------------------------------------------
# Modo consola (-Consola o -Si): el mismo instalador sin ventana
# ---------------------------------------------------------------------------------------------
function Start-Consola {
    Write-Host ''
    Write-Host 'Instalación de los Mutadores Irreales'
    Write-Host '====================================='
    $origen = Get-Origen
    if ($origen.Version) { Write-Host "Versión: $($origen.Version)" }
    if ($origen.Error) { Write-Host $origen.Error; Write-Host 'No se cambió nada.'; exit 1 }

    $sistema = if ($Carpeta) { Resolve-CarpetaSystem $Carpeta } else { Find-CarpetaSystem }
    if (-not $sistema -and -not $Si) {
        Write-Host 'No se encontró la carpeta del juego.'
        $sistema = Resolve-CarpetaSystem (Read-Host 'Pegá la ruta de la carpeta System de UT2004')
    }
    if (-not $sistema) { Write-Host 'No hay un UT2004.ini en esa carpeta. No se cambió nada.'; exit 1 }
    Write-Host "Carpeta System: $sistema"
    if (Test-JuegoAbierto) { Write-Host $TextoAbierto; Write-Host 'No se cambió nada.'; exit 1 }

    try { $plan = Get-Plan $origen $sistema (-not $SinConfiguracion) (-not $SinRespaldo) }
    catch { Write-Host "No se pudo revisar la carpeta del juego: $($_.Exception.Message)"; Write-Host 'No se cambió nada.'; exit 1 }
    # Los avisos que se repiten en el resultado se muestran solo ahí
    if ($plan.Bloqueo) { Write-Host $plan.Bloqueo; Write-Host 'No se cambió nada.'; exit 1 }
    foreach ($a in $plan.Avisos) { if ($plan.AvisosResultado -notcontains $a -or $plan.NadaQueHacer) { Write-Host $a } }
    if ($plan.NadaQueHacer) { Write-Host 'Ya está todo instalado. No hace falta hacer nada.'; exit 0 }

    Write-Host ''
    foreach ($d in $plan.Descripcion) { Write-Host $d }
    if (-not $Si) {
        $respuesta = Read-Host '¿Continuar? [s/N]'
        if ($respuesta -notmatch '^(s|si|sí)$') { Write-Host 'Cancelado. No se cambió nada.'; exit 1 }
    }
    try { $resultado = Invoke-Plan $plan } catch { Write-Host ''; Write-Host $_.Exception.Message; exit 1 }
    Write-Host ''
    foreach ($l in $resultado.Detalle) { Write-Host $l }
    Write-Host ''
    foreach ($l in $resultado.Resumen) { Write-Host $l }
    exit 0
}

# ---------------------------------------------------------------------------------------------
# Ventana (lo normal al hacer doble clic en Instalar-MutadoresIrreales.cmd)
# ---------------------------------------------------------------------------------------------
function Start-Ventana {
    Add-Type -AssemblyName System.Windows.Forms, System.Drawing
    [System.Windows.Forms.Application]::EnableVisualStyles()

    $script:Origen = Get-Origen
    $script:Sistema = if ($Carpeta) { Resolve-CarpetaSystem $Carpeta } else { Find-CarpetaSystem }
    $script:Respaldo = $null

    $fuente = New-Object System.Drawing.Font('Segoe UI', 10)
    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'Instalar Mutadores Irreales'
    $form.Font = $fuente
    $form.ClientSize = New-Object System.Drawing.Size(680, 470)
    $form.MinimumSize = New-Object System.Drawing.Size(560, 400)
    $form.StartPosition = 'CenterScreen'
    try { $form.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon((Join-Path $PSHOME 'powershell.exe')) } catch { }

    $titulo = New-Object System.Windows.Forms.Label
    $titulo.Text = if ($script:Origen.Version) { "Mutadores Irreales $($script:Origen.Version)" } else { 'Mutadores Irreales' }
    $titulo.Font = New-Object System.Drawing.Font('Segoe UI', 15, [System.Drawing.FontStyle]::Bold)
    $titulo.Location = New-Object System.Drawing.Point(14, 12)
    $titulo.AutoSize = $true

    $sub = New-Object System.Windows.Forms.Label
    $sub.Text = 'Instala los mutadores en Unreal Tournament 2004. El juego tiene que estar cerrado.'
    $sub.Location = New-Object System.Drawing.Point(16, 50)
    $sub.AutoSize = $true

    $lblCarpeta = New-Object System.Windows.Forms.Label
    $lblCarpeta.Text = 'Carpeta System del juego:'
    $lblCarpeta.Location = New-Object System.Drawing.Point(16, 86)
    $lblCarpeta.AutoSize = $true

    $txtCarpeta = New-Object System.Windows.Forms.TextBox
    $txtCarpeta.ReadOnly = $true
    $txtCarpeta.Location = New-Object System.Drawing.Point(16, 110)
    $txtCarpeta.Size = New-Object System.Drawing.Size(530, 27)
    $txtCarpeta.Anchor = 'Top, Left, Right'

    $btnCambiar = New-Object System.Windows.Forms.Button
    $btnCambiar.Text = 'Cambiar…'
    $btnCambiar.Location = New-Object System.Drawing.Point(556, 108)
    $btnCambiar.Size = New-Object System.Drawing.Size(108, 30)
    $btnCambiar.Anchor = 'Top, Right'

    $lblPlan = New-Object System.Windows.Forms.Label
    $lblPlan.Text = 'Qué se va a hacer:'
    $lblPlan.Location = New-Object System.Drawing.Point(16, 150)
    $lblPlan.AutoSize = $true

    $txtPlan = New-Object System.Windows.Forms.TextBox
    $txtPlan.Multiline = $true
    $txtPlan.ReadOnly = $true
    $txtPlan.ScrollBars = 'Vertical'
    $txtPlan.BackColor = [System.Drawing.SystemColors]::Window
    $txtPlan.Location = New-Object System.Drawing.Point(16, 174)
    $txtPlan.Size = New-Object System.Drawing.Size(648, 206)
    $txtPlan.Anchor = 'Top, Bottom, Left, Right'

    $chkConfig = New-Object System.Windows.Forms.CheckBox
    $chkConfig.Text = 'Actualizar la configuración del juego (recomendado)'
    $chkConfig.Checked = $true
    $chkConfig.AutoSize = $true
    $chkConfig.Location = New-Object System.Drawing.Point(16, 394)
    $chkConfig.Anchor = 'Bottom, Left'
    $ayuda = New-Object System.Windows.Forms.ToolTip
    $ayuda.SetToolTip($chkConfig, 'Pasa las opciones y los mutadores elegidos al nombre nuevo y borra lo que ya no existe en UT2004.ini y User.ini (con copia en el respaldo, salvo que se elija no guardarla). Si no se tilda, esos archivos no se tocan.')

    $chkSinRespaldo = New-Object System.Windows.Forms.CheckBox
    $chkSinRespaldo.Text = 'No guardar copia de respaldo'
    $chkSinRespaldo.Checked = [bool]$SinRespaldo
    $chkSinRespaldo.AutoSize = $true
    $chkSinRespaldo.Location = New-Object System.Drawing.Point(16, 424)
    $chkSinRespaldo.Anchor = 'Bottom, Left'
    $ayuda.SetToolTip($chkSinRespaldo, 'Lo que se saca de System se borra y los .ini se cambian sin guardar una copia. Si no se tilda, todo queda en una carpeta Respaldo-instalacion-<fecha> al lado del instalador.')

    $btnRespaldo = New-Object System.Windows.Forms.Button
    $btnRespaldo.Text = 'Abrir respaldo'
    $btnRespaldo.Location = New-Object System.Drawing.Point(16, 420)
    $btnRespaldo.Size = New-Object System.Drawing.Size(140, 34)
    $btnRespaldo.Anchor = 'Bottom, Left'
    $btnRespaldo.Visible = $false

    $btnInstalar = New-Object System.Windows.Forms.Button
    $btnInstalar.Text = 'Instalar'
    $btnInstalar.Location = New-Object System.Drawing.Point(444, 420)
    $btnInstalar.Size = New-Object System.Drawing.Size(110, 34)
    $btnInstalar.Anchor = 'Bottom, Right'

    $btnCerrar = New-Object System.Windows.Forms.Button
    $btnCerrar.Text = 'Cerrar'
    $btnCerrar.Location = New-Object System.Drawing.Point(564, 420)
    $btnCerrar.Size = New-Object System.Drawing.Size(100, 34)
    $btnCerrar.Anchor = 'Bottom, Right'
    $btnCerrar.DialogResult = 'Cancel'

    $form.Controls.AddRange(@($titulo, $sub, $lblCarpeta, $txtCarpeta, $btnCambiar, $lblPlan, $txtPlan, $chkConfig, $chkSinRespaldo, $btnRespaldo, $btnInstalar, $btnCerrar))
    $form.AcceptButton = $btnInstalar
    $form.CancelButton = $btnCerrar

    # Vuelve a calcular qué hay que hacer y lo muestra
    $actualizar = {
        $txtCarpeta.Text = if ($script:Sistema) { $script:Sistema } else { '(no se encontró)' }
        $btnInstalar.Enabled = $false
        if ($script:Origen.Error) { $txtPlan.Text = $script:Origen.Error; $btnCambiar.Enabled = $false; return }
        if (-not $script:Sistema) {
            $txtPlan.Text = 'No se encontró la carpeta del juego. Tocá "Cambiar…" y elegí la carpeta de Unreal Tournament 2004 (o su carpeta System).'
            return
        }
        try {
            $plan = Get-Plan $script:Origen $script:Sistema $chkConfig.Checked (-not $chkSinRespaldo.Checked)
        } catch {
            $txtPlan.Text = "No se pudo revisar la carpeta del juego:`r`n$($_.Exception.Message)`r`n`r`nRevisá que la carpeta sea la correcta (Cambiar…) o probá con la versión de consola: Instalar-MutadoresIrreales.cmd -Consola"
            return
        }
        if ($plan.Bloqueo) { $txtPlan.Text = $plan.Bloqueo; return }
        $lineas = New-Object System.Collections.Generic.List[string]
        if ($plan.NadaQueHacer) {
            $lineas.Add('Ya está todo instalado. No hace falta hacer nada.')
        } else {
            foreach ($d in $plan.Descripcion) { $lineas.Add("• $d") }
            if ($plan.AReemplazar.Count -or $plan.ArchivosViejos.Count -or $plan.Inis.Count -or $plan.PruebasViejas.Count) {
                $lineas.Add('')
                if ($plan.ConRespaldo) { $lineas.Add('Todo lo que se saca o se cambia queda en una carpeta de respaldo, al lado del instalador.') }
                else { $lineas.Add('No se guarda copia de respaldo: lo que se saca se borra y la configuración se cambia sin copia.') }
            }
            $btnInstalar.Enabled = $true
        }
        if ($plan.Avisos.Count) { $lineas.Add(''); foreach ($a in $plan.Avisos) { $lineas.Add($a) } }
        if (Test-JuegoAbierto) { $lineas.Add(''); $lineas.Add("Atención: $TextoAbierto") }
        $txtPlan.Text = $lineas -join "`r`n"
    }

    $btnCambiar.Add_Click({
        $dialogo = New-Object System.Windows.Forms.FolderBrowserDialog
        $dialogo.Description = 'Elegí la carpeta de Unreal Tournament 2004 (o su carpeta System)'
        if ($script:Sistema) { $dialogo.SelectedPath = $script:Sistema }
        if ($dialogo.ShowDialog($form) -ne 'OK') { return }
        $elegida = Resolve-CarpetaSystem $dialogo.SelectedPath
        if (-not $elegida) {
            [void][System.Windows.Forms.MessageBox]::Show($form, 'En esa carpeta no está UT2004.ini. Elegí la carpeta de Unreal Tournament 2004 o su carpeta System.', 'Carpeta incorrecta', 'OK', 'Warning')
            return
        }
        $script:Sistema = $elegida
        & $actualizar
    })

    $btnInstalar.Add_Click({
        if (Test-JuegoAbierto) {
            [void][System.Windows.Forms.MessageBox]::Show($form, "$TextoAbierto`r`n`r`nCerralo y volvé a tocar Instalar.", 'El juego está abierto', 'OK', 'Warning')
            & $actualizar
            return
        }
        $form.Cursor = 'WaitCursor'
        $btnInstalar.Enabled = $false
        $btnCambiar.Enabled = $false
        try {
            $plan = Get-Plan $script:Origen $script:Sistema $chkConfig.Checked (-not $chkSinRespaldo.Checked)
            if ($plan.Bloqueo) { throw $plan.Bloqueo }
            $resultado = Invoke-Plan $plan
            $txtPlan.Text = ((@($resultado.Resumen) + @('', 'Detalle:', '') + @($resultado.Detalle)) -join "`r`n")
            $script:Respaldo = $resultado.Respaldo
            $chkConfig.Visible = $false
            $chkSinRespaldo.Visible = $false
            if ($script:Respaldo) { $btnRespaldo.Visible = $true }
            $btnInstalar.Text = 'Instalado'
            $lblPlan.Text = 'Resultado:'
        } catch {
            $txtPlan.Text = "No se pudo completar la instalación.`r`n`r`n$($_.Exception.Message)"
            [void][System.Windows.Forms.MessageBox]::Show($form, $_.Exception.Message, 'No se pudo instalar', 'OK', 'Error')
            $btnCambiar.Enabled = $true
            $btnInstalar.Enabled = $true
        } finally {
            $form.Cursor = 'Default'
        }
    })

    $chkConfig.Add_CheckedChanged({ & $actualizar })
    $chkSinRespaldo.Add_CheckedChanged({ & $actualizar })
    $btnRespaldo.Add_Click({ if ($script:Respaldo) { Start-Process explorer.exe -ArgumentList "`"$script:Respaldo`"" } })

    $form.Add_Shown({ & $actualizar; $form.Activate() })
    [void]$form.ShowDialog()
    $form.Dispose()
    exit 0
}

if ($Si -or $Consola) {
    Start-Consola
} else {
    try {
        Start-Ventana
    } catch {
        # Si la ventana no se puede mostrar, el mismo instalador en una consola visible
        $mensaje = $_.Exception.Message
        try {
            [void][System.Windows.Forms.MessageBox]::Show("No se pudo abrir la ventana del instalador:`r`n$mensaje`r`n`r`nSe abre la versión de consola.", 'Instalador', 'OK', 'Warning')
        } catch { }
        $argumentos = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-NoExit', '-File', "`"$PSCommandPath`"", '-Consola')
        if ($Carpeta) { $argumentos += @('-Carpeta', "`"$Carpeta`"") }
        if ($SinRespaldo) { $argumentos += '-SinRespaldo' }
        if ($SinConfiguracion) { $argumentos += '-SinConfiguracion' }
        Start-Process powershell.exe -ArgumentList $argumentos
        exit 1
    }
}
