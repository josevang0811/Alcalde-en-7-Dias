// El mapa de la sede se lee de data/mapa/: tres capas en CSV (las mismas que
// exporta Tiled) y un archivo de texto con vigilantes, camaras, ductos y
// tableros electricos.
//   terreno.csv  1 pared, 2 piso, 3 puerta, 4 roja, 5 azul, 6 amarilla, 7 con codigo
//   zonas.csv    16 + numero de zona (ver NOMBRES_ZONA)
//   objetos.csv  muebles y cosas que se recogen (ver CODIGOS_OBJETO), -1 nada
// Por dentro cada baldosa se guarda como una letra, que es mas facil de leer:
//   #  pared       .  piso       D  puerta abierta
//   1  puerta roja 2 azul  3 amarilla  4 con codigo (cerradas)
//   A armario  M escritorio  S servidor  L farol  P prueba  E camioneta
//   T tablero electrico  r b y tarjetas  n nota con el codigo  o botella
//   C carro  p planta  I impresora  V camara de estudio  Q consola
//   O escritorio del rival  W TV del rival  X tablero de conspiracion
//   U cuaderno del rival  H sofa  Z casillero  F cafetera  v rejilla
//   c caseta  z contenedor  G pantalla verde

final String[] NOMBRES_ZONA = {"Exterior", "Recepción", "Redacción de bulos", "Estudio de TV",
  "Seguridad", "Archivo", "Cuarto del servidor", "Oficina del rival", "Pasillo", "Aseo", "Descanso"};
final int ZONA_EXTERIOR = 0;
// letra de cada codigo de objetos.csv, desde el 32
final String CODIGOS_OBJETO = "AMSLPEjkTrbynCpIVQOWXUHZFvczoGhlm";
final String TERRENO = "?#.D1234";   // indice = codigo de terreno.csv
final String[] NOMBRES_TARJETA = {"", "roja", "azul", "amarilla", "código"};

class Mapa {
  int ancho, alto;
  char[][] celdas;
  int[][] zona;
  float[][] luz;          // luz de cada baldosa (0.5 apagado, 0.62 oscuro, 1 junto a un farol): cuenta para que te vean
  float[][] luzR, luzG, luzB;   // color de la luz de cada baldosa: solo para el dibujo
  int[][] adorno;         // en las paredes: 0 ladrillo, 1 tira de neon, 2 letrero del rival
  float[][] corte;        // 0 pared entera, 1 pared recortada porque tapa a un jugador
  boolean[] zonaApagada = new boolean[11];
  ArrayList<float[]> fuentesLuz = new ArrayList<float[]>();   // x, y, r, g, b, radio, fuerza, altura
  float[] inicioX = new float[2];
  float[] inicioY = new float[2];
  int servidorI = -1, servidorJ = -1;   // un servidor para marcarlo con la flechita
  ArrayList<int[]> lamparas = new ArrayList<int[]>();

  // Lo que viene en entidades.txt
  ArrayList<String[]> lineasVigilantes = new ArrayList<String[]>();
  ArrayList<String[]> lineasCiviles = new ArrayList<String[]>();
  ArrayList<float[]> datosCamaras = new ArrayList<float[]>();
  ArrayList<int[]> rejillas = new ArrayList<int[]>();      // x, y de cada rejilla
  ArrayList<int[]> ductos = new ArrayList<int[]>();        // indice de rejilla A, indice B, largo en baldosas
  ArrayList<int[]> tableros = new ArrayList<int[]>();      // x, y del tablero electrico
  ArrayList<int[]> zonasTablero = new ArrayList<int[]>();  // zonas que apaga cada tablero

  // Grafo de cuartos: cada zona es un vertice; cada puerta une las dos zonas
  // que separa. La arista guarda que tarjeta pide (0 ninguna).
  ArrayList<int[]> puertasGrafo = new ArrayList<int[]>();   // zona A, zona B, tarjeta, x, y

