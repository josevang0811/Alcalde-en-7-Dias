// La ronda de los lives.
//
// Pasó algo en la ciudad y en varios sitios se juntó gente alrededor de
// alguien que está transmitiendo en vivo en la red social. Los cúmulos salen
// al azar por todo el mapa (no solo en el parque). Para quedarse con uno hay
// que llegar, oprimir F (o E) junto al que transmite y marcar 6 flechas en
// orden. Cada live reclamado es un punto y ya nadie lo cambia. Gana el que
// tenga más cuando se reclaman todos o se acaba el tiempo. Aquí sirve mucho
// el carro: el mapa es grande.
//
// Se reutiliza lo de la ronda de la gente: el que transmite es un Ciudadano
// marcado como live, el público son ciudadanos quietos alrededor, y la
// secuencia es la misma cola de flechas (Gente.pde), solo que más larga.

final int NUM_LIVES = 6;
final int PUBLICO_POR_LIVE = 4;
final float TIEMPO_LIVES = 120;
final int LARGO_LIVE = 6;
final float ALCANCE_LIVE = 1.5;
final float SEPARACION_LIVES = 14;   // baldosas mínimas entre dos cúmulos

int largoSecuencia() {
  return evento == LIVES ? LARGO_LIVE : LARGO_SECUENCIA;
}

float alcanceDe() {
  return evento == LIVES ? ALCANCE_LIVE : ALCANCE_CONVENCER;
}

float tiempoRonda() {
  return evento == LIVES ? TIEMPO_LIVES : TIEMPO_RONDA;
}

// Un sitio bueno para un cúmulo: dentro de una manzana con espacio, lejos
// del parque, de la sede, del río y de los otros cúmulos, y al que se pueda
// llegar caminando desde la plaza.
boolean sitioParaLive(float x, float y, ArrayList<PVector> otros) {
  int z = zonaEn(x, y);
  if (z == 0 || z == 1 || z == 2 || z == 7 || z == 9) return false;
  if (dist(x, y, centroX, centroY) < 16) return false;
  if (!libre(x, y, 1.1)) return false;
  for (PVector o : otros) if (dist(x, y, o.x, o.y) < SEPARACION_LIVES) return false;
  return rutaBFS(centroX + radioPlaza + 1, centroY, x, y) != null;
}

// Pone los cúmulos. Los ciudadanos de los lives van al final de la lista,
// siempre en el mismo orden (el que transmite y su público), para que en red
// el invitado arme la misma lista y la foto del anfitrión los ubique.
void crearLives() {
  for (int k = ciudadanos.size() - 1; k >= 0; k--) {
    Ciudadano z = ciudadanos.get(k);
    if (z.live || z.quieto) ciudadanos.remove(k);
  }
  ArrayList<PVector> sitios = new ArrayList<PVector>();
  for (int intento = 0; intento < 3000 && sitios.size() < NUM_LIVES; intento++) {
    float x = random(3, baldosasX - 3), y = random(3, baldosasY - 3);
    if (sitioParaLive(x, y, sitios)) sitios.add(new PVector(x, y));
  }
  int id = ciudadanos.size();
  for (PVector s : sitios) {
    Ciudadano live = new Ciudadano(id++, s.x, s.y);
    live.live = true;
    live.quieto = true;
    ciudadanos.add(live);
    for (int k = 0; k < PUBLICO_POR_LIVE; k++) {
      float a = TWO_PI * k / PUBLICO_POR_LIVE + random(-0.3, 0.3);
      PVector p = puntoLibreCerca(s.x + cos(a) * 1.25, s.y + sin(a) * 1.25);
      Ciudadano z = new Ciudadano(id++, p.x, p.y);
      z.quieto = true;
      z.dirX = s.x - p.x;
      z.dirY = s.y - p.y;
      ciudadanos.add(z);
    }
  }
}

int livesDe(Candidato c) {
  int n = 0;
  for (Ciudadano z : ciudadanos) if (z.live && z.dueno == c.id) n++;
  return n;
}

