// Interfaz — Boton, la oficina (menu principal), la barra de arriba, la
// tarjeta de fin de partida y el manual de ayuda. La llamada del telefono
// esta en Llamada.pde, el celular en Celular.pde, el mapa en Mapa.pde y el
// cuaderno con el arbol en Cuaderno.pde.
// Todo lo que toca Processing (fill, rect, text, mouseX...) vive en los
// .pde, nunca en los .java: asi el modelo del juego se puede explicar y
// probar sin depender de que haya una ventana abierta.
//
// Contenido del archivo:
//   1. Las dos clases de la interfaz: Boton y ObjetoOficina
//   2. Utilidades de dibujo (papel, sombras, texto, iconos)
//   3. Menu principal: la oficina
//   4. La barra de arriba y la tarjeta de fin de partida (el cuaderno
//      con el arbol esta en Cuaderno.pde)
//   5. Pantalla de ayuda: el manual

// ===========================================================================
// 1. CLASES DE LA INTERFAZ
// ===========================================================================

// Boton es una caja rectangular con texto que sabe dibujarse a si misma y
// decir si un punto cae adentro. No sabe que accion representa (eso lo
// decide mousePressed() en AlcaldeDigitalRediseno.pde): asi el mismo Boton sirve
// para "Pasar turno", "Nueva campaña", etc. sin repetir codigo. Recibe su
// x, y, ancho y alto ya calculados por quien lo crea.
class Boton {
    float x, y, ancho, alto;
    String texto;

    Boton(float x, float y, float ancho, float alto, String texto) {
        this.x = x;
        this.y = y;
        this.ancho = ancho;
        this.alto = alto;
        this.texto = texto;
    }

    // Se dibuja como una etiqueta de papel con contorno negro, el mismo
    // estilo del dibujo de la oficina. Con el mouse encima se pinta amarilla
    // y "se levanta" un poco sobre su sombra. No guarda ningun estado de
    // hover: lo recalcula cada vez que se dibuja.
    void dibujar() {
        boolean encima = contiene(mouseX, mouseY);
        if (encima) {
            pedirCursorMano();
        }
        float radio = alto * 0.28;
        float sombra = max(2, alto * 0.09);
        float elevacion = encima ? sombra * 0.7 : 0;

        noStroke();
        fill(COLOR_SOMBRA);
        rect(x + sombra, y + sombra, ancho, alto, radio);

        stroke(COLOR_CONTORNO);
        strokeWeight(grosorContorno);
        if (encima) {
            fill(COLOR_BOTON_HOVER);
        } else {
            fill(COLOR_BOTON);
        }
        rect(x, y - elevacion, ancho, alto, radio);

        fill(COLOR_BOTON_TEXTO);
        ajustarLetra(LETRA_NEGRITA, texto, ancho * 0.84, tx(17, 13));
        textAlign(CENTER, CENTER);
        text(texto, x + ancho / 2, y + alto / 2 - elevacion);
    }

    // Prueba simple de punto dentro de rectangulo. La usan tanto dibujar()
    // (para el hover) como mousePressed() (para el clic): es la unica fuente
    // de verdad sobre "donde esta" este boton.
    boolean contiene(float mx, float my) {
        return mx >= x && mx <= x + ancho && my >= y && my <= y + alto;
    }
}

// Un objeto de la oficina con el que se puede interactuar (el cuaderno, la
// puerta, el televisor...). Solo guarda lo necesario para saber si el mouse
// esta encima y que decir de el en la etiqueta; el dibujo de cada objeto es
// una funcion aparte porque cada uno tiene una forma distinta. Su caja esta
// en coordenadas del lienzo de la oficina, no en pixeles de pantalla.
class ObjetoOficina {
    String nombre;       // como se llama ("Televisor")
    String funcion;      // para que sirve en el juego ("Mapa de Ciudad Nova")
    String accion;       // que dice la etiqueta ("Clic para abrirlo")
    boolean habilitado;  // false si llega en una entrega posterior
    float x, y, ancho, alto;

    ObjetoOficina(String nombre, String funcion, String accion, boolean habilitado,
                  float x, float y, float ancho, float alto) {
        this.nombre = nombre;
        this.funcion = funcion;
        this.accion = accion;
        this.habilitado = habilitado;
        this.x = x;
        this.y = y;
        this.ancho = ancho;
        this.alto = alto;
    }

    boolean contiene(float ex, float ey) {
        return ex >= x && ex <= x + ancho && ey >= y && ey <= y + alto;
    }

    float centroX() {
        return x + ancho / 2;
    }

    float centroY() {
        return y + alto / 2;
    }
}

// ===========================================================================
// 2. UTILIDADES DE DIBUJO
// ===========================================================================

void pedirCursorMano() {
    quiereMano = true;
}

// Aplica el cursor que pidio este cuadro. Solo llama a cursor() cuando
// cambia, porque cambiarlo en cada cuadro no hace falta.
// Los cursores son los del prototipo (una flecha y una mano en pixel art).
// Si el sistema no acepta cursores de imagen, se usan los normales.
void actualizarCursor() {
    int deseado = quiereMano ? HAND : ARROW;
    if (deseado != cursorActual) {
        try {
            if (deseado == HAND) {
                cursor(imgCursorMano, 16, 22);
            } else {
                cursor(imgCursor, 13, 2);
            }
        } catch (Exception e) {
            cursor(deseado);
        }
        cursorActual = deseado;
    }
    quiereMano = false;
}

