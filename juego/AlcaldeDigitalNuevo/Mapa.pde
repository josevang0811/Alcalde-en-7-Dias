// Mapa — el televisor en grande: el grafo de Ciudad Nova.
//
// Se abre haciendo clic en el televisor de la oficina. Muestra los vertices
// (las 8 zonas, con su nombre) y las aristas (las 12 calles, con sus
// minutos de camino, que son el peso guardado en la matriz de adyacencia).
// Los barrios del candidato van en rojo (la sede con un circulo blanco). Al
// pasar el mouse por una zona se resaltan sus calles y sus vecinas: es la
// fila de esa zona en la matriz.
//
// Por ahora hay un solo candidato. Todo se calcula de nuevo en cada cuadro
// (son muy pocas figuras), asi que un barrio conquistado se ve enseguida.

// Donde se dibuja el grafo en la pantalla (se calcula en pantallaMapa()).
float mapaX, mapaY, mapaAncho, mapaAlto;

// Con el rediseno, el televisor ya no muestra el grafo: al hacer clic la
// camara se acerca hasta que el noticiero llena la pantalla, con los
// titulares corriendo abajo (Diseno.pde). El grafo, con sus calles y
// minutos, se ve en el mapa de papel del celular. Un clic o Esc alejan la
// camara y se vuelve a la oficina.
void pantallaMapa() {
    dibujarZoomTV(zoomTV);
    if (zoomTVHasta == 0 && zoomTV <= 0.001) {
        irA(MENU);
        return;
    }
    if (zoomTV > 0.98 && zoomTVHasta == 1 && !videollamadaActiva) {
        pedirCursorMano();
        float parpadeo = 0.6 + 0.4 * sin(millis() * 0.005);
        textoPixel("CLIC O ESC PARA VOLVER A LA OFICINA", width / 2, pcY(97), max(2, round(camAncho / 640)), 1,
            color(255, 247, 230, 255 * parpadeo), #1a1010, 0, 0, false, CENTER, CENTER);
    }
}

// En el mapa de papel del celular (el Mapa.html del equipo de diseño), cada
// barrio es una de las ubicaciones del dibujo. Su centro, en fracción del
// mapa, en el orden de los barrios de GrafoCiudad (Centro, La Universidad,
// La Colina, El Puerto, El Mercado, Barrio Sur, Parque Industrial, Barrio
// Norte). El mapa del equipo traía 12 lugares: se dejaron estos 8.
float[] POSTIT_X = {0.508, 0.355, 0.162, 0.215, 0.520, 0.775, 0.818, 0.640};
float[] POSTIT_Y = {0.560, 0.343, 0.396, 0.735, 0.800, 0.670, 0.371, 0.170};
boolean mapaEnPapel = false;

float radioZonaMapa() {
    if (mapaEnPapel) {
        return mapaAncho * 0.045;
    }
    return tx(30, 20);
}

float xZona(int z) {
    if (mapaEnPapel) {
        return mapaX + POSTIT_X[z] * mapaAncho;
    }
    return mapaX + partida.getCiudad().getX(z) * mapaAncho;
}

float yZona(int z) {
    if (mapaEnPapel) {
        return mapaY + POSTIT_Y[z] * mapaAlto;
    }
    return mapaY + partida.getCiudad().getY(z) * mapaAlto;
}

// La zona que esta bajo el mouse, o -1 si no hay ninguna.
int zonaEnMapa(float mx, float my) {
    for (int z = 0; z < partida.getCiudad().cantidad(); z++) {
        if (dist(mx, my, xZona(z), yZona(z)) <= radioZonaMapa()) {
            return z;
        }
    }
    return -1;
}

void dibujarCabeceraMapa(float x, float y) {
    noStroke();
    fill(COLOR_BLANCO);
    usarLetra(LETRA_NEGRITA, tx(16, 12));
    textAlign(LEFT, CENTER);
    text("CIUDAD NOVA · TURNO " + turnoVisible(), x, y);
    usarLetra(LETRA_NEGRITA, tx(14, 11));
    String vivo = "EN VIVO";
    float anchoInsignia = textWidth(vivo) + tx(30, 22);
    float xInsignia = width - x - anchoInsignia;
    float altoInsignia = tx(24, 18);
    fill(COLOR_ROJO);
    rect(xInsignia, y - altoInsignia / 2, anchoInsignia, altoInsignia, 4);
    fill(COLOR_BLANCO);
    if ((millis() / 600) % 2 == 0) {
        ellipse(xInsignia + tx(11, 8), y, tx(8, 6), tx(8, 6));
    }
    text(vivo, xInsignia + tx(20, 15), y - 1);
}

// Las aristas: una linea por cada calle (mitad de arriba de la matriz, para
// no repetir) con su peso en minutos en el medio. Si hay una zona bajo el
// mouse, sus calles se pintan amarillas y las demas se apagan.
void dibujarCallesMapa(int resaltada) {
    GrafoCiudad ciudad = partida.getCiudad();
    for (int a = 0; a < ciudad.cantidad(); a++) {
        for (int b = a + 1; b < ciudad.cantidad(); b++) {
            if (!ciudad.hayCalle(a, b)) {
                continue;
            }
            boolean suya = resaltada == a || resaltada == b;
            stroke(suya ? COLOR_AMARILLO : COLOR_CALLE_TV, resaltada >= 0 && !suya ? 110 : 255);
            strokeWeight(tx(suya ? 10 : 8, 5));
            line(xZona(a), yZona(a), xZona(b), yZona(b));
        }
    }
    for (int a = 0; a < ciudad.cantidad(); a++) {
        for (int b = a + 1; b < ciudad.cantidad(); b++) {
            if (ciudad.hayCalle(a, b)) {
                dibujarMinutos(ciudad.getMinutos(a, b) + " min", (xZona(a) + xZona(b)) / 2, (yZona(a) + yZona(b)) / 2);
            }
        }
    }
}

// Etiqueta de papel con los minutos, en letra pixel.
void dibujarMinutos(String texto, float cx, float cy) {
    float celda = max(1.5, celdaInterfaz() * 0.75);
    texto = texto.toUpperCase();
    float ancho = (medirPixel(texto) + 6) * celda;
    float alto = 11 * celda;
    noStroke();
    fill(#2b1a2a);
    rect(cx - ancho / 2 - celda, cy - alto / 2 - celda, ancho + 2 * celda, alto + 2 * celda);
    fill(#ecd2a4);
    rect(cx - ancho / 2, cy - alto / 2, ancho, alto);
    textoPixel(texto, cx, cy, celda, #2b1a2a, CENTER, CENTER);
}

// Los vertices: un circulo por zona con su nombre debajo. Los barrios del
// candidato van rojos (la sede con un circulo blanco); las vecinas de la
// zona bajo el mouse se ven un poco mas grandes.
void dibujarZonasMapa(int resaltada) {
    GrafoCiudad ciudad = partida.getCiudad();
    float r = radioZonaMapa();
    for (int z = 0; z < ciudad.cantidad(); z++) {
        boolean vecina = resaltada >= 0 && ciudad.hayCalle(resaltada, z);
        float tamano = (z == resaltada) ? 1.15 : (vecina ? 1.07 : 1);
        if (z == resaltada) {
            pedirCursorMano();
            noStroke();
            fill(COLOR_AMARILLO, 70);
            ellipse(xZona(z), yZona(z), r * 3, r * 3);
        }
        stroke(COLOR_CONTORNO);
        strokeWeight(grosorContorno * 1.2);
        fill(partida.esPropio(z) ? COLOR_ROJO : COLOR_GRIS_CLARO);
        ellipse(xZona(z), yZona(z), r * 2 * tamano, r * 2 * tamano);
        if (z == Partida.ZONA_SEDE) {
            noStroke();
            fill(COLOR_BLANCO);
            ellipse(xZona(z), yZona(z), r * 0.8, r * 0.8);
        }
        fill(COLOR_BLANCO);
        usarLetra(LETRA_NEGRITA, tx(15, 11));
        textAlign(CENTER, TOP);
        text(ciudad.getNombre(z), xZona(z), yZona(z) + r * 1.2);
    }
}

// Abajo: que es cada cosa, o las vecinas de la zona bajo el mouse.
void dibujarLeyendaMapa(float x, float y, int resaltada) {
    GrafoCiudad ciudad = partida.getCiudad();
    float r = tx(9, 7);
    textAlign(LEFT, CENTER);
    usarLetra(LETRA_TEXTO, tx(15, 11));
    if (resaltada >= 0) {
        String vecinas = "";
        for (int z = 0; z < ciudad.cantidad(); z++) {
            if (ciudad.hayCalle(resaltada, z)) {
                vecinas += (vecinas.isEmpty() ? "" : ", ") + ciudad.getNombre(z) + " (" + ciudad.getMinutos(resaltada, z) + " min)";
            }
        }
        fill(COLOR_AMARILLO);
        text(ciudad.getNombre(resaltada) + " tiene calle con: " + vecinas, x, y);
        return;
    }
    stroke(COLOR_CONTORNO);
    strokeWeight(1.5);
    fill(COLOR_ROJO);
    ellipse(x + r, y, r * 2, r * 2);
    fill(COLOR_BLANCO);
    String propios = "Tus barrios (sede: " + ciudad.getNombre(Partida.ZONA_SEDE) + ")";
    text(propios, x + r * 3, y);
    float x2 = x + r * 3 + textWidth(propios) + tx(30, 20);
    stroke(COLOR_CONTORNO);
    fill(COLOR_GRIS_CLARO);
    ellipse(x2 + r, y, r * 2, r * 2);
    fill(COLOR_BLANCO);
    text("Zona   ·   Las líneas son calles, con los minutos de camino   ·   Pasa el mouse por una zona para ver sus vecinas", x2 + r * 3, y);
}

void clicEnMapa() {
    if (videollamadaActiva) {
        if (mouseEnSaltar()) {
            terminarBienvenida();
        }
        return;
    }
    if (zoomTVHasta == 1) {
        alejarTV();
    }
}
