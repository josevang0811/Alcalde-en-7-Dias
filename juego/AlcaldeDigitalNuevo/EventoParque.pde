// EventoParque — los eventos del parque (el mundo abierto) dentro de la campaña.
//
// Cuando a la ronda de minijuego le toca uno del mundo abierto (volantes,
// convencer a la gente o los lives, ver Minijuegos.pde), Valeria llama y lo
// presenta. Al colgar, la pantalla se oscurece y el
// candidato aparece en el parqueadero de su sede, en la ciudad
// (MundoAbierto.pde, en el mismo programa). Camina hasta el parque, juega
// los 60 segundos contra los otros tres candidatos y, con Enter en la
// pantalla final, vuelve a la oficina.
//
// El puesto da apoyo: +20 el primero, +10 el segundo, 0 el tercero y -5 el
// último. Si ganó apoyo, el influencer le escribe al celular y el jugador
// escoge en el mapa en qué barrio ponerlo (solo los que alcanza, como al
// publicar). Si quedó de último, se resta solo en su barrio más fuerte. La
// ronda cuenta como la jugada del turno: no se publica con el celular.

final int EVENTO = 6;              // estado de la aplicación mientras se juega el evento
final int DURACION_A_EVENTO = 900;

MundoAbierto mundo;
int momentoAEvento = -1;
String titularEvento = null;      // la noticia que deja el evento, para la TV

// Lo que dejó el último evento, para el chat del influencer
int apoyoEvento = 0;              // lo que ganó (para escoger barrio), 0 si nada
int turnoApoyo = -1;              // en qué turno se ganó
int puestoEvento = -1;            // 0 = primero (los empatados comparten puesto)
int filaYo = -1;                  // en qué fila de la lista final va el jugador
int tipoEvento;                   // mundo.VOLANTES, mundo.GENTE o mundo.LIVES
String[] filasEvento;             // la lista final: "1. Morales · 6"
int[] premioRival = new int[4];   // lo que acumulan los rivales en los minijuegos (gráfica de la TV)
color[] coloresEvento;
boolean apoyoPuesto = false;      // ya lo mandó a un barrio

void prepararMundoAbierto() {
    mundo = new MundoAbierto();
    mundo.prepararMundo();
}

boolean esRondaDeEvento() {
    int m = minijuegoDeRonda();
    return m == MINI_VOLANTES || m == MINI_GENTE || m == MINI_LIVES;
}

// Ronda en la que no se publica: la misión o un evento del parque
boolean esRondaEspecial() {
    return esRondaDeMision() || esRondaDeEvento();
}

boolean eventoHechoEstaRonda() {
    return minijuegoHecho();
}

boolean llamadaDeEvento() {
    return esRondaDeEvento() && !eventoHechoEstaRonda();
}

int eventoDeEstaRonda() {
    return tipoDeMinijuego(minijuegoDeRonda());
}

int tipoDeMinijuego(int mini) {
    if (mini == MINI_VOLANTES) {
        return mundo.VOLANTES;
    }
    return mini == MINI_LIVES ? mundo.LIVES : mundo.GENTE;
}

// Lo que dice Valeria por teléfono en las rondas de los eventos
String[] partesLlamadaEvento(int mini) {
    if (mini == MINI_LIVES) {
        return new String[] {
            "Candidato, es Valeria. Hay lives en el parque regando un rumor sin verificar.",
            "Llega a cada live y reclámalo con F, eligiendo la respuesta responsable."
        };
    }
    if (mini == MINI_VOLANTES) {
        return new String[] {
            "Candidato, soy Valeria. Dicen que vas a cerrar el parque central, y es falso.",
            "Ve al parque y pega volantes verificados con E. Con Q lanzas botellas."
        };
    }
    return new String[] {
        "Candidato, Valeria de nuevo. Hoy hay transmisión en vivo desde el parque.",
        "Convence gente: con E es rápido, con F conversas y nadie te lo quita."
    };
}

void alColgarEvento() {
    momentoAEvento = millis();
}

// Encima de la oficina mientras se oscurece; al terminar, empieza el evento.
void dibujarIdaAEvento() {
    if (momentoAEvento < 0) {
        return;
    }
    float t = constrain((millis() - momentoAEvento) / (float) DURACION_A_EVENTO, 0, 1);
    noStroke();
    fill(0, 255 * t);
    rect(0, 0, width, height);
    if (t >= 1) {
        momentoAEvento = -1;
        empezarEvento();
    }
}