// --- Letras ---
// En P2D el texto solo se ve nitido si se dibuja al mismo tamano con el que
// se creo la fuente: si se achica, las letras delgadas (la i, la l, los dos
// puntos) se pierden, y si se agranda se ve pixelado. Por eso no se usa
// textSize() para cambiar de tamano: cada tipo de letra tiene una PFont por
// cada tamano en pixeles, que se crea la primera vez que se pide y se
// guarda en fuentes[tipo][tamano] para las siguientes.

PFont fuenteDe(int tipo, float tamano) {
    int t = constrain(int(tamano), 6, TAMANO_MAXIMO_LETRA);
    if (fuentes[tipo][t] == null) {
        fuentes[tipo][t] = createFont(nombresFuente[tipo], t, true);
    }
    return fuentes[tipo][t];
}

// Pone la letra del tipo pedido (LETRA_TITULO, LETRA_NEGRITA, LETRA_TEXTO o
// LETRA_MANO) al tamano dado, en pixeles de pantalla.
void usarLetra(int tipo, float tamano) {
    PFont f = fuenteDe(tipo, tamano);
    textFont(f, f.getSize());
}

// Igual que usarLetra(), pero para el texto de la oficina, que se dibuja
// dentro de scale(escalaEscena): la fuente se crea al tamano que va a tener
// en pantalla y se usa al tamano del lienzo, asi el scale() la deja 1:1.
// aumentoTexto es mayor que 1 solo mientras se redibuja un objeto agrandado
// por el mouse.
void usarLetraEscena(int tipo, float tamanoLienzo) {
    float factor = escalaEscena * aumentoTexto;
    PFont f = fuenteDe(tipo, tamanoLienzo * factor);
    textFont(f, f.getSize() / factor);
}

// Pone el tamano mas grande (sin pasar de "tamano") con el que el texto
// cabe en anchoMax. Se usa donde el texto va dentro de una caja de ancho
// fijo, para que nunca se salga aunque cambie la fuente o la pantalla.
// La letra pixel va en pasos de media celda: al achicarla se redondea y a
// veces queda un poco más ancha de lo pedido. Por eso se baja hasta que de
// verdad quepa.
void ajustarLetra(int tipo, String texto, float anchoMax, float tamano) {
    usarLetra(tipo, tamano);
    float t = tamano;
    while (textWidth(texto) > anchoMax && t > 4) {
        t *= 0.94;
        usarLetra(tipo, t);
    }
}

// Parte un texto en lineas que quepan en "ancho", palabra por palabra, con
// la fuente y el tamano que esten puestos en ese momento.
ArrayList<String> partirEnLineas(String texto, float ancho) {
    ArrayList<String> lineas = new ArrayList<String>();
    String[] palabras = split(texto, ' ');
    String linea = "";
    for (String palabra : palabras) {
        String prueba = linea.isEmpty() ? palabra : linea + " " + palabra;
        if (textWidth(prueba) > ancho && !linea.isEmpty()) {
            lineas.add(linea);
            linea = palabra;
        } else {
            linea = prueba;
        }
    }
    if (!linea.isEmpty()) {
        lineas.add(linea);
    }
    return lineas;
}

float interlineado() {
    return (textAscent() + textDescent()) * 1.12;
}

// Escribe un parrafo con salto de linea automatico y devuelve cuanto alto
// ocupo, para poder poner lo siguiente justo debajo. Usa el textAlign que
// tenga puesto quien lo llama (normalmente LEFT, TOP).
float dibujarParrafo(String texto, float x, float y, float ancho) {
    ArrayList<String> lineas = partirEnLineas(texto, ancho);
    float paso = interlineado();
    for (int i = 0; i < lineas.size(); i++) {
        text(lineas.get(i), x, y + i * paso);
    }
    return lineas.size() * paso;
}

float desplazamientoSombra() {
    return max(3, 6 * escala);
}

// Una hoja de papel con su sombra y contorno negro: es la base de la ficha
// lateral, la tarjeta final, el manual y las etiquetas.
void dibujarPapel(float x, float y, float ancho, float alto, float radio, color relleno) {
    float d = desplazamientoSombra();
    noStroke();
    fill(COLOR_SOMBRA);
    rect(x + d, y + d, ancho, alto, radio);
    stroke(COLOR_CONTORNO);
    strokeWeight(grosorContorno);
    fill(relleno);
    rect(x, y, ancho, alto, radio);
}

// Un pedazo de cinta transparente, como si el papel estuviera pegado.
void dibujarCinta(float cx, float cy, float ancho, float alto, float angulo) {
    pushMatrix();
    translate(cx, cy);
    rotate(angulo);
    noStroke();
    fill(COLOR_CINTA);
    rect(-ancho / 2, -alto / 2, ancho, alto, alto * 0.15);
    popMatrix();
}

// Texto con un borde de otro color alrededor: se escribe el texto varias
// veces corrido en todas las direcciones con el color del borde, y encima
// el texto normal. Sirve para titulos que deben leerse sobre cualquier fondo.
void textoConContorno(String texto, float x, float y, float grosor, color relleno, color borde, float opacidad) {
    fill(borde, opacidad);
    for (int i = 0; i < 8; i++) {
        float angulo = TWO_PI * i / 8;
        text(texto, x + cos(angulo) * grosor, y + sin(angulo) * grosor);
    }
    fill(relleno, opacidad);
    text(texto, x, y);
}

// --- Iconos ---
// Se dibujan con figuras basicas en vez de caracteres tipo emoji: asi no
// dependen de que la fuente del sistema tenga ese simbolo y se ven iguales
// en cualquier computador. Todos reciben un tamano (r) para escalar.

