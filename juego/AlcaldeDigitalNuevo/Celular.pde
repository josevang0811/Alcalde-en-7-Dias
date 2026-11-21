// Celular — publicar en Civitas: el chat con el influencer y el mapa.
//
// Despues de la llamada, el influencer (Nico Viral) escribe por el celular
// preguntando que hacer con la noticia (no la repite: hay que acordarse de
// lo que conto la periodista y, sobre todo, de donde salio). A la izquierda queda el celular: el chat, una
// barra para enviar y las seis tarjetas (seis formas de publicar la
// noticia). A la derecha queda el mapa de Ciudad Nova, el grafo de barrios.
//
// El jugador elige una tarjeta y un barrio; solo con las dos cosas se activa
// el boton de enviar. Solo se puede publicar en los barrios propios y en los
// que estan a una calle de ellos (a dos con Perfil verificado): lo decide
// el recorrido por niveles (BFS) del grafo. Al enviar, un punto
// de luz sale del barrio propio mas cercano y viaja por el camino mas corto
// (Dijkstra) hasta el barrio elegido; al llegar, el apoyo del barrio sube o
// baja y el influencer cuenta como le fue. Con 50 de apoyo el barrio queda
// conquistado y la frontera crece.
//
// Las reglas (que vale cada tarjeta, a donde se puede publicar, el camino)
// estan en Influencer.java, Partida.java y GrafoCiudad.java; aqui solo se
// dibuja y se responde al mouse.

// ===========================================================================
// ESTADO
// ===========================================================================

final int CEL_ELIGIENDO = 0;  // el jugador elige tarjeta y barrio
final int CEL_VIAJANDO = 1;   // la publicacion va por las calles
final int CEL_LISTO = 2;      // ya llego: se ve el resultado
int faseCelular = CEL_ELIGIENDO;

final int ESPERA_ESCRIBIENDO = 900;  // "escribiendo..." antes de cada respuesta
final int MS_POR_MINUTO = 90;        // velocidad del viaje: milisegundos por minuto de calle
final int VIAJE_MINIMO = 700;
final int DURACION_FESTEJO = 2200;   // ondas y "+30" sobre el barrio al llegar

int tarjetaElegida = -1;  // posicion en la lista de tarjetas del turno, o -1
int barrioElegido = -1;
boolean usarTransmision = false;  // si se activo la Transmision en vivo para este envio
boolean celularAbiertoEsteTurno = false;
int momentoIntro;         // cuando se abrio el celular por primera vez en el turno
boolean introSonada = false;
boolean reaccionSonada = false;

// Lo que paso con la publicacion del turno: se guarda al enviar para
// animarla y para que el chat lo siga mostrando si se vuelve a abrir.
String envioTexto;
int envioBarrio;
int envioCategoria;
int envioCambio;
int[] apoyoAntes;          // el apoyo de todos los barrios antes de publicar
boolean envioConquisto;
boolean envioPerdio;
Publicacion envioPublicacion;
String envioNoticiaIA;     // lo que invento la IA, si se uso su tarjeta
ArrayList<Integer> envioCamino;
int envioMinutos;
int momentoEnvio;
int duracionViaje;
String envioReaccion;
String envioExplicacion;

// Un mensaje del chat: un texto normal y, si hace falta, una segunda parte
// en negrita (el titular de la noticia, el barrio donde se publica).
class Mensaje {
    String texto;
    String destacado;
    boolean mio;  // true si lo envia el jugador (va a la derecha, en blanco)

    Mensaje(String texto, String destacado, boolean mio) {
        this.texto = texto;
        this.destacado = destacado;
        this.mio = mio;
    }
}

// ===========================================================================
// LAYOUT
// ===========================================================================
// Se recalcula en cada cuadro porque son unas pocas cuentas.

float celX, celY, celAncho, celAlto;   // el marco del celular
float panX, panY, panAncho, panAlto;   // su pantalla
float padCel;
float altoCabecera;
float chatY, chatAlto;
float composerY, altoComposer;
float enviarX, enviarY, radioEnviar;
float tarjetasY, anchoTarjeta, altoTarjeta, separacionTarjetas;
float mapaPanelX, mapaPanelY, mapaPanelAncho, mapaPanelAlto;

// El celular y el mapa de papel son dibujos del equipo que suben desde abajo
// al abrir (Diseno.pde) y despues se balancean un poquito. Por eso el layout
// se recalcula en cada cuadro: todo lo de adentro (el chat, las tarjetas,
// los barrios) se mueve con ellos. El balanceo de estos dos es solo hacia
// arriba y abajo, sin girar, para que los clics caigan donde se ve.
// El mapa de papel (el del equipo, 1000 x 943), en porcentaje de la cámara
final float MAPA_IZQ = 53.385, MAPA_ANCHO = 44.219;
final float MAPA_ALTO = 44.219 * 2576.0 / 1438.0 * 943 / 1000;
final float MAPA_ARRIBA = 12.593 + (79.571 - MAPA_ALTO) / 2;

void calcularLayoutCelular() {
    float[] cel = cajaObjeto(10.413, 12.514, 25.321, 84.207, 109.894, aparicion(40), 1.8, -1.1);
    celX = cel[0];
    celY = cel[1];
    celAncho = cel[2];
    celAlto = cel[3];
    // La pantalla negra del dibujo del celular (en fraccion de la imagen).
    panX = celX + celAncho * 0.0793;
    panY = celY + celAlto * 0.1208;
    panAncho = celAncho * (0.9222 - 0.0793);
    panAlto = celAlto * (0.8783 - 0.1208);

    // De abajo hacia arriba: las tarjetas, la barra para enviar y, en lo
    // que queda, el chat debajo de la cabecera.
    padCel = max(6, 8 * escala);
    separacionTarjetas = padCel * 0.7;
    altoTarjeta = constrain(panAlto * 0.118, 40, 140);
    anchoTarjeta = (panAncho - padCel * 2 - separacionTarjetas) / 2;
    tarjetasY = panY + panAlto - padCel - altoTarjeta * 3 - separacionTarjetas * 2;
    altoComposer = tx(40, 28);
    composerY = tarjetasY - padCel - altoComposer;
    radioEnviar = altoComposer / 2;
    enviarX = panX + panAncho - padCel - radioEnviar;
    enviarY = composerY + altoComposer / 2;
    altoCabecera = tx(52, 38);
    chatY = panY + altoCabecera;
    chatAlto = composerY - padCel * 0.6 - chatY;

    float[] papel = cajaObjeto(MAPA_IZQ, MAPA_ARRIBA, MAPA_ANCHO, MAPA_ALTO, 115.848, aparicion(130), 2.0, -0.7);
    mapaPanelX = papel[0];
    mapaPanelY = papel[1];
    mapaPanelAncho = papel[2];
    mapaPanelAlto = papel[3];
    // Las mismas variables que usa Mapa.pde, para reusar xZona(), yZona() y
    // zonaEnMapa(); con mapaEnPapel, cada barrio es uno de los post-its.
    mapaX = mapaPanelX;
    mapaY = mapaPanelY;
    mapaAncho = mapaPanelAncho;
    mapaAlto = mapaPanelAlto;
    mapaEnPapel = true;
}

// ===========================================================================
// TURNO Y TIEMPOS
// ===========================================================================

// Al empezar un turno el celular queda como nuevo: sin tarjeta ni barrio
// elegidos y con un mensaje sin leer.
void reiniciarCelular() {
    faseCelular = CEL_ELIGIENDO;
    tarjetaElegida = -1;
    barrioElegido = -1;
    celularAbiertoEsteTurno = false;
    introSonada = false;
    reaccionSonada = false;
    usarTransmision = false;
    envioCamino = null;
    reiniciarEncargo();   // Encargo.pde
}

void abrirCelular() {
    irA(CELULAR);
    if (!celularAbiertoEsteTurno) {
        celularAbiertoEsteTurno = true;
        momentoIntro = millis();
    }
}

