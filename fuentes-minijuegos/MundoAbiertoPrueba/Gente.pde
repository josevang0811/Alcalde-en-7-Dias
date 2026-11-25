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
    if (c == yo) errorConversacion = millis();   // se ve en el panel (dibujarSecuenciaJugador)
    else avisarA(c, evento == LIVES ? "¡Esa respuesta empeora las cosas! La conversación vuelve a empezar" : "Flecha equivocada: la secuencia vuelve a empezar");
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

// La secuencia del jugador, encima del ciudadano. En vez de flechas, cada
// paso es una conversación: el ciudadano cuenta lo que le llegó y alrededor
// salen cuatro palabras, una en cada dirección (arriba, derecha, abajo,
// izquierda). Solo una es la respuesta responsable; las otras tres son lo que
// hace que el problema crezca. Se elige con las mismas teclas (flechas o
// WASD) o con el gesto de la mano: la dirección de la palabra es la tecla.
// Por dentro sigue siendo la misma cola de direcciones (marcarFlecha), así
// que los bots y el juego en red no cambian.

// situación | palabra correcta | tres palabras que empeoran las cosas
final String[][] CONVERSACIONES = {
  {"ME LLEGÓ UN AUDIO: DICE QUE EL ALCALDE ROBA", "BUSCA LA FUENTE", "REENVÍALO YA", "CRÉELO Y YA", "INSULTA AL ALCALDE"},
  {"EN UN GRUPO SE BURLAN DE MI HIJO", "DENÚNCIALO", "ÚNETE A LA BURLA", "NO ES PARA TANTO", "BÚRLATE DE ELLOS"},
  {"UN PERFIL SIN FOTO ME PIDE MI CLAVE", "NO SE LA DES", "DÁSELA RÁPIDO", "MÁNDALE TUS DATOS", "AGRÉGALO"},
  {"ESTA FOTO DEL CANDIDATO PARECE EDITADA", "BUSCA EL ORIGINAL", "COMPÁRTELA", "CRÉELA ASÍ", "BÚRLATE DE ÉL"},
  {"DICEN QUE LA GENTE DEL PUERTO ES LADRONA", "NO GENERALICES", "REPÍTELO", "ÚNETE AL ODIO", "SEÑALA A ALGUIEN"},
  {"ME DICEN QUE GANÉ UN PREMIO SI DOY UN CÓDIGO", "ES UNA ESTAFA", "DA EL CÓDIGO", "¡QUÉ SUERTE!", "PÁSALO A OTROS"},
  {"HAY UN RETO VIRAL QUE ES PELIGROSO", "NO LO HAGAS", "GRÁBATE HACIÉNDOLO", "RETA A TUS AMIGOS", "SÚBELO YA"},
  {"PUBLICARON DÓNDE VIVE MI VECINA", "REPÓRTALO", "COMPÁRTELO", "NO ES PROBLEMA", "AGREGA MÁS DATOS"},
};

int errorConversacion = -10000;   // cuándo eligió mal el jugador

// La conversación que toca en el paso k de la secuencia con ese ciudadano
String[] conversacionDe(Ciudadano z, int k) {
  int base = abs(ciudadanos.indexOf(z) * 5);
  return CONVERSACIONES[(base + k * 3) % CONVERSACIONES.length];
}