void empezarEvento() {
    tipoEvento = eventoDeEstaRonda();
    if (enRed() && campanaEnRed) {
        // en red todos entran al mismo parque (Red.pde)
        mundo.configurarEventoRed(tipoEvento, modoRedJuego == RED_ANFITRION ? mundo.ANFITRION : mundo.INVITADO,
            miAsientoRed, humanoAsiento, nombreAsiento);
    } else {
        mundo.configurarEventoRed(tipoEvento, mundo.SOLO, 0, new boolean[4], new String[] {"", "", "", ""});
    }
    estado = EVENTO;
}

// La llama el mundo al terminar (Enter en su pantalla final).
void volverALaOficina() {
    java.util.ArrayList<MundoAbierto.Candidato> lista = mundo.resultado;
    puestoEvento = mundo.posicionDe(mundo.yo);
    filaYo = lista.indexOf(mundo.yo);
    int premio = mundo.premioDe(mundo.yo);
    filasEvento = new String[lista.size()];
    coloresEvento = new color[lista.size()];
    for (int k = 0; k < lista.size(); k++) {
        MundoAbierto.Candidato c = lista.get(k);
        filasEvento[k] = (k + 1) + ". " + (c == mundo.yo ? "Tú" : c.nombre) + "  ·  " + mundo.puntajeDe(c);
        coloresEvento[k] = c.col;
        if (c != mundo.yo) {
            premioRival[c.id] += mundo.premioDe(c);
        }
    }
    rondaMinijuegoHecha = partida.getTurno();
    String ganador = lista.get(0) == mundo.yo ? partida.getNombreCandidato() : lista.get(0).nombre;
    if (tipoEvento == mundo.VOLANTES) {
        titularEvento = "Volantes verificados contra el rumor del parque: gana " + ganador;
    } else if (tipoEvento == mundo.GENTE) {
        titularEvento = "Transmisión en vivo desde el parque: " + ganador + " sumó más seguidores";
    } else {
        titularEvento = "Lives con rumores en toda la ciudad: " + ganador + " aclaró más";
    }

    estado = MENU;
    marcarApertura();
    GrafoCiudad ciudad = partida.getCiudad();
    apoyoPuesto = false;
    if (premio > 0) {
        apoyoEvento = premio;
        turnoApoyo = partida.getTurno();
        celularAbiertoEsteTurno = false;   // aparece el mensaje sin leer
        faseCelular = CEL_ELIGIENDO;
        barrioElegido = -1;
        avisar("¡Quedaste de " + (puestoEvento + 1) + ".°! Nico te escribió: revisa el celular para poner los +" + premio + " de apoyo.");
    } else if (premio < 0) {
        apoyoEvento = 0;
        int z = partida.barrioConMasApoyo();
        int cambio = partida.registrarEvento(z, premio);
        avisar("Quedaste de último: " + cambio + " de apoyo en " + ciudad.getNombre(z) + ". Termina el día con el botón rojo.");
        mostrarTextoFlotante(str(cambio), COLOR_ERROR);
    } else {
        apoyoEvento = 0;
        partida.registrarEvento(Partida.ZONA_SEDE, 0);
        avisar("Quedaste de " + (puestoEvento + 1) + ".°: esta vez no ganas ni pierdes apoyo. Termina el día con el botón rojo.");
    }
    informeDeEvento(tipoEvento, puestoEvento, premio);   // Impacto.pde
}

// El celular está en el modo de "poner el apoyo del evento"
boolean modoApoyo() {
    return apoyoEvento > 0 && turnoApoyo == partida.getTurno() && !partidaTerminada();
}

// Una campaña nueva vuelve a tener sus eventos
void reiniciarEventosCampana() {
    sortearMinijuegos();
    premioRival = new int[4];
    titularEvento = null;
    momentoAEvento = -1;
    apoyoEvento = 0;
    turnoApoyo = -1;
}

// ---------------------------------------------------------------------------
// El celular en modo apoyo (lo usa Celular.pde)
// ---------------------------------------------------------------------------

String nombreEvento() {
    if (tipoEvento == mundo.LIVES) {
        return "la ronda de los lives";
    }
    return tipoEvento == mundo.VOLANTES ? "la ronda de volantes" : "la ronda de convencer a la gente";
}

