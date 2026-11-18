// Bienvenida — la videollamada de Valeria en la TV, antes de la primera
// llamada de Marta.
//
// Al llegar a la oficina por primera vez en una campaña
// (sola o en red, a cada jugador en su PC) la TV se enciende sola con una videollamada: la cámara se acerca, se ve a
// Valeria (su dibujo de 20 x 20 agrandado, moviendo la boca y parpadeando)
// y ella explica en pocas frases el impacto de lo que se publica, con su voz y subtítulos abajo.
// Se puede saltar con el botón SALTAR o con Esc. Al terminar, la cámara
// vuelve a la oficina y el teléfono empieza a sonar como siempre.
//
// La voz son frases fijas: se graban una vez con Azure (la clave de
// valeria.txt) y quedan en data/voz/, así que después suenan sin internet.
// Se piden al arrancar el juego (precargarBienvenida). Si no hay voz, los
// subtítulos avanzan solos según lo largo de cada frase.

String[] FRASES_BIENVENIDA = {
    "¡Hola, candidato! Soy Valeria, tu estratega digital. Esta campaña se gana en Civitas, la red social de la ciudad.",
    "Antes de publicar, revisa tres pistas: quién lo publicó, qué dicen los comentarios y si ataca a un grupo de personas.",
    "Si compartes algo falso o un mensaje de odio, la gente lo nota: pierdes credibilidad y lo que publiques llegará a menos gente.",
    "Después de cada jugada verás un informe de impacto: cuánta gente lo vio, qué comentaron y qué era en verdad la noticia.",
    "¡Mucha suerte, candidato!"
};

boolean bienvenidaPendiente = true;   // vuelve a true con cada campaña nueva
boolean videollamadaActiva = false;
int momentoProgramadoBienvenida = -1;
int momentoBienvenida;                // cuando empezó la videollamada
int fraseBienvenida;                  // la que se está diciendo
int momentoFrase;                     // cuando empezó esa frase
boolean fraseConVoz;
Clip[] vocesBienvenida;
Clip vozBienvenida;
PImage[] caraValeriaTV;               // 0 boca cerrada, 1 boca abierta, 2 ojos cerrados
PImage imgTVApagado;

final int ESPERA_BIENVENIDA = 1400;   // en la oficina, antes de que la TV se encienda
final int INICIO_FRASES = 900;        // ya con la TV en grande, antes de hablar
final int PAUSA_ENTRE_FRASES = 350;

// Las tres caras salen del dibujo de 20 x 20 (data/valeria.png): la boca
// son los dos pixeles rosados de la fila 11; abierta, se oscurecen y bajan
// una fila. Los ojos son los pixeles (7, 7) y (12, 7).
void cargarBienvenida() {
    imgTVApagado = loadImage("tv/televisor_apagado.jpg");
    // Si el equipo de diseño ya dibujó el retrato grande de Valeria
    // (data/retratos/valeria_base.png, valeria_habla.png y
    // valeria_parpadeo.png, ver docs/guia-personajes.md), se usa ese.
    if (new java.io.File(dataPath("retratos/valeria_base.png")).exists()) {
        String[] nombres = {"base", "habla", "parpadeo"};
        caraValeriaTV = new PImage[3];
        for (int i = 0; i < 3; i++) {
            String archivo = "retratos/valeria_" + nombres[i] + ".png";
            caraValeriaTV[i] = new java.io.File(dataPath(archivo)).exists() ? loadImage(archivo) : loadImage("retratos/valeria_base.png");
        }
        return;
    }
    PImage base = loadImage("valeria.png");
    caraValeriaTV = new PImage[3];
    for (int i = 0; i < 3; i++) {
        caraValeriaTV[i] = base.get();
        caraValeriaTV[i].loadPixels();
    }
    PImage abierta = caraValeriaTV[1];
    color labio = abierta.get(9, 11);
    abierta.set(9, 11, color(60, 16, 30));
    abierta.set(10, 11, color(60, 16, 30));
    abierta.set(9, 12, labio);
    abierta.set(10, 12, labio);
    PImage cerrados = caraValeriaTV[2];
    color sombra = cerrados.get(9, 13);
    cerrados.set(7, 7, sombra);
    cerrados.set(12, 7, sombra);
    for (PImage p : caraValeriaTV) {
        p.updatePixels();
    }
}

