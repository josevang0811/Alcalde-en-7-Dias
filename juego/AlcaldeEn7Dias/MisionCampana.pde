// MisionCampana — la mision Infiltrado dentro de la campana.
//
// Cuando a una ronda de minijuego le toca Infiltrado (Minijuegos.pde), el
// telefono no lo contesta la periodista: llama Valeria, la
// estratega digital de la campana. Cuenta que Titulares Ya va a publicar un
// bulo y que esta noche hay que entrar a su sede a copiar el servidor. Al
// colgar, la pantalla se oscurece y empieza la mision (Infiltrado.pde, en el
// mismo programa). Cuando la mision termina, se vuelve a la oficina con el
// resultado: el apoyo en El Puerto sube o baja, la ronda cuenta como si se
// hubiera publicado y la TV pasa la noticia de lo que paso.
//
// Las habilidades que el candidato ya tiene en el arbol se vuelven
// herramientas de la mision (Volantes da mas botellas, Megafono hace que
// suenen mas fuerte, etc.; ver Campana.pde dentro de Infiltrado.pde).

final int MISION = 5;           // estado de la aplicacion mientras se juega la mision
final int ZONA_BULO = 3;        // El Puerto: el barrio del bulo
final String BULO_MISION = "el agua contaminada de El Puerto";
final int DURACION_A_MISION = 900;   // la pantalla se oscurece antes de empezar

Infiltrado mision;
boolean misionHecha = false;    // ya se jugo en esta campana
int momentoAMision = -1;        // cuando empezo a oscurecerse (o -1)
String titularMision = null;    // la noticia que deja la mision, para la TV
int cambioMision;               // cuanto apoyo gano o perdio en El Puerto

// Se crea una sola vez, al arrancar el juego (carga sus dibujos y sonidos).
void prepararInfiltrado() {
    mision = new Infiltrado();
    mision.prepararMision();
    // las frases fijas de Valeria (las de la misión y las de las tres
    // llamadas) se graban una sola vez para que suenen aunque no haya internet
    StringList llamadas = new StringList();
    for (String f : partesLlamadaMision()) llamadas.append(f);
    for (String f : partesLlamadaEvento(MINI_VOLANTES)) llamadas.append(f);
    for (String f : partesLlamadaEvento(MINI_GENTE)) llamadas.append(f);
    for (String f : partesLlamadaEvento(MINI_LIVES)) llamadas.append(f);
    mision.precargarVoces(llamadas.array());
    precargarVozPeriodista(frasesFijasPeriodista());
    precargarBienvenida();
    if (mision.musica != null) {
        // la canción de calma suena en todo el juego (oficina, mundo abierto);
        // en la misión cambia según lo que pase, como siempre
        mision.musica.momento = mision.M_CALMA;
        mision.musica.volumenUsuario = volumenMusica;
    }
}

// La misión Infiltrado es uno más de los minijuegos (Minijuegos.pde)
boolean esRondaDeMision() {
    return minijuegoDeRonda() == MINI_INFILTRADO;
}

// La llamada de esta ronda es la de Valeria (mientras no se haya jugado).
boolean llamadaDeValeria() {
    return (esRondaDeMision() && !misionHecha) || llamadaDeEvento();
}

// Lo que dice Valeria por telefono, en las cuatro partes de la llamada.
String[] partesLlamadaValeria() {
    if (llamadaDeEvento()) {
        return partesLlamadaEvento(minijuegoDeRonda());   // los del mundo abierto (EventoParque.pde)
    }
    return partesLlamadaMision();
}

String[] partesLlamadaMision() {
    return new String[] {
        "Candidato, soy Valeria. Perdón por llamar así, pero esto no puede esperar.",
        "Titulares Ya va a publicar mañana un bulo sobre " + BULO_MISION + ".",
        "Esta noche entras a su sede, copias el servidor con las pruebas y sales sin que te vean. En el aseo hay uniformes de conserje.",
        "Yo te guío por el auricular. Antes de entrar, estudia bien el plano."
    };
}

// --- La voz de la llamada (Valeria o la periodista) ---
// Si hay voz (Azure, o las frases ya guardadas en data/voz/), cada parte de
// la llamada suena con su voz en vez de las silabas de antes: Valeria con
// la suya y Marta, la periodista, con vozPeriodista. Se piden en otro hilo
// apenas empieza la llamada.

Clip[] vocesValeria;
int parteConVoz = -1;
Clip vozSonando;

void pedirVocesValeria(String[] partes) {
    pedirVocesLlamada(partes, null);
}

// voz: null para la de Valeria
void pedirVocesLlamada(String[] partes, String voz) {
    vocesValeria = new Clip[partes.length];
    parteConVoz = -1;
    if (mision == null || !mision.valeriaConVoz()) {
        return;
    }
    Thread h = new Thread(new PedidoVocesValeria(partes, voz == null ? mision.vozAzure : voz));
    h.setDaemon(true);
    h.start();
}

class PedidoVocesValeria implements Runnable {
    String[] partes;
    String voz;
    Clip[] destino;

    PedidoVocesValeria(String[] partes, String voz) {
        this.partes = partes;
        this.voz = voz;
        destino = vocesValeria;   // si empieza otra llamada, esta no la pisa
    }

