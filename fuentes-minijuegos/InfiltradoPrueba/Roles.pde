// Roles. Antes de entrar cada jugador tiene un rol con una habilidad propia
// (tecla F el jugador 1, M el jugador 2) que despues necesita enfriarse.
//   Hacker:   apaga 12 s la camara mas cercana (hasta 9 baldosas) y contesta
//             la radio con una secuencia mas corta.
//   Fantasma: "Sombra": 6 s en los que casi nadie lo nota, y agachado se
//             mueve mas rapido.
// En solitario se elige el rol; en cooperativo el jugador 1 elige y el
// jugador 2 queda con el otro.

final int ROL_HACKER = 0;
final int ROL_FANTASMA = 1;
final String[] NOMBRES_ROL = {"Hacker", "Fantasma"};
final String[] HABILIDAD_ROL = {"Hackear cámara", "Sombra"};
final float[] ENFRIAR_ROL = {25, 30};
final float TIEMPO_HACKEO = 12;
final float TIEMPO_SOMBRA = 6;
final float ALCANCE_HACKEO = 9;


void usarHabilidad(Jugador j) {
  if (estado != JUGANDO || j.escondido || j.contestando != null) return;
  if (j.enfriamiento > 0) {
    avisar(HABILIDAD_ROL[j.rol] + " lista en " + ceil(j.enfriamiento) + " s");
    return;
  }
  if (j.rol == ROL_HACKER) {
    CamaraSeguridad mejor = null;
    float mejorD = ALCANCE_HACKEO;
    for (CamaraSeguridad c : camaras) {
      float d = dist(c.x, c.y, j.x, j.y);
      if (d < mejorD && c.hackeada <= 0) {
        mejorD = d;
        mejor = c;
      }
    }
    if (mejor == null) {
      avisar("No hay cámaras a tu alcance para hackear");
      return;
    }
    mejor.hackeada = TIEMPO_HACKEO;
    sonar("hackeo");
    chispas(mejor.x, mejor.y, NEON_CIAN, 12);
    textoFlotante(mejor.x, mejor.y, "Hackeada", NEON_CIAN);
    mejor.sospecha = 0;
    j.enfriamiento = enfriamientoRol(ROL_HACKER);
    j.hackeoX = mejor.x;
    j.hackeoY = mejor.y;
    j.efectoHabilidad = 0.6;
    avisar("Cámara hackeada por " + round(TIEMPO_HACKEO) + " s");
  } else {
    j.sombra = TIEMPO_SOMBRA;
    sonar("sombra");
    chispas(j.x, j.y, NEON_MAGENTA, 12);
    j.enfriamiento = enfriamientoRol(ROL_FANTASMA);
    avisar("Sombra: por " + round(TIEMPO_SOMBRA) + " s casi nadie te nota");
  }
}

void actualizarRoles(float dt) {
  for (Jugador j : jugadores) {
    j.enfriamiento = max(0, j.enfriamiento - dt);
    j.sombra = max(0, j.sombra - dt);
    j.efectoHabilidad = max(0, j.efectoHabilidad - dt);
  }
  for (CamaraSeguridad c : camaras) c.hackeada = max(0, c.hackeada - dt);
}

// Cuanto se multiplica la sospecha de quien mira a este jugador
float factorRol(Jugador j) {
  return j.sombra > 0 ? 0.2 : 1;
}

float velocidadAgachado(Jugador j) {
  return j.rol == ROL_FANTASMA ? 1.9 : 1.4;
}

int largoSecuenciaRadio(Jugador j) {
  return j.rol == ROL_HACKER ? 3 : 4;
}

// Rayo del hackeo desde el jugador hasta la camara
void dibujarEfectosRol() {
  for (Jugador j : jugadores) {
    if (j.efectoHabilidad > 0) {
      float a = 255 * j.efectoHabilidad / 0.6;
      stroke(25, 227, 227, a);
      strokeWeight(2 * pixel);
      float x0 = pantallaX(j.x, j.y), y0 = pantallaY(j.x, j.y) - 18 * pixel;
      float x1 = pantallaX(j.hackeoX, j.hackeoY), y1 = pantallaY(j.hackeoX, j.hackeoY) - 24 * pixel;
      // linea quebrada, como una señal
      int tramos = 6;
      float px = x0, py = y0;
      for (int k = 1; k <= tramos; k++) {
        float nx = lerp(x0, x1, k / (float) tramos) + (k < tramos ? random(-6, 6) * pixel : 0);
        float ny = lerp(y0, y1, k / (float) tramos) + (k < tramos ? random(-6, 6) * pixel : 0);
        line(px, py, nx, ny);
        px = nx;
        py = ny;
      }
    }
  }
}
