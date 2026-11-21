// Llamada — el telefono rojo de la oficina.
//
// Al empezar cada turno suena el telefono: vibra, timbra y, mientras suena,
// es lo unico de la oficina que responde (el cuaderno y lo demas avisan que
// primero hay que contestar; la ayuda y la puerta si funcionan). Al hacer
// clic se contesta: el auricular sube al frente de la pantalla y la
// periodista cuenta la noticia de ultima hora, letra por letra. La llamada
// no se puede adelantar ni colgar: cuando la periodista termina de hablar,
// y despues de un momento para leer, se corta sola ("tu, tu, tu") y el
// auricular vuelve a su base. La noticia no se repite (salvo con la Libreta
// de notas del arbol), asi que hay que prestar atencion.
//
// La llamada es una secuencia de fases. Igual que las demas animaciones del
// juego, cada fase guarda el momento (millis) en que empezo y cada cuadro se
// calcula que tan avanzada va: no hacen falta hilos ni temporizadores.

final int LLAMADA_NINGUNA = 0;      // no hay llamada: la campana termino
final int LLAMADA_POR_SONAR = 1;    // empezo el turno: en un momento suena
final int LLAMADA_SONANDO = 2;      // vibra y timbra hasta que contesten
final int LLAMADA_CONTESTANDO = 3;  // el auricular sube al frente
final int LLAMADA_HABLANDO = 4;     // la periodista cuenta la noticia
final int LLAMADA_CORTADA = 5;      // "tu, tu, tu": la periodista colgo
final int LLAMADA_COLGANDO = 6;     // el auricular vuelve a su base
final int LLAMADA_ATENDIDA = 7;     // ya se oyo la noticia de este turno

final int ESPERA_ANTES_DE_SONAR = 1200;
final int CICLO_TIMBRE = 2600;      // cada cuanto se repite el "ring, ring"
final int DURACION_CONTESTAR = 650;
final int DURACION_CORTE = 700;     // lo que dura el "tu, tu" (corto: que cuelgue rápido)
final int DURACION_COLGAR = 380;
final int MS_POR_LETRA = 24;   // un poco más rápido, al ritmo de las voces (+25%)
// La llamada de la periodista dura como mucho 10 s: dice el titular y quién
// lo publicó, y cuelga. Los comentarios los cuenta Nico en el celular.
final int MAX_LLAMADA = 10000;

int faseLlamada = LLAMADA_NINGUNA;
// Con la Libreta de notas del arbol se puede volver a oir la noticia, una
// sola vez por turno.
boolean repeticionUsada = false;
int momentoFaseLlamada;
int timbresTocados;            // cuantos "ring, ring" van en esta fase

// Lo que dice la periodista, en cuatro partes: saludo, titular, de donde
// salio la noticia y despedida. Cada parte se escribe con su propia letra.
String[] partesLlamada;
int[] momentosLetras;          // en que momento (ms) aparece cada letra
int finEscritura;              // cuando termina de escribirse todo
int letrasConVoz;              // hasta que letra ya sono la voz
int momentoUltimaVoz;

// Donde queda el auricular cuando esta al frente (coordenadas del lienzo de
// la oficina): a la derecha, parado, grande, como en el dibujo del equipo.

// ===========================================================================
// FASES
// ===========================================================================

// Se llama al empezar cada turno (al cerrar la portada, al pasar turno y al
// empezar una campana nueva).
void prepararLlamadaDelTurno() {
    repeticionUsada = false;
    if (partidaTerminada()) {
        cambiarFaseLlamada(LLAMADA_NINGUNA);
    } else {
        cambiarFaseLlamada(LLAMADA_POR_SONAR);
    }
}

// Cambia de fase y hace los sonidos que van con cada cambio.
void cambiarFaseLlamada(int fase) {
    if (faseLlamada == LLAMADA_SONANDO) {
        sonidos.pararTimbre();
    }
    if (faseLlamada == LLAMADA_CORTADA) {
        sonidos.pararOcupado();
    }
    faseLlamada = fase;
    momentoFaseLlamada = millis();
    timbresTocados = 0;
    esperaVoz = 0;
    esperaSiguiente = 0;
    ultimoCuadroLlamada = millis();
    if (fase == LLAMADA_CONTESTANDO) {
        sonidos.tocarDescolgar();
    } else if (fase == LLAMADA_CORTADA) {
        sonidos.tocarOcupado();
    } else if (fase == LLAMADA_ATENDIDA) {
        sonidos.tocarColgar();
    }
}

