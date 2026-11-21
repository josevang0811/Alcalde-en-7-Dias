// Cinematica — escenas cortas contadas plano por plano (el prólogo, y las
// que vengan después).
//
// Cada escena es un archivo de texto en data/cinematicas/ que el equipo de
// diseño puede editar sin tocar código. Al empezar, el archivo se lee y sus
// planos se meten en una COLA: se muestra el de adelante y, cuando se le
// acaba el tiempo, se saca y pasa el siguiente. La escena termina cuando la
// cola queda vacía (o el jugador la salta).
//
// Los dibujos se piensan en un lienzo de pixel art (320x180 si la escena no
// dice otra cosa) que se agranda a la pantalla. La cámara se mueve sobre ese
// lienzo: centro (x, y) y zoom, de un punto a otro a lo largo del plano, con
// una curva suave. Encima se pueden poner luces que laten, lluvia, destellos
// y sacudidas, y debajo un sonido de ambiente que se repite.
//
// Órdenes del archivo (una por línea; # es comentario):
//   lienzo <ancho> <alto>            tamaño del lienzo de toda la escena (va antes del primer plano)
//   plano <ms>                       empieza un plano que dura <ms>
//   fondo <#rrggbb>                  color detrás de todo
//   capa <imagen> <x> <y> [desde] [vibra|fundir]   imagen en el lienzo; aparece a los <desde> ms
//   ajustar <imagen> [desde] [fundir]               imagen que llena todo el lienzo
//   deslizar <imagen> <x> <y> <escala> <paso> <cada> <mueve> [desde]
//                                    imagen que sube <paso> pixeles cada <cada> ms (tarda <mueve>
//                                    ms en subir), como un feed que alguien va bajando con el dedo.
//                                    <escala> la achica: el feed del celular se dibuja a 4 por pixel
//   camara <x0> <y0> <z0> <x1> <y1> <z1>    centro y zoom al empezar y al terminar el plano
//   globo <x> <y> <desde> <texto>    notificación de Civitas sobre el lienzo
//   subtitulo <desde> <quien>|<texto>       línea de diálogo abajo, en la barra negra
//   rotulo <texto>                   texto grande en el centro (p. ej. "25 AÑOS DESPUÉS")
//   sonido <desde> <archivo.wav>     suena una vez a los <desde> ms
//   fundido <entrada> <salida>       ms de fundido a negro al empezar y al terminar
//   temblor <fuerza>                 la cámara tiembla un poco (en pixeles del lienzo)
//   sacudida <desde> <fuerza>        un golpe corto de cámara (el celular que vibra)
//   luz <x> <y> <radio> <#rrggbb> <fuerza>   un brillo que late (la pantalla del celular, una lámpara)
//   destello <desde>                 las luces del plano se encienden de golpe y bajan (una notificación)
//   lluvia <cantidad> [x0 y0 x1 y1]  gotas cayendo; con el rectángulo, solo ahí (una ventana)
//   ambiente <archivo.wav|nada>      sonido de fondo que se repite hasta que otro plano lo cambie

int lienzoAncho = 320;
int lienzoAlto = 180;

class PlanoCine {
    int duracion = 3000;
    color fondo = #0a0a10;
    ArrayList<String[]> capas = new ArrayList<String[]>();      // imagen, x, y, desde, vibra
    ArrayList<String[]> globos = new ArrayList<String[]>();     // x, y, desde, texto
    ArrayList<String[]> subtitulos = new ArrayList<String[]>(); // desde, quien, texto
    ArrayList<String[]> sonidos = new ArrayList<String[]>();    // desde, archivo
    float[] camara = null;
    ArrayList<float[]> luces = new ArrayList<float[]>();      // x, y, radio, color, fuerza
    ArrayList<Integer> destellos = new ArrayList<Integer>();
    ArrayList<float[]> sacudidas = new ArrayList<float[]>();  // desde, fuerza
    float[] lluvia = null;                                    // cantidad, x0, y0, x1, y1
    String ambiente = null;
    String rotulo = null;
    int fundidoEntrada = 300;
    int fundidoSalida = 300;
    float temblor = 0;
}

java.util.ArrayDeque<PlanoCine> colaCine = new java.util.ArrayDeque<PlanoCine>();
PlanoCine planoCine = null;
int momentoPlano;
boolean[] sonidosHechos;
String trasCinematica = "";          // qué hacer al terminar (lo lee terminarCinematica)
HashMap<String, PImage> imagenesCine = new HashMap<String, PImage>();
boolean prologoPendiente = true;     // el prólogo sale una sola vez por sesión

