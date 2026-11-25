// MisionReels — el último día: decidir qué reels comparte el candidato.
//
// El día 7 Marta no trae un encargo: llama para decir que toda la ciudad está
// mirando la cuenta del candidato y que lo que comparta llega lejos. Al
// colgar se abre el feed de Civitas con los reels que más se están moviendo.
// Cada reel se decide con un gesto:
//
//   → derecha     COMPARTIR (con los seguidores del candidato)
//   ← izquierda   NO COMPARTIR
//
// Se puede deslizar con la mano (la cámara de ../OjoGestos, como en el
// prototipo ReelsPrueba), arrastrando el reel con el mouse o con las flechas
// (o A y D). No hay tiempo: cada reel espera a que se decida. Al final se cuenta cuántos se decidieron bien y la
// credibilidad sube o baja.
//
// Los reels se arman con los dibujos del juego (personas, carros, pisos...),
// igual que en el prototipo, y se escriben en data/reels/reels_dia7.txt, así
// se pueden cambiar sin tocar el código. Van en una cola (ArrayDeque): se
// muestra el de adelante y, al decidirlo, se saca y sigue el siguiente.

final int REEL_W = 108, REEL_H = 192;           // el lienzo de un reel (vertical, como un celular)
final int DURACION_SALIDA_REEL = 7000;          // la respuesta se queda hasta que el jugador siga (o 7 s)
final int DURACION_INTRO_REELS = 4200;
final int SEGUIDORES_INICIALES = 48000;
final int R_INTRO = 0, R_VIENDO = 1, R_SALIENDO = 2, R_FIN = 3;

class ReelDia {
    String id, autor = "", texto = "", leyenda = "", contacto = "";
    String siAcierta = "", siFalla = "";
    boolean compartir;                     // lo responsable: compartirlo (true) o no (false)
    boolean bulo, odio;                    // para la huella del final (Creditos.pde)
    int megusta;
    color fondo = #333333;
    float horizonte = -1;
    String piso = null;
    String imagen = null;                  // un dibujo que llena todo el reel (data/reels/)
    ArrayList<float[]> bloques = new ArrayList<float[]>();
    ArrayList<Object[]> objetos = new ArrayList<Object[]>();     // imagen, x, y, escala
    ArrayList<Object[]> actores = new ArrayList<Object[]>();     // sprite, x, y, escala, animación
    ArrayList<Object[]> letreros = new ArrayList<Object[]>();    // x, y, tamaño, fondo, letra, texto
    ArrayList<String> mensajes = new ArrayList<String>();
    ArrayList<String[]> comentarios = new ArrayList<String[]>();
}

boolean reelsActivos = false;
int turnoReels = -1;                       // el día en que ya se jugó la misión
boolean reelsTerminados = false;
java.util.ArrayDeque<ReelDia> colaReels = new java.util.ArrayDeque<ReelDia>();
ArrayList<ReelDia> todosLosReelsDia;
ReelDia reelActual, reelSaliente;
int estadoReels = R_INTRO;
int momentoEstadoReels, momentoReelActual;
int totalReels, numeroReel;
int aciertosReels, erroresReels, seguidoresReels;
int cambioSeguidores;
boolean ultimoAcierto, ultimoCompartido, ultimoSinDecidir;
float arrastreReel = 0;                    // cuánto se ha corrido el reel con el mouse
float inicioArrastre = -1;
float salidaDesde = 0;                     // dónde estaba el reel al decidirlo
HashMap<String, PImage> imagenesReels = new HashMap<String, PImage>();
float reelMarcoX, reelMarcoY, reelMarcoW, reelMarcoH;

boolean esDiaReels() {
    return partida != null && partida.getTurno() == Partida.TURNOS_TOTALES && !esRondaEspecial() && !partidaTerminada();
}

// Lo que dice Marta (Llamada.pde)
String[] frasesReels() {
    return new String[] {
        "Candidato, es el último día y toda la ciudad está mirando su cuenta.",
        "Lo que usted comparta hoy le llega a cuarenta y ocho mil personas.",
        "Le mando los reels que más se están moviendo. A la derecha, lo que vale la pena compartir. A la izquierda, lo que no. Decida rápido."
    };
}

// ---------------------------------------------------------------------------
// Empezar y terminar