int tiempoEnFase() {
    return millis() - momentoFaseLlamada;
}

// Se llama al principio de cada draw(): hace avanzar las fases que cambian
// solas, con el tiempo.
void actualizarLlamada() {
    actualizarBienvenida();
    actualizarMusicaJuego();   // Opciones.pde
    if (faseLlamada == LLAMADA_POR_SONAR) {
        actualizarPorSonar();
    } else if (faseLlamada == LLAMADA_SONANDO) {
        actualizarTimbre();
    } else if (faseLlamada == LLAMADA_CONTESTANDO && tiempoEnFase() >= DURACION_CONTESTAR) {
        cambiarFaseLlamada(LLAMADA_HABLANDO);
        letrasConVoz = -1;
    } else if (faseLlamada == LLAMADA_HABLANDO) {
        actualizarEsperaVoz();
        actualizarVoz();
        // no se cuelga mientras la voz sigue hablando: el texto no se quita
        // antes de que termine de decirlo (el tope es solo por si algo falla)
        boolean vozTodaviaSuena = vozSonando != null && vozSonando.isRunning();
        int tope = llamadaDeValeria() ? 45000 : (llamadaDeEncargo() ? MAX_LLAMADA_ENCARGO : MAX_LLAMADA);
        boolean seAcaboElTope = tiempoEnFase() >= tope;
        if ((tiempoEnFase() - esperaVoz >= finEscritura + pausaDeLectura() && !vozTodaviaSuena) || seAcaboElTope) {
            if (seAcaboElTope && vozSonando != null) {
                vozSonando.stop();   // a los 10 s se cuelga aunque no haya terminado
            }
            cambiarFaseLlamada(LLAMADA_CORTADA);
        }
    } else if (faseLlamada == LLAMADA_CORTADA && tiempoEnFase() >= DURACION_CORTE) {
        cambiarFaseLlamada(LLAMADA_COLGANDO);
    } else if (faseLlamada == LLAMADA_COLGANDO && tiempoEnFase() >= DURACION_COLGAR) {
        cambiarFaseLlamada(LLAMADA_ATENDIDA);
        if (llamadaDeValeria()) {
            alColgarValeria();   // al colgar Valeria empieza la mision (MisionCampana.pde)
        } else {
            empezarEncargo();   // al colgar corren los 10 segundos del encargo (Encargo.pde)
        }
    }
}

// El telefono solo suena con la oficina a la vista. Si el jugador esta en
// la ayuda, la cuenta vuelve a empezar al regresar.
void actualizarPorSonar() {
    if (estado != MENU || mostrarPortada || saliendo || transicionDiaActiva()) {
        momentoFaseLlamada = millis();
    } else if (tiempoEnFase() >= ESPERA_ANTES_DE_SONAR) {
        cambiarFaseLlamada(LLAMADA_SONANDO);
    }
}

// Cada CICLO_TIMBRE se toca otra vez el sonido del "ring, ring". Fuera de
// la oficina (en la ayuda, o saliendo por la puerta) el timbre se calla.
void actualizarTimbre() {
    if (estado != MENU || saliendo) {
        sonidos.pararTimbre();
        momentoFaseLlamada = millis();
        timbresTocados = 0;
        return;
    }
    int ciclo = tiempoEnFase() / CICLO_TIMBRE;
    if (ciclo >= timbresTocados) {
        sonidos.tocarTimbre();
        timbresTocados = ciclo + 1;
    }
}

// El sonido tiene dos rafagas: de 0 a 400 ms y de 600 a 1000 ms de cada
// ciclo. El telefono vibra solo mientras suena alguna.
boolean timbreSonandoAhora() {
    if (faseLlamada != LLAMADA_SONANDO) {
        return false;
    }
    int t = tiempoEnFase() % CICLO_TIMBRE;
    return t < 400 || (t >= 600 && t < 1000);
}

