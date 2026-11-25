// Lo que va encima de la ciudad: objetivo, reloj, lista en vivo, avisos,
// nombres de los candidatos, la pantalla final y el mapa.

final color CAFE = color(43, 30, 26);
final color CREMA = color(246, 236, 200);

int zonaActual = -1;
int momentoZona = -10000;
String aviso = "";
int momentoAviso = -10000;

void avisar(String s) {
  aviso = s;
  momentoAviso = millis();
}

// De pixeles del dibujo a pixeles de la pantalla (igual que dibujarCiudad)
float aPantallaX(float nx) {
  return round(width / 2.0 - round(camX) * pixel) + nx * pixel;
}

float aPantallaY(float ny) {
  return round(height / 2.0 - round(camY) * pixel) + ny * pixel;
}

// Cuando el candidato entra a otra zona se muestra su nombre un rato
// (solo paseando; en la ronda estorba). La calle y los bordes no cuentan.
void revisarZona() {
  int z = zonaEn(yo.x, yo.y);
  if (z == 0 || z == 12) return;
  if (z != zonaActual) {
    zonaActual = z;
    if (estadoRonda == PASEO) momentoZona = millis();
  }
}

void caja(float x, float y, float w, float h, float alfa) {
  noStroke();
  fill(CAFE, alfa);
  rect(x, y, w, h, 4 * pixel);
}

void dibujarHud() {
  dibujarEtiquetas();
  dibujarAvisoZona();
  if (sinFotos()) {
    dibujarObjetivo(fotoRecibida ? "Se perdió la conexión con el parque" : "Conectando con el parque",
      (fotoRecibida ? "" : "Esperando a que el anfitrión llegue al evento. ") + "Enter: volver a la oficina");
    dibujarAyuda();
    return;
  }
  int estadoHud = estadoRonda;
  if (estadoHud == PASEO || estadoHud == REUNION) estadoHud = enLaPlaza(yo) ? REUNION : PASEO;
  switch (estadoHud) {
  case PASEO:
    dibujarAyudaCarro();
    dibujarObjetivo("Ve al centro del parque", evento == VOLANTES
      ? "Los candidatos se reúnen en la plaza de la fuente para pegar volantes."
      : (evento == GENTE ? "Los candidatos se reúnen en la plaza de la fuente para convencer a la gente."
      : "Los candidatos se reúnen en la plaza de la fuente; de ahí salen a buscar los lives."));
    dibujarFlecha(centroX, centroY, radioPlaza + 2);
    break;
  case VUELTA:
    dibujarAyudaCarro();
    dibujarObjetivo("Vuelve a tu sede", "Entra por el parqueadero de la sede para volver a tu oficina.");
    dibujarFlecha(yo.inicioX, yo.inicioY, 1.8);
    break;
  case REUNION:
    dibujarObjetivo("Esperando a los candidatos", enLaPlaza() + " de " + candidatos.size() + " en la plaza"
      + (modoRed == ANFITRION && esperaReunion > 15 ? " · se empieza en " + ceil(45 - esperaReunion) + " s" : ""));
    break;
  case CUENTA:
    dibujarCuenta();
    break;
  case RONDA:
    dibujarReloj();
    dibujarLista();
    dibujarBotellasHud();
    dibujarMiraBotella();
    if (evento == VOLANTES) {
      dibujarAyudaPegar();
    } else {
      if (evento == LIVES) {
        dibujarAyudaCarro();
        Ciudadano m = liveMasCercano(yo);
        if (m != null && !enSecuencia(yo)) dibujarFlecha(m.x, m.y, ALCANCE_LIVE + 1);
      }
      dibujarCandados();
      dibujarAyudaGente();
      dibujarSecuenciaJugador();
    }
    break;
  case FINAL:
    dibujarCandados();
    dibujarLista();
    dibujarFinal();
    break;
  }
  if (modoPrueba) dibujarSelectorEvento();
  dibujarAviso();
  dibujarAyuda();
  if (verMapa) dibujarMinimapa();
}

