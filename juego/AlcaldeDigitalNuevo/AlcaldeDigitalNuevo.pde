// Alcalde Digital — sketch principal (rediseño)
// Aqui vive la maquina de estados de la aplicacion (que pantalla se ve y que
// pasa con los clics y el teclado), la paleta de colores, las fuentes y las
// medidas de todo el layout. La logica del juego (el arbol, la partida, las
// noticias) esta en los .java; este archivo solo coordina cuando se llama a
// cada cosa, Interfaz.pde se encarga de dibujarla, Llamada.pde maneja el
// telefono que suena al empezar cada turno y Celular.pde la publicacion en
// Civitas (el chat con el influencer y el mapa).
//
// Para probar en una ventana en vez de pantalla completa, cambiar la linea
// fullScreen(P2D) de setup() por size(1280, 720, P2D): todo el layout se
// calcula a partir de width y height, asi que se adapta solo.

// ===========================================================================
// ESTADOS
// ===========================================================================

// Los estados posibles de la aplicacion. Se usan int en vez de un enum
// para mantener el estilo simple que pide el curso (nada de tipos nuevos).
final int MENU = 0;   // la oficina del candidato: es el menu principal
final int ARBOL = 1;  // el cuaderno abierto con el arbol de habilidades
final int AYUDA = 2;  // el manual "Como jugar"
final int MAPA = 3;   // el televisor en grande: el grafo de la ciudad
final int CELULAR = 4; // el celular: el chat con el influencer y el mapa para publicar
int estado;

// ===========================================================================
// COLORES
// ===========================================================================
// Bloque unico de colores: ningun color suelto aparece en el resto del
// codigo. La paleta sale del dibujo original de la oficina (los colores de
// Paint): pared crema, piso amarillo, madera cafe, telefono rojo, pantalla
// azul y contornos negros gruesos.

color COLOR_CONTORNO = #1A1A1A;
color COLOR_PARED = #EFE4B0;
color COLOR_PARED_LATERAL = #E4D69E;
color COLOR_PISO = #FFC90E;
color COLOR_PISO_SOMBRA = #EDB300;
color COLOR_MADERA = #B97A57;
color COLOR_MADERA_CLARA = #C98D69;
color COLOR_MADERA_OSCURA = #8E5A3C;
color COLOR_MADERA_VETA = #A76C4B;
color COLOR_ROJO = #ED1C24;
color COLOR_ROJO_OSCURO = #B0141A;
color COLOR_AZUL = #00A2E8;
color COLOR_AZUL_CLARO = #99D9EA;
color COLOR_AZUL_OSCURO = #005E8C;
color COLOR_AZUL_GRIS = #7092BE;
color COLOR_PANTALLA = #0E2436;   // fondo oscuro del televisor
color COLOR_CALLE_TV = #3E6A8F;   // calles del grafo en el televisor
color COLOR_VERDE = #22B14C;
color COLOR_VERDE_LIMA = #B5E61D;
color COLOR_ROSADO = #FFAEC9;
color COLOR_NARANJA = #FF7F27;
color COLOR_AMARILLO = #FFF200;
color COLOR_DORADO = #E0A800;
color COLOR_GRIS = #7F7F7F;
color COLOR_GRIS_CLARO = #C3C3C3;
color COLOR_GRIS_OSCURO = #464646;
color COLOR_BLANCO = #FFFFFF;
color COLOR_NEGRO = #000000;

color COLOR_PAPEL = #FFFDF4;
color COLOR_POSTIT = #FFF38A;
color COLOR_RENGLON = #C5E8F3;
color COLOR_MARGEN = #F28B8B;
color COLOR_TINTA = #2F3BB5;  // tinta azul de esfero, para lo "escrito a mano"

color COLOR_TEXTO = #1A1A1A;
color COLOR_TEXTO_SUAVE = #5C5C5C;
color COLOR_TEXTO_CLARO = #FFFFFF;
color COLOR_TEXTO_CREMA = #FFF3D6;
color COLOR_EXITO = #178A38;
color COLOR_ERROR = #D7141A;
color COLOR_AVISO = #C25A00;

color COLOR_BOTON = #FFF6D8;
color COLOR_BOTON_HOVER = #FFC90E;
color COLOR_BOTON_TEXTO = #1A1A1A;

color COLOR_TARJETA = #CDEFF8;  // tarjetas del celular, sobre la pantalla azul

color COLOR_RAIZ = #FFC90E;
color COLOR_MONEDA = #FFC90E;
color COLOR_BLOQUEADA = #E8E8E8;
color COLOR_BRILLO = #FFF200;

// El arbol dibujado del cuaderno (Cuaderno.pde).
color COLOR_TRONCO = #B97A57;
color COLOR_TRONCO_OSCURO = #8E5A3C;
color COLOR_FOLLAJE = #1E6B30;
color COLOR_FOLLAJE_CLARO = #2E8B41;
color COLOR_PASTO = #22B14C;
color COLOR_DORADO_CLARO = #E9D98B;  // habilidad desbloqueada
color COLOR_DORADO_OSCURO = #7A6A1E; // su candado abierto