int livesLibres() {
  int n = 0;
  for (Ciudadano z : ciudadanos) if (z.live && !z.asegurado) n++;
  return n;
}

int totalLives() {
  int n = 0;
  for (Ciudadano z : ciudadanos) if (z.live) n++;
  return n;
}

// El live libre más cercano al candidato (para la flecha y los bots)
Ciudadano liveMasCercano(Candidato c) {
  Ciudadano mejor = null;
  float md = 1e9;
  for (Ciudadano z : ciudadanos) {
    if (!z.live || z.asegurado) continue;
    float d = dist(c.x, c.y, z.x, z.y);
    if (d < md) {
      md = d;
      mejor = z;
    }
  }
  return mejor;
}

// Los bots: van al live libre que les sale más a cuenta (cerca y que otro
// bot no esté buscando) y marcan las flechas con su ritmo.
void botLives(Bot b, float dt) {
  Candidato c = b.c;
  if (c.aturdido > 0) {
    c.moviendose = false;
    return;
  }
  b.revisarTiro -= dt;
  if (b.revisarTiro <= 0) {
    b.revisarTiro = 0.5;
    b.intentarTiro();
  }
  if (enSecuencia(c)) {
    c.moviendose = false;
    b.ritmo -= dt;
    if (b.ritmo <= 0) {
      b.ritmo = dificultad == FACIL ? random(0.6, 0.85) : random(0.35, 0.55);
      java.util.ArrayDeque<Integer> cola = secuencias.get(c.id);
      if (cola != null && !cola.isEmpty()) {
        int f = cola.peek();
        if (random(1) < (dificultad == FACIL ? 0.12 : 0.06)) f = (f + 1) % 4;
        marcarFlecha(c, f);
      }
    }
    return;
  }
  Ciudadano m = b.meta;
  if (m == null || !m.live || m.asegurado || (m.ocupadoPor >= 0 && m.ocupadoPor != c.id)) {
    float mejor = 1e9;
    m = null;
    for (Ciudadano z : ciudadanos) {
      if (!z.live || z.asegurado || (z.ocupadoPor >= 0 && z.ocupadoPor != c.id)) continue;
      float costo = dist(c.x, c.y, z.x, z.y) + random(0, 4);
      for (Candidato o : candidatos) if (o.bot != null && o != c && o.bot.meta == z) costo += 12;
      if (costo < mejor) {
        mejor = costo;
        m = z;
      }
    }
    b.meta = m;
    b.ruta = null;
  }
  if (m == null) {
    c.moviendose = false;
    return;
  }
  if (dist(c.x, c.y, m.x, m.y) > ALCANCE_LIVE - 0.3) {
    b.replan -= dt;
    if (b.ruta == null || b.replan <= 0) {
      b.replan = 3;
      b.irA(m.x, m.y);
    }
    b.seguirRuta(dt, false);   // caminan: el jugador puede ganarles en carro
    return;
  }
  c.moviendose = false;
  empezarSecuencia(c, m);
  b.ritmo = 0.5;
}

// Encima del que transmite: el letrero rojo de EN VIVO y el celular
void dibujarMarcaLive(Ciudadano z, float sx, float sy) {
  if (estadoRonda != RONDA && estadoRonda != FINAL) return;
  // el celular en la mano
  noStroke();
  fill(30, 28, 36);
  rect(sx + 3, sy - 19, 4, 6);
  fill(140, 200, 250);
  rect(sx + 3.6, sy - 18.4, 2.8, 3.6);
  if (z.asegurado) return;
  // el letrero, que titila
  float y = sy - 38 + sin(millis() / 260.0) * 1.2;
  fill(CAFE);
  rect(sx - 12, y - 1, 24, 9);
  fill(millis() % 1000 < 650 ? color(226, 52, 52) : color(170, 36, 36));
  rect(sx - 11, y, 22, 7);
  fill(255);
  ellipse(sx - 7.5, y + 3.5, 2.5, 2.5);
  textFont(fuenteNegrita, 6);
  textAlign(LEFT, CENTER);
  text("LIVE", sx - 5, y + 3);
}