void dibujarAvisoZona() {
  float t = (millis() - momentoZona) / 1000.0;
  if (zonaActual < 0 || t > 3.2) return;
  float alfa = 255 * constrain(min(t / 0.3, (3.2 - t) / 0.6), 0, 1);
  String nombre = nombresZona[zonaActual].toUpperCase();
  textFont(fuenteNegrita, 13 * pixel);
  float w = textWidth(nombre) + 28 * pixel;
  float h = 24 * pixel;
  float y = height - 70 * pixel;
  caja(width / 2.0 - w / 2, y, w, h, alfa * 0.85);
  fill(CREMA, alfa);
  textAlign(CENTER, CENTER);
  text(nombre, width / 2.0, y + h / 2 - pixel);
}

void dibujarObjetivo(String titulo, String detalle) {
  textFont(fuente, 9 * pixel);
  float w = max(textWidth(detalle), 120 * pixel) + 20 * pixel;
  caja(10 * pixel, 10 * pixel, w, 38 * pixel, 215);
  fill(250, 214, 80);
  textFont(fuenteNegrita, 8 * pixel);
  textAlign(LEFT, TOP);
  text("OBJETIVO", 20 * pixel, 15 * pixel);
  fill(CREMA);
  textFont(fuenteNegrita, 11 * pixel);
  text(titulo, 20 * pixel, 24 * pixel);
  textFont(fuente, 9 * pixel);
  fill(CREMA, 200);
  text(detalle, 20 * pixel, 37 * pixel);
}

// Flecha alrededor del candidato que apunta al centro del parque
// Flecha alrededor del candidato que apunta a (mx, my), con los metros
void dibujarFlecha(float mx, float my, float llegada) {
  float d = dist(yo.x, yo.y, mx, my);
  if (d < llegada) return;
  float sx = aPantallaX(pantallaX(yo.x, yo.y)), sy = aPantallaY(pantallaY(yo.x, yo.y) - 12);
  float tx = aPantallaX(pantallaX(mx, my)), ty = aPantallaY(pantallaY(mx, my));
  float a = atan2(ty - sy, tx - sx);
  float r = 30 * pixel;
  pushMatrix();
  translate(sx + cos(a) * r, sy + sin(a) * r);
  rotate(a);
  noStroke();
  fill(CAFE, 200);
  triangle(9 * pixel, 0, -5 * pixel, -7 * pixel, -5 * pixel, 7 * pixel);
  fill(250, 214, 80);
  triangle(6 * pixel, 0, -3 * pixel, -4.5 * pixel, -3 * pixel, 4.5 * pixel);
  popMatrix();
  textFont(fuenteNegrita, 8 * pixel);
  textAlign(CENTER, CENTER);
  fill(CREMA);
  float metros = d * 1.5;
  String s = round(metros) + " m";
  float lx = sx + cos(a) * (r + 18 * pixel), ly = sy + sin(a) * (r + 12 * pixel);
  caja(lx - textWidth(s) / 2 - 4 * pixel, ly - 6 * pixel, textWidth(s) + 8 * pixel, 12 * pixel, 180);
  fill(CREMA);
  text(s, lx, ly - pixel);
}

void dibujarCuenta() {
  int n = ceil(relojRonda);
  float f = relojRonda - floor(relojRonda);
  textFont(fuenteNegrita, (40 + 30 * f) * pixel);
  textAlign(CENTER, CENTER);
  fill(CAFE, 200);
  text(n, width / 2.0 + 2 * pixel, height / 2.0 - 40 * pixel + 2 * pixel);
  fill(250, 214, 80);
  text(n, width / 2.0, height / 2.0 - 40 * pixel);
  textFont(fuenteNegrita, 12 * pixel);
  fill(CREMA);
  String s = evento == VOLANTES ? "Ronda de volantes: el que más carteleras tenga al final gana"
    : (evento == GENTE ? "Convencer a la gente: el que más ciudadanos tenga al final gana"
    : "Lives: reclama los cúmulos de gente de la ciudad; el que tenga más gana");
  caja(width / 2.0 - textWidth(s) / 2 - 12 * pixel, height / 2.0 + 4 * pixel, textWidth(s) + 24 * pixel, 22 * pixel, 210);
  fill(CREMA);
  text(s, width / 2.0, height / 2.0 + 14 * pixel);
}