void dibujarSecuenciaJugador() {
  Ciudadano z = secuenciaCon.get(yo.id);
  java.util.ArrayDeque<Integer> cola = secuencias.get(yo.id);
  if (z == null || cola == null || cola.isEmpty()) return;
  int largo = largoSecuencia();
  int hechas = largo - cola.size();
  boolean seEquivoco = millis() - errorConversacion < 1400;
  if (evento != LIVES) {
    dibujarFlechasJugador(z, cola, largo, hechas, seEquivoco);   // en la ronda de la gente, solo flechas
    return;
  }
  int f = cola.peek();                 // la dirección de la palabra correcta
  String[] conv = conversacionDe(z, hechas);
  // las palabras en su lugar: la correcta en la dirección f, las otras en las demás
  String[] palabras = new String[4];
  int mala = 2;
  for (int d = 0; d < 4; d++) {
    palabras[d] = d == f ? conv[1] : conv[mala++];
  }
  // abajo: las respuestas que ya dio (si no caben, solo las últimas)
  java.util.ArrayList<String> dadas = new java.util.ArrayList<String>();
  for (int k = 0; k < hechas; k++) {
    dadas.add(conversacionDe(z, k)[1]);
  }
  String abajo = seEquivoco ? "ESA RESPUESTA EMPEORA LAS COSAS" : (hechas == 0 ? "ELIGE LA RESPUESTA RESPONSABLE · F PARA DEJARLO" : String.join(" · ", dadas));
  // El panel se mide con lo que lleva adentro, para que ningún texto se salga
  float pad = 8 * pixel;
  textFont(fuente, 7 * pixel);
  String situacion = "«" + conv[0] + "»";
  float anchoSituacion = textWidth(situacion);
  textFont(fuenteNegrita, 8 * pixel);
  float[] anchoPalabra = new float[4];
  for (int d = 0; d < 4; d++) {
    anchoPalabra[d] = textWidth(palabras[d]) + 10 * pixel;
  }
  float lado = max(anchoPalabra[1], anchoPalabra[3]);
  float separacion = max(58 * pixel, lado / 2 + 20 * pixel);   // del centro a las palabras de los lados
  float anchoCruz = separacion * 2 + lado;
  float anchoMax = width - 12 * pixel;
  textFont(fuente, 7 * pixel);
  while (dadas.size() > 1 && textWidth(abajo) + pad * 2 > anchoMax) {
    dadas.remove(0);
    abajo = "… " + String.join(" · ", dadas);
  }
  float ancho = min(anchoMax, max(max(anchoSituacion, textWidth(abajo)) + pad * 2, max(anchoCruz + pad, 196 * pixel)));
  float alto = 96 * pixel;
  float sx = aPantallaX(pantallaX(z.x, z.y));
  float sy = aPantallaY(pantallaY(z.x, z.y) - 40) - alto;   // el panel termina encima de la cabeza
  float x0 = constrain(sx - ancho / 2, 6 * pixel, width - ancho - 6 * pixel);
  float y0 = max(6 * pixel, sy);
  float cx = x0 + ancho / 2;
  caja(x0, y0, ancho, alto, 232);
  if (seEquivoco) {
    noFill();
    stroke(216, 58, 52);
    strokeWeight(2 * pixel);
    rect(x0, y0, ancho, alto, 4 * pixel);
    noStroke();
  }
  // lo que le llegó al ciudadano
  textAlign(CENTER, CENTER);
  fill(CREMA, 200);
  text(situacion, cx, y0 + 10 * pixel);
  // la cruz de palabras: arriba, derecha, abajo, izquierda
  float cy = y0 + 46 * pixel;
  float[][] lugar = {{0, -17 * pixel}, {separacion, 0}, {0, 17 * pixel}, {-separacion, 0}};
  textFont(fuenteNegrita, 8 * pixel);
  for (int d = 0; d < 4; d++) {
    float px = cx + lugar[d][0], py = cy + lugar[d][1];
    float w = anchoPalabra[d];
    noStroke();
    fill(246, 236, 200, 235);
    rect(px - w / 2, py - 7 * pixel, w, 14 * pixel, 3 * pixel);
    fill(CAFE);
    text(palabras[d], px, py - pixel * 0.5);
  }
  // en el centro, cuántas van
  textFont(fuente, 7 * pixel);
  fill(CREMA, 170);
  text((hechas + 1) + "/" + largo, cx, cy);
  if (seEquivoco) {
    fill(240, 110, 100);
  } else {
    fill(hechas > 0 ? color(150, 220, 160) : color(246, 236, 200, 150));
  }
  text(abajo, cx, y0 + alto - 9 * pixel);
}

