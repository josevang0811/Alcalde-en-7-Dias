// Calificacion final y variacion de rondas.
// Rango:
//   Fantasma   nadie te descubrio, la alarma nunca subio y no noqueaste a nadie
//   Silencioso la alarma no paso del nivel 1
//   Ruidoso    lo demas
// Ademas se cuentan puntos para comparar partidas: botin, oportunidades,
// rango y salida.
// Variacion: en cada mision cada vigilante empieza su ronda en otro punto y
// puede recorrerla al reves; las camaras arrancan en otro angulo y los
// empleados en otro puesto. Asi el reconocimiento siempre vale la pena.

int alarmaMaxima;
int noqueos;

String rangoFinal() {
  if (vecesDescubierto == 0 && alarmaMaxima == 0 && noqueos == 0) return "Fantasma";
  if (alarmaMaxima <= 1) return "Silencioso";
  return "Ruidoso";
}

color colorRango(String r) {
  if (r.equals("Fantasma")) return NEON_CIAN;
  if (r.equals("Silencioso")) return NEON_VERDE;
  return COLOR_AMBAR;
}

int bonoRango(String r) {
  if (r.equals("Fantasma")) return 1500;
  if (r.equals("Silencioso")) return 700;
  return 0;
}

int puntosMision() {
  int p = 1000 + valorExtraido * 150 + oportunidadesHechas() * 400 + bonoRango(rangoFinal());
  if (salidaUsada == SALIDA_DUCTO) p += 300;   // la salida limpia
  p -= vecesDescubierto * 150;
  return max(0, p);
}

// Rota la ronda un punto al azar y a veces la invierte
int[][] variarRonda(int[][] ruta) {
  int n = ruta.length;
  // que no empiece encima de la camioneta: se busca un punto lejos de la entrada
  int inicio = 0;
  for (int intento = 0; intento < 12; intento++) {
    int k = int(random(n));
    if (dist(ruta[k][0] + 0.5, ruta[k][1] + 0.5, mapa.inicioX[0], mapa.inicioY[0]) > 10) {
      inicio = k;
      break;
    }
  }
  boolean alReves = random(1) < 0.5;
  int[][] nueva = new int[n][];
  for (int k = 0; k < n; k++) {
    int idx = alReves ? (inicio - k + n) % n : (inicio + k) % n;
    nueva[k] = ruta[idx];
  }
  return nueva;
}

void dibujarCalificacion() {
  float e = escala;
  noStroke();
  fill(0, 170);
  rect(0, 0, width, height);
  float w = 700 * e;
  float h = 460 * e;
  float x = width / 2 - w / 2;
  float y = height / 2 - h / 2;
  panel(x, y, w, h);
  boolean gano = estado == GANASTE;
  textAlign(CENTER, TOP);
  textFont(letraTitulo);
  fill(gano ? NEON_VERDE : COLOR_RIVAL);
  text(gano ? "MISIÓN CUMPLIDA" : "TE ATRAPARON", width / 2, y + 22 * e);
  textFont(letraMedia);
  if (gano) {
    String r = rangoFinal();
    fill(160);
    text("Rango", width / 2, y + 86 * e);
    textFont(letraGrande);
    fill(colorRango(r));
    text(r.toUpperCase() + "   ·   " + puntosMision() + " puntos", width / 2, y + 108 * e);
  } else {
    fill(225);
    text(motivoFin + ".", width / 2, y + 92 * e);
  }
  // datos de la mision en dos columnas
  textFont(letraChica);
  String[][] filas = {
    {"Salida", gano ? NOMBRES_SALIDA[salidaUsada] : "ninguna"},
    {"Hora", horaTexto()},
    {"Botín", (gano ? valorExtraido : 0) + " de " + (mejorBotin + 3) + " posibles"},
    {"Oportunidades", oportunidadesHechas() + " de 3"},
    {"Te descubrieron", vecesDescubierto + (vecesDescubierto == 1 ? " vez" : " veces")},
    {"Alarma máxima", alarmaMaxima + " (" + NOMBRES_ALARMA[alarmaMaxima] + ")"},
    {"Noqueados", "" + noqueos},
    {"Chat del rival", chatLeido ? "leído" : "sin leer"}
  };
  for (int k = 0; k < filas.length; k++) {
    float cx = x + 60 * e + (k % 2) * 310 * e;
    float cy = y + 158 * e + (k / 2) * 26 * e;
    textAlign(LEFT, TOP);
    fill(150);
    text(filas[k][0], cx, cy);
    textAlign(RIGHT, TOP);
    fill(235);
    text(filas[k][1], cx + 270 * e, cy);
  }
  // lo que pasa en Alcalde Digital
  float ay = y + 278 * e;
  stroke(25, 227, 227, 60);
  line(x + 40 * e, ay - 10 * e, x + w - 40 * e, ay - 10 * e);
  noStroke();
  textAlign(CENTER, TOP);
  textFont(letraMedia);
  int cambio = cambioApoyo(gano);
  fill(cambio >= 0 ? NEON_VERDE : COLOR_RIVAL);
  text("En Alcalde Digital: " + (cambio >= 0 ? "+" : "") + cambio + " de apoyo en " + barrioCampana, width / 2, ay);
  textFont(letraChica);
  fill(210);
  text("Noticia de mañana:", width / 2, ay + 30 * e);
  fill(242, 242, 233);
  text("\"" + proximaNoticia(gano) + "\"", x + 30 * e, ay + 50 * e, w - 60 * e, 60 * e);
  fill(130);
  if (desdeCampana) {
    text("Enter para volver a tu oficina   ·   R para intentarlo otra vez", width / 2, y + h - 30 * e);
  } else {
    text("Guardado en data/resultado.txt   ·   R para volver al inicio   ·   C para los créditos", width / 2, y + h - 30 * e);
  }
}