  Mapa(String carpeta) {
    String[] ter = loadStrings(carpeta + "/terreno.csv");
    String[] zon = loadStrings(carpeta + "/zonas.csv");
    String[] obj = loadStrings(carpeta + "/objetos.csv");
    alto = ter.length;
    ancho = split(ter[0], ',').length;
    celdas = new char[ancho][alto];
    zona = new int[ancho][alto];
    luz = new float[ancho][alto];
    luzR = new float[ancho][alto];
    luzG = new float[ancho][alto];
    luzB = new float[ancho][alto];
    adorno = new int[ancho][alto];
    corte = new float[ancho][alto];
    for (int j = 0; j < alto; j++) {
      String[] ft = split(trim(ter[j]), ',');
      String[] fz = split(trim(zon[j]), ',');
      String[] fo = split(trim(obj[j]), ',');
      for (int i = 0; i < ancho; i++) {
        char c = TERRENO.charAt(constrain(int(ft[i]), 0, TERRENO.length() - 1));
        if (c == '?') c = '#';
        zona[i][j] = constrain(int(fz[i]) - 16, 0, NOMBRES_ZONA.length - 1);
        int o = int(fo[i]);
        if (o >= 32 && o - 32 < CODIGOS_OBJETO.length()) {
          char letra = CODIGOS_OBJETO.charAt(o - 32);
          if (letra == 'j') {
            inicioX[0] = i + 0.5;
            inicioY[0] = j + 0.5;
          } else if (letra == 'k') {
            inicioX[1] = i + 0.5;
            inicioY[1] = j + 0.5;
          } else {
            c = letra;
          }
        }
        if (c == 'L') lamparas.add(new int[] {i, j});
        if (c == 'S' && servidorI < 0) {
          servidorI = i;
          servidorJ = j;
        }
        celdas[i][j] = c;
      }
    }
    leerEntidades(carpeta + "/entidades.txt");
    armarGrafoCuartos();
    elegirAdornos();
    calcularLuz();
  }

  void leerEntidades(String archivo) {
    for (String linea : loadStrings(archivo)) {
      linea = trim(linea);
      if (linea.length() == 0 || linea.charAt(0) == '#') continue;
      String[] p = splitTokens(linea, " ");
      if (p[0].equals("vigilante") || p[0].equals("jefe")) lineasVigilantes.add(p);
      if (p[0].equals("civil")) lineasCiviles.add(p);
      if (p[0].equals("camara")) datosCamaras.add(new float[] {float(p[1]), float(p[2]), radians(float(p[3])), radians(float(p[4]))});
      if (p[0].equals("ducto")) {
        int a = indiceRejilla(p[1]);
        int b = indiceRejilla(p[2]);
        int[] pa = rejillas.get(a);
        int[] pb = rejillas.get(b);
        ductos.add(new int[] {a, b, abs(pa[0] - pb[0]) + abs(pa[1] - pb[1])});
      }
      if (p[0].equals("tablero")) {
        String[] xy = split(p[1], ',');
        tableros.add(new int[] {int(xy[0]), int(xy[1])});
        int[] zs = new int[p.length - 2];
        for (int k = 2; k < p.length; k++) zs[k - 2] = int(p[k]);
        zonasTablero.add(zs);
      }
    }
  }

  // Devuelve el indice de la rejilla en "x,y" (la agrega si es nueva)
  int indiceRejilla(String xy) {
    String[] v = split(xy, ',');
    int x = int(v[0]);
    int y = int(v[1]);
    for (int k = 0; k < rejillas.size(); k++) {
      if (rejillas.get(k)[0] == x && rejillas.get(k)[1] == y) return k;
    }
    rejillas.add(new int[] {x, y});
    return rejillas.size() - 1;
  }

  char en(int i, int j) {
    if (i < 0 || j < 0 || i >= ancho || j >= alto) return '#';
    return celdas[i][j];
  }

  boolean esPared(int i, int j) {
    return en(i, j) == '#';
  }

