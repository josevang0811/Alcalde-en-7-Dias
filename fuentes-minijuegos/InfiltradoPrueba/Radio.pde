// Radio de los vigilantes. Poco despues de noquear a uno, la central lo
// llama. Si nadie contesta a tiempo, sube la alarma y mandan gente a revisar.
// Para contestar hay que acercarse al cuerpo y repetir una secuencia de
// direcciones (el jugador "imita" la voz del vigilante con calma).
// La central acepta pocas excusas: despues de MAX_RADIOS ya no se las cree.

final float ESPERA_RADIO = 4;     // segundos desde el golpe hasta que suena
final float TIEMPO_RADIO = 12;    // segundos que suena antes de que la central sospeche
final int MAX_RADIOS = 3;
final int LARGO_SECUENCIA = 4;
int radiosContestadas;

// Lo que dice la central (se elige uno al azar)
String[] LLAMADAS = {
  "Unidad, reporte su posición.",
  "¿Todo en orden por ahí?",
  "Oímos un golpe en su zona. Confirme.",
  "Control de rutina. Responda."
};
String[] RESPUESTAS = {
  "Todo tranquilo, central.",
  "Sin novedad. Fue una caja que se cayó.",
  "Aquí todo en orden.",
  "Sigo la ronda, sin novedad."
};

void sonarRadio(Vigilante v) {
  v.radioSonando = TIEMPO_RADIO;
  v.tiempoPitido = 0;
  avisar("Suena la radio del vigilante. Contéstala antes de que la central sospeche");
}

// Se llama desde Vigilante.actualizarRadio mientras esta noqueado
void actualizarRadioDe(Vigilante v, float dt) {
  if (v.radioTerminada) return;
  if (v.esperaRadio > 0) {
    v.esperaRadio -= dt;
    if (v.esperaRadio <= 0) sonarRadio(v);
    return;
  }
  if (v.radioSonando < 0) return;
  v.radioSonando -= dt;
  v.tiempoPitido -= dt;
  if (v.tiempoPitido <= 0) {
    v.tiempoPitido = 1.5;
    hacerRuido(v.x, v.y, 1.2);   // el pitido se oye de cerca
    sonar("radio");
  }
  if (v.radioSonando <= 0) falloRadio(v, "Nadie contestó la radio. La central manda a revisar");
}

void falloRadio(Vigilante v, String motivo) {
  sonar("estatica");
  v.radioSonando = -1;
  v.radioTerminada = true;
  for (Jugador j : jugadores) {
    if (j.contestando == v) j.contestando = null;
  }
  subirAlarma(motivo);
  for (Vigilante otro : vigilantes) {
    if (otro != v) otro.alarma(v.x, v.y);
  }
}

// Vigilante cuya radio suena cerca del jugador (o null)
Vigilante radioCercana(Jugador j) {
  for (Vigilante v : vigilantes) {
    if (v.inconsciente && v.radioSonando > 0 && dist(v.x, v.y, j.x, j.y) < 1.5) return v;
  }
  return null;
}

void contestarRadio(Jugador j, Vigilante v) {
  if (radiosContestadas >= maxRadios()) {
    falloRadio(v, "La central ya no te cree: reconoció que no es su vigilante");
    return;
  }
  if (j.arrastrando != null) soltarCuerpo(j);
  j.contestando = v;
  j.pasoRadio = 0;
  j.secuenciaRadio = new int[largoSecuenciaRadio(j)];
  for (int k = 0; k < j.secuenciaRadio.length; k++) j.secuenciaRadio[k] = int(random(4));
  j.llamada = int(random(LLAMADAS.length));
  j.agachado = false;
}

// dir: 0 arriba, 1 derecha, 2 abajo, 3 izquierda
void teclaRadio(Jugador j, int dir) {
  Vigilante v = j.contestando;
  if (v == null) return;
  if (dir != j.secuenciaRadio[j.pasoRadio]) {
    j.contestando = null;
    falloRadio(v, "Titubeaste en la radio. La central sospecha");
    return;
  }
  j.pasoRadio++;
  if (j.pasoRadio >= j.secuenciaRadio.length) {
    j.contestando = null;
    v.radioSonando = -1;
    v.radioTerminada = true;
    radiosContestadas++;
    String extra = radiosContestadas >= maxRadios() ? " La central no aceptará otra excusa." : "";
    avisar("\"" + RESPUESTAS[j.llamada] + "\" La central se lo creyó." + extra);
    sonar("radio_ok");
    textoFlotante(j.x, j.y, "Sin novedad", NEON_VERDE);
  }
}

