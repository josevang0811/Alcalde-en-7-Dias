// La ronda de convencer a la gente.
//
// Por el parque y sus calles caminan 20 ciudadanos. Hay dos formas de
// ganarse uno:
//   - Rápida: E a su lado. Queda de tu color claro, pero cualquier rival se
//     lo puede llevar igual.
//   - Segura: F a su lado. Arriba del ciudadano salen 4 flechas que hay que
//     marcar en orden (flechas o WASD); no hace falta mantener nada. Si se
//     completan, queda de tu color con candado y ya nadie lo cambia. Un error
//     vuelve a empezar la secuencia; F otra vez la deja y un botellazo la corta.

final int NUM_CIUDADANOS = 20;
final float ALCANCE_CONVENCER = 1.15;   // baldosas
final int LARGO_SECUENCIA = 4;
final int ARRIBA_F = 0, DERECHA_F = 1, ABAJO_F = 2, IZQUIERDA_F = 3;

ArrayList<Ciudadano> ciudadanos = new ArrayList<Ciudadano>();

class Ciudadano extends Movil {
  int id;
  float x, y, dirX = 1, dirY = 1;
  boolean moviendose;
  PImage[] frente = new PImage[3];
  PImage[] espalda = new PImage[3];
  ArrayList<PVector> ruta;
  int paso;
  float espera;              // segundos quieto antes de buscar otro sitio
  int dueno = -1;            // candidato que lo convenció (-1: nadie)
  boolean asegurado;
  int ocupadoPor = -1;       // candidato que le está haciendo la secuencia
  float trabadoCarro;
  boolean live;              // está transmitiendo en vivo (ronda de los lives)
  boolean quieto;            // no camina: el que transmite y su público

  Ciudadano(int id, float x, float y) {
    this.id = id;
    this.x = x;
    this.y = y;
    int v = id % 8;
    for (int k = 0; k < 3; k++) {
      frente[k] = loadImage("personas/ciudadano" + v + "_frente_" + k + ".png");
      espalda[k] = loadImage("personas/ciudadano" + v + "_espalda_" + k + ".png");
    }
    espera = random(0, 3);
  }

  public float px() {
    return x;
  }

  public float py() {
    return y;
  }

  // Pasea: va a un sitio al azar del área, se queda un rato y busca otro.
  // Mientras alguien lo está convenciendo se queda quieto.
  void actualizar(float dt) {
    moviendose = false;
    if (ocupadoPor >= 0 || quieto) return;
    if (espera > 0) {
      espera -= dt;
      return;
    }
    if (ruta == null || paso >= ruta.size()) {
      PVector d = puntoAlAzarArena();
      ruta = rutaBFS(x, y, d.x, d.y);
      paso = 0;
      if (ruta == null) {
        espera = 1;
        return;
      }
    }
    PVector p = ruta.get(paso);
    float dx = p.x - x, dy = p.y - y;
    float l = sqrt(dx * dx + dy * dy);
    if (l < 0.15) {
      paso++;
      if (paso >= ruta.size()) espera = random(1.5, 4);
      return;
    }
    float v = 1.3 * dt;
    float nx = x + dx / l * v, ny = y + dy / l * v;
    boolean conCarros = trabadoCarro < 1.2;
    if (conCarros && personaChocaCarro(nx, ny)) {
      trabadoCarro += dt;
      return;
    }
    if (!personaChocaCarro(x, y)) trabadoCarro = 0;
    if (libre(nx, y, RADIO_PERSONA)) x = nx;
    if (libre(x, ny, RADIO_PERSONA)) y = ny;
    dirX = dx / l;
    dirY = dy / l;
    moviendose = true;
  }

  public void dibujar() {
    float sx = round(pantallaX(x, y));
    float sy = round(pantallaY(x, y));
    noStroke();
    fill(40, 34, 60, 70);
    ellipse(sx, sy, 13, 5);
    // anillo: punteado gris si nadie lo tiene, claro si es rápido, fuerte si es seguro
    if ((estadoRonda == RONDA || estadoRonda == FINAL) && (evento != LIVES || live)) {
      if (dueno < 0) {
        stroke(250, 246, 236, 170);
        strokeWeight(1);
        noFill();
        for (int k = 0; k < 12; k += 2) {
          float a0 = TWO_PI * k / 12, a1 = TWO_PI * (k + 1) / 12;
          line(sx + cos(a0) * 8, sy + sin(a0) * 3.5, sx + cos(a1) * 8, sy + sin(a1) * 3.5);
        }
      } else {
        Candidato c = candidatos.get(dueno);
        noStroke();
        fill(asegurado ? c.col : c.claro, asegurado ? 170 : 120);
        ellipse(sx, sy, 17, 7.5);
        noFill();
        stroke(c.col);
        strokeWeight(asegurado ? 1.6 : 1);
        ellipse(sx, sy, 17, 7.5);
      }
      noStroke();
    }
    float mx = dirX - dirY;
    float my = (dirX + dirY) * 0.5;
    int cuadro = moviendose ? 1 + (millis() / 180) % 2 : 0;
    PImage img = my < -0.05 ? espalda[cuadro] : frente[cuadro];
    pushMatrix();
    translate(sx, sy);
    if (mx > 0) scale(-1, 1);
    image(img, -8, -27);
    popMatrix();
    if (live) dibujarMarcaLive(this, sx, sy);
  }
}

