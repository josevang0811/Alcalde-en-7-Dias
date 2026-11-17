// Los candidatos: el jugador y los rivales que maneja el computador (Bots.pde).
// Todos caminan igual, chocan con lo mismo, pegan volantes y lanzan botellas.

final float RADIO_PERSONA = 0.22;   // en baldosas
final float VELOCIDAD_CAMINAR = 3.0;
final float VELOCIDAD_CORRER = 5.2;

ArrayList<Candidato> candidatos = new ArrayList<Candidato>();

class Candidato extends Movil {
  int id;
  String nombre;
  color col, claro;
  float x, y;                // pies, en baldosas
  float inicioX, inicioY;    // de dónde sale
  float dirX = 1, dirY = 1;  // hacia dónde mira (en baldosas)
  boolean moviendose, corriendo;
  PImage[] frente = new PImage[3];
  PImage[] espalda = new PImage[3];
  int botellas;
  float aturdido;            // segundos que le quedan quieto por un botellazo
  float progresoPegar;       // 0 a 1 mientras mantiene pegando
  int puntoPegando = -1;
  int ultimoLogro;           // millis del último volante (desempata la lista)
  float filaLista = -1;      // posición animada en la lista en vivo
  Bot bot;                   // null si es el jugador
  float trabadoCarro;        // segundos sin poder pasar por un carro

  Candidato(int id, String nombre, color col, String sprites, float x, float y) {
    this.id = id;
    this.nombre = nombre;
    this.col = col;
    this.claro = lerpColor(col, color(255), 0.45);
    this.x = this.inicioX = x;
    this.y = this.inicioY = y;
    for (int k = 0; k < 3; k++) {
      frente[k] = loadImage("personas/" + sprites + "_frente_" + k + ".png");
      espalda[k] = loadImage("personas/" + sprites + "_espalda_" + k + ".png");
    }
  }

  boolean esJugador() {
    return bot == null;
  }

  public float px() {
    return x;
  }

  public float py() {
    return y;
  }

  // gx, gy: hacia dónde quiere ir, en baldosas (no hace falta que midan 1)
  void mover(float dt, float gx, float gy, boolean correr) {
    moviendose = false;
    corriendo = false;
    if (aturdido > 0) return;
    float largo = sqrt(gx * gx + gy * gy);
    if (largo < 0.001) return;
    gx /= largo;
    gy /= largo;
    corriendo = correr;
    float velocidad = correr ? VELOCIDAD_CORRER : VELOCIDAD_CAMINAR;
    if (bot != null) velocidad *= bot.factorVelocidad();
    // por separado en x y en y para poder deslizarse por las paredes
    float dx = gx * velocidad * dt;
    float dy = gy * velocidad * dt;
    // los carros estorban, pero si uno se queda trabado más de un segundo pasa
    boolean conCarros = trabadoCarro < 1.2;
    boolean movio = false;
    if (libre(x + dx, y, RADIO_PERSONA) && !(conCarros && personaChocaCarro(x + dx, y))) {
      x += dx;
      movio = true;
    }
    if (libre(x, y + dy, RADIO_PERSONA) && !(conCarros && personaChocaCarro(x, y + dy))) {
      y += dy;
      movio = true;
    }
    if (!movio && (personaChocaCarro(x + dx, y) || personaChocaCarro(x, y + dy))) trabadoCarro += dt;
    else if (movio && !personaChocaCarro(x, y)) trabadoCarro = 0;
    dirX = gx;
    dirY = gy;
    moviendose = true;
  }

  void mirarHacia(float tx, float ty) {
    float dx = tx - x, dy = ty - y;
    float l = sqrt(dx * dx + dy * dy);
    if (l > 0.01) {
      dirX = dx / l;
      dirY = dy / l;
    }
  }

  // Se dibuja dentro de la transformación de la ciudad (pixeles del dibujo)
  public void dibujar() {
    if (this == yo && manejando != null) return;   // va dentro del carro
    float sx = round(pantallaX(x, y));
    float sy = round(pantallaY(x, y));
    float mx = dirX - dirY;
    float my = (dirX + dirY) * 0.5;
    int cuadro = moviendose ? 1 + (millis() / (corriendo ? 110 : 160)) % 2 : 0;
    PImage img = my < -0.05 ? espalda[cuadro] : frente[cuadro];
    // anillo del color del candidato bajo los pies
    noStroke();
    fill(40, 34, 60, 80);
    ellipse(sx, sy, 15, 6);
    noFill();
    stroke(col);
    strokeWeight(1.2);
    ellipse(sx, sy, 17, 7.5);
    noStroke();
    pushMatrix();
    translate(sx, sy);
    if (mx > 0) scale(-1, 1);
    if (aturdido > 0) tint(255, 200, 200);
    image(img, -8, -27);
    noTint();
    popMatrix();
  }
}

// ---------------------------------------------------------------------------
// Teclado del jugador
// ---------------------------------------------------------------------------

boolean tArriba, tAbajo, tIzquierda, tDerecha, tCorrer, tPegar;

void teclaCambio(boolean bajando) {
  char k = Character.toLowerCase(key);
  if (key == CODED) {
    if (keyCode == UP) tArriba = bajando;
    if (keyCode == DOWN) tAbajo = bajando;
    if (keyCode == LEFT) tIzquierda = bajando;
    if (keyCode == RIGHT) tDerecha = bajando;
    if (keyCode == SHIFT) tCorrer = bajando;
    return;
  }
  if (k == 'w') tArriba = bajando;
  if (k == 's') tAbajo = bajando;
  if (k == 'a') tIzquierda = bajando;
  if (k == 'd') tDerecha = bajando;
  if (k == 'e') tPegar = bajando;
}
