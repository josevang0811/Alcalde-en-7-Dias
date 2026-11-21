// HUD en pixel art (opcion 2 de los bocetos). Se dibuja en una capa del
// tamano del arte (la pantalla dividida por "pixel", unos 640 x 360) con letra
// sin suavizar, y despues se agranda sin suavizar: asi los marcos, los iconos
// y las letras quedan con pixeles gruesos como los sprites.

PGraphics capaHud;
PFont pixel8, pixel10, pixel12;
HashMap<PImage, PImage> retratos = new HashMap<PImage, PImage>();

void prepararHudPixel() {
  capaHud = createGraphics(ceil(width / (float) pixel), ceil(height / (float) pixel));
  capaHud.noSmooth();   // antes de beginDraw: si no, Processing lo ignora y la letra sale suavizada (borrosa al agrandarla)
  pixel8 = createFont("DejaVuSansMono-Bold.ttf", 8, false);
  pixel10 = createFont("DejaVuSansMono-Bold.ttf", 10, false);
  pixel12 = createFont("DejaVuSansMono-Bold.ttf", 12, false);
}

// ---------------------------------------------------------------- piezas

// Marco con bisel, remaches en las esquinas y esquinas claras en L
void marcoPixel(PGraphics g, int x0, int y0, int x1, int y1, color c) {
  g.noStroke();
  g.fill(15, 20, 36, 235);
  g.rect(x0, y0, x1 - x0 + 1, y1 - y0 + 1);
  g.noFill();
  g.stroke(5, 7, 13);
  g.rect(x0, y0, x1 - x0, y1 - y0);
  g.stroke(c);
  g.rect(x0 + 1, y0 + 1, x1 - x0 - 2, y1 - y0 - 2);
  g.stroke(red(c), green(c), blue(c), 110);
  g.line(x0 + 2, y0 + 2, x1 - 2, y0 + 2);
  g.stroke(20, 26, 46);
  g.line(x0 + 2, y1 - 2, x1 - 2, y1 - 2);
  g.noStroke();
  g.fill(201, 205, 211);
  int[][] remaches = {{x0 + 3, y0 + 3}, {x1 - 4, y0 + 3}, {x0 + 3, y1 - 4}, {x1 - 4, y1 - 4}};
  for (int[] r : remaches) g.rect(r[0], r[1], 2, 2);
  g.fill(242, 242, 233);
  g.rect(x0, y0, 7, 1);
  g.rect(x0, y0, 1, 7);
  g.rect(x1 - 6, y0, 7, 1);
  g.rect(x1, y0, 1, 7);
  g.rect(x0, y1, 7, 1);
  g.rect(x0, y1 - 6, 1, 7);
  g.rect(x1 - 6, y1, 7, 1);
  g.rect(x1, y1 - 6, 1, 7);
}

void textoPixel(PGraphics g, String t, float x, float y, color c, PFont f) {
  g.textFont(f);
  g.fill(c);
  g.text(t, round(x), round(y));
}

void iconoMochila(PGraphics g, int x, int y, color c) {
  g.noStroke();
  g.fill(c);
  g.rect(x + 1, y + 2, 8, 8);
  g.rect(x + 3, y, 4, 1);
  g.rect(x + 3, y, 1, 2);
  g.rect(x + 6, y, 1, 2);
  g.fill(122, 74, 16);
  g.rect(x + 3, y + 5, 4, 3);
}

void iconoOreja(PGraphics g, int x, int y, color c) {
  g.noStroke();
  g.fill(c);
  g.rect(x + 2, y, 4, 1);
  g.rect(x + 1, y + 1, 1, 6);
  g.rect(x + 6, y + 1, 1, 4);
  g.rect(x + 5, y + 5, 1, 2);
  g.rect(x + 3, y + 7, 2, 1);
  g.rect(x + 3, y + 3, 2, 2);
}