// 0 en la primera rafaga del ciclo y 1 en la segunda.
int rafagaActual() {
    return (tiempoEnFase() % CICLO_TIMBRE) < 500 ? 0 : 1;
}

// --- Preguntas que se hace el resto de la interfaz ---

boolean telefonoSonando() {
    return faseLlamada == LLAMADA_SONANDO;
}

// Mientras se ve la escena de la llamada (auricular al frente, globo).
boolean llamadaEnPantalla() {
    return faseLlamada >= LLAMADA_CONTESTANDO && faseLlamada <= LLAMADA_COLGANDO;
}

boolean auricularEnSuBase() {
    return !llamadaEnPantalla();
}

// Mientras el telefono suena (o esta por sonar), el resto de la oficina
// espera. La ayuda, la puerta y el cajon (volver al menu) siguen
// funcionando: no son parte del turno.
boolean bloqueadoPorLlamada(ObjetoOficina o) {
    boolean esperando = faseLlamada == LLAMADA_POR_SONAR || faseLlamada == LLAMADA_SONANDO;
    return esperando && o != objetoTelefono && o != objetoPostit && o != objetoPuerta && o != objetoCajon;
}

// Lo que dice la etiqueta del telefono segun la fase.
String accionTelefono() {
    if (partidaTerminada()) {
        return "La campaña terminó";
    } else if (faseLlamada == LLAMADA_SONANDO) {
        return "¡Está sonando! Clic para contestar";
    } else if (faseLlamada == LLAMADA_POR_SONAR) {
        return "Está por sonar...";
    } else if (faseLlamada == LLAMADA_ATENDIDA) {
        if (puedeRepetirLlamada()) {
            return "Libreta: clic para volver a oír (1 vez)";
        }
        if (telefonoHumeando) {
            return "El mensaje se autodestruyó";
        }
        return repeticionUsada ? "Ya volviste a oír la noticia" : "Ya colgaron";
    }
    return "La campaña terminó";
}

// La noticia se oye una sola vez: para volver a oirla hace falta la Libreta
// de notas, y solo sirve una vez por turno.
boolean puedeRepetirLlamada() {
    return faseLlamada == LLAMADA_ATENDIDA && !repeticionUsada && arbol.tiene(ArbolHabilidades.LIBRETA) && !esRondaEspecial();
}

// ===========================================================================
// CLICS
// ===========================================================================

void clicEnTelefono() {
    if (partidaTerminada()) {
        avisar("La campaña terminó: ya no hay más llamadas.");
    } else if (faseLlamada == LLAMADA_SONANDO) {
        contestarTelefono(false);
    } else if (puedeRepetirLlamada()) {
        repeticionUsada = true;
        contestarTelefono(true);
    } else if (faseLlamada == LLAMADA_ATENDIDA && telefonoHumeando) {
        avisar("El mensaje se autodestruyó. Mañana llega otro encargo.");
    } else if (faseLlamada == LLAMADA_ATENDIDA) {
        avisar(repeticionUsada ? "Ya volviste a oír la noticia en este turno."
            : "Ya colgaron. Con la «Libreta de notas» del árbol puedes volver a oír la noticia.");
    } else if (faseLlamada == LLAMADA_POR_SONAR) {
        avisar("Espera un momento: el teléfono está por sonar.");
    }
}

// Arma lo que va a decir la periodista y levanta el auricular. "repetir" es
// true cuando el jugador levanta otra vez el telefono para volver a oir la
// noticia del turno (con la Libreta de notas).
void contestarTelefono(boolean repetir) {
    Noticia n = partida.getNoticiaDelTurno();
    // La noticia viene de una publicación de Civitas. Para que la llamada no
    // pase de 10 s, la periodista solo dice de qué se trata y quién la hizo;
    // los comentarios los cuenta Nico en el celular. El tipo real no se dice.
    partesLlamada = frasesCortasDeNoticia(n);
    if (llamadaDeEncargo()) {
        partesLlamada = frasesEncargo(n);   // la llamada como misión secreta (Encargo.pde)
        empezarMusicaEncargo();
    }
    // En la ronda de la mision llama Valeria (MisionCampana.pde).
    if (llamadaDeValeria()) {
        partesLlamada = partesLlamadaValeria();
        pedirVocesValeria(partesLlamada);
    } else {
        pedirVocesLlamada(partesLlamada, mision.vozPeriodista);   // la periodista también habla
    }
    calcularMomentosLetras();
    textoAviso = null;  // el aviso de abajo ("primero contesta...") ya no hace falta
    cambiarFaseLlamada(LLAMADA_CONTESTANDO);
}