// Al colgar Marta (Llamada.pde)
void empezarMisionReels() {
    if (turnoReels == partida.getTurno()) {
        return;
    }
    turnoReels = partida.getTurno();
    if (todosLosReelsDia == null) {
        todosLosReelsDia = cargarReelsDia("reels/reels_dia7.txt");
    }
    colaReels.clear();
    colaReels.addAll(todosLosReelsDia);
    totalReels = colaReels.size();
    numeroReel = 0;
    aciertosReels = 0;
    erroresReels = 0;
    seguidoresReels = SEGUIDORES_INICIALES;
    reelActual = null;
    reelSaliente = null;
    arrastreReel = 0;
    inicioArrastre = -1;
    reelsTerminados = false;
    reelsActivos = true;
    cambiarEstadoReels(R_INTRO);
    abrirOjoReels();
}

void cambiarEstadoReels(int e) {
    estadoReels = e;
    momentoEstadoReels = millis();
}

void siguienteReelDia() {
    reelSaliente = reelActual;
    reelActual = colaReels.poll();
    arrastreReel = 0;
    inicioArrastre = -1;
    if (reelActual == null) {
        cambiarEstadoReels(R_FIN);
        return;
    }
    numeroReel++;
    momentoReelActual = millis();
    cambiarEstadoReels(R_VIENDO);
}

// El jugador decidió (o se acabó el tiempo: sinDecidir)
// Con la respuesta en pantalla, cualquier gesto pasa al siguiente reel
// (después de un momento, para que no se salte sin querer).
boolean avanzarRespuestaReel() {
    if (estadoReels == R_SALIENDO && millis() - momentoEstadoReels > 900) {
        siguienteReelDia();
        return true;
    }
    return false;
}

void decidirReel(boolean compartir, boolean sinDecidir) {
    if (avanzarRespuestaReel()) {
        return;
    }
    if (estadoReels != R_VIENDO || reelActual == null) {
        return;
    }
    ultimoCompartido = compartir;
    ultimoSinDecidir = sinDecidir;
    ultimoAcierto = !sinDecidir && compartir == reelActual.compartir;
    if (sinDecidir) {
        cambioSeguidores = 0;
    } else if (ultimoAcierto) {
        aciertosReels++;
        cambioSeguidores = compartir ? 1200 : 300;
        sonidos.tocarExito();
    } else {
        erroresReels++;
        cambioSeguidores = compartir ? -2500 : -600;
        sonidos.tocarFallo();
    }
    if (compartir && !sinDecidir) {
        partida.sumarAlcance(seguidoresReels / 4);
        partida.anotarReelCompartido(reelActual.bulo, reelActual.odio);
    }
    seguidoresReels = max(0, seguidoresReels + cambioSeguidores);
    salidaDesde = arrastreReel;
    cambiarEstadoReels(R_SALIENDO);
}

// Al cerrar el resumen: la credibilidad cambia según cómo le fue
void terminarMisionReels() {
    int cambio = aciertosReels * 2 - erroresReels * 3;
    partida.cambiarCredibilidad(cambio);
    reelsActivos = false;
    reelsTerminados = true;
    cerrarOjoReels();
    avisar("Credibilidad " + (cambio >= 0 ? "+" : "") + cambio + " por los reels. Ya puedes terminar el día.");
}

boolean reelsHechosHoy() {
    return reelsTerminados && turnoReels == partida.getTurno();
}

void reiniciarMisionReels() {
    reelsActivos = false;
    reelsTerminados = false;
    turnoReels = -1;
    cerrarOjoReels();
}

// ---------------------------------------------------------------------------
// Cada cuadro

