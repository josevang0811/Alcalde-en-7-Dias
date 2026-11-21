// Encargo — la llamada de cada día como una misión secreta.
//
//   1. Al contestar arranca la música del encargo (data/encargo/, una pista
//      original hecha por código) y Marta da el mensaje como si fuera una
//      misión: el titular, quién lo publicó y "tiene diez segundos para
//      decidir qué hacer con esta información. Este mensaje se autodestruirá".
//   2. Al colgar se abre solo el celular y corren 10 segundos para elegir la
//      tarjeta y el barrio y enviar, igual que siempre.
//   3. Si envía a tiempo, el mensaje se autodestruye: el teléfono rojo echa
//      humo, el celular queda abierto como siempre y se ve cómo llega la
//      publicación. Si a los 10 segundos no envió nada, el que se quema es el
//      celular (chispas, humo y la pantalla negra): la noticia se regó sola,
//      pierde apoyo y por el resto del día ya no hay celular.
//   4. El televisor, o el botón TERMINAR EL DÍA, cierran el día.
//
// Las rondas de la misión y del parque no tienen encargo: siguen como antes.

final int SEGUNDOS_ENCARGO = 10;
final int DURACION_AUTODESTRUCCION = 2800;
final int MAX_LLAMADA_ENCARGO = 35000;   // tope de seguridad: se cuelga cuando la voz termina

int turnoDelEncargo = -1;
boolean encargoCorriendo = false;
int encargoTotal, encargoCorrido, encargoUltimoCuadro;
int encargoUltimoTic = -1;
int momentoAutodestruccion = -1;
boolean celularDestruido = false;     // en este turno ya no hay celular
boolean encargoSinPublicar = false;
boolean telefonoHumeando = false;     // el mensaje ya se autodestruyó: el teléfono rojo echa humo
int momentoEnviadoEncargo = -100000;
javax.sound.sampled.Clip clipMusicaEncargo, clipAutodestruccion;

// Las partículas de la explosión: x, y, velocidad x, velocidad y, tamaño, tipo (0 chispa, 1 humo)
ArrayList<float[]> particulasEncargo = new ArrayList<float[]>();

boolean llamadaDeEncargo() {
    return !llamadaDeValeria() && !esRondaEspecial() && !modoApoyo() && !partidaTerminada();
}

// Lo que dice Marta en el encargo
String[] frasesEncargo(Noticia n) {
    String autor = "Lo publicó " + n.describirAutor() + ".";
    if (n.generaOdio()) {
        autor += " Y está lleno de mensajes de odio.";
    }
    return new String[] {
        "Candidato, tiene un encargo.",
        "En Civitas dicen que " + n.getTitular() + ".",
        autor,
        "Tiene diez segundos para decidir qué hacer. Este mensaje se autodestruirá."
    };
}

// ---------------------------------------------------------------------------
// Sonido

javax.sound.sampled.Clip abrirClipEncargo(String archivo) {
    try {
        javax.sound.sampled.AudioInputStream entrada = javax.sound.sampled.AudioSystem.getAudioInputStream(new java.io.File(dataPath(archivo)));
        javax.sound.sampled.Clip clip = javax.sound.sampled.AudioSystem.getClip();
        clip.open(entrada);
        return clip;
    } catch (Exception e) {
        println("Encargo: no se pudo abrir " + archivo);
        return null;
    }
}

void volumenClip(javax.sound.sampled.Clip clip, float db) {
    if (clip == null || !clip.isControlSupported(javax.sound.sampled.FloatControl.Type.MASTER_GAIN)) {
        return;
    }
    javax.sound.sampled.FloatControl g = (javax.sound.sampled.FloatControl) clip.getControl(javax.sound.sampled.FloatControl.Type.MASTER_GAIN);
    g.setValue(constrain(db, g.getMinimum(), g.getMaximum()));
}

