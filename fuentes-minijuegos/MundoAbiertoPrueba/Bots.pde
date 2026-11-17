// Los candidatos rivales que maneja el computador.
//
// Antes de la ronda caminan hasta la plaza del parque. Durante la ronda
// escogen un punto (cerca, libre o del que va ganando), van hasta él con una
// ruta BFS, pegan su volante y escogen otro. Si alguien les queda a tiro y
// les quedan botellas, se la lanzan.

final int FACIL = 0, NORMAL = 1;
int dificultad = NORMAL;

class Bot {
  Candidato c;
  ArrayList<PVector> ruta;
  int paso;
  int objetivo = -1;        // punto al que va
  float pensar;             // segundos para volver a escoger punto
  float esperaPegar;        // reacción antes de empezar a pegar
  float revisarTiro;
  float atascado;           // segundos sin avanzar
  float ultX, ultY;
  float tiempoYendo;        // para el seguro de la reunión
  float lugarX, lugarY;     // su puesto alrededor de la fuente
  Ciudadano meta;           // a quién va a convencer (ronda de la gente)
  float replan, ritmo;

  Bot(Candidato c, int puesto) {
    this.c = c;
    float a = TWO_PI * puesto / 4.0 + QUARTER_PI;
    lugarX = centroX + 3.6 * cos(a);
    lugarY = centroY + 3.6 * sin(a);
  }

  float factorVelocidad() {
    return dificultad == FACIL ? 0.78 : 0.9;
  }

  void irA(float tx, float ty) {
    ruta = rutaBFS(c.x, c.y, tx, ty);
    paso = 0;
    atascado = 0;
  }

  // Sigue la ruta. Devuelve true cuando llegó.
  boolean seguirRuta(float dt, boolean correr) {
    if (ruta == null || paso >= ruta.size()) return true;
    PVector p = ruta.get(paso);
    float dx = p.x - c.x, dy = p.y - c.y;
    if (dx * dx + dy * dy < 0.2 * 0.2) {
      paso++;
      return paso >= ruta.size();
    }
    c.mover(dt, dx, dy, correr);
    // si no avanza (se trabó con una esquina), recalcula la ruta
    atascado += dt;
    if (atascado > 0.8) {
      if (dist(c.x, c.y, ultX, ultY) < 0.25) {
        PVector fin = ruta.get(ruta.size() - 1);
        irA(fin.x, fin.y);
      }
      atascado = 0;
      ultX = c.x;
      ultY = c.y;
    }
    return false;
  }

  // --- Antes de la ronda: ir a la plaza y esperar ---
  void hastaLaPlaza(float dt) {
    if (dist(c.x, c.y, lugarX, lugarY) < 0.5) {
      c.moviendose = false;
      c.mirarHacia(centroX, centroY);
      return;
    }
    if (ruta == null) irA(lugarX, lugarY);
    tiempoYendo += dt;
    seguirRuta(dt, dist(c.x, c.y, lugarX, lugarY) > 4);
    // seguro: si en 40 s no llegó, aparece en su puesto
    if (tiempoYendo > 40 || ruta == null) {
      c.x = lugarX;
      c.y = lugarY;
    }
  }

  void ponerEnSuPuesto() {
    c.x = lugarX;
    c.y = lugarY;
    c.mirarHacia(centroX, centroY);
    ruta = null;
    objetivo = -1;
  }

  // --- Durante la ronda ---
  void enLaRonda(float dt) {
    if (c.aturdido > 0) {
      c.moviendose = false;
      return;
    }
    pensar -= dt;
    revisarTiro -= dt;
    if (revisarTiro <= 0) {
      revisarTiro = 0.5;
      intentarTiro();
    }
    if (objetivo < 0 || dueno(objetivo) == c.id || pensar <= 0) escogerPunto();
    if (objetivo < 0) return;
    Punto p = puntos.get(objetivo);
    boolean alcanza = dist(c.x, c.y, p.x, p.y) < ALCANCE_PEGAR - 0.2;
    if (!alcanza) {
      esperaPegar = dificultad == FACIL ? random(0.3, 0.7) : random(0.1, 0.3);
      if (seguirRuta(dt, true)) {
        irA(p.fx, p.fy);   // llegó al final pero no alcanza
        if (ruta == null) {
          objetivo = -1;   // no hay cómo llegar: escoge otro
          pensar = 1;
        }
      }
      actualizarPegado(c, dt, false);
      return;
    }
    c.moviendose = false;
    if (esperaPegar > 0) {
      esperaPegar -= dt;
      c.mirarHacia(p.x, p.y);
      return;
    }
    actualizarPegado(c, dt, true);
  }

