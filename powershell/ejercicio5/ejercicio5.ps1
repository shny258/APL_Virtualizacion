#!/usr/bin/pwsh

param(
    [Parameter(HelpMessage="ID o lista de IDs de personajes (ej: 1,2,3)")]
    [string[]]$Id,

    [Parameter(HelpMessage="Nombre o lista de nombres de personajes")]
    [string[]]$Nombre,

    [Parameter(HelpMessage="Borra la caché local antes de ejecutar")]
    [switch]$Clear
)

# Configuración
$ApiUrl = "https://rickandmortyapi.com/api/character"
$CacheDir = "./cache"

# Lógica de limpieza de caché
if ($Clear) {
    Write-Host "Borrando caché en $CacheDir..." -ForegroundColor Yellow
    Remove-Item -Path $CacheDir -Recurse -Force -ErrorAction SilentlyContinue
}

# Asegurar existencia de directorio de caché, sino lo creo
if (!(Test-Path $CacheDir)) { 
    New-Item -ItemType Directory -Path $CacheDir | Out-Null 
}
function Show-CharacterInfo ($Char) {
    Write-Host "`n[ Character Info ]" -ForegroundColor Cyan
    $Char | Select-Object `
        @{n='ID'; e={$_.id}},
        @{n='Name'; e={$_.name}},
        @{n='Status'; e={$_.status}},
        @{n='Species'; e={$_.species}},
        @{n='Origin'; e={$_.origin.name}},
        @{n='Location'; e={$_.location.name}},
        @{n='EpisodeCount'; e={$_.episode.Count}} | Format-List | Out-String | Write-Host
}

# --- Procesar IDs --- (misma logica de cache que en bash... busco si existe el id_x.json y devuelvo.. sino paso ese id a un array de ids pendientes que iran como pathvariable)
if ($Id) {
    Write-Host "--- Procesando IDs ---" -ForegroundColor Green
    $pendingIds = @()

    foreach ($currentId in $Id) {
        $path = Join-Path $CacheDir "id_$currentId.json"
        if (Test-Path $path) {
            Show-CharacterInfo (Get-Content $path | ConvertFrom-Json)
        } else {
            $pendingIds += $currentId
        }
    }

    if ($pendingIds.Count -gt 0) {
        try {
            $idsParam = $pendingIds -join ','
            $resp = Invoke-RestMethod -Uri "$ApiUrl/$idsParam" #se usa por defecto GEt que es justo lo que necesitamos... la api devuelve un json y pwsh lo pasa a un objeto
            
            # Aca fuerzo la rta a un array por simplicidad... ya que puede venir un solo obj o un obj dentro de un array
            $results = if ($resp -is [array]) { $resp } else { @($resp) }

            foreach ($p in $results) {
                Show-CharacterInfo $p
                $p | ConvertTo-Json -Depth 5 | Out-File (Join-Path $CacheDir "id_$($p.id).json") #como decia antes, pwsh pasa a objeto, pero la cache que planteamos es en json... asi como vino de la API por si en algun momento necesitamos otros campos, es mas escalable y no consume memoria extra significativa
            }
        } catch {
            Write-Error "Fallo en la consulta de API por ID: $_"
        }
    }
}

# --- Procesar Nombres --- misma logica que los ids...
if ($Nombre) {
    Write-Host "--- Procesando Nombres ---" -ForegroundColor Green
    foreach ($n in $Nombre) {
        $safeName = $n -replace '\s+', '-'
        $path = Join-Path $CacheDir "nombre_$safeName.json"

        if (Test-Path $path) {
            Write-Host "Cargando '$n' desde caché..."
            Show-CharacterInfo (Get-Content $path | ConvertFrom-Json)
        } else {
            try {
                $resp = Invoke-RestMethod -Uri "$ApiUrl/?name=$n"
                foreach ($p in $resp.results) {
                    Show-CharacterInfo $p
                    $p | ConvertTo-Json -Depth 5 | Out-File (Join-Path $CacheDir "nombre_$($p.name -replace '\s+', '-').json")
                }
            } catch {
                Write-Warning "No se encontró el personaje: $n"
            }
        }
    }
}