// Lo que dice la periodista de una noticia: el titular y quién la publicó (y
// si viene cargada de odio). Son las mismas frases que se graban al arrancar.
String[] frasesCortasDeNoticia(Noticia n) {
    String autor = "Lo publicó " + n.describirAutor() + ".";
    if (n.generaOdio()) {
        autor += " Y está lleno de mensajes de odio.";
    }
    return new String[] {
        "Candidato, en Civitas dicen que " + n.getTitular() + ".",
        autor
    };
}

// Los saludos y despedidas, para grabar su voz al arrancar.
String[] frasesFijasPeriodista() {
    return new String[] {
        "¡Aló, candidato! Le habla " + Noticiero.PERIODISTA + ", del " + Noticiero.MEDIO + ". Tengo una de última hora:",
        "¿Aló? Marta otra vez. Le cuento lo último:",
        "¡Qué bueno que contesta! Acaba de llegarme esto:",
        "Aló, candidato. Esto se está moviendo mucho:",
        "Marta Ríos, del Noticiero. Anote esto:",
        "¿Me escucha? Le tengo una noticia:",
        "Le repito lo que le conté:",
        "Eso era todo.",
        "Lo dejo, que me entra otra llamada.",
        "Eso es todo por ahora. ¡Suerte en la campaña!",
        "Tengo que colgar, me esperan en el canal.",
        "Si sé algo más, lo llamo. ¡Hasta luego!",
        "Me tengo que ir. ¡Que le vaya bien!"
    };
}

// ===========================================================================
// LETRA POR LETRA
// ===========================================================================

// Calcula de una vez en que momento aparece cada letra: normalmente cada
// MS_POR_LETRA, con una pausa despues de un punto o una coma (como cuando
// alguien habla) y otra mas larga entre una parte y la siguiente.
void calcularMomentosLetras() {
    int total = 0;
    for (String parte : partesLlamada) {
        total += parte.length();
    }
    momentosLetras = new int[total];
    int t = 0;
    int i = 0;
    for (String parte : partesLlamada) {
        for (int k = 0; k < parte.length(); k++) {
            t += MS_POR_LETRA;
            momentosLetras[i] = t;
            i++;
            char c = parte.charAt(k);
            if (c == '.' || c == '!' || c == '?' || c == ':') {
                t += 220;
            } else if (c == ',' || c == ';') {
                t += 100;
            }
        }
        t += 320;
    }
    finEscritura = t;
}

// Cuantas letras se ven ahora. Despues de que la periodista termina (cuando
// se corta la llamada) se ve todo.
int letrasVisibles() {
    if (faseLlamada != LLAMADA_HABLANDO) {
        return momentosLetras.length;
    }
    int transcurrido = tiempoEnFase() - esperaVoz;
    int cuantas = 0;
    while (cuantas < momentosLetras.length && momentosLetras[cuantas] <= transcurrido) {
        cuantas++;
    }
    return cuantas;
}

// Con la voz de Valeria, el texto espera a la voz: si una frase termina de
// escribirse y Valeria todavia la esta diciendo, la escritura se detiene
// hasta que acabe (antes la siguiente parte cortaba la anterior). Si la voz
// de la parte que sigue aun no llega, se espera hasta 2 s por ella.
int esperaVoz;             // ms que la escritura lleva detenida
int esperaSiguiente;       // ms esperando la voz de la parte que sigue
int ultimoCuadroLlamada;