void dibujarReloj() {
  int s = max(0, ceil(relojRonda));
  String t = nf(s / 60, 1) + ":" + nf(s % 60, 2);
  textFont(fuenteNegrita, 20 * pixel);
  float w = textWidth(t) + 26 * pixel;
  caja(width / 2.0 - w / 2, 8 * pixel, w, 30 * pixel, 220);
  boolean apurado = relojRonda < 10;
  fill(apurado ? lerpColor(color(250, 120, 100), CREMA, 0.5 + 0.5 * sin(millis() / 90.0)) : CREMA);
  textAlign(CENTER, CENTER);
  text(t, width / 2.0, 22 * pixel);
}

// Lista en vivo: cada fila se desliza a su nuevo puesto cuando alguien pasa a otro
void dibujarLista() {
  ArrayList<Candidato> l = estadoRonda == FINAL ? resultado : listaOrdenada();
  float x = width - 150 * pixel, y0 = 10 * pixel, fila = 20 * pixel;
  caja(x - 6 * pixel, y0, 146 * pixel, 22 * pixel + fila * l.size(), 215);
  textFont(fuenteNegrita, 8 * pixel);
  fill(250, 214, 80);
  textAlign(LEFT, TOP);
  text(evento == VOLANTES ? "VOLANTES PEGADOS" : (evento == GENTE ? "GENTE CONVENCIDA"
    : "LIVES · QUEDAN " + livesLibres() + " DE " + totalLives()), x + 2 * pixel, y0 + 6 * pixel);
  for (int k = 0; k < l.size(); k++) {
    Candidato c = l.get(k);
    if (c.filaLista < 0) c.filaLista = k;
    c.filaLista += (k - c.filaLista) * 0.18;
    float y = y0 + 20 * pixel + c.filaLista * fila;
    if (c == yo) {
      noStroke();
      fill(255, 255, 255, 30);
      rect(x - 2 * pixel, y, 138 * pixel, fila - 2 * pixel, 3 * pixel);
    }
    fill(c.col);
    rect(x + 2 * pixel, y + 4 * pixel, 10 * pixel, 10 * pixel, 2 * pixel);
    textFont(fuenteNegrita, 10 * pixel);
    fill(CREMA);
    textAlign(LEFT, CENTER);
    text((k + 1) + ". " + nombreVisible(c), x + 18 * pixel, y + 8 * pixel);
    textAlign(RIGHT, CENTER);
    text(puntajeDe(c), x + 128 * pixel, y + 8 * pixel);
  }
}

// Las botellas no se acaban: el recuadro solo recuerda la tecla
void dibujarBotellasHud() {
  float x = 10 * pixel, y = height - 52 * pixel;
  textFont(fuenteNegrita, 9 * pixel);
  String texto = "Botellas ilimitadas · Q o clic: al cursor";
  float w = textWidth(texto) + 34 * pixel;
  caja(x, y, w, 24 * pixel, 210);
  noStroke();
  fill(90, 170, 110);
  rect(x + 8 * pixel, y + 7 * pixel, 6 * pixel, 12 * pixel, 1.5 * pixel);
  rect(x + 9.5 * pixel, y + 4 * pixel, 3 * pixel, 4 * pixel);
  fill(CREMA);
  textAlign(LEFT, CENTER);
  text(texto, x + 20 * pixel, y + 12 * pixel);
}