void dibujarCheck(float x, float y, float r, color c) {
    noFill();
    stroke(c);
    strokeWeight(max(2, r * 0.3));
    beginShape();
    vertex(x - r * 0.48, y + r * 0.02);
    vertex(x - r * 0.12, y + r * 0.38);
    vertex(x + r * 0.5, y - r * 0.36);
    endShape();
}

void dibujarCandado(float x, float y, float r, color c) {
    noFill();
    stroke(c);
    strokeWeight(max(1.5, r * 0.2));
    arc(x, y - r * 0.12, r * 0.8, r * 0.95, PI, TWO_PI);
    line(x - r * 0.4, y - r * 0.12, x - r * 0.4, y + r * 0.05);
    line(x + r * 0.4, y - r * 0.12, x + r * 0.4, y + r * 0.05);
    noStroke();
    fill(c);
    rect(x - r * 0.55, y, r * 1.1, r * 0.75, r * 0.15);
}

void dibujarPersona(float x, float y, float r, color c) {
    noStroke();
    fill(c);
    ellipse(x, y - r * 0.38, r * 0.8, r * 0.8);
    arc(x, y + r * 0.62, r * 1.5, r * 1.3, PI, TWO_PI);
}

// ===========================================================================
// 3. MENU PRINCIPAL: LA OFICINA
// ===========================================================================
// La oficina es una imagen (Diseno.pde) puesta sobre un lienzo de
// referencia de 1200 x 670, la proporcion del dibujo. Por eso aqui aparecen
// coordenadas fijas: son del lienzo, no pixeles de la pantalla.

final float ANCHO_ESCENA = 1200;
final float ALTO_ESCENA = 670;   // 1200 / (2576 / 1438): la proporcion del dibujo
final float GROSOR_ESCENA = 3;        // grosor del contorno negro del dibujo

String[] TITULARES_TV = {
    "Arranca la carrera por la alcaldía",
    "Verifica antes de compartir",
    "Un rumor también cuesta votos",
    "Civitas, la red social de Ciudad Nova",
    "Siete días para conquistar la ciudad"
};

void pantallaMenu() {
    objetoResaltado = null;
    if (!mostrarPortada && !saliendo && !llamadaEnPantalla()) {
        objetoResaltado = objetoBajoMouse();
    }
    if (objetoResaltado != null) {
        pedirCursorMano();
    }

    // El dibujo de la oficina es una sola imagen (el rediseno del equipo);
    // encima van solo las cosas que cambian: el turno del calendario, el
    // titular de la TV, el telefono cuando vibra, las burbujas y la llamada.
    background(0);
    pushMatrix();
    translate(origenEscenaX, origenEscenaY);
    scale(escalaEscena);
    image(imgOficina, 0, 0, ANCHO_ESCENA, ALTO_ESCENA);
    dibujarTurnoCalendario();
    dibujarTelevisorOficina();
    dibujarTelefonoVibrando();
    dibujarResalteObjeto(objetoResaltado);
    dibujarPuntosPendientes();
    dibujarAvisoCelular();
    dibujarPistaCelular();
    dibujarPistaCuaderno();
    dibujarAvisoTimbre();
    dibujarCandadoObjeto();
    dibujarEscenaLlamada();
    popMatrix();
    dibujarCierreObjeto();

    if (objetoResaltado != null && objetoCerrando < 0) {
        dibujarEtiqueta(objetoResaltado);
    }
    if (avisoActivo()) {
        dibujarAviso();
    } else if (telefonoSonando() && !saliendo) {
        dibujarCartelInferior("¡Suena el teléfono! Haz clic en él para contestar", 255);
    } else if (objetoResaltado == null && !mostrarPortada && !saliendo && !llamadaEnPantalla()) {
        dibujarCartelInferior("Pasa el mouse por la oficina y haz clic en un objeto para usarlo", 255);
    }
    dibujarIdaAMision();
    dibujarIdaAEvento();
    dibujarSalida();
}

// Convierte la posicion del mouse al lienzo de la oficina (deshace el
// translate y el scale) y pregunta objeto por objeto si la contiene.
ObjetoOficina objetoBajoMouse() {
    float ex = (mouseX - origenEscenaX) / escalaEscena;
    float ey = (mouseY - origenEscenaY) / escalaEscena;
    for (ObjetoOficina o : objetosOficina) {
        if (o.contiene(ex, ey)) {
            return o;
        }
    }
    return null;
}

// Al hacer clic en un objeto que todavia no funciona, aparece sobre el un
// candado que crece rapido, se queda un momento y se encoge.
void dibujarCandadoObjeto() {
    if (objetoConCandado == null) {
        return;
    }
    float t = (millis() - momentoCandado) / (float) DURACION_CANDADO;
    if (t >= 1) {
        return;
    }
    float tamano = 1;
    if (t < 0.2) {
        tamano = sin(t / 0.2 * HALF_PI) * 1.15;
    } else if (t > 0.8) {
        tamano = (1 - t) / 0.2;
    }
    pushMatrix();
    translate(objetoConCandado.centroX(), objetoConCandado.centroY());
    scale(tamano);
    stroke(COLOR_CONTORNO);
    strokeWeight(GROSOR_ESCENA);
    fill(COLOR_BLANCO);
    ellipse(0, 0, 50, 50);
    dibujarCandado(0, 2, 22, COLOR_GRIS_OSCURO);
    popMatrix();
}

// --- El turno que se muestra ---

// Cuando la partida termina el turno queda en 11; en pantalla nunca se
// muestra un turno mayor que el ultimo.
int turnoVisible() {
    return min(partida.getTurno(), Partida.TURNOS_TOTALES);
}

// --- El cuaderno (abre el arbol de habilidades) ---