// Colores con transparencia: el cuarto numero es la opacidad (0 a 255).
color COLOR_SOMBRA = color(0, 0, 0, 55);
color COLOR_VELO = color(12, 16, 30, 175);
color COLOR_VELO_PORTADA = color(12, 16, 30, 205);
color COLOR_CINTA = color(255, 255, 255, 150);

// Las tres ramas del arbol, en el mismo orden en que ArbolHabilidades las
// cuelga de la raiz (Alcance, Credibilidad, IA). El color fuerte es el del
// anillo de cada habilidad y el de las barras y etiquetas; el claro, el del
// arbolito dibujado en la tapa del cuaderno de la oficina.
String[] NOMBRES_RAMA = {"Alcance", "Credibilidad", "IA"};
color[] COLORES_RAMA = {COLOR_AZUL_CLARO, COLOR_VERDE_LIMA, COLOR_ROSADO};
color[] COLORES_RAMA_FUERTE = {COLOR_AZUL, COLOR_VERDE, COLOR_ROJO};

// ===========================================================================
// FUENTES
// ===========================================================================

// Cuatro tipos de letra. Cada uno tiene una lista de fuentes en orden de
// preferencia: la primera es la que se uso al disenar en Windows; las demas
// son parecidas por si alguien del equipo abre el juego en Mac o Linux.
final int LETRA_TITULO = 0;   // letra de afiche: titulos grandes y el noticiero
final int LETRA_NEGRITA = 1;  // botones, etiquetas y nombres de habilidades
final int LETRA_TEXTO = 2;    // parrafos
final int LETRA_MANO = 3;     // lo "escrito a mano" en el cuaderno y los post-it
String[][] FUENTES_CANDIDATAS = {
    {"Impact", "Arial Black", "Segoe UI Black", "DejaVu Sans Bold"},
    {"Segoe UI Bold", "Arial Bold", "Helvetica Bold", "DejaVu Sans Bold"},
    {"Segoe UI", "Arial", "Helvetica", "DejaVu Sans"},
    {"Segoe Print Bold", "Segoe Print", "Ink Free", "Comic Sans MS Bold", "Chalkboard SE Bold", "DejaVu Sans Bold"}
};
final int TAMANO_MAXIMO_LETRA = 400;
String[] nombresFuente = new String[4];                    // la fuente elegida de cada tipo
PFont[][] fuentes = new PFont[4][TAMANO_MAXIMO_LETRA + 1];  // [tipo][tamano]: se llenan al pedirlas
// Mayor que 1 solo mientras se redibuja agrandado el objeto de la oficina
// que esta bajo el mouse (ver usarLetraEscena() en Interfaz.pde).
float aumentoTexto = 1;

// ===========================================================================
// LAYOUT
// ===========================================================================
// El juego corre en pantalla completa, y la pantalla completa no siempre
// mide lo mismo (varia con el monitor). Por eso las medidas de abajo se
// calculan una sola vez en setup(), a partir del width y height reales, y
// se reusan en todas las pantallas. No hace falta recalcularlas cuadro a
// cuadro porque el tamano de la ventana ya no cambia durante la partida.

float escala;          // tamano de la interfaz comparado con el diseno de 1200x700
float grosorContorno;  // grosor del contorno negro de botones, nodos y papeles

// Oficina: se dibuja en un lienzo fijo y se escala entero (ver Interfaz.pde)
float escalaEscena;
float origenEscenaX, origenEscenaY;

// Barra de arriba y margen de las hojas de papel (el cuaderno calcula lo
// suyo en Cuaderno.pde)
float altoBarra;
float margenHoja;

// Tarjeta de fin de partida
float tarjetaX, tarjetaY, tarjetaAncho, tarjetaAlto;

// Manual de ayuda
float ayudaX, ayudaY, ayudaAncho, ayudaAlto;

// ===========================================================================
// MODELO Y ELEMENTOS DE LA INTERFAZ
// ===========================================================================

// Un solo arbol y una sola partida para toda la aplicacion: por ahora el
// juego es de un jugador.
ArbolHabilidades arbol;
Partida partida;
Sonidos sonidos;

Boton botonVolverMenu;
Boton botonPasarTurno;
Boton botonVolverAyuda;
Boton botonVolverMapa;
Boton botonVolverCelular;
Boton botonCuadernoCelular;
Boton botonNuevaPartida;
Boton botonFinOficina;

