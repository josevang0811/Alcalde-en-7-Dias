// Televisor — el noticiero que se ve al hacer clic en la TV de la oficina
// (como en el prototipo Oficina_1 del equipo de diseño).
//
// Al acercarse la cámara se ve la pantalla de inicio (NEWS con el globo).
// Después de un momento, con un salto de imagen, empieza el noticiero, que
// dura 20 segundos:
//   - El presentador muestra en su globo primero el mapa de la partida (los
//     8 barrios como post-its del color de quien los tiene, unidos por las
//     calles) y después la gráfica de apoyo de los cuatro candidatos.
//   - A la derecha pasan 4 reels de la red social, uno cada 5 segundos
//     (subiendo, como al deslizar el dedo): el primero es el del barrio
//     donde se jugó en el turno; los otros, al azar.
//   - Abajo, la cinta de titulares y el @ de quien publicó la noticia.
// Al terminar vuelve la pantalla de inicio y la cámara se aleja sola.
//
// Los dibujos llenan la cámara de la oficina, así que todo lo de encima se
// ubica en porcentajes de la cámara (pcX, pcY), igual que en el prototipo.
// Todos los textos van en la letra pixel (Diseno.pde).

final int ESPERA_INICIO_TV = 1500;    // la pantalla de inicio, ya con la TV en grande
final int SALTO_TV = 300;             // el salto de imagen al empezar
final int DURACION_NOTICIERO = 20000;
final int MS_POR_REEL = 5000;
final int SALTO_FIN_TV = 340;
final int ESPERA_FIN_TV = 1800;       // la pantalla de inicio otra vez, antes de alejarse

PImage imgNoticieroTV, imgInicioTV, imgMapaTV, imgGraficaTV, imgVolumenReel;
PImage[] reelsBarrio = new PImage[8];
PImage reelReportero, reelDisturbios, reelProtesta, reelVotos;
PImage[] todosLosReels;
// post-its: [color][variante]; colores en el orden de COLORES_POSTIT
final String[] COLORES_POSTIT = {"amarillo", "azul", "rojo", "naranja", "verde"};
PImage[][] postits = new PImage[5][8];

