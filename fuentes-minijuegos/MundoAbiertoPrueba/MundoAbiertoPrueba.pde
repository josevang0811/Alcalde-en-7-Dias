// MundoAbiertoPrueba — la ciudad del mundo abierto de Alcalde Digital y sus
// eventos en el parque: la ronda de volantes y la de convencer a la gente
// (en la prueba se escoge con 1 o 2 antes de la ronda).
//
// El candidato sale de su sede de campaña y tiene que llegar al centro del
// parque, donde se reúnen los otros tres candidatos (manejados por el
// computador). Cuando están los cuatro empieza la ronda: 60 segundos para
// pegar volantes en las carteleras del parque y sus calles. Pegar encima del
// volante de otro le quita el punto. Cada uno tiene 3 botellas: al que le
// pegan se queda quieto 2 segundos. Al final, el que más puntos tenga gana
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

import processing.opengl.*;

int pixel;                  // cuántas veces se agranda el pixel art (2 en 720p, 3 en 1080p)
Candidato yo;
float camX, camY;           // centro de la cámara, en pixeles del dibujo
int ultimoMillis;
boolean verMapa = false;
boolean modoPrueba = true;  // en el juego principal no hay selector de evento
boolean verChoques = false;
PFont fuente, fuenteNegrita;

void setup() {
  fullScreen(P2D);
  noSmooth();
  // En OpenGL hay que pedir aparte que las imágenes se agranden sin suavizar
  if (g instanceof PGraphicsOpenGL) ((PGraphicsOpenGL) g).textureSampling(2);
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

void draw() {
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

  background(150, 196, 226);
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

void keyPressed() {
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
    if (k == 'q' && rondaActiva()) lanzarDe(yo);
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

void keyReleased() {
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
// <solo-sketch>
void volverALaOficina() {
  reiniciarTodo();
}
// </solo-sketch>
