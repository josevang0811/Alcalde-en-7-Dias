// Interfaz encima del mundo: objetivos, estado de alerta, postura y ruido de
// cada jugador, avisos y las pantallas de inicio y final.

void dibujarHud(float dt) {
  tiempoAviso = max(0, tiempoAviso - dt);
  float e = escala;

  // Bordes oscuros para que se sienta de noche
  noFill();
  for (int k = 0; k < 6; k++) {
    stroke(0, 28);
    strokeWeight((60 - k * 9) * e);
    rect(0, 0, width, height);
  }

  // Destello rojo cuando te descubren o suena una alarma
  if (destelloAlarma > 0) {
    stroke(232, 52, 78, 190 * destelloAlarma);
    strokeWeight(14 * e);
    rect(0, 0, width, height);
  }

  if (estado == INICIO || estado == ELEGIR_ROL || estado == CREDITOS || estado == LLAMADA) return;
  if (estado == RECONOCIMIENTO) {
    dibujarHudReconocimiento();
    return;
  }
  if (mapaAbierto) {
    dibujarHudMapa();
    return;
  }

  // Objetivos, alarma, jugadores y avisos en pixel art (HudPixel.pde)
  dibujarHudPixel();

  if (ventana != 0) dibujarVentana();
  dibujarDestelloFoto();

}

void dibujarHudReconocimiento() {
  float e = escala;
  float w = 640 * e;
  float x = width / 2 - w / 2;
  float y = 14 * e;
  panel(x, y, w, 100 * e);
  textAlign(CENTER, TOP);
  textFont(letraGrande);
  fill(NEON_MAGENTA);
  text("RECONOCIMIENTO", width / 2, y + 10 * e);
  textFont(letraChica);
  fill(215);
  text("Estudia las rondas, las cámaras, las tarjetas y los ductos. Adentro ya no se dibujan las rutas.", width / 2, y + 42 * e);
  // tiempo que queda
  float resto = max(0, tiempoReconocimiento) / tiempoReconocimientoTotal();
  noStroke();
  fill(40);
  rect(x + 20 * e, y + 64 * e, w - 40 * e, 6 * e);
  fill(NEON_MAGENTA);
  rect(x + 20 * e, y + 64 * e, (w - 40 * e) * resto, 6 * e);
  fill(160);
  text("Enter o Espacio: entrar ya   ·   " + ceil(max(0, tiempoReconocimiento)) + " s", width / 2, y + 78 * e);

  // Leyenda de colores abajo (sin nombres: una raya de color por cada ronda)
  textFont(letraChica);
  String rondas = "Rondas de los vigilantes";
  String camara = "Zona que barre cada cámara";
  float rayas = vigilantes.size() * 14 * e;
  float total = rayas + 8 * e + textWidth(rondas) + 40 * e + 22 * e + 8 * e + textWidth(camara);
  float lx = width / 2 - total / 2;
  float ly = height - 34 * e;
  panel(lx - 14 * e, ly - 16 * e, total + 28 * e, 32 * e);
  textAlign(LEFT, CENTER);
  noStroke();
  for (Vigilante v : vigilantes) {
    fill(v.colorRonda);
    rect(lx, ly - 2 * e, 10 * e, 4 * e);
    lx += 14 * e;
  }
  fill(220);
  text(rondas, lx + 8 * e, ly);
  lx += 8 * e + textWidth(rondas) + 40 * e;
  fill(25, 227, 227, 120);
  rect(lx, ly - 6 * e, 22 * e, 12 * e);
  fill(220);
  text(camara, lx + 30 * e, ly);
}

