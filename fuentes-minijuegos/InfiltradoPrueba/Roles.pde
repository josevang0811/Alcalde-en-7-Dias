// Roles. Antes de entrar cada jugador tiene un rol con una habilidad propia
// (tecla F el jugador 1, M el jugador 2) que despues necesita enfriarse.
//   Hacker:   apaga 12 s la camara mas cercana (hasta 9 baldosas) y contesta
//             la radio con una secuencia mas corta.
//   Fantasma: "Sombra": 6 s en los que casi nadie lo nota, y agachado se
//             mueve mas rapido.
// En solitario se elige el rol; en cooperativo el jugador 1 elige y el
// jugador 2 queda con el otro.

final int ROL_HACKER = 0;
final int ROL_FANTASMA = 1;
final String[] NOMBRES_ROL = {"Hacker", "Fantasma"};
final String[] HABILIDAD_ROL = {"Hackear cámara", "Sombra"};
final float[] ENFRIAR_ROL = {25, 30};
final float TIEMPO_HACKEO = 12;
final float TIEMPO_SOMBRA = 6;
final float ALCANCE_HACKEO = 9;

int rolElegido = ROL_HACKER;   // en la pantalla de elegir

void usarHabilidad(Jugador j) {
  if (estado != JUGANDO || j.escondido || j.contestando != null) return;
  if (j.enfriamiento > 0) {
    avisar(HABILIDAD_ROL[j.rol] + " lista en " + ceil(j.enfriamiento) + " s");
    return;
  }
  if (j.rol == ROL_HACKER) {
    CamaraSeguridad mejor = null;
    float mejorD = ALCANCE_HACKEO;
    for (CamaraSeguridad c : camaras) {
      float d = dist(c.x, c.y, j.x, j.y);
      if (d < mejorD && c.hackeada <= 0) {
        mejorD = d;
        mejor = c;
      }
    }
    if (mejor == null) {
      avisar("No hay cámaras a tu alcance para hackear");
      return;
    }
    mejor.hackeada = TIEMPO_HACKEO;
    sonar("hackeo");
    chispas(mejor.x, mejor.y, NEON_CIAN, 12);
    textoFlotante(mejor.x, mejor.y, "Hackeada", NEON_CIAN);
    mejor.sospecha = 0;
    j.enfriamiento = enfriamientoRol(ROL_HACKER);
    j.hackeoX = mejor.x;
    j.hackeoY = mejor.y;
    j.efectoHabilidad = 0.6;
    avisar("Cámara hackeada por " + round(TIEMPO_HACKEO) + " s");
  } else {
    j.sombra = TIEMPO_SOMBRA;
    sonar("sombra");
    chispas(j.x, j.y, NEON_MAGENTA, 12);
    j.enfriamiento = enfriamientoRol(ROL_FANTASMA);
    avisar("Sombra: por " + round(TIEMPO_SOMBRA) + " s casi nadie te nota");
  }
}

void actualizarRoles(float dt) {
  for (Jugador j : jugadores) {
    j.enfriamiento = max(0, j.enfriamiento - dt);
    j.sombra = max(0, j.sombra - dt);
    j.efectoHabilidad = max(0, j.efectoHabilidad - dt);
  }
  for (CamaraSeguridad c : camaras) c.hackeada = max(0, c.hackeada - dt);
}

// Cuanto se multiplica la sospecha de quien mira a este jugador
float factorRol(Jugador j) {
  return j.sombra > 0 ? 0.2 : 1;
}

float velocidadAgachado(Jugador j) {
  return j.rol == ROL_FANTASMA ? 1.9 : 1.4;
}

int largoSecuenciaRadio(Jugador j) {
  return j.rol == ROL_HACKER ? 3 : 4;
}

