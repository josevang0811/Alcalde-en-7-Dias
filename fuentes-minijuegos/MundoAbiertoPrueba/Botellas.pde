// Botellas: cada candidato empieza la ronda con las mismas y las lanza cuando
// quiere. Al que le pega se queda quieto un rato y no puede pegar volantes.

final int BOTELLAS_INICIO = 3;
final float TIEMPO_ATURDIDO = 2.0;
final float VELOCIDAD_BOTELLA = 9.0;   // baldosas por segundo
final float ALCANCE_BOTELLA = 7.0;
final float ESPERA_LANZAR = 0.6;       // entre una botella y otra

ArrayList<Botella> botellasVolando = new ArrayList<Botella>();
ArrayList<Particula> particulas = new ArrayList<Particula>();
ArrayList<TextoFlotante> textosFlotantes = new ArrayList<TextoFlotante>();
float[] esperaLanzar = new float[8];

class Botella extends Movil {
  float x, y, vx, vy, recorrido;
  int dueno;
  boolean viva = true;

  Botella(Candidato c, float dx, float dy) {
    float l = sqrt(dx * dx + dy * dy);
    vx = dx / l * VELOCIDAD_BOTELLA;
    vy = dy / l * VELOCIDAD_BOTELLA;
    x = c.x + vx / VELOCIDAD_BOTELLA * 0.3;
    y = c.y + vy / VELOCIDAD_BOTELLA * 0.3;
    dueno = c.id;
  }

  public float px() {
    return x;
  }

  public float py() {
    return y;
  }

  void actualizar(float dt) {
    int pasos = 4;
    for (int k = 0; k < pasos && viva; k++) {
      x += vx * dt / pasos;
      y += vy * dt / pasos;
      recorrido += VELOCIDAD_BOTELLA * dt / pasos;
      for (Candidato c : candidatos) {
        if (c.id == dueno || c.aturdido > 0) continue;
        if (dist(x, y, c.x, c.y) < 0.5) {
          c.aturdido = TIEMPO_ATURDIDO;
          c.progresoPegar = 0;
          romper();
          efectoTexto(c.x, c.y, "¡PUM!", color(250, 246, 236));
          avisarA(c, candidatos.get(dueno).nombre + " te pegó un botellazo");
          avisarA(candidatos.get(dueno), "¡Le pegaste a " + c.nombre + "!");
          return;
        }
      }
      if (!libre(x, y, 0.05) || recorrido >= ALCANCE_BOTELLA) romper();
    }
  }

  void romper() {
    viva = false;
    efectoVidrio(x, y);
  }

  // Vuela en arco: más alto a la mitad del recorrido
  public void dibujar() {
    float t = constrain(recorrido / ALCANCE_BOTELLA, 0, 1);
    float z = 12 + 16 * 4 * t * (1 - t) - 10 * t;
    float sx = pantallaX(x, y), sy = pantallaY(x, y);
    noStroke();
    fill(40, 34, 60, 70);
    ellipse(sx, sy, 6, 2.5);
    pushMatrix();
    translate(sx, sy - z);
    rotate(recorrido * 4);
    fill(43, 30, 26);
    rect(-2.2, -4.6, 4.4, 9.2);
    rect(-1.3, -7, 2.6, 3);
    fill(76, 156, 98);
    rect(-1.5, -4, 3, 8);
    fill(160, 220, 180);
    rect(-0.8, -6.4, 1.6, 2.4);
    rect(-1, -3, 0.8, 4);
    popMatrix();
  }
}

// Lanza hacia (dx, dy) en baldosas. Devuelve false si no puede.
boolean lanzarBotella(Candidato c, float dx, float dy) {
  if (c.botellas <= 0 || c.aturdido > 0 || esperaLanzar[c.id] > 0) return false;
  if (dx * dx + dy * dy < 0.0001) return false;
  c.botellas--;
  esperaLanzar[c.id] = ESPERA_LANZAR;
  c.mirarHacia(c.x + dx, c.y + dy);
  botellasVolando.add(new Botella(c, dx, dy));
  // el invitado ya lo oyó al oprimir Q (Bots y otros: según la distancia)
  if (modoRed != INVITADO) sonarEn("lanzar", c.x, c.y);
  return true;
}

// Una persona lanza hacia donde mira; si hay un rival más o menos en esa
// dirección y a tiro, la botella se le apunta a él.
void lanzarDe(Candidato yo) {
  float mejor = radians(35);
  Candidato blanco = null;
  for (Candidato c : candidatos) {
    if (c == yo || c.aturdido > 0) continue;
    float dx = c.x - yo.x, dy = c.y - yo.y;
    float d = sqrt(dx * dx + dy * dy);
    if (d > ALCANCE_BOTELLA || d < 0.1) continue;
    float a = acos(constrain((dx * yo.dirX + dy * yo.dirY) / d, -1, 1));
    if (a < mejor) {
      mejor = a;
      blanco = c;
    }
  }
  if (blanco != null) lanzarBotella(yo, blanco.x - yo.x, blanco.y - yo.y);
  else lanzarBotella(yo, yo.dirX, yo.dirY);
}

void actualizarBotellas(float dt) {
  for (int k = 0; k < esperaLanzar.length; k++) esperaLanzar[k] = max(0, esperaLanzar[k] - dt);
  for (int k = botellasVolando.size() - 1; k >= 0; k--) {
    Botella b = botellasVolando.get(k);
    b.actualizar(dt);
    if (!b.viva) botellasVolando.remove(k);
  }
  for (Candidato c : candidatos) c.aturdido = max(0, c.aturdido - dt);
  for (int k = particulas.size() - 1; k >= 0; k--) {
    if (!particulas.get(k).actualizar(dt)) particulas.remove(k);
  }
  for (int k = textosFlotantes.size() - 1; k >= 0; k--) {
    if (!textosFlotantes.get(k).actualizar(dt)) textosFlotantes.remove(k);
  }
}

// ---------------------------------------------------------------------------
// Efectos: papelitos, vidrios y textos que suben
// ---------------------------------------------------------------------------

class Particula {
  float x, y, vx, vy, vida, total, tam;
  color col;

  Particula(float x, float y, float vx, float vy, float vida, color col, float tam) {
    this.x = x;
    this.y = y;
    this.vx = vx;
    this.vy = vy;
    this.vida = this.total = vida;
    this.col = col;
    this.tam = tam;
  }

  boolean actualizar(float dt) {
    x += vx * dt;
    y += vy * dt;
    vy += 160 * dt;
    vida -= dt;
    return vida > 0;
  }

  void dibujar() {
    noStroke();
    fill(col, 255 * constrain(vida / total * 1.5, 0, 1));
    rect(x - tam / 2, y - tam / 2, tam, tam);
  }
}

class TextoFlotante {
  float x, y, vida = 1.1;
  String texto;
  color col;

  TextoFlotante(float x, float y, String texto, color col) {
    this.x = x;
    this.y = y;
    this.texto = texto;
    this.col = col;
  }

  boolean actualizar(float dt) {
    vida -= dt;
    return vida > 0;
  }
}
