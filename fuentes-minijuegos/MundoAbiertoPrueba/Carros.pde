// Carros: el tráfico de la ciudad y los carros que se pueden manejar.
//
// El tráfico va por un grafo de carriles. Cada vía tiene dos carriles (uno
// por sentido, por la derecha). Un "tramo" es un pedazo de carril: una recta
// entre dos cruces o una curva dentro de un cruce (de frente, a la derecha o
// a la izquierda). Al terminar un tramo, el carro escoge al azar uno de los
// siguientes. En los bordes de la ciudad los carriles dan la vuelta en U.
// Cada cruce tiene su semáforo: 6,5 s verde para un eje, 1,5 s amarillo, y
// luego el otro eje. Los carros paran en rojo y frenan si hay alguien
// adelante (otro carro o una persona).
//
// Cualquier carro se puede manejar: E al lado para subirse (en el paseo,
// no durante un evento), WASD para manejar y E otra vez para bajarse. El
// carro se queda donde lo deja el jugador.

final int NUM_TRAFICO = 14;
final float ANCLA_CARRO_X = 32, ANCLA_CARRO_Y = 32;
final int ROJO = 0, AMARILLO = 1, VERDE = 2;
final float CICLO_SEMAFORO = 16;

PImage[][] dibujoCarro = new PImage[8][8];
ArrayList<Carro> carros = new ArrayList<Carro>();
ArrayList<Tramo> tramos = new ArrayList<Tramo>();
Carro manejando = null;       // el carro que maneja el jugador (o null)
int[] viasX, viasY;           // baldosa donde empieza cada vía (4 de ancho)
float maleconX;
float[][] desfaseSemaforo;
ArrayList<float[]> lucesSemaforo = new ArrayList<float[]>();   // i, j, eje (0 v, 1 h), 6 coordenadas

// ---------------------------------------------------------------------------
// Tramos de carril
// ---------------------------------------------------------------------------

class Tramo {
  float[] px, py, acum;
  float largo;
  ArrayList<Tramo> siguientes = new ArrayList<Tramo>();
  int cruceI = -1, cruceJ = -1;   // si termina en la entrada de un cruce
  int eje = -1;                   // 0 vertical, 1 horizontal (para el semáforo)
  boolean enCruce;

  // Recta o curva (Bézier cuadrática) de a a b con control c
  Tramo(float ax, float ay, float cx, float cy, float bx, float by, boolean enCruce) {
    this.enCruce = enCruce;
    int n = max(2, ceil(dist(ax, ay, bx, by) / 0.25));
    px = new float[n + 1];
    py = new float[n + 1];
    acum = new float[n + 1];
    for (int k = 0; k <= n; k++) {
      float t = k / (float) n;
      px[k] = sq(1 - t) * ax + 2 * (1 - t) * t * cx + t * t * bx;
      py[k] = sq(1 - t) * ay + 2 * (1 - t) * t * cy + t * t * by;
      if (k > 0) acum[k] = acum[k - 1] + dist(px[k - 1], py[k - 1], px[k], py[k]);
    }
    largo = acum[n];
  }

  // Posición y rumbo a una distancia s del comienzo
  float[] en(float s) {
    s = constrain(s, 0, largo);
    int k = 1;
    while (k < acum.length - 1 && acum[k] < s) k++;
    float t = (s - acum[k - 1]) / max(0.0001, acum[k] - acum[k - 1]);
    float x = lerp(px[k - 1], px[k], t), y = lerp(py[k - 1], py[k], t);
    return new float[] {x, y, atan2(py[k] - py[k - 1], px[k] - px[k - 1])};
  }
}

Tramo recta(float ax, float ay, float bx, float by) {
  Tramo t = new Tramo(ax, ay, (ax + bx) / 2, (ay + by) / 2, bx, by, false);
  tramos.add(t);
  return t;
}

Tramo curva(float ax, float ay, float cx, float cy, float bx, float by, boolean enCruce) {
  Tramo t = new Tramo(ax, ay, cx, cy, bx, by, enCruce);
  tramos.add(t);
  return t;
}