// Si el jugador tiene puntos sin gastar, el cuaderno muestra una burbuja
// naranja con cuantos, como una notificacion.
void dibujarPuntosPendientes() {
    if (partida.getPuntos() <= 0 || partidaTerminada()) {
        return;
    }
    float pulso = 1 + 0.08 * sin(millis() * 0.008);
    stroke(COLOR_CONTORNO);
    strokeWeight(2);
    fill(COLOR_NARANJA);
    ellipse(770, 420, 26 * pulso, 26 * pulso);
    fill(COLOR_BLANCO);
    usarLetraEscena(LETRA_NEGRITA, 14);
    textAlign(CENTER, CENTER);
    text(partida.getPuntos(), 770, 418);
}

// La primera vez, una burbuja que rebota invita a abrir el cuaderno. No
// sale mientras el telefono suena o hay una llamada: primero va la noticia.
void dibujarPistaCuaderno() {
    if (cuadernoYaAbierto || mostrarPortada || saliendo || objetoResaltado == objetoCuaderno) {
        return;
    }
    if (faseLlamada == LLAMADA_POR_SONAR || telefonoSonando() || llamadaEnPantalla()) {
        return;
    }
    // Primero se publica con el celular; despues, el cuaderno.
    if (!partida.yaPublicoEsteTurno() && !partidaTerminada()) {
        return;
    }
    float rebote = sin(millis() * 0.006) * 5;
    dibujarBurbujaPista("¡Sigue aquí!", 632, 352 + rebote);
}

// --- Capas de la interfaz sobre la oficina (en pixeles de pantalla) ---

// Etiqueta con el nombre del objeto bajo el mouse, para que sirve y que
// pasa al hacer clic. Va encima del objeto, o debajo si arriba no cabe.
void dibujarEtiqueta(ObjetoOficina o) {
    float tamanoNombre = tx(19, 14);
    float tamanoTexto = tx(15, 12);
    float pad = max(9, 13 * escala);
    float icono = tamanoTexto * 1.3;

    String accion = accionDe(o);
    usarLetra(LETRA_NEGRITA, tamanoNombre);
    float anchoNombre = textWidth(o.nombre);
    usarLetra(LETRA_TEXTO, tamanoTexto);
    float anchoFuncion = textWidth(o.funcion);
    usarLetra(LETRA_NEGRITA, tamanoTexto);
    float anchoAccion = textWidth(accion) + icono;
    float ancho = max(anchoNombre, anchoFuncion, anchoAccion) + pad * 2;
    float alto = tamanoNombre * 1.35 + tamanoTexto * 1.35 * 2 + pad * 1.6;

    float cx = origenEscenaX + o.centroX() * escalaEscena;
    float arriba = origenEscenaY + o.y * escalaEscena;
    float abajo = origenEscenaY + (o.y + o.alto) * escalaEscena;
    float separacion = max(6, 12 * escala);
    float x = constrain(cx - ancho / 2, pad, width - ancho - pad);
    float y = arriba - alto - separacion;
    if (y < pad) {
        y = abajo + separacion;
    }

    dibujarPapel(x, y, ancho, alto, pad * 0.8, COLOR_PAPEL);
    float yTexto = y + pad * 0.8;
    fill(COLOR_TEXTO);
    usarLetra(LETRA_NEGRITA, tamanoNombre);
    textAlign(LEFT, TOP);
    text(o.nombre, x + pad, yTexto);
    yTexto += tamanoNombre * 1.35;
    fill(COLOR_TEXTO_SUAVE);
    usarLetra(LETRA_TEXTO, tamanoTexto);
    text(o.funcion, x + pad, yTexto);
    yTexto += tamanoTexto * 1.35;

    float yIcono = yTexto + tamanoTexto * 0.62;
    if (disponibleAhora(o)) {
        dibujarCheck(x + pad + icono * 0.35, yIcono, tamanoTexto * 0.5, COLOR_EXITO);
        fill(COLOR_EXITO);
    } else {
        dibujarCandado(x + pad + icono * 0.35, yIcono, tamanoTexto * 0.6, COLOR_GRIS);
        fill(COLOR_TEXTO_SUAVE);
    }
    usarLetra(LETRA_NEGRITA, tamanoTexto);
    textAlign(LEFT, TOP);
    text(accion, x + pad + icono, yTexto);
}

// Lo que dice la ultima linea de la etiqueta. Casi siempre es fijo, pero el
// telefono cambia segun la llamada, y mientras suena los demas objetos
// piden contestar primero.
String accionDe(ObjetoOficina o) {
    if (bloqueadoPorLlamada(o)) {
        return "Primero contesta el teléfono";
    } else if (o == objetoTelefono) {
        return accionTelefono();
    } else if (o == objetoCelular) {
        return accionCelular();
    }
    return o.accion;
}

// Si hacer clic ahora sirve (check verde) o no (candado).
boolean disponibleAhora(ObjetoOficina o) {
    if (bloqueadoPorLlamada(o)) {
        return false;
    } else if (o == objetoTelefono) {
        return !partidaTerminada() && (telefonoSonando() || puedeRepetirLlamada());
    } else if (o == objetoCelular) {
        return celularDisponible();
    }
    return o.habilitado;
}

String accionCelular() {
    if (partidaTerminada()) {
        return "La campaña terminó";
    } else if (modoApoyo()) {
        return apoyoPuesto ? "Clic para ver el chat" : "Nico te escribió: pon el apoyo del parque";
    } else if (esRondaDeMision()) {
        return "En esta ronda va la misión";
    } else if (esRondaDeEvento()) {
        return "En esta ronda va el evento del parque";
    } else if (celularDestruido) {
        return "Se autodestruyó: mañana llega otro";
    } else if (!celularDisponible()) {
        return "Primero escucha la noticia";
    } else if (partida.yaPublicoEsteTurno()) {
        return "Ya publicaste: clic para ver el chat";
    }
    return "Clic para publicar";
}

