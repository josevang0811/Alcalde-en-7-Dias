// Contencion — acto 2 del caso del día: frenar el bulo en la red de Civitas.
//
// La red se lee de data/casos/<caso>.txt (órdenes explicadas en ese archivo)
// y la lógica está en RedCivitas.java (grafo con listas de adyacencia, BFS
// por turnos y árbol de padres para rastrear el origen). Aquí solo se dibuja
// y se maneja el mouse.
//
// Cada turno el jugador tiene unos puntos para verificar cuentas, hablar con
// influencers, desmentir con una prueba, reportar bots o rastrear de quién le
// llegó el bulo a alguien. Con "Pasar turno" el bulo avanza un nivel.

RedCivitas redCivitas;
boolean contencionEnCurso = false;
boolean contencionTerminada = false;
String casoTitulo = "", casoBulo = "", casoVerdad = "", casoLeccion = "";
int casoTurnos = 8, casoPuntos = 3, casoVentaja = 2;
int puntosTurno, cartasEvidencia;
int cuentaElegida = -1, cuentaEncima = -1;
int momentoTurno = -10000;          // para animar los pulsos del último turno
ArrayList<String> feedContencion = new ArrayList<String>();
float resultadoContencion = -1;     // % contagiado al terminar (lo usa el debate)
String avisoContencion = "";
int momentoAvisoContencion = -10000;

final color C_LIMPIA = #c9ced6;
final color C_CONTAGIADA = #d83a34;
final color C_PROTEGIDA = #3b7fd0;
final color C_CORREGIDA = #e08a2c;
final color C_ELIMINADA = #3a3d46;
final color C_FONDO_RED = #10131c;
final color C_PANEL = #181c28;
final color C_TEXTO = #e8e6e1;
final color C_TEXTO_SUAVE = #8a90a0;

boolean contencionActiva() {
    return contencionEnCurso;
}

void empezarContencion(String caso) {
    String[] lineas = loadStrings("casos/" + caso + ".txt");
    if (lineas == null) {
        println("Contencion: no se encontró casos/" + caso + ".txt");
        return;
    }
    redCivitas = new RedCivitas();
    String origen = "";
    ArrayList<String> botsConocidos = new ArrayList<String>();
    ArrayList<String> ids = new ArrayList<String>();
    ArrayList<String[]> conexiones = new ArrayList<String[]>();
    long semilla = 1;
    float contagioCaso = 0.3;
    cartasEvidencia = 0;
    for (String linea : lineas) {
        linea = trim(linea);
        if (linea.length() == 0 || linea.startsWith("#")) {
            continue;
        }
        String[] t = splitTokens(linea, " ");
        String orden = t[0];
        if (orden.equals("titulo")) casoTitulo = restoDe(linea, 1);
        else if (orden.equals("bulo")) casoBulo = restoDe(linea, 1);
        else if (orden.equals("verdad")) casoVerdad = restoDe(linea, 1);
        else if (orden.equals("leccion")) casoLeccion = restoDe(linea, 1);
        else if (orden.equals("ventaja")) casoVentaja = int(t[1]);
        else if (orden.equals("puntos")) casoPuntos = int(t[1]);
        else if (orden.equals("turnos")) casoTurnos = int(t[1]);
        else if (orden.equals("cartas")) cartasEvidencia = int(t[1]);
        else if (orden.equals("semilla")) semilla = Long.parseLong(t[1]);
        else if (orden.equals("contagio")) contagioCaso = float(t[1]);
        else if (orden.equals("cuenta")) {
            ids.add(t[1]);
            redCivitas.agregarCuenta(restoDe(linea, 6), t[2], float(t[3]), float(t[4]), float(t[5]));
        } else if (orden.equals("seguidores")) {
            conexiones.add(t);
        } else if (orden.equals("origen")) {
            origen = t[1];
        } else if (orden.equals("botconocido")) {
            botsConocidos.add(t[1]);
        }
    }
    for (String[] t : conexiones) {
        int a = ids.indexOf(t[1]);
        for (int k = 2; k < t.length; k++) {
            redCivitas.seguir(ids.indexOf(t[k]), a);
        }
    }
    redCivitas.empezar(max(0, ids.indexOf(origen)), semilla);
    redCivitas.contagio = contagioCaso;
    for (String b : botsConocidos) {
        int i = ids.indexOf(b);
        if (i >= 0) {
            redCivitas.esBotConocido[i] = true;
        }
    }
    feedContencion.clear();
    feedContencion.add(redCivitas.nombres.get(redCivitas.origen) + " publicó el video");
    // el bulo sale con ventaja (lo que tardó la investigación)
    for (int k = 0; k < casoVentaja; k++) {
        redCivitas.avanzar();
        anotarContagios();
    }
    puntosTurno = casoPuntos;
    cuentaElegida = -1;
    contencionTerminada = false;
    resultadoContencion = -1;
    contencionEnCurso = true;
    momentoTurno = millis();
}