void dibujarMisionReels() {
    leerOjoReels();
    background(#0b0d14);
    float celda = max(2, round(height / 360.0));
    reelMarcoH = height * 0.78;
    reelMarcoW = reelMarcoH * REEL_W / REEL_H;
    reelMarcoX = width / 2 - reelMarcoW / 2;
    reelMarcoY = height * 0.1;
    int t = millis() - momentoEstadoReels;

    if (estadoReels == R_INTRO) {
        dibujarIntroReels(celda, t);
        if (t > DURACION_INTRO_REELS) {
            siguienteReelDia();
        }
    } else if (estadoReels == R_FIN) {
        dibujarFinReels(celda);
    } else {
        dibujarFeedReels(celda, t);
        if (estadoReels == R_SALIENDO && t > DURACION_SALIDA_REEL) {
            siguienteReelDia();
        }
    }
    dibujarCamaraOjoReels(celda);
}

void dibujarIntroReels(float celda, int t) {
    float y = height * 0.2;
    textoPixel("CIVITAS · REELS", width / 2, y, celda * 4, #ffffff, CENTER, CENTER);
    y += celda * 34;
    textoPixel("TE SIGUEN " + milesReel(SEGUIDORES_INICIALES) + " PERSONAS: LO QUE COMPARTAS LES LLEGA A TODAS", width / 2, y, celda, #8a90a0, CENTER, CENTER);
    y += celda * 34;
    flechaReel(width / 2 - celda * 70, y, -1, celda * 1.4, #d83a34);
    textoPixel("NO COMPARTIR", width / 2 - celda * 84, y, celda * 1.5, #ffffff, RIGHT, CENTER);
    flechaReel(width / 2 + celda * 70, y, 1, celda * 1.4, #4aa84a);
    textoPixel("COMPARTIR", width / 2 + celda * 84, y, celda * 1.5, #ffffff, LEFT, CENTER);
    y += celda * 30;
    textoPixel("DESLIZA LA MANO, ARRASTRA EL REEL CON EL MOUSE O USA LAS FLECHAS", width / 2, y, celda, #d8dce6, CENTER, CENTER);
    y += celda * 14;
    textoPixel(totalReels + " REELS: PIÉNSALO ANTES DE DESLIZAR", width / 2, y, celda, #d8dce6, CENTER, CENTER);
    y += celda * 36;
    int quedan = max(1, ceil((DURACION_INTRO_REELS - t) / 1000.0));
    textoPixel(str(quedan), width / 2, y, celda * 5, #f2c14e, CENTER, CENTER);
}

void dibujarFeedReels(float celda, int t) {
    // el reel que sale vuela hacia el lado que se eligió; el nuevo sube desde abajo
    float subida = 0;
    if (estadoReels == R_VIENDO) {
        float a = constrain((millis() - momentoReelActual) / 300.0, 0, 1);
        subida = (1 - (1 - pow(1 - a, 3))) * reelMarcoH;
    }
    float dx = arrastreReel;
    float giro = 0;
    if (estadoReels == R_SALIENDO) {
        float a = constrain(t / 380.0, 0, 1);
        float lado = ultimoSinDecidir ? 0 : (ultimoCompartido ? 1 : -1);
        dx = lerp(salidaDesde, lado * width * 0.6, a * a);
        if (ultimoSinDecidir) {
            subida = -a * a * reelMarcoH;   // sin decidir, se va hacia arriba
        }
    }
    giro = dx / width * 0.35;
    // el marco del celular
    noStroke();
    fill(#1a1e2a);
    rect(reelMarcoX - celda * 4, reelMarcoY - celda * 4, reelMarcoW + celda * 8, reelMarcoH + celda * 8, celda * 6);
    clip(reelMarcoX, reelMarcoY, reelMarcoW, reelMarcoH);
    fill(#05060a);
    rect(reelMarcoX, reelMarcoY, reelMarcoW, reelMarcoH);
    if (reelActual != null && !(estadoReels == R_SALIENDO && t > 380)) {
        pushMatrix();
        translate(reelMarcoX + reelMarcoW / 2 + dx, reelMarcoY + reelMarcoH + subida);
        rotate(giro);
        dibujarReelDia(reelActual, -reelMarcoW / 2, -reelMarcoH, celda);
        popMatrix();
    }
    noClip();

    // a los lados: qué hace cada gesto (se ilumina hacia donde se arrastra)
    float cy = reelMarcoY + reelMarcoH / 2;
    float tira = constrain(arrastreReel / (reelMarcoW * 0.3), -1, 1);
    color cIzq = lerpColor(#5a2a2a, #d83a34, max(0.35, -tira));
    color cDer = lerpColor(#2a4a2a, #4aa84a, max(0.35, tira));
    float gx = reelMarcoX - celda * 22;
    flechaReel(gx, cy, -1, celda * 1.6, cIzq);
    textoPixel("NO COMPARTIR", gx - celda * 14, cy, celda * 1.5, cIzq, RIGHT, CENTER);
    float dxF = reelMarcoX + reelMarcoW + celda * 22;
    flechaReel(dxF, cy, 1, celda * 1.6, cDer);
    textoPixel("COMPARTIR", dxF + celda * 14, cy, celda * 1.5, cDer, LEFT, CENTER);

    // arriba: cuál va y los seguidores; abajo: el tiempo que queda
    textoPixel("REEL " + numeroReel + " DE " + totalReels, width / 2, reelMarcoY - celda * 14, celda, #8a90a0, CENTER, CENTER);
    float sx = width * 0.96, sy = height * 0.1;
    textoPixel("SEGUIDORES QUE CONFÍAN EN TI", sx, sy, celda, #8a90a0, RIGHT, CENTER);
    textoPixel(milesReel(seguidoresReels), sx, sy + celda * 16, celda * 2.5, #f2c14e, RIGHT, CENTER);
    if (estadoReels == R_SALIENDO) {
        dibujarRespuestaReel(celda, t);
    }
}

// Lo que pasó con la decisión, sobre el lugar del reel
void dibujarRespuestaReel(float celda, int t) {
    ReelDia r = reelActual;
    float a = constrain((t - 200) / 200.0, 0, 1);
    tint(255, 255 * a);
    color c = ultimoSinDecidir ? #8a90a0 : (ultimoAcierto ? #4aa84a : #d83a34);
    String titulo = ultimoSinDecidir ? "SE TE PASÓ" : (ultimoAcierto ? "¡BIEN!" : (ultimoCompartido ? "NO DEBISTE COMPARTIRLO" : "ESE SÍ VALÍA LA PENA"));
    float ancho = reelMarcoW - celda * 16;
    float y = reelMarcoY + reelMarcoH * 0.3;
    y = lineasCentradasReel(titulo, y, celda * 2, ancho, c);
    y += celda * 10;
    String texto = ultimoSinDecidir ? "NO DECIDISTE A TIEMPO: EL REEL SIGUIÓ CIRCULANDO SIN TI." : (ultimoAcierto ? r.siAcierta : r.siFalla);
    y = lineasCentradasReel(texto.toUpperCase(), y, celda, ancho, #ffffff);
    if (t > 900 && (millis() / 500) % 2 == 0) {
        textoPixel("CLIC O DESLIZA PARA SEGUIR", width / 2, reelMarcoY + reelMarcoH - celda * 12, celda, #8a90a0, CENTER, CENTER);
    }
    if (cambioSeguidores != 0) {
        y += celda * 10;
        textoPixel((cambioSeguidores > 0 ? "+" : "") + milesReel(cambioSeguidores) + " SEGUIDORES", width / 2, y, celda * 1.2, cambioSeguidores > 0 ? #4aa84a : #d83a34, CENTER, CENTER);
    }
    noTint();
}

void dibujarFinReels(float celda) {
    float y = height * 0.22;
    textoPixel("DECIDISTE BIEN " + aciertosReels + " DE " + totalReels, width / 2, y, celda * 3, aciertosReels * 2 >= totalReels ? #4aa84a : #d83a34, CENTER, CENTER);
    y += celda * 30;
    textoPixel("TE SIGUEN " + milesReel(seguidoresReels) + " PERSONAS", width / 2, y, celda * 1.5, #f2c14e, CENTER, CENTER);
    y += celda * 24;
    int cambio = aciertosReels * 2 - erroresReels * 3;
    textoPixel("CREDIBILIDAD " + (cambio >= 0 ? "+" : "") + cambio, width / 2, y, celda * 1.5, cambio >= 0 ? #4aa84a : #d83a34, CENTER, CENTER);
    y += celda * 30;
    String leccion = erroresReels == 0
        ? "CON MUCHOS SEGUIDORES, CADA COSA QUE COMPARTES PESA MÁS. LO HICISTE BIEN."
        : "CON MUCHOS SEGUIDORES, UN ERROR SE MULTIPLICA: ANTES DE COMPARTIR, PREGUNTA DE DÓNDE SALIÓ.";
    parrafoPixel(leccion, width / 2 - width * 0.3, y, celda, width * 0.6, #d8dce6, 3);
    if ((millis() / 500) % 2 == 0) {
        textoPixel("CLIC O ESPACIO PARA VOLVER A LA OFICINA", width / 2, height * 0.85, celda, #8a90a0, CENTER, CENTER);
    }
}

// ---------------------------------------------------------------------------
// Un reel (el lienzo de 108 x 192, como en el prototipo)

PImage imagenReel(String nombre) {
    if (!nombre.endsWith(".png")) {
        nombre += ".png";
    }
    if (!imagenesReels.containsKey(nombre)) {
        imagenesReels.put(nombre, new java.io.File(dataPath(nombre)).exists() ? loadImage(nombre) : null);
    }
    return imagenesReels.get(nombre);
}

void dibujarReelDia(ReelDia r, float x, float y, float celda) {
    float s = reelMarcoW / REEL_W;
    float tr = (millis() - momentoReelActual) / 1000.0;
    noStroke();
    fill(r.fondo);
    rect(x, y, reelMarcoW, reelMarcoH);
    if (r.contacto.length() > 0) {
        dibujarChatReel(r, x, y, celda, tr);
        return;
    }
    dibujarEscenaReel(r, x, y, s, tr);
    // abajo: quién lo publicó y qué dice
    fill(0, 150);
    rect(x, y + reelMarcoH * 0.78, reelMarcoW, reelMarcoH * 0.22);
    float px = x + celda * 6, py = y + reelMarcoH * 0.8;
    textoPixel(r.autor, px, py, celda, #ffffff, LEFT, TOP);
    parrafoPixel(r.texto, px, py + celda * 12, celda, reelMarcoW * 0.8, #d8dce6, 2);
    if (r.megusta > 0) {
        textoPixel("ME GUSTA " + milesReel(r.megusta), px, py + celda * 36, celda, #f2c14e, LEFT, TOP);
    }
    // un comentario a la vez, como pasan en vivo
    if (r.comentarios.size() > 0) {
        String[] c = r.comentarios.get(int(tr / 2.0) % r.comentarios.size());
        fill(0, 130);
        rect(x + celda * 4, y + reelMarcoH * 0.7, reelMarcoW - celda * 8, celda * 12, celda * 2);
        textoPixel(recortarReel(c[0] + ": " + c[1], floor((reelMarcoW - celda * 14) / celda / 6)), x + celda * 7, y + reelMarcoH * 0.7 + celda * 6, celda, #ffffff, LEFT, CENTER);
    }
}

void dibujarEscenaReel(ReelDia r, float x, float y, float s, float t) {
    if (r.imagen != null) {
        PImage fondo = imagenReel(r.imagen);
        if (fondo != null) {
            image(fondo, x, y, REEL_W * s, REEL_H * s);
        }
    }
    if (r.horizonte >= 0 && r.piso != null) {
        PImage piso = imagenReel(r.piso);
        if (piso != null) {
            for (int fila = 0; fila * 8 < REEL_H - r.horizonte + 16; fila++) {
                for (int col = -1; col * 32 < REEL_W + 32; col++) {
                    float px = col * 32 + (fila % 2) * 16 - 16;
                    float py = r.horizonte + fila * 8 - 8;
                    image(piso, x + px * s, y + py * s, 32 * s, 16 * s);
                }
            }
        }
    }
    for (float[] b : r.bloques) {
        fill((int) b[4]);
        rect(x + b[0] * s, y + b[1] * s, b[2] * s, b[3] * s);
    }
    // objetos y personas, de atrás para adelante
    ArrayList<Object[]> orden = new ArrayList<Object[]>();
    orden.addAll(r.objetos);
    orden.addAll(r.actores);
    java.util.Collections.sort(orden, new java.util.Comparator<Object[]>() {
        public int compare(Object[] a, Object[] b) {
            return Float.compare((Float) a[2], (Float) b[2]);
        }
    });
    for (Object[] e : orden) {
        float ex = (Float) e[1], ey = (Float) e[2], esc = (Float) e[3];
        boolean esActor = e.length > 4;
        String anim = esActor ? (String) e[4] : "";
        int cuadro = 0;
        float salto = 0, giro = 0;
        if (anim.equals("baila")) {
            cuadro = int(t * 6) % 3;
            salto = abs(sin(t * 6)) * 3;
        } else if (anim.equals("rie")) {
            salto = abs(sin(t * 9 + ex)) * 1.5;
        } else if (anim.equals("cae")) {
            giro = constrain((t - 1.0) / 0.3, 0, 1) * HALF_PI;
        } else if (anim.equals("camina")) {
            cuadro = int(t * 5) % 3;
        }
        PImage img = imagenReel(esActor ? (String) e[0] + "_" + cuadro : (String) e[0]);
        if (img == null) {
            continue;
        }
        float w = img.width * esc, h = img.height * esc;
        pushMatrix();
        translate(x + ex * s, y + (ey - salto) * s);
        rotate(giro);
        image(img, -w / 2 * s, -h * s, w * s, h * s);
        popMatrix();
    }
    for (Object[] l : r.letreros) {
        float lx = (Float) l[0], ly = (Float) l[1], tam = (Float) l[2];
        float c = max(1, round(s * tam * 0.6));
        String texto = (String) l[5];
        float w = medirPixel(texto) * c + c * 6, h = c * 11;
        fill((Integer) l[3]);
        rect(x + lx * s - w / 2, y + ly * s - h / 2, w, h);
        textoPixel(texto, x + lx * s, y + ly * s, c, (Integer) l[4], CENTER, CENTER);
    }
    if (r.leyenda.length() > 0) {
        float c = max(1, round(s * 0.55));
        ArrayList<String> filas = partirPixel(r.leyenda, floor((REEL_W * s - c * 16) / c));
        float ly = y + 14 * s;
        for (String f : filas) {
            float w = medirPixel(f) * c + c * 6;
            fill(255);
            rect(x + REEL_W * s / 2 - w / 2, ly - c * 5, w, c * 10);
            textoPixel(f, x + REEL_W * s / 2, ly, c, #111111, CENTER, CENTER);
            ly += c * 11;
        }
    }
}

// Un reel que es la captura de un chat
void dibujarChatReel(ReelDia r, float x, float y, float celda, float t) {
    fill(#1d2230);
    rect(x, y, reelMarcoW, reelMarcoH);
    fill(#2c3a55);
    rect(x, y, reelMarcoW, celda * 22);
    fill(#5a6070);
    ellipse(x + celda * 12, y + celda * 11, celda * 12, celda * 12);
    textoPixel(r.contacto, x + celda * 22, y + celda * 11, celda, #ffffff, LEFT, CENTER);
    float py = y + celda * 32;
    int visibles = min(r.mensajes.size(), 1 + int(t / 0.5));
    for (int k = 0; k < visibles; k++) {
        ArrayList<String> filas = partirPixel(r.mensajes.get(k), floor(reelMarcoW * 0.7 / celda));
        float h = filas.size() * celda * 11 + celda * 6;
        float w = 0;
        for (String f : filas) {
            w = max(w, medirPixel(f) * celda);
        }
        fill(#3a4054);
        rect(x + celda * 6, py, w + celda * 10, h, celda * 3);
        for (int i = 0; i < filas.size(); i++) {
            textoPixel(filas.get(i), x + celda * 11, py + celda * 4 + i * celda * 11, celda, #ffffff, LEFT, TOP);
        }
        py += h + celda * 6;
    }
    // abajo, quién lo subió
    fill(0, 150);
    rect(x, y + reelMarcoH * 0.84, reelMarcoW, reelMarcoH * 0.16);
    textoPixel(r.autor, x + celda * 6, y + reelMarcoH * 0.86, celda, #ffffff, LEFT, TOP);
    parrafoPixel(r.texto, x + celda * 6, y + reelMarcoH * 0.86 + celda * 12, celda, reelMarcoW * 0.85, #d8dce6, 2);
}

// Un texto partido en líneas que no se salen de <ancho>, cada una centrada.
// Devuelve dónde quedó la siguiente línea.
float lineasCentradasReel(String texto, float y, float celda, float ancho, color c) {
    for (String f : partirPixel(texto, floor(ancho / celda))) {
        textoPixel(f, width / 2, y, celda, c, CENTER, CENTER);
        y += celda * 11;
    }
    return y;
}

String milesReel(int n) {
    int a = abs(n);
    String s = a >= 1000 ? nf(a / 1000.0, 0, 1).replace(".0", "").replace('.', ',') + " MIL" : str(a);
    return (n < 0 ? "-" : "") + s;
}

String recortarReel(String t, int max) {
    return t.length() <= max ? t : t.substring(0, max(0, max - 3)) + "...";
}

void flechaReel(float x, float y, int lado, float celda, color c) {
    fill(c);
    noStroke();
    float l = celda * 6;
    rect(x - (lado > 0 ? l : 0), y - celda * 1.2, l, celda * 2.4);
    triangle(x, y - celda * 5, x, y + celda * 5, x + celda * 6 * lado, y);
}

// ---------------------------------------------------------------------------
// Entrada (AlcaldeDigitalNuevo.pde reparte aquí mientras reelsActivos)

void teclaReels() {
    if (key == ESC) {
        key = 0;
    }
    if (estadoReels == R_FIN) {
        if (key == ' ' || key == ENTER || key == RETURN) {
            terminarMisionReels();
        }
        return;
    }
    if ((key == ' ' || key == ENTER || key == RETURN) && avanzarRespuestaReel()) {
        return;
    }
    if ((key == CODED && keyCode == LEFT) || key == 'a' || key == 'A') {
        decidirReel(false, false);
    } else if ((key == CODED && keyCode == RIGHT) || key == 'd' || key == 'D') {
        decidirReel(true, false);
    }
}

void clicReels() {
    if (estadoReels == R_FIN) {
        if (millis() - momentoEstadoReels > 800) {
            terminarMisionReels();
        }
        return;
    }
    if (avanzarRespuestaReel()) {
        return;
    }
    if (estadoReels == R_VIENDO) {
        inicioArrastre = mouseX;
    }
}

void mouseDragged() {
    if (reelsActivos && estadoReels == R_VIENDO && inicioArrastre >= 0) {
        arrastreReel = mouseX - inicioArrastre;
    }
}

void mouseReleased() {
    if (!reelsActivos || inicioArrastre < 0) {
        return;
    }
    inicioArrastre = -1;
    if (estadoReels == R_VIENDO && abs(arrastreReel) > reelMarcoW * 0.3) {
        decidirReel(arrastreReel > 0, false);
    } else {
        arrastreReel = 0;   // no alcanzó: vuelve a su lugar
    }
}

// ---------------------------------------------------------------------------
// La mano: el ojo de gestos (../OjoGestos), el mismo del prototipo de los
// reels. Es un programa en Python que ve la mano por la cámara y manda líneas
// de texto por la red local ("FLECHA IZQUIERDA", "MANO x y"...). Si no está
// instalado, la misión se juega igual con el mouse o el teclado.

final int PUERTO_OJO_REELS = 5205;
Server servidorOjoReels;
Client clienteOjoReels;
Process procesoOjoReels;
StringBuilder bufferOjoReels = new StringBuilder();
PImage camaraOjoReels;
float manoReelX = -1, manoReelY = -1;
String estadoOjoReels = "";
boolean ganchoOjoReels = false;

void abrirOjoReels() {
    if (servidorOjoReels != null) {
        return;
    }
    java.io.File carpeta = new java.io.File(sketchPath("../OjoGestos"));
    java.io.File exe = new java.io.File(carpeta, "dist/ojo_gestos/ojo_gestos.exe");
    java.io.File py = new java.io.File(carpeta, ".venv/Scripts/pythonw.exe");
    if (!py.exists()) {
        py = new java.io.File(carpeta, ".venv/bin/python");
    }
    ArrayList<String> cmd = new ArrayList<String>();
    if (exe.exists()) {
        cmd.add(exe.getAbsolutePath());
    } else if (py.exists()) {
        cmd.add(py.getAbsolutePath());
        cmd.add(new java.io.File(carpeta, "ojo_gestos.py").getAbsolutePath());
    } else {
        estadoOjoReels = "";   // sin cámara: no se dice nada, se juega con el mouse
        return;
    }
    try {
        servidorOjoReels = new Server(this, PUERTO_OJO_REELS);
        cmd.add("--puerto");
        cmd.add("" + PUERTO_OJO_REELS);
        ProcessBuilder pb = new ProcessBuilder(cmd);
        pb.directory(carpeta);
        pb.redirectErrorStream(true);
        pb.redirectOutput(new java.io.File(carpeta, "ojo_registro.txt"));
        procesoOjoReels = pb.start();
        estadoOjoReels = "ABRIENDO LA CÁMARA...";
        if (!ganchoOjoReels) {
            ganchoOjoReels = true;
            // si el juego se cierra en plena misión, el ojo también
            Runtime.getRuntime().addShutdownHook(new Thread(new Runnable() {
                public void run() {
                    if (procesoOjoReels != null) {
                        procesoOjoReels.destroy();
                    }
                }
            }));
        }
    } catch (Exception e) {
        estadoOjoReels = "";
        servidorOjoReels = null;
    }
}

void leerOjoReels() {
    if (servidorOjoReels == null) {
        return;
    }
    Client c = servidorOjoReels.available();
    while (c != null) {
        if (clienteOjoReels == null) {
            clienteOjoReels = c;
            estadoOjoReels = "CÁMARA CONECTADA";
            clienteOjoReels.write("VIDEO 1\n");
        }
        String s = c.readString();
        if (s != null) {
            bufferOjoReels.append(s);
        }
        c = servidorOjoReels.available();
    }
    int i;
    while ((i = bufferOjoReels.indexOf("\n")) >= 0) {
        String linea = trim(bufferOjoReels.substring(0, i));
        bufferOjoReels.delete(0, i + 1);
        recibirOjoReels(linea);
    }
    if (clienteOjoReels != null && !clienteOjoReels.active()) {
        clienteOjoReels = null;
        estadoOjoReels = "LA CÁMARA SE CERRÓ: SIGUE CON EL MOUSE";
    }
}

void recibirOjoReels(String linea) {
    if (linea.startsWith("IMG ")) {
        try {
            byte[] jpg = java.util.Base64.getDecoder().decode(linea.substring(4));
            camaraOjoReels = new PImage(javax.imageio.ImageIO.read(new java.io.ByteArrayInputStream(jpg)));
        } catch (Exception e) {
            // una imagen dañada se ignora
        }
        return;
    }
    String[] p = splitTokens(linea);
    if (p.length == 0) {
        return;
    }
    if (p[0].equals("MANO")) {
        manoReelX = p.length >= 3 ? float(p[1]) : -1;
        manoReelY = p.length >= 3 ? float(p[2]) : -1;
    } else if (p[0].equals("FLECHA") && p.length > 1) {
        if (p[1].equals("IZQUIERDA")) {
            decidirReel(false, false);
        } else if (p[1].equals("DERECHA")) {
            decidirReel(true, false);
        }
    } else if (p[0].equals("LANZAR") && estadoReels == R_FIN) {
        terminarMisionReels();
    }
}

// La cámara pequeña, abajo a la izquierda, para ver que el ojo sí ve la mano
void dibujarCamaraOjoReels(float celda) {
    if (servidorOjoReels == null) {
        return;
    }
    float w = width * 0.14, h = w * 0.75;
    float x = width * 0.02, y = height - h - height * 0.03;
    if (camaraOjoReels != null) {
        image(camaraOjoReels, x, y, w, h);
        if (manoReelX >= 0) {
            noStroke();
            fill(#f2c14e);
            ellipse(x + manoReelX * w, y + manoReelY * h, celda * 6, celda * 6);
        }
    } else {
        noStroke();
        fill(#1d2230);
        rect(x, y, w, h, 6);
    }
    textoPixel(estadoOjoReels, x, y - celda * 8, celda, clienteOjoReels != null ? #4aa84a : #8a90a0, LEFT, CENTER);
}

void cerrarOjoReels() {
    if (clienteOjoReels != null) {
        clienteOjoReels.write("ADIOS\n");
    }
    if (procesoOjoReels != null) {
        procesoOjoReels.destroy();
    }
    if (servidorOjoReels != null) {
        servidorOjoReels.stop();
    }
    procesoOjoReels = null;
    servidorOjoReels = null;
    clienteOjoReels = null;
    camaraOjoReels = null;
}

// ---------------------------------------------------------------------------
// Leer data/reels/reels_dia7.txt (el formato está explicado al principio del archivo)

ArrayList<ReelDia> cargarReelsDia(String archivo) {
    ArrayList<ReelDia> lista = new ArrayList<ReelDia>();
    String[] lineas = loadStrings(archivo);
    if (lineas == null) {
        println("MisionReels: no se encontró " + archivo);
        return lista;
    }
    ReelDia r = null;
    for (String linea : lineas) {
        linea = trim(linea);
        if (linea.length() == 0 || linea.startsWith("#")) {
            continue;
        }
        String[] t = splitTokens(linea, " ");
        String o = t[0];
        if (o.equals("reel")) {
            r = new ReelDia();
            r.id = t[1];
            continue;
        }
        if (r == null) {
            continue;
        }
        String resto = restoReel(linea, 1);
        if (o.equals("fin")) {
            lista.add(r);
            r = null;
        } else if (o.equals("compartir")) r.compartir = t[1].equals("si");
        else if (o.equals("tipo")) {
            r.bulo = resto.contains("bulo");
            r.odio = resto.contains("odio");
        }
        else if (o.equals("autor")) r.autor = resto;
        else if (o.equals("texto")) r.texto = resto;
        else if (o.equals("megusta")) r.megusta = int(t[1]);
        else if (o.equals("fondo")) r.fondo = unhex("FF" + t[1].substring(1));
        else if (o.equals("horizonte")) r.horizonte = float(t[1]);
        else if (o.equals("piso")) r.piso = t[1];
        else if (o.equals("imagen")) r.imagen = t[1];
        else if (o.equals("bloque")) r.bloques.add(new float[] {float(t[1]), float(t[2]), float(t[3]), float(t[4]), unhex("FF" + t[5].substring(1))});
        else if (o.equals("objeto")) r.objetos.add(new Object[] {t[1], float(t[2]), float(t[3]), float(t[4])});
        else if (o.equals("actor")) r.actores.add(new Object[] {t[1], float(t[2]), float(t[3]), float(t[4]), t.length > 5 ? t[5] : "quieto"});
        else if (o.equals("letrero")) r.letreros.add(new Object[] {float(t[1]), float(t[2]), float(t[3]), unhex("FF" + t[4].substring(1)), unhex("FF" + t[5].substring(1)), restoReel(linea, 6)});
        else if (o.equals("leyenda")) r.leyenda = resto;
        else if (o.equals("contacto")) r.contacto = resto;
        else if (o.equals("mensaje")) r.mensajes.add(resto);
        else if (o.equals("comentario")) r.comentarios.add(split(resto, '|'));
        else if (o.equals("si_acierta")) r.siAcierta = resto;
        else if (o.equals("si_falla")) r.siFalla = resto;
    }
    return lista;
}

String restoReel(String linea, int n) {
    String[] t = splitTokens(linea, " ");
    StringBuilder sb = new StringBuilder();
    for (int i = n; i < t.length; i++) {
        if (sb.length() > 0) {
            sb.append(' ');
        }
        sb.append(t[i]);
    }
    return sb.toString();
}
