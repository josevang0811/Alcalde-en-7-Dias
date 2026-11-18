// Cinematica — escenas cortas contadas plano por plano (el prólogo, y las
// que vengan después).
//
// Cada escena es un archivo de texto en data/cinematicas/ que el equipo de
// diseño puede editar sin tocar código. Al empezar, el archivo se lee y sus
// planos se meten en una COLA: se muestra el de adelante y, cuando se le
// acaba el tiempo, se saca y pasa el siguiente. La escena termina cuando la
// cola queda vacía (o el jugador la salta).
//
// Los dibujos se piensan en un lienzo de 320x180 (pixel art) que se agranda
// a la pantalla. La cámara se mueve sobre ese lienzo: centro (x, y) y zoom,
// desde un punto a otro a lo largo del plano, con una curva suave.
//
// Órdenes del archivo (una por línea; # es comentario):
//   plano <ms>                       empieza un plano que dura <ms>
//   fondo <#rrggbb>                  color detrás de todo
//   capa <imagen> <x> <y> [desde] [vibra]   imagen en el lienzo; aparece a los <desde> ms
//   ajustar <imagen>                 imagen que llena el lienzo (por ejemplo una de 1920x1080)
//   camara <x0> <y0> <z0> <x1> <y1> <z1>    centro y zoom al empezar y al terminar el plano
//   globo <x> <y> <desde> <texto>    notificación de Civitas sobre el lienzo
//   subtitulo <desde> <quien>|<texto>       línea de diálogo abajo, en la barra negra
//   rotulo <texto>                   texto grande en el centro (p. ej. "25 AÑOS DESPUÉS")
//   sonido <desde> <archivo.wav>     suena una vez a los <desde> ms
//   fundido <entrada> <salida>       ms de fundido a negro al empezar y al terminar
//   temblor <fuerza>                 la cámara tiembla un poco (en pixeles del lienzo)

final int LIENZO_ANCHO = 320;
final int LIENZO_ALTO = 180;

class PlanoCine {
    int duracion = 3000;
    color fondo = #0a0a10;
    ArrayList<String[]> capas = new ArrayList<String[]>();      // imagen, x, y, desde, vibra
    ArrayList<String[]> globos = new ArrayList<String[]>();     // x, y, desde, texto
    ArrayList<String[]> subtitulos = new ArrayList<String[]>(); // desde, quien, texto
    ArrayList<String[]> sonidos = new ArrayList<String[]>();    // desde, archivo
    float[] camara = {160, 90, 1, 160, 90, 1};
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
        if (orden.equals("plano")) {
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
            p.capas.add(new String[] {t[1], "0", "0", "0", "ajustar"});
        } else if (orden.equals("camara")) {
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
}

void saltarCinematica() {
    colaCine.clear();
    planoCine = null;
    terminarCinematica();
}

void terminarCinematica() {
    planoCine = null;
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
    float escala = max(width / (float) LIENZO_ANCHO, height / (float) LIENZO_ALTO) * zoom;
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
        if (c[4].equals("ajustar")) {
            image(img, 0, 0, LIENZO_ANCHO, LIENZO_ALTO);
        } else {
            float dx = c[4].equals("vibra") && (t / 60) % 2 == 0 ? 1 : 0;
            image(img, float(c[1]) + dx, float(c[2]));
        }
    }
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
        javax.sound.sampled.Clip clip = javax.sound.sampled.AudioSystem.getClip();
        clip.open(entrada);
        clip.start();
    } catch (Exception e) {
        println("Cinematica: no se pudo sonar " + archivo);
    }
}