// Los objetos de la oficina con los que se puede interactuar. Se guardan por
// separado (para saber que hacer con cada clic) y tambien en una lista (para
// recorrerlos todos al buscar cual esta bajo el mouse).
ObjetoOficina objetoCuaderno;
ObjetoOficina objetoPostit;
ObjetoOficina objetoPuerta;
ObjetoOficina objetoTelevisor;
ObjetoOficina objetoTelefono;
ObjetoOficina objetoCelular;
ObjetoOficina objetoEstanteria;
ObjetoOficina objetoCajon;
ArrayList<ObjetoOficina> objetosOficina;

// ===========================================================================
// ESTADO DE LA INTERFAZ Y ANIMACIONES
// ===========================================================================
// Las animaciones no usan hilos ni nada especial: se guarda el momento
// (millis) en que empezaron y cada cuadro se calcula que tan avanzadas van.

final int DURACION_ONDA = 600;       // onda que sale de un nodo recien desbloqueado
final int DURACION_SACUDIDA = 420;   // un nodo que no se puede comprar se sacude
final int DURACION_CANDADO = 1100;   // candado sobre un objeto de la oficina que no funciona aun
final int DURACION_FLOTANTE = 1100;  // el "+3" / "-2" que sube junto a los puntos
final int DURACION_AVISO = 2800;     // mensajes cortos en la parte de abajo
final int DURACION_FUNDIDO = 450;    // la portada se desvanece
final int DURACION_SALIDA = 1000;    // la puerta se abre y todo se oscurece
final int DURACION_TITULAR = 5200;   // cada titular del noticiero de la TV

// Nodo que muestra el panel lateral: el ultimo sobre el que paso o hizo
// clic el mouse (null hasta el primer hover, para mostrar una bienvenida).
Nodo nodoSeleccionado;
Nodo nodoBajoMouse;
Nodo nodoAnimado;
Boton botonDesbloquear;  // se crea cuando la habilidad elegida se puede comprar
int momentoAnimacion;
boolean animacionExitosa;

ObjetoOficina objetoResaltado;
ObjetoOficina objetoConCandado;
int momentoCandado;

// "Fotos" de las partes que no se mueven de cada pantalla (ver
// pantallaMenu() en Interfaz.pde). null significa que hay que volver a
// dibujarla y tomarla de nuevo.
PImage fotoOficina;
PImage fotoCuaderno;
PImage fotoAyuda;

boolean mostrarPortada = true;
int momentoFinPortada = -100000;
boolean cuadernoYaAbierto = false;
boolean saliendo = false;
int momentoSalida;

String textoAviso = null;
int momentoAviso;

String textoFlotante = null;
color colorFlotante;
float xFlotante, yFlotante;
int momentoFlotante;

// Cursor: cada cuadro, lo que esta bajo el mouse "pide" la mano si se puede
// hacer clic ahi; al final del cuadro se aplica (ver actualizarCursor()).
boolean quiereMano = false;
int cursorActual = -1;

// ===========================================================================
// PREPARACION
// ===========================================================================

void setup() {
    fullScreen(P2D);
    smooth(8);
    // Los dibujos del equipo son pixel art: se agrandan sin suavizar.
    if (g instanceof PGraphicsOpenGL) {
        ((PGraphicsOpenGL) g).textureSampling(2);
    }

    // Menos segmentos por curva (el valor por defecto es 20): las esquinas
    // redondeadas se siguen viendo suaves y cada figura cuesta menos dibujarla.
    bezierDetail(8);

    arbol = new ArbolHabilidades();
    partida = new Partida();
    partida.iniciar("Jugador 1", arbol);
    sonidos = new Sonidos();
    estado = MENU;

    elegirFuentes();
    cargarDiseno();
    prepararInfiltrado();
    prepararMundoAbierto();
    sortearMinijuegos();
    calcularLayout();
    crearBotones();
    crearObjetosOficina();
}

// Calcula, a partir del tamano real de la pantalla, cuanto mide cada zona
// de la interfaz. Todo sale de width, height o de un porcentaje de ellos.
void calcularLayout() {
    // Factor de escala general para tamanos (no posiciones): compara la
    // pantalla real contra un diseno de referencia de 1200x700 y usa el lado
    // mas pequeno, para que nada se salga en monitores muy anchos o muy
    // altos. Nunca baja de 0.65 para que el texto no quede ilegible.
    escala = min(width / 1200.0, height / 700.0);
    escala = max(escala, 0.65);
    grosorContorno = max(1.5, 2.4 * escala);

    calcularLayoutOficina();
    altoBarra = constrain(height * 0.085, 56, 110);
    margenHoja = max(12, 18 * escala);
    calcularLayoutLibro();
    calcularLayoutTarjetas();
}

// La oficina se escala entera con un solo factor (el mas pequeno entre el
// ancho y el alto) y se centra: asi nunca se deforma ni se sale de la
// pantalla. Lo que sobra a los lados o arriba y abajo lo cubre el mismo
// dibujo, que es mas grande que el lienzo (ver dibujarHabitacion()).
void calcularLayoutOficina() {
    calcularCamara();
    escalaEscena = camAncho / ANCHO_ESCENA;
    origenEscenaX = camX;
    origenEscenaY = camY;
}