// Direcciones: 0 este (+x), 1 sur (+y), 2 oeste (-x), 3 norte (-y)
final int ESTE = 0, SUR = 1, OESTE = 2, NORTE = 3;

// Dónde se entra a un cruce y dónde se sale, según el sentido
float[] entradaCruce(int i, int j, int d) {
  float X = viasX[i], Y = viasY[j];
  if (d == ESTE) return new float[] {X, Y + 3};
  if (d == SUR) return new float[] {X + 1, Y};
  if (d == OESTE) return new float[] {X + 4, Y + 1};
  return new float[] {X + 3, Y + 4};
}

float[] salidaCruce(int i, int j, int d) {
  float X = viasX[i], Y = viasY[j];
  if (d == ESTE) return new float[] {X + 4, Y + 3};
  if (d == SUR) return new float[] {X + 1, Y + 4};
  if (d == OESTE) return new float[] {X, Y + 1};
  return new float[] {X + 3, Y};
}

void armarCarriles() {
  int ni = viasX.length, nj = viasY.length;
  float finX = baldosasX - 1.5, finY = baldosasY - 1.5, iniX = maleconX + 1.5, iniY = 1.5;
  // las curvas dentro de cada cruce: [i][j][entra][sale]
  Tramo[][][][] giro = new Tramo[ni][nj][4][4];
  for (int i = 0; i < ni; i++) {
    for (int j = 0; j < nj; j++) {
      for (int d = 0; d < 4; d++) {
        for (int e = 0; e < 4; e++) {
          if (e == (d + 2) % 4) continue;   // sin vuelta en U en el cruce
          float[] a = entradaCruce(i, j, d), b = salidaCruce(i, j, e);
          float cx, cy;
          if (d == e) {
            cx = (a[0] + b[0]) / 2;
            cy = (a[1] + b[1]) / 2;
          } else if (d == ESTE || d == OESTE) {
            cx = b[0];
            cy = a[1];
          } else {
            cx = a[0];
            cy = b[1];
          }
          giro[i][j][d][e] = curva(a[0], a[1], cx, cy, b[0], b[1], true);
        }
      }
    }
  }
  // las rectas entre cruces, con su llegada al cruce siguiente
  for (int i = 0; i < ni; i++) {
    for (int j = 0; j < nj; j++) {
      // al este
      float[] s = salidaCruce(i, j, ESTE);
      if (i + 1 < ni) unirAlCruce(recta(s[0], s[1], viasX[i + 1], s[1]), giro, i + 1, j, ESTE);
      // al sur
      s = salidaCruce(i, j, SUR);
      if (j + 1 < nj) unirAlCruce(recta(s[0], s[1], s[0], viasY[j + 1]), giro, i, j + 1, SUR);
      // al oeste
      s = salidaCruce(i, j, OESTE);
      if (i > 0) unirAlCruce(recta(s[0], s[1], viasX[i - 1] + 4, s[1]), giro, i - 1, j, OESTE);
      // al norte
      s = salidaCruce(i, j, NORTE);
      if (j > 0) unirAlCruce(recta(s[0], s[1], s[0], viasY[j - 1] + 4), giro, i, j - 1, NORTE);
    }
  }
  // los bordes: el carril sigue hasta cerca del borde y da la vuelta en U
  for (int j = 0; j < nj; j++) {
    float Y = viasY[j];
    // derecha (este)
    float[] s = salidaCruce(ni - 1, j, ESTE);
    Tramo a = recta(s[0], s[1], finX, Y + 3);
    Tramo u = curva(finX, Y + 3, finX + 1.3, Y + 2, finX, Y + 1, false);
    Tramo b = recta(finX, Y + 1, viasX[ni - 1] + 4, Y + 1);
    a.siguientes.add(u);
    u.siguientes.add(b);
    unirAlCruce(b, giro, ni - 1, j, OESTE);
    // izquierda (oeste, en el malecón)
    s = salidaCruce(0, j, OESTE);
    a = recta(s[0], s[1], iniX, Y + 1);
    u = curva(iniX, Y + 1, iniX - 1.3, Y + 2, iniX, Y + 3, false);
    b = recta(iniX, Y + 3, viasX[0], Y + 3);
    a.siguientes.add(u);
    u.siguientes.add(b);
    unirAlCruce(b, giro, 0, j, ESTE);
  }
  for (int i = 0; i < ni; i++) {
    float X = viasX[i];
    // abajo (sur)
    float[] s = salidaCruce(i, nj - 1, SUR);
    Tramo a = recta(s[0], s[1], X + 1, finY);
    Tramo u = curva(X + 1, finY, X + 2, finY + 1.3, X + 3, finY, false);
    Tramo b = recta(X + 3, finY, X + 3, viasY[nj - 1] + 4);
    a.siguientes.add(u);
    u.siguientes.add(b);
    unirAlCruce(b, giro, i, nj - 1, NORTE);
    // arriba (norte)
    s = salidaCruce(i, 0, NORTE);
    a = recta(s[0], s[1], X + 3, iniY);
    u = curva(X + 3, iniY, X + 2, iniY - 1.3, X + 1, iniY, false);
    b = recta(X + 1, iniY, X + 1, viasY[0]);
    a.siguientes.add(u);
    u.siguientes.add(b);
    unirAlCruce(b, giro, i, 0, SUR);
  }
  // cada curva del cruce sigue por la recta que sale de ella
  for (Tramo t : tramos) {
    if (!t.enCruce) continue;
    float bx = t.px[t.px.length - 1], by = t.py[t.py.length - 1];
    for (Tramo r : tramos) {
      if (r.enCruce) continue;
      if (dist(r.px[0], r.py[0], bx, by) < 0.05) t.siguientes.add(r);
    }
  }
}

