// Todo lo que se dibuja del mundo. La cuadricula se pasa a pantalla con la
// formula isometrica de siempre:
//   pantallaX = (x - y) * anchoBaldosa / 2
//   pantallaY = (x + y) * altoBaldosa / 2
// y se dibuja de atras hacia adelante (por diagonales x + y) para que lo que
// esta mas cerca de la camara tape a lo que esta detras.

// Colores de la paleta neon nocturno (los mismos de los sprites)
final color NEON_CIAN = #19E3E3;
final color NEON_MAGENTA = #FF2E88;
final color COLOR_RIVAL = #E8344E;
final color COLOR_AMBAR = #FFB547;
final color NEON_VERDE = #3DDC84;
final color COLOR_FONDO = #0B0E1A;

// El centro de la camara se redondea a pixeles enteros: asi todas las
// baldosas caen justas y no aparecen rayitas entre ellas.
float pantallaX(float x, float y) {
  return round(width / 2 - (camX - camY) * anchoBaldosa / 2) + (x - y) * anchoBaldosa / 2;
}

float pantallaY(float x, float y) {
  return round(height / 2 - (camX + camY) * altoBaldosa / 2) + (x + y) * altoBaldosa / 2;
}

void dibujarMundo() {
  noTint();
  actualizarMarcas();
  dibujarPisos();
  dibujarSobrePiso();
  dibujarCapaOrdenada();
  dibujarProyectiles();
  dibujarDuctos(60);
  dibujarResplandores();
  dibujarBrilloUsable();
  dibujarAparatosCamara();
  dibujarIndicadores();
  noTint();
}

// ---------------------------------------------------------------------------
// Piso
// ---------------------------------------------------------------------------

// Que sprite de piso va en cada baldosa (depende del cuarto)
PImage spritePiso(int i, int j) {
  char c = mapa.celdas[i][j];
  int v = (i * 7 + j * 13) % 2;   // dos versiones para que no se vea repetido
  if (c == 'D' || mapa.esPuertaCerrada(i, j)) return pisoMadera[v];
  int z = mapa.zona[i][j];
  if (z == 0) return (j == 27 || j == 29) && i % 3 == 0 && i > 20 ? pisoAsfalto[1] : pisoAsfalto[0];
  if (z == 1 || z == 8) return pisoBaldosa[v];   // recepcion y pasillo
  if (z == 2 || z == 10) return pisoAlfombra[v]; // redaccion y descanso
  if (z == 3) return pisoNegro[v];               // estudio
  if (z == 4 || z == 6) return pisoMetal[v];     // seguridad y servidor
  if (z == 5) return pisoMadera[v];              // archivo
  if (z == 7) return pisoRoja[v];                // oficina del rival
  return pisoBlanca[v];                          // aseo
}

void dibujarPisos() {
  for (int i = 0; i < mapa.ancho; i++) {
    for (int j = 0; j < mapa.alto; j++) {
      if (mapa.esPared(i, j)) continue;
      float sx = pantallaX(i, j);
      float sy = pantallaY(i, j);
      if (sx < -anchoBaldosa * 2 || sx > width + anchoBaldosa * 2 || sy < -altoPared * 2 || sy > height + altoBaldosa * 2) continue;
      tinteLuz(i, j, 255);
      sprite(spritePiso(i, j), sx - 16 * pixel, sy);
    }
  }
  noTint();
}