// "Mantén E para pegar" encima de la cartelera que alcanza el jugador
void dibujarAyudaPegar() {
  int p = puntoAlAlcance(yo);
  if (p < 0 || yo.aturdido > 0) return;
  Punto pt = puntos.get(p);
  String s = dueno(p) == yo.id ? "Este punto ya es tuyo" : (dueno(p) >= 0 ? "Mantén E para tapar el volante" : "Mantén E para pegar");
  float sx = aPantallaX(pantallaX(pt.x, pt.y)), sy = aPantallaY(pantallaY(pt.x, pt.y) - 40);
  textFont(fuenteNegrita, 9 * pixel);
  float w = textWidth(s) + 14 * pixel;
  caja(sx - w / 2, sy - 9 * pixel, w, 17 * pixel, 210);
  fill(dueno(p) == yo.id ? color(160, 220, 170) : CREMA);
  textAlign(CENTER, CENTER);
  text(s, sx, sy - pixel);
}

// Nombres, barra de pegar, estrellitas del botellazo y textos que suben
void dibujarEtiquetas() {
  for (Candidato c : candidatos) {
    if (c == yo && manejando != null) continue;
    float sx = aPantallaX(pantallaX(c.x, c.y)), sy = aPantallaY(pantallaY(c.x, c.y) - 31);
    if (sx < -50 || sx > width + 50 || sy < -50 || sy > height + 50) continue;
    textFont(fuenteNegrita, 8 * pixel);
    String n = c == yo ? "TÚ" : c.nombre;
    float w = textWidth(n) + 8 * pixel;
    noStroke();
    fill(c.col, 230);
    rect(sx - w / 2, sy - 11 * pixel, w, 11 * pixel, 3 * pixel);
    fill(255);
    textAlign(CENTER, CENTER);
    text(n, sx, sy - 6 * pixel);
    if (c.progresoPegar > 0) {
      float bw = 26 * pixel;
      fill(CAFE, 220);
      rect(sx - bw / 2 - pixel, sy - 19 * pixel, bw + 2 * pixel, 6 * pixel, 2 * pixel);
      fill(c.claro);
      rect(sx - bw / 2, sy - 18 * pixel, bw * c.progresoPegar, 4 * pixel, 1.5 * pixel);
    }
    if (c.aturdido > 0) {
      for (int k = 0; k < 3; k++) {
        float a = millis() / 180.0 + k * TWO_PI / 3;
        float ex = sx + cos(a) * 10 * pixel, ey = sy - 16 * pixel + sin(a) * 3 * pixel;
        fill(250, 214, 80);
        quad(ex, ey - 3 * pixel, ex + 2 * pixel, ey, ex, ey + 3 * pixel, ex - 2 * pixel, ey);
      }
    }
  }
  for (TextoFlotante t : textosFlotantes) {
    float sx = aPantallaX(pantallaX(t.x, t.y));
    float sy = aPantallaY(pantallaY(t.x, t.y) - 44) - (1.1 - t.vida) * 22 * pixel;
    textFont(fuenteNegrita, 12 * pixel);
    textAlign(CENTER, CENTER);
    fill(CAFE, 255 * min(1, t.vida * 2));
    text(t.texto, sx + pixel, sy + pixel);
    fill(t.col, 255 * min(1, t.vida * 2));
    text(t.texto, sx, sy);
  }
}

void dibujarAviso() {
  float t = (millis() - momentoAviso) / 1000.0;
  if (t > 2.6 || aviso.length() == 0) return;
  float alfa = 255 * constrain(min(t / 0.2, (2.6 - t) / 0.5), 0, 1);
  textFont(fuenteNegrita, 11 * pixel);
  float w = textWidth(aviso) + 24 * pixel;
  float y = estadoRonda == RONDA || estadoRonda == FINAL ? 46 * pixel : height - 100 * pixel;
  caja(width / 2.0 - w / 2, y, w, 22 * pixel, alfa * 0.9);
  fill(CREMA, alfa);
  textAlign(CENTER, CENTER);
  text(aviso, width / 2.0, y + 10 * pixel);
}