void actualizarEsperaVoz() {
    int ahora = millis();
    int dt = constrain(ahora - ultimoCuadroLlamada, 0, 100);
    ultimoCuadroLlamada = ahora;
    if (!valeriaTieneVoz() || parteConVoz < 0) {
        return;
    }
    int letras = letrasVisibles();
    int finParte = 0;
    for (int p = 0; p <= parteConVoz && p < partesLlamada.length; p++) {
        finParte += partesLlamada[p].length();
    }
    if (letras < finParte) {
        return;
    }
    if (vozSonando != null && vozSonando.isRunning()) {
        esperaVoz += dt;
    } else if (parteConVoz + 1 < partesLlamada.length && vocesValeria[parteConVoz + 1] == null && esperaSiguiente < 2000) {
        esperaVoz += dt;
        esperaSiguiente += dt;
    }
}

// Tiempo para terminar de leer despues de que se escribio todo: mas largo
// si el texto es largo, pero nunca mas de 5 segundos.
int pausaDeLectura() {
    if (!llamadaDeValeria()) {
        return 400;   // termina de hablar y cuelga
    }
    return min(900 + momentosLetras.length * 3, 1800);
}

// Mientras aparecen letras, suena una silaba de la voz cada dos letras (sin
// contar espacios ni signos). Si en un cuadro aparecen varias letras, no
// suenan todas de golpe: solo la ultima.
void actualizarVoz() {
    if (valeriaTieneVoz()) {
        actualizarVozValeria();   // con voz de verdad (Valeria o la periodista)
        return;
    }
    int ultima = letrasVisibles() - 1;  // la letra que acaba de aparecer
    if (ultima < letrasConVoz + 2) {
        return;  // todavia no van dos letras desde la ultima silaba
    }
    letrasConVoz = ultima;
    if (millis() - momentoUltimaVoz >= 70 && Character.isLetterOrDigit(letraNumero(ultima))) {
        sonidos.tocarVoz(ultima / 2);
        momentoUltimaVoz = millis();
    }
}

// La letra numero i contando todas las partes seguidas.
char letraNumero(int i) {
    for (String parte : partesLlamada) {
        if (i < parte.length()) {
            return parte.charAt(i);
        }
        i -= parte.length();
    }
    return ' ';
}

// ===========================================================================
// DIBUJO: EL TELEFONO SONANDO
// ===========================================================================

// Cuanto se mueve el telefono en este cuadro: {corrimiento, giro, salto del
// auricular}. Solo se mueve mientras suena una rafaga del timbre.
float[] vibracionTelefono() {
    if (!timbreSonandoAhora() || !auricularEnSuBase()) {
        return new float[] {0, 0, 0};
    }
    float t = millis();
    float corrimiento = sin(t * 0.11) * 1.6;
    float giro = sin(t * 0.083) * 0.022;
    float salto = abs(sin(t * 0.06)) * 5;
    return new float[] {corrimiento, giro, salto};
}

// Encima del telefono que suena: las rayitas amarillas de vibracion (como
// en el dibujo), el "¡RIIING!" de cada rafaga y una burbuja que invita a
// contestar. Se dibuja dentro del lienzo de la oficina.
void dibujarAvisoTimbre() {
    if (faseLlamada != LLAMADA_SONANDO) {
        return;
    }
    if (timbreSonandoAhora()) {
        dibujarRayasVibracion(900, 432, -1);
        dibujarRayasVibracion(1074, 432, 1);
        dibujarOnomatopeya();
    }
    if (objetoResaltado != objetoTelefono) {
        float rebote = sin(millis() * 0.006) * 5;
        dibujarBurbujaPista("¡Contesta!", 987, 330 + rebote);
    }
}

// Tres arcos que se abren hacia un lado ("lado" es -1 a la izquierda y 1 a
// la derecha). Se dibujan dos veces: grueso en negro y encima delgado en
// amarillo, asi el amarillo se ve sobre la pared crema.
void dibujarRayasVibracion(float x, float y, int lado) {
    float pulso = 1 + 0.08 * sin(millis() * 0.05);
    float inicio = lado < 0 ? PI - 0.7 : -0.7;
    noFill();
    for (int capa = 0; capa < 2; capa++) {
        if (capa == 0) {
            stroke(COLOR_CONTORNO);
            strokeWeight(6.5);
        } else {
            stroke(COLOR_AMARILLO);
            strokeWeight(3.2);
        }
        for (int i = 1; i <= 3; i++) {
            float r = (12 + i * 11) * pulso;
            arc(x, y, r * 2, r * 2, inicio, inicio + 1.4);
        }
    }
}