  // Puntaje de cada punto (menos es mejor): lo que cuesta llegar, más barato
  // si está libre o si es del que va ganando, y caro si otro bot ya va para allá.
  void escogerPunto() {
    pensar = random(3, 5);
    Candidato lid = lider();
    float mejor = 1e9;
    int elegido = -1;
    for (Punto p : puntos) {
      int d = dueno(p.id);
      if (d == c.id) continue;
      float costo = dist(c.x, c.y, p.fx, p.fy);
      if (d < 0) costo -= 1.5;
      if (lid != null && d == lid.id && lid != c) costo -= 3;
      if (d == yo.id) costo -= 0.5;
      for (Candidato o : candidatos) {
        if (o.bot != null && o != c && o.bot.objetivo == p.id) costo += 5;
      }
      costo += random(0, 2.5);
      if (p.id == objetivo) costo -= 1.5;   // no cambiar de idea por poco
      if (costo < mejor) {
        mejor = costo;
        elegido = p.id;
      }
    }
    if (elegido != objetivo) {
      objetivo = elegido;
      if (objetivo >= 0) irA(puntos.get(objetivo).fx, puntos.get(objetivo).fy);
    }
  }

  // Si tiene botellas y alguien le queda a tiro (con preferencia el que va
  // ganando o el que está pegando cerca), a veces se la lanza.
  void intentarTiro() {
    if (c.botellas <= 0 || esperaLanzar[c.id] > 0) return;
    Candidato lid = lider();
    Candidato blanco = null;
    float mejor = 1e9;
    for (Candidato o : candidatos) {
      if (o == c || o.aturdido > 0) continue;
      float d = dist(c.x, c.y, o.x, o.y);
      if (d > ALCANCE_BOTELLA - 1.5 || d < 0.8) continue;
      if (!lineaBotella(c.x, c.y, o.x, o.y)) continue;
      float costo = d;
      if (o == lid) costo -= 2;
      if (o.progresoPegar > 0) costo -= 2;
      if (costo < mejor) {
        mejor = costo;
        blanco = o;
      }
    }
    if (blanco == null) return;
    float ganas = dificultad == FACIL ? 0.15 : 0.32;
    if (blanco.progresoPegar > 0) ganas += 0.25;
    if (random(1) > ganas) return;
    // apunta a donde va a estar, con un error según la dificultad
    float t = dist(c.x, c.y, blanco.x, blanco.y) / VELOCIDAD_BOTELLA;
    float vx = blanco.moviendose ? blanco.dirX * (blanco.corriendo ? VELOCIDAD_CORRER : VELOCIDAD_CAMINAR) : 0;
    float vy = blanco.moviendose ? blanco.dirY * (blanco.corriendo ? VELOCIDAD_CORRER : VELOCIDAD_CAMINAR) : 0;
    float tx = blanco.x + vx * t * 0.8, ty = blanco.y + vy * t * 0.8;
    float err = dificultad == FACIL ? 0.35 : 0.12;
    float a = atan2(ty - c.y, tx - c.x) + random(-err, err);
    lanzarBotella(c, cos(a), sin(a));
  }
}

