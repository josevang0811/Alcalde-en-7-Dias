// Un vigilante hace su ronda por la sede. Tiene un cono de vista (su
// linterna) y una barra de sospecha:
//   - Si ve a un jugador, la sospecha sube (mas rapido si esta cerca, en la
//     luz o corriendo; mas lento si esta agachado o en la sombra).
//   - Con 40 se vuelve a mirar que fue eso (SOSPECHA).
//   - Con 100 te descubre y te persigue (ALERTA). Si te alcanza, pierdes.
//   - Si oye un ruido, va a revisar el lugar.
// Para moverse a cualquier baldosa usa BFS sobre la cuadricula del mapa.
class Vigilante extends Persona {
  final float RANGO = 6.0;
  final float APERTURA = radians(40);   // mitad del cono

  int estado = V_PATRULLA;
  float sospecha;
  int[][] ruta;
  int indiceRuta;
  ArrayList<int[]> camino = new ArrayList<int[]>();
  float ultimoX, ultimoY;      // donde vio por ultima vez a alguien
  float tiempoSinVer, tiempoRecalculo, tiempoQuieto, tiempoBuscando;
  float reaccion;              // segundos que se queda quieto al descubrirte
  float anguloBase;
  Jugador objetivo;            // a quien persigue
  Jugador jugadorVisto;        // a quien ve en este cuadro (o null)
  int tableroPendiente = -1;   // tablero electrico que va a revisar (o -1)
  color colorRonda;            // para dibujar su ronda en el reconocimiento
  ArrayList<int[]> rondaCompleta = new ArrayList<int[]>();
  Persona cuerpoPorDespertar;  // compañero noqueado al que va a despertar
  boolean esJefe;              // el jefe de seguridad reconoce los disfraces de cerca

  Vigilante(int[][] ruta, color colorRonda) {
    this.ruta = ruta;
    this.colorRonda = colorRonda;
    x = ruta[0][0] + 0.5;
    y = ruta[0][1] + 0.5;
    indiceRuta = 1;
    irA(ruta[1][0], ruta[1][1]);
    // La ronda completa (para el plano) se arma uniendo con BFS cada punto
    // con el siguiente, y el ultimo con el primero
    for (int k = 0; k < ruta.length; k++) {
      int[] a = ruta[k];
      int[] b = ruta[(k + 1) % ruta.length];
      ArrayList<int[]> tramo = mapa.caminoBFS(a[0], a[1], b[0], b[1]);
      for (int t = 0; t < tramo.size(); t++) {
        if (t == 0 && rondaCompleta.size() > 0) continue;   // no repetir la esquina
        rondaCompleta.add(tramo.get(t));
      }
    }
  }

  // Con la alarma en busqueda ven mas lejos
  float rango() {
    return RANGO + rangoExtraAlarma();
  }

  void irA(int i, int j) {
    camino = mapa.caminoBFS(floor(x), floor(y), i, j);
  }

  void actualizar(float dt) {
    if (inconsciente) {
      actualizarRadio(dt);
      return;
    }
    mirar(dt);
    cambiarEstado(dt);
    if (!partidaEnCurso()) return;   // acaba de atrapar a alguien
    if (estaCharlando(this)) return;  // se queda quieto conversando
    mover(dt);
  }

  // 1. Revisar si ve a algun jugador
  void mirar(float dt) {
    jugadorVisto = null;
    float mejorRitmo = 0;
    for (Jugador j : jugadores) {
      if (j.escondido || j.atrapado) continue;
      float d = dist(x, y, j.x, j.y);
      boolean enCono = d <= rango() && abs(diferenciaAngulo(atan2(j.y - y, j.x - x), angulo)) <= APERTURA;
      boolean pegado = d < 1.0;   // tan cerca que lo nota aunque este de espaldas
      if (!(enCono || pegado)) continue;
      // va corriendo hacia una botella: no se fija en nadie salvo que lo tenga encima
      if (apurado && !pegado) continue;
      if (!mapa.hayLinea(x, y, j.x, j.y)) continue;
      float ritmo = 120 * (1.1 - d / rango()) * mapa.factorLuz(j.x, j.y);
      if (j.agachado) ritmo *= 0.5;
      if (j.corriendo) ritmo *= 1.4;
      if (pegado) ritmo = max(ritmo, 60);
      ritmo *= factorDisfraz(j, esJefe, d) * factorRol(j);
      if (ritmo > mejorRitmo) {
        mejorRitmo = ritmo;
        jugadorVisto = j;
      }
    }
    buscarCuerpos();
    if (jugadorVisto != null) {
      sospecha = min(100, sospecha + mejorRitmo * dt);
      ultimoX = jugadorVisto.x;
      ultimoY = jugadorVisto.y;
      tiempoSinVer = 0;
    } else {
      tiempoSinVer += dt;
      if (estado != V_ALERTA) sospecha = max(0, sospecha - 10 * dt);
    }
  }