// La recta llega a la entrada del cruce (i, j) en el sentido d: de ahí
// salen las curvas de frente, a la derecha y a la izquierda.
void unirAlCruce(Tramo r, Tramo[][][][] giro, int i, int j, int d) {
  r.cruceI = i;
  r.cruceJ = j;
  r.eje = (d == SUR || d == NORTE) ? 0 : 1;
  for (int e = 0; e < 4; e++) {
    if (giro[i][j][d][e] != null) r.siguientes.add(giro[i][j][d][e]);
  }
}

// ---------------------------------------------------------------------------
// Semáforos
// ---------------------------------------------------------------------------

// Luz para el eje 0 (vertical) o 1 (horizontal) en el cruce (i, j)
int luz(int i, int j, int eje) {
  float t = (millis() / 1000.0 + desfaseSemaforo[i][j]) % CICLO_SEMAFORO;
  int ejeVerde = t < CICLO_SEMAFORO / 2 ? 0 : 1;
  float dentro = t % (CICLO_SEMAFORO / 2);
  if (eje != ejeVerde) return ROJO;
  return dentro < CICLO_SEMAFORO / 2 - 1.5 ? VERDE : AMARILLO;
}

// La luz que toca, encima del dibujo del semáforo (se llama justo después de él)
void dibujarLuzSemaforo(int s) {
  if (s < 0 || s >= lucesSemaforo.size()) return;
  float[] l = lucesSemaforo.get(s);
  int estado = luz((int) l[0], (int) l[1], (int) l[2]);
  int k = estado == ROJO ? 0 : (estado == AMARILLO ? 1 : 2);
  float x = l[3 + k * 2], y = l[4 + k * 2];
  color c = estado == ROJO ? color(255, 70, 60) : (estado == AMARILLO ? color(255, 210, 70) : color(90, 240, 120));
  noStroke();
  fill(c, 70);
  ellipse(x, y - 1, 6, 6);
  fill(c);
  rect(x - 1, y - 2, 2.4, 2);
}

// ---------------------------------------------------------------------------
// Los carros
// ---------------------------------------------------------------------------

class Carro extends Movil {
  float x, y, ang, vel;
  int variante;
  boolean ia;               // lo maneja el tráfico
  Tramo tramo;
  float s;                  // distancia recorrida en el tramo
  float parado;             // segundos frenado por otro carro
  float fantasma;           // segundos ignorando carros (para destrabar)

  Carro(float x, float y, float ang, int variante) {
    this.x = x;
    this.y = y;
    this.ang = ang;
    this.variante = variante;
  }

  public float px() {
    return x;
  }

  public float py() {
    return y;
  }