// "¡RIIING!" en letra de historieta: una vez a cada lado del telefono, una
// por cada rafaga del timbre. Sirve tambien a quien juega sin sonido.
void dibujarOnomatopeya() {
    int t = tiempoEnFase() % CICLO_TIMBRE;
    int inicioRafaga = rafagaActual() == 0 ? 0 : 600;
    float crecer = constrain((t - inicioRafaga) / 90.0, 0, 1);
    float x = rafagaActual() == 0 ? 846 : 1120;
    float giro = rafagaActual() == 0 ? -0.16 : 0.16;
    pushMatrix();
    translate(x, 392);
    rotate(giro);
    scale(0.7 + 0.3 * crecer);
    usarLetraEscena(LETRA_TITULO, 30);
    textAlign(CENTER, CENTER);
    textoConContorno("¡RIIING!", 0, 0, 2.6, COLOR_AMARILLO, COLOR_CONTORNO, 255);
    popMatrix();
}

// Burbuja naranja con una punta hacia abajo, la misma de "¡Empieza aquí!"
// sobre el cuaderno. (cx, y) es el centro de arriba de la burbuja.
void dibujarBurbujaPista(String texto, float cx, float y) {
    usarLetraEscena(LETRA_NEGRITA, 15);
    float ancho = textWidth(texto) + 26;
    float alto = 30;
    stroke(COLOR_CONTORNO);
    strokeWeight(2.5);
    fill(COLOR_NARANJA);
    triangle(cx - 9, y + alto - 1, cx + 9, y + alto - 1, cx, y + alto + 11);
    rect(cx - ancho / 2, y, ancho, alto, 10);
    noStroke();
    triangle(cx - 7.5, y + alto - 3, cx + 7.5, y + alto - 3, cx, y + alto + 7);
    fill(COLOR_BLANCO);
    textAlign(CENTER, CENTER);
    text(texto, cx, y + alto / 2 - 1);
}

// ===========================================================================
// DIBUJO: LA ESCENA DE LA LLAMADA
// ===========================================================================

// Que tan arriba esta el auricular: 0 en su base, 1 al frente.
float auricularLevantado() {
    if (faseLlamada == LLAMADA_CONTESTANDO) {
        return subirConRebote(tiempoEnFase() / (float) DURACION_CONTESTAR);
    } else if (faseLlamada == LLAMADA_HABLANDO || faseLlamada == LLAMADA_CORTADA) {
        return 1;
    } else if (faseLlamada == LLAMADA_COLGANDO) {
        return 1 - suavizar(tiempoEnFase() / (float) DURACION_COLGAR);
    }
    return 0;
}

// Curva de animacion que arranca y frena suave.
float suavizar(float t) {
    t = constrain(t, 0, 1);
    return t * t * (3 - 2 * t);
}

// Llega un poquito mas alla del final y vuelve: da la sensacion de que el
// auricular se levanto con fuerza.
float subirConRebote(float t) {
    t = constrain(t, 0, 1) - 1;
    return 1 + 2.7 * t * t * t + 1.7 * t * t;
}

// La escena completa: la oficina cambia por su version oscura sin el
// auricular, el auricular del dibujo sube desde abajo hasta la derecha y se
// queda balanceandose, y a su lado el globo con lo que dice la periodista.
// Todo en coordenadas del lienzo de la oficina.
void dibujarEscenaLlamada() {
    if (!llamadaEnPantalla()) {
        return;
    }
    float levantado = auricularLevantado();
    tint(255, 255 * constrain(levantado * 1.6, 0, 1));
    image(imgSinAuricular, 0, 0, ANCHO_ESCENA, ALTO_ESCENA);
    noTint();

    // El auricular ocupa el rectangulo del prototipo (70.8 %, 8.7 %, 27.5 % x
    // 84.9 %) y empieza 113.6 % de su alto mas abajo, fuera de la pantalla.
    float w = exPc(27.5);
    float h = eyPc(84.888);
    float[] v = vaiven(1.6, 0);
    float dy = (1 - levantado) * h * 1.13582;
    pushMatrix();
    translate(exPc(70.781) + w / 2 + v[0] * w, eyPc(8.675) + h / 2 + v[1] * h + dy);
    rotate(v[2]);
    image(imgAuricular, -w / 2, -h / 2, w, h);
    popMatrix();

    if (faseLlamada == LLAMADA_HABLANDO || faseLlamada == LLAMADA_CORTADA) {
        dibujarGloboLlamada();
    }
}

