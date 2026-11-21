// Nivel de alarma (0 a 3) y reloj de la noche.
// La alarma sube cuando algo sale mal: te descubren, una camara te ve,
// encuentran un cuerpo, nadie contesta una radio o un empleado avisa.
// Cada nivel cambia la sede:
//   1 Precaucion: los vigilantes caminan mas rapido y las camaras giran mas.
//   2 Busqueda: ven mas lejos, se prenden todas las luces, bloquean los
//     tableros y cierran la entrada principal (hay que buscar otra salida).
//   3 Policia en camino: hay 90 s para salir.
// El reloj empieza a las 2:00 a. m.; a las 5:00 llega el turno de la manana
// (si LIMITE_DE_TIEMPO esta en true; por ahora esta apagado).

final boolean LIMITE_DE_TIEMPO = false;   // por ahora la noche no se acaba (Jose, 25-10)
// En true, si te ve un vigilante, una camara o un empleado llega a avisar, la
// mision termina. En false (lo que pidio Jose) te persiguen y sube la alarma.
final boolean DETECTADO_PIERDE = false;
final float SEGUNDOS_POR_MINUTO = 2;   // un minuto de la noche dura 2 s
final int HORA_INICIO = 2 * 60;        // en minutos desde la medianoche
final int HORA_FIN = 5 * 60;
final float TIEMPO_POLICIA = 90;
final float PAUSA_ALARMA = 4;          // un mismo susto no sube dos niveles seguidos
final int ENTRADA_I = 8, ENTRADA_J = 21;
String[] NOMBRES_ALARMA = {"Tranquilo", "Precaución", "Búsqueda", "Policía en camino"};

float tiempoPolicia;
float ultimaSubida = -99;
boolean avisoAmanecer;

float minutosDeLaNoche() {
  return HORA_INICIO + tiempoMision / SEGUNDOS_POR_MINUTO;
}

String horaTexto() {
  int m = floor(minutosDeLaNoche()) % (24 * 60);
  int h = m / 60;
  int h12 = h % 12 == 0 ? 12 : h % 12;
  return h12 + ":" + nf(m % 60, 2) + (h < 12 ? " a. m." : " p. m.");
}

// Algo salio mal: la alarma sube un nivel (salvo que acabe de subir)
void subirAlarma(String motivo) {
  destelloAlarma = 1;
  if (nivelAlarma >= 3 || tiempoMision - ultimaSubida < PAUSA_ALARMA) {
    avisar(motivo);
    return;
  }
  ultimaSubida = tiempoMision;
  nivelAlarma++;
  sonar("alarma");
  sacudir(5);
  alarmaMaxima = max(alarmaMaxima, nivelAlarma);
  avisar(motivo + "  ·  Alarma: " + NOMBRES_ALARMA[nivelAlarma]);
  if (nivelAlarma == 2) {
    for (int z = 0; z < mapa.zonaApagada.length; z++) mapa.zonaApagada[z] = false;
    if (mapa.celdas[ENTRADA_I][ENTRADA_J] == 'D') mapa.cerrarPuerta(ENTRADA_I, ENTRADA_J, '1');
    mapa.calcularLuz();
  }
  if (nivelAlarma == 3) tiempoPolicia = TIEMPO_POLICIA;
}

// Al borrar las grabaciones
void bajarAlarma() {
  nivelAlarma = max(0, nivelAlarma - 1);
  if (nivelAlarma < 3) tiempoPolicia = 0;
}

void actualizarAlarma(float dt) {
  float m = minutosDeLaNoche();
  if (!LIMITE_DE_TIEMPO) m = 0;
  if (LIMITE_DE_TIEMPO && m >= HORA_FIN - 30 && !avisoAmanecer) {
    avisoAmanecer = true;
    avisar("Son las 4:30. A las 5:00 llega el turno de la mañana");
  }
  if (LIMITE_DE_TIEMPO && m >= HORA_FIN) {
    perder("Amaneció y llegó el turno de la mañana");
    return;
  }
  if (nivelAlarma == 3) {
    tiempoPolicia -= dt;
    if (tiempoPolicia <= 0) perder("Llegó la policía");
  }
}

float factorVelocidadAlarma() {
  return nivelAlarma >= 1 ? 1.15 : 1;
}

float factorGiroCamaras() {
  return nivelAlarma >= 1 ? 1.4 : 1;
}

float rangoExtraAlarma() {
  return nivelAlarma >= 2 ? 1.5 : 0;
}

boolean tablerosBloqueados() {
  return nivelAlarma >= 2;
}