// La tarjeta de fin de partida y el manual de ayuda son hojas de papel
// centradas sobre el escritorio.
void calcularLayoutTarjetas() {
    // La tarjeta final mide lo que ocupa su contenido (titulo, resumen,
    // estilo de campana, barras de progreso, mensaje y botones), para que
    // no quede un hueco vacio entre el texto y los botones.
    float altoContenido = tx(52, 32) * 1.25
        + tx(17, 13) * 2.1 + tx(14, 10)
        + tx(14, 11) * 1.5 + tx(30, 20) * 1.5 + tx(15, 12) * 2.1 + tx(14, 10)
        + altoProgreso() + tx(8, 6)
        + tx(15, 12) * 1.5;
    tarjetaAncho = min(width * 0.56, 780 * escala);
    tarjetaAlto = min(height * 0.92, margenTarjeta() * 2 + altoContenido + altoBotonTarjeta() * 1.5);
    tarjetaX = (width - tarjetaAncho) / 2;
    tarjetaY = (height - tarjetaAlto) / 2;

    ayudaAncho = width * 0.9;
    ayudaX = (width - ayudaAncho) / 2;
    ayudaY = altoBarra + margenHoja * 0.6;
    ayudaAlto = height - ayudaY - margenHoja;
}

// Para cada tipo de letra se queda con la primera fuente de su lista que
// este instalada en este computador (o con la sans serif de Java si no
// encuentra ninguna). Las PFont de cada tamano se crean despues, a medida
// que se necesitan (ver usarLetra() en Interfaz.pde).
void elegirFuentes() {
    String[] instaladas = PFont.list();
    for (int tipo = 0; tipo < FUENTES_CANDIDATAS.length; tipo++) {
        nombresFuente[tipo] = primeraInstalada(FUENTES_CANDIDATAS[tipo], instaladas);
    }
}

String primeraInstalada(String[] candidatas, String[] instaladas) {
    for (String nombre : candidatas) {
        for (String instalada : instaladas) {
            if (instalada.equals(nombre)) {
                return nombre;
            }
        }
    }
    return "SansSerif";
}

// Los botones se crean una sola vez aqui (no en cada draw()) porque su
// posicion no cambia durante la partida; solo cambia su color segun el
// mouse, y eso lo resuelve Boton.dibujar().
void crearBotones() {
    float altoBoton = constrain(altoBarra * 0.62, 34, 60);
    float yBoton = (altoBarra - altoBoton) / 2;
    float anchoVolver = constrain(width * 0.11, 130, 210);
    botonVolverMenu = new Boton(width * 0.015, yBoton, anchoVolver, altoBoton, "← Oficina");
    botonVolverAyuda = new Boton(width * 0.015, yBoton, anchoVolver, altoBoton, "← Oficina");
    botonVolverMapa = new Boton(width * 0.015, yBoton, anchoVolver, altoBoton, "← Oficina");
    botonVolverCelular = new Boton(width * 0.015, yBoton, anchoVolver, altoBoton, "← Oficina");

    float anchoPasarTurno = constrain(width * 0.13, 160, 250);
    botonPasarTurno = new Boton(width - anchoPasarTurno - width * 0.015, yBoton,
        anchoPasarTurno, altoBoton, "Pasar turno");
    botonCuadernoCelular = new Boton(width - anchoPasarTurno - width * 0.015, yBoton,
        anchoPasarTurno, altoBoton, "Ir al cuaderno →");

    float anchoTarjetaBoton = tarjetaAncho * 0.36;
    float yTarjetaBoton = tarjetaY + tarjetaAlto - altoBotonTarjeta() - margenTarjeta();
    // al terminar la campaña solo queda volver al menú principal
    botonNuevaPartida = new Boton(tarjetaX + tarjetaAncho * 0.25, yTarjetaBoton,
        tarjetaAncho * 0.5, altoBotonTarjeta(), "Menú principal");
    botonFinOficina = new Boton(tarjetaX + tarjetaAncho * 0.53, yTarjetaBoton,
        anchoTarjetaBoton, altoBotonTarjeta(), "Volver a la oficina");
}

float margenTarjeta() {
    return tx(34, 22);
}

float altoBotonTarjeta() {
    return constrain(height * 0.065, 38, 64);
}