// Encima del piso: charcos de luz de colores, conos de vista, ruido y rutas
void dibujarSobrePiso() {
  for (float[] f : mapa.fuentesLuz) {
    float sx = pantallaX(f[0], f[1]);
    float sy = pantallaY(f[0], f[1]);
    if (fueraDePantalla(sx, sy, f[5] * 1.6 * anchoBaldosa)) continue;
    manchaLuz(sx, sy, f[5] * 1.6, color(f[2], f[3], f[4]), 120 * f[6], true);
  }

  for (Vigilante v : vigilantes) {
    if (v.inconsciente) continue;
    color c = color(255, 181, 71, 75);
    if (v.estado == V_SOSPECHA || v.estado == V_BUSCANDO) c = color(255, 181, 71, 90);
    if (v.estado == V_ALERTA) c = color(232, 52, 78, 100);
    dibujarCono(v.x, v.y, v.angulo, v.APERTURA, v.rango(), c);
  }
  for (Civil cv : civiles) {
    if (cv.inconsciente || cv.estado == C_ASUSTADO || cv.estado == C_HUYENDO) continue;
    color c = cv.estado == C_SOSPECHA ? color(255, 46, 136, 70) : color(242, 242, 233, 32);
    dibujarCono(cv.x, cv.y, cv.angulo, cv.APERTURA, cv.RANGO, c);
  }
  for (CamaraSeguridad cam : camaras) {
    if (!camarasEncendidas()) break;
    if (cam.hackeada > 0) continue;
    color c = cam.viendo ? color(232, 52, 78, 95) : color(25, 227, 227, 45);
    dibujarCono(cam.x, cam.y, cam.angulo, cam.APERTURA, cam.RANGO, c);
  }

  noFill();
  strokeWeight(2 * pixel);
  for (Ruido r : ruidos) {
    float actual = r.radio * (0.25 + 0.75 * (1 - r.vida));
    stroke(255, 46, 136, 210 * r.vida);
    ellipse(pantallaX(r.x, r.y), pantallaY(r.x, r.y),
      actual * anchoBaldosa * 1.414, actual * altoBaldosa * 1.414);
  }

  if (verRutas) dibujarRutas();
}

// Cono de vista recortado por las paredes: se lanzan rayos y cada uno se
// detiene en la primera baldosa que tapa la vista.
// Para no dibujar lo que cae fuera de la pantalla (margen en pixeles)
boolean fueraDePantalla(float sx, float sy, float margen) {
  float m = margen + 20;
  // con el zoom del reconocimiento se ve mas: se agranda el margen
  if (zoom < 0.99) return false;
  return sx < -m || sx > width + m || sy < -m || sy > height + m;
}

void dibujarCono(float cx, float cy, float ang, float apertura, float rango, color c) {
  if (fueraDePantalla(pantallaX(cx, cy), pantallaY(cx, cy), rango * anchoBaldosa)) return;
  noStroke();
  fill(c);
  beginShape();
  vertex(pantallaX(cx, cy), pantallaY(cx, cy));
  int rayos = 18;
  for (int k = 0; k <= rayos; k++) {
    float a = ang - apertura + 2 * apertura * k / rayos;
    float largo = alcanceRayo(cx, cy, a, rango);
    float px = cx + cos(a) * largo;
    float py = cy + sin(a) * largo;
    vertex(pantallaX(px, py), pantallaY(px, py));
  }
  endShape(CLOSE);
}

float alcanceRayo(float cx, float cy, float a, float rango) {
  for (float d = 0.1; d < rango; d += 0.1) {
    if (mapa.bloqueaVista(floor(cx + cos(a) * d), floor(cy + sin(a) * d))) return d;
  }
  return rango;
}

// Tecla V: muestra el camino que BFS le dio a cada vigilante
void dibujarRutas() {
  strokeWeight(2 * escala);
  for (Vigilante v : vigilantes) {
    color c = color(255, 255, 255, 160);
    if (v.estado == V_SOSPECHA) c = color(255, 180, 60, 200);
    if (v.estado == V_ALERTA) c = color(235, 60, 50, 220);
    stroke(c);
    float ax = v.x;
    float ay = v.y;
    for (int[] p : v.camino) {
      float bx = p[0] + 0.5;
      float by = p[1] + 0.5;
      line(pantallaX(ax, ay), pantallaY(ax, ay), pantallaX(bx, by), pantallaY(bx, by));
      ax = bx;
      ay = by;
    }
    noStroke();
    fill(c);
    for (int[] p : v.camino) {
      rect(pantallaX(p[0] + 0.5, p[1] + 0.5) - 2 * escala, pantallaY(p[0] + 0.5, p[1] + 0.5) - 2 * escala, 4 * escala, 4 * escala);
    }
    // puntos de la ronda
    noFill();
    stroke(255, 255, 255, 90);
    for (int[] p : v.ruta) {
      float sx = pantallaX(p[0] + 0.5, p[1] + 0.5);
      float sy = pantallaY(p[0] + 0.5, p[1] + 0.5);
      quad(sx, sy - 6 * escala, sx + 12 * escala, sy, sx, sy + 6 * escala, sx - 12 * escala, sy);
    }
  }
}