  // Si ve un cuerpo tirado (que nadie haya encontrado), da la alerta.
  // En la sombra hay que estar mas cerca para notarlo.
  void buscarCuerpos() {
    if (!partidaEnCurso()) return;
    for (Persona q : personas()) {
      if (q == this || !q.cuerpoALaVista()) continue;
      float d = dist(x, y, q.x, q.y);
      if (d > rango() * max(0.5, mapa.factorLuz(q.x, q.y))) continue;
      if (abs(diferenciaAngulo(atan2(q.y - y, q.x - x), angulo)) > APERTURA) continue;
      if (!mapa.hayLinea(x, y, q.x, q.y)) continue;
      cuerpoEncontrado(q, this);
      return;
    }
  }

  void irADespertar(Persona q) {
    revisar(q.x, q.y);
    sospecha = max(sospecha, 70);
    cuerpoPorDespertar = q;
  }

  // 2. Pasar de un estado a otro
  void cambiarEstado(float dt) {
    if (estado != V_ALERTA && sospecha >= 100 && DETECTADO_PIERDE) {
      vecesDescubierto++;
      sonar("descubierto");
      sacudir(6);
      destelloAlarma = 1;
      perder(esJefe ? "El jefe de seguridad te reconoció" : "Un vigilante te vio");
      return;
    }
    if (estado != V_ALERTA && sospecha >= 100) {
      estado = V_ALERTA;
      objetivo = jugadorVisto;
      tiempoRecalculo = 0;
      reaccion = 0.8;
      vecesDescubierto++;
      quemarDisfraz(objetivo);
      sonar("descubierto");
      sacudir(6);
      subirAlarma("¡Te descubrieron! Rompe la línea de vista y escóndete");
    } else if (estado != V_ALERTA && sospecha >= 40 && jugadorVisto != null) {
      // Vio algo raro: va hacia alla (y actualiza el camino cada tanto)
      tiempoRecalculo -= dt;
      if (estado != V_SOSPECHA || tiempoRecalculo <= 0) {
        revisar(ultimoX, ultimoY);
        tiempoRecalculo = 0.6;
      }
    }

    if (estado == V_ALERTA) {
      if (reaccion <= 0 && objetivo != null && !objetivo.escondido && !objetivo.atrapado && dist(x, y, objetivo.x, objetivo.y) < 0.6) {
        if (atraparJugador(objetivo, this)) return;
        perder(jugadores.size() > 1 ? "Un vigilante atrapó al jugador " + objetivo.numero : "Un vigilante te atrapó");
        return;
      }
      tiempoRecalculo -= dt;
      if (tiempoRecalculo <= 0) {
        tiempoRecalculo = 0.4;
        camino = mapa.caminoBFS(floor(x), floor(y), floor(ultimoX), floor(ultimoY));
      }
      if (tiempoSinVer > 4) {
        // Te perdio: va a revisar donde te vio por ultima vez
        revisar(ultimoX, ultimoY);
        sospecha = 70;
        avisar("El vigilante te perdió de vista");
      }
    }
  }

  // Ir a revisar un punto (por algo que vio, oyo o porque sono una alarma)
  void revisar(float px, float py) {
    estado = V_SOSPECHA;
    camino = mapa.caminoBFS(floor(x), floor(y), floor(px), floor(py));
  }

  // "pasos" es el resultado del BFS del ruido: cuantas baldosas recorrio el
  // sonido hasta cada punto (-1 si no llego).
  void escuchar(float px, float py, int[][] pasos) {
    if (estado == V_ALERTA || inconsciente) return;
    if (apurado) return;   // va por la botella: otro ruido no lo desvia
    int i = constrain(floor(x), 0, mapa.ancho - 1);
    int j = constrain(floor(y), 0, mapa.alto - 1);
    if (pasos[i][j] < 0) return;
    sospecha = max(sospecha, 45);
    tableroPendiente = -1;
    revisar(px, py);
  }

  // Oyo una botella: va derecho y apurado a ese punto
  boolean apurado;
  void irARuidoFuerte(float px, float py) {
    // aunque estuviera sospechando de ti, lo que le importa ahora es la botella
    sospecha = 55;
    jugadorVisto = null;
    tableroPendiente = -1;
    cuerpoPorDespertar = null;
    // si la botella cayo sobre un mueble, va a la baldosa libre mas cercana
    int bi = floor(px), bj = floor(py);
    float mejor = 99;
    for (int i = floor(px) - 2; i <= floor(px) + 2; i++) {
      for (int j = floor(py) - 2; j <= floor(py) + 2; j++) {
        if (i < 0 || j < 0 || i >= mapa.ancho || j >= mapa.alto || mapa.esSolidoVigilante(i, j)) continue;
        float d = dist(i + 0.5, j + 0.5, px, py);
        if (d < mejor) {
          mejor = d;
          bi = i;
          bj = j;
        }
      }
    }
    revisar(bi + 0.5, bj + 0.5);
    apurado = true;
  }

  // Alguien corto la luz: va al tablero y la vuelve a prender
  void irATablero(int k, int ti, int tj) {
    revisar(ti + 0.5, tj + 0.5);
    sospecha = max(sospecha, 40);
    tableroPendiente = k;
  }