// Cada objeto recibe su caja de clic en coordenadas del lienzo de la
// oficina (1200x675), las mismas con que se dibuja en Interfaz.pde. Por
// ahora funcionan el cuaderno, el post-it, la puerta, el televisor, el
// telefono y el celular; la estanteria se ve y responde al mouse, pero
// avisa que llega despues.
void crearObjetosOficina() {
    // Las cajas salen de las zonas de clic del prototipo (en porcentaje del
    // dibujo) pasadas al lienzo de 1200 x 670.
    objetoCuaderno = new ObjetoOficina("Libro de campaña", "Árbol de habilidades", "Clic para abrirlo", true, exPc(41), eyPc(60.5), exPc(24.5), eyPc(20.5));
    objetoPostit = new ObjetoOficina("Post-it de ayuda", "¿Cómo jugar? Reglas y controles", "Clic para leerlo", true, 290, 166, 84, 68);
    objetoPuerta = new ObjetoOficina("Puerta", "Salir del juego", "Clic para salir", true, 1158, 90, 42, 330);
    objetoTelevisor = new ObjetoOficina("Televisor", "Noticiero de Ciudad Nova", "Clic para verlo en grande", true, exPc(59), eyPc(2.1), exPc(27.6), eyPc(29.4));
    objetoTelefono = new ObjetoOficina("Teléfono", "Noticias de última hora", "Clic para contestar", true, exPc(74.5), eyPc(56), exPc(16), eyPc(22));
    objetoCelular = new ObjetoOficina("Celular", "Publicar en Civitas", "Clic para publicar", true, exPc(13), eyPc(60), exPc(21), eyPc(20));
    objetoEstanteria = new ObjetoOficina("Estantería de trofeos", "Quién va ganando", "Próximamente", false, 80, 8, 300, 132);
    objetoCajon = new ObjetoOficina("Cajón del escritorio", "Volver al periódico del menú", "Clic para abrirlo", true, exPc(31.4), eyPc(90.6), exPc(37.6), eyPc(9.4));

    objetosOficina = new ArrayList<ObjetoOficina>();
    objetosOficina.add(objetoCuaderno);
    objetosOficina.add(objetoPostit);
    objetosOficina.add(objetoPuerta);
    objetosOficina.add(objetoTelevisor);
    objetosOficina.add(objetoTelefono);
    objetosOficina.add(objetoCelular);
    objetosOficina.add(objetoEstanteria);
    objetosOficina.add(objetoCajon);
}

// Atajo para escalar un tamano de texto (o de icono) con el mismo factor
// que el resto de la interfaz, sin que baje de un minimo legible.
float tx(float base, float minimo) {
    return max(base * escala, minimo);
}

// ===========================================================================
// CICLO PRINCIPAL
// ===========================================================================

// draw() no dibuja nada por si mismo: primero deja avanzar la llamada (que
// cambia de fase con el tiempo), despues despacha a la pantalla que
// corresponde segun el estado actual, y al final aplica el cursor que haya
// pedido lo que esta bajo el mouse.
void draw() {
    // Lo que llegó por la red (multijugador, Red.pde)
    procesarRed();
    // Una cinemática (el prólogo) tapa todo mientras dura (Cinematica.pde)
    if (cinematicaActiva()) {
        actualizarMusicaJuego();
        dibujarCinematica();
        return;
    }
    // Si a esta ronda le tocó la mision, mientras dura es lo unico que se ve.
    if (estado == MISION) {
        mision.dibujar();
        return;
    }
    // Los minijuegos del mundo abierto (EventoParque.pde, Minijuegos.pde)
    if (estado == EVENTO) {
        mundo.dibujar();
        dibujarFeedEvento();   // Civitas en vivo (Impacto.pde)
        mandarFotoEvento();
        return;
    }
    actualizarLlamada();
    actualizarCelular();
    actualizarZoomTV();
    if (dibujarPaseoCamara()) {
        // la camara va entre el menu del cajon y la oficina
    } else if (enMenu) {
        pantallaCajon();
    } else if (estado == MENU) {
        pantallaMenu();
    } else if (estado == ARBOL) {
        pantallaArbol();
    } else if (estado == AYUDA) {
        pantallaAyuda();
    } else if (estado == MAPA) {
        pantallaMapa();
    } else if (estado == CELULAR) {
        pantallaCelular();
    }
    if (enSala && enMenu && !camaraBajando) {
        pantallaSala();
    }
    dibujarCredibilidad();   // Impacto.pde
    dibujarInforme();
    dibujarEsperaTurno();
    dibujarVotaciones();
    actualizarCursor();
}

// Igual que draw(), mousePressed() solo despacha: cada pantalla revisa sus
// propios botones u objetos.
void mousePressed() {
    if (cinematicaActiva()) {
        return;   // en la cinemática el clic no hace nada (se salta con espacio)
    }
    // En el menu del cajon se responde siempre (nada de la oficina lo bloquea)
    if (enMenu && !saliendo && !camaraBajando && !camaraSubiendo) {
        if (enSala) {
            clicEnSala();
        } else {
            clicEnMenu();
        }
        return;
    }
    if (saliendo || camaraBajando || camaraSubiendo || estado == MISION || momentoAMision >= 0 || estado == EVENTO || momentoAEvento >= 0) {
        return;
    }
    if (enSala && enMenu) {
        clicEnSala();
        return;
    }
    if (clicEnInforme()) {
        return;   // el informe de impacto se cierra con un clic
    }
    if (hayVotaciones()) {
        votacionesCerradas = true;
        return;
    }
    if (esperandoTurno) {
        return;  // en red, mientras los demás pasan turno
    }
    if (enMenu) {
        clicEnMenu();
    } else if (estado == MENU) {
        clicEnOficina();
    } else if (estado == ARBOL) {
        clicEnCuaderno();
    } else if (estado == AYUDA) {
        clicEnAyuda();
    } else if (estado == MAPA) {
        clicEnMapa();
    } else if (estado == CELULAR) {
        clicEnCelular();
    }
}

