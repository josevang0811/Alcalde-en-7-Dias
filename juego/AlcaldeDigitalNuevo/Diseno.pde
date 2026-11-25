// Diseno — el rediseno grafico del equipo (el prototipo Oficina.html).
//
// La oficina, el cajon del menu, el telefono, el celular, el mapa de papel,
// el libro y el noticiero son dibujos del equipo que viven en data/. Este
// archivo los carga y tiene lo que comparten todas las pantallas:
//   1. Las imagenes y la "camara": el rectangulo de la pantalla donde se ve
//      el dibujo (con la proporcion del dibujo; lo que sobra queda negro).
//   2. La letra en pixel art (5 x 7) del prototipo, para titulos, la TV,
//      el menu y el libro.
//   3. El menu del cajon con el periodico y el paseo de la camara hacia la
//      oficina.
//   4. Lo que se dibuja encima de la oficina: el turno en el calendario, el
//      titular de la TV y el telefono que vibra.
//   5. Las animaciones de abrir un objeto: la oficina se oscurece y el
//      objeto sube desde abajo balanceandose; y el zoom al televisor.
// La logica del juego no cambia: solo cambia como se ve.

// ===========================================================================
// 1. IMAGENES Y CAMARA
// ===========================================================================

PImage imgCajon;          // el menu: el cajon abierto con el periodico
PImage imgOficina;        // la oficina con todo en su lugar
PImage imgSinAuricular;   // oscurecida y sin el auricular (durante la llamada)
PImage imgSinCelular;     // oscurecida y sin el celular (al publicar)
PImage imgSinLibro;       // oscurecida y sin el libro (el arbol)
PImage imgAuricular, imgCelular, imgMapaCiudad;
PImage[] pinesBarrio = new PImage[8];   // las ubicaciones del mapa de papel
PImage imgTelefonoBase;   // el telefono recortado de la oficina, para hacerlo vibrar
PImage imgCursor, imgCursorMano;

// Proporcion del dibujo (2576 x 1438 en el prototipo).
final float PROPORCION_DIBUJO = 2576.0 / 1438.0;
// La "camara": donde queda el dibujo en la pantalla.
float camX, camY, camAncho, camAlto;

void cargarDiseno() {
    imgCajon = loadImage("menu_cajon.jpg");
    cargarCapasOficina();
    cargarBienvenida();   // Bienvenida.pde
    cargarTelevisor();
    imgAuricular = loadImage("auricular.png");
    imgCelular = loadImage("celular.png");
    imgMapaCiudad = loadImage("mapa_ciudad.png");
    for (int z = 0; z < pinesBarrio.length; z++) {
        pinesBarrio[z] = loadImage("pin_barrio_" + z + ".png");
    }
    cargarLibroHabilidades();   // Cuaderno.pde
    imgCursor = loadImage("cursor.png");
    imgCursorMano = loadImage("cursor_mano.png");
    prepararGlifos();
    prepararPapelMenu();
}

// --- La oficina por capas ---
// El fondo (la oficina con el escritorio vacío y la TV apagada) y cada
// objeto de la mesa son dibujos separados del equipo. Con ellos se arman,
// una sola vez al empezar, las versiones que usa el juego: la oficina con
// todo, y las oscurecidas sin el objeto que se tiene en la mano (el
// teléfono sin el auricular durante la llamada, sin el celular y el mapa al
// publicar, sin el libro al abrir el árbol). Para agregar un objeto nuevo
// o animarlo basta con su imagen y su lugar en CAPAS_MESA.

final int CAPA_TELEFONO = 0, CAPA_CELULAR = 1, CAPA_MAPA = 2, CAPA_LIBRO = 3;
String[] ARCHIVOS_MESA = {"mesa_telefono.png", "mesa_celular.png", "mesa_mapa.png", "mesa_libro.png"};
// esquina de arriba a la izquierda de cada objeto, en el dibujo de 1932 x 1079
float[][] CAPAS_MESA = {{1447, 606}, {258, 718}, {410, 648}, {779, 650}};
PImage[] objetosMesa = new PImage[4];
PImage imgFondoOficina, imgTelefonoSinAuricular, imgOficinaSinTelefono;
final float ANCHO_DIBUJO = 1932, ALTO_DIBUJO = 1079;

void cargarCapasOficina() {
    imgFondoOficina = loadImage("oficina_fondo.jpg");
    for (int k = 0; k < objetosMesa.length; k++) {
        objetosMesa[k] = loadImage(ARCHIVOS_MESA[k]);
    }
    imgTelefonoSinAuricular = loadImage("mesa_telefono_base.png");
    imgTelefonoBase = objetosMesa[CAPA_TELEFONO];
    boolean[] todos = {true, true, true, true};
    imgOficina = componerOficina(todos, true, 1);
    imgOficinaSinTelefono = componerOficina(new boolean[] {false, true, true, true}, true, 1);
    imgSinAuricular = componerOficina(todos, false, 0.58);
    imgSinCelular = componerOficina(new boolean[] {true, false, false, true}, true, 0.72);
    imgSinLibro = componerOficina(new boolean[] {true, true, true, false}, true, 0.41);
}

// La oficina con los objetos que se piden ("auricular": si el teléfono
// tiene el auricular puesto) y oscurecida a "brillo" (1 = normal).
PImage componerOficina(boolean[] con, boolean auricular, float brillo) {
    PGraphics pg = createGraphics((int) ANCHO_DIBUJO, (int) ALTO_DIBUJO);
    pg.beginDraw();
    pg.image(imgFondoOficina, 0, 0, ANCHO_DIBUJO, ALTO_DIBUJO);
    for (int k = 0; k < objetosMesa.length; k++) {
        if (!con[k]) {
            continue;
        }
        PImage img = objetosMesa[k];
        float x = CAPAS_MESA[k][0], y = CAPAS_MESA[k][1];
        if (k == CAPA_TELEFONO && !auricular) {
            img = imgTelefonoSinAuricular;
            x += 2;   // la base sola queda corrida dos pixeles
        }
        pg.image(img, x, y);
    }
    if (brillo < 1) {
        pg.noStroke();
        pg.fill(0, 255 * (1 - brillo));
        pg.rect(0, 0, ANCHO_DIBUJO, ALTO_DIBUJO);
    }
    pg.endDraw();
    return pg.get();
}

void calcularCamara() {
    camAncho = min(width, height * PROPORCION_DIBUJO);
    camAlto = camAncho / PROPORCION_DIBUJO;
    camX = (width - camAncho) / 2;
    camY = (height - camAlto) / 2;
}

