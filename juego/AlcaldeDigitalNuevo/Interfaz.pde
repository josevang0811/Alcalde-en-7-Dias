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
void ajustarLetra(int tipo, String texto, float anchoMax, float tamano) {
    usarLetra(tipo, tamano);
    float anchoTexto = textWidth(texto);
    if (anchoTexto > anchoMax) {
        usarLetra(tipo, tamano * anchoMax / anchoTexto);
    }
}

void ajustarLetraEscena(int tipo, String texto, float anchoMax, float tamanoLienzo) {
    usarLetraEscena(tipo, tamanoLienzo);
    float anchoTexto = textWidth(texto);
    if (anchoTexto > anchoMax) {
        usarLetraEscena(tipo, tamanoLienzo * anchoMax / anchoTexto);
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

// Parte un texto en dos lineas lo mas parejas posible. Se usa con los
// nombres de habilidad que no caben en una sola linea dentro del nodo
// ("Transmisión en vivo" queda "Transmisión" / "en vivo").
String[] partirEnDos(String texto) {
    String[] palabras = split(texto, ' ');
    if (palabras.length < 2) {
        return new String[] {texto};
    }
    String[] mejor = {texto, ""};
    float mejorAncho = Float.MAX_VALUE;
    for (int i = 1; i < palabras.length; i++) {
        String arriba = join(subset(palabras, 0, i), " ");
        String abajo = join(subset(palabras, i, palabras.length - i), " ");
        float anchoMayor = max(textWidth(arriba), textWidth(abajo));
        if (anchoMayor < mejorAncho) {
            mejorAncho = anchoMayor;
            mejor[0] = arriba;
            mejor[1] = abajo;
        }
    }
    return mejor;
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

// Fondo de las pantallas del cuaderno y del manual: la superficie del
// escritorio vista desde arriba, con vetas onduladas.
void dibujarFondoMadera() {
    background(COLOR_MADERA);
    stroke(COLOR_MADERA_VETA);
    strokeWeight(max(1, 1.6 * escala));
    noFill();
    float separacion = max(18, 30 * escala);
    for (float y = separacion * 0.5; y < height; y += separacion) {
        beginShape();
        for (float x = -20; x <= width + 40; x += 40) {
            vertex(x, y + sin(x * 0.004 + y * 0.07) * separacion * 0.2);
        }
        endShape();
    }
}

// --- Iconos ---
// Se dibujan con figuras basicas en vez de caracteres tipo emoji: asi no
// dependen de que la fuente del sistema tenga ese simbolo y se ven iguales
// en cualquier computador. Todos reciben un tamano (r) para escalar.

void dibujarMoneda(float x, float y, float r) {
    stroke(COLOR_CONTORNO);
    strokeWeight(max(1.2, r * 0.14));
    fill(COLOR_MONEDA);
    ellipse(x, y, r * 2, r * 2);
    noFill();
    stroke(COLOR_DORADO);
    strokeWeight(max(1, r * 0.12));
    ellipse(x, y, r * 1.35, r * 1.35);
}

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

void dibujarEstrella(float cx, float cy, float radioExterior, float radioInterior) {
    beginShape();
    for (int i = 0; i < 10; i++) {
        float angulo = -HALF_PI + i * PI / 5;
        float r = (i % 2 == 0) ? radioExterior : radioInterior;
        vertex(cx + cos(angulo) * r, cy + sin(angulo) * r);
    }
    endShape(CLOSE);
}

// ===========================================================================
// 3. MENU PRINCIPAL: LA OFICINA
// ===========================================================================
// La oficina se dibuja sobre un lienzo de referencia de 1200 x 675 (16:9, la
// proporcion del dibujo original) y se escala de una sola vez con scale():
// por eso aqui si aparecen coordenadas fijas, pero son del lienzo, no
// pixeles de la pantalla. Las paredes, el piso y las patas del escritorio se
// dibujan mas grandes que el lienzo para que, si el monitor no es 16:9, lo
// que sobra muestre mas habitacion en vez de franjas vacias.
//
// Cada objeto se dibuja siempre en su posicion normal; el aumento y el
// brillo cuando el mouse esta encima los agrega dibujarObjetoResaltado().

final float ANCHO_ESCENA = 1200;
final float ALTO_ESCENA = 670;   // 1200 / (2576 / 1438): la proporcion del dibujo
final float LINEA_PISO = 345;         // donde la pared del fondo toca el piso
final float ESQUINA_IZQUIERDA = 130;  // esquinas de la pared del fondo
final float ESQUINA_DERECHA = 1050;
final float FUGA_X = 590;             // punto de fuga de la perspectiva
final float FUGA_Y = -120;
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

// Cada objeto interactivo tiene su propia funcion de dibujo; esta solo
// elige cual llamar.
void dibujarObjeto(ObjetoOficina o) {
    if (o == objetoCuaderno) {
        dibujarCuaderno();
    } else if (o == objetoPostit) {
        dibujarPostit();
    } else if (o == objetoPuerta) {
        dibujarPuerta();
    } else if (o == objetoTelevisor) {
        dibujarTelevisor();
    } else if (o == objetoTelefono) {
        dibujarTelefono();
    } else if (o == objetoCelular) {
        dibujarCelular();
    } else if (o == objetoEstanteria) {
        dibujarEstanteria();
    }
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

// El objeto bajo el mouse se vuelve a dibujar encima de la foto, un poco
// mas grande y con un brillo detras. Como crece desde su centro, tapa por
// completo su copia de la foto.
void dibujarObjetoResaltado() {
    ObjetoOficina o = objetoResaltado;
    if (o == null) {
        return;
    }
    dibujarBrillo(o);
    pushMatrix();
    translate(o.centroX(), o.centroY());
    scale(aumentoDe(o));
    translate(-o.centroX(), -o.centroY());
    // Mientras se dibuja agrandado, sus letras se crean a ese tamano mayor
    // para que no se vean pixeladas (ver usarLetraEscena()).
    aumentoTexto = aumentoDe(o);
    dibujarObjeto(o);
    aumentoTexto = 1;
    popMatrix();
}

// Los objetos pequenos crecen un poco mas que los grandes al pasar el
// mouse: la puerta crece apenas, el celular se nota bastante.
float aumentoDe(ObjetoOficina o) {
    return 1 + min(0.06, 10 / max(o.ancho, o.alto));
}

// Varias elipses casi transparentes, una encima de otra, hacen un brillo
// suave detras del objeto: amarillo si funciona, blanco si todavia no (o si
// tiene que esperar a que se conteste el telefono).
void dibujarBrillo(ObjetoOficina o) {
    noStroke();
    for (int i = 5; i >= 1; i--) {
        if (disponibleAhora(o)) {
            fill(COLOR_BRILLO, 34);
        } else {
            fill(COLOR_BLANCO, 34);
        }
        ellipse(o.centroX(), o.centroY(), o.ancho * (1 + i * 0.1), o.alto * (1 + i * 0.1));
    }
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

// --- Perspectiva ---
// La habitacion tiene un punto de fuga (FUGA_X, FUGA_Y): toda linea que va
// "hacia el fondo" apunta hacia el. Esta funcion da la altura y en la que
// la linea que sale del punto de fuga y pasa por (xRef, yRef) cruza la
// vertical x. Con ella se ubican el piso de las paredes laterales, la
// puerta y el mapa, para que respeten la perspectiva.
float yEnPerspectiva(float x, float xRef, float yRef) {
    return FUGA_Y + (yRef - FUGA_Y) * (x - FUGA_X) / (xRef - FUGA_X);
}

float pisoIzquierdo(float x) {
    return yEnPerspectiva(x, ESQUINA_IZQUIERDA, LINEA_PISO);
}

float pisoDerecho(float x) {
    return yEnPerspectiva(x, ESQUINA_DERECHA, LINEA_PISO);
}

// Punto dentro de un cuadrilatero a partir de coordenadas relativas (u, v)
// entre 0 y 1. Las esquinas van en el orden: arriba-izquierda,
// arriba-derecha, abajo-derecha, abajo-izquierda. Sirve para dibujar cosas
// "pegadas" a una superficie en perspectiva (los paneles de la puerta, las
// calles del mapa) pensandolas como si fueran planas.
PVector puntoEnCuadro(float[] c, float u, float v) {
    float xArriba = lerp(c[0], c[2], u);
    float yArriba = lerp(c[1], c[3], u);
    float xAbajo = lerp(c[6], c[4], u);
    float yAbajo = lerp(c[7], c[5], u);
    return new PVector(lerp(xArriba, xAbajo, v), lerp(yArriba, yAbajo, v));
}

void cuadroRelativo(float[] c, float u1, float v1, float u2, float v2) {
    PVector a = puntoEnCuadro(c, u1, v1);
    PVector b = puntoEnCuadro(c, u2, v1);
    PVector d = puntoEnCuadro(c, u2, v2);
    PVector e = puntoEnCuadro(c, u1, v2);
    quad(a.x, a.y, b.x, b.y, d.x, d.y, e.x, e.y);
}

// Linea quebrada dentro de un cuadrilatero: "puntos" trae pares (u, v).
void trazoEnCuadro(float[] c, float[] puntos) {
    noFill();
    beginShape();
    for (int i = 0; i < puntos.length; i += 2) {
        PVector p = puntoEnCuadro(c, puntos[i], puntos[i + 1]);
        vertex(p.x, p.y);
    }
    endShape();
}

// --- La habitacion ---

void dibujarHabitacion() {
    stroke(COLOR_CONTORNO);
    strokeWeight(GROSOR_ESCENA);

    fill(COLOR_PARED);
    rect(ESQUINA_IZQUIERDA, -700, ESQUINA_DERECHA - ESQUINA_IZQUIERDA, LINEA_PISO + 700);

    fill(COLOR_PARED_LATERAL);
    quad(-1000, -700, ESQUINA_IZQUIERDA, -700, ESQUINA_IZQUIERDA, LINEA_PISO, -1000, pisoIzquierdo(-1000));
    quad(ESQUINA_DERECHA, -700, 2200, -700, 2200, pisoDerecho(2200), ESQUINA_DERECHA, LINEA_PISO);

    fill(COLOR_PISO);
    beginShape();
    vertex(-1000, pisoIzquierdo(-1000));
    vertex(ESQUINA_IZQUIERDA, LINEA_PISO);
    vertex(ESQUINA_DERECHA, LINEA_PISO);
    vertex(2200, pisoDerecho(2200));
    vertex(2200, 1800);
    vertex(-1000, 1800);
    endShape(CLOSE);
}

// El mapa de la ciudad colgado en la pared izquierda (decorativo). Su borde
// cercano (x = 15) se ve mas alto que el lejano, como pide la perspectiva.
float[] esquinasMapa() {
    float xCerca = 15;
    float xLejos = 105;
    return new float[] {
        xCerca, 45,
        xLejos, yEnPerspectiva(xLejos, xCerca, 45),
        xLejos, yEnPerspectiva(xLejos, xCerca, 305),
        xCerca, 305
    };
}

void dibujarMapaPared() {
    float[] c = esquinasMapa();
    stroke(COLOR_CONTORNO);
    strokeWeight(GROSOR_ESCENA + 2);
    fill(COLOR_AZUL_GRIS);
    quad(c[0], c[1], c[2], c[3], c[4], c[5], c[6], c[7]);

    stroke(COLOR_VERDE_LIMA);
    strokeWeight(4);
    trazoEnCuadro(c, new float[] {0.0, 0.3, 0.3, 0.36, 0.45, 0.55, 0.68, 0.6, 1.0, 0.74});
    strokeWeight(2.5);
    trazoEnCuadro(c, new float[] {0.3, 0.0, 0.36, 0.42, 0.22, 1.0});
    trazoEnCuadro(c, new float[] {0.74, 0.0, 0.66, 0.5, 0.82, 1.0});
    trazoEnCuadro(c, new float[] {0.0, 0.84, 0.5, 0.86, 1.0, 0.9});

    // La chinche roja marca la sede de la campana.
    PVector sede = puntoEnCuadro(c, 0.55, 0.4);
    stroke(COLOR_CONTORNO);
    strokeWeight(2);
    fill(COLOR_ROJO);
    ellipse(sede.x, sede.y, 12, 12);
}

// --- La estanteria con el trofeo ---

void dibujarEstanteria() {
    noStroke();
    fill(COLOR_SOMBRA);
    rect(180, 142, 300, 14);

    stroke(COLOR_CONTORNO);
    strokeWeight(GROSOR_ESCENA);
    // Cara de arriba: se ve porque la escena esta mirada desde arriba.
    fill(COLOR_MADERA_CLARA);
    quad(199, 96, 475, 96, 468, 110, 174, 110);
    fill(COLOR_MADERA_OSCURA);
    quad(468, 110, 475, 96, 475, 126, 468, 142);
    fill(COLOR_MADERA);
    rect(174, 110, 294, 32);

    dibujarLibros();
    dibujarTrofeo();
}

void dibujarLibros() {
    stroke(COLOR_CONTORNO);
    strokeWeight(GROSOR_ESCENA - 1);
    fill(COLOR_ROJO);
    rect(378, 58, 15, 46);
    fill(COLOR_AZUL);
    rect(393, 64, 17, 40);
    fill(COLOR_VERDE);
    rect(410, 53, 14, 51);
    fill(COLOR_AMARILLO);
    quad(426, 104, 439, 104, 458, 70, 446, 64);
    strokeWeight(1.5);
    line(378, 68, 393, 68);
    line(378, 94, 393, 94);
    line(393, 74, 410, 74);
    line(410, 63, 424, 63);
    line(410, 94, 424, 94);
}

void dibujarTrofeo() {
    stroke(COLOR_CONTORNO);
    strokeWeight(GROSOR_ESCENA);
    fill(COLOR_MADERA_OSCURA);
    rect(224, 82, 52, 20, 3);
    fill(COLOR_DORADO);
    rect(238, 87, 24, 9, 2);

    // Asas: primero un trazo negro grueso y encima uno amarillo mas
    // delgado, asi quedan con contorno como el resto del dibujo.
    noFill();
    strokeWeight(9);
    arc(221, 34, 26, 30, HALF_PI, PI + HALF_PI);
    arc(279, 34, 26, 30, -HALF_PI, HALF_PI);
    stroke(COLOR_AMARILLO);
    strokeWeight(4);
    arc(221, 34, 26, 30, HALF_PI, PI + HALF_PI);
    arc(279, 34, 26, 30, -HALF_PI, HALF_PI);

    stroke(COLOR_CONTORNO);
    strokeWeight(GROSOR_ESCENA);
    fill(COLOR_AMARILLO);
    rect(244, 60, 12, 23);
    ellipse(250, 70, 20, 8);
    beginShape();
    vertex(217, 17);
    vertex(283, 17);
    bezierVertex(283, 46, 270, 62, 250, 63);
    bezierVertex(230, 62, 217, 46, 217, 17);
    endShape(CLOSE);
    ellipse(250, 17, 66, 12);

    noStroke();
    fill(COLOR_DORADO);
    dibujarEstrella(250, 38, 10, 4.5);
}

// --- El post-it de ayuda ---

void dibujarPostit() {
    pushMatrix();
    translate(540, 102);
    rotate(-0.06);
    noStroke();
    fill(COLOR_SOMBRA);
    rect(-35, -35, 80, 80);
    stroke(COLOR_CONTORNO);
    strokeWeight(GROSOR_ESCENA - 1);
    fill(COLOR_POSTIT);
    rect(-40, -40, 80, 80);
    fill(COLOR_ROJO);
    ellipse(0, -31, 12, 12);
    fill(COLOR_TINTA);
    usarLetraEscena(LETRA_MANO, 17);
    textAlign(CENTER, CENTER);
    text("¿Cómo", 0, -6);
    text("jugar?", 0, 16);
    popMatrix();
}

// --- El televisor con el noticiero ---

void dibujarTelevisor() {
    noStroke();
    fill(COLOR_SOMBRA);
    rect(620, 30, 316, 186, 10);

    stroke(COLOR_CONTORNO);
    strokeWeight(GROSOR_ESCENA);
    fill(COLOR_GRIS);
    rect(612, 22, 316, 186, 10);
    noStroke();
    fill(COLOR_VERDE_LIMA);
    ellipse(916, 200, 5, 5);
    dibujarPantallaTV();
}

// La pantalla se anima (insignia "EN VIVO", titulares), asi que se vuelve a
// dibujar completa en cada cuadro encima de la foto de la oficina.
void dibujarPantallaTV() {
    noStroke();
    fill(COLOR_AZUL);
    rect(626, 35, 288, 158, 4);
    dibujarNoticiasTV();
    // Se repasa el borde de la pantalla porque el contenido lo tapa.
    noFill();
    stroke(COLOR_CONTORNO);
    strokeWeight(GROSOR_ESCENA);
    rect(626, 35, 288, 158, 4);
}

// El noticiero muestra el grafo de la ciudad: arriba el nombre y el turno
// con la insignia "EN VIVO", en el medio las zonas y las calles, y abajo la
// franja de ultima hora.
void dibujarNoticiasTV() {
    noStroke();
    fill(COLOR_PANTALLA);
    rect(626, 35, 288, 125, 4, 4, 0, 0);
    fill(COLOR_BLANCO);
    usarLetraEscena(LETRA_NEGRITA, 10);
    textAlign(LEFT, TOP);
    text("CIUDAD NOVA · TURNO " + turnoVisible(), 634, 40);

    // Insignia "EN VIVO": su ancho sale del texto, asi cabe con cualquier fuente.
    usarLetraEscena(LETRA_NEGRITA, 10);
    float anchoInsignia = textWidth("EN VIVO") + 22;
    float xInsignia = 906 - anchoInsignia;
    noStroke();
    fill(COLOR_ROJO);
    rect(xInsignia, 40, anchoInsignia, 17, 3);
    fill(COLOR_BLANCO);
    if ((millis() / 600) % 2 == 0) {
        ellipse(xInsignia + 8, 48.5, 6, 6);
    }
    textAlign(LEFT, CENTER);
    text("EN VIVO", xInsignia + 15, 48);

    dibujarGrafoTV(640, 62, 260, 90);
    dibujarTitularTV();
}

// Solo vertices y aristas: primero todas las calles (una linea por cada
// casilla de la matriz con calle, mirando solo la mitad de arriba para no
// dibujar cada calle dos veces) y encima las zonas. Los barrios del
// candidato van de su color (rojo), la sede con un circulo blanco; los
// demas, en gris.
void dibujarGrafoTV(float x, float y, float ancho, float alto) {
    GrafoCiudad ciudad = partida.getCiudad();
    stroke(COLOR_CALLE_TV);
    strokeWeight(3);
    for (int a = 0; a < ciudad.cantidad(); a++) {
        for (int b = a + 1; b < ciudad.cantidad(); b++) {
            if (ciudad.hayCalle(a, b)) {
                line(x + ciudad.getX(a) * ancho, y + ciudad.getY(a) * alto,
                     x + ciudad.getX(b) * ancho, y + ciudad.getY(b) * alto);
            }
        }
    }
    for (int z = 0; z < ciudad.cantidad(); z++) {
        float zx = x + ciudad.getX(z) * ancho;
        float zy = y + ciudad.getY(z) * alto;
        stroke(COLOR_CONTORNO);
        strokeWeight(1.5);
        fill(partida.esPropio(z) ? COLOR_ROJO : COLOR_GRIS_CLARO);
        ellipse(zx, zy, 17, 17);
        if (z == Partida.ZONA_SEDE) {
            noStroke();
            fill(COLOR_BLANCO);
            ellipse(zx, zy, 7, 7);
        }
    }
}

// Franja de "ultima hora": cada titular aparece letra por letra, como si
// lo estuvieran escribiendo en vivo, y cambia cada DURACION_TITULAR.
void dibujarTitularTV() {
    noStroke();
    fill(COLOR_BLANCO);
    rect(626, 160, 288, 33);
    fill(COLOR_ROJO);
    rect(626, 160, 70, 33);
    fill(COLOR_BLANCO);
    usarLetraEscena(LETRA_NEGRITA, 10);
    textAlign(CENTER, CENTER);
    text("ÚLTIMA", 661, 170);
    text("HORA", 661, 183);

    int indice = (millis() / DURACION_TITULAR) % TITULARES_TV.length;
    String titular = TITULARES_TV[indice];
    int letras = min(titular.length(), (millis() % DURACION_TITULAR) / 40);
    fill(COLOR_TEXTO);
    ajustarLetraEscena(LETRA_NEGRITA, titular, 204, 13);
    textAlign(LEFT, CENTER);
    text(titular.substring(0, letras), 703, 176);
}

// --- El calendario (muestra el turno actual, no es interactivo) ---

void dibujarCalendario() {
    stroke(COLOR_CONTORNO);
    strokeWeight(2);
    line(960, 64, 989, 46);
    line(1018, 64, 989, 46);
    fill(COLOR_GRIS_OSCURO);
    ellipse(989, 46, 7, 7);

    noStroke();
    fill(COLOR_SOMBRA);
    rect(952, 66, 82, 98, 4);
    stroke(COLOR_CONTORNO);
    strokeWeight(GROSOR_ESCENA);
    fill(COLOR_BLANCO);
    rect(948, 62, 82, 98, 4);
    fill(COLOR_ROJO);
    rect(948, 62, 82, 24, 4, 4, 0, 0);

    noStroke();
    fill(COLOR_TEXTO_CLARO);
    usarLetraEscena(LETRA_NEGRITA, 13);
    textAlign(CENTER, CENTER);
    text("TURNO", 989, 73);
    fill(COLOR_TEXTO);
    usarLetraEscena(LETRA_TITULO, 46);
    text(turnoVisible(), 989, 116);
    fill(COLOR_TEXTO_SUAVE);
    usarLetraEscena(LETRA_TEXTO, 12);
    text("de " + Partida.TURNOS_TOTALES, 989, 146);
}

// Cuando la partida termina el turno queda en 11; en pantalla nunca se
// muestra un turno mayor que el ultimo.
int turnoVisible() {
    return min(partida.getTurno(), Partida.TURNOS_TOTALES);
}

// --- La puerta (salir del juego) ---

float[] esquinasMarcoPuerta() {
    float xLejos = 1085;
    float xCerca = 1180;
    return new float[] {
        xLejos, yEnPerspectiva(xLejos, xCerca, 30),
        xCerca, 30,
        xCerca, pisoDerecho(xCerca),
        xLejos, pisoDerecho(xLejos)
    };
}

// La hoja de la puerta. Al salir del juego se "abre": su borde cercano se
// corre hacia las bisagras y deja ver el hueco oscuro de atras.
float[] esquinasHojaPuerta() {
    float xLejos = 1092;
    float xCerca = lerp(1172, 1100, aperturaPuerta());
    return new float[] {
        xLejos, yEnPerspectiva(xLejos, 1172, 40),
        xCerca, yEnPerspectiva(xCerca, 1172, 40),
        xCerca, pisoDerecho(xCerca),
        xLejos, pisoDerecho(xLejos)
    };
}

float aperturaPuerta() {
    if (!saliendo) {
        return 0;
    }
    return constrain((millis() - momentoSalida) / (DURACION_SALIDA * 0.45), 0, 1);
}

void dibujarPuerta() {
    stroke(COLOR_CONTORNO);
    strokeWeight(GROSOR_ESCENA);
    float[] marco = esquinasMarcoPuerta();
    fill(COLOR_MADERA_OSCURA);
    quad(marco[0], marco[1], marco[2], marco[3], marco[4], marco[5], marco[6], marco[7]);
    fill(COLOR_NEGRO);
    cuadroRelativo(marco, 0.08, 0.03, 0.92, 1);

    float[] hoja = esquinasHojaPuerta();
    fill(COLOR_MADERA);
    quad(hoja[0], hoja[1], hoja[2], hoja[3], hoja[4], hoja[5], hoja[6], hoja[7]);
    fill(COLOR_MADERA_CLARA);
    strokeWeight(2);
    cuadroRelativo(hoja, 0.2, 0.08, 0.8, 0.42);
    cuadroRelativo(hoja, 0.2, 0.52, 0.8, 0.92);

    PVector manija = puntoEnCuadro(hoja, 0.86, 0.5);
    strokeWeight(2);
    fill(COLOR_AMARILLO);
    ellipse(manija.x, manija.y, 9, 13);
}

// --- El escritorio ---

void dibujarEscritorio() {
    noStroke();
    fill(COLOR_PISO_SOMBRA);
    quad(200, 540, 950, 540, 1080, 725, 70, 725);

    stroke(COLOR_CONTORNO);
    strokeWeight(GROSOR_ESCENA);
    dibujarPatas();
    dibujarCajones();
    fill(COLOR_MADERA);
    rect(100, 455, 945, 67);
    fill(COLOR_MADERA_CLARA);
    quad(206.5, 330, 946, 330, 1045, 455, 100, 455);
}

void dibujarPatas() {
    stroke(COLOR_CONTORNO);
    strokeWeight(GROSOR_ESCENA);
    fill(COLOR_MADERA);
    quad(100, 522, 160, 522, 155, 712, 106, 712);
    quad(985, 522, 1045, 522, 1039, 712, 990, 712);
    // El lado de cada pata que mira hacia el centro queda en sombra.
    noStroke();
    fill(COLOR_MADERA_OSCURA);
    quad(146, 524, 158.5, 524, 153.8, 710, 143, 710);
    quad(986.5, 524, 999, 524, 1002, 710, 991.5, 710);
}

void dibujarCajones() {
    stroke(COLOR_CONTORNO);
    strokeWeight(GROSOR_ESCENA);
    fill(COLOR_MADERA);
    rect(172, 522, 256, 72, 0, 0, 6, 6);
    rect(428, 522, 550, 62, 0, 0, 6, 6);
    fill(COLOR_MADERA_OSCURA);
    ellipse(300, 557, 14, 14);
    ellipse(703, 552, 14, 14);
}

// --- El celular (publicar en Civitas, ver Celular.pde) ---

void dibujarCelular() {
    pushMatrix();
    translate(318, 394);
    rotate(0.3);
    noStroke();
    fill(COLOR_SOMBRA);
    rect(-16, -30, 40, 68, 8);
    stroke(COLOR_CONTORNO);
    strokeWeight(GROSOR_ESCENA);
    fill(COLOR_GRIS_OSCURO);
    rect(-20, -34, 40, 68, 8);

    noStroke();
    fill(COLOR_AZUL_GRIS);
    rect(-15, -27, 30, 52, 3);
    fill(COLOR_AZUL);
    rect(-15, -27, 30, 9, 3, 3, 0, 0);
    fill(COLOR_BLANCO);
    rect(-12, -14, 24, 10, 2);
    rect(-12, -1, 24, 10, 2);
    rect(-12, 12, 17, 9, 2);
    fill(COLOR_AZUL_GRIS);
    ellipse(-8, -9, 5, 5);
    ellipse(-8, 4, 5, 5);
    fill(COLOR_NEGRO);
    ellipse(0, -30.5, 4, 4);
    popMatrix();
}

// --- El cuaderno (abre el arbol de habilidades) ---

void dibujarCuaderno() {
    noStroke();
    fill(COLOR_SOMBRA);
    quad(492, 348, 704, 348, 724, 446, 474, 446);

    stroke(COLOR_CONTORNO);
    strokeWeight(GROSOR_ESCENA);
    fill(COLOR_GRIS);
    quad(484, 342, 696, 342, 716, 440, 464, 440);

    fill(COLOR_BLANCO);
    beginShape();
    vertex(590, 350);
    bezierVertex(565, 339, 525, 337, 492, 346);
    vertex(474, 430);
    bezierVertex(510, 423, 560, 425, 590, 434);
    endShape(CLOSE);
    beginShape();
    vertex(590, 350);
    bezierVertex(615, 339, 655, 337, 688, 346);
    vertex(706, 430);
    bezierVertex(670, 423, 620, 425, 590, 434);
    endShape(CLOSE);

    dibujarRenglonesCuaderno();
    dibujarArbolitoCuaderno();

    // Cinta roja de marcapaginas
    stroke(COLOR_CONTORNO);
    strokeWeight(2);
    fill(COLOR_ROJO);
    beginShape();
    vertex(586, 433);
    vertex(595, 433);
    vertex(596, 458);
    vertex(591, 452);
    vertex(585, 458);
    endShape(CLOSE);
}

// La pagina izquierda tiene "texto" (rayitas grises).
void dibujarRenglonesCuaderno() {
    stroke(COLOR_GRIS_CLARO);
    strokeWeight(2.5);
    for (int i = 0; i < 6; i++) {
        float y = 358 + i * 12;
        float xInicio = lerp(492, 474, (y - 346) / 84.0) + 12;
        float xFin = 578 - (i % 3) * 14;
        line(xInicio, y, xFin, y);
    }
}

// La pagina derecha tiene un arbolito dibujado con los colores de las
// ramas: es una pista de lo que hay adentro del cuaderno.
void dibujarArbolitoCuaderno() {
    stroke(COLOR_GRIS);
    strokeWeight(1.5);
    line(640, 362, 614, 386);
    line(640, 362, 640, 386);
    line(640, 362, 666, 386);
    line(614, 386, 606, 410);
    line(614, 386, 622, 410);
    line(640, 386, 640, 410);
    line(666, 386, 666, 410);

    stroke(COLOR_CONTORNO);
    strokeWeight(1.2);
    fill(COLOR_RAIZ);
    rect(631, 356, 18, 10, 2);
    fill(COLORES_RAMA[0]);
    rect(605, 381, 18, 10, 2);
    fill(COLORES_RAMA[1]);
    rect(631, 381, 18, 10, 2);
    fill(COLORES_RAMA[2]);
    rect(657, 381, 18, 10, 2);
    fill(COLOR_BLOQUEADA);
    rect(600, 405, 12, 8, 2);
    rect(616, 405, 12, 8, 2);
    rect(634, 405, 12, 8, 2);
    rect(660, 405, 12, 8, 2);
}

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

// --- El telefono rojo (la llamada de cada turno, ver Llamada.pde) ---

// Cuando suena, todo el telefono tiembla (gira y se corre un poquito sobre
// su base) y el auricular salta sobre la horquilla. Durante la llamada el
// auricular no esta: lo dibuja al frente dibujarEscenaLlamada().
void dibujarTelefono() {
    noStroke();
    fill(COLOR_SOMBRA);
    ellipse(868, 414, 176, 20);
    float[] vibracion = vibracionTelefono();
    pushMatrix();
    translate(862 + vibracion[0], 404);
    rotate(vibracion[1]);
    translate(-862, -404);
    stroke(COLOR_CONTORNO);
    strokeWeight(GROSOR_ESCENA);
    dibujarCuerpoTelefono();
    dibujarDiscoTelefono(862, 372);
    dibujarHorquillas();
    if (auricularEnSuBase()) {
        dibujarCableTelefono(vibracion[2]);
        pushMatrix();
        translate(0, -vibracion[2]);
        dibujarAuricular(GROSOR_ESCENA);
        popMatrix();
    }
    popMatrix();
}

// Los dos soportes donde descansa el auricular. Solo se ven cuando esta
// levantado (el auricular los tapa).
void dibujarHorquillas() {
    stroke(COLOR_CONTORNO);
    strokeWeight(2.5);
    fill(COLOR_ROJO_OSCURO);
    rect(818, 322, 16, 14, 4, 4, 0, 0);
    rect(890, 322, 16, 14, 4, 4, 0, 0);
}

void dibujarCuerpoTelefono() {
    fill(COLOR_ROJO);
    beginShape();
    vertex(800, 404);
    vertex(924, 404);
    vertex(912, 348);
    bezierVertex(908, 336, 900, 332, 890, 332);
    vertex(834, 332);
    bezierVertex(824, 332, 816, 336, 812, 348);
    endShape(CLOSE);
    fill(COLOR_ROJO_OSCURO);
    rect(792, 400, 140, 14, 4);
}

// Disco de marcar: un anillo con diez agujeros alrededor del centro.
void dibujarDiscoTelefono(float cx, float cy) {
    fill(COLOR_GRIS_CLARO);
    ellipse(cx, cy, 62, 44);
    fill(COLOR_BLANCO);
    strokeWeight(1.5);
    for (int i = 0; i < 10; i++) {
        float angulo = radians(-60 + i * 29);
        ellipse(cx + cos(angulo) * 22, cy + sin(angulo) * 15, 8, 6);
    }
    strokeWeight(2);
    fill(COLOR_ROJO);
    ellipse(cx, cy, 20, 14);
    fill(COLOR_BLANCO);
    ellipse(cx, cy, 9, 6);
}

// El cable en espiral: pequenos aros a lo largo de una curva de Bezier.
// "salto" sube la punta que va al auricular cuando este salta al sonar.
void dibujarCableTelefono(float salto) {
    noFill();
    stroke(COLOR_CONTORNO);
    strokeWeight(1.8);
    for (int i = 0; i <= 14; i++) {
        float t = i / 14.0;
        float x = bezierPoint(934, 964, 962, 926, t);
        float y = bezierPoint(328 - salto, 342, 396, 404, t);
        ellipse(x, y, 10, 7);
    }
}

// "grosor" es el del contorno: cuando el auricular se dibuja agrandado al
// frente, se le pasa uno mas delgado para que el scale() no lo engorde.
void dibujarAuricular(float grosor) {
    stroke(COLOR_CONTORNO);
    strokeWeight(grosor);
    fill(COLOR_ROJO);
    beginShape();
    vertex(792, 336);
    bezierVertex(786, 320, 790, 306, 806, 302);
    vertex(918, 302);
    bezierVertex(934, 306, 938, 320, 932, 336);
    bezierVertex(924, 345, 906, 345, 900, 335);
    vertex(896, 322);
    vertex(828, 322);
    vertex(824, 335);
    bezierVertex(818, 345, 800, 345, 792, 336);
    endShape(CLOSE);
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
    usarLetra(LETRA_NEGRITA, tx(16, 12));
    float pad = max(10, 18 * escala);
    float ancho = min(textWidth(texto) + pad * 2, width * 0.92);
    float alto = tx(16, 12) * 2.1;
    float x = width / 2 - ancho / 2;
    float y = height - alto - max(10, 20 * escala);
    noStroke();
    fill(COLOR_VELO, opacidad);
    rect(x, y, ancho, alto, alto / 2);
    fill(COLOR_TEXTO_CREMA, opacidad);
    ajustarLetra(LETRA_NEGRITA, texto, ancho - pad * 2, tx(16, 12));
    textAlign(CENTER, CENTER);
    text(texto, width / 2, y + alto / 2 - 1);
}

// Portada: el titulo del juego sobre la oficina oscurecida. Al primer clic
// (o con Esc) se desvanece y la oficina queda lista para usarse.
void dibujarPortada() {
    float visible = 1;
    if (!mostrarPortada) {
        visible = 1 - (millis() - momentoFinPortada) / (float) DURACION_FUNDIDO;
    }
    if (visible <= 0) {
        return;
    }
    float opacidad = 255 * visible;
    noStroke();
    fill(COLOR_VELO_PORTADA, opacidad);
    rect(0, 0, width, height);

    float cx = width / 2;
    float yTitulo = height * 0.36;
    float altoCinta = dibujarCintaTitulo(cx, yTitulo, opacidad);
    dibujarCintaSubtitulo(cx, yTitulo + altoCinta * 0.72, opacidad);

    fill(COLOR_TEXTO_CREMA, opacidad);
    usarLetra(LETRA_TEXTO, tx(19, 14));
    textAlign(CENTER, TOP);
    float yLema = yTitulo + altoCinta * 1.45;
    String lema = "Compite por la alcaldía publicando en Civitas. La información verificada " +
        "te da influencia; las mentiras dan un empujón rápido, pero cuestan credibilidad.";
    dibujarParrafo(lema, cx, yLema, min(width * 0.62, 820 * escala));

    float parpadeo = 0.55 + 0.45 * sin(millis() * 0.005);
    fill(COLOR_PISO, opacidad * parpadeo);
    usarLetra(LETRA_NEGRITA, tx(22, 16));
    textAlign(CENTER, CENTER);
    text("Haz clic para empezar", cx, height * 0.8);

    fill(COLOR_GRIS_CLARO, opacidad);
    usarLetra(LETRA_TEXTO, tx(13, 11));
    text("Estructura de Datos II  ·  Rediseño en desarrollo", cx, height - tx(26, 18));
}

// Cinta roja de campana con el titulo. Sus extremos tienen un corte en V.
// Devuelve su alto para ubicar lo que va debajo.
float dibujarCintaTitulo(float cx, float cy, float opacidad) {
    String titulo = "ALCALDE DIGITAL";
    float tamano = tx(80, 44);
    usarLetra(LETRA_TITULO, tamano);
    float alto = tamano * 1.4;
    float ancho = textWidth(titulo) + alto * 1.2;
    float x = cx - ancho / 2;
    float y = cy - alto / 2;
    float corte = alto * 0.32;
    float d = desplazamientoSombra() * 1.5;

    noStroke();
    fill(COLOR_NEGRO, opacidad * 0.45);
    formaCinta(x + d, y + d, ancho, alto, corte);
    stroke(COLOR_CONTORNO, opacidad);
    strokeWeight(grosorContorno * 1.6);
    fill(COLOR_ROJO, opacidad);
    formaCinta(x, y, ancho, alto, corte);

    textAlign(CENTER, CENTER);
    textoConContorno(titulo, cx, cy - tamano * 0.06, max(2, 3 * escala), COLOR_BLANCO, COLOR_ROJO_OSCURO, opacidad);
    return alto;
}

void dibujarCintaSubtitulo(float cx, float y, float opacidad) {
    String subtitulo = "CIUDAD NOVA";
    float tamano = tx(24, 16);
    usarLetra(LETRA_NEGRITA, tamano);
    float alto = tamano * 1.8;
    float ancho = textWidth(subtitulo) + alto * 2.2;
    stroke(COLOR_CONTORNO, opacidad);
    strokeWeight(grosorContorno * 1.3);
    fill(COLOR_AZUL, opacidad);
    formaCinta(cx - ancho / 2, y, ancho, alto, alto * 0.3);
    fill(COLOR_BLANCO, opacidad);
    textAlign(CENTER, CENTER);
    text(subtitulo, cx, y + alto / 2 - tamano * 0.08);
}

void formaCinta(float x, float y, float ancho, float alto, float corte) {
    beginShape();
    vertex(x - corte, y);
    vertex(x + ancho + corte, y);
    vertex(x + ancho, y + alto / 2);
    vertex(x + ancho + corte, y + alto);
    vertex(x - corte, y + alto);
    vertex(x, y + alto / 2);
    endShape(CLOSE);
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

// --- La barra superior ---

// Franja de madera oscura: su fondo va en la foto; encima, en cada cuadro,
// los botones a los extremos y en el medio la informacion de la partida:
// candidato, turno y puntos de influencia.
void dibujarFondoBarra() {
    noStroke();
    fill(COLOR_SOMBRA);
    rect(0, altoBarra, width, max(3, 6 * escala));
    fill(COLOR_MADERA_OSCURA);
    rect(0, 0, width, altoBarra);
    stroke(COLOR_CONTORNO);
    strokeWeight(grosorContorno);
    line(0, altoBarra, width, altoBarra);
}

void dibujarContenidoBarra() {
    botonVolverMenu.dibujar();
    if (!partidaTerminada()) {
        if (partida.getTurno() >= Partida.TURNOS_TOTALES) {
            botonPasarTurno.texto = "Terminar campaña";
        } else {
            botonPasarTurno.texto = "Pasar turno";
        }
        botonPasarTurno.dibujar();
    }

    float inicio = botonVolverMenu.x + botonVolverMenu.ancho;
    float fin = botonPasarTurno.x;
    float anchoZona = (fin - inicio) / 3;
    float yCentro = altoBarra / 2;
    dibujarInfoCandidato(inicio, anchoZona, yCentro);
    dibujarInfoTurno(inicio + anchoZona, anchoZona, yCentro);
    dibujarInfoPuntos(inicio + anchoZona * 2, anchoZona, yCentro);
}

void dibujarInfoCandidato(float x, float ancho, float yCentro) {
    float r = altoBarra * 0.2;
    String nombre = partida.getNombreCandidato();
    ajustarLetra(LETRA_NEGRITA, nombre, ancho * 0.9 - r * 2.6, tx(18, 13));
    float anchoTotal = r * 2.6 + textWidth(nombre);
    float xInicio = x + ancho / 2 - anchoTotal / 2;
    dibujarPersona(xInicio + r, yCentro, r, COLOR_TEXTO_CREMA);
    fill(COLOR_TEXTO_CREMA);
    textAlign(LEFT, CENTER);
    text(nombre, xInicio + r * 2.6, yCentro - 1);
}

// Turno actual y una fila de puntos, uno por turno, llenos hasta el actual.
void dibujarInfoTurno(float x, float ancho, float yCentro) {
    String texto = "Turno " + turnoVisible() + " de " + Partida.TURNOS_TOTALES;
    ajustarLetra(LETRA_NEGRITA, texto, ancho * 0.9, tx(18, 13));
    float anchoTexto = textWidth(texto);
    float r = altoBarra * 0.07;
    float anchoPuntos = Partida.TURNOS_TOTALES * r * 2.8;
    boolean cabenPuntos = anchoTexto + anchoPuntos + r * 3 < ancho * 0.95;
    float anchoTotal = cabenPuntos ? anchoTexto + r * 3 + anchoPuntos : anchoTexto;
    float xInicio = x + ancho / 2 - anchoTotal / 2;

    fill(COLOR_TEXTO_CREMA);
    textAlign(LEFT, CENTER);
    text(texto, xInicio, yCentro - 1);
    if (!cabenPuntos) {
        return;
    }
    float xPunto = xInicio + anchoTexto + r * 3 + r;
    for (int i = 1; i <= Partida.TURNOS_TOTALES; i++) {
        stroke(COLOR_TEXTO_CREMA);
        strokeWeight(max(1, r * 0.35));
        if (i <= turnoVisible()) {
            fill(COLOR_PISO);
        } else {
            noFill();
        }
        ellipse(xPunto, yCentro, r * 2, r * 2);
        xPunto += r * 2.8;
    }
}

void dibujarInfoPuntos(float x, float ancho, float yCentro) {
    float r = altoBarra * 0.19;
    String texto = partida.getPuntos() == 1 ? "1 punto de influencia" : partida.getPuntos() + " puntos de influencia";
    ajustarLetra(LETRA_NEGRITA, texto, ancho * 0.9 - r * 2.6, tx(18, 13));
    float anchoTotal = r * 2.6 + textWidth(texto);
    float xInicio = x + ancho / 2 - anchoTotal / 2;
    dibujarMoneda(xInicio + r, yCentro, r);
    fill(COLOR_TEXTO_CREMA);
    textAlign(LEFT, CENTER);
    text(texto, xInicio + r * 2.6, yCentro - 1);
    // El texto flotante (+3 / -2) sale justo encima de la moneda.
    xFlotante = xInicio + r;
    yFlotante = yCentro + altoBarra * 0.55;
}

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