boolean cinematicaActiva() {
    return planoCine != null;
}

// Lee data/cinematicas/<nombre>.txt, arma la cola de planos y empieza.
void empezarCinematica(String nombre, String despues) {
    colaCine.clear();
    lienzoAncho = 320;
    lienzoAlto = 180;
    String[] lineas = loadStrings("cinematicas/" + nombre + ".txt");
    if (lineas == null) {
        println("Cinematica: no se encontró cinematicas/" + nombre + ".txt");
        trasCinematica = despues;
        terminarCinematica();
        return;
    }
    PlanoCine p = null;
    for (String linea : lineas) {
        linea = trim(linea);
        if (linea.length() == 0 || linea.startsWith("#")) {
            continue;
        }
        String[] t = splitTokens(linea, " ");
        String orden = t[0];
        if (orden.equals("lienzo")) {
            lienzoAncho = int(t[1]);
            lienzoAlto = int(t[2]);
        } else if (orden.equals("plano")) {
            p = new PlanoCine();
            p.duracion = int(t[1]);
            colaCine.add(p);
        } else if (p == null) {
            continue;
        } else if (orden.equals("fondo")) {
            p.fondo = unhex("FF" + t[1].replace("#", ""));
        } else if (orden.equals("capa")) {
            p.capas.add(new String[] {t[1], t[2], t[3], t.length > 4 ? t[4] : "0", t.length > 5 ? t[5] : ""});
        } else if (orden.equals("ajustar")) {
            p.capas.add(new String[] {t[1], "0", "0", t.length > 2 ? t[2] : "0", "ajustar", t.length > 3 ? t[3] : ""});
        } else if (orden.equals("deslizar")) {
            p.capas.add(new String[] {t[1], t[2], t[3], t.length > 8 ? t[8] : "0", "deslizar", "", t[4], t[5], t[6], t[7]});
        } else if (orden.equals("camara")) {
            p.camara = new float[6];
            for (int k = 0; k < 6; k++) {
                p.camara[k] = float(t[k + 1]);
            }
        } else if (orden.equals("globo")) {
            p.globos.add(new String[] {t[1], t[2], t[3], restoDe(linea, 4)});
        } else if (orden.equals("subtitulo")) {
            String[] partes = split(restoDe(linea, 2), '|');
            p.subtitulos.add(new String[] {t[1], partes.length > 1 ? trim(partes[0]) : "", trim(partes[partes.length - 1])});
        } else if (orden.equals("rotulo")) {
            p.rotulo = restoDe(linea, 1);
        } else if (orden.equals("sonido")) {
            p.sonidos.add(new String[] {t[1], t[2]});
        } else if (orden.equals("fundido")) {
            p.fundidoEntrada = int(t[1]);
            p.fundidoSalida = int(t[2]);
        } else if (orden.equals("temblor")) {
            p.temblor = float(t[1]);
        } else if (orden.equals("sacudida")) {
            p.sacudidas.add(new float[] {float(t[1]), float(t[2])});
        } else if (orden.equals("luz")) {
            p.luces.add(new float[] {float(t[1]), float(t[2]), float(t[3]), unhex("FF" + t[4].replace("#", "")), float(t[5])});
        } else if (orden.equals("destello")) {
            p.destellos.add(int(t[1]));
        } else if (orden.equals("lluvia")) {
            p.lluvia = t.length > 5 ? new float[] {float(t[1]), float(t[2]), float(t[3]), float(t[4]), float(t[5])}
                                    : new float[] {float(t[1]), 0, 0, -1, -1};
        } else if (orden.equals("ambiente")) {
            p.ambiente = t[1];
        }
    }
    trasCinematica = despues;
    siguientePlano();
}

// El texto de una línea desde la palabra n (para textos con espacios).
String restoDe(String linea, int n) {
    String[] t = splitTokens(linea, " ");
    String r = "";
    for (int k = n; k < t.length; k++) {
        r += (k > n ? " " : "") + t[k];
    }
    return r;
}

void siguientePlano() {
    planoCine = colaCine.poll();     // saca el de adelante (null si ya no hay)
    momentoPlano = millis();
    if (planoCine == null) {
        terminarCinematica();
        return;
    }
    sonidosHechos = new boolean[planoCine.sonidos.size()];
    if (planoCine.camara == null) {
        planoCine.camara = new float[] {lienzoAncho / 2.0, lienzoAlto / 2.0, 1, lienzoAncho / 2.0, lienzoAlto / 2.0, 1};
    }
    if (planoCine.ambiente != null) {
        cambiarAmbienteCine(planoCine.ambiente);
    }
    gotasCine = null;
}

