// Un jugador infiltrado. Se mueve con cuatro teclas, puede correr (mas rapido
// pero hace mucho ruido) o agacharse (lento pero casi no suena y cuesta mas
// verlo). Tambien puede meterse en un armario para que no lo vean.
class Jugador {
  final float RADIO = 0.25;   // tamano para chocar con paredes y muebles
  int numero;
  float x, y;
  float dirX = 1, dirY = 1;   // hacia donde mira (en la cuadricula)
  boolean agachado, corriendo, escondido, moviendose;
  boolean pulsoUsar;          // presiono "usar" en este cuadro
  int pruebas;                // cosas de botin que lleva encima
  int peso, valorBotin;       // kilos en la mochila y lo que valen (Mochila.pde)
  java.util.ArrayDeque<Integer> mochila = new java.util.ArrayDeque<Integer>();   // pila: lo ultimo guardado sale primero
  int botellas;               // para lanzar y distraer
  // Ducto de ventilacion
  boolean enDucto;
  int rejillaOrigen, opcionDucto;
  ArrayList<Integer> destinosDucto;
  int[] distanciasDucto;
  float esperaDucto, viajeDucto;
  float tiempoPaso;
  color ropa;
  Persona arrastrando;        // cuerpo que va arrastrando (o null)
  boolean disfrazado, disfrazQuemado, avisoZona;
  // Rol (Roles.pde)
  int rol;
  // Cooperativo: esposado esperando que lo suelten (Rescate.pde)
  boolean atrapado;
  float tiempoAtrapado, progresoSoltar;
  float enfriamiento, sombra, efectoHabilidad, hackeoX, hackeoY;   // uniforme de conserje (Disfraz.pde)
  // Contestando la radio de un vigilante noqueado (Radio.pde)
  Vigilante contestando;
  int[] secuenciaRadio;
  int pasoRadio, llamada;

  Jugador(int numero, float x, float y, color ropa) {
    this.numero = numero;
    this.x = x;
    this.y = y;
    this.ropa = ropa;
  }

  // ix, iy son la direccion en pantalla (derecha y abajo positivos).
  // En isometrico "arriba en pantalla" es ir hacia -x y -y a la vez, por eso
  // se gira la direccion antes de mover.
  void actualizar(float dt, float ix, float iy, boolean correr) {
    moviendose = false;
    corriendo = false;
    if (escondido || contestando != null || atrapado) return;   // quieto en la radio o esposado
    float gx = ix + iy;
    float gy = iy - ix;
    float largo = sqrt(gx * gx + gy * gy);
    if (largo == 0) return;
    gx /= largo;
    gy /= largo;
    corriendo = correr && !agachado && arrastrando == null;
    float velocidad = 2.6;
    if (agachado) velocidad = velocidadAgachado(this);
    if (corriendo) velocidad = 4.2;
    if (arrastrando != null) velocidad = 1.3;   // un cuerpo pesa
    velocidad *= factorPeso(this);
    // Se mueve por separado en x y en y para poder deslizarse por las paredes
    float dx = gx * velocidad * dt;
    float dy = gy * velocidad * dt;
    if (!mapa.chocaCaja(x + dx, y, RADIO)) x += dx;
    if (!mapa.chocaCaja(x, y + dy, RADIO)) y += dy;
    dirX = gx;
    dirY = gy;
    moviendose = true;
    // Cada cierto tiempo los pasos hacen un ruido que oyen los vigilantes
    tiempoPaso -= dt;
    if (tiempoPaso <= 0) {
      tiempoPaso = 0.35;
      if (radioRuido() > 0) {
        hacerRuido(x, y, radioRuido());
        sonar(corriendo ? "paso_correr" : "paso");
      }
    }
  }

  // Hasta donde se oyen los pasos ahora mismo (en baldosas)
  float radioRuido() {
    if (escondido || !moviendose) return 0;
    if (agachado) return 0;     // agachado no hace ningun ruido, cargue lo que cargue
    if (arrastrando != null) return 1.0;
    if (corriendo) return 3.2 + ruidoPeso(this);
    // los pasos de un conserje que camina no le llaman la atención a nadie:
    // se ven en el dibujo pero ningún vigilante va a revisar
    if (disfrazado) return 0.9;
    return 1.4 + ruidoPeso(this);
  }

  void cambiarPostura() {
    if (!escondido && arrastrando == null) agachado = !agachado;
  }

  boolean usandoMantenido() {
    if (numero == 1) return letras['e'];
    return teclaEnter;
  }

  String teclaHabilidad() {
    return numero == 1 ? "F" : "M";
  }

  String postura() {
    String p = posturaSola();
    return disfrazado ? "Conserje · " + p : p;
  }

  String posturaSola() {
    if (atrapado) return "¡Esposado! " + ceil(tiempoAtrapado) + " s";
    if (enDucto) return "En el ducto";
    if (contestando != null) return "En la radio";
    if (arrastrando != null) return "Arrastrando";
    if (escondido) return "Escondido";
    if (corriendo) return "Corriendo";
    if (agachado) return "Agachado";
    if (moviendose) return "Caminando";
    return "Quieto";
  }

  String teclaUsar() {
    return numero == 1 ? "E" : "Enter";
  }
}

// Un ruido es un circulo que se agranda y desaparece. Solo es para dibujarlo:
// el aviso a los vigilantes se hace una sola vez en hacerRuido().
class Ruido {
  float x, y, radio;
  float vida = 1;

  Ruido(float x, float y, float radio) {
    this.x = x;
    this.y = y;
    this.radio = radio;
  }

  boolean actualizar(float dt) {
    vida -= dt / 0.7;
    return vida > 0;
  }
}

// Botella lanzada: vuela en arco desde (x0, y0) hasta (x1, y1)
class Proyectil {
  float x0, y0, x1, y1;
  float t = 0;
  float duracion;

  Proyectil(float x0, float y0, float x1, float y1) {
    this.x0 = x0;
    this.y0 = y0;
    this.x1 = x1;
    this.y1 = y1;
    duracion = 0.25 + dist(x0, y0, x1, y1) * 0.08;
  }

  float x() {
    return lerp(x0, x1, t / duracion);
  }

  float y() {
    return lerp(y0, y1, t / duracion);
  }

  // altura del arco en pixeles del dibujo
  float altura() {
    float u = t / duracion;
    return 4 * u * (1 - u) * 22;
  }
}

// Vidrio que salta cuando se rompe una botella (solo se ve)
class Particula {
  float x, y, vx, vy, vida;
  color c = color(140, 255, 190);   // vidrio verde por defecto

  Particula(float x, float y) {
    this.x = x;
    this.y = y;
    float a = random(TWO_PI);
    float v = random(0.6, 1.8);
    vx = cos(a) * v;
    vy = sin(a) * v;
    vida = random(0.3, 0.6);
  }

  boolean actualizar(float dt) {
    x += vx * dt;
    y += vy * dt;
    vida -= dt;
    return vida > 0;
  }
}
