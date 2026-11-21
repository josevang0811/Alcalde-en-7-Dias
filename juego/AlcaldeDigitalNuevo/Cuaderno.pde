// Cuaderno — el libro de habilidades (el Libro_de_habilidades.html del
// equipo de diseño). Al abrirlo, la oficina se oscurece y el libro sube
// desde abajo; después se queda balanceándose un poquito.
//
// Hoja izquierda: el árbol dibujado, con las 13 habilidades del juego como
// medallas (doradas con el candado abierto si ya están compradas, grises
// con candado si no) unidas por ramas de madera. Hoja derecha: los puntos,
// la medalla y el nombre de la habilidad elegida (del color de lo cara que
// es), lo que hace escrito en los renglones y, en el recuadro de abajo, el
// costo: un clic ahí la compra. En el post-it, la foto del candidato con la
// corbata de su color. Todo el texto va en la letra pixel (Diseno.pde).
//
// Las posiciones salen del HTML, en pixeles de un libro de 1043 x 732, y se
// pasan a la pantalla con bx / by. Lo que se ve y donde se hace clic salen de
// la misma tabla, así siempre coinciden.

final float LIBRO_W = 1043, LIBRO_H = 732;
PImage imgLibroHabilidades, imgNodoAbierto, imgNodoCerrado, imgAristaLibro;

void cargarLibroHabilidades() {
    imgLibroHabilidades = loadImage("libro_habilidades.png");
    imgNodoAbierto = loadImage("nodo_abierto.png");
    imgNodoCerrado = loadImage("nodo_cerrado.png");
    imgAristaLibro = loadImage("arista_libro.png");
}

// ===========================================================================
// LAYOUT
// ===========================================================================

// El libro en la pantalla (se recalcula en cada cuadro porque sube y se
// balancea al abrirlo).
float libroX, libroY, libroAncho, libroAlto, libroGiro;

// Donde va el libro, en porcentaje de la cámara (con la proporción del dibujo)
final float LIBRO_IZQ = 18.9, LIBRO_ARRIBA = 8.5, LIBRO_ANCHO = 62.2, LIBRO_ALTO = 78.0;

// Cada habilidad en el árbol (centro de su medalla, en pixeles del libro de
// 1043 x 732): la raíz abajo en el tronco y las tres ramas hacia la copa.
String[] NOMBRES_LUGAR = {
    "Campaña",
    ArbolHabilidades.VOLANTES, ArbolHabilidades.MEGAFONO, ArbolHabilidades.PERFIL_VERIFICADO, ArbolHabilidades.TRANSMISION,
    ArbolHabilidades.LIBRETA, ArbolHabilidades.FUENTE_CONFIABLE, ArbolHabilidades.GOLPE_DE_SUERTE, ArbolHabilidades.RUEDA_DE_PRENSA,
    ArbolHabilidades.ASISTENTE_IA, ArbolHabilidades.MODELO_MEJORADO, ArbolHabilidades.BOTS, ArbolHabilidades.IA_PERFECTA
};
float[][] LUGARES_ARBOL = {
    {283, 507},
    {180, 392}, {112, 298}, {182, 288}, {172, 180},
    {283, 410}, {250, 300}, {255, 190}, {330, 300},
    {388, 392}, {420, 302}, {448, 212}, {366, 198}
};
final float DIAMETRO_NODO = 50;   // en pixeles del libro

void calcularLayoutLibro() {
    float[] caja = cajaObjeto(LIBRO_IZQ, LIBRO_ARRIBA, LIBRO_ANCHO, LIBRO_ALTO, 108.9, aparicion(40), 1.8, -1.1);
    // el balanceo del HTML: un corrimiento y un giro lentos (7 s)
    float f = sin(millis() / 7000.0 * TWO_PI);
    libroX = caja[0] + caja[2] * 0.005 * f;
    libroY = caja[1];
    libroAncho = caja[2];
    libroAlto = caja[3];
    libroGiro = radians(0.7 * f);
}