// Circulo rojo con un 1 sobre el celular: hay un mensaje sin leer del
// influencer (se ve desde que se oye la noticia hasta que se abre el chat).
void dibujarAvisoCelular() {
    if (!celularDisponible() || celularAbiertoEsteTurno || saliendo || llamadaEnPantalla()) {
        return;
    }
    float pulso = 1 + 0.1 * sin(millis() * 0.01);
    stroke(COLOR_CONTORNO);
    strokeWeight(2);
    fill(COLOR_ROJO);
    ellipse(258, 452, 22 * pulso, 22 * pulso);
    fill(COLOR_BLANCO);
    usarLetraEscena(LETRA_NEGRITA, 13);
    textAlign(CENTER, CENTER);
    text("1", 258, 451);
}

// Despues de la llamada, una burbuja senala el celular hasta que se publica.
void dibujarPistaCelular() {
    if (!celularDisponible() || partida.yaPublicoEsteTurno() || mostrarPortada || saliendo) {
        return;
    }
    if (llamadaEnPantalla() || objetoResaltado == objetoCelular) {
        return;
    }
    float rebote = sin(millis() * 0.006) * 5;
    dibujarBurbujaPista(modoApoyo() ? "¡Te escribieron!" : "¡Publica aquí!", 214, 392 + rebote);
}

boolean avisoActivo() {
    return textoAviso != null && millis() - momentoAviso < DURACION_AVISO;
}

// El aviso se desvanece durante su ultimo medio segundo.
void dibujarAviso() {
    int pasado = millis() - momentoAviso;
    float opacidad = 255;
    if (pasado > DURACION_AVISO - 500) {
        opacidad = map(pasado, DURACION_AVISO - 500, DURACION_AVISO, 255, 0);
    }
    dibujarCartelInferior(textoAviso, opacidad);
}

// Cartel oscuro y redondeado centrado en la parte de abajo de la pantalla.
void dibujarCartelInferior(String texto, float opacidad) {
    float tamano = tx(16, 12);
    usarLetra(LETRA_NEGRITA, tamano);
    float pad = max(10, 18 * escala);
    // no se monta sobre la barra de credibilidad (abajo a la izquierda) ni
    // sobre el botón rojo (abajo a la derecha)
    float reserva = width * 0.04;
    if (partida != null && !enMenu && estado != MAPA) {
        reserva = max(reserva, bordeDerechoCredibilidad() + 12);
    }
    if (puedeTerminarDia()) {
        reserva = max(reserva, width - cajaBotonTerminarDia()[0] + 12);
    }
    float disponible = width - reserva * 2 - pad * 2;
    // si no cabe en una línea, va en dos; y si aun así no cabe, la letra se achica
    ArrayList<String> lineas = new ArrayList<String>();
    if (textWidth(texto) <= disponible) {
        lineas.add(texto);
    } else {
        ArrayList<String> partes = partirEnLineas(texto, disponible);
        if (partes.size() <= 2) {
            lineas.addAll(partes);
        } else {
            // en dos mitades parecidas, y se achica lo que haga falta
            String[] palabras = split(texto, ' ');
            String a = "", b = "";
            for (String p : palabras) {
                if (textWidth(a + " " + p) <= textWidth(texto) / 2 || a.isEmpty()) {
                    a = a.isEmpty() ? p : a + " " + p;
                } else {
                    b = b.isEmpty() ? p : b + " " + p;
                }
            }
            lineas.add(a);
            lineas.add(b);
        }
    }
    String larga = lineas.get(0);
    for (String l : lineas) {
        if (textWidth(l) > textWidth(larga)) {
            larga = l;
        }
    }
    ajustarLetra(LETRA_NEGRITA, larga, disponible, tamano);
    float anchoTexto = textWidth(larga);
    float paso = tamano * 1.25;
    float ancho = anchoTexto + pad * 2;
    float alto = tamano * 2.1 + (lineas.size() - 1) * paso;
    float x = width / 2 - ancho / 2;
    float y = height - alto - max(10, 20 * escala);
    noStroke();
    fill(COLOR_VELO, opacidad);
    rect(x, y, ancho, alto, min(alto / 2, tamano * 1.05));
    fill(COLOR_TEXTO_CREMA, opacidad);
    textAlign(CENTER, CENTER);
    float y0 = y + alto / 2 - (lineas.size() - 1) * paso / 2 - 1;
    for (int i = 0; i < lineas.size(); i++) {
        text(lineas.get(i), width / 2, y0 + i * paso);
    }
}

// Al salir, la puerta se abre y la pantalla se oscurece; cuando termina de
// oscurecerse se cierra el programa.
void dibujarSalida() {
    if (!saliendo) {
        return;
    }
    float t = (millis() - momentoSalida) / (float) DURACION_SALIDA;
    float oscuridad = constrain((t - 0.35) / 0.65, 0, 1);
    noStroke();
    fill(COLOR_NEGRO, 255 * oscuridad);
    rect(0, 0, width, height);
    if (t >= 1) {
        exit();
    }
}

// ===========================================================================
// 4. LA BARRA DE ARRIBA Y EL FIN DE LA PARTIDA
// ===========================================================================

// La pantalla del arbol esta en Cuaderno.pde. Aqui quedan la barra de
// arriba, que comparten varias pantallas, y la tarjeta de fin de partida.

