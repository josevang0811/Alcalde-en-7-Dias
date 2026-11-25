import javax.sound.sampled.*;

// MundoAbierto — la ciudad y los eventos del parque (rondas 3 y 4), dentro
// de Alcalde Digital.
//
// Es el sketch MundoAbiertoPrueba completo metido en una sola clase, igual
// que Infiltrado. setup() se llama prepararMundo(), draw() se llama
// dibujar() y las teclas llegan por teclaPresionada() y teclaSoltada(). El
// juego empieza cada evento con configurarEvento() y, al terminar, el mundo
// llama a volverALaOficina() (EventoParque.pde).
//
// No se edita a mano: se arma con herramientas/fusionar.py a partir de la
// carpeta MundoAbiertoPrueba (cada parte lleva arriba el nombre de su archivo).

class MundoAbierto {

// ======================================================================
// MundoAbiertoPrueba.pde
// ======================================================================
// MundoAbiertoPrueba — la ciudad del mundo abierto de Alcalde Digital y sus
// eventos en el parque: la ronda de volantes y la de convencer a la gente
// (en la prueba se escoge con 1 o 2 antes de la ronda).
//
// El candidato sale de su sede de campaña y tiene que llegar al centro del
// parque, donde se reúnen los otros tres candidatos (manejados por el
// computador). Cuando están los cuatro empieza la ronda: 60 segundos para
// pegar volantes en las carteleras del parque y sus calles. Pegar encima del
// volante de otro le quita el punto. Las botellas son ilimitadas (con una
// pausa corta entre una y otra): al que le pegan se queda quieto 2 segundos. Al final, el que más puntos tenga gana
// apoyo (+20, +10, 0, -5).
//
// El dibujo de la ciudad sale de data/mundo/, que se arma con
// herramientas/gen_ciudad.py.
//
// En la ronda de la gente hay 20 ciudadanos: E convence rápido (se lo pueden
// quitar) y F abre una secuencia de 4 flechas que lo asegura.
//
// Teclas: WASD o flechas para caminar, Shift para correr, E para pegar o
// convencer, F para asegurar, Q para lanzar una botella, M para el mapa, C
// para ver los choques.


int pixel;                  // cuántas veces se agranda el pixel art (2 en 720p, 3 en 1080p)
Candidato yo;
float camX, camY;           // centro de la cámara, en pixeles del dibujo
int ultimoMillis;
boolean verMapa = false;
boolean modoPrueba = true;  // en el juego principal no hay selector de evento
boolean verChoques = false;
PFont fuente, fuenteNegrita;

void prepararMundo() {
  pixel = max(1, round(height / 360.0));
  fuente = createFont("DejaVuSansMono.ttf", 14);
  fuenteNegrita = createFont("DejaVuSansMono-Bold.ttf", 14);
  cargarMundo();
  cargarPuntos();
  crearCandidatos();
  crearCiudadanos();
  cargarCarros();
  cargarSonidosMundo();
  camX = pantallaX(yo.x, yo.y);
  camY = pantallaY(yo.x, yo.y) - 14;
  ultimoMillis = millis();
}

void dibujar() {
  float dt = min(0.05, (millis() - ultimoMillis) / 1000.0);
  ultimoMillis = millis();

  actualizarRonda(dt);
  sonidosDelCuadro(dt);
  revisarZona();

  // La cámara sigue al candidato con un poco de retraso
  float objX = pantallaX(yo.x, yo.y);
  float objY = pantallaY(yo.x, yo.y) - 14;
  camX += (objX - camX) * min(1, dt * 8);
  camY += (objY - camY) * min(1, dt * 8);
  limitarCamara();

  background(89, 132, 159);   // el fondo, con la misma paleta profunda de data/mundo
  dibujarCiudad();
  dibujarHud();
}

// La cámara no muestra (casi) nada fuera de la ciudad
void limitarCamara() {
  float mitadW = width / 2.0 / pixel;
  float mitadH = height / 2.0 / pixel;
  camX = constrain(camX, mitadW, max(mitadW, anchoMundo - mitadW));
  camY = constrain(camY, mitadH, max(mitadH, altoMundo - mitadH));
}

void teclaPresionada() {
  if (key == ESC) key = 0;   // ESC no cierra la prueba
  // en plena secuencia de flechas, las flechas (y WASD) son para la secuencia
  if (rondaActiva() && evento != VOLANTES && teclaSecuencia()) return;
  teclaCambio(true);
  char k = Character.toLowerCase(key);
  if (modoRed == INVITADO) {
    // el invitado manda sus acciones al anfitrión
    if (k == 'e' || k == 'f' || k == 'q') enviarAccionRed(k);
    if (k == 'q' && rondaActiva() && yo.botellas > 0 && yo.aturdido <= 0) sonar("lanzar");
  } else {
    if (k == 'e' && !accionRapida(yo)) teclaCarro();
    if (k == 'f') accionAsegurar(yo);
    if (k == 'q' && rondaActiva()) lanzarAlMouse(yo);   // hacia el cursor
  }
  if (modoPrueba && (k == '1' || k == '2' || k == '3') && estadoRonda != RONDA && estadoRonda != CUENTA) {
    evento = k == '1' ? VOLANTES : (k == '2' ? GENTE : LIVES);
    crearCiudadanos();
    if (evento == LIVES) crearLives();
    if (estadoRonda == FINAL) repetirRonda();
  }
  if (k == 'm') verMapa = !verMapa;
  if (k == 'c') verChoques = !verChoques;
  if (sinFotos() && (key == ENTER || key == RETURN)) {
    // el invitado se queda sin parque: vuelve sin premio
    resultado = listaOrdenada();
    volverALaOficina();
    return;
  }
  if (estadoRonda == FINAL) {
    if (key == ENTER || key == RETURN) {
      if (modoRed == SOLO) empezarVuelta();
      else volverALaOficina();
      return;
    }
    if (k == 'r' && modoRed == SOLO) repetirRonda();
  }
}

void teclaSoltada() {
  teclaCambio(false);
}

// El juego principal empieza un evento con esto: el candidato aparece en su
// sede y los demás salen otra vez de sus puntos.
void configurarEvento(int tipo) {
  modoPrueba = false;
  evento = tipo;
  crearCiudadanos();
  if (tipo == LIVES) crearLives();
  reiniciarTodo();
  zonaActual = -1;
  verMapa = false;
  aviso = "";
  tArriba = tAbajo = tIzquierda = tDerecha = tCorrer = tPegar = false;
  ultimoMillis = millis();
}

// En el juego principal esta función la pone el juego (vuelve a la oficina
// con el resultado). En la prueba, Enter en la pantalla final empieza todo
// otra vez.


// ======================================================================
// Botellas.pde
// ======================================================================
// Botellas: cada candidato empieza la ronda con las mismas y las lanza cuando
// quiere. Al que le pega se queda quieto un rato y no puede pegar volantes.

final int BOTELLAS_INICIO = 3;
final float TIEMPO_ATURDIDO = 2.0;
final float VELOCIDAD_BOTELLA = 9.0;   // baldosas por segundo
final float ALCANCE_BOTELLA = 7.0;
final float ESPERA_LANZAR = 0.6;       // entre una botella y otra

ArrayList<Botella> botellasVolando = new ArrayList<Botella>();
ArrayList<Particula> particulas = new ArrayList<Particula>();
ArrayList<TextoFlotante> textosFlotantes = new ArrayList<TextoFlotante>();
float[] esperaLanzar = new float[8];

class Botella extends Movil {
  float x, y, vx, vy, recorrido;
  int dueno;
  boolean viva = true;
  Candidato objetivo;   // si se lanzó con el cursor encima de un rival, lo sigue

  Botella(Candidato c, float dx, float dy) {
    float l = sqrt(dx * dx + dy * dy);
    vx = dx / l * VELOCIDAD_BOTELLA;
    vy = dy / l * VELOCIDAD_BOTELLA;
    x = c.x + vx / VELOCIDAD_BOTELLA * 0.3;
    y = c.y + vy / VELOCIDAD_BOTELLA * 0.3;
    dueno = c.id;
  }

  public float px() {
    return x;
  }

  public float py() {
    return y;
  }

  void actualizar(float dt) {
    int pasos = 4;
    for (int k = 0; k < pasos && viva; k++) {
      if (objetivo != null && objetivo.aturdido <= 0) {
        float dx = objetivo.x - x, dy = objetivo.y - y, l = sqrt(dx * dx + dy * dy);
        if (l > 0.01) {
          vx = dx / l * VELOCIDAD_BOTELLA;
          vy = dy / l * VELOCIDAD_BOTELLA;
        }
      }
      x += vx * dt / pasos;
      y += vy * dt / pasos;
      recorrido += VELOCIDAD_BOTELLA * dt / pasos;
      for (Candidato c : candidatos) {
        if (c.id == dueno || c.aturdido > 0) continue;
        if (dist(x, y, c.x, c.y) < 0.5) {
          c.aturdido = TIEMPO_ATURDIDO;
          c.progresoPegar = 0;
          romper();
          efectoTexto(c.x, c.y, "¡PUM!", color(250, 246, 236));
          avisarA(c, candidatos.get(dueno).nombre + " te pegó un botellazo");
          avisarA(candidatos.get(dueno), "¡Le pegaste a " + c.nombre + "!");
          return;
        }
      }
      if (!libre(x, y, 0.05) || recorrido >= ALCANCE_BOTELLA) romper();
    }
  }

  void romper() {
    viva = false;
    efectoVidrio(x, y);
  }

  // Vuela en arco: más alto a la mitad del recorrido
  public void dibujar() {
    float t = constrain(recorrido / ALCANCE_BOTELLA, 0, 1);
    float z = 12 + 16 * 4 * t * (1 - t) - 10 * t;
    float sx = pantallaX(x, y), sy = pantallaY(x, y);
    noStroke();
    fill(40, 34, 60, 70);
    ellipse(sx, sy, 6, 2.5);
    pushMatrix();
    translate(sx, sy - z);
    rotate(recorrido * 4);
    fill(43, 30, 26);
    rect(-2.2, -4.6, 4.4, 9.2);
    rect(-1.3, -7, 2.6, 3);
    fill(76, 156, 98);
    rect(-1.5, -4, 3, 8);
    fill(160, 220, 180);
    rect(-0.8, -6.4, 1.6, 2.4);
    rect(-1, -3, 0.8, 4);
    popMatrix();
  }
}

// Lanza hacia (dx, dy) en baldosas. Devuelve false si no puede.
boolean lanzarBotella(Candidato c, float dx, float dy) {
  if (c.botellas <= 0 || c.aturdido > 0 || esperaLanzar[c.id] > 0) return false;
  if (dx * dx + dy * dy < 0.0001) return false;
  // las botellas son ilimitadas: solo hay una pausa corta entre una y otra
  esperaLanzar[c.id] = ESPERA_LANZAR;
  c.mirarHacia(c.x + dx, c.y + dy);
  botellasVolando.add(new Botella(c, dx, dy));
  // el invitado ya lo oyó al oprimir Q (Bots y otros: según la distancia)
  if (modoRed != INVITADO) sonarEn("lanzar", c.x, c.y);
  return true;
}

// Una persona lanza hacia donde mira; si hay un rival más o menos en esa
// dirección y a tiro, la botella se le apunta a él.
void lanzarDe(Candidato yo) {
  float mejor = radians(35);
  Candidato blanco = null;
  for (Candidato c : candidatos) {
    if (c == yo || c.aturdido > 0) continue;
    float dx = c.x - yo.x, dy = c.y - yo.y;
    float d = sqrt(dx * dx + dy * dy);
    if (d > ALCANCE_BOTELLA || d < 0.1) continue;
    float a = acos(constrain((dx * yo.dirX + dy * yo.dirY) / d, -1, 1));
    if (a < mejor) {
      mejor = a;
      blanco = c;
    }
  }
  if (blanco != null) lanzarBotella(yo, blanco.x - yo.x, blanco.y - yo.y);
  else lanzarBotella(yo, yo.dirX, yo.dirY);
}


// --- Apuntar con el mouse ---
// La botella va hacia el cursor. Si el cursor está encima de un rival (a
// tiro), se le apunta a él y le pega; si no, cae donde está el cursor.
float[] mouseEnMundo() {
  float nx = (mouseX - aPantallaX(0)) / pixel, ny = (mouseY - aPantallaY(0)) / pixel;
  float a = (nx - OX) / T, b = (ny - OY) * 2 / T;
  return new float[] {(a + b) / 2, (b - a) / 2};
}

// El rival que tiene el cursor encima (su dibujo mide 16 x 28)
Candidato rivalBajoMouse(Candidato yo) {
  float nx = (mouseX - aPantallaX(0)) / pixel, ny = (mouseY - aPantallaY(0)) / pixel;
  Candidato mejor = null;
  float mejorY = -1e9;
  for (Candidato c : candidatos) {
    if (c == yo) continue;
    float sx = pantallaX(c.x, c.y), sy = pantallaY(c.x, c.y);
    if (nx >= sx - 10 && nx <= sx + 10 && ny >= sy - 30 && ny <= sy + 4 && sy > mejorY) {
      mejor = c;   // si hay dos, el de adelante
      mejorY = sy;
    }
  }
  return mejor;
}

void lanzarAlMouse(Candidato yo) {
  Candidato blanco = rivalBajoMouse(yo);
  if (blanco != null) {
    if (lanzarBotella(yo, blanco.x - yo.x, blanco.y - yo.y)) {
      botellasVolando.get(botellasVolando.size() - 1).objetivo = blanco;   // lo sigue
    }
    return;
  }
  float[] m = mouseEnMundo();
  lanzarBotella(yo, m[0] - yo.x, m[1] - yo.y);
}

// Clic izquierdo en la ronda: lanzar (lo llama el mousePressed del juego)
void clicLanzar() {
  if (rondaActiva() && modoRed != INVITADO && yo.aturdido <= 0) lanzarAlMouse(yo);
}

// La mira: un aro rojo en el rival que tiene el cursor encima (a tiro) y
// una cruz pequeña donde está el mouse
void dibujarMiraBotella() {
  Candidato c = rivalBajoMouse(yo);
  noFill();
  strokeWeight(2 * pixel);
  if (c != null) {
    float d = dist(c.x, c.y, yo.x, yo.y);
    float sx = aPantallaX(pantallaX(c.x, c.y)), sy = aPantallaY(pantallaY(c.x, c.y) - 13);
    stroke(d <= ALCANCE_BOTELLA ? color(230, 60, 50) : color(150, 140, 130), 230);
    ellipse(sx, sy, 26 * pixel, 34 * pixel);
  }
  stroke(c != null ? color(230, 60, 50) : color(255, 243, 214), 220);
  strokeWeight(1.5 * pixel);
  float r = 5 * pixel;
  line(mouseX - r, mouseY, mouseX - r * 0.4, mouseY);
  line(mouseX + r * 0.4, mouseY, mouseX + r, mouseY);
  line(mouseX, mouseY - r, mouseX, mouseY - r * 0.4);
  line(mouseX, mouseY + r * 0.4, mouseX, mouseY + r);
  noStroke();
}

void actualizarBotellas(float dt) {
  for (int k = 0; k < esperaLanzar.length; k++) esperaLanzar[k] = max(0, esperaLanzar[k] - dt);
  for (int k = botellasVolando.size() - 1; k >= 0; k--) {
    Botella b = botellasVolando.get(k);
    b.actualizar(dt);
    if (!b.viva) botellasVolando.remove(k);
  }
  for (Candidato c : candidatos) c.aturdido = max(0, c.aturdido - dt);
  for (int k = particulas.size() - 1; k >= 0; k--) {
    if (!particulas.get(k).actualizar(dt)) particulas.remove(k);
  }
  for (int k = textosFlotantes.size() - 1; k >= 0; k--) {
    if (!textosFlotantes.get(k).actualizar(dt)) textosFlotantes.remove(k);
  }
}

// ---------------------------------------------------------------------------
// Efectos: papelitos, vidrios y textos que suben
// ---------------------------------------------------------------------------

class Particula {
  float x, y, vx, vy, vida, total, tam;
  color col;

