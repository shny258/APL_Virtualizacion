<#
.SYNOPSIS
    Procesa un archivo de texto aplicando reglas de puntuación y formato.
#>

param (
    [Parameter(Mandatory=$false)]
    [Alias("a", "archivo")] #Reconoce -a y -archivo
    [string]$ArchivoEntrada,

    [Parameter(Mandatory=$false)]
    [Alias("s", "salida")]  #Reconoce -s y -salida
    [string]$ArchivoSalida,

    [Parameter(Mandatory=$false)]
    [Alias("h", "help")]    #Reconoce -h y -help
    [switch]$MostrarAyuda
)

# --- Función de Ayuda (Uso) ---
function Show-Usage {
    Write-Host @"
    Uso: .\ejercicio2.ps1 -a <ruta_archivo> [-s <ruta_salida>] [-h]

Opciones:
  -a, -archivo    Archivo de entrada (Obligatorio)
  -s, -salida     Archivo de salida (Opcional)
  -h, -help       Muestra esta ayuda
"@
    exit
}

# Si el usuario pide ayuda o no pone el parámetro obligatorio, mostrar uso
if ($MostrarAyuda) {
    Show-Usage
}

# 1. Validaciones de seguridad
# Validar que ArchivoEntrada tenga un valor real (no solo el parámetro vacío)
if ([string]::IsNullOrWhiteSpace($ArchivoEntrada)) {
    Write-Host "Error: El parámetro -ArchivoEntrada requiere un nombre de archivo." -ForegroundColor Red
    Show-Usage
}

# Validar que si se puso el parámetro de salida, no esté vacío
# (PSBoundParameters comprueba si el usuario escribió el parámetro en la consola)
if ($PSBoundParameters.ContainsKey('ArchivoSalida') -and [string]::IsNullOrWhiteSpace($ArchivoSalida)) {
    Write-Host "Error: Se especificó -ArchivoSalida pero no se indicó un nombre de archivo." -ForegroundColor Red
    Show-Usage
}

# --- 2. Validaciones de Archivos en Disco ---
if (-not (Test-Path -Path $ArchivoEntrada -PathType Leaf)) {
    Write-Host "Error: El archivo de entrada '$ArchivoEntrada' no existe." -ForegroundColor Red
    exit 1
}

if ($ArchivoSalida) {
    $null | Out-File -FilePath $ArchivoSalida -Force
}

# 3. Función de procesamiento de texto
function ProcessText {
    param ([string]$l)

    # --- A. Espaciado y Formato ---
    $l = $l -replace '\s+', ' '        # Colapsar espacios
    $l = $l.Trim()                     # Trim inicial y final
    if ([string]::IsNullOrWhiteSpace($l)) { return $null }

    # --- B. Signos de Apertura (¿ y ¡) ---
    # Coloca el signo al inicio de la frase si termina en cierre y no tiene apertura
    $l = $l -replace '(^|[.!?]\s+)([^¿¡\s][^.!?]*)\?', '$1¿$2?'
    $l = $l -replace '(^|[.!?]\s+)([^¿¡\s][^.!?]*)\!', '$1¡$2!'

    # --- C. Mayúsculas ---
    # Usamos un callback de Regex para convertir a mayúsculas tras signos y al inicio
    $callback = {
        param($match)
        return $match.Groups[1].Value + $match.Groups[2].Value.ToUpper()
    }
    
    # Inicio del texto y después de . ! ? (incluyendo si hay signos de apertura)
    $l = [regex]::Replace($l, "(^|[.!?]\s+)([a-z¿¡])", $callback)
    
    # Caso especial: signo de apertura seguido de letra (ej: ¿c -> ¿C)
    $l = [regex]::Replace($l, "(¿|¡)([a-z])", { param($m) $m.Groups[1].Value + $m.Groups[2].Value.ToUpper() })

    # --- D. Puntuación y Limpieza ---
    $l = $l -replace "'", '"'          # Unificar comillas
    $l = $l -replace '\.{4,}', '...'   # Normalizar puntos suspensivos

    # Eliminar comas redundantes (al final o antes de punto/signo)
    $l = $l -replace ',(?=\s*$)', ''
    $l = $l -replace ',\s*([.!?])', '$1'

    # Protegemos puntos suspensivos para el espaciado
    $l = $l -replace '\.\.\.', '@DOTS@'
    
    # Espaciado: No antes, uno después
    $l = $l -replace '\s+([.,;:?!])', '$1'
    $l = $l -replace '([.,;:?!])(?!\s|$)', '$1 '
    
    # Restauramos puntos suspensivos
    $l = $l -replace '@DOTS@', '...'

    # --- E. Asegurar cierre de párrafo ---
    if ($l -notmatch '[.?!]$') {
        $l += "."
    }

    return $l
}

# 4. Procesar el archivo línea por línea
try {
    $lineas = Get-Content -Path $ArchivoEntrada
    foreach ($linea in $lineas) {
        if (-not [string]::IsNullOrWhiteSpace($linea)) {
            $lineaFinal = ProcessText -l $linea
            
            if ($null -ne $lineaFinal) {
                if ($ArchivoSalida) {
                    $lineaFinal | Out-File -FilePath $ArchivoSalida -Append -Encoding utf8
                } else {
                    Write-Host $lineaFinal
                }
            }
        }
    }

    if ($ArchivoSalida) {
        Write-Host "¡Listo! El procesamiento finalizó y se guardó en '$ArchivoSalida'." -ForegroundColor Green
    }
} catch {
    Write-Error "Ocurrió un error al procesar el archivo: $_"
}