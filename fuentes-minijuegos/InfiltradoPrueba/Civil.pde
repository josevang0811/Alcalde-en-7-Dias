// Empleados que se quedan trabajando de noche en la sede. No atrapan a
// nadie, pero si ven a un jugador (o un cuerpo) salen corriendo a avisarle
// al vigilante mas cercano. "Mas cercano" se mide por camino con Dijkstra
// (Mapa.dijkstraCivil): las puertas y las zonas oscuras cuestan mas.

final int C_TRABAJANDO = 0;
final int C_SOSPECHA = 1;
final int C_HUYENDO = 2;
final int C_ASUSTADO = 3;

class Civil extends Persona {
  final float RANGO = 4.5;
  final float APERTURA = radians(50);

  int[][] ruta;
  int indiceRuta;
  ArrayList<int[]> camino = new ArrayList<int[]>();
  SpritesPersona sprites;
  int estado = C_TRABAJANDO;
  float sospecha;
  float espera;               // segundos que se queda en su puesto
  float ultimoX, ultimoY;     // donde vio al jugador
  Persona cuerpoVisto;        // cuerpo que va a reportar (o null)
  Vigilante destino;          // a quien le va a avisar
  float recalculo, tiempoAsustado;
  Jugador jugadorVisto;

  Civil(int[][] ruta, SpritesPersona sprites) {
    this.ruta = ruta;
    this.sprites = sprites;
    x = ruta[0][0] + 0.5;
    y = ruta[0][1] + 0.5;
    angulo = HALF_PI;
    indiceRuta = 0;
    espera = 2;
  }

  void actualizar(float dt) {
    if (inconsciente) return;
    mirar(dt);
    if (estaCharlando(this)) return;  // se queda quieto conversando
    mover(dt);
  }

  // Mira si hay un jugador o un cuerpo delante
  void mirar(float dt) {
    jugadorVisto = null;
    if (estado == C_HUYENDO) return;   // ya va a avisar
    float mejor = 0;
    for (Jugador j : jugadores) {
      if (j.escondido || j.atrapado) continue;
      float d = dist(x, y, j.x, j.y);
      if (d > RANGO || abs(diferenciaAngulo(atan2(j.y - y, j.x - x), angulo)) > APERTURA) continue;
      if (!mapa.hayLinea(x, y, j.x, j.y)) continue;
      float ritmo = 150 * (1.1 - d / RANGO) * mapa.factorLuz(j.x, j.y);
      if (j.agachado) ritmo *= 0.6;
      ritmo *= factorDisfrazCivil(j) * factorRol(j);
      if (ritmo > mejor) {
        mejor = ritmo;
        jugadorVisto = j;
      }
    }
    if (jugadorVisto != null) {
      sospecha = min(100, sospecha + mejor * dt);
      ultimoX = jugadorVisto.x;
      ultimoY = jugadorVisto.y;
    } else {
      sospecha = max(0, sospecha - 15 * dt);
    }
    if (sospecha >= 100) {
      huir(null);
      return;
    }
    if (estado == C_TRABAJANDO && sospecha > 35) estado = C_SOSPECHA;
    if (estado == C_SOSPECHA && sospecha <= 0) estado = C_TRABAJANDO;
    // un cuerpo en el piso tambien lo hace salir corriendo
    for (Persona q : personas()) {
      if (q == this || !q.cuerpoALaVista()) continue;
      float d = dist(x, y, q.x, q.y);
      if (d > RANGO || abs(diferenciaAngulo(atan2(q.y - y, q.x - x), angulo)) > APERTURA) continue;
      if (!mapa.hayLinea(x, y, q.x, q.y)) continue;
      huir(q);
      return;
    }
  }

  // Sale corriendo hacia el vigilante mas cercano (por Dijkstra)
  void huir(Persona cuerpo) {
    if (estado == C_HUYENDO) return;
    estado = C_HUYENDO;
    cuerpoVisto = cuerpo;
    if (cuerpo != null) {
      ultimoX = cuerpo.x;
      ultimoY = cuerpo.y;
    }
    elegirVigilante();
    if (destino == null) {
      asustarse();
      return;
    }
    avisar(cuerpo == null ? "¡Un empleado te vio! Va corriendo a avisarle a seguridad"
      : "¡Un empleado vio el cuerpo! Va corriendo a avisarle a seguridad");
  }

