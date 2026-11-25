// Creditos — la pantalla final (diseño de Jesus, Créditos.html).
//
// A la izquierda, el celular con el feed de Civitas: la ciudad cuenta cómo le
// fue con el candidato que ganó. Cada color gobierna a su manera (rojo, obras;
// azul, ecología; verde, cultura; naranja, tecnología) y el último post de
// cada uno es el costo de esa forma de gobernar. Después vienen unos posts
// sobre cómo jugó el jugador (si compartió bulos, si verificó, si amplificó
// odio) y, al final, uno que pide dejar el celular.
//
// A la derecha, el noticiero da el resultado y abajo van los nombres del
// equipo. Todo sale de data/creditos/creditos.txt, así se puede cambiar sin
// tocar el código. El feed sube solo; con la rueda del mouse o las flechas
// se puede mover.
//
// Todo esto se ve dentro de una tablet. Con un clic (o espacio) la imagen de
// la pantalla se guarda y sigue la cinemática del final
// (data/cinematicas/final.txt): la cámara se aleja de la tablet, sube hasta
// Mateo, él desliza la pantalla y aparece la foto con Andrés. Después, la
// pantalla de inicio.

boolean creditosActivos = false;
int momentoCreditos;
int ganadorCreditos;                 // el asiento que ganó
ArrayList<String[]> postsCreditos = new ArrayList<String[]>();   // imagen (o -), cuenta, texto, me gusta
ArrayList<String> nombresEquipo = new ArrayList<String>();
float desplazamientoFeed = 0;
float altoFeed = 0;
int ultimoCuadroCreditos;
PImage imgCelularCreditos, imgTVCreditos;
PImage[] imgPostsCreditos = new PImage[20];
final String[] TEMA_ASIENTO = {"azul", "rojo", "naranja", "verde"};   // en el orden de COLOR_ASIENTO
final float CRED_PROPORCION = 795 / 528.0;
final float VELOCIDAD_FEED = 0.045;   // fracción del alto del feed por segundo

void empezarCreditos() {
    if (imgCelularCreditos == null) {
        imgCelularCreditos = loadImage("creditos/celular.png");
        imgTVCreditos = loadImage("creditos/tv.png");
        for (int i = 0; i < imgPostsCreditos.length; i++) {
            imgPostsCreditos[i] = loadImage("creditos/post_" + nf(i, 2) + ".png");
        }
    }
    // gana el que tenga más apoyo, igual que en la gráfica del noticiero
    ganadorCreditos = 0;
    for (int a = 1; a < 4; a++) {
        if (apoyoDeAsiento(a) > apoyoDeAsiento(ganadorCreditos)) {
            ganadorCreditos = a;
        }
    }
    armarFeedCreditos();
    desplazamientoFeed = 0;
    momentoCreditos = millis();
    ultimoCuadroCreditos = millis();
    creditosActivos = true;
}

int asientoPropio() {
    return enRed() ? miAsientoRed : 0;
}

void armarFeedCreditos() {
    postsCreditos.clear();
    nombresEquipo.clear();
    String tema = TEMA_ASIENTO[ganadorCreditos];
    String[] lineas = loadStrings("creditos/creditos.txt");
    ArrayList<String[]> personales = new ArrayList<String[]>();
    String[] cierre = null;
    for (String l : lineas) {
        l = trim(l);
        if (l.length() == 0 || l.startsWith("#")) continue;
        String[] t = splitTokens(l, " ");
        if (t[0].equals("post") && t[1].equals(tema)) {
            postsCreditos.add(split(restoDe(l, 2), '|'));
        } else if (t[0].equals("si") && cumpleCondicion(t[1])) {
            personales.add(split(restoDe(l, 2), '|'));
        } else if (t[0].equals("cierre")) {
            cierre = split(restoDe(l, 1), '|');
        } else if (t[0].equals("nombre")) {
            nombresEquipo.add(restoDe(l, 1));
        }
    }
    // lo que hizo el jugador va después del primer post, para que se vea pronto
    int donde = min(1, postsCreditos.size());
    for (int i = personales.size() - 1; i >= 0; i--) {
        postsCreditos.add(donde, personales.get(i));
    }
    if (cierre != null) {
        postsCreditos.add(cierre);
    }
}

// Condiciones de creditos.txt sobre cómo jugó el jugador
boolean cumpleCondicion(String c) {
    boolean gano = ganadorCreditos == asientoPropio();
    if (c.equals("gano")) return gano;
    if (c.equals("perdio")) return !gano;
    if (c.equals("bulos")) return partida.getBulosCompartidos() > 0;
    if (c.equals("sin_bulos")) return partida.getBulosCompartidos() == 0;
    if (c.equals("verifico")) return partida.getAciertos() >= 3;
    if (c.equals("odio")) return partida.getOdioAmplificado() > 0;
    if (c.equals("ia")) return partida.getUsosIA() > 0;
    return false;
}