// Del libro (1043 x 732) a la pantalla, sin el giro (el giro se aplica al
// dibujar, con pushMatrix, y al revisar el mouse se deshace).
float bx(float x) {
    return libroX + x / LIBRO_W * libroAncho;
}

float by(float y) {
    return libroY + y / LIBRO_H * libroAlto;
}

float bl(float largo) {
    return largo / LIBRO_W * libroAncho;
}

// El mouse en coordenadas del libro sin girar
float[] mouseEnLibro() {
    float cx = libroX + libroAncho / 2, cy = libroY + libroAlto / 2;
    float dx = mouseX - cx, dy = mouseY - cy;
    float c = cos(-libroGiro), s = sin(-libroGiro);
    return new float[] {cx + dx * c - dy * s, cy + dx * s + dy * c};
}

void girarLibro() {
    float cx = libroX + libroAncho / 2, cy = libroY + libroAlto / 2;
    translate(cx, cy);
    rotate(libroGiro);
    translate(-cx, -cy);
}

int lugarDe(Nodo n) {
    for (int i = 0; i < NOMBRES_LUGAR.length; i++) {
        if (NOMBRES_LUGAR[i].equals(n.getNombre())) {
            return i;
        }
    }
    return -1;
}

// El vaivén propio de las medallas (más corto, 5 s, como #layer del HTML)
float vaivenNodos() {
    return bl(2) * sin(millis() / 5000.0 * TWO_PI);
}

float centroNodoX(Nodo n) {
    return bx(LUGARES_ARBOL[lugarDe(n)][0]) + vaivenNodos();
}

float centroNodoY(Nodo n) {
    return by(LUGARES_ARBOL[lugarDe(n)][1]);
}

float radioNodoLibro() {
    return bl(DIAMETRO_NODO) / 2;
}

// ===========================================================================
// PANTALLA
// ===========================================================================

