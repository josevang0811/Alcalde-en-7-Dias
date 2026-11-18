// Impacto — lo que pasó en Civitas con cada jugada, explicado.
//
// Lo pidió la profesora: que el juego devuelva el impacto de lo que se
// publica, y que se vea qué tiene que ver cada cosa con las redes sociales.
// Aquí están:
//   - El INFORME DE IMPACTO: después de publicar (y al volver de un
//     minijuego o de la misión) sale una hoja con cuánta gente lo vio, cómo
//     reaccionaron (comentarios), la etiqueta que le puso Civitas a la
//     noticia, qué era en realidad y qué pista lo delataba, cuánto cambió el
//     apoyo y la credibilidad, y la lección del turno.
//   - La CREDIBILIDAD (Partida.java): una barra siempre visible en la
//     oficina. Con más credibilidad lo que publicas llega a más gente.
//   - CIVITAS EN VIVO: durante los minijuegos del mundo abierto, un panel
//     con las vistas y los comentarios de la gente que reaccionan a lo que
//     pasa.
//   - TU HUELLA DIGITAL: el resumen al final de la campaña (Interfaz.pde).

class Informe {
    String titulo;          // "TURNO 3 · PUBLICASTE EN EL MERCADO"
    String publicado;       // lo que se publicó (el texto de la tarjeta)
    String etiqueta;        // la etiqueta de Civitas sobre la noticia
    color colorEtiqueta;
    int vistas, compartidos, meGusta;
    String[] comentarios;
    String verdad;          // "ERA FALSA"
    String pista;           // qué la delataba
    String leccion;
    int cambioApoyo;
    String barrio;
    int credAntes, credDespues;
}

Informe informeActual;          // el que se está mostrando o espera para mostrarse
int momentoListoInforme = -1;   // desde cuándo se puede mostrar
boolean informeVisto = true;

boolean informeVisible() {
    if (informeActual == null || informeVisto || millis() < momentoListoInforme) {
        return false;
    }
    if (estado == CELULAR) {
        return faseCelular == CEL_LISTO;
    }
    return estado == MENU && !enMenu && !llamadaEnPantalla() && !camaraBajando && !camaraSubiendo;
}

void mostrarInforme(Informe inf, int espera) {
    informeActual = inf;
    informeVisto = false;
    momentoListoInforme = millis() + espera;
}

// ---------------------------------------------------------------------------
// Armar los informes
// ---------------------------------------------------------------------------

// Después de publicar (Celular.pde, enviarPublicacion)
void informeDePublicacion(Publicacion p, Tarjeta tarjeta, Noticia n, String barrio) {
    Informe inf = new Informe();
    int accion = tarjeta.getAccion();
    inf.titulo = "TURNO " + partida.getTurno() + (accion == Influencer.CALLAR ? " · DECIDISTE NO PUBLICAR" : " · PUBLICASTE EN " + barrio.toUpperCase());
    inf.publicado = p.usoIA() ? "«" + envioNoticiaIA + "» (inventada con IA)" : "«" + tarjeta.getTexto() + "»";
    inf.barrio = barrio;
    inf.cambioApoyo = p.getCambio();
    inf.credAntes = p.getCredAntes();
    inf.credDespues = p.getCredDespues();
    inf.vistas = p.getAlcance();
    boolean mala = p.getCategoria() == Influencer.NEGATIVA;
    inf.compartidos = round(inf.vistas * (mala ? 0.22 : 0.12));
    inf.meGusta = round(inf.vistas * (mala ? 0.18 : 0.42));
    if (n.getTipo() == Noticia.FALSA) {
        inf.etiqueta = "CIVITAS: CONTENIDO ENGAÑOSO";
        inf.colorEtiqueta = #d83a34;
        inf.verdad = "LA NOTICIA ERA FALSA";
    } else if (n.getTipo() == Noticia.VERDADERA) {
        inf.etiqueta = "CIVITAS: INFORMACIÓN VERIFICADA";
        inf.colorEtiqueta = #3f9a4a;
        inf.verdad = "LA NOTICIA ERA VERDADERA";
    } else {
        inf.etiqueta = "CIVITAS: ESTO ES UNA OPINIÓN";
        inf.colorEtiqueta = #d08a1c;
        inf.verdad = "LA NOTICIA ERA UNA OPINIÓN";
    }
    inf.pista = pistaDe(n);
    inf.comentarios = comentariosDe(p, n, accion);
    inf.leccion = leccionDe(p, n, accion);
    mostrarInforme(inf, 2600);   // después de que llega y Nico contesta
}