void anotarContagios() {
    for (int[] c : redCivitas.ultimosContagios) {
        String quien = redCivitas.nombres.get(c[1]);
        String verbo = redCivitas.tipos.get(c[1]).equals(RedCivitas.GRUPO) ? " lo reenvió al grupo" : " lo compartió";
        feedContencion.add(0, quien + verbo);
    }
    while (feedContencion.size() > 9) {
        feedContencion.remove(feedContencion.size() - 1);
    }
}

void pasarTurnoContencion() {
    if (contencionTerminada) {
        return;
    }
    int nuevos = redCivitas.avanzar();
    anotarContagios();
    if (nuevos == 0 && !feedContencion.get(0).startsWith("Nadie")) {
        feedContencion.add(0, "Nadie más lo compartió este turno");
    }
    puntosTurno = casoPuntos;
    momentoTurno = millis();
    if (!redCivitas.sigueVivo() || redCivitas.turno >= casoTurnos + casoVentaja) {
        contencionTerminada = true;
        resultadoContencion = redCivitas.porcentajeContagiado();
    }
}

void avisarContencion(String texto) {
    avisoContencion = texto;
    momentoAvisoContencion = millis();
}

// ---------- Dibujo ----------

// La red ocupa la parte izquierda; el panel, la derecha.
float redX0() { return width * 0.03; }
float redX1() { return width * 0.70; }
float redY0() { return height * 0.13; }
float redY1() { return height * 0.92; }
float xCuenta(int i) { return lerp(redX0(), redX1(), redCivitas.posiciones.get(i)[0]); }
float yCuenta(int i) { return lerp(redY0(), redY1(), redCivitas.posiciones.get(i)[1]); }
float radioCuenta(int i) {
    return height * (0.018 + 0.0035 * min(6, redCivitas.seguidores(i)));
}

color colorEstado(int e) {
    if (e == RedCivitas.CONTAGIADA) return C_CONTAGIADA;
    if (e == RedCivitas.PROTEGIDA) return C_PROTEGIDA;
    if (e == RedCivitas.CORREGIDA) return C_CORREGIDA;
    if (e == RedCivitas.ELIMINADA) return C_ELIMINADA;
    return C_LIMPIA;
}

