// Oportunidades (como en Hitman): objetivos opcionales que se descubren
// revisando la sede y que cambian lo que pasa despues en Alcalde Digital.
//   0. Cambiar el borrador del bulo en el computador del rival. Se descubre
//      leyendo su chat. Mantener usar 4 s junto al escritorio.
//   1. Fotografiar el tablero de conspiracion. Se descubre al verlo. El
//      flash hace un poco de ruido.
//   2. Sabotear la impresora de volantes falsos de la redaccion. Se descubre
//      en el cuaderno del rival. Mantener usar 4 s; la impresora suena.

final String[] NOMBRES_OPORTUNIDAD = {"Cambiar el borrador del bulo", "Fotografiar el tablero", "Sabotear la impresora de volantes"};
final char[] OBJETO_OPORTUNIDAD = {'O', 'X', 'I'};
final float[] RADIO_OPORTUNIDAD = {1.6, 1.9, 1.5};
final float TIEMPO_OPORTUNIDAD = 4;

boolean[] oportunidadVista = new boolean[3];
boolean[] oportunidadHecha = new boolean[3];
float[] progresoOportunidad = new float[3];
float zumbidoImpresora;

void prepararOportunidades() {
  oportunidadVista = new boolean[3];
  oportunidadHecha = new boolean[3];
  progresoOportunidad = new float[3];
}

void descubrirOportunidad(int k) {
  if (oportunidadVista[k]) return;
  oportunidadVista[k] = true;
  avisar("Oportunidad nueva: " + NOMBRES_OPORTUNIDAD[k]);
}

// La oportunidad que este jugador puede hacer ahora (o -1)
int oportunidadCercana(Jugador j) {
  if (soloEscapar()) return -1;
  for (int k = 0; k < 3; k++) {
    if (!oportunidadVista[k] || oportunidadHecha[k]) continue;
    if (mapa.cercano(j.x, j.y, OBJETO_OPORTUNIDAD[k], RADIO_OPORTUNIDAD[k]) != null) return k;
  }
  return -1;
}

// La foto es al presionar; las otras dos se hacen manteniendo usar
boolean usarOportunidad(Jugador j) {
  int k = oportunidadCercana(j);
  if (k < 0) return false;
  if (k == 1) {
    oportunidadHecha[1] = true;
    hacerRuido(j.x, j.y, 2.5);   // el flash y el "clic"
    destelloFoto = 1;
    sonar("foto");
    textoFlotante(j.x, j.y, "+3", NEON_MAGENTA);
    avisar("Foto del tablero tomada: es una prueba más (+3)");
  }
  return true;
}

float destelloFoto;

void actualizarOportunidades(float dt) {
  destelloFoto = max(0, destelloFoto - dt * 3);
  for (Jugador j : jugadores) {
    int k = oportunidadCercana(j);
    if (k != 0 && k != 2) continue;
    if (!j.usandoMantenido()) continue;
    progresoOportunidad[k] += dt / TIEMPO_OPORTUNIDAD;
    if (k == 2) {
      zumbidoImpresora -= dt;
      if (zumbidoImpresora <= 0) {
        zumbidoImpresora = 1;
        hacerRuido(j.x, j.y, 2);
      }
    }
    if (progresoOportunidad[k] >= 1) {
      oportunidadHecha[k] = true;
      sonar("servidor_listo");
      textoFlotante(j.x, j.y, "+10 apoyo", NEON_MAGENTA);
      chispas(j.x, j.y, NEON_MAGENTA, 12);
      avisar(k == 0 ? "Cambiaste el borrador: mañana su bulo sale con los datos reales"
        : "Impresora saboteada: los volantes falsos salen en blanco");
    }
  }
}

int oportunidadesHechas() {
  int n = 0;
  for (boolean b : oportunidadHecha) if (b) n++;
  return n;
}

// Panel de oportunidades debajo de los objetivos
void dibujarOportunidades(float x, float y, float w) {
  float e = escala;
  panel(x, y, w, 92 * e);
  textFont(letraChica);
  textAlign(LEFT, TOP);
  fill(NEON_MAGENTA);
  text("Oportunidades " + oportunidadesHechas() + "/3", x + 12 * e, y + 8 * e);
  for (int k = 0; k < 3; k++) {
    String t = oportunidadVista[k] ? NOMBRES_OPORTUNIDAD[k] : "??? (revisa la oficina del rival)";
    if (oportunidadVista[k] && !oportunidadHecha[k] && progresoOportunidad[k] > 0 && k != 1) t += "  " + round(progresoOportunidad[k] * 100) + "%";
    objetivo(x + 12 * e, y + 28 * e + k * 20 * e, oportunidadHecha[k], t);
  }
}

void dibujarDestelloFoto() {
  if (destelloFoto <= 0) return;
  noStroke();
  fill(255, 255, 255, 200 * destelloFoto);
  rect(0, 0, width, height);
}
