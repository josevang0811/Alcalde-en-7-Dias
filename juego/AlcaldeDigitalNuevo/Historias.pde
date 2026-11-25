// Historias — las personas de Ciudad Nova a las que les llega la noticia.
//
// Algunos días la noticia del encargo no sale al azar del mazo: es la de una
// historia (Noticiero.historiaDelDia). Antes de que suene el teléfono se ve
// a la persona de la que habla la noticia, y al terminar el día, antes de la
// pantalla negra, se ve qué le pasó según lo que hizo el jugador.
//
// Cada historia son tres cinemáticas en data/cinematicas/:
//   <nombre>_inicio.txt   la presentación (antes del teléfono)
//   <nombre>_bueno.txt    si desmintió o fue con cautela
//   <nombre>_malo.txt     si calló, la compartió o usó la IA
// El rótulo del final cambia según la tarjeta: la cinemática escribe
// {cierre} y aquí se elige el texto.

String[] NOMBRES_HISTORIA = {"", "efrain", "", "", "", "carmen", "", ""};   // por día (1 a 7)

// Cómo terminó la historia de cada día: la categoría de la tarjeta que se
// envió (Influencer.MAYOR ... Influencer.IA), o -1 si no se ha jugado.
int[] finalHistoria = {-1, -1, -1, -1, -1, -1, -1, -1};
boolean[] inicioHistoriaVisto = new boolean[8];
String textoCierreHistoria = "";

// Lo que dice la voz del audio reenviado (plano 7 del inicio). Se graba con
// la voz de Azure, como las llamadas, y suena con el filtro de radio.
final String TEXTO_NOTA_VOZ = "Vecina, dicen que el de la tienda se lleva a los niños en un furgón. Pásela.";
final String VOZ_NOTA = "es-CO-SalomeNeural";
javax.sound.sampled.Clip clipNotaVoz;

void reiniciarHistorias() {
    java.util.Arrays.fill(finalHistoria, -1);
    java.util.Arrays.fill(inicioHistoriaVisto, false);
}

String historiaDelDia(int dia) {
    if (dia < 1 || dia >= NOMBRES_HISTORIA.length) {
        return "";
    }
    return NOMBRES_HISTORIA[dia];
}

boolean hayHistoriaHoy() {
    return historiaDelDia(partida.getTurno()).length() > 0;
}

// --- La presentación, antes del teléfono (Llamada.pde, actualizarPorSonar) ---

// true si la cinemática empezó: el teléfono espera a que termine.
boolean empezarInicioHistoria() {
    int dia = partida.getTurno();
    if (!hayHistoriaHoy() || inicioHistoriaVisto[dia] || esRondaEspecial()) {
        return false;
    }
    inicioHistoriaVisto[dia] = true;
    empezarCinematica(historiaDelDia(dia) + "_inicio", "llamada");
    return true;
}

// --- Lo que hizo el jugador ---

// Al enviar (Celular.pde) o si el celular se autodestruye (Encargo.pde)
void registrarResultadoHistoria(int categoria) {
    int dia = partida.getTurno();
    if (hayHistoriaHoy() && finalHistoria[dia] < 0) {
        finalHistoria[dia] = categoria;
    }
}

// --- El final, entre TERMINAR EL DÍA y la pantalla negra (Ronda.pde) ---

// Se llama con el turno ya avanzado: la historia es la del día anterior.
// true si empezó la cinemática del final.
boolean empezarFinalHistoria() {
    int dia = partida.getTurno() - 1;
    String nombre = historiaDelDia(dia);
    if (nombre.length() == 0) {
        return false;
    }
    int c = finalHistoria[dia] < 0 ? Influencer.NEUTRA : finalHistoria[dia];   // no envió nada: es callar
    textoCierreHistoria = cierreDeHistoria(dia, c);
    boolean bueno = c == Influencer.MAYOR || c == Influencer.MENOR;
    empezarCinematica(nombre + (bueno ? "_bueno" : "_malo"), "dia");
    return true;
}

String cierreDeHistoria(int dia, int categoria) {
    if (dia == 1) {
        if (categoria == Influencer.MAYOR) {
            return "EL DESMENTIDO LLEGÓ A 9.000 PERSONAS.|EL AUDIO HABÍA LLEGADO A 3.400.";
        } else if (categoria == Influencer.MENOR) {
            return "EL DESMENTIDO LLEGÓ TARDE.|PARA ALGUNOS, DON EFRAÍN YA ERA CULPABLE.";
        } else if (categoria == Influencer.NEGATIVA) {
            return "TÚ TAMBIÉN LA COMPARTISTE.";
        } else if (categoria == Influencer.IA) {
            return "MIENTRAS TANTO, LA IA ESCRIBÍA OTRA COSA.";
        }
        return "NADIE DIJO NADA.";
    }
    if (dia == 5) {
        if (categoria == Influencer.MAYOR) {
            return "ESA SEMANA, 31 ABUELOS RECONOCIERON LA ESTAFA.|NINGUNO CAYÓ.";
        } else if (categoria == Influencer.MENOR) {
            return "EL VIDEO DEJÓ DE CIRCULAR.|LA ESTAFA SIGUIÓ.";
        } else if (categoria == Influencer.NEGATIVA) {
            return "TU VIDEO «PARA QUE NADIE CAIGA»|LO VIERON 15.000 PERSONAS. ELLA TAMBIÉN.";
        } else if (categoria == Influencer.IA) {
            return "MIENTRAS TANTO, LA IA ESCRIBÍA OTRA COSA.";
        }
        return "NADIE DIJO NADA. CARMEN TAMPOCO.";
    }
    return "";
}

// --- La voz del audio reenviado ---

// Se pide al arrancar, en otro hilo (sin internet no hay voz: queda el subtítulo).
void precargarVozHistorias() {
    if (mision == null || !mision.valeriaConVoz()) {
        return;
    }
    Thread h = new Thread(new Runnable() {
        public void run() {
            try {
                clipNotaVoz = mision.vozDeAzure(TEXTO_NOTA_VOZ, VOZ_NOTA);
            } catch (Exception e) {
                println("Historias: sin voz para la nota de voz (" + e.getMessage() + ")");
            }
        }
    });
    h.setDaemon(true);
    h.start();
}

// La cinemática pide "voz:nota" en vez de un archivo (Cinematica.pde, sonarCine)
void sonarVozHistoria(String cual) {
    if (cual.equals("nota") && clipNotaVoz != null) {
        clipNotaVoz.stop();
        clipNotaVoz.setFramePosition(0);
        clipNotaVoz.start();
    }
}