// Posiciones en porcentaje de la camara (las mismas del prototipo) pasadas
// a pixeles de pantalla.
float pcX(float porcentaje) {
    return camX + camAncho * porcentaje / 100;
}

float pcY(float porcentaje) {
    return camY + camAlto * porcentaje / 100;
}

float pcAncho(float porcentaje) {
    return camAncho * porcentaje / 100;
}

float pcAlto(float porcentaje) {
    return camAlto * porcentaje / 100;
}

// Y en el lienzo de la oficina (1200 de ancho, ver Interfaz.pde).
float exPc(float porcentaje) {
    return ANCHO_ESCENA * porcentaje / 100;
}

float eyPc(float porcentaje) {
    return ALTO_ESCENA * porcentaje / 100;
}

// Curvas de animacion del prototipo.
float facilEntradaSalida(float x) {
    x = constrain(x, 0, 1);
    return x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2;
}

// Sube rapido y frena suave (como la curva cubic-bezier(.2,.85,.25,1) del
// prototipo, que usan los objetos al subir).
float facilSalida(float x) {
    x = constrain(x, 0, 1);
    return 1 - pow(1 - x, 3.6);
}

// ===========================================================================
// 2. LETRA EN PIXEL ART
// ===========================================================================
// Cada letra es una cuadricula de 7 filas: "1" es un pixel pintado. Los
// textos se arman en una imagen pequena (un pixel por celda) y se agrandan
// al dibujarlos; como el juego dibuja las imagenes sin suavizar, quedan con
// pixeles gruesos igual que en el prototipo. Cada texto se arma una sola vez
// y se guarda.

String[] GLIFOS = {
    " 00/00/00/00/00/00/00",
    "!11/11/11/11/11/00/11",
    "%11001/11010/00010/00100/01000/01011/10011",
    "+00000/00100/00100/11111/00100/00100/00000",
    ",00/00/00/00/11/11/01",
    "-00000/00000/00000/11111/00000/00000/00000",
    ".00/00/00/00/00/11/11",
    "001110/10001/10011/10101/11001/10001/01110",
    "100100/01100/00100/00100/00100/00100/01110",
    "201110/10001/00001/00010/00100/01000/11111",
    "311110/00001/00001/01110/00001/00001/11110",
    "400010/00110/01010/10010/11111/00010/00010",
    "511111/10000/11110/00001/00001/10001/01110",
    "600110/01000/10000/11110/10001/10001/01110",
    "711111/00001/00010/00100/01000/01000/01000",
    "801110/10001/10001/01110/10001/10001/01110",
    "901110/10001/10001/01111/00001/00010/01100",
    ":00/11/11/00/11/11/00",
    "?01110/10001/00001/00110/00100/00000/00100",
    "A01110/10001/10001/11111/10001/10001/10001",
    "B11110/10001/10001/11110/10001/10001/11110",
    "C01110/10001/10000/10000/10000/10001/01110",
    "D11110/10001/10001/10001/10001/10001/11110",
    "E11111/10000/10000/11110/10000/10000/11111",
    "F11111/10000/10000/11110/10000/10000/10000",
    "G01110/10001/10000/10111/10001/10001/01111",
    "H10001/10001/10001/11111/10001/10001/10001",
    "I01110/00100/00100/00100/00100/00100/01110",
    "J00111/00010/00010/00010/00010/10010/01100",
    "K10001/10010/10100/11000/10100/10010/10001",
    "L10000/10000/10000/10000/10000/10000/11111",
    "M10001/11011/10101/10101/10001/10001/10001",
    "N10001/11001/10101/10101/10011/10001/10001",
    "O01110/10001/10001/10001/10001/10001/01110",
    "P11110/10001/10001/11110/10000/10000/10000",
    "Q01110/10001/10001/10001/10101/10010/01101",
    "R11110/10001/10001/11110/10100/10010/10001",
    "S01111/10000/10000/01110/00001/00001/11110",
    "T11111/00100/00100/00100/00100/00100/00100",
    "U10001/10001/10001/10001/10001/10001/01110",
    "V10001/10001/10001/10001/10001/01010/00100",
    "W10001/10001/10001/10101/10101/11011/10001",
    "X10001/10001/01010/00100/01010/10001/10001",
    "Y10001/10001/01010/00100/00100/00100/00100",
    "Z11111/00001/00010/00100/01000/10000/11111",
    "■00000/01110/01110/01110/00000/00000/00000",
    "¡11/00/11/11/11/11/11",
    "¿00100/00000/00100/01100/10000/10001/01110",
    "/00001/00010/00010/00100/01000/01000/10000",
    "(010/100/100/100/100/100/010",
    ")010/001/001/001/001/001/010",
    "'1/1/0/0/0/0/0",
    "\"101/101/000/000/000/000/000",
    "·0/0/0/1/0/0/0",
    "=00000/00000/11111/00000/11111/00000/00000",
    ">10000/01000/00100/00010/00100/01000/10000",
    "<00001/00010/00100/01000/00100/00010/00001",
    ";00/11/11/00/11/11/01",
    "@01110/10001/10111/10101/10111/10000/01110",
    "#01010/11111/01010/01010/11111/01010/00000",
    "_00000/00000/00000/00000/00000/00000/11111",
    "&01100/10010/10100/01000/10101/10010/01101",
    "*00000/10101/01110/11111/01110/10101/00000",
    "«00000/00101/01010/10100/01010/00101/00000",
    "»00000/10100/01010/00101/01010/10100/00000",
    "—0000000/0000000/0000000/1111111/0000000/0000000/0000000",
    "–00000/00000/00000/11111/00000/00000/00000",
    "…00000/00000/00000/00000/00000/00000/10101",
    "$00100/01111/10100/01110/00101/11110/00100",
    "[110/100/100/100/100/100/110",
    "]011/001/001/001/001/001/011",
    "|1/1/1/1/1/1/1",
    "✓00000/00001/00010/10100/01000/00000/00000",
    "→00000/00100/00010/11111/00010/00100/00000",
    "←00000/00100/01000/11111/01000/00100/00000",
    "±00100/00100/11111/00100/00100/00000/11111",
    "º010/101/010/000/000/000/000",
    "°010/101/010/000/000/000/000",
    "“101/101/000/000/000/000/000",
    "”101/101/000/000/000/000/000",
    "‘1/1/0/0/0/0/0",
    "’1/1/0/0/0/0/0",
    "♥00000/01010/11111/11111/01110/00100/00000"
};

