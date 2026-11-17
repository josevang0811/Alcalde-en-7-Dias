// Marcas de lo que se puede usar. Al acercarse, el objeto se marca con un
// borde que palpita y encima sale la tecla y la accion. El color dice que
// pasa: cian se usa, verde se recoge, ambar esta cerrado y falta algo.
// De mas lejos (RADIO_BRILLO) lo usable tiene un borde suave.

final float RADIO_BRILLO = 4;

// Que hay para usar al lado de un jugador
class Interaccion {
  int i, j;           // baldosa del objeto
  Persona persona;    // o la persona (para noquear o arrastrar)
  String accion;
  boolean conTecla;   // false: solo informa, no hay nada que presionar
  color c;

  Interaccion(int[] t, String accion, boolean conTecla, color c) {
    i = t[0];
    j = t[1];
    this.accion = accion;
    this.conTecla = conTecla;
    this.c = c;
  }

  // Para marcar a un jugador (el compañero esposado): solo la etiqueta
  float px, py;
  boolean enPunto;
  Interaccion(float x, float y, String accion, color c) {
    i = -1;
    j = -1;
    px = x;
    py = y;
    enPunto = true;
    this.accion = accion;
    this.conTecla = true;
    this.c = c;
  }

  Interaccion(Persona p, String accion, color c) {
    persona = p;
    i = -1;
    j = -1;
    this.accion = accion;
    this.conTecla = true;
    this.c = c;
  }
}

// Marca de cada persona en este cuadro (noquear, arrastrar, cuerpo cerca)
HashMap<Persona, Float> marcaPersona = new HashMap<Persona, Float>();
HashMap<Persona, Integer> colorPersona = new HashMap<Persona, Integer>();

float marcaDe(Persona p) {
  Float f = marcaPersona.get(p);
  return f == null ? 0 : f;
}

color colorMarcaDe(Persona p) {
  Integer c = colorPersona.get(p);
  return c == null ? 0 : c;
}

// Contorno de una persona (se llama ya trasladado a sus pies, despues de
// dibujarla)
void contornoPersona(PImage img, color c, float f) {
  PImage b = contorno(img);
  float pulso = f >= 1 ? 0.65 + 0.35 * sin(millis() / 140.0) : 0.8 + 0.2 * sin(millis() / 400.0);
  tint(red(c), green(c), blue(c), 255 * f * pulso);
  // dos pixeles de grueso: la gente es chica y se mueve
  image(b, -9 * pixel, -28 * pixel, b.width * pixel, b.height * pixel);
  int[][] lados = {{-1, 0}, {1, 0}, {0, -1}, {0, 1}};
  for (int[] d : lados) image(b, (-9 + d[0]) * pixel, (-28 + d[1]) * pixel, b.width * pixel, b.height * pixel);
  noTint();
}

// Fuerza de la marca de cada baldosa en este cuadro (0 nada, 1 la de al lado)
float[][] marca;
color[][] colorMarca;
// Silueta blanca de cada sprite y la primera fila con pixeles (para la etiqueta)
HashMap<PImage, PImage> siluetas = new HashMap<PImage, PImage>();
HashMap<PImage, Integer> filaArriba = new HashMap<PImage, Integer>();