// Rayo del hackeo desde el jugador hasta la camara
void dibujarEfectosRol() {
  for (Jugador j : jugadores) {
    if (j.efectoHabilidad > 0) {
      float a = 255 * j.efectoHabilidad / 0.6;
      stroke(25, 227, 227, a);
      strokeWeight(2 * pixel);
      float x0 = pantallaX(j.x, j.y), y0 = pantallaY(j.x, j.y) - 18 * pixel;
      float x1 = pantallaX(j.hackeoX, j.hackeoY), y1 = pantallaY(j.hackeoX, j.hackeoY) - 24 * pixel;
      // linea quebrada, como una señal
      int tramos = 6;
      float px = x0, py = y0;
      for (int k = 1; k <= tramos; k++) {
        float nx = lerp(x0, x1, k / (float) tramos) + (k < tramos ? random(-6, 6) * pixel : 0);
        float ny = lerp(y0, y1, k / (float) tramos) + (k < tramos ? random(-6, 6) * pixel : 0);
        line(px, py, nx, ny);
        px = nx;
        py = ny;
      }
    }
  }
}

// Pantalla para elegir el rol (entre el inicio y el reconocimiento). Va en
// pixel art, como el HUD: se dibuja en una capa del tamaño del arte (unos
// 640 x 360) con los marcos y la letra del HUD, y se agranda sin suavizar.
PGraphics capaRol;

void dibujarElegirRol() {
  if (capaRol == null || capaRol.width != capaHud.width || capaRol.height != capaHud.height) {
    capaRol = createGraphics(capaHud.width, capaHud.height);
    capaRol.noSmooth();
  }
  PGraphics g = capaRol;
  g.beginDraw();
  g.clear();
  g.noStroke();
  g.fill(0, 150);
  g.rect(0, 0, g.width, g.height);
  int w = 404, h = 262;
  int x = (g.width - w) / 2, y = (g.height - h) / 2;
  marcoPixel(g, x, y, x + w - 1, y + h - 1, NEON_CIAN);
  // titulo con una raya debajo
  g.textAlign(CENTER, TOP);
  textoPixel(g, numJugadores == 1 ? "ELIGE TU ROL" : "JUGADOR 1: ELIGE TU ROL", g.width / 2, y + 9, color(242, 242, 233), pixel12);
  g.fill(NEON_CIAN);
  g.rect(g.width / 2 - 40, y + 25, 80, 1);
  String[][] textos = {
    {"Apaga 12 s la cámara más cercana.", "Contesta la radio con 3 flechas, no 4.", "Habilidad cada 25 s."},
    {"Sombra: 6 s en los que casi nadie te nota.", "Agachado se mueve más rápido.", "Habilidad cada 30 s."}
  };
  color[] colores = {NEON_CIAN, NEON_MAGENTA};
  int cw = 184, ch = 128;
  for (int r = 0; r < 2; r++) {
    int cx = x + 14 + r * (cw + 8);
    int cy = y + 34;
    boolean sel = r == rolElegido;
    // la tarjeta elegida se levanta un pixel y titila el borde
    int sube = sel ? 1 : 0;
    color borde = sel ? ((frameCount / 20) % 2 == 0 ? colores[r] : color(242, 242, 233)) : color(70, 80, 110);
    marcoPixel(g, cx, cy - sube, cx + cw - 1, cy + ch - 1 - sube, borde);
    if (sel) {
      g.noStroke();
      g.fill(red(colores[r]), green(colores[r]), blue(colores[r]), 28);
      g.rect(cx + 3, cy + 3 - sube, cw - 6, ch - 6);
    }
    iconoRol(g, r, cx + 10, cy + 10 - sube, sel ? colores[r] : color(110, 120, 150));
    g.textAlign(LEFT, TOP);
    textoPixel(g, NOMBRES_ROL[r].toUpperCase(), cx + 32, cy + 10 - sube, sel ? colores[r] : color(170, 176, 196), pixel12);
    textoPixel(g, "F / M: " + HABILIDAD_ROL[r], cx + 32, cy + 25 - sube, color(140, 146, 170), pixel8);
    g.fill(sel ? color(226, 228, 236) : color(150, 156, 176));
    g.textFont(pixel8);
    float ty = cy + 44 - sube;
    for (int k = 0; k < 3; k++) {
      g.text("· " + textos[r][k], cx + 10, round(ty), cw - 20, 30);
      ty += g.textWidth(textos[r][k]) > cw - 28 ? 22 : 12;
    }
    if (numJugadores == 2) {
      textoPixel(g, sel ? "JUGADOR 1" : "JUGADOR 2", cx + 10, cy + ch - 16 - sube, sel ? NEON_CIAN : NEON_VERDE, pixel8);
    }
  }
  herramientasPixel(g, x + 14, y + 172, w - 28);
  // pie: teclas
  g.textAlign(CENTER, TOP);
  textoPixel(g, "A / D: CAMBIAR      E / ENTER: ENTRAR", g.width / 2, y + h - 17,
    (frameCount / 30) % 2 == 0 ? color(242, 242, 233) : color(150, 156, 176), pixel8);
  g.endDraw();
  image(capaRol, 0, 0, capaRol.width * pixel, capaRol.height * pixel);
}

