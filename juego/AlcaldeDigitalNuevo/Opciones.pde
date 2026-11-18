// Opciones — el volumen de la música, desde OPCIONES del menú principal.
//
// La música del juego es la de la misión Infiltrado (su canción de calma
// suena en la oficina y en el mundo abierto; en la misión cambia según lo
// que pase). Aquí se sube o se baja con una barra (clic en la barra, en
// - y +, o con las flechas). El valor se guarda en data/ajustes.txt.
// Mientras alguien habla (las llamadas, la videollamada de Valeria) la
// música baja sola para que se entienda.

boolean opcionesAbiertas = false;
float volumenMusica = 0.7;
boolean ajustesLeidos = false;

void leerAjustes() {
    ajustesLeidos = true;
    java.io.File f = new java.io.File(dataPath("ajustes.txt"));
    if (!f.exists()) {
        return;
    }
    for (String linea : loadStrings(f.getAbsolutePath())) {
        String[] p = split(trim(linea), '=');
        if (p.length == 2 && p[0].equals("volumen_musica")) {
            volumenMusica = constrain(float(p[1]), 0, 1);
        }
        if (p.length == 2 && p[0].equals("ambiente")) {
            ambienteMundo = p[1];   // Ambiente.pde
        }
    }
}

void guardarAjustes() {
    saveStrings(dataPath("ajustes.txt"), new String[] {
        "volumen_musica=" + nf(volumenMusica, 1, 2).replace(',', '.'),
        "ambiente=" + ambienteMundo
    });
}

// Cada cuadro (desde actualizarLlamada): fuera de la misión suena la calma,
// con el volumen elegido, y baja mientras alguien habla.
void actualizarMusicaJuego() {
    if (!ajustesLeidos) {
        leerAjustes();
    }
    if (mision == null || mision.musica == null) {
        return;
    }
    mision.musica.volumenUsuario = volumenMusica;
    if (estado == MISION) {
        return;   // en la misión la maneja ella
    }
    mision.musica.momento = mision.M_CALMA;
    boolean hablan = videollamadaActiva || faseLlamada == LLAMADA_HABLANDO;
    mision.musica.atenuar = cinematicaActiva() ? 0 : (hablan ? 0.3 : 1);   // en las cinemáticas, sin música
}

void cambiarVolumen(float v) {
    volumenMusica = constrain(round(v * 20) / 20.0, 0, 1);
    guardarAjustes();
}

// --- El panel (un papel encima del menú) ---

float[] cajaOpciones() {
    float w = pcAncho(40), h = pcAlto(52);
    return new float[] {pcX(50) - w / 2, pcY(50) - h / 2, w, h};
}

float celdaOpciones() {
    return max(1, round(cajaOpciones()[3] / 140));
}

// Barra de volumen: x, y, ancho, alto
float[] barraVolumen() {
    float[] c = cajaOpciones();
    float k = celdaOpciones();
    return new float[] {c[0] + c[2] * 0.2, c[1] + c[3] * 0.42, c[2] * 0.6, 9 * k};
}

float[] botonMenos() {
    float[] b = barraVolumen();
    float k = celdaOpciones();
    return new float[] {b[0] - 16 * k, b[1] - 2 * k, 12 * k, 13 * k};
}

float[] botonMas() {
    float[] b = barraVolumen();
    float k = celdaOpciones();
    return new float[] {b[0] + b[2] + 4 * k, b[1] - 2 * k, 12 * k, 13 * k};
}

float[] botonVolverOpciones() {
    float[] c = cajaOpciones();
    float k = celdaOpciones();
    float w = (medirPixel("VOLVER") + 14) * k, h = 15 * k;
    return new float[] {c[0] + c[2] / 2 - w / 2, c[1] + c[3] - h - 10 * k, w, h};
}

boolean dentro(float[] r) {
    return mouseX >= r[0] && mouseX <= r[0] + r[2] && mouseY >= r[1] && mouseY <= r[1] + r[3];
}