String[] PERFILES_RAMA = {"Comunicador", "Candidato confiable", "Candidato de la IA"};
String[] DESCRIPCIONES_PERFIL = {
    "Tu mensaje llega a todos los rincones de Ciudad Nova.",
    "La gente cree en lo que publicas: tu palabra vale oro.",
    "Ganaste terreno con noticias inventadas: funciona, pero la ciudad se cree cualquier cosa."
};

// --- El texto flotante de los puntos ---

// "+3" al pasar turno o "-2" al comprar: sube desde la moneda y se desvanece.
void dibujarTextoFlotante() {
    if (textoFlotante == null) {
        return;
    }
    float t = (millis() - momentoFlotante) / (float) DURACION_FLOTANTE;
    if (t >= 1) {
        textoFlotante = null;
        return;
    }
    float opacidad = 255 * (1 - t * t);
    float subida = altoBarra * 0.5 * t;
    usarLetra(LETRA_TITULO, tx(30, 20));
    textAlign(CENTER, CENTER);
    textoConContorno(textoFlotante, xFlotante, yFlotante + altoBarra * 0.35 - subida, max(1.5, 2 * escala),
        colorFlotante, COLOR_CONTORNO, opacidad);
}

// --- Progreso por rama (lo usa la tarjeta final) ---

float filaPanel() {
    return tx(25, 19);
}

float altoProgreso() {
    return filaPanel() * 6.5;
}

// Una barra por rama: cuantas de sus habilidades estan desbloqueadas contra
// cuantas tiene (peso del subarbol). Se usa en la tarjeta final.
void dibujarProgreso(float x, float y, float ancho) {
    float fila = filaPanel();
    fill(COLOR_TEXTO);
    usarLetra(LETRA_NEGRITA, tx(16, 12));
    textAlign(LEFT, TOP);
    text("Progreso de la campaña", x, y);
    y += fila * 1.1;

    ArrayList<Nodo> ramas = arbol.getRaiz().getHijos();
    for (int i = 0; i < ramas.size(); i++) {
        Nodo rama = ramas.get(i);
        int hechas = arbol.contarDesbloqueadasEn(rama);
        int total = arbol.peso(rama);
        fill(COLOR_TEXTO);
        usarLetra(LETRA_TEXTO, tx(14, 11));
        textAlign(LEFT, TOP);
        text(NOMBRES_RAMA[i], x, y);
        textAlign(RIGHT, TOP);
        text(hechas + " / " + total, x + ancho, y);

        float yBarra = y + fila * 0.8;
        float alto = fila * 0.34;
        noStroke();
        fill(COLOR_BLOQUEADA);
        rect(x, yBarra, ancho, alto, alto / 2);
        if (hechas > 0) {
            fill(COLORES_RAMA_FUERTE[i]);
            rect(x, yBarra, ancho * hechas / total, alto, alto / 2);
        }
        y += fila * 1.5;
    }

    int total = arbol.peso(arbol.getRaiz()) - 1;
    int hechas = arbol.contarDesbloqueadas() - 1;
    fill(COLOR_TEXTO_SUAVE);
    usarLetra(LETRA_TEXTO, tx(14, 11));
    textAlign(LEFT, TOP);
    text("Habilidades desbloqueadas: " + hechas + " de " + total, x, y + fila * 0.1);
}

// --- Fin de la partida ---

// Tarjeta final: un velo oscuro tapa el cuaderno (y deja de pedir la mano
// para lo que quedo debajo) y encima va el resumen de la campana.
void dibujarFinDePartida() {
    quiereMano = false;
    noStroke();
    fill(COLOR_VELO);
    rect(0, 0, width, height);
    float radio = max(8, 14 * escala);
    dibujarPapel(tarjetaX, tarjetaY, tarjetaAncho, tarjetaAlto, radio, COLOR_PAPEL);
    dibujarCinta(tarjetaX + tarjetaAncho / 2, tarjetaY, tarjetaAncho * 0.26, max(16, 26 * escala), 0.03);

    float cx = tarjetaX + tarjetaAncho / 2;
    float margen = tarjetaAncho * 0.1;
    float ancho = tarjetaAncho - margen * 2;
    float y = tarjetaY + margenTarjeta();

    fill(COLOR_ROJO);
    String titulo = arbolCompleto() ? "¡ÁRBOL COMPLETO!" : "FIN DE LA CAMPAÑA";
    ajustarLetra(LETRA_TITULO, titulo, ancho, tx(52, 32));
    textAlign(CENTER, TOP);
    text(titulo, cx, y);
    y += tx(52, 32) * 1.25;

    int turnos = turnoVisible();
    int hechas = arbol.contarDesbloqueadas() - 1;
    int total = arbol.peso(arbol.getRaiz()) - 1;
    fill(COLOR_TEXTO);
    usarLetra(LETRA_TEXTO, tx(17, 13));
    y += dibujarParrafo("Jugaste " + (turnos == 1 ? "1 turno" : turnos + " turnos") + ", conquistaste " + partida.contarBarriosPropios() + " de " +
        partida.getCiudad().cantidad() + " barrios y desbloqueaste " + hechas + " de " + total + " habilidades.", cx, y, ancho);
    y += tx(14, 10);

    y = dibujarPerfil(cx, y, ancho);
    y += tx(14, 10);
    dibujarProgreso(tarjetaX + margen, y, ancho);
    y += altoProgreso() + tx(8, 6);

    // Tu huella digital: lo que dejaste en Civitas (Impacto.pde)
    fill(COLOR_ROJO);
    usarLetra(LETRA_NEGRITA, tx(15, 12));
    textAlign(CENTER, TOP);
    text("TU HUELLA DIGITAL", cx, y);
    y += tx(15, 12) * 1.5;
    fill(COLOR_TEXTO);
    usarLetra(LETRA_TEXTO, tx(14, 11));
    y += dibujarParrafo("Te vieron " + miles(partida.getAlcanceTotal()) + " personas · credibilidad final " + partida.getCredibilidad() +
        " · " + partida.getAciertos() + " jugadas acertadas · " + partida.getBulosCompartidos() + " bulos compartidos · " +
        partida.getOdioAmplificado() + " mensajes de odio amplificados · " + partida.getUsosIA() + " noticias inventadas con IA.", cx, y, ancho);
    fill(COLOR_TEXTO_SUAVE);
    dibujarParrafo(partida.getBulosCompartidos() + partida.getOdioAmplificado() + partida.getUsosIA() == 0
        ? "No regaste bulos ni odio: así se gana confianza en la red." : "Lo que se publica no se borra del todo: cada bulo llegó a gente real.", cx, y, ancho);

    botonNuevaPartida.dibujar();   // "Menú principal": la campaña no sigue
}