// Qué delataba a la noticia: quién la publicó, lo que decían los
// comentarios y si atacaba a un grupo.
String pistaDe(Noticia n) {
    String quien;
    if (n.getTipoAutor() == Noticia.REPORTERO) {
        quien = "La publicó un medio con cuenta verificada";
    } else if (n.getTipoAutor() == Noticia.USUARIO) {
        quien = "La publicó una persona común, sin citar fuente";
    } else {
        quien = "La publicó una cuenta anónima, sin nombre ni foto";
    }
    String odio = n.generaOdio() ? " Además atacaba a un grupo de personas." : "";
    return quien + ". En los comentarios: " + n.getComentarios() + "." + odio;
}

String[] comentariosDe(Publicacion p, Noticia n, int accion) {
    if (p.usoIA()) {
        return p.iaDescubierta()
            ? new String[] {"@vecina_ana: ¿Una noticia hecha con IA? Qué decepción.", "@datos_claros: Esto es falso, ya lo verificamos. No compartan."}
            : new String[] {"@juan_23: ¡No sabía eso! Lo comparto.", "@marta_r: ¿Alguien tiene la fuente? No la encuentro."};
    }
    if (accion == Influencer.CALLAR) {
        return new String[] {"(No publicaste nada: nadie comentó.)"};
    }
    int c = p.getCategoria();
    if (c == Influencer.MAYOR) {
        if (accion == Influencer.DESMENTIR) {
            return new String[] {"@profe_luis: Gracias por aclararlo, ya se lo había reenviado a mi familia.", "@vecina_ana: Así sí: con pruebas."};
        } else if (accion == Influencer.OPINION) {
            return new String[] {"@sofi_m: Me gusta que lo digas como opinión y no como un hecho.", "@don_pedro: Yo pienso distinto, pero respeto el debate."};
        }
        return new String[] {"@juan_23: Con la fuente y todo. Así da gusto.", "@vecina_ana: Lo comparto, esto es importante."};
    } else if (c == Influencer.MENOR) {
        return new String[] {"@marta_r: Bien que avises, pero ¿al fin es cierto o no?", "@sofi_m: Esperaré a ver qué dicen los medios."};
    } else if (c == Influencer.NEUTRA) {
        return new String[] {"@don_pedro: ¿Y el candidato qué opina de esto?"};
    }
    if (n.generaOdio()) {
        return new String[] {"@vecina_ana: Esto es odio puro. Me da tristeza que lo compartas.", "@troll_9999: ¡JAJA, que se vayan todos!", "@profe_luis: Reportado."};
    }
    if (n.getTipo() == Noticia.FALSA) {
        return new String[] {"@datos_claros: FALSO. Ya está desmentido, no lo compartan.", "@juan_23: Me lo creí y lo reenvié. Qué pena."};
    }
    return new String[] {"@marta_r: ¿Por qué cambias lo que dice la noticia?", "@sofi_m: Así no, candidato."};
}

String leccionDe(Publicacion p, Noticia n, int accion) {
    if (p.usoIA()) {
        return "Inventar con IA es desinformar: si te pillan pierdes la confianza, y si no, igual engañaste a la gente.";
    }
    if (n.generaOdio() && (accion == Influencer.COMPARTIR || accion == Influencer.EXAGERAR)) {
        return "Amplificar un mensaje de odio lastima a personas reales, aunque dé muchos me gusta.";
    }
    if (n.getTipo() == Noticia.FALSA && (accion == Influencer.COMPARTIR || accion == Influencer.EXAGERAR)) {
        return "Compartir sin verificar riega el bulo: llegó a mucha gente, pero te costó credibilidad.";
    }
    switch (accion) {
        case 0:   // COMPARTIR
            return n.getTipo() == Noticia.VERDADERA ? "Lo verificado, con su fuente, suma confianza." : "Una opinión compartida como si fuera un hecho confunde a la gente.";
        case 1:   // DESMENTIR
            return n.getTipo() == Noticia.FALSA ? "Desmentir a tiempo frena la cadena del bulo." : "Desmentir algo cierto también es desinformar.";
        case 2:   // OPINION
            return n.getTipo() == Noticia.OPINION ? "Separar opinión de hecho deja que cada quien decida." : "Si es un hecho, presentarlo como opinión le quita fuerza a la verdad.";
        case 3:   // CAUTELA
            return "Pedir confirmación es prudente, pero llega a menos gente.";
        case 4:   // CALLAR
            return "No publicar también es una decisión: no sumaste, pero tampoco hiciste daño.";
        case 5:   // EXAGERAR
            return "El titular alarmista se comparte más, pero desinforma y la gente lo nota.";
    }
    return "";
}

