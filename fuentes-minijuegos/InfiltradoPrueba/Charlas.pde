// Conversaciones que se pueden escuchar. Cuando dos personas tranquilas
// (vigilantes o empleados) se cruzan y hay un jugador cerca, se detienen a
// hablar. Si el jugador esta a menos de RADIO_ESCUCHA cuando dicen algo
// util, se queda con la pista (por ejemplo, la mitad del codigo).
// Cada charla se dice una sola vez por mision.

final float RADIO_ESCUCHA = 6;
final float DISTANCIA_CHARLA = 2.2;
final float SEGUNDOS_POR_LINEA = 3.2;
final float PAUSA_ENTRE_CHARLAS = 20;

// Pistas que puede dar una charla
final int PISTA_NINGUNA = 0;
final int PISTA_CODIGO = 1;      // los dos ultimos digitos del codigo
final int PISTA_AMARILLA = 2;    // donde esta la tarjeta amarilla
final int PISTA_ROJA = 3;        // donde esta la tarjeta roja

class Charla {
  String[] lineas;   // se alternan: la primera la dice "a", la segunda "b"...
  int pista;
  int lineaPista;    // en que linea se da la pista

  Charla(int pista, int lineaPista, String... lineas) {
    this.pista = pista;
    this.lineaPista = lineaPista;
    this.lineas = lineas;
  }
}

ArrayList<Charla> charlasPendientes = new ArrayList<Charla>();
Charla charlaActual;
Persona hablaA, hablaB;
float tiempoCharla;          // segundos desde que empezo la charla actual
float esperaCharla;          // pausa hasta la siguiente
boolean pistaAmarilla, pistaRoja;   // ya se escucharon esas pistas

void prepararCharlas() {
  charlasPendientes.clear();
  charlaActual = null;
  hablaA = null;
  hablaB = null;
  esperaCharla = 5;
  pistaAmarilla = false;
  pistaRoja = false;
  String fin = "" + codigoServidor.charAt(2) + codigoServidor.charAt(3);
  charlasPendientes.add(new Charla(PISTA_CODIGO, 1,
    "¿Cambiaron el código del cuarto del servidor?",
    "No, sigue terminando en " + fin + ". El resto lo anotaron en el archivo.",
    "Qué seguridad tan seria la de esta empresa..."));
  charlasPendientes.add(new Charla(PISTA_AMARILLA, 1,
    "¿Quién tiene la tarjeta de la oficina del jefe?",
    "La dejaron en el descanso, al lado de la cafetera.",
    "Siempre la dejan ahí."));
  charlasPendientes.add(new Charla(PISTA_NINGUNA, 0,
    "El jefe de seguridad mira a todo el mundo de cerca.",
    "Sí, a él no se le escapa ni un conserje nuevo."));
  charlasPendientes.add(new Charla(PISTA_ROJA, 1,
    "La puerta de carga del parqueadero solo abre con la roja.",
    "La roja quedó en la caseta de afuera.",
    "Alguien la va a perder un día."));
  charlasPendientes.add(new Charla(PISTA_NINGUNA, 0,
    "Si la central llama y no contestas, mandan a todos.",
    "Por eso nunca suelto la radio."));
}

// Puede hablar si esta tranquilo (ni buscando, ni noqueado, ni huyendo)
boolean puedeCharlar(Persona p) {
  if (p.inconsciente) return false;
  if (p instanceof Vigilante) return ((Vigilante) p).estado == V_PATRULLA;
  return ((Civil) p).estado == C_TRABAJANDO;
}

boolean estaCharlando(Persona p) {
  return charlaActual != null && (p == hablaA || p == hablaB);
}

boolean jugadorCerca(float x, float y, float radio) {
  for (Jugador j : jugadores) {
    if (!j.enDucto && dist(j.x, j.y, x, y) <= radio) return true;
  }
  return false;
}