  float dx() {
    return cos(ang);
  }

  float dy() {
    return sin(ang);
  }

  // Tráfico: sigue su tramo, para en rojo y frena si hay algo adelante
  void actualizarIA(float dt) {
    float objetivo = tramo.enCruce ? 3.0 : 4.6;
    float falta = tramo.largo - s;
    if (tramo.cruceI >= 0) {
      int l = luz(tramo.cruceI, tramo.cruceJ, tramo.eje);
      if (l == ROJO || (l == AMARILLO && falta > 1.4)) {
        if (falta > 0.25) objetivo = min(objetivo, max(0, (falta - 0.45) * 2.4));
      }
    }
    float adelante = libreAdelante(this);
    boolean porCarro = adelante < 2.6;
    if (porCarro) objetivo = min(objetivo, max(0, (adelante - 1.15) * 2.6));
    // si lleva mucho rato frenado por otro carro, se destraba un momento
    if (porCarro && vel < 0.2) parado += dt;
    else parado = 0;
    if (parado > 5) {
      fantasma = 1.5;
      parado = 0;
    }
    fantasma = max(0, fantasma - dt);
    vel += constrain(objetivo - vel, -11 * dt, 5 * dt);
    s += vel * dt;
    while (s > tramo.largo) {
      s -= tramo.largo;
      if (tramo.siguientes.size() == 0) {
        s = 0;
        break;
      }
      tramo = tramo.siguientes.get(int(random(tramo.siguientes.size())));
    }
    float[] p = tramo.en(s);
    x = p[0];
    y = p[1];
    ang = p[2];
  }

  public void dibujar() {
    int d = ((round(ang / QUARTER_PI) % 8) + 8) % 8;
    float sx = round(pantallaX(x, y)), sy = round(pantallaY(x, y));
    noStroke();
    fill(40, 34, 60, 70);
    ellipse(sx + 2, sy + 2, 36, 16);
    image(dibujoCarro[variante][d], sx - ANCLA_CARRO_X, sy - ANCLA_CARRO_Y);
  }
}

// Cuánto espacio libre tiene el carro adelante (otro carro o una persona en
// su carril), hasta 3 baldosas.
float libreAdelante(Carro c) {
  float menor = 99;
  float fx = c.dx(), fy = c.dy();
  if (c.fantasma <= 0) {
    for (Carro o : carros) {
      if (o == c) continue;
      float vx = o.x - c.x, vy = o.y - c.y;
      float a = vx * fx + vy * fy;
      float lat = abs(vx * fy - vy * fx);
      if (a > 0 && a < 3 && lat < 0.8) menor = min(menor, a);
    }
  }
  for (Candidato p : candidatos) {
    if (p == yo && manejando != null) continue;
    float vx = p.x - c.x, vy = p.y - c.y;
    float a = vx * fx + vy * fy;
    float lat = abs(vx * fy - vy * fx);
    if (a > 0 && a < 3 && lat < 0.65) menor = min(menor, a - 0.1);
  }
  for (Ciudadano z : ciudadanos) {
    float vx = z.x - c.x, vy = z.y - c.y;
    float a = vx * fx + vy * fy;
    float lat = abs(vx * fy - vy * fx);
    if (a > 0 && a < 3 && lat < 0.65) menor = min(menor, a - 0.1);
  }
  return menor;
}

