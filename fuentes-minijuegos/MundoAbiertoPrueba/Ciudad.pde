// La ciudad: piso en trozos, objetos con su orden de dibujo, choques, zonas
// y las rutas (BFS) para los candidatos que maneja el computador.
//
// Coordenadas: el mundo se mide en baldosas (x, y). En pantalla una baldosa
// es un rombo de 32x16 pixeles del dibujo: ir hacia +x baja a la derecha e ir
// hacia +y baja a la izquierda.

float OX, OY;               // dónde cae la baldosa (0, 0) en el dibujo
int T = 16;                 // unidades del generador por baldosa
int CEL = 4;                // la cuadrícula de choques mide 4x4 unidades
int TROZO = 512;
int anchoMundo, altoMundo;  // tamaño del dibujo completo, en pixeles
int baldosasX, baldosasY;
float inicioX, inicioY;
float centroX, centroY, radioPlaza;
float arenaX0, arenaY0, arenaX1, arenaY1;
boolean arenaCerrada = false;   // durante la ronda nadie sale del parque y sus calles

PImage[][] trozos;
ArrayList<Objeto> objetos = new ArrayList<Objeto>();
boolean[][] choque;         // [i][j] = celda de 4x4 unidades bloqueada
boolean[][] paso;           // celda por donde cabe una persona (para las rutas)
int celdasX, celdasY;
int[][] zona;               // [i][j] por baldosa
String[] nombresZona;
PImage minimapa;

// Un objeto quieto de la ciudad: su dibujo, dónde va y su huella en el piso
// (la caja que ocupa, en unidades), que sirve para saber si alguien está
// delante o detrás de él. Si es una cartelera, punto dice cuál.
class Objeto {
  PImage img;
  int x0, y0;
  float prof;
  float hx, hy, hw, hd;     // huella; hw < 0 si es un punto
  int punto;
  int semaforo = -1;        // si es un semáforo, cuál (para prender su luz)

  Objeto(PImage img, int x0, int y0, float prof, float hx, float hy, float hw, float hd, int punto) {
    this.img = img;
    this.x0 = x0;
    this.y0 = y0;
    this.prof = prof;
    this.hx = hx;
    this.hy = hy;
    this.hw = hw;
    this.hd = hd;
    this.punto = punto;
  }

  // ¿El punto (ux, uy) en unidades queda detrás de este objeto?
  // Detrás de una caja es estar antes de su borde de abajo en x y en y.
  boolean tapa(float ux, float uy) {
    if (hw < 0) return ux + uy < prof;
    return ux < hx + hw && uy < hy + hd;
  }

  boolean seCruza(float x1, float y1, float x2, float y2) {
    return x0 < x2 && x0 + img.width > x1 && y0 < y2 && y0 + img.height > y1;
  }
}

