// Cómo va un evento del parque (volantes o convencer a la gente):
//   PASEO    el candidato sale de su sede y tiene que llegar al centro del parque
//   REUNION  ya está en la plaza; se espera a que lleguen los demás
//   CUENTA   3, 2, 1...
//   RONDA    60 segundos pegando volantes (o convenciendo gente) y lanzando botellas
//   FINAL    la lista final y cuánto apoyo da cada puesto
//   VUELTA   el candidato vuelve a su sede (a pie o en carro) y entra a la oficina

final int PASEO = 0, REUNION = 1, CUENTA = 2, RONDA = 3, FINAL = 4, VUELTA = 5;
// Los eventos que se pueden jugar en el parque
final int VOLANTES = 0, GENTE = 1, LIVES = 2;
int evento = VOLANTES;
final float TIEMPO_RONDA = 60;
final float TIEMPO_CUENTA = 3;
final int[] PREMIO_PUESTO = {20, 10, 0, -5};

int estadoRonda = PASEO;
float relojRonda;
ArrayList<Candidato> resultado;   // la lista al terminar

// Cuatro asientos. Sin red, el 0 es el jugador y los otros tres son bots.
// En red, los asientos con persona no tienen bot y llevan el nombre que
// escogió cada uno; el jugador de este PC es el de miAsiento.
void crearCandidatos() {
  candidatos.clear();
  String[] nombres = {"Tú", "Morales", "Rincón", "Pérez"};
  color[] colores = {color(52, 96, 196), color(214, 62, 52), color(236, 160, 30), color(60, 150, 80)};
  String[] sprites = {"jugador1", "jefe", "civil", "civil2"};
  // salen de la sede, de Titulares Ya, del mercado y del colegio
  float[][] salidas = {{inicioX, inicioY}, {30, 34}, {86, 35}, {84, 70}};
  for (int k = 0; k < 4; k++) {
    boolean humano = modoRed == SOLO ? k == 0 : asientoHumano[k];
    String nombre = modoRed == SOLO ? nombres[k] : (humano ? nombresAsiento[k] : nombres[k]);
    String sprite = humano && k == 1 ? "jugador2" : sprites[k];
    PVector s = k == 0 ? new PVector(inicioX, inicioY) : puntoLibreCerca(salidas[k][0], salidas[k][1]);
    Candidato c = new Candidato(k, nombre, colores[k], sprite, s.x, s.y);
    if (!humano) c.bot = new Bot(c, k);
    candidatos.add(c);
    destinoCand[k][0] = s.x;
    destinoCand[k][1] = s.y;
  }
  yo = candidatos.get(modoRed == SOLO ? 0 : miAsiento);
}

boolean rondaActiva() {
  return estadoRonda == RONDA;
}

boolean enLaPlaza(Candidato c) {
  return dist(c.x, c.y, centroX, centroY) < radioPlaza + 0.3;
}

int enLaPlaza() {
  int n = 0;
  for (Candidato c : candidatos) if (enLaPlaza(c)) n++;
  return n;
}