  void alarma(float px, float py) {
    if (estado == V_ALERTA || inconsciente) return;
    sospecha = max(sospecha, 75);
    revisar(px, py);
  }

  void volverARonda() {
    estado = V_PATRULLA;
    irA(ruta[indiceRuta][0], ruta[indiceRuta][1]);
  }

  // 3. Caminar
  void mover(float dt) {
    float velocidad = 1.4;
    if (estado == V_SOSPECHA) velocidad = apurado ? 2.8 : 1.9;
    if (estado == V_ALERTA) velocidad = 3.1;
    velocidad *= factorVelocidadAlarma();

    // En la persecucion, si ya lo tiene cerca y lo ve, va directo hacia el
    // Al descubrirte se queda un momento sorprendido: es tu chance de huir
    if (reaccion > 0) {
      reaccion -= dt;
      if (jugadorVisto != null) girarHacia(atan2(jugadorVisto.y - y, jugadorVisto.x - x), dt);
      return;
    }

    if (estado == V_ALERTA && jugadorVisto != null && dist(x, y, jugadorVisto.x, jugadorVisto.y) < 1.5) {
      float dx = jugadorVisto.x - x;
      float dy = jugadorVisto.y - y;
      float d = sqrt(dx * dx + dy * dy);
      if (d > 0.01) {
        x += dx / d * velocidad * dt;
        y += dy / d * velocidad * dt;
      }
      girarHacia(atan2(dy, dx), dt);
      return;
    }

    if (estado == V_BUSCANDO) {
      // Se queda mirando a un lado y al otro
      tiempoBuscando -= dt;
      angulo = anguloBase + sin(tiempoBuscando * 2.2) * 1.3;
      if (tiempoBuscando <= 0) volverARonda();
      return;
    }

    if (camino.size() > 0) {
      int[] c = camino.get(0);
      float dx = c[0] + 0.5 - x;
      float dy = c[1] + 0.5 - y;
      float d = sqrt(dx * dx + dy * dy);
      if (d < 0.05) {
        camino.remove(0);
      } else {
        float paso = min(d, velocidad * dt);
        x += dx / d * paso;
        y += dy / d * paso;
        girarHacia(atan2(dy, dx), dt);
      }
      return;
    }

    // Llego al final del camino
    if (estado == V_PATRULLA) {
      tiempoQuieto += dt;
      if (tiempoQuieto > 1.2) {
        tiempoQuieto = 0;
        indiceRuta = (indiceRuta + 1) % ruta.length;
        irA(ruta[indiceRuta][0], ruta[indiceRuta][1]);
      }
    } else if (estado == V_SOSPECHA) {
      if (cuerpoPorDespertar != null) {
        if (dist(x, y, cuerpoPorDespertar.x, cuerpoPorDespertar.y) < 1.8) despertar(cuerpoPorDespertar);
        cuerpoPorDespertar = null;
      }
      if (tableroPendiente >= 0) {
        int[] t = mapa.tableros.get(tableroPendiente);
        if (dist(x, y, t[0] + 0.5, t[1] + 0.5) < 2) prenderTablero(tableroPendiente);
        tableroPendiente = -1;
      }
      estado = V_BUSCANDO;
      tiempoBuscando = apurado ? 5 : 3.5;   // si vino por una botella, revisa mas rato
      if (apurado) sospecha = min(sospecha, 25);   // la botella le hizo olvidar lo que habia visto
      apurado = false;
      anguloBase = angulo;
    } else if (estado == V_ALERTA && jugadorVisto != null) {
      girarHacia(atan2(jugadorVisto.y - y, jugadorVisto.x - x), dt);
    }
  }

  // Llega al compañero noqueado y lo levanta: los dos quedan buscando
  void despertar(Persona q) {
    q.inconsciente = false;
    q.cuerpoEscondido = false;
    if (q.arrastradoPor != null) soltarCuerpo(q.arrastradoPor);
    if (q instanceof Vigilante) {
      Vigilante v = (Vigilante) q;
      v.estado = V_BUSCANDO;
      v.tiempoBuscando = 4;
      v.anguloBase = v.angulo;
      v.sospecha = 60;
      v.radioSonando = -1;
      v.radioTerminada = true;
      for (Jugador jj : jugadores) {
        if (jj.contestando == v) jj.contestando = null;
      }
    } else {
      ((Civil) q).despertar();
    }
    avisar("Despertaron al que noqueaste");
  }

  // Radio (ver Radio.pde)
  float esperaRadio = -1;    // segundos hasta que la central llame
  float radioSonando = -1;   // segundos que le quedan sonando (-1 no suena)
  float tiempoPitido;
  boolean radioTerminada;    // ya se contesto o ya fallo

  void empezarRadio() {
    esperaRadio = ESPERA_RADIO;
    radioSonando = -1;
    radioTerminada = false;
  }

  void actualizarRadio(float dt) {
    actualizarRadioDe(this, dt);
  }

  void girarHacia(float objetivoAngulo, float dt) {
    float giro = 6 * dt;
    angulo += constrain(diferenciaAngulo(objetivoAngulo, angulo), -giro, giro);
  }
}