void pantallaArbol() {
    calcularLayoutLibro();
    dibujarPlaca(imgSinLibro);

    nodoBajoMouse = null;
    if (!partidaTerminada()) {
        nodoBajoMouse = nodoEnPosicion(mouseX, mouseY);
    }
    if (nodoBajoMouse != null) {
        pedirCursorMano();
    }
    pushMatrix();
    girarLibro();
    image(imgLibroHabilidades, libroX, libroY, libroAncho, libroAlto);
    dibujarRamasLibro();
    for (Nodo n : arbol.preorden()) {
        dibujarNodoArbol(n);
    }
    // la hoja derecha muestra lo que está bajo el mouse; si no hay nada, la
    // habilidad elegida con clic
    dibujarPaginaDerecha(nodoBajoMouse != null ? nodoBajoMouse : nodoSeleccionado);
    popMatrix();

    botonVolverMenu.dibujar();
    textoPixel("LIBRO DE CAMPAÑA · TURNO " + turnoVisible() + " DE " + Partida.TURNOS_TOTALES, width / 2,
        botonVolverMenu.y + botonVolverMenu.alto / 2, celdaInterfaz(), 1, #fff3d6, #1a1010, 0, 0, false, CENTER, CENTER);
    dibujarTextoFlotante();
    if (avisoActivo()) {
        dibujarAviso();
    }
    if (partidaTerminada()) {
        dibujarFinDePartida();
    }
}

// ===========================================================================
// EL ARBOL
// ===========================================================================

// Las ramas de madera: una por cada arista padre-hijo.
void dibujarRamasLibro() {
    for (Nodo n : arbol.preorden()) {
        for (Nodo h : n.getHijos()) {
            float x1 = centroNodoX(n), y1 = centroNodoY(n);
            float x2 = centroNodoX(h), y2 = centroNodoY(h);
            float largo = dist(x1, y1, x2, y2);
            float grueso = bl(9);
            pushMatrix();
            translate(x1, y1);
            rotate(atan2(y2 - y1, x2 - x1));
            image(imgAristaLibro, 0, -grueso / 2, largo, grueso);
            popMatrix();
        }
    }
}

// El nodo bajo (mx, my): se mira cada lugar del árbol (recorrido en
// preorden) y se devuelve el primero cuyo círculo contiene el punto.
Nodo nodoEnPosicion(float mx, float my) {
    float[] m = mouseEnLibro();
    for (Nodo n : arbol.preorden()) {
        if (lugarDe(n) >= 0 && dist(m[0], m[1], centroNodoX(n), centroNodoY(n)) <= radioNodoLibro() * 1.1) {
            return n;
        }
    }
    return null;
}

// Cada habilidad es una medalla: dorada con el candado abierto si ya está
// comprada, gris con candado si no. Con el mouse encima crece un poco; la
// elegida lleva un anillo blanco; la que se puede comprar, un brillo que
// late.
void dibujarNodoArbol(Nodo n) {
    if (lugarDe(n) < 0) {
        return;
    }
    boolean desbloqueada = n.getDesbloqueada();
    float cx = centroNodoX(n) + sacudidaNodo(n);
    float cy = centroNodoY(n);
    float d = bl(DIAMETRO_NODO) * (n == nodoBajoMouse ? 1.15 : 1);
    if (sePuedeComprar(n) && !desbloqueada) {
        noStroke();
        float brillo = 0.5 + 0.5 * sin(millis() * 0.006);
        fill(255, 230, 120, 60 + 80 * brillo);
        ellipse(cx, cy, d * 1.35, d * 1.35);
    }
    if (n == nodoSeleccionado) {
        noStroke();
        fill(255);
        ellipse(cx, cy, d * 1.18, d * 1.18);
    }
    image(desbloqueada ? imgNodoAbierto : imgNodoCerrado, cx - d / 2, cy - d / 2, d, d);
    if (!desbloqueada && partida.getTurno() < n.getRondaMinima()) {
        dibujarInsigniaRonda(cx + d * 0.4, cy - d * 0.4, d * 0.2, n.getRondaMinima());
    }
    dibujarOndaNodo(n, cx, cy, d / 2);
}

// "R6": la habilidad se puede comprar desde la ronda 6.
void dibujarInsigniaRonda(float x, float y, float r, int ronda) {
    stroke(#1a1414);
    strokeWeight(1.5);
    fill(#c0392b);
    ellipse(x, y, r * 2.6, r * 2.6);
    float celda = max(1, r * 2 / 9);
    textoPixel("R" + ronda, x, y, celda, 1, #ffffff, 0, 0, 0, false, CENTER, CENTER);
}

// Al desbloquear sale una onda dorada; si no se pudo, el nodo se sacude.
void dibujarOndaNodo(Nodo n, float x, float y, float r) {
    if (n != nodoAnimado || !animacionExitosa) {
        return;
    }
    float t = (millis() - momentoAnimacion) / (float) DURACION_ONDA;
    if (t >= 1) {
        return;
    }
    noFill();
    stroke(COLOR_DORADO, 255 * (1 - t));
    strokeWeight(max(2, r * 0.3 * (1 - t)));
    float dd = r * 2 * (1 + t * 1.4);
    ellipse(x, y, dd, dd);
}

float sacudidaNodo(Nodo n) {
    if (n != nodoAnimado || animacionExitosa) {
        return 0;
    }
    float t = (millis() - momentoAnimacion) / (float) DURACION_SACUDIDA;
    if (t >= 1) {
        return 0;
    }
    return sin(t * TWO_PI * 3) * radioNodoLibro() * 0.3 * (1 - t);
}

// ===========================================================================
// LA HOJA DERECHA
// ===========================================================================

// La celda de la letra pixel en el libro: "cqw" del HTML (1 % del ancho)
// pasado a celdas de la letra de 7 filas.
float celdaLibro(float cqw) {
    return max(1, libroAncho * cqw / 100 / 7.5);
}

// El color del nombre según lo cara que es (como R[] del HTML): blanca la
// raíz, verde, azul, morada, rosada y dorada la más cara.
color colorRareza(Nodo n) {
    int c = n.getCosto();
    if (c <= 0) {
        return #ffffff;
    } else if (c <= 2) {
        return #7dff7d;
    } else if (c <= 3) {
        return #4db8ff;
    } else if (c <= 4) {
        return #c77dff;
    } else if (c <= 5) {
        return #ff5d8f;
    }
    return #ffd23f;
}

void dibujarPaginaDerecha(Nodo n) {
    // los puntos
    float celda = celdaLibro(2.5);
    textoPixel("PUNTOS: " + partida.getPuntos(), bx(663), by(102), celda, 1, #ffffff, #000000, 0, 0, false, CENTER, CENTER);
    xFlotante = bx(800);
    yFlotante = by(118);
    dibujarCorbata();
    if (n == null) {
        textoPixel("ELIGE UNA HABILIDAD", bx(610), by(274), celdaLibro(1.6), 1, #5f5244, 0, 0, 0, false, LEFT, CENTER);
        textoPixel("DEL ÁRBOL", bx(610), by(308), celdaLibro(1.6), 1, #5f5244, 0, 0, 0, false, LEFT, CENTER);
        dibujarCostoLibro(null);
        return;
    }
    // la medalla en el círculo de la hoja y el nombre al lado
    float d = bl(DIAMETRO_NODO) * 1.04;
    image(n.getDesbloqueada() ? imgNodoAbierto : imgNodoCerrado, bx(604) - d / 2, by(207) - d / 2, d, d);
    String nombre = n.getNombre().toUpperCase();
    float celdaNombre = celdaLibro(2.0);
    while (medirPixel(nombre) * celdaNombre > bl(300) && celdaNombre > 1) {
        celdaNombre *= 0.9;
    }
    color rareza = colorRareza(n);
    if (n.getCosto() >= 6) {
        // la más cara brilla
        noStroke();
        fill(rareza, 50 + 30 * sin(millis() * 0.004));
        rect(bx(640) - bl(6), by(213) - bl(16), medirPixel(nombre) * celdaNombre + bl(12), bl(32), bl(8));
    }
    textoPixel(nombre, bx(640), by(213), celdaNombre, 1, rareza, #000000, 0, 0, false, LEFT, CENTER);
    // lo que hace, en los renglones de la hoja
    float celdaTexto = celdaLibro(1.45);
    int maxCeldas = floor(bl(355) / celdaTexto);
    ArrayList<String> lineas = partirPixel(n.getDescripcion().toUpperCase(), maxCeldas);
    float[] renglones = {274, 308, 346, 385, 418};
    for (int i = 0; i < min(lineas.size(), renglones.length); i++) {
        textoPixel(lineas.get(i), bx(610), by(renglones[i]), celdaTexto, 1, #ffffff, #000000, 0, 0, false, LEFT, CENTER);
    }
    dibujarCostoLibro(n);
}

// La corbata del candidato en la foto del post-it, del color de su asiento
// (en el HTML se cambiaba con la tecla R solo para probar).
void dibujarCorbata() {
    color c = COLOR_ASIENTO[enRed() ? miAsientoRed : 0];
    float x = bx(878), y = by(137);
    float w = bl(24), h = bl(56);
    float u = w / 10;   // la corbata es de 10 x 24 cuadritos
    pushMatrix();
    translate(x, y);
    rotate(radians(5));
    translate(-w / 2, 0);
    noStroke();
    int[][] negro = {{2, 0, 6, 4}, {3, 4, 4, 4}, {2, 8, 6, 5}, {1, 13, 8, 4}, {2, 17, 6, 3}, {3, 20, 4, 3}, {4, 23, 2, 1}};
    int[][] tela = {{3, 1, 4, 2}, {4, 4, 2, 4}, {3, 8, 4, 5}, {2, 13, 6, 4}, {3, 17, 4, 3}, {4, 20, 2, 3}};
    fill(#000000);
    for (int[] r : negro) {
        rect(r[0] * u, r[1] * u * h / w / 2.4, r[2] * u, r[3] * u * h / w / 2.4 + 0.5);
    }
    fill(c);
    for (int[] r : tela) {
        rect(r[0] * u, r[1] * u * h / w / 2.4, r[2] * u, r[3] * u * h / w / 2.4 + 0.5);
    }
    popMatrix();
}

// El recuadro del costo (abajo en la hoja derecha): la palabra COSTO
// clarita, corriendo en diagonal, y encima el número grande. Un clic ahí
// compra la habilidad elegida (si se puede; si no, el número se sacude).
float[] cajaCosto() {
    return new float[] {bx(579), by(468), bl(373), bl(135)};
}

boolean mouseEnCosto() {
    float[] c = cajaCosto();
    float[] m = mouseEnLibro();
    return m[0] >= c[0] && m[0] <= c[0] + c[2] && m[1] >= c[1] && m[1] <= c[1] + c[3];
}

int momentoNegado = -100000;

void dibujarCostoLibro(Nodo n) {
    float[] c = cajaCosto();
    float celda = celdaLibro(1.6);
    // COSTO repetido, corriendo despacio en diagonal (como el HTML)
    clip(c[0], c[1], c[2], c[3]);
    float avance = (millis() % 7000) / 7000.0;
    float paso = bl(33);
    for (int fila = -1; fila < 6; fila++) {
        float y = c[1] + fila * paso - avance * bl(69);
        float x0 = c[0] - (fila % 2 == 0 ? 0 : bl(42)) - avance * bl(83);
        for (float x = x0; x < c[0] + c[2] + bl(80); x += medirPixel("COSTO ") * celda) {
            textoPixel("COSTO", x, y + paso, celda, 1, color(95, 82, 68, 97), 0, 0, 0, false, LEFT, CENTER);
        }
    }
    noClip();
    if (n == null) {
        return;
    }
    float cx = bx(765), cy = by(536);
    if (millis() - momentoNegado < 300) {
        cx += sin((millis() - momentoNegado) / 300.0 * TWO_PI * 2) * bl(8);
    }
    boolean propia = n.getDesbloqueada();
    boolean abierta = arbol.estaDisponible(n) || propia;
    if (propia) {
        textoPixel("COMPRADA", cx, cy, celdaLibro(1.9), 1, #ffffff, #000000, 0, 0, false, CENTER, CENTER);
    } else if (!abierta || partida.getTurno() < n.getRondaMinima()) {
        textoPixel("BLOQUEADA", cx, cy - bl(14), celdaLibro(1.9), 1, #ffffff, #000000, 0, 0, false, CENTER, CENTER);
        dibujarMotivoLibro(n, cx, cy + bl(22));
    } else {
        boolean alcanza = partida.puedePagar(n.getCosto());
        boolean lista = n == nodoSeleccionado && sePuedeComprar(n);
        if (lista) {
            pedirCursorManoSi(mouseEnCosto());
            noStroke();
            fill(255, 235, 150, 30 + 40 * (0.5 + 0.5 * sin(millis() * 0.0057)));
            rect(c[0], c[1], c[2], c[3], bl(8));
        }
        textoPixel(str(n.getCosto()), cx, cy - bl(6), celdaLibro(9) / 3, 3, alcanza ? #8c8c8c : #b5605a, #000000, 0, 0, true, CENTER, CENTER);
        String pie = lista ? "CLIC PARA COMPRAR" : (alcanza ? "ELÍGELA Y HAZ CLIC AQUÍ" : textoEstadoHabilidad(n).toUpperCase());
        dibujarLineasCentradas(pie, cx, by(590), celdaLibro(1.2), lista ? #5f7f22 : #3a2a22);
    }
}

void dibujarMotivoLibro(Nodo n, float cx, float y) {
    dibujarLineasCentradas(textoEstadoHabilidad(n).toUpperCase(), cx, y, celdaLibro(1.2), #3a2a22);
}

void dibujarLineasCentradas(String texto, float cx, float y, float celda, color c) {
    ArrayList<String> lineas = partirPixel(texto, floor(bl(340) / celda));
    for (int i = 0; i < min(2, lineas.size()); i++) {
        textoPixel(lineas.get(i), cx, y + i * 10 * celda, celda, 1, c, 0, 0, 0, false, CENTER, CENTER);
    }
}

void pedirCursorManoSi(boolean condicion) {
    if (condicion) {
        pedirCursorMano();
    }
}

// Si el mouse está sobre el libro (con un margen; el libro va un poco girado)
boolean mouseSobreLibro() {
    float[] m = mouseEnLibro();
    float margen = libroAncho * 0.02;
    return m[0] >= libroX - margen && m[0] <= libroX + libroAncho + margen && m[1] >= libroY - margen && m[1] <= libroY + libroAlto + margen;
}

boolean sePuedeComprar(Nodo n) {
    return arbol.estaDisponible(n) && partida.puedePagar(n.getCosto()) && partida.getTurno() >= n.getRondaMinima()
        && !partidaTerminada();
}

// Explica en una frase por qué una habilidad no se puede comprar todavía
// (o confirma que sí), en el mismo orden en que lo revisa desbloquear().
String textoEstadoHabilidad(Nodo n) {
    if (n == arbol.getRaiz()) {
        return "Siempre está desbloqueada: de aquí salen las tres ramas.";
    }
    if (n.getDesbloqueada()) {
        return "Desbloqueada: ya es parte de tu campaña.";
    }
    Nodo padre = arbol.buscarPadre(arbol.getRaiz(), n.getNombre());
    if (padre != null && !padre.getDesbloqueada()) {
        return "Primero desbloquea «" + padre.getNombre() + "».";
    }
    if (partida.getTurno() < n.getRondaMinima()) {
        return "Se puede comprar desde la ronda " + n.getRondaMinima() + ".";
    }
    if (!partida.puedePagar(n.getCosto())) {
        int faltan = n.getCosto() - partida.getPuntos();
        return "Te faltan " + (faltan == 1 ? "1 punto" : faltan + " puntos") + ". Termina el día para ganar más.";
    }
    return n == nodoSeleccionado ? "¡Disponible!" : "¡Disponible! Haz clic en ella para elegirla.";
}

// ===========================================================================
// CLICS
// ===========================================================================

// Un clic en una habilidad la elige; un clic en el costo la compra. Si la
// partida terminó, solo responden los botones de la tarjeta final.
void clicEnCuaderno() {
    if (partidaTerminada()) {
        if (botonNuevaPartida.contiene(mouseX, mouseY)) {
            // la campaña terminó: se deja lista una nueva y se vuelve al
            // menú principal (no se sigue jugando la terminada)
            cerrarRed();
            reiniciarPartida();
            volverAlMenu();
        }
        return;
    }
    if (botonVolverMenu.contiene(mouseX, mouseY)) {
        irA(MENU);
    } else if (!mouseSobreLibro() && !mouseEnCosto()) {
        irA(MENU);   // un clic fuera del libro lo cierra
    } else if (mouseEnCosto() && nodoSeleccionado != null && !nodoSeleccionado.getDesbloqueada()) {
        if (sePuedeComprar(nodoSeleccionado)) {
            intentarDesbloquear(nodoSeleccionado);
        } else {
            momentoNegado = millis();
            avisar(textoEstadoHabilidad(nodoSeleccionado));
        }
    } else {
        Nodo clic = nodoEnPosicion(mouseX, mouseY);
        if (clic != null) {
            nodoSeleccionado = clic;
        }
    }
}
