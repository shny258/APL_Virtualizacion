#!/bin/bash

archivoEntrada=""
archivoSalida=""

uso() {
    echo "Uso: $0 -a <archivo_entrada> [-s <archivo_salida>]"
    echo "  -a, --archivo   Archivo de texto a procesar (obligatorio)"
    echo "  -s, --salida    Archivo donde guardar el resultado (opcional)"
    exit 1
}

#Procesar los parametros
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -a|--archivo)
            # Validar que $2 no esté vacío y no sea otra bandera (que no empiece con -)
            if [[ -z "$2" || "$2" == -* ]]; then
                echo "Error: El parámetro $1 requiere un nombre de archivo."
                uso
            fi
            archivoEntrada="$2"
            shift 2 
            ;;
        -s|--salida)
            if [[ -z "$2" || "$2" == -* ]]; then
                echo "Error: El parámetro $1 requiere un nombre de archivo de salida."
                uso
            fi
            archivoSalida="$2"
            shift 2
            ;;
        -h|--help)
            uso
            ;;
        *)
        echo "Error: Parametro desconocido '$1'."
        uso
        ;;
    esac
done

# 2. Validaciones de seguridad
if [[ -z "$archivoEntrada" ]]; then
    echo "Error: Debes indicar un archivo de entrada usando -a o --archivo."
    exit 1
fi

if [[ ! -f "$archivoEntrada" ]]; then
    echo "Error: El archivo de entrada '$archivoEntrada' no existe."
    exit 1
fi

# 3. Preparar el archivo de salida (si el usuario lo solicitó)
# Si se indicó un archivo de salida, lo vaciamos/sobrescribimos aquí
if [[ -n "$archivo_salida" ]]; then
    > "$archivo_salida" 
fi

#3.5 Procesar linea a linea

procesar_texto() {
    local l="$1"

# --- A. Espaciado y Formato ---
    l=$(echo "$l" | sed -E 's/[[:space:]]+/ /g') # Colapsar espacios
    l=$(echo "$l" | sed -E 's/^[[:space:]]*//; s/[[:space:]]*$//') # Trim

    # Si queda vacía, salir
    [[ -z "$l" ]] && return

    # --- B. Signos de Apertura (¿ y ¡) ---
    # Busca bloques que terminan en ? o ! y les pone el signo al inicio si no lo tienen
    l=$(echo "$l" | sed -E 's/(^|[.!?] )([^¿¡[:space:]][^.!?]*)\?/\1¿\2?/g')
    l=$(echo "$l" | sed -E 's/(^|[.!?] )([^¿¡[:space:]][^.!?]*)\!/\1¡\2!/g')

    # --- C. Mayúsculas (Corregido para manejar ¿ y ¡) ---
    l=$(echo "$l" | sed -E 's/^([a-z])/\U\1/')                 # Inicio: letra
    l=$(echo "$l" | sed -E 's/^(¿|¡)([a-z])/\1\U\2/')        # Inicio: signo + letra
    l=$(echo "$l" | sed -E 's/([.!?] )([a-z])/\1\U\2/g')      # Tras punto: letra
    l=$(echo "$l" | sed -E 's/([.!?] )(¿|¡)([a-z])/\1\2\U\3/g') # Tras punto: signo + letra

    # --- D. Puntuación y el truco de los puntos suspensivos ---
    l=$(echo "$l" | sed -E "s/'/\"/g")                        # Unificar comillas
    l=$(echo "$l" | sed -E 's/\.{4,}/.../g')                  # Normalizar puntos

    # 1. Eliminar CUALQUIER coma que esté al final de la línea o antes de un punto
    l=$(echo "$l" | sed -E 's/,[[:space:]]*$//')              # Coma al final -> fuera
    l=$(echo "$l" | sed -E 's/,[[:space:]]*([.!?])/\1/g')     # Coma antes de punto/signo -> fuera
    
    # 2. Protegemos los puntos suspensivos para que sed no los rompa
    l=$(echo "$l" | sed 's/\.\.\./@DOTS@/g')
    
    # 3. Espaciado estándar: No antes, uno después
    l=$(echo "$l" | sed -E 's/ +([.,;:?!])/\1/g')
    l=$(echo "$l" | sed -E 's/([.,;:?!])([^ ])/\1 \2/g')
    
    # 4. Restauramos puntos suspensivos
    l=$(echo "$l" | sed 's/@DOTS@/.../g')

    # --- E. Asegurar cierre de párrafo (. ! ?) ---
    # Si después de todo no termina en punto, exclamación o interrogación, ponemos punto.
    [[ ! "$l" =~ [.\?\!]$ ]] && l="$l."

    echo "$l"
}

# 4. Procesar el archivo línea por línea
while IFS= read -r linea || [[ -n "$linea" ]]; do

    # Solo imprimir si la línea procesada no quedó vacía
    if [[ -n "$linea" ]]; then
        linea_final=$(procesar_texto "$linea")
        
        if [[ -n "$linea_final" ]]; then
            if [[ -n "$archivoSalida" ]]; then
                # Guardar en archivo (append)
                echo "$linea_final" >> "$archivoSalida"
            else
                # Mostrar en consola
                echo "$linea_final"
            fi
        fi
    fi
done < "$archivoEntrada"

# Mensaje final de éxito
if [[ -n "$archivoSalida" ]]; then
    echo "¡Listo! El procesamiento finalizó y se guardó en '$archivoSalida'."
fi