void crearCiudadanos() {
  ciudadanos.clear();
  for (int k = 0; k < NUM_CIUDADANOS; k++) {
    PVector p = puntoAlAzarArena();
    ciudadanos.add(new Ciudadano(k, p.x, p.y));
  }
}

// Un punto libre al azar dentro del parque y sus calles
PVector puntoAlAzarArena() {
  for (int k = 0; k < 40; k++) {
    float x = random(arenaX0 + 0.5, arenaX1 - 0.5);
    float y = random(arenaY0 + 0.5, arenaY1 - 0.5);
    if (celdaUsable(celdaDe(x), celdaDe(y))) return new PVector(x, y);
  }
  return new PVector(centroX + 4, centroY + 4);
}

void reiniciarGente() {
  for (Ciudadano z : ciudadanos) {
    z.dueno = -1;
    z.asegurado = false;
    z.ocupadoPor = -1;
  }
  for (Candidato c : candidatos) cancelarSecuencia(c);
}

int genteDe(Candidato c) {
  int n = 0;
  for (Ciudadano z : ciudadanos) if (z.dueno == c.id) n++;
  return n;
}

// El ciudadano más cercano al alcance que todavía se puede ganar, o null
Ciudadano ciudadanoAlAlcance(Candidato c) {
  if (c == yo && manejando != null) return null;
  Ciudadano mejor = null;
  float md = alcanceDe();
  for (Ciudadano z : ciudadanos) {
    if (z.asegurado || (evento == LIVES && !z.live)) continue;
    if (z.ocupadoPor >= 0 && z.ocupadoPor != c.id) continue;
    float d = dist(c.x, c.y, z.x, z.y);
    if (d < md) {
      md = d;
      mejor = z;
    }
  }
  return mejor;
}

// Cualquier ciudadano cerca (aunque ya esté asegurado), para los mensajes
Ciudadano ciudadanoCerca(Candidato c) {
  if (c == yo && manejando != null) return null;
  Ciudadano mejor = null;
  float md = alcanceDe();
  for (Ciudadano z : ciudadanos) {
    if (evento == LIVES && !z.live) continue;
    float d = dist(c.x, c.y, z.x, z.y);
    if (d < md) {
      md = d;
      mejor = z;
    }
  }
  return mejor;
}

// ---------------------------------------------------------------------------
// Las dos formas de convencer
// ---------------------------------------------------------------------------

// Forma rápida: se lo lleva aunque sea de otro (si no está asegurado)
boolean convencerRapido(Candidato c, Ciudadano z) {
  if (z == null || z.asegurado || z.dueno == c.id || c.aturdido > 0) return false;
  int antes = z.dueno;
  z.dueno = c.id;
  c.ultimoLogro = millis();
  efectoTexto(z.x, z.y, "+1", c.col);
  efectoChispas(z.x, z.y, c.col);
  if (antes >= 0 && antes != c.id) {
    avisarA(c, "Le quitaste un ciudadano a " + candidatos.get(antes).nombre);
    avisarA(candidatos.get(antes), c.nombre + " te quitó un ciudadano");
  }
  return true;
}

void asegurar(Candidato c, Ciudadano z) {
  int antes = z.dueno;
  z.dueno = c.id;
  z.asegurado = true;
  z.ocupadoPor = -1;
  c.ultimoLogro = millis();
  efectoTexto(z.x, z.y, "¡Asegurado!", c.col);
  efectoChispas(z.x, z.y, c.col);
  if (antes >= 0 && antes != c.id) avisarA(candidatos.get(antes), c.nombre + " aseguró a uno de los tuyos");
}


// --- La secuencia de flechas: una cola que se va vaciando en orden ---
// Cada candidato tiene la suya (los bots la "teclean" con su propio ritmo).
HashMap<Integer, java.util.ArrayDeque<Integer>> secuencias = new HashMap<Integer, java.util.ArrayDeque<Integer>>();
HashMap<Integer, Ciudadano> secuenciaCon = new HashMap<Integer, Ciudadano>();