void dibujarFinal() {
  float w = 300 * pixel, h = 190 * pixel;
  float x = width / 2.0 - w / 2, y = height / 2.0 - h / 2;
  noStroke();
  fill(20, 16, 14, 120);
  rect(0, 0, width, height);
  fill(CREMA);
  rect(x - 3 * pixel, y - 3 * pixel, w + 6 * pixel, h + 6 * pixel, 7 * pixel);
  fill(CAFE);
  rect(x, y, w, h, 6 * pixel);
  int pos = posicionDe(yo);
  textAlign(CENTER, TOP);
  textFont(fuenteNegrita, 8 * pixel);
  fill(250, 214, 80);
  text(evento == VOLANTES ? "FIN DE LA RONDA DE VOLANTES" : (evento == GENTE ? "FIN DE LA RONDA DE CONVENCER GENTE" : "FIN DE LA RONDA DE LOS LIVES"), width / 2.0, y + 10 * pixel);
  textFont(fuenteNegrita, 17 * pixel);
  fill(CREMA);
  String titulo = pos == 0 ? "¡Ganaste!" : "Quedaste de " + (pos + 1) + ".°";
  text(titulo, width / 2.0, y + 22 * pixel);
  float fy = y + 50 * pixel;
  for (int k = 0; k < resultado.size(); k++) {
    Candidato c = resultado.get(k);
    float ry = fy + k * 20 * pixel;
    if (c == yo) {
      fill(255, 255, 255, 28);
      rect(x + 14 * pixel, ry - 2 * pixel, w - 28 * pixel, 18 * pixel, 3 * pixel);
    }
    fill(c.col);
    rect(x + 22 * pixel, ry + 3 * pixel, 10 * pixel, 10 * pixel, 2 * pixel);
    textFont(fuenteNegrita, 10 * pixel);
    fill(CREMA);
    textAlign(LEFT, CENTER);
    text((k + 1) + ".  " + nombreVisible(c), x + 40 * pixel, ry + 7 * pixel);
    textAlign(RIGHT, CENTER);
    int pts = puntajeDe(c);
    text(pts + (evento == VOLANTES ? " volantes" : (evento == LIVES ? (pts == 1 ? " live" : " lives") : (pts == 1 ? " persona" : " personas"))), x + 200 * pixel, ry + 7 * pixel);
    int pr = premioDe(c);
    fill(pr > 0 ? color(140, 220, 150) : (pr < 0 ? color(240, 130, 110) : color(200, 190, 170)));
    text((pr > 0 ? "+" : "") + pr + " apoyo", x + w - 22 * pixel, ry + 7 * pixel);
  }
  textFont(fuente, 9 * pixel);
  fill(CREMA, 220);
  textAlign(CENTER, TOP);
  int premio = premioDe(yo);
  String s = premio > 0 ? "Vuelve a tu oficina: el influencer te va a escribir al celular para decidir en qué barrio poner el apoyo."
    : (premio < 0 ? "Quedar de último resta " + (-premio) + " de apoyo en tu barrio más fuerte."
    : "Esta vez no ganas ni pierdes apoyo.");
  text(s, x + 16 * pixel, fy + resultado.size() * 20 * pixel + 4 * pixel, w - 32 * pixel, 30 * pixel);
  textFont(fuenteNegrita, 9 * pixel);
  fill(250, 214, 80);
  text((modoRed == SOLO ? "Enter: volver a la sede" : "Enter: volver a la oficina") + (modoRed == SOLO ? "   ·   R: repetir la ronda" : ""), width / 2.0, y + h - 18 * pixel);
}