void iconoSirena(PGraphics g, int x, int y, color c, boolean prendida) {
  g.noStroke();
  g.fill(92, 100, 120);
  g.rect(x, y + 7, 10, 3);
  g.fill(prendida ? c : color(red(c) * 0.45, green(c) * 0.45, blue(c) * 0.45));
  g.rect(x + 2, y + 2, 6, 5);
  g.rect(x + 3, y + 1, 4, 1);
  if (prendida) {
    g.rect(x - 2, y + 1, 1, 1);
    g.rect(x + 11, y + 1, 1, 1);
    g.rect(x + 4, y - 2, 2, 1);
  }
}

void iconoBotella(PGraphics g, int x, int y) {
  g.noStroke();
  g.fill(30, 122, 76);
  g.rect(x + 1, y + 3, 3, 7);
  g.rect(x + 2, y, 1, 3);
  g.fill(61, 220, 132);
  g.rect(x + 1, y + 4, 1, 2);
}

// Cara del jugador sacada de su sprite (el arte ya esta a escala 1)
PImage retrato(PImage sprite) {
  PImage r = retratos.get(sprite);
  if (r == null) {
    r = sprite.get(2, 2, 12, 12);
    retratos.put(sprite, r);
  }
  return r;
}

void barraPixel(PGraphics g, int x, int y, int partes, int llenas, int ancho, int alto, color[] colores) {
  g.noStroke();
  for (int k = 0; k < partes; k++) {
    g.fill(k < llenas ? colores[min(colores.length - 1, k * colores.length / partes)] : color(35, 42, 72));
    g.rect(x + k * (ancho + 2), y, ancho, alto);
  }
}

// ---------------------------------------------------------------- HUD

void dibujarHudPixel() {
  PGraphics g = capaHud;
  g.beginDraw();
  g.clear();
  g.textAlign(LEFT, TOP);
  int an = g.width;
  int al = g.height;

  if (soloEscapar()) {
    dibujarPanelEscape(g);
  } else {
    dibujarObjetivosPixel(g);
  }

  // Estado y alarma (arriba a la derecha)
  dibujarEstadoPixel(g, an);

  // Tarjeta de cada jugador (abajo)
  for (int k = 0; k < jugadores.size(); k++) tarjetaJugadorPixel(g, jugadores.get(k), 8 + k * 236, al - 62);
  if (jugadores.size() == 1) {
    g.textAlign(RIGHT, BOTTOM);
    textoPixel(g, desdeCampana ? "G ver la ruta · R reiniciar la misión" : "G ver la ruta · R reiniciar · Esc salir", an - 8, al - 4, color(110, 118, 145), pixel8);
    g.textAlign(LEFT, TOP);
  }

  // Aviso del momento
  if (tiempoAviso > 0 && !aviso.equals("")) {
    g.textFont(pixel8);
    int aw = ceil(g.textWidth(aviso)) + 20;
    int ax = an / 2 - aw / 2;
    int ay = round(al * 0.37) - 10;
    marcoPixel(g, ax, ay, ax + aw, ay + 20, NEON_MAGENTA);
    textoPixel(g, aviso, ax + 10, ay + 5, color(242, 242, 233), pixel8);
  }
  g.endDraw();
  image(capaHud, 0, 0, capaHud.width * pixel, capaHud.height * pixel);
}

// Con el servidor copiado: solo las salidas y lo que se lleva
void dibujarPanelEscape(PGraphics g) {
  marcoPixel(g, 8, 8, 236, 60, NEON_VERDE);
  textoPixel(g, "ESCAPA", 15, 11, NEON_VERDE, pixel12);
  g.textAlign(RIGHT, TOP);
  textoPixel(g, horaTexto(), 229, 14, color(242, 242, 233), pixel8);
  g.textAlign(LEFT, TOP);
  String[] nombres = {"Camioneta (entrada)", "Moto (fondo del parqueadero)", "Ducto a la calle"};
  for (int s = 0; s < 1; s++) {   // solo la de la ruta
    int y = 30 + s * 12;
    String b = bloqueoSalida(s);
    // "espera a tu compañero" no cuenta como bloqueo: la salida sirve
    boolean sirve = b.equals("") || b.startsWith("Espera");
    color c = sirve ? color(242, 242, 233) : color(92, 103, 135);
    g.noStroke();
    g.fill(sirve ? NEON_VERDE : COLOR_RIVAL);
    g.rect(16, y + 2, 5, 5);
    textoPixel(g, nombres[s], 26, y - 1, c, pixel8);
    if (!sirve) {
      g.textAlign(RIGHT, TOP);
      textoPixel(g, s == SALIDA_DUCTO ? "más de 2 kg" : "bloqueada", 229, y - 1, COLOR_RIVAL, pixel8);
      g.textAlign(LEFT, TOP);
    }
  }
  textoPixel(g, "Sigue la ruta hasta la camioneta (G)", 16, 46, COLOR_AMBAR, pixel8);
}

