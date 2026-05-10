#!/bin/bash

directorio="$1"
directorio_ingresado="$1"
script_dir="$(cd "$(dirname "$0")" && pwd)"

mostrar_ayuda() {
    cat <<EOF
Uso: $0 <directorio>

Busca archivos duplicados dentro del directorio indicado.
Dos archivos se consideran duplicados si tienen el mismo nombre y el mismo tamaño.

Opciones:
  -h, --help, help    Muestra esta ayuda
EOF
}

normalizar_directorio() {
    local ruta="$1"

    if [[ "$ruta" =~ ^([A-Za-z]):[\\/](.*)$ ]]; then
        local unidad="${BASH_REMATCH[1],,}"
        local resto="${BASH_REMATCH[2]//\\//}"
        printf '/mnt/%s/%s\n' "$unidad" "$resto"
        return
    fi

    printf '%s\n' "$ruta"
}

if [[ "$directorio" == "-h" || "$directorio" == "--help" || "$directorio" == "help" ]]; then
    mostrar_ayuda
    exit 0
fi

if [[ -z "$directorio" ]]; then
    mostrar_ayuda
    exit 1
fi

directorio="$(normalizar_directorio "$directorio")"

if [[ -f "$directorio" ]]; then
    echo "Error: '$directorio_ingresado' es un archivo. Debe indicar un directorio valido."
    exit 1
fi

if [[ ! -d "$directorio" ]]; then
    echo "Error: '$directorio_ingresado' no es un directorio valido"
    exit 1
fi

mapfile -t listado < <(find "$directorio" -type f -printf '%s/%p\n' | awk -f "$script_dir/ejercicio3.awk")

declare -A rutas_duplicadas
declare -A archivos_vistos

for linea in "${listado[@]}"; do
    IFS='|' read -r dir_archivo archivo size <<< "$linea"

    clave="$archivo|$size"
    ruta="$dir_archivo/$archivo"

    if [[ -n "${archivos_vistos[$clave]}" ]]; then
        if [[ -z "${rutas_duplicadas[$clave]}" ]]; then
            rutas_duplicadas["$clave"]="${archivos_vistos[$clave]}"
        fi
        rutas_duplicadas["$clave"]+=$'\n'"$ruta"
    else
        archivos_vistos["$clave"]="$ruta"
    fi
done

for clave in "${!rutas_duplicadas[@]}"; do
    printf '%s:\n%s\n\n' "$clave" "${rutas_duplicadas[$clave]}"
done