// Al cerrar los créditos se guarda lo que muestra la tablet (la cinemática
// arranca con esa imagen en la pantalla) y sigue el final.
void terminarCreditos() {
    creditosActivos = false;
    pararMusicaNoticiero();   // Televisor.pde
    creditosSinAviso = true;  // la imagen de la pantalla va sin el "CLIC O ESPACIO"
    dibujarCreditos();
    creditosSinAviso = false;
    PImage pantalla = get(int(credX), int(credY), int(credW), int(credH));
    imagenesCine.put("cinematicas/final/pantalla_creditos.png", pantalla);
    empezarCinematica("final", "final");
    if (!cinematicaActiva()) {
        terminarFinal();      // si faltara final.txt, se sigue igual
    }
}

// Después de la cinemática del final: en red, antes salen las votaciones
// (Red.pde) sobre la oficina; solo, se vuelve a la pantalla de inicio.
void terminarFinal() {
    callarSonidosCine();      // Cinematica.pde
    irA(MENU);
    if (!hayVotaciones()) {
        volverAlMenuPrincipal();
    }
}

// Se deja lista una campaña nueva y se vuelve al menú principal
void volverAlMenuPrincipal() {
    cerrarRed();
    reiniciarPartida();
    volverAlMenu();
}

// ---------------------------------------------------------------------------
// Dibujo

float credX, credY, credW, credH;
boolean creditosSinAviso = false;

float crX(float pct) { return credX + credW * pct / 100; }
float crY(float pct) { return credY + credH * pct / 100; }