void tarjetaJugador(Jugador j, float x, float y) {
  float e = escala;
  panel(x, y, 420 * e, 70 * e);
  noStroke();
  fill(j.ropa);
  rect(x, y, 5 * e, 70 * e);
  textFont(letraMedia);
  textAlign(LEFT, TOP);
  fill(235);
  text("J" + j.numero + " " + NOMBRES_ROL[j.rol] + " · " + j.postura(), x + 14 * e, y + 8 * e);
  textFont(letraChica);
  textAlign(RIGHT, CENTER);
  fill(j.botellas > 0 ? NEON_VERDE : color(110));
  text("Botellas: " + j.botellas, x + 408 * e, y + 38 * e);
  // habilidad del rol: lista o cuanto le falta
  textAlign(LEFT, CENTER);
  boolean lista = j.enfriamiento <= 0;
  fill(lista ? (j.rol == ROL_HACKER ? NEON_CIAN : NEON_MAGENTA) : color(110));
  text(j.teclaHabilidad() + ": " + (j.sombra > 0 ? "activa" : (lista ? "lista" : ceil(j.enfriamiento) + " s")), x + 226 * e, y + 38 * e);
  // Mochila: kilos que lleva de los que caben
  textFont(letraChica);
  textAlign(RIGHT, TOP);
  fill(j.peso >= CAPACIDAD_MOCHILA ? COLOR_AMBAR : color(200));
  text("Mochila " + j.peso + "/" + CAPACIDAD_MOCHILA + " kg", x + 408 * e, y + 10 * e);
  // Ruido: 10 rayitas, se llenan segun hasta donde se oyen los pasos
  textFont(letraChica);
  textAlign(LEFT, CENTER);
  fill(160);
  text("Ruido", x + 14 * e, y + 38 * e);
  int llenas = min(10, round(j.radioRuido() / 3.7 * 10));
  for (int k = 0; k < 10; k++) {
    if (k < llenas) fill(k < 4 ? NEON_VERDE : (k < 7 ? COLOR_AMBAR : COLOR_RIVAL));
    else fill(35, 42, 66);
    rect(x + 70 * e + k * 14 * e, y + 33 * e, 10 * e, 10 * e);
  }
  fill(130);
  textAlign(LEFT, BOTTOM);
  String controles = j.numero == 1 ? "WASD · Shift corre · C agacha · E usa · Q lanza · X suelta · F rol"
    : "Flechas · - corre · . agacha · Enter · , lanza · K suelta · M rol";
  text(controles, x + 14 * e, y + 66 * e);
}

void objetivo(float x, float y, boolean hecho, String texto) {
  float e = escala;
  stroke(hecho ? NEON_VERDE : color(130));
  strokeWeight(1.5 * e);
  noFill();
  rect(x, y + 2 * e, 11 * e, 11 * e);
  if (hecho) {
    line(x + 2 * e, y + 8 * e, x + 5 * e, y + 11 * e);
    line(x + 5 * e, y + 11 * e, x + 10 * e, y + 3 * e);
  }
  noStroke();
  fill(hecho ? NEON_VERDE : color(220));
  textAlign(LEFT, TOP);
  text(texto, x + 18 * e, y);
}

// Panel de las ventanas y menus: el mismo marco del HUD en pixel art,
// agrandado a la escala del arte
void panel(float x, float y, float w, float h) {
  panel(x, y, w, h, NEON_CIAN);
}

void panel(float x, float y, float w, float h, color c) {
  pushMatrix();
  translate(round(x), round(y));
  scale(pixel);
  strokeWeight(1);
  marcoPixel(g, 0, 0, round(w / pixel) - 1, round(h / pixel) - 1, c);
  popMatrix();
  noStroke();
}

String reloj(float segundos) {
  int s = floor(segundos);
  return nf(s / 60, 2) + ":" + nf(s % 60, 2);
}

// ---------------------------------------------------------------------------
// Pantallas
// ---------------------------------------------------------------------------

