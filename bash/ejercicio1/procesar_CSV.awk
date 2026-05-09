function normalizar(c) {
    # Saca todos los caracteres molestos y espacios
    gsub(/[\r\n\t]+/, "", c)           # elimina \r \n \t
    gsub(/^[ \t]+|[ \t]+$/, "", c)     # trim
    gsub(/[ \t]+/, "", c)              # elimina espacios internos
    return tolower(c)
}

function normalizar_display(c) {
    gsub(/[\r\n\t]+/, "", c)           # elimina \r \n \t
    gsub(/^[ \t]+|[ \t]+$/, "", c)
    gsub(/[ \t]+/, " ", c)
    return c
}

BEGIN {
    suma = 0
    conteo = 0
    FPAT = "([^,]*|\"([^\"]|\"\")*\")" # parsear los campos que tienen coma entre comillas
    debug = 0  # modo debug para comprobar que se estan parseando bien los campos
}

NR == 1 {
    print "=== PROCESANDO CSV ==="
    print "Archivo: " FILENAME

    print "\nColumnas detectadas (normalizadas):"
    for (i=1; i<=NF; i++) {
        key = normalizar($i)
        col[key] = i         # clave normalizada (sin espacios)
        cleaned = normalizar_display($i)
        display[key] = cleaned  # clave normalizada pero con espacios para mostrar al usuario
        original = $i

        print "   • [" cleaned "]  (key: " key ")"
    }
    print "----------------------------------------"

    if (filtro != "") {
        fkey = normalizar(filtro)
        if (!(fkey in col)) {
            print "Error: Campo de filtro no encontrado." > "/dev/stderr"
            exit 1
        }
        print "Filtro: " filtro " contiene \"" buscar "\""
    }

    if (operacion == "sumar") {
        skey = normalizar(campo_suma)
        if (!(skey in col)) {
            print "Error: El campo a sumar " skey " no existe." > "/dev/stderr"
            exit 1
        }
        print "Sumando campo: " display[skey]
    } else {
        print "Operación: Contar registros"
    }
    print "----------------------------------------"
    next
}

# === DEBUG: Mostrar cómo se parsean los campos de las primeras filas ===
NR <= 5 && debug == 1 {
    print "\n=== FILA " NR " ==="
    print "Línea original:", $0
    print "Cantidad de campos detectados:", NF
    
    for (i=1; i<=NF; i++) {
        printf "Campo %2d: [%s]\n", i, $i
    }
    print "----------------------------------------"
}

{
    # Filtro
    if (filtro == "" || tolower($col[fkey]) ~ tolower(buscar)) {
        conteo++
        
        if (operacion == "sumar") {
            valor = $col[skey]
            norm_valor = normalizar(valor)
            if (norm_valor ~ /^[0-9.]+$/) {
                suma += norm_valor + 0
            } else if (norm_valor != "") {
                print "Warning: Valor no numérico ignorado: " norm_valor > "/dev/stderr"
            }
        }
        
        print $0   # mostramos el registro
    }
}

END {
    print "----------------------------------------"
    if (operacion == "contar") {
        print "Registros encontrados: " conteo
    } else {
        print "Suma de " display[skey] ": " suma
    }
}