// En la oficina, el primer clic cierra la portada. Durante la llamada los
// clics no hacen nada: la periodista habla a su ritmo y cuelga sola. Si no, cada clic pregunta que
// objeto esta bajo el mouse: mientras suena el telefono solo responden el
// telefono, la ayuda y la puerta; los habilitados cambian de pantalla (o
// salen del juego) y los que llegan despues se sacuden y lo avisan.
void clicEnOficina() {
    if (mostrarPortada) {
        cerrarPortada();
        return;
    }
    if (llamadaEnPantalla()) {
        return;  // la llamada no se adelanta ni se cuelga: se cierra sola
    }
    ObjetoOficina objeto = objetoBajoMouse();
    if (objeto == null) {
        return;
    }
    if (bloqueadoPorLlamada(objeto)) {
        avisar(telefonoSonando() ? "Primero contesta el teléfono: está sonando." : "Espera un momento: el teléfono está por sonar.");
    } else if (objeto == objetoTelefono) {
        clicEnTelefono();
    } else if (objeto == objetoCelular) {
        clicEnCelularOficina();
    } else if (!objeto.habilitado) {
        objetoConCandado = objeto;
        momentoCandado = millis();
        avisar("«" + objeto.funcion + "» llega en las próximas entregas.");
    } else if (objeto == objetoCuaderno) {
        irA(ARBOL);
        cuadernoYaAbierto = true;
    } else if (objeto == objetoTelevisor) {
        irA(MAPA);
        acercarTV();
    } else if (objeto == objetoPostit) {
        irA(AYUDA);
    } else if (objeto == objetoPuerta) {
        saliendo = true;
        momentoSalida = millis();
    } else if (objeto == objetoCajon) {
        volverAlMenu();
    }
}

// El celular se abre despues de oir la noticia; si la campana termino, ya
// no hay nada que publicar.
void clicEnCelularOficina() {
    if (partidaTerminada()) {
        avisar("La campaña terminó: ya no hay más publicaciones.");
    } else if (modoApoyo()) {
        abrirCelular();
    } else if (esRondaDeMision()) {
        avisar("En esta ronda no se publica: la misión de Valeria cuenta como tu jugada.");
    } else if (esRondaDeEvento()) {
        avisar("En esta ronda no se publica: el evento del parque cuenta como tu jugada.");
    } else if (!celularDisponible()) {
        avisar("Primero escucha la noticia del teléfono.");
    } else {
        abrirCelular();
    }
}

void clicEnAyuda() {
    if (botonVolverAyuda.contiene(mouseX, mouseY)) {
        irA(MENU);
    }
}

// Cambia de pantalla. Al volver a la oficina se descarta su foto, porque
// mientras tanto pudo cambiar el turno del calendario.
void irA(int nuevoEstado) {
    if (nuevoEstado != estado) {
        marcarApertura();
        if (nuevoEstado == MENU) {
            marcarCierre(estado);
        }
    }
    estado = nuevoEstado;
    if (nuevoEstado == MENU) {
        fotoOficina = null;
    }
}

// desbloquear() ya revisa por su cuenta si el nodo esta disponible, si es
// su ronda y si hay puntos suficientes: aqui no se repite esa validacion,
// solo se intenta y se anima el resultado (sale una onda si funciono, se
// sacude si no).
void intentarDesbloquear(Nodo n) {
    if (n == null || n.getDesbloqueada()) {
        return;
    }
    int puntosAntes = partida.getPuntos();
    boolean exito = arbol.desbloquear(n.getNombre(), partida);
    nodoAnimado = n;
    momentoAnimacion = millis();
    animacionExitosa = exito;
    if (exito) {
        mostrarTextoFlotante("-" + (puntosAntes - partida.getPuntos()), COLOR_ERROR);
    }
}