void dibujarAyuda() {
  textFont(fuente, 9 * pixel);
  String s;
  if (estadoRonda == RONDA && evento == VOLANTES) s = "WASD caminar · Shift correr · E (mantener) pegar · Q botella · M mapa";
  else if (estadoRonda == RONDA && evento == GENTE) s = "WASD caminar · E convencer · F asegurar (flechas) · Q botella · M mapa";
  else if (manejando != null) s = "W acelerar · S frenar · A D girar · E bajarte · M mapa";
  else if (estadoRonda == RONDA) s = "WASD caminar · Shift correr · F reclamar live" + (puedeManejar() ? " · E subirte a un carro" : "") + " · Q botella · M mapa";
  else s = "WASD caminar · Shift correr · E subirte a un carro · M mapa" + (modoPrueba ? " · C choques" : "");
  float w = textWidth(s) + 16 * pixel;
  caja(8 * pixel, height - 22 * pixel, w, 15 * pixel, 170);
  fill(CREMA);
  textAlign(LEFT, CENTER);
  text(s, 16 * pixel, height - 15 * pixel);
}

// El mapa de la ciudad con los candidatos y el centro del parque
void dibujarMinimapa() {
  float esc = min((width - 60.0) / minimapa.width, (height - 80.0) / minimapa.height);
  float w = minimapa.width * esc, h = minimapa.height * esc;
  float x = width / 2.0 - w / 2, y = height / 2.0 - h / 2 + 10;
  noStroke();
  fill(20, 16, 14, 170);
  rect(0, 0, width, height);
  fill(CREMA);
  rect(x - 6, y - 6, w + 12, h + 12, 6);
  image(minimapa, x, y, w, h);
  float f = esc / 4.0;   // el minimapa es el dibujo a 1/4
  // centro del parque
  float cx = x + pantallaX(centroX, centroY) * f, cy = y + pantallaY(centroX, centroY) * f;
  noFill();
  stroke(250, 214, 80);
  strokeWeight(3);
  ellipse(cx, cy, 26 + 6 * sin(millis() / 200.0), 13 + 3 * sin(millis() / 200.0));
  // los lives que quedan libres
  if (evento == LIVES && (estadoRonda == RONDA || estadoRonda == FINAL)) {
    for (Ciudadano z : ciudadanos) {
      if (!z.live) continue;
      float lx = x + pantallaX(z.x, z.y) * f, ly = y + pantallaY(z.x, z.y) * f;
      fill(z.asegurado ? candidatos.get(z.dueno).col : color(226, 52, 52));
      stroke(255);
      strokeWeight(1.5);
      rect(lx - 9, ly - 14, 18, 10, 2);
      noStroke();
      fill(255);
      ellipse(lx - 4, ly - 9, 3, 3);
    }
  }
  for (Candidato c : candidatos) {
    float px = x + pantallaX(c.x, c.y) * f;
    float py = y + pantallaY(c.x, c.y) * f;
    float r = c == yo ? 7 + 2 * sin(millis() / 150.0) : 5;
    fill(c.col);
    stroke(255);
    strokeWeight(2);
    ellipse(px, py - 4, r * 2, r * 2);
  }
  noStroke();
  textFont(fuenteNegrita, 10 * pixel);
  fill(CREMA);
  textAlign(CENTER, BOTTOM);
  text("CIUDAD · M para cerrar", width / 2.0, y - 12);
}

// Solo en la prueba: escoger qué evento se juega (1 volantes, 2 gente)
void dibujarSelectorEvento() {
  if (estadoRonda == RONDA || estadoRonda == CUENTA) return;
  textFont(fuente, 8 * pixel);
  String s = "Evento de prueba: " + (evento == VOLANTES ? "[1 Volantes]  2 Gente  3 Lives" : (evento == GENTE ? "1 Volantes  [2 Gente]  3 Lives" : "1 Volantes  2 Gente  [3 Lives]"));
  float w = textWidth(s) + 14 * pixel;
  float y = estadoRonda == FINAL ? height - 40 * pixel : 52 * pixel;
  caja(10 * pixel, y, w, 14 * pixel, 190);
  fill(CREMA);
  textAlign(LEFT, CENTER);
  text(s, 17 * pixel, y + 6.5 * pixel);
}