void dibujarObjetivosPixel(PGraphics g) {
  // Objetivos
  marcoPixel(g, 8, 8, 236, 30 + paradasRuta.size() * 11 + 18, NEON_CIAN);
  textoPixel(g, "TU RUTA", 15, 11, NEON_CIAN, pixel12);
  g.textAlign(RIGHT, TOP);
  textoPixel(g, horaTexto(), 229, 14, color(242, 242, 233), pixel8);
  g.textAlign(LEFT, TOP);
  int llevadas = 0;
  for (Jugador j : jugadores) llevadas += j.valorBotin;
  // solo la ruta: las tarjetas que hagan falta, el servidor y la salida
  StringList lista = new StringList();
  IntList hecho = new IntList();
  for (int[] p : paradasRuta) {
    if (p[2] >= 1 && p[2] <= 4) {
      lista.append("Toma la " + nombreParada(p[2]).toLowerCase());
      hecho.append(tarjetas[p[2]] ? 1 : 0);
    }
  }
  lista.append("Copia el servidor");
  hecho.append(servidorCopiado ? 1 : 0);
  lista.append("Sal por la camioneta");
  hecho.append(0);
  boolean[] hechos = new boolean[lista.size()];
  String[] textos = new String[lista.size()];
  for (int k = 0; k < lista.size(); k++) {
    hechos[k] = hecho.get(k) == 1;
    textos[k] = (k + 1) + ". " + lista.get(k);
  }
  for (int k = 0; k < textos.length; k++) {
    int y = 30 + k * 11;
    color c = hechos[k] ? NEON_VERDE : color(242, 242, 233);
    g.noStroke();
    if (hechos[k]) {
      g.fill(c);
      g.rect(16, y + 1, 6, 6);
    } else {
      g.noFill();
      g.stroke(c);
      g.rect(16, y + 1, 5, 5);
      g.noStroke();
    }
    textoPixel(g, textos[k], 26, y - 2, c, pixel8);
  }
  // barra de copia junto a "Copia el servidor"
  if (!servidorCopiado && progresoServidor > 0) {
    int yb = 30 + (textos.length - 2) * 11 + 3;
    g.fill(35, 42, 72);
    g.rect(170, yb, 58, 5);
    g.fill(NEON_MAGENTA);
    g.rect(170, yb, round(58 * progresoServidor), 5);
  }
  textoPixel(g, "G: ver la ruta en el mapa", 16, 30 + textos.length * 11 + 4, color(125, 139, 176), pixel8);
  // las oportunidades y el botín siguen en la sede, pero ya no se muestran
}