// ---------------------------------------------------------------------------
// Capa ordenada: bloques altos y personas, diagonal por diagonal
// ---------------------------------------------------------------------------

void dibujarCapaOrdenada() {
  int diagonales = mapa.ancho + mapa.alto - 1;
  for (int d = 0; d < diagonales; d++) {
    // Primero las personas de esta diagonal y luego los bloques, porque el
    // centro de un bloque de la diagonal d esta en d + 1 (un poco mas adelante)
    for (Jugador j : jugadores) {
      if (!j.escondido && floor(j.x + j.y) == d) dibujarJugador(j);
    }
    for (Vigilante v : vigilantes) {
      if (floor(v.x + v.y) == d) dibujarVigilante(v);
    }
    for (Civil c : civiles) {
      if (floor(c.x + c.y) == d) dibujarCivil(c);
    }
    for (int i = max(0, d - (mapa.alto - 1)); i <= min(mapa.ancho - 1, d); i++) {
      dibujarBaldosaAlta(i, d - i);
    }
  }
}

// Paredes, muebles y objetos de una baldosa. Cada sprite tiene la esquina de
// atras de la baldosa en un punto fijo, por eso se corre hacia arriba segun
// lo alto que sea (pared 28 px, muebles 40 px de espacio arriba).
void dibujarBaldosaAlta(int i, int j) {
  char c = mapa.celdas[i][j];
  float sx = pantallaX(i, j) - 16 * pixel;
  float sy = pantallaY(i, j);
  if (sx < -anchoBaldosa * 2 || sx > width + anchoBaldosa || sy < -altoPared * 2 || sy > height + altoPared * 2) return;
  float corte = mapa.corte[i][j];

  if (c == '#' || mapa.esPuertaCerrada(i, j)) {
    // Pared (o puerta cerrada) entera que se desvanece y deja ver una pared
    // baja cuando tapa a alguien
    if (corte > 0.02) {
      tinteLuz(i, j, 255 * corte);
      sprite(paredBaja, sx, sy - 6 * pixel);
      if (corte >= 0.98) bordeSprite(paredBaja, sx, sy - 6 * pixel, i, j);
    }
    if (corte < 0.98) {
      float alfa = 255 * (1 - corte);
      PImage img = paredLadrillo[(i * 7 + j * 13) % 2];
      PImage luzImg = null;
      if (c != '#') {
        img = spriteObjeto[c];
        luzImg = spriteObjetoLuz[c];
      } else if (mapa.adorno[i][j] == 1) {
        img = paredNeon;
        luzImg = paredNeonLuz;
      } else if (mapa.adorno[i][j] == 2) {
        img = paredLetrero;
        luzImg = paredLetreroLuz;
      }
      tinteLuz(i, j, alfa);
      sprite(img, sx, sy - 28 * pixel);
      if (luzImg != null) {
        tint(255, alfa);   // lo que brilla no se oscurece
        sprite(luzImg, sx, sy - 28 * pixel);
      }
      luzSprite(img, sx, sy - 28 * pixel, i, j);
      bordeSprite(img, sx, sy - 28 * pixel, i, j);
    }
  } else if (c < 128 && spriteObjeto[c] != null) {
    float alfa = 255 * (1 - 0.6 * corte);
    PImage luzImg = spriteObjetoLuz[c];
    if (c == 'S' && servidorCopiado) luzImg = servidorLuzCopiado;
    boolean apagada = mapa.zonaApagada[mapa.zona[i][j]] && c != 'S';
    tinteLuz(i, j, alfa);
    sprite(spriteObjeto[c], sx, sy - 40 * pixel);
    if (luzImg != null && !apagada) {
      tint(255, alfa);
      sprite(luzImg, sx, sy - 40 * pixel);
    }
    luzSprite(spriteObjeto[c], sx, sy - 40 * pixel, i, j);
    bordeSprite(spriteObjeto[c], sx, sy - 40 * pixel, i, j);
    noTint();
    // la flechita sobra cuando ya tiene la etiqueta encima
    if (marca != null && marca[i][j] >= 1) return;
    // flechitas sobre lo que se puede recoger o usar
    // solo se marca lo que falta de la ruta: tarjetas que hacen falta, el
    // servidor y, ya copiado, la camioneta
    if (paradaPendiente(i, j, c)) marcador(i + 0.5, j + 0.5, c == 'S' ? 40 : (c == 'E' ? 30 : 14), colorParada(c == 'S' ? 5 : (c == 'E' ? 6 : "-rbyn".indexOf(c))));
  }
  noTint();
}