// Al volver de un minijuego del mundo abierto (EventoParque.pde)
void informeDeEvento(int tipo, int puesto, int premio) {
    Informe inf = new Informe();
    String[] nombres = {"VOLANTES VERIFICADOS", "TRANSMISIÓN DESDE EL PARQUE", "LOS LIVES DE LA CIUDAD"};
    inf.titulo = "TURNO " + partida.getTurno() + " · " + nombres[constrain(tipo, 0, 2)];
    int[] credPorPuesto = {6, 3, 0, -2};
    int antes = partida.getCredibilidad();
    partida.cambiarCredibilidad(credPorPuesto[constrain(puesto, 0, 3)]);
    inf.credAntes = antes;
    inf.credDespues = partida.getCredibilidad();
    inf.vistas = round((2600 - puesto * 600) * partida.factorCredibilidad());
    partida.sumarAlcance(inf.vistas);
    inf.compartidos = round(inf.vistas * 0.15);
    inf.meGusta = round(inf.vistas * 0.4);
    inf.cambioApoyo = premio;
    inf.barrio = premio > 0 ? "el barrio que elijas en el celular" : "tu barrio más fuerte";
    inf.colorEtiqueta = puesto == 0 ? #3f9a4a : (puesto == 1 ? #d08a1c : #d83a34);
    inf.etiqueta = "QUEDASTE DE " + (puesto + 1) + ".º";
    if (tipo == mundo.VOLANTES) {
        inf.publicado = "Pegaste volantes con la información verificada para frenar el rumor del parque.";
        inf.verdad = "EL RUMOR ERA FALSO";
        inf.pista = "Nadie citaba una fuente: solo «me dijeron que...». Lo que más se compartía era lo más alarmante.";
        inf.comentarios = puesto <= 1 ? new String[] {"@vecina_ana: Vi tu volante y busqué el enlace: era mentira lo del parque.", "@juan_23: Ya lo borré del grupo de la familia."}
            : new String[] {"@don_pedro: A mí me llegó primero el rumor que la aclaración.", "@sofi_m: ¿Entonces sí o no cierran el parque?"};
        inf.leccion = "Un bulo viaja más rápido que la aclaración: hay que llegar antes con información verificada.";
    } else if (tipo == mundo.GENTE) {
        inf.publicado = "Hablaste con la gente del parque mientras se transmitía en Civitas.";
        inf.verdad = "CADA PERSONA CONVENCIDA COMPARTE TU MENSAJE";
        inf.pista = "Convencer con calma (la secuencia completa) dura más que el «me gusta» rápido, que otro te puede quitar.";
        inf.comentarios = puesto <= 1 ? new String[] {"@profe_luis: Lo escuché en el live y me convenció, sin gritos.", "@sofi_m: Lo comparto con mis amigos."}
            : new String[] {"@marta_r: Otro candidato llegó primero con más ruido.", "@juan_23: Mucho like y poca conversación."};
        inf.leccion = "Un seguidor convencido con argumentos vale más que mil «me gusta» rápidos.";
    } else {
        inf.publicado = "Llegaste a los lives que regaban rumores para que contaran la versión verificada.";
        inf.verdad = "VARIOS LIVES DIFUNDÍAN UN RUMOR";
        inf.pista = "En vivo nadie verifica: lo que se dice se comparte al instante y sin fuente.";
        inf.comentarios = puesto <= 1 ? new String[] {"@datos_claros: Bien que aclararan en vivo antes de que se regara.", "@vecina_ana: Ahora sí entiendo qué pasó."}
            : new String[] {"@troll_9999: ¡Yo lo vi en un live, tiene que ser verdad!", "@don_pedro: Cada live decía una cosa distinta."};
        inf.leccion = "Que algo se transmita en vivo no lo hace verdad: verifica antes de compartir.";
    }
    mostrarInforme(inf, 400);
}

