BEGIN {
    FS = "/"
}

{
    archivo = $NF
    directorio = ""
    size = $1

    for (i = 2; i < NF; i++) {
        if (i == 2) {
            directorio = $i
        } else {
            directorio = directorio "/" $i
        }
    }

    if (directorio == "") {
        directorio = "."
    }

    print directorio "|" archivo "|" size
}