void dibujarCreditos() {
    // la tablet: el marco oscuro y, adentro, la pantalla con los créditos
    background(#07080b);
    float marco = round(height * 0.045);
    float margen = round(height * 0.03);
    float libre = marco + margen;
    credW = min(width - libre * 2, (height - libre * 2) * CRED_PROPORCION);
    credH = credW / CRED_PROPORCION;
    credX = round((width - credW) / 2);
    credY = round((height - credH) / 2);
    dibujarMarcoTablet(marco);
    clip(credX, credY, credW, credH);
    fill(#050609);
    noStroke();
    rect(credX, credY, credW, credH);
    float celda = max(2, round(credW / 640));
    float t = (millis() - momentoCreditos) / 1000.0;

    // el feed sube solo
    int ahora = millis();
    float dt = constrain((ahora - ultimoCuadroCreditos) / 1000.0, 0, 0.1);
    ultimoCuadroCreditos = ahora;
    float fx = crX(10.5), fy = crY(15.9), fw = credW * 0.272, fh = credH * 0.677;
    if (t > 2.5) desplazamientoFeed += fh * VELOCIDAD_FEED * dt;
    desplazamientoFeed = constrain(desplazamientoFeed, 0, max(0, altoFeed - fh));

    // el celular, con un balanceo lento como en el HTML
    float bob = sin(t * TWO_PI / 7) * credH * 0.004;
    float ph = credH * 0.9, pw = ph * imgCelularCreditos.width / imgCelularCreditos.height;
    image(imgCelularCreditos, crX(8), crY(5) + bob, pw, ph);
    noStroke();
    fill(#f4f4f4);
    rect(fx, fy + bob, fw, fh);
    clip(fx, fy + bob, fw, fh);
    altoFeed = dibujarFeedCreditos(fx, fy + bob - desplazamientoFeed, fw, celda);
    noClip();

    // el noticiero con el resultado
    float tvBob = sin((t + 3) * TWO_PI / 8.5) * credH * 0.004;
    float tw = credW * 0.495, th = tw * imgTVCreditos.height / imgTVCreditos.width;
    float tx = crX(48.5), ty = crY(7.5) + tvBob;
    image(imgTVCreditos, tx, ty, tw, th);
    float k = tw / imgTVCreditos.width;
    dibujarResultadoTV(tx, ty, k, celda, t);

    // los nombres del equipo
    stroke(#8a8a8a);
    strokeWeight(max(1, celda / 2));
    line(crX(49), crY(60.5), crX(99), crY(60.5));
    noStroke();
    float ny = crY(66);
    textoPixel("CREADO POR", crX(74), ny, celda * 2, #d9d9d9, CENTER, CENTER);
    ny += celda * 26;
    for (String n : nombresEquipo) {
        textoPixel(n.toUpperCase(), crX(74), ny, celda, #bbbbbb, CENTER, CENTER);
        ny += celda * 14;
    }
    if (t > 4 && !creditosSinAviso) {
        float a = 0.5 + 0.5 * sin(millis() * 0.004);
        tint(255, 255 * a);   // la transparencia del texto va con tint (los textos se guardan por color)
        textoPixel("CLIC O ESPACIO PARA SEGUIR", crX(74), crY(96), celda, #a0a6b4, CENTER, CENTER);
        noTint();
    }
    noClip();
}

// El borde de la tablet alrededor de la pantalla (igual al de final/tablet_pov.png)
void dibujarMarcoTablet(float marco) {
    noStroke();
    fill(#1d1e23);
    rect(credX - marco, credY - marco, credW + marco * 2, credH + marco * 2, marco * 0.9);
    stroke(#4a4c55);
    strokeWeight(max(2, marco * 0.08));
    noFill();
    rect(credX - marco, credY - marco, credW + marco * 2, credH + marco * 2, marco * 0.9);
    noStroke();
    fill(#33353c);
    ellipse(credX - marco / 2, credY + credH / 2, marco * 0.22, marco * 0.22);   // la cámara
}

// El globo del presentador dice quién ganó; la pantallita de la derecha
// pasa los reels del noticiero del juego.
void dibujarResultadoTV(float tx, float ty, float k, float celda, float t) {
    String quien = nombreDeAsiento(ganadorCreditos).toUpperCase();
    int apoyo = apoyoDeAsiento(ganadorCreditos);
    String texto = ganadorCreditos == asientoPropio() ? "¡GANASTE CON " + apoyo + " DE APOYO!" : "GANÓ " + quien + " CON " + apoyo + " DE APOYO";
    parrafoPixel(texto, tx + 372 * k, ty + 112 * k, celda, 350 * k, #2a1e12, 3);
    // reels en la pantallita
    if (todosLosReels != null && todosLosReels.length > 0) {
        PImage r = todosLosReels[int(t / 3) % todosLosReels.length];
        if (r != null) {
            float px = tx + 885 * k, py = ty + 62 * k, pw = 375 * k, ph = 626 * k;
            float s = max(pw / r.width, ph / r.height);
            clip(px, py, pw, ph);
            image(r, px + pw / 2 - r.width * s / 2, py + ph / 2 - r.height * s / 2, r.width * s, r.height * s);
            noClip();
        }
    }
}

// Dibuja los posts uno debajo del otro y devuelve el alto total
float dibujarFeedCreditos(float x, float y, float w, float celda) {
    float y0 = y;
    float pad = w * 0.07;
    color[] colores = {#d63a30, #3a7be0, #2fae4f, #f08a2e, #a05bd0, #58c4d6};
    for (int n = 0; n < postsCreditos.size(); n++) {
        String[] p = postsCreditos.get(n);
        String imagen = p[0], cuenta = p.length > 1 ? p[1] : "", texto = p.length > 2 ? p[2] : "", gusta = p.length > 3 ? p[3] : "";
        y += pad;
        // cabecera: avatar y cuenta
        float av = w * 0.11;
        noStroke();
        fill(colores[(cuenta.length() + n) % colores.length]);
        ellipse(x + pad + av / 2, y + av / 2, av, av);
        textoPixel(cuenta, x + pad + av + pad * 0.6, y + av / 2, celda, #222222, LEFT, CENTER);
        y += av + pad * 0.6;
        // la foto (o un recuadro de color si el post es solo texto)
        float iw = w - pad * 2;
        if (!imagen.equals("-")) {
            int i = constrain(int(imagen), 0, imgPostsCreditos.length - 1);
            image(imgPostsCreditos[i], x + pad, y, iw, iw);
            y += iw + pad * 0.6;
        } else {
            float hTexto = partirPixel(texto, floor((iw - celda * 12) / (celda * 1.5))).size() * celda * 1.5 * 11 + celda * 20;
            fill(colores[(cuenta.length() + n + 2) % colores.length]);
            rect(x + pad, y, iw, hTexto);
            parrafoPixel(texto, x + pad + celda * 6, y + celda * 10, celda * 1.5, iw - celda * 12, #ffffff, 8);
            y += hTexto + pad * 0.6;
        }
        // corazón y me gusta
        fill(#d63a30);
        float hx = x + pad + celda * 3, hy = y + celda * 3;
        ellipse(hx - celda * 1.5, hy, celda * 3.5, celda * 3.5);
        ellipse(hx + celda * 1.5, hy, celda * 3.5, celda * 3.5);
        triangle(hx - celda * 3.2, hy + celda * 0.6, hx + celda * 3.2, hy + celda * 0.6, hx, hy + celda * 4.2);
        if (gusta.length() > 0) {
            textoPixel(gusta + " ME GUSTA", x + pad + celda * 10, hy + celda, celda, #222222, LEFT, CENTER);
        }
        y += celda * 12;
        if (!imagen.equals("-")) {
            y += parrafoPixel(cuenta + " " + texto, x + pad, y, celda, iw, #333333, 4);
        }
        y += pad;
        fill(#e2e2e2);
        rect(x, y, w, max(1, celda / 2));
    }
    return y - y0 + w * 0.2;
}

// ---------------------------------------------------------------------------
// Entrada

void clicCreditos() {
    if (millis() - momentoCreditos > 1500) {
        terminarCreditos();
    }
}

void teclaCreditos() {
    if (key == CODED && keyCode == DOWN) {
        desplazamientoFeed += credH * 0.08;
    } else if (key == CODED && keyCode == UP) {
        desplazamientoFeed -= credH * 0.08;
    } else if ((key == ' ' || key == ENTER || key == RETURN || key == ESC) && millis() - momentoCreditos > 1500) {
        terminarCreditos();
    }
}

void ruedaCreditos(float cuanto) {
    desplazamientoFeed += cuanto * credH * 0.04;
}