void cargarCarros() {
  for (int v = 0; v < 8; v++) {
    for (int d = 0; d < 8; d++) {
      dibujoCarro[v][d] = loadImage("mundo/carro_" + v + "_" + d + ".png");
    }
  }
  HashMap<String, String> info = new HashMap<String, String>();
  for (String l : loadStrings("mundo/mundo.txt")) {
    String[] p = split(trim(l), '=');
    if (p.length == 2) info.put(p[0], p[1]);
  }
  viasX = int(split(info.get("VIAS_X"), ','));
  viasY = int(split(info.get("VIAS_Y"), ','));
  maleconX = float(info.get("MALECON"));
  desfaseSemaforo = new float[viasX.length][viasY.length];
  for (int i = 0; i < viasX.length; i++) {
    for (int j = 0; j < viasY.length; j++) {
      desfaseSemaforo[i][j] = (i * 5.3 + j * 3.1) % CICLO_SEMAFORO;
    }
  }
  for (String l : loadStrings("mundo/semaforos.txt")) {
    String[] p = splitTokens(l);
    if (p.length < 9) continue;
    float[] f = new float[9];
    f[0] = float(p[0]);
    f[1] = float(p[1]);
    f[2] = p[2].equals("v") ? 0 : 1;
    for (int k = 0; k < 6; k++) f[3 + k] = float(p[3 + k]);
    lucesSemaforo.add(f);
  }
  armarCarriles();
  // los estacionados (el de la campaña, los de la gasolinera...)
  for (String l : loadStrings("mundo/carros.txt")) {
    String[] p = splitTokens(l);
    if (p.length < 4) continue;
    carros.add(new Carro(float(p[0]), float(p[1]), float(p[2]), int(p[3])));
  }
  // el tráfico, repartido por las rectas
  ArrayList<Tramo> rectas = new ArrayList<Tramo>();
  for (Tramo t : tramos) if (!t.enCruce && t.largo > 6) rectas.add(t);
  int intentos = 0;
  while (carros.size() < NUM_TRAFICO + 6 && intentos < 500) {
    intentos++;
    Tramo t = rectas.get(int(random(rectas.size())));
    float s = random(1, t.largo - 2);
    float[] p = t.en(s);
    boolean lejos = true;
    for (Carro o : carros) if (dist(o.x, o.y, p[0], p[1]) < 4) lejos = false;
    if (!lejos) continue;
    Carro c = new Carro(p[0], p[1], p[2], random(1) < 0.35 ? 7 : int(random(7)));
    c.ia = true;
    c.tramo = t;
    c.s = s;
    carros.add(c);
  }
}

void actualizarCarros(float dt) {
  for (Carro c : carros) {
    if (c.ia) c.actualizarIA(dt);
  }
  if (manejando != null) {
    manejarCarro(manejando, dt);
    yo.x = manejando.x;
    yo.y = manejando.y;
  }
}

// ---------------------------------------------------------------------------
// Manejar
// ---------------------------------------------------------------------------

// ¿Cabe el carro en (x, y) con ese rumbo? Se mira con dos círculos (adelante
// y atrás). No entra al parque, al malecón ni al río.
boolean carroCabe(Carro c, float x, float y, float ang) {
  for (int k = -1; k <= 1; k += 2) {
    float cx = x + cos(ang) * 0.45 * k, cy = y + sin(ang) * 0.45 * k;
    if (!libre(cx, cy, 0.38)) return false;
    int z = zonaEn(cx, cy);
    if (z == 1 || z == 2 || z == 7) return false;
    for (Carro o : carros) {
      if (o == c) continue;
      for (int m = -1; m <= 1; m += 2) {
        if (dist(cx, cy, o.x + o.dx() * 0.45 * m, o.y + o.dy() * 0.45 * m) < 0.78) return false;
      }
    }
    for (Candidato p : candidatos) {
      if (p == yo) continue;
      if (dist(cx, cy, p.x, p.y) < 0.6) return false;
    }
  }
  return true;
}

// W acelera, S frena (o va en reversa), A y D giran
void manejarCarro(Carro c, float dt) {
  float acel = (tArriba ? 1 : 0) - (tAbajo ? 1 : 0);
  float giro = (tDerecha ? 1 : 0) - (tIzquierda ? 1 : 0);
  if (acel > 0) c.vel += (c.vel < 0 ? 14 : 7) * dt;
  else if (acel < 0) c.vel -= (c.vel > 0 ? 14 : 5) * dt;
  else c.vel -= constrain(c.vel, -4 * dt, 4 * dt);
  c.vel = constrain(c.vel, -3, 9.5);
  float nuevoAng = c.ang + giro * 2.3 * dt * constrain(c.vel / 3, -1, 1);
  float nx = c.x + cos(nuevoAng) * c.vel * dt;
  float ny = c.y + sin(nuevoAng) * c.vel * dt;
  if (carroCabe(c, nx, ny, nuevoAng)) {
    c.x = nx;
    c.y = ny;
    c.ang = nuevoAng;
  } else if (carroCabe(c, c.x, c.y, nuevoAng)) {
    c.ang = nuevoAng;
    c.vel *= -0.25;
  } else {
    c.vel *= -0.25;
  }
}