  boolean esPuertaCerrada(int i, int j) {
    char c = en(i, j);
    return c >= '1' && c <= '4';
  }

  int zonaEn(float x, float y) {
    return zona[constrain(floor(x), 0, ancho - 1)][constrain(floor(y), 0, alto - 1)];
  }

  // Los jugadores no pasan por paredes, puertas cerradas ni muebles
  boolean esSolido(int i, int j) {
    char c = en(i, j);
    return c == '#' || esPuertaCerrada(i, j) || "AMSLCpIVQOWXUHZFczGm".indexOf(c) >= 0;
  }

  // Los vigilantes tienen todas las tarjetas: las puertas cerradas no los frenan
  boolean esSolidoVigilante(int i, int j) {
    if (esPuertaCerrada(i, j)) return false;
    return esSolido(i, j);
  }

  // Tapa la vista: paredes, puertas cerradas y muebles altos
  boolean bloqueaVista(int i, int j) {
    char c = en(i, j);
    return c == '#' || esPuertaCerrada(i, j) || "ASCcZG".indexOf(c) >= 0;
  }

  boolean chocaCaja(float cx, float cy, float r) {
    for (int i = floor(cx - r); i <= floor(cx + r); i++) {
      for (int j = floor(cy - r); j <= floor(cy + r); j++) {
        if (esSolido(i, j)) return true;
      }
    }
    return false;
  }

  boolean hayLinea(float x1, float y1, float x2, float y2) {
    int di = floor(x2);
    int dj = floor(y2);
    float d = dist(x1, y1, x2, y2);
    int pasos = ceil(d / 0.2);
    for (int k = 1; k < pasos; k++) {
      float t = k / (float) pasos;
      int i = floor(lerp(x1, x2, t));
      int j = floor(lerp(y1, y2, t));
      if (i == di && j == dj) continue;
      if (bloqueaVista(i, j)) return false;
    }
    return true;
  }

  // ---------------------------------------------------------------------
  // Grafo de cuartos (zonas unidas por puertas)
  // ---------------------------------------------------------------------

  void armarGrafoCuartos() {
    puertasGrafo.clear();
    for (int i = 1; i < ancho - 1; i++) {
      for (int j = 1; j < alto - 1; j++) {
        char c = celdas[i][j];
        if (c != 'D' && !esPuertaCerrada(i, j)) continue;
        int tarjeta = c == 'D' ? 0 : c - '0';
        int a, b;
        if (!esPared(i, j - 1) && !esPared(i, j + 1)) {
          a = zona[i][j - 1];
          b = zona[i][j + 1];
        } else {
          a = zona[i - 1][j];
          b = zona[i + 1][j];
        }
        puertasGrafo.add(new int[] {a, b, tarjeta, i, j});
      }
    }
  }

  // BFS sobre el grafo de cuartos: a que zonas se llega desde afuera con las
  // tarjetas que se tienen (tarjetas[k] = true si ya se tiene la tarjeta k).
  boolean[] zonasAlcanzables(boolean[] tarjetas) {
    boolean[] visitada = new boolean[NOMBRES_ZONA.length];
    ArrayList<Integer> cola = new ArrayList<Integer>();
    cola.add(ZONA_EXTERIOR);
    visitada[ZONA_EXTERIOR] = true;
    int frente = 0;
    while (frente < cola.size()) {
      int z = cola.get(frente);
      frente++;
      for (int[] p : puertasGrafo) {
        boolean abierta = p[2] == 0 || tarjetas[p[2]];
        if (!abierta) continue;
        int otra = -1;
        if (p[0] == z) otra = p[1];
        if (p[1] == z) otra = p[0];
        if (otra >= 0 && !visitada[otra]) {
          visitada[otra] = true;
          cola.add(otra);
        }
      }
    }
    return visitada;
  }

  // ---------------------------------------------------------------------
  // Adornos y luz
  // ---------------------------------------------------------------------