// Mismo orden que usar(): lo primero que se encuentra es lo que se hace
Interaccion interaccionPara(Jugador j) {
  if (estado != JUGANDO || j.enDucto || j.escondido || ventana != 0 || j.contestando != null) return null;
  int[] t;
  if (j.atrapado) return null;
  Jugador esposado = companeroAtrapado(j);
  if (esposado != null) return new Interaccion(esposado.x, esposado.y, "Mantén: soltar a J" + esposado.numero, NEON_VERDE);
  int sal = salidaCercana(j);
  if (sal >= 0 && servidorCopiado) {
    String b = bloqueoSalida(sal);
    int[] ts = sal == SALIDA_DUCTO ? new int[] {DUCTO_CALLE_I, DUCTO_CALLE_J} : mapa.cercano(j.x, j.y, sal == SALIDA_CAMIONETA ? 'E' : 'm', 1.6);
    if (b.equals("")) return new Interaccion(ts, "Escapar en " + (sal == SALIDA_DUCTO ? "el ducto" : "la " + NOMBRES_SALIDA[sal]), true, NEON_VERDE);
    return new Interaccion(ts, b, false, COLOR_AMBAR);
  }
  Vigilante radio = radioCercana(j);
  if (radio != null) return new Interaccion(radio, "Contestar la radio", NEON_CIAN);
  if (j.arrastrando != null) {
    if ((t = esconditeParaCuerpo(j)) != null) return new Interaccion(t, "Esconder el cuerpo", true, NEON_CIAN);
    return new Interaccion(j.arrastrando, "Soltar", NEON_CIAN);
  }
  Persona p = aQuienNoquear(j);
  if (p != null) return new Interaccion(p, "Noquear", NEON_MAGENTA);
  if ((p = cuerpoCercano(j)) != null) return new Interaccion(p, "Arrastrar", NEON_CIAN);
  if ((t = botinCercano(j)) != null) {
    int k = indiceBotin(mapa.celdas[t[0]][t[1]]);
    String dato = PESO_BOTIN[k] + " kg, " + VALOR_BOTIN[k] + " pts";
    if (!cabeEnMochila(j, t)) return new Interaccion(t, NOMBRES_BOTIN[k] + " (" + dato + "): no cabe, " + (j.numero == 1 ? "X" : "K") + " suelta", false, COLOR_AMBAR);
    return new Interaccion(t, "Guardar " + NOMBRES_BOTIN[k] + " (" + dato + ")", true, NEON_VERDE);
  }
  if (!soloEscapar() && (t = mapa.cercano(j.x, j.y, 'r', 1.2)) != null) return new Interaccion(t, "Tomar tarjeta roja", true, NEON_VERDE);
  if (!soloEscapar() && (t = mapa.cercano(j.x, j.y, 'b', 1.2)) != null) return new Interaccion(t, "Tomar tarjeta azul", true, NEON_VERDE);
  if (!soloEscapar() && (t = mapa.cercano(j.x, j.y, 'y', 1.2)) != null) return new Interaccion(t, "Tomar tarjeta amarilla", true, NEON_VERDE);
  if (!soloEscapar() && (t = mapa.cercano(j.x, j.y, 'n', 1.2)) != null) return new Interaccion(t, "Leer nota", true, NEON_VERDE);
  if ((t = mapa.cercano(j.x, j.y, 'o', 1.2)) != null) return new Interaccion(t, "Tomar botella", true, NEON_VERDE);
  if ((t = mapa.puertaCercana(j.x, j.y, 1.3)) != null) {
    int k = mapa.celdas[t[0]][t[1]] - '0';
    if (k == 4) return new Interaccion(t, "Teclado (" + codigoConocido() + ")", true, tarjetas[4] ? NEON_CIAN : COLOR_AMBAR);
    if (tarjetas[k]) return new Interaccion(t, "Abrir", true, NEON_CIAN);
    if (jugadores.size() > 1 && t[0] == PESADA_I && t[1] == PESADA_J) return new Interaccion(t, "Mantengan los dos: empujar", true, NEON_VERDE);
    return new Interaccion(t, k == 4 ? "Falta el código" : "Falta tarjeta " + NOMBRES_TARJETA[k], false, COLOR_AMBAR);
  }
  if ((t = mapa.cercano(j.x, j.y, 'v', 1.1)) != null) return new Interaccion(t, "Ducto", true, NEON_CIAN);
  if ((t = mapa.cercano(j.x, j.y, 'T', 1.4)) != null) {
    int k = indiceTablero(t[0], t[1]);
    boolean apagado = k >= 0 && mapa.zonaApagada[mapa.zonasTablero.get(k)[0]];
    if (tablerosBloqueados()) return new Interaccion(t, "Bloqueado", false, COLOR_AMBAR);
    return new Interaccion(t, apagado ? "Prender la luz" : "Cortar la luz", true, NEON_CIAN);
  }
  if (!servidorCopiado && (t = mapa.cercano(j.x, j.y, 'S', 1.4)) != null) {
    return new Interaccion(t, progresoServidor > 0 ? "Mantén: copiar " + round(progresoServidor * 100) + "%" : "Mantén: copiar (después solo escapas)", true, NEON_CIAN);
  }
  int op = oportunidadCercana(j);
  if (op >= 0) {
    t = mapa.cercano(j.x, j.y, OBJETO_OPORTUNIDAD[op], RADIO_OPORTUNIDAD[op]);
    String[] acciones = {"Mantén: cambiar el borrador", "Tomar foto (hace ruido)", "Mantén: sabotear"};
    return new Interaccion(t, acciones[op], true, NEON_MAGENTA);
  }
  if (soloEscapar()) {
    // ya no se revisa nada: solo lo que sirve para escapar
    if (puedeTomarUniforme(j)) return new Interaccion(mapa.cercano(j.x, j.y, 'Z', 1.5), "Ponerse el uniforme", true, NEON_VERDE);
    if ((t = mapa.cercano(j.x, j.y, 'A', 1.3)) != null) {
      if (esconditeOcupado(t[0], t[1])) return new Interaccion(t, "Ocupado", false, COLOR_AMBAR);
      return new Interaccion(t, "Esconderse", true, NEON_CIAN);
    }
    return null;
  }
  if ((t = mapa.cercano(j.x, j.y, 'O', 1.6)) != null) return new Interaccion(t, "Leer", true, NEON_CIAN);
  if ((t = mapa.cercano(j.x, j.y, 'X', 1.9)) != null) return new Interaccion(t, "Ver el tablero", true, NEON_CIAN);
  if ((t = mapa.cercano(j.x, j.y, 'U', 1.6)) != null) return new Interaccion(t, "Leer", true, NEON_CIAN);
  if ((t = mapa.cercano(j.x, j.y, 'W', 1.9)) != null) return new Interaccion(t, "Ver la TV", true, NEON_CIAN);
  if ((t = mapa.cercano(j.x, j.y, 'Q', 1.5)) != null) return new Interaccion(t, "Usar la consola", true, NEON_CIAN);
  if (puedeTomarUniforme(j)) return new Interaccion(mapa.cercano(j.x, j.y, 'Z', 1.5), "Ponerse el uniforme", true, NEON_VERDE);
  if ((t = mapa.cercano(j.x, j.y, 'A', 1.3)) != null) {
    if (esconditeOcupado(t[0], t[1])) return new Interaccion(t, "Ocupado", false, COLOR_AMBAR);
    return new Interaccion(t, "Esconderse", true, NEON_CIAN);
  }
  if ((t = mapa.cercano(j.x, j.y, 'E', 1.6)) != null) return new Interaccion(t, "Salida: primero copia el servidor", false, COLOR_AMBAR);
  return null;
}

