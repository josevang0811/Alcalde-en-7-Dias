// Llamada del inicio: antes del reconocimiento suena el telefono y Valeria le
// cuenta al candidato que Titulares Ya esta regando un bulo y que esta noche
// tiene que entrar a borrarlo. La llamada tambien la escribe el modelo con los
// datos de la campana (bulo, barrio, apoyo); se pide apenas se elige el rol,
// asi que mientras suena el telefono ya casi siempre esta lista.
// E o Espacio pasa a la siguiente frase; Enter cuelga.
// Solo suena la primera vez que se juega (al reiniciar ya no).

final float TIMBRE_MAXIMO = 8;   // si no llega a tiempo, se usa el guion de respaldo

String[] lineasLlamada;
Clip[] vocesLlamada;
float[] segundosLlamada;
volatile boolean llamadaLista;
volatile String[] lineasRecibidas;
volatile Clip[] vocesRecibidas;
boolean llamadaPedida, llamadaHecha, contestada;
int lineaLlamada;
float tiempoLlamada, tiempoLinea, proximoTimbre;

String[] guionRespaldo() {
  return new String[] {
    "Candidato, soy Valeria. Perdón por la hora, pero esto no puede esperar.",
    "Titulares Ya está regando un bulo sobre ti: " + buloCampana + ".",
    "En " + barrioCampana + " tienes " + apoyoCampana + " % de apoyo y mañana lo podemos perder.",
    "Esta noche entras a su sede, copias el servidor con las pruebas y sales sin que te vean.",
    "En el aseo hay uniformes de conserje: con uno puesto casi nadie te reconoce.",
    "Yo te guío por el auricular. Antes de entrar, estudia bien el plano."
  };
}

// Se llama al elegir 1 o 2 jugadores: pide la llamada de una vez
void prepararLlamada() {
  if (llamadaPedida || llamadaHecha || !valeriaActiva) return;
  llamadaPedida = true;
  llamadaLista = false;
  String usuario = null;
  if (valeriaConIA()) {
    usuario = "Es de madrugada y llamas por teléfono al candidato para ponerlo al tanto.\n" +
      "Datos:\n" +
      "- El bulo que Titulares Ya está regando contra él: " + buloCampana + ".\n" +
      "- Barrio donde hace campaña: " + barrioCampana + ", con " + apoyoCampana + " % de apoyo.\n" +
      "- La misión: entrar esta noche a la sede de Titulares Ya, copiar el servidor donde guardan los bulos " +
      "y salir sin que lo vean. Antes de entrar va a estudiar el plano de la sede.\n" +
      (numJugadores == 2 ? "- Esta vez van dos: el candidato y alguien de su equipo.\n" : "") +
      "Escribe lo que dices en la llamada: 4 o 5 frases, una por renglón, de máximo 20 palabras cada una. " +
      "Empieza saludándolo y termina diciendo que lo vas a guiar por el auricular. No numeres los renglones.";
  }
  Thread h = new Thread(new PedidoLlamada(usuario, guionRespaldo()));
  h.setDaemon(true);
  h.start();
}

class PedidoLlamada implements Runnable {
  String usuario;
  String[] respaldoL;

  PedidoLlamada(String usuario, String[] respaldoL) {
    this.usuario = usuario;
    this.respaldoL = respaldoL;
  }

  public void run() {
    String[] lineas = null;
    long t0 = System.currentTimeMillis();
    if (usuario != null) {
      try {
        String t = pedirAlModelo(PERSONA_VALERIA + "\nAhora es una llamada por teléfono: puedes decir varias frases, como se te pide.", usuario, 400);
        StringList ls = new StringList();
        for (String l : split(t, '\n')) {
          l = limpiarFrase(l);
          while (l.length() > 0 && (l.charAt(0) == '-' || Character.isDigit(l.charAt(0)) || l.charAt(0) == '.')) l = trim(l.substring(1));
          if (l.length() > 0) ls.append(l);
        }
        if (ls.size() >= 3) lineas = ls.array();
        fallosSeguidos = 0;
      } catch (Exception e) {
        fallosSeguidos++;
        println("Valeria (llamada): " + e.getMessage());
      }
    }
    if (lineas == null) lineas = respaldoL;
    Clip[] voces = new Clip[lineas.length];
    if (valeriaConVoz()) {
      for (int k = 0; k < lineas.length; k++) {
        try {
          voces[k] = vozDeAzure(lineas[k]);
        } catch (Exception e) {
          println("Valeria (voz de la llamada): " + e.getMessage());
          break;
        }
      }
    }
    println("Valeria: llamada lista en " + (System.currentTimeMillis() - t0) + " ms");
    vocesRecibidas = voces;
    lineasRecibidas = lineas;
    llamadaLista = true;
  }
}

void empezarLlamada() {
  estado = LLAMADA;
  contestada = false;
  tiempoLlamada = 0;
  proximoTimbre = 0.3;
  if (!llamadaPedida) prepararLlamada();
  if (musica != null) musica.atenuar = 0.35;
}