void dibujarContencion() {
    background(C_FONDO_RED);
    float celda = max(2, round(height / 360.0));
    cuentaEncima = cuentaBajoMouse();

    // Encabezado
    textoPixel("CIVITAS · EL BULO SE ESTÁ REGANDO", redX0(), height * 0.045, celda * 1.5, C_CONTAGIADA, LEFT, CENTER);
    textoPixel(casoTitulo.toUpperCase(), redX0(), height * 0.085, celda, C_TEXTO_SUAVE, LEFT, CENTER);

    dibujarConexionesRed();
    dibujarPulsosRed();
    for (int i = 0; i < redCivitas.total(); i++) {
        dibujarCuentaRed(i, celda);
    }
    dibujarPanelContencion(celda);
    if (millis() - momentoAvisoContencion < 2200) {
        textoPixel(avisoContencion, (redX0() + redX1()) / 2, height * 0.96, celda, #f2c14e, CENTER, CENTER);
    } else {
        textoPixel("CLIC EN UNA CUENTA PARA VER QUÉ HACER · ESPACIO: PASAR TURNO", (redX0() + redX1()) / 2, height * 0.96, celda, C_TEXTO_SUAVE, CENTER, CENTER);
    }
    if (contencionTerminada) {
        dibujarFinContencion(celda);
    }
}

void dibujarConexionesRed() {
    for (int a = 0; a < redCivitas.total(); a++) {
        for (int b : redCivitas.siguen.get(a)) {
            boolean viajo = redCivitas.padre[b] == a && (redCivitas.estado[b] == RedCivitas.CONTAGIADA || redCivitas.estado[b] == RedCivitas.CORREGIDA);
            boolean rastreo = viajo && redCivitas.rastreada[b];
            boolean resaltada = cuentaElegida == a || cuentaElegida == b || cuentaEncima == a;
            if (rastreo) {
                stroke(#f2c14e);
                strokeWeight(height * 0.004);
            } else if (viajo) {
                stroke(C_CONTAGIADA, 150);
                strokeWeight(height * 0.0025);
            } else {
                stroke(resaltada ? color(170, 178, 195, 170) : color(80, 88, 105, 110));
                strokeWeight(height * 0.0015);
            }
            flechaRed(xCuenta(a), yCuenta(a), xCuenta(b), yCuenta(b), radioCuenta(b));
        }
    }
    noStroke();
}

// Línea con punta de flecha que termina en el borde del círculo destino
void flechaRed(float x0, float y0, float x1, float y1, float r) {
    float d = dist(x0, y0, x1, y1);
    if (d < 1) return;
    float ux = (x1 - x0) / d, uy = (y1 - y0) / d;
    float fx = x1 - ux * (r + 3), fy = y1 - uy * (r + 3);
    line(x0, y0, fx, fy);
    float p = height * 0.009;
    line(fx, fy, fx - ux * p - uy * p * 0.6, fy - uy * p + ux * p * 0.6);
    line(fx, fy, fx - ux * p + uy * p * 0.6, fy - uy * p - ux * p * 0.6);
}

// Puntos rojos que viajan por las flechas del último turno
void dibujarPulsosRed() {
    float t = (millis() - momentoTurno) / 700.0;
    if (t > 1) return;
    noStroke();
    fill(C_CONTAGIADA);
    for (int[] c : redCivitas.ultimosContagios) {
        float x = lerp(xCuenta(c[0]), xCuenta(c[1]), t);
        float y = lerp(yCuenta(c[0]), yCuenta(c[1]), t);
        rect(x - height * 0.005, y - height * 0.005, height * 0.01, height * 0.01);
    }
}

void dibujarCuentaRed(int i, float celda) {
    float x = xCuenta(i), y = yCuenta(i), r = radioCuenta(i);
    int e = redCivitas.estado[i];
    // al contagiarse, la cuenta "salta" un poco cuando le llega el pulso
    float salto = 0;
    if (redCivitas.turnoContagio[i] == redCivitas.turno && e == RedCivitas.CONTAGIADA) {
        float t = (millis() - momentoTurno - 700) / 300.0;
        if (t > 0 && t < 1) salto = sin(t * PI) * r * 0.35;
    }
    if (i == cuentaElegida || i == cuentaEncima) {
        noFill();
        stroke(C_TEXTO);
        strokeWeight(height * 0.0025);
        ellipse(x, y, (r + height * 0.009) * 2, (r + height * 0.009) * 2);
    }
    noStroke();
    fill(colorEstado(e));
    String tipo = redCivitas.tipos.get(i);
    if (tipo.equals(RedCivitas.GRUPO)) {
        rect(x - r - salto, y - r - salto, (r + salto) * 2, (r + salto) * 2, r * 0.35);
    } else if (tipo.equals(RedCivitas.MEDIO)) {
        rect(x - r * 1.2 - salto, y - r * 0.8 - salto, (r * 1.2 + salto) * 2, (r * 0.8 + salto) * 2, 3);
    } else {
        ellipse(x, y, (r + salto) * 2, (r + salto) * 2);
    }
    if (tipo.equals(RedCivitas.INFLUENCER)) {
        noFill();
        stroke(colorEstado(e));
        strokeWeight(height * 0.002);
        ellipse(x, y, r * 2.7, r * 2.7);
        noStroke();
    }
    if (e == RedCivitas.ELIMINADA) {
        stroke(C_CONTAGIADA);
        strokeWeight(height * 0.004);
        line(x - r * 0.6, y - r * 0.6, x + r * 0.6, y + r * 0.6);
        line(x - r * 0.6, y + r * 0.6, x + r * 0.6, y - r * 0.6);
        noStroke();
    }
    // nombre y marcas
    color tinta = e == RedCivitas.ELIMINADA ? C_TEXTO_SUAVE : C_TEXTO;
    textoPixel(redCivitas.nombres.get(i), x, y + r + celda * 7, celda, tinta, CENTER, CENTER);
    if (tipo.equals(RedCivitas.BOT) && redCivitas.esBotConocido[i]) {
        textoPixel("BOT", x, y, celda, #10131c, CENTER, CENTER);
    }
    if (i == redCivitas.origen && redCivitas.origenDescubierto) {
        textoPixel("ORIGEN", x, y - r - celda * 6, celda, #f2c14e, CENTER, CENTER);
    }
}

int cuentaBajoMouse() {
    for (int i = 0; i < redCivitas.total(); i++) {
        float r = radioCuenta(i) * 1.3;
        if (dist(mouseX, mouseY, xCuenta(i), yCuenta(i)) < r) {
            return i;
        }
    }
    return -1;
}

// ---------- Panel de la derecha ----------

float panelX() { return width * 0.73; }
float panelAncho() { return width * 0.25; }

// Botones del panel: se arman al dibujar y se revisan al hacer clic
ArrayList<float[]> botonesContencion = new ArrayList<float[]>();   // x, y, w, h, accion
final int ACC_VERIFICAR = 1, ACC_INFLUENCER = 2, ACC_DESMENTIR = 3, ACC_REPORTAR = 4, ACC_RASTREAR = 5, ACC_TURNO = 6, ACC_SEGUIR = 7;

void dibujarPanelContencion(float celda) {
    botonesContencion.clear();
    float x = panelX(), w = panelAncho(), y = height * 0.05;
    noStroke();
    fill(C_PANEL);
    rect(x, y, w, height * 0.90, 8);
    float px = x + celda * 8;
    float py = y + celda * 10;

    int turnoJugador = min(casoTurnos, redCivitas.turno - casoVentaja + 1);
    textoPixel("TURNO " + turnoJugador + " DE " + casoTurnos, px, py, celda * 1.5, C_TEXTO, LEFT, CENTER);
    py += celda * 16;
    // puntos de acción
    textoPixel("PUNTOS", px, py, celda, C_TEXTO_SUAVE, LEFT, CENTER);
    for (int k = 0; k < casoPuntos; k++) {
        fill(k < puntosTurno ? #f2c14e : #3a3d46);
        rect(px + celda * 40 + k * celda * 9, py - celda * 3, celda * 6, celda * 6);
    }
    py += celda * 12;
    textoPixel("CARTAS DE EVIDENCIA: " + cartasEvidencia, px, py, celda, C_TEXTO_SUAVE, LEFT, CENTER);
    py += celda * 14;

    // cuánto se ha regado
    float pct = redCivitas.porcentajeContagiado();
    textoPixel("YA LO COMPARTIÓ: " + round(pct) + "%", px, py, celda, C_TEXTO, LEFT, CENTER);
    py += celda * 8;
    fill(#2a2f3d);
    rect(px, py, w - celda * 16, celda * 5);
    fill(C_CONTAGIADA);
    rect(px, py, (w - celda * 16) * pct / 100.0, celda * 5);
    py += celda * 16;

    // la cuenta elegida y sus acciones
    if (cuentaElegida >= 0) {
        py = dibujarFichaCuenta(cuentaElegida, px, py, w - celda * 16, celda);
    } else {
        py += parrafoPixel("Elige una cuenta en la red para ver quién es y qué puedes hacer.", px, py, celda, w - celda * 16, C_TEXTO_SUAVE, 4);
        py += celda * 8;
    }

    // Civitas en vivo
    py = max(py + celda * 6, height * 0.62);
    textoPixel("CIVITAS EN VIVO", px, py, celda, C_CONTAGIADA, LEFT, CENTER);
    py += celda * 10;
    for (int k = 0; k < min(6, feedContencion.size()); k++) {
        textoPixel(recortar(feedContencion.get(k), floor((w - celda * 16) / celda / 6)), px, py, celda, k == 0 ? C_TEXTO : C_TEXTO_SUAVE, LEFT, CENTER);
        py += celda * 9;
    }

    // pasar turno
    float bh = celda * 14;
    botonContencion("PASAR TURNO", px, y + height * 0.90 - bh - celda * 8, w - celda * 16, bh, ACC_TURNO, true, celda);
}

String recortar(String t, int maxLetras) {
    return t.length() <= maxLetras ? t : t.substring(0, max(0, maxLetras - 1)) + "…";
}

float dibujarFichaCuenta(int i, float px, float py, float w, float celda) {
    String tipo = redCivitas.tipos.get(i);
    int e = redCivitas.estado[i];
    textoPixel(recortar(redCivitas.nombres.get(i), floor(w / (celda * 1.5) / 6)), px, py, celda * 1.5, C_TEXTO, LEFT, CENTER);
    py += celda * 12;
    String queEs = tipo.equals(RedCivitas.BOT) ? (redCivitas.esBotConocido[i] ? "BOT (lo descubriste)" : "Cuenta") :
                   tipo.equals(RedCivitas.GRUPO) ? "Grupo" : tipo.equals(RedCivitas.MEDIO) ? "Medio" :
                   tipo.equals(RedCivitas.INFLUENCER) ? "Influencer" : "Persona";
    textoPixel(queEs + " · " + redCivitas.seguidores(i) + " la siguen", px, py, celda, C_TEXTO_SUAVE, LEFT, CENTER);
    py += celda * 9;
    float c = redCivitas.credulidad.get(i);
    String crede = c >= 0.8 ? "Se cree casi todo" : c >= 0.5 ? "A veces se lo cree" : "Desconfía";
    textoPixel(crede, px, py, celda, C_TEXTO_SUAVE, LEFT, CENTER);
    py += celda * 9;
    String est = e == RedCivitas.CONTAGIADA ? "YA LO COMPARTIÓ" : e == RedCivitas.PROTEGIDA ? "VERIFICADA" :
                 e == RedCivitas.CORREGIDA ? "LO DESMINTIÓ" : e == RedCivitas.ELIMINADA ? "REPORTADA" : "NO LO HA VISTO";
    textoPixel(est, px, py, celda, colorEstado(e) == C_LIMPIA ? C_TEXTO : colorEstado(e), LEFT, CENTER);
    py += celda * 12;
    if (redCivitas.rastreada[i] && redCivitas.padre[i] >= 0) {
        textoPixel("LE LLEGÓ DE:", px, py, celda, #f2c14e, LEFT, CENTER);
        py += celda * 9;
        textoPixel(redCivitas.nombres.get(redCivitas.padre[i]), px, py, celda, #f2c14e, LEFT, CENTER);
        py += celda * 10;
    }

    float bh = celda * 12, gap = celda * 3;
    boolean esBot = tipo.equals(RedCivitas.BOT);
    if (e == RedCivitas.LIMPIA && !esBot) {
        botonContencion("VERIFICAR · 1", px, py, w, bh, ACC_VERIFICAR, puntosTurno >= 1, celda);
        py += bh + gap;
    }
    if (tipo.equals(RedCivitas.INFLUENCER) && (e == RedCivitas.LIMPIA || e == RedCivitas.CONTAGIADA)) {
        botonContencion("HABLAR CON ÉL · 2", px, py, w, bh, ACC_INFLUENCER, puntosTurno >= 2, celda);
        py += bh + gap;
    }
    if (!esBot && (e == RedCivitas.LIMPIA || e == RedCivitas.CONTAGIADA)) {
        botonContencion("DESMENTIR CON PRUEBA · 2", px, py, w, bh, ACC_DESMENTIR, puntosTurno >= 2 && cartasEvidencia > 0, celda);
        py += bh + gap;
    }
    if (((esBot && redCivitas.esBotConocido[i]) || (i == redCivitas.origen && redCivitas.origenDescubierto)) && e != RedCivitas.ELIMINADA) {
        botonContencion("REPORTAR · 1", px, py, w, bh, ACC_REPORTAR, puntosTurno >= 1, celda);
        py += bh + gap;
    }
    if ((e == RedCivitas.CONTAGIADA || e == RedCivitas.CORREGIDA) && !redCivitas.rastreada[i]) {
        botonContencion("RASTREAR DE DÓNDE VINO · 1", px, py, w, bh, ACC_RASTREAR, puntosTurno >= 1, celda);
        py += bh + gap;
    }
    return py + celda * 4;
}

void botonContencion(String texto, float x, float y, float w, float h, int accion, boolean activo, float celda) {
    boolean encima = activo && mouseX > x && mouseX < x + w && mouseY > y && mouseY < y + h;
    noStroke();
    fill(!activo ? #22262f : encima ? #3b7fd0 : #2c3a55);
    rect(x, y, w, h, 4);
    textoPixel(texto, x + w / 2, y + h / 2, celda, activo ? C_TEXTO : #5a6070, CENTER, CENTER);
    if (activo) {
        botonesContencion.add(new float[] {x, y, w, h, accion});
    }
}

// ---------- Final ----------

void dibujarFinContencion(float celda) {
    fill(0, 170);
    noStroke();
    rect(0, 0, width, height);
    float w = width * 0.46, h = height * 0.56;
    float x = width / 2 - w / 2, y = height / 2 - h / 2;
    fill(C_PANEL);
    rect(x, y, w, h, 10);
    float px = x + celda * 12, py = y + celda * 16, ancho = w - celda * 24;
    float pct = resultadoContencion;
    String titular = pct < 25 ? "LO FRENASTE A TIEMPO" : pct < 55 ? "SE REGÓ, PERO NO A TODOS" : "SE TE SALIÓ DE LAS MANOS";
    color ct = pct < 25 ? #4aa84a : pct < 55 ? #e08a2c : C_CONTAGIADA;
    textoPixel(titular, x + w / 2, py, celda * 2, ct, CENTER, CENTER);
    py += celda * 22;
    textoPixel("LO COMPARTIÓ EL " + round(pct) + "% DE LA RED", x + w / 2, py, celda * 1.5, C_TEXTO, CENTER, CENTER);
    py += celda * 14;
    textoPixel(redCivitas.origenDescubierto ? "ENCONTRASTE A QUIEN LO PUBLICÓ PRIMERO" : "NO SE SUPO QUIÉN LO PUBLICÓ PRIMERO", x + w / 2, py, celda, C_TEXTO_SUAVE, CENTER, CENTER);
    py += celda * 16;
    textoPixel("LA VERDAD", px, py, celda, #f2c14e, LEFT, CENTER);
    py += celda * 9;
    py += parrafoPixel(casoVerdad, px, py, celda, ancho, C_TEXTO, 3) + celda * 8;
    textoPixel("LO QUE QUEDA", px, py, celda, #f2c14e, LEFT, CENTER);
    py += celda * 9;
    parrafoPixel(casoLeccion, px, py, celda, ancho, C_TEXTO, 3);
    float bh = celda * 14;
    botonContencion("CONTINUAR", x + w / 2 - celda * 40, y + h - bh - celda * 10, celda * 80, bh, ACC_SEGUIR, true, celda);
}

// ---------- Entrada ----------

void clicContencion() {
    for (float[] b : botonesContencion) {
        if (mouseX > b[0] && mouseX < b[0] + b[2] && mouseY > b[1] && mouseY < b[1] + b[3]) {
            accionContencion(int(b[4]));
            return;
        }
    }
    if (contencionTerminada) {
        return;
    }
    int i = cuentaBajoMouse();
    if (i >= 0) {
        cuentaElegida = i;
    } else if (mouseX < redX1()) {
        cuentaElegida = -1;
    }
}

void accionContencion(int accion) {
    int i = cuentaElegida;
    if (accion == ACC_SEGUIR) {
        contencionEnCurso = false;
        return;
    }
    if (accion == ACC_TURNO) {
        pasarTurnoContencion();
        return;
    }
    if (i < 0) return;
    String nombre = redCivitas.nombres.get(i);
    if (accion == ACC_VERIFICAR && puntosTurno >= 1 && redCivitas.verificar(i)) {
        puntosTurno -= 1;
        feedContencion.add(0, "Verificaste a " + nombre);
    } else if (accion == ACC_INFLUENCER && puntosTurno >= 2) {
        int n = redCivitas.hablarConInfluencer(i);
        puntosTurno -= 2;
        feedContencion.add(0, nombre + " les pidió no compartirlo (" + n + ")");
    } else if (accion == ACC_DESMENTIR && puntosTurno >= 2 && cartasEvidencia > 0) {
        int n = redCivitas.desmentir(i);
        puntosTurno -= 2;
        cartasEvidencia--;
        feedContencion.add(0, "Desmentiste con prueba en " + nombre + " (" + n + ")");
    } else if (accion == ACC_REPORTAR && puntosTurno >= 1 && redCivitas.reportar(i)) {
        puntosTurno -= 1;
        feedContencion.add(0, "Reportaste a " + nombre);
    } else if (accion == ACC_RASTREAR && puntosTurno >= 1) {
        int p = redCivitas.rastrear(i);
        puntosTurno -= 1;
        if (p >= 0 && p != i) {
            avisarContencion("A " + nombre + " LE LLEGÓ DE " + redCivitas.nombres.get(p));
        }
        if (redCivitas.origenDescubierto) {
            avisarContencion("¡ENCONTRASTE EL ORIGEN: " + redCivitas.nombres.get(redCivitas.origen) + "!");
        }
    }
    if (!redCivitas.sigueVivo()) {
        contencionTerminada = true;
        resultadoContencion = redCivitas.porcentajeContagiado();
    }
}

void teclaContencion() {
    if (key == ' ' && !contencionTerminada) {
        pasarTurnoContencion();
    } else if ((key == ENTER || key == RETURN) && contencionTerminada) {
        contencionEnCurso = false;
    }
}