  // Letreros del rival en algunas paredes fijas y tiras de neon repartidas.
  // Solo se adornan paredes cuya cara izquierda da a un piso.
  void elegirAdornos() {
    int[][] letreros = {{14, 0}, {29, 0}, {20, 6}, {9, 14}, {35, 14}, {13, 21}, {24, 21}, {37, 6}};
    for (int i = 0; i < ancho; i++) {
      for (int j = 0; j < alto; j++) {
        adorno[i][j] = 0;
        if (!esPared(i, j) || j + 1 >= alto || esPared(i, j + 1) || esPuertaCerrada(i, j + 1)) continue;
        if ((i * 5 + j * 3) % 7 == 0) adorno[i][j] = 1;
      }
    }
    for (int[] p : letreros) {
      if (esPared(p[0], p[1])) adorno[p[0]][p[1]] = 2;
    }
  }

  // Luz fija: cada farol ilumina las baldosas a las que llega en linea recta.
  // Lo mas oscuro es 0.62 (0.5 si se cortaron las luces de esa zona) y junto
  // a un farol llega a 1. Esto es lo que usa el juego para saber que tan
  // facil es verte. Aparte se calcula el color de la luz (solo para el dibujo).
  void calcularLuz() {
    for (int i = 0; i < ancho; i++) {
      for (int j = 0; j < alto; j++) {
        luz[i][j] = zonaApagada[zona[i][j]] ? 0.5 : 0.62;
        for (int[] l : lamparas) {
          if (zonaApagada[zona[l[0]][l[1]]]) continue;
          float d = dist(l[0] + 0.5, l[1] + 0.5, i + 0.5, j + 0.5);
          if (d < 5 && hayLinea(l[0] + 0.5, l[1] + 0.5, i + 0.5, j + 0.5)) {
            luz[i][j] = max(luz[i][j], 1.0 - d / 5 * 0.38);
          }
        }
      }
    }

    fuentesLuz.clear();
    for (int i = 0; i < ancho; i++) {
      for (int j = 0; j < alto; j++) {
        char c = celdas[i][j];
        boolean apagada = zonaApagada[zona[i][j]];
        if (!apagada) {
          if (c == 'L') fuentesLuz.add(new float[] {i + 0.5, j + 0.5, 232, 52, 78, 4.5, 1.1, 26});
          if (c == 'M') fuentesLuz.add(new float[] {i + 0.5, j + 0.5, 25, 227, 227, 2.0, 0.5, 12});
          if (c == 'Q') fuentesLuz.add(new float[] {i + 0.5, j + 0.5, 25, 227, 227, 2.4, 0.6, 14});
          if (c == 'W') fuentesLuz.add(new float[] {i + 0.5, j + 0.5, 62, 84, 120, 2.6, 0.6, 18});
        }
        if (c == 'S') fuentesLuz.add(new float[] {i + 0.5, j + 0.5, 61, 220, 132, 2.0, 0.4, 18});
        if (c == 'E') fuentesLuz.add(new float[] {i + 0.5, j + 0.5, 61, 220, 132, 2.2, 0.6, 2});
        if (c == 'c') fuentesLuz.add(new float[] {i + 0.5, j + 0.5, 217, 130, 43, 2.5, 0.7, 14});
        if (c == '1') fuentesLuz.add(new float[] {i + 0.5, j + 0.5, 232, 52, 78, 1.4, 0.5, 14});
        if (c == '2') fuentesLuz.add(new float[] {i + 0.5, j + 0.5, 62, 123, 255, 1.4, 0.5, 14});
        if (c == '3') fuentesLuz.add(new float[] {i + 0.5, j + 0.5, 255, 181, 71, 1.4, 0.5, 14});
        if (c == '4') fuentesLuz.add(new float[] {i + 0.5, j + 0.5, 25, 227, 227, 1.4, 0.5, 14});
        if (c == '#' && adorno[i][j] == 2) fuentesLuz.add(new float[] {i + 0.5, j + 1.3, 255, 46, 136, 3.0, 0.8, 16});
        if (c == '#' && adorno[i][j] == 1) fuentesLuz.add(new float[] {i + 0.5, j + 1.2, 25, 227, 227, 1.8, 0.35, 24});
      }
    }
    for (int i = 0; i < ancho; i++) {
      for (int j = 0; j < alto; j++) {
        boolean apagada = zonaApagada[zona[i][j]];
        luzR[i][j] = apagada ? 0.4 : 0.66;
        luzG[i][j] = apagada ? 0.42 : 0.7;
        luzB[i][j] = apagada ? 0.7 : 1.0;
        for (float[] f : fuentesLuz) {
          if (abs(f[0] - i) > f[5] + 1 || abs(f[1] - j) > f[5] + 1) continue;
          float d = dist(f[0], f[1], i + 0.5, j + 0.5);
          if (d >= f[5] || !hayLinea(f[0], f[1], i + 0.5, j + 0.5)) continue;
          float fuerza = pow(1 - d / f[5], 1.6) * f[6];
          luzR[i][j] += fuerza * f[2] / 255;
          luzG[i][j] += fuerza * f[3] / 255;
          luzB[i][j] += fuerza * f[4] / 255;
        }
      }
    }
  }