// Al pasar turno se vuelve a la oficina: cada turno empieza ahi, con el
// telefono sonando. Si la campana termino, se queda en el cuaderno, donde
// aparece la tarjeta final.
void pasarTurno() {
    // En red el turno avanza cuando todos los candidatos están listos
    if (esperarTurnoRed()) {
        return;
    }
    boolean publico = partida.yaPublicoEsteTurno();
    partida.siguienteTurno();
    reiniciarCelular();
    if (partidaTerminada()) {
        cambiarFaseLlamada(LLAMADA_NINGUNA);
    } else {
        irA(MENU);
        String inicio = publico ? "" : "No publicaste nada en el turno anterior. ";
        avisar(inicio + "Turno " + partida.getTurno() + " de " + Partida.TURNOS_TOTALES + ": recibiste " +
            partida.getPuntosUltimoTurno() + " puntos para el árbol.");
        mostrarTextoFlotante("+" + partida.getPuntosUltimoTurno(), COLOR_EXITO);
        prepararLlamadaDelTurno();
    }
}

// La partida de esta entrega termina al pasar del ultimo turno o cuando ya
// no queda ninguna habilidad por desbloquear.
boolean partidaTerminada() {
    return partida.seAcabaronLosTurnos() || arbolCompleto();
}

// peso() cuenta todos los nodos del arbol: si los desbloqueados son igual
// de muchos, no queda nada por comprar.
boolean arbolCompleto() {
    return arbol.contarDesbloqueadas() == arbol.peso(arbol.getRaiz());
}

// Una partida nueva es simplemente un arbol nuevo (todo bloqueado menos la
// raiz) y la partida reiniciada en el turno 1, que empieza en la oficina
// con la primera llamada.
void reiniciarPartida() {
    reiniciarMisionCampana();
    reiniciarEventosCampana();
    bienvenidaPendiente = true;
    arbol = new ArbolHabilidades();
    partida.iniciar(partida.getNombreCandidato(), arbol);
    fotoCuaderno = null;
    reiniciarCelular();
    nodoSeleccionado = null;
    nodoAnimado = null;
    textoFlotante = null;
    textoAviso = null;
    irA(MENU);
    prepararLlamadaDelTurno();
}

// Al cerrar la portada empieza el primer turno: en un momento suena el
// telefono.
void cerrarPortada() {
    // la primera vez, antes de la campaña, va el prólogo (Cinematica.pde);
    // al terminar se vuelve a llamar a esta misma función
    if (prologoPendiente) {
        prologoPendiente = false;
        empezarCinematica("prologo", "portada");
        return;
    }
    mostrarPortada = false;
    momentoFinPortada = millis();
    prepararLlamadaDelTurno();
    programarBienvenida();   // la videollamada de Valeria, si es la primera vez (Bienvenida.pde)
}

void avisar(String texto) {
    textoAviso = texto;
    momentoAviso = millis();
}

void mostrarTextoFlotante(String texto, color c) {
    textoFlotante = texto;
    colorFlotante = c;
    momentoFlotante = millis();
}

// ===========================================================================
// TECLADO
// ===========================================================================

// Esc vuelve a la oficina en vez de cerrar el juego (para salir esta la
// puerta). Enter o la barra espaciadora contestan el telefono, igual que
// un clic (la llamada ya no se puede adelantar). La tecla P muestra, durante la
// sustentacion, que el recorrido preorden y las medidas del arbol funcionan
// de verdad y no son solo una animacion en pantalla.
void keyPressed() {
    if (cinematicaActiva()) {
        if (key == ESC) {
            key = 0;
        }
        if (key == ' ' || key == ESC || key == ENTER || key == RETURN) {
            saltarCinematica();
        }
        return;
    }
    if (estado == MISION) {
        if (key == ESC) {
            key = 0;  // en la mision Esc no cierra el juego
        }
        mision.teclaPresionada();
        return;
    }
    if (estado == EVENTO) {
        if (key == ESC) {
            key = 0;
        }
        if (key == CODED && keyCode == 119) {   // F8: siguiente ambiente de color (Ambiente.pde)
            siguienteAmbiente();
            return;
        }
        mundo.teclaPresionada();
        return;
    }
    if (enSala && enMenu) {
        teclaSala();
        return;
    }
    if (opcionesAbiertas) {
        if (key == ESC) {
            key = 0;
        }
        teclaOpciones();
        return;
    }
    if (key == ESC) {
        key = 0;  // sin esto, Processing cerraria el juego al oprimir Esc
        teclaEscape();
    } else if (estado == CELULAR && (key == ENTER || key == RETURN || (key >= '1' && key <= '6'))) {
        teclaCelular();
    } else if (estado == ARBOL && (key == ENTER || key == RETURN)) {
        // En el cuaderno, Enter compra la habilidad elegida (igual que el boton).
        if (nodoSeleccionado != null && sePuedeComprar(nodoSeleccionado)) {
            intentarDesbloquear(nodoSeleccionado);
        }
    } else if (key == ENTER || key == RETURN || key == ' ') {
        teclaContestar();
    } else if (key == 'P' || key == 'p') {
        imprimirPreordenConsola();
    }
}

void keyReleased() {
    if (estado == MISION) {
        mision.teclaSoltada();
    }
    if (estado == EVENTO) {
        mundo.teclaSoltada();
    }
}