void actualizarRonda(float dt) {
  // El invitado no simula: sigue la foto del anfitrión y manda sus teclas
  if (modoRed == INVITADO) {
    seguirFoto(dt);
    mandarTeclas();
    return;
  }
  switch (estadoRonda) {
  case PASEO:
  case REUNION:
    moverHumanos(dt);
    for (Candidato c : candidatos) if (c.bot != null) c.bot.hastaLaPlaza(dt);
    estadoRonda = enLaPlaza(yo) ? REUNION : PASEO;
    // en red, si alguien no llega en 45 segundos se empieza sin esperarlo
    if (estadoRonda == REUNION && modoRed == ANFITRION) esperaReunion += dt;
    if (faltanEnLaPlaza() == 0 || esperaReunion > 45) {
      estadoRonda = CUENTA;
      relojRonda = TIEMPO_CUENTA;
    }
    break;
  case CUENTA:
    moverHumanos(dt);
    for (Candidato c : candidatos) {
      if (c.bot != null || enLaPlaza(c)) continue;
      // nadie sale de la plaza mientras se cuenta
      PVector p = puntoLibreCerca(lerp(c.x, centroX, 0.15), lerp(c.y, centroY, 0.15));
      c.x = p.x;
      c.y = p.y;
    }
    relojRonda -= dt;
    if (relojRonda <= 0) empezarRonda();
    break;
  case RONDA:
    relojRonda -= dt;
    moverHumanos(dt);
    if (evento == VOLANTES) {
      for (Candidato c : candidatos) {
        if (c.bot != null) c.bot.enLaRonda(dt);
        else actualizarPegado(c, dt, teclasDe(c)[T_PEGAR]);
      }
    } else {
      for (Candidato c : candidatos) {
        if (c.bot == null) continue;
        if (evento == LIVES) botLives(c.bot, dt);
        else botGente(c.bot, dt);
      }
      revisarSecuencias();
      // en la de los lives se acaba antes si ya no queda ninguno libre
      if (evento == LIVES && totalLives() > 0 && livesLibres() == 0) relojRonda = 0;
    }
    if (relojRonda <= 0) terminarRonda();
    break;
  case FINAL:
    for (Candidato c : candidatos) {
      if (c.bot != null) c.bot.pasear(dt);   // los bots siguen caminando
      else c.moviendose = false;
    }
    break;
  case VUELTA:
    moverHumanos(dt);
    for (Candidato c : candidatos) if (c.bot != null) c.bot.pasear(dt);
    if (dist(yo.x, yo.y, yo.inicioX, yo.inicioY) < 1.8) {
      if (manejando != null) bajarseDelCarro();
      sonar("puerta");
      volverALaOficina();
    }
    break;
  }
  actualizarBotellas(dt);
  for (Ciudadano z : ciudadanos) z.actualizar(dt);
  actualizarCarros(dt);
}

void empezarRonda() {
  estadoRonda = RONDA;
  relojRonda = tiempoRonda();
  arenaCerrada = evento != LIVES;   // los lives están por toda la ciudad
  duenoDePunto.clear();
  reiniciarGente();
  botellasVolando.clear();
  for (Candidato c : candidatos) {
    c.botellas = BOTELLAS_INICIO;
    c.aturdido = 0;
    c.progresoPegar = 0;
    c.ultimoLogro = 0;
    if (c.bot != null) {
      c.bot.objetivo = -1;
      c.bot.meta = null;
      c.bot.ruta = null;
    }
  }
  if (evento == VOLANTES) avisarTodos("¡A pegar volantes! Mantén E junto a una cartelera");
  else if (evento == GENTE) avisarTodos("¡A convencer! E para rápido, F para asegurar conversando");
  else avisarTodos("¡Hay lives por toda la ciudad! Llega a uno y reclámalo con F");
}

void terminarRonda() {
  estadoRonda = FINAL;
  arenaCerrada = false;
  resultado = listaOrdenada();
  for (Candidato c : candidatos) {
    cancelarSecuencia(c);
    c.progresoPegar = 0;
  }
}

// Después de la lista final, el candidato vuelve caminando (o en carro) a su
// sede. En red no: ahí se vuelve directo a la oficina.
void empezarVuelta() {
  estadoRonda = VUELTA;
  avisar("Vuelve a tu sede: entra por el parqueadero");
}


// El puesto cuenta cuántos tienen más puntos: los empatados comparten el
// mejor puesto. Con 0 puntos no se gana apoyo (a lo sumo se pierde, si se
// queda solo de último).
int posicionDe(Candidato c) {
  int mas = 0;
  for (Candidato o : candidatos) if (puntajeDe(o) > puntajeDe(c)) mas++;
  return mas;
}

int premioDe(Candidato c) {
  int premio = PREMIO_PUESTO[constrain(posicionDe(c), 0, PREMIO_PUESTO.length - 1)];
  if (puntajeDe(c) == 0) premio = min(premio, 0);
  return premio;
}

// Repetir solo la ronda: todos de vuelta alrededor de la fuente
void repetirRonda() {
  if (manejando != null) bajarseDelCarro();
  for (Candidato c : candidatos) {
    if (c.bot != null) c.bot.ponerEnSuPuesto();
  }
  PVector p = puntoLibreCerca(centroX + 3.6 * cos(QUARTER_PI + PI * 0), centroY + 3.6 * sin(QUARTER_PI));
  yo.x = p.x;
  yo.y = p.y;
  estadoRonda = CUENTA;
  relojRonda = TIEMPO_CUENTA;
  duenoDePunto.clear();
  reiniciarGente();
}