  // Entre mas luz, mas rapido te descubren. En la sombra cuesta mas verte.
  float factorLuz(float x, float y) {
    float l = luz[constrain(floor(x), 0, ancho - 1)][constrain(floor(y), 0, alto - 1)];
    return map(l, 0.5, 1.0, 0.3, 1.0);
  }

  // Una pared (o mueble alto) se recorta si esta delante de un jugador y lo tapa.
  void actualizarCortes(ArrayList<Jugador> js, float dt) {
    float k = min(1, dt * 8);
    for (int i = 0; i < ancho; i++) {
      for (int j = 0; j < alto; j++) {
        if (!bloqueaVista(i, j)) continue;
        boolean tapa = false;
        for (Jugador jug : js) {
          float delante = (i + j + 1) - (jug.x + jug.y);
          float lado = abs((i - j) - (jug.x - jug.y));
          if (delante > 0.2 && delante < 5.5 && lado < 3.0) tapa = true;
        }
        float meta = tapa ? 1 : 0;
        corte[i][j] += (meta - corte[i][j]) * k;
      }
    }
  }

  // Busca la baldosa del tipo pedido mas cercana a (x, y), si esta a menos de "radio"
  int[] cercano(float x, float y, char tipo, float radio) {
    int[] mejor = null;
    float mejorD = radio;
    for (int i = max(0, floor(x) - 2); i <= min(ancho - 1, floor(x) + 2); i++) {
      for (int j = max(0, floor(y) - 2); j <= min(alto - 1, floor(y) + 2); j++) {
        if (celdas[i][j] != tipo) continue;
        float d = dist(x, y, i + 0.5, j + 0.5);
        if (d <= mejorD) {
          mejorD = d;
          mejor = new int[] {i, j};
        }
      }
    }
    return mejor;
  }

  // Puerta cerrada mas cercana (cualquier color)
  int[] puertaCercana(float x, float y, float radio) {
    int[] mejor = null;
    float mejorD = radio;
    for (int i = max(0, floor(x) - 2); i <= min(ancho - 1, floor(x) + 2); i++) {
      for (int j = max(0, floor(y) - 2); j <= min(alto - 1, floor(y) + 2); j++) {
        if (!esPuertaCerrada(i, j)) continue;
        float d = dist(x, y, i + 0.5, j + 0.5);
        if (d <= mejorD) {
          mejorD = d;
          mejor = new int[] {i, j};
        }
      }
    }
    return mejor;
  }

  // La seguridad cierra una puerta (con el tipo de tarjeta que pida)
  void cerrarPuerta(int i, int j, char tipo) {
    celdas[i][j] = tipo;
    armarGrafoCuartos();
    calcularLuz();
  }

  void abrirPuerta(int i, int j) {
    celdas[i][j] = 'D';
    armarGrafoCuartos();
    calcularLuz();
  }