// El estilo de campana sale de la rama con mas habilidades desbloqueadas.
// Si hay empate entre las mas altas, el candidato es "equilibrado".
float dibujarPerfil(float cx, float y, float ancho) {
    ArrayList<Nodo> ramas = arbol.getRaiz().getHijos();
    int mejor = -1;
    int maximo = 0;
    boolean empate = false;
    for (int i = 0; i < ramas.size(); i++) {
        int hechas = arbol.contarDesbloqueadasEn(ramas.get(i));
        if (hechas > maximo) {
            maximo = hechas;
            mejor = i;
            empate = false;
        } else if (hechas == maximo && maximo > 0) {
            empate = true;
        }
    }
    String perfil;
    String descripcion;
    if (mejor < 0) {
        perfil = "Campaña en pausa";
        descripcion = "No desbloqueaste habilidades: cada punto sin usar es una oportunidad perdida.";
    } else if (empate) {
        perfil = "Candidato equilibrado";
        descripcion = "Repartiste tu influencia entre varias ramas sin especializarte en una.";
    } else {
        perfil = PERFILES_RAMA[mejor];
        descripcion = DESCRIPCIONES_PERFIL[mejor];
    }

    fill(COLOR_TEXTO_SUAVE);
    usarLetra(LETRA_NEGRITA, tx(14, 11));
    textAlign(CENTER, TOP);
    text("TU ESTILO DE CAMPAÑA", cx, y);
    y += tx(14, 11) * 1.5;
    fill(COLOR_TINTA);
    ajustarLetra(LETRA_MANO, perfil, ancho, tx(30, 20));
    text(perfil, cx, y);
    y += tx(30, 20) * 1.5;
    fill(COLOR_TEXTO);
    usarLetra(LETRA_TEXTO, tx(15, 12));
    y += dibujarParrafo(descripcion, cx, y, ancho);
    return y;
}

// ===========================================================================
// 5. PANTALLA DE AYUDA: EL MANUAL
// ===========================================================================

// El manual es una hoja pegada sobre el escritorio, con dos columnas. Todo
// es fijo menos el boton de volver, asi que el resto se guarda como foto.
// Con el rediseno, el manual es una hoja que sube sobre la oficina
// oscurecida, igual que los demas objetos.
void pantallaAyuda() {
    background(0);
    image(imgOficina, camX, camY, camAncho, camAlto);
    noStroke();
    fill(COLOR_VELO);
    rect(0, 0, width, height);
    pushMatrix();
    translate(0, (1 - aparicion(0)) * height);
    dibujarManual();
    popMatrix();
    botonVolverAyuda.dibujar();
}