// Color con que se marca una baldosa usable, o 0 si no se puede usar
color colorUsable(int i, int j) {
  char c = mapa.celdas[i][j];
  if (soloEscapar() && "PrbynhlOXUWQS".indexOf(c) >= 0) return 0;
  if ("Prbynohl".indexOf(c) >= 0) return NEON_VERDE;
  if (mapa.esPuertaCerrada(i, j)) return tarjetas[c - '0'] ? NEON_CIAN : COLOR_AMBAR;
  if ("vTOXUWAQ".indexOf(c) >= 0) return NEON_CIAN;
  if (c == 'Z') {   // casillero con uniformes: mientras alguien no lo tenga puesto
    for (Jugador p : jugadores) {
      if (!p.disfrazado) return NEON_VERDE;
    }
  }
  if (c == 'S' && !servidorCopiado) return NEON_CIAN;
  if ((c == 'E' || c == 'm') && servidorCopiado) return NEON_VERDE;
  return 0;
}

// Se llama una vez por cuadro antes de dibujar el mundo
void actualizarMarcas() {
  if (marca == null || marca.length != mapa.ancho || marca[0].length != mapa.alto) {
    marca = new float[mapa.ancho][mapa.alto];
    colorMarca = new color[mapa.ancho][mapa.alto];
  }
  for (int i = 0; i < mapa.ancho; i++) {
    for (int j = 0; j < mapa.alto; j++) marca[i][j] = 0;
  }
  marcaPersona.clear();
  colorPersona.clear();
  if (estado != JUGANDO) return;
  // Cuerpos tirados cerca: borde suave para que se vean
  for (Persona q : personas()) {
    if (!q.inconsciente || q.cuerpoEscondido) continue;
    for (Jugador p : jugadores) {
      float d = dist(p.x, p.y, q.x, q.y);
      if (d <= RADIO_BRILLO) ponerMarcaPersona(q, map(d, 0, RADIO_BRILLO, 0.6, 0.3), NEON_CIAN);
    }
  }
  int r = ceil(RADIO_BRILLO);
  for (Jugador p : jugadores) {
    if (p.enDucto) continue;
    for (int i = max(0, floor(p.x) - r); i <= min(mapa.ancho - 1, floor(p.x) + r); i++) {
      for (int j = max(0, floor(p.y) - r); j <= min(mapa.alto - 1, floor(p.y) + r); j++) {
        float d = dist(p.x, p.y, i + 0.5, j + 0.5);
        if (d > RADIO_BRILLO) continue;
        color c = colorUsable(i, j);
        if (c == 0) continue;
        // mas cerca, un poco mas fuerte
        float f = map(d, 0, RADIO_BRILLO, 0.6, 0.3);
        if (f > marca[i][j]) {
          marca[i][j] = f;
          colorMarca[i][j] = c;
        }
      }
    }
    Interaccion it = interaccionPara(p);
    if (it != null && it.enPunto) {
      // sin borde: la etiqueta basta
    } else if (it != null && it.persona != null) {
      ponerMarcaPersona(it.persona, 1, it.c);
    } else if (it != null) {
      marca[it.i][it.j] = 1;
      colorMarca[it.i][it.j] = it.c;
    }
  }
}