// Cuadro del minijuego encima del jugador que contesta
void dibujarRadios() {
  for (Jugador j : jugadores) {
    Vigilante v = j.contestando;
    if (v == null) continue;
    float w = 330 * escala;
    float h = 112 * escala;
    // abajo al centro (en cooperativo, cada uno de su lado)
    float x = width / 2 - w / 2;
    if (jugadores.size() > 1) x = j.numero == 1 ? width / 2 - w - 10 * escala : width / 2 + 10 * escala;
    float y = height * 0.62;
    stroke(COLOR_AMBAR);
    strokeWeight(1.5 * escala);
    fill(11, 14, 26, 240);
    rect(x, y, w, h, 4 * escala);
    textFont(letraChica);
    textAlign(LEFT, TOP);
    fill(COLOR_AMBAR);
    text("RADIO · CENTRAL", x + 12 * escala, y + 10 * escala);
    fill(242, 242, 233);
    text("\"" + LLAMADAS[j.llamada] + "\"", x + 12 * escala, y + 28 * escala);
    // secuencia de flechas
    float lado = 34 * escala;
    float sep = 12 * escala;
    int largo = j.secuenciaRadio.length;
    float x0 = x + (w - (largo * lado + (largo - 1) * sep)) / 2;
    float y0 = y + 52 * escala;
    for (int k = 0; k < largo; k++) {
      float bx = x0 + k * (lado + sep);
      boolean hecha = k < j.pasoRadio;
      boolean actual = k == j.pasoRadio;
      stroke(hecha ? NEON_VERDE : (actual ? COLOR_AMBAR : color(90, 100, 130)));
      strokeWeight((actual ? 2 : 1) * escala);
      fill(hecha ? color(61, 220, 132, 60) : color(20, 26, 46));
      rect(bx, y0, lado, lado, 3 * escala);
      flecha(bx + lado / 2, y0 + lado / 2, j.secuenciaRadio[k], hecha ? NEON_VERDE : color(242, 242, 233));
    }
    // tiempo que queda
    float u = constrain(v.radioSonando / TIEMPO_RADIO, 0, 1);
    noStroke();
    fill(40, 46, 70);
    rect(x + 12 * escala, y + h - 14 * escala, w - 24 * escala, 4 * escala);
    fill(u > 0.35 ? COLOR_AMBAR : COLOR_RIVAL);
    rect(x + 12 * escala, y + h - 14 * escala, (w - 24 * escala) * u, 4 * escala);
    textAlign(RIGHT, TOP);
    fill(150, 160, 190);
    text(j.numero == 1 ? "WASD" : "Flechas", x + w - 12 * escala, y + 10 * escala);
  }
}

void flecha(float x, float y, int dir, color c) {
  pushMatrix();
  translate(x, y);
  rotate(dir * HALF_PI);
  noStroke();
  fill(c);
  float s = 7 * escala;
  triangle(0, -s * 1.3, -s, 0, s, 0);
  rect(-s * 0.35, 0, s * 0.7, s * 1.1);
  popMatrix();
}

// Radio que parpadea encima del cuerpo, con el tiempo que le queda
void iconoRadio(Vigilante v) {
  float sx = pantallaX(v.x, v.y) + 8 * pixel;
  float sy = pantallaY(v.x, v.y) - (v.cuerpoEscondido ? 34 : 20) * pixel;
  boolean prendido = (millis() / 250) % 2 == 0;
  medidor(sx, sy, 100 * v.radioSonando / TIEMPO_RADIO, COLOR_AMBAR);
  noStroke();
  fill(15, 20, 36, 230);
  ellipse(sx, sy, 20 * escala, 20 * escala);
  fill(prendido ? COLOR_AMBAR : color(120, 90, 40));
  rect(sx - 4 * escala, sy - 5 * escala, 8 * escala, 11 * escala, 1 * escala);
  rect(sx + 1 * escala, sy - 10 * escala, 2 * escala, 5 * escala);
  fill(COLOR_FONDO);
  rect(sx - 2 * escala, sy - 3 * escala, 4 * escala, 3 * escala);
}