void dibujarEstadoPixel(PGraphics g, int an) {
  int peor = V_PATRULLA;
  for (Vigilante v : vigilantes) {
    if (v.inconsciente) continue;
    if (v.estado == V_ALERTA) peor = V_ALERTA;
    else if (v.estado != V_PATRULLA && peor != V_ALERTA) peor = V_SOSPECHA;
  }
  String texto = "SIN DETECTAR";
  color c = NEON_VERDE;
  if (peor == V_SOSPECHA) {
    texto = "SOSPECHAN";
    c = COLOR_AMBAR;
  }
  if (peor == V_ALERTA) {
    texto = "¡ALERTA!";
    c = (frameCount / 10) % 2 == 0 ? COLOR_RIVAL : color(140, 28, 46);
  }
  color[] coloresAlarma = {NEON_VERDE, COLOR_AMBAR, #FF7A3D, COLOR_RIVAL};
  int alto = nivelAlarma == 3 ? 62 : 52;
  marcoPixel(g, an - 136, 8, an - 8, 8 + alto, c);
  iconoSirena(g, an - 128, 15, c, peor != V_PATRULLA && (frameCount / 12) % 2 == 0);
  textoPixel(g, texto, an - 112, 11, c, pixel12);
  for (int k = 0; k < 3; k++) {
    g.noStroke();
    g.fill(k < nivelAlarma ? coloresAlarma[nivelAlarma] : color(35, 42, 72));
    g.rect(an - 112 + k * 16, 34, 13, 6);
  }
  g.textAlign(RIGHT, TOP);
  textoPixel(g, "NIVEL " + nivelAlarma, an - 15, 32, coloresAlarma[nivelAlarma], pixel8);
  textoPixel(g, NOMBRES_ALARMA[nivelAlarma], an - 15, 44 - 1, color(160, 168, 190), pixel8);
  if (nivelAlarma == 3) textoPixel(g, "Policía en " + ceil(max(0, tiempoPolicia)) + " s", an - 15, 54, (frameCount / 15) % 2 == 0 ? COLOR_RIVAL : color(242, 242, 233), pixel8);
  g.textAlign(LEFT, TOP);
}

void tarjetaJugadorPixel(PGraphics g, Jugador j, int x, int y) {
  color c = j.ropa;
  marcoPixel(g, x, y, x + 228, y + 54, c);
  // retrato
  SpritesPersona s = j.numero == 1 ? spritesJugador1 : spritesJugador2;
  if (j.disfrazado) s = j.numero == 1 ? spritesConserje1 : spritesConserje2;
  g.noStroke();
  g.fill(29, 58, 74);
  g.rect(x + 6, y + 6, 20, 20);
  g.noFill();
  g.stroke(c);
  g.rect(x + 6, y + 6, 19, 19);
  g.image(retrato(s.frente[0]), x + 10, y + 10);
  textoPixel(g, "J" + j.numero + " " + NOMBRES_ROL[j.rol], x + 31, y + 4, c, pixel10);
  textoPixel(g, j.postura(), x + 31, y + 16, color(242, 242, 233), pixel8);
  // botellas
  iconoBotella(g, x + 170, y + 6);
  textoPixel(g, "x" + j.botellas, x + 177, y + 5, j.botellas > 0 ? NEON_VERDE : color(110, 118, 145), pixel10);
  // ruido
  iconoOreja(g, x + 6, y + 31, color(154, 163, 181));
  int llenas = min(10, round(j.radioRuido() / 3.7 * 10));
  color[] coloresRuido = {NEON_VERDE, NEON_VERDE, NEON_VERDE, NEON_VERDE, COLOR_AMBAR, COLOR_AMBAR, COLOR_AMBAR, COLOR_RIVAL, COLOR_RIVAL, COLOR_RIVAL};
  barraPixel(g, x + 18, y + 33, 10, llenas, 5, 6, coloresRuido);
  // mochila
  iconoMochila(g, x + 94, y + 30, j.peso >= CAPACIDAD_MOCHILA ? COLOR_RIVAL : COLOR_AMBAR);
  color[] coloresMochila = {COLOR_AMBAR};
  barraPixel(g, x + 106, y + 33, CAPACIDAD_MOCHILA, j.peso, 4, 6, coloresMochila);
  // habilidad del rol
  boolean lista = j.enfriamiento <= 0;
  String hab = j.teclaHabilidad() + ": " + (j.sombra > 0 ? "activa" : (lista ? "lista" : ceil(j.enfriamiento) + " s"));
  textoPixel(g, hab, x + 150, y + 31, lista ? (j.rol == ROL_HACKER ? NEON_CIAN : NEON_MAGENTA) : color(110, 118, 145), pixel8);
  // controles
  String controles = j.numero == 1 ? "WASD C agacha E usa Q lanza X suelta F rol" : "Flechas . agacha Enter , lanza K suelta M rol";
  textoPixel(g, controles, x + 6, y + 43, color(92, 103, 135), pixel8);
}
