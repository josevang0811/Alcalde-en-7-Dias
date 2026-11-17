// Salidas. Con el servidor copiado hay tres maneras de irse y se elige al
// llegar (usar):
//   Camioneta: la de siempre, junto a la entrada. Con la policia en camino
//              (alarma 3) el callejon queda bloqueado y ya no sirve.
//   Moto:      al fondo del parqueadero, junto a la puerta de carga. Hay que
//              cruzar el parqueadero iluminado, pero sirve siempre.
//   Ducto:     la rejilla del parqueadero da a la calle. Es la mas limpia,
//              pero no se cabe con mas de 2 kg en la mochila.
// En cooperativo los dos tienen que estar en la salida.

final int SALIDA_CAMIONETA = 0;
final int SALIDA_MOTO = 1;
final int SALIDA_DUCTO = 2;
final String[] NOMBRES_SALIDA = {"camioneta", "moto", "ducto"};
final int DUCTO_CALLE_I = 40, DUCTO_CALLE_J = 22;
final int PESO_DUCTO = 2;

int salidaUsada = -1;

// Copiar el servidor es lo ultimo: despues ya no se recoge ni se revisa nada,
// solo queda escapar
boolean soloEscapar() {
  return servidorCopiado;
}

// Salida junto al jugador (o -1)
int salidaCercana(Jugador j) {
  if (mapa.cercano(j.x, j.y, 'E', 1.6) != null) return SALIDA_CAMIONETA;
  if (mapa.cercano(j.x, j.y, 'm', 1.6) != null) return SALIDA_MOTO;
  if (dist(j.x, j.y, DUCTO_CALLE_I + 0.5, DUCTO_CALLE_J + 0.5) < 1.2) return SALIDA_DUCTO;
  return -1;
}

// Por que no se puede salir por ahi ahora ("" si se puede)
String bloqueoSalida(int s) {
  if (!servidorCopiado) return "Primero copia el servidor";
  if (s == SALIDA_CAMIONETA && nivelAlarma >= 3) return "La policía bloquea el callejón";
  if (s == SALIDA_DUCTO) {
    for (Jugador p : jugadores) {
      if (p.peso > PESO_DUCTO) return "No cabes: más de " + PESO_DUCTO + " kg";
    }
  }
  for (Jugador p : jugadores) {
    if (p.atrapado || salidaCercana(p) != s) return "Espera a tu compañero";
  }
  return "";
}

// Devuelve true si el jugador estaba en una salida (haya podido o no salir)
boolean intentarSalir(Jugador j) {
  int s = salidaCercana(j);
  if (s < 0 || !servidorCopiado) return false;
  // la rejilla del parqueadero tambien es la entrada a los ductos: con el
  // servidor copiado usar ahi es salir
  String b = bloqueoSalida(s);
  if (!b.equals("")) {
    avisar(b);
    return true;
  }
  salidaUsada = s;
  ganar();
  return true;
}