void dibujarPantallaInicio() {
  float e = escala;
  noStroke();
  fill(0, 150);
  rect(0, 0, width, height);
  float w = 780 * e;
  float h = 510 * e;
  float x = width / 2 - w / 2;
  float y = height / 2 - h / 2;
  panel(x, y, w, h);

  textAlign(CENTER, TOP);
  textFont(letraTitulo);
  fill(NEON_MAGENTA);
  text("INFILTRADO", width / 2, y + 28 * e);
  textFont(letraMedia);
  fill(160);
  text("Prueba del modo sigilo · Alcalde Digital", width / 2, y + 88 * e);

  fill(225);
  text("Es de noche. Te metes a la sede de Titulares Ya, la agencia que fabrica", width / 2, y + 128 * e);
  text("los bulos contra tu campaña. Copia su servidor y sal sin que te atrapen.", width / 2, y + 150 * e);

  float cx = x + 50 * e;
  textAlign(LEFT, TOP);
  fill(NEON_CIAN);
  text("Jugador 1", cx, y + 196 * e);
  fill(NEON_VERDE);
  text("Jugador 2", cx + 360 * e, y + 196 * e);
  textFont(letraChica);
  fill(210);
  String[] c1 = {"WASD   mover", "Shift  correr (hace ruido)", "C      agacharse (no hace ruido)", "E      usar / mantener para copiar", "Q / X  lanzar botella / soltar botín", "F      habilidad del rol"};
  String[] c2 = {"Flechas  mover", "-        correr", ".        agacharse", "Enter    usar", ", / K    lanzar / soltar botín", "M        habilidad del rol"};
  for (int k = 0; k < 6; k++) {
    text(c1[k], cx, y + 222 * e + k * 20 * e);
    text(c2[k], cx + 360 * e, y + 222 * e + k * 20 * e);
  }

  fill(170);
  textAlign(CENTER, TOP);
  text("Correr hace ruido y los vigilantes lo oyen. Agachado y en la sombra cuesta más verte.", width / 2, y + 354 * e);
  text("Tarjetas abren puertas, los ductos son atajos y cortar la luz te esconde.", width / 2, y + 374 * e);

  textFont(letraGrande);
  boolean parpadeo = (frameCount / 30) % 2 == 0;
  fill(parpadeo ? 255 : 200);
  text("1  jugar solo        2  cooperativo", width / 2, y + 410 * e);
  textFont(letraChica);
  fill(120);
  text("C créditos   ·   Esc para salir", width / 2, y + 465 * e);
}

void dibujarPantallaFinal() {
  dibujarCalificacion();
}

// ---------------------------------------------------------------------------
// Lo que se lee en la oficina del rival
// ---------------------------------------------------------------------------

