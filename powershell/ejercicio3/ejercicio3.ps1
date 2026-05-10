param(
    [Parameter(Mandatory = $true)]
    [string]$Directorio
)

$DirectorioOriginal = $Directorio

if (-not (Test-Path -LiteralPath $Directorio -PathType Container)) {
    if ([System.IO.Path]::DirectorySeparatorChar -eq '/' -and $Directorio -match '^(?<unidad>[a-zA-Z]):[\\/](?<resto>.*)$') {
        $unidad = $Matches['unidad'].ToLower()
        $resto = $Matches['resto'] -replace '\\', '/'
        $Directorio = "/mnt/$unidad/$resto"
    }

    if (-not (Test-Path -LiteralPath $Directorio -PathType Container)) {
        Write-Error "La ruta '$DirectorioOriginal' no existe o no es un directorio."
        exit 1
    }
}

try {
    $Directorio = (Resolve-Path -LiteralPath $Directorio -ErrorAction Stop).Path

    Get-ChildItem -LiteralPath $Directorio -Recurse -File -ErrorAction Stop |
        Group-Object Name, Length |
        Where-Object { $_.Count -gt 1 } |
        ForEach-Object {
            $_.Group | Select-Object Name, Length, FullName
            ""
        }
}
catch {
    Write-Error "No se pudo procesar '$DirectorioOriginal'. Detalle: $($_.Exception.Message)"
    exit 1
}