// Las tildes se dibujan encima de la letra sin tilde.
String LETRAS_CON_TILDE = "ÁÉÍÓÚÑÜ";
String LETRAS_SIN_TILDE = "AEIOUNU";
String[] MARCA_TILDE = {"00010", "00100"};
String[] MARCA_ENIE = {"01001", "10110"};

HashMap<Character, String[]> glifos = new HashMap<Character, String[]>();
HashMap<String, PImage> textosPixel = new HashMap<String, PImage>();

void prepararGlifos() {
    for (String g : GLIFOS) {
        glifos.put(g.charAt(0), split(g.substring(1), '/'));
    }
}

char letraBase(char c) {
    c = Character.toUpperCase(c);
    int i = LETRAS_CON_TILDE.indexOf(c);
    return i >= 0 ? LETRAS_SIN_TILDE.charAt(i) : c;
}

String[] glifo(char c) {
    String[] g = glifos.get(letraBase(c));
    return g != null ? g : glifos.get(' ');
}

// Ancho de un texto en celdas (con letra de tamano 1).
int medirPixel(String texto) {
    int ancho = 0;
    for (int i = 0; i < texto.length(); i++) {
        ancho += glifo(texto.charAt(i))[0].length() + 1;
    }
    return max(0, ancho - 1);
}

// Parte un texto en lineas de a lo sumo "maxCeldas" (a tamano 1).
ArrayList<String> partirPixel(String texto, int maxCeldas) {
    ArrayList<String> lineas = new ArrayList<String>();
    String linea = "";
    for (String palabra : split(texto, ' ')) {
        String prueba = linea.isEmpty() ? palabra : linea + " " + palabra;
        if (medirPixel(prueba) > maxCeldas && !linea.isEmpty()) {
            lineas.add(linea);
            linea = palabra;
        } else {
            linea = prueba;
        }
    }
    lineas.add(linea);
    return lineas;
}

final int MARGEN_PIXEL = 2;   // celdas libres alrededor (para el borde y la negrita)

// Arma la imagen de un texto. s: cuantas celdas mide cada punto de la letra.
// borde, luz y sombra en 0 quieren decir "sin eso": el borde es un
// contorno de una celda; la luz pinta la fila de arriba de cada trazo y la
// sombra la de abajo (como en el "7" rojo del periodico).
PImage imagenTextoPixel(String texto, int s, color relleno, color borde, color luz, color sombra, boolean negrita) {
    String clave = texto + "|" + s + "|" + relleno + "|" + borde + "|" + luz + "|" + sombra + "|" + negrita;
    PImage guardada = textosPixel.get(clave);
    if (guardada != null) {
        return guardada;
    }
    if (textosPixel.size() > 3000) {
        textosPixel.clear();   // los textos que cambian cada cuadro (contadores) no se acumulan
    }
    int ancho = medirPixel(texto) * s + MARGEN_PIXEL * 2;
    int alto = 9 * s + MARGEN_PIXEL * 2;   // 7 filas y 2 arriba para las tildes
    boolean[][] lleno = new boolean[ancho][alto];
    int x = MARGEN_PIXEL;
    int y0 = MARGEN_PIXEL + 2 * s;
    for (int i = 0; i < texto.length(); i++) {
        char c = Character.toUpperCase(texto.charAt(i));
        String[] g = glifo(c);
        int anchoGlifo = g[0].length();
        marcarGlifo(lleno, g, x, y0, s);
        int t = LETRAS_CON_TILDE.indexOf(c);
        if (t >= 0) {
            marcarGlifo(lleno, c == 'Ñ' ? MARCA_ENIE : MARCA_TILDE, x, y0 - 2 * s, s);
        }
        x += (anchoGlifo + 1) * s;
    }
    if (negrita) {
        lleno = engrosar(lleno);
    }
    PImage img = createImage(ancho, alto, ARGB);
    img.loadPixels();
    for (int cy = 0; cy < alto; cy++) {
        for (int cx = 0; cx < ancho; cx++) {
            color c = 0;
            if (lleno[cx][cy]) {
                c = relleno;
                if (luz != 0 && (cy == 0 || !lleno[cx][cy - 1])) {
                    c = luz;
                } else if (sombra != 0 && (cy == alto - 1 || !lleno[cx][cy + 1])) {
                    c = sombra;
                }
            } else if (borde != 0 && tocaLleno(lleno, cx, cy)) {
                c = borde;
            }
            img.pixels[cy * ancho + cx] = c;
        }
    }
    img.updatePixels();
    textosPixel.put(clave, img);
    return img;
}

void marcarGlifo(boolean[][] lleno, String[] g, int x, int y, int s) {
    for (int fila = 0; fila < g.length; fila++) {
        for (int col = 0; col < g[fila].length(); col++) {
            if (g[fila].charAt(col) != '1') {
                continue;
            }
            for (int a = 0; a < s; a++) {
                for (int b = 0; b < s; b++) {
                    int px = x + col * s + a;
                    int py = y + fila * s + b;
                    if (px >= 0 && py >= 0 && px < lleno.length && py < lleno[0].length) {
                        lleno[px][py] = true;
                    }
                }
            }
        }
    }
}

boolean tocaLleno(boolean[][] lleno, int x, int y) {
    for (int dx = -1; dx <= 1; dx++) {
        for (int dy = -1; dy <= 1; dy++) {
            int px = x + dx;
            int py = y + dy;
            if (px >= 0 && py >= 0 && px < lleno.length && py < lleno[0].length && lleno[px][py]) {
                return true;
            }
        }
    }
    return false;
}

boolean[][] engrosar(boolean[][] lleno) {
    boolean[][] nuevo = new boolean[lleno.length][lleno[0].length];
    for (int x = 0; x < lleno.length; x++) {
        for (int y = 0; y < lleno[0].length; y++) {
            nuevo[x][y] = tocaLleno(lleno, x, y);
        }
    }
    return nuevo;
}

// Dibuja un texto en letra pixel. "celda" es lo que mide un pixel de la
// letra donde se dibuja; alinH es LEFT, CENTER o RIGHT y alinV TOP, CENTER o
// BOTTOM (se alinea la caja de las 7 filas, sin contar el margen).
void textoPixel(String texto, float x, float y, float celda, int s, color relleno, color borde,
                color luz, color sombra, boolean negrita, int alinH, int alinV) {
    PImage img = imagenTextoPixel(texto, s, relleno, borde, luz, sombra, negrita);
    float anchoTexto = medirPixel(texto) * s * celda;
    float altoTexto = 7 * s * celda;
    float x0 = x;
    if (alinH == CENTER) {
        x0 = x - anchoTexto / 2;
    } else if (alinH == RIGHT) {
        x0 = x - anchoTexto;
    }
    float y0 = y;
    if (alinV == CENTER) {
        y0 = y - altoTexto / 2;
    } else if (alinV == BOTTOM) {
        y0 = y - altoTexto;
    }
    image(img, x0 - MARGEN_PIXEL * celda, y0 - (MARGEN_PIXEL + 2 * s) * celda, img.width * celda, img.height * celda);
}