void saltarCinematica() {
    colaCine.clear();
    planoCine = null;
    terminarCinematica();
}

void terminarCinematica() {
    planoCine = null;
    cambiarAmbienteCine("nada");
    String despues = trasCinematica;
    trasCinematica = "";
    if (despues.equals("portada")) {
        cerrarPortada();   // sigue la campaña como si no hubiera pasado nada
    }
}

PImage imagenCine(String archivo) {
    PImage img = imagenesCine.get(archivo);
    if (img == null && !imagenesCine.containsKey(archivo)) {
        img = new java.io.File(dataPath(archivo)).exists() ? loadImage(archivo) : null;
        imagenesCine.put(archivo, img);
    }
    return img;
}

// Suavizado de entrada y salida (como una cámara de verdad).
float curvaCine(float t) {
    t = constrain(t, 0, 1);
    return t * t * (3 - 2 * t);
}

void dibujarCinematica() {
    if (planoCine == null) {
        return;
    }
    PlanoCine p = planoCine;
    int t = millis() - momentoPlano;
    if (t >= p.duracion) {
        siguientePlano();
        if (planoCine == null) {
            return;
        }
        p = planoCine;
        t = 0;
    }
    for (int k = 0; k < p.sonidos.size(); k++) {
        if (!sonidosHechos[k] && t >= int(p.sonidos.get(k)[0])) {
            sonidosHechos[k] = true;
            sonarCine(p.sonidos.get(k)[1]);
        }
    }
    background(p.fondo);

    // La cámara: escala para que el lienzo de 320x180 llene la pantalla
    float avance = curvaCine(t / (float) p.duracion);
    float cx = lerp(p.camara[0], p.camara[3], avance);
    float cy = lerp(p.camara[1], p.camara[4], avance);
    float zoom = lerp(p.camara[2], p.camara[5], avance);
    if (p.temblor > 0) {
        cx += random(-p.temblor, p.temblor);
        cy += random(-p.temblor, p.temblor);
    }
    for (float[] sa : p.sacudidas) {
        float edad = t - sa[0];
        if (edad >= 0 && edad < 260) {
            float f = sa[1] * (1 - edad / 260.0);
            cx += random(-f, f);
            cy += random(-f, f);
        }
    }
    float escala = max(width / (float) lienzoAncho, height / (float) lienzoAlto) * zoom;
    pushMatrix();
    translate(width / 2.0 - cx * escala, height / 2.0 - cy * escala);
    scale(escala);
    for (String[] c : p.capas) {
        if (t < int(c[3])) {
            continue;
        }
        PImage img = imagenCine("cinematicas/" + c[0]);
        if (img == null) {
            img = imagenCine(c[0]);   // también se pueden usar dibujos del juego (data/...)
        }
        if (img == null) {
            continue;
        }
        boolean fundir = c[4].equals("fundir") || (c.length > 5 && c[5].equals("fundir"));
        if (fundir) {
            tint(255, 255 * constrain((t - int(c[3])) / 600.0, 0, 1));
        }
        if (c[4].equals("deslizar")) {
            dibujarDeslizarCine(img, c, t - int(c[3]));
        } else if (c[4].equals("ajustar")) {
            image(img, 0, 0, lienzoAncho, lienzoAlto);
        } else {
            float dx = c[4].equals("vibra") && (t / 60) % 2 == 0 ? 1 : 0;
            image(img, float(c[1]) + dx, float(c[2]));
        }
        noTint();
    }
    dibujarLucesCine(p, t);
    dibujarLluviaCine(p);
    for (String[] gl : p.globos) {
        if (t >= int(gl[2])) {
            dibujarGloboCine(float(gl[0]), float(gl[1]), gl[3], t - int(gl[2]));
        }
    }
    popMatrix();

    dibujarBarrasCine();
    // solo se ve el último subtítulo que ya empezó (uno reemplaza al anterior)
    String[] actual = null;
    for (String[] s : p.subtitulos) {
        if (t >= int(s[0])) {
            actual = s;
        }
    }
    if (actual != null) {
        dibujarSubtituloCine(actual[1], actual[2], t - int(actual[0]));
    }
    if (p.rotulo != null) {
        float a = constrain((t - 300) / 600.0, 0, 1);
        tint(255, 255 * a);   // el color va fijo y la transparencia con tint (los textos se guardan por color)
        String[] filas = split(p.rotulo, '|');   // con | se parte en varias líneas
        float celdaGrande = max(3, round(height / 150.0));
        float celdaChica = max(2, round(height / 300.0));
        float y = height / 2.0 - (filas.length - 1) * 8 * celdaChica;
        for (int k = 0; k < filas.length; k++) {
            float celda = k == 0 ? celdaGrande : celdaChica;
            if (k == 1) {
                y += 8 * celdaGrande;
            } else if (k > 1) {
                y += 12 * celdaChica;
            }
            textoPixel(trim(filas[k]), width / 2.0, y, celda, k == 0 ? color(235, 230, 220) : color(170, 170, 180), CENTER, CENTER);
        }
        noTint();
    }
    // fundidos a negro al entrar y al salir del plano
    float negro = 0;
    if (p.fundidoEntrada > 0 && t < p.fundidoEntrada) {
        negro = 1 - t / (float) p.fundidoEntrada;
    }
    if (p.fundidoSalida > 0 && t > p.duracion - p.fundidoSalida) {
        negro = max(negro, (t - (p.duracion - p.fundidoSalida)) / (float) p.fundidoSalida);
    }
    if (negro > 0) {
        noStroke();
        fill(0, 255 * constrain(negro, 0, 1));
        rect(0, 0, width, height);
    }
    textoPixel("ESPACIO: SALTAR", width - 24, height * 0.055, max(2, round(height / 360.0)), color(120, 120, 130), RIGHT, CENTER);   // arriba, en la barra negra
}