// Icono de 16 x 16 de cada rol: un portátil para el hacker y un fantasma
void iconoRol(PGraphics g, int r, int x, int y, color c) {
  g.noStroke();
  if (r == 0) {
    g.fill(c);
    g.rect(x + 2, y + 2, 12, 9);
    g.fill(10, 14, 26);
    g.rect(x + 3, y + 3, 10, 7);
    g.fill(c);
    g.rect(x + 4, y + 4, 4, 1);
    g.rect(x + 4, y + 6, 6, 1);
    g.rect(x + 4, y + 8, 3, 1);
    g.rect(x, y + 12, 16, 2);
    g.fill(red(c) * 0.6, green(c) * 0.6, blue(c) * 0.6);
    g.rect(x + 1, y + 14, 14, 1);
  } else {
    g.fill(c);
    g.rect(x + 4, y + 1, 8, 1);
    g.rect(x + 2, y + 2, 12, 2);
    g.rect(x + 1, y + 4, 14, 9);
    g.rect(x + 1, y + 13, 3, 2);
    g.rect(x + 6, y + 13, 4, 2);
    g.rect(x + 12, y + 13, 3, 2);
    g.fill(10, 14, 26);
    g.rect(x + 4, y + 6, 2, 3);
    g.rect(x + 10, y + 6, 2, 3);
    g.rect(x + 7, y + 10, 2, 1);
  }
}

// Las herramientas de la campaña, en letra pixel
void herramientasPixel(PGraphics g, int x, int y, int w) {
  g.textAlign(LEFT, TOP);
  textoPixel(g, "HERRAMIENTAS DE TU CAMPAÑA" + (campanaDePrueba ? " (DE PRUEBA)" : " · " + barrioCampana.toUpperCase()), x, y, NEON_VERDE, pixel8);
  g.fill(NEON_VERDE);
  g.rect(x, y + 11, w, 1);
  int n = 0;
  for (int k = 0; k < HERRAMIENTAS.length; k++) {
    if (!tieneHerramienta(HERRAMIENTAS[k])) continue;
    if (n == 4) {
      break;   // no caben más
    }
    int cx = x;
    int cy = y + 16 + n * 11;
    g.fill(NEON_VERDE);
    g.rect(cx, cy + 3, 2, 2);
    textoPixel(g, HERRAMIENTAS[k] + ": " + EFECTO_HERRAMIENTA[k], cx + 5, cy, color(220, 222, 230), pixel8);
    n++;
  }
  if (n == 0) {
    textoPixel(g, "Ninguna. Desbloquea habilidades en el árbol de Alcalde Digital.", x, y + 16, color(140, 146, 170), pixel8);
  }
}