// Todo desde el principio: cada uno en su punto de salida
void reiniciarTodo() {
  if (manejando != null) bajarseDelCarro();
  for (Candidato c : candidatos) {
    c.x = c.inicioX;
    c.y = c.inicioY;
    c.aturdido = 0;
    c.botellas = 0;
    if (c.bot != null) {
      c.bot.ruta = null;
      c.bot.tiempoYendo = 0;
      c.bot.objetivo = -1;
    }
  }
  duenoDePunto.clear();
  reiniciarGente();
  arenaCerrada = false;
  estadoRonda = PASEO;
  camX = pantallaX(yo.x, yo.y);
  camY = pantallaY(yo.x, yo.y) - 14;
}

// Lo que va en el piso (debajo de todo): la plaza de reunión, los anillos de
// los puntos y el borde del área de juego.
void dibujarPisoRonda() {
  if (estadoRonda == VUELTA) {
    // la entrada de la sede, titilando
    float sx = pantallaX(yo.inicioX, yo.inicioY), sy = pantallaY(yo.inicioX, yo.inicioY);
    float w = 2 * 1.8 * T * 1.414, h = w / 2;
    noFill();
    stroke(250, 214, 80, 120 + 90 * sin(millis() / 200.0));
    strokeWeight(2);
    ellipse(sx, sy, w, h);
  }
  if (estadoRonda == PASEO || estadoRonda == REUNION) {
    float sx = pantallaX(centroX, centroY), sy = pantallaY(centroX, centroY);
    float w = 2 * radioPlaza * T * 1.414, h = w / 2;
    noFill();
    stroke(250, 214, 80, 120 + 90 * sin(millis() / 200.0));
    strokeWeight(2);
    ellipse(sx, sy, w, h);
  }
  dibujarAnillosPuntos();
  if (estadoRonda == RONDA) {
    // borde del área: línea punteada amarilla
    stroke(250, 214, 80, 170);
    strokeWeight(1.5);
    float[][] esq = {{arenaX0, arenaY0}, {arenaX1, arenaY0}, {arenaX1, arenaY1}, {arenaX0, arenaY1}};
    for (int k = 0; k < 4; k++) {
      float[] a = esq[k], b = esq[(k + 1) % 4];
      float largo = dist(a[0], a[1], b[0], b[1]);
      for (float t = 0; t < largo; t += 1.0) {
        float t2 = min(largo, t + 0.5);
        line(pantallaX(lerp(a[0], b[0], t / largo), lerp(a[1], b[1], t / largo)),
          pantallaY(lerp(a[0], b[0], t / largo), lerp(a[1], b[1], t / largo)),
          pantallaX(lerp(a[0], b[0], t2 / largo), lerp(a[1], b[1], t2 / largo)),
          pantallaY(lerp(a[0], b[0], t2 / largo), lerp(a[1], b[1], t2 / largo)));
      }
    }
  }
  noStroke();
}

// Lo que va encima de todo en la ciudad: papelitos y vidrios
void dibujarEncimaRonda() {
  for (Particula p : particulas) p.dibujar();
}

ArrayList<Movil> movilesVisibles() {
  ArrayList<Movil> m = new ArrayList<Movil>();
  for (Candidato c : candidatos) m.add(c);
  for (Botella b : botellasVolando) m.add(b);
  for (Ciudadano z : ciudadanos) m.add(z);
  for (Carro c : carros) {
    float sx = pantallaX(c.x, c.y), sy = pantallaY(c.x, c.y);
    if (abs(sx - camX) < width / pixel && abs(sy - camY) < height / pixel) m.add(c);
  }
  return m;
}

// Mueve a las personas (no bots) con sus teclas. En la ronda de la gente,
// el que está haciendo una secuencia de flechas no camina.
void moverHumanos(float dt) {
  for (Candidato c : candidatos) {
    if (c.bot != null) continue;
    if (c == yo && manejando != null) continue;
    if (estadoRonda == RONDA && evento != VOLANTES && enSecuencia(c)) {
      c.moviendose = false;
      continue;
    }
    boolean[] t = teclasDe(c);
    float ix = (t[T_DER] ? 1 : 0) - (t[T_IZQ] ? 1 : 0);
    float iy = (t[T_ABAJO] ? 1 : 0) - (t[T_ARRIBA] ? 1 : 0);
    c.mover(dt, ix + iy, iy - ix, t[T_CORRER]);
  }
}