// Al arrancar: graba en data/voz/ las frases que falten (si hay clave e internet)
void precargarBienvenida() {
    if (mision == null || !mision.valeriaConVoz()) {
        return;
    }
    Thread h = new Thread(new Runnable() {
        public void run() {
            for (String f : FRASES_BIENVENIDA) {
                java.io.File g = new java.io.File(dataPath("voz/" + mision.vozAzure + "_" + Integer.toHexString(f.hashCode()) + ".wav"));
                if (g.exists()) {
                    continue;
                }
                try {
                    mision.vozDeAzure(f, mision.vozAzure).close();
                } catch (Exception e) {
                    return;   // sin internet: se intenta la próxima vez
                }
            }
        }
    });
    h.setDaemon(true);
    h.start();
}

// Al entrar a la oficina (cerrarPortada): si toca, se programa la videollamada
void programarBienvenida() {
    if (bienvenidaPendiente) {   // también en red: a cada jugador le sale al entrar
        momentoProgramadoBienvenida = millis() + ESPERA_BIENVENIDA;
    }
}

// Cada cuadro (desde actualizarLlamada)
void actualizarBienvenida() {
    if (momentoProgramadoBienvenida > 0 && millis() >= momentoProgramadoBienvenida) {
        if (estado == MENU && !camaraBajando && !camaraSubiendo && !mostrarPortada && !saliendo) {
            momentoProgramadoBienvenida = -1;
            empezarBienvenida();
        } else {
            momentoProgramadoBienvenida = millis() + 300;   // espera a que la oficina esté a la vista
        }
    }
    if (!videollamadaActiva) {
        return;
    }
    int t = millis() - momentoBienvenida - DURACION_ZOOM_TV - INICIO_FRASES;
    if (t < 0) {
        return;
    }
    if (fraseBienvenida < 0) {
        empezarFrase(0);
        return;
    }
    if (fraseTerminada()) {
        if (fraseBienvenida + 1 >= FRASES_BIENVENIDA.length) {
            if (millis() - momentoFrase > duracionFrase() + 1200) {
                terminarBienvenida();
            }
        } else {
            empezarFrase(fraseBienvenida + 1);
        }
    }
}

void empezarBienvenida() {
    videollamadaActiva = true;
    bienvenidaPendiente = false;
    fraseBienvenida = -1;
    momentoBienvenida = millis();
    vocesBienvenida = new Clip[FRASES_BIENVENIDA.length];
    // las voces (ya grabadas, o pidiéndolas si hay internet) se cargan en otro hilo
    if (mision != null && mision.valeriaConVoz()) {
        final Clip[] destino = vocesBienvenida;
        Thread h = new Thread(new Runnable() {
            public void run() {
                for (int i = 0; i < FRASES_BIENVENIDA.length; i++) {
                    try {
                        destino[i] = mision.vozDeAzure(FRASES_BIENVENIDA[i], mision.vozAzure);
                    } catch (Exception e) {
                        return;
                    }
                }
            }
        });
        h.setDaemon(true);
        h.start();
    }
    irA(MAPA);
    acercarTV();
}

void empezarFrase(int i) {
    fraseBienvenida = i;
    momentoFrase = millis();
    vozBienvenida = vocesBienvenida[i];
    fraseConVoz = vozBienvenida != null;
    if (fraseConVoz) {
        vozBienvenida.setFramePosition(0);
        vozBienvenida.start();
    }
}

// Lo que dura una frase sin voz (para los subtítulos solos)
int duracionFrase() {
    if (fraseConVoz) {
        return (int) (vozBienvenida.getMicrosecondLength() / 1000);
    }
    return 900 + FRASES_BIENVENIDA[fraseBienvenida].length() * 55;
}

boolean fraseTerminada() {
    int t = millis() - momentoFrase;
    if (!fraseConVoz && vocesBienvenida[fraseBienvenida] != null && t < 400) {
        // la voz llegó justo al empezar: se usa
        empezarFrase(fraseBienvenida);
        return false;
    }
    return t >= duracionFrase() + PAUSA_ENTRE_FRASES;
}

boolean valeriaHablando() {
    if (fraseBienvenida < 0) {
        return false;
    }
    if (fraseConVoz) {
        return vozBienvenida.isRunning();
    }
    return millis() - momentoFrase < duracionFrase();
}