void cargarMundo() {
  HashMap<String, String> info = new HashMap<String, String>();
  for (String l : loadStrings("mundo/mundo.txt")) {
    String[] p = split(trim(l), '=');
    if (p.length == 2) info.put(p[0], p[1]);
  }
  OX = float(info.get("OX"));
  OY = float(info.get("OY"));
  T = int(info.get("T"));
  CEL = int(info.get("CEL"));
  TROZO = int(info.get("TROZO"));
  anchoMundo = int(info.get("ANCHO"));
  altoMundo = int(info.get("ALTO"));
  baldosasX = int(info.get("BALDOSAS_X"));
  baldosasY = int(info.get("BALDOSAS_Y"));
  inicioX = float(info.get("INICIO_X"));
  inicioY = float(info.get("INICIO_Y"));
  centroX = float(info.get("CENTRO_X"));
  centroY = float(info.get("CENTRO_Y"));
  radioPlaza = float(info.get("RADIO_PLAZA"));
  arenaX0 = float(info.get("ARENA_X0"));
  arenaY0 = float(info.get("ARENA_Y0"));
  arenaX1 = float(info.get("ARENA_X1"));
  arenaY1 = float(info.get("ARENA_Y1"));

  // Piso
  int tx = ceil(anchoMundo / (float) TROZO);
  int ty = ceil(altoMundo / (float) TROZO);
  trozos = new PImage[tx][ty];
  for (int i = 0; i < tx; i++) {
    for (int j = 0; j < ty; j++) {
      trozos[i][j] = loadImage("mundo/piso_" + i + "_" + j + ".png");
    }
  }

  // Objetos (ya vienen en orden de dibujo). Los dibujos repetidos se cargan una vez.
  HashMap<String, PImage> dibujos = new HashMap<String, PImage>();
  for (String l : loadStrings("mundo/objetos.txt")) {
    String[] p = splitTokens(l);
    if (p.length < 9) continue;
    PImage img = dibujos.get(p[0]);
    if (img == null) {
      img = loadImage("mundo/" + p[0]);
      dibujos.put(p[0], img);
    }
    Objeto o = new Objeto(img, int(p[1]), int(p[2]), float(p[3]),
      float(p[4]), float(p[5]), float(p[6]), float(p[7]), int(p[8]));
    if (p.length >= 10) o.semaforo = int(p[9]);
    objetos.add(o);
  }

  // Choques: blanco = no se pasa
  PImage c = loadImage("mundo/choques.png");
  c.loadPixels();
  celdasX = c.width;
  celdasY = c.height;
  choque = new boolean[celdasX][celdasY];
  for (int j = 0; j < celdasY; j++) {
    for (int i = 0; i < celdasX; i++) {
      choque[i][j] = (c.pixels[j * celdasX + i] & 0xFF) > 127;
    }
  }
  // Para las rutas: una celda sirve si ella y sus ocho vecinas están libres
  // (así la persona, que es más ancha que una celda, no se queda pegada).
  paso = new boolean[celdasX][celdasY];
  for (int i = 1; i < celdasX - 1; i++) {
    for (int j = 1; j < celdasY - 1; j++) {
      boolean ok = true;
      for (int a = -1; a <= 1 && ok; a++) {
        for (int b = -1; b <= 1 && ok; b++) {
          if (choque[i + a][j + b]) ok = false;
        }
      }
      paso[i][j] = ok;
    }
  }

  // Zonas: el valor de cada pixel es el número de la zona
  PImage z = loadImage("mundo/zonas.png");
  z.loadPixels();
  zona = new int[z.width][z.height];
  for (int j = 0; j < z.height; j++) {
    for (int i = 0; i < z.width; i++) {
      zona[i][j] = z.pixels[j * z.width + i] & 0xFF;
    }
  }
  nombresZona = loadStrings("mundo/zonas.txt");
  minimapa = loadImage("mundo/minimapa.png");
}

float pantallaX(float x, float y) {
  return OX + (x - y) * T;
}

float pantallaY(float x, float y) {
  return OY + (x + y) * T / 2.0;
}

boolean enArena(float x, float y) {
  return x >= arenaX0 && x <= arenaX1 && y >= arenaY0 && y <= arenaY1;
}

// ¿Se puede estar en (x, y)? Revisa las celdas que toca un círculo de radio r.
boolean libre(float x, float y, float r) {
  if (arenaCerrada && !enArena(x, y)) return false;
  float ux = x * T, uy = y * T, ru = r * T;
  int i0 = floor((ux - ru) / CEL), i1 = floor((ux + ru) / CEL);
  int j0 = floor((uy - ru) / CEL), j1 = floor((uy + ru) / CEL);
  for (int i = i0; i <= i1; i++) {
    for (int j = j0; j <= j1; j++) {
      if (i < 0 || j < 0 || i >= celdasX || j >= celdasY) return false;
      if (choque[i][j]) return false;
    }
  }
  return true;
}

int zonaEn(float x, float y) {
  int i = constrain(floor(x), 0, zona.length - 1);
  int j = constrain(floor(y), 0, zona[0].length - 1);
  return zona[i][j];
}

// ---------------------------------------------------------------------------
// Rutas: BFS sobre la cuadrícula de celdas (un cuarto de baldosa)
// ---------------------------------------------------------------------------

int celdaDe(float baldosas) {
  return floor(baldosas * T / CEL);
}

float baldosaDe(int celda) {
  return (celda + 0.5) * CEL / (float) T;
}

boolean celdaUsable(int i, int j) {
  if (i < 0 || j < 0 || i >= celdasX || j >= celdasY || !paso[i][j]) return false;
  if (arenaCerrada && !enArena(baldosaDe(i), baldosaDe(j))) return false;
  return true;
}

// La celda usable más cercana a (x, y), buscando en anillos cada vez más grandes
PVector puntoLibreCerca(float x, float y) {
  int ci = celdaDe(x), cj = celdaDe(y);
  for (int r = 0; r < 40; r++) {
    for (int a = -r; a <= r; a++) {
      for (int b = -r; b <= r; b++) {
        if (max(abs(a), abs(b)) != r) continue;
        if (celdaUsable(ci + a, cj + b)) return new PVector(baldosaDe(ci + a), baldosaDe(cj + b));
      }
    }
  }
  return new PVector(x, y);
}

