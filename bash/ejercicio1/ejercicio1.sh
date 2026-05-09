#!/bin/bash
# Integrantes: Tomas Ballesteros, Nicolas Catania, Rodrigo Ezequiel Aragón, Villan Matias Nicolas, Luciano martins louro 
# Ejercicio 1 - Manejo de archivos CSV - Bash
# Descripción: Realizar un script genérico que pueda leer registros de un CSV y realizar operaciones simples de filtros, suma y cuentas sobre los campos del mismo.
#El script deberá leer de la primera línea del archivo el nombre de los campos, nombres que se podrán utilizar en los parámetros para las operaciones
# Se debe poder filtrar un campo por un patrón de texto. Ejemplos: Pais = “Argentina”, Provincia = “San” (filtra tanto Santa Cruz, Santa Fe, San Juan y San Luis)
# Nota: El script debe ejecutarse en un entorno donde awk esté instalado y accesible.

function help() {
    echo "Ejercicio 1 - Manejo de archivos CSV - Bash"
    echo "Procesa un archivo CSV y realiza operaciones simples de filtros, suma y cuentas."
    echo "Uso: $0 -d|--directorio <dir> (-p|--pantalla | -a|--archivo <file>) [-h|--help]"
    echo "Ejemplo: $0 -d ./encuestas -a resultados.json"
    echo "Opciones:"
    echo "  -a, --archivo   Archivo CSV a procesar"
    echo "  -f, --filtro    Nombre del campo para aplicar el filtro (opcional)"
    echo "  -b, --buscar    Patrón a buscar en el campo filtro (opcional, requerido si se usó el parámetro filtro)"
    echo "  -c, --contar    Operación para Contar registros (no tiene valor)"
    echo "  -s, --sumar     Nombre del campo para la operación de suma"
    echo "  -h, --help      Muestra esta ayuda"
    exit 0
}

# Función para validar que el archivo existe y es un CSV
function validar_archivo() {
    if [[ ! -f "$1" ]]; then
        echo "Error: El archivo '$1' no existe."
        exit 1
    fi
    if [[ "${1##*.}" != "csv" ]]; then
        echo "Error: El archivo '$1' no es un archivo CSV."
        exit 1
    fi
}

function validar_parametros() {
    if [ -z $1 ]; then
        echo "Error: El archivo CSV es obligatorio" >&2
        exit 1
    fi
    if [ -n "$2" -a -z "$3" ] || [ -n "$3" -a -z "$2" ]; then
        echo "Error: Si se especifica un filtro tambien se debe especificar un patron de busqueda y viceversa" >&2
        exit 1
    fi
    if [ $4 = true ] && [ -n "$5" ]; then
        echo "Error: No se pueden usar las opciones contar y sumar al mismo tiempo" >&2
        exit 1
    fi
    if [ $4 = false ] && [ -z "$5" ]; then
        echo "Error: Se debe especificar una operacion a realizar (contar o sumar)" >&2
        exit 1
    fi
    validar_archivo "$1"
}

# Variables
archivo=""
filtro=""
buscar=""
contar=false
sumar=""

# Opciones
options=$(getopt -o a:f:b:cs:h --long archivo:,filtro:,buscar:,contar,sumar:,help -- "$@" 2>/dev/null)
if [ "$?" != 0 ]; then
    echo "Error: Opcion incorrecta" >&2
    exit 1
fi
eval set -- "$options"
while true; do
    case "$1" in
        -a|--archivo) archivo="$2"; shift 2 ;;
        -f|--filtro) filtro="$2"; shift 2 ;;
        -b|--buscar) buscar="$2"; shift 2 ;;
        -c|--contar) contar=true; shift ;;
        -s|--sumar) sumar="$2"; shift 2 ;;
        -h|--help) help; exit 0;;
        --) shift; break ;;
        *) echo "Error: Opcion desconocida: $1" >&2; exit 1 ;;
    esac
done

# Validaciones de parametros
validar_parametros "$archivo" "$filtro" "$buscar" $contar "$sumar"

# Procesar el archivo CSV
awk -f procesar_CSV.awk \
    -v filtro="$filtro" \
    -v buscar="$buscar" \
    -v operacion="$([ "$contar" = true ] && echo "contar" || echo "sumar")" \
    -v campo_suma="$sumar" \
    "$archivo"
