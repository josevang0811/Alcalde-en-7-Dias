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
        tint(255, 130 + 125 * parpadeo);   // parpadea con tint (el texto se guarda una sola vez) sin dejar de leerse
        textoPixel("CLIC O ESC PARA VOLVER A LA OFICINA", width / 2, pcY(97), celdaInterfaz(), 1,
            color(255, 247, 230), #1a1010, 0, 0, false, CENTER, CENTER);
        noTint();
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