void actualizarLlamada(float dt) {
  tiempoLlamada += dt;
  if (!contestada) {
    proximoTimbre -= dt;
    if (proximoTimbre <= 0) {
      sonar("telefono");
      proximoTimbre = 2.2;
    }
    if ((llamadaLista && tiempoLlamada > 2.2) || tiempoLlamada > TIMBRE_MAXIMO) contestar();
    return;
  }
  tiempoLinea += dt;
  if (tiempoLinea > segundosLlamada[lineaLlamada] + 0.6) siguienteLineaLlamada();
}

void contestar() {
  contestada = true;
  tiempoLlamada = 0;
  if (llamadaLista) {
    lineasLlamada = lineasRecibidas;
    vocesLlamada = vocesRecibidas;
  } else {
    // no llego a tiempo: guion de respaldo y sin voz
    lineasLlamada = guionRespaldo();
    vocesLlamada = new Clip[lineasLlamada.length];
  }
  segundosLlamada = new float[lineasLlamada.length];
  for (int k = 0; k < lineasLlamada.length; k++) {
    Clip c = vocesLlamada[k];
    segundosLlamada[k] = c != null ? c.getMicrosecondLength() / 1e6 : max(2.8, lineasLlamada[k].length() / 15.0);
  }
  sonar("auricular");
  lineaLlamada = -1;
  siguienteLineaLlamada();
}

void siguienteLineaLlamada() {
  if (!contestada) {
    contestar();
    return;
  }
  if (lineaLlamada >= 0 && vocesLlamada[lineaLlamada] != null) vocesLlamada[lineaLlamada].stop();
  lineaLlamada++;
  tiempoLinea = 0;
  if (lineaLlamada >= lineasLlamada.length) {
    colgar();
    return;
  }
  if (vocesLlamada[lineaLlamada] != null) {
    vocesLlamada[lineaLlamada].setFramePosition(0);
    vocesLlamada[lineaLlamada].start();
  }
}

void colgar() {
  if (vocesLlamada != null) for (Clip c : vocesLlamada) if (c != null) c.stop();
  llamadaHecha = true;
  sonar("auricular");
  if (musica != null) musica.atenuar = 1;
  irAlReconocimiento();
}

void dibujarLlamada() {
  noStroke();
  fill(COLOR_FONDO, 238);
  rect(0, 0, width, height);
  PGraphics g = capaHud;
  g.beginDraw();
  g.clear();
  g.textAlign(LEFT, TOP);
  int an = g.width, al = g.height;
  int x0 = an / 2 - 170, y0 = al / 2 - 62, x1 = an / 2 + 170, y1 = al / 2 + 62;
  marcoPixel(g, x0, y0, x1, y1, COLOR_VALERIA);
  // retrato al doble
  g.noStroke();
  g.fill(40, 30, 64);
  g.rect(x0 + 10, y0 + 12, 44, 44);
  g.image(caraValeria, x0 + 12, y0 + 14, 40, 40);
  textoPixel(g, "VALERIA", x0 + 64, y0 + 10, COLOR_VALERIA, pixel12);
  textoPixel(g, "Estrategia digital de la campaña", x0 + 64, y0 + 25, color(160, 168, 190), pixel8);
  g.textAlign(RIGHT, TOP);
  if (!contestada) {
    boolean prende = (millis() / 300) % 2 == 0;
    textoPixel(g, "LLAMADA ENTRANTE", x1 - 10, y0 + 12, prende ? NEON_VERDE : color(30, 110, 66), pixel8);
  } else {
    int s = floor(tiempoLlamada);
    textoPixel(g, "EN LLAMADA " + s / 60 + ":" + nf(s % 60, 2), x1 - 10, y0 + 12, NEON_VERDE, pixel8);
  }
  g.textAlign(LEFT, TOP);
  if (!contestada) {
    // ondas del timbre
    int p = (millis() / 200) % 4;
    for (int k = 0; k < p; k++) {
      g.noFill();
      g.stroke(NEON_VERDE);
      g.rect(an / 2 - 8 - k * 6, y0 + 74 - k * 6, 16 + k * 12, 16 + k * 12);
    }
    g.noStroke();
    g.fill(NEON_VERDE);
    g.rect(an / 2 - 4, y0 + 78, 8, 8);
    textoPixel(g, "E contestar", x0 + 12, y1 - 14, color(110, 118, 145), pixel8);
  } else if (lineaLlamada >= 0 && lineaLlamada < lineasLlamada.length) {
    String t = lineasLlamada[lineaLlamada];
    int letras = t.length();
    float dur = segundosLlamada[lineaLlamada];
    letras = vocesLlamada[lineaLlamada] != null ? ceil(letras * constrain(tiempoLinea / max(0.1, dur * 0.9), 0, 1)) : min(letras, ceil(tiempoLinea * 32));
    g.textFont(pixel10);
    g.fill(242, 242, 233);
    g.text(t.substring(0, letras), x0 + 64, y0 + 42, x1 - x0 - 76, 50);
    textoPixel(g, (lineaLlamada + 1) + "/" + lineasLlamada.length + "   E siguiente · Enter colgar", x0 + 12, y1 - 14, color(110, 118, 145), pixel8);
  }
  g.endDraw();
  image(g, 0, 0, g.width * pixel, g.height * pixel);
}
