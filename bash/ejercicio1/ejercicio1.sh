#!/bin/bash

# Función de ayuda (Help)
mostrar_ayuda() {
    echo "Uso: $0 [OPCIONES]"
    echo ""
    echo "Descripción:"
    echo "  Script para filtrar, contar o sumar registros de un archivo CSV."
    echo ""
    echo "Opciones:"
    echo "  -a, --archivo PATH    Ruta al archivo CSV (Obligatorio)."
    echo "  -f, --filtro CAMPO    Nombre de la columna para filtrar."
    echo "  -b, --buscar PATRON   Texto o patrón a buscar en la columna de filtro."
    echo "  -c, --contar          Cuenta la cantidad de registros que cumplen el filtro."
    echo "  -s, --sumar CAMPO     Suma los valores de la columna indicada."
    echo "  -h, --help            Muestra este mensaje de ayuda."
    echo ""
    echo "Ejemplos:"
    echo "  $0 -a datos.csv -f Provincia -b Cordoba -s Poblacion"
    echo "  $0 -a datos.csv -c"
    exit 0
}

# Inicialización de variables
ARCHIVO=""
FILTRO=""
BUSCAR=""
CONTAR=0
SUMAR=""

# Procesamiento de parámetros (Soporta cualquier orden y -h/--help)
OPTS=$(getopt -o a:f:b:s:ch --l archivo:,filtro:,buscar:,sumar:,contar,help -- "$@" 2> /dev/null)
if [ $? -ne 0 ]; then
    echo "ERROR: Parámetros inválidos."
    echo "Use -h o --help para ver las opciones disponibles."
    exit 1
fi

eval set -- "$OPTS"

while true; do
    case "$1" in
        -a|--archivo) ARCHIVO="$2"; shift 2 ;;
        -f|--filtro)  FILTRO="$2";  shift 2 ;;
        -b|--buscar)  BUSCAR="$2";  shift 2 ;;
        -s|--sumar)   SUMAR="$2";   shift 2 ;;
        -c|--contar)  CONTAR=1;     shift 1 ;;
        -h|--help)    mostrar_ayuda ;;
        --) shift; break ;;
        *) echo "Error interno"; exit 1 ;;
    esac
done


# 1. Validar si no se pasaron parámetros
if [[ $# -eq 0 && -z "$ARCHIVO" ]]; then
    mostrar_ayuda
fi

# 2. Validar parámetro obligatorio: Archivo
if [[ -z "$ARCHIVO" ]]; then
    echo "ERROR: No se indicó el archivo de entrada. Use -a o --archivo."
    exit 1
fi

# 3. Validar existencia del archivo físico
if [[ ! -e "$ARCHIVO" ]]; then
    echo "ERROR: El archivo '$ARCHIVO' no existe."
    exit 1
fi

if [[ ! -f "$ARCHIVO" ]]; then
    echo "ERROR: '$ARCHIVO' no es un archivo válido."
    exit 1
fi

# 4. Validar que se elija una operación
if [[ "$CONTAR" -eq 0 && -z "$SUMAR" ]]; then
    echo "ERROR: Debe elegir una operación. Use --contar o --sumar [CAMPO]."
    exit 1
fi

# 5. Validar exclusividad
if [[ "$CONTAR" -eq 1 && -n "$SUMAR" ]]; then
    echo "ERROR: No puede usar --contar y --sumar al mismo tiempo. Elija solo una."
    exit 1
fi

# 6. Validar relación Filtro/Buscar
if [[ -n "$FILTRO" && -z "$BUSCAR" ]]; then
    echo "ERROR: Indicó el campo de filtro '$FILTRO' pero falta el patrón a buscar (-b)."
    exit 1
fi

if [[ -z "$FILTRO" && -n "$BUSCAR" ]]; then
    echo "ERROR: Indicó un patrón de búsqueda '$BUSCAR' pero falta el campo (-f)."
    exit 1
fi

# --- PROCESAMIENTO ---

CABECERA=$(head -1 "$ARCHIVO")

get_col_idx() {
    local campo=$1
    echo "$CABECERA" | awk -v c="$campo" -F',' '{
        for(i=1;i<=NF;i++) {
            if($i==c) { print i; exit }
        }
    }'
}

# Obtener índices y validar si los campos existen en el CSV
IDX_FILTRO=0
if [[ -n "$FILTRO" ]]; then
    IDX_FILTRO=$(get_col_idx "$FILTRO")
    if [[ -z "$IDX_FILTRO" ]]; then
        echo "ERROR: La columna de filtro '$FILTRO' no existe en el archivo."
        exit 1
    fi
fi

IDX_SUMA=0
if [[ -n "$SUMAR" ]]; then
    IDX_SUMA=$(get_col_idx "$SUMAR")
    if [[ -z "$IDX_SUMA" ]]; then
        echo "ERROR: La columna de suma '$SUMAR' no existe en el archivo."
        exit 1
    fi
fi

# (Resto del código de ejecución AWK y Reporte igual al anterior...)

if [[ $CONTAR -eq 1 ]]; then
    RESULTADO_FINAL=$(awk -F',' -v colF="$IDX_FILTRO" -v patF="$BUSCAR" 'BEGIN { res=0 } NR > 1 { if (colF == 0 || $colF ~ patF) res++ } END { printf "%d", res }' "$ARCHIVO")
else
    RESULTADO_FINAL=$(awk -F',' -v colF="$IDX_FILTRO" -v patF="$BUSCAR" -v colS="$IDX_SUMA" 'BEGIN { res=0 } NR > 1 { if (colF == 0 || $colF ~ patF) { res += $colS } } END { printf "%.2f", res }' "$ARCHIVO")
fi

echo "=========================================="
echo "      REPORTE DE PROCESAMIENTO CSV        "
echo "=========================================="
echo "Archivo: $ARCHIVO"
[[ $IDX_FILTRO -gt 0 ]] && echo "Filtro:  $FILTRO ~ '$BUSCAR'" || echo "Filtro:  Ninguno"
echo "------------------------------------------"

if [[ $CONTAR -eq 1 ]]; then
    printf "Operación: CUENTA DE REGISTROS\n"
    printf "Resultado: %g\n" "$RESULTADO_FINAL"
else
    printf "Operación: SUMATORIA DE %s\n" "$SUMAR"
    printf "Resultado: %.2f\n" "$RESULTADO_FINAL"
fi
echo "=========================================="