// El celular se usa despues de oir la noticia del turno, una vez por turno.
boolean celularDisponible() {
    if (modoApoyo()) {
        return true;   // el influencer escribe por el apoyo del evento del parque
    }
    return !partidaTerminada() && faseLlamada == LLAMADA_ATENDIDA && !esRondaEspecial() && !celularDestruido;
}

boolean introLista() {
    return millis() - momentoIntro >= ESPERA_ESCRIBIENDO;
}

int momentoLlegada() {
    return momentoEnvio + duracionViaje;
}

boolean reaccionLista() {
    return faseCelular == CEL_LISTO && millis() - momentoLlegada() >= ESPERA_ESCRIBIENDO;
}

// Se llama al principio de cada draw(), este donde este el jugador: asi la
// publicacion llega aunque se haya devuelto a la oficina durante el viaje.
void actualizarCelular() {
    if (faseCelular == CEL_VIAJANDO && millis() >= momentoLlegada()) {
        faseCelular = CEL_LISTO;
        if (envioCambio > 0) {
            sonidos.tocarExito();
        } else if (envioCambio < 0) {
            sonidos.tocarFallo();
        }
    }
    if (estado == CELULAR && celularAbiertoEsteTurno && introLista() && !introSonada) {
        introSonada = true;
        sonidos.tocarMensaje();
    }
    if (reaccionLista() && !reaccionSonada) {
        reaccionSonada = true;
        if (estado == CELULAR) {
            sonidos.tocarMensaje();
        }
    }
}

// ===========================================================================
// ENVIAR
// ===========================================================================

// Publica de verdad (el modelo cambia aqui mismo) y deja preparado todo lo
// que se necesita para animar el viaje y contar el resultado.
void enviarPublicacion() {
    if (faseCelular != CEL_ELIGIENDO) {
        return;
    }
    if (tarjetaElegida < 0) {
        avisar("Primero elige una de las tarjetas.");
        return;
    }
    if (barrioElegido < 0) {
        avisar("Elige en el mapa el barrio donde se publica.");
        return;
    }
    GrafoCiudad ciudad = partida.getCiudad();
    Tarjeta tarjeta = partida.getTarjetasDelTurno().get(tarjetaElegida);
    boolean[] propios = partida.barriosPropios();
    int origen = ciudad.propioMasCercano(propios, barrioElegido);
    boolean eraPropio = partida.esPropio(barrioElegido);
    apoyoAntes = new int[ciudad.cantidad()];
    for (int z = 0; z < apoyoAntes.length; z++) {
        apoyoAntes[z] = partida.getApoyo(z);
    }

    Publicacion p = partida.publicar(tarjeta, barrioElegido, usarTransmision);
    if (p == null) {
        return;
    }
    String barrio = ciudad.getNombre(barrioElegido);
    envioPublicacion = p;
    envioTexto = tarjeta.getTexto();
    envioBarrio = barrioElegido;
    envioCategoria = p.getCategoria();
    envioCamino = ciudad.caminoMasCorto(origen, barrioElegido);
    envioMinutos = ciudad.minutosMasCorto(origen, barrioElegido);
    envioCambio = p.getCambio();
    envioConquisto = !eraPropio && partida.esPropio(barrioElegido);
    envioPerdio = eraPropio && !partida.esPropio(barrioElegido);
    envioNoticiaIA = p.usoIA() ? partida.getInfluencer().noticiaInventada(barrio) : null;
    if (p.usoIA()) {
        envioReaccion = p.iaDescubierta() ? "¡Nos pillaron! En " + barrio + " descubrieron que la noticia la hizo una IA."
            : "Nadie se dio cuenta de que era IA. En " + barrio + " se lo creyeron todo.";
    } else {
        envioReaccion = partida.getInfluencer().reaccion(envioCategoria, barrio);
    }
    envioExplicacion = partida.getInfluencer().explicacion(partida.getNoticiaDelTurno().getTipo());
    informeDePublicacion(p, tarjeta, partida.getNoticiaDelTurno(), barrio);   // Impacto.pde

    duracionViaje = max(VIAJE_MINIMO, envioMinutos * MS_POR_MINUTO);
    momentoEnvio = millis();
    faseCelular = CEL_VIAJANDO;
    textoAviso = null;
    sonidos.tocarEnvio();
    // para las gráficas del informe (Impacto.pde)
    informeActual.apoyoAntes = apoyoAntes[barrioElegido];
    informeActual.apoyoDespues = partida.getApoyo(barrioElegido);
    alEnviarEnEncargo();   // si era el encargo, el mensaje se autodestruye (Encargo.pde)
}

// Mientras la publicacion viaja, los barrios siguen mostrando el apoyo y el
// color de antes: el cambio (y los bonos de Volantes y Megafono) se ven
// cuando llega.
int apoyoVisible(int z) {
    if (faseCelular == CEL_VIAJANDO) {
        return apoyoAntes[z];
    }
    return partida.getApoyo(z);
}

boolean propioVisible(int z) {
    if (faseCelular == CEL_VIAJANDO) {
        return z == Partida.ZONA_SEDE || apoyoAntes[z] >= Partida.UMBRAL_CONQUISTA;
    }
    return partida.esPropio(z);
}

boolean[] propiosVisibles() {
    boolean[] propios = new boolean[partida.getCiudad().cantidad()];
    for (int z = 0; z < propios.length; z++) {
        propios[z] = propioVisible(z);
    }
    return propios;
}

// ===========================================================================
// PANTALLA
// ===========================================================================