// Se llama al contestar el teléfono (Llamada.pde)
void empezarMusicaEncargo() {
    if (!llamadaDeEncargo() || turnoDelEncargo == partida.getTurno()) {
        return;   // con la Libreta se vuelve a oír, pero el encargo ya pasó
    }
    if (clipMusicaEncargo == null) {
        // Si está la canción que puso el equipo (mision_imposible.wav, solo
        // para la copia local: no se sube) suena esa; si no, la pista propia.
        if (new java.io.File(dataPath("encargo/mision_imposible.wav")).exists()) {
            clipMusicaEncargo = abrirClipEncargo("encargo/mision_imposible.wav");
        }
        if (clipMusicaEncargo == null) {
            clipMusicaEncargo = abrirClipEncargo("encargo/encargo_musica.wav");
        }
    }
    if (clipMusicaEncargo != null) {
        clipMusicaEncargo.setFramePosition(0);
        clipMusicaEncargo.loop(javax.sound.sampled.Clip.LOOP_CONTINUOUSLY);
    }
}

boolean musicaEncargoSonando() {
    return clipMusicaEncargo != null && clipMusicaEncargo.isRunning();
}

void pararMusicaEncargo() {
    if (clipMusicaEncargo != null) {
        clipMusicaEncargo.stop();
    }
}

// ---------------------------------------------------------------------------
// La cuenta de 10 segundos

// Se llama cuando cuelga Marta (Llamada.pde)
void empezarEncargo() {
    if (!llamadaDeEncargo() || turnoDelEncargo == partida.getTurno()) {
        return;
    }
    turnoDelEncargo = partida.getTurno();
    encargoCorriendo = true;
    encargoTotal = SEGUNDOS_ENCARGO * 1000;
    encargoCorrido = 0;
    encargoUltimoCuadro = millis();
    encargoUltimoTic = -1;
    celularDestruido = false;
    // el celular se abre solo y listo para elegir, sin esperar el "escribiendo"
    abrirCelular();
    momentoIntro = millis() - ESPERA_ESCRIBIENDO;
}

boolean encargoEnPausa() {
    return estado == AYUDA || enMenu || mostrarPortada || saliendo || cinematicaActiva() || videollamadaActiva;
}

int segundosEncargo() {
    return max(0, ceil((encargoTotal - encargoCorrido) / 1000.0));
}

// Se llama en cada draw()
void actualizarEncargo() {
    int ahora = millis();
    int dt = constrain(ahora - encargoUltimoCuadro, 0, 100);
    encargoUltimoCuadro = ahora;
    // mientras Marta habla la música baja para que se le entienda
    if (musicaEncargoSonando()) {
        volumenClip(clipMusicaEncargo, faseLlamada == LLAMADA_HABLANDO ? -11 : -2);
    }
    if (momentoAutodestruccion >= 0) {
        actualizarParticulasEncargo(dt);
        if (ahora - momentoAutodestruccion >= DURACION_AUTODESTRUCCION) {
            terminarAutodestruccion();
        }
        return;
    }
    if (!encargoCorriendo || encargoEnPausa()) {
        return;
    }
    encargoCorrido += dt;
    int quedan = segundosEncargo();
    if (quedan > 0 && quedan != encargoUltimoTic) {
        encargoUltimoTic = quedan;
        sonidos.tocarTic();
    }
    if (encargoCorrido >= encargoTotal) {
        autodestruir();
    }
}

// ---------------------------------------------------------------------------
// La autodestrucción

// Envió a tiempo (Celular.pde): el celular sigue abierto y el mensaje se destruye
void alEnviarEnEncargo() {
    if (!encargoCorriendo) {
        return;
    }
    encargoCorriendo = false;
    pararMusicaEncargo();
    telefonoHumeando = true;
    momentoEnviadoEncargo = millis();
    sonarAutodestruccion();
}

void sonarAutodestruccion() {
    if (clipAutodestruccion == null) {
        clipAutodestruccion = abrirClipEncargo("encargo/autodestruccion.wav");
    }
    if (clipAutodestruccion != null) {
        clipAutodestruccion.setFramePosition(0);
        clipAutodestruccion.start();
    }
}

boolean encargoTerminado() {
    return celularDestruido || telefonoHumeando;
}

