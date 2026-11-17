// La ronda de volantes: los puntos para pegar, de quién es cada uno y las
// cuentas de la lista en vivo.
//
// Cada punto es una cartelera. Pegar es quedarse al lado y mantener E un
// momento; el punto pasa a ser de ese candidato aunque ya tuviera dueño.

final float TIEMPO_PEGAR = 0.8;     // segundos manteniendo E
final float ALCANCE_PEGAR = 1.45;   // baldosas desde la cartelera

class Punto {
  int id;
  float x, y;           // la cartelera, en baldosas
  char eje;
  float fx, fy;         // dónde se para quien pega
  float[] cara = new float[8];   // la cara del tablero en pixeles del dibujo

  Punto(int id, String[] p) {
    this.id = id;
    x = float(p[0]);
    y = float(p[1]);
    eje = p[2].charAt(0);
    for (int k = 0; k < 8; k++) cara[k] = float(p[5 + k]);
    PVector f = puntoLibreCerca(float(p[3]), float(p[4]));
    fx = f.x;
    fy = f.y;
  }
}

ArrayList<Punto> puntos = new ArrayList<Punto>();
// De quién es cada punto: id del punto -> id del candidato. Si no está, es libre.
HashMap<Integer, Integer> duenoDePunto = new HashMap<Integer, Integer>();

void cargarPuntos() {
  for (String l : loadStrings("mundo/puntos.txt")) {
    String[] p = splitTokens(l);
    if (p.length >= 13) puntos.add(new Punto(puntos.size(), p));
  }
}

int dueno(int punto) {
  Integer d = duenoDePunto.get(punto);
  return d == null ? -1 : d;
}

int volantesDe(Candidato c) {
  int n = 0;
  for (int d : duenoDePunto.values()) if (d == c.id) n++;
  return n;
}

// El punto al que alcanza el candidato (el más cercano), o -1
int puntoAlAlcance(Candidato c) {
  int mejor = -1;
  float md = ALCANCE_PEGAR;
  for (Punto p : puntos) {
    float d = dist(c.x, c.y, p.x, p.y);
    if (d < md) {
      md = d;
      mejor = p.id;
    }
  }
  return mejor;
}

// Se llama cada cuadro: si el candidato está pegando, avanza; si suelta,
// se aleja o le pegan un botellazo, vuelve a cero.
void actualizarPegado(Candidato c, float dt, boolean manteniendo) {
  int p = puntoAlAlcance(c);
  if (!manteniendo || c.aturdido > 0 || p < 0 || dueno(p) == c.id || c.moviendose) {
    c.progresoPegar = 0;
    c.puntoPegando = -1;
    return;
  }
  if (p != c.puntoPegando) {
    c.puntoPegando = p;
    c.progresoPegar = 0;
  }
  Punto pt = puntos.get(p);
  c.mirarHacia(pt.x, pt.y);
  c.progresoPegar += dt / TIEMPO_PEGAR;
  if (c.progresoPegar >= 1) {
    pegar(c, pt);
    c.progresoPegar = 0;
    c.puntoPegando = -1;
  }
}

void pegar(Candidato c, Punto p) {
  int antes = dueno(p.id);
  duenoDePunto.put(p.id, c.id);
  c.ultimoLogro = millis();
  // papelitos del color del candidato
  efectoPapel(p.x, p.y, c.col);
  efectoTexto(p.x, p.y, "+1", c.col);
  if (antes >= 0 && antes != c.id) {
    avisarA(c, "Le quitaste el punto a " + candidatos.get(antes).nombre);
    avisarA(candidatos.get(antes), c.nombre + " tapó tu volante");
  }
}

// Puntos de cada candidato en el evento que se esté jugando
int puntajeDe(Candidato c) {
  if (evento == LIVES) return livesDe(c);
  return evento == VOLANTES ? volantesDe(c) : genteDe(c);
}

