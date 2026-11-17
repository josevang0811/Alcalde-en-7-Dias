// Acciones a dos (cooperativo).
// Puerta pesada: la puerta de carga del parqueadero tambien se puede abrir
// sin la tarjeta roja si los dos jugadores la empujan a la vez (mantener usar
// 2,5 s). Hace ruido. La otra accion a dos esta en la consola de seguridad:
// uno se queda vigilando con las camaras en bucle mientras el otro avanza.

final int PESADA_I = 30, PESADA_J = 21;
final float TIEMPO_EMPUJAR = 2.5;
float progresoEmpujar;

boolean puertaPesadaCerrada() {
  return mapa.esPuertaCerrada(PESADA_I, PESADA_J);
}

boolean juntoAPuertaPesada(Jugador j) {
  return dist(j.x, j.y, PESADA_I + 0.5, PESADA_J + 0.5) < 1.7;
}

void actualizarEquipo(float dt) {
  if (jugadores.size() < 2 || !puertaPesadaCerrada()) {
    progresoEmpujar = 0;
    return;
  }
  boolean empujan = true;
  for (Jugador j : jugadores) {
    if (j.atrapado || !juntoAPuertaPesada(j) || !j.usandoMantenido()) empujan = false;
  }
  if (empujan) {
    progresoEmpujar += dt / TIEMPO_EMPUJAR;
    if (progresoEmpujar >= 1) {
      mapa.abrirPuerta(PESADA_I, PESADA_J);
      sonar("empujar");
      sacudir(5);
      hacerRuido(PESADA_I + 0.5, PESADA_J + 0.5, 3.5);
      avisar("Entre los dos forzaron la puerta de carga (hizo ruido)");
      progresoEmpujar = 0;
    }
  } else {
    progresoEmpujar = max(0, progresoEmpujar - dt * 0.5);
  }
}

void dibujarEquipo() {
  if (progresoEmpujar <= 0) return;
  float sx = pantallaX(PESADA_I + 0.5, PESADA_J + 0.5);
  float sy = pantallaY(PESADA_I + 0.5, PESADA_J + 0.5) - 44 * pixel;
  noStroke();
  fill(40, 46, 70);
  rect(sx - 30 * escala, sy, 60 * escala, 6 * escala);
  fill(NEON_VERDE);
  rect(sx - 30 * escala, sy, 60 * escala * progresoEmpujar, 6 * escala);
}