void autodestruir() {
    encargoCorriendo = false;
    telefonoHumeando = true;
    pararMusicaEncargo();
    if (estado != CELULAR) {
        irA(CELULAR);   // lo que esté abierto se cierra: se ve cómo se quema el celular
    }
    calcularLayoutCelular();
    momentoAutodestruccion = millis();
    sonarAutodestruccion();
    // chispas que saltan y humo que sube desde la pantalla
    particulasEncargo.clear();
    float cx = panX + panAncho / 2, cy = panY + panAlto * 0.45;
    float u = celdaEncargo();
    for (int i = 0; i < 46; i++) {
        float a = random(TWO_PI), v = random(4, 14) * u * 0.2;
        particulasEncargo.add(new float[] {cx + random(-1, 1) * panAncho * 0.3, cy + random(-1, 1) * panAlto * 0.3,
            cos(a) * v, sin(a) * v - 2 * u * 0.2, round(random(1, 2.6)) * u, 0, 0});
    }
    for (int i = 0; i < 110; i++) {
        particulasEncargo.add(new float[] {cx + random(-1, 1) * panAncho * 0.25, cy + random(-0.4, 0.6) * panAlto * 0.3,
            random(-0.8, 0.8) * u * 0.2, -random(2, 5) * u * 0.2, random(1.5, 3) * u, 1, random(-1200, 300)});
    }
    // si no alcanzó a publicar, la noticia se regó sin respuesta
    encargoSinPublicar = !partida.yaPublicoEsteTurno();
    if (encargoSinPublicar) {
        int z = partida.barrioConMasApoyo();
        int cambio = partida.registrarEvento(z, -CASTIGO_SIN_RESPONDER);
        avisoFinDia = "No decidiste a tiempo: la noticia se regó sola (" + cambio + " de apoyo en " + partida.getCiudad().getNombre(z) + "). ";
    }
}

void terminarAutodestruccion() {
    momentoAutodestruccion = -1;
    celularDestruido = true;
    particulasEncargo.clear();
    if (estado == CELULAR) {
        irA(MENU);
    }
    if (encargoSinPublicar) {
        avisar(avisoFinDia);
        mostrarTextoFlotante(str(-CASTIGO_SIN_RESPONDER), COLOR_ERROR);
    } else {
        avisar("Usa el botón TERMINAR EL DÍA.");
    }
}

boolean autodestruyendo() {
    return momentoAutodestruccion >= 0;
}

void actualizarParticulasEncargo(int dt) {
    float k = dt / 16.0;
    for (float[] p : particulasEncargo) {
        if (p[6] < 0) {
            p[6] += dt;   // el humo sale poco a poco
            continue;
        }
        p[6] += dt;
        p[0] += p[2] * k;
        p[1] += p[3] * k;
        if (p[5] == 0) {
            p[3] += 0.35 * k * celdaEncargo() * 0.2;   // las chispas caen
        } else {
            p[4] += 0.05 * k * celdaEncargo();         // el humo crece
            p[2] *= 0.99;
        }
    }
}

void reiniciarEncargo() {
    encargoCorriendo = false;
    telefonoHumeando = false;
    momentoEnviadoEncargo = -100000;
    momentoAutodestruccion = -1;
    celularDestruido = false;
    particulasEncargo.clear();
    pararMusicaEncargo();
}

// ---------------------------------------------------------------------------
// Dibujo

float celdaEncargo() {
    return max(2, round(camAncho / 480));
}

// Encima de todo (en draw): la cuenta y la explosión
void dibujarEncargo() {
    dibujarCelularQuemado();
    dibujarTelefonoHumeando();
    dibujarAvisoEnviado();
    dibujarBotonTerminarDia();
    if (autodestruyendo() && estado == CELULAR) {
        dibujarAutodestruccion();
    }
    if (encargoCorriendo && !enMenu && !mostrarPortada && estado != AYUDA) {
        dibujarCuentaEncargo();
    }
}