void terminarBienvenida() {
    if (vozBienvenida != null) {
        vozBienvenida.stop();
    }
    videollamadaActiva = false;
    alejarTV();
    // el teléfono cuenta su espera desde ahora
    momentoFaseLlamada = millis();
}

// ---------------------------------------------------------------------------
// Dibujo: la TV con la videollamada (dentro del zoom del televisor)
// ---------------------------------------------------------------------------

// La pantalla dentro del dibujo de la TV apagada (en % de la cámara)
final float PANT_IZQ = 5.6, PANT_ARRIBA = 7.6, PANT_ANCHO = 88.8, PANT_ALTO = 83.6;

void dibujarVideollamada(float visible) {
    tint(255, 255 * visible);
    image(imgTVApagado, camX, camY, camAncho, camAlto);
    noTint();
    if (visible < 0.9) {
        return;
    }
    float x = pcX(PANT_IZQ), y = pcY(PANT_ARRIBA), w = pcAncho(PANT_ANCHO), h = pcAlto(PANT_ALTO);
    int t = millis() - momentoBienvenida - DURACION_ZOOM_TV;
    // se enciende: una raya blanca que se abre
    float abre = constrain(t / 350.0, 0, 1);
    clip(x, y + h / 2 * (1 - abre), w, h * abre);
    dibujarCuartoValeria(x, y, w, h);
    dibujarCaraValeria(x, y, w, h);
    dibujarMarcoVideollamada(x, y, w, h, t);
    dibujarSubtitulos(x, y, w, h);
    noClip();
    if (abre < 1) {
        noStroke();
        fill(255, 255 * (1 - abre));
        rect(x, y + h / 2 * (1 - abre), w, max(2, h * abre));
    }
    // un brillo suave de vidrio encima
    noStroke();
    fill(255, 10);
    quad(x, y, x + w * 0.35, y, x + w * 0.1, y + h * 0.55, x, y + h * 0.55);
    dibujarBotonSaltar(x, y, w, h);
}