boolean enSecuencia(Candidato c) {
  return secuenciaCon.get(c.id) != null;
}

void empezarSecuencia(Candidato c, Ciudadano z) {
  java.util.ArrayDeque<Integer> cola = new java.util.ArrayDeque<Integer>();
  for (int k = 0; k < largoSecuencia(); k++) cola.add(int(random(4)));
  secuencias.put(c.id, cola);
  secuenciaCon.put(c.id, z);
  z.ocupadoPor = c.id;
  c.progresoPegar = 0.05;
  c.mirarHacia(z.x, z.y);
}

void cancelarSecuencia(Candidato c) {
  Ciudadano z = secuenciaCon.get(c.id);
  if (z != null && z.ocupadoPor == c.id) z.ocupadoPor = -1;
  secuenciaCon.remove(c.id);
  secuencias.remove(c.id);
  c.progresoPegar = 0;
}

// Una flecha marcada. Si es la que sigue, sale de la cola; si no, la
// secuencia vuelve a empezar con flechas nuevas.
void marcarFlecha(Candidato c, int flecha) {
  java.util.ArrayDeque<Integer> cola = secuencias.get(c.id);
  Ciudadano z = secuenciaCon.get(c.id);
  if (cola == null || z == null) return;
  if (cola.peek() == flecha) {
    if (c == yo) sonar("flecha_ok");
    cola.poll();
    c.progresoPegar = max(0.05, (largoSecuencia() - cola.size()) / (float) largoSecuencia());
    if (cola.isEmpty()) {
      asegurar(c, z);
      secuenciaCon.remove(c.id);
      secuencias.remove(c.id);
      c.progresoPegar = 0;
    }
  } else {
    if (c == yo) sonar("flecha_mal");
    cola.clear();
    for (int k = 0; k < largoSecuencia(); k++) cola.add(int(random(4)));
    c.progresoPegar = 0.05;
    avisarA(c, "¡Esa no era! La secuencia vuelve a empezar");
  }
}

// Cada cuadro, para todos: si el ciudadano se alejó, se lo llevaron o al
// candidato le pegaron, la secuencia se corta.
void revisarSecuencias() {
  for (Candidato c : candidatos) {
    Ciudadano z = secuenciaCon.get(c.id);
    if (z == null) continue;
    if (c.aturdido > 0 || z.asegurado || dist(c.x, c.y, z.x, z.y) > alcanceDe() + 0.3) {
      cancelarSecuencia(c);
      if (c.aturdido > 0) avisarA(c, "El botellazo te cortó la secuencia");
    }
  }
}

// ---------------------------------------------------------------------------
// El jugador: E es la forma rápida y F empieza (o deja) la secuencia
// ---------------------------------------------------------------------------

// Devuelve true si la tecla sirvió (para que E no suba al carro de paso)
boolean accionRapida(Candidato c) {
  if (estadoRonda != RONDA || evento == VOLANTES) return false;
  // en la de los lives no hay forma rápida: E también empieza las flechas
  if (evento == LIVES) {
    if (enSecuencia(c) || ciudadanoAlAlcance(c) == null) return false;
    accionAsegurar(c);
    return true;
  }
  if (enSecuencia(c)) return false;
  return convencerRapido(c, ciudadanoAlAlcance(c));
}

void accionAsegurar(Candidato c) {
  if (estadoRonda != RONDA || evento == VOLANTES) return;
  if (enSecuencia(c)) {
    cancelarSecuencia(c);
    return;
  }
  Ciudadano z = ciudadanoAlAlcance(c);
  if (z != null && c.aturdido <= 0) empezarSecuencia(c, z);
}

// Devuelve true si la tecla se usó en la secuencia (y no para caminar)
boolean teclaSecuencia() {
  if (!enSecuencia(yo)) return false;
  int f = -1;
  char k = Character.toLowerCase(key);
  if (key == CODED) {
    if (keyCode == UP) f = ARRIBA_F;
    if (keyCode == RIGHT) f = DERECHA_F;
    if (keyCode == DOWN) f = ABAJO_F;
    if (keyCode == LEFT) f = IZQUIERDA_F;
  } else {
    if (k == 'w') f = ARRIBA_F;
    if (k == 'd') f = DERECHA_F;
    if (k == 's') f = ABAJO_F;
    if (k == 'a') f = IZQUIERDA_F;
  }
  if (f < 0) return false;
  if (modoRed == INVITADO) {
    enviarAccionRed(char('0' + f));
    sonar("flecha_ok");
  }
  else marcarFlecha(yo, f);
  return true;
}