// La cuenta: entre el celular y el mapa, un número grande y una mecha que se
// quema. En la oficina o el libro va arriba, al centro.
void dibujarCuentaEncargo() {
    float u = celdaEncargo();
    int quedan = segundosEncargo();
    float resto = 1 - encargoCorrido / (float) encargoTotal;
    float cx, cy;
    if (estado == CELULAR) {
        calcularLayoutCelular();
        cx = (celX + celAncho + mapaPanelX) / 2;
        cy = panY + panAlto * 0.42;
    } else {
        cx = width / 2;
        cy = camY + u * 44;
    }
    // lo que va adentro, para medir la caja (nada se sale del recuadro)
    String titulo = "SE AUTODESTRUYE EN";
    String[] ayuda;
    if (estado != CELULAR) {
        ayuda = new String[] {"¡VUELVE AL CELULAR!"};
    } else if (partida.yaPublicoEsteTurno()) {
        ayuda = new String[] {"¡ENVIADO!"};
    } else {
        ayuda = new String[] {"TARJETA, BARRIO", "Y ENVÍA"};
    }
    float kc = u * 0.5, kn = u * 4;
    float anchoTexto = medirPixel(titulo) * kc;
    for (String a : ayuda) {
        anchoTexto = max(anchoTexto, medirPixel(a) * kc);
    }
    float pad = u * 4;
    float w = max(anchoTexto, medirPixel("10") * kn) + pad * 2;
    float altoTitulo = u * 9, altoNumero = 7 * kn, altoMecha = u * 6, altoAyuda = ayuda.length * u * 6;
    float h = altoTitulo + u * 4 + altoNumero + u * 3 + altoMecha + altoAyuda + u * 3;
    float x0 = cx - w / 2, y0 = cy - h / 2;
    float pulso = 0.5 + 0.5 * sin(millis() * 0.02);
    noStroke();
    fill(10, 10, 14, 235);
    rect(x0, y0, w, h, u * 2);
    fill(quedan <= 3 ? lerpColor(#5a1410, #d83a34, pulso) : #2a0e0e);
    rect(x0, y0, w, altoTitulo, u * 2, u * 2, 0, 0);
    textoPixel(titulo, cx, y0 + altoTitulo / 2, kc, #ffd6cf, CENTER, CENTER);
    float yNumero = y0 + altoTitulo + u * 4 + altoNumero / 2;
    textoPixel(str(quedan), cx, yNumero, kn, quedan <= 3 ? #ff5a4a : #fff3d6, CENTER, CENTER);
    // la mecha: se acorta y en la punta echa chispas
    float mx = x0 + pad, my = y0 + altoTitulo + u * 4 + altoNumero + u * 3 + altoMecha / 2, mw = w - pad * 2;
    fill(60, 50, 44);
    rect(mx, my - u, mw, u * 2);
    fill(#c8a46a);
    rect(mx, my - u, mw * resto, u * 2);
    float px = mx + mw * resto;
    for (int i = 0; i < 6; i++) {
        float a = random(TWO_PI), r = random(1, 2.5) * u;
        fill(random(1) < 0.5 ? #ffd34e : #ff7a2e);
        rect(round((px + cos(a) * r) / u) * u, round((my + sin(a) * r) / u) * u, u, u);
    }
    float yAyuda = my + altoMecha / 2 + u * 3;
    for (int i = 0; i < ayuda.length; i++) {
        textoPixel(ayuda[i], cx, yAyuda + i * u * 6, kc, #fff3d6, CENTER, CENTER);
    }
}

// En la oficina, el celular quemado sigue echando humo sobre el escritorio
void dibujarCelularQuemado() {
    if (!celularDestruido || estado != MENU || enMenu || mostrarPortada || llamadaEnPantalla()) {
        return;
    }
    float u = celdaEncargo();
    humoEn(pcX(17.7), pcY(72), u, 9);
    fill(#ff7a2e, 110 + 110 * sin(millis() * 0.02));
    rect(round(pcX(17.7) / u) * u, round(pcY(72) / u) * u, u, u);
}

// Humo que sube de un punto de la oficina (en % de la cámara)
void humoEn(float cx, float cy, float u, int puffs) {
    int t = millis();
    noStroke();
    for (int i = 0; i < puffs; i++) {
        float fase = ((t / 2600.0) + i / (float) puffs) % 1;
        float x = cx + sin(fase * 5 + i) * u * 3 + (i % 3 - 1) * u * 2;
        float y = cy - fase * u * 55;
        fill(lerpColor(#1e1a18, #7a7672, fase), 255 * pow(1 - fase, 0.7));
        circuloPixel(x, y, u * (3 + fase * 6), u);
    }
}

// El teléfono rojo del escritorio, después de que el mensaje se autodestruyó
void dibujarTelefonoHumeando() {
    if (!telefonoHumeando || estado != MENU || enMenu || mostrarPortada || llamadaEnPantalla()) {
        return;
    }
    float u = celdaEncargo();
    humoEn(pcX(80.5), pcY(62), u, 12);
    fill(#ff7a2e, 110 + 110 * sin(millis() * 0.02));
    rect(round(pcX(80.5) / u) * u, round(pcY(62) / u) * u, u, u);
}

// Al enviar a tiempo: un letrero entre el celular y el mapa, con su humo
void dibujarAvisoEnviado() {
    int t = millis() - momentoEnviadoEncargo;
    if (estado != CELULAR || t > 2600) {
        return;
    }
    calcularLayoutCelular();
    float u = celdaEncargo();
    float cx = (celX + celAncho + mapaPanelX) / 2, cy = panY + panAlto * 0.42;
    float a = t < 2000 ? 1 : 1 - (t - 2000) / 600.0;
    // la caja se mide con su texto, para que nada se salga
    String grande = "¡ENVIADO!";
    String[] chicas = {"EL MENSAJE SE", "AUTODESTRUYÓ"};
    float kg = u, kc = u * 0.5, pad = u * 4;
    float anchoTexto = medirPixel(grande) * kg;
    for (String c : chicas) {
        anchoTexto = max(anchoTexto, medirPixel(c) * kc);
    }
    float w = anchoTexto + pad * 2;
    float h = pad + 7 * kg + u * 4 + chicas.length * u * 6 + pad * 0.6;
    float x0 = cx - w / 2, y0 = cy - h / 2;
    humoEn(cx, y0, u, 8);
    noStroke();
    fill(10, 10, 14, 230 * a);
    rect(x0, y0, w, h, u * 2);
    tint(255, 255 * a);
    textoPixel(grande, cx, y0 + pad + 3.5 * kg, kg, #8ee59a, CENTER, CENTER);
    for (int i = 0; i < chicas.length; i++) {
        textoPixel(chicas[i], cx, y0 + pad + 7 * kg + u * 5 + i * u * 6, kc, #ffd6cf, CENTER, CENTER);
    }
    noTint();
}

// ---------------------------------------------------------------------------
// El botón TERMINAR EL DÍA

boolean puedeTerminarDia() {
    return !partidaTerminada() && faseLlamada == LLAMADA_ATENDIDA && !encargoCorriendo && !autodestruyendo()
        && !esperandoTurno && !transicionDiaActiva() && !llamadaEnPantalla() && !informeVisible()
        && !enMenu && !mostrarPortada && estado == MENU
        && (partida.yaPublicoEsteTurno() || encargoTerminado() || esRondaEspecial());
}

float[] cajaBotonTerminarDia() {
    float u = celdaEncargo();
    float w = (medirPixel("TERMINAR EL DÍA") + 22) * u * 0.75, h = u * 14;
    // abajo a la derecha de la oficina (solo se muestra ahí)
    return new float[] {camX + camAncho - w - u * 6, camY + camAlto - h - u * 6, w, h};
}

boolean mouseEnTerminarDia() {
    if (!puedeTerminarDia()) {
        return false;
    }
    float[] b = cajaBotonTerminarDia();
    return mouseX >= b[0] && mouseX <= b[0] + b[2] && mouseY >= b[1] && mouseY <= b[1] + b[3];
}

void dibujarBotonTerminarDia() {
    if (!puedeTerminarDia()) {
        return;
    }
    float u = celdaEncargo();
    float[] b = cajaBotonTerminarDia();
    boolean encima = mouseEnTerminarDia();
    if (encima) {
        pedirCursorMano();
    }
    float pulso = 0.5 + 0.5 * sin(millis() * 0.005);
    noStroke();
    fill(#1a1010);
    rect(b[0] - u * 0.5, b[1] - u * 0.5, b[2] + u, b[3] + u, u * 2);
    fill(encima ? #e8584d : lerpColor(#8a2a22, #b8382e, pulso));
    rect(b[0], b[1], b[2], b[3], u * 2);
    textoPixel("TERMINAR EL DÍA", b[0] + b[2] / 2, b[1] + b[3] / 2, u * 0.75, #fff3d6, CENTER, CENTER);
}

// Se llama al principio de mousePressed: true si el clic era del botón
boolean clicEnTerminarDia() {
    if (!mouseEnTerminarDia()) {
        return false;
    }
    terminarDia();   // Ronda.pde
    return true;
}

// Un círculo hecho de cuadritos, para el humo pixelado
void circuloPixel(float cx, float cy, float r, float u) {
    int n = max(1, round(r / u));
    for (int j = -n; j <= n; j++) {
        for (int i = -n; i <= n; i++) {
            if (i * i + j * j <= n * n + n * 0.5) {
                rect(round((cx + i * u) / u) * u, round((cy + j * u) / u) * u, u, u);
            }
        }
    }
}

void dibujarAutodestruccion() {
    calcularLayoutCelular();
    int t = millis() - momentoAutodestruccion;
    float u = celdaEncargo();
    noStroke();
    // la pantalla se quema: de un blanco que encandila a negro con grietas
    float quemado = constrain(t / 500.0, 0, 1);
    fill(lerpColor(#ffffff, #0c0a0a, quemado), 245);
    rect(panX, panY, panAncho, panAlto, max(4, 6 * escala));
    if (t > 250) {
        stroke(#3a3230);
        strokeWeight(u * 0.6);
        randomSeed(turnoDelEncargo * 31);
        for (int g = 0; g < 7; g++) {
            float x = panX + panAncho * random(0.2, 0.8), y = panY + panAlto * random(0.2, 0.8);
            for (int s = 0; s < 5; s++) {
                float nx = x + random(-1, 1) * panAncho * 0.12, ny = y + random(-1, 1) * panAlto * 0.08;
                line(x, y, nx, ny);
                x = nx;
                y = ny;
            }
        }
        randomSeed(millis());
        noStroke();
        // brasas que titilan en las grietas
        fill(#ff7a2e, 120 + 120 * sin(t * 0.03));
        circuloPixel(panX + panAncho * 0.5, panY + panAlto * 0.45, u * 1.5, u);
    }
    // el destello del primer instante
    if (t < 160) {
        fill(255, 245, 220, 230 * (1 - t / 160.0));
        rect(0, 0, width, height);
    }
    // chispas y humo
    for (float[] p : particulasEncargo) {
        if (p[6] < 0) {
            continue;
        }
        if (p[5] == 0) {
            if (t > 900) {
                continue;
            }
            fill(random(1) < 0.5 ? #ffd34e : #ff8a3a);
            rect(round(p[0] / u) * u, round(p[1] / u) * u, p[4], p[4]);
        } else {
            float vida = constrain(p[6] / 2400.0, 0, 1);
            fill(lerpColor(#2a2726, #7e7a76, vida), 150 * (1 - vida * vida));
            circuloPixel(p[0], p[1], p[4], u);
        }
    }
    // el letrero
    float a = constrain((t - 600) / 300.0, 0, 1);
    if (a > 0) {
        tint(255, 255 * a);
        float cx = panX + panAncho / 2;
        textoPixel("MENSAJE", cx, panY + panAlto * 0.72, u, #ff5a4a, CENTER, CENTER);
        textoPixel("AUTODESTRUIDO", cx, panY + panAlto * 0.72 + u * 10, u, #ff5a4a, CENTER, CENTER);
        noTint();
    }
}
