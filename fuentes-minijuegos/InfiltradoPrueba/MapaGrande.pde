// Mapa grande: con G se abre el plano de toda la sede, igual que el del
// reconocimiento (cuartos con su nombre, rondas, camaras, tarjetas y salidas),
// con la posicion de cada jugador. Mientras esta abierto la partida se pausa.
// Cuando una charla da una pista ("esta en el descanso"), ese cuarto parpadea
// en el mapa por un rato.

boolean mapaAbierto;
float[] resalteZona = new float[11];   // por cuarto: segundos que le quedan parpadeando

void alternarMapa() {
  if (ventana != 0) return;
  for (Jugador j : jugadores) if (j.contestando != null) return;
  mapaAbierto = !mapaAbierto;
  for (Jugador j : jugadores) j.pulsoUsar = false;   // que nada quede presionado al volver
}

void resaltarZona(int z, String mensaje) {
  resalteZona[z] = 25;
  avisar(mensaje + " (G para ver el mapa)");
}

void actualizarResaltes(float dt) {
  for (int z = 0; z < resalteZona.length; z++) resalteZona[z] = max(0, resalteZona[z] - dt);
}

// Encima del plano: cuartos resaltados y donde esta cada jugador
void dibujarMarcasMapa() {
  noStroke();
  float pulso = 0.5 + 0.5 * sin(millis() / 180.0);
  float[] sumaX = new float[resalteZona.length];
  float[] sumaY = new float[resalteZona.length];
  int[] cuenta = new int[resalteZona.length];
  for (int i = 0; i < mapa.ancho; i++) {
    for (int j = 0; j < mapa.alto; j++) {
      int z = mapa.zona[i][j];
      if (resalteZona[z] <= 0 || mapa.esPared(i, j)) continue;
      sumaX[z] += i + 0.5;
      sumaY[z] += j + 0.5;
      cuenta[z]++;
      fill(61, 220, 132, 80 + 90 * pulso);
      quad(pantallaX(i, j), pantallaY(i, j), pantallaX(i + 1, j), pantallaY(i + 1, j),
        pantallaX(i + 1, j + 1), pantallaY(i + 1, j + 1), pantallaX(i, j + 1), pantallaY(i, j + 1));
    }
  }
  // "pista aqui" en el centro de cada cuarto resaltado
  for (int z = 0; z < resalteZona.length; z++) {
    if (cuenta[z] > 0) etiquetaMundo(sumaX[z] / cuenta[z], sumaY[z] / cuenta[z], "PISTA AQUÍ", NEON_VERDE);
  }
  for (Jugador p : jugadores) {
    float sx = pantallaX(p.x, p.y);
    float sy = pantallaY(p.x, p.y);
    noFill();
    stroke(p.ropa);
    strokeWeight(3 / zoom);
    float r = (18 + 8 * pulso) / zoom;
    ellipse(sx, sy, r * 2, r);
    noStroke();
    fill(p.ropa);
    triangle(sx - 8 / zoom, sy - 34 / zoom, sx + 8 / zoom, sy - 34 / zoom, sx, sy - 20 / zoom);
    etiquetaMundo(p.x, p.y - 1.2, jugadores.size() > 1 ? "J" + p.numero : "Tú", p.ropa);
  }
}

// Franja de arriba mientras el mapa esta abierto
void dibujarHudMapa() {
  float e = escala;
  float w = 520 * e;
  float x = width / 2 - w / 2;
  float y = 14 * e;
  panel(x, y, w, 64 * e, NEON_VERDE);
  textAlign(CENTER, TOP);
  textFont(letraGrande);
  fill(NEON_VERDE);
  text("MAPA DE LA SEDE", width / 2, y + 10 * e);
  textFont(letraChica);
  fill(200);
  text("Partida en pausa   ·   G para volver", width / 2, y + 40 * e);
}
