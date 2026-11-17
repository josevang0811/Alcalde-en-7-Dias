import javax.sound.sampled.*;

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