void dibujarManual() {
    fill(COLOR_TEXTO_CREMA);
    usarLetra(LETRA_NEGRITA, tx(18, 13));
    textAlign(RIGHT, CENTER);
    text("Esc también te devuelve a la oficina", width - width * 0.02, altoBarra / 2);

    float radio = max(6, 10 * escala);
    dibujarPapel(ayudaX, ayudaY, ayudaAncho, ayudaAlto, radio, COLOR_PAPEL);
    dibujarCinta(ayudaX + ayudaAncho * 0.18, ayudaY, ayudaAncho * 0.1, max(14, 22 * escala), -0.05);
    dibujarCinta(ayudaX + ayudaAncho * 0.82, ayudaY, ayudaAncho * 0.1, max(14, 22 * escala), 0.05);

    float margen = ayudaAncho * 0.04;
    float x = ayudaX + margen;
    float y = ayudaY + margen * 0.8;
    fill(COLOR_TINTA);
    usarLetra(LETRA_MANO, tx(38, 24));
    textAlign(LEFT, TOP);
    text("¿Cómo jugar?", x, y);
    fill(COLOR_TEXTO_SUAVE);
    usarLetra(LETRA_TEXTO, tx(15, 12));
    textAlign(RIGHT, TOP);
    text("Manual del candidato de Ciudad Nova", ayudaX + ayudaAncho - margen, y + tx(38, 24) * 0.45);
    y += tx(38, 24) * 1.55;
    stroke(COLOR_MARGEN);
    strokeWeight(max(1.5, 2 * escala));
    line(ayudaX + grosorContorno, y, ayudaX + ayudaAncho - grosorContorno, y);
    y += margen * 0.6;

    float anchoColumna = (ayudaAncho - margen * 3) / 2;
    float x2 = x + anchoColumna + margen;
    float y1 = seccionAyuda("Tu objetivo",
        "Ganar la alcaldía de Ciudad Nova conquistando sus barrios. Lo que publicas suma o resta apoyo: " +
        "con " + Partida.UMBRAL_CONQUISTA + " de apoyo un barrio es tuyo.", x, y, anchoColumna);
    y1 = seccionAyuda("Cada turno: la llamada y el celular",
        "Suena el teléfono: " + Noticiero.PERIODISTA + ", del " + Noticiero.MEDIO + ", te cuenta una publicación de Civitas: " +
        "quién la hizo, qué dicen los comentarios y si genera odio (no todo lo que circula es cierto). Las rondas 2, 4 y 6 " +
        "son de minijuego, sacado al azar. Después abre el celular: " + Influencer.NOMBRE + " te ofrece seis tarjetas. " +
        "Elige una y, en el mapa, el barrio donde publicar: solo tus barrios o los que tienen calle con ellos.", x, y1, anchoColumna);
    seccionOficina(x, y1, anchoColumna);

    float y2 = seccionAyuda("Turnos y puntos",
        "La campaña dura " + Partida.TURNOS_TOTALES + " turnos. Al pasar turno recibes puntos para el árbol: " +
        Partida.PUNTOS_SI_GANO + " si tu publicación sumó, " + Partida.PUNTOS_SI_QUEDO_IGUAL + " si quedaste igual y " +
        Partida.PUNTOS_SI_PERDIO + " si restó. Si no los gastas, se guardan.", x2, y, anchoColumna);
    y2 = seccionAyuda("Cómo desbloquear una habilidad",
        "En el cuaderno, haz clic en una habilidad y cómprala con el botón de la hoja derecha. Solo se puede " +
        "si ya tienes la de abajo, tienes los puntos y es su ronda (algunas piden la ronda 2 o la 6).", x2, y2, anchoColumna);
    y2 = seccionRamas(x2, y2, anchoColumna);
    seccionAyuda("Atajos de teclado",
        "Esc: volver a la oficina.   Enter o espacio: contestar el teléfono (la llamada no se repite).   " +
        "En el celular, 1 a 6 eligen tarjeta y Enter envía.   " +
        "P: muestra en la consola el preorden del árbol, su altura y su peso, la matriz del grafo y la tabla de Dijkstra.",
        x2, y2, anchoColumna);
}

// Un titulo y su parrafo. Devuelve donde deberia empezar lo siguiente.
float seccionAyuda(String titulo, String texto, float x, float y, float ancho) {
    fill(COLOR_TEXTO);
    usarLetra(LETRA_NEGRITA, tx(18, 13));
    textAlign(LEFT, TOP);
    text(titulo, x, y);
    y += tx(18, 13) * 1.5;
    usarLetra(LETRA_TEXTO, tx(15, 12));
    y += dibujarParrafo(texto, x, y, ancho);
    return y + tx(18, 13);
}

// Lista de los objetos de la oficina, con un check verde para los que ya
// funcionan y un candado para los que llegan en las proximas entregas.
float seccionOficina(float x, float y, float ancho) {
    fill(COLOR_TEXTO);
    usarLetra(LETRA_NEGRITA, tx(18, 13));
    textAlign(LEFT, TOP);
    text("Tu oficina", x, y);
    y += tx(18, 13) * 1.5;
    float fila = tx(15, 12) * 1.75;
    float r = tx(15, 12) * 0.5;
    for (ObjetoOficina o : objetosOficina) {
        if (o.habilitado) {
            dibujarCheck(x + r, y + fila * 0.42, r, COLOR_EXITO);
        } else {
            dibujarCandado(x + r, y + fila * 0.4, r * 1.2, COLOR_GRIS);
        }
        fill(COLOR_TEXTO);
        usarLetra(LETRA_NEGRITA, tx(15, 12));
        textAlign(LEFT, TOP);
        String nombre = o.nombre + ": ";
        text(nombre, x + r * 3, y);
        fill(o.habilitado ? COLOR_TEXTO : COLOR_TEXTO_SUAVE);
        usarLetra(LETRA_TEXTO, tx(15, 12));
        String detalle = o.habilitado ? o.funcion : o.funcion + " (próximamente)";
        usarLetra(LETRA_NEGRITA, tx(15, 12));
        float anchoNombre = textWidth(nombre);
        usarLetra(LETRA_TEXTO, tx(15, 12));
        text(detalle, x + r * 3 + anchoNombre, y);
        y += fila;
    }
    return y + tx(18, 13);
}

float seccionRamas(float x, float y, float ancho) {
    fill(COLOR_TEXTO);
    usarLetra(LETRA_NEGRITA, tx(18, 13));
    textAlign(LEFT, TOP);
    text("Las tres ramas", x, y);
    y += tx(18, 13) * 1.5;
    String[] descripciones = {
        "llegar a más barrios: bonos a los vecinos y publicar más lejos.",
        "jugar limpio: volver a oír la noticia, puntos extra y perder menos.",
        "inventar noticias. Funciona si no te descubren, pero si te descubren, resta."
    };
    float r = tx(15, 12) * 0.55;
    for (int i = 0; i < NOMBRES_RAMA.length; i++) {
        stroke(COLOR_CONTORNO);
        strokeWeight(max(1, grosorContorno * 0.6));
        fill(COLORES_RAMA_FUERTE[i]);
        rect(x, y + r * 0.35, r * 2.2, r * 1.6, r * 0.4);
        fill(COLOR_TEXTO);
        usarLetra(LETRA_TEXTO, tx(15, 12));
        textAlign(LEFT, TOP);
        float alto = dibujarParrafo(NOMBRES_RAMA[i] + ": " + descripciones[i], x + r * 3.2, y, ancho - r * 3.2);
        y += alto + tx(6, 4);
    }
    return y + tx(18, 13);
}
