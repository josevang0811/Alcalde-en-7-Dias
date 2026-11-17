// Consola del cuarto de seguridad (las pantallas de las camaras). Desde ahi:
//   1. Apagar las camaras 30 s (despues hay que esperar a que se enfrien).
//   2. Borrar las grabaciones: la alarma baja un nivel (una vez por mision).
//   3. Buscar en las pantallas: marca 30 s donde estan las tarjetas y el botin.
//   4. Vigilar: pone las camaras en bucle mientras el jugador se quede en la
//      consola. Sirve en cooperativo: uno vigila y el otro avanza.
// Mientras se usa, el jugador no se mueve. W/S o flechas eligen, E/Enter confirma.

final float TIEMPO_CAMARAS_APAGADAS = 30;
final float ENFRIAR_CAMARAS = 45;
final float TIEMPO_MOSTRAR = 30;
String[] OPCIONES_CONSOLA = {"Apagar las cámaras", "Borrar las grabaciones", "Buscar en las pantallas", "Vigilar: cámaras en bucle", "Salir"};
boolean camarasEnBucle;    // alguien se quedo en la consola vigilando

int opcionConsola;
float camarasApagadas;     // segundos que les quedan apagadas
float enfriarCamaras;      // segundos para poder volver a apagarlas
boolean grabacionesBorradas;
float mostrarObjetos;      // segundos que quedan marcados tarjetas y botin

void abrirConsola(Jugador j) {
  abrirVentana(j, 5);
  opcionConsola = 0;
}

boolean usandoConsola(Jugador j) {
  return ventana == 5 && quienLee == j;
}

void moverOpcionConsola(int d) {
  if (camarasEnBucle) return;
  opcionConsola = (opcionConsola + d + OPCIONES_CONSOLA.length) % OPCIONES_CONSOLA.length;
}

// Por que una opcion no se puede usar ahora ("" si se puede)
String bloqueoOpcion(int k) {
  if (camarasEnBucle && k != 3) return "";
  if (k == 3 && camarasEnBucle) return "vigilando";
  if (k == 0 && camarasApagadas > 0) return "apagadas " + ceil(camarasApagadas) + " s";
  if (k == 0 && enfriarCamaras > 0) return "espera " + ceil(enfriarCamaras) + " s";
  if (k == 1 && grabacionesBorradas) return "ya borradas";
  if (k == 1 && nivelAlarma == 0) return "no hay nada que borrar";
  return "";
}

void elegirOpcionConsola() {
  int k = opcionConsola;
  if (camarasEnBucle) {
    // estaba vigilando: E deja la consola
    camarasEnBucle = false;
    ventana = 0;
    avisar("Dejaste la consola: las cámaras vuelven a grabar");
    return;
  }
  if (k == 4) {
    ventana = 0;
    return;
  }
  if (k == 3) {
    camarasEnBucle = true;
    avisar("Cámaras en bucle mientras te quedes aquí. Tu compañero puede avanzar");
    return;
  }
  if (!bloqueoOpcion(k).equals("")) return;
  if (k == 0) {
    camarasApagadas = TIEMPO_CAMARAS_APAGADAS;
    for (CamaraSeguridad c : camaras) c.sospecha = 0;
    avisar("Cámaras apagadas por 30 segundos");
  } else if (k == 1) {
    grabacionesBorradas = true;
    bajarAlarma();
    avisar("Grabaciones borradas: la alarma bajó un nivel");
  } else if (k == 2) {
    mostrarObjetos = TIEMPO_MOSTRAR;
    avisar("Marcadas las tarjetas y el botín por 30 segundos");
  }
  ventana = 0;
}

void actualizarSeguridad(float dt) {
  if (camarasApagadas > 0) {
    camarasApagadas -= dt;
    if (camarasApagadas <= 0) {
      enfriarCamaras = ENFRIAR_CAMARAS;
      avisar("Las cámaras volvieron a encenderse");
    }
  } else {
    enfriarCamaras = max(0, enfriarCamaras - dt);
  }
  mostrarObjetos = max(0, mostrarObjetos - dt);
  if (camarasEnBucle && ventana != 5) camarasEnBucle = false;
}

boolean camarasEncendidas() {
  return camarasApagadas <= 0 && !camarasEnBucle;
}

void dibujarConsola() {
  float e = escala;
  float w = min(460 * e, width - 40 * e);
  float h = 290 * e;
  float x = width / 2 - w / 2;
  float y = height / 2 - h / 2 - 20 * e;
  noStroke();
  fill(0, 120);
  rect(0, 0, width, height);
  stroke(NEON_CIAN);
  strokeWeight(1.5 * e);
  fill(11, 14, 26, 245);
  rect(x, y, w, h, 4 * e);
  textFont(letraMedia);
  textAlign(LEFT, TOP);
  fill(NEON_CIAN);
  text("SEGURIDAD · consola de cámaras", x + 18 * e, y + 14 * e);
  textFont(letraChica);
  for (int k = 0; k < OPCIONES_CONSOLA.length; k++) {
    float oy = y + 52 * e + k * 38 * e;
    boolean sel = k == opcionConsola;
    String bloqueo = bloqueoOpcion(k);
    if (sel) {
      noStroke();
      fill(25, 227, 227, 40);
      rect(x + 12 * e, oy - 4 * e, w - 24 * e, 30 * e, 3 * e);
    }
    fill(bloqueo.equals("") ? color(242, 242, 233) : color(120, 128, 150));
    textAlign(LEFT, TOP);
    text((sel ? "> " : "  ") + OPCIONES_CONSOLA[k], x + 20 * e, oy + 4 * e);
    if (!bloqueo.equals("")) {
      fill(COLOR_AMBAR);
      textAlign(RIGHT, TOP);
      text(bloqueo, x + w - 22 * e, oy + 4 * e);
    }
  }
  textAlign(LEFT, BOTTOM);
  fill(150, 160, 190);
  String teclas = quienLee != null && quienLee.numero == 2 ? "Flechas elegir · Enter confirmar" : "W/S elegir · E confirmar";
  if (camarasEnBucle) teclas = "Vigilando: las cámaras no te ven ni a tu compañero · " + (quienLee != null && quienLee.numero == 2 ? "Enter" : "E") + " para salir";
  text(teclas, x + 18 * e, y + h - 12 * e);
}

// Marcas de tarjetas y botin en todo el mapa (opcion 3 de la consola)
void dibujarObjetosMarcados() {
  if (mostrarObjetos <= 0) return;
  for (int i = 0; i < mapa.ancho; i++) {
    for (int j = 0; j < mapa.alto; j++) {
      char c = mapa.celdas[i][j];
      if ("rbynPhl".indexOf(c) < 0) continue;
      float sx = pantallaX(i + 0.5, j + 0.5);
      float sy = pantallaY(i + 0.5, j + 0.5);
      color col = "rby".indexOf(c) >= 0 ? NEON_CIAN : NEON_VERDE;
      manchaLuz(sx, sy - 6 * pixel, 1.2, col, 120 + 60 * sin(millis() / 200.0), false);
      marcador(i + 0.5, j + 0.5, 24, col);
    }
  }
}