  void elegirVigilante() {
    int[] dist = mapa.dijkstraCivil(floor(x), floor(y));
    destino = null;
    int mejor = Integer.MAX_VALUE;
    for (Vigilante v : vigilantes) {
      if (v.inconsciente) continue;
      int k = floor(v.y) * mapa.ancho + floor(v.x);
      if (dist[k] < mejor) {
        mejor = dist[k];
        destino = v;
      }
    }
    if (destino != null) camino = mapa.caminoCivil(floor(destino.x), floor(destino.y));
    recalculo = 0.8;
  }

  // Llego donde el vigilante: le cuenta lo que vio
  void avisarVigilante() {
    if (cuerpoVisto != null && !cuerpoVisto.encontrado) {
      cuerpoEncontrado(cuerpoVisto, destino);
    } else if (cuerpoVisto == null && DETECTADO_PIERDE) {
      perder("Un empleado le avisó a seguridad que te vio");
      return;
    } else if (cuerpoVisto == null) {
      subirAlarma("Un empleado le avisó a seguridad dónde te vio");
      destino.sospecha = max(destino.sospecha, 85);
      destino.revisar(ultimoX, ultimoY);
    }
    asustarse();
  }

  void asustarse() {
    estado = C_ASUSTADO;
    tiempoAsustado = 15;
    camino.clear();
    sospecha = 0;
    cuerpoVisto = null;
  }

  // Lo despertaron despues de noquearlo: queda asustado un rato
  void despertar() {
    asustarse();
  }

  void mover(float dt) {
    if (estado == C_HUYENDO) {
      // el vigilante se mueve: cada tanto se recalcula el camino
      recalculo -= dt;
      if (destino == null || destino.inconsciente || recalculo <= 0) elegirVigilante();
      if (destino == null) {
        asustarse();
        return;
      }
      if (dist(x, y, destino.x, destino.y) < 1.4) {
        avisarVigilante();
        return;
      }
      seguirCamino(3.0, dt);
      return;
    }
    if (estado == C_ASUSTADO) {
      tiempoAsustado -= dt;
      if (tiempoAsustado <= 0) {
        estado = C_TRABAJANDO;
        irA(ruta[indiceRuta][0], ruta[indiceRuta][1]);
      }
      return;
    }
    if (estado == C_SOSPECHA) {
      // se queda quieto mirando hacia lo que le parecio raro
      if (jugadorVisto != null) girarHacia(atan2(ultimoY - y, ultimoX - x), dt);
      return;
    }
    moverRutina(dt);
  }

  // Va de un puesto a otro de su ruta y se queda un rato en cada uno
  void moverRutina(float dt) {
    if (camino.size() > 0) {
      seguirCamino(1.1, dt);
      return;
    }
    espera -= dt;
    if (espera <= 0) {
      espera = random(3, 6);
      indiceRuta = (indiceRuta + 1) % ruta.length;
      irA(ruta[indiceRuta][0], ruta[indiceRuta][1]);
    }
  }

  void irA(int i, int j) {
    camino = mapa.caminoBFS(floor(x), floor(y), i, j);
  }

  void seguirCamino(float velocidad, float dt) {
    if (camino.size() == 0) return;
    int[] c = camino.get(0);
    float dx = c[0] + 0.5 - x;
    float dy = c[1] + 0.5 - y;
    float d = sqrt(dx * dx + dy * dy);
    if (d < 0.05) {
      camino.remove(0);
      return;
    }
    float paso = min(d, velocidad * dt);
    x += dx / d * paso;
    y += dy / d * paso;
    girarHacia(atan2(dy, dx), dt);
  }

  void girarHacia(float objetivo, float dt) {
    float giro = 6 * dt;
    angulo += constrain(diferenciaAngulo(objetivo, angulo), -giro, giro);
  }

  boolean caminando() {
    return camino.size() > 0 && estado != C_ASUSTADO && estado != C_SOSPECHA;
  }
}

void dibujarCivil(Civil c) {
  if (c.inconsciente) {
    if (!c.cuerpoEscondido) dibujarCuerpo(c.sprites, c);
    return;
  }
  dibujarPersona(c.sprites, c.x, c.y, c.angulo, c.estado == C_ASUSTADO, c.caminando(), 255, c);
}