// Camino más corto (en pasos de celda) de (x0, y0) a (x1, y1). Devuelve la
// lista de puntos a seguir, ya simplificada, o null si no hay camino.
// BFS con una cola: se visita por anillos de distancia desde el inicio, y cada
// celda guarda de dónde se llegó para reconstruir el camino al final.
int[] vieneDe;
ArrayList<PVector> rutaBFS(float x0, float y0, float x1, float y1) {
  if (vieneDe == null) vieneDe = new int[celdasX * celdasY];
  java.util.Arrays.fill(vieneDe, -1);
  PVector a = puntoLibreCerca(x0, y0);
  PVector b = puntoLibreCerca(x1, y1);
  int si = celdaDe(a.x), sj = celdaDe(a.y);
  int ti = celdaDe(b.x), tj = celdaDe(b.y);
  int inicio = si * celdasY + sj, meta = ti * celdasY + tj;
  java.util.ArrayDeque<Integer> cola = new java.util.ArrayDeque<Integer>();
  cola.add(inicio);
  vieneDe[inicio] = inicio;
  int[] di = {1, -1, 0, 0, 1, 1, -1, -1};
  int[] dj = {0, 0, 1, -1, 1, -1, 1, -1};
  boolean llego = false;
  while (!cola.isEmpty()) {
    int c = cola.poll();
    if (c == meta) {
      llego = true;
      break;
    }
    int ci = c / celdasY, cj = c % celdasY;
    for (int k = 0; k < 8; k++) {
      int ni = ci + di[k], nj = cj + dj[k];
      if (!celdaUsable(ni, nj)) continue;
      // en diagonal solo si las dos celdas de al lado también sirven
      if (k >= 4 && (!celdaUsable(ci + di[k], cj) || !celdaUsable(ci, cj + dj[k]))) continue;
      int n = ni * celdasY + nj;
      if (vieneDe[n] != -1) continue;
      vieneDe[n] = c;
      cola.add(n);
    }
  }
  if (!llego) return null;
  ArrayList<PVector> celdas = new ArrayList<PVector>();
  int c = meta;
  while (c != inicio) {
    celdas.add(new PVector(baldosaDe(c / celdasY), baldosaDe(c % celdasY)));
    c = vieneDe[c];
  }
  java.util.Collections.reverse(celdas);   // se armó desde la meta hacia atrás
  celdas.add(new PVector(b.x, b.y));
  // simplificar: de cada punto se salta al más lejano que se vea en línea recta
  ArrayList<PVector> ruta = new ArrayList<PVector>();
  PVector actual = new PVector(a.x, a.y);
  int k = 0;
  while (k < celdas.size()) {
    int mejor = k;
    for (int m = min(celdas.size() - 1, k + 24); m > k; m--) {
      if (lineaLibre(actual.x, actual.y, celdas.get(m).x, celdas.get(m).y)) {
        mejor = m;
        break;
      }
    }
    actual = celdas.get(mejor);
    ruta.add(actual);
    k = mejor + 1;
  }
  return ruta;
}

boolean lineaLibre(float x0, float y0, float x1, float y1) {
  float d = dist(x0, y0, x1, y1);
  int n = max(1, ceil(d / 0.12));
  for (int k = 0; k <= n; k++) {
    float t = k / (float) n;
    if (!libre(lerp(x0, x1, t), lerp(y0, y1, t), RADIO_PERSONA)) return false;
  }
  return true;
}

// ---------------------------------------------------------------------------
// Dibujo
// ---------------------------------------------------------------------------

// Lo que se mueve (candidatos, botellas) se mete entre los objetos quietos:
// cada uno va antes del primer objeto que lo tapa y se le cruza en pantalla.
// (Es una clase abstracta y no una interfaz para que el sketch se pueda meter
// entero dentro de una clase del juego principal.)
abstract class Movil {
  abstract float px();      // pies en baldosas
  abstract float py();
  abstract void dibujar();
}

