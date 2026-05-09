<#
.SYNOPSIS
    Script para procesar archivos CSV con opciones de filtrado, conteo y suma.
.DESCRIPTION
    Este script permite procesar un archivo CSV especificado por el usuario, aplicando un filtro en una columna determinada, y luego realizar una operación de conteo o suma sobre los resultados filtrados.
.PARAMETER Archivo
    Ruta al archivo CSV que se desea procesar.
.PARAMETER Filtro
    Nombre de la columna que se utilizará para aplicar el filtro.
.PARAMETER Buscar
    Valor que se buscará en la columna especificada por el filtro.
.PARAMETER Contar
    Si se especifica, el script contará el número de filas que coinciden con el filtro.
.PARAMETER Sumar
    Si se especifica, el script sumará los valores de la columna indicada para las filas que coinciden con el filtro.
.EXAMPLE
    .\ejercicio1.ps1 -Archivo "datos.csv" -Filtro "Categoria" -Buscar "Electrónica" -Contar
    Este comando contará el número de filas en el archivo "datos.csv" donde la columna "Categoria" tiene el valor "Electrónica".
.EXAMPLE
    .\ejercicio1.ps1 -Archivo "datos.csv" -Filtro "Categoria" -Buscar "Electrónica" -Sumar "Precio"
    Este comando sumará los valores de la columna "Precio" para las filas en el archivo "datos.csv" donde la columna "Categoria" tiene el valor "Electrónica".
.NOTES
    - Asegúrese de que el archivo CSV tenga una fila de encabezado con los nombres de las columnas.
    - El script requiere que se especifique al menos una de las opciones -Contar o -Sumar para realizar una operación sobre los datos filtrados.
.NOTES
    - Autor: Tomas Ballesteros, Nicolas Catania, Rodrigo Ezequiel Aragón, Villan Matias Nicolas, Luciano martins louro
#>

[CmdletBinding(DefaultParameterSetName="Contar")]
param(
    [Parameter(Mandatory= $true, Position=0)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [validateScript({ $_.EndsWith(".csv") })]
    [Alias("a")]
    [string]$Archivo,


    [Parameter(mandatory= $false)]
    [ValidateNotNullOrEmpty()]
    [Alias("f")]
    [string]$Filtro,


    [Parameter(mandatory= $false)]
    [ValidateNotNullOrEmpty()]
    [Alias("b")]
    [string]$Buscar,

    [Parameter(Mandatory= $true, ParameterSetName="Contar")]
    [Alias("c")]
    [switch]$Contar,

    [Parameter(Mandatory= $true, ParameterSetName="Sumar")]
    [Alias("s")]
    [ValidateNotNullOrEmpty()]
    [string]$Sumar
)

if (($Filtro -and -not $Buscar) -or (-not $Filtro -and $Buscar)) {
    throw "Error: Los parámetros -Filtro y -Buscar deben usarse juntos."
}

try {
    $datos = Import-Csv -Path $Archivo

    Write-Host "=== PROCESANDO CSV ===" 
    write-host "archivo: $Archivo" 
    Write-Host "Columnas disponibles: $($datos[0].PSObject.Properties.Name -join ", ")" 
    Write-Host "----------------------------------------" 

    if ($Filtro) {
        if (-not ($datos[0].PSObject.Properties.Name -contains $Filtro)) {
            throw "Error: El campo '$Filtro' no existe en el archivo CSV."
        }
        $registros = $datos | Where-Object { $_.$Filtro -like "*$Buscar*" }
        Write-Host "Filtro aplicado: $Filtro contiene '$Buscar'" 
    }
    else {
        $registros = $datos
    }

        $registros | Format-Table -AutoSize

    if ($Contar) {
        $resultado = $registros.Count
        Write-Host "Operación: Contar registros"
        Write-Host "Registros encontrados: $resultado"
    }else {
        if (-not ($datos[0].PSObject.Properties.Name -contains $Sumar)) {
            throw "Error: El campo '$Sumar' no existe en el archivo CSV."
            exit 1
        }

        $resultado = ($registros | Measure-Object -Property $Sumar -Sum).Sum
        Write-Host "Operación: Sumar valores de la columna '$Sumar'"
        Write-Host "Resultado de la suma: $resultado"
    }
}
catch {
    throw "Error: No se pudo importar el archivo CSV."
}