void ponerMarcaPersona(Persona q, float f, color c) {
  if (f <= marcaDe(q)) return;
  marcaPersona.put(q, f);
  colorPersona.put(q, c);
}

PImage silueta(PImage img) {
  PImage s = siluetas.get(img);
  if (s != null) return s;
  img.loadPixels();
  s = createImage(img.width, img.height, ARGB);
  s.loadPixels();
  int arriba = img.height;
  for (int k = 0; k < img.pixels.length; k++) {
    boolean lleno = alpha(img.pixels[k]) > 40;
    s.pixels[k] = lleno ? color(255) : color(255, 0);
    if (lleno) arriba = min(arriba, k / img.width);
  }
  s.updatePixels();
  siluetas.put(img, s);
  filaArriba.put(img, arriba);
  return s;
}

// Contorno de un sprite: los pixeles vacios que tocan uno lleno. La imagen
// tiene un pixel de mas por cada lado.
HashMap<PImage, PImage> contornos = new HashMap<PImage, PImage>();

PImage contorno(PImage img) {
  PImage c = contornos.get(img);
  if (c != null) return c;
  img.loadPixels();
  int w = img.width, h = img.height;
  c = createImage(w + 2, h + 2, ARGB);
  c.loadPixels();
  for (int y = 0; y < h + 2; y++) {
    for (int x = 0; x < w + 2; x++) {
      boolean lleno = llenoEn(img, x - 1, y - 1);
      boolean toca = llenoEn(img, x - 2, y - 1) || llenoEn(img, x, y - 1) || llenoEn(img, x - 1, y - 2) || llenoEn(img, x - 1, y);
      c.pixels[y * (w + 2) + x] = !lleno && toca ? color(255) : color(255, 0);
    }
  }
  c.updatePixels();
  contornos.put(img, c);
  return c;
}

boolean llenoEn(PImage img, int x, int y) {
  if (x < 0 || y < 0 || x >= img.width || y >= img.height) return false;
  return alpha(img.pixels[y * img.width + x]) > 40;
}

// Borde de color alrededor del sprite. Se dibuja despues del sprite y solo
// pinta por fuera, asi no se trasluce cuando el mueble se recorta.
void bordeSprite(PImage img, float x, float y, int i, int j) {
  if (marca == null || marca[i][j] <= 0) return;
  color c = colorMarca[i][j];
  float f = marca[i][j];
  float pulso = f >= 1 ? 0.65 + 0.35 * sin(millis() / 140.0) : 0.8 + 0.2 * sin(millis() / 400.0);
  float transparencia = 1 - 0.6 * mapa.corte[i][j];
  PImage b = contorno(img);
  tint(red(c), green(c), blue(c), 255 * f * pulso * transparencia);
  image(b, round(x) - pixel, round(y) - pixel, b.width * pixel, b.height * pixel);
  noTint();
}

// Encima del sprite: lo ilumina un poco (solo el que esta al lado)
void luzSprite(PImage img, float x, float y, int i, int j) {
  if (marca == null || marca[i][j] < 1) return;
  color c = colorMarca[i][j];
  float transparencia = 1 - 0.8 * mapa.corte[i][j];   // si el mueble se recorta, el brillo tambien
  tint(red(c), green(c), blue(c), (22 + 18 * sin(millis() / 140.0)) * transparencia);
  image(silueta(img), round(x), round(y), img.width * pixel, img.height * pixel);
  noTint();
}