// --- Ronda de la gente, para los bots ---
// Si están solos usan la forma segura (la secuencia de flechas, a su ritmo y
// a veces con un error); si hay rivales cerca van por la rápida. Les gusta
// quitarle al que va ganando los que tiene sin asegurar.
void botGente(Bot b, float dt) {
  Candidato c = b.c;
  if (c.aturdido > 0) {
    c.moviendose = false;
    return;
  }
  b.pensar -= dt;
  b.revisarTiro -= dt;
  if (b.revisarTiro <= 0) {
    b.revisarTiro = 0.5;
    b.intentarTiro();
  }
  if (enSecuencia(c)) {
    c.moviendose = false;
    b.ritmo -= dt;
    if (b.ritmo <= 0) {
      b.ritmo = dificultad == FACIL ? random(0.55, 0.8) : random(0.3, 0.5);
      java.util.ArrayDeque<Integer> cola = secuencias.get(c.id);
      if (cola != null && !cola.isEmpty()) {
        int f = cola.peek();
        if (random(1) < (dificultad == FACIL ? 0.12 : 0.05)) f = (f + 1) % 4;   // se equivoca
        marcarFlecha(c, f);
      }
    }
    return;
  }
  Ciudadano m = b.meta;
  if (m == null || m.asegurado || b.pensar <= 0 || (m.ocupadoPor >= 0 && m.ocupadoPor != c.id)) {
    escogerCiudadano(b);
    m = b.meta;
  }
  if (m == null) return;
  float d = dist(c.x, c.y, m.x, m.y);
  if (d > ALCANCE_CONVENCER - 0.25) {
    b.replan -= dt;
    if (b.replan <= 0 || b.ruta == null) {
      b.replan = 0.7;
      b.irA(m.x, m.y);
    }
    b.seguirRuta(dt, true);
    b.esperaPegar = dificultad == FACIL ? random(0.3, 0.6) : random(0.1, 0.25);
    return;
  }
  c.moviendose = false;
  c.mirarHacia(m.x, m.y);
  if (b.esperaPegar > 0) {
    b.esperaPegar -= dt;
    return;
  }
  boolean rivalCerca = false;
  for (Candidato o : candidatos) {
    if (o != c && o.aturdido <= 0 && dist(o.x, o.y, c.x, c.y) < 3.5) rivalCerca = true;
  }
  if (m.dueno != c.id && (rivalCerca || random(1) < 0.3)) {
    convencerRapido(c, m);
    b.esperaPegar = 0.3;
  } else if (m.dueno == c.id && rivalCerca) {
    b.pensar = 0;   // lo tiene sin asegurar y hay rivales: mejor buscar otro
  } else {
    empezarSecuencia(c, m);
    b.ritmo = 0.4;
  }
}

// Costo de cada ciudadano (menos es mejor): lo que hay que caminar, más
// barato si es de nadie o del que va ganando, más caro si ya es suyo sin
// asegurar o si otro bot va por él.
void escogerCiudadano(Bot b) {
  Candidato c = b.c;
  b.pensar = random(2.5, 4);
  Candidato lid = lider();
  float mejor = 1e9;
  Ciudadano elegido = null;
  for (Ciudadano z : ciudadanos) {
    if (z.asegurado) continue;
    if (z.ocupadoPor >= 0 && z.ocupadoPor != c.id) continue;
    float costo = dist(c.x, c.y, z.x, z.y);
    if (z.dueno < 0) costo -= 1;
    if (lid != null && z.dueno == lid.id && lid != c) costo -= 2.5;
    if (z.dueno == yo.id) costo -= 0.5;
    if (z.dueno == c.id) costo += 2;
    for (Candidato o : candidatos) {
      if (o.bot != null && o != c && o.bot.meta == z) costo += 4;
    }
    costo += random(0, 2);
    if (z == b.meta) costo -= 1.5;
    if (costo < mejor) {
      mejor = costo;
      elegido = z;
    }
  }
  if (elegido != b.meta) {
    b.meta = elegido;
    b.ruta = null;
  }
}

// La botella pasa por encima de lo bajo, pero no a través de edificios ni árboles
boolean lineaBotella(float x0, float y0, float x1, float y1) {
  float d = dist(x0, y0, x1, y1);
  int n = max(1, ceil(d / 0.15));
  for (int k = 1; k < n; k++) {
    float t = k / (float) n;
    if (!libre(lerp(x0, x1, t), lerp(y0, y1, t), 0.05)) return false;
  }
  return true;
}