    public void run() {
        for (int i = 0; i < partes.length; i++) {
            try {
                destino[i] = mision.vozDeAzure(partes[i], voz);
            } catch (Exception e) {
                println("Voz de la llamada: " + e.getMessage());
            }
        }
    }
}

// Las frases fijas de la periodista (saludos y despedidas) se graban al
// arrancar, para que suenen aunque no haya internet.
void precargarVozPeriodista(String[] frases) {
    if (mision == null || !mision.valeriaConVoz()) {
        return;
    }
    final String[] lista = frases;
    Thread h = new Thread(new Runnable() {
        public void run() {
            for (String f : lista) {
                java.io.File g = new java.io.File(dataPath("voz/" + mision.vozPeriodista + "_" + Integer.toHexString(f.hashCode()) + ".wav"));
                if (g.exists()) {
                    continue;
                }
                try {
                    mision.vozDeAzure(f, mision.vozPeriodista).close();
                } catch (Exception e) {
                    return;   // sin internet: se intenta la proxima vez
                }
            }
        }
    });
    h.setDaemon(true);
    h.start();
}

boolean valeriaTieneVoz() {
    return vocesValeria != null && vocesValeria[0] != null;
}

// En que parte de la llamada va la escritura (0 a 3).
int parteActualLlamada() {
    int letras = letrasVisibles();
    for (int p = 0; p < partesLlamada.length; p++) {
        letras -= partesLlamada[p].length();
        if (letras < 0) {
            return p;
        }
    }
    return partesLlamada.length - 1;
}

// Cuando empieza a escribirse una parte, suena su frase (si ya llego). La
// escritura espera a que termine la anterior (Llamada.pde, actualizarEsperaVoz).
void actualizarVozValeria() {
    int p = parteActualLlamada();
    if (p == parteConVoz || vocesValeria == null || vocesValeria[p] == null) {
        return;
    }
    if (vozSonando != null) {
        vozSonando.stop();
    }
    vozSonando = vocesValeria[p];
    vozSonando.setFramePosition(0);
    vozSonando.start();
    parteConVoz = p;
    esperaSiguiente = 0;
}

// --- Ir a la mision y volver ---

// Al colgar Valeria, la pantalla se empieza a oscurecer.
void alColgarValeria() {
    if (llamadaDeEvento()) {
        alColgarEvento();
        return;
    }
    momentoAMision = millis();
}

// Encima de la oficina mientras se oscurece; al terminar, empieza la mision.
void dibujarIdaAMision() {
    if (momentoAMision < 0) {
        return;
    }
    float t = constrain((millis() - momentoAMision) / (float) DURACION_A_MISION, 0, 1);
    noStroke();
    fill(0, 255 * t);
    rect(0, 0, width, height);
    if (t >= 1) {
        momentoAMision = -1;
        empezarMision();
    }
}

// Las habilidades del arbol que la mision sabe usar como herramientas.
StringList herramientasDelArbol() {
    StringList lista = new StringList();
    for (Nodo n : arbol.preorden()) {
        if (n.getDesbloqueada() && n != arbol.getRaiz()) {
            lista.append(n.getNombre());
        }
    }
    return lista;
}

void empezarMision() {
    GrafoCiudad ciudad = partida.getCiudad();
    // El barrio de la mision es el del bulo: ahi cambia el apoyo al volver.
    mision.configurarCampana(ciudad.getNombre(ZONA_BULO), partida.getApoyo(ZONA_BULO),
        BULO_MISION, herramientasDelArbol());
    mision.llamadaHecha = true;   // la llamada ya la hizo el juego principal
    mision.numJugadores = 1;
    mision.reintentarMision();    // deja la mision lista en la eleccion de rol
    mision.ultimoMillis = millis();
    estado = MISION;
}

// La llama la mision al terminar (Enter en su pantalla final).
void volverALaCampana() {
    boolean exito = mision.estado == mision.GANASTE;
    // Exito: +25, mas el botin y +5 por cada oportunidad. Fracaso: -15
    // (la cuenta esta en la mision, que tambien la muestra en su pantalla final).
    int valor = mision.cambioApoyo(exito);
    cambioMision = partida.registrarMision(ZONA_BULO, valor);
    informeDeMision(exito, cambioMision);   // Impacto.pde
    titularMision = mision.proximaNoticia(exito);
    misionHecha = true;
    if (mision.musica != null) {
        mision.musica.momento = mision.M_CALMA;   // de vuelta en la oficina, la calma
    }
    mision.callarValeria();
    estado = MENU;
    fotoOficina = null;
    marcarApertura();
    GrafoCiudad ciudad = partida.getCiudad();
    String cambio = (cambioMision >= 0 ? "+" : "") + cambioMision;
    avisar(exito ? "¡Misión cumplida! " + cambio + " de apoyo en " + ciudad.getNombre(ZONA_BULO) + ". Pasa turno desde el libro."
        : "La misión salió mal: " + cambio + " de apoyo en " + ciudad.getNombre(ZONA_BULO) + ". Pasa turno desde el libro.");
    mostrarTextoFlotante(cambio, cambioMision >= 0 ? COLOR_EXITO : COLOR_ERROR);
}

// Una campana nueva vuelve a tener su mision.
void reiniciarMisionCampana() {
    misionHecha = false;
    titularMision = null;
    momentoAMision = -1;
}