void actualizarCharlas(float dt) {
  if (charlaActual != null) {
    // si a alguno lo asustan o lo noquean, la charla se corta
    if (!puedeCharlar(hablaA) || !puedeCharlar(hablaB)) {
      terminarCharla();
      return;
    }
    int antes = floor(tiempoCharla / SEGUNDOS_POR_LINEA);
    tiempoCharla += dt;
    int ahora = floor(tiempoCharla / SEGUNDOS_POR_LINEA);
    // al empezar la linea con la pista, se la lleva quien la oiga
    if (ahora != antes) revisarPista(ahora);
    if (ahora >= charlaActual.lineas.length) terminarCharla();
    return;
  }
  esperaCharla -= dt;
  if (esperaCharla > 0 || charlasPendientes.size() == 0) return;
  // busca dos personas tranquilas juntas con un jugador cerca
  ArrayList<Persona> gente = personas();
  for (int a = 0; a < gente.size(); a++) {
    for (int b = a + 1; b < gente.size(); b++) {
      Persona p = gente.get(a);
      Persona q = gente.get(b);
      if (!puedeCharlar(p) || !puedeCharlar(q)) continue;
      if (dist(p.x, p.y, q.x, q.y) > DISTANCIA_CHARLA) continue;
      if (!jugadorCerca((p.x + q.x) / 2, (p.y + q.y) / 2, RADIO_ESCUCHA)) continue;
      empezarCharla(p, q);
      return;
    }
  }
}

void empezarCharla(Persona p, Persona q) {
  charlaActual = charlasPendientes.remove(0);
  hablaA = p;
  hablaB = q;
  tiempoCharla = 0;
  // se miran
  p.angulo = atan2(q.y - p.y, q.x - p.x);
  q.angulo = atan2(p.y - q.y, p.x - q.x);
}

void terminarCharla() {
  charlaActual = null;
  hablaA = null;
  hablaB = null;
  esperaCharla = PAUSA_ENTRE_CHARLAS;
}

void revisarPista(int linea) {
  if (charlaActual == null || linea != charlaActual.lineaPista) return;
  // un poco de margen: si te alejaste un paso igual alcanzas a oirlo
  if (!jugadorCerca((hablaA.x + hablaB.x) / 2, (hablaA.y + hablaB.y) / 2, RADIO_ESCUCHA + 2)) return;
  int p = charlaActual.pista;
  if (p == PISTA_CODIGO) {
    conocerDigitos(2, 3, "Escuchaste los dos últimos dígitos del código");
    if (!digitoConocido[0]) resaltarZona(5, "Los otros dos dígitos están anotados en el archivo");
  }
  if (p == PISTA_AMARILLA && !pistaAmarilla) {
    pistaAmarilla = true;
    resaltarZona(10, "Pista: la tarjeta amarilla está en el descanso");
  }
  if (p == PISTA_ROJA && !pistaRoja) {
    pistaRoja = true;
    resaltarZona(0, "Pista: la tarjeta roja está en la caseta del parqueadero");
  }
}

// Globo con lo que se dice ahora, encima de quien habla
void dibujarCharla() {
  if (charlaActual == null) return;
  int k = floor(tiempoCharla / SEGUNDOS_POR_LINEA);
  if (k >= charlaActual.lineas.length) return;
  Persona quien = k % 2 == 0 ? hablaA : hablaB;
  // la charla solo empieza con un jugador cerca, asi que siempre se lee
  String texto = charlaActual.lineas[k];
  float sx = pantallaX(quien.x, quien.y);
  float sy = pantallaY(quien.x, quien.y) - 40 * pixel;
  textFont(letraChica);
  float w = textWidth(texto) + 20 * escala;
  float h = 24 * escala;
  float x0 = constrain(sx - w / 2, 8 * escala, width - w - 8 * escala);
  stroke(242, 242, 233, 160);
  strokeWeight(1);
  fill(242, 242, 233, 235);
  rect(x0, sy - h, w, h, 8 * escala);
  noStroke();
  triangle(sx - 5 * escala, sy - 1, sx + 5 * escala, sy - 1, sx, sy + 6 * escala);
  fill(COLOR_FONDO);
  textAlign(CENTER, CENTER);
  text(texto, x0 + w / 2, sy - h / 2 - 1 * escala);
  // pista resaltada: que se note que eso sirve
  if (k == charlaActual.lineaPista && charlaActual.pista != PISTA_NINGUNA) {
    noFill();
    stroke(NEON_VERDE);
    strokeWeight(2 * escala);
    rect(x0 - 2 * escala, sy - h - 2 * escala, w + 4 * escala, h + 4 * escala, 9 * escala);
  }
}