  // ---------------------------------------------------------------------
  // BFS
  // ---------------------------------------------------------------------

  // Camino mas corto para un vigilante (BFS sobre la cuadricula: cada
  // baldosa libre es un vertice unido a sus 4 vecinas). Devuelve las
  // baldosas desde el origen hasta la meta.
  ArrayList<int[]> caminoBFS(int i0, int j0, int i1, int j1) {
    ArrayList<int[]> camino = new ArrayList<int[]>();
    if (esSolidoVigilante(i1, j1) || esSolidoVigilante(i0, j0)) return camino;
    int total = ancho * alto;
    int inicio = j0 * ancho + i0;
    int meta = j1 * ancho + i1;
    boolean[] visitado = new boolean[total];
    int[] anterior = new int[total];
    for (int k = 0; k < total; k++) anterior[k] = -1;
    ArrayList<Integer> cola = new ArrayList<Integer>();
    cola.add(inicio);
    visitado[inicio] = true;
    int frente = 0;   // en vez de borrar de la cola, se avanza este indice
    int[] di = {1, -1, 0, 0};
    int[] dj = {0, 0, 1, -1};
    while (frente < cola.size()) {
      int actual = cola.get(frente);
      frente++;
      if (actual == meta) break;
      int ci = actual % ancho;
      int cj = actual / ancho;
      for (int k = 0; k < 4; k++) {
        int ni = ci + di[k];
        int nj = cj + dj[k];
        if (esSolidoVigilante(ni, nj)) continue;
        int n = nj * ancho + ni;
        if (!visitado[n]) {
          visitado[n] = true;
          anterior[n] = actual;
          cola.add(n);
        }
      }
    }
    if (!visitado[meta]) return camino;
    int paso = meta;
    while (paso != -1) {
      camino.add(new int[] {paso % ancho, paso / ancho});
      paso = anterior[paso];
    }
    java.util.Collections.reverse(camino);   // se armó desde la meta hacia atrás
    return camino;
  }

  // ---------------------------------------------------------------------
  // Dijkstra de los civiles sobre la cuadricula. No todas las baldosas
  // cuestan lo mismo: cruzar una puerta cuesta 3 (hay que abrirla) y una
  // zona a oscuras tambien 3 (les da miedo). Por eso el camino mas corto no
  // siempre es el de menos baldosas y BFS no basta.
  // Igual que en clase: "dist" son los temporales, "fijo" marca los que ya
  // son definitivos y "anteriorCivil" guarda de donde se llego.
  // ---------------------------------------------------------------------
  int[] anteriorCivil;

  int costoCivil(int i, int j) {
    if (celdas[i][j] == 'D' || esPuertaCerrada(i, j)) return 3;
    if (zonaApagada[zona[i][j]]) return 3;
    return 1;
  }

  int[] dijkstraCivil(int i0, int j0) {
    int total = ancho * alto;
    int[] dist = new int[total];
    boolean[] fijo = new boolean[total];
    anteriorCivil = new int[total];
    for (int k = 0; k < total; k++) {
      dist[k] = Integer.MAX_VALUE;
      anteriorCivil[k] = -1;
    }
    dist[j0 * ancho + i0] = 0;
    int[] di = {1, -1, 0, 0};
    int[] dj = {0, 0, 1, -1};
    for (int vuelta = 0; vuelta < total; vuelta++) {
      // se fija la baldosa con el menor temporal
      int u = -1;
      for (int k = 0; k < total; k++) {
        if (!fijo[k] && dist[k] != Integer.MAX_VALUE && (u == -1 || dist[k] < dist[u])) u = k;
      }
      if (u == -1) break;
      fijo[u] = true;
      // y se relajan sus vecinas
      int ui = u % ancho;
      int uj = u / ancho;
      for (int k = 0; k < 4; k++) {
        int ni = ui + di[k];
        int nj = uj + dj[k];
        if (esSolidoVigilante(ni, nj)) continue;
        int n = nj * ancho + ni;
        int nueva = dist[u] + costoCivil(ni, nj);
        if (!fijo[n] && nueva < dist[n]) {
          dist[n] = nueva;
          anteriorCivil[n] = u;
        }
      }
    }
    return dist;
  }