// El fondo de la videollamada: la oficina de Valeria en pixeles grandes
void dibujarCuartoValeria(float x, float y, float w, float h) {
    float u = h / 45;   // un "pixel" del cuarto
    noStroke();
    for (int fila = 0; fila < 46; fila++) {
        fill(lerpColor(#2b2350, #463a7a, fila / 45.0));
        rect(x, y + fila * u, w, u + 1);
    }
    // una ventana de noche con la ciudad y un afiche de campaña
    fill(#1a1430);
    rect(x + w * 0.08, y + h * 0.12, w * 0.22, h * 0.38);
    fill(#0f2a55);
    rect(x + w * 0.08 + u, y + h * 0.12 + u, w * 0.22 - 2 * u, h * 0.38 - 2 * u);
    randomSeed(7);
    for (int i = 0; i < 9; i++) {
        float bx = x + w * 0.08 + u + i * (w * 0.22 - 2 * u) / 9;
        float alto = h * random(0.08, 0.22);
        fill(#1b1b3a);
        rect(bx, y + h * 0.5 - u - alto, (w * 0.22 - 2 * u) / 9 - 1, alto);
        fill(#ffd27a);
        if (random(1) < 0.7) {
            rect(bx + u * 0.6, y + h * 0.5 - u - alto * 0.7, u * 0.6, u * 0.6);
        }
    }
    randomSeed(millis());
    fill(#f2eee4);
    rect(x + w * 0.72, y + h * 0.24, w * 0.18, h * 0.3);
    fill(#3b7fd0);
    rect(x + w * 0.72 + u, y + h * 0.24 + u, w * 0.18 - 2 * u, h * 0.1);
    textoPixel("VOTA", x + w * 0.81, y + h * 0.335, max(1, round(u * 0.32)), #f2eee4, CENTER, CENTER);
    textoPixel("CIVITAS", x + w * 0.81, y + h * 0.43, max(1, round(u * 0.22)), #2b2350, CENTER, CENTER);
    // el escritorio
    fill(#5b3a2a);
    rect(x, y + h * 0.84, w, h * 0.16);
    fill(#7a4f38);
    rect(x, y + h * 0.84, w, u);
}

void dibujarCaraValeria(float x, float y, float w, float h) {
    // boca: se abre y se cierra mientras habla; parpadea cada tanto
    int cara = 0;
    if (valeriaHablando()) {
        int paso = millis() / 115;
        cara = (paso * 7 + paso / 3) % 5 < 2 ? 0 : 1;
    }
    if (millis() % 3600 < 130) {
        cara = 2;
    }
    PImage img = caraValeriaTV[cara];
    float alto = h * 0.78;
    float ancho = alto * img.width / (float) img.height;   // el retrato grande puede no ser cuadrado
    float respira = sin(millis() / 900.0) * h * 0.006;
    image(img, x + w / 2 - ancho / 2, y + h - alto + respira, ancho, alto);
}

// Arriba: quién llama, EN VIVO y el tiempo de la llamada
void dibujarMarcoVideollamada(float x, float y, float w, float h, int t) {
    float celda = max(1, round(h / 190));
    float alto = 15 * celda;
    noStroke();
    fill(0, 140);
    rect(x, y, w, alto);
    textoPixel("VALERIA · ESTRATEGIA DIGITAL", x + 6 * celda, y + alto / 2, celda, #ffffff, LEFT, CENTER);
    int s = max(0, t / 1000);
    String reloj = nf(s / 60, 2) + ":" + nf(s % 60, 2);
    float xReloj = x + w - 6 * celda;
    textoPixel(reloj, xReloj, y + alto / 2, celda, #ffffff, RIGHT, CENTER);
    float xVivo = xReloj - (medirPixel(reloj) + 8) * celda;
    textoPixel("EN VIVO", xVivo, y + alto / 2, celda, #ff6b6b, RIGHT, CENTER);
    boolean punto = (millis() / 600) % 2 == 0;
    fill(punto ? #ff3b3b : #7a1c1c);
    rect(xVivo - (medirPixel("EN VIVO") + 9) * celda, y + alto / 2 - 3 * celda, 6 * celda, 6 * celda);
}

// Abajo: la frase actual, como subtítulos de video
void dibujarSubtitulos(float x, float y, float w, float h) {
    if (fraseBienvenida < 0) {
        return;
    }
    float celda = max(1, round(h / 185));
    String frase = FRASES_BIENVENIDA[fraseBienvenida].toUpperCase();
    ArrayList<String> lineas = partirPixel(frase, floor(w * 0.86 / celda));
    float paso = 11 * celda;
    float altoCaja = lineas.size() * paso + 6 * celda;
    float yCaja = y + h - altoCaja - 2 * celda;
    float anchoMax = 0;
    for (String l : lineas) {
        anchoMax = max(anchoMax, medirPixel(l) * celda);
    }
    noStroke();
    fill(0, 185);
    rect(x + w / 2 - anchoMax / 2 - 6 * celda, yCaja, anchoMax + 12 * celda, altoCaja);
    for (int i = 0; i < lineas.size(); i++) {
        textoPixel(lineas.get(i), x + w / 2, yCaja + 3 * celda + paso * i + paso / 2, celda, #fff3b0, CENTER, CENTER);
    }
}

float[] cajaSaltar(float x, float y, float w, float h) {
    float celda = max(1, round(h / 170));
    float bw = (medirPixel("SALTAR >") + 10) * celda, bh = 14 * celda;
    return new float[] {x + w - bw - 6 * celda, y + 21 * celda, bw, bh};
}

boolean mouseEnSaltar() {
    float[] c = cajaSaltar(pcX(PANT_IZQ), pcY(PANT_ARRIBA), pcAncho(PANT_ANCHO), pcAlto(PANT_ALTO));
    return mouseX >= c[0] && mouseX <= c[0] + c[2] && mouseY >= c[1] && mouseY <= c[1] + c[3];
}

void dibujarBotonSaltar(float x, float y, float w, float h) {
    float[] c = cajaSaltar(x, y, w, h);
    boolean encima = mouseEnSaltar();
    if (encima) {
        pedirCursorMano();
    }
    noStroke();
    fill(encima ? #e8584d : color(0, 160));
    rect(c[0], c[1], c[2], c[3]);
    textoPixel("SALTAR >", c[0] + c[2] / 2, c[1] + c[3] / 2, max(1, round(h / 170)), #ffffff, CENTER, CENTER);
}
