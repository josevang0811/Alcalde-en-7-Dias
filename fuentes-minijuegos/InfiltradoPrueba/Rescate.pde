// Cooperativo: si un vigilante atrapa a un jugador y el otro sigue libre,
// no se pierde de inmediato. El atrapado queda esposado en el piso y el
// compañero tiene TIEMPO_RESCATE segundos para llegar y soltarlo (mantener
// usar 2 s a su lado). Si se acaba el tiempo o atrapan a los dos, se pierde.

final float TIEMPO_RESCATE = 20;
final float TIEMPO_SOLTAR = 2;

// Devuelve true si la partida sigue (el otro jugador puede rescatarlo)
boolean atraparJugador(Jugador j, Vigilante quien) {
  Jugador otro = null;
  for (Jugador p : jugadores) {
    if (p != j && !p.atrapado) otro = p;
  }
  if (otro == null) return false;
  j.atrapado = true;
  j.tiempoAtrapado = TIEMPO_RESCATE;
  j.progresoSoltar = 0;
  j.escondido = false;
  j.agachado = true;
  j.contestando = null;
  if (j.arrastrando != null) soltarCuerpo(j);
  if (ventana != 0 && quienLee == j) ventana = 0;
  // el vigilante lo deja esposado y se queda buscando al otro
  quien.estado = V_BUSCANDO;
  quien.tiempoBuscando = 5;
  quien.anguloBase = quien.angulo;
  quien.sospecha = 70;
  quien.objetivo = null;
  subirAlarma("¡Atraparon al jugador " + j.numero + "! Jugador " + otro.numero + ": tienes " + round(TIEMPO_RESCATE) + " s para soltarlo");
  return true;
}

// Compañero esposado al lado de este jugador (o null)
Jugador companeroAtrapado(Jugador j) {
  for (Jugador p : jugadores) {
    if (p != j && p.atrapado && dist(p.x, p.y, j.x, j.y) < 1.3) return p;
  }
  return null;
}

void actualizarRescates(float dt) {
  for (Jugador j : jugadores) {
    if (!j.atrapado) continue;
    j.tiempoAtrapado -= dt;
    if (j.tiempoAtrapado <= 0) {
      perder("No alcanzaste a soltar al jugador " + j.numero);
      return;
    }
  }
  for (Jugador j : jugadores) {
    if (j.atrapado) continue;
    Jugador p = companeroAtrapado(j);
    if (p != null && j.usandoMantenido()) {
      p.progresoSoltar += dt / TIEMPO_SOLTAR;
      if (p.progresoSoltar >= 1) {
        p.atrapado = false;
        p.progresoSoltar = 0;
        avisar("¡Soltaste al jugador " + p.numero + "! Salgan de ahí");
      }
    } else if (p != null) {
      p.progresoSoltar = max(0, p.progresoSoltar - dt);
    }
  }
}

// Esposas y tiempo que queda, encima del jugador atrapado
void dibujarRescates() {
  for (Jugador j : jugadores) {
    if (!j.atrapado) continue;
    float sx = pantallaX(j.x, j.y);
    float sy = pantallaY(j.x, j.y) - 30 * pixel;
    medidor(sx, sy, 100 * j.tiempoAtrapado / TIEMPO_RESCATE, COLOR_RIVAL);
    noStroke();
    fill(15, 20, 36, 230);
    ellipse(sx, sy, 20 * escala, 20 * escala);
    noFill();
    stroke((frameCount / 10) % 2 == 0 ? COLOR_RIVAL : color(242, 242, 233));
    strokeWeight(2 * escala);
    ellipse(sx - 3 * escala, sy, 7 * escala, 7 * escala);
    ellipse(sx + 3 * escala, sy, 7 * escala, 7 * escala);
    if (j.progresoSoltar > 0) {
      noStroke();
      fill(40, 46, 70);
      rect(sx - 20 * escala, sy + 16 * escala, 40 * escala, 5 * escala);
      fill(NEON_VERDE);
      rect(sx - 20 * escala, sy + 16 * escala, 40 * escala * j.progresoSoltar, 5 * escala);
    }
  }
}