// Tamano de celda de la letra pixel para la interfaz (2 en 720p, 3 en 1080p).
float celdaInterfaz() {
    return max(2, round(camAncho / 640));
}

// Atajo para el caso comun: texto liso de un color.
void textoPixel(String texto, float x, float y, float celda, color relleno, int alinH, int alinV) {
    textoPixel(texto, x, y, celda, 1, relleno, 0, 0, 0, false, alinH, alinV);
}

// Parrafo en letra pixel; devuelve el alto que ocupo.
float parrafoPixel(String texto, float x, float y, float celda, float ancho, color relleno, int maxLineas) {
    ArrayList<String> lineas = partirPixel(texto, floor(ancho / celda));
    int n = min(lineas.size(), maxLineas);
    for (int i = 0; i < n; i++) {
        textoPixel(lineas.get(i), x, y + i * 11 * celda, celda, relleno, LEFT, TOP);
    }
    return n * 11 * celda;
}

// ===========================================================================
// 3. EL MENU: EL CAJON CON EL PERIODICO
// ===========================================================================
// El periodico se arma una sola vez en una imagen de 284 x 234 celdas (como
// el prototipo) y las opciones en imagenes de 236 x 28, normal y resaltada.

final int PAPEL_ANCHO = 284, PAPEL_ALTO = 234;
final int OPCION_ANCHO = 236, OPCION_ALTO = 28;
String[] OPCIONES_MENU = {"SOLO", "MULTIJUGADOR", "OPCIONES", "SALIR"};
final int OPCION_SOLO = 0, OPCION_MULTIJUGADOR = 1, OPCION_OPCIONES = 2, OPCION_SALIR = 3;
PImage papelMenu;
PImage[] opcionNormal = new PImage[4];
PImage[] opcionResaltada = new PImage[4];
int opcionBajoMouse = -1;

// Paseo de la camara entre el menu y la oficina.
boolean enMenu = true;            // se ve el cajon (o se esta saliendo de el)
boolean camaraBajando = false;    // del menu a la oficina
boolean camaraSubiendo = false;   // de la oficina al menu
int momentoCamara;
boolean campanaEmpezada = false;

// Bordes irregulares del papel (en celdas), como en el prototipo.
int bordeArriba(int x) {
    return 7 + round(1.6 * sin(x / 21.0) + 1.1 * sin(x / 8.5));
}

int bordeAbajo(int x) {
    return 227 + round(1.8 * sin(x / 26.0 + 1) + 1.0 * sin(x / 9.0));
}

int bordeIzquierdo(int y) {
    return 7 + round(0.6 * sin(y / 29.0));
}

int bordeDerecho(int y) {
    return 277 + round(2 * sin(y / 33.0 + 2) + 1 * sin(y / 11.0));
}

boolean dentroPapel(int x, int y) {
    return x >= bordeIzquierdo(y) && x <= bordeDerecho(y) && y >= bordeArriba(x) && y <= bordeAbajo(x);
}

// Un "ruido" fijo por celda para las manchitas del papel.
int ruidoCelda(int x, int y) {
    int h = x * 374761393 + y * 668265263;
    h = (h ^ (h >>> 13)) * 1274126177;
    return (h ^ (h >>> 16)) & 0x7fffffff;
}