  Particula(float x, float y, float vx, float vy, float vida, color col, float tam) {
    this.x = x;
    this.y = y;
    this.vx = vx;
    this.vy = vy;
    this.vida = this.total = vida;
    this.col = col;
    this.tam = tam;
  }

  boolean actualizar(float dt) {
    x += vx * dt;
    y += vy * dt;
    vy += 160 * dt;
    vida -= dt;
    return vida > 0;
  }

  void dibujar() {
    noStroke();
    fill(col, 255 * constrain(vida / total * 1.5, 0, 1));
    rect(x - tam / 2, y - tam / 2, tam, tam);
  }
}

class TextoFlotante {
  float x, y, vida = 1.1;
  String texto;
  color col;

  TextoFlotante(float x, float y, String texto, color col) {
    this.x = x;
    this.y = y;
    this.texto = texto;
    this.col = col;
  }

  boolean actualizar(float dt) {
    vida -= dt;
    return vida > 0;
  }
}


// ======================================================================
// Bots.pde
// ======================================================================
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

  // Después de la ronda: caminan de un punto a otro del parque, con pausas
  float pausaPaseo;
  void pasear(float dt) {
    if (c.aturdido > 0) {
      c.moviendose = false;
      return;
    }
    if (pausaPaseo > 0) {
      pausaPaseo -= dt;
      c.moviendose = false;
      return;
    }
    if (ruta == null) {
      PVector p = puntoLibreCerca(centroX + random(-8, 8), centroY + random(-8, 8));
      irA(p.x, p.y);
      if (ruta == null) pausaPaseo = 1;
      return;
    }
    if (seguirRuta(dt, false)) {
      ruta = null;
      c.moviendose = false;
      pausaPaseo = random(0.6, 2.2);
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


// ======================================================================
// Candidato.pde
// ======================================================================
// Los candidatos: el jugador y los rivales que maneja el computador (Bots.pde).
// Todos caminan igual, chocan con lo mismo, pegan volantes y lanzan botellas.

final float RADIO_PERSONA = 0.22;   // en baldosas
final float VELOCIDAD_CAMINAR = 3.0;
final float VELOCIDAD_CORRER = 5.2;

ArrayList<Candidato> candidatos = new ArrayList<Candidato>();

class Candidato extends Movil {
  int id;
  String nombre;
  color col, claro;
  float x, y;                // pies, en baldosas
  float inicioX, inicioY;    // de dónde sale
  float dirX = 1, dirY = 1;  // hacia dónde mira (en baldosas)
  boolean moviendose, corriendo;
  PImage[] frente = new PImage[3];
  PImage[] espalda = new PImage[3];
  int botellas;
  float aturdido;            // segundos que le quedan quieto por un botellazo
  float progresoPegar;       // 0 a 1 mientras mantiene pegando
  int puntoPegando = -1;
  int ultimoLogro;           // millis del último volante (desempata la lista)
  float filaLista = -1;      // posición animada en la lista en vivo
  Bot bot;                   // null si es el jugador
  float trabadoCarro;        // segundos sin poder pasar por un carro

  Candidato(int id, String nombre, color col, String sprites, float x, float y) {
    this.id = id;
    this.nombre = nombre;
    this.col = col;
    this.claro = lerpColor(col, color(255), 0.45);
    this.x = this.inicioX = x;
    this.y = this.inicioY = y;
    for (int k = 0; k < 3; k++) {
      frente[k] = loadImage("personas/" + sprites + "_frente_" + k + ".png");
      espalda[k] = loadImage("personas/" + sprites + "_espalda_" + k + ".png");
    }
  }

  public float px() {
    return x;
  }

  public float py() {
    return y;
  }

  // gx, gy: hacia dónde quiere ir, en baldosas (no hace falta que midan 1)
  void mover(float dt, float gx, float gy, boolean correr) {
    moviendose = false;
    corriendo = false;
    if (aturdido > 0) return;
    float largo = sqrt(gx * gx + gy * gy);
    if (largo < 0.001) return;
    gx /= largo;
    gy /= largo;
    corriendo = correr;
    float velocidad = correr ? VELOCIDAD_CORRER : VELOCIDAD_CAMINAR;
    if (bot != null) velocidad *= bot.factorVelocidad();
    // por separado en x y en y para poder deslizarse por las paredes
    float dx = gx * velocidad * dt;
    float dy = gy * velocidad * dt;
    // los carros estorban, pero si uno se queda trabado más de un segundo pasa
    boolean conCarros = trabadoCarro < 1.2;
    boolean movio = false;
    if (libre(x + dx, y, RADIO_PERSONA) && !(conCarros && personaChocaCarro(x + dx, y))) {
      x += dx;
      movio = true;
    }
    if (libre(x, y + dy, RADIO_PERSONA) && !(conCarros && personaChocaCarro(x, y + dy))) {
      y += dy;
      movio = true;
    }
    if (!movio && (personaChocaCarro(x + dx, y) || personaChocaCarro(x, y + dy))) trabadoCarro += dt;
    else if (movio && !personaChocaCarro(x, y)) trabadoCarro = 0;
    dirX = gx;
    dirY = gy;
    moviendose = true;
  }

  void mirarHacia(float tx, float ty) {
    float dx = tx - x, dy = ty - y;
    float l = sqrt(dx * dx + dy * dy);
    if (l > 0.01) {
      dirX = dx / l;
      dirY = dy / l;
    }
  }

  // Se dibuja dentro de la transformación de la ciudad (pixeles del dibujo)
  public void dibujar() {
    if (this == yo && manejando != null) return;   // va dentro del carro
    float sx = round(pantallaX(x, y));
    float sy = round(pantallaY(x, y));
    float mx = dirX - dirY;
    float my = (dirX + dirY) * 0.5;
    int cuadro = moviendose ? 1 + (millis() / (corriendo ? 110 : 160)) % 2 : 0;
    PImage img = my < -0.05 ? espalda[cuadro] : frente[cuadro];
    // anillo del color del candidato bajo los pies
    noStroke();
    fill(40, 34, 60, 80);
    ellipse(sx, sy, 15, 6);
    noFill();
    stroke(col);
    strokeWeight(1.2);
    ellipse(sx, sy, 17, 7.5);
    noStroke();
    pushMatrix();
    translate(sx, sy);
    if (mx > 0) scale(-1, 1);
    if (aturdido > 0) tint(255, 200, 200);
    image(img, -8, -27);
    noTint();
    popMatrix();
  }
}

// ---------------------------------------------------------------------------
// Teclado del jugador
// ---------------------------------------------------------------------------

boolean tArriba, tAbajo, tIzquierda, tDerecha, tCorrer, tPegar;

void teclaCambio(boolean bajando) {
  char k = Character.toLowerCase(key);
  if (key == CODED) {
    if (keyCode == UP) tArriba = bajando;
    if (keyCode == DOWN) tAbajo = bajando;
    if (keyCode == LEFT) tIzquierda = bajando;
    if (keyCode == RIGHT) tDerecha = bajando;
    if (keyCode == SHIFT) tCorrer = bajando;
    return;
  }
  if (k == 'w') tArriba = bajando;
  if (k == 's') tAbajo = bajando;
  if (k == 'a') tIzquierda = bajando;
  if (k == 'd') tDerecha = bajando;
  if (k == 'e') tPegar = bajando;
}


// ======================================================================
// Carros.pde
// ======================================================================
// Carros: el tráfico de la ciudad y los carros que se pueden manejar.
//
// El tráfico va por un grafo de carriles. Cada vía tiene dos carriles (uno
// por sentido, por la derecha). Un "tramo" es un pedazo de carril: una recta
// entre dos cruces o una curva dentro de un cruce (de frente, a la derecha o
// a la izquierda). Al terminar un tramo, el carro escoge al azar uno de los
// siguientes. En los bordes de la ciudad los carriles dan la vuelta en U.
// Cada cruce tiene su semáforo: 6,5 s verde para un eje, 1,5 s amarillo, y
// luego el otro eje. Los carros paran en rojo y frenan si hay alguien
// adelante (otro carro o una persona).
//
// Cualquier carro se puede manejar: E al lado para subirse (en el paseo,
// no durante un evento), WASD para manejar y E otra vez para bajarse. El
// carro se queda donde lo deja el jugador.

final int NUM_TRAFICO = 14;
final float ANCLA_CARRO_X = 32, ANCLA_CARRO_Y = 32;
final int ROJO = 0, AMARILLO = 1, VERDE = 2;
final float CICLO_SEMAFORO = 16;

PImage[][] dibujoCarro = new PImage[8][8];
ArrayList<Carro> carros = new ArrayList<Carro>();
ArrayList<Tramo> tramos = new ArrayList<Tramo>();
Carro manejando = null;       // el carro que maneja el jugador (o null)
int[] viasX, viasY;           // baldosa donde empieza cada vía (4 de ancho)
float maleconX;
float[][] desfaseSemaforo;
ArrayList<float[]> lucesSemaforo = new ArrayList<float[]>();   // i, j, eje (0 v, 1 h), 6 coordenadas

// ---------------------------------------------------------------------------
// Tramos de carril
// ---------------------------------------------------------------------------

class Tramo {
  float[] px, py, acum;
  float largo;
  ArrayList<Tramo> siguientes = new ArrayList<Tramo>();
  int cruceI = -1, cruceJ = -1;   // si termina en la entrada de un cruce
  int eje = -1;                   // 0 vertical, 1 horizontal (para el semáforo)
  boolean enCruce;

  // Recta o curva (Bézier cuadrática) de a a b con control c
  Tramo(float ax, float ay, float cx, float cy, float bx, float by, boolean enCruce) {
    this.enCruce = enCruce;
    int n = max(2, ceil(dist(ax, ay, bx, by) / 0.25));
    px = new float[n + 1];
    py = new float[n + 1];
    acum = new float[n + 1];
    for (int k = 0; k <= n; k++) {
      float t = k / (float) n;
      px[k] = sq(1 - t) * ax + 2 * (1 - t) * t * cx + t * t * bx;
      py[k] = sq(1 - t) * ay + 2 * (1 - t) * t * cy + t * t * by;
      if (k > 0) acum[k] = acum[k - 1] + dist(px[k - 1], py[k - 1], px[k], py[k]);
    }
    largo = acum[n];
  }

  // Posición y rumbo a una distancia s del comienzo
  float[] en(float s) {
    s = constrain(s, 0, largo);
    int k = 1;
    while (k < acum.length - 1 && acum[k] < s) k++;
    float t = (s - acum[k - 1]) / max(0.0001, acum[k] - acum[k - 1]);
    float x = lerp(px[k - 1], px[k], t), y = lerp(py[k - 1], py[k], t);
    return new float[] {x, y, atan2(py[k] - py[k - 1], px[k] - px[k - 1])};
  }
}

Tramo recta(float ax, float ay, float bx, float by) {
  Tramo t = new Tramo(ax, ay, (ax + bx) / 2, (ay + by) / 2, bx, by, false);
  tramos.add(t);
  return t;
}

Tramo curva(float ax, float ay, float cx, float cy, float bx, float by, boolean enCruce) {
  Tramo t = new Tramo(ax, ay, cx, cy, bx, by, enCruce);
  tramos.add(t);
  return t;
}

// Direcciones: 0 este (+x), 1 sur (+y), 2 oeste (-x), 3 norte (-y)
final int ESTE = 0, SUR = 1, OESTE = 2, NORTE = 3;

// Dónde se entra a un cruce y dónde se sale, según el sentido
float[] entradaCruce(int i, int j, int d) {
  float X = viasX[i], Y = viasY[j];
  if (d == ESTE) return new float[] {X, Y + 3};
  if (d == SUR) return new float[] {X + 1, Y};
  if (d == OESTE) return new float[] {X + 4, Y + 1};
  return new float[] {X + 3, Y + 4};
}

float[] salidaCruce(int i, int j, int d) {
  float X = viasX[i], Y = viasY[j];
  if (d == ESTE) return new float[] {X + 4, Y + 3};
  if (d == SUR) return new float[] {X + 1, Y + 4};
  if (d == OESTE) return new float[] {X, Y + 1};
  return new float[] {X + 3, Y};
}

void armarCarriles() {
  int ni = viasX.length, nj = viasY.length;
  float finX = baldosasX - 1.5, finY = baldosasY - 1.5, iniX = maleconX + 1.5, iniY = 1.5;
  // las curvas dentro de cada cruce: [i][j][entra][sale]
  Tramo[][][][] giro = new Tramo[ni][nj][4][4];
  for (int i = 0; i < ni; i++) {
    for (int j = 0; j < nj; j++) {
      for (int d = 0; d < 4; d++) {
        for (int e = 0; e < 4; e++) {
          if (e == (d + 2) % 4) continue;   // sin vuelta en U en el cruce
          float[] a = entradaCruce(i, j, d), b = salidaCruce(i, j, e);
          float cx, cy;
          if (d == e) {
            cx = (a[0] + b[0]) / 2;
            cy = (a[1] + b[1]) / 2;
          } else if (d == ESTE || d == OESTE) {
            cx = b[0];
            cy = a[1];
          } else {
            cx = a[0];
            cy = b[1];
          }
          giro[i][j][d][e] = curva(a[0], a[1], cx, cy, b[0], b[1], true);
        }
      }
    }
  }
  // las rectas entre cruces, con su llegada al cruce siguiente
  for (int i = 0; i < ni; i++) {
    for (int j = 0; j < nj; j++) {
      // al este
      float[] s = salidaCruce(i, j, ESTE);
      if (i + 1 < ni) unirAlCruce(recta(s[0], s[1], viasX[i + 1], s[1]), giro, i + 1, j, ESTE);
      // al sur
      s = salidaCruce(i, j, SUR);
      if (j + 1 < nj) unirAlCruce(recta(s[0], s[1], s[0], viasY[j + 1]), giro, i, j + 1, SUR);
      // al oeste
      s = salidaCruce(i, j, OESTE);
      if (i > 0) unirAlCruce(recta(s[0], s[1], viasX[i - 1] + 4, s[1]), giro, i - 1, j, OESTE);
      // al norte
      s = salidaCruce(i, j, NORTE);
      if (j > 0) unirAlCruce(recta(s[0], s[1], s[0], viasY[j - 1] + 4), giro, i, j - 1, NORTE);
    }
  }
  // los bordes: el carril sigue hasta cerca del borde y da la vuelta en U
  for (int j = 0; j < nj; j++) {
    float Y = viasY[j];
    // derecha (este)
    float[] s = salidaCruce(ni - 1, j, ESTE);
    Tramo a = recta(s[0], s[1], finX, Y + 3);
    Tramo u = curva(finX, Y + 3, finX + 1.3, Y + 2, finX, Y + 1, false);
    Tramo b = recta(finX, Y + 1, viasX[ni - 1] + 4, Y + 1);
    a.siguientes.add(u);
    u.siguientes.add(b);
    unirAlCruce(b, giro, ni - 1, j, OESTE);
    // izquierda (oeste, en el malecón)
    s = salidaCruce(0, j, OESTE);
    a = recta(s[0], s[1], iniX, Y + 1);
    u = curva(iniX, Y + 1, iniX - 1.3, Y + 2, iniX, Y + 3, false);
    b = recta(iniX, Y + 3, viasX[0], Y + 3);
    a.siguientes.add(u);
    u.siguientes.add(b);
    unirAlCruce(b, giro, 0, j, ESTE);
  }
  for (int i = 0; i < ni; i++) {
    float X = viasX[i];
    // abajo (sur)
    float[] s = salidaCruce(i, nj - 1, SUR);
    Tramo a = recta(s[0], s[1], X + 1, finY);
    Tramo u = curva(X + 1, finY, X + 2, finY + 1.3, X + 3, finY, false);
    Tramo b = recta(X + 3, finY, X + 3, viasY[nj - 1] + 4);
    a.siguientes.add(u);
    u.siguientes.add(b);
    unirAlCruce(b, giro, i, nj - 1, NORTE);
    // arriba (norte)
    s = salidaCruce(i, 0, NORTE);
    a = recta(s[0], s[1], X + 3, iniY);
    u = curva(X + 3, iniY, X + 2, iniY - 1.3, X + 1, iniY, false);
    b = recta(X + 1, iniY, X + 1, viasY[0]);
    a.siguientes.add(u);
    u.siguientes.add(b);
    unirAlCruce(b, giro, i, 0, SUR);
  }
  // cada curva del cruce sigue por la recta que sale de ella
  for (Tramo t : tramos) {
    if (!t.enCruce) continue;
    float bx = t.px[t.px.length - 1], by = t.py[t.py.length - 1];
    for (Tramo r : tramos) {
      if (r.enCruce) continue;
      if (dist(r.px[0], r.py[0], bx, by) < 0.05) t.siguientes.add(r);
    }
  }
}

// La recta llega a la entrada del cruce (i, j) en el sentido d: de ahí
// salen las curvas de frente, a la derecha y a la izquierda.
void unirAlCruce(Tramo r, Tramo[][][][] giro, int i, int j, int d) {
  r.cruceI = i;
  r.cruceJ = j;
  r.eje = (d == SUR || d == NORTE) ? 0 : 1;
  for (int e = 0; e < 4; e++) {
    if (giro[i][j][d][e] != null) r.siguientes.add(giro[i][j][d][e]);
  }
}

// ---------------------------------------------------------------------------
// Semáforos
// ---------------------------------------------------------------------------

// Luz para el eje 0 (vertical) o 1 (horizontal) en el cruce (i, j)
int luz(int i, int j, int eje) {
  float t = (millis() / 1000.0 + desfaseSemaforo[i][j]) % CICLO_SEMAFORO;
  int ejeVerde = t < CICLO_SEMAFORO / 2 ? 0 : 1;
  float dentro = t % (CICLO_SEMAFORO / 2);
  if (eje != ejeVerde) return ROJO;
  return dentro < CICLO_SEMAFORO / 2 - 1.5 ? VERDE : AMARILLO;
}

// La luz que toca, encima del dibujo del semáforo (se llama justo después de él)
void dibujarLuzSemaforo(int s) {
  if (s < 0 || s >= lucesSemaforo.size()) return;
  float[] l = lucesSemaforo.get(s);
  int estado = luz((int) l[0], (int) l[1], (int) l[2]);
  int k = estado == ROJO ? 0 : (estado == AMARILLO ? 1 : 2);
  float x = l[3 + k * 2], y = l[4 + k * 2];
  color c = estado == ROJO ? color(255, 70, 60) : (estado == AMARILLO ? color(255, 210, 70) : color(90, 240, 120));
  noStroke();
  fill(c, 70);
  ellipse(x, y - 1, 6, 6);
  fill(c);
  rect(x - 1, y - 2, 2.4, 2);
}

// ---------------------------------------------------------------------------
// Los carros
// ---------------------------------------------------------------------------

class Carro extends Movil {
  float x, y, ang, vel;
  int variante;
  boolean ia;               // lo maneja el tráfico
  Tramo tramo;
  float s;                  // distancia recorrida en el tramo
  float parado;             // segundos frenado por otro carro
  float fantasma;           // segundos ignorando carros (para destrabar)

  Carro(float x, float y, float ang, int variante) {
    this.x = x;
    this.y = y;
    this.ang = ang;
    this.variante = variante;
  }

  public float px() {
    return x;
  }

  public float py() {
    return y;
  }

  float dx() {
    return cos(ang);
  }

  float dy() {
    return sin(ang);
  }

  // Tráfico: sigue su tramo, para en rojo y frena si hay algo adelante
  void actualizarIA(float dt) {
    float objetivo = tramo.enCruce ? 3.0 : 4.6;
    float falta = tramo.largo - s;
    if (tramo.cruceI >= 0) {
      int l = luz(tramo.cruceI, tramo.cruceJ, tramo.eje);
      if (l == ROJO || (l == AMARILLO && falta > 1.4)) {
        if (falta > 0.25) objetivo = min(objetivo, max(0, (falta - 0.45) * 2.4));
      }
    }
    float adelante = libreAdelante(this);
    boolean porCarro = adelante < 2.6;
    if (porCarro) objetivo = min(objetivo, max(0, (adelante - 1.15) * 2.6));
    // si lleva mucho rato frenado por otro carro, se destraba un momento
    if (porCarro && vel < 0.2) parado += dt;
    else parado = 0;
    if (parado > 5) {
      fantasma = 1.5;
      parado = 0;
    }
    fantasma = max(0, fantasma - dt);
    vel += constrain(objetivo - vel, -11 * dt, 5 * dt);
    s += vel * dt;
    while (s > tramo.largo) {
      s -= tramo.largo;
      if (tramo.siguientes.size() == 0) {
        s = 0;
        break;
      }
      tramo = tramo.siguientes.get(int(random(tramo.siguientes.size())));
    }
    float[] p = tramo.en(s);
    x = p[0];
    y = p[1];
    ang = p[2];
  }

  public void dibujar() {
    int d = ((round(ang / QUARTER_PI) % 8) + 8) % 8;
    float sx = round(pantallaX(x, y)), sy = round(pantallaY(x, y));
    noStroke();
    fill(40, 34, 60, 70);
    ellipse(sx + 2, sy + 2, 36, 16);
    image(dibujoCarro[variante][d], sx - ANCLA_CARRO_X, sy - ANCLA_CARRO_Y);
  }
}

// Cuánto espacio libre tiene el carro adelante (otro carro o una persona en
// su carril), hasta 3 baldosas.
float libreAdelante(Carro c) {
  float menor = 99;
  float fx = c.dx(), fy = c.dy();
  if (c.fantasma <= 0) {
    for (Carro o : carros) {
      if (o == c) continue;
      float vx = o.x - c.x, vy = o.y - c.y;
      float a = vx * fx + vy * fy;
      float lat = abs(vx * fy - vy * fx);
      if (a > 0 && a < 3 && lat < 0.8) menor = min(menor, a);
    }
  }
  for (Candidato p : candidatos) {
    if (p == yo && manejando != null) continue;
    float vx = p.x - c.x, vy = p.y - c.y;
    float a = vx * fx + vy * fy;
    float lat = abs(vx * fy - vy * fx);
    if (a > 0 && a < 3 && lat < 0.65) menor = min(menor, a - 0.1);
  }
  for (Ciudadano z : ciudadanos) {
    float vx = z.x - c.x, vy = z.y - c.y;
    float a = vx * fx + vy * fy;
    float lat = abs(vx * fy - vy * fx);
    if (a > 0 && a < 3 && lat < 0.65) menor = min(menor, a - 0.1);
  }
  return menor;
}

void cargarCarros() {
  for (int v = 0; v < 8; v++) {
    for (int d = 0; d < 8; d++) {
      dibujoCarro[v][d] = loadImage("mundo/carro_" + v + "_" + d + ".png");
    }
  }
  HashMap<String, String> info = new HashMap<String, String>();
  for (String l : loadStrings("mundo/mundo.txt")) {
    String[] p = split(trim(l), '=');
    if (p.length == 2) info.put(p[0], p[1]);
  }
  viasX = int(split(info.get("VIAS_X"), ','));
  viasY = int(split(info.get("VIAS_Y"), ','));
  maleconX = float(info.get("MALECON"));
  desfaseSemaforo = new float[viasX.length][viasY.length];
  for (int i = 0; i < viasX.length; i++) {
    for (int j = 0; j < viasY.length; j++) {
      desfaseSemaforo[i][j] = (i * 5.3 + j * 3.1) % CICLO_SEMAFORO;
    }
  }
  for (String l : loadStrings("mundo/semaforos.txt")) {
    String[] p = splitTokens(l);
    if (p.length < 9) continue;
    float[] f = new float[9];
    f[0] = float(p[0]);
    f[1] = float(p[1]);
    f[2] = p[2].equals("v") ? 0 : 1;
    for (int k = 0; k < 6; k++) f[3 + k] = float(p[3 + k]);
    lucesSemaforo.add(f);
  }
  armarCarriles();
  // los estacionados (el de la campaña, los de la gasolinera...)
  for (String l : loadStrings("mundo/carros.txt")) {
    String[] p = splitTokens(l);
    if (p.length < 4) continue;
    carros.add(new Carro(float(p[0]), float(p[1]), float(p[2]), int(p[3])));
  }
  // el tráfico, repartido por las rectas
  ArrayList<Tramo> rectas = new ArrayList<Tramo>();
  for (Tramo t : tramos) if (!t.enCruce && t.largo > 6) rectas.add(t);
  int intentos = 0;
  while (carros.size() < NUM_TRAFICO + 6 && intentos < 500) {
    intentos++;
    Tramo t = rectas.get(int(random(rectas.size())));
    float s = random(1, t.largo - 2);
    float[] p = t.en(s);
    boolean lejos = true;
    for (Carro o : carros) if (dist(o.x, o.y, p[0], p[1]) < 4) lejos = false;
    if (!lejos) continue;
    Carro c = new Carro(p[0], p[1], p[2], random(1) < 0.35 ? 7 : int(random(7)));
    c.ia = true;
    c.tramo = t;
    c.s = s;
    carros.add(c);
  }
}

void actualizarCarros(float dt) {
  for (Carro c : carros) {
    if (c.ia) c.actualizarIA(dt);
  }
  if (manejando != null) {
    manejarCarro(manejando, dt);
    yo.x = manejando.x;
    yo.y = manejando.y;
  }
}

// ---------------------------------------------------------------------------
// Manejar
// ---------------------------------------------------------------------------

// ¿Cabe el carro en (x, y) con ese rumbo? Se mira con dos círculos (adelante
// y atrás). No entra al parque, al malecón ni al río.
boolean carroCabe(Carro c, float x, float y, float ang) {
  for (int k = -1; k <= 1; k += 2) {
    float cx = x + cos(ang) * 0.45 * k, cy = y + sin(ang) * 0.45 * k;
    if (!libre(cx, cy, 0.38)) return false;
    int z = zonaEn(cx, cy);
    if (z == 1 || z == 2 || z == 7) return false;
    for (Carro o : carros) {
      if (o == c) continue;
      for (int m = -1; m <= 1; m += 2) {
        if (dist(cx, cy, o.x + o.dx() * 0.45 * m, o.y + o.dy() * 0.45 * m) < 0.78) return false;
      }
    }
    for (Candidato p : candidatos) {
      if (p == yo) continue;
      if (dist(cx, cy, p.x, p.y) < 0.6) return false;
    }
  }
  return true;
}

// W acelera, S frena (o va en reversa), A y D giran
void manejarCarro(Carro c, float dt) {
  float acel = (tArriba ? 1 : 0) - (tAbajo ? 1 : 0);
  float giro = (tDerecha ? 1 : 0) - (tIzquierda ? 1 : 0);
  if (acel > 0) c.vel += (c.vel < 0 ? 14 : 7) * dt;
  else if (acel < 0) c.vel -= (c.vel > 0 ? 14 : 5) * dt;
  else c.vel -= constrain(c.vel, -4 * dt, 4 * dt);
  c.vel = constrain(c.vel, -3, 9.5);
  float nuevoAng = c.ang + giro * 2.3 * dt * constrain(c.vel / 3, -1, 1);
  float nx = c.x + cos(nuevoAng) * c.vel * dt;
  float ny = c.y + sin(nuevoAng) * c.vel * dt;
  if (carroCabe(c, nx, ny, nuevoAng)) {
    c.x = nx;
    c.y = ny;
    c.ang = nuevoAng;
  } else if (carroCabe(c, c.x, c.y, nuevoAng)) {
    c.ang = nuevoAng;
    c.vel *= -0.25;
  } else {
    c.vel *= -0.25;
  }
}

Carro carroCercano(float x, float y, float alcance) {
  Carro mejor = null;
  float md = alcance;
  for (Carro c : carros) {
    float d = dist(c.x, c.y, x, y);
    if (d < md) {
      md = d;
      mejor = c;
    }
  }
  return mejor;
}

// E en el paseo: subirse al carro de al lado o bajarse del que se maneja
void teclaCarro() {
  if (!puedeManejar()) return;
  if (manejando != null) {
    bajarseDelCarro();
    return;
  }
  Carro c = carroCercano(yo.x, yo.y, 1.6);
  if (c == null) return;
  c.ia = false;
  c.tramo = null;
  c.vel = 0;
  manejando = c;
  sonar("puerta");
  yo.moviendose = false;
  avisar("WASD para manejar · E para bajarte");
}

void bajarseDelCarro() {
  Carro c = manejando;
  if (c == null) return;
  manejando = null;
  sonar("puerta");
  c.vel = 0;
  // se baja por un lado, donde haya espacio
  float[][] lados = {{-sin(c.ang), cos(c.ang)}, {sin(c.ang), -cos(c.ang)}, {-cos(c.ang), -sin(c.ang)}, {cos(c.ang), sin(c.ang)}};
  for (float[] l : lados) {
    for (float r = 0.9; r <= 2.2; r += 0.3) {
      float x = c.x + l[0] * r, y = c.y + l[1] * r;
      if (libre(x, y, RADIO_PERSONA) && !personaChocaCarro(x, y)) {
        yo.x = x;
        yo.y = y;
        return;
      }
    }
  }
  PVector p = puntoLibreCerca(c.x, c.y + 1.5);
  yo.x = p.x;
  yo.y = p.y;
}

// Para las personas: ¿ese punto queda encima de algún carro?
boolean personaChocaCarro(float x, float y) {
  for (Carro c : carros) {
    if (c == manejando) continue;
    for (int m = -1; m <= 1; m += 2) {
      if (dist(x, y, c.x + c.dx() * 0.45 * m, c.y + c.dy() * 0.45 * m) < 0.58) return true;
    }
  }
  if (manejando != null) {
    for (int m = -1; m <= 1; m += 2) {
      if (dist(x, y, manejando.x + manejando.dx() * 0.45 * m, manejando.y + manejando.dy() * 0.45 * m) < 0.58) return true;
    }
  }
  return false;
}

// Se maneja al ir al parque, al volver a la sede y en la ronda de los lives
// (que es por toda la ciudad). En red no, para no desincronizar.
boolean puedeManejar() {
  if (modoRed != SOLO) return false;
  return estadoRonda == PASEO || estadoRonda == VUELTA || (estadoRonda == RONDA && evento == LIVES);
}

// "E: subirte" encima del carro más cercano, y la velocidad al manejar
void dibujarAyudaCarro() {
  if (!puedeManejar()) return;
  if (manejando != null) {
    textFont(fuenteNegrita, 11 * pixel);
    String s = round(abs(manejando.vel) * 1.5 * 3.6) + " km/h";
    float w = textWidth(s) + 18 * pixel;
    caja(width - w - 10 * pixel, height - 34 * pixel, w, 22 * pixel, 210);
    fill(CREMA);
    textAlign(CENTER, CENTER);
    text(s, width - w / 2 - 10 * pixel, height - 23 * pixel);
    return;
  }
  Carro c = carroCercano(yo.x, yo.y, 1.6);
  if (c == null) return;
  float sx = aPantallaX(pantallaX(c.x, c.y)), sy = aPantallaY(pantallaY(c.x, c.y) - 34);
  String s = "E: subirte al carro";
  textFont(fuenteNegrita, 9 * pixel);
  float w = textWidth(s) + 14 * pixel;
  caja(sx - w / 2, sy - 9 * pixel, w, 17 * pixel, 210);
  fill(CREMA);
  textAlign(CENTER, CENTER);
  text(s, sx, sy - pixel);
}


// ======================================================================
// Ciudad.pde
// ======================================================================
// La ciudad: piso en trozos, objetos con su orden de dibujo, choques, zonas
// y las rutas (BFS) para los candidatos que maneja el computador.
//
// Coordenadas: el mundo se mide en baldosas (x, y). En pantalla una baldosa
// es un rombo de 32x16 pixeles del dibujo: ir hacia +x baja a la derecha e ir
// hacia +y baja a la izquierda.

float OX, OY;               // dónde cae la baldosa (0, 0) en el dibujo
int T = 16;                 // unidades del generador por baldosa
int CEL = 4;                // la cuadrícula de choques mide 4x4 unidades
int TROZO = 512;
int anchoMundo, altoMundo;  // tamaño del dibujo completo, en pixeles
int baldosasX, baldosasY;
float inicioX, inicioY;
float centroX, centroY, radioPlaza;
float arenaX0, arenaY0, arenaX1, arenaY1;
boolean arenaCerrada = false;   // durante la ronda nadie sale del parque y sus calles

PImage[][] trozos;
ArrayList<Objeto> objetos = new ArrayList<Objeto>();
boolean[][] choque;         // [i][j] = celda de 4x4 unidades bloqueada
boolean[][] paso;           // celda por donde cabe una persona (para las rutas)
int celdasX, celdasY;
int[][] zona;               // [i][j] por baldosa
String[] nombresZona;
PImage minimapa;

// Un objeto quieto de la ciudad: su dibujo, dónde va y su huella en el piso
// (la caja que ocupa, en unidades), que sirve para saber si alguien está
// delante o detrás de él. Si es una cartelera, punto dice cuál.
class Objeto {
  PImage img;
  int x0, y0;
  float prof;
  float hx, hy, hw, hd;     // huella; hw < 0 si es un punto
  int punto;
  int semaforo = -1;        // si es un semáforo, cuál (para prender su luz)

  Objeto(PImage img, int x0, int y0, float prof, float hx, float hy, float hw, float hd, int punto) {
    this.img = img;
    this.x0 = x0;
    this.y0 = y0;
    this.prof = prof;
    this.hx = hx;
    this.hy = hy;
    this.hw = hw;
    this.hd = hd;
    this.punto = punto;
  }

  // ¿El punto (ux, uy) en unidades queda detrás de este objeto?
  // Detrás de una caja es estar antes de su borde de abajo en x y en y.
  boolean tapa(float ux, float uy) {
    if (hw < 0) return ux + uy < prof;
    return ux < hx + hw && uy < hy + hd;
  }

  boolean seCruza(float x1, float y1, float x2, float y2) {
    return x0 < x2 && x0 + img.width > x1 && y0 < y2 && y0 + img.height > y1;
  }
}

void cargarMundo() {
  HashMap<String, String> info = new HashMap<String, String>();
  for (String l : loadStrings("mundo/mundo.txt")) {
    String[] p = split(trim(l), '=');
    if (p.length == 2) info.put(p[0], p[1]);
  }
  OX = float(info.get("OX"));
  OY = float(info.get("OY"));
  T = int(info.get("T"));
  CEL = int(info.get("CEL"));
  TROZO = int(info.get("TROZO"));
  anchoMundo = int(info.get("ANCHO"));
  altoMundo = int(info.get("ALTO"));
  baldosasX = int(info.get("BALDOSAS_X"));
  baldosasY = int(info.get("BALDOSAS_Y"));
  inicioX = float(info.get("INICIO_X"));
  inicioY = float(info.get("INICIO_Y"));
  centroX = float(info.get("CENTRO_X"));
  centroY = float(info.get("CENTRO_Y"));
  radioPlaza = float(info.get("RADIO_PLAZA"));
  arenaX0 = float(info.get("ARENA_X0"));
  arenaY0 = float(info.get("ARENA_Y0"));
  arenaX1 = float(info.get("ARENA_X1"));
  arenaY1 = float(info.get("ARENA_Y1"));

  // Piso
  int tx = ceil(anchoMundo / (float) TROZO);
  int ty = ceil(altoMundo / (float) TROZO);
  trozos = new PImage[tx][ty];
  for (int i = 0; i < tx; i++) {
    for (int j = 0; j < ty; j++) {
      trozos[i][j] = loadImage("mundo/piso_" + i + "_" + j + ".png");
    }
  }

  // Objetos (ya vienen en orden de dibujo). Los dibujos repetidos se cargan una vez.
  HashMap<String, PImage> dibujos = new HashMap<String, PImage>();
  for (String l : loadStrings("mundo/objetos.txt")) {
    String[] p = splitTokens(l);
    if (p.length < 9) continue;
    PImage img = dibujos.get(p[0]);
    if (img == null) {
      img = loadImage("mundo/" + p[0]);
      dibujos.put(p[0], img);
    }
    Objeto o = new Objeto(img, int(p[1]), int(p[2]), float(p[3]),
      float(p[4]), float(p[5]), float(p[6]), float(p[7]), int(p[8]));
    if (p.length >= 10) o.semaforo = int(p[9]);
    objetos.add(o);
  }

  // Choques: blanco = no se pasa
  PImage c = loadImage("mundo/choques.png");
  c.loadPixels();
  celdasX = c.width;
  celdasY = c.height;
  choque = new boolean[celdasX][celdasY];
  for (int j = 0; j < celdasY; j++) {
    for (int i = 0; i < celdasX; i++) {
      choque[i][j] = (c.pixels[j * celdasX + i] & 0xFF) > 127;
    }
  }
  // Para las rutas: una celda sirve si ella y sus ocho vecinas están libres
  // (así la persona, que es más ancha que una celda, no se queda pegada).
  paso = new boolean[celdasX][celdasY];
  for (int i = 1; i < celdasX - 1; i++) {
    for (int j = 1; j < celdasY - 1; j++) {
      boolean ok = true;
      for (int a = -1; a <= 1 && ok; a++) {
        for (int b = -1; b <= 1 && ok; b++) {
          if (choque[i + a][j + b]) ok = false;
        }
      }
      paso[i][j] = ok;
    }
  }

  // Zonas: el valor de cada pixel es el número de la zona
  PImage z = loadImage("mundo/zonas.png");
  z.loadPixels();
  zona = new int[z.width][z.height];
  for (int j = 0; j < z.height; j++) {
    for (int i = 0; i < z.width; i++) {
      zona[i][j] = z.pixels[j * z.width + i] & 0xFF;
    }
  }
  nombresZona = loadStrings("mundo/zonas.txt");
  minimapa = loadImage("mundo/minimapa.png");
}

float pantallaX(float x, float y) {
  return OX + (x - y) * T;
}

float pantallaY(float x, float y) {
  return OY + (x + y) * T / 2.0;
}

boolean enArena(float x, float y) {
  return x >= arenaX0 && x <= arenaX1 && y >= arenaY0 && y <= arenaY1;
}

// ¿Se puede estar en (x, y)? Revisa las celdas que toca un círculo de radio r.
boolean libre(float x, float y, float r) {
  if (arenaCerrada && !enArena(x, y)) return false;
  float ux = x * T, uy = y * T, ru = r * T;
  int i0 = floor((ux - ru) / CEL), i1 = floor((ux + ru) / CEL);
  int j0 = floor((uy - ru) / CEL), j1 = floor((uy + ru) / CEL);
  for (int i = i0; i <= i1; i++) {
    for (int j = j0; j <= j1; j++) {
      if (i < 0 || j < 0 || i >= celdasX || j >= celdasY) return false;
      if (choque[i][j]) return false;
    }
  }
  return true;
}

int zonaEn(float x, float y) {
  int i = constrain(floor(x), 0, zona.length - 1);
  int j = constrain(floor(y), 0, zona[0].length - 1);
  return zona[i][j];
}

// ---------------------------------------------------------------------------
// Rutas: BFS sobre la cuadrícula de celdas (un cuarto de baldosa)
// ---------------------------------------------------------------------------

int celdaDe(float baldosas) {
  return floor(baldosas * T / CEL);
}

float baldosaDe(int celda) {
  return (celda + 0.5) * CEL / (float) T;
}

boolean celdaUsable(int i, int j) {
  if (i < 0 || j < 0 || i >= celdasX || j >= celdasY || !paso[i][j]) return false;
  if (arenaCerrada && !enArena(baldosaDe(i), baldosaDe(j))) return false;
  return true;
}

// La celda usable más cercana a (x, y), buscando en anillos cada vez más grandes
PVector puntoLibreCerca(float x, float y) {
  int ci = celdaDe(x), cj = celdaDe(y);
  for (int r = 0; r < 40; r++) {
    for (int a = -r; a <= r; a++) {
      for (int b = -r; b <= r; b++) {
        if (max(abs(a), abs(b)) != r) continue;
        if (celdaUsable(ci + a, cj + b)) return new PVector(baldosaDe(ci + a), baldosaDe(cj + b));
      }
    }
  }
  return new PVector(x, y);
}

// Camino más corto (en pasos de celda) de (x0, y0) a (x1, y1). Devuelve la
// lista de puntos a seguir, ya simplificada, o null si no hay camino.
// BFS con una cola: se visita por anillos de distancia desde el inicio, y cada
// celda guarda de dónde se llegó para reconstruir el camino al final.
int[] vieneDe;
ArrayList<PVector> rutaBFS(float x0, float y0, float x1, float y1) {
  if (vieneDe == null) vieneDe = new int[celdasX * celdasY];
  java.util.Arrays.fill(vieneDe, -1);
  PVector a = puntoLibreCerca(x0, y0);
  PVector b = puntoLibreCerca(x1, y1);
  int si = celdaDe(a.x), sj = celdaDe(a.y);
  int ti = celdaDe(b.x), tj = celdaDe(b.y);
  int inicio = si * celdasY + sj, meta = ti * celdasY + tj;
  java.util.ArrayDeque<Integer> cola = new java.util.ArrayDeque<Integer>();
  cola.add(inicio);
  vieneDe[inicio] = inicio;
  int[] di = {1, -1, 0, 0, 1, 1, -1, -1};
  int[] dj = {0, 0, 1, -1, 1, -1, 1, -1};
  boolean llego = false;
  while (!cola.isEmpty()) {
    int c = cola.poll();
    if (c == meta) {
      llego = true;
      break;
    }
    int ci = c / celdasY, cj = c % celdasY;
    for (int k = 0; k < 8; k++) {
      int ni = ci + di[k], nj = cj + dj[k];
      if (!celdaUsable(ni, nj)) continue;
      // en diagonal solo si las dos celdas de al lado también sirven
      if (k >= 4 && (!celdaUsable(ci + di[k], cj) || !celdaUsable(ci, cj + dj[k]))) continue;
      int n = ni * celdasY + nj;
      if (vieneDe[n] != -1) continue;
      vieneDe[n] = c;
      cola.add(n);
    }
  }
  if (!llego) return null;
  ArrayList<PVector> celdas = new ArrayList<PVector>();
  int c = meta;
  while (c != inicio) {
    celdas.add(new PVector(baldosaDe(c / celdasY), baldosaDe(c % celdasY)));
    c = vieneDe[c];
  }
  java.util.Collections.reverse(celdas);   // se armó desde la meta hacia atrás
  celdas.add(new PVector(b.x, b.y));
  // simplificar: de cada punto se salta al más lejano que se vea en línea recta
  ArrayList<PVector> ruta = new ArrayList<PVector>();
  PVector actual = new PVector(a.x, a.y);
  int k = 0;
  while (k < celdas.size()) {
    int mejor = k;
    for (int m = min(celdas.size() - 1, k + 24); m > k; m--) {
      if (lineaLibre(actual.x, actual.y, celdas.get(m).x, celdas.get(m).y)) {
        mejor = m;
        break;
      }
    }
    actual = celdas.get(mejor);
    ruta.add(actual);
    k = mejor + 1;
  }
  return ruta;
}

boolean lineaLibre(float x0, float y0, float x1, float y1) {
  float d = dist(x0, y0, x1, y1);
  int n = max(1, ceil(d / 0.12));
  for (int k = 0; k <= n; k++) {
    float t = k / (float) n;
    if (!libre(lerp(x0, x1, t), lerp(y0, y1, t), RADIO_PERSONA)) return false;
  }
  return true;
}

// ---------------------------------------------------------------------------
// Dibujo
// ---------------------------------------------------------------------------

// Lo que se mueve (candidatos, botellas) se mete entre los objetos quietos:
// cada uno va antes del primer objeto que lo tapa y se le cruza en pantalla.
// (Es una clase abstracta y no una interfaz para que el sketch se pueda meter
// entero dentro de una clase del juego principal.)
abstract class Movil {
  abstract float px();      // pies en baldosas
  abstract float py();
  abstract void dibujar();
}

void dibujarCiudad() {
  pushMatrix();
  // la cámara se redondea a pixeles enteros del dibujo para que nada tiemble
  float cx = round(camX), cy = round(camY);
  translate(round(width / 2.0 - cx * pixel), round(height / 2.0 - cy * pixel));
  scale(pixel);
  float vx1 = cx - width / 2.0 / pixel, vx2 = cx + width / 2.0 / pixel;
  float vy1 = cy - height / 2.0 / pixel, vy2 = cy + height / 2.0 / pixel;

  // 1) piso: solo los trozos que se ven
  for (int i = max(0, floor(vx1 / TROZO)); i <= min(trozos.length - 1, floor(vx2 / TROZO)); i++) {
    for (int j = max(0, floor(vy1 / TROZO)); j <= min(trozos[0].length - 1, floor(vy2 / TROZO)); j++) {
      image(trozos[i][j], i * TROZO, j * TROZO);
    }
  }
  if (verChoques) dibujarChoques(vx1, vy1, vx2, vy2);
  dibujarPisoRonda();

  // 2) a cada cosa que se mueve se le busca su lugar entre los objetos
  ArrayList<Movil> moviles = movilesVisibles();
  int[] lugar = new int[moviles.size()];
  for (int m = 0; m < moviles.size(); m++) {
    Movil mv = moviles.get(m);
    float ux = mv.px() * T, uy = mv.py() * T;
    float sx = pantallaX(mv.px(), mv.py()), sy = pantallaY(mv.px(), mv.py());
    lugar[m] = objetos.size();
    for (int k = 0; k < objetos.size(); k++) {
      Objeto o = objetos.get(k);
      if (o.seCruza(sx - 9, sy - 34, sx + 9, sy + 3) && o.tapa(ux, uy)) {
        lugar[m] = k;
        break;
      }
    }
  }
  // lo alto que tapa al jugador se vuelve transparente
  float ux = yo.x * T, uy = yo.y * T;
  float px = pantallaX(yo.x, yo.y), py = pantallaY(yo.x, yo.y);
  int lugarYo = objetos.size();
  for (int m = 0; m < moviles.size(); m++) if (moviles.get(m) == yo) lugarYo = lugar[m];
  int[] orden = ordenDeMoviles(moviles, lugar);
  int siguiente = 0;   // el próximo móvil de "orden" por dibujar

  for (int k = 0; k <= objetos.size(); k++) {
    // los móviles que van justo antes del objeto k
    while (siguiente < orden.length && lugar[orden[siguiente]] == k) {
      moviles.get(orden[siguiente]).dibujar();
      siguiente++;
    }
    if (k == objetos.size()) break;
    Objeto o = objetos.get(k);
    if (!o.seCruza(vx1, vy1, vx2, vy2)) continue;
    if (k >= lugarYo && o.img.height > 34 && o.seCruza(px - 9, py - 30, px + 9, py + 3) && o.tapa(ux, uy)) {
      tint(255, 110);
      image(o.img, o.x0, o.y0);
      noTint();
    } else {
      image(o.img, o.x0, o.y0);
    }
    if (o.punto >= 0) dibujarVolante(o.punto);
    if (o.semaforo >= 0) dibujarLuzSemaforo(o.semaforo);
  }
  dibujarEncimaRonda();
  popMatrix();
}

// Los móviles ordenados una sola vez por cuadro: primero por el objeto
// delante del que van y, en el mismo lugar, de atrás hacia adelante
// (x + y). Son pocos, así que basta la inserción simple. Antes se recorría
// la lista completa por cada objeto de la ciudad.
int[] ordenDeMoviles(ArrayList<Movil> moviles, int[] lugar) {
  int n = moviles.size();
  int[] orden = new int[n];
  float[] fondo = new float[n];
  for (int m = 0; m < n; m++) {
    orden[m] = m;
    fondo[m] = moviles.get(m).px() + moviles.get(m).py();
  }
  for (int a = 1; a < n; a++) {
    int v = orden[a];
    int b = a - 1;
    while (b >= 0 && (lugar[orden[b]] > lugar[v] || (lugar[orden[b]] == lugar[v] && fondo[orden[b]] > fondo[v]))) {
      orden[b + 1] = orden[b];
      b--;
    }
    orden[b + 1] = v;
  }
  return orden;
}

// Rombos rojos en las celdas bloqueadas que se ven (para revisar el mapa)
void dibujarChoques(float vx1, float vy1, float vx2, float vy2) {
  noStroke();
  fill(255, 0, 0, 90);
  float paso = CEL / (float) T;
  for (int i = 0; i < celdasX; i++) {
    for (int j = 0; j < celdasY; j++) {
      if (!choque[i][j]) continue;
      float x = i * paso, y = j * paso;
      float sx = pantallaX(x, y), sy = pantallaY(x, y);
      if (sx < vx1 - 10 || sx > vx2 + 10 || sy < vy1 - 10 || sy > vy2 + 10) continue;
      quad(sx, sy, pantallaX(x + paso, y), pantallaY(x + paso, y),
        pantallaX(x + paso, y + paso), pantallaY(x + paso, y + paso), pantallaX(x, y + paso), pantallaY(x, y + paso));
    }
  }
}


// ======================================================================
// EnLinea.pde
// ======================================================================
// Los eventos del parque en línea (multijugador en red).
//
// El anfitrión (el PC que creó la partida) simula todo: los bots, la gente,
// los carros, las botellas y de quién es cada punto. Cada invitado manda sus
// teclas y el anfitrión le devuelve, unas 15 veces por segundo, una "foto"
// del estado (estadoRed). El invitado no simula: copia esa foto y mueve las
// cosas suavemente hacia donde dice. Los efectos (papelitos, chispas, vidrios
// y textos que suben) y los avisos también se mandan, para que cada uno los
// vea en su pantalla.
//
// Los asientos van de 0 a 3. El 0 es el anfitrión; los que no tienen persona
// los juega el computador. En la prueba (sin red) todo esto queda apagado.
//
// Quien manda y recibe los mensajes es el juego principal (Red.pde); aquí
// solo se arma y se lee el texto.

final int SOLO = 0, ANFITRION = 1, INVITADO = 2;
int modoRed = SOLO;
int miAsiento = 0;
boolean[] asientoHumano = new boolean[4];
String[] nombresAsiento = new String[4];
boolean fotoRecibida = false;     // el invitado ya recibió la primera foto
int momentoFoto = 0;              // cuándo llegó la última
int[] ultimaEntrada = new int[4]; // cuándo mandó teclas cada invitado (para saber quién está en el parque)
float esperaReunion = 0;          // cuánto lleva el anfitrión esperando en la plaza

// Teclas de cada asiento: arriba, abajo, izquierda, derecha, correr, pegar
final int T_ARRIBA = 0, T_ABAJO = 1, T_IZQ = 2, T_DER = 3, T_CORRER = 4, T_PEGAR = 5;
boolean[][] teclasAsiento = new boolean[4][6];
int ultimaMascara = -1;
int momentoMascara = 0;

// El juego principal empieza un evento en red con esto
void configurarEventoRed(int tipo, int modo, int asiento, boolean[] humanos, String[] nombres) {
  modoRed = modo;
  miAsiento = asiento;
  for (int k = 0; k < 4; k++) {
    asientoHumano[k] = humanos[k];
    nombresAsiento[k] = nombres[k];
    for (int t = 0; t < 6; t++) teclasAsiento[k][t] = false;
  }
  fotoRecibida = false;
  esperaReunion = 0;
  for (int k = 0; k < 4; k++) ultimaEntrada[k] = -100000;
  crearCandidatos();
  configurarEvento(tipo);
}

String nombreVisible(Candidato c) {
  return c == yo ? "Tú" : c.nombre;
}

boolean[] teclasDe(Candidato c) {
  if (c == yo) {
    return new boolean[] {tArriba, tAbajo, tIzquierda, tDerecha, tCorrer, tPegar};
  }
  return teclasAsiento[c.id];
}

int mascaraLocal() {
  boolean[] t = teclasDe(yo);
  int m = 0;
  for (int k = 0; k < 6; k++) if (t[k]) m |= 1 << k;
  return m;
}

// El anfitrión recibe las teclas de un invitado
void entradaRemota(int asiento, int mascara) {
  if (asiento < 0 || asiento > 3) return;
  ultimaEntrada[asiento] = millis();
  for (int k = 0; k < 6; k++) teclasAsiento[asiento][k] = (mascara & (1 << k)) != 0;
}

// ... y sus acciones de un toque: e, f, q o una flecha (0 a 3)
void accionRemota(int asiento, char a) {
  if (asiento < 0 || asiento >= candidatos.size()) return;
  Candidato c = candidatos.get(asiento);
  if (a == 'e') accionRapida(c);
  else if (a == 'f') accionAsegurar(c);
  else if (a == 'q' && rondaActiva()) lanzarDe(c);
  else if (a >= '0' && a <= '3' && enSecuencia(c)) marcarFlecha(c, a - '0');
}

// El invitado manda sus teclas cuando cambian (y cada cuarto de segundo)
void mandarTeclas() {
  int m = mascaraLocal();
  if (m != ultimaMascara || millis() - momentoMascara > 250) {
    enviarTeclasRed(m);
    ultimaMascara = m;
    momentoMascara = millis();
  }
}

// ---------------------------------------------------------------------------
// Avisos y efectos: se ven aquí y, si es el anfitrión, se mandan
// ---------------------------------------------------------------------------

void avisarA(Candidato c, String s) {
  if (c == null || c.bot != null) return;
  if (c == yo) avisar(s);
  else if (modoRed == ANFITRION) avisoRed(c.id, s);
}

void avisarTodos(String s) {
  avisar(s);
  if (modoRed == ANFITRION) avisoRed(-1, s);
}

void efectoPapel(float x, float y, color col) {
  float sx = pantallaX(x, y), sy = pantallaY(x, y) - 16;
  for (int k = 0; k < 14; k++) {
    particulas.add(new Particula(sx, sy, random(-40, 40), random(-70, -20), random(0.5, 0.9), k % 3 == 0 ? color(250, 246, 236) : col, 2));
  }
  sonarEn("volante", x, y);
  if (modoRed == ANFITRION) fxRed("papel " + x + " " + y + " " + col);
}

void efectoChispas(float x, float y, color col) {
  float sx = pantallaX(x, y), sy = pantallaY(x, y) - 20;
  for (int k = 0; k < 12; k++) {
    particulas.add(new Particula(sx, sy, random(-40, 40), random(-70, -20), random(0.5, 0.9),
      k % 3 == 0 ? color(250, 246, 236) : col, 2));
  }
  if (millis() - momentoAsegurado > 100) sonarEn("convencer", x, y);
  if (modoRed == ANFITRION) fxRed("chispas " + x + " " + y + " " + col);
}

void efectoVidrio(float x, float y) {
  float sx = pantallaX(x, y), sy = pantallaY(x, y) - 10;
  for (int k = 0; k < 10; k++) {
    particulas.add(new Particula(sx, sy, random(-50, 50), random(-60, -10), random(0.3, 0.6),
      k % 2 == 0 ? color(90, 170, 110) : color(200, 236, 210), 1.5));
  }
  sonarEn("vidrio", x, y);
  if (modoRed == ANFITRION) fxRed("vidrio " + x + " " + y);
}

int momentoAsegurado = -1000;

void efectoTexto(float x, float y, String texto, color col) {
  textosFlotantes.add(new TextoFlotante(x, y, texto, col));
  if (texto.equals("¡PUM!")) sonarEn("golpe", x, y);
  if (texto.equals("¡Asegurado!")) {
    sonarEn("asegurado", x, y);
    momentoAsegurado = millis();
  }
  if (modoRed == ANFITRION) fxRed("texto " + x + " " + y + " " + col + " " + texto.replace(' ', '_'));
}

// El invitado repite el efecto que le mandó el anfitrión
void aplicarFx(String linea) {
  String[] p = splitTokens(linea);
  if (p.length < 3) return;
  int antes = modoRed;
  modoRed = SOLO;   // para que no lo vuelva a mandar
  float x = float(p[1]), y = float(p[2]);
  if (p[0].equals("papel") && p.length >= 4) efectoPapel(x, y, int(p[3]));
  else if (p[0].equals("chispas") && p.length >= 4) efectoChispas(x, y, int(p[3]));
  else if (p[0].equals("vidrio")) efectoVidrio(x, y);
  else if (p[0].equals("texto") && p.length >= 5) efectoTexto(x, y, p[4].replace('_', ' '), int(p[3]));
  modoRed = antes;
}

// ---------------------------------------------------------------------------
// La foto del estado (anfitrión -> invitados)
// ---------------------------------------------------------------------------

String f2(float v) {
  return nf(v, 0, 2).replace(',', '.');
}

String estadoRed() {
  StringBuilder s = new StringBuilder();
  s.append(estadoRonda).append(' ').append(f2(relojRonda)).append(' ').append(evento).append('|');
  for (Candidato c : candidatos) {
    s.append(f2(c.x)).append(' ').append(f2(c.y)).append(' ').append(f2(c.dirX)).append(' ').append(f2(c.dirY)).append(' ')
      .append(c.moviendose ? 1 : 0).append(' ').append(c.corriendo ? 1 : 0).append(' ').append(f2(c.aturdido)).append(' ')
      .append(f2(c.progresoPegar)).append(' ').append(c.botellas).append(' ').append(c.ultimoLogro).append(';');
  }
  s.append('|');
  for (Ciudadano z : ciudadanos) {
    s.append(f2(z.x)).append(' ').append(f2(z.y)).append(' ').append(f2(z.dirX)).append(' ').append(f2(z.dirY)).append(' ')
      .append(z.moviendose ? 1 : 0).append(' ').append(z.dueno).append(' ').append(z.asegurado ? 1 : 0).append(' ').append(z.ocupadoPor).append(' ')
      .append(z.live ? 1 : (z.quieto ? 2 : 0)).append(';');
  }
  s.append('|');
  for (Carro c : carros) {
    s.append(f2(c.x)).append(' ').append(f2(c.y)).append(' ').append(f2(c.ang)).append(' ').append(c.variante).append(';');
  }
  s.append('|');
  for (Punto p : puntos) s.append(dueno(p.id)).append(' ');
  s.append('|');
  for (Botella b : botellasVolando) {
    s.append(f2(b.x)).append(' ').append(f2(b.y)).append(' ').append(f2(b.recorrido)).append(';');
  }
  s.append('|');
  for (Candidato c : candidatos) {
    java.util.ArrayDeque<Integer> cola = secuencias.get(c.id);
    Ciudadano z = secuenciaCon.get(c.id);
    if (cola == null || z == null) continue;
    s.append(c.id).append(' ').append(z.id).append(' ');
    for (int f : cola) s.append(f);
    s.append(';');
  }
  return s.toString();
}

// El invitado copia la foto. Las posiciones no saltan: se guardan como
// destino y cada cuadro se acercan (seguirFoto).
float[][] destinoCand = new float[4][2];
float[][] destinoCiud;

void aplicarEstado(String foto) {
  String[] partes = split(foto, '|');
  if (partes.length < 7) return;
  String[] g = splitTokens(partes[0]);
  int nuevoEstado = int(g[0]);
  relojRonda = float(g[1]);
  evento = int(g[2]);
  // candidatos
  String[] cs = splitTokens(partes[1], ";");
  for (int k = 0; k < cs.length && k < candidatos.size(); k++) {
    String[] v = splitTokens(cs[k]);
    if (v.length < 10) continue;
    Candidato c = candidatos.get(k);
    destinoCand[k][0] = float(v[0]);
    destinoCand[k][1] = float(v[1]);
    if (!fotoRecibida || dist(c.x, c.y, destinoCand[k][0], destinoCand[k][1]) > 3) {
      c.x = destinoCand[k][0];
      c.y = destinoCand[k][1];
    }
    c.dirX = float(v[2]);
    c.dirY = float(v[3]);
    c.moviendose = v[4].equals("1");
    c.corriendo = v[5].equals("1");
    c.aturdido = float(v[6]);
    c.progresoPegar = float(v[7]);
    c.botellas = int(v[8]);
    c.ultimoLogro = int(v[9]);
  }
  // gente
  String[] zs = splitTokens(partes[2], ";");
  // la lista del anfitrión manda (en la ronda de los lives cambia de tamaño)
  while (ciudadanos.size() > zs.length) ciudadanos.remove(ciudadanos.size() - 1);
  while (ciudadanos.size() < zs.length) {
    String[] v = splitTokens(zs[ciudadanos.size()]);
    ciudadanos.add(new Ciudadano(ciudadanos.size(), float(v[0]), float(v[1])));
  }
  if (destinoCiud == null || destinoCiud.length != ciudadanos.size()) destinoCiud = new float[ciudadanos.size()][2];
  for (int k = 0; k < zs.length && k < ciudadanos.size(); k++) {
    String[] v = splitTokens(zs[k]);
    if (v.length < 8) continue;
    Ciudadano z = ciudadanos.get(k);
    destinoCiud[k][0] = float(v[0]);
    destinoCiud[k][1] = float(v[1]);
    if (!fotoRecibida || dist(z.x, z.y, destinoCiud[k][0], destinoCiud[k][1]) > 3) {
      z.x = destinoCiud[k][0];
      z.y = destinoCiud[k][1];
    }
    z.dirX = float(v[2]);
    z.dirY = float(v[3]);
    z.moviendose = v[4].equals("1");
    z.dueno = int(v[5]);
    z.asegurado = v[6].equals("1");
    z.ocupadoPor = int(v[7]);
    if (v.length > 8) {
      z.live = v[8].equals("1");
      z.quieto = !v[8].equals("0");
    }
  }
  // carros (la lista del anfitrión manda)
  String[] ks = splitTokens(partes[3], ";");
  while (carros.size() > ks.length) carros.remove(carros.size() - 1);
  for (int k = 0; k < ks.length; k++) {
    String[] v = splitTokens(ks[k]);
    if (v.length < 4) continue;
    if (k >= carros.size()) carros.add(new Carro(float(v[0]), float(v[1]), float(v[2]), int(v[3])));
    Carro c = carros.get(k);
    c.ia = false;
    c.x = float(v[0]);
    c.y = float(v[1]);
    c.ang = float(v[2]);
    c.variante = int(v[3]);
  }
  // puntos
  String[] ps = splitTokens(partes[4]);
  duenoDePunto.clear();
  for (int k = 0; k < ps.length && k < puntos.size(); k++) {
    int d = int(ps[k]);
    if (d >= 0) duenoDePunto.put(k, d);
  }
  // botellas
  botellasVolando.clear();
  for (String b : splitTokens(partes[5], ";")) {
    String[] v = splitTokens(b);
    if (v.length < 3) continue;
    Botella bt = new Botella(yo, 1, 0);
    bt.x = float(v[0]);
    bt.y = float(v[1]);
    bt.recorrido = float(v[2]);
    botellasVolando.add(bt);
  }
  // secuencias de flechas
  secuencias.clear();
  secuenciaCon.clear();
  for (String q : splitTokens(partes[6], ";")) {
    String[] v = splitTokens(q);
    if (v.length < 3) continue;
    int id = int(v[0]), z = int(v[1]);
    java.util.ArrayDeque<Integer> cola = new java.util.ArrayDeque<Integer>();
    for (char f : v[2].toCharArray()) cola.add(f - '0');
    secuencias.put(id, cola);
    if (z >= 0 && z < ciudadanos.size()) secuenciaCon.put(id, ciudadanos.get(z));
  }
  // cambios de momento
  if (nuevoEstado != estadoRonda) {
    if (nuevoEstado == RONDA) arenaCerrada = true;
    if (nuevoEstado == FINAL) {
      arenaCerrada = false;
      resultado = listaOrdenada();
    }
    estadoRonda = nuevoEstado;
  }
  fotoRecibida = true;
  momentoFoto = millis();
}

// El invitado sin fotos (el anfitrión no ha llegado o se fue) puede volver
boolean sinFotos() {
  return modoRed == INVITADO && estadoRonda != FINAL && (!fotoRecibida || millis() - momentoFoto > 4000);
}

// Para empezar no se espera a quien todavía no ha entrado al parque
// (un invitado que sigue en su oficina): ese entra cuando llegue.
boolean estaEnElParque(Candidato c) {
  return c.bot != null || c == yo || millis() - ultimaEntrada[c.id] < 3000;
}

int faltanEnLaPlaza() {
  int n = 0;
  for (Candidato c : candidatos) if (!enLaPlaza(c) && estaEnElParque(c)) n++;
  return n;
}

// Cada cuadro, el invitado acerca todo a la última foto
void seguirFoto(float dt) {
  float f = min(1, dt * 12);
  for (int k = 0; k < candidatos.size(); k++) {
    Candidato c = candidatos.get(k);
    c.x += (destinoCand[k][0] - c.x) * f;
    c.y += (destinoCand[k][1] - c.y) * f;
  }
  if (destinoCiud != null) {
    for (int k = 0; k < ciudadanos.size() && k < destinoCiud.length; k++) {
      Ciudadano z = ciudadanos.get(k);
      z.x += (destinoCiud[k][0] - z.x) * f;
      z.y += (destinoCiud[k][1] - z.y) * f;
    }
  }
  for (int k = particulas.size() - 1; k >= 0; k--) {
    if (!particulas.get(k).actualizar(dt)) particulas.remove(k);
  }
  for (int k = textosFlotantes.size() - 1; k >= 0; k--) {
    if (!textosFlotantes.get(k).actualizar(dt)) textosFlotantes.remove(k);
  }
}

// En la prueba no hay red: estas funciones las pone el juego principal (Red.pde).


// ======================================================================
// Gente.pde
// ======================================================================
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


// ======================================================================
// Hud.pde
// ======================================================================
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


// ======================================================================
// Lives.pde
// ======================================================================
// La ronda de los lives.
//
// Pasó algo en la ciudad y en varios sitios se juntó gente alrededor de
// alguien que está transmitiendo en vivo en la red social. Los cúmulos salen
// al azar por todo el mapa (no solo en el parque). Para quedarse con uno hay
// que llegar, oprimir F (o E) junto al que transmite y marcar 6 flechas en
// orden. Cada live reclamado es un punto y ya nadie lo cambia. Gana el que
// tenga más cuando se reclaman todos o se acaba el tiempo. Aquí sirve mucho
// el carro: el mapa es grande.
//
// Se reutiliza lo de la ronda de la gente: el que transmite es un Ciudadano
// marcado como live, el público son ciudadanos quietos alrededor, y la
// secuencia es la misma cola de flechas (Gente.pde), solo que más larga.

final int NUM_LIVES = 6;
final int PUBLICO_POR_LIVE = 4;
final float TIEMPO_LIVES = 120;
final int LARGO_LIVE = 6;
final float ALCANCE_LIVE = 1.5;
final float SEPARACION_LIVES = 14;   // baldosas mínimas entre dos cúmulos

int largoSecuencia() {
  return evento == LIVES ? LARGO_LIVE : LARGO_SECUENCIA;
}

float alcanceDe() {
  return evento == LIVES ? ALCANCE_LIVE : ALCANCE_CONVENCER;
}

float tiempoRonda() {
  return evento == LIVES ? TIEMPO_LIVES : TIEMPO_RONDA;
}

// Un sitio bueno para un cúmulo: dentro de una manzana con espacio, lejos
// del parque, de la sede, del río y de los otros cúmulos, y al que se pueda
// llegar caminando desde la plaza.
boolean sitioParaLive(float x, float y, ArrayList<PVector> otros) {
  int z = zonaEn(x, y);
  if (z == 0 || z == 1 || z == 2 || z == 7 || z == 9) return false;
  if (dist(x, y, centroX, centroY) < 16) return false;
  if (!libre(x, y, 1.1)) return false;
  for (PVector o : otros) if (dist(x, y, o.x, o.y) < SEPARACION_LIVES) return false;
  return rutaBFS(centroX + radioPlaza + 1, centroY, x, y) != null;
}

// Pone los cúmulos. Los ciudadanos de los lives van al final de la lista,
// siempre en el mismo orden (el que transmite y su público), para que en red
// el invitado arme la misma lista y la foto del anfitrión los ubique.
void crearLives() {
  for (int k = ciudadanos.size() - 1; k >= 0; k--) {
    Ciudadano z = ciudadanos.get(k);
    if (z.live || z.quieto) ciudadanos.remove(k);
  }
  ArrayList<PVector> sitios = new ArrayList<PVector>();
  for (int intento = 0; intento < 3000 && sitios.size() < NUM_LIVES; intento++) {
    float x = random(3, baldosasX - 3), y = random(3, baldosasY - 3);
    if (sitioParaLive(x, y, sitios)) sitios.add(new PVector(x, y));
  }
  int id = ciudadanos.size();
  for (PVector s : sitios) {
    Ciudadano live = new Ciudadano(id++, s.x, s.y);
    live.live = true;
    live.quieto = true;
    ciudadanos.add(live);
    for (int k = 0; k < PUBLICO_POR_LIVE; k++) {
      float a = TWO_PI * k / PUBLICO_POR_LIVE + random(-0.3, 0.3);
      PVector p = puntoLibreCerca(s.x + cos(a) * 1.25, s.y + sin(a) * 1.25);
      Ciudadano z = new Ciudadano(id++, p.x, p.y);
      z.quieto = true;
      z.dirX = s.x - p.x;
      z.dirY = s.y - p.y;
      ciudadanos.add(z);
    }
  }
}

int livesDe(Candidato c) {
  int n = 0;
  for (Ciudadano z : ciudadanos) if (z.live && z.dueno == c.id) n++;
  return n;
}

int livesLibres() {
  int n = 0;
  for (Ciudadano z : ciudadanos) if (z.live && !z.asegurado) n++;
  return n;
}

int totalLives() {
  int n = 0;
  for (Ciudadano z : ciudadanos) if (z.live) n++;
  return n;
}

// El live libre más cercano al candidato (para la flecha y los bots)
Ciudadano liveMasCercano(Candidato c) {
  Ciudadano mejor = null;
  float md = 1e9;
  for (Ciudadano z : ciudadanos) {
    if (!z.live || z.asegurado) continue;
    float d = dist(c.x, c.y, z.x, z.y);
    if (d < md) {
      md = d;
      mejor = z;
    }
  }
  return mejor;
}

// Los bots: van al live libre que les sale más a cuenta (cerca y que otro
// bot no esté buscando) y marcan las flechas con su ritmo.
void botLives(Bot b, float dt) {
  Candidato c = b.c;
  if (c.aturdido > 0) {
    c.moviendose = false;
    return;
  }
  b.revisarTiro -= dt;
  if (b.revisarTiro <= 0) {
    b.revisarTiro = 0.5;
    b.intentarTiro();
  }
  if (enSecuencia(c)) {
    c.moviendose = false;
    b.ritmo -= dt;
    if (b.ritmo <= 0) {
      // van despacio a propósito: así el jugador alcanza a quitarles los lives
      b.ritmo = dificultad == FACIL ? random(1.2, 1.6) : random(0.8, 1.1);
      java.util.ArrayDeque<Integer> cola = secuencias.get(c.id);
      if (cola != null && !cola.isEmpty()) {
        int f = cola.peek();
        if (random(1) < (dificultad == FACIL ? 0.12 : 0.06)) f = (f + 1) % 4;
        marcarFlecha(c, f);
      }
    }
    return;
  }
  Ciudadano m = b.meta;
  if (m == null || !m.live || m.asegurado || (m.ocupadoPor >= 0 && m.ocupadoPor != c.id)) {
    float mejor = 1e9;
    m = null;
    for (Ciudadano z : ciudadanos) {
      if (!z.live || z.asegurado || (z.ocupadoPor >= 0 && z.ocupadoPor != c.id)) continue;
      float costo = dist(c.x, c.y, z.x, z.y) + random(0, 4);
      for (Candidato o : candidatos) if (o.bot != null && o != c && o.bot.meta == z) costo += 12;
      if (costo < mejor) {
        mejor = costo;
        m = z;
      }
    }
    b.meta = m;
    b.ruta = null;
  }
  if (m == null) {
    c.moviendose = false;
    return;
  }
  if (dist(c.x, c.y, m.x, m.y) > ALCANCE_LIVE - 0.3) {
    b.replan -= dt;
    if (b.ruta == null || b.replan <= 0) {
      b.replan = 3;
      b.irA(m.x, m.y);
    }
    b.seguirRuta(dt, false);   // caminan: el jugador puede ganarles en carro
    return;
  }
  c.moviendose = false;
  empezarSecuencia(c, m);
  b.ritmo = 1.2;   // se demoran un momento antes de la primera flecha
}

// Encima del que transmite: el letrero rojo de EN VIVO y el celular
void dibujarMarcaLive(Ciudadano z, float sx, float sy) {
  if (estadoRonda != RONDA && estadoRonda != FINAL) return;
  // el celular en la mano
  noStroke();
  fill(30, 28, 36);
  rect(sx + 3, sy - 19, 4, 6);
  fill(140, 200, 250);
  rect(sx + 3.6, sy - 18.4, 2.8, 3.6);
  if (z.asegurado) return;
  // el letrero, que titila
  float y = sy - 38 + sin(millis() / 260.0) * 1.2;
  fill(CAFE);
  rect(sx - 12, y - 1, 24, 9);
  fill(millis() % 1000 < 650 ? color(226, 52, 52) : color(170, 36, 36));
  rect(sx - 11, y, 22, 7);
  fill(255);
  ellipse(sx - 7.5, y + 3.5, 2.5, 2.5);
  textFont(fuenteNegrita, 6);
  textAlign(LEFT, CENTER);
  text("LIVE", sx - 5, y + 3);
}


// ======================================================================
// Ronda.pde
// ======================================================================
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


// ======================================================================
// SonidosMundo.pde
// ======================================================================

// Los efectos de sonido del mundo abierto: pasos, botellas, volantes, gente
// convencida, flechas, la cuenta regresiva y el silbato del final.
//
// Son WAV cortos de data/sfx_mundo/ (los genera herramientas/gen_sonidos.py,
// estilo 8 bits). Cada efecto se carga en tres copias (Clip) para que pueda
// sonar encima de sí mismo. Lo que pasa lejos del candidato suena más bajo.

final String[] SONIDOS_MUNDO = {"paso", "lanzar", "vidrio", "golpe", "volante", "convencer", "asegurado",
  "flecha_ok", "flecha_mal", "cuenta", "empieza", "fin", "puerta"};
final float[] VOLUMEN_SONIDO = {0.35, 0.7, 0.8, 0.9, 0.8, 0.8, 0.9, 0.6, 0.7, 0.7, 0.8, 0.8, 0.8};
HashMap<String, Clip[]> clipsMundo = new HashMap<String, Clip[]>();
HashMap<String, Integer> turnoClip = new HashMap<String, Integer>();
boolean haySonidoMundo = true;

void cargarSonidosMundo() {
  try {
    for (int k = 0; k < SONIDOS_MUNDO.length; k++) {
      java.io.File f = new java.io.File(dataPath("sfx_mundo/" + SONIDOS_MUNDO[k] + ".wav"));
      if (!f.exists()) continue;
      Clip[] copias = new Clip[3];
      for (int c = 0; c < 3; c++) {
        AudioInputStream ais = AudioSystem.getAudioInputStream(f);
        copias[c] = AudioSystem.getClip();
        copias[c].open(ais);
        ais.close();
        ponerVolumen(copias[c], VOLUMEN_SONIDO[k]);
      }
      clipsMundo.put(SONIDOS_MUNDO[k], copias);
      turnoClip.put(SONIDOS_MUNDO[k], 0);
    }
  } catch (Exception e) {
    haySonidoMundo = false;
    println("Mundo sin sonido: " + e.getMessage());
  }
}

void ponerVolumen(Clip c, float v) {
  if (!c.isControlSupported(FloatControl.Type.MASTER_GAIN)) return;
  FloatControl g = (FloatControl) c.getControl(FloatControl.Type.MASTER_GAIN);
  float db = 20 * (float) Math.log10(max(0.0001, v));
  g.setValue(constrain(db, g.getMinimum(), g.getMaximum()));
}

// Suena con su volumen normal
void sonar(String nombre) {
  sonarCon(nombre, 1);
}

// Suena más bajo si pasa lejos del candidato (y no suena si es muy lejos)
void sonarEn(String nombre, float x, float y) {
  if (yo == null) return;
  float d = dist(x, y, yo.x, yo.y);
  if (d > 22) return;
  sonarCon(nombre, 1 - d / 26);
}

void sonarCon(String nombre, float factor) {
  if (!haySonidoMundo) return;
  Clip[] copias = clipsMundo.get(nombre);
  if (copias == null) return;
  int k = turnoClip.get(nombre);
  turnoClip.put(nombre, (k + 1) % copias.length);
  Clip c = copias[k];
  c.stop();
  int i = java.util.Arrays.asList(SONIDOS_MUNDO).indexOf(nombre);
  ponerVolumen(c, VOLUMEN_SONIDO[i] * factor);
  c.setFramePosition(0);
  c.start();
}

// Lo que suena por el paso del tiempo: los pasos del candidato, la cuenta
// regresiva, la salida y el silbato. Se revisa en cada cuadro, igual en el
// anfitrión que en el invitado (que no simula: solo ve cambiar la foto).
int estadoSonado = -1;
int cuentaSonada = -1;
float relojPaso = 0;

void sonidosDelCuadro(float dt) {
  // pasos (no al manejar)
  if (yo != null && yo.moviendose && manejando == null) {
    relojPaso -= dt;
    if (relojPaso <= 0) {
      sonar("paso");
      relojPaso = yo.corriendo ? 0.24 : 0.36;
    }
  } else {
    relojPaso = 0;
  }
  if (estadoRonda == CUENTA) {
    int n = ceil(relojRonda);
    if (n != cuentaSonada && n > 0) sonar("cuenta");
    cuentaSonada = n;
  } else {
    cuentaSonada = -1;
  }
  if (estadoRonda != estadoSonado) {
    if (estadoRonda == RONDA && estadoSonado >= 0) sonar("empieza");
    if (estadoRonda == FINAL && estadoSonado == RONDA) sonar("fin");
    estadoSonado = estadoRonda;
  }
}


// ======================================================================
// Volantes.pde
// ======================================================================
// La ronda de volantes: los puntos para pegar, de quién es cada uno y las
// cuentas de la lista en vivo.
//
// Cada punto es una cartelera. Pegar es quedarse al lado y mantener E un
// momento; el punto pasa a ser de ese candidato aunque ya tuviera dueño.

final float TIEMPO_PEGAR = 0.8;     // segundos manteniendo E
final float ALCANCE_PEGAR = 1.45;   // baldosas desde la cartelera

class Punto {
  int id;
  float x, y;           // la cartelera, en baldosas
  char eje;
  float fx, fy;         // dónde se para quien pega
  float[] cara = new float[8];   // la cara del tablero en pixeles del dibujo

  Punto(int id, String[] p) {
    this.id = id;
    x = float(p[0]);
    y = float(p[1]);
    eje = p[2].charAt(0);
    for (int k = 0; k < 8; k++) cara[k] = float(p[5 + k]);
    PVector f = puntoLibreCerca(float(p[3]), float(p[4]));
    fx = f.x;
    fy = f.y;
  }
}

ArrayList<Punto> puntos = new ArrayList<Punto>();
// De quién es cada punto: id del punto -> id del candidato. Si no está, es libre.
HashMap<Integer, Integer> duenoDePunto = new HashMap<Integer, Integer>();

void cargarPuntos() {
  for (String l : loadStrings("mundo/puntos.txt")) {
    String[] p = splitTokens(l);
    if (p.length >= 13) puntos.add(new Punto(puntos.size(), p));
  }
}

int dueno(int punto) {
  Integer d = duenoDePunto.get(punto);
  return d == null ? -1 : d;
}

int volantesDe(Candidato c) {
  int n = 0;
  for (int d : duenoDePunto.values()) if (d == c.id) n++;
  return n;
}

// El punto al que alcanza el candidato (el más cercano), o -1
int puntoAlAlcance(Candidato c) {
  int mejor = -1;
  float md = ALCANCE_PEGAR;
  for (Punto p : puntos) {
    float d = dist(c.x, c.y, p.x, p.y);
    if (d < md) {
      md = d;
      mejor = p.id;
    }
  }
  return mejor;
}

// Se llama cada cuadro: si el candidato está pegando, avanza; si suelta,
// se aleja o le pegan un botellazo, vuelve a cero.
void actualizarPegado(Candidato c, float dt, boolean manteniendo) {
  int p = puntoAlAlcance(c);
  if (!manteniendo || c.aturdido > 0 || p < 0 || dueno(p) == c.id || c.moviendose) {
    c.progresoPegar = 0;
    c.puntoPegando = -1;
    return;
  }
  if (p != c.puntoPegando) {
    c.puntoPegando = p;
    c.progresoPegar = 0;
  }
  Punto pt = puntos.get(p);
  c.mirarHacia(pt.x, pt.y);
  c.progresoPegar += dt / TIEMPO_PEGAR;
  if (c.progresoPegar >= 1) {
    pegar(c, pt);
    c.progresoPegar = 0;
    c.puntoPegando = -1;
  }
}

void pegar(Candidato c, Punto p) {
  int antes = dueno(p.id);
  duenoDePunto.put(p.id, c.id);
  c.ultimoLogro = millis();
  // papelitos del color del candidato
  efectoPapel(p.x, p.y, c.col);
  efectoTexto(p.x, p.y, "+1", c.col);
  if (antes >= 0 && antes != c.id) {
    avisarA(c, "Le quitaste el punto a " + candidatos.get(antes).nombre);
    avisarA(candidatos.get(antes), c.nombre + " tapó tu volante");
  }
}

// Puntos de cada candidato en el evento que se esté jugando
int puntajeDe(Candidato c) {
  if (evento == LIVES) return livesDe(c);
  return evento == VOLANTES ? volantesDe(c) : genteDe(c);
}

// Lista en vivo: candidatos de más a menos volantes; si empatan, va primero
// el que llegó antes a esa cuenta. Pocos elementos: ordenamiento por inserción.
ArrayList<Candidato> listaOrdenada() {
  ArrayList<Candidato> l = new ArrayList<Candidato>(candidatos);
  for (int a = 1; a < l.size(); a++) {
    Candidato v = l.get(a);
    int b = a - 1;
    while (b >= 0 && vaDespues(l.get(b), v)) {
      l.set(b + 1, l.get(b));
      b--;
    }
    l.set(b + 1, v);
  }
  return l;
}

boolean vaDespues(Candidato a, Candidato b) {
  int va = puntajeDe(a), vb = puntajeDe(b);
  if (va != vb) return va < vb;
  if (va == 0) return a.id > b.id;
  return a.ultimoLogro > b.ultimoLogro;
}

Candidato lider() {
  Candidato l = listaOrdenada().get(0);
  return puntajeDe(l) > 0 ? l : null;
}

// ---------------------------------------------------------------------------
// Dibujo de los puntos
// ---------------------------------------------------------------------------

// Anillo en el piso de cada punto: punteado si está libre, del color claro
// del dueño si ya tiene volante.
void dibujarAnillosPuntos() {
  if (evento != VOLANTES) return;
  for (Punto p : puntos) {
    float sx = pantallaX(p.x, p.y), sy = pantallaY(p.x, p.y);
    int d = dueno(p.id);
    float w = 2 * 0.95 * T * 1.414, h = w / 2;
    if (d >= 0) {
      Candidato c = candidatos.get(d);
      noStroke();
      fill(c.claro, 110);
      ellipse(sx, sy, w, h);
      noFill();
      stroke(c.col);
      strokeWeight(1.3);
      ellipse(sx, sy, w, h);
    } else {
      stroke(250, 214, 80, 220);
      strokeWeight(1.3);
      noFill();
      for (int k = 0; k < 16; k += 2) {
        float a0 = TWO_PI * k / 16, a1 = TWO_PI * (k + 1) / 16;
        line(sx + cos(a0) * w / 2, sy + sin(a0) * h / 2, sx + cos(a1) * w / 2, sy + sin(a1) * h / 2);
      }
    }
    // el punto al que alcanza el jugador brilla
    if (puntoAlAlcance(yo) == p.id && d != yo.id && rondaActiva()) {
      noFill();
      stroke(255, 255, 255, 150 + 100 * sin(millis() / 120.0));
      strokeWeight(1);
      ellipse(sx, sy, w + 4, h + 2);
    }
  }
  noStroke();
}

// El volante encima del tablero (se llama justo después de dibujar la cartelera)
void dibujarVolante(int punto) {
  int d = dueno(punto);
  if (d < 0) return;
  Candidato c = candidatos.get(d);
  float[] q = puntos.get(punto).cara;
  float cx = (q[0] + q[2] + q[4] + q[6]) / 4, cy = (q[1] + q[3] + q[5] + q[7]) / 4;
  noStroke();
  fill(c.col);
  beginShape();
  for (int k = 0; k < 4; k++) vertex(lerp(q[2 * k], cx, 0.08), lerp(q[2 * k + 1], cy, 0.08));
  endShape(CLOSE);
  // franja clara arriba, como la foto del candidato en el volante
  fill(c.claro);
  beginShape();
  vertex(lerp(q[6], q[0], 0.2) * 0.75 + cx * 0.25, lerp(q[7], q[1], 0.2) * 0.75 + cy * 0.25);
  vertex(lerp(q[4], q[2], 0.2) * 0.75 + cx * 0.25, lerp(q[5], q[3], 0.2) * 0.75 + cy * 0.25);
  vertex(lerp(q[4], q[2], 0.5) * 0.75 + cx * 0.25, lerp(q[5], q[3], 0.5) * 0.75 + cy * 0.25);
  vertex(lerp(q[6], q[0], 0.5) * 0.75 + cx * 0.25, lerp(q[7], q[1], 0.5) * 0.75 + cy * 0.25);
  endShape(CLOSE);
}

}