void dibujarCiudad() {
  pushMatrix();
  // la cámara se redondea a pixeles enteros del dibujo para que nada tiemble
  float cx = round(camX), cy = round(camY);
  translate(round(width / 2.0 - cx * pixel), round(height / 2.0 - cy * pixel));
  scale(pixel);
  float vx1 = cx - width / 2.0 / pixel, vx2 = cx + width / 2.0 / pixel;
  float vy1 = cy - height / 2.0 / pixel, vy2 = cy + height / 2.0 / pixel;

  // 1) piso: solo los trozos que se ven
  for (int i = max(0, floor(vx1 / TROZO)); i <= min(trozos.length - 1, floor(vx2 / TROZO)); i++) {
    for (int j = max(0, floor(vy1 / TROZO)); j <= min(trozos[0].length - 1, floor(vy2 / TROZO)); j++) {
      image(trozos[i][j], i * TROZO, j * TROZO);
    }
  }
  if (verChoques) dibujarChoques(vx1, vy1, vx2, vy2);
  dibujarPisoRonda();

  // 2) a cada cosa que se mueve se le busca su lugar entre los objetos
  ArrayList<Movil> moviles = movilesVisibles();
  int[] lugar = new int[moviles.size()];
  for (int m = 0; m < moviles.size(); m++) {
    Movil mv = moviles.get(m);
    float ux = mv.px() * T, uy = mv.py() * T;
    float sx = pantallaX(mv.px(), mv.py()), sy = pantallaY(mv.px(), mv.py());
    lugar[m] = objetos.size();
    for (int k = 0; k < objetos.size(); k++) {
      Objeto o = objetos.get(k);
      if (o.seCruza(sx - 9, sy - 34, sx + 9, sy + 3) && o.tapa(ux, uy)) {
        lugar[m] = k;
        break;
      }
    }
  }
  // lo alto que tapa al jugador se vuelve transparente
  float ux = yo.x * T, uy = yo.y * T;
  float px = pantallaX(yo.x, yo.y), py = pantallaY(yo.x, yo.y);
  int lugarYo = objetos.size();
  for (int m = 0; m < moviles.size(); m++) if (moviles.get(m) == yo) lugarYo = lugar[m];
  int[] orden = ordenDeMoviles(moviles, lugar);
  int siguiente = 0;   // el próximo móvil de "orden" por dibujar

  for (int k = 0; k <= objetos.size(); k++) {
    // los móviles que van justo antes del objeto k
    while (siguiente < orden.length && lugar[orden[siguiente]] == k) {
      moviles.get(orden[siguiente]).dibujar();
      siguiente++;
    }
    if (k == objetos.size()) break;
    Objeto o = objetos.get(k);
    if (!o.seCruza(vx1, vy1, vx2, vy2)) continue;
    if (k >= lugarYo && o.img.height > 34 && o.seCruza(px - 9, py - 30, px + 9, py + 3) && o.tapa(ux, uy)) {
      tint(255, 110);
      image(o.img, o.x0, o.y0);
      noTint();
    } else {
      image(o.img, o.x0, o.y0);
    }
    if (o.punto >= 0) dibujarVolante(o.punto);
    if (o.semaforo >= 0) dibujarLuzSemaforo(o.semaforo);
  }
  dibujarEncimaRonda();
  popMatrix();
}

// Los móviles ordenados una sola vez por cuadro: primero por el objeto
// delante del que van y, en el mismo lugar, de atrás hacia adelante
// (x + y). Son pocos, así que basta la inserción simple. Antes se recorría
// la lista completa por cada objeto de la ciudad.
int[] ordenDeMoviles(ArrayList<Movil> moviles, int[] lugar) {
  int n = moviles.size();
  int[] orden = new int[n];
  float[] fondo = new float[n];
  for (int m = 0; m < n; m++) {
    orden[m] = m;
    fondo[m] = moviles.get(m).px() + moviles.get(m).py();
  }
  for (int a = 1; a < n; a++) {
    int v = orden[a];
    int b = a - 1;
    while (b >= 0 && (lugar[orden[b]] > lugar[v] || (lugar[orden[b]] == lugar[v] && fondo[orden[b]] > fondo[v]))) {
      orden[b + 1] = orden[b];
      b--;
    }
    orden[b + 1] = v;
  }
  return orden;
}

// Rombos rojos en las celdas bloqueadas que se ven (para revisar el mapa)
void dibujarChoques(float vx1, float vy1, float vx2, float vy2) {
  noStroke();
  fill(255, 0, 0, 90);
  float paso = CEL / (float) T;
  for (int i = 0; i < celdasX; i++) {
    for (int j = 0; j < celdasY; j++) {
      if (!choque[i][j]) continue;
      float x = i * paso, y = j * paso;
      float sx = pantallaX(x, y), sy = pantallaY(x, y);
      if (sx < vx1 - 10 || sx > vx2 + 10 || sy < vy1 - 10 || sy > vy2 + 10) continue;
      quad(sx, sy, pantallaX(x + paso, y), pantallaY(x + paso, y),
        pantallaX(x + paso, y + paso), pantallaY(x + paso, y + paso), pantallaX(x, y + paso), pantallaY(x, y + paso));
    }
  }
}
