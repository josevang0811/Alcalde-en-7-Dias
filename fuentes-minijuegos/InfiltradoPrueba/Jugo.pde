// "Jugo": lo que hace que cada accion se sienta. Temblor de pantalla, texto
// que flota y se desvanece, y chispas de colores.

float temblor;            // fuerza del temblor (en pixeles del arte), baja sola
ArrayList<TextoFlotante> textosFlotantes = new ArrayList<TextoFlotante>();

class TextoFlotante {
  float x, y;             // en la cuadricula
  String texto;
  color c;
  float vida = 1.3;

  TextoFlotante(float x, float y, String texto, color c) {
    this.x = x;
    this.y = y;
    this.texto = texto;
    this.c = c;
  }
}

void sacudir(float fuerza) {
  temblor = max(temblor, fuerza);
}

void textoFlotante(float x, float y, String texto, color c) {
  textosFlotantes.add(new TextoFlotante(x, y, texto, c));
}

void chispas(float x, float y, color c, int n) {
  for (int k = 0; k < n; k++) {
    Particula p = new Particula(x, y);
    p.c = c;
    particulas.add(p);
  }
}

void actualizarJugo(float dt) {
  temblor = max(0, temblor - dt * 18);
  for (int k = textosFlotantes.size() - 1; k >= 0; k--) {
    TextoFlotante t = textosFlotantes.get(k);
    t.vida -= dt;
    if (t.vida <= 0) textosFlotantes.remove(k);
  }
}

// Se aplica antes de dibujar el mundo
void aplicarTemblor() {
  if (temblor <= 0) return;
  translate(round(random(-temblor, temblor)) * pixel * 0.5, round(random(-temblor, temblor)) * pixel * 0.5);
}

void dibujarTextosFlotantes() {
  textFont(letraMedia);
  textAlign(CENTER, CENTER);
  for (TextoFlotante t : textosFlotantes) {
    float u = 1 - t.vida / 1.3;
    float sx = pantallaX(t.x, t.y);
    float sy = pantallaY(t.x, t.y) - 34 * pixel - u * 24 * pixel;
    float a = 255 * min(1, t.vida / 0.4);
    fill(0, a * 0.6);
    text(t.texto, sx + 1 * escala, sy + 1 * escala);
    fill(red(t.c), green(t.c), blue(t.c), a);
    text(t.texto, sx, sy);
  }
}