ArrayList<Mensaje> mensajesApoyo() {
    ArrayList<Mensaje> lista = new ArrayList<Mensaje>();
    if (!introLista()) {
        return lista;
    }
    GrafoCiudad ciudad = partida.getCiudad();
    lista.add(new Mensaje("¡Jefe! Ya me contaron lo del parque.", null, false));
    lista.add(new Mensaje("Quedaste de " + (puestoEvento + 1) + ".° en " + nombreEvento() + ": tenemos +" + apoyoEvento + " de apoyo para poner.",
        faseCelular == CEL_ELIGIENDO ? "¿En qué barrio lo ponemos? Elige uno en el mapa." : null, false));
    if (faseCelular == CEL_ELIGIENDO) {
        return lista;
    }
    lista.add(new Mensaje("Ponlo en " + ciudad.getNombre(envioBarrio) + ".", null, true));
    lista.add(new Mensaje("¡Va saliendo! Llega en " + envioMinutos + " min.", null, false));
    if (reaccionLista()) {
        String cambio = envioCambio > 0 ? "+" + envioCambio + " de apoyo" : "Sin cambios: el barrio ya estaba en el tope";
        lista.add(new Mensaje("Listo, la gente del parque se acuerda de ti en " + ciudad.getNombre(envioBarrio) + ".", cambio, false));
        if (envioConquisto) {
            lista.add(new Mensaje("¡" + ciudad.getNombre(envioBarrio) + " ya es tuyo! Ahora llegamos a sus vecinos.", null, false));
        }
        lista.add(new Mensaje("Esta ronda ya cuenta como tu jugada: termina el día con el botón rojo.", null, false));
    }
    return lista;
}

// Manda el apoyo al barrio elegido, con el mismo viaje por las calles que
// una publicación.
void enviarApoyoEvento() {
    if (faseCelular != CEL_ELIGIENDO || barrioElegido < 0) {
        if (barrioElegido < 0) {
            avisar("Elige en el mapa el barrio donde va el apoyo.");
        }
        return;
    }
    GrafoCiudad ciudad = partida.getCiudad();
    boolean[] propios = partida.barriosPropios();
    int origen = ciudad.propioMasCercano(propios, barrioElegido);
    boolean eraPropio = partida.esPropio(barrioElegido);
    apoyoAntes = new int[ciudad.cantidad()];
    for (int z = 0; z < apoyoAntes.length; z++) {
        apoyoAntes[z] = partida.getApoyo(z);
    }
    envioCambio = partida.registrarEvento(barrioElegido, apoyoEvento);
    envioPublicacion = null;
    envioBarrio = barrioElegido;
    envioCamino = ciudad.caminoMasCorto(origen, barrioElegido);
    envioMinutos = ciudad.minutosMasCorto(origen, barrioElegido);
    envioConquisto = !eraPropio && partida.esPropio(barrioElegido);
    envioPerdio = false;
    duracionViaje = max(VIAJE_MINIMO, envioMinutos * MS_POR_MINUTO);
    momentoEnvio = millis();
    faseCelular = CEL_VIAJANDO;
    apoyoPuesto = true;
    textoAviso = null;
    sonidos.tocarEnvio();
}

// En vez de las tarjetas, la lista final del evento
void dibujarResultadoEventoCelular() {
    if (filasEvento == null) {
        return;
    }
    float x = panX + padCel;
    float y = tarjetasY;
    float ancho = panAncho - padCel * 2;
    float fila = altoTarjeta * 0.62;
    noStroke();
    fill(COLOR_AZUL_OSCURO, 150);
    rect(x, y, ancho, fila * (filasEvento.length + 1) + padCel, padCel);
    fill(COLOR_POSTIT);
    usarLetra(LETRA_NEGRITA, tx(13, 10));
    textAlign(LEFT, CENTER);
    text(tipoEvento == mundo.VOLANTES ? "RONDA DE VOLANTES" : (tipoEvento == mundo.GENTE ? "CONVENCER A LA GENTE" : "RONDA DE LOS LIVES"), x + padCel, y + fila * 0.6);
    for (int k = 0; k < filasEvento.length; k++) {
        float fy = y + fila * (k + 1.4);
        fill(coloresEvento[k]);
        rect(x + padCel, fy - fila * 0.22, fila * 0.44, fila * 0.44, 3);
        fill(k == filaYo ? COLOR_BLANCO : COLOR_TEXTO_CREMA);
        usarLetra(k == filaYo ? LETRA_NEGRITA : LETRA_TEXTO, tx(14, 11));
        text(filasEvento[k], x + padCel + fila * 0.7, fy);
    }
}