// Una imagen que sube de a pasos (el feed que Andrés va bajando)
void dibujarDeslizarCine(PImage img, String[] c, int edad) {
    float escala = float(c[6]);
    float paso = float(c[7]);
    int cada = int(c[8]);
    int mueve = int(c[9]);
    int pasos = max(0, round(img.height * escala / paso) - 1);   // no sube más allá del final
    int n = edad / cada;
    float subida;
    if (n == 0) {
        subida = 0;
    } else if (n > pasos) {
        subida = pasos;
    } else {
        subida = n - 1 + curvaCine((edad - n * cada) / (float) mueve);
    }
    image(img, float(c[1]), float(c[2]) - subida * paso, img.width * escala, img.height * escala);
}

// ---- Luces, lluvia y ambiente ----

PImage halo;   // un círculo blanco que se desvanece hacia el borde (se tiñe con el color de cada luz)

PImage imagenHalo() {
    if (halo == null) {
        int n = 128;
        halo = createImage(n, n, ARGB);
        halo.loadPixels();
        for (int y = 0; y < n; y++) {
            for (int x = 0; x < n; x++) {
                float d = dist(x, y, n / 2.0, n / 2.0) / (n / 2.0);
                float a = constrain(1 - d, 0, 1);
                halo.pixels[y * n + x] = color(255, 255, 255, 255 * a * a);
            }
        }
        halo.updatePixels();
    }
    return halo;
}

// Las luces laten despacio; un destello las sube de golpe y baja en medio segundo.
void dibujarLucesCine(PlanoCine p, int t) {
    if (p.luces.isEmpty()) {
        return;
    }
    float extra = 0;
    for (int d : p.destellos) {
        float edad = t - d;
        if (edad >= 0 && edad < 500) {
            extra = max(extra, 1 - edad / 500.0);
        }
    }
    blendMode(ADD);
    for (float[] l : p.luces) {
        color c = (int) l[3];
        float fuerza = l[4] * (0.85 + 0.15 * sin(t / 400.0)) + extra * 0.6;
        tint(red(c), green(c), blue(c), 255 * constrain(fuerza, 0, 1));
        image(imagenHalo(), l[0] - l[2], l[1] - l[2], l[2] * 2, l[2] * 2);
    }
    noTint();
    blendMode(BLEND);
}

float[][] gotasCine = null;

void dibujarLluviaCine(PlanoCine p) {
    if (p.lluvia == null) {
        return;
    }
    float x0 = p.lluvia[1], y0 = p.lluvia[2];
    float x1 = p.lluvia[3] < 0 ? lienzoAncho : p.lluvia[3];
    float y1 = p.lluvia[4] < 0 ? lienzoAlto : p.lluvia[4];
    int n = (int) p.lluvia[0];
    if (gotasCine == null || gotasCine.length != n) {
        gotasCine = new float[n][2];
        for (int k = 0; k < n; k++) {
            gotasCine[k][0] = random(x0, x1);
            gotasCine[k][1] = random(y0, y1);
        }
    }
    noStroke();
    fill(170, 195, 235, 110);
    for (float[] g : gotasCine) {
        g[0] -= 0.6;
        g[1] += 4.5;
        if (g[1] > y1) {
            g[1] = y0;
            g[0] = random(x0, x1);
        }
        if (g[0] < x0) {
            g[0] = x1;
        }
        rect(round(g[0]), round(g[1]), 1, 3);
    }
}

