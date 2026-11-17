// Camara de seguridad pegada a una esquina. Gira de un lado a otro; si ve a
// un jugador el tiempo suficiente, suena la alarma y todos los vigilantes van
// a revisar ese punto. Despues de sonar descansa unos segundos.
class CamaraSeguridad {
  final float RANGO = 5.5;
  final float APERTURA = radians(24);

  float x, y;
  float anguloBase, amplitud, angulo;
  float t;            // reloj propio para el giro
  float sospecha;     // 0 a 100
  float descanso;
  boolean viendo;
  float hackeada;     // segundos que le quedan apagada por el Hacker

  CamaraSeguridad(float x, float y, float anguloBase, float amplitud) {
    this.x = x;
    this.y = y;
    this.anguloBase = anguloBase;
    this.amplitud = amplitud;
    angulo = anguloBase;
  }

  void actualizar(float dt) {
    descanso = max(0, descanso - dt);
    boolean veiaAntes = viendo;
    viendo = false;
    if (!camarasEncendidas() || hackeada > 0) return;   // apagada desde la consola o hackeada
    Jugador visto = null;
    for (Jugador j : jugadores) {
      if (j.escondido || j.atrapado) continue;
      float d = dist(x, y, j.x, j.y);
      if (d > RANGO) continue;
      if (abs(diferenciaAngulo(atan2(j.y - y, j.x - x), angulo)) > APERTURA) continue;
      if (!mapa.hayLinea(x, y, j.x, j.y)) continue;
      if (!veiaAntes && !viendo) sonar("pitido_camara");
      viendo = true;
      visto = j;
      float ritmo = 70 * mapa.factorLuz(j.x, j.y) * factorRol(j) * factorCamaraHerramienta() * factorDisfrazCivil(j);
      if (j.agachado) ritmo *= 0.6;
      sospecha = min(100, sospecha + ritmo * dt);
    }
    // Un cuerpo tirado a la vista de la camara tambien da la alerta
    for (Persona q : personas()) {
      if (!q.cuerpoALaVista() || !partidaEnCurso()) continue;
      if (dist(x, y, q.x, q.y) > RANGO) continue;
      if (abs(diferenciaAngulo(atan2(q.y - y, q.x - x), angulo)) > APERTURA) continue;
      if (!mapa.hayLinea(x, y, q.x, q.y)) continue;
      cuerpoEncontrado(q, null);
      break;
    }
    if (viendo) {
      // Mientras ve a alguien deja de girar (lo sigue mirando)
      if (sospecha >= 100 && descanso <= 0) {
        sonarAlarma(visto.x, visto.y);
        sospecha = 0;
        descanso = 5;
      }
    } else {
      girar(dt);
      sospecha = max(0, sospecha - 25 * dt);
    }
  }

  void girar(float dt) {
    t += dt * factorGiroCamaras();
    angulo = anguloBase + sin(t * 0.8) * amplitud;
  }
}