// La ronda de la gente: encima del ciudadano, la fila de flechas que hay que
// marcar. Las hechas quedan en verde y la que sigue se resalta.
void dibujarFlechasJugador(Ciudadano z, java.util.ArrayDeque<Integer> cola, int largo, int hechas, boolean seEquivoco) {
  float celda = 18 * pixel, sep = 4 * pixel, pad = 7 * pixel;
  String abajo = seEquivoco ? "TE EQUIVOCASTE: VUELVE A EMPEZAR" : "FLECHAS O WASD · F PARA DEJARLO";
  textFont(fuente, 7 * pixel);
  float fila = largo * celda + (largo - 1) * sep;
  float ancho = max(fila, textWidth(abajo)) + pad * 2;
  float inicioFila = (ancho - fila) / 2;   // las flechas van centradas en el panel
  float alto = celda + pad * 2 + 12 * pixel;
  float sx = aPantallaX(pantallaX(z.x, z.y));
  float sy = aPantallaY(pantallaY(z.x, z.y) - 40) - alto;
  float x0 = constrain(sx - ancho / 2, 6 * pixel, width - ancho - 6 * pixel);
  float y0 = max(6 * pixel, sy);
  caja(x0, y0, ancho, alto, 232);
  if (seEquivoco) {
    noFill();
    stroke(216, 58, 52);
    strokeWeight(2 * pixel);
    rect(x0, y0, ancho, alto, 4 * pixel);
    noStroke();
  }
  Integer[] faltan = cola.toArray(new Integer[0]);
  for (int k = hechas; k < largo; k++) {
    float x = x0 + inicioFila + k * (celda + sep);
    float y = y0 + pad;
    boolean actual = k == hechas;
    if (actual) y -= abs(sin(millis() / 180.0)) * 2 * pixel;   // la que sigue salta un poco
    noStroke();
    fill(actual ? color(246, 236, 200) : color(246, 236, 200, 120));
    rect(x, y, celda, celda, 3 * pixel);
    flechaSecuencia(x + celda / 2, y + celda / 2, celda * 0.32, faltan[k - hechas], actual ? CAFE : color(43, 30, 26, 150));
  }
  for (int k = 0; k < hechas; k++) {
    float x = x0 + inicioFila + k * (celda + sep);
    noStroke();
    fill(90, 170, 100);
    rect(x, y0 + pad, celda, celda, 3 * pixel);
    stroke(CREMA);
    strokeWeight(2 * pixel);
    noFill();
    float cx = x + celda / 2, cy = y0 + pad + celda / 2;
    line(cx - 4 * pixel, cy, cx - pixel, cy + 3 * pixel);
    line(cx - pixel, cy + 3 * pixel, cx + 5 * pixel, cy - 4 * pixel);
    noStroke();
  }
  textFont(fuente, 7 * pixel);
  textAlign(CENTER, CENTER);
  if (seEquivoco) fill(240, 110, 100);
  else fill(246, 236, 200, 170);
  text(abajo, x0 + ancho / 2, y0 + alto - 8 * pixel);
}

// Una flecha (0 arriba, 1 derecha, 2 abajo, 3 izquierda) centrada en (cx, cy)
void flechaSecuencia(float cx, float cy, float r, int dir, color c) {
  pushMatrix();
  translate(cx, cy);
  rotate(HALF_PI * dir);
  noStroke();
  fill(c);
  triangle(0, -r * 1.3, -r * 1.1, -r * 0.1, r * 1.1, -r * 0.1);
  rect(-r * 0.4, -r * 0.15, r * 0.8, r * 1.3);
  popMatrix();
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
    else s = "F: reclamar el live (6 respuestas)";
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
