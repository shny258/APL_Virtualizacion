#!/bin/bash

# Integrantes del equipo: Tomas Ballesteros, Nicolas Catania, Rodrigo Ezequiel Aragón, Villan Matias Nicolas, Luciano Martins Louro

# Funciones Auxiliares

mostrar_ayuda() {
    echo "Uso: $0 -d <directorio> -p <palabras> -l <log> [--daemon] | --kill"
    echo ""
    echo "Parámetros:"
    echo "  -h, --help        Muestra este mensaje de ayuda y termina."
    echo "  -d, --directorio  (Obligatorio) Ruta del directorio a monitorear."
    echo "  -p, --palabras    Palabras a buscar separadas por comas (ej: error,falla,urgente)."
    echo "  -l, --log         Ruta del archivo de log donde se guardarán los registros."
    echo "  -k, --kill        Detiene el demonio que está monitoreando el directorio indicado."
    exit 0
}

manejar_error() {
    echo "Ocurrió un problema: $1"
    echo "Por favor, verifica los datos ingresados."
    exit 1
}

limpiar_temporales() {
    if [ "$DAEMON" -eq 1 ] && [ -n "$PID_FILE" ] && [ -f "$PID_FILE" ]; then
        rm -f "$PID_FILE"
    fi
}

log_event() {
    local arch=$1
    local op=$2
    local size
    size=$(stat -c%s "$arch" 2>/dev/null || echo "0")
    local datetime
    datetime=$(date +"%Y-%m-%d %H:%M:%S")
    
    echo "[$datetime] Operación: $op | Archivo: $arch | Tamaño: $size bytes" >> "$LOG" || \
    manejar_error "No se pudo escribir en el archivo de registro."
}

trap limpiar_temporales EXIT SIGINT SIGTERM


# Procesamiento de Parámetros

KILL=0
DAEMON=0

if [ $# -eq 0 ]; then
    mostrar_ayuda
fi

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help) mostrar_ayuda ;;
        -d|--directorio) DIR="$2"; shift 2 ;;
        -p|--palabras) PALABRAS="$2"; shift 2 ;;
        -l|--log) LOG="$2"; shift 2 ;;
        -k|--kill) KILL=1; shift ;;
        --daemon) DAEMON=1; shift ;;
        *) manejar_error "Se ingresó un parámetro desconocido ('$1'). Ejecute con -h para ver la ayuda." ;;
    esac
done


# Validaciones Generales

if [ -z "$DIR" ]; then
    manejar_error "El parámetro de directorio (-d o --directorio) es obligatorio."
fi

DIR=$(realpath "$DIR" 2>/dev/null) || manejar_error "No se pudo procesar la ruta del directorio."

if [ ! -d "$DIR" ]; then
    manejar_error "El directorio indicado ('$DIR') no existe o no se puede acceder a él."
fi

PID_FILE="/tmp/demonio_$(echo "$DIR" | md5sum | awk '{print $1}').pid"


# Lógica de Finalización (--kill)

if [ "$KILL" -eq 1 ]; then
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if kill -0 "$PID" 2>/dev/null; then
            pkill -P "$PID" 2>/dev/null
            kill "$PID" 2>/dev/null
            echo "Demonio detenido exitosamente. Ya no se está monitoreando el directorio."
        else
            echo "El proceso ya no estaba en ejecución. Limpiando registros..."
        fi
        rm -f "$PID_FILE"
        exit 0
    else
        manejar_error "No se encontró ningún monitor en ejecución para el directorio: $DIR"
    fi
fi


# Validaciones para Inicio

if [ -z "$PALABRAS" ] || [ -z "$LOG" ]; then
    manejar_error "Para iniciar el monitor, los parámetros -p/--palabras y -l/--log son obligatorios."
fi

LOG=$(realpath -m "$LOG") || manejar_error "No se pudo procesar la ruta del archivo de log."

LOG_DIR=$(dirname "$LOG")
if [ ! -d "$LOG_DIR" ]; then
    mkdir -p "$LOG_DIR" 2>/dev/null || manejar_error "No se pudo crear la carpeta para guardar el archivo de registro."
fi

if [ -f "$PID_FILE" ]; then
    if kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        manejar_error "Ya existe un monitor funcionando para este directorio. Deténgalo primero con --kill."
    else
        rm -f "$PID_FILE"
    fi
fi

if ! command -v inotifywait &> /dev/null; then
    manejar_error "El sistema necesita una herramienta adicional llamada 'inotify-tools' para funcionar."
fi

if [ "$DAEMON" -eq 0 ]; then
    nohup "$0" -d "$DIR" -p "$PALABRAS" -l "$LOG" --daemon >/dev/null 2>&1 &
    echo "¡Monitor iniciado correctamente en segundo plano!"
    echo "Vigilando el directorio: $DIR"
    exit 0
fi


# Lógica Principal del Demonio

echo $$ > "$PID_FILE"

REGEX=$(echo "$PALABRAS" | tr ',' '|')

for file in "$DIR"/*; do
    if [ -f "$file" ]; then
        if grep -iqE "$REGEX" "$file" 2>/dev/null; then
            log_event "$file" "EXISTENTE (Escaneo Inicial)"
        fi
    fi
done

inotifywait -m -e close_write,moved_to "$DIR" --format "%w%f|%e" 2>/dev/null | while IFS='|' read -r file action; do
    if [ -f "$file" ]; then
        if grep -iqE "$REGEX" "$file" 2>/dev/null; then
            log_event "$file" "NUEVO/MODIFICADO ($action)"
        fi
    fi
done