void teclaContestar() {
    if (estado != MENU || saliendo || mostrarPortada) {
        return;
    }
    if (telefonoSonando()) {
        clicEnTelefono();
    }
}

void teclaEscape() {
    if (saliendo || enMenu || camaraBajando || camaraSubiendo) {
        return;
    }
    if (llamadaEnPantalla()) {
        return;
    } else if (estado == MAPA) {
        if (videollamadaActiva) {
            terminarBienvenida();   // Esc salta la bienvenida
        } else {
            alejarTV();
        }
    } else if (estado == ARBOL || estado == AYUDA || estado == CELULAR) {
        irA(MENU);
    } else if (mostrarPortada) {
        cerrarPortada();
    } else {
        avisar("Para salir del juego, haz clic en la puerta.");
    }
}

void imprimirPreordenConsola() {
    println("--- Recorrido preorden del árbol de habilidades ---");
    for (Nodo n : arbol.preorden()) {
        String marca = n.getDesbloqueada() ? "[X]" : "[ ]";
        println(marca + " " + n.getNombre());
    }
    println("Altura: " + arbol.altura(arbol.getRaiz()));
    println("Peso: " + arbol.peso(arbol.getRaiz()));
    println("Desbloqueadas: " + arbol.contarDesbloqueadas() + " de " + arbol.peso(arbol.getRaiz()) + " nodos");
    String disponibles = "";
    for (Nodo n : arbol.disponibles()) {
        if (!disponibles.isEmpty()) {
            disponibles += ", ";
        }
        disponibles += n.getNombre();
    }
    if (disponibles.isEmpty()) {
        disponibles = "ninguna";
    }
    println("Disponibles ahora: " + disponibles);
    Noticia n = partida.getNoticiaDelTurno();
    println("Noticia del turno " + turnoVisible() + " (" + n.nombreTipo() + "): " + n.getTitular());
    imprimirGrafoConsola();
}

// Lo mismo para el grafo: la matriz de adyacencia (minutos), los niveles del
// BFS desde los barrios propios, a donde se puede publicar y la tabla de
// Dijkstra desde la sede,
// como la tabla final que se hace en clase: el valor Final de cada barrio
// (minutos desde la sede) y su Anterior, para leer el camino hacia atras.
void imprimirGrafoConsola() {
    GrafoCiudad ciudad = partida.getCiudad();
    int n = ciudad.cantidad();
    println("--- Grafo de Ciudad Nova: matriz de adyacencia (minutos, 0 = sin calle) ---");
    for (int a = 0; a < n; a++) {
        String fila = "";
        for (int b = 0; b < n; b++) {
            fila += nf(ciudad.getMinutos(a, b), 2) + " ";
        }
        println(fila + " " + a + " " + ciudad.getNombre(a));
    }
    boolean[] propios = partida.barriosPropios();
    boolean[] alcanzables = partida.alcanzablesDesde(propios);
    int[] nivel = ciudad.niveles(propios);
    String textoNiveles = "";
    for (int z = 0; z < n; z++) {
        textoNiveles += (textoNiveles.isEmpty() ? "" : ", ") + ciudad.getNombre(z) + "=" + nivel[z];
    }
    println("BFS desde tus barrios (calles de distancia): " + textoNiveles);
    println("Puedes publicar hasta a " + partida.callesDeAlcance() + " calle(s) de tu territorio.");
    String textoPropios = "";
    String textoAlcance = "";
    for (int z = 0; z < n; z++) {
        if (propios[z]) {
            textoPropios += (textoPropios.isEmpty() ? "" : ", ") + ciudad.getNombre(z) + " (" + partida.getApoyo(z) + ")";
        } else if (alcanzables[z]) {
            textoAlcance += (textoAlcance.isEmpty() ? "" : ", ") + ciudad.getNombre(z) + " (" + partida.getApoyo(z) + ")";
        }
    }
    println("Barrios propios (apoyo): " + textoPropios);
    println("Se puede publicar también en: " + (textoAlcance.isEmpty() ? "ninguno más" : textoAlcance));

    boolean[] fijo = new boolean[n];
    int[] temporal = new int[n];
    int[] anterior = new int[n];
    ciudad.dijkstra(Partida.ZONA_SEDE, fijo, temporal, anterior);
    println("--- Dijkstra desde la sede (" + ciudad.getNombre(Partida.ZONA_SEDE) + ") ---");
    println("Barrio               | Final  | Anterior");
    for (int z = 0; z < n; z++) {
        String nombre = ciudad.getNombre(z);
        while (nombre.length() < 20) {
            nombre += " ";
        }
        String previo = anterior[z] == GrafoCiudad.SIN_ANTERIOR ? "–" : ciudad.getNombre(anterior[z]);
        println(nombre + " | " + nf(temporal[z], 2) + " min | " + previo);
    }
}