// Las flechas de la secuencia del jugador, grandes encima del ciudadano
void dibujarSecuenciaJugador() {
  Ciudadano z = secuenciaCon.get(yo.id);
  java.util.ArrayDeque<Integer> cola = secuencias.get(yo.id);
  if (z == null || cola == null) return;
  float sx = aPantallaX(pantallaX(z.x, z.y)), sy = aPantallaY(pantallaY(z.x, z.y) - 52);
  int largo = largoSecuencia();
  int hechas = largo - cola.size();
  float tam = 20 * pixel, sep = 4 * pixel;
  float total = largo * tam + (largo - 1) * sep;
  caja(sx - total / 2 - 6 * pixel, sy - tam / 2 - 6 * pixel, total + 12 * pixel, tam + 22 * pixel, 225);
  textFont(fuente, 7 * pixel);
  fill(CREMA, 190);
  textAlign(CENTER, CENTER);
  text("F para dejarlo", sx, sy + tam / 2 + 5 * pixel);
  Integer[] faltan = cola.toArray(new Integer[0]);
  for (int k = 0; k < largo; k++) {
    float x = sx - total / 2 + k * (tam + sep);
    boolean hecha = k < hechas;
    boolean sigue = k == hechas;
    noStroke();
    fill(hecha ? color(90, 170, 110) : (sigue ? CREMA : color(90, 80, 74)));
    rect(x, sy - tam / 2, tam, tam, 3 * pixel);
    if (hecha) continue;
    int f = faltan[k - hechas];
    pushMatrix();
    translate(x + tam / 2, sy);
    rotate(HALF_PI * f);
    fill(sigue ? CAFE : CREMA);
    triangle(0, -tam * 0.32, tam * 0.28, tam * 0.05, -tam * 0.28, tam * 0.05);
    rect(-tam * 0.1, 0, tam * 0.2, tam * 0.3);
    popMatrix();
  }
}

// "E: rápido · mantén E: asegurar" encima del ciudadano que alcanza el jugador
void dibujarAyudaGente() {
  if (enSecuencia(yo) || yo.aturdido > 0) return;
  Ciudadano z = ciudadanoCerca(yo);
  if (z == null) return;
  String s;
  if (evento == LIVES) {
    if (z.asegurado) s = z.dueno == yo.id ? "Este live ya es tuyo" : "Este live ya es de " + candidatos.get(z.dueno).nombre;
    else if (z.ocupadoPor >= 0 && z.ocupadoPor != yo.id) s = candidatos.get(z.ocupadoPor).nombre + " lo está reclamando";
    else s = "F: reclamar el live (6 flechas)";
  } else if (z.asegurado) s = z.dueno == yo.id ? "Este ya es tuyo y está asegurado" : "Asegurado por " + candidatos.get(z.dueno).nombre;
  else if (z.ocupadoPor >= 0 && z.ocupadoPor != yo.id) s = candidatos.get(z.ocupadoPor).nombre + " lo está convenciendo";
  else if (z.dueno == yo.id) s = "Es tuyo · F para asegurarlo";
  else s = "E: convencer rápido · F: asegurar";
  float sx = aPantallaX(pantallaX(z.x, z.y)), sy = aPantallaY(pantallaY(z.x, z.y) - (evento == LIVES ? 56 : 44));
  textFont(fuenteNegrita, 9 * pixel);
  float w = textWidth(s) + 14 * pixel;
  caja(sx - w / 2, sy - 9 * pixel, w, 17 * pixel, 210);
  fill(z.dueno == yo.id ? color(160, 220, 170) : CREMA);
  textAlign(CENTER, CENTER);
  text(s, sx, sy - pixel);
}

// Candadito encima de los ciudadanos asegurados
void dibujarCandados() {
  if (estadoRonda != RONDA && estadoRonda != FINAL) return;
  for (Ciudadano z : ciudadanos) {
    if (!z.asegurado) continue;
    float sx = aPantallaX(pantallaX(z.x, z.y)), sy = aPantallaY(pantallaY(z.x, z.y) - 33);
    if (sx < -20 || sx > width + 20 || sy < -20 || sy > height + 20) continue;
    color c = candidatos.get(z.dueno).col;
    noFill();
    stroke(CAFE);
    strokeWeight(2.4 * pixel);
    arc(sx, sy - 3 * pixel, 6 * pixel, 7 * pixel, PI, TWO_PI);
    stroke(c);
    strokeWeight(1.2 * pixel);
    arc(sx, sy - 3 * pixel, 6 * pixel, 7 * pixel, PI, TWO_PI);
    noStroke();
    fill(CAFE);
    rect(sx - 4.5 * pixel, sy - 3.5 * pixel, 9 * pixel, 7.5 * pixel, 1.5 * pixel);
    fill(c);
    rect(sx - 3.5 * pixel, sy - 2.5 * pixel, 7 * pixel, 5.5 * pixel, pixel);
  }
}