void dibujarOpciones() {
    noStroke();
    fill(0, 150);
    rect(camX, camY, camAncho, camAlto);
    float[] c = cajaOpciones();
    float k = celdaOpciones();
    // el papel, como las etiquetas del mapa
    fill(#2b1a2a);
    rect(c[0] - 2 * k, c[1] - 2 * k, c[2] + 4 * k, c[3] + 4 * k);
    fill(#ecd2a4);
    rect(c[0], c[1], c[2], c[3]);
    fill(#c9a06b);
    rect(c[0], c[1] + c[3] - 3 * k, c[2], 3 * k);
    textoPixel("OPCIONES", c[0] + c[2] / 2, c[1] + 16 * k, k, 2, #2b1a2a, 0, 0, 0, false, CENTER, CENTER);
    textoPixel("MÚSICA", c[0] + c[2] / 2, c[1] + c[3] * 0.32, k, #2b1a2a, CENTER, CENTER);
    // la barra
    float[] b = barraVolumen();
    fill(#2b1a2a);
    rect(b[0] - k, b[1] - k, b[2] + 2 * k, b[3] + 2 * k);
    fill(#c9b38f);
    rect(b[0], b[1], b[2], b[3]);
    fill(#3b7fd0);
    rect(b[0], b[1], b[2] * volumenMusica, b[3]);
    // rayitas cada 10 %
    fill(#2b1a2a, 90);
    for (int i = 1; i < 10; i++) {
        rect(b[0] + b[2] * i / 10.0, b[1], max(1, k * 0.5), b[3]);
    }
    textoPixel(round(volumenMusica * 100) + "%", c[0] + c[2] / 2, b[1] + b[3] + 10 * k, k, #2b1a2a, CENTER, CENTER);
    dibujarBotonOpcion(botonMenos(), "-");
    dibujarBotonOpcion(botonMas(), "+");
    dibujarBotonOpcion(botonVolverOpciones(), "VOLVER");
    textoPixel("FLECHAS: SUBIR Y BAJAR · ESC: VOLVER", c[0] + c[2] / 2, c[1] + c[3] * 0.66, max(1, k * 0.75), #5f4a3a, CENTER, CENTER);
    if (dentro(barraVolumen()) || dentro(botonMenos()) || dentro(botonMas()) || dentro(botonVolverOpciones())) {
        pedirCursorMano();
    }
    // arrastrando sobre la barra también se mueve
    if (mousePressed && dentro(new float[] {b[0], b[1] - 4 * k, b[2], b[3] + 8 * k})) {
        volumenMusica = constrain((mouseX - b[0]) / b[2], 0, 1);
    }
}

void dibujarBotonOpcion(float[] r, String texto) {
    float k = celdaOpciones();
    boolean encima = dentro(r);
    noStroke();
    fill(#2b1a2a);
    rect(r[0], r[1], r[2], r[3]);
    fill(encima ? #e8584d : #4a3040);
    rect(r[0] + k, r[1] + k, r[2] - 2 * k, r[3] - 2 * k);
    textoPixel(texto, r[0] + r[2] / 2, r[1] + r[3] / 2, k, #fff3d6, CENTER, CENTER);
}

void clicEnOpciones() {
    float[] b = barraVolumen();
    float k = celdaOpciones();
    if (dentro(botonVolverOpciones())) {
        opcionesAbiertas = false;
        guardarAjustes();
    } else if (dentro(botonMenos())) {
        cambiarVolumen(volumenMusica - 0.1);
    } else if (dentro(botonMas())) {
        cambiarVolumen(volumenMusica + 0.1);
    } else if (dentro(new float[] {b[0], b[1] - 4 * k, b[2], b[3] + 8 * k})) {
        cambiarVolumen((mouseX - b[0]) / b[2]);
    } else if (!dentro(cajaOpciones())) {
        opcionesAbiertas = false;   // clic afuera: se cierra
        guardarAjustes();
    }
}

void teclaOpciones() {
    if (key == CODED && (keyCode == LEFT || keyCode == DOWN)) {
        cambiarVolumen(volumenMusica - 0.05);
    } else if (key == CODED && (keyCode == RIGHT || keyCode == UP)) {
        cambiarVolumen(volumenMusica + 0.05);
    } else if (key == 0 || key == ENTER || key == RETURN) {
        opcionesAbiertas = false;   // Esc (ya convertido en 0) o Enter
        guardarAjustes();
    }
}
