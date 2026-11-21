// Ronda — cómo termina un día y cómo empieza el siguiente.
//
// El orden de un día:
//   1. Suena el teléfono con el encargo (Encargo.pde): hay 10 s para decidir
//      dónde va la noticia.
//   2. Con el celular y el mapa se publica; el libro se puede abrir cuando
//      se quiera.
//   3. El botón rojo TERMINAR EL DÍA cierra el turno (en red, cuando todos
//      lo tocaron).
//   4. Una pantalla negra anuncia el día siguiente. Al terminar la campaña
//      salen los créditos.
//
// En las rondas de la misión y del parque el día se termina igual, con el
// botón, al volver a la oficina.

final int CASTIGO_SIN_RESPONDER = 3;      // apoyo que se pierde si no se decide a tiempo
final int DURACION_TRANSICION_DIA = 2600;

boolean diaPorTerminar = false;      // se tocó el botón: al pasar el turno va la pantalla negra
int momentoTransicionDia = -1;       // la pantalla negra con "DÍA N"
String avisoFinDia = null;           // lo que pasó si no se decidió a tiempo
String avisoTrasTransicion = null;   // el resumen del turno, para cuando se quita la pantalla negra

// Se llama en cada draw(): al quitarse la pantalla negra se cuenta cómo
// salió el turno anterior.
void actualizarRonda() {
    if (avisoTrasTransicion != null && !transicionDiaActiva() && estado == MENU) {
        avisar(avisoTrasTransicion);
        mostrarTextoFlotante("+" + partida.getPuntosUltimoTurno(), COLOR_EXITO);
        avisoTrasTransicion = null;
    }
}

// El botón TERMINAR EL DÍA (Encargo.pde)
void terminarDia() {
    diaPorTerminar = true;
    pasarTurno();   // en red espera a los demás
    if (esperandoTurno) {
        irA(MENU);
    }
}

// Lo llama pasarTurno() cuando el turno ya avanzó: el día cambia con la
// pantalla negra ("DÍA N"), o salen los créditos si la campaña terminó.
// Devuelve false si el turno no se cerró con el botón.
boolean cerrarDia() {
    if (!diaPorTerminar) {
        return false;
    }
    diaPorTerminar = false;
    irA(MENU);
    if (partidaTerminada()) {
        empezarCreditos();   // Creditos.pde
    } else {
        momentoTransicionDia = millis();
    }
    return true;
}

boolean transicionDiaActiva() {
    return momentoTransicionDia >= 0 && millis() - momentoTransicionDia < DURACION_TRANSICION_DIA;
}

// La pantalla negra entre un día y otro
void dibujarTransicionDia() {
    if (!transicionDiaActiva()) {
        return;
    }
    float t = (millis() - momentoTransicionDia) / (float) DURACION_TRANSICION_DIA;
    float a = t < 0.75 ? 1 : 1 - (t - 0.75) / 0.25;
    noStroke();
    fill(0, 255 * a);
    rect(0, 0, width, height);
    float celda = celdaInterfaz();
    float aparece = constrain(t / 0.2, 0, 1) * a;
    tint(255, 255 * aparece);
    textoPixel("DÍA " + partida.getTurno() + " DE " + Partida.TURNOS_TOTALES, width / 2, height * 0.46, celda * 4, COLOR_TEXTO_CREMA, CENTER, CENTER);
    String sub = partida.getTurno() == Partida.TURNOS_TOTALES ? "EL ÚLTIMO DÍA DE CAMPAÑA" : "LA CAMPAÑA SIGUE";
    textoPixel(sub, width / 2, height * 0.46 + celda * 34, celda * 1.5, #a0a6b4, CENTER, CENTER);
    noTint();
}

void reiniciarRonda() {
    avisoFinDia = null;
    avisoTrasTransicion = null;
    diaPorTerminar = false;
    momentoTransicionDia = -1;
}

// ---------------------------------------------------------------------------
// Atajo para la exposición: F9 salta al final de la campaña desde cualquier
// parte (la portada, el prólogo, una misión, un día a medias). Los días que
// faltan se dan por pasados y salen los créditos.
void saltarAlFinal() {
    if (creditosActivos) {
        return;
    }
    // lo que esté abierto se cierra
    colaCine.clear();
    planoCine = null;
    trasCinematica = "";
    cambiarAmbienteCine("nada");
    prologoPendiente = false;
    bienvenidaPendiente = false;
    momentoProgramadoBienvenida = -1;
    if (videollamadaActiva) {
        terminarBienvenida();
    }
    callarVoces();             // MisionCampana.pde
    if (mision != null) {
        mision.callarValeria();
    }
    momentoAMision = -1;       // los fundidos hacia la misión o el parque
    momentoAEvento = -1;
    cerrarOpciones();          // Opciones.pde
    enSala = false;
    enMenu = false;
    camaraBajando = false;
    camaraSubiendo = false;
    mostrarPortada = false;
    campanaEmpezada = true;
    momentoTransicionDia = -1;
    avisoTrasTransicion = null;
    irA(MENU);
    // los días que faltan
    while (!partida.seAcabaronLosTurnos()) {
        partida.siguienteTurno();
    }
    reiniciarCelular();
    cambiarFaseLlamada(LLAMADA_NINGUNA);
    diaPorTerminar = true;
    cerrarDia();
}
