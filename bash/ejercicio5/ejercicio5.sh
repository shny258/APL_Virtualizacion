#!/bin/bash

# Inicialización de variables
IDS_ARRAY=()
NOMBRES_ARRAY=()
DEBE_BORRAR_CACHE=0
API_URL="https://rickandmortyapi.com/api/character" #siempre consultamos a character asi que dejo ese /character


# Función de ayuda (Help)
mostrar_ayuda() {
    echo "Uso: $0 [OPCIONES]"
    echo ""
    echo "Descripción:"
    echo "  Script para consultar la API de Rick & Morty"
    echo ""
    echo "Opciones:"
    echo "  -i, --id  ID          ID del personaje a consultar, puede indicar un unico ID o varios bajo el formato: [id1,id2,id3]"
    echo "  -n, --nombre NOMBRE   Nombre del personaje a consultar"
    echo "  -c, --clear  CLEAR    Borra la cache local"
    echo "  -h, --help            Muestra este mensaje de ayuda."
    echo ""
    echo "Ejemplos:"
    echo "  $0 -i 3"
    echo "  $0 -i 3,4 -n Rick"
    exit 0
}

# Función para validar IDs, ya que el usuario no es informatico y bueno, por ahi mete un XD y se muere el llamado a api por ids
validar_ids() {
    local -a entrada=("${IDS_ARRAY[@]}")
    ids_validados=() 

    for id in "${entrada[@]}"; do
        # Trimming: Quita espacios, tabs, etc.
        local id_limpio=$(echo "$id" | tr -d '[:space:]')

        # Regex para solo números
        if [[ -n "$id_limpio" && "$id_limpio" =~ ^[0-9]+$ ]]; then
            ids_validados+=("$id_limpio")
        else
            echo "Aviso: '$id' no es un ID numérico válido. Se omitirá." >&2
        fi
    done
}

OPTS=$(getopt -o i:n:ch --l id:,nombre:,clear,help -- "$@" 2> /dev/null)
if [ $? -ne 0 ]; then
    echo "ERROR: Parámetros inválidos."
    echo "Use -h o --help para ver las opciones disponibles."
    exit 1
fi

eval set -- "$OPTS"

while true; do
    case "$1" in
        -i|--id) 
            IFS=',' read -ra IDS_ARRAY <<< "$2"
            shift 2 ;;
        -n|--nombre) 
            IFS=',' read -ra NOMBRES_ARRAY <<< "$2"
            shift 2 ;;
        -c|--clear) 
            DEBE_BORRAR_CACHE=1; shift 1 ;;
        -h|--help) 
            mostrar_ayuda ;;
        --) shift; break ;;
        *) echo "Error interno"; exit 1 ;;
    esac
done

if [[ ${#IDS_ARRAY[@]} -gt 0 ]]; then
    validar_ids
    IDS_ARRAY=("${ids_validados[@]}")
fi

if [[ ${#IDS_ARRAY[@]} -eq 0 && ${#NOMBRES_ARRAY[@]} -eq 0 && $DEBE_BORRAR_CACHE -eq 0 ]]; then
    echo "Error: Debes proporcionar al menos un ID o un Nombre."
    echo "Usa -h para ayuda."
    exit 1
fi

# Proceso IDs y Nombres por separado... la API segun entiendo no soporta consultar por ambas cosas, tampoco tendria mucho sentido...
if [[ ${#IDS_ARRAY[@]} -gt 0 ]]; then
    echo "--- Procesando IDs ---"
    ids_concatenados=$(IFS=,; echo "${IDS_ARRAY[*]}")
    # TODO: implementar busqueda en cache, si esta devuelvo y no llamo a la API
    RESPUESTA=$(wget -qO- "${API_URL}/${ids_concatenados}")

    if [[ $? -ne 0 || -z "$RESPUESTA" ]]; then
        echo "Error: No se pudo conectar con la API o el ID no existe."
    else
        echo "$RESPUESTA" | jq -c '. | if type == "array" then .[] else . end' | while read -r p; do
        echo "-----------------------"
        echo "$p" | jq -r '
        "Character info:",
        "Id: \(.id)",
        "Name: \(.name)",
        "Status: \(.status)",
        "Species: \(.species)",
        "Gender: \(.gender)",
        "Origin: \(.origin.name)",
        "Location: \(.location.name)",
        "Episodes: \(.episode | length)"
        '
        # Guardo en cache... 1 archivo por id, para facilitar la posterior busqueda
        ID_ACTUAL=$(echo "$p" | jq -r '.id')
        mkdir -p cache
        echo "$p" > "cache/id_${ID_ACTUAL}.json"

        done
    fi
fi

if [[ ${#NOMBRES_ARRAY[@]} -gt 0 ]]; then
    echo "--- Procesando Nombres ---"
    for nombre in "${NOMBRES_ARRAY[@]}"; do
        echo "Buscando Nombre: $nombre"
    done
fi