// Al volver de la misión Infiltrado (MisionCampana.pde)
void informeDeMision(boolean exito, int cambio) {
    Informe inf = new Informe();
    inf.titulo = "TURNO " + partida.getTurno() + " · MISIÓN: EL BULO DEL RIVAL";
    int antes = partida.getCredibilidad();
    partida.cambiarCredibilidad(exito ? 8 : -3);
    inf.credAntes = antes;
    inf.credDespues = partida.getCredibilidad();
    inf.vistas = exito ? 1200 : 8400;   // cuánta gente vio el bulo antes de que cayera (o no)
    inf.compartidos = round(inf.vistas * (exito ? 0.1 : 0.25));
    inf.meGusta = round(inf.vistas * 0.3);
    inf.cambioApoyo = cambio;
    inf.barrio = "el barrio del bulo";
    inf.etiqueta = exito ? "BULO DESACTIVADO" : "EL BULO SIGUE CIRCULANDO";
    inf.colorEtiqueta = exito ? #3f9a4a : #d83a34;
    inf.publicado = exito ? "Sacaste las pruebas del servidor del rival: Civitas marcó su publicación como falsa."
        : "No alcanzaste a sacar las pruebas: el bulo del rival siguió en Civitas.";
    inf.verdad = "ERA UN BULO FABRICADO";
    inf.pista = "Lo regaban cuentas creadas el mismo día, todas con el mismo texto: eso es una campaña coordinada.";
    inf.comentarios = exito ? new String[] {"@datos_claros: Confirmado: era un montaje. Gracias por las pruebas.", "@vecina_ana: Y yo que casi lo comparto…"}
        : new String[] {"@juan_23: Ya lo vi en tres grupos, debe ser cierto.", "@profe_luis: ¿Nadie lo ha verificado?"};
    inf.leccion = exito ? "Las vistas que se le ganan a un bulo son gente que no fue engañada."
        : "Si muchas cuentas nuevas repiten lo mismo a la vez, sospecha: puede ser una campaña falsa.";
    mostrarInforme(inf, 400);
}

// ---------------------------------------------------------------------------
// Dibujo del informe (una hoja de papel con letra pixel)
// ---------------------------------------------------------------------------

// El informe es corto y directo: qué era la noticia, por qué (la pista),
// qué impacto tuvo (apoyo y credibilidad) y la enseñanza del turno.
float[] cajaInforme() {
    float w = pcAncho(50), h = altoInforme;
    return new float[] {pcX(50) - w / 2, pcY(50) - h / 2, w, h};
}

float altoInforme = 300;   // se ajusta a lo que tenga cada informe

float[] botonContinuarInforme() {
    float[] c = cajaInforme();
    float k = celdaInforme();
    float w = (medirPixel("CONTINUAR") + 16) * k, h = 15 * k;
    return new float[] {c[0] + c[2] / 2 - w / 2, c[1] + c[3] - h - 7 * k, w, h};
}

float celdaInforme() {
    return max(1, round(camAlto / 260));
}

String miles(int n) {
    String s = str(abs(n));
    String r = "";
    for (int i = 0; i < s.length(); i++) {
        if (i > 0 && (s.length() - i) % 3 == 0) {
            r += ".";
        }
        r += s.charAt(i);
    }
    return (n < 0 ? "-" : "") + r;
}

// Escribe un párrafo partido en líneas y devuelve dónde termina
float parrafoInforme(String texto, float x, float y, float ancho, float k, color c) {
    ArrayList<String> lineas = partirPixel(texto.toUpperCase(), floor(ancho / k));
    for (String l : lineas) {
        textoPixel(l, x, y, k, c, LEFT, TOP);
        y += 10 * k;
    }
    return y;
}