// Flechita que sube y baja encima de algo importante
void marcador(float x, float y, float alto, color c) {
  float sx = pantallaX(x, y);
  float sy = pantallaY(x, y) - (alto + 6) * pixel + sin(millis() / 200.0) * 2 * pixel;
  noStroke();
  fill(c);
  triangle(sx - 4 * pixel, sy - 5 * pixel, sx + 4 * pixel, sy - 5 * pixel, sx, sy);
}

// Botellas volando (con su sombra en el piso) y vidrio roto
void dibujarProyectiles() {
  noStroke();
  for (Proyectil p : proyectiles) {
    float sx = pantallaX(p.x(), p.y());
    float sy = pantallaY(p.x(), p.y());
    fill(0, 110);
    ellipse(sx, sy, 6 * pixel, 3 * pixel);
    fill(#1E7A4C);
    rect(round(sx - pixel), round(sy - (10 + p.altura()) * pixel), 2 * pixel, 5 * pixel);
    fill(NEON_VERDE);
    rect(round(sx - pixel), round(sy - (10 + p.altura()) * pixel), pixel, pixel);
  }
  for (Particula q : particulas) {
    fill(red(q.c), green(q.c), blue(q.c), 255 * q.vida / 0.6);
    rect(round(pantallaX(q.x, q.y)), round(pantallaY(q.x, q.y) - 3 * pixel), pixel, pixel);
  }
}

// Los ductos se ven como lineas punteadas entre sus rejillas
void dibujarDuctos(int alfa) {
  stroke(25, 227, 227, alfa);
  strokeWeight(2 * pixel);
  for (int[] d : mapa.ductos) {
    int[] a = mapa.rejillas.get(d[0]);
    int[] b = mapa.rejillas.get(d[1]);
    // el ducto va en L: primero en x y luego en y
    float[][] puntos = {{a[0] + 0.5, a[1] + 0.5}, {b[0] + 0.5, a[1] + 0.5}, {b[0] + 0.5, b[1] + 0.5}};
    for (int k = 0; k < 2; k++) {
      float largo = dist(puntos[k][0], puntos[k][1], puntos[k + 1][0], puntos[k + 1][1]);
      for (float t = 0; t < largo; t += 0.6) {
        float u0 = t / max(0.01, largo);
        float u1 = min(1, (t + 0.3) / max(0.01, largo));
        float x0 = lerp(puntos[k][0], puntos[k + 1][0], u0), y0 = lerp(puntos[k][1], puntos[k + 1][1], u0);
        float x1 = lerp(puntos[k][0], puntos[k + 1][0], u1), y1 = lerp(puntos[k][1], puntos[k + 1][1], u1);
        line(pantallaX(x0, y0), pantallaY(x0, y0) - 30 * pixel, pantallaX(x1, y1), pantallaY(x1, y1) - 30 * pixel);
      }
    }
  }
}

// Brillo de lo que da luz (farol, pantallas, letreros), encima de todo
void dibujarResplandores() {
  for (float[] f : mapa.fuentesLuz) {
    float sx = pantallaX(f[0], f[1]);
    float sy = pantallaY(f[0], f[1]) - f[7] * pixel;
    if (fueraDePantalla(sx, sy, anchoBaldosa * 1.5)) continue;
    manchaLuz(sx, sy, 1.0, color(f[2], f[3], f[4]), 170 * f[6], false);
  }
}

// ---------------------------------------------------------------------------
// Personas
// ---------------------------------------------------------------------------

void dibujarJugador(Jugador j) {
  SpritesPersona s = j.numero == 1 ? spritesJugador1 : spritesJugador2;
  if (j.disfrazado) s = j.numero == 1 ? spritesConserje1 : spritesConserje2;
  dibujarPersona(s, j.x, j.y, atan2(j.dirY, j.dirX), j.agachado, j.moviendose, j.sombra > 0 ? 110 : 255, null);
  if (jugadores.size() > 1) {
    textFont(letraChica);
    textAlign(CENTER, BOTTOM);
    fill(j.ropa);
    text("J" + j.numero, pantallaX(j.x, j.y), pantallaY(j.x, j.y) - (j.agachado ? 22 : 30) * pixel);
  }
}

void dibujarVigilante(Vigilante v) {
  if (v.inconsciente) {
    if (!v.cuerpoEscondido) dibujarCuerpo(v.esJefe ? spritesJefe : spritesVigilante, v);
    return;
  }
  boolean camina = (v.camino.size() > 0 && v.estado != V_BUSCANDO) || v.estado == V_ALERTA;
  dibujarPersona(v.esJefe ? spritesJefe : spritesVigilante, v.x, v.y, v.angulo, false, camina, 255, v);
}

// Persona noqueada: el sprite acostado en el piso
void dibujarCuerpo(SpritesPersona s, Persona p) {
  float sx = round(pantallaX(p.x, p.y));
  float sy = round(pantallaY(p.x, p.y));
  noStroke();
  fill(0, 120);
  ellipse(sx, sy, 26 * pixel, 7 * pixel);
  PImage img = s.frente[0];
  pushMatrix();
  translate(sx - 13 * pixel, sy - 4 * pixel);
  rotate(HALF_PI);
  int i = constrain(floor(p.x), 0, mapa.ancho - 1);
  int j = constrain(floor(p.y), 0, mapa.alto - 1);
  tint(min(255, mapa.luzR[i][j] * 280), min(255, mapa.luzG[i][j] * 280), min(255, mapa.luzB[i][j] * 280));
  image(img, -8 * pixel, -27 * pixel, img.width * pixel, img.height * pixel);
  color borde = colorMarcaDe(p);
  if (borde != 0) contornoPersona(img, borde, marcaDe(p));
  popMatrix();
  noTint();
}

// (x, y) son los pies en la cuadricula. Se elige el sprite segun hacia donde
// mira en pantalla: de frente o de espaldas, y se voltea si mira a la derecha.
void dibujarPersona(SpritesPersona s, float x, float y, float ang, boolean agachado, boolean camina, float alfa, Persona p) {
  float sx = round(pantallaX(x, y));
  float sy = round(pantallaY(x, y));
  float mx = cos(ang) - sin(ang);
  float my = (cos(ang) + sin(ang)) * 0.5;
  boolean espalda = my < -0.05;
  PImage img;
  if (agachado && s.frenteAgachado != null) {
    img = espalda ? s.espaldaAgachado : s.frenteAgachado;
  } else {
    int cuadro = camina ? 1 + (millis() / 160) % 2 : 0;
    img = espalda ? s.espalda[cuadro] : s.frente[cuadro];
  }
  noStroke();
  fill(0, 120);
  ellipse(sx, sy, 13 * pixel, 5 * pixel);
  // la gente se ve un poco mas clara que el fondo para que se lea bien
  int i = constrain(floor(x), 0, mapa.ancho - 1);
  int j = constrain(floor(y), 0, mapa.alto - 1);
  tint(min(255, mapa.luzR[i][j] * 300), min(255, mapa.luzG[i][j] * 300), min(255, mapa.luzB[i][j] * 300), alfa);
  pushMatrix();
  translate(sx, sy);
  if (mx > 0) scale(-1, 1);
  image(img, -8 * pixel, -27 * pixel, img.width * pixel, img.height * pixel);
  color borde = p == null ? 0 : colorMarcaDe(p);
  if (borde != 0) contornoPersona(img, borde, marcaDe(p));
  popMatrix();
  noTint();
}

// ---------------------------------------------------------------------------
// Camaras y simbolos encima de la gente
// ---------------------------------------------------------------------------

void dibujarAparatosCamara() {
  for (CamaraSeguridad cam : camaras) {
    float sx = round(pantallaX(cam.x, cam.y));
    float sy = round(pantallaY(cam.x, cam.y) - 24 * pixel);
    float mx = cos(cam.angulo) - sin(cam.angulo);
    float my = (cos(cam.angulo) + sin(cam.angulo)) * 0.5;
    float p = pixel;
    noStroke();
    fill(10, 10, 18);
    rect(sx - 4 * p, sy - 3 * p, 8 * p, 6 * p);
    fill(#3E5478);
    rect(sx - 3 * p, sy - 2 * p, 6 * p, 4 * p);
    fill(10, 10, 18);
    rect(sx - 1 * p + round(mx * 3) * p, sy - 1 * p + round(my * 2) * p, 3 * p, 3 * p);
    boolean parpadeo = (frameCount / 20) % 2 == 0 && camarasEncendidas() && cam.hackeada <= 0;
    color led = cam.viendo ? COLOR_RIVAL : (parpadeo ? NEON_VERDE : color(20, 60, 40));
    fill(led);
    rect(sx + 2 * p, sy - 2 * p, p, p);
    if (cam.viendo || parpadeo) manchaLuz(sx + 2.5 * p, sy - 1.5 * p, 0.35, led, 160, false);
    if (cam.sospecha > 1) medidor(sx, sy - 10 * p, cam.sospecha, COLOR_RIVAL);
  }
}

void dibujarIndicadores() {
  // Fantasma de cada vigilante por encima de todo: si una pared lo tapa,
  // igual se ve donde esta (como en Project Zomboid o Mark of the Ninja)
  for (Vigilante v : vigilantes) {
    if (v.inconsciente) continue;
    boolean camina = (v.camino.size() > 0 && v.estado != V_BUSCANDO) || v.estado == V_ALERTA;
    float sx = round(pantallaX(v.x, v.y));
    float sy = round(pantallaY(v.x, v.y));
    float mx = cos(v.angulo) - sin(v.angulo);
    float my = (cos(v.angulo) + sin(v.angulo)) * 0.5;
    SpritesPersona sv = v.esJefe ? spritesJefe : spritesVigilante;
    PImage img = my < -0.05 ? sv.espalda[camina ? 1 + (millis() / 160) % 2 : 0]
      : sv.frente[camina ? 1 + (millis() / 160) % 2 : 0];
    tint(red(v.colorRonda), green(v.colorRonda), blue(v.colorRonda), 60);
    pushMatrix();
    translate(sx, sy);
    if (mx > 0) scale(-1, 1);
    image(img, -8 * pixel, -27 * pixel, img.width * pixel, img.height * pixel);
    popMatrix();
    noTint();
  }
  for (Vigilante v : vigilantes) {
    float sx = pantallaX(v.x, v.y);
    float sy = pantallaY(v.x, v.y) - 36 * pixel;
    if (v.inconsciente) {
      if (v.radioSonando > 0) iconoRadio(v);
      else if (!v.cuerpoEscondido) dibujarZetas(sx + 10 * pixel, pantallaY(v.x, v.y) - 14 * pixel);
    } else if (v.estado == V_ALERTA) {
      simbolo(sx, sy, "!", COLOR_RIVAL);
    } else if (v.sospecha > 1 || v.estado != V_PATRULLA) {
      medidor(sx, sy, v.sospecha, COLOR_AMBAR);
      simbolo(sx, sy, "?", COLOR_AMBAR);
    }
  }
  for (Civil c : civiles) {
    float sx = pantallaX(c.x, c.y);
    float sy = pantallaY(c.x, c.y) - 36 * pixel;
    if (c.inconsciente) {
      if (!c.cuerpoEscondido) dibujarZetas(sx + 10 * pixel, pantallaY(c.x, c.y) - 14 * pixel);
    } else if (c.estado == C_HUYENDO) {
      simbolo(sx, sy, "!", NEON_MAGENTA);
    } else if (c.sospecha > 1) {
      medidor(sx, sy, c.sospecha, NEON_MAGENTA);
      simbolo(sx, sy, "?", NEON_MAGENTA);
    }
  }
  dibujarObjetosMarcados();
  dibujarEfectosRol();
  dibujarRescates();
  dibujarTextosFlotantes();
  dibujarEquipo();
  dibujarCharla();
  // Tecla y accion encima de lo que se puede usar
  dibujarEtiquetasUso();
  dibujarRadios();
  // Estado del jugador (escondido, en el ducto) encima de el
  for (Jugador j : jugadores) {
    String pista = pistaPara(j);
    if (pista.equals("")) continue;
    float sx = pantallaX(j.x, j.y);
    float sy = pantallaY(j.x, j.y) - (j.escondido ? 18 : 40) * pixel;
    textFont(letraChica);
    float w = textWidth(pista) + 14 * escala;
    stroke(25, 227, 227, 120);
    strokeWeight(1);
    fill(15, 20, 36, 225);
    rect(sx - w / 2, sy - 10 * escala, w, 20 * escala, 3 * escala);
    fill(#F2F2E9);
    textAlign(CENTER, CENTER);
    text(pista, sx, sy);
  }
}

// Lo que se le muestra al jugador encima de el cuando esta escondido o en un
// ducto. Lo que se puede usar se marca en el objeto (Interaccion.pde).
String pistaPara(Jugador j) {
  String t = "[" + j.teclaUsar() + "] ";
  if (estado != JUGANDO) return "";
  if (j.enDucto) {
    if (j.viajeDucto >= 0) return "Gateando por el ducto...";
    int[] r = mapa.rejillas.get(j.destinosDucto.get(j.opcionDucto));
    return "Ducto hacia " + NOMBRES_ZONA[mapa.zonaEn(r[0], r[1])] + "  " + t + "cambiar";
  }
  if (j.escondido) return (jugadores.size() > 1 ? "J" + j.numero + " escondido · " : "") + t + "Salir";
  return "";
}

// "z z" que sube encima de alguien noqueado
void dibujarZetas(float x, float y) {
  textFont(letraChica);
  textAlign(CENTER, CENTER);
  for (int k = 0; k < 2; k++) {
    float t = (millis() / 1400.0 + k * 0.5) % 1;
    fill(200, 210, 255, 220 * (1 - t));
    text("z", x + k * 6 * escala + t * 4 * escala, y - t * 14 * escala);
  }
}

void simbolo(float x, float y, String s, color c) {
  stroke(c);
  strokeWeight(1.5 * escala);
  fill(15, 20, 36, 230);
  ellipse(x, y, 20 * escala, 20 * escala);
  textFont(letraMedia);
  textAlign(CENTER, CENTER);
  fill(c);
  text(s, x, y - 1 * escala);
}

void medidor(float x, float y, float valor, color c) {
  noFill();
  strokeWeight(3 * escala);
  stroke(0, 160);
  ellipse(x, y, 26 * escala, 26 * escala);
  stroke(c);
  arc(x, y, 26 * escala, 26 * escala, -HALF_PI, -HALF_PI + TWO_PI * valor / 100);
}

// ---------------------------------------------------------------------------
// Reconocimiento: el plano con las rondas
// ---------------------------------------------------------------------------

// Se dibuja encima del mundo: la zona que barre cada camara, la ronda
// completa de cada vigilante (con un color por vigilante) y etiquetas de
// los lugares importantes.
void dibujarPlano() {
  for (CamaraSeguridad cam : camaras) {
    dibujarCono(cam.x, cam.y, cam.anguloBase, cam.amplitud + cam.APERTURA, cam.RANGO, color(25, 227, 227, 45));
  }

  for (int n = 0; n < vigilantes.size(); n++) {
    Vigilante v = vigilantes.get(n);
    ArrayList<int[]> r = v.rondaCompleta;
    stroke(red(v.colorRonda), green(v.colorRonda), blue(v.colorRonda), rutaMision.size() > 1 ? 110 : 210);   // tenues: resalta la ruta
    strokeWeight((rutaMision.size() > 1 ? 3 : 4) * escala);
    for (int k = 0; k + 1 < r.size(); k++) {
      int[] a = r.get(k);
      int[] b = r.get(k + 1);
      line(pantallaX(a[0] + 0.5, a[1] + 0.5), pantallaY(a[0] + 0.5, a[1] + 0.5),
        pantallaX(b[0] + 0.5, b[1] + 0.5), pantallaY(b[0] + 0.5, b[1] + 0.5));
    }
    // Donde se detiene a mirar
    noStroke();
    fill(v.colorRonda);
    for (int[] p : v.ruta) {
      float sx = pantallaX(p[0] + 0.5, p[1] + 0.5);
      float sy = pantallaY(p[0] + 0.5, p[1] + 0.5);
      quad(sx, sy - 7 * escala, sx + 14 * escala, sy, sx, sy + 7 * escala, sx - 14 * escala, sy);
    }
  }

  dibujarDuctos(200);
  dibujarRutaMision();

  // Nombre de cada cuarto en su centro
  float[] sumaX = new float[NOMBRES_ZONA.length];
  float[] sumaY = new float[NOMBRES_ZONA.length];
  int[] cuenta = new int[NOMBRES_ZONA.length];
  for (int i = 0; i < mapa.ancho; i++) {
    for (int j = 0; j < mapa.alto; j++) {
      if (mapa.esPared(i, j)) continue;
      int z = mapa.zona[i][j];
      sumaX[z] += i + 0.5;
      sumaY[z] += j + 0.5;
      cuenta[z]++;
    }
  }
  // BFS sobre el grafo de cuartos: los que no se alcanzan sin tarjetas salen con candado
  boolean[] alcanza = mapa.zonasAlcanzables(tarjetas);
  for (int z = 1; z < NOMBRES_ZONA.length; z++) {
    if (cuenta[z] > 0) textoMundo(sumaX[z] / cuenta[z], sumaY[z] / cuenta[z], (alcanza[z] ? "" : "[cerrado] ") + NOMBRES_ZONA[z]);
  }

  boolean servidorMarcado = false;
  boolean camionetaMarcada = false;
  for (int i = 0; i < mapa.ancho; i++) {
    for (int j = 0; j < mapa.alto; j++) {
      char c = mapa.celdas[i][j];
      // solo se rotula lo de la ruta (dibujarRutaMision); lo demás ya no se marca
      if (c == 'S' && !servidorMarcado && rutaMision.size() < 2) {
        etiquetaMundo(i + 0.5, j + 0.5, "SERVIDOR", COLOR_AMBAR);
        servidorMarcado = true;
      }
    }
  }
}

// Texto suelto sobre el plano (nombres de cuartos)
void textoMundo(float x, float y, String texto) {
  float sx = pantallaX(x, y);
  float sy = pantallaY(x, y);
  pushMatrix();
  translate(sx, sy);
  scale(0.8 / zoom);
  textFont(letraMedia);
  textAlign(CENTER, CENTER);
  fill(0, 170);
  text(texto, 1.5 * escala, 1.5 * escala);
  fill(242, 242, 233, 210);
  text(texto, 0, 0);
  popMatrix();
}

// Etiqueta con recuadro; se dibuja a tamano fijo aunque el plano este alejado
void etiquetaMundo(float x, float y, String texto, color c) {
  float sx = pantallaX(x, y);
  float sy = pantallaY(x, y) - altoPared * 1.15;
  pushMatrix();
  translate(sx, sy);
  scale(0.75 / zoom);
  textFont(letraMedia);
  float w = textWidth(texto) + 14 * escala;
  stroke(c);
  strokeWeight(1.5 * escala);
  fill(15, 20, 36, 230);
  rect(-w / 2, -12 * escala, w, 24 * escala, 4 * escala);
  fill(c);
  textAlign(CENTER, CENTER);
  text(texto, 0, -1 * escala);
  popMatrix();
}