void dibujarVentana() {
  if (ventana == 5) {
    dibujarConsola();
    return;
  }
  if (ventana == 6) {
    dibujarTeclado();
    return;
  }
  float e = escala;
  float w = min(560 * e, width - 40 * e);
  float h = 330 * e;
  float x = width / 2 - w / 2;
  float y = height / 2 - h / 2 - 20 * e;
  noStroke();
  fill(0, 120);
  rect(0, 0, width, height);
  panel(x, y, w, h);
  textAlign(LEFT, TOP);
  textFont(letraMedia);
  String titulo = "";
  String pie = "";
  if (ventana == 1) {
    titulo = "Celular del rival · chat con Max Rumor";
    pie = "El borrador del bulo sigue abierto en su computador.";
    String[][] chat = {
      {"Max Rumor", "Jefe, mañana sale el del agua contaminada en El Puerto."},
      {"Rival", "Perfecto. Que parezca real, con foto y todo."},
      {"Max Rumor", "Y el miércoles, lo de los subsidios falsos en Barrio Sur."},
      {"Rival", "El de La Colina ni se va a dar cuenta."}
    };
    float cy = y + 52 * e;
    textFont(letraChica);
    for (String[] m : chat) {
      boolean suyo = m[0].equals("Rival");
      float bw = w * 0.86;
      float bx = suyo ? x + w - bw - 20 * e : x + 20 * e;
      stroke(suyo ? COLOR_RIVAL : NEON_MAGENTA);
      strokeWeight(1);
      fill(suyo ? color(60, 20, 34) : color(40, 18, 46));
      rect(bx, cy, bw, 44 * e, 6 * e);
      noStroke();
      fill(suyo ? COLOR_RIVAL : NEON_MAGENTA);
      text(m[0], bx + 10 * e, cy + 6 * e);
      fill(235);
      text(m[1], bx + 10 * e, cy + 22 * e);
      cy += 54 * e;
    }
  } else if (ventana == 2) {
    titulo = "Tablero de conspiración";
    pie = "Nos siguen barrio por barrio. Los hilos son las calles de la ciudad.";
    String[] barrios = {"Centro", "La Universidad", "La Colina", "El Puerto", "El Mercado", "Barrio Sur", "Parque Industrial", "Barrio Norte"};
    float[][] pos = {{0.5, 0.45}, {0.3, 0.2}, {0.12, 0.45}, {0.3, 0.75}, {0.55, 0.85}, {0.82, 0.8}, {0.85, 0.4}, {0.65, 0.15}};
    int[][] calles = {{0, 1}, {0, 3}, {0, 4}, {0, 6}, {0, 7}, {1, 2}, {1, 7}, {2, 3}, {3, 4}, {4, 5}, {5, 6}, {6, 7}};
    float gx = x + 30 * e, gy = y + 50 * e, gw = w - 60 * e, gh = h - 110 * e;
    noStroke();
    fill(143, 86, 52);
    rect(gx - 10 * e, gy - 10 * e, gw + 20 * e, gh + 20 * e, 4 * e);
    stroke(COLOR_RIVAL);
    strokeWeight(2 * e);
    for (int[] c : calles) {
      line(gx + pos[c[0]][0] * gw, gy + pos[c[0]][1] * gh, gx + pos[c[1]][0] * gw, gy + pos[c[1]][1] * gh);
    }
    textFont(letraChica);
    textAlign(CENTER, TOP);
    for (int k = 0; k < barrios.length; k++) {
      float px = gx + pos[k][0] * gw, py = gy + pos[k][1] * gh;
      noStroke();
      fill(k == 2 ? NEON_CIAN : color(242, 242, 233));
      rect(px - 10 * e, py - 12 * e, 20 * e, 16 * e);
      fill(COLOR_RIVAL);
      ellipse(px, py - 12 * e, 6 * e, 6 * e);
      fill(20);
      text(barrios[k], px, py + 6 * e);
    }
    textAlign(LEFT, TOP);
  } else if (ventana == 3) {
    titulo = "Cuaderno del rival";
    pie = "Anotó: \"esta noche imprimir los volantes falsos en la redacción\".";
    String[][] filas = {
      {"Granja de bots", "desbloqueada", "Cientos de cuentas falsas que comparten todo"},
      {"Deepfakes del estudio", "desbloqueada", "Videos falsos grabados en la pantalla verde"},
      {"Prensa comprada", "en progreso", "Periodistas que repiten sus titulares"},
      {"Hackear al influencer", "bloqueada", "Su próximo objetivo: Nico Viral"}
    };
    float cy = y + 56 * e;
    textFont(letraChica);
    for (String[] f : filas) {
      fill(f[1].equals("bloqueada") ? color(130) : COLOR_AMBAR);
      text("● " + f[0], x + 24 * e, cy);
      fill(f[1].equals("desbloqueada") ? COLOR_RIVAL : color(150));
      textAlign(RIGHT, TOP);
      text(f[1], x + w - 24 * e, cy);
      textAlign(LEFT, TOP);
      fill(190);
      text(f[2], x + 40 * e, cy + 18 * e);
      cy += 50 * e;
    }
  } else if (ventana == 4) {
    titulo = "TV · Titulares Ya en vivo";
    pie = "Así venden sus bulos todas las noches.";
    float tx = x + 30 * e, ty = y + 56 * e, tw = w - 60 * e, th = h - 130 * e;
    noStroke();
    fill(30, 39, 66);
    rect(tx, ty, tw, th);
    fill(COLOR_RIVAL);
    rect(tx, ty + th - 40 * e, tw, 40 * e);
    fill(255);
    textFont(letraMedia);
    text("¿EL CANDIDATO DE LA COLINA ESCONDE ALGO?", tx + 12 * e, ty + th - 32 * e, tw - 24 * e, 30 * e);
    fill(227, 167, 126);
    rect(tx + tw / 2 - 30 * e, ty + 30 * e, 60 * e, 70 * e);
    fill(COLOR_RIVAL);
    textFont(letraChica);
    text("● EN VIVO", tx + 10 * e, ty + 8 * e);
  }
  textFont(letraMedia);
  textAlign(LEFT, TOP);
  fill(NEON_MAGENTA);
  text(titulo, x + 20 * e, y + 16 * e);
  textFont(letraChica);
  fill(190);
  text(pie, x + 20 * e, y + h - 40 * e, w - 40 * e, 20 * e);
  fill(130);
  textAlign(RIGHT, TOP);
  text("Muévete o presiona usar para cerrar", x + w - 20 * e, y + h - 22 * e);
}

// Nombre para el plano: el jefe se distingue de los vigilantes
String nombreVigilante(int n) {
  return vigilantes.get(n).esJefe ? "Jefe de seguridad" : "Vigilante " + (n + 1);
}
