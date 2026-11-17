// Puerta del cuarto del servidor: teclado con un codigo de 4 digitos que
// cambia en cada mision. Los dos primeros estan en una nota del archivo y
// los dos ultimos se escuchan en una conversacion. Se puede intentar sin
// saberlo, pero con 3 codigos malos salta la alarma y el teclado se bloquea.
// Se marca con las teclas de numeros; Borrar corrige; E/Enter cierra.

final int INTENTOS_TECLADO = 3;
final float BLOQUEO_TECLADO = 20;

String codigoServidor = "0000";
boolean[] digitoConocido = new boolean[4];
String marcado = "";
int intentosMalos;
float tecladoBloqueado;
int[] puertaTeclado;          // la puerta que se esta abriendo
float mensajeTeclado;         // segundos que se muestra "incorrecto"

void prepararCodigo() {
  codigoServidor = "";
  for (int k = 0; k < 4; k++) codigoServidor += int(random(10));
  digitoConocido = new boolean[4];
  marcado = "";
  intentosMalos = 0;
  tecladoBloqueado = 0;
  mensajeTeclado = 0;
}

void conocerDigitos(int a, int b, String mensaje) {
  boolean nuevo = !digitoConocido[a] || !digitoConocido[b];
  digitoConocido[a] = true;
  digitoConocido[b] = true;
  boolean todos = digitoConocido[0] && digitoConocido[1] && digitoConocido[2] && digitoConocido[3];
  tarjetas[4] = todos;   // para el grafo de cuartos: ya se puede entrar
  if (nuevo) avisar(mensaje + ": " + codigoConocido() + (todos ? ". ¡Ya tienes el código completo!" : ""));
}

// El codigo con lo que se sabe y "_" en lo que falta
String codigoConocido() {
  String s = "";
  for (int k = 0; k < 4; k++) s += digitoConocido[k] ? "" + codigoServidor.charAt(k) : "_";
  return s;
}

void abrirTeclado(Jugador j, int[] puerta) {
  if (tecladoBloqueado > 0) {
    avisar("El teclado está bloqueado " + ceil(tecladoBloqueado) + " s");
    return;
  }
  puertaTeclado = puerta;
  marcado = "";
  abrirVentana(j, 6);
}

boolean usandoTeclado(Jugador j) {
  return ventana == 6 && quienLee == j;
}

void teclaTeclado(char c) {
  if (c == BACKSPACE) {
    if (marcado.length() > 0) marcado = marcado.substring(0, marcado.length() - 1);
    return;
  }
  if (c < '0' || c > '9' || marcado.length() >= 4) return;
  marcado += c;
  sonar("tecla");
  if (marcado.length() < 4) return;
  if (marcado.equals(codigoServidor)) {
    mapa.abrirPuerta(puertaTeclado[0], puertaTeclado[1]);
    conocerDigitos(0, 1, "");
    conocerDigitos(2, 3, "");
    ventana = 0;
    avisar("Código correcto: la puerta del servidor se abrió");
    sonar("codigo_ok");
    sonar("puerta");
    return;
  }
  intentosMalos++;
  sonar("codigo_mal");
  sacudir(3);
  mensajeTeclado = 1.2;
  if (intentosMalos >= INTENTOS_TECLADO) {
    intentosMalos = 0;
    tecladoBloqueado = BLOQUEO_TECLADO;
    ventana = 0;
    subirAlarma("Tres códigos malos: saltó la alarma del teclado");
    hacerRuido(puertaTeclado[0] + 0.5, puertaTeclado[1] + 0.5, 6);
  }
}

void actualizarTeclado(float dt) {
  tecladoBloqueado = max(0, tecladoBloqueado - dt);
  mensajeTeclado = max(0, mensajeTeclado - dt);
  if (mensajeTeclado <= 0 && marcado.length() == 4) marcado = "";
}

void dibujarTeclado() {
  float e = escala;
  float w = 330 * e;
  float h = 316 * e;
  float x = width / 2 - w / 2;
  float y = height / 2 - h / 2 - 20 * e;
  noStroke();
  fill(0, 120);
  rect(0, 0, width, height);
  stroke(NEON_CIAN);
  strokeWeight(1.5 * e);
  fill(11, 14, 26, 245);
  rect(x, y, w, h, 6 * e);
  textFont(letraChica);
  textAlign(CENTER, TOP);
  fill(NEON_CIAN);
  text("CUARTO DEL SERVIDOR", x + w / 2, y + 12 * e);
  // pantalla con lo marcado
  boolean malo = mensajeTeclado > 0;
  fill(malo ? color(90, 20, 30) : color(8, 30, 30));
  stroke(malo ? COLOR_RIVAL : color(25, 227, 227, 120));
  rect(x + 30 * e, y + 34 * e, w - 60 * e, 46 * e, 3 * e);
  textFont(letraGrande);
  textAlign(CENTER, CENTER);
  fill(malo ? COLOR_RIVAL : NEON_VERDE);
  String pantalla = malo ? "ERROR" : "";
  if (!malo) {
    for (int k = 0; k < 4; k++) pantalla += (k < marcado.length() ? marcado.charAt(k) : '·') + (k < 3 ? " " : "");
  }
  text(pantalla, x + w / 2, y + 56 * e);
  // teclas (solo dibujo: se marca con el teclado de verdad)
  textFont(letraMedia);
  String[] filas = {"1 2 3", "4 5 6", "7 8 9", "  0  "};
  for (int f = 0; f < 4; f++) {
    for (int c = 0; c < 3; c++) {
      char d = filas[f].charAt(c * 2);
      if (d == ' ') continue;
      float bx = x + w / 2 - 66 * e + c * 46 * e;
      float by = y + 94 * e + f * 34 * e;
      noStroke();
      fill(30, 38, 62);
      rect(bx, by, 40 * e, 28 * e, 3 * e);
      fill(220);
      text(d, bx + 20 * e, by + 13 * e);
    }
  }
  textFont(letraChica);
  textAlign(LEFT, BOTTOM);
  fill(150, 160, 190);
  text("Sabes: " + codigoConocido(), x + 14 * e, y + h - 26 * e);
  textAlign(RIGHT, BOTTOM);
  text("Intentos malos: " + intentosMalos + " de " + INTENTOS_TECLADO, x + w - 14 * e, y + h - 26 * e);
  textAlign(CENTER, BOTTOM);
  fill(110, 120, 150);
  text("Marca con los números · E/Enter para salir", x + w / 2, y + h - 8 * e);
}