// Brillo suave del color de la marca, para que se note de lejos
void dibujarBrilloUsable() {
  if (marca == null || estado != JUGANDO) return;
  for (int i = 0; i < mapa.ancho; i++) {
    for (int j = 0; j < mapa.alto; j++) {
      if (marca[i][j] <= 0) continue;
      float sx = pantallaX(i + 0.5, j + 0.5);
      float sy = pantallaY(i + 0.5, j + 0.5) - 10 * pixel;
      if (sx < -50 || sx > width + 50 || sy < -50 || sy > height + 50) continue;
      boolean alLado = marca[i][j] >= 1;
      float pulso = alLado ? 0.7 + 0.3 * sin(millis() / 140.0) : 0.75 + 0.25 * sin(millis() / 400.0 + i + j);
      manchaLuz(sx, sy, alLado ? 1.0 : 0.7, colorMarca[i][j], (alLado ? 230 : 230 * marca[i][j]) * pulso, false);
    }
  }
}

// Tecla y accion flotando encima del objeto
void dibujarEtiquetasUso() {
  if (estado != JUGANDO) return;
  int[] ultima = null;
  for (Jugador p : jugadores) {
    Interaccion it = interaccionPara(p);
    if (it == null) continue;
    // si los dos miran lo mismo, la segunda va un poco mas arriba
    boolean repetida = ultima != null && ultima[0] == it.i && ultima[1] == it.j && it.persona == null;
    ultima = new int[] {it.i, it.j};
    float sx, sy;
    if (it.enPunto) {
      sx = pantallaX(it.px, it.py);
      sy = pantallaY(it.px, it.py) - 46 * pixel;
    } else if (it.persona != null) {
      Persona q = it.persona;
      sx = pantallaX(q.x, q.y);
      sy = pantallaY(q.x, q.y) - (q.inconsciente ? 14 : 34) * pixel - 6 * escala;
    } else {
      sx = pantallaX(it.i + 0.5, it.j + 0.5);
      sy = pantallaY(it.i, it.j) - altoSprite(it.i, it.j) * pixel - 10 * escala;
    }
    sy += sin(millis() / 220.0) * 2 * escala - (repetida ? 26 * escala : 0);
    etiquetaUso(sx, sy, it.conTecla ? p.teclaUsar() : null, it.accion, it.c);
  }
}

// Cuanto sobresale el sprite de la baldosa (pixeles del dibujo, sin agrandar)
float altoSprite(int i, int j) {
  char c = mapa.celdas[i][j];
  PImage img = c < 128 ? spriteObjeto[c] : null;
  if (img == null) return 20;
  silueta(img);
  int base = mapa.esPuertaCerrada(i, j) ? 28 : 40;
  // lo bajito (botella, tarjeta) igual lleva la etiqueta sobre la cabeza
  return max(20, base - filaArriba.get(img));
}

void etiquetaUso(float x, float y, String tecla, String accion, color c) {
  textFont(letraChica);
  float alto = 22 * escala;
  float anchoTecla = tecla == null ? 0 : textWidth(tecla) + 12 * escala;
  float separa = tecla == null ? 0 : 6 * escala;
  float w = anchoTecla + separa + textWidth(accion) + 16 * escala;
  float x0 = x - w / 2;
  float y0 = y - alto;
  // caja
  stroke(red(c), green(c), blue(c), 200);
  strokeWeight(1.5 * escala);
  fill(11, 14, 26, 235);
  rect(x0, y0, w, alto, 3 * escala);
  // tecla
  float cx = x0 + 8 * escala;
  if (tecla != null) {
    noStroke();
    fill(c);
    rect(cx, y0 + 3 * escala, anchoTecla, alto - 6 * escala, 2 * escala);
    fill(COLOR_FONDO);
    textAlign(CENTER, CENTER);
    text(tecla, cx + anchoTecla / 2, y0 + alto / 2 - 1 * escala);
    cx += anchoTecla + separa;
  }
  fill(tecla == null ? c : color(242, 242, 233));
  textAlign(LEFT, CENTER);
  text(accion, cx, y0 + alto / 2 - 1 * escala);
  // piquito hacia el objeto
  noStroke();
  fill(red(c), green(c), blue(c), 200);
  triangle(x - 4 * escala, y, x + 4 * escala, y, x, y + 5 * escala);
}