// Los colores de los candidatos (los del mapa del equipo): asiento 0 azul,
// 1 rojo, 2 naranja y 3 verde (los mismos del mundo abierto).
final color[] COLOR_ASIENTO = {#3b7fd0, #d83a34, #e08a2c, #4aa84a};

void cargarTelevisor() {
    imgNoticieroTV = loadImage("tv/noticiero.jpg");
    imgInicioTV = loadImage("tv/inicio_noticiero.jpg");
    imgMapaTV = loadImage("tv/mapa_tv.png");
    imgGraficaTV = loadImage("tv/grafica_base.png");
    imgVolumenReel = loadImage("tv/reel_volumen.png");
    // en el orden de los barrios de GrafoCiudad
    String[] barrios = {"centro", "universidad", "colina", "puerto", "mercado", "sur", "industrial", "norte"};
    for (int z = 0; z < 8; z++) {
        reelsBarrio[z] = loadImage("tv/reel_" + barrios[z] + ".jpg");
    }
    reelReportero = loadImage("tv/reel_reportero.jpg");
    reelDisturbios = loadImage("tv/reel_disturbios.jpg");
    reelProtesta = loadImage("tv/reel_protesta.jpg");
    reelVotos = loadImage("tv/reel_votos.jpg");
    todosLosReels = new PImage[] {reelsBarrio[0], reelsBarrio[1], reelsBarrio[2], reelsBarrio[3], reelsBarrio[4],
        reelsBarrio[5], reelsBarrio[6], reelsBarrio[7], reelReportero, reelDisturbios, reelProtesta, reelVotos};
    for (int c = 0; c < 5; c++) {
        for (int k = 0; k < 8; k++) {
            postits[c][k] = loadImage("tv/postit_" + COLORES_POSTIT[c] + "_" + k + ".png");
        }
    }
}

// Cuánto va del noticiero (ms): negativo mientras se ve la pantalla de
// inicio al llegar. Solo tiene sentido con la TV acercándose o en grande.
int tiempoNoticiero() {
    return millis() - momentoZoomTV - DURACION_ZOOM_TV - ESPERA_INICIO_TV;
}

// Todo el noticiero, con opacidad "visible" (0 a 1) mientras se acerca la cámara
void dibujarNoticiero(float visible) {
    if (videollamadaActiva) {
        dibujarVideollamada(visible);   // la bienvenida de Valeria (Bienvenida.pde)
        return;
    }
    if (zoomTVHasta == 0) {
        // alejándose: solo la pantalla de inicio
        dibujarPantallaCompleta(imgInicioTV, visible, 0, 1);
        return;
    }
    int t = tiempoNoticiero();
    if (t < 0 && reelsDelNoticiero == null) {
        elegirReels();
    }
    int fin = SALTO_TV + DURACION_NOTICIERO;
    if (t >= fin + SALTO_FIN_TV + ESPERA_FIN_TV) {
        alejarTV();   // terminó: la cámara vuelve sola a la oficina
    }
    boolean conNoticiero = t >= 0 && t < fin + SALTO_FIN_TV;
    if (conNoticiero) {
        dibujarPantallaCompleta(imgNoticieroTV, visible, 0, 1);
        int dentro = t - SALTO_TV;
        if (visible > 0.9 && dentro > -SALTO_TV) {
            dibujarReelsTV(max(0, dentro));
            dibujarNubesTV(dentro);
            dibujarFranjaTitulares(pcX(17.663), pcY(88.456), pcAncho(77.057), pcAlto(5.355), 32, true);
            dibujarArrobaTV();
        }
    }
    // la pantalla de inicio encima: antes de empezar, en el salto (se va
    // corriendo y brillando) y al final (vuelve)
    if (t < SALTO_TV) {
        float u = t < 0 ? 0 : t / (float) SALTO_TV;
        dibujarPantallaCompleta(imgInicioTV, visible * (1 - u), saltoImagen(u), 1 + 0.7 * sin(PI * u));
    } else if (t >= fin) {
        float u = constrain((t - fin) / (float) SALTO_FIN_TV, 0, 1);
        dibujarPantallaCompleta(imgInicioTV, visible * u, saltoImagen(1 - u), 1 + 0.6 * sin(PI * u));
    }
    if (zoomTV < 0.01) {
        reelsDelNoticiero = null;
    }
}

// El corrimiento del salto de imagen (en fracción del ancho)
float saltoImagen(float u) {
    return u < 0.55 ? -0.014 * u / 0.55 : 0.01 * (1 - (u - 0.55) / 0.45);
}

// Una de las pantallas completas del televisor, corrida "dx" (fracción del
// ancho) y con "brillo" (1 normal)
void dibujarPantallaCompleta(PImage img, float alfa, float dx, float brillo) {
    if (alfa <= 0.002) {
        return;
    }
    tint(constrain(255 * brillo, 0, 255), 255 * alfa);
    image(img, camX + dx * camAncho, camY, camAncho, camAlto);
    noTint();
    if (brillo > 1.01) {
        noStroke();
        fill(255, 255 * alfa * (brillo - 1) * 0.35);
        rect(camX, camY, camAncho, camAlto);
    }
}

// ---------------------------------------------------------------------------
// Los reels: 4, uno cada 5 s, subiendo como al deslizar
// ---------------------------------------------------------------------------

PImage[] reelsDelNoticiero;

void elegirReels() {
    reelsDelNoticiero = new PImage[4];
    reelsDelNoticiero[0] = reelDelTurno();
    ArrayList<PImage> resto = new ArrayList<PImage>();
    for (PImage r : todosLosReels) {
        if (r != reelsDelNoticiero[0]) {
            resto.add(r);
        }
    }
    java.util.Collections.shuffle(resto);
    for (int k = 1; k < 4; k++) {
        reelsDelNoticiero[k] = resto.get(k - 1);
    }
}

// El reel del turno: el del barrio donde se jugó; en una ronda de minijuego
// sin jugada todavía, uno de gente en la calle; si no, el del reportero.
PImage reelDelTurno() {
    int z = partida.getJugadaZona(partida.getTurno());
    if (z < 0) {
        z = partida.getJugadaZona(partida.getTurno() - 1);
    }
    if (z >= 0 && z < reelsBarrio.length) {
        return reelsBarrio[z];
    }
    int mini = minijuegoDeRonda();
    if (mini == MINI_LIVES) {
        return reelDisturbios;
    } else if (mini == MINI_VOLANTES || mini == MINI_GENTE) {
        return reelProtesta;
    }
    return partida.getTurno() >= Partida.TURNOS_TOTALES ? reelVotos : reelReportero;
}

void dibujarReelsTV(int t) {
    if (reelsDelNoticiero == null) {
        elegirReels();
    }
    float x = pcX(63.043), y = pcY(9.318), w = pcAncho(25.582), h = pcAlto(75.869);
    noStroke();
    fill(#141824);
    rect(x, y, w, h);
    int actual = min(3, t / MS_POR_REEL);
    float u = 1;
    if (actual > 0) {
        u = curvaReel(constrain((t - actual * MS_POR_REEL) / 550.0, 0, 1));
    }
    clip(x, y, w, h);
    if (actual > 0 && u < 1) {
        dibujarReelEn(reelsDelNoticiero[actual - 1], x, y - u * h, w, h);
    }
    dibujarReelEn(reelsDelNoticiero[actual], x, y + (1 - u) * h, w, h);
    noClip();
    // el icono del volumen queda encima de los reels
    float lado = pcAncho(4.2);
    image(imgVolumenReel, pcX(86.4) - lado / 2, pcY(81.4) - lado / 2, lado, lado);
}

// cubic-bezier(.45,0,.2,1) aproximada
float curvaReel(float x) {
    return x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2;
}

// Llena el cuadro sin deformar (como background-size: cover)
void dibujarReelEn(PImage r, float x, float y, float w, float h) {
    float esc = max(w / r.width, h / r.height);
    float rw = r.width * esc, rh = r.height * esc;
    image(r, x + (w - rw) / 2, y + (h - rh) / 2, rw, rh);
}

// ---------------------------------------------------------------------------
// El globo del presentador: el mapa (primeros 10 s) y la gráfica (10 a 20 s)
// ---------------------------------------------------------------------------

void dibujarNubesTV(int t) {
    int mitad = DURACION_NOTICIERO / 2;
    if (t < 0) {
        return;
    }
    if (t < mitad + 240) {
        float[] e = t < mitad ? entradaNube(t - 120) : salidaNube(t - mitad);
        if (e[0] > 0) {
            dibujarMapaTV(e[0], e[1]);
        }
    }
    if (t >= mitad && t < DURACION_NOTICIERO + 240) {
        float[] e = t < DURACION_NOTICIERO ? entradaNube(t - mitad - 120) : salidaNube(t - DURACION_NOTICIERO);
        if (e[0] > 0) {
            dibujarGraficaTV(e[0], e[1], t - mitad);
        }
    }
}

// {opacidad, escala} al aparecer (rebota un poquito) y al irse
float[] entradaNube(int t) {
    float u = constrain(t / 620.0, 0, 1);
    if (u < 0.55) {
        float v = u / 0.55;
        return new float[] {v, 0.6 + 0.47 * v};
    }
    float v = (u - 0.55) / 0.45;
    return new float[] {1, 1.07 - 0.07 * v};
}

float[] salidaNube(int t) {
    float u = constrain(t / 240.0, 0, 1);
    return new float[] {1 - u, 1 - 0.3 * u};
}

// Escala alrededor del centro de un rectángulo (en porcentajes de la cámara)
void escalarNube(float izq, float arriba, float ancho, float alto, float escala) {
    float cx = pcX(izq + ancho / 2), cy = pcY(arriba + alto / 2);
    translate(cx, cy);
    scale(escala);
    translate(-cx, -cy);
}

// El mapa de la partida: el mapa del equipo con un post-it por barrio, del
// color del candidato que lo tiene (amarillo si es de nadie), unidos por
// las calles del grafo.
void dibujarMapaTV(float alfa, float escala) {
    // llena el globo del presentador
    float izq = 26.6, ancho = 26.2;
    float altoImg = ancho * camAncho / camAlto * imgMapaTV.height / imgMapaTV.width;
    float arriba = 26.4 - altoImg / 2;
    pushMatrix();
    escalarNube(izq, arriba, ancho, altoImg, escala);
    tint(255, 255 * alfa);
    float x0 = pcX(izq), y0 = pcY(arriba), w = pcAncho(ancho), h = pcAlto(altoImg);
    image(imgMapaTV, x0, y0, w, h);
    GrafoCiudad ciudad = partida.getCiudad();
    float mx = x0 + w * 0.12, my = y0 + h * 0.16, mw = w * 0.76, mh = h * 0.68;
    stroke(30, 22, 18, 235 * alfa);
    strokeWeight(max(2, w / 150));
    for (int a = 0; a < ciudad.cantidad(); a++) {
        for (int b = a + 1; b < ciudad.cantidad(); b++) {
            if (ciudad.hayCalle(a, b)) {
                line(mx + ciudad.getX(a) * mw, my + ciudad.getY(a) * mh, mx + ciudad.getX(b) * mw, my + ciudad.getY(b) * mh);
            }
        }
    }
    noStroke();
    float lado = w * 0.085;
    int jugado = partida.getJugadaZona(partida.getTurno());
    for (int z = 0; z < ciudad.cantidad(); z++) {
        PImage p = postits[colorPostit(z)][z % 8];
        float cx = mx + ciudad.getX(z) * mw, cy = my + ciudad.getY(z) * mh;
        float salto = z == jugado ? abs(sin(millis() / 260.0)) * lado * 0.25 : 0;
        image(p, cx - lado / 2, cy - lado * p.height / p.width / 2 - salto, lado, lado * p.height / p.width);
    }
    noTint();
    popMatrix();
}

// El color del post-it de un barrio: el de quien lo tiene
int colorPostit(int z) {
    int dueno = duenoDeBarrio(z);
    if (dueno < 0) {
        return 0;   // amarillo: de nadie
    }
    // COLORES_POSTIT: amarillo, azul, rojo, naranja, verde
    return dueno + 1;
}

// El asiento que tiene el barrio (50 de apoyo o más), o -1. En red se
// miran las tablas de todos; si no, solo se sabe lo del jugador.
int duenoDeBarrio(int z) {
    if (enRed() && campanaEnRed) {
        int mejor = -1;
        int valor = Partida.UMBRAL_CONQUISTA - 1;
        for (int a = 0; a < 4; a++) {
            int v = a == miAsientoRed ? partida.getApoyo(z) : (humanoAsiento[a] && tieneTabla[a] ? apoyoAsiento[a][z] : 0);
            if (v > valor) {
                valor = v;
                mejor = a;
            }
        }
        return mejor;
    }
    return partida.esPropio(z) ? 0 : -1;
}

// La gráfica de apoyo: las barras crecen sobre el dibujo del equipo (los
// ejes y las cuatro siluetas con su corbata de color).
final int[] ASIENTO_BARRA = {0, 1, 3, 2};               // azul, rojo, verde, naranja
final float[] X_BARRA = {94.5, 229, 361, 493.5};        // centros en el dibujo (615 x 360)

void dibujarGraficaTV(float alfa, float escala, int t) {
    float izq = 23.874, arriba = 14.951, ancho = 23.874, alto = 25.035;
    pushMatrix();
    escalarNube(izq, arriba, ancho, alto, escala);
    float x0 = pcX(izq), y0 = pcY(arriba), w = pcAncho(ancho);
    float k = w / imgGraficaTV.width;   // pixeles de pantalla por pixel del dibujo
    tint(255, 255 * alfa);
    image(imgGraficaTV, x0, y0, w, pcAlto(alto));
    noTint();
    int maximo = 120;
    for (int a = 0; a < 4; a++) {
        maximo = max(maximo, apoyoDeAsiento(a));
    }
    float crece = facilSalida(constrain((t - 200) / 900.0, 0, 1));
    for (int i = 0; i < 4; i++) {
        int asiento = ASIENTO_BARRA[i];
        int v = apoyoDeAsiento(asiento);
        float hb = 190 * v / (float) maximo * crece;
        float bx = x0 + (X_BARRA[i] - 41) * k, by = y0 + (232 - hb) * k, bw = 82 * k, bh = hb * k;
        noStroke();
        fill(#1a1414, 255 * alfa);
        rect(bx - 3 * k, by - 3 * k, bw + 6 * k, bh + 3 * k);
        fill(COLOR_ASIENTO[asiento], 255 * alfa);
        rect(bx, by, bw, bh);
        // rayitas en diagonal, como en el dibujo
        if (bh > 2) {
            clip(bx, by, bw, bh);
            stroke(255, 255, 255, 60 * alfa);
            strokeWeight(max(1, 3 * k));
            for (float d = 0; d < bh + bw; d += 14 * k) {
                line(bx, by + bh - d, bx + bw, by + bh - d - bw);
            }
            noClip();
            noStroke();
        }
        tint(255, 255 * alfa);
        float celda = max(1, round(k * 4));
        textoPixel(str(v), bx + bw / 2, by - 6 * k, celda, 1, #fff7e6, #1a1414, 0, 0, false, CENTER, BOTTOM);
        noTint();
    }
    popMatrix();
}

// El apoyo total de cada asiento. El jugador, el real. En red, los demás
// humanos salen de la tabla del anfitrión (Red.pde). Los que juega el
// computador: lo mismo que empezó el jugador, más lo que ganan en los
// minijuegos y una campaña propia que suma un poco cada turno (siempre lo
// mismo para el mismo turno, así se ve igual en todos los PCs).
int apoyoDeAsiento(int asiento) {
    if (enRed() && campanaEnRed) {
        if (asiento == miAsientoRed) {
            return partida.apoyoTotal();
        }
        if (humanoAsiento[asiento] && tieneTabla[asiento]) {
            return votosDe(asiento);
        }
    } else if (asiento == 0) {
        return partida.apoyoTotal();
    }
    int s = Partida.UMBRAL_CONQUISTA + premioRival[asiento];
    for (int t = 1; t < partida.getTurno(); t++) {
        s += (t * 37 + asiento * 13) % 11 + 2;
    }
    return max(0, s);
}

String nombreDeAsiento(int asiento) {
    if (enRed() && campanaEnRed && humanoAsiento[asiento]) {
        return nombreAsiento[asiento];
    }
    if (!enRed() && asiento == 0) {
        return partida.getNombreCandidato();
    }
    String[] rivales = {"Tú", "Morales", "Rincón", "Pérez"};
    return rivales[asiento];
}

// El @ de quien publicó la noticia, en el recuadro blanco de abajo a la izquierda
void dibujarArrobaTV() {
    String autor = partida.getNoticiaDelTurno() != null ? partida.getNoticiaDelTurno().getAutor() : "@civitas";
    float ancho = pcAncho(7.2);
    float celda = max(1, round(camAncho / 700.0));
    while (medirPixel(autor) * celda > ancho && celda > 0.6) {
        celda *= 0.85;
    }
    textoPixel(autor, pcX(12.9), pcY(91.2), celda, 1, #141010, 0, 0, 0, false, CENTER, CENTER);
}