void dibujarInforme() {
    if (!informeVisible()) {
        return;
    }
    Informe inf = informeActual;
    float aparece = constrain((millis() - momentoListoInforme) / 300.0, 0, 1);
    noStroke();
    fill(0, 170 * aparece);
    rect(0, 0, width, height);
    float[] c = cajaInforme();
    float k = celdaInforme();
    pushMatrix();
    translate(0, (1 - facilSalida(aparece)) * pcAlto(10));
    // el papel
    fill(#2b1a2a);
    rect(c[0] - 2 * k, c[1] - 2 * k, c[2] + 4 * k, c[3] + 4 * k);
    fill(#f3e6c8);
    rect(c[0], c[1], c[2], c[3]);
    fill(#3b7fd0);
    rect(c[0], c[1], c[2], 17 * k);
    textoPixel(inf.titulo, c[0] + 8 * k, c[1] + 8.5 * k, k, #ffffff, LEFT, CENTER);
    float x = c[0] + 9 * k, ancho = c[2] - 18 * k;
    float y = c[1] + 25 * k;
    // qué era y por qué
    fill(inf.colorEtiqueta);
    rect(x, y, ancho, 14 * k);
    textoPixel(inf.verdad, x + 6 * k, y + 7 * k, k, #ffffff, LEFT, CENTER);
    y += 20 * k;
    y = parrafoInforme("¿POR QUÉ? " + inf.pista, x, y, ancho, k, #3a2a22) + 6 * k;
    // el impacto
    String apoyo = "APOYO EN " + inf.barrio.toUpperCase() + ": " + (inf.cambioApoyo > 0 ? "+" : "") + inf.cambioApoyo;
    textoPixel(apoyo, x, y, k, inf.cambioApoyo >= 0 ? #3f9a4a : #d83a34, LEFT, TOP);
    y += 11 * k;
    int dif = inf.credDespues - inf.credAntes;
    textoPixel("CREDIBILIDAD: " + inf.credAntes + " A " + inf.credDespues + "  (" + (dif >= 0 ? "+" : "") + dif + ")", x, y, k,
        dif >= 0 ? #3f9a4a : #d83a34, LEFT, TOP);
    y += 15 * k;
    // la enseñanza
    float altoLeccion = (partirPixel(inf.leccion.toUpperCase(), floor((ancho - 12 * k) / k)).size()) * 10 * k + 8 * k;
    fill(#fff6d8);
    rect(x, y, ancho, altoLeccion);
    fill(#e0b33a);
    rect(x, y, 3 * k, altoLeccion);
    parrafoInforme(inf.leccion, x + 8 * k, y + 4 * k, ancho - 12 * k, k, #2b1a2a);
    y += altoLeccion + 8 * k;
    // continuar
    altoInforme = (y - c[1]) + 15 * k + 7 * k;
    float[] b = botonContinuarInforme();
    boolean encima = dentro(b);
    if (encima) {
        pedirCursorMano();
    }
    fill(#2b1a2a);
    rect(b[0], b[1], b[2], b[3]);
    fill(encima ? #e8584d : #4a3040);
    rect(b[0] + k, b[1] + k, b[2] - 2 * k, b[3] - 2 * k);
    textoPixel("CONTINUAR", b[0] + b[2] / 2, b[1] + b[3] / 2, k, #fff3d6, CENTER, CENTER);
    popMatrix();
}

// Devuelve true si el clic era para el informe (y lo cierra)
boolean clicEnInforme() {
    if (!informeVisible()) {
        return false;
    }
    if (millis() - momentoListoInforme > 400) {
        informeVisto = true;   // cualquier clic lo cierra (el botón es la guía)
    }
    return true;
}

// ---------------------------------------------------------------------------
// La credibilidad, siempre a la vista en la oficina
// ---------------------------------------------------------------------------

void dibujarCredibilidad() {
    if (partida == null || enMenu || camaraBajando || camaraSubiendo || estado == MAPA) {
        return;
    }
    float k = max(1, round(camAlto / 300));
    int v = partida.getCredibilidad();
    String texto = "CREDIBILIDAD " + v;
    float w = (medirPixel(texto) + 10) * k + 60 * k;
    float h = 13 * k;
    float x = camX + 6 * k, y = camY + camAlto - h - 6 * k;
    noStroke();
    fill(#1a1010, 210);
    rect(x, y, w, h);
    textoPixel(texto, x + 5 * k, y + h / 2, k, #fff3d6, LEFT, CENTER);
    float bx = x + (medirPixel(texto) + 10) * k, bw = 54 * k;
    fill(#4a3040);
    rect(bx, y + 3 * k, bw, h - 6 * k);
    fill(v >= 60 ? #54e08a : (v >= 35 ? #ffd24a : #ff5c5c));
    rect(bx, y + 3 * k, bw * v / 100.0, h - 6 * k);
}

// ---------------------------------------------------------------------------
// Civitas en vivo: durante los minijuegos del mundo abierto
// ---------------------------------------------------------------------------

int puntajeVistoFeed = 0;
int vistasFeed = 0;
StringList feedComentarios = new StringList();
IntList feedColores = new IntList();
int momentoFeed = 0;

String[] COMENTARIOS_BIEN = {
    "@vecina_ana: ¡Eso! Así se habla con la gente.", "@juan_23: Ya lo compartí en el grupo del barrio.",
    "@profe_luis: Por fin alguien con la información clara.", "@sofi_m: ¡Lo estoy viendo en vivo!", "@datos_claros: Esto sí está verificado."
};
String[] COMENTARIOS_RIVAL = {
    "@troll_9999: ¡El otro candidato va ganando, JAJA!", "@don_pedro: Me llegó un rumor que no sé si creer…",
    "@marta_r: ¿Alguien sabe si eso es verdad?", "@cuenta_nueva_01: ¡COMPARTAN ANTES DE QUE LO BORREN!"
};

void reiniciarFeed() {
    puntajeVistoFeed = 0;
    vistasFeed = 0;
    feedComentarios.clear();
    feedColores.clear();
    momentoFeed = millis();
}

void agregarAlFeed(String s, color c) {
    feedComentarios.append(s);
    feedColores.append(c);
    while (feedComentarios.size() > 4) {
        feedComentarios.remove(0);
        feedColores.remove(0);
    }
}

void dibujarFeedEvento() {
    if (mundo == null || mundo.yo == null || mundo.estadoRonda != mundo.RONDA) {
        if (mundo != null && mundo.estadoRonda != mundo.RONDA && mundo.estadoRonda != mundo.FINAL) {
            reiniciarFeed();
        }
        return;
    }
    int pts = mundo.puntajeDe(mundo.yo);
    if (pts > puntajeVistoFeed) {
        vistasFeed += (pts - puntajeVistoFeed) * (90 + (int) random(60));
        agregarAlFeed(COMENTARIOS_BIEN[(int) random(COMENTARIOS_BIEN.length)], #9fffb0);
    }
    puntajeVistoFeed = pts;
    if (millis() - momentoFeed > 4500) {
        momentoFeed = millis();
        vistasFeed += 20 + (int) random(40);
        agregarAlFeed(COMENTARIOS_RIVAL[(int) random(COMENTARIOS_RIVAL.length)], #ffb0b0);
    }
    float k = max(1, round(height / 360.0));
    float w = 150 * k, h = 70 * k;
    float x = width - w - 8 * k, y = height - h - 8 * k;
    noStroke();
    fill(10, 12, 30, 215);
    rect(x, y, w, h);
    fill(#ff3b3b);
    rect(x + 4 * k, y + 4 * k, 5 * k, 5 * k);
    textoPixel("CIVITAS EN VIVO", x + 12 * k, y + 6.5 * k, k, #ffffff, LEFT, CENTER);
    textoPixel(miles(vistasFeed) + " VISTAS", x + w - 4 * k, y + 6.5 * k, k, #9fd3ff, RIGHT, CENTER);
    float yy = y + 14 * k;
    for (int i = 0; i < feedComentarios.size(); i++) {
        String s = feedComentarios.get(i).toUpperCase();
        float kk = k * 0.75;
        ArrayList<String> l = partirPixel(s, floor((w - 8 * k) / kk));
        for (int j = 0; j < min(2, l.size()); j++) {
            textoPixel(l.get(j), x + 4 * k, yy, max(1, kk), feedColores.get(i), LEFT, TOP);
            yy += 8 * kk;
        }
        yy += 2 * k;
    }
}