color[] COLORES_ROLLO = {#1a1414, #78767a, #78767a, #605e64, #605e64, #aaa8aa, #aaa8aa, #aaa8aa, #aaa8aa,
    #cdcbc8, #cdcbc8, #96949a, #96949a, #96949a, #bebcba, #bebcba, #bebcba, #d2cfc8, #d2cfc8, #d2cfc8,
    #d2cfc8, #aaa69e};

void prepararPapelMenu() {
    PGraphics p = createGraphics(PAPEL_ANCHO, PAPEL_ALTO);
    p.noSmooth();   // antes de beginDraw, o Processing lo ignora
    p.beginDraw();
    p.noStroke();
    p.clear();
    // sombra
    p.fill(0, 97);
    for (int y = 0; y < PAPEL_ALTO; y++) {
        for (int x = 0; x < PAPEL_ANCHO; x++) {
            if (dentroPapel(x - 4, y - 5) && !dentroPapel(x, y)) {
                p.rect(x, y, 1, 1);
            }
        }
    }
    // la hoja, con el rollo de la izquierda
    for (int y = 0; y < PAPEL_ALTO; y++) {
        for (int x = 0; x < PAPEL_ANCHO; x++) {
            if (!dentroPapel(x, y)) {
                continue;
            }
            boolean borde = !dentroPapel(x - 1, y) || !dentroPapel(x + 1, y) || !dentroPapel(x, y - 1) || !dentroPapel(x, y + 1);
            color c;
            int dx = x - bordeIzquierdo(y);
            if (borde) {
                c = #1a1414;
            } else if (dx < COLORES_ROLLO.length) {
                c = COLORES_ROLLO[dx];
            } else {
                c = #d8d4cc;
                int h = ruidoCelda(x, y) % 97;
                if (h == 0) c = #c8c4bc;
                if (h == 1) c = #e4e0d8;
                if (x > bordeDerecho(y) - 5) c = #c8c4bc;
                if (y > bordeAbajo(x) - 4) c = #c0bcb4;
                if (y == bordeArriba(x) + 1) c = #ece8e0;
            }
            p.fill(c);
            p.rect(x, y, 1, 1);
        }
    }
    // cabecera
    p.fill(#1a1414);
    p.rect(30, 12, 233, 2);
    p.rect(30, 26, 233, 1);
    p.rect(34, 17, 3, 3);
    p.rect(256, 17, 3, 3);
    String cabecera = "DIARIO DE CIUDAD NOVA";
    pegarTexto(p, cabecera, 146 - medirPixel(cabecera) / 2, 17, 1, #3a3434, 0, 0, 0, false);
    // titular: "ALCALDE EN 7 DÍAS"
    pegarTexto(p, "ALCALDE", 35, 32, 3, #a8a49a, 0, 0, 0, false);
    pegarTexto(p, "ALCALDE", 34, 31, 3, #1a1616, 0, 0, 0, false);
    pegarTexto(p, "EN", 35, 55, 2, #a8a49a, 0, 0, 0, false);
    pegarTexto(p, "EN", 34, 54, 2, #1a1616, 0, 0, 0, false);
    pegarTexto(p, "7", 34, 71, 4, #c42828, #2a0c0c, #e65050, #8c1616, false);
    pegarTexto(p, "DÍAS", 72, 69, 4, #a8a49a, 0, 0, 0, false);
    pegarTexto(p, "DÍAS", 71, 68, 4, #1a1616, 0, 0, 0, false);
    // la foto del candidato
    p.fill(#1a1414);
    p.rect(201, 31, 62, 56);
    p.fill(#b4b4ba);
    p.rect(203, 33, 58, 52);
    p.fill(#a2a2a8);
    p.rect(203, 70, 58, 15);
    p.fill(#7c7c84);
    circuloFoto(p, 252, 55, 5);
    elipseFoto(p, 253, 72, 12, 13, 60);
    p.fill(#1a1a1e);
    circuloFoto(p, 228, 52, 10);
    elipseFoto(p, 228, 86, 24, 22, 62);
    p.fill(#d6d6dc);
    p.rect(206, 35, 14, 1);
    p.rect(206, 36, 16, 1);
    // columnas de texto de mentiras
    p.fill(#78746e);
    long semilla = 7;
    for (int k = 0; k < 6; k++) {
        int x = 172;
        int y = 70 + k * 5;
        int fin = k == 5 ? 210 : 258;
        while (x < fin) {
            semilla = (semilla * 1664525L + 1013904223L) % 4294967296L;
            int w = 5 + (int) (semilla / 4294967296.0 * 9);
            p.rect(x, y, min(w, fin - x), 1);
            x += w + 2;
        }
    }
    // reglas dobles y pie
    p.fill(#1a1414);
    p.rect(34, 100, 229, 1);
    p.rect(34, 102, 229, 1);
    String pie = "EDICIÓN ESPECIAL";
    pegarTexto(p, pie, 146 - medirPixel(pie) / 2, 217, 1, #6a6660, 0, 0, 0, false);
    p.endDraw();
    papelMenu = p.get();

    for (int i = 0; i < OPCIONES_MENU.length; i++) {
        opcionNormal[i] = imagenOpcion(i, false);
        opcionResaltada[i] = imagenOpcion(i, true);
    }
}

void circuloFoto(PGraphics p, int cx, int cy, int r) {
    for (int y = -r; y <= r; y++) {
        for (int x = -r; x <= r; x++) {
            if (x * x + y * y <= r * r && dentroFoto(cx + x, cy + y)) {
                p.rect(cx + x, cy + y, 1, 1);
            }
        }
    }
}

// Media elipse de los hombros: solo desde la fila "desde" hacia abajo.
void elipseFoto(PGraphics p, float cx, float cy, float rx, float ry, int desde) {
    for (int y = desde; y < 85; y++) {
        for (int x = 203; x < 261; x++) {
            float dx = (x - cx) / rx;
            float dy = (y - cy) / ry;
            if (dx * dx + dy * dy <= 1) {
                p.rect(x, y, 1, 1);
            }
        }
    }
}

boolean dentroFoto(int x, int y) {
    return x >= 203 && x < 261 && y >= 33 && y < 85;
}

// Pega un texto pixel dentro de un PGraphics, en celdas (sin agrandar).
void pegarTexto(PGraphics p, String texto, int x, int y, int s, color relleno, color borde, color luz, color sombra, boolean negrita) {
    PImage img = imagenTextoPixel(texto, s, relleno, borde, luz, sombra, negrita);
    p.image(img, x - MARGEN_PIXEL, y - MARGEN_PIXEL - 2 * s);
}

// Una opcion del menu: normal (texto oscuro con un cuadrito) o resaltada
// (franja roja de marcador, flecha y texto claro con borde).
PImage imagenOpcion(int i, boolean resaltada) {
    PGraphics p = createGraphics(OPCION_ANCHO, OPCION_ALTO);
    p.noSmooth();
    p.beginDraw();
    p.noStroke();
    p.clear();
    String texto = OPCIONES_MENU[i];
    int ox = 21;
    int anchoTexto = medirPixel(texto) * 3;
    if (resaltada) {
        for (int y = 2; y < 26; y++) {
            int a = 2 + ((y * 7) % 3);
            int b = ox + anchoTexto + 10 - ((y * 5) % 4);
            for (int x = a; x < b; x++) {
                p.fill((x + y) % 11 == 0 ? #d9453c : #e8584d);
                p.rect(x, y, 1, 1);
            }
        }
        p.fill(#1a1010);
        for (int dy = 0; dy < 11; dy++) {
            int w = dy <= 5 ? dy + 1 : 11 - dy;
            p.rect(5, 8 + dy, w * 2, 1);
        }
        pegarTexto(p, texto, ox, 4, 3, #fff7e6, #1a1010, 0, 0, false);
    } else {
        p.fill(#5a5450);
        p.rect(8, 12, 5, 5);
        pegarTexto(p, texto, ox + 1, 5, 3, #f2eee4, 0, 0, 0, false);
        pegarTexto(p, texto, ox, 4, 3, #1a1616, 0, 0, 0, false);
    }
    if (i < 3) {
        p.fill(#8a847c);
        for (int x = 2; x < 234; x += 2) {
            p.rect(x, 27, 1, 1);
        }
    }
    p.endDraw();
    return p.get();
}

// Donde va el periodico: el rectangulo del prototipo, con un vaiven suave.
float papelX() {
    return pcX(26.86);
}

float papelY() {
    return pcY(11.96) - pcAlto(65.1) * 0.007 * (0.5 - 0.5 * cos(millis() / 3400.0 * TWO_PI));
}

float papelCelda() {
    return pcAncho(44.1) / PAPEL_ANCHO;
}

// La opcion que esta bajo el mouse, o -1.
int opcionEnMenu(float mx, float my) {
    float celda = papelCelda();
    for (int i = 0; i < OPCIONES_MENU.length; i++) {
        float x = papelX() + 28 * celda;
        float y = papelY() + (104 + i * 28) * celda;
        if (mx >= x && mx <= x + OPCION_ANCHO * celda && my >= y && my <= y + OPCION_ALTO * celda) {
            return i;
        }
    }
    return -1;
}

// El menu completo en su posicion (dy corre todo hacia abajo durante el
// paseo de la camara; "cerrar" lo achica y oscurece un poco).
void dibujarMenu(float dy, float cerrar) {
    pushMatrix();
    translate(0, dy);
    // se achica alrededor de un punto un poco arriba del centro
    float cx = pcX(50);
    float cy = pcY(35);
    translate(cx, cy);
    scale(1 - 0.07 * cerrar);
    translate(-cx, -cy);
    image(imgCajon, camX, camY, camAncho, camAlto);
    float celda = papelCelda();
    float px = papelX();
    float py = papelY();
    image(papelMenu, px, py, PAPEL_ANCHO * celda, PAPEL_ALTO * celda);
    for (int i = 0; i < OPCIONES_MENU.length; i++) {
        boolean resaltada = i == opcionBajoMouse && !camaraBajando && !camaraSubiendo;
        PImage img = resaltada ? opcionResaltada[i] : opcionNormal[i];
        image(img, px + 28 * celda, py + (104 + i * 28) * celda, OPCION_ANCHO * celda, OPCION_ALTO * celda);
    }
    if (cerrar > 0) {
        noStroke();
        fill(0, 255 * 0.4 * cerrar);
        rect(camX - 2, camY - 2, camAncho + 4, camAlto + 4);
    }
    popMatrix();
}

void clicEnMenu() {
    if (camaraBajando || camaraSubiendo) {
        return;
    }
    if (opcionesAbiertas) {
        clicEnOpciones();
        return;
    }
    int i = opcionEnMenu(mouseX, mouseY);
    if (i == OPCION_SOLO) {
        camaraBajando = true;
        momentoCamara = millis();
    } else if (i == OPCION_MULTIJUGADOR) {
        abrirSala();
    } else if (i == OPCION_OPCIONES) {
        opcionesAbiertas = true;   // Opciones.pde
    } else if (i == OPCION_SALIR) {
        saliendo = true;
        momentoSalida = millis();
    }
}

// Volver al menu desde la oficina (clic en el cajon del escritorio).
void volverAlMenu() {
    // no se sube al menu si algo de la oficina está a medio camino (una
    // llamada, o la ida a un minijuego): desde el menu no se terminaría y
    // los clics quedarían bloqueados
    if (camaraBajando || camaraSubiendo || llamadaEnPantalla() || momentoAMision >= 0 || momentoAEvento >= 0) {
        return;
    }
    camaraSubiendo = true;
    momentoCamara = millis();
}

// Del menu a la oficina (y de vuelta) ahora es un parpadeo, como en el
// prototipo Oficina_1: los parpados se cierran a medias, se cierran del
// todo, la imagen cambia de golpe y se abren (la oficina llega un poco
// agrandada y se acomoda). Devuelve true mientras dura (y ya lo dibujo).
final int DURACION_PARPADEO = 875;
final int CAMBIO_PARPADEO = 260;      // cuando cambia la imagen (con los ojos cerrados)

// Que tan cerrados estan los parpados (0 abiertos, 1 cerrados) a los ms "t"
// (la misma curva del prototipo, a doble velocidad).
float cierreParpados(float t) {
    t *= 2;
    if (t < 120) {
        return 0.4 * facilEntradaSalidaCuad(t / 120);
    } else if (t < 210) {
        return 0.4 - 0.3 * facilEntradaSalidaCuad((t - 120) / 90);
    } else if (t < 480) {
        float u = constrain((t - 210) / 270, 0, 1);
        return 0.1 + 0.9 * u * u;
    } else if (t < 580) {
        return 1;
    }
    float u = constrain((t - 580) / 430, 0, 1);
    return 1 - (1 - pow(1 - u, 3));
}

float facilEntradaSalidaCuad(float x) {
    x = constrain(x, 0, 1);
    return x < 0.5 ? 2 * x * x : 1 - pow(-2 * x + 2, 2) / 2;
}

// Los dos parpados, oscuros, con el borde un poco curvo.
void dibujarParpados(float cierre) {
    if (cierre <= 0.001) {
        return;
    }
    float alto = camAlto * 0.53 * cierre;
    float curva = camAlto * 0.06;
    noStroke();
    fill(#0a0604);
    rect(camX - 2, camY - 2, camAncho + 4, alto + 2);
    ellipse(camX + camAncho / 2, camY + alto, camAncho * 1.15, curva * 2 * cierre);
    rect(camX - 2, camY + camAlto - alto, camAncho + 4, alto + 2);
    ellipse(camX + camAncho / 2, camY + camAlto - alto, camAncho * 1.15, curva * 2 * cierre);
}

boolean dibujarPaseoCamara() {
    if (!camaraBajando && !camaraSubiendo) {
        return false;
    }
    float t = millis() - momentoCamara;
    float p = constrain(t / CAMBIO_PARPADEO, 0, 1);
    float n = 1 - pow(1 - constrain((t - CAMBIO_PARPADEO) / 500.0, 0, 1), 5);
    boolean cambio = t >= CAMBIO_PARPADEO;
    background(0);
    // la oficina se ve si ya cambio yendo al juego, o si todavia no cambio volviendo al menu
    boolean veOficina = camaraBajando == cambio;
    if (veOficina) {
        float esc = cambio ? 1 + 0.18 * (1 - n) : 1 + 0.18 * facilEntradaSalidaCuad(p);
        pushMatrix();
        float cx = pcX(50);
        float cy = pcY(95.3);
        translate(cx, cy);
        scale(esc);
        translate(-cx, -cy);
        dibujarOficinaConTV();   // la oficina con la TV encendida
        popMatrix();
    } else {
        // el menu: al irse baja un poquito y se oscurece; al volver llega y se acomoda
        float dy = cambio ? 0.05 * camAlto * (1 - n) : 0.015 * camAlto * p;
        dibujarMenu(dy, camaraBajando ? 0.6 * p : 0);
    }
    dibujarParpados(cierreParpados(t));
    if (t >= DURACION_PARPADEO) {
        if (camaraBajando) {
            camaraBajando = false;
            enMenu = false;
            mostrarPortada = false;
            if (!campanaEmpezada) {
                campanaEmpezada = true;
                cerrarPortada();
            } else if (bienvenidaPendiente && momentoProgramadoBienvenida < 0 && !videollamadaActiva) {
                programarBienvenida();   // una campaña nueva (por ejemplo en red) también la muestra
            }
        } else {
            camaraSubiendo = false;
            enMenu = true;
            mostrarPortada = true;   // mientras se ve el menu, el telefono espera
        }
    }
    return true;
}

void pantallaCajon() {
    background(0);
    opcionBajoMouse = opcionesAbiertas ? -1 : opcionEnMenu(mouseX, mouseY);
    if (opcionBajoMouse >= 0) {
        pedirCursorMano();
    }
    dibujarMenu(0, 0);
    if (opcionesAbiertas) {
        dibujarOpciones();
    }
    if (avisoActivo()) {
        dibujarAviso();
    }
    dibujarSalida();   // SALIR del menú: se oscurece y se cierra el juego (Interfaz.pde)
}

// ===========================================================================
// 4. ENCIMA DE LA OFICINA
// ===========================================================================
// Todo en el lienzo de la oficina (1200 x 670, el dibujo entero).

// El turno en la hojita del calendario "WK" (se tapa el 1 del dibujo).
void dibujarTurnoCalendario() {
    noStroke();
    fill(#e9e5dc);
    rect(940, 243, 37, 24);
    textoPixel(str(turnoVisible()), 958.5, 255, 2.6, 1, #3a3632, 0, 0, 0, true, CENTER, CENTER);
}

// La franja de "ultima hora" que corre en la parte de abajo del televisor.
PImage imgFranjaTV;
String textoFranjaTV = "";

String textoTitulares() {
    String t = "";
    for (String titular : TITULARES_TV) {
        t += titular.toUpperCase() + "  ■  ";
    }
    String mision = titularMision != null ? titularMision.toUpperCase() + "  ■  " : "";
    if (titularEvento != null) {
        mision = titularEvento.toUpperCase() + "  ■  " + mision;
    }
    return "CIUDAD NOVA · TURNO " + turnoVisible() + " DE " + Partida.TURNOS_TOTALES + "  ■  " + textoSondeo() + mision + t;
}

// Imagen larga con los titulares dos veces seguidas, para que al correr no
// se note donde empieza de nuevo.
PImage franjaTitulares() {
    String texto = textoTitulares();
    if (imgFranjaTV == null || !texto.equals(textoFranjaTV)) {
        textoFranjaTV = texto;
        PImage una = imagenTextoPixel(texto, 1, #ffffff, #4a0606, 0, 0, false);
        imgFranjaTV = createImage(una.width * 2, una.height, ARGB);
        imgFranjaTV.copy(una, 0, 0, una.width, una.height, 0, 0, una.width, una.height);
        imgFranjaTV.copy(una, 0, 0, una.width, una.height, una.width, 0, una.width, una.height);
    }
    return imgFranjaTV;
}

// Dibuja la franja corriendo dentro de un rectangulo (x, y, ancho, alto):
// se recorta de la imagen larga el pedazo que toca ver.
void dibujarFranjaTitulares(float x, float y, float ancho, float alto, float celdasPorSegundo, boolean conFondo) {
    PImage franja = franjaTitulares();
    int vuelta = franja.width / 2;
    float celda = alto / franja.height;
    int ventana = min(vuelta, ceil(ancho / celda));
    int inicio = (int) ((millis() / 1000.0 * celdasPorSegundo) % vuelta);
    if (conFondo) {
        noStroke();
        fill(#c21d1d);
        rect(x, y, ancho, alto);
    }
    image(franja.get(inicio, 0, ventana, franja.height), x, y, ventana * celda, alto);
}

// La TV de la oficina está siempre encendida con el noticiero en pequeño
// (Televisor.pde): el presentador, los reels, el mapa, la gráfica de los
// candidatos y la del impacto de lo último que se publicó.
// La oficina entera en la cámara, con el noticiero pequeño en la TV (para
// el zoom al televisor, la placa oscura del celular y el libro, y al bajar
// del menú: la TV no se ve apagada en ningún momento)
void dibujarOficinaConTV() {
    image(imgOficina, camX, camY, camAncho, camAlto);
    pushMatrix();
    translate(camX, camY);
    scale(camAncho / ANCHO_ESCENA);
    dibujarTelevisorOficina();
    popMatrix();
}

void dibujarTelevisorOficina() {
    if (imgNoticieroTV == null) {
        dibujarFranjaTitulares(722, 170, 299, 17, 18, true);
        return;
    }
    dibujarNoticieroOficina(TV_OFICINA_X, TV_OFICINA_Y, TV_OFICINA_ANCHO, TV_OFICINA_ALTO);
}

// Mientras suena, el telefono tiembla sobre el escritorio: se vuelve a
// pegar su recorte un poco corrido y girado.
void dibujarTelefonoVibrando() {
    if (faseLlamada != LLAMADA_SONANDO || !timbreSonandoAhora()) {
        return;
    }
    // la oficina sin el teléfono y encima solo el teléfono, temblando
    image(imgOficinaSinTelefono, 0, 0, ANCHO_ESCENA, ALTO_ESCENA);
    dibujarTurnoCalendario();
    dibujarTelevisorOficina();
    float[] v = vibracionTelefono();
    float k = ANCHO_ESCENA / ANCHO_DIBUJO;
    float ancho = imgTelefonoBase.width * k;
    float alto = imgTelefonoBase.height * k;
    float x = CAPAS_MESA[CAPA_TELEFONO][0] * k;
    float y = CAPAS_MESA[CAPA_TELEFONO][1] * k;
    pushMatrix();
    translate(x + ancho / 2 + v[0], y + alto * 0.85 - v[2] * 0.4);
    rotate(v[1]);
    image(imgTelefonoBase, -ancho / 2, -alto * 0.85, ancho, alto);
    popMatrix();
}

// Con el mouse encima, el objeto se aclara un poco (como en el prototipo).
void dibujarResalteObjeto(ObjetoOficina o) {
    if (o == null) {
        return;
    }
    noStroke();
    fill(255, 255, 255, 23);
    rect(o.x, o.y, o.ancho, o.alto, min(o.ancho, o.alto) * 0.12);
}

// ===========================================================================
// 5. ABRIR UN OBJETO
// ===========================================================================
// Al abrir el telefono, el celular o el libro, la oficina cambia por su
// version oscura (sin ese objeto) y el objeto sube desde abajo de la
// pantalla; despues se queda balanceandose un poquito.

final int DURACION_APARECER = 750;
final int DURACION_FUNDIDO_PLACA = 300;
int momentoApertura = -100000;

void marcarApertura() {
    momentoApertura = millis();
}

// 0 al empezar a abrir, 1 cuando ya llego (con la curva de subida).
float aparicion(int retraso) {
    return facilSalida((millis() - momentoApertura - retraso) / (float) DURACION_APARECER);
}

// La oficina oscura de fondo, que aparece fundiendose sobre la normal.
void dibujarPlaca(PImage placa) {
    background(0);
    float t = constrain((millis() - momentoApertura) / (float) DURACION_FUNDIDO_PLACA, 0, 1);
    dibujarOficinaConTV();   // la oficina con la TV encendida
    tint(255, 255 * t);
    image(placa, camX, camY, camAncho, camAlto);
    noTint();
}

// El vaiven de un objeto: un corrimiento y un giro pequenos y lentos.
// Devuelve {dx, dy, giro} en fracciones del tamano del objeto.
float[] vaiven(float periodo, float desfase) {
    float t = (millis() / 1000.0 + desfase) / periodo * TWO_PI;
    return new float[] {-0.0028 * sin(t), -0.0057 * (1 - cos(t)) * 0.5 - 0.0023 * sin(2 * t), radians(0.5) * sin(t)};
}

// Dibuja un objeto en su rectangulo (en porcentajes de la camara),
// subiendo desde abajo segun "llegada" (0 a 1) y balanceandose.
// "fuera" es cuanto mas abajo empieza, en porcentaje de su propio alto.
void dibujarObjetoSubiendo(PImage img, float izq, float arriba, float ancho, float alto, float fuera,
                           float llegada, float periodo, float desfase) {
    float x = pcX(izq);
    float y = pcY(arriba);
    float w = pcAncho(ancho);
    float h = pcAlto(alto);
    float[] v = vaiven(periodo, desfase);
    float dy = (1 - llegada) * h * fuera / 100;
    pushMatrix();
    translate(x + w / 2 + v[0] * w, y + h / 2 + v[1] * h + dy);
    image(img, -w / 2, -h / 2, w, h);
    popMatrix();
}

// Esquina superior izquierda de un objeto ya subido, con su vaiven, para
// dibujar cosas encima que se muevan con el (devuelve {x, y, w, h}).
float[] cajaObjeto(float izq, float arriba, float ancho, float alto, float fuera, float llegada, float periodo, float desfase) {
    float w = pcAncho(ancho);
    float h = pcAlto(alto);
    float[] v = vaiven(periodo, desfase);
    float dy = (1 - llegada) * h * fuera / 100;
    return new float[] {pcX(izq) + v[0] * w, pcY(arriba) + v[1] * h + dy, w, h};
}

// --- Cerrar: el objeto baja de vuelta y la oficina se aclara ---

final int DURACION_CERRAR = 650;
int objetoCerrando = -1;   // la pantalla que se cerro (CELULAR, ARBOL o AYUDA), o -1
int momentoCierre;

void marcarCierre(int desde) {
    if (desde == CELULAR || desde == ARBOL || desde == AYUDA) {
        objetoCerrando = desde;
        momentoCierre = millis();
    }
}

// Se dibuja encima de la oficina (en pixeles de pantalla) mientras dura.
void dibujarCierreObjeto() {
    if (objetoCerrando < 0) {
        return;
    }
    float t = (millis() - momentoCierre) / (float) DURACION_CERRAR;
    if (t >= 1) {
        objetoCerrando = -1;
        return;
    }
    float llegada = 1 - facilEntradaSalida(t);
    float placa = 1 - constrain((millis() - momentoCierre - 200) / 300.0, 0, 1);
    PImage fondo = objetoCerrando == CELULAR ? imgSinCelular : (objetoCerrando == ARBOL ? imgSinLibro : null);
    if (fondo != null) {
        tint(255, 255 * placa);
        image(fondo, camX, camY, camAncho, camAlto);
        noTint();
    } else {
        noStroke();
        fill(COLOR_VELO, alpha(COLOR_VELO) * placa);
        rect(0, 0, width, height);
    }
    if (objetoCerrando == CELULAR) {
        dibujarObjetoSubiendo(imgCelular, 10.413, 12.514, 25.321, 84.207, 109.894, llegada, 1.8, -1.1);
        dibujarObjetoSubiendo(imgMapaCiudad, MAPA_IZQ, MAPA_ARRIBA, MAPA_ANCHO, MAPA_ALTO, 115.848, llegada, 2.0, -0.7);
    } else if (objetoCerrando == ARBOL) {
        dibujarObjetoSubiendo(imgLibroHabilidades, LIBRO_IZQ, LIBRO_ARRIBA, LIBRO_ANCHO, LIBRO_ALTO, 108.9, llegada, 1.8, -1.1);
    }
}

// --- El televisor: la camara se acerca hasta que la pantalla llena todo ---

final int DURACION_ZOOM_TV = 1500;
final int DURACION_ALEJAR_TV = 1100;
float zoomTV = 0;          // 0 en la oficina, 1 con el noticiero en grande
float zoomTVDesde = 0;
float zoomTVHasta = 0;
int momentoZoomTV;
int duracionZoomTV = DURACION_ZOOM_TV;

void acercarTV() {
    zoomTVDesde = zoomTV;
    zoomTVHasta = 1;
    momentoZoomTV = millis();
    duracionZoomTV = DURACION_ZOOM_TV;
}

void alejarTV() {
    zoomTVDesde = zoomTV;
    zoomTVHasta = 0;
    momentoZoomTV = millis();
    duracionZoomTV = DURACION_ALEJAR_TV;
}

void actualizarZoomTV() {
    float u = constrain((millis() - momentoZoomTV) / (float) duracionZoomTV, 0, 1);
    float k = 0.5 - 0.5 * cos(PI * u);
    zoomTV = lerp(zoomTVDesde, zoomTVHasta, k);
}

// La oficina vista con el zoom "e" (0 a 1): crece hacia el televisor con un
// pequeno balanceo, y al final aparece encima la pantalla del noticiero.
void dibujarZoomTV(float e) {
    background(0);
    float escalaZoom = exp(log(1 / 0.288) * e);
    float giro = radians(-0.55 * sin(PI * e));
    float ox = pcX(72.8);
    float oy = pcY(16.7);
    pushMatrix();
    translate(ox, oy);
    translate(-0.228 * e * camAncho, 0.333 * e * camAlto);
    rotate(giro);
    scale(escalaZoom);
    translate(-ox, -oy);
    dibujarOficinaConTV();   // la oficina con la TV encendida
    popMatrix();
    float visible = constrain((e - 0.5) / 0.42, 0, 1);
    visible = visible * visible * (3 - 2 * visible);
    if (visible > 0) {
        dibujarNoticiero(visible);   // Televisor.pde
    }
}