// --- El globo de la periodista ---

// Medidas del globo en el lienzo de la oficina.
final float GLOBO_X = 90;
final float GLOBO_Y = 58;
final float GLOBO_ANCHO = 720;
final float GLOBO_MARGEN = 26;

// Letra y tamano de cada parte: el titular va mas grande y en negrita para
// que sea lo primero que se lee.
int letraParte(int parte) {
    return parte == 1 ? LETRA_NEGRITA : LETRA_TEXTO;
}

float tamanoParte(int parte) {
    return parte == 1 ? 25 : 19;
}

color colorParte(int parte) {
    if (parte == 3 && llamadaDeEncargo()) {
        return COLOR_ROJO;   // "este mensaje se autodestruirá"
    }
    if (parte == 1) {
        return COLOR_TEXTO;
    } else if (parte == 2) {
        return COLOR_GRIS_OSCURO;
    }
    return COLOR_TEXTO;
}

// El globo se abre haciendose un poco mas grande, y su alto se mide con
// todo el texto (no con lo que va escrito) para que no crezca mientras la
// periodista habla.
void dibujarGloboLlamada() {
    float anchoTexto = GLOBO_ANCHO - GLOBO_MARGEN * 2;
    float altoCabecera = 34;
    float altoPista = 30;
    float alto = GLOBO_MARGEN + altoCabecera + altoTextoLlamada(anchoTexto) + altoPista + GLOBO_MARGEN * 0.7;
    float aparecer = 1;
    if (faseLlamada == LLAMADA_HABLANDO) {
        aparecer = suavizar(tiempoEnFase() / 180.0);
    }

    pushMatrix();
    float cx = GLOBO_X + GLOBO_ANCHO / 2;
    float cy = GLOBO_Y + alto / 2;
    translate(cx, cy);
    scale(0.92 + 0.08 * aparecer);
    translate(-cx, -cy);
    dibujarFormaGlobo(GLOBO_X, GLOBO_Y, GLOBO_ANCHO, alto);
    float yTexto = dibujarCabeceraLlamada(GLOBO_X + GLOBO_MARGEN, GLOBO_Y + GLOBO_MARGEN * 0.8);
    dibujarTextoLlamada(GLOBO_X + GLOBO_MARGEN, yTexto + 8, anchoTexto);
    dibujarPistaLlamada(GLOBO_X + GLOBO_ANCHO - GLOBO_MARGEN, GLOBO_Y + alto - GLOBO_MARGEN * 0.6);
    popMatrix();
}

// El globo de papel del equipo (globo_llamada.png), estirado al tamaño del
// texto: el cuerpo ocupa el 92 % del ancho del dibujo y la punta sale a la
// derecha, hacia el auricular.
PImage imgGloboLlamada;

void dibujarFormaGlobo(float x, float y, float ancho, float alto) {
    if (imgGloboLlamada == null) {
        imgGloboLlamada = loadImage("globo_llamada.png");
    }
    float extra = alto * 0.06;
    image(imgGloboLlamada, x - ancho * 0.03, y - extra, ancho / 0.92 + ancho * 0.03, alto + extra * 2);
}