// Lista en vivo: candidatos de más a menos volantes; si empatan, va primero
// el que llegó antes a esa cuenta. Pocos elementos: ordenamiento por inserción.
ArrayList<Candidato> listaOrdenada() {
  ArrayList<Candidato> l = new ArrayList<Candidato>(candidatos);
  for (int a = 1; a < l.size(); a++) {
    Candidato v = l.get(a);
    int b = a - 1;
    while (b >= 0 && vaDespues(l.get(b), v)) {
      l.set(b + 1, l.get(b));
      b--;
    }
    l.set(b + 1, v);
  }
  return l;
}

boolean vaDespues(Candidato a, Candidato b) {
  int va = puntajeDe(a), vb = puntajeDe(b);
  if (va != vb) return va < vb;
  if (va == 0) return a.id > b.id;
  return a.ultimoLogro > b.ultimoLogro;
}

Candidato lider() {
  Candidato l = listaOrdenada().get(0);
  return puntajeDe(l) > 0 ? l : null;
}

// ---------------------------------------------------------------------------
// Dibujo de los puntos
// ---------------------------------------------------------------------------

// Anillo en el piso de cada punto: punteado si está libre, del color claro
// del dueño si ya tiene volante.
void dibujarAnillosPuntos() {
  if (evento != VOLANTES) return;
  for (Punto p : puntos) {
    float sx = pantallaX(p.x, p.y), sy = pantallaY(p.x, p.y);
    int d = dueno(p.id);
    float w = 2 * 0.95 * T * 1.414, h = w / 2;
    if (d >= 0) {
      Candidato c = candidatos.get(d);
      noStroke();
      fill(c.claro, 110);
      ellipse(sx, sy, w, h);
      noFill();
      stroke(c.col);
      strokeWeight(1.3);
      ellipse(sx, sy, w, h);
    } else {
      stroke(250, 214, 80, 220);
      strokeWeight(1.3);
      noFill();
      for (int k = 0; k < 16; k += 2) {
        float a0 = TWO_PI * k / 16, a1 = TWO_PI * (k + 1) / 16;
        line(sx + cos(a0) * w / 2, sy + sin(a0) * h / 2, sx + cos(a1) * w / 2, sy + sin(a1) * h / 2);
      }
    }
    // el punto al que alcanza el jugador brilla
    if (puntoAlAlcance(yo) == p.id && d != yo.id && rondaActiva()) {
      noFill();
      stroke(255, 255, 255, 150 + 100 * sin(millis() / 120.0));
      strokeWeight(1);
      ellipse(sx, sy, w + 4, h + 2);
    }
  }
  noStroke();
}

// El volante encima del tablero (se llama justo después de dibujar la cartelera)
void dibujarVolante(int punto) {
  int d = dueno(punto);
  if (d < 0) return;
  Candidato c = candidatos.get(d);
  float[] q = puntos.get(punto).cara;
  float cx = (q[0] + q[2] + q[4] + q[6]) / 4, cy = (q[1] + q[3] + q[5] + q[7]) / 4;
  noStroke();
  fill(c.col);
  beginShape();
  for (int k = 0; k < 4; k++) vertex(lerp(q[2 * k], cx, 0.08), lerp(q[2 * k + 1], cy, 0.08));
  endShape(CLOSE);
  // franja clara arriba, como la foto del candidato en el volante
  fill(c.claro);
  beginShape();
  vertex(lerp(q[6], q[0], 0.2) * 0.75 + cx * 0.25, lerp(q[7], q[1], 0.2) * 0.75 + cy * 0.25);
  vertex(lerp(q[4], q[2], 0.2) * 0.75 + cx * 0.25, lerp(q[5], q[3], 0.2) * 0.75 + cy * 0.25);
  vertex(lerp(q[4], q[2], 0.5) * 0.75 + cx * 0.25, lerp(q[5], q[3], 0.5) * 0.75 + cy * 0.25);
  vertex(lerp(q[6], q[0], 0.5) * 0.75 + cx * 0.25, lerp(q[7], q[1], 0.5) * 0.75 + cy * 0.25);
  endShape(CLOSE);
}