Carro carroCercano(float x, float y, float alcance) {
  Carro mejor = null;
  float md = alcance;
  for (Carro c : carros) {
    float d = dist(c.x, c.y, x, y);
    if (d < md) {
      md = d;
      mejor = c;
    }
  }
  return mejor;
}

// E en el paseo: subirse al carro de al lado o bajarse del que se maneja
void teclaCarro() {
  if (!puedeManejar()) return;
  if (manejando != null) {
    bajarseDelCarro();
    return;
  }
  Carro c = carroCercano(yo.x, yo.y, 1.6);
  if (c == null) return;
  c.ia = false;
  c.tramo = null;
  c.vel = 0;
  manejando = c;
  sonar("puerta");
  yo.moviendose = false;
  avisar("WASD para manejar · E para bajarte");
}

void bajarseDelCarro() {
  Carro c = manejando;
  if (c == null) return;
  manejando = null;
  sonar("puerta");
  c.vel = 0;
  // se baja por un lado, donde haya espacio
  float[][] lados = {{-sin(c.ang), cos(c.ang)}, {sin(c.ang), -cos(c.ang)}, {-cos(c.ang), -sin(c.ang)}, {cos(c.ang), sin(c.ang)}};
  for (float[] l : lados) {
    for (float r = 0.9; r <= 2.2; r += 0.3) {
      float x = c.x + l[0] * r, y = c.y + l[1] * r;
      if (libre(x, y, RADIO_PERSONA) && !personaChocaCarro(x, y)) {
        yo.x = x;
        yo.y = y;
        return;
      }
    }
  }
  PVector p = puntoLibreCerca(c.x, c.y + 1.5);
  yo.x = p.x;
  yo.y = p.y;
}

// Para las personas: ¿ese punto queda encima de algún carro?
boolean personaChocaCarro(float x, float y) {
  for (Carro c : carros) {
    if (c == manejando) continue;
    for (int m = -1; m <= 1; m += 2) {
      if (dist(x, y, c.x + c.dx() * 0.45 * m, c.y + c.dy() * 0.45 * m) < 0.58) return true;
    }
  }
  if (manejando != null) {
    for (int m = -1; m <= 1; m += 2) {
      if (dist(x, y, manejando.x + manejando.dx() * 0.45 * m, manejando.y + manejando.dy() * 0.45 * m) < 0.58) return true;
    }
  }
  return false;
}

// Se maneja al ir al parque, al volver a la sede y en la ronda de los lives
// (que es por toda la ciudad). En red no, para no desincronizar.
boolean puedeManejar() {
  if (modoRed != SOLO) return false;
  return estadoRonda == PASEO || estadoRonda == VUELTA || (estadoRonda == RONDA && evento == LIVES);
}

// "E: subirte" encima del carro más cercano, y la velocidad al manejar
void dibujarAyudaCarro() {
  if (!puedeManejar()) return;
  if (manejando != null) {
    textFont(fuenteNegrita, 11 * pixel);
    String s = round(abs(manejando.vel) * 1.5 * 3.6) + " km/h";
    float w = textWidth(s) + 18 * pixel;
    caja(width - w - 10 * pixel, height - 34 * pixel, w, 22 * pixel, 210);
    fill(CREMA);
    textAlign(CENTER, CENTER);
    text(s, width - w / 2 - 10 * pixel, height - 23 * pixel);
    return;
  }
  Carro c = carroCercano(yo.x, yo.y, 1.6);
  if (c == null) return;
  float sx = aPantallaX(pantallaX(c.x, c.y)), sy = aPantallaY(pantallaY(c.x, c.y) - 34);
  String s = "E: subirte al carro";
  textFont(fuenteNegrita, 9 * pixel);
  float w = textWidth(s) + 14 * pixel;
  caja(sx - w / 2, sy - 9 * pixel, w, 17 * pixel, 210);
  fill(CREMA);
  textAlign(CENTER, CENTER);
  text(s, sx, sy - pixel);
}