// Arriba del globo: la etiqueta roja de "ULTIMA HORA" (la misma del
// noticiero de la TV) y quien llama. Devuelve donde empieza el texto.
float dibujarCabeceraLlamada(float x, float y) {
    usarLetraEscena(LETRA_NEGRITA, 14);
    boolean valeria = llamadaDeValeria();
    boolean encargo = llamadaDeEncargo();
    String etiqueta = valeria ? (llamadaDeEvento() ? "EVENTO" : "MISIÓN") : (encargo ? "ENCARGO SECRETO" : "ÚLTIMA HORA");
    float anchoEtiqueta = textWidth(etiqueta) + 20;
    noStroke();
    fill(valeria ? #7a4fc0 : (encargo ? #1a1a1a : COLOR_ROJO));
    rect(x, y, anchoEtiqueta, 26, 4);
    fill(COLOR_BLANCO);
    textAlign(LEFT, CENTER);
    text(etiqueta, x + 10, y + 12);

    fill(COLOR_TEXTO);
    usarLetraEscena(LETRA_NEGRITA, 16);
    text(valeria ? "Valeria  ·  Estrategia digital de tu campaña" : (encargo ? Noticiero.PERIODISTA + "  ·  mensaje cifrado" : Noticiero.PERIODISTA + "  ·  " + Noticiero.MEDIO), x + anchoEtiqueta + 12, y + 12);
    return y + 34;
}

// Alto que ocupa todo el texto de la llamada (las cuatro partes completas).
float altoTextoLlamada(float ancho) {
    float alto = 0;
    for (int p = 0; p < partesLlamada.length; p++) {
        usarLetraEscena(letraParte(p), tamanoParte(p));
        alto += partirEnLineas(partesLlamada[p], ancho).size() * interlineado() + separacionParte();
    }
    return alto;
}

float separacionParte() {
    return 9;
}

// Escribe las cuatro partes hasta la letra que toca. Cada parte se parte en
// lineas con su texto completo antes de escribirla: asi una palabra no
// salta de una linea a otra mientras va apareciendo.
void dibujarTextoLlamada(float x, float y, float ancho) {
    int quedan = letrasVisibles();
    textAlign(LEFT, TOP);
    for (int p = 0; p < partesLlamada.length; p++) {
        usarLetraEscena(letraParte(p), tamanoParte(p));
        fill(colorParte(p));
        ArrayList<String> lineas = partirEnLineas(partesLlamada[p], ancho);
        float paso = interlineado();
        for (String linea : lineas) {
            if (quedan > 0) {
                text(linea.substring(0, min(quedan, linea.length())), x, y);
            }
            quedan -= linea.length() + 1;  // + 1 por el espacio donde se partio
            y += paso;
        }
        // El espacio del final de la ultima linea no existe: se devuelve.
        quedan += 1;
        y += separacionParte();
    }
}

// Abajo a la derecha: un recordatorio de que la noticia no se repite, o el
// "tu, tu, tu" cuando se corta la llamada (cada "tu" aparece con su pitido).
void dibujarPistaLlamada(float xDerecha, float yAbajo) {
    textAlign(RIGHT, BOTTOM);
    if (faseLlamada == LLAMADA_CORTADA) {
        int tus = min(3, 1 + tiempoEnFase() / 250);
        String texto = "Se cortó la llamada ·";
        for (int i = 0; i < tus; i++) {
            texto += " tu...";
        }
        fill(COLOR_ROJO_OSCURO);
        usarLetraEscena(LETRA_NEGRITA, 16);
        text(texto, xDerecha, yAbajo);
        return;
    }
    float parpadeo = 0.75 + 0.25 * sin(millis() * 0.006);
    fill(COLOR_GRIS_OSCURO, 255 * parpadeo);
    usarLetraEscena(LETRA_NEGRITA, 14);
    if (llamadaDeValeria()) {
        text(llamadaDeEvento() ? "Prepárate: al colgar sales al parque" : "Prepárate: al colgar empieza la misión", xDerecha, yAbajo);
        return;
    }
    if (llamadaDeEncargo() && !repeticionUsada) {
        fill(COLOR_ROJO, 255 * parpadeo);
        text("Al colgar tienes 10 segundos", xDerecha, yAbajo);
        return;
    }
    text(repeticionUsada ? "Libreta de notas: no la vuelves a oír en este turno" : "Escucha bien: la noticia no se repite",
        xDerecha, yAbajo);
}