javax.sound.sampled.Clip clipAmbienteCine;
String ambienteCineActual = "nada";

// El sonido de fondo sigue sonando entre planos hasta que otro lo cambie.
void cambiarAmbienteCine(String archivo) {
    if (archivo.equals(ambienteCineActual)) {
        return;
    }
    if (clipAmbienteCine != null) {
        clipAmbienteCine.stop();
        clipAmbienteCine.close();
        clipAmbienteCine = null;
    }
    ambienteCineActual = archivo;
    if (archivo.equals("nada")) {
        return;
    }
    try {
        javax.sound.sampled.AudioInputStream entrada = javax.sound.sampled.AudioSystem.getAudioInputStream(new java.io.File(dataPath(archivo)));
        clipAmbienteCine = javax.sound.sampled.AudioSystem.getClip();
        clipAmbienteCine.open(entrada);
        clipAmbienteCine.loop(javax.sound.sampled.Clip.LOOP_CONTINUOUSLY);
    } catch (Exception e) {
        println("Cinematica: no se pudo sonar el ambiente " + archivo);
    }
}

// Las barras negras de cine, arriba y abajo
void dibujarBarrasCine() {
    float barra = height * 0.11;
    noStroke();
    fill(0);
    rect(0, 0, width, barra);
    rect(0, height - barra, width, barra);
}

// Una notificación de Civitas: entra desde un lado y se queda
void dibujarGloboCine(float x, float y, String texto, int edad) {
    float entra = curvaCine(edad / 250.0);
    float celda = 0.5;
    float ancho = medirPixel(texto) * celda + 8;
    pushMatrix();
    translate(x + (1 - entra) * 20, y);
    noStroke();
    fill(14, 18, 30, 230 * entra);
    rect(0, 0, ancho, 9, 2);
    fill(216, 58, 52, 255 * entra);
    rect(0, 0, 2, 9);
    tint(255, 255 * entra);
    textoPixel(texto, 5, 4.5, celda, color(225, 230, 240), LEFT, CENTER);
    noTint();
    popMatrix();
}

// Subtítulo con el nombre de quien habla; las letras aparecen de a poco y,
// si no cabe, se parte en dos líneas (cabe en la barra negra de abajo)
void dibujarSubtituloCine(String quien, String texto, int edad) {
    float celda = max(2, round(height / 270.0));
    String rotuloQuien = quien.length() > 0 ? quien.toUpperCase() + ":  " : "";
    float anchoQuien = medirPixel(rotuloQuien) * celda;
    ArrayList<String> lineas = partirPixel(texto, floor((width * 0.8 - anchoQuien) / celda));
    int letras = edad / 35;
    float alto = 11 * celda;
    float y = height - height * 0.055 - (lineas.size() - 1) * alto / 2;
    float anchoMayor = 0;
    for (String l : lineas) {
        anchoMayor = max(anchoMayor, medirPixel(l) * celda);
    }
    float x0 = width / 2.0 - (anchoQuien + anchoMayor) / 2;
    if (anchoQuien > 0) {
        textoPixel(rotuloQuien, x0, y, celda, color(224, 138, 44), LEFT, CENTER);
    }
    for (int k = 0; k < lineas.size(); k++) {
        String l = lineas.get(k);
        if (letras <= 0) {
            break;
        }
        textoPixel(l.substring(0, min(l.length(), letras)), x0 + anchoQuien, y + k * alto, celda, color(235, 232, 225), LEFT, CENTER);
        letras -= l.length() + 1;
    }
}

// Un sonido suelto (WAV de data/), sin librerías: con javax.sound
void sonarCine(String archivo) {
    try {
        javax.sound.sampled.AudioInputStream entrada = javax.sound.sampled.AudioSystem.getAudioInputStream(new java.io.File(dataPath(archivo)));
        final javax.sound.sampled.Clip clip = javax.sound.sampled.AudioSystem.getClip();
        clip.open(entrada);
        // al terminar de sonar se cierra, para no dejar la línea de audio abierta
        clip.addLineListener(new javax.sound.sampled.LineListener() {
            public void update(javax.sound.sampled.LineEvent ev) {
                if (ev.getType() == javax.sound.sampled.LineEvent.Type.STOP) {
                    clip.close();
                }
            }
        });
        clip.start();
    } catch (Exception e) {
        println("Cinematica: no se pudo sonar " + archivo);
    }
}