  // Camino desde el origen del ultimo Dijkstra hasta (i, j), leyendo
  // "anteriorCivil" hacia atras
  ArrayList<int[]> caminoCivil(int i, int j) {
    ArrayList<int[]> camino = new ArrayList<int[]>();
    int paso = j * ancho + i;
    if (anteriorCivil == null || (anteriorCivil[paso] == -1)) return camino;
    while (paso != -1) {
      camino.add(new int[] {paso % ancho, paso / ancho});
      paso = anteriorCivil[paso];
    }
    java.util.Collections.reverse(camino);
    return camino;
  }

  // Ruido por BFS: el sonido avanza por los pasillos y las puertas abiertas,
  // no atraviesa paredes. Devuelve cuantos pasos hay desde (x, y) hasta cada
  // baldosa, hasta "maxPasos" (las que no alcanza quedan en -1).
  int[][] pasosRuido(float x, float y, int maxPasos) {
    int[][] pasos = new int[ancho][alto];
    for (int i = 0; i < ancho; i++) {
      for (int j = 0; j < alto; j++) pasos[i][j] = -1;
    }
    int i0 = constrain(floor(x), 0, ancho - 1);
    int j0 = constrain(floor(y), 0, alto - 1);
    ArrayList<int[]> cola = new ArrayList<int[]>();
    cola.add(new int[] {i0, j0});
    pasos[i0][j0] = 0;
    int frente = 0;
    int[] di = {1, -1, 0, 0};
    int[] dj = {0, 0, 1, -1};
    while (frente < cola.size()) {
      int[] a = cola.get(frente);
      frente++;
      if (pasos[a[0]][a[1]] >= maxPasos) continue;
      for (int k = 0; k < 4; k++) {
        int ni = a[0] + di[k];
        int nj = a[1] + dj[k];
        if (ni < 0 || nj < 0 || ni >= ancho || nj >= alto) continue;
        if (esPared(ni, nj) || esPuertaCerrada(ni, nj) || pasos[ni][nj] >= 0) continue;
        pasos[ni][nj] = pasos[a[0]][a[1]] + 1;
        cola.add(new int[] {ni, nj});
      }
    }
    return pasos;
  }

  // ---------------------------------------------------------------------
  // Ductos: grafo de rejillas con Dijkstra (el peso es el largo del ducto)
  // ---------------------------------------------------------------------

  // Minutos (aqui: baldosas) desde la rejilla "origen" hasta cada rejilla
  int[] distanciasDucto(int origen) {
    int n = rejillas.size();
    int[] dist = new int[n];
    boolean[] fijo = new boolean[n];
    for (int k = 0; k < n; k++) dist[k] = Integer.MAX_VALUE;
    dist[origen] = 0;
    for (int vuelta = 0; vuelta < n; vuelta++) {
      // se fija la rejilla de menor distancia temporal
      int u = -1;
      for (int k = 0; k < n; k++) {
        if (!fijo[k] && dist[k] != Integer.MAX_VALUE && (u == -1 || dist[k] < dist[u])) u = k;
      }
      if (u == -1) break;
      fijo[u] = true;
      // y se relajan sus ductos
      for (int[] d : ductos) {
        int otra = -1;
        if (d[0] == u) otra = d[1];
        if (d[1] == u) otra = d[0];
        if (otra >= 0 && !fijo[otra] && dist[u] + d[2] < dist[otra]) dist[otra] = dist[u] + d[2];
      }
    }
    return dist;
  }

  int rejillaEn(int i, int j) {
    for (int k = 0; k < rejillas.size(); k++) {
      if (rejillas.get(k)[0] == i && rejillas.get(k)[1] == j) return k;
    }
    return -1;
  }
}