void pantallaCelular() {
    calcularLayoutCelular();
    dibujarPlaca(imgSinCelular);
    dibujarMarcoCelular();
    dibujarCabeceraChat();
    dibujarChat();
    dibujarComposer();
    dibujarTarjetas();
    dibujarMapaCelular();

    // Arriba, sobre la oficina oscura: volver, el turno y (al terminar) ir
    // al libro.
    botonVolverCelular.dibujar();
    if (faseCelular == CEL_LISTO) {
        botonCuadernoCelular.dibujar();
    }
    textoPixel("CIVITAS · TURNO " + turnoVisible() + " DE " + Partida.TURNOS_TOTALES, width / 2,
        botonVolverCelular.y + botonVolverCelular.alto / 2, celdaInterfaz(), 1, #fff3d6, #1a1010, 0, 0, false, CENTER, CENTER);
    if (avisoActivo()) {
        dibujarAviso();
    }
}

// El dibujo del celular y, en su pantalla negra, el fondo azul de Civitas.
void dibujarMarcoCelular() {
    image(imgCelular, celX, celY, celAncho, celAlto);
    noStroke();
    fill(COLOR_AZUL);
    rect(panX, panY, panAncho, panAlto, max(4, 6 * escala));
}

// Arriba del chat: la foto y el nombre del influencer, y si esta escribiendo.
void dibujarCabeceraChat() {
    noStroke();
    fill(COLOR_AZUL_CLARO);
    float radio = max(16, 26 * escala) * 0.45;
    rect(panX, panY, panAncho, altoCabecera, radio, radio, 0, 0);
    stroke(COLOR_AZUL_OSCURO);
    strokeWeight(1);
    line(panX, panY + altoCabecera, panX + panAncho, panY + altoCabecera);

    float r = altoCabecera * 0.32;
    float cx = panX + padCel * 2.4 + r;
    float cy = panY + altoCabecera / 2;
    fill(COLOR_AZUL_OSCURO);
    usarLetra(LETRA_NEGRITA, tx(18, 13));
    textAlign(CENTER, CENTER);
    text("<", panX + padCel * 1.1, cy - 2);
    dibujarAvatar(cx, cy, r);

    fill(COLOR_TEXTO);
    usarLetra(LETRA_NEGRITA, tx(17, 13));
    textAlign(LEFT, BOTTOM);
    text(Influencer.NOMBRE, cx + r * 1.6, cy + 2);
    fill(COLOR_AZUL_OSCURO);
    String estadoNico = influencerEscribiendo() ? "escribiendo..." : "en línea · influencer de tu campaña";
    ajustarLetra(LETRA_TEXTO, estadoNico, panX + panAncho - padCel - (cx + r * 1.6), tx(13, 10));
    textAlign(LEFT, TOP);
    text(estadoNico, cx + r * 1.6, cy + 3);
    dibujarBotonTransmision();
}

// --- Transmision en vivo ---
// Si el candidato tiene la habilidad y no la ha usado, en la cabecera del
// chat aparece un boton "EN VIVO" para activarla en este envio.

boolean transmisionDisponible() {
    return faseCelular == CEL_ELIGIENDO && partida.puedeUsarTransmision() && !modoApoyo();
}

float[] cajaBotonTransmision() {
    usarLetra(LETRA_NEGRITA, tx(12, 9));
    float alto = altoCabecera * 0.46;
    float ancho = textWidth("EN VIVO") + alto * 1.6;
    return new float[] {panX + panAncho - padCel - ancho, panY + altoCabecera / 2 - alto / 2, ancho, alto};
}

boolean mouseEnTransmision() {
    float[] c = cajaBotonTransmision();
    return mouseX >= c[0] && mouseX <= c[0] + c[2] && mouseY >= c[1] && mouseY <= c[1] + c[3];
}

void dibujarBotonTransmision() {
    if (!transmisionDisponible()) {
        return;
    }
    float[] c = cajaBotonTransmision();
    if (mouseEnTransmision()) {
        pedirCursorMano();
    }
    stroke(COLOR_CONTORNO);
    strokeWeight(1.5);
    fill(usarTransmision ? COLOR_ROJO : COLOR_BLANCO);
    rect(c[0], c[1], c[2], c[3], c[3] / 2);
    noStroke();
    fill(usarTransmision ? COLOR_BLANCO : COLOR_ROJO);
    if (!usarTransmision || (millis() / 500) % 2 == 0) {
        ellipse(c[0] + c[3] * 0.55, c[1] + c[3] / 2, c[3] * 0.35, c[3] * 0.35);
    }
    usarLetra(LETRA_NEGRITA, tx(12, 9));
    textAlign(LEFT, CENTER);
    text("EN VIVO", c[0] + c[3] * 0.95, c[1] + c[3] / 2 - 1);
}

void dibujarAvatar(float cx, float cy, float r) {
    stroke(COLOR_CONTORNO);
    strokeWeight(1.5);
    fill(COLOR_BLANCO);
    ellipse(cx, cy, r * 2, r * 2);
    dibujarPersona(cx, cy + r * 0.12, r * 0.8, COLOR_GRIS);
}

boolean influencerEscribiendo() {
    return !introLista() || (faseCelular == CEL_LISTO && !reaccionLista());
}

// --- Chat ---

// Los mensajes que se ven ahora, del mas viejo al mas nuevo. Dependen de en
// que va el turno: la noticia, la orden del jugador y la respuesta.
ArrayList<Mensaje> mensajesDelChat() {
    if (modoApoyo()) {
        return mensajesApoyo();   // el apoyo que se ganó en el parque (EventoParque.pde)
    }
    ArrayList<Mensaje> lista = new ArrayList<Mensaje>();
    if (!introLista()) {
        return lista;
    }
    // Nico no repite la noticia: el jugador tiene que acordarse de lo que
    // conto la periodista. Solo despues de publicar se le muestra completa.
    lista.add(new Mensaje("¡Hola, jefe! ¿Oíste lo que contó " + Noticiero.PERIODISTA + " por teléfono?", null, false));
    // Los comentarios de la publicación ya no los dice la periodista (la
    // llamada es corta): los cuenta Nico. Y hay que decidir rápido.
    lista.add(new Mensaje("Ya la vi en Civitas. En los comentarios, " + partida.getNoticiaDelTurno().getComentarios() + ".", null, false));
    if (faseCelular == CEL_ELIGIENDO) {
        lista.add(new Mensaje("¿Qué hacemos con esa noticia? Elige una tarjeta y en el mapa el barrio donde la publico.", null, false));
        return lista;
    }
    GrafoCiudad ciudad = partida.getCiudad();
    lista.add(new Mensaje(envioTexto, "Publícala en " + ciudad.getNombre(envioBarrio) + ".", true));
    if (envioNoticiaIA != null) {
        lista.add(new Mensaje("La IA escribió esto:", "«" + envioNoticiaIA + "»", false));
    }
    lista.add(new Mensaje("¡Va saliendo! Llega en " + envioMinutos + " min.", null, false));
    if (reaccionLista()) {
        lista.add(new Mensaje(envioReaccion, textoCambio(envioPublicacion), false));
        for (String efecto : envioPublicacion.getEfectos()) {
            lista.add(new Mensaje(efecto, null, false));
        }
        Noticia n = partida.getNoticiaDelTurno();
        lista.add(new Mensaje("La noticia era: «" + n.getTitular() + "» (de " + n.getFuente() + ").", envioExplicacion, false));
        if (envioConquisto) {
            lista.add(new Mensaje("¡" + ciudad.getNombre(envioBarrio) + " ya es tuyo! Ahora llegamos a sus vecinos.", null, false));
        } else if (envioPerdio) {
            lista.add(new Mensaje("Perdimos " + ciudad.getNombre(envioBarrio) + ": bajó de " + Partida.UMBRAL_CONQUISTA + " de apoyo.", null, false));
        }
    }
    return lista;
}

// Cuanto cambio el apoyo. Si el barrio ya estaba en un limite (0 o 100),
// se dice, para que no parezca que la tarjeta no valia nada.
String textoCambio(Publicacion p) {
    int cambio = p.getCambio();
    int valor = p.getValor();
    String texto;
    if (cambio > 0) {
        texto = "+" + cambio + " de apoyo";
    } else if (cambio < 0) {
        texto = cambio + " de apoyo";
    } else {
        texto = "Sin cambios en el apoyo";
    }
    if (valor < 0 && cambio > valor) {
        texto += " (valía " + valor + ", pero el barrio ya estaba en " + apoyoAntes[p.getZona()] + ")";
    } else if (valor > 0 && cambio < valor) {
        texto += " (llegó al tope de " + Partida.TOPE_APOYO + ")";
    }
    return texto;
}

// Los mensajes se apilan desde abajo, como en cualquier chat: el mas nuevo
// queda justo encima de la barra de enviar y los viejos suben. Lo que no
// cabe se corta por arriba (clip).
void dibujarChat() {
    ArrayList<Mensaje> mensajes = mensajesDelChat();
    float anchoMax = panAncho * 0.78;
    float y = chatY + chatAlto - padCel * 0.6;
    clip(panX, chatY, panAncho, chatAlto);
    if (influencerEscribiendo()) {
        y -= dibujarEscribiendo(y);
        y -= padCel * 0.8;
    }
    for (int i = mensajes.size() - 1; i >= 0; i--) {
        Mensaje m = mensajes.get(i);
        float alto = altoMensaje(m, anchoMax);
        y -= alto;
        dibujarMensaje(m, y, anchoMax, alto);
        y -= padCel * 0.8;
    }
    noClip();
}

float tamanoChat() {
    return tx(14, 11);
}

// Alto de la burbuja: las lineas del texto normal mas las del destacado.
float altoMensaje(Mensaje m, float anchoMax) {
    float pad = padCel;
    usarLetra(LETRA_TEXTO, tamanoChat());
    float alto = partirEnLineas(m.texto, anchoMax - pad * 2).size() * interlineado();
    if (m.destacado != null) {
        usarLetra(LETRA_NEGRITA, tamanoChat());
        alto += pad * 0.4 + partirEnLineas(m.destacado, anchoMax - pad * 2).size() * interlineado();
    }
    return alto + pad * 1.6;
}

float anchoMensaje(Mensaje m, float anchoMax) {
    float pad = padCel;
    float mayor = 0;
    usarLetra(LETRA_TEXTO, tamanoChat());
    for (String linea : partirEnLineas(m.texto, anchoMax - pad * 2)) {
        mayor = max(mayor, textWidth(linea));
    }
    if (m.destacado != null) {
        usarLetra(LETRA_NEGRITA, tamanoChat());
        for (String linea : partirEnLineas(m.destacado, anchoMax - pad * 2)) {
            mayor = max(mayor, textWidth(linea));
        }
    }
    return mayor + pad * 2;
}

// Las del influencer van a la izquierda, azul oscuro con letra blanca y su
// foto al lado; las del jugador, a la derecha y en blanco.
void dibujarMensaje(Mensaje m, float y, float anchoMax, float alto) {
    float pad = padCel;
    float ancho = anchoMensaje(m, anchoMax);
    float r = tx(13, 10);
    float x = m.mio ? panX + panAncho - pad - ancho : panX + pad + r * 2 + pad * 0.6;
    if (!m.mio) {
        dibujarAvatar(panX + pad + r, y + alto - r, r);
    }
    noStroke();
    fill(COLOR_SOMBRA);
    rect(x + 2, y + 2, ancho, alto, pad);
    fill(m.mio ? COLOR_BLANCO : COLOR_AZUL_OSCURO);
    rect(x, y, ancho, alto, pad);

    float yTexto = y + pad * 0.8;
    fill(m.mio ? COLOR_TEXTO : COLOR_TEXTO_CLARO);
    textAlign(LEFT, TOP);
    usarLetra(LETRA_TEXTO, tamanoChat());
    yTexto += dibujarParrafo(m.texto, x + pad, yTexto, anchoMax - pad * 2);
    if (m.destacado != null) {
        yTexto += pad * 0.4;
        fill(m.mio ? COLOR_AZUL_OSCURO : COLOR_POSTIT);
        usarLetra(LETRA_NEGRITA, tamanoChat());
        dibujarParrafo(m.destacado, x + pad, yTexto, anchoMax - pad * 2);
    }
}

// Los tres puntos que saltan mientras el influencer escribe. Devuelve su alto.
float dibujarEscribiendo(float yAbajo) {
    float pad = padCel;
    float r = tx(13, 10);
    float alto = tx(34, 26);
    float ancho = alto * 1.9;
    float x = panX + pad + r * 2 + pad * 0.6;
    float y = yAbajo - alto;
    dibujarAvatar(panX + pad + r, y + alto - r, r);
    noStroke();
    fill(COLOR_AZUL_OSCURO);
    rect(x, y, ancho, alto, pad);
    for (int i = 0; i < 3; i++) {
        float salto = sin(millis() * 0.012 - i * 0.9) * alto * 0.12;
        fill(COLOR_BLANCO, 200);
        ellipse(x + ancho * (0.3 + i * 0.2), y + alto / 2 + min(0, salto), alto * 0.2, alto * 0.2);
    }
    return alto;
}

// --- Barra de enviar ---

boolean puedeEnviar() {
    if (modoApoyo()) {
        return faseCelular == CEL_ELIGIENDO && barrioElegido >= 0;
    }
    return faseCelular == CEL_ELIGIENDO && tarjetaElegida >= 0 && barrioElegido >= 0;
}

boolean mouseEnEnviar() {
    return dist(mouseX, mouseY, enviarX, enviarY) <= radioEnviar;
}

// La caja dice que falta por elegir; el boton redondo solo se pone verde
// cuando ya hay tarjeta y barrio.
void dibujarComposer() {
    float x = panX + padCel;
    float ancho = enviarX - radioEnviar - padCel * 0.6 - x;
    noStroke();
    fill(COLOR_AZUL_OSCURO, 120);
    rect(x, composerY, ancho, altoComposer, altoComposer / 2);

    String texto;
    color colorTexto = COLOR_TEXTO_CREMA;
    GrafoCiudad ciudad = partida.getCiudad();
    if (modoApoyo() && faseCelular == CEL_VIAJANDO) {
        texto = "Llevando el apoyo a " + ciudad.getNombre(envioBarrio) + "...";
    } else if (modoApoyo() && faseCelular == CEL_LISTO) {
        texto = "Ya pusiste el apoyo del parque.";
    } else if (modoApoyo() && puedeEnviar()) {
        texto = "Listo: +" + apoyoEvento + " de apoyo a " + ciudad.getNombre(barrioElegido);
        colorTexto = COLOR_BLANCO;
    } else if (modoApoyo()) {
        texto = "Elige en el mapa dónde va el apoyo →";
    } else if (faseCelular == CEL_VIAJANDO) {
        texto = "Publicando en " + ciudad.getNombre(envioBarrio) + "...";
    } else if (faseCelular == CEL_LISTO) {
        texto = "Ya publicaste en este turno.";
    } else if (puedeEnviar()) {
        texto = (usarTransmision ? "EN VIVO: enviar a " : "Listo: enviar a ") + ciudad.getNombre(barrioElegido);
        colorTexto = COLOR_BLANCO;
    } else if (tarjetaElegida >= 0) {
        texto = "Falta el barrio: elígelo en el mapa →";
    } else if (barrioElegido >= 0) {
        texto = "Falta la tarjeta: elige una abajo";
    } else {
        texto = "Elige una tarjeta y un barrio...";
    }
    fill(colorTexto);
    ajustarLetra(LETRA_NEGRITA, texto, ancho - altoComposer * 0.8, tx(14, 11));
    textAlign(LEFT, CENTER);
    text(texto, x + altoComposer * 0.4, composerY + altoComposer / 2 - 1);

    boolean activo = puedeEnviar();
    boolean encima = activo && mouseEnEnviar();
    if (encima) {
        pedirCursorMano();
    }
    stroke(COLOR_CONTORNO);
    strokeWeight(grosorContorno);
    fill(activo ? (encima ? COLOR_VERDE_LIMA : COLOR_VERDE) : COLOR_GRIS_CLARO);
    float latido = activo ? 1 + 0.05 * sin(millis() * 0.008) : 1;
    ellipse(enviarX, enviarY, radioEnviar * 2 * latido, radioEnviar * 2 * latido);
    dibujarAvion(enviarX, enviarY, radioEnviar * 0.5, activo ? COLOR_BLANCO : COLOR_GRIS);
}

// El avioncito de papel de "enviar".
void dibujarAvion(float cx, float cy, float r, color c) {
    noStroke();
    fill(c);
    triangle(cx - r, cy - r * 0.75, cx + r * 1.05, cy, cx - r * 0.35, cy + r * 0.05);
    fill(c, 170);
    triangle(cx - r, cy + r * 0.75, cx + r * 1.05, cy, cx - r * 0.35, cy + r * 0.05);
}

// --- Tarjetas ---

float xTarjeta(int i) {
    return panX + padCel + (i % 2) * (anchoTarjeta + separacionTarjetas);
}

float yTarjeta(int i) {
    return tarjetasY + (i / 2) * (altoTarjeta + separacionTarjetas);
}

// La tarjeta bajo el mouse, o -1.
int tarjetaBajoMouse() {
    ArrayList<Tarjeta> tarjetas = partida.getTarjetasDelTurno();
    for (int i = 0; i < tarjetas.size(); i++) {
        float x = xTarjeta(i);
        float y = yTarjeta(i);
        if (mouseX >= x && mouseX <= x + anchoTarjeta && mouseY >= y && mouseY <= y + altoTarjeta) {
            return i;
        }
    }
    return -1;
}

void dibujarTarjetas() {
    if (modoApoyo()) {
        dibujarResultadoEventoCelular();   // en vez de tarjetas, la lista del evento
        return;
    }
    ArrayList<Tarjeta> tarjetas = partida.getTarjetasDelTurno();
    int bajoMouse = faseCelular == CEL_ELIGIENDO ? tarjetaBajoMouse() : -1;
    for (int i = 0; i < tarjetas.size(); i++) {
        dibujarTarjeta(tarjetas.get(i), i, i == bajoMouse);
    }
}

void dibujarTarjeta(Tarjeta t, int i, boolean encima) {
    float x = xTarjeta(i);
    float y = yTarjeta(i);
    float w = anchoTarjeta;
    float h = altoTarjeta;
    float radio = padCel * 0.8;
    boolean elegida = i == tarjetaElegida;
    boolean apagada = faseCelular != CEL_ELIGIENDO && !elegida;
    if (encima && !partida.estaBloqueada(t)) {
        pedirCursorMano();
    }

    color fondo = COLOR_TARJETA;
    if (partida.estaBloqueada(t)) {
        fondo = COLOR_GRIS_CLARO;
    } else if (elegida) {
        fondo = COLOR_POSTIT;
    } else if (encima) {
        fondo = COLOR_BLANCO;
    }
    float elevacion = (encima && !partida.estaBloqueada(t)) || (elegida && faseCelular == CEL_ELIGIENDO) ? 2 : 0;
    noStroke();
    fill(COLOR_SOMBRA);
    rect(x + 3, y + 3, w, h, radio);
    stroke(COLOR_CONTORNO);
    strokeWeight(elegida ? grosorContorno * 1.4 : 1.5);
    fill(fondo, apagada ? 150 : 255);
    rect(x, y - elevacion, w, h, radio);

    // Numero para elegirla con el teclado (1 a 6); la elegida lleva un
    // check en su lugar.
    if (elegida) {
        dibujarCheck(x + radio * 1.1, y - elevacion + radio * 1.1, tx(9, 7), COLOR_EXITO);
    } else {
        fill(COLOR_AZUL_OSCURO, apagada ? 110 : 200);
        usarLetra(LETRA_NEGRITA, tx(11, 9));
        textAlign(LEFT, TOP);
        text(i + 1, x + radio * 0.6, y - elevacion + radio * 0.45);
    }

    // Abajo puede ir una franja: en la bloqueada dice por que no se puede
    // usar, y cuando el influencer ya conto el resultado, cada tarjeta dice
    // lo que valia (asi se aprende para la proxima noticia).
    boolean conValor = (reaccionLista() || t.getCategoria() == Influencer.IA) && !partida.estaBloqueada(t);
    float altoAviso = (partida.estaBloqueada(t) || conValor) ? tx(12, 9) * 1.6 : 0;
    float margenTexto = padCel * 1.6;
    float anchoTexto = w - margenTexto * 2;
    float altoDisponible = h - padCel * 1.2 - altoAviso;
    float tamano = tamanoQueCabe(t.getTexto(), anchoTexto, altoDisponible);
    usarLetra(LETRA_NEGRITA, tamano);
    ArrayList<String> lineas = partirEnLineas(t.getTexto(), anchoTexto);
    float paso = interlineado();
    float yTexto = y - elevacion + (h - altoAviso - lineas.size() * paso) / 2;
    fill(partida.estaBloqueada(t) ? COLOR_TEXTO_SUAVE : COLOR_TEXTO, apagada ? 140 : 255);
    textAlign(CENTER, TOP);
    for (int k = 0; k < lineas.size(); k++) {
        text(lineas.get(k), x + w / 2, yTexto + k * paso);
    }

    if (partida.estaBloqueada(t)) {
        noStroke();
        fill(COLOR_ROJO_OSCURO, apagada ? 140 : 255);
        rect(x, y + h - altoAviso, w, altoAviso, 0, 0, radio, radio);
        String aviso = "IA · se desbloquea en el árbol";
        fill(COLOR_BLANCO);
        ajustarLetra(LETRA_NEGRITA, aviso, w - radio * 4, tx(12, 9));
        textAlign(CENTER, CENTER);
        text(aviso, x + w / 2 + radio * 0.8, y + h - altoAviso / 2 - 1);
        dibujarCandado(x + radio * 1.5, y + h - altoAviso / 2 - 1, altoAviso * 0.42, COLOR_BLANCO);
    } else if (conValor) {
        noStroke();
        fill(colorValor(t.getCategoria()));
        rect(x, y - elevacion + h - altoAviso, w, altoAviso, 0, 0, radio, radio);
        fill(COLOR_BLANCO);
        String valor = textoValor(t.getCategoria());
        ajustarLetra(LETRA_NEGRITA, valor, w - radio * 2, tx(12, 9));
        textAlign(CENTER, CENTER);
        text(valor, x + w / 2, y - elevacion + h - altoAviso / 2 - 1);
    }

}

String textoValor(int categoria) {
    if (categoria == Influencer.IA) {
        return partida.probabilidadIA() + "%: +" + Influencer.PUNTOS[Influencer.MAYOR] + " o " + Influencer.PUNTOS[Influencer.NEGATIVA];
    }
    int puntos = Influencer.PUNTOS[categoria];
    String numero = puntos > 0 ? "+" + puntos : "" + puntos;
    String[] nombres = {"la mejor", "buena", "neutra", "resta apoyo"};
    return numero + " · " + nombres[categoria];
}

color colorValor(int categoria) {
    if (categoria == Influencer.IA) {
        return COLOR_ROJO_OSCURO;
    }
    int puntos = Influencer.PUNTOS[categoria];
    if (puntos > 0) {
        return COLOR_EXITO;
    } else if (puntos < 0) {
        return COLOR_ERROR;
    }
    return COLOR_GRIS;
}

// El tamano de letra mas grande (sin pasar del normal) con el que el texto
// cabe en la tarjeta, partido en lineas.
float tamanoQueCabe(String texto, float ancho, float alto) {
    float tamano = tx(14, 11);
    while (tamano > 8) {
        usarLetra(LETRA_NEGRITA, tamano);
        if (partirEnLineas(texto, ancho).size() * interlineado() <= alto) {
            return tamano;
        }
        tamano -= 0.5;
    }
    return 8;
}

// ===========================================================================
// EL MAPA (A LA DERECHA)
// ===========================================================================

void dibujarMapaCelular() {
    image(imgMapaCiudad, mapaPanelX, mapaPanelY, mapaPanelAncho, mapaPanelAlto);

    // Titulo en una etiqueta de papel pegada arriba del mapa.
    String titulo = faseCelular == CEL_ELIGIENDO ? (modoApoyo() ? "¿DÓNDE VA EL APOYO?" : "¿DÓNDE LA PUBLICAMOS?") : "CIUDAD NOVA";
    String cuenta = "Tus barrios: " + contarPropiosVisibles() + " de " + partida.getCiudad().cantidad();
    float celda = celdaInterfaz();
    float anchoTitulo = (medirPixel(titulo) + 6) * celda;
    float altoTitulo = 13 * celda;
    float xt = mapaPanelX + mapaPanelAncho * 0.06;
    float yt = mapaPanelY - altoTitulo * 0.55;
    noStroke();
    fill(COLOR_SOMBRA);
    rect(xt + celda, yt + celda, anchoTitulo, altoTitulo);
    fill(#fff6d8);
    rect(xt, yt, anchoTitulo, altoTitulo);
    textoPixel(titulo, xt + 3 * celda, yt + altoTitulo / 2, celda, #1a1616, LEFT, CENTER);
    textoPixel(cuenta.toUpperCase(), mapaPanelX + mapaPanelAncho * 0.94, yt + altoTitulo / 2, celda, 1, #fff3d6, #1a1010, 0, 0, false, RIGHT, CENTER);

    int bajoMouse = zonaEnMapa(mouseX, mouseY);
    boolean[] propios = propiosVisibles();
    boolean[] alcanzables = partida.alcanzablesDesde(propios);

    dibujarCallesCelular(bajoMouse, alcanzables);
    dibujarViaje();
    dibujarBarriosCelular(bajoMouse, propios, alcanzables);
    dibujarFestejo();
    // Abajo va la leyenda o, si el mouse esta sobre un barrio, su ficha,
    // en una franja oscura pegada al borde de abajo del mapa.
    float altoFranja = tx(34, 26);
    float yFranja = mapaPanelY + mapaPanelAlto - altoFranja * 0.4;
    noStroke();
    fill(COLOR_VELO);
    rect(mapaPanelX + mapaPanelAncho * 0.02, yFranja, mapaPanelAncho * 0.96, altoFranja, altoFranja / 2);
    if (bajoMouse >= 0) {
        dibujarFichaBarrio(bajoMouse, propios, alcanzables, mapaPanelX + mapaPanelAncho * 0.05, yFranja + altoFranja / 2);
    } else {
        dibujarLeyendaCelular(mapaPanelX + mapaPanelAncho * 0.05, yFranja + altoFranja / 2);
    }
}

int contarPropiosVisibles() {
    int cuenta = 0;
    for (boolean propio : propiosVisibles()) {
        if (propio) {
            cuenta++;
        }
    }
    return cuenta;
}

// El barrio al que apunta la vista previa del camino: el que esta bajo el
// mouse si se puede publicar ahi, o si no el ya elegido.
int destinoVistaPrevia(int bajoMouse, boolean[] alcanzables) {
    if (faseCelular != CEL_ELIGIENDO) {
        return -1;
    }
    if (bajoMouse >= 0 && alcanzables[bajoMouse]) {
        return bajoMouse;
    }
    return barrioElegido;
}

// Las calles. Mientras se elige, el camino mas corto hasta el barrio de la
// vista previa se pinta amarillo, con sus minutos.
void dibujarCallesCelular(int bajoMouse, boolean[] alcanzables) {
    // Las calles del grafo son las rutas rojas del mapa del equipo: gruesas,
    // con un borde oscuro (primero todos los bordes y después el rojo, así
    // los cruces quedan limpios).
    GrafoCiudad ciudad = partida.getCiudad();
    float grueso = mapaAncho * 0.012;
    strokeCap(SQUARE);
    for (int capa = 0; capa < 2; capa++) {
        stroke(capa == 0 ? color(60, 10, 10, 200) : color(226, 30, 30));
        strokeWeight(capa == 0 ? grueso + max(2, grueso * 0.5) : grueso);
        for (int a = 0; a < ciudad.cantidad(); a++) {
            for (int b = a + 1; b < ciudad.cantidad(); b++) {
                if (ciudad.hayCalle(a, b)) {
                    line(xZona(a), yZona(a), xZona(b), yZona(b));
                }
            }
        }
    }
    strokeCap(ROUND);
    // Los minutos solo se escriben en las calles que importan ahora (las
    // del camino y las del barrio bajo el mouse): con todas, el mapa se
    // llena de etiquetas encima de los nombres.
    boolean[][] conMinutos = new boolean[ciudad.cantidad()][ciudad.cantidad()];
    int destino = destinoVistaPrevia(bajoMouse, alcanzables);
    if (destino >= 0) {
        int origen = ciudad.propioMasCercano(propiosVisibles(), destino);
        ArrayList<Integer> camino = ciudad.caminoMasCorto(origen, destino);
        stroke(COLOR_AMARILLO, 200);
        strokeWeight(tx(9, 5));
        for (int k = 0; k + 1 < camino.size(); k++) {
            int a = camino.get(k);
            int b = camino.get(k + 1);
            line(xZona(a), yZona(a), xZona(b), yZona(b));
            conMinutos[a][b] = true;
            conMinutos[b][a] = true;
        }
    }
    if (bajoMouse >= 0) {
        for (int v : ciudad.vecinos(bajoMouse)) {
            conMinutos[bajoMouse][v] = true;
            conMinutos[v][bajoMouse] = true;
        }
    }
    for (int a = 0; a < ciudad.cantidad(); a++) {
        for (int b = a + 1; b < ciudad.cantidad(); b++) {
            if (conMinutos[a][b]) {
                dibujarMinutos(ciudad.getMinutos(a, b) + " min", (xZona(a) + xZona(b)) / 2, (yZona(a) + yZona(b)) / 2);
            }
        }
    }
}

// Que tan avanzado va el viaje, de 0 a 1.
float avanceViaje() {
    if (faseCelular != CEL_VIAJANDO) {
        return 1;
    }
    return constrain((millis() - momentoEnvio) / (float) duracionViaje, 0, 1);
}

// La publicacion viajando: el tramo ya recorrido queda amarillo y un punto
// de luz avanza por las calles. Cada calle del camino ocupa una parte del
// viaje proporcional a sus minutos, asi las calles largas tardan mas.
void dibujarViaje() {
    if (faseCelular != CEL_VIAJANDO || envioCamino == null) {
        return;
    }
    GrafoCiudad ciudad = partida.getCiudad();
    float t = suavizar(avanceViaje());
    float puntoX = xZona(envioCamino.get(0));
    float puntoY = yZona(envioCamino.get(0));
    float recorrido = 0;
    stroke(COLOR_AMARILLO);
    strokeWeight(tx(11, 6));
    for (int k = 0; k + 1 < envioCamino.size(); k++) {
        int a = envioCamino.get(k);
        int b = envioCamino.get(k + 1);
        float parte = envioMinutos > 0 ? ciudad.getMinutos(a, b) / (float) envioMinutos : 1;
        if (t >= recorrido + parte) {
            line(xZona(a), yZona(a), xZona(b), yZona(b));
            puntoX = xZona(b);
            puntoY = yZona(b);
        } else if (t > recorrido) {
            float u = (t - recorrido) / parte;
            puntoX = lerp(xZona(a), xZona(b), u);
            puntoY = lerp(yZona(a), yZona(b), u);
            line(xZona(a), yZona(a), puntoX, puntoY);
        }
        recorrido += parte;
    }
    noStroke();
    for (int i = 4; i >= 1; i--) {
        fill(COLOR_AMARILLO, 45);
        float d = tx(16, 11) * (1 + i * 0.45);
        ellipse(puntoX, puntoY, d, d);
    }
    fill(COLOR_BLANCO);
    ellipse(puntoX, puntoY, tx(14, 10), tx(14, 10));
}

// Los barrios son las ubicaciones del mapa del equipo (Mapa.html): cada una
// con su dibujo (casas, edificios, el puerto, el mercado), balanceándose un
// poquito. Los que todavía no se pueden tocar llevan un candado; con el
// mouse encima crecen y muestran su etiqueta de papel; el elegido lleva un
// borde blanco. Los propios, una chinche del color del candidato.
void dibujarBarriosCelular(int bajoMouse, boolean[] propios, boolean[] alcanzables) {
    GrafoCiudad ciudad = partida.getCiudad();
    boolean eligiendo = faseCelular == CEL_ELIGIENDO;
    for (int z = 0; z < ciudad.cantidad(); z++) {
        if (z == bajoMouse || (z == barrioElegido && eligiendo)) {
            continue;   // se dibujan al final, encima de los demás
        }
        dibujarBarrioMapa(z, bajoMouse, propios, alcanzables);
    }
    if (barrioElegido >= 0 && eligiendo && barrioElegido != bajoMouse) {
        dibujarBarrioMapa(barrioElegido, bajoMouse, propios, alcanzables);
    }
    if (bajoMouse >= 0) {
        dibujarBarrioMapa(bajoMouse, bajoMouse, propios, alcanzables);
    }
}

void dibujarBarrioMapa(int z, int bajoMouse, boolean[] propios, boolean[] alcanzables) {
    boolean eligiendo = faseCelular == CEL_ELIGIENDO;
    boolean alcance = alcanzables[z];
    boolean bloqueado = !propios[z] && !alcance;
    boolean encima = z == bajoMouse;
    boolean elegido = z == barrioElegido && eligiendo;
    PImage img = pinesBarrio[z];
    float w = mapaAncho * 0.085 * (encima ? 1.14 : 1);
    float h = w * img.height / img.width;
    // el vaivén de cada ubicación (como .pin del HTML)
    float zx = xZona(z) + sin(millis() / (5000.0 + z * 500) * TWO_PI + z) * w * 0.035;
    float zy = yZona(z);
    if (eligiendo && alcance && encima) {
        pedirCursorMano();
    }
    if (eligiendo && alcance && !propios[z]) {
        float latido = 0.5 + 0.5 * sin(millis() * 0.006 + z);
        noStroke();
        fill(COLOR_AMARILLO, elegido ? 0 : 70 + 80 * latido);
        rect(zx - w * 0.62, zy - h * 0.62, w * 1.24, h * 1.24);
    }
    if (elegido) {
        // el borde del elegido: blanco por fuera y oscuro por dentro
        noStroke();
        fill(#2b1a2a);
        rect(zx - w * 0.62, zy - h * 0.62, w * 1.24, h * 1.24);
        fill(#fff8e0);
        rect(zx - w * 0.58, zy - h * 0.58, w * 1.16, h * 1.16);
    }
    noStroke();
    fill(0, 70);
    rect(zx - w / 2 + w * 0.05, zy - h / 2 + h * 0.08, w, h);
    if (bloqueado) {
        tint(150);
    }
    image(img, zx - w / 2, zy - h / 2, w, h);
    noTint();
    if (bloqueado) {
        dibujarCandadoMapa(zx, zy, w * 0.46);
    }
    if (propios[z]) {
        dibujarChinche(zx, zy - h * 0.48, w * 0.13, z == Partida.ZONA_SEDE);
    }
    if (elegido) {
        dibujarPin(zx, zy - h * 0.62, w * 0.2);
    }
    if (encima || elegido) {
        dibujarEtiquetaBarrio(z, zx, zy - h * 0.62 - (elegido ? w * 0.5 : 0), propios[z]);
    }
}

// El candado del HTML (12 x 15 cuadritos)
void dibujarCandadoMapa(float cx, float cy, float ancho) {
    float u = ancho / 12;
    float x = cx - 6 * u, y = cy - 7.5 * u;
    noStroke();
    fill(#2b1a2a);
    rect(x + 2 * u, y + 1 * u, 8 * u, 6 * u);
    fill(#aeb4bb);
    rect(x + 3 * u, y + 2 * u, 6 * u, 5 * u);
    fill(#2b1a2a);
    rect(x + 4.5 * u, y + 3 * u, 3 * u, 4 * u);
    rect(x + 1 * u, y + 6 * u, 10 * u, 8 * u);
    fill(#ecd2a4);
    rect(x + 2 * u, y + 7 * u, 8 * u, 6 * u);
    fill(#c9a06b);
    rect(x + 2 * u, y + 11 * u, 8 * u, 2 * u);
    fill(#2b1a2a);
    rect(x + 5 * u, y + 8 * u, 2 * u, 3 * u);
}

// La etiqueta de papel sobre el barrio: el nombre y el apoyo de cada
// candidato (un cuadrito de su color y su porcentaje). En una partida de
// un jugador solo se sabe el del jugador.
void dibujarEtiquetaBarrio(int z, float cx, float yAbajo, boolean propio) {
    float celda = max(1.5, celdaInterfaz() * 0.85);
    String nombre = partida.getCiudad().getNombre(z).toUpperCase();
    IntList asientos = new IntList();
    if (enRed() && campanaEnRed) {
        for (int a = 0; a < 4; a++) {
            if (a == miAsientoRed || (humanoAsiento[a] && tieneTabla[a])) {
                asientos.append(a);
            }
        }
    } else {
        asientos.append(0);
    }
    String[] textos = new String[asientos.size()];
    float anchoPuntos = 0;
    for (int i = 0; i < asientos.size(); i++) {
        int a = asientos.get(i);
        int v = a == (enRed() ? miAsientoRed : 0) ? apoyoVisible(z) : apoyoAsiento[a][z];
        textos[i] = v + "%";
        anchoPuntos += (medirPixel(textos[i]) + 12) * celda;
    }
    float ancho = max(medirPixel(nombre) * celda, anchoPuntos) + 14 * celda;
    float alto = 27 * celda;
    float x = cx - ancho / 2, y = yAbajo - alto - 4 * celda;
    noStroke();
    fill(#2b1a2a);
    rect(x - 3 * celda / 2, y - 3 * celda / 2, ancho + 3 * celda, alto + 3 * celda);
    rect(cx - 1.5 * celda, y + alto, 3 * celda, 3 * celda);
    fill(#ecd2a4);
    rect(x, y, ancho, alto);
    fill(#c9a06b);
    rect(x, y + alto - 2 * celda, ancho, 2 * celda);
    fill(#f6e4c0);
    rect(x, y, ancho, 2 * celda);
    textoPixel(nombre, cx, y + 8 * celda, celda, #2b1a2a, CENTER, CENTER);
    float xi = cx - anchoPuntos / 2;
    for (int i = 0; i < asientos.size(); i++) {
        fill(#2b1a2a);
        rect(xi, y + 15 * celda, 8 * celda, 8 * celda);
        fill(COLOR_ASIENTO[asientos.get(i)]);
        rect(xi + celda, y + 16 * celda, 6 * celda, 6 * celda);
        textoPixel(textos[i], xi + 10 * celda, y + 19 * celda, celda, #2b1a2a, LEFT, CENTER);
        xi += (medirPixel(textos[i]) + 12) * celda;
    }
}

// La chinche que sujeta un post-it propio (la de la sede lleva el centro
// blanco, como el circulo blanco de antes).
void dibujarChinche(float cx, float cy, float r, boolean sede) {
    noStroke();
    fill(COLOR_SOMBRA);
    ellipse(cx + r * 0.25, cy + r * 0.3, r * 2, r * 2);
    stroke(COLOR_CONTORNO);
    strokeWeight(1.5);
    fill(COLOR_ASIENTO[enRed() ? miAsientoRed : 0]);
    ellipse(cx, cy, r * 2, r * 2);
    noStroke();
    fill(sede ? COLOR_BLANCO : color(255, 255, 255, 120));
    ellipse(cx - (sede ? 0 : r * 0.3), cy - (sede ? 0 : r * 0.3), r * (sede ? 0.9 : 0.6), r * (sede ? 0.9 : 0.6));
}

// Un pin amarillo sobre el barrio elegido.
void dibujarPin(float cx, float yPunta, float r) {
    stroke(COLOR_CONTORNO);
    strokeWeight(2);
    fill(COLOR_AMARILLO);
    triangle(cx - r * 0.55, yPunta - r * 1.2, cx + r * 0.55, yPunta - r * 1.2, cx, yPunta);
    ellipse(cx, yPunta - r * 1.5, r * 1.6, r * 1.6);
    noStroke();
    fill(COLOR_CONTORNO);
    ellipse(cx, yPunta - r * 1.5, r * 0.55, r * 0.55);
}

// Al llegar la publicacion: ondas que salen del barrio y el cambio de apoyo
// subiendo; si se conquisto, un letrero mas grande.
void dibujarFestejo() {
    if (faseCelular != CEL_LISTO) {
        return;
    }
    float t = (millis() - momentoLlegada()) / (float) DURACION_FESTEJO;
    if (t >= 1) {
        return;
    }
    float zx = xZona(envioBarrio);
    float zy = yZona(envioBarrio);
    color c = envioCambio > 0 ? COLOR_VERDE_LIMA : (envioCambio < 0 ? COLOR_ROJO : COLOR_BLANCO);
    noFill();
    for (int i = 0; i < 3; i++) {
        float ti = t * 1.4 - i * 0.18;
        if (ti > 0 && ti < 1) {
            stroke(c, 255 * (1 - ti));
            strokeWeight(tx(4, 2));
            float d = radioZonaMapa() * 2 * (1 + ti * 2.2);
            ellipse(zx, zy, d, d);
        }
    }
    float opacidad = t < 0.75 ? 255 : map(t, 0.75, 1, 255, 0);
    float subida = radioZonaMapa() * (1.4 + t * 1.6);
    float celda = max(2, celdaInterfaz());
    String texto = envioCambio > 0 ? "+" + envioCambio : (envioCambio < 0 ? "" + envioCambio : "±0");
    tint(255, opacidad);
    textoPixel(texto, zx, zy - subida, celda, 3, c, COLOR_CONTORNO, 0, 0, false, CENTER, BOTTOM);
    if (envioConquisto) {
        textoPixel("¡CONQUISTADO!", zx, zy - subida - 26 * celda, celda, 2, COLOR_AMARILLO, COLOR_CONTORNO, 0, 0, false, CENTER, BOTTOM);
    }
    // Los bonos de Volantes y Megafono, mas pequenos, sobre cada barrio.
    for (int z = 0; z < partida.getCiudad().cantidad(); z++) {
        int bono = envioPublicacion != null ? envioPublicacion.getBono(z) : 0;
        if (bono > 0) {
            textoPixel("+" + bono, xZona(z), yZona(z) - radioZonaMapa() * (1.2 + t), celda, 2, COLOR_VERDE_LIMA, COLOR_CONTORNO, 0, 0, false, CENTER, BOTTOM);
        }
    }
    noTint();
}

void dibujarLeyendaCelular(float x, float y) {
    float celda = max(1.5, celdaInterfaz() * 0.85);
    String[] textos = {"TUYO", "PUEDES PUBLICAR AHÍ", "CON CANDADO: FUERA DE ALCANCE"};
    color[] colores = {COLOR_ASIENTO[enRed() ? miAsientoRed : 0], COLOR_AMARILLO, #aeb4bb};
    float xi = x;
    for (int i = 0; i < textos.length; i++) {
        noStroke();
        fill(#1a1010);
        rect(xi, y - 4 * celda, 8 * celda, 8 * celda);
        fill(colores[i]);
        rect(xi + celda, y - 3 * celda, 6 * celda, 6 * celda);
        textoPixel(textos[i], xi + 11 * celda, y, celda, #ffffff, LEFT, CENTER);
        xi += (medirPixel(textos[i]) + 20) * celda;
    }
    textoPixel("· CON " + Partida.UMBRAL_CONQUISTA + "% EL BARRIO ES TUYO", xi, y, celda, #9fd3ff, LEFT, CENTER);
}

// La ficha del barrio bajo el mouse, en la franja de abajo del mapa: su
// nombre, si es propio o se puede publicar ahí, su apoyo y, si se puede,
// por donde llega la publicación y en cuántos minutos.
void dibujarFichaBarrio(int z, boolean[] propios, boolean[] alcanzables, float x, float y) {
    GrafoCiudad ciudad = partida.getCiudad();
    String estadoBarrio;
    color colorEstadoBarrio;
    if (z == Partida.ZONA_SEDE) {
        estadoBarrio = "TU SEDE";
        colorEstadoBarrio = COLOR_ROSADO;
    } else if (propios[z]) {
        estadoBarrio = "ES TUYO";
        colorEstadoBarrio = COLOR_ROSADO;
    } else if (alcanzables[z]) {
        estadoBarrio = faseCelular == CEL_ELIGIENDO ? "PUEDES PUBLICAR AQUÍ" : "AL ALCANCE EL PRÓXIMO TURNO";
        colorEstadoBarrio = COLOR_VERDE_LIMA;
    } else {
        estadoBarrio = "FUERA DE ALCANCE";
        colorEstadoBarrio = COLOR_GRIS_CLARO;
    }
    String detalle = "APOYO " + apoyoVisible(z) + "%";
    if (alcanzables[z] && faseCelular == CEL_ELIGIENDO) {
        int origen = ciudad.propioMasCercano(propios, z);
        ArrayList<Integer> camino = ciudad.caminoMasCorto(origen, z);
        if (camino.size() == 1) {
            detalle += " · SE PUBLICA AQUÍ MISMO";
        } else {
            detalle += " · LLEGA EN " + ciudad.minutosMasCorto(origen, z) + " MIN: ";
            for (int k = 0; k < camino.size(); k++) {
                detalle += (k > 0 ? " > " : "") + ciudad.getNombre(camino.get(k)).toUpperCase();
            }
        }
    } else if (!alcanzables[z]) {
        detalle += " · A MÁS DE " + partida.callesDeAlcance() + (partida.callesDeAlcance() == 1 ? " CALLE" : " CALLES") + " DE TUS BARRIOS";
    }
    float derecha = mapaPanelX + mapaPanelAncho - (x - mapaPanelX);
    float celda = max(1.5, celdaInterfaz() * 0.85);
    String nombre = ciudad.getNombre(z).toUpperCase();
    textoPixel(nombre, x, y, celda, #ffffff, LEFT, CENTER);
    float xi = x + (medirPixel(nombre) + 8) * celda;
    textoPixel(estadoBarrio, xi, y, celda, colorEstadoBarrio, LEFT, CENTER);
    xi += (medirPixel(estadoBarrio) + 8) * celda;
    float c2 = celda;
    while (medirPixel(detalle) * c2 > derecha - xi && c2 > 0.8) {
        c2 *= 0.9;
    }
    textoPixel(detalle, xi, y, c2, #9fd3ff, LEFT, CENTER);
}

// ===========================================================================
// CLICS Y TECLADO
// ===========================================================================

void clicEnCelular() {
    if (botonVolverCelular.contiene(mouseX, mouseY)) {
        irA(MENU);
        return;
    }
    if (faseCelular == CEL_LISTO && botonCuadernoCelular.contiene(mouseX, mouseY)) {
        irA(ARBOL);
        cuadernoYaAbierto = true;
        return;
    }
    // un clic fuera del celular y del mapa lo cierra
    boolean enCelular = mouseX >= celX && mouseX <= celX + celAncho && mouseY >= celY && mouseY <= celY + celAlto;
    boolean enMapa = mouseX >= mapaPanelX && mouseX <= mapaPanelX + mapaPanelAncho && mouseY >= mapaPanelY && mouseY <= mapaPanelY + mapaPanelAlto;
    if (!enCelular && !enMapa) {
        irA(MENU);
        return;
    }
    if (faseCelular != CEL_ELIGIENDO) {
        return;
    }
    if (mouseEnEnviar()) {
        if (modoApoyo()) {
            enviarApoyoEvento();
        } else {
            enviarPublicacion();
        }
        return;
    }
    if (transmisionDisponible() && mouseEnTransmision()) {
        usarTransmision = !usarTransmision;
        avisar(usarTransmision ? "Transmisión en vivo activada: esta publicación contará como la mejor (solo una vez por partida)."
            : "Transmisión en vivo desactivada.");
        return;
    }
    int t = modoApoyo() ? -1 : tarjetaBajoMouse();
    if (t >= 0) {
        elegirTarjeta(t);
        return;
    }
    int z = zonaEnMapa(mouseX, mouseY);
    if (z >= 0) {
        elegirBarrio(z);
    }
}

void elegirTarjeta(int i) {
    ArrayList<Tarjeta> tarjetas = partida.getTarjetasDelTurno();
    if (i < 0 || i >= tarjetas.size()) {
        return;
    }
    if (partida.estaBloqueada(tarjetas.get(i))) {
        avisar("La opción de IA se desbloquea con el «Asistente de IA» del árbol (desde la ronda 2).");
        return;
    }
    tarjetaElegida = i;
}

void elegirBarrio(int z) {
    if (partida.puedePublicarEn(z)) {
        barrioElegido = z;
    } else {
        avisar(partida.getCiudad().getNombre(z) + " está fuera de alcance: solo puedes publicar en tus barrios y en los que tienen calle con ellos.");
    }
}

// Del 1 al 6 eligen tarjeta; Enter envia.
void teclaCelular() {
    if (faseCelular != CEL_ELIGIENDO) {
        return;
    }
    if (modoApoyo()) {
        if (key == ENTER || key == RETURN) {
            enviarApoyoEvento();
        }
        return;
    }
    if (key >= '1' && key <= '6') {
        elegirTarjeta(key - '1');
    } else if (key == ENTER || key == RETURN) {
        enviarPublicacion();
    }
}
