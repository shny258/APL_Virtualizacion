#!/bin/bash


# Procesamiento de Parámetros

KILL=0
DAEMON=0

while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--directorio) DIR="$2"; shift 2 ;;
        -p|--palabras) PALABRAS="$2"; shift 2 ;;
        -l|--log) LOG="$2"; shift 2 ;;
        -k|--kill) KILL=1; shift ;;
        --daemon) DAEMON=1; shift ;;
        *) echo "Parámetro desconocido: $1"; exit 1 ;;
    esac
done

if [ -z "$DIR" ]; then
    echo "Error: El parámetro -d / --directorio es obligatorio."
    exit 1
fi

DIR=$(realpath "$DIR" 2>/dev/null)
if [ ! -d "$DIR" ]; then
    echo "Error: El directorio '$DIR' no existe o no es válido."
    exit 1
fi

PID_FILE="/tmp/demonio_$(echo "$DIR" | md5sum | awk '{print $1}').pid"


# Lógica de Finalización (--kill)

if [ "$KILL" -eq 1 ]; then
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if kill -0 "$PID" 2>/dev/null; then
            pkill -P "$PID" 2>/dev/null
            kill "$PID" 2>/dev/null
            
            echo "Demonio monitoreando '$DIR' detenido exitosamente (PID $PID)."
        else
            echo "El proceso ya no estaba en ejecución. Limpiando registro..."
        fi
        rm -f "$PID_FILE"
        exit 0
    else
        echo "No hay ningún demonio en ejecución para el directorio: $DIR"
        exit 1
    fi
fi


# Validaciones para Inicio

if [ -z "$PALABRAS" ] || [ -z "$LOG" ]; then
    echo "Error: Faltan parámetros (-p/--palabras y -l/--log son obligatorios para iniciar)."
    exit 1
fi

LOG=$(realpath -m "$LOG")

if [ -f "$PID_FILE" ]; then
    if kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo "Error: Ya existe un demonio en ejecución para el directorio '$DIR'."
        exit 1
    else
        rm -f "$PID_FILE"
    fi
fi

if ! command -v inotifywait &> /dev/null; then
    echo "Error: inotify-tools no está instalado. Ejecute: sudo apt install inotify-tools"
    exit 1
fi

if [ "$DAEMON" -eq 0 ]; then
    nohup "$0" -d "$DIR" -p "$PALABRAS" -l "$LOG" --daemon >/dev/null 2>&1 &
    echo "Demonio iniciado en segundo plano. Monitoreando: $DIR"
    exit 0
fi


# Ejecución del Demonio 

echo $$ > "$PID_FILE"

REGEX=$(echo "$PALABRAS" | tr ',' '|')

log_event() {
    local arch=$1
    local op=$2
    local size
    size=$(stat -c%s "$arch" 2>/dev/null || echo "0")
    local datetime
    datetime=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$datetime] Operación: $op | Archivo: $arch | Tamaño: $size bytes" >> "$LOG"
}

# 1. Procesamiento inicial (archivos ya existentes)
for file in "$DIR"/*; do
    if [ -f "$file" ]; then
        if grep -iqE "$REGEX" "$file" 2>/dev/null; then
            log_event "$file" "EXISTENTE (Escaneo Inicial)"
        fi
    fi
done

# 2. Monitoreo en tiempo real
inotifywait -m -e close_write,moved_to "$DIR" --format "%w%f|%e" 2>/dev/null | while IFS='|' read -r file action; do
    if [ -f "$file" ]; then
        if grep -iqE "$REGEX" "$file" 2>/dev/null; then
            log_event "$file" "NUEVO/MODIFICADO ($action)"
        fi
    fi
done