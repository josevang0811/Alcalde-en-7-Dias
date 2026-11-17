import javax.sound.sampled.*;

// Infiltrado — la mision de sigilo de la ronda 2, dentro de Alcalde Digital.
//
// Es el sketch InfiltradoPrueba completo metido en una sola clase: asi sus
// variables (estado, escala, mapa...) y sus funciones no chocan con las del
// juego principal, que tiene unas con el mismo nombre. setup() se llama
// prepararMision(), draw() se llama dibujar() y las teclas llegan por
// teclaPresionada() y teclaSoltada(). El juego principal la crea una vez,
// le pasa los datos de la campana con configurarCampana() y, al terminar,
// la mision llama a volverALaCampana() (MisionCampana.pde).
//
// No se edita a mano: se arma con herramientas/fusionar.py a partir de la
// carpeta InfiltradoPrueba (cada parte lleva arriba el nombre de su archivo).

class Infiltrado {

// ======================================================================
// InfiltradoPrueba.pde
// ======================================================================

// InfiltradoPrueba
// Prueba aparte del modo "Infiltrado" de Alcalde Digital. El candidato se mete
// de noche a la sede de "Titulares Ya", la agencia que fabrica los bulos, para
// copiar su servidor y salir sin que lo atrapen.
//
// Arte: pixel art "neon nocturno" (sprites en la carpeta data/).
// El mapa de la sede (44 x 32) se lee de data/mapa/ (capas en CSV como las de Tiled).
// Vista isometrica estilo Project Zomboid: paredes con altura que se recortan
// cuando tapan al jugador, zonas oscuras y luz de lamparas. Todo el mapa y los
// vigilantes se ven siempre: el reto es leer las rondas y elegir el momento.
// Antes de entrar hay una fase de reconocimiento con el plano completo.
// Por dentro el mapa es una cuadricula normal: la vista, el ruido y los
// caminos de los vigilantes (BFS) se calculan sobre la cuadricula y solo el
// dibujo se pasa a isometrico.

final int INICIO = 0;
final int JUGANDO = 1;
final int GANASTE = 2;
final int PERDISTE = 3;
final int RECONOCIMIENTO = 4;
final int ELEGIR_ROL = 5;

// Estados de un vigilante
final int V_PATRULLA = 0;
final int V_SOSPECHA = 1;
final int V_BUSCANDO = 2;
final int V_ALERTA = 3;

int estado = INICIO;
int numJugadores = 1;

float escala;          // 1 = pantalla de 1280x720 (para textos e interfaz)
int pixel;             // cuantas veces se agranda el pixel art (2 en 720p, 3 en 1080p)
float anchoBaldosa;    // ancho del rombo de una baldosa en pantalla
float altoBaldosa;     // alto del rombo (la mitad del ancho)
float altoPared;
float camX, camY;      // punto de la cuadricula que queda en el centro de la pantalla
float zoom = 1;        // 1 = normal; en el reconocimiento se aleja para ver todo

Mapa mapa;
ArrayList<Jugador> jugadores = new ArrayList<Jugador>();
ArrayList<Vigilante> vigilantes = new ArrayList<Vigilante>();
ArrayList<CamaraSeguridad> camaras = new ArrayList<CamaraSeguridad>();
ArrayList<Ruido> ruidos = new ArrayList<Ruido>();
ArrayList<Proyectil> proyectiles = new ArrayList<Proyectil>();
ArrayList<Particula> particulas = new ArrayList<Particula>();
ArrayList<Civil> civiles = new ArrayList<Civil>();

final float TIEMPO_COPIA = 7;   // segundos que tarda copiar el servidor (un jugador)
final float TIEMPO_RECONOCIMIENTO = 15;
final float RADIO_LANZAMIENTO = 7;   // hasta donde llega una botella (baldosas)
final float RUIDO_BOTELLA = 13;         // radio del ruido al romperse (atrae desde lejos)

boolean[] tarjetas = new boolean[5];   // 1 roja, 2 azul, 3 amarilla, 4 codigo (se comparten en cooperativo)
boolean chatLeido, tableroVisto, cuadernoVisto;   // lo que se reviso en la oficina del rival
int ventana;          // 0 nada, 1 chat del rival, 2 tablero de conspiracion, 3 cuaderno, 4 TV
Jugador quienLee;
float progresoServidor;
boolean servidorCopiado;
int pruebasExtraidas;
int valorExtraido;
int vecesDescubierto;
int nivelAlarma;      // 0 a 3: sube cada vez que algo sale mal
float tiempoMision;
float tiempoReconocimiento;
float tiempoZumbido;
float destelloAlarma;
boolean verRutas;
String aviso = "";
float tiempoAviso;
String motivoFin = "";
int ultimoMillis;

PFont letraChica, letraMedia, letraGrande, letraTitulo;

// Teclas que se mantienen presionadas
boolean[] letras = new boolean[256];
boolean flechaArriba, flechaAbajo, flechaIzq, flechaDer;
boolean teclaShift, teclaEnter;

void prepararMision() {
  escala = height / 720.0;
  pixel = max(1, round(height / 360.0));
  anchoBaldosa = 32 * pixel;
  altoBaldosa = 16 * pixel;
  altoPared = 28 * pixel;
  cargarSprites();
  letraChica = createFont("DejaVuSansMono.ttf", 12 * escala);
  letraMedia = createFont("DejaVuSansMono.ttf", 15 * escala);
  letraGrande = createFont("DejaVuSansMono-Bold.ttf", 22 * escala);
  letraTitulo = createFont("DejaVuSansMono-Bold.ttf", 46 * escala);
  iniciarMision();
  iniciarAudio();
  prepararHudPixel();
  iniciarValeria();
  prepararRespaldo();
    ultimoMillis = millis();
}

void dibujar() {
  int ahora = millis();
  float dt = min((ahora - ultimoMillis) / 1000.0, 0.05);
  ultimoMillis = ahora;

  if (estado == JUGANDO && !mapaAbierto) actualizar(dt);   // con el mapa abierto, en pausa
  if (estado == RECONOCIMIENTO) actualizarReconocimiento(dt);
  mapa.actualizarCortes(jugadores, dt);
  actualizarMusica();
  actualizarJugo(dt);
  if (estado == LLAMADA) actualizarLlamada(dt);
  actualizarValeria(dt);
  if (estado == JUGANDO && !mapaAbierto) actualizarResaltes(dt);
  moverCamara(dt);

  background(COLOR_FONDO);
  // El zoom se aplica alrededor del centro de la pantalla
  pushMatrix();
  aplicarTemblor();
  translate(width / 2, height / 2);
  scale(zoom);
  translate(-width / 2, -height / 2);
  dibujarMundo();
  if (estado == RECONOCIMIENTO || (estado == JUGANDO && mapaAbierto)) dibujarPlano();
  if (estado == JUGANDO && mapaAbierto) dibujarMarcasMapa();
  popMatrix();
  dibujarHud(dt);
  if (estado == INICIO) dibujarPantallaInicio();
  if (estado == ELEGIR_ROL) dibujarElegirRol();
  if (estado == CREDITOS) {
    actualizarCreditos(dt);
    dibujarCreditos();
  }
  if (estado == GANASTE || estado == PERDISTE) dibujarPantallaFinal();
  if (estado == LLAMADA) dibujarLlamada();
  dibujarValeria();
}

// ---------------------------------------------------------------------------
// Preparar la mision
// ---------------------------------------------------------------------------

void iniciarMision() {
  mapa = new Mapa("mapa");
  jugadores.clear();
  jugadores.add(new Jugador(1, mapa.inicioX[0], mapa.inicioY[0], NEON_CIAN));
  if (numJugadores == 2) {
    jugadores.add(new Jugador(2, mapa.inicioX[1], mapa.inicioY[1], NEON_VERDE));
  }
  // el jugador 1 tiene el rol elegido y el 2 (si hay) el otro
  jugadores.get(0).rol = rolElegido;
  if (jugadores.size() > 1) jugadores.get(1).rol = 1 - rolElegido;

  // Cada vigilante recibe su ronda como una lista de baldosas (columna, fila).
  // Entre un punto y el siguiente el camino lo busca BFS.
  vigilantes.clear();
  for (String[] p : mapa.lineasVigilantes) {
    color c = unhex("FF" + p[1]);
    int[][] ruta = new int[p.length - 2][2];
    for (int k = 2; k < p.length; k++) {
      String[] xy = split(p[k], ',');
      ruta[k - 2][0] = int(xy[0]);
      ruta[k - 2][1] = int(xy[1]);
    }
    Vigilante v = new Vigilante(variarRonda(ruta), c);
    v.esJefe = p[0].equals("jefe");
    vigilantes.add(v);
  }
  // Empleados: "civil <civil|civil2> x,y x,y ..." (los puestos donde trabajan)
  civiles.clear();
  for (String[] p : mapa.lineasCiviles) {
    int[][] ruta = new int[p.length - 2][2];
    for (int k = 2; k < p.length; k++) {
      String[] xy = split(p[k], ',');
      ruta[k - 2][0] = int(xy[0]);
      ruta[k - 2][1] = int(xy[1]);
    }
    Civil cv = new Civil(variarRonda(ruta), p[1].equals("civil2") ? spritesCivil2 : spritesCivil);
    civiles.add(cv);
  }
  camaras.clear();
  for (float[] c : mapa.datosCamaras) {
    CamaraSeguridad cam = new CamaraSeguridad(c[0], c[1], c[2], c[3]);
    cam.t = random(TWO_PI);   // cada mision arranca en otro punto del giro
    cam.girar(0);
    camaras.add(cam);
  }

  escondites.clear();
  nivelAlarma = 0;
  alarmaMaxima = 0;
  noqueos = 0;
  radiosContestadas = 0;
  camarasApagadas = 0;
  enfriarCamaras = 0;
  grabacionesBorradas = false;
  mostrarObjetos = 0;
  salidaUsada = -1;
  camarasEnBucle = false;
  progresoEmpujar = 0;
  tiempoPolicia = 0;
  prepararCodigo();
  mapaAbierto = false;
  resalteZona = new float[NOMBRES_ZONA.length];
  prepararOportunidades();
  leerCampana();
  aplicarHerramientas();
  prepararCharlas();
  mejorBotin = calcularMejorBotin();
  reiniciarValeria();
  ultimaSubida = -99;
  avisoAmanecer = false;
  ruidos.clear();
  proyectiles.clear();
  particulas.clear();
  textosFlotantes.clear();
  temblor = 0;
  tarjetas = new boolean[5];
  chatLeido = false;
  tableroVisto = false;
  cuadernoVisto = false;
  ventana = 0;
  progresoServidor = 0;
  servidorCopiado = false;
  pruebasExtraidas = 0;
  vecesDescubierto = 0;
  tiempoMision = 0;
  destelloAlarma = 0;
  verRutas = false;
  aviso = "";
  tiempoAviso = 0;
  camX = mapa.inicioX[0];
  camY = mapa.inicioY[0];
  zoom = 1;
}

// Al elegir 1 o 2 jugadores primero viene el reconocimiento: la camara se
// aleja para mostrar toda la sede y se dibujan las rondas de los vigilantes.
void empezar(int cuantos) {
  numJugadores = cuantos;
  iniciarMision();
  // la primera vez, antes del reconocimiento llama Valeria (Llamada.pde)
  if (valeriaActiva && !llamadaHecha) {
    empezarLlamada();
    return;
  }
  irAlReconocimiento();
}

void irAlReconocimiento() {
  estado = RECONOCIMIENTO;
  tiempoReconocimiento = tiempoReconocimientoTotal();
  camX = centroPlanoX();
  camY = centroPlanoY();
  zoom = zoomPlano();
}

// Durante el reconocimiento los vigilantes y las camaras se mueven, pero no
// detectan a nadie y el reloj de la mision no corre.
void actualizarReconocimiento(float dt) {
  tiempoReconocimiento -= dt;
  for (Vigilante v : vigilantes) v.mover(dt);
  for (Civil c : civiles) c.moverRutina(dt);
  for (CamaraSeguridad c : camaras) c.girar(dt);
  if (tiempoReconocimiento <= 0) entrar();
}

void entrar() {
  estado = JUGANDO;
  avisar("Revisa la sede y al final copia el servidor: después solo queda escapar");
}

// Zoom con el que cabe toda la sede en la pantalla
float zoomPlano() {
  float anchoMapa = (mapa.ancho + mapa.alto) * anchoBaldosa / 2;
  float altoMapa = (mapa.ancho + mapa.alto) * altoBaldosa / 2 + altoPared;
  return min(width * 0.96 / anchoMapa, (height - 170 * escala) / altoMapa);
}

// Un poco corrido hacia arriba en la cuadricula para que el plano quede bajo
// el panel de arriba
float centroPlanoX() {
  return mapa.ancho / 2.0 - 1.5;
}

float centroPlanoY() {
  return mapa.alto / 2.0 - 1.5;
}

// ---------------------------------------------------------------------------
// Un cuadro de juego
// ---------------------------------------------------------------------------

void actualizar(float dt) {
  tiempoMision += dt;
  destelloAlarma = max(0, destelloAlarma - dt * 1.5);

  // Jugador 1: WASD, Shift corre
  Jugador j1 = jugadores.get(0);
  float ix = (letras['d'] ? 1 : 0) - (letras['a'] ? 1 : 0);
  float iy = (letras['s'] ? 1 : 0) - (letras['w'] ? 1 : 0);
  if (usandoConsola(j1) || usandoTeclado(j1)) ix = iy = 0;
  j1.actualizar(dt, ix, iy, teclaShift);

  // Jugador 2: flechas, la tecla "-" corre
  if (jugadores.size() > 1) {
    Jugador j2 = jugadores.get(1);
    float ix2 = (flechaDer ? 1 : 0) - (flechaIzq ? 1 : 0);
    float iy2 = (flechaAbajo ? 1 : 0) - (flechaArriba ? 1 : 0);
    if (usandoConsola(j2) || usandoTeclado(j2)) ix2 = iy2 = 0;
    j2.actualizar(dt, ix2, iy2, letras['-']);
  }

  // Si quien esta leyendo algo se mueve, la ventana se cierra (la consola
  // no: mientras se usa, el jugador se queda quieto)
  if (ventana != 0 && ventana != 5 && ventana != 6 && quienLee != null && quienLee.moviendose) ventana = 0;

  for (Jugador j : jugadores) {
    if (j.pulsoUsar) {
      usar(j);
      j.pulsoUsar = false;
    }
    actualizarDucto(j, dt);
    revisarZonaDisfraz(j);
  }

  actualizarArrastres(dt);
  actualizarRoles(dt);
  actualizarRescates(dt);
  actualizarEquipo(dt);
  actualizarOportunidades(dt);
  if (estado != JUGANDO) return;
  actualizarSeguridad(dt);
  actualizarAlarma(dt);
  actualizarTeclado(dt);
  actualizarCharlas(dt);
  if (estado != JUGANDO) return;
  actualizarServidor(dt);
  actualizarProyectiles(dt);

  for (int k = ruidos.size() - 1; k >= 0; k--) {
    if (!ruidos.get(k).actualizar(dt)) ruidos.remove(k);
  }
  for (Vigilante v : vigilantes) {
    v.actualizar(dt);
    if (estado != JUGANDO) return;   // alguien fue atrapado
  }
  for (Civil c : civiles) {
    c.actualizar(dt);
  }
  for (CamaraSeguridad c : camaras) {
    c.actualizar(dt);
  }
}

// Lo que pasa al presionar "usar" (E o Enter). Se revisa en orden: lo que
// esta mas cerca y es mas especifico va primero.
void usar(Jugador j) {
  if (j.enDucto) {
    cambiarDestinoDucto(j);
    return;
  }
  if (j.escondido) {
    j.escondido = false;
    avisar("Saliste del armario");
    return;
  }
  if (j.atrapado) return;
  if (companeroAtrapado(j) != null) return;   // soltarlo es mantener usar (Rescate.pde)
  if (usandoConsola(j)) {
    elegirOpcionConsola();
    return;
  }
  if (usandoTeclado(j)) {
    ventana = 0;
    return;
  }
  if (ventana != 0) {
    ventana = 0;
    return;
  }
  if (j.contestando != null) return;
  // La radio de un vigilante noqueado va primero: hay poco tiempo
  Vigilante radio = radioCercana(j);
  if (radio != null) {
    contestarRadio(j, radio);
    return;
  }
  // Con el servidor copiado, en una salida se escapa (Salidas.pde)
  if (intentarSalir(j)) return;
  // Cuerpos: esconder o soltar el que se arrastra, noquear, empezar a arrastrar
  if (j.arrastrando != null) {
    int[] lugar = esconditeParaCuerpo(j);
    if (lugar != null) esconderCuerpo(j, lugar);
    else soltarCuerpo(j);
    return;
  }
  Persona victima = aQuienNoquear(j);
  if (victima != null) {
    noquearPersona(j, victima);
    return;
  }
  Persona cuerpo = cuerpoCercano(j);
  if (cuerpo != null) {
    empezarArrastre(j, cuerpo);
    return;
  }
  // Cosas que se recogen
  int[] botin = botinCercano(j);
  if (botin != null) {
    guardarBotin(j, botin);
    return;
  }
  if (!soloEscapar() && recoger(j, 'r', "Tienes la tarjeta roja: abre la puerta de carga")) {
    tarjetas[1] = true;
    return;
  }
  if (!soloEscapar() && recoger(j, 'b', "Tienes la tarjeta azul: abre el cuarto de seguridad")) {
    tarjetas[2] = true;
    return;
  }
  if (!soloEscapar() && recoger(j, 'y', "Tienes la tarjeta amarilla: abre la oficina del rival")) {
    tarjetas[3] = true;
    return;
  }
  if (!soloEscapar() && recoger(j, 'n', "")) {
    conocerDigitos(0, 1, "Una nota con el código del servidor");
    return;
  }
  if (recoger(j, 'o', "Tomaste una botella (" + (j.numero == 1 ? "Q" : ",") + " para lanzarla)")) {
    j.botellas += 2;
    return;
  }
  // Puertas cerradas
  int[] puerta = mapa.puertaCercana(j.x, j.y, 1.3);
  if (puerta != null) {
    int k = mapa.celdas[puerta[0]][puerta[1]] - '0';
    if (k == 4) {
      abrirTeclado(j, puerta);
    } else if (tarjetas[k]) {
      mapa.abrirPuerta(puerta[0], puerta[1]);
      sonar("tarjeta");
      sonar("puerta");
      avisar(k == 4 ? "Marcaste el código: la puerta se abrió" : "Abriste la puerta " + NOMBRES_TARJETA[k]);
    } else if (jugadores.size() > 1 && puerta[0] == PESADA_I && puerta[1] == PESADA_J) {
      avisar("Sin tarjeta: empújenla los dos a la vez (mantengan usar)");
    } else {
      sonar("negado");
      avisar("Necesitas la tarjeta " + NOMBRES_TARJETA[k]);
    }
    return;
  }
  // Ductos de ventilacion
  int[] rejilla = mapa.cercano(j.x, j.y, 'v', 1.1);
  if (rejilla != null) {
    entrarDucto(j, mapa.rejillaEn(rejilla[0], rejilla[1]));
    return;
  }
  // Tablero electrico
  int[] tablero = mapa.cercano(j.x, j.y, 'T', 1.4);
  if (tablero != null) {
    cambiarLuces(tablero[0], tablero[1]);
    return;
  }
  // Oportunidades ya descubiertas (Oportunidades.pde)
  if (usarOportunidad(j)) return;
  // La oficina del rival
  if (!soloEscapar() && mapa.cercano(j.x, j.y, 'O', 1.6) != null) {
    abrirVentana(j, 1);
    if (!chatLeido) avisar("Ahora sabes cuál será su próximo bulo");
    chatLeido = true;
    descubrirOportunidad(0);
    return;
  }
  if (!soloEscapar() && mapa.cercano(j.x, j.y, 'X', 1.9) != null) {
    abrirVentana(j, 2);
    tableroVisto = true;
    descubrirOportunidad(1);
    return;
  }
  if (!soloEscapar() && mapa.cercano(j.x, j.y, 'U', 1.6) != null) {
    abrirVentana(j, 3);
    cuadernoVisto = true;
    descubrirOportunidad(2);
    return;
  }
  if (!soloEscapar() && mapa.cercano(j.x, j.y, 'W', 1.9) != null) {
    abrirVentana(j, 4);
    return;
  }
  if (puedeTomarUniforme(j)) {
    ponerseUniforme(j);
    return;
  }
  if (!soloEscapar() && mapa.cercano(j.x, j.y, 'Q', 1.5) != null) {
    abrirConsola(j);
    return;
  }
  int[] armario = mapa.cercano(j.x, j.y, 'A', 1.3);
  if (armario != null) {
    if (esconditeOcupado(armario[0], armario[1])) {
      avisar("Ese armario ya tiene un cuerpo adentro");
    } else if (alguienLoEstaViendo(j)) {
      avisar("No puedes esconderte: te están viendo");
    } else {
      j.escondido = true;
      j.agachado = false;
      avisar("Escondido en el armario. Presiona otra vez para salir");
    }
  }
}

boolean recoger(Jugador j, char tipo, String mensaje) {
  int[] p = mapa.cercano(j.x, j.y, tipo, 1.2);
  if (p == null) return false;
  mapa.celdas[p[0]][p[1]] = '.';
  avisar(mensaje);
  sonar("rby".indexOf(tipo) >= 0 ? "tarjeta" : "recoger");
  chispas(p[0] + 0.5, p[1] + 0.5, tipo == 'r' ? COLOR_RIVAL : (tipo == 'b' ? #3E7BFF : (tipo == 'y' ? COLOR_AMBAR : NEON_VERDE)), 10);
  return true;
}

void abrirVentana(Jugador j, int cual) {
  ventana = cual;
  quienLee = j;
}

boolean alguienLoEstaViendo(Jugador j) {
  for (Vigilante v : vigilantes) {
    if (v.jugadorVisto == j && v.sospecha > 30) return true;
  }
  return false;
}

// ---------------------------------------------------------------------------
// Ductos de ventilacion
// ---------------------------------------------------------------------------

// Al entrar, Dijkstra calcula cuanto se tarda hasta cada rejilla del ducto.
// Mientras esta adentro, "usar" cambia el destino; si no se toca nada en un
// segundo y medio, el jugador gatea hasta alla sin que nadie lo vea.
void entrarDucto(Jugador j, int rejilla) {
  int[] dist = mapa.distanciasDucto(rejilla);
  ArrayList<Integer> destinos = new ArrayList<Integer>();
  for (int k = 0; k < dist.length; k++) {
    if (k != rejilla && dist[k] != Integer.MAX_VALUE) destinos.add(k);
  }
  if (destinos.size() == 0) return;
  j.enDucto = true;
  sonar("ducto");
  j.escondido = true;
  j.rejillaOrigen = rejilla;
  j.destinosDucto = destinos;
  j.distanciasDucto = dist;
  j.opcionDucto = 0;
  j.esperaDucto = 1.5;
  j.viajeDucto = -1;
  avisar("Dentro del ducto. " + j.teclaUsar() + " para elegir a dónde ir");
}

void cambiarDestinoDucto(Jugador j) {
  if (j.viajeDucto >= 0) return;   // ya va gateando
  j.opcionDucto = (j.opcionDucto + 1) % j.destinosDucto.size();
  j.esperaDucto = 1.5;
}

void actualizarDucto(Jugador j, float dt) {
  if (!j.enDucto) return;
  if (j.viajeDucto < 0) {
    j.esperaDucto -= dt;
    if (j.esperaDucto <= 0) {
      int destino = j.destinosDucto.get(j.opcionDucto);
      j.viajeDucto = j.distanciasDucto[destino] * 0.22;   // segundos gateando
    }
    return;
  }
  j.viajeDucto -= dt;
  if (j.viajeDucto <= 0) {
    int[] r = mapa.rejillas.get(j.destinosDucto.get(j.opcionDucto));
    j.x = r[0] + 0.5;
    j.y = r[1] + 0.5;
    j.enDucto = false;
    sonar("ducto");
    j.escondido = false;
    avisar("Saliste del ducto en " + NOMBRES_ZONA[mapa.zonaEn(j.x, j.y)]);
  }
}

// ---------------------------------------------------------------------------
// Tableros electricos
// ---------------------------------------------------------------------------

// Cortar la luz deja una zona en la sombra (cuesta mas verte), pero el
// vigilante mas cercano va a revisar el tablero y la vuelve a prender.
void cambiarLuces(int ti, int tj) {
  int k = indiceTablero(ti, tj);
  if (k < 0) return;
  if (tablerosBloqueados()) {
    avisar("Seguridad bloqueó los tableros eléctricos");
    return;
  }
  int[] zs = mapa.zonasTablero.get(k);
  boolean apagar = !mapa.zonaApagada[zs[0]];
  sonar("interruptor");
  String nombres = "";
  for (int z : zs) {
    mapa.zonaApagada[z] = apagar;
    nombres += (nombres.equals("") ? "" : " y ") + NOMBRES_ZONA[z];
  }
  mapa.calcularLuz();
  if (!apagar) {
    avisar("Prendiste la luz de " + nombres);
    return;
  }
  avisar("Cortaste la luz de " + nombres + ". Alguien vendrá a revisar");
  hacerRuido(ti + 0.5, tj + 0.5, 2.0);
  // el vigilante mas cercano (por camino, no en linea recta) va al tablero
  Vigilante elegido = null;
  int mejor = Integer.MAX_VALUE;
  for (Vigilante v : vigilantes) {
    if (v.estado == V_ALERTA || v.inconsciente) continue;
    int largo = mapa.caminoBFS(floor(v.x), floor(v.y), ti, tj).size();
    if (largo > 0 && largo < mejor) {
      mejor = largo;
      elegido = v;
    }
  }
  if (elegido != null) elegido.irATablero(k, ti, tj);
}

int indiceTablero(int i, int j) {
  for (int k = 0; k < mapa.tableros.size(); k++) {
    if (mapa.tableros.get(k)[0] == i && mapa.tableros.get(k)[1] == j) return k;
  }
  return -1;
}

void prenderTablero(int k) {
  int[] zs = mapa.zonasTablero.get(k);
  if (!mapa.zonaApagada[zs[0]]) return;
  for (int z : zs) mapa.zonaApagada[z] = false;
  mapa.calcularLuz();
  avisar("Un vigilante volvió a prender la luz");
}

// ---------------------------------------------------------------------------
// Botellas
// ---------------------------------------------------------------------------

// Se lanza hacia donde mira el jugador, hasta 4.5 baldosas o hasta la primera
// pared. Al caer hace ruido y el vigilante que la oiga va a revisar.
void lanzar(Jugador j) {
  if (j.escondido || j.arrastrando != null) return;
  if (j.botellas <= 0) {
    avisar("No tienes botellas. Busca alguna tirada por ahí");
    return;
  }
  j.botellas--;
  sonar("lanzar");
  float ang = atan2(j.dirY, j.dirX);
  float largo = max(0.6, alcanceRayo(j.x, j.y, ang, RADIO_LANZAMIENTO) - 0.4);
  proyectiles.add(new Proyectil(j.x, j.y, j.x + cos(ang) * largo, j.y + sin(ang) * largo));
}

void actualizarProyectiles(float dt) {
  for (int k = proyectiles.size() - 1; k >= 0; k--) {
    Proyectil p = proyectiles.get(k);
    p.t += dt;
    if (p.t >= p.duracion) {
      ruidoBotella(p.x1, p.y1);
      sonar("botella");
      sacudir(2);
      for (int q = 0; q < 10; q++) particulas.add(new Particula(p.x1, p.y1));
      proyectiles.remove(k);
    }
  }
  for (int k = particulas.size() - 1; k >= 0; k--) {
    if (!particulas.get(k).actualizar(dt)) particulas.remove(k);
  }
}

// ---------------------------------------------------------------------------
// Servidor, salida, ruido y alarma
// ---------------------------------------------------------------------------

// Copiar el servidor: hay que mantener presionado "usar" junto a el.
// Mientras copia, el ventilador hace ruido cada cierto tiempo.
void actualizarServidor(float dt) {
  if (servidorCopiado) return;
  boolean copiando = false;
  for (Jugador j : jugadores) {
    if (j.escondido || !j.usandoMantenido()) continue;
    int[] s = mapa.cercano(j.x, j.y, 'S', 1.4);
    if (s != null) {
      progresoServidor += dt / TIEMPO_COPIA;
      copiando = true;
      tiempoZumbido -= dt;
      if (tiempoZumbido <= 0) {
        tiempoZumbido = 1.2;
        sonar("copiando");
        hacerRuido(s[0] + 0.5, s[1] + 0.5, 2.2);
      }
    }
  }
  if (copiando && progresoServidor >= 1) {
    progresoServidor = 1;
    servidorCopiado = true;
    sonar("servidor_listo");
    textoFlotante(jugadores.get(0).x, jugadores.get(0).y, "¡Copiado!", NEON_VERDE);
    for (Jugador jj : jugadores) chispas(jj.x, jj.y, NEON_VERDE, 14);
    avisar("¡Bulos copiados! Ya no hay nada más que hacer: escapa por la camioneta, la moto o el ducto");
  }
}

// Un ruido avisa a los vigilantes a los que llega. El sonido se reparte con
// BFS por los pasillos y puertas abiertas: una pared en medio lo frena.
void hacerRuido(float x, float y, float radio) {
  ruidos.add(new Ruido(x, y, radio));
  if (radio < 1) return;   // pasos agachado: se ven en el dibujo pero nadie los oye
  int maxPasos = ceil(radio * 1.3);
  int[][] pasos = null;
  for (Vigilante v : vigilantes) {
    if (dist(v.x, v.y, x, y) > maxPasos) continue;
    if (pasos == null) pasos = mapa.pasosRuido(x, y, maxPasos);
    v.escuchar(x, y, pasos);
  }
}

// Una botella rota se oye lejos y el vigilante que la oye va derecho y
// apurado a ese punto (el ruido igual se frena en paredes y puertas cerradas)
void ruidoBotella(float x, float y) {
  float radio = ruidoLanzamiento();
  ruidos.add(new Ruido(x, y, radio));
  int maxPasos = ceil(radio * 1.3);
  int[][] pasos = mapa.pasosRuido(x, y, maxPasos);
  int atraidos = 0;
  for (Vigilante v : vigilantes) {
    if (v.inconsciente) continue;
    if (v.estado == V_ALERTA && !DETECTADO_PIERDE) continue;
    int i = constrain(floor(v.x), 0, mapa.ancho - 1);
    int j = constrain(floor(v.y), 0, mapa.alto - 1);
    if (pasos[i][j] < 0) continue;
    v.irARuidoFuerte(x, y);
    atraidos++;
  }
  if (atraidos > 0) textoFlotante(x, y, atraidos == 1 ? "¡Va uno!" : "¡Van " + atraidos + "!", COLOR_AMBAR);
}

void sonarAlarma(float x, float y) {
  if (DETECTADO_PIERDE) {
    destelloAlarma = 1;
    sonar("descubierto");
    perder("Una cámara te vio");
    return;
  }
  subirAlarma("¡Una cámara te vio! Los vigilantes van para allá");
  for (Vigilante v : vigilantes) {
    v.alarma(x, y);
  }
}

void perder(String motivo) {
  if (estado != JUGANDO) return;
  motivoFin = motivo;
  estado = PERDISTE;
  sonar("derrota");
  escribirResultado(false);
}

void ganar() {
  pruebasExtraidas = 0;
  valorExtraido = 0;
  for (Jugador j : jugadores) {
    pruebasExtraidas += j.pruebas;
    valorExtraido += j.valorBotin;
  }
  if (oportunidadHecha[1]) valorExtraido += 3;   // la foto del tablero cuenta como prueba
  estado = GANASTE;
  sonar("victoria");
  escribirResultado(true);
}

// Los vigilantes y las camaras tienen su propio "estado", por eso para saber
// el de la partida desde adentro de esas clases se usa esta funcion.
boolean partidaEnCurso() {
  return estado == JUGANDO;
}

void avisar(String texto) {
  aviso = texto;
  tiempoAviso = 3.5;
}

// La camara sigue al punto medio entre los jugadores (o al unico jugador).
// En el reconocimiento se queda en el centro del plano y alejada.
void moverCamara(float dt) {
  float sx = 0, sy = 0;
  for (Jugador j : jugadores) {
    sx += j.x;
    sy += j.y;
  }
  sx /= jugadores.size();
  sy /= jugadores.size();
  float zoomMeta = 1;
  if (estado == RECONOCIMIENTO || (estado == JUGANDO && mapaAbierto)) {
    sx = centroPlanoX();
    sy = centroPlanoY();
    zoomMeta = zoomPlano();
  }
  float k = min(1, dt * 4);
  camX += (sx - camX) * k;
  camY += (sy - camY) * k;
  zoom += (zoomMeta - zoom) * k;
}

// Diferencia entre dos angulos, siempre entre -PI y PI
float diferenciaAngulo(float a, float b) {
  float d = a - b;
  while (d > PI) d -= TWO_PI;
  while (d < -PI) d += TWO_PI;
  return d;
}

// ---------------------------------------------------------------------------
// Teclado
// ---------------------------------------------------------------------------

void teclaPresionada() {
  if (key == CODED) {
    if (keyCode == UP) flechaArriba = true;
    if (keyCode == DOWN) flechaAbajo = true;
    if (keyCode == LEFT) flechaIzq = true;
    if (keyCode == RIGHT) flechaDer = true;
    if (keyCode == SHIFT) teclaShift = true;
    if (estado == ELEGIR_ROL && (keyCode == LEFT || keyCode == RIGHT)) rolElegido = 1 - rolElegido;
    // El jugador 2 elige en la consola con las flechas
    if (estado == JUGANDO && jugadores.size() > 1 && usandoConsola(jugadores.get(1))) {
      if (keyCode == UP) moverOpcionConsola(-1);
      if (keyCode == DOWN) moverOpcionConsola(1);
    }
    // El jugador 2 contesta la radio con las flechas
    if (estado == JUGANDO && jugadores.size() > 1 && jugadores.get(1).contestando != null) {
      if (keyCode == UP) teclaRadio(jugadores.get(1), 0);
      if (keyCode == RIGHT) teclaRadio(jugadores.get(1), 1);
      if (keyCode == DOWN) teclaRadio(jugadores.get(1), 2);
      if (keyCode == LEFT) teclaRadio(jugadores.get(1), 3);
    }
    return;
  }
  if (key == ENTER || key == RETURN) {
    if (!teclaEnter && desdeCampana && (estado == GANASTE || estado == PERDISTE)) volverALaCampana();
    else if (!teclaEnter && estado == CREDITOS) cerrarCreditos();
    else if (!teclaEnter && estado == LLAMADA) colgar();
    else if (!teclaEnter && estado == ELEGIR_ROL) empezar(numJugadores);
    else if (!teclaEnter && estado == RECONOCIMIENTO) entrar();
    else if (!teclaEnter && estado == JUGANDO && jugadores.size() > 1) {
      jugadores.get(1).pulsoUsar = true;
    }
    teclaEnter = true;
    return;
  }
  char c = Character.toLowerCase(key);
  if (c < 256) {
    if (!letras[c]) alPresionar(c);   // solo la primera vez, no al repetir
    letras[c] = true;
  }
}

void teclaSoltada() {
  if (key == CODED) {
    if (keyCode == UP) flechaArriba = false;
    if (keyCode == DOWN) flechaAbajo = false;
    if (keyCode == LEFT) flechaIzq = false;
    if (keyCode == RIGHT) flechaDer = false;
    if (keyCode == SHIFT) teclaShift = false;
    return;
  }
  if (key == ENTER || key == RETURN) {
    teclaEnter = false;
    return;
  }
  char c = Character.toLowerCase(key);
  if (c < 256) letras[c] = false;
}

void alPresionar(char c) {
  if (estado == CREDITOS) {
    if (c == 'c' || c == 'r') cerrarCreditos();
    return;
  }
  if (estado == INICIO && c == 'c') {
    abrirCreditos();
    return;
  }
  if (estado == INICIO) {
    if (c == '1' || c == '2') {
      numJugadores = c == '1' ? 1 : 2;
      iniciarMision();
      estado = ELEGIR_ROL;
      prepararLlamada();   // Valeria va escribiendo la llamada mientras se elige el rol
    }
    return;
  }
  if (estado == ELEGIR_ROL) {
    if (c == 'a' || c == 'd') rolElegido = 1 - rolElegido;
    if (c == 'e' || c == ' ') empezar(numJugadores);
    return;
  }
  if (estado == RECONOCIMIENTO) {
    if (c == ' ') entrar();
    return;
  }
  if (estado == LLAMADA) {
    if (c == 'e' || c == ' ') siguienteLineaLlamada();
    return;
  }
  if (estado == GANASTE || estado == PERDISTE) {
    if (desdeCampana) {
      // dentro de Alcalde Digital: E o Espacio vuelven a la oficina y R
      // repite la mision desde la eleccion de rol
      if (c == 'e' || c == ' ') volverALaCampana();
      if (c == 'r') reintentarMision();
      return;
    }
    if (c == 'c') {
      abrirCreditos();
      return;
    }
    if (c == 'r') {
      estado = INICIO;
      iniciarMision();
    }
    return;
  }
  // Jugando
  if (c == 'g') {
    alternarMapa();
    return;
  }
  if (mapaAbierto) return;   // en pausa: solo G cierra el mapa
  if (ventana == 6 && ((c >= '0' && c <= '9') || key == BACKSPACE)) {
    teclaTeclado(key == BACKSPACE ? BACKSPACE : c);
    return;
  }
  if (jugadores.get(0).contestando != null) {
    // El jugador 1 contesta la radio con WASD
    int dir = "wdsa".indexOf(c);
    if (dir >= 0) teclaRadio(jugadores.get(0), dir);
    return;
  }
  if (usandoConsola(jugadores.get(0)) && (c == 'w' || c == 's')) {
    moverOpcionConsola(c == 'w' ? -1 : 1);
    return;
  }
  if (c == 'e') jugadores.get(0).pulsoUsar = true;
  if (c == 'q') lanzar(jugadores.get(0));
  if (c == 'x') soltarBotin(jugadores.get(0));
  if (c == 'k' && jugadores.size() > 1) soltarBotin(jugadores.get(1));
  if (c == 'f') usarHabilidad(jugadores.get(0));
  if (c == 'm' && jugadores.size() > 1) usarHabilidad(jugadores.get(1));
  if (c == ',' && jugadores.size() > 1) lanzar(jugadores.get(1));
  if (c == 'c') jugadores.get(0).cambiarPostura();
  if (c == '.' && jugadores.size() > 1) jugadores.get(1).cambiarPostura();
  if (c == 'v') verRutas = !verRutas;
  if (c == 'r') {
    if (desdeCampana) {
      reintentarMision();
      return;
    }
    estado = INICIO;
    iniciarMision();
  }
}

// Dentro de Alcalde Digital, reiniciar es volver a elegir el rol (sin la
// llamada ni la pantalla de inicio).
void reintentarMision() {
  iniciarMision();
  estado = ELEGIR_ROL;
}


// ======================================================================
// Alarma.pde
// ======================================================================
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

// Nivel de alarma debajo del estado de alerta (arriba a la derecha)
void dibujarNivelAlarma(float derecha, float arriba) {
  float e = escala;
  float w = 230 * e;
  float h = nivelAlarma == 3 ? 58 * e : 40 * e;
  float x = derecha - w;
  panel(x, arriba, w, h);
  textFont(letraChica);
  textAlign(LEFT, TOP);
  fill(160);
  text("Alarma", x + 10 * e, arriba + 8 * e);
  color[] colores = {NEON_VERDE, COLOR_AMBAR, #FF7A3D, COLOR_RIVAL};
  for (int k = 0; k < 3; k++) {
    float sx = x + 66 * e + k * 22 * e;
    noStroke();
    fill(k < nivelAlarma ? colores[nivelAlarma] : color(45, 52, 78));
    rect(sx, arriba + 10 * e, 18 * e, 9 * e, 2 * e);
  }
  fill(colores[nivelAlarma]);
  textAlign(RIGHT, TOP);
  text(NOMBRES_ALARMA[nivelAlarma], x + w - 10 * e, arriba + 8 * e);
  textAlign(LEFT, TOP);
  fill(130);
  text("Nivel " + nivelAlarma + " de 3", x + 10 * e, arriba + 22 * e);
  if (nivelAlarma == 3) {
    fill((frameCount / 15) % 2 == 0 ? COLOR_RIVAL : color(242, 242, 233));
    text("La policía llega en " + ceil(max(0, tiempoPolicia)) + " s", x + 10 * e, arriba + 38 * e);
  }
}


// ======================================================================
// Audio.pde
// ======================================================================

// Musica dinamica y efectos de sonido, con javax.sound (viene con Java: no
// hace falta instalar ninguna libreria en Processing).
//
// Musica: cuatro pistas, una por momento de la mision:
//   0 calma    nadie sospecha
//   1 tension  un vigilante sospecha, un empleado huye o suena una radio
//   2 alerta   te persiguen, la policia viene o atraparon a un jugador
//   3 escape   ya copiaste el servidor y vas a salir
// Las cuatro suenan en un hilo aparte que las mezcla; al cambiar de momento
// una baja y la otra sube en 1,5 s (fundido). Cada pista sigue donde iba.
// Si hay archivos en data/musica/ (calma.wav, tension.wav, alerta.wav,
// escape.wav y opcional menu.wav) se usan esos; si no, la musica generada de
// data/musica_respaldo/.
// Efectos: WAV cortos de data/sfx/, cada uno con su volumen y tres copias para
// que puedan sonar encima de si mismos.

final int M_CALMA = 0, M_TENSION = 1, M_ALERTA = 2, M_ESCAPE = 3, M_MENU = 4;
final String[] PISTAS = {"calma", "tension", "alerta", "escape", "menu"};
final float VOLUMEN_MUSICA = 0.55;
final float VOLUMEN_EFECTOS = 0.8;

Musica musica;
HashMap<String, Clip[]> efectos = new HashMap<String, Clip[]>();
HashMap<String, Integer> turnoEfecto = new HashMap<String, Integer>();
boolean hayAudio = true;
boolean musicaPropia;   // se encontraron los archivos de data/musica/

// Volumen de cada efecto (los de onda cuadrada suenan mas fuerte)
String[] NOMBRES_EFECTO = {"paso", "paso_correr", "puerta", "negado", "tarjeta", "recoger", "botella", "lanzar",
  "noqueo", "radio", "radio_ok", "estatica", "alarma", "descubierto", "tecla", "codigo_ok", "codigo_mal",
  "copiando", "servidor_listo", "hackeo", "sombra", "interruptor", "ducto", "esconder", "foto", "aviso",
  "victoria", "derrota", "empujar", "pitido_camara", "telefono", "auricular"};
float[] VOLUMEN_EFECTO = {0.25, 0.35, 0.7, 0.35, 0.5, 0.7, 0.9, 0.6,
  0.9, 0.5, 0.5, 0.6, 0.35, 0.8, 0.4, 0.6, 0.4,
  0.4, 0.7, 0.6, 0.7, 0.7, 0.7, 0.8, 0.8, 0.3,
  0.8, 0.8, 0.8, 0.4, 0.55, 0.45};

void iniciarAudio() {
  try {
    for (int k = 0; k < NOMBRES_EFECTO.length; k++) cargarEfecto(NOMBRES_EFECTO[k], VOLUMEN_EFECTO[k] * VOLUMEN_EFECTOS);
    musica = new Musica();
    Thread hilo = new Thread(musica);
    hilo.setDaemon(true);
    hilo.start();
  } catch (Exception e) {
    hayAudio = false;
    println("Sin sonido: " + e.getMessage());
  }
}

// Lee un WAV de 16 bits como muestras entre -1 y 1 (mono)
float[] leerWav(String ruta) throws Exception {
  java.io.File f = new java.io.File(ruta);
  if (!f.exists()) return null;
  AudioInputStream ais = AudioSystem.getAudioInputStream(f);
  AudioFormat fmt = ais.getFormat();
  byte[] b = ais.readAllBytes();
  ais.close();
  int canales = fmt.getChannels();
  int n = b.length / (2 * canales);
  float[] x = new float[n];
  boolean grande = fmt.isBigEndian();
  for (int i = 0; i < n; i++) {
    float suma = 0;
    for (int c = 0; c < canales; c++) {
      int p = (i * canales + c) * 2;
      int v = grande ? (b[p] << 8) | (b[p + 1] & 0xff) : (b[p + 1] << 8) | (b[p] & 0xff);
      suma += v / 32768.0;
    }
    x[i] = suma / canales;
  }
  return x;
}

// Igual que leerWav pero guarda las muestras en short (para la musica)
short[] leerWavCorto(String ruta) throws Exception {
  java.io.File f = new java.io.File(ruta);
  if (!f.exists()) return null;
  AudioInputStream ais = AudioSystem.getAudioInputStream(f);
  AudioFormat fmt = ais.getFormat();
  byte[] b = ais.readAllBytes();
  ais.close();
  int canales = fmt.getChannels();
  int n = b.length / (2 * canales);
  short[] x = new short[n];
  boolean grande = fmt.isBigEndian();
  for (int i = 0; i < n; i++) {
    int suma = 0;
    for (int c = 0; c < canales; c++) {
      int p = (i * canales + c) * 2;
      suma += grande ? (b[p] << 8) | (b[p + 1] & 0xff) : (b[p + 1] << 8) | (b[p] & 0xff);
    }
    x[i] = (short) (suma / canales);
  }
  return x;
}

void cargarEfecto(String nombre, float volumen) throws Exception {
  float[] x = leerWav(dataPath("sfx/" + nombre + ".wav"));
  if (x == null) return;
  byte[] b = new byte[x.length * 2];
  for (int i = 0; i < x.length; i++) {
    int v = (int) constrain(x[i] * volumen * 32767, -32768, 32767);
    b[2 * i] = (byte) (v & 0xff);
    b[2 * i + 1] = (byte) ((v >> 8) & 0xff);
  }
  AudioFormat fmt = new AudioFormat(22050, 16, 1, true, false);
  Clip[] copias = new Clip[3];
  for (int k = 0; k < 3; k++) {
    copias[k] = AudioSystem.getClip();
    copias[k].open(fmt, b, 0, b.length);
  }
  efectos.put(nombre, copias);
  turnoEfecto.put(nombre, 0);
}

void sonar(String nombre) {
  if (!hayAudio) return;
  Clip[] copias = efectos.get(nombre);
  if (copias == null) return;
  int k = turnoEfecto.get(nombre);
  turnoEfecto.put(nombre, (k + 1) % copias.length);
  Clip c = copias[k];
  c.stop();
  c.setFramePosition(0);
  c.start();
}

// Que momento de la musica toca segun lo que pasa en la mision
int momentoMusica() {
  if (estado == INICIO || estado == ELEGIR_ROL || estado == CREDITOS || estado == LLAMADA) return M_MENU;
  if (estado == RECONOCIMIENTO) return M_CALMA;
  if (estado == GANASTE) return M_ESCAPE;
  if (estado == PERDISTE) return M_TENSION;
  boolean alerta = nivelAlarma >= 3;
  boolean tension = false;
  for (Vigilante v : vigilantes) {
    if (v.inconsciente) {
      if (v.radioSonando > 0) tension = true;
      continue;
    }
    if (v.estado == V_ALERTA) alerta = true;
    else if (v.estado != V_PATRULLA) tension = true;
  }
  for (Civil c : civiles) if (c.estado == C_HUYENDO) tension = true;
  for (Jugador j : jugadores) if (j.atrapado) alerta = true;
  if (alerta) return M_ALERTA;
  if (servidorCopiado) return M_ESCAPE;
  if (tension) return M_TENSION;
  return M_CALMA;
}

void actualizarMusica() {
  if (musica != null) musica.momento = momentoMusica();
}

// Mezclador de la musica en su propio hilo
class Musica implements Runnable {
  final int FRECUENCIA = 22050;
  short[][] pistas = new short[5][];   // en short y no en float: las canciones son largas y asi ocupan la mitad
  int[] posicion = new int[5];
  float[] ganancia = new float[5];
  volatile int momento = M_MENU;
  volatile float atenuar = 1;   // baja la musica mientras habla Valeria
  volatile float volumenUsuario = 1;   // el de Opciones (Alcalde Digital)
  float atenuacion = 1;

  Musica() throws Exception {
    musicaPropia = false;
    for (int k = 0; k < 5; k++) {
      short[] propia = leerWavCorto(dataPath("musica/" + PISTAS[k] + ".wav"));
      if (propia != null) musicaPropia = true;   // basta con una canción propia
      pistas[k] = propia != null ? propia : leerWavCorto(dataPath("musica_respaldo/" + PISTAS[k] + ".wav"));
    }
    // sin pista de menu: se usa la de calma
    if (pistas[M_MENU] == null) pistas[M_MENU] = pistas[M_CALMA];
  }

  public void run() {
    try {
      AudioFormat fmt = new AudioFormat(FRECUENCIA, 16, 1, true, false);
      SourceDataLine linea = AudioSystem.getSourceDataLine(fmt);
      int bloque = 1024;
      linea.open(fmt, bloque * 8);
      linea.start();
      byte[] salida = new byte[bloque * 2];
      float pasoFundido = bloque / (1.5 * FRECUENCIA);   // 1,5 s de fundido
      while (true) {
        int m = momento;
        atenuacion += constrain(atenuar - atenuacion, -0.03, 0.03);
        for (int k = 0; k < 5; k++) {
          float meta = k == m ? 1 : 0;
          ganancia[k] += constrain(meta - ganancia[k], -pasoFundido, pasoFundido);
        }
        for (int i = 0; i < bloque; i++) {
          float v = 0;
          for (int k = 0; k < 5; k++) {
            if (ganancia[k] <= 0.001 || pistas[k] == null) continue;
            // la de menu comparte datos con calma: no se avanza dos veces
            if (k == M_MENU && pistas[M_MENU] == pistas[M_CALMA]) {
              v += pistas[M_CALMA][posicion[M_CALMA] % pistas[M_CALMA].length] / 32768.0 * ganancia[k] * 0.7;
              continue;
            }
            v += pistas[k][posicion[k]] / 32768.0 * ganancia[k];
            posicion[k] = (posicion[k] + 1) % pistas[k].length;
          }
          if (ganancia[M_MENU] > 0.001 && pistas[M_MENU] == pistas[M_CALMA] && ganancia[M_CALMA] <= 0.001) {
            posicion[M_CALMA] = (posicion[M_CALMA] + 1) % pistas[M_CALMA].length;
          }
          int s = (int) constrain(v * VOLUMEN_MUSICA * volumenUsuario * atenuacion * 32767, -32768, 32767);
          salida[2 * i] = (byte) (s & 0xff);
          salida[2 * i + 1] = (byte) ((s >> 8) & 0xff);
        }
        linea.write(salida, 0, salida.length);
      }
    } catch (Exception e) {
      println("La música no pudo sonar: " + e.getMessage());
    }
  }
}


// ======================================================================
// Calificacion.pde
// ======================================================================
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


// ======================================================================
// CamaraSeguridad.pde
// ======================================================================
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


// ======================================================================
// Campana.pde
// ======================================================================
// Conexion con Alcalde Digital.
// El juego principal no se toca: se comunican por dos archivos de texto en
// data/ (clave=valor, faciles de escribir con saveStrings y leer con
// loadStrings).
//   campana.txt   lo escribe Alcalde Digital antes de entrar: el barrio, el
//                 apoyo y las habilidades que el candidato tiene en su arbol.
//                 Si no existe se usan valores de prueba.
//   resultado.txt lo escribe Infiltrado al terminar: si salio bien, el
//                 botin, el rango, las oportunidades, cuanto apoyo cambia y
//                 la noticia que saldria al dia siguiente.
// Cada habilidad del arbol se vuelve una herramienta en la mision:
//   Volantes           +2 paquetes para lanzar y distraer (como las botellas)
//   Megafono           lo que se lanza hace mas ruido (atrae desde mas lejos)
//   Perfil verificado  el jefe de seguridad tiene que estar mas cerca para reconocerte
//   Libreta de notas   el reconocimiento dura 25 s en vez de 15
//   Fuente confiable   empiezas sabiendo los dos primeros digitos del codigo
//   Rueda de prensa    la central acepta una respuesta mas por radio
//   Asistente de IA    la habilidad del rol se recarga un 30 % mas rapido
//   Bots de difusion   las camaras tardan mas en verte

final String[] HERRAMIENTAS = {"Volantes", "Megáfono", "Perfil verificado", "Libreta de notas",
  "Fuente confiable", "Rueda de prensa", "Asistente de IA", "Bots de difusión"};
final String[] EFECTO_HERRAMIENTA = {"+2 paquetes para lanzar", "lo que lanzas suena más fuerte",
  "el jefe te reconoce más de cerca", "reconocimiento de 25 s", "sabes 2 dígitos del código",
  "una respuesta de radio más", "tu habilidad se recarga más rápido", "las cámaras tardan más en verte"};

String barrioCampana = "La Colina";
int apoyoCampana = 45;
String buloCampana = "agua contaminada en El Puerto";
boolean campanaDePrueba = true;
StringList habilidadesCampana = new StringList();

// Cuando la mision se juega dentro de Alcalde Digital (ronda 2), el juego
// principal pasa los datos directamente con configurarCampana() y no se
// leen ni se escriben archivos.
boolean desdeCampana = false;

void configurarCampana(String barrio, int apoyo, String bulo, StringList habilidades) {
  desdeCampana = true;
  campanaDePrueba = false;
  barrioCampana = barrio;
  apoyoCampana = apoyo;
  buloCampana = bulo;
  habilidadesCampana.clear();
  for (String h : habilidades) habilidadesCampana.append(h);
}


void leerCampana() {
  if (desdeCampana) return;
  habilidadesCampana.clear();
  String[] lineas = null;
  try {
    if (new java.io.File(dataPath("campana.txt")).exists()) lineas = loadStrings("campana.txt");
  } catch (Exception e) {
    lineas = null;
  }
  campanaDePrueba = lineas == null;
  if (lineas == null) {
    // valores de prueba cuando se juega sin pasar por Alcalde Digital
    habilidadesCampana.append("Volantes");
    habilidadesCampana.append("Libreta de notas");
    habilidadesCampana.append("Asistente de IA");
    return;
  }
  for (String l : lineas) {
    l = trim(l);
    if (l.length() == 0 || l.charAt(0) == '#' || l.indexOf('=') < 0) continue;
    String clave = trim(l.substring(0, l.indexOf('=')));
    String valor = trim(l.substring(l.indexOf('=') + 1));
    if (clave.equals("barrio")) barrioCampana = valor;
    if (clave.equals("apoyo")) apoyoCampana = int(valor);
    if (clave.equals("bulo")) buloCampana = valor;
    if (clave.equals("habilidades")) {
      for (String h : split(valor, ',')) if (trim(h).length() > 0) habilidadesCampana.append(trim(h));
    }
  }
}

boolean tieneHerramienta(String nombre) {
  return habilidadesCampana.hasValue(nombre);
}

// Lo que cambia al empezar la mision
void aplicarHerramientas() {
  for (Jugador j : jugadores) {
    if (tieneHerramienta("Volantes")) j.botellas += 2;
  }
  if (tieneHerramienta("Fuente confiable")) {
    digitoConocido[0] = true;
    digitoConocido[1] = true;
  }
}

float tiempoReconocimientoTotal() {
  return tieneHerramienta("Libreta de notas") ? 25 : TIEMPO_RECONOCIMIENTO;
}

float ruidoLanzamiento() {
  return tieneHerramienta("Megáfono") ? 17 : RUIDO_BOTELLA;
}

float distanciaJefe() {
  return tieneHerramienta("Perfil verificado") ? 1.8 : DISTANCIA_JEFE;
}

int maxRadios() {
  return tieneHerramienta("Rueda de prensa") ? MAX_RADIOS + 1 : MAX_RADIOS;
}

float enfriamientoRol(int rol) {
  return ENFRIAR_ROL[rol] * (tieneHerramienta("Asistente de IA") ? 0.7 : 1);
}

float factorCamaraHerramienta() {
  return tieneHerramienta("Bots de difusión") ? 0.7 : 1;
}

// Cuanto apoyo gana o pierde el candidato en el barrio: con exito, 25 mas el
// botin y 5 por cada oportunidad; si sale mal, -15.
int cambioApoyo(boolean exito) {
  if (!exito) return -15;
  return 25 + valorExtraido + 5 * oportunidadesHechas();
}

String proximaNoticia(boolean exito) {
  if (!exito) return "Titulares Ya acusa a tu campaña de espiar su sede";
  if (oportunidadHecha[0]) return "El bulo sobre " + buloCampana + " salió con los datos reales y Titulares Ya quedó en evidencia";
  if (chatLeido) return "Filtran los chats de Titulares Ya: el bulo sobre " + buloCampana + " era inventado";
  return "Se filtra el servidor de Titulares Ya: el bulo sobre " + buloCampana + " queda desmentido";
}

void escribirResultado(boolean exito) {
  if (desdeCampana) return;   // el juego principal lee el resultado directamente
  StringList l = new StringList();
  l.append("# Lo escribe Infiltrado al terminar. Alcalde Digital lo puede leer con loadStrings.");
  l.append("exito=" + (exito ? "si" : "no"));
  l.append("barrio=" + barrioCampana);
  l.append("salida=" + (salidaUsada >= 0 ? NOMBRES_SALIDA[salidaUsada] : "ninguna"));
  l.append("rango=" + rangoFinal());
  l.append("botin=" + (exito ? valorExtraido : 0));
  l.append("chat_leido=" + (chatLeido ? "si" : "no"));
  String ops = "";
  for (int k = 0; k < 3; k++) if (oportunidadHecha[k]) ops += (ops.equals("") ? "" : ";") + NOMBRES_OPORTUNIDAD[k];
  l.append("oportunidades=" + ops);
  l.append("alarma_maxima=" + alarmaMaxima);
  l.append("apoyo_cambio=" + cambioApoyo(exito));
  l.append("proxima_noticia=" + proximaNoticia(exito));
  try {
    saveStrings(dataPath("resultado.txt"), l.array());
  } catch (Exception e) {
    println("No se pudo escribir resultado.txt: " + e.getMessage());
  }
}

// Lista de herramientas en la pantalla de elegir rol
void dibujarHerramientasCampana(float x, float y, float w) {
  float e = escala;
  textFont(letraChica);
  textAlign(LEFT, TOP);
  fill(NEON_VERDE);
  text("Herramientas de tu campaña" + (campanaDePrueba ? " (de prueba: no hay campana.txt)" : " · " + barrioCampana), x, y);
  int n = 0;
  for (int k = 0; k < HERRAMIENTAS.length; k++) {
    if (!tieneHerramienta(HERRAMIENTAS[k])) continue;
    float cx = x + (n % 2) * w / 2;
    float cy = y + 22 * e + (n / 2) * 18 * e;
    fill(220);
    text("· " + HERRAMIENTAS[k] + ": " + EFECTO_HERRAMIENTA[k], cx, cy);
    n++;
  }
  if (n == 0) {
    fill(140);
    text("Ninguna. Desbloquea habilidades en el árbol de Alcalde Digital.", x, y + 22 * e);
  }
}


// ======================================================================
// Charlas.pde
// ======================================================================
// Conversaciones que se pueden escuchar. Cuando dos personas tranquilas
// (vigilantes o empleados) se cruzan y hay un jugador cerca, se detienen a
// hablar. Si el jugador esta a menos de RADIO_ESCUCHA cuando dicen algo
// util, se queda con la pista (por ejemplo, la mitad del codigo).
// Cada charla se dice una sola vez por mision.

final float RADIO_ESCUCHA = 6;
final float DISTANCIA_CHARLA = 2.2;
final float SEGUNDOS_POR_LINEA = 3.2;
final float PAUSA_ENTRE_CHARLAS = 20;

// Pistas que puede dar una charla
final int PISTA_NINGUNA = 0;
final int PISTA_CODIGO = 1;      // los dos ultimos digitos del codigo
final int PISTA_AMARILLA = 2;    // donde esta la tarjeta amarilla
final int PISTA_ROJA = 3;        // donde esta la tarjeta roja

class Charla {
  String[] lineas;   // se alternan: la primera la dice "a", la segunda "b"...
  int pista;
  int lineaPista;    // en que linea se da la pista

  Charla(int pista, int lineaPista, String... lineas) {
    this.pista = pista;
    this.lineaPista = lineaPista;
    this.lineas = lineas;
  }
}

ArrayList<Charla> charlasPendientes = new ArrayList<Charla>();
Charla charlaActual;
Persona hablaA, hablaB;
float tiempoCharla;          // segundos desde que empezo la charla actual
float esperaCharla;          // pausa hasta la siguiente
boolean pistaAmarilla, pistaRoja;   // ya se escucharon esas pistas

void prepararCharlas() {
  charlasPendientes.clear();
  charlaActual = null;
  hablaA = null;
  hablaB = null;
  esperaCharla = 5;
  pistaAmarilla = false;
  pistaRoja = false;
  String fin = "" + codigoServidor.charAt(2) + codigoServidor.charAt(3);
  charlasPendientes.add(new Charla(PISTA_CODIGO, 1,
    "¿Cambiaron el código del cuarto del servidor?",
    "No, sigue terminando en " + fin + ". El resto lo anotaron en el archivo.",
    "Qué seguridad tan seria la de esta empresa..."));
  charlasPendientes.add(new Charla(PISTA_AMARILLA, 1,
    "¿Quién tiene la tarjeta de la oficina del jefe?",
    "La dejaron en el descanso, al lado de la cafetera.",
    "Siempre la dejan ahí."));
  charlasPendientes.add(new Charla(PISTA_NINGUNA, 0,
    "El jefe de seguridad mira a todo el mundo de cerca.",
    "Sí, a él no se le escapa ni un conserje nuevo."));
  charlasPendientes.add(new Charla(PISTA_ROJA, 1,
    "La puerta de carga del parqueadero solo abre con la roja.",
    "La roja quedó en la caseta de afuera.",
    "Alguien la va a perder un día."));
  charlasPendientes.add(new Charla(PISTA_NINGUNA, 0,
    "Si la central llama y no contestas, mandan a todos.",
    "Por eso nunca suelto la radio."));
}

// Puede hablar si esta tranquilo (ni buscando, ni noqueado, ni huyendo)
boolean puedeCharlar(Persona p) {
  if (p.inconsciente) return false;
  if (p instanceof Vigilante) return ((Vigilante) p).estado == V_PATRULLA;
  return ((Civil) p).estado == C_TRABAJANDO;
}

boolean estaCharlando(Persona p) {
  return charlaActual != null && (p == hablaA || p == hablaB);
}

boolean jugadorCerca(float x, float y, float radio) {
  for (Jugador j : jugadores) {
    if (!j.enDucto && dist(j.x, j.y, x, y) <= radio) return true;
  }
  return false;
}

void actualizarCharlas(float dt) {
  if (charlaActual != null) {
    // si a alguno lo asustan o lo noquean, la charla se corta
    if (!puedeCharlar(hablaA) || !puedeCharlar(hablaB)) {
      terminarCharla();
      return;
    }
    int antes = floor(tiempoCharla / SEGUNDOS_POR_LINEA);
    tiempoCharla += dt;
    int ahora = floor(tiempoCharla / SEGUNDOS_POR_LINEA);
    // al empezar la linea con la pista, se la lleva quien la oiga
    if (ahora != antes) revisarPista(ahora);
    if (ahora >= charlaActual.lineas.length) terminarCharla();
    return;
  }
  esperaCharla -= dt;
  if (esperaCharla > 0 || charlasPendientes.size() == 0) return;
  // busca dos personas tranquilas juntas con un jugador cerca
  ArrayList<Persona> gente = personas();
  for (int a = 0; a < gente.size(); a++) {
    for (int b = a + 1; b < gente.size(); b++) {
      Persona p = gente.get(a);
      Persona q = gente.get(b);
      if (!puedeCharlar(p) || !puedeCharlar(q)) continue;
      if (dist(p.x, p.y, q.x, q.y) > DISTANCIA_CHARLA) continue;
      if (!jugadorCerca((p.x + q.x) / 2, (p.y + q.y) / 2, RADIO_ESCUCHA)) continue;
      empezarCharla(p, q);
      return;
    }
  }
}

void empezarCharla(Persona p, Persona q) {
  charlaActual = charlasPendientes.remove(0);
  hablaA = p;
  hablaB = q;
  tiempoCharla = 0;
  // se miran
  p.angulo = atan2(q.y - p.y, q.x - p.x);
  q.angulo = atan2(p.y - q.y, p.x - q.x);
}

void terminarCharla() {
  charlaActual = null;
  hablaA = null;
  hablaB = null;
  esperaCharla = PAUSA_ENTRE_CHARLAS;
}

void revisarPista(int linea) {
  if (charlaActual == null || linea != charlaActual.lineaPista) return;
  // un poco de margen: si te alejaste un paso igual alcanzas a oirlo
  if (!jugadorCerca((hablaA.x + hablaB.x) / 2, (hablaA.y + hablaB.y) / 2, RADIO_ESCUCHA + 2)) return;
  int p = charlaActual.pista;
  if (p == PISTA_CODIGO) {
    conocerDigitos(2, 3, "Escuchaste los dos últimos dígitos del código");
    if (!digitoConocido[0]) resaltarZona(5, "Los otros dos dígitos están anotados en el archivo");
  }
  if (p == PISTA_AMARILLA && !pistaAmarilla) {
    pistaAmarilla = true;
    resaltarZona(10, "Pista: la tarjeta amarilla está en el descanso");
  }
  if (p == PISTA_ROJA && !pistaRoja) {
    pistaRoja = true;
    resaltarZona(0, "Pista: la tarjeta roja está en la caseta del parqueadero");
  }
}

// Globo con lo que se dice ahora, encima de quien habla
void dibujarCharla() {
  if (charlaActual == null) return;
  int k = floor(tiempoCharla / SEGUNDOS_POR_LINEA);
  if (k >= charlaActual.lineas.length) return;
  Persona quien = k % 2 == 0 ? hablaA : hablaB;
  // la charla solo empieza con un jugador cerca, asi que siempre se lee
  String texto = charlaActual.lineas[k];
  float sx = pantallaX(quien.x, quien.y);
  float sy = pantallaY(quien.x, quien.y) - 40 * pixel;
  textFont(letraChica);
  float w = textWidth(texto) + 20 * escala;
  float h = 24 * escala;
  float x0 = constrain(sx - w / 2, 8 * escala, width - w - 8 * escala);
  stroke(242, 242, 233, 160);
  strokeWeight(1);
  fill(242, 242, 233, 235);
  rect(x0, sy - h, w, h, 8 * escala);
  noStroke();
  triangle(sx - 5 * escala, sy - 1, sx + 5 * escala, sy - 1, sx, sy + 6 * escala);
  fill(COLOR_FONDO);
  textAlign(CENTER, CENTER);
  text(texto, x0 + w / 2, sy - h / 2 - 1 * escala);
  // pista resaltada: que se note que eso sirve
  if (k == charlaActual.lineaPista && charlaActual.pista != PISTA_NINGUNA) {
    noFill();
    stroke(NEON_VERDE);
    strokeWeight(2 * escala);
    rect(x0 - 2 * escala, sy - h - 2 * escala, w + 4 * escala, h + 4 * escala, 9 * escala);
  }
}


// ======================================================================
// Civil.pde
// ======================================================================
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


// ======================================================================
// Creditos.pde
// ======================================================================
// Pantalla de creditos (C en el inicio o al final de la mision). Los textos
// suben solos. Si en data/musica/creditos.txt hay lineas del tipo
//   calma=Nombre de la cancion — Compositor (Juego)
// se muestran en la seccion de musica.

final int CREDITOS = 6;
float desplazamientoCreditos;
int estadoAntesCreditos = INICIO;

void abrirCreditos() {
  estadoAntesCreditos = estado;
  estado = CREDITOS;
  desplazamientoCreditos = 0;
}

void cerrarCreditos() {
  estado = estadoAntesCreditos == CREDITOS ? INICIO : estadoAntesCreditos;
}

String[] lineasCreditos() {
  StringList l = new StringList();
  l.append("#INFILTRADO");
  l.append("Modo sigilo de Alcalde Digital");
  l.append("");
  l.append("@Proyecto");
  l.append("Jose Van Strahlen García y el equipo de Alcalde Digital");
  l.append("Estructura de Datos II · Universidad del Norte · 2026");
  l.append("");
  l.append("@Programación y arte");
  l.append("Pixel art \"neón nocturno\" y código en Processing");
  l.append("hechos con ayuda de Claude (Anthropic)");
  l.append("");
  l.append("@Estructuras de datos en juego");
  l.append("BFS en la cuadrícula (vigilantes y ruido) · BFS en el grafo de cuartos");
  l.append("Dijkstra en los ductos y para los empleados · Listas y matrices");
  l.append("");
  l.append("@Música");
  if (musicaPropia) {
    String[] propias = null;
    try {
      if (new java.io.File(dataPath("musica/creditos.txt")).exists()) propias = loadStrings("musica/creditos.txt");
    } catch (Exception e) {
      propias = null;
    }
    if (propias != null) {
      for (String p : propias) {
        p = trim(p);
        if (p.length() == 0 || p.charAt(0) == '#') continue;
        l.append(p.indexOf('=') >= 0 ? trim(p.substring(p.indexOf('=') + 1)) : p);
      }
    }
    l.append("");
    l.append("ARC Raiders: Johan Söderqvist y Patrik Andrén · Embark Studios");
    l.append("Cyberpunk 2077: Marcin Przybyłowicz, P.T. Adamczyk y Paul Leonard-Morgan");
    l.append("CD PROJEKT RED");
    l.append("");
    l.append("La música pertenece a sus autores y estudios.");
    l.append("Se usa solo de forma privada, sin fines comerciales y sin distribuirse.");
  } else {
    l.append("Música de respaldo generada por código");
    l.append("(sintetizadores hechos con numpy, sin grabaciones)");
  }
  l.append("");
  l.append("@Sonido");
  l.append("30 efectos generados por código (osciladores y ruido)");
  l.append("");
  l.append("@Letra");
  l.append("DejaVu Sans Mono (licencia libre)");
  l.append("");
  l.append("@Inspiración");
  l.append("Project Zomboid · Hotline Miami · Cyberpunk 2077 · Hitman · Payday 2 · Mark of the Ninja");
  l.append("");
  l.append("");
  l.append("Gracias por jugar");
  return l.array();
}

void actualizarCreditos(float dt) {
  desplazamientoCreditos += dt * 38 * escala;
}

void dibujarCreditos() {
  float e = escala;
  noStroke();
  fill(COLOR_FONDO, 235);
  rect(0, 0, width, height);
  String[] l = lineasCreditos();
  float y = height - desplazamientoCreditos;
  textAlign(CENTER, TOP);
  for (String s : l) {
    if (s.startsWith("#")) {
      textFont(letraTitulo);
      fill(NEON_MAGENTA);
      text(s.substring(1), width / 2, y);
      y += 64 * e;
    } else if (s.startsWith("@")) {
      textFont(letraMedia);
      fill(NEON_CIAN);
      text(s.substring(1).toUpperCase(), width / 2, y);
      y += 28 * e;
    } else {
      textFont(letraMedia);
      fill(225);
      text(s, width / 2, y);
      y += 24 * e;
    }
  }
  // al terminar vuelve a empezar
  if (y < 0) desplazamientoCreditos = 0;
  noStroke();
  fill(COLOR_FONDO);
  rect(0, height - 40 * e, width, 40 * e);
  textFont(letraChica);
  fill(130);
  textAlign(CENTER, BOTTOM);
  text("C, R o Enter para volver", width / 2, height - 14 * e);
}


// ======================================================================
// Dibujo.pde
// ======================================================================
// Todo lo que se dibuja del mundo. La cuadricula se pasa a pantalla con la
// formula isometrica de siempre:
//   pantallaX = (x - y) * anchoBaldosa / 2
//   pantallaY = (x + y) * altoBaldosa / 2
// y se dibuja de atras hacia adelante (por diagonales x + y) para que lo que
// esta mas cerca de la camara tape a lo que esta detras.

// Colores de la paleta neon nocturno (los mismos de los sprites)
final color NEON_CIAN = #19E3E3;
final color NEON_MAGENTA = #FF2E88;
final color COLOR_RIVAL = #E8344E;
final color COLOR_AMBAR = #FFB547;
final color NEON_VERDE = #3DDC84;
final color COLOR_FONDO = #0B0E1A;
final color COLOR_PANEL = #0F1424;

// El centro de la camara se redondea a pixeles enteros: asi todas las
// baldosas caen justas y no aparecen rayitas entre ellas.
float pantallaX(float x, float y) {
  return round(width / 2 - (camX - camY) * anchoBaldosa / 2) + (x - y) * anchoBaldosa / 2;
}

float pantallaY(float x, float y) {
  return round(height / 2 - (camX + camY) * altoBaldosa / 2) + (x + y) * altoBaldosa / 2;
}

void dibujarMundo() {
  noTint();
  actualizarMarcas();
  dibujarPisos();
  dibujarSobrePiso();
  dibujarCapaOrdenada();
  dibujarProyectiles();
  dibujarDuctos(60);
  dibujarResplandores();
  dibujarBrilloUsable();
  dibujarAparatosCamara();
  dibujarIndicadores();
  noTint();
}

// ---------------------------------------------------------------------------
// Piso
// ---------------------------------------------------------------------------

// Que sprite de piso va en cada baldosa (depende del cuarto)
PImage spritePiso(int i, int j) {
  char c = mapa.celdas[i][j];
  int v = (i * 7 + j * 13) % 2;   // dos versiones para que no se vea repetido
  if (c == 'D' || mapa.esPuertaCerrada(i, j)) return pisoMadera[v];
  int z = mapa.zona[i][j];
  if (z == 0) return (j == 27 || j == 29) && i % 3 == 0 && i > 20 ? pisoAsfalto[1] : pisoAsfalto[0];
  if (z == 1 || z == 8) return pisoBaldosa[v];   // recepcion y pasillo
  if (z == 2 || z == 10) return pisoAlfombra[v]; // redaccion y descanso
  if (z == 3) return pisoNegro[v];               // estudio
  if (z == 4 || z == 6) return pisoMetal[v];     // seguridad y servidor
  if (z == 5) return pisoMadera[v];              // archivo
  if (z == 7) return pisoRoja[v];                // oficina del rival
  return pisoBlanca[v];                          // aseo
}

void dibujarPisos() {
  for (int i = 0; i < mapa.ancho; i++) {
    for (int j = 0; j < mapa.alto; j++) {
      if (mapa.esPared(i, j)) continue;
      float sx = pantallaX(i, j);
      float sy = pantallaY(i, j);
      if (sx < -anchoBaldosa * 2 || sx > width + anchoBaldosa * 2 || sy < -altoPared * 2 || sy > height + altoBaldosa * 2) continue;
      tinteLuz(i, j, 255);
      sprite(spritePiso(i, j), sx - 16 * pixel, sy);
    }
  }
  noTint();
}

// Encima del piso: charcos de luz de colores, conos de vista, ruido y rutas
void dibujarSobrePiso() {
  for (float[] f : mapa.fuentesLuz) {
    float sx = pantallaX(f[0], f[1]);
    float sy = pantallaY(f[0], f[1]);
    if (fueraDePantalla(sx, sy, f[5] * 1.6 * anchoBaldosa)) continue;
    manchaLuz(sx, sy, f[5] * 1.6, color(f[2], f[3], f[4]), 120 * f[6], true);
  }

  for (Vigilante v : vigilantes) {
    if (v.inconsciente) continue;
    color c = color(255, 181, 71, 75);
    if (v.estado == V_SOSPECHA || v.estado == V_BUSCANDO) c = color(255, 181, 71, 90);
    if (v.estado == V_ALERTA) c = color(232, 52, 78, 100);
    dibujarCono(v.x, v.y, v.angulo, v.APERTURA, v.rango(), c);
  }
  for (Civil cv : civiles) {
    if (cv.inconsciente || cv.estado == C_ASUSTADO || cv.estado == C_HUYENDO) continue;
    color c = cv.estado == C_SOSPECHA ? color(255, 46, 136, 70) : color(242, 242, 233, 32);
    dibujarCono(cv.x, cv.y, cv.angulo, cv.APERTURA, cv.RANGO, c);
  }
  for (CamaraSeguridad cam : camaras) {
    if (!camarasEncendidas()) break;
    if (cam.hackeada > 0) continue;
    color c = cam.viendo ? color(232, 52, 78, 95) : color(25, 227, 227, 45);
    dibujarCono(cam.x, cam.y, cam.angulo, cam.APERTURA, cam.RANGO, c);
  }

  noFill();
  strokeWeight(2 * pixel);
  for (Ruido r : ruidos) {
    float actual = r.radio * (0.25 + 0.75 * (1 - r.vida));
    stroke(255, 46, 136, 210 * r.vida);
    ellipse(pantallaX(r.x, r.y), pantallaY(r.x, r.y),
      actual * anchoBaldosa * 1.414, actual * altoBaldosa * 1.414);
  }

  if (verRutas) dibujarRutas();
}

// Cono de vista recortado por las paredes: se lanzan rayos y cada uno se
// detiene en la primera baldosa que tapa la vista.
// Para no dibujar lo que cae fuera de la pantalla (margen en pixeles)
boolean fueraDePantalla(float sx, float sy, float margen) {
  float m = margen + 20;
  // con el zoom del reconocimiento se ve mas: se agranda el margen
  if (zoom < 0.99) return false;
  return sx < -m || sx > width + m || sy < -m || sy > height + m;
}

void dibujarCono(float cx, float cy, float ang, float apertura, float rango, color c) {
  if (fueraDePantalla(pantallaX(cx, cy), pantallaY(cx, cy), rango * anchoBaldosa)) return;
  noStroke();
  fill(c);
  beginShape();
  vertex(pantallaX(cx, cy), pantallaY(cx, cy));
  int rayos = 18;
  for (int k = 0; k <= rayos; k++) {
    float a = ang - apertura + 2 * apertura * k / rayos;
    float largo = alcanceRayo(cx, cy, a, rango);
    float px = cx + cos(a) * largo;
    float py = cy + sin(a) * largo;
    vertex(pantallaX(px, py), pantallaY(px, py));
  }
  endShape(CLOSE);
}

float alcanceRayo(float cx, float cy, float a, float rango) {
  for (float d = 0.1; d < rango; d += 0.1) {
    if (mapa.bloqueaVista(floor(cx + cos(a) * d), floor(cy + sin(a) * d))) return d;
  }
  return rango;
}

// Tecla V: muestra el camino que BFS le dio a cada vigilante
void dibujarRutas() {
  strokeWeight(2 * escala);
  for (Vigilante v : vigilantes) {
    color c = color(255, 255, 255, 160);
    if (v.estado == V_SOSPECHA) c = color(255, 180, 60, 200);
    if (v.estado == V_ALERTA) c = color(235, 60, 50, 220);
    stroke(c);
    float ax = v.x;
    float ay = v.y;
    for (int[] p : v.camino) {
      float bx = p[0] + 0.5;
      float by = p[1] + 0.5;
      line(pantallaX(ax, ay), pantallaY(ax, ay), pantallaX(bx, by), pantallaY(bx, by));
      ax = bx;
      ay = by;
    }
    noStroke();
    fill(c);
    for (int[] p : v.camino) {
      rect(pantallaX(p[0] + 0.5, p[1] + 0.5) - 2 * escala, pantallaY(p[0] + 0.5, p[1] + 0.5) - 2 * escala, 4 * escala, 4 * escala);
    }
    // puntos de la ronda
    noFill();
    stroke(255, 255, 255, 90);
    for (int[] p : v.ruta) {
      float sx = pantallaX(p[0] + 0.5, p[1] + 0.5);
      float sy = pantallaY(p[0] + 0.5, p[1] + 0.5);
      quad(sx, sy - 6 * escala, sx + 12 * escala, sy, sx, sy + 6 * escala, sx - 12 * escala, sy);
    }
  }
}

// ---------------------------------------------------------------------------
// Capa ordenada: bloques altos y personas, diagonal por diagonal
// ---------------------------------------------------------------------------

void dibujarCapaOrdenada() {
  int diagonales = mapa.ancho + mapa.alto - 1;
  for (int d = 0; d < diagonales; d++) {
    // Primero las personas de esta diagonal y luego los bloques, porque el
    // centro de un bloque de la diagonal d esta en d + 1 (un poco mas adelante)
    for (Jugador j : jugadores) {
      if (!j.escondido && floor(j.x + j.y) == d) dibujarJugador(j);
    }
    for (Vigilante v : vigilantes) {
      if (floor(v.x + v.y) == d) dibujarVigilante(v);
    }
    for (Civil c : civiles) {
      if (floor(c.x + c.y) == d) dibujarCivil(c);
    }
    for (int i = max(0, d - (mapa.alto - 1)); i <= min(mapa.ancho - 1, d); i++) {
      dibujarBaldosaAlta(i, d - i);
    }
  }
}

// Paredes, muebles y objetos de una baldosa. Cada sprite tiene la esquina de
// atras de la baldosa en un punto fijo, por eso se corre hacia arriba segun
// lo alto que sea (pared 28 px, muebles 40 px de espacio arriba).
void dibujarBaldosaAlta(int i, int j) {
  char c = mapa.celdas[i][j];
  float sx = pantallaX(i, j) - 16 * pixel;
  float sy = pantallaY(i, j);
  if (sx < -anchoBaldosa * 2 || sx > width + anchoBaldosa || sy < -altoPared * 2 || sy > height + altoPared * 2) return;
  float corte = mapa.corte[i][j];

  if (c == '#' || mapa.esPuertaCerrada(i, j)) {
    // Pared (o puerta cerrada) entera que se desvanece y deja ver una pared
    // baja cuando tapa a alguien
    if (corte > 0.02) {
      tinteLuz(i, j, 255 * corte);
      sprite(paredBaja, sx, sy - 6 * pixel);
      if (corte >= 0.98) bordeSprite(paredBaja, sx, sy - 6 * pixel, i, j);
    }
    if (corte < 0.98) {
      float alfa = 255 * (1 - corte);
      PImage img = paredLadrillo[(i * 7 + j * 13) % 2];
      PImage luzImg = null;
      if (c != '#') {
        img = spriteObjeto[c];
        luzImg = spriteObjetoLuz[c];
      } else if (mapa.adorno[i][j] == 1) {
        img = paredNeon;
        luzImg = paredNeonLuz;
      } else if (mapa.adorno[i][j] == 2) {
        img = paredLetrero;
        luzImg = paredLetreroLuz;
      }
      tinteLuz(i, j, alfa);
      sprite(img, sx, sy - 28 * pixel);
      if (luzImg != null) {
        tint(255, alfa);   // lo que brilla no se oscurece
        sprite(luzImg, sx, sy - 28 * pixel);
      }
      luzSprite(img, sx, sy - 28 * pixel, i, j);
      bordeSprite(img, sx, sy - 28 * pixel, i, j);
    }
  } else if (c < 128 && spriteObjeto[c] != null) {
    float alfa = 255 * (1 - 0.6 * corte);
    PImage luzImg = spriteObjetoLuz[c];
    if (c == 'S' && servidorCopiado) luzImg = servidorLuzCopiado;
    boolean apagada = mapa.zonaApagada[mapa.zona[i][j]] && c != 'S';
    tinteLuz(i, j, alfa);
    sprite(spriteObjeto[c], sx, sy - 40 * pixel);
    if (luzImg != null && !apagada) {
      tint(255, alfa);
      sprite(luzImg, sx, sy - 40 * pixel);
    }
    luzSprite(spriteObjeto[c], sx, sy - 40 * pixel, i, j);
    bordeSprite(spriteObjeto[c], sx, sy - 40 * pixel, i, j);
    noTint();
    // la flechita sobra cuando ya tiene la etiqueta encima
    if (marca != null && marca[i][j] >= 1) return;
    // flechitas sobre lo que se puede recoger o usar
    if (soloEscapar()) {
      // ya solo importan las salidas
      if (c == 'E' || c == 'm' || (i == DUCTO_CALLE_I && j == DUCTO_CALLE_J)) marcador(i + 0.5, j + 0.5, c == 'v' ? 14 : 30, NEON_VERDE);
      return;
    }
    if (c == 'h' || c == 'l' || c == 'P' || c == 'r' || c == 'b' || c == 'y' || c == 'n' || c == 'o') marcador(i + 0.5, j + 0.5, 14, c == 'r' ? COLOR_RIVAL : (c == 'b' ? #3E7BFF : COLOR_AMBAR));
    if (c == 'S' && !servidorCopiado && i == mapa.servidorI && j == mapa.servidorJ) marcador(i + 0.5, j + 0.5, 40, COLOR_AMBAR);
    if ((c == 'E' || c == 'm') && servidorCopiado) marcador(i + 0.5, j + 0.5, 30, NEON_VERDE);
    if ((c == 'O' && !chatLeido) || (c == 'X' && !tableroVisto) || (c == 'U' && !cuadernoVisto)) marcador(i + 0.5, j + 0.5, 30, NEON_MAGENTA);
  }
  noTint();
}

// Flechita que sube y baja encima de algo importante
void marcador(float x, float y, float alto, color c) {
  float sx = pantallaX(x, y);
  float sy = pantallaY(x, y) - (alto + 6) * pixel + sin(millis() / 200.0) * 2 * pixel;
  noStroke();
  fill(c);
  triangle(sx - 4 * pixel, sy - 5 * pixel, sx + 4 * pixel, sy - 5 * pixel, sx, sy);
}

// Botellas volando (con su sombra en el piso) y vidrio roto
void dibujarProyectiles() {
  noStroke();
  for (Proyectil p : proyectiles) {
    float sx = pantallaX(p.x(), p.y());
    float sy = pantallaY(p.x(), p.y());
    fill(0, 110);
    ellipse(sx, sy, 6 * pixel, 3 * pixel);
    fill(#1E7A4C);
    rect(round(sx - pixel), round(sy - (10 + p.altura()) * pixel), 2 * pixel, 5 * pixel);
    fill(NEON_VERDE);
    rect(round(sx - pixel), round(sy - (10 + p.altura()) * pixel), pixel, pixel);
  }
  for (Particula q : particulas) {
    fill(red(q.c), green(q.c), blue(q.c), 255 * q.vida / 0.6);
    rect(round(pantallaX(q.x, q.y)), round(pantallaY(q.x, q.y) - 3 * pixel), pixel, pixel);
  }
}

// Los ductos se ven como lineas punteadas entre sus rejillas
void dibujarDuctos(int alfa) {
  stroke(25, 227, 227, alfa);
  strokeWeight(2 * pixel);
  for (int[] d : mapa.ductos) {
    int[] a = mapa.rejillas.get(d[0]);
    int[] b = mapa.rejillas.get(d[1]);
    // el ducto va en L: primero en x y luego en y
    float[][] puntos = {{a[0] + 0.5, a[1] + 0.5}, {b[0] + 0.5, a[1] + 0.5}, {b[0] + 0.5, b[1] + 0.5}};
    for (int k = 0; k < 2; k++) {
      float largo = dist(puntos[k][0], puntos[k][1], puntos[k + 1][0], puntos[k + 1][1]);
      for (float t = 0; t < largo; t += 0.6) {
        float u0 = t / max(0.01, largo);
        float u1 = min(1, (t + 0.3) / max(0.01, largo));
        float x0 = lerp(puntos[k][0], puntos[k + 1][0], u0), y0 = lerp(puntos[k][1], puntos[k + 1][1], u0);
        float x1 = lerp(puntos[k][0], puntos[k + 1][0], u1), y1 = lerp(puntos[k][1], puntos[k + 1][1], u1);
        line(pantallaX(x0, y0), pantallaY(x0, y0) - 30 * pixel, pantallaX(x1, y1), pantallaY(x1, y1) - 30 * pixel);
      }
    }
  }
}

// Brillo de lo que da luz (farol, pantallas, letreros), encima de todo
void dibujarResplandores() {
  for (float[] f : mapa.fuentesLuz) {
    float sx = pantallaX(f[0], f[1]);
    float sy = pantallaY(f[0], f[1]) - f[7] * pixel;
    if (fueraDePantalla(sx, sy, anchoBaldosa * 1.5)) continue;
    manchaLuz(sx, sy, 1.0, color(f[2], f[3], f[4]), 170 * f[6], false);
  }
}

// ---------------------------------------------------------------------------
// Personas
// ---------------------------------------------------------------------------

void dibujarJugador(Jugador j) {
  SpritesPersona s = j.numero == 1 ? spritesJugador1 : spritesJugador2;
  if (j.disfrazado) s = j.numero == 1 ? spritesConserje1 : spritesConserje2;
  dibujarPersona(s, j.x, j.y, atan2(j.dirY, j.dirX), j.agachado, j.moviendose, j.sombra > 0 ? 110 : 255, null);
  if (jugadores.size() > 1) {
    textFont(letraChica);
    textAlign(CENTER, BOTTOM);
    fill(j.ropa);
    text("J" + j.numero, pantallaX(j.x, j.y), pantallaY(j.x, j.y) - (j.agachado ? 22 : 30) * pixel);
  }
}

void dibujarVigilante(Vigilante v) {
  if (v.inconsciente) {
    if (!v.cuerpoEscondido) dibujarCuerpo(v.esJefe ? spritesJefe : spritesVigilante, v);
    return;
  }
  boolean camina = (v.camino.size() > 0 && v.estado != V_BUSCANDO) || v.estado == V_ALERTA;
  dibujarPersona(v.esJefe ? spritesJefe : spritesVigilante, v.x, v.y, v.angulo, false, camina, 255, v);
}

// Persona noqueada: el sprite acostado en el piso
void dibujarCuerpo(SpritesPersona s, Persona p) {
  float sx = round(pantallaX(p.x, p.y));
  float sy = round(pantallaY(p.x, p.y));
  noStroke();
  fill(0, 120);
  ellipse(sx, sy, 26 * pixel, 7 * pixel);
  PImage img = s.frente[0];
  pushMatrix();
  translate(sx - 13 * pixel, sy - 4 * pixel);
  rotate(HALF_PI);
  int i = constrain(floor(p.x), 0, mapa.ancho - 1);
  int j = constrain(floor(p.y), 0, mapa.alto - 1);
  tint(min(255, mapa.luzR[i][j] * 280), min(255, mapa.luzG[i][j] * 280), min(255, mapa.luzB[i][j] * 280));
  image(img, -8 * pixel, -27 * pixel, img.width * pixel, img.height * pixel);
  color borde = colorMarcaDe(p);
  if (borde != 0) contornoPersona(img, borde, marcaDe(p));
  popMatrix();
  noTint();
}

// (x, y) son los pies en la cuadricula. Se elige el sprite segun hacia donde
// mira en pantalla: de frente o de espaldas, y se voltea si mira a la derecha.
void dibujarPersona(SpritesPersona s, float x, float y, float ang, boolean agachado, boolean camina, float alfa, Persona p) {
  float sx = round(pantallaX(x, y));
  float sy = round(pantallaY(x, y));
  float mx = cos(ang) - sin(ang);
  float my = (cos(ang) + sin(ang)) * 0.5;
  boolean espalda = my < -0.05;
  PImage img;
  if (agachado && s.frenteAgachado != null) {
    img = espalda ? s.espaldaAgachado : s.frenteAgachado;
  } else {
    int cuadro = camina ? 1 + (millis() / 160) % 2 : 0;
    img = espalda ? s.espalda[cuadro] : s.frente[cuadro];
  }
  noStroke();
  fill(0, 120);
  ellipse(sx, sy, 13 * pixel, 5 * pixel);
  // la gente se ve un poco mas clara que el fondo para que se lea bien
  int i = constrain(floor(x), 0, mapa.ancho - 1);
  int j = constrain(floor(y), 0, mapa.alto - 1);
  tint(min(255, mapa.luzR[i][j] * 300), min(255, mapa.luzG[i][j] * 300), min(255, mapa.luzB[i][j] * 300), alfa);
  pushMatrix();
  translate(sx, sy);
  if (mx > 0) scale(-1, 1);
  image(img, -8 * pixel, -27 * pixel, img.width * pixel, img.height * pixel);
  color borde = p == null ? 0 : colorMarcaDe(p);
  if (borde != 0) contornoPersona(img, borde, marcaDe(p));
  popMatrix();
  noTint();
}

// ---------------------------------------------------------------------------
// Camaras y simbolos encima de la gente
// ---------------------------------------------------------------------------

void dibujarAparatosCamara() {
  for (CamaraSeguridad cam : camaras) {
    float sx = round(pantallaX(cam.x, cam.y));
    float sy = round(pantallaY(cam.x, cam.y) - 24 * pixel);
    float mx = cos(cam.angulo) - sin(cam.angulo);
    float my = (cos(cam.angulo) + sin(cam.angulo)) * 0.5;
    float p = pixel;
    noStroke();
    fill(10, 10, 18);
    rect(sx - 4 * p, sy - 3 * p, 8 * p, 6 * p);
    fill(#3E5478);
    rect(sx - 3 * p, sy - 2 * p, 6 * p, 4 * p);
    fill(10, 10, 18);
    rect(sx - 1 * p + round(mx * 3) * p, sy - 1 * p + round(my * 2) * p, 3 * p, 3 * p);
    boolean parpadeo = (frameCount / 20) % 2 == 0 && camarasEncendidas() && cam.hackeada <= 0;
    color led = cam.viendo ? COLOR_RIVAL : (parpadeo ? NEON_VERDE : color(20, 60, 40));
    fill(led);
    rect(sx + 2 * p, sy - 2 * p, p, p);
    if (cam.viendo || parpadeo) manchaLuz(sx + 2.5 * p, sy - 1.5 * p, 0.35, led, 160, false);
    if (cam.sospecha > 1) medidor(sx, sy - 10 * p, cam.sospecha, COLOR_RIVAL);
  }
}

void dibujarIndicadores() {
  // Fantasma de cada vigilante por encima de todo: si una pared lo tapa,
  // igual se ve donde esta (como en Project Zomboid o Mark of the Ninja)
  for (Vigilante v : vigilantes) {
    if (v.inconsciente) continue;
    boolean camina = (v.camino.size() > 0 && v.estado != V_BUSCANDO) || v.estado == V_ALERTA;
    float sx = round(pantallaX(v.x, v.y));
    float sy = round(pantallaY(v.x, v.y));
    float mx = cos(v.angulo) - sin(v.angulo);
    float my = (cos(v.angulo) + sin(v.angulo)) * 0.5;
    SpritesPersona sv = v.esJefe ? spritesJefe : spritesVigilante;
    PImage img = my < -0.05 ? sv.espalda[camina ? 1 + (millis() / 160) % 2 : 0]
      : sv.frente[camina ? 1 + (millis() / 160) % 2 : 0];
    tint(red(v.colorRonda), green(v.colorRonda), blue(v.colorRonda), 60);
    pushMatrix();
    translate(sx, sy);
    if (mx > 0) scale(-1, 1);
    image(img, -8 * pixel, -27 * pixel, img.width * pixel, img.height * pixel);
    popMatrix();
    noTint();
  }
  for (Vigilante v : vigilantes) {
    float sx = pantallaX(v.x, v.y);
    float sy = pantallaY(v.x, v.y) - 36 * pixel;
    if (v.inconsciente) {
      if (v.radioSonando > 0) iconoRadio(v);
      else if (!v.cuerpoEscondido) dibujarZetas(sx + 10 * pixel, pantallaY(v.x, v.y) - 14 * pixel);
    } else if (v.estado == V_ALERTA) {
      simbolo(sx, sy, "!", COLOR_RIVAL);
    } else if (v.sospecha > 1 || v.estado != V_PATRULLA) {
      medidor(sx, sy, v.sospecha, COLOR_AMBAR);
      simbolo(sx, sy, "?", COLOR_AMBAR);
    }
  }
  for (Civil c : civiles) {
    float sx = pantallaX(c.x, c.y);
    float sy = pantallaY(c.x, c.y) - 36 * pixel;
    if (c.inconsciente) {
      if (!c.cuerpoEscondido) dibujarZetas(sx + 10 * pixel, pantallaY(c.x, c.y) - 14 * pixel);
    } else if (c.estado == C_HUYENDO) {
      simbolo(sx, sy, "!", NEON_MAGENTA);
    } else if (c.sospecha > 1) {
      medidor(sx, sy, c.sospecha, NEON_MAGENTA);
      simbolo(sx, sy, "?", NEON_MAGENTA);
    }
  }
  dibujarObjetosMarcados();
  dibujarEfectosRol();
  dibujarRescates();
  dibujarTextosFlotantes();
  dibujarEquipo();
  dibujarCharla();
  // Tecla y accion encima de lo que se puede usar
  dibujarEtiquetasUso();
  dibujarRadios();
  // Estado del jugador (escondido, en el ducto) encima de el
  for (Jugador j : jugadores) {
    String pista = pistaPara(j);
    if (pista.equals("")) continue;
    float sx = pantallaX(j.x, j.y);
    float sy = pantallaY(j.x, j.y) - (j.escondido ? 18 : 40) * pixel;
    textFont(letraChica);
    float w = textWidth(pista) + 14 * escala;
    stroke(25, 227, 227, 120);
    strokeWeight(1);
    fill(15, 20, 36, 225);
    rect(sx - w / 2, sy - 10 * escala, w, 20 * escala, 3 * escala);
    fill(#F2F2E9);
    textAlign(CENTER, CENTER);
    text(pista, sx, sy);
  }
}

// Lo que se le muestra al jugador encima de el cuando esta escondido o en un
// ducto. Lo que se puede usar se marca en el objeto (Interaccion.pde).
String pistaPara(Jugador j) {
  String t = "[" + j.teclaUsar() + "] ";
  if (estado != JUGANDO) return "";
  if (j.enDucto) {
    if (j.viajeDucto >= 0) return "Gateando por el ducto...";
    int[] r = mapa.rejillas.get(j.destinosDucto.get(j.opcionDucto));
    return "Ducto hacia " + NOMBRES_ZONA[mapa.zonaEn(r[0], r[1])] + "  " + t + "cambiar";
  }
  if (j.escondido) return (jugadores.size() > 1 ? "J" + j.numero + " escondido · " : "") + t + "Salir";
  return "";
}

// "z z" que sube encima de alguien noqueado
void dibujarZetas(float x, float y) {
  textFont(letraChica);
  textAlign(CENTER, CENTER);
  for (int k = 0; k < 2; k++) {
    float t = (millis() / 1400.0 + k * 0.5) % 1;
    fill(200, 210, 255, 220 * (1 - t));
    text("z", x + k * 6 * escala + t * 4 * escala, y - t * 14 * escala);
  }
}

void simbolo(float x, float y, String s, color c) {
  stroke(c);
  strokeWeight(1.5 * escala);
  fill(15, 20, 36, 230);
  ellipse(x, y, 20 * escala, 20 * escala);
  textFont(letraMedia);
  textAlign(CENTER, CENTER);
  fill(c);
  text(s, x, y - 1 * escala);
}

void medidor(float x, float y, float valor, color c) {
  noFill();
  strokeWeight(3 * escala);
  stroke(0, 160);
  ellipse(x, y, 26 * escala, 26 * escala);
  stroke(c);
  arc(x, y, 26 * escala, 26 * escala, -HALF_PI, -HALF_PI + TWO_PI * valor / 100);
}

// ---------------------------------------------------------------------------
// Reconocimiento: el plano con las rondas
// ---------------------------------------------------------------------------

// Se dibuja encima del mundo: la zona que barre cada camara, la ronda
// completa de cada vigilante (con un color por vigilante) y etiquetas de
// los lugares importantes.
void dibujarPlano() {
  for (CamaraSeguridad cam : camaras) {
    dibujarCono(cam.x, cam.y, cam.anguloBase, cam.amplitud + cam.APERTURA, cam.RANGO, color(25, 227, 227, 45));
  }

  for (int n = 0; n < vigilantes.size(); n++) {
    Vigilante v = vigilantes.get(n);
    ArrayList<int[]> r = v.rondaCompleta;
    stroke(red(v.colorRonda), green(v.colorRonda), blue(v.colorRonda), 210);
    strokeWeight(4 * escala);
    for (int k = 0; k + 1 < r.size(); k++) {
      int[] a = r.get(k);
      int[] b = r.get(k + 1);
      line(pantallaX(a[0] + 0.5, a[1] + 0.5), pantallaY(a[0] + 0.5, a[1] + 0.5),
        pantallaX(b[0] + 0.5, b[1] + 0.5), pantallaY(b[0] + 0.5, b[1] + 0.5));
    }
    // Donde se detiene a mirar
    noStroke();
    fill(v.colorRonda);
    for (int[] p : v.ruta) {
      float sx = pantallaX(p[0] + 0.5, p[1] + 0.5);
      float sy = pantallaY(p[0] + 0.5, p[1] + 0.5);
      quad(sx, sy - 7 * escala, sx + 14 * escala, sy, sx, sy + 7 * escala, sx - 14 * escala, sy);
    }
  }

  dibujarDuctos(200);

  // Nombre de cada cuarto en su centro
  float[] sumaX = new float[NOMBRES_ZONA.length];
  float[] sumaY = new float[NOMBRES_ZONA.length];
  int[] cuenta = new int[NOMBRES_ZONA.length];
  for (int i = 0; i < mapa.ancho; i++) {
    for (int j = 0; j < mapa.alto; j++) {
      if (mapa.esPared(i, j)) continue;
      int z = mapa.zona[i][j];
      sumaX[z] += i + 0.5;
      sumaY[z] += j + 0.5;
      cuenta[z]++;
    }
  }
  // BFS sobre el grafo de cuartos: los que no se alcanzan sin tarjetas salen con candado
  boolean[] alcanza = mapa.zonasAlcanzables(tarjetas);
  for (int z = 1; z < NOMBRES_ZONA.length; z++) {
    if (cuenta[z] > 0) textoMundo(sumaX[z] / cuenta[z], sumaY[z] / cuenta[z], (alcanza[z] ? "" : "[cerrado] ") + NOMBRES_ZONA[z]);
  }

  boolean servidorMarcado = false;
  boolean camionetaMarcada = false;
  for (int i = 0; i < mapa.ancho; i++) {
    for (int j = 0; j < mapa.alto; j++) {
      char c = mapa.celdas[i][j];
      if (c == 'S' && !servidorMarcado) {
        etiquetaMundo(i + 0.5, j + 0.5, "SERVIDOR", COLOR_AMBAR);
        servidorMarcado = true;
      }
      if (c == 'E' && !camionetaMarcada) {
        etiquetaMundo(i + 0.5, j + 0.5, "Camioneta", NEON_VERDE);
        camionetaMarcada = true;
      }
      if (c == 'm') etiquetaMundo(i + 0.5, j + 0.5, "Moto (salida)", NEON_VERDE);
      if (i == DUCTO_CALLE_I && j == DUCTO_CALLE_J) etiquetaMundo(i + 0.5, j + 0.5, "Ducto a la calle (máx. 2 kg)", NEON_VERDE);
      if (c == 'r') etiquetaMundo(i + 0.5, j + 0.5, "Tarjeta roja", COLOR_RIVAL);
      if (c == 'b') etiquetaMundo(i + 0.5, j + 0.5, "Tarjeta azul", #3E7BFF);
      if (c == 'y') etiquetaMundo(i + 0.5, j + 0.5, "Tarjeta amarilla", COLOR_AMBAR);
      if (c == 'n') etiquetaMundo(i + 0.5, j + 0.5, "Código", NEON_CIAN);
      if (c == 'O') etiquetaMundo(i + 0.5, j + 0.5, "Celular del rival", NEON_MAGENTA);
      if (c == 'T') etiquetaMundo(i + 0.5, j + 0.5, "Luces", #F2F2E9);
    }
  }
}

// Texto suelto sobre el plano (nombres de cuartos)
void textoMundo(float x, float y, String texto) {
  float sx = pantallaX(x, y);
  float sy = pantallaY(x, y);
  pushMatrix();
  translate(sx, sy);
  scale(0.8 / zoom);
  textFont(letraMedia);
  textAlign(CENTER, CENTER);
  fill(0, 170);
  text(texto, 1.5 * escala, 1.5 * escala);
  fill(242, 242, 233, 210);
  text(texto, 0, 0);
  popMatrix();
}

// Etiqueta con recuadro; se dibuja a tamano fijo aunque el plano este alejado
void etiquetaMundo(float x, float y, String texto, color c) {
  float sx = pantallaX(x, y);
  float sy = pantallaY(x, y) - altoPared * 1.15;
  pushMatrix();
  translate(sx, sy);
  scale(0.75 / zoom);
  textFont(letraMedia);
  float w = textWidth(texto) + 14 * escala;
  stroke(c);
  strokeWeight(1.5 * escala);
  fill(15, 20, 36, 230);
  rect(-w / 2, -12 * escala, w, 24 * escala, 4 * escala);
  fill(c);
  textAlign(CENTER, CENTER);
  text(texto, 0, -1 * escala);
  popMatrix();
}


// ======================================================================
// Disfraz.pde
// ======================================================================
// Disfraz de conserje. En el casillero del aseo hay uniformes (uno por
// jugador). Con el uniforme puesto, caminando, nadie se fija en ti en ningún
// cuarto de la sede: ni los vigilantes (salvo que estés pegado a ellos), ni
// los empleados, ni las cámaras, y tus pasos no los hacen ir a revisar. Se
// nota solo si:
//   - corras, te agaches o arrastres un cuerpo (un conserje no hace eso),
//   - el jefe de seguridad te vea de cerca: el si conoce a su gente.
// Si un vigilante te descubre, el disfraz queda quemado.

final float DISTANCIA_JEFE = 3;
final float DISTANCIA_PEGADO = 1.0;   // a menos de esto cualquier vigilante ve que no eres el conserje
final int[] ZONAS_PROHIBIDAS = {4, 6, 7};   // seguridad, servidor, oficina del rival

boolean enZonaProhibida(Jugador j) {
  int z = mapa.zonaEn(j.x, j.y);
  for (int p : ZONAS_PROHIBIDAS) {
    if (z == p) return true;
  }
  return false;
}

// Cuanto se multiplica la sospecha de quien mira a este jugador.
// esJefe: si quien mira es el jefe de seguridad. d: distancia.
float factorDisfraz(Jugador j, boolean esJefe, float d) {
  if (!j.disfrazado) return 1;
  if (j.corriendo || j.agachado || j.arrastrando != null) return 1;
  if (esJefe && d < distanciaJefe()) return 1.6;   // el jefe te reconoce
  if (d < DISTANCIA_PEGADO) return 1;                // pegado a un vigilante, se nota
  return 0;
}

// Los empleados no se fijan en un conserje que hace lo suyo
float factorDisfrazCivil(Jugador j) {
  if (!j.disfrazado) return 1;
  if (j.corriendo || j.agachado || j.arrastrando != null) return 1;
  return 0;
}

boolean puedeTomarUniforme(Jugador j) {
  return !j.disfrazado && mapa.cercano(j.x, j.y, 'Z', 1.5) != null;
}

void ponerseUniforme(Jugador j) {
  j.disfrazado = true;
  sonar("recoger");
  j.agachado = false;
  avisar("Uniforme puesto: no te reconocen salvo que te les pegues. Camina normal y evita al jefe (gorra blanca)");
}

// Te descubrieron: el disfraz ya no sirve
void quemarDisfraz(Jugador j) {
  if (j == null || !j.disfrazado) return;
  j.disfrazado = false;
  j.disfrazQuemado = true;
}

// Avisa una vez al entrar disfrazado a un cuarto donde un conserje no entra
void revisarZonaDisfraz(Jugador j) {
  // el uniforme ya sirve en todos los cuartos; solo avisa una vez cuando
  // pasas cerca del casillero sin tenerlo puesto
  boolean cerca = puedeTomarUniforme(j);
  if (cerca && !j.avisoZona) eventoValeria("uniforme", 2, "", "En ese casillero hay uniformes de conserje. Póntelo con E: así casi nadie te reconoce.");
  if (cerca) j.avisoZona = true;
}


// ======================================================================
// Equipo.pde
// ======================================================================
// Acciones a dos (cooperativo).
// Puerta pesada: la puerta de carga del parqueadero tambien se puede abrir
// sin la tarjeta roja si los dos jugadores la empujan a la vez (mantener usar
// 2,5 s). Hace ruido. La otra accion a dos esta en la consola de seguridad:
// uno se queda vigilando con las camaras en bucle mientras el otro avanza.

final int PESADA_I = 30, PESADA_J = 21;
final float TIEMPO_EMPUJAR = 2.5;
float progresoEmpujar;

boolean puertaPesadaCerrada() {
  return mapa.esPuertaCerrada(PESADA_I, PESADA_J);
}

boolean juntoAPuertaPesada(Jugador j) {
  return dist(j.x, j.y, PESADA_I + 0.5, PESADA_J + 0.5) < 1.7;
}

void actualizarEquipo(float dt) {
  if (jugadores.size() < 2 || !puertaPesadaCerrada()) {
    progresoEmpujar = 0;
    return;
  }
  boolean empujan = true;
  for (Jugador j : jugadores) {
    if (j.atrapado || !juntoAPuertaPesada(j) || !j.usandoMantenido()) empujan = false;
  }
  if (empujan) {
    progresoEmpujar += dt / TIEMPO_EMPUJAR;
    if (progresoEmpujar >= 1) {
      mapa.abrirPuerta(PESADA_I, PESADA_J);
      sonar("empujar");
      sacudir(5);
      hacerRuido(PESADA_I + 0.5, PESADA_J + 0.5, 3.5);
      avisar("Entre los dos forzaron la puerta de carga (hizo ruido)");
      progresoEmpujar = 0;
    }
  } else {
    progresoEmpujar = max(0, progresoEmpujar - dt * 0.5);
  }
}

void dibujarEquipo() {
  if (progresoEmpujar <= 0) return;
  float sx = pantallaX(PESADA_I + 0.5, PESADA_J + 0.5);
  float sy = pantallaY(PESADA_I + 0.5, PESADA_J + 0.5) - 44 * pixel;
  noStroke();
  fill(40, 46, 70);
  rect(sx - 30 * escala, sy, 60 * escala, 6 * escala);
  fill(NEON_VERDE);
  rect(sx - 30 * escala, sy, 60 * escala * progresoEmpujar, 6 * escala);
}


// ======================================================================
// Hud.pde
// ======================================================================
// Interfaz encima del mundo: objetivos, estado de alerta, postura y ruido de
// cada jugador, avisos y las pantallas de inicio y final.

void dibujarHud(float dt) {
  tiempoAviso = max(0, tiempoAviso - dt);
  float e = escala;

  // Bordes oscuros para que se sienta de noche
  noFill();
  for (int k = 0; k < 6; k++) {
    stroke(0, 28);
    strokeWeight((60 - k * 9) * e);
    rect(0, 0, width, height);
  }

  // Destello rojo cuando te descubren o suena una alarma
  if (destelloAlarma > 0) {
    stroke(232, 52, 78, 190 * destelloAlarma);
    strokeWeight(14 * e);
    rect(0, 0, width, height);
  }

  if (estado == INICIO || estado == ELEGIR_ROL || estado == CREDITOS || estado == LLAMADA) return;
  if (estado == RECONOCIMIENTO) {
    dibujarHudReconocimiento();
    return;
  }
  if (mapaAbierto) {
    dibujarHudMapa();
    return;
  }

  // Objetivos, alarma, jugadores y avisos en pixel art (HudPixel.pde)
  dibujarHudPixel();

  if (ventana != 0) dibujarVentana();
  dibujarDestelloFoto();

}

void dibujarHudReconocimiento() {
  float e = escala;
  float w = 640 * e;
  float x = width / 2 - w / 2;
  float y = 14 * e;
  panel(x, y, w, 100 * e);
  textAlign(CENTER, TOP);
  textFont(letraGrande);
  fill(NEON_MAGENTA);
  text("RECONOCIMIENTO", width / 2, y + 10 * e);
  textFont(letraChica);
  fill(215);
  text("Estudia las rondas, las cámaras, las tarjetas y los ductos. Adentro ya no se dibujan las rutas.", width / 2, y + 42 * e);
  // tiempo que queda
  float resto = max(0, tiempoReconocimiento) / tiempoReconocimientoTotal();
  noStroke();
  fill(40);
  rect(x + 20 * e, y + 64 * e, w - 40 * e, 6 * e);
  fill(NEON_MAGENTA);
  rect(x + 20 * e, y + 64 * e, (w - 40 * e) * resto, 6 * e);
  fill(160);
  text("Enter o Espacio: entrar ya   ·   " + ceil(max(0, tiempoReconocimiento)) + " s", width / 2, y + 78 * e);

  // Leyenda de colores abajo (sin nombres: una raya de color por cada ronda)
  textFont(letraChica);
  String rondas = "Rondas de los vigilantes";
  String camara = "Zona que barre cada cámara";
  float rayas = vigilantes.size() * 14 * e;
  float total = rayas + 8 * e + textWidth(rondas) + 40 * e + 22 * e + 8 * e + textWidth(camara);
  float lx = width / 2 - total / 2;
  float ly = height - 34 * e;
  panel(lx - 14 * e, ly - 16 * e, total + 28 * e, 32 * e);
  textAlign(LEFT, CENTER);
  noStroke();
  for (Vigilante v : vigilantes) {
    fill(v.colorRonda);
    rect(lx, ly - 2 * e, 10 * e, 4 * e);
    lx += 14 * e;
  }
  fill(220);
  text(rondas, lx + 8 * e, ly);
  lx += 8 * e + textWidth(rondas) + 40 * e;
  fill(25, 227, 227, 120);
  rect(lx, ly - 6 * e, 22 * e, 12 * e);
  fill(220);
  text(camara, lx + 30 * e, ly);
}

void tarjetaJugador(Jugador j, float x, float y) {
  float e = escala;
  panel(x, y, 420 * e, 70 * e);
  noStroke();
  fill(j.ropa);
  rect(x, y, 5 * e, 70 * e);
  textFont(letraMedia);
  textAlign(LEFT, TOP);
  fill(235);
  text("J" + j.numero + " " + NOMBRES_ROL[j.rol] + " · " + j.postura(), x + 14 * e, y + 8 * e);
  textFont(letraChica);
  textAlign(RIGHT, CENTER);
  fill(j.botellas > 0 ? NEON_VERDE : color(110));
  text("Botellas: " + j.botellas, x + 408 * e, y + 38 * e);
  // habilidad del rol: lista o cuanto le falta
  textAlign(LEFT, CENTER);
  boolean lista = j.enfriamiento <= 0;
  fill(lista ? (j.rol == ROL_HACKER ? NEON_CIAN : NEON_MAGENTA) : color(110));
  text(j.teclaHabilidad() + ": " + (j.sombra > 0 ? "activa" : (lista ? "lista" : ceil(j.enfriamiento) + " s")), x + 226 * e, y + 38 * e);
  // Mochila: kilos que lleva de los que caben
  textFont(letraChica);
  textAlign(RIGHT, TOP);
  fill(j.peso >= CAPACIDAD_MOCHILA ? COLOR_AMBAR : color(200));
  text("Mochila " + j.peso + "/" + CAPACIDAD_MOCHILA + " kg", x + 408 * e, y + 10 * e);
  // Ruido: 10 rayitas, se llenan segun hasta donde se oyen los pasos
  textFont(letraChica);
  textAlign(LEFT, CENTER);
  fill(160);
  text("Ruido", x + 14 * e, y + 38 * e);
  int llenas = min(10, round(j.radioRuido() / 3.7 * 10));
  for (int k = 0; k < 10; k++) {
    if (k < llenas) fill(k < 4 ? NEON_VERDE : (k < 7 ? COLOR_AMBAR : COLOR_RIVAL));
    else fill(35, 42, 66);
    rect(x + 70 * e + k * 14 * e, y + 33 * e, 10 * e, 10 * e);
  }
  fill(130);
  textAlign(LEFT, BOTTOM);
  String controles = j.numero == 1 ? "WASD · Shift corre · C agacha · E usa · Q lanza · X suelta · F rol"
    : "Flechas · - corre · . agacha · Enter · , lanza · K suelta · M rol";
  text(controles, x + 14 * e, y + 66 * e);
}

void objetivo(float x, float y, boolean hecho, String texto) {
  float e = escala;
  stroke(hecho ? NEON_VERDE : color(130));
  strokeWeight(1.5 * e);
  noFill();
  rect(x, y + 2 * e, 11 * e, 11 * e);
  if (hecho) {
    line(x + 2 * e, y + 8 * e, x + 5 * e, y + 11 * e);
    line(x + 5 * e, y + 11 * e, x + 10 * e, y + 3 * e);
  }
  noStroke();
  fill(hecho ? NEON_VERDE : color(220));
  textAlign(LEFT, TOP);
  text(texto, x + 18 * e, y);
}

// Panel de las ventanas y menus: el mismo marco del HUD en pixel art,
// agrandado a la escala del arte
void panel(float x, float y, float w, float h) {
  panel(x, y, w, h, NEON_CIAN);
}

void panel(float x, float y, float w, float h, color c) {
  pushMatrix();
  translate(round(x), round(y));
  scale(pixel);
  strokeWeight(1);
  marcoPixel(g, 0, 0, round(w / pixel) - 1, round(h / pixel) - 1, c);
  popMatrix();
  noStroke();
}

String reloj(float segundos) {
  int s = floor(segundos);
  return nf(s / 60, 2) + ":" + nf(s % 60, 2);
}

// ---------------------------------------------------------------------------
// Pantallas
// ---------------------------------------------------------------------------

void dibujarPantallaInicio() {
  float e = escala;
  noStroke();
  fill(0, 150);
  rect(0, 0, width, height);
  float w = 780 * e;
  float h = 510 * e;
  float x = width / 2 - w / 2;
  float y = height / 2 - h / 2;
  panel(x, y, w, h);

  textAlign(CENTER, TOP);
  textFont(letraTitulo);
  fill(NEON_MAGENTA);
  text("INFILTRADO", width / 2, y + 28 * e);
  textFont(letraMedia);
  fill(160);
  text("Prueba del modo sigilo · Alcalde Digital", width / 2, y + 88 * e);

  fill(225);
  text("Es de noche. Te metes a la sede de Titulares Ya, la agencia que fabrica", width / 2, y + 128 * e);
  text("los bulos contra tu campaña. Copia su servidor y sal sin que te atrapen.", width / 2, y + 150 * e);

  float cx = x + 50 * e;
  textAlign(LEFT, TOP);
  fill(NEON_CIAN);
  text("Jugador 1", cx, y + 196 * e);
  fill(NEON_VERDE);
  text("Jugador 2", cx + 360 * e, y + 196 * e);
  textFont(letraChica);
  fill(210);
  String[] c1 = {"WASD   mover", "Shift  correr (hace ruido)", "C      agacharse (no hace ruido)", "E      usar / mantener para copiar", "Q / X  lanzar botella / soltar botín", "F      habilidad del rol"};
  String[] c2 = {"Flechas  mover", "-        correr", ".        agacharse", "Enter    usar", ", / K    lanzar / soltar botín", "M        habilidad del rol"};
  for (int k = 0; k < 6; k++) {
    text(c1[k], cx, y + 222 * e + k * 20 * e);
    text(c2[k], cx + 360 * e, y + 222 * e + k * 20 * e);
  }

  fill(170);
  textAlign(CENTER, TOP);
  text("Correr hace ruido y los vigilantes lo oyen. Agachado y en la sombra cuesta más verte.", width / 2, y + 354 * e);
  text("Tarjetas abren puertas, los ductos son atajos y cortar la luz te esconde.", width / 2, y + 374 * e);

  textFont(letraGrande);
  boolean parpadeo = (frameCount / 30) % 2 == 0;
  fill(parpadeo ? 255 : 200);
  text("1  jugar solo        2  cooperativo", width / 2, y + 410 * e);
  textFont(letraChica);
  fill(120);
  text("C créditos   ·   Esc para salir", width / 2, y + 465 * e);
}

void dibujarPantallaFinal() {
  dibujarCalificacion();
}

// ---------------------------------------------------------------------------
// Lo que se lee en la oficina del rival
// ---------------------------------------------------------------------------

void dibujarVentana() {
  if (ventana == 5) {
    dibujarConsola();
    return;
  }
  if (ventana == 6) {
    dibujarTeclado();
    return;
  }
  float e = escala;
  float w = min(560 * e, width - 40 * e);
  float h = 330 * e;
  float x = width / 2 - w / 2;
  float y = height / 2 - h / 2 - 20 * e;
  noStroke();
  fill(0, 120);
  rect(0, 0, width, height);
  panel(x, y, w, h);
  textAlign(LEFT, TOP);
  textFont(letraMedia);
  String titulo = "";
  String pie = "";
  if (ventana == 1) {
    titulo = "Celular del rival · chat con Max Rumor";
    pie = "El borrador del bulo sigue abierto en su computador.";
    String[][] chat = {
      {"Max Rumor", "Jefe, mañana sale el del agua contaminada en El Puerto."},
      {"Rival", "Perfecto. Que parezca real, con foto y todo."},
      {"Max Rumor", "Y el miércoles, lo de los subsidios falsos en Barrio Sur."},
      {"Rival", "El de La Colina ni se va a dar cuenta."}
    };
    float cy = y + 52 * e;
    textFont(letraChica);
    for (String[] m : chat) {
      boolean suyo = m[0].equals("Rival");
      float bw = w * 0.86;
      float bx = suyo ? x + w - bw - 20 * e : x + 20 * e;
      stroke(suyo ? COLOR_RIVAL : NEON_MAGENTA);
      strokeWeight(1);
      fill(suyo ? color(60, 20, 34) : color(40, 18, 46));
      rect(bx, cy, bw, 44 * e, 6 * e);
      noStroke();
      fill(suyo ? COLOR_RIVAL : NEON_MAGENTA);
      text(m[0], bx + 10 * e, cy + 6 * e);
      fill(235);
      text(m[1], bx + 10 * e, cy + 22 * e);
      cy += 54 * e;
    }
  } else if (ventana == 2) {
    titulo = "Tablero de conspiración";
    pie = "Nos siguen barrio por barrio. Los hilos son las calles de la ciudad.";
    String[] barrios = {"Centro", "La Universidad", "La Colina", "El Puerto", "El Mercado", "Barrio Sur", "Parque Industrial", "Barrio Norte"};
    float[][] pos = {{0.5, 0.45}, {0.3, 0.2}, {0.12, 0.45}, {0.3, 0.75}, {0.55, 0.85}, {0.82, 0.8}, {0.85, 0.4}, {0.65, 0.15}};
    int[][] calles = {{0, 1}, {0, 3}, {0, 4}, {0, 6}, {0, 7}, {1, 2}, {1, 7}, {2, 3}, {3, 4}, {4, 5}, {5, 6}, {6, 7}};
    float gx = x + 30 * e, gy = y + 50 * e, gw = w - 60 * e, gh = h - 110 * e;
    noStroke();
    fill(143, 86, 52);
    rect(gx - 10 * e, gy - 10 * e, gw + 20 * e, gh + 20 * e, 4 * e);
    stroke(COLOR_RIVAL);
    strokeWeight(2 * e);
    for (int[] c : calles) {
      line(gx + pos[c[0]][0] * gw, gy + pos[c[0]][1] * gh, gx + pos[c[1]][0] * gw, gy + pos[c[1]][1] * gh);
    }
    textFont(letraChica);
    textAlign(CENTER, TOP);
    for (int k = 0; k < barrios.length; k++) {
      float px = gx + pos[k][0] * gw, py = gy + pos[k][1] * gh;
      noStroke();
      fill(k == 2 ? NEON_CIAN : color(242, 242, 233));
      rect(px - 10 * e, py - 12 * e, 20 * e, 16 * e);
      fill(COLOR_RIVAL);
      ellipse(px, py - 12 * e, 6 * e, 6 * e);
      fill(20);
      text(barrios[k], px, py + 6 * e);
    }
    textAlign(LEFT, TOP);
  } else if (ventana == 3) {
    titulo = "Cuaderno del rival";
    pie = "Anotó: \"esta noche imprimir los volantes falsos en la redacción\".";
    String[][] filas = {
      {"Granja de bots", "desbloqueada", "Cientos de cuentas falsas que comparten todo"},
      {"Deepfakes del estudio", "desbloqueada", "Videos falsos grabados en la pantalla verde"},
      {"Prensa comprada", "en progreso", "Periodistas que repiten sus titulares"},
      {"Hackear al influencer", "bloqueada", "Su próximo objetivo: Nico Viral"}
    };
    float cy = y + 56 * e;
    textFont(letraChica);
    for (String[] f : filas) {
      fill(f[1].equals("bloqueada") ? color(130) : COLOR_AMBAR);
      text("● " + f[0], x + 24 * e, cy);
      fill(f[1].equals("desbloqueada") ? COLOR_RIVAL : color(150));
      textAlign(RIGHT, TOP);
      text(f[1], x + w - 24 * e, cy);
      textAlign(LEFT, TOP);
      fill(190);
      text(f[2], x + 40 * e, cy + 18 * e);
      cy += 50 * e;
    }
  } else if (ventana == 4) {
    titulo = "TV · Titulares Ya en vivo";
    pie = "Así venden sus bulos todas las noches.";
    float tx = x + 30 * e, ty = y + 56 * e, tw = w - 60 * e, th = h - 130 * e;
    noStroke();
    fill(30, 39, 66);
    rect(tx, ty, tw, th);
    fill(COLOR_RIVAL);
    rect(tx, ty + th - 40 * e, tw, 40 * e);
    fill(255);
    textFont(letraMedia);
    text("¿EL CANDIDATO DE LA COLINA ESCONDE ALGO?", tx + 12 * e, ty + th - 32 * e, tw - 24 * e, 30 * e);
    fill(227, 167, 126);
    rect(tx + tw / 2 - 30 * e, ty + 30 * e, 60 * e, 70 * e);
    fill(COLOR_RIVAL);
    textFont(letraChica);
    text("● EN VIVO", tx + 10 * e, ty + 8 * e);
  }
  textFont(letraMedia);
  textAlign(LEFT, TOP);
  fill(NEON_MAGENTA);
  text(titulo, x + 20 * e, y + 16 * e);
  textFont(letraChica);
  fill(190);
  text(pie, x + 20 * e, y + h - 40 * e, w - 40 * e, 20 * e);
  fill(130);
  textAlign(RIGHT, TOP);
  text("Muévete o presiona usar para cerrar", x + w - 20 * e, y + h - 22 * e);
}

// Nombre para el plano: el jefe se distingue de los vigilantes
String nombreVigilante(int n) {
  return vigilantes.get(n).esJefe ? "Jefe de seguridad" : "Vigilante " + (n + 1);
}


// ======================================================================
// HudPixel.pde
// ======================================================================
// HUD en pixel art (opcion 2 de los bocetos). Se dibuja en una capa del
// tamano del arte (la pantalla dividida por "pixel", unos 640 x 360) con letra
// sin suavizar, y despues se agranda sin suavizar: asi los marcos, los iconos
// y las letras quedan con pixeles gruesos como los sprites.

PGraphics capaHud;
PFont pixel8, pixel10, pixel12;
HashMap<PImage, PImage> retratos = new HashMap<PImage, PImage>();

void prepararHudPixel() {
  capaHud = createGraphics(ceil(width / (float) pixel), ceil(height / (float) pixel));
  capaHud.noSmooth();   // antes de beginDraw: si no, Processing lo ignora y la letra sale suavizada (borrosa al agrandarla)
  pixel8 = createFont("DejaVuSansMono-Bold.ttf", 8, false);
  pixel10 = createFont("DejaVuSansMono-Bold.ttf", 10, false);
  pixel12 = createFont("DejaVuSansMono-Bold.ttf", 12, false);
}

// ---------------------------------------------------------------- piezas

// Marco con bisel, remaches en las esquinas y esquinas claras en L
void marcoPixel(PGraphics g, int x0, int y0, int x1, int y1, color c) {
  g.noStroke();
  g.fill(15, 20, 36, 235);
  g.rect(x0, y0, x1 - x0 + 1, y1 - y0 + 1);
  g.noFill();
  g.stroke(5, 7, 13);
  g.rect(x0, y0, x1 - x0, y1 - y0);
  g.stroke(c);
  g.rect(x0 + 1, y0 + 1, x1 - x0 - 2, y1 - y0 - 2);
  g.stroke(red(c), green(c), blue(c), 110);
  g.line(x0 + 2, y0 + 2, x1 - 2, y0 + 2);
  g.stroke(20, 26, 46);
  g.line(x0 + 2, y1 - 2, x1 - 2, y1 - 2);
  g.noStroke();
  g.fill(201, 205, 211);
  int[][] remaches = {{x0 + 3, y0 + 3}, {x1 - 4, y0 + 3}, {x0 + 3, y1 - 4}, {x1 - 4, y1 - 4}};
  for (int[] r : remaches) g.rect(r[0], r[1], 2, 2);
  g.fill(242, 242, 233);
  g.rect(x0, y0, 7, 1);
  g.rect(x0, y0, 1, 7);
  g.rect(x1 - 6, y0, 7, 1);
  g.rect(x1, y0, 1, 7);
  g.rect(x0, y1, 7, 1);
  g.rect(x0, y1 - 6, 1, 7);
  g.rect(x1 - 6, y1, 7, 1);
  g.rect(x1, y1 - 6, 1, 7);
}

void textoPixel(PGraphics g, String t, float x, float y, color c, PFont f) {
  g.textFont(f);
  g.fill(c);
  g.text(t, round(x), round(y));
}

void iconoTarjeta(PGraphics g, int x, int y, color c, boolean llena) {
  g.noStroke();
  if (llena) {
    g.fill(c);
    g.rect(x, y, 10, 7);
    g.fill(242, 242, 233);
    g.rect(x + 2, y + 2, 3, 2);
  } else {
    g.noFill();
    g.stroke(c);
    g.rect(x, y, 9, 6);
    g.noStroke();
    g.fill(c);
    g.rect(x + 2, y + 2, 3, 2);
  }
}

void iconoMochila(PGraphics g, int x, int y, color c) {
  g.noStroke();
  g.fill(c);
  g.rect(x + 1, y + 2, 8, 8);
  g.rect(x + 3, y, 4, 1);
  g.rect(x + 3, y, 1, 2);
  g.rect(x + 6, y, 1, 2);
  g.fill(122, 74, 16);
  g.rect(x + 3, y + 5, 4, 3);
}

void iconoOreja(PGraphics g, int x, int y, color c) {
  g.noStroke();
  g.fill(c);
  g.rect(x + 2, y, 4, 1);
  g.rect(x + 1, y + 1, 1, 6);
  g.rect(x + 6, y + 1, 1, 4);
  g.rect(x + 5, y + 5, 1, 2);
  g.rect(x + 3, y + 7, 2, 1);
  g.rect(x + 3, y + 3, 2, 2);
}

void iconoSirena(PGraphics g, int x, int y, color c, boolean prendida) {
  g.noStroke();
  g.fill(92, 100, 120);
  g.rect(x, y + 7, 10, 3);
  g.fill(prendida ? c : color(red(c) * 0.45, green(c) * 0.45, blue(c) * 0.45));
  g.rect(x + 2, y + 2, 6, 5);
  g.rect(x + 3, y + 1, 4, 1);
  if (prendida) {
    g.rect(x - 2, y + 1, 1, 1);
    g.rect(x + 11, y + 1, 1, 1);
    g.rect(x + 4, y - 2, 2, 1);
  }
}

void iconoBotella(PGraphics g, int x, int y) {
  g.noStroke();
  g.fill(30, 122, 76);
  g.rect(x + 1, y + 3, 3, 7);
  g.rect(x + 2, y, 1, 3);
  g.fill(61, 220, 132);
  g.rect(x + 1, y + 4, 1, 2);
}

// Cara del jugador sacada de su sprite (el arte ya esta a escala 1)
PImage retrato(PImage sprite) {
  PImage r = retratos.get(sprite);
  if (r == null) {
    r = sprite.get(2, 2, 12, 12);
    retratos.put(sprite, r);
  }
  return r;
}

void barraPixel(PGraphics g, int x, int y, int partes, int llenas, int ancho, int alto, color[] colores) {
  g.noStroke();
  for (int k = 0; k < partes; k++) {
    g.fill(k < llenas ? colores[min(colores.length - 1, k * colores.length / partes)] : color(35, 42, 72));
    g.rect(x + k * (ancho + 2), y, ancho, alto);
  }
}

// ---------------------------------------------------------------- HUD

void dibujarHudPixel() {
  PGraphics g = capaHud;
  g.beginDraw();
  g.clear();
  g.textAlign(LEFT, TOP);
  int an = g.width;
  int al = g.height;

  if (soloEscapar()) {
    dibujarPanelEscape(g);
  } else {
    dibujarObjetivosPixel(g);
  }

  // Estado y alarma (arriba a la derecha)
  dibujarEstadoPixel(g, an);

  // Tarjeta de cada jugador (abajo)
  for (int k = 0; k < jugadores.size(); k++) tarjetaJugadorPixel(g, jugadores.get(k), 8 + k * 236, al - 62);
  if (jugadores.size() == 1) {
    g.textAlign(RIGHT, BOTTOM);
    textoPixel(g, desdeCampana ? "G mapa · V rutas · R reiniciar la misión" : "G mapa · V rutas · R reiniciar · Esc salir", an - 8, al - 4, color(110, 118, 145), pixel8);
    g.textAlign(LEFT, TOP);
  }

  // Aviso del momento
  if (tiempoAviso > 0 && !aviso.equals("")) {
    g.textFont(pixel8);
    int aw = ceil(g.textWidth(aviso)) + 20;
    int ax = an / 2 - aw / 2;
    int ay = round(al * 0.37) - 10;
    marcoPixel(g, ax, ay, ax + aw, ay + 20, NEON_MAGENTA);
    textoPixel(g, aviso, ax + 10, ay + 5, color(242, 242, 233), pixel8);
  }
  g.endDraw();
  image(capaHud, 0, 0, capaHud.width * pixel, capaHud.height * pixel);
}

// Con el servidor copiado: solo las salidas y lo que se lleva
void dibujarPanelEscape(PGraphics g) {
  marcoPixel(g, 8, 8, 236, 84, NEON_VERDE);
  textoPixel(g, "ESCAPA", 15, 11, NEON_VERDE, pixel12);
  g.textAlign(RIGHT, TOP);
  textoPixel(g, horaTexto(), 229, 14, color(242, 242, 233), pixel8);
  g.textAlign(LEFT, TOP);
  String[] nombres = {"Camioneta (entrada)", "Moto (fondo del parqueadero)", "Ducto a la calle"};
  for (int s = 0; s < 3; s++) {
    int y = 30 + s * 12;
    String b = bloqueoSalida(s);
    // "espera a tu compañero" no cuenta como bloqueo: la salida sirve
    boolean sirve = b.equals("") || b.startsWith("Espera");
    color c = sirve ? color(242, 242, 233) : color(92, 103, 135);
    g.noStroke();
    g.fill(sirve ? NEON_VERDE : COLOR_RIVAL);
    g.rect(16, y + 2, 5, 5);
    textoPixel(g, nombres[s], 26, y - 1, c, pixel8);
    if (!sirve) {
      g.textAlign(RIGHT, TOP);
      textoPixel(g, s == SALIDA_DUCTO ? "más de 2 kg" : "bloqueada", 229, y - 1, COLOR_RIVAL, pixel8);
      g.textAlign(LEFT, TOP);
    }
  }
  int llevadas = 0;
  for (Jugador j : jugadores) llevadas += j.valorBotin;
  textoPixel(g, "Llevas " + llevadas + " puntos de botín", 16, 70, COLOR_AMBAR, pixel8);
}

void dibujarObjetivosPixel(PGraphics g) {
  // Objetivos
  marcoPixel(g, 8, 8, 236, 100, NEON_CIAN);
  textoPixel(g, "INFILTRADO", 15, 11, NEON_CIAN, pixel12);
  g.textAlign(RIGHT, TOP);
  textoPixel(g, horaTexto(), 229, 14, color(242, 242, 233), pixel8);
  g.textAlign(LEFT, TOP);
  int llevadas = 0;
  for (Jugador j : jugadores) llevadas += j.valorBotin;
  // copiar el servidor va de ultimo: despues ya solo se escapa
  boolean[] hechos = {llevadas >= mejorBotin, chatLeido, oportunidadesHechas() == 3, servidorCopiado};
  String[] textos = {"Botín: " + llevadas + " (lo mejor que cabe: " + mejorBotin + ")",
    "Extra: lee el chat del rival", "Extra: oportunidades " + oportunidadesHechas() + "/3", "Al final: copia el servidor"};
  for (int k = 0; k < 4; k++) {
    int y = 30 + k * 11;
    color c = hechos[k] ? NEON_VERDE : color(242, 242, 233);
    g.noStroke();
    if (hechos[k]) {
      g.fill(c);
      g.rect(16, y + 1, 6, 6);
    } else {
      g.noFill();
      g.stroke(c);
      g.rect(16, y + 1, 5, 5);
      g.noStroke();
    }
    textoPixel(g, textos[k], 26, y - 2, c, pixel8);
  }
  // barra de copia junto al ultimo objetivo
  if (!servidorCopiado && progresoServidor > 0) {
    g.fill(35, 42, 72);
    g.rect(170, 64, 58, 5);
    g.fill(NEON_MAGENTA);
    g.rect(170, 64, round(58 * progresoServidor), 5);
  }
  // tarjetas
  color[] colores = {0, COLOR_RIVAL, #3E7BFF, COLOR_AMBAR, NEON_CIAN};
  String[] nombres = {"", "roja", "azul", "amar.", codigoConocido()};
  for (int k = 1; k <= 4; k++) {
    int x = 16 + (k - 1) * 56;
    iconoTarjeta(g, x, 76, colores[k], tarjetas[k]);
    textoPixel(g, nombres[k], x + 13, 74, tarjetas[k] ? color(242, 242, 233) : color(92, 103, 135), pixel8);
  }
  boolean[] alcanza = mapa.zonasAlcanzables(tarjetas);
  int n = 0;
  for (boolean b : alcanza) if (b) n++;
  textoPixel(g, "Alcanzas " + n + " de " + alcanza.length + " cuartos", 16, 86, color(125, 139, 176), pixel8);

  // Oportunidades (cuando ya se descubrio alguna)
  boolean algunaVista = false;
  for (boolean b : oportunidadVista) if (b) algunaVista = true;
  if (algunaVista) {
    marcoPixel(g, 8, 104, 236, 152, NEON_MAGENTA);
    textoPixel(g, "OPORTUNIDADES " + oportunidadesHechas() + "/3", 15, 107, NEON_MAGENTA, pixel8);
    for (int k = 0; k < 3; k++) {
      int y = 119 + k * 10;
      String t = oportunidadVista[k] ? NOMBRES_OPORTUNIDAD[k] : "??? (revisa la oficina)";
      if (oportunidadVista[k] && !oportunidadHecha[k] && progresoOportunidad[k] > 0 && k != 1) t += " " + round(progresoOportunidad[k] * 100) + "%";
      color c = oportunidadHecha[k] ? NEON_VERDE : (oportunidadVista[k] ? color(242, 242, 233) : color(92, 103, 135));
      g.noStroke();
      g.fill(c);
      if (oportunidadHecha[k]) g.rect(16, y + 2, 5, 5);
      else g.rect(17, y + 4, 3, 1);
      textoPixel(g, t, 26, y - 1, c, pixel8);
    }
  }

}

void dibujarEstadoPixel(PGraphics g, int an) {
  int peor = V_PATRULLA;
  for (Vigilante v : vigilantes) {
    if (v.inconsciente) continue;
    if (v.estado == V_ALERTA) peor = V_ALERTA;
    else if (v.estado != V_PATRULLA && peor != V_ALERTA) peor = V_SOSPECHA;
  }
  String texto = "SIN DETECTAR";
  color c = NEON_VERDE;
  if (peor == V_SOSPECHA) {
    texto = "SOSPECHAN";
    c = COLOR_AMBAR;
  }
  if (peor == V_ALERTA) {
    texto = "¡ALERTA!";
    c = (frameCount / 10) % 2 == 0 ? COLOR_RIVAL : color(140, 28, 46);
  }
  color[] coloresAlarma = {NEON_VERDE, COLOR_AMBAR, #FF7A3D, COLOR_RIVAL};
  int alto = nivelAlarma == 3 ? 62 : 52;
  marcoPixel(g, an - 136, 8, an - 8, 8 + alto, c);
  iconoSirena(g, an - 128, 15, c, peor != V_PATRULLA && (frameCount / 12) % 2 == 0);
  textoPixel(g, texto, an - 112, 11, c, pixel12);
  for (int k = 0; k < 3; k++) {
    g.noStroke();
    g.fill(k < nivelAlarma ? coloresAlarma[nivelAlarma] : color(35, 42, 72));
    g.rect(an - 112 + k * 16, 34, 13, 6);
  }
  g.textAlign(RIGHT, TOP);
  textoPixel(g, "NIVEL " + nivelAlarma, an - 15, 32, coloresAlarma[nivelAlarma], pixel8);
  textoPixel(g, NOMBRES_ALARMA[nivelAlarma], an - 15, 44 - 1, color(160, 168, 190), pixel8);
  if (nivelAlarma == 3) textoPixel(g, "Policía en " + ceil(max(0, tiempoPolicia)) + " s", an - 15, 54, (frameCount / 15) % 2 == 0 ? COLOR_RIVAL : color(242, 242, 233), pixel8);
  g.textAlign(LEFT, TOP);
}

void tarjetaJugadorPixel(PGraphics g, Jugador j, int x, int y) {
  color c = j.ropa;
  marcoPixel(g, x, y, x + 228, y + 54, c);
  // retrato
  SpritesPersona s = j.numero == 1 ? spritesJugador1 : spritesJugador2;
  if (j.disfrazado) s = j.numero == 1 ? spritesConserje1 : spritesConserje2;
  g.noStroke();
  g.fill(29, 58, 74);
  g.rect(x + 6, y + 6, 20, 20);
  g.noFill();
  g.stroke(c);
  g.rect(x + 6, y + 6, 19, 19);
  g.image(retrato(s.frente[0]), x + 10, y + 10);
  textoPixel(g, "J" + j.numero + " " + NOMBRES_ROL[j.rol], x + 31, y + 4, c, pixel10);
  textoPixel(g, j.postura(), x + 31, y + 16, color(242, 242, 233), pixel8);
  // botellas
  iconoBotella(g, x + 170, y + 6);
  textoPixel(g, "x" + j.botellas, x + 177, y + 5, j.botellas > 0 ? NEON_VERDE : color(110, 118, 145), pixel10);
  // ruido
  iconoOreja(g, x + 6, y + 31, color(154, 163, 181));
  int llenas = min(10, round(j.radioRuido() / 3.7 * 10));
  color[] coloresRuido = {NEON_VERDE, NEON_VERDE, NEON_VERDE, NEON_VERDE, COLOR_AMBAR, COLOR_AMBAR, COLOR_AMBAR, COLOR_RIVAL, COLOR_RIVAL, COLOR_RIVAL};
  barraPixel(g, x + 18, y + 33, 10, llenas, 5, 6, coloresRuido);
  // mochila
  iconoMochila(g, x + 94, y + 30, j.peso >= CAPACIDAD_MOCHILA ? COLOR_RIVAL : COLOR_AMBAR);
  color[] coloresMochila = {COLOR_AMBAR};
  barraPixel(g, x + 106, y + 33, CAPACIDAD_MOCHILA, j.peso, 4, 6, coloresMochila);
  // habilidad del rol
  boolean lista = j.enfriamiento <= 0;
  String hab = j.teclaHabilidad() + ": " + (j.sombra > 0 ? "activa" : (lista ? "lista" : ceil(j.enfriamiento) + " s"));
  textoPixel(g, hab, x + 150, y + 31, lista ? (j.rol == ROL_HACKER ? NEON_CIAN : NEON_MAGENTA) : color(110, 118, 145), pixel8);
  // controles
  String controles = j.numero == 1 ? "WASD C agacha E usa Q lanza X suelta F rol" : "Flechas . agacha Enter , lanza K suelta M rol";
  textoPixel(g, controles, x + 6, y + 43, color(92, 103, 135), pixel8);
}


// ======================================================================
// Interaccion.pde
// ======================================================================
// Marcas de lo que se puede usar. Al acercarse, el objeto se marca con un
// borde que palpita y encima sale la tecla y la accion. El color dice que
// pasa: cian se usa, verde se recoge, ambar esta cerrado y falta algo.
// De mas lejos (RADIO_BRILLO) lo usable tiene un borde suave.

final float RADIO_BRILLO = 4;

// Que hay para usar al lado de un jugador
class Interaccion {
  int i, j;           // baldosa del objeto
  Persona persona;    // o la persona (para noquear o arrastrar)
  String accion;
  boolean conTecla;   // false: solo informa, no hay nada que presionar
  color c;

  Interaccion(int[] t, String accion, boolean conTecla, color c) {
    i = t[0];
    j = t[1];
    this.accion = accion;
    this.conTecla = conTecla;
    this.c = c;
  }

  // Para marcar a un jugador (el compañero esposado): solo la etiqueta
  float px, py;
  boolean enPunto;
  Interaccion(float x, float y, String accion, color c) {
    i = -1;
    j = -1;
    px = x;
    py = y;
    enPunto = true;
    this.accion = accion;
    this.conTecla = true;
    this.c = c;
  }

  Interaccion(Persona p, String accion, color c) {
    persona = p;
    i = -1;
    j = -1;
    this.accion = accion;
    this.conTecla = true;
    this.c = c;
  }
}

// Marca de cada persona en este cuadro (noquear, arrastrar, cuerpo cerca)
HashMap<Persona, Float> marcaPersona = new HashMap<Persona, Float>();
HashMap<Persona, Integer> colorPersona = new HashMap<Persona, Integer>();

float marcaDe(Persona p) {
  Float f = marcaPersona.get(p);
  return f == null ? 0 : f;
}

color colorMarcaDe(Persona p) {
  Integer c = colorPersona.get(p);
  return c == null ? 0 : c;
}

// Contorno de una persona (se llama ya trasladado a sus pies, despues de
// dibujarla)
void contornoPersona(PImage img, color c, float f) {
  PImage b = contorno(img);
  float pulso = f >= 1 ? 0.65 + 0.35 * sin(millis() / 140.0) : 0.8 + 0.2 * sin(millis() / 400.0);
  tint(red(c), green(c), blue(c), 255 * f * pulso);
  // dos pixeles de grueso: la gente es chica y se mueve
  image(b, -9 * pixel, -28 * pixel, b.width * pixel, b.height * pixel);
  int[][] lados = {{-1, 0}, {1, 0}, {0, -1}, {0, 1}};
  for (int[] d : lados) image(b, (-9 + d[0]) * pixel, (-28 + d[1]) * pixel, b.width * pixel, b.height * pixel);
  noTint();
}

// Fuerza de la marca de cada baldosa en este cuadro (0 nada, 1 la de al lado)
float[][] marca;
color[][] colorMarca;
// Silueta blanca de cada sprite y la primera fila con pixeles (para la etiqueta)
HashMap<PImage, PImage> siluetas = new HashMap<PImage, PImage>();
HashMap<PImage, Integer> filaArriba = new HashMap<PImage, Integer>();

// Mismo orden que usar(): lo primero que se encuentra es lo que se hace
Interaccion interaccionPara(Jugador j) {
  if (estado != JUGANDO || j.enDucto || j.escondido || ventana != 0 || j.contestando != null) return null;
  int[] t;
  if (j.atrapado) return null;
  Jugador esposado = companeroAtrapado(j);
  if (esposado != null) return new Interaccion(esposado.x, esposado.y, "Mantén: soltar a J" + esposado.numero, NEON_VERDE);
  int sal = salidaCercana(j);
  if (sal >= 0 && servidorCopiado) {
    String b = bloqueoSalida(sal);
    int[] ts = sal == SALIDA_DUCTO ? new int[] {DUCTO_CALLE_I, DUCTO_CALLE_J} : mapa.cercano(j.x, j.y, sal == SALIDA_CAMIONETA ? 'E' : 'm', 1.6);
    if (b.equals("")) return new Interaccion(ts, "Escapar en " + (sal == SALIDA_DUCTO ? "el ducto" : "la " + NOMBRES_SALIDA[sal]), true, NEON_VERDE);
    return new Interaccion(ts, b, false, COLOR_AMBAR);
  }
  Vigilante radio = radioCercana(j);
  if (radio != null) return new Interaccion(radio, "Contestar la radio", NEON_CIAN);
  if (j.arrastrando != null) {
    if ((t = esconditeParaCuerpo(j)) != null) return new Interaccion(t, "Esconder el cuerpo", true, NEON_CIAN);
    return new Interaccion(j.arrastrando, "Soltar", NEON_CIAN);
  }
  Persona p = aQuienNoquear(j);
  if (p != null) return new Interaccion(p, "Noquear", NEON_MAGENTA);
  if ((p = cuerpoCercano(j)) != null) return new Interaccion(p, "Arrastrar", NEON_CIAN);
  if ((t = botinCercano(j)) != null) {
    int k = indiceBotin(mapa.celdas[t[0]][t[1]]);
    String dato = PESO_BOTIN[k] + " kg, " + VALOR_BOTIN[k] + " pts";
    if (!cabeEnMochila(j, t)) return new Interaccion(t, NOMBRES_BOTIN[k] + " (" + dato + "): no cabe, " + (j.numero == 1 ? "X" : "K") + " suelta", false, COLOR_AMBAR);
    return new Interaccion(t, "Guardar " + NOMBRES_BOTIN[k] + " (" + dato + ")", true, NEON_VERDE);
  }
  if (!soloEscapar() && (t = mapa.cercano(j.x, j.y, 'r', 1.2)) != null) return new Interaccion(t, "Tomar tarjeta roja", true, NEON_VERDE);
  if (!soloEscapar() && (t = mapa.cercano(j.x, j.y, 'b', 1.2)) != null) return new Interaccion(t, "Tomar tarjeta azul", true, NEON_VERDE);
  if (!soloEscapar() && (t = mapa.cercano(j.x, j.y, 'y', 1.2)) != null) return new Interaccion(t, "Tomar tarjeta amarilla", true, NEON_VERDE);
  if (!soloEscapar() && (t = mapa.cercano(j.x, j.y, 'n', 1.2)) != null) return new Interaccion(t, "Leer nota", true, NEON_VERDE);
  if ((t = mapa.cercano(j.x, j.y, 'o', 1.2)) != null) return new Interaccion(t, "Tomar botella", true, NEON_VERDE);
  if ((t = mapa.puertaCercana(j.x, j.y, 1.3)) != null) {
    int k = mapa.celdas[t[0]][t[1]] - '0';
    if (k == 4) return new Interaccion(t, "Teclado (" + codigoConocido() + ")", true, tarjetas[4] ? NEON_CIAN : COLOR_AMBAR);
    if (tarjetas[k]) return new Interaccion(t, "Abrir", true, NEON_CIAN);
    if (jugadores.size() > 1 && t[0] == PESADA_I && t[1] == PESADA_J) return new Interaccion(t, "Mantengan los dos: empujar", true, NEON_VERDE);
    return new Interaccion(t, k == 4 ? "Falta el código" : "Falta tarjeta " + NOMBRES_TARJETA[k], false, COLOR_AMBAR);
  }
  if ((t = mapa.cercano(j.x, j.y, 'v', 1.1)) != null) return new Interaccion(t, "Ducto", true, NEON_CIAN);
  if ((t = mapa.cercano(j.x, j.y, 'T', 1.4)) != null) {
    int k = indiceTablero(t[0], t[1]);
    boolean apagado = k >= 0 && mapa.zonaApagada[mapa.zonasTablero.get(k)[0]];
    if (tablerosBloqueados()) return new Interaccion(t, "Bloqueado", false, COLOR_AMBAR);
    return new Interaccion(t, apagado ? "Prender la luz" : "Cortar la luz", true, NEON_CIAN);
  }
  if (!servidorCopiado && (t = mapa.cercano(j.x, j.y, 'S', 1.4)) != null) {
    return new Interaccion(t, progresoServidor > 0 ? "Mantén: copiar " + round(progresoServidor * 100) + "%" : "Mantén: copiar (después solo escapas)", true, NEON_CIAN);
  }
  int op = oportunidadCercana(j);
  if (op >= 0) {
    t = mapa.cercano(j.x, j.y, OBJETO_OPORTUNIDAD[op], RADIO_OPORTUNIDAD[op]);
    String[] acciones = {"Mantén: cambiar el borrador", "Tomar foto (hace ruido)", "Mantén: sabotear"};
    return new Interaccion(t, acciones[op], true, NEON_MAGENTA);
  }
  if (soloEscapar()) {
    // ya no se revisa nada: solo lo que sirve para escapar
    if (puedeTomarUniforme(j)) return new Interaccion(mapa.cercano(j.x, j.y, 'Z', 1.5), "Ponerse el uniforme", true, NEON_VERDE);
    if ((t = mapa.cercano(j.x, j.y, 'A', 1.3)) != null) {
      if (esconditeOcupado(t[0], t[1])) return new Interaccion(t, "Ocupado", false, COLOR_AMBAR);
      return new Interaccion(t, "Esconderse", true, NEON_CIAN);
    }
    return null;
  }
  if ((t = mapa.cercano(j.x, j.y, 'O', 1.6)) != null) return new Interaccion(t, "Leer", true, NEON_CIAN);
  if ((t = mapa.cercano(j.x, j.y, 'X', 1.9)) != null) return new Interaccion(t, "Ver el tablero", true, NEON_CIAN);
  if ((t = mapa.cercano(j.x, j.y, 'U', 1.6)) != null) return new Interaccion(t, "Leer", true, NEON_CIAN);
  if ((t = mapa.cercano(j.x, j.y, 'W', 1.9)) != null) return new Interaccion(t, "Ver la TV", true, NEON_CIAN);
  if ((t = mapa.cercano(j.x, j.y, 'Q', 1.5)) != null) return new Interaccion(t, "Usar la consola", true, NEON_CIAN);
  if (puedeTomarUniforme(j)) return new Interaccion(mapa.cercano(j.x, j.y, 'Z', 1.5), "Ponerse el uniforme", true, NEON_VERDE);
  if ((t = mapa.cercano(j.x, j.y, 'A', 1.3)) != null) {
    if (esconditeOcupado(t[0], t[1])) return new Interaccion(t, "Ocupado", false, COLOR_AMBAR);
    return new Interaccion(t, "Esconderse", true, NEON_CIAN);
  }
  if ((t = mapa.cercano(j.x, j.y, 'E', 1.6)) != null) return new Interaccion(t, "Salida: primero copia el servidor", false, COLOR_AMBAR);
  return null;
}

// Color con que se marca una baldosa usable, o 0 si no se puede usar
color colorUsable(int i, int j) {
  char c = mapa.celdas[i][j];
  if (soloEscapar() && "PrbynhlOXUWQS".indexOf(c) >= 0) return 0;
  if ("Prbynohl".indexOf(c) >= 0) return NEON_VERDE;
  if (mapa.esPuertaCerrada(i, j)) return tarjetas[c - '0'] ? NEON_CIAN : COLOR_AMBAR;
  if ("vTOXUWAQ".indexOf(c) >= 0) return NEON_CIAN;
  if (c == 'Z') {   // casillero con uniformes: mientras alguien no lo tenga puesto
    for (Jugador p : jugadores) {
      if (!p.disfrazado) return NEON_VERDE;
    }
  }
  if (c == 'S' && !servidorCopiado) return NEON_CIAN;
  if ((c == 'E' || c == 'm') && servidorCopiado) return NEON_VERDE;
  return 0;
}

// Se llama una vez por cuadro antes de dibujar el mundo
void actualizarMarcas() {
  if (marca == null || marca.length != mapa.ancho || marca[0].length != mapa.alto) {
    marca = new float[mapa.ancho][mapa.alto];
    colorMarca = new color[mapa.ancho][mapa.alto];
  }
  for (int i = 0; i < mapa.ancho; i++) {
    for (int j = 0; j < mapa.alto; j++) marca[i][j] = 0;
  }
  marcaPersona.clear();
  colorPersona.clear();
  if (estado != JUGANDO) return;
  // Cuerpos tirados cerca: borde suave para que se vean
  for (Persona q : personas()) {
    if (!q.inconsciente || q.cuerpoEscondido) continue;
    for (Jugador p : jugadores) {
      float d = dist(p.x, p.y, q.x, q.y);
      if (d <= RADIO_BRILLO) ponerMarcaPersona(q, map(d, 0, RADIO_BRILLO, 0.6, 0.3), NEON_CIAN);
    }
  }
  int r = ceil(RADIO_BRILLO);
  for (Jugador p : jugadores) {
    if (p.enDucto) continue;
    for (int i = max(0, floor(p.x) - r); i <= min(mapa.ancho - 1, floor(p.x) + r); i++) {
      for (int j = max(0, floor(p.y) - r); j <= min(mapa.alto - 1, floor(p.y) + r); j++) {
        float d = dist(p.x, p.y, i + 0.5, j + 0.5);
        if (d > RADIO_BRILLO) continue;
        color c = colorUsable(i, j);
        if (c == 0) continue;
        // mas cerca, un poco mas fuerte
        float f = map(d, 0, RADIO_BRILLO, 0.6, 0.3);
        if (f > marca[i][j]) {
          marca[i][j] = f;
          colorMarca[i][j] = c;
        }
      }
    }
    Interaccion it = interaccionPara(p);
    if (it != null && it.enPunto) {
      // sin borde: la etiqueta basta
    } else if (it != null && it.persona != null) {
      ponerMarcaPersona(it.persona, 1, it.c);
    } else if (it != null) {
      marca[it.i][it.j] = 1;
      colorMarca[it.i][it.j] = it.c;
    }
  }
}

void ponerMarcaPersona(Persona q, float f, color c) {
  if (f <= marcaDe(q)) return;
  marcaPersona.put(q, f);
  colorPersona.put(q, c);
}

PImage silueta(PImage img) {
  PImage s = siluetas.get(img);
  if (s != null) return s;
  img.loadPixels();
  s = createImage(img.width, img.height, ARGB);
  s.loadPixels();
  int arriba = img.height;
  for (int k = 0; k < img.pixels.length; k++) {
    boolean lleno = alpha(img.pixels[k]) > 40;
    s.pixels[k] = lleno ? color(255) : color(255, 0);
    if (lleno) arriba = min(arriba, k / img.width);
  }
  s.updatePixels();
  siluetas.put(img, s);
  filaArriba.put(img, arriba);
  return s;
}

// Contorno de un sprite: los pixeles vacios que tocan uno lleno. La imagen
// tiene un pixel de mas por cada lado.
HashMap<PImage, PImage> contornos = new HashMap<PImage, PImage>();

PImage contorno(PImage img) {
  PImage c = contornos.get(img);
  if (c != null) return c;
  img.loadPixels();
  int w = img.width, h = img.height;
  c = createImage(w + 2, h + 2, ARGB);
  c.loadPixels();
  for (int y = 0; y < h + 2; y++) {
    for (int x = 0; x < w + 2; x++) {
      boolean lleno = llenoEn(img, x - 1, y - 1);
      boolean toca = llenoEn(img, x - 2, y - 1) || llenoEn(img, x, y - 1) || llenoEn(img, x - 1, y - 2) || llenoEn(img, x - 1, y);
      c.pixels[y * (w + 2) + x] = !lleno && toca ? color(255) : color(255, 0);
    }
  }
  c.updatePixels();
  contornos.put(img, c);
  return c;
}

boolean llenoEn(PImage img, int x, int y) {
  if (x < 0 || y < 0 || x >= img.width || y >= img.height) return false;
  return alpha(img.pixels[y * img.width + x]) > 40;
}

// Borde de color alrededor del sprite. Se dibuja despues del sprite y solo
// pinta por fuera, asi no se trasluce cuando el mueble se recorta.
void bordeSprite(PImage img, float x, float y, int i, int j) {
  if (marca == null || marca[i][j] <= 0) return;
  color c = colorMarca[i][j];
  float f = marca[i][j];
  float pulso = f >= 1 ? 0.65 + 0.35 * sin(millis() / 140.0) : 0.8 + 0.2 * sin(millis() / 400.0);
  float transparencia = 1 - 0.6 * mapa.corte[i][j];
  PImage b = contorno(img);
  tint(red(c), green(c), blue(c), 255 * f * pulso * transparencia);
  image(b, round(x) - pixel, round(y) - pixel, b.width * pixel, b.height * pixel);
  noTint();
}

// Encima del sprite: lo ilumina un poco (solo el que esta al lado)
void luzSprite(PImage img, float x, float y, int i, int j) {
  if (marca == null || marca[i][j] < 1) return;
  color c = colorMarca[i][j];
  float transparencia = 1 - 0.8 * mapa.corte[i][j];   // si el mueble se recorta, el brillo tambien
  tint(red(c), green(c), blue(c), (22 + 18 * sin(millis() / 140.0)) * transparencia);
  image(silueta(img), round(x), round(y), img.width * pixel, img.height * pixel);
  noTint();
}

// Brillo suave del color de la marca, para que se note de lejos
void dibujarBrilloUsable() {
  if (marca == null || estado != JUGANDO) return;
  for (int i = 0; i < mapa.ancho; i++) {
    for (int j = 0; j < mapa.alto; j++) {
      if (marca[i][j] <= 0) continue;
      float sx = pantallaX(i + 0.5, j + 0.5);
      float sy = pantallaY(i + 0.5, j + 0.5) - 10 * pixel;
      if (sx < -50 || sx > width + 50 || sy < -50 || sy > height + 50) continue;
      boolean alLado = marca[i][j] >= 1;
      float pulso = alLado ? 0.7 + 0.3 * sin(millis() / 140.0) : 0.75 + 0.25 * sin(millis() / 400.0 + i + j);
      manchaLuz(sx, sy, alLado ? 1.0 : 0.7, colorMarca[i][j], (alLado ? 230 : 230 * marca[i][j]) * pulso, false);
    }
  }
}

// Tecla y accion flotando encima del objeto
void dibujarEtiquetasUso() {
  if (estado != JUGANDO) return;
  int[] ultima = null;
  for (Jugador p : jugadores) {
    Interaccion it = interaccionPara(p);
    if (it == null) continue;
    // si los dos miran lo mismo, la segunda va un poco mas arriba
    boolean repetida = ultima != null && ultima[0] == it.i && ultima[1] == it.j && it.persona == null;
    ultima = new int[] {it.i, it.j};
    float sx, sy;
    if (it.enPunto) {
      sx = pantallaX(it.px, it.py);
      sy = pantallaY(it.px, it.py) - 46 * pixel;
    } else if (it.persona != null) {
      Persona q = it.persona;
      sx = pantallaX(q.x, q.y);
      sy = pantallaY(q.x, q.y) - (q.inconsciente ? 14 : 34) * pixel - 6 * escala;
    } else {
      sx = pantallaX(it.i + 0.5, it.j + 0.5);
      sy = pantallaY(it.i, it.j) - altoSprite(it.i, it.j) * pixel - 10 * escala;
    }
    sy += sin(millis() / 220.0) * 2 * escala - (repetida ? 26 * escala : 0);
    etiquetaUso(sx, sy, it.conTecla ? p.teclaUsar() : null, it.accion, it.c);
  }
}

// Cuanto sobresale el sprite de la baldosa (pixeles del dibujo, sin agrandar)
float altoSprite(int i, int j) {
  char c = mapa.celdas[i][j];
  PImage img = c < 128 ? spriteObjeto[c] : null;
  if (img == null) return 20;
  silueta(img);
  int base = mapa.esPuertaCerrada(i, j) ? 28 : 40;
  // lo bajito (botella, tarjeta) igual lleva la etiqueta sobre la cabeza
  return max(20, base - filaArriba.get(img));
}

void etiquetaUso(float x, float y, String tecla, String accion, color c) {
  textFont(letraChica);
  float alto = 22 * escala;
  float anchoTecla = tecla == null ? 0 : textWidth(tecla) + 12 * escala;
  float separa = tecla == null ? 0 : 6 * escala;
  float w = anchoTecla + separa + textWidth(accion) + 16 * escala;
  float x0 = x - w / 2;
  float y0 = y - alto;
  // caja
  stroke(red(c), green(c), blue(c), 200);
  strokeWeight(1.5 * escala);
  fill(11, 14, 26, 235);
  rect(x0, y0, w, alto, 3 * escala);
  // tecla
  float cx = x0 + 8 * escala;
  if (tecla != null) {
    noStroke();
    fill(c);
    rect(cx, y0 + 3 * escala, anchoTecla, alto - 6 * escala, 2 * escala);
    fill(COLOR_FONDO);
    textAlign(CENTER, CENTER);
    text(tecla, cx + anchoTecla / 2, y0 + alto / 2 - 1 * escala);
    cx += anchoTecla + separa;
  }
  fill(tecla == null ? c : color(242, 242, 233));
  textAlign(LEFT, CENTER);
  text(accion, cx, y0 + alto / 2 - 1 * escala);
  // piquito hacia el objeto
  noStroke();
  fill(red(c), green(c), blue(c), 200);
  triangle(x - 4 * escala, y, x + 4 * escala, y, x, y + 5 * escala);
}


// ======================================================================
// Jugador.pde
// ======================================================================
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


// ======================================================================
// Jugo.pde
// ======================================================================
// "Jugo": lo que hace que cada accion se sienta. Temblor de pantalla, texto
// que flota y se desvanece, y chispas de colores.

float temblor;            // fuerza del temblor (en pixeles del arte), baja sola
ArrayList<TextoFlotante> textosFlotantes = new ArrayList<TextoFlotante>();

class TextoFlotante {
  float x, y;             // en la cuadricula
  String texto;
  color c;
  float vida = 1.3;

  TextoFlotante(float x, float y, String texto, color c) {
    this.x = x;
    this.y = y;
    this.texto = texto;
    this.c = c;
  }
}

void sacudir(float fuerza) {
  temblor = max(temblor, fuerza);
}

void textoFlotante(float x, float y, String texto, color c) {
  textosFlotantes.add(new TextoFlotante(x, y, texto, c));
}

void chispas(float x, float y, color c, int n) {
  for (int k = 0; k < n; k++) {
    Particula p = new Particula(x, y);
    p.c = c;
    particulas.add(p);
  }
}

void actualizarJugo(float dt) {
  temblor = max(0, temblor - dt * 18);
  for (int k = textosFlotantes.size() - 1; k >= 0; k--) {
    TextoFlotante t = textosFlotantes.get(k);
    t.vida -= dt;
    if (t.vida <= 0) textosFlotantes.remove(k);
  }
}

// Se aplica antes de dibujar el mundo
void aplicarTemblor() {
  if (temblor <= 0) return;
  translate(round(random(-temblor, temblor)) * pixel * 0.5, round(random(-temblor, temblor)) * pixel * 0.5);
}

void dibujarTextosFlotantes() {
  textFont(letraMedia);
  textAlign(CENTER, CENTER);
  for (TextoFlotante t : textosFlotantes) {
    float u = 1 - t.vida / 1.3;
    float sx = pantallaX(t.x, t.y);
    float sy = pantallaY(t.x, t.y) - 34 * pixel - u * 24 * pixel;
    float a = 255 * min(1, t.vida / 0.4);
    fill(0, a * 0.6);
    text(t.texto, sx + 1 * escala, sy + 1 * escala);
    fill(red(t.c), green(t.c), blue(t.c), a);
    text(t.texto, sx, sy);
  }
}


// ======================================================================
// Llamada.pde
// ======================================================================
// Llamada del inicio: antes del reconocimiento suena el telefono y Valeria le
// cuenta al candidato que Titulares Ya esta regando un bulo y que esta noche
// tiene que entrar a borrarlo. La llamada tambien la escribe el modelo con los
// datos de la campana (bulo, barrio, apoyo); se pide apenas se elige el rol,
// asi que mientras suena el telefono ya casi siempre esta lista.
// E o Espacio pasa a la siguiente frase; Enter cuelga.
// Solo suena la primera vez que se juega (al reiniciar ya no).

final float TIMBRE_MAXIMO = 8;   // si no llega a tiempo, se usa el guion de respaldo

String[] lineasLlamada;
Clip[] vocesLlamada;
float[] segundosLlamada;
volatile boolean llamadaLista;
volatile String[] lineasRecibidas;
volatile Clip[] vocesRecibidas;
boolean llamadaPedida, llamadaHecha, contestada;
int lineaLlamada;
float tiempoLlamada, tiempoLinea, proximoTimbre;

String[] guionRespaldo() {
  return new String[] {
    "Candidato, soy Valeria. Perdón por la hora, pero esto no puede esperar.",
    "Titulares Ya está regando un bulo sobre ti: " + buloCampana + ".",
    "En " + barrioCampana + " tienes " + apoyoCampana + " % de apoyo y mañana lo podemos perder.",
    "Esta noche entras a su sede, copias el servidor con las pruebas y sales sin que te vean.",
    "En el aseo hay uniformes de conserje: con uno puesto casi nadie te reconoce.",
    "Yo te guío por el auricular. Antes de entrar, estudia bien el plano."
  };
}

// Se llama al elegir 1 o 2 jugadores: pide la llamada de una vez
void prepararLlamada() {
  if (llamadaPedida || llamadaHecha || !valeriaActiva) return;
  llamadaPedida = true;
  llamadaLista = false;
  String usuario = null;
  if (valeriaConIA()) {
    usuario = "Es de madrugada y llamas por teléfono al candidato para ponerlo al tanto.\n" +
      "Datos:\n" +
      "- El bulo que Titulares Ya está regando contra él: " + buloCampana + ".\n" +
      "- Barrio donde hace campaña: " + barrioCampana + ", con " + apoyoCampana + " % de apoyo.\n" +
      "- La misión: entrar esta noche a la sede de Titulares Ya, copiar el servidor donde guardan los bulos " +
      "y salir sin que lo vean. Antes de entrar va a estudiar el plano de la sede.\n" +
      (numJugadores == 2 ? "- Esta vez van dos: el candidato y alguien de su equipo.\n" : "") +
      "Escribe lo que dices en la llamada: 4 o 5 frases, una por renglón, de máximo 20 palabras cada una. " +
      "Empieza saludándolo y termina diciendo que lo vas a guiar por el auricular. No numeres los renglones.";
  }
  Thread h = new Thread(new PedidoLlamada(usuario, guionRespaldo()));
  h.setDaemon(true);
  h.start();
}

class PedidoLlamada implements Runnable {
  String usuario;
  String[] respaldoL;

  PedidoLlamada(String usuario, String[] respaldoL) {
    this.usuario = usuario;
    this.respaldoL = respaldoL;
  }

  public void run() {
    String[] lineas = null;
    long t0 = System.currentTimeMillis();
    if (usuario != null) {
      try {
        String t = pedirAlModelo(PERSONA_VALERIA + "\nAhora es una llamada por teléfono: puedes decir varias frases, como se te pide.", usuario, 400);
        StringList ls = new StringList();
        for (String l : split(t, '\n')) {
          l = limpiarFrase(l);
          while (l.length() > 0 && (l.charAt(0) == '-' || Character.isDigit(l.charAt(0)) || l.charAt(0) == '.')) l = trim(l.substring(1));
          if (l.length() > 0) ls.append(l);
        }
        if (ls.size() >= 3) lineas = ls.array();
        fallosSeguidos = 0;
      } catch (Exception e) {
        fallosSeguidos++;
        println("Valeria (llamada): " + e.getMessage());
      }
    }
    if (lineas == null) lineas = respaldoL;
    Clip[] voces = new Clip[lineas.length];
    if (valeriaConVoz()) {
      for (int k = 0; k < lineas.length; k++) {
        try {
          voces[k] = vozDeAzure(lineas[k]);
        } catch (Exception e) {
          println("Valeria (voz de la llamada): " + e.getMessage());
          break;
        }
      }
    }
    println("Valeria: llamada lista en " + (System.currentTimeMillis() - t0) + " ms");
    vocesRecibidas = voces;
    lineasRecibidas = lineas;
    llamadaLista = true;
  }
}

void empezarLlamada() {
  estado = LLAMADA;
  contestada = false;
  tiempoLlamada = 0;
  proximoTimbre = 0.3;
  if (!llamadaPedida) prepararLlamada();
  if (musica != null) musica.atenuar = 0.35;
}

void actualizarLlamada(float dt) {
  tiempoLlamada += dt;
  if (!contestada) {
    proximoTimbre -= dt;
    if (proximoTimbre <= 0) {
      sonar("telefono");
      proximoTimbre = 2.2;
    }
    if ((llamadaLista && tiempoLlamada > 2.2) || tiempoLlamada > TIMBRE_MAXIMO) contestar();
    return;
  }
  tiempoLinea += dt;
  if (tiempoLinea > segundosLlamada[lineaLlamada] + 0.6) siguienteLineaLlamada();
}

void contestar() {
  contestada = true;
  tiempoLlamada = 0;
  if (llamadaLista) {
    lineasLlamada = lineasRecibidas;
    vocesLlamada = vocesRecibidas;
  } else {
    // no llego a tiempo: guion de respaldo y sin voz
    lineasLlamada = guionRespaldo();
    vocesLlamada = new Clip[lineasLlamada.length];
  }
  segundosLlamada = new float[lineasLlamada.length];
  for (int k = 0; k < lineasLlamada.length; k++) {
    Clip c = vocesLlamada[k];
    segundosLlamada[k] = c != null ? c.getMicrosecondLength() / 1e6 : max(2.8, lineasLlamada[k].length() / 15.0);
  }
  sonar("auricular");
  lineaLlamada = -1;
  siguienteLineaLlamada();
}

void siguienteLineaLlamada() {
  if (!contestada) {
    contestar();
    return;
  }
  if (lineaLlamada >= 0 && vocesLlamada[lineaLlamada] != null) vocesLlamada[lineaLlamada].stop();
  lineaLlamada++;
  tiempoLinea = 0;
  if (lineaLlamada >= lineasLlamada.length) {
    colgar();
    return;
  }
  if (vocesLlamada[lineaLlamada] != null) {
    vocesLlamada[lineaLlamada].setFramePosition(0);
    vocesLlamada[lineaLlamada].start();
  }
}

void colgar() {
  if (vocesLlamada != null) for (Clip c : vocesLlamada) if (c != null) c.stop();
  llamadaHecha = true;
  sonar("auricular");
  if (musica != null) musica.atenuar = 1;
  irAlReconocimiento();
}

void dibujarLlamada() {
  noStroke();
  fill(COLOR_FONDO, 238);
  rect(0, 0, width, height);
  PGraphics g = capaHud;
  g.beginDraw();
  g.clear();
  g.textAlign(LEFT, TOP);
  int an = g.width, al = g.height;
  int x0 = an / 2 - 170, y0 = al / 2 - 62, x1 = an / 2 + 170, y1 = al / 2 + 62;
  marcoPixel(g, x0, y0, x1, y1, COLOR_VALERIA);
  // retrato al doble
  g.noStroke();
  g.fill(40, 30, 64);
  g.rect(x0 + 10, y0 + 12, 44, 44);
  g.image(caraValeria, x0 + 12, y0 + 14, 40, 40);
  textoPixel(g, "VALERIA", x0 + 64, y0 + 10, COLOR_VALERIA, pixel12);
  textoPixel(g, "Estrategia digital de la campaña", x0 + 64, y0 + 25, color(160, 168, 190), pixel8);
  g.textAlign(RIGHT, TOP);
  if (!contestada) {
    boolean prende = (millis() / 300) % 2 == 0;
    textoPixel(g, "LLAMADA ENTRANTE", x1 - 10, y0 + 12, prende ? NEON_VERDE : color(30, 110, 66), pixel8);
  } else {
    int s = floor(tiempoLlamada);
    textoPixel(g, "EN LLAMADA " + s / 60 + ":" + nf(s % 60, 2), x1 - 10, y0 + 12, NEON_VERDE, pixel8);
  }
  g.textAlign(LEFT, TOP);
  if (!contestada) {
    // ondas del timbre
    int p = (millis() / 200) % 4;
    for (int k = 0; k < p; k++) {
      g.noFill();
      g.stroke(NEON_VERDE);
      g.rect(an / 2 - 8 - k * 6, y0 + 74 - k * 6, 16 + k * 12, 16 + k * 12);
    }
    g.noStroke();
    g.fill(NEON_VERDE);
    g.rect(an / 2 - 4, y0 + 78, 8, 8);
    textoPixel(g, "E contestar", x0 + 12, y1 - 14, color(110, 118, 145), pixel8);
  } else if (lineaLlamada >= 0 && lineaLlamada < lineasLlamada.length) {
    String t = lineasLlamada[lineaLlamada];
    int letras = t.length();
    float dur = segundosLlamada[lineaLlamada];
    letras = vocesLlamada[lineaLlamada] != null ? ceil(letras * constrain(tiempoLinea / max(0.1, dur * 0.9), 0, 1)) : min(letras, ceil(tiempoLinea * 32));
    g.textFont(pixel10);
    g.fill(242, 242, 233);
    g.text(t.substring(0, letras), x0 + 64, y0 + 42, x1 - x0 - 76, 50);
    textoPixel(g, (lineaLlamada + 1) + "/" + lineasLlamada.length + "   E siguiente · Enter colgar", x0 + 12, y1 - 14, color(110, 118, 145), pixel8);
  }
  g.endDraw();
  image(g, 0, 0, g.width * pixel, g.height * pixel);
}


// ======================================================================
// Mapa.pde
// ======================================================================
// El mapa de la sede se lee de data/mapa/: tres capas en CSV (las mismas que
// exporta Tiled) y un archivo de texto con vigilantes, camaras, ductos y
// tableros electricos.
//   terreno.csv  1 pared, 2 piso, 3 puerta, 4 roja, 5 azul, 6 amarilla, 7 con codigo
//   zonas.csv    16 + numero de zona (ver NOMBRES_ZONA)
//   objetos.csv  muebles y cosas que se recogen (ver CODIGOS_OBJETO), -1 nada
// Por dentro cada baldosa se guarda como una letra, que es mas facil de leer:
//   #  pared       .  piso       D  puerta abierta
//   1  puerta roja 2 azul  3 amarilla  4 con codigo (cerradas)
//   A armario  M escritorio  S servidor  L farol  P prueba  E camioneta
//   T tablero electrico  r b y tarjetas  n nota con el codigo  o botella
//   C carro  p planta  I impresora  V camara de estudio  Q consola
//   O escritorio del rival  W TV del rival  X tablero de conspiracion
//   U cuaderno del rival  H sofa  Z casillero  F cafetera  v rejilla
//   c caseta  z contenedor  G pantalla verde

final String[] NOMBRES_ZONA = {"Exterior", "Recepción", "Redacción de bulos", "Estudio de TV",
  "Seguridad", "Archivo", "Cuarto del servidor", "Oficina del rival", "Pasillo", "Aseo", "Descanso"};
final int ZONA_EXTERIOR = 0;
// letra de cada codigo de objetos.csv, desde el 32
final String CODIGOS_OBJETO = "AMSLPEjkTrbynCpIVQOWXUHZFvczoGhlm";
final String TERRENO = "?#.D1234";   // indice = codigo de terreno.csv
final String[] NOMBRES_TARJETA = {"", "roja", "azul", "amarilla", "código"};

class Mapa {
  int ancho, alto;
  char[][] celdas;
  int[][] zona;
  float[][] luz;          // luz de cada baldosa (0.5 apagado, 0.62 oscuro, 1 junto a un farol): cuenta para que te vean
  float[][] luzR, luzG, luzB;   // color de la luz de cada baldosa: solo para el dibujo
  int[][] adorno;         // en las paredes: 0 ladrillo, 1 tira de neon, 2 letrero del rival
  float[][] corte;        // 0 pared entera, 1 pared recortada porque tapa a un jugador
  boolean[] zonaApagada = new boolean[11];
  ArrayList<float[]> fuentesLuz = new ArrayList<float[]>();   // x, y, r, g, b, radio, fuerza, altura
  float[] inicioX = new float[2];
  float[] inicioY = new float[2];
  int totalPruebas;
  int valorBotinTotal;   // suma del valor de todo el botin (Mochila.pde)
  int servidorI = -1, servidorJ = -1;   // un servidor para marcarlo con la flechita
  ArrayList<int[]> lamparas = new ArrayList<int[]>();

  // Lo que viene en entidades.txt
  ArrayList<String[]> lineasVigilantes = new ArrayList<String[]>();
  ArrayList<String[]> lineasCiviles = new ArrayList<String[]>();
  ArrayList<float[]> datosCamaras = new ArrayList<float[]>();
  ArrayList<int[]> rejillas = new ArrayList<int[]>();      // x, y de cada rejilla
  ArrayList<int[]> ductos = new ArrayList<int[]>();        // indice de rejilla A, indice B, largo en baldosas
  ArrayList<int[]> tableros = new ArrayList<int[]>();      // x, y del tablero electrico
  ArrayList<int[]> zonasTablero = new ArrayList<int[]>();  // zonas que apaga cada tablero

  // Grafo de cuartos: cada zona es un vertice; cada puerta une las dos zonas
  // que separa. La arista guarda que tarjeta pide (0 ninguna).
  ArrayList<int[]> puertasGrafo = new ArrayList<int[]>();   // zona A, zona B, tarjeta, x, y

  Mapa(String carpeta) {
    String[] ter = loadStrings(carpeta + "/terreno.csv");
    String[] zon = loadStrings(carpeta + "/zonas.csv");
    String[] obj = loadStrings(carpeta + "/objetos.csv");
    alto = ter.length;
    ancho = split(ter[0], ',').length;
    celdas = new char[ancho][alto];
    zona = new int[ancho][alto];
    luz = new float[ancho][alto];
    luzR = new float[ancho][alto];
    luzG = new float[ancho][alto];
    luzB = new float[ancho][alto];
    adorno = new int[ancho][alto];
    corte = new float[ancho][alto];
    for (int j = 0; j < alto; j++) {
      String[] ft = split(trim(ter[j]), ',');
      String[] fz = split(trim(zon[j]), ',');
      String[] fo = split(trim(obj[j]), ',');
      for (int i = 0; i < ancho; i++) {
        char c = TERRENO.charAt(constrain(int(ft[i]), 0, TERRENO.length() - 1));
        if (c == '?') c = '#';
        zona[i][j] = constrain(int(fz[i]) - 16, 0, NOMBRES_ZONA.length - 1);
        int o = int(fo[i]);
        if (o >= 32 && o - 32 < CODIGOS_OBJETO.length()) {
          char letra = CODIGOS_OBJETO.charAt(o - 32);
          if (letra == 'j') {
            inicioX[0] = i + 0.5;
            inicioY[0] = j + 0.5;
          } else if (letra == 'k') {
            inicioX[1] = i + 0.5;
            inicioY[1] = j + 0.5;
          } else {
            c = letra;
          }
        }
        if (c == 'L') lamparas.add(new int[] {i, j});
        if (LETRAS_BOTIN.indexOf(c) >= 0) {
          totalPruebas++;
          valorBotinTotal += VALOR_BOTIN[LETRAS_BOTIN.indexOf(c)];
        }
        if (c == 'S' && servidorI < 0) {
          servidorI = i;
          servidorJ = j;
        }
        celdas[i][j] = c;
      }
    }
    leerEntidades(carpeta + "/entidades.txt");
    armarGrafoCuartos();
    elegirAdornos();
    calcularLuz();
  }

  void leerEntidades(String archivo) {
    for (String linea : loadStrings(archivo)) {
      linea = trim(linea);
      if (linea.length() == 0 || linea.charAt(0) == '#') continue;
      String[] p = splitTokens(linea, " ");
      if (p[0].equals("vigilante") || p[0].equals("jefe")) lineasVigilantes.add(p);
      if (p[0].equals("civil")) lineasCiviles.add(p);
      if (p[0].equals("camara")) datosCamaras.add(new float[] {float(p[1]), float(p[2]), radians(float(p[3])), radians(float(p[4]))});
      if (p[0].equals("ducto")) {
        int a = indiceRejilla(p[1]);
        int b = indiceRejilla(p[2]);
        int[] pa = rejillas.get(a);
        int[] pb = rejillas.get(b);
        ductos.add(new int[] {a, b, abs(pa[0] - pb[0]) + abs(pa[1] - pb[1])});
      }
      if (p[0].equals("tablero")) {
        String[] xy = split(p[1], ',');
        tableros.add(new int[] {int(xy[0]), int(xy[1])});
        int[] zs = new int[p.length - 2];
        for (int k = 2; k < p.length; k++) zs[k - 2] = int(p[k]);
        zonasTablero.add(zs);
      }
    }
  }

  // Devuelve el indice de la rejilla en "x,y" (la agrega si es nueva)
  int indiceRejilla(String xy) {
    String[] v = split(xy, ',');
    int x = int(v[0]);
    int y = int(v[1]);
    for (int k = 0; k < rejillas.size(); k++) {
      if (rejillas.get(k)[0] == x && rejillas.get(k)[1] == y) return k;
    }
    rejillas.add(new int[] {x, y});
    return rejillas.size() - 1;
  }

  char en(int i, int j) {
    if (i < 0 || j < 0 || i >= ancho || j >= alto) return '#';
    return celdas[i][j];
  }

  boolean esPared(int i, int j) {
    return en(i, j) == '#';
  }

  boolean esPuertaCerrada(int i, int j) {
    char c = en(i, j);
    return c >= '1' && c <= '4';
  }

  int zonaEn(float x, float y) {
    return zona[constrain(floor(x), 0, ancho - 1)][constrain(floor(y), 0, alto - 1)];
  }

  float corteEn(int i, int j) {
    if (i < 0 || j < 0 || i >= ancho || j >= alto) return 0;
    return corte[i][j];
  }

  // Los jugadores no pasan por paredes, puertas cerradas ni muebles
  boolean esSolido(int i, int j) {
    char c = en(i, j);
    return c == '#' || esPuertaCerrada(i, j) || "AMSLCpIVQOWXUHZFczGm".indexOf(c) >= 0;
  }

  // Los vigilantes tienen todas las tarjetas: las puertas cerradas no los frenan
  boolean esSolidoVigilante(int i, int j) {
    if (esPuertaCerrada(i, j)) return false;
    return esSolido(i, j);
  }

  // Tapa la vista: paredes, puertas cerradas y muebles altos
  boolean bloqueaVista(int i, int j) {
    char c = en(i, j);
    return c == '#' || esPuertaCerrada(i, j) || "ASCcZG".indexOf(c) >= 0;
  }

  boolean chocaCaja(float cx, float cy, float r) {
    for (int i = floor(cx - r); i <= floor(cx + r); i++) {
      for (int j = floor(cy - r); j <= floor(cy + r); j++) {
        if (esSolido(i, j)) return true;
      }
    }
    return false;
  }

  boolean hayLinea(float x1, float y1, float x2, float y2) {
    int di = floor(x2);
    int dj = floor(y2);
    float d = dist(x1, y1, x2, y2);
    int pasos = ceil(d / 0.2);
    for (int k = 1; k < pasos; k++) {
      float t = k / (float) pasos;
      int i = floor(lerp(x1, x2, t));
      int j = floor(lerp(y1, y2, t));
      if (i == di && j == dj) continue;
      if (bloqueaVista(i, j)) return false;
    }
    return true;
  }

  // ---------------------------------------------------------------------
  // Grafo de cuartos (zonas unidas por puertas)
  // ---------------------------------------------------------------------

  void armarGrafoCuartos() {
    puertasGrafo.clear();
    for (int i = 1; i < ancho - 1; i++) {
      for (int j = 1; j < alto - 1; j++) {
        char c = celdas[i][j];
        if (c != 'D' && !esPuertaCerrada(i, j)) continue;
        int tarjeta = c == 'D' ? 0 : c - '0';
        int a, b;
        if (!esPared(i, j - 1) && !esPared(i, j + 1)) {
          a = zona[i][j - 1];
          b = zona[i][j + 1];
        } else {
          a = zona[i - 1][j];
          b = zona[i + 1][j];
        }
        puertasGrafo.add(new int[] {a, b, tarjeta, i, j});
      }
    }
  }

  // BFS sobre el grafo de cuartos: a que zonas se llega desde afuera con las
  // tarjetas que se tienen (tarjetas[k] = true si ya se tiene la tarjeta k).
  boolean[] zonasAlcanzables(boolean[] tarjetas) {
    boolean[] visitada = new boolean[NOMBRES_ZONA.length];
    ArrayList<Integer> cola = new ArrayList<Integer>();
    cola.add(ZONA_EXTERIOR);
    visitada[ZONA_EXTERIOR] = true;
    int frente = 0;
    while (frente < cola.size()) {
      int z = cola.get(frente);
      frente++;
      for (int[] p : puertasGrafo) {
        boolean abierta = p[2] == 0 || tarjetas[p[2]];
        if (!abierta) continue;
        int otra = -1;
        if (p[0] == z) otra = p[1];
        if (p[1] == z) otra = p[0];
        if (otra >= 0 && !visitada[otra]) {
          visitada[otra] = true;
          cola.add(otra);
        }
      }
    }
    return visitada;
  }

  // ---------------------------------------------------------------------
  // Adornos y luz
  // ---------------------------------------------------------------------

  // Letreros del rival en algunas paredes fijas y tiras de neon repartidas.
  // Solo se adornan paredes cuya cara izquierda da a un piso.
  void elegirAdornos() {
    int[][] letreros = {{14, 0}, {29, 0}, {20, 6}, {9, 14}, {35, 14}, {13, 21}, {24, 21}, {37, 6}};
    for (int i = 0; i < ancho; i++) {
      for (int j = 0; j < alto; j++) {
        adorno[i][j] = 0;
        if (!esPared(i, j) || j + 1 >= alto || esPared(i, j + 1) || esPuertaCerrada(i, j + 1)) continue;
        if ((i * 5 + j * 3) % 7 == 0) adorno[i][j] = 1;
      }
    }
    for (int[] p : letreros) {
      if (esPared(p[0], p[1])) adorno[p[0]][p[1]] = 2;
    }
  }

  // Luz fija: cada farol ilumina las baldosas a las que llega en linea recta.
  // Lo mas oscuro es 0.62 (0.5 si se cortaron las luces de esa zona) y junto
  // a un farol llega a 1. Esto es lo que usa el juego para saber que tan
  // facil es verte. Aparte se calcula el color de la luz (solo para el dibujo).
  void calcularLuz() {
    for (int i = 0; i < ancho; i++) {
      for (int j = 0; j < alto; j++) {
        luz[i][j] = zonaApagada[zona[i][j]] ? 0.5 : 0.62;
        for (int[] l : lamparas) {
          if (zonaApagada[zona[l[0]][l[1]]]) continue;
          float d = dist(l[0] + 0.5, l[1] + 0.5, i + 0.5, j + 0.5);
          if (d < 5 && hayLinea(l[0] + 0.5, l[1] + 0.5, i + 0.5, j + 0.5)) {
            luz[i][j] = max(luz[i][j], 1.0 - d / 5 * 0.38);
          }
        }
      }
    }

    fuentesLuz.clear();
    for (int i = 0; i < ancho; i++) {
      for (int j = 0; j < alto; j++) {
        char c = celdas[i][j];
        boolean apagada = zonaApagada[zona[i][j]];
        if (!apagada) {
          if (c == 'L') fuentesLuz.add(new float[] {i + 0.5, j + 0.5, 232, 52, 78, 4.5, 1.1, 26});
          if (c == 'M') fuentesLuz.add(new float[] {i + 0.5, j + 0.5, 25, 227, 227, 2.0, 0.5, 12});
          if (c == 'Q') fuentesLuz.add(new float[] {i + 0.5, j + 0.5, 25, 227, 227, 2.4, 0.6, 14});
          if (c == 'W') fuentesLuz.add(new float[] {i + 0.5, j + 0.5, 62, 84, 120, 2.6, 0.6, 18});
        }
        if (c == 'S') fuentesLuz.add(new float[] {i + 0.5, j + 0.5, 61, 220, 132, 2.0, 0.4, 18});
        if (c == 'E') fuentesLuz.add(new float[] {i + 0.5, j + 0.5, 61, 220, 132, 2.2, 0.6, 2});
        if (c == 'c') fuentesLuz.add(new float[] {i + 0.5, j + 0.5, 217, 130, 43, 2.5, 0.7, 14});
        if (c == '1') fuentesLuz.add(new float[] {i + 0.5, j + 0.5, 232, 52, 78, 1.4, 0.5, 14});
        if (c == '2') fuentesLuz.add(new float[] {i + 0.5, j + 0.5, 62, 123, 255, 1.4, 0.5, 14});
        if (c == '3') fuentesLuz.add(new float[] {i + 0.5, j + 0.5, 255, 181, 71, 1.4, 0.5, 14});
        if (c == '4') fuentesLuz.add(new float[] {i + 0.5, j + 0.5, 25, 227, 227, 1.4, 0.5, 14});
        if (c == '#' && adorno[i][j] == 2) fuentesLuz.add(new float[] {i + 0.5, j + 1.3, 255, 46, 136, 3.0, 0.8, 16});
        if (c == '#' && adorno[i][j] == 1) fuentesLuz.add(new float[] {i + 0.5, j + 1.2, 25, 227, 227, 1.8, 0.35, 24});
      }
    }
    for (int i = 0; i < ancho; i++) {
      for (int j = 0; j < alto; j++) {
        boolean apagada = zonaApagada[zona[i][j]];
        luzR[i][j] = apagada ? 0.4 : 0.66;
        luzG[i][j] = apagada ? 0.42 : 0.7;
        luzB[i][j] = apagada ? 0.7 : 1.0;
        for (float[] f : fuentesLuz) {
          if (abs(f[0] - i) > f[5] + 1 || abs(f[1] - j) > f[5] + 1) continue;
          float d = dist(f[0], f[1], i + 0.5, j + 0.5);
          if (d >= f[5] || !hayLinea(f[0], f[1], i + 0.5, j + 0.5)) continue;
          float fuerza = pow(1 - d / f[5], 1.6) * f[6];
          luzR[i][j] += fuerza * f[2] / 255;
          luzG[i][j] += fuerza * f[3] / 255;
          luzB[i][j] += fuerza * f[4] / 255;
        }
      }
    }
  }

  // Entre mas luz, mas rapido te descubren. En la sombra cuesta mas verte.
  float factorLuz(float x, float y) {
    float l = luz[constrain(floor(x), 0, ancho - 1)][constrain(floor(y), 0, alto - 1)];
    return map(l, 0.5, 1.0, 0.3, 1.0);
  }

  // Una pared (o mueble alto) se recorta si esta delante de un jugador y lo tapa.
  void actualizarCortes(ArrayList<Jugador> js, float dt) {
    float k = min(1, dt * 8);
    for (int i = 0; i < ancho; i++) {
      for (int j = 0; j < alto; j++) {
        if (!bloqueaVista(i, j)) continue;
        boolean tapa = false;
        for (Jugador jug : js) {
          float delante = (i + j + 1) - (jug.x + jug.y);
          float lado = abs((i - j) - (jug.x - jug.y));
          if (delante > 0.2 && delante < 5.5 && lado < 3.0) tapa = true;
        }
        float meta = tapa ? 1 : 0;
        corte[i][j] += (meta - corte[i][j]) * k;
      }
    }
  }

  // Busca la baldosa del tipo pedido mas cercana a (x, y), si esta a menos de "radio"
  int[] cercano(float x, float y, char tipo, float radio) {
    int[] mejor = null;
    float mejorD = radio;
    for (int i = max(0, floor(x) - 2); i <= min(ancho - 1, floor(x) + 2); i++) {
      for (int j = max(0, floor(y) - 2); j <= min(alto - 1, floor(y) + 2); j++) {
        if (celdas[i][j] != tipo) continue;
        float d = dist(x, y, i + 0.5, j + 0.5);
        if (d <= mejorD) {
          mejorD = d;
          mejor = new int[] {i, j};
        }
      }
    }
    return mejor;
  }

  // Puerta cerrada mas cercana (cualquier color)
  int[] puertaCercana(float x, float y, float radio) {
    int[] mejor = null;
    float mejorD = radio;
    for (int i = max(0, floor(x) - 2); i <= min(ancho - 1, floor(x) + 2); i++) {
      for (int j = max(0, floor(y) - 2); j <= min(alto - 1, floor(y) + 2); j++) {
        if (!esPuertaCerrada(i, j)) continue;
        float d = dist(x, y, i + 0.5, j + 0.5);
        if (d <= mejorD) {
          mejorD = d;
          mejor = new int[] {i, j};
        }
      }
    }
    return mejor;
  }

  // La seguridad cierra una puerta (con el tipo de tarjeta que pida)
  void cerrarPuerta(int i, int j, char tipo) {
    celdas[i][j] = tipo;
    armarGrafoCuartos();
    calcularLuz();
  }

  void abrirPuerta(int i, int j) {
    celdas[i][j] = 'D';
    armarGrafoCuartos();
    calcularLuz();
  }

  // ---------------------------------------------------------------------
  // BFS
  // ---------------------------------------------------------------------

  // Camino mas corto para un vigilante (BFS sobre la cuadricula: cada
  // baldosa libre es un vertice unido a sus 4 vecinas). Devuelve las
  // baldosas desde el origen hasta la meta.
  ArrayList<int[]> caminoBFS(int i0, int j0, int i1, int j1) {
    ArrayList<int[]> camino = new ArrayList<int[]>();
    if (esSolidoVigilante(i1, j1) || esSolidoVigilante(i0, j0)) return camino;
    int total = ancho * alto;
    int inicio = j0 * ancho + i0;
    int meta = j1 * ancho + i1;
    boolean[] visitado = new boolean[total];
    int[] anterior = new int[total];
    for (int k = 0; k < total; k++) anterior[k] = -1;
    ArrayList<Integer> cola = new ArrayList<Integer>();
    cola.add(inicio);
    visitado[inicio] = true;
    int frente = 0;   // en vez de borrar de la cola, se avanza este indice
    int[] di = {1, -1, 0, 0};
    int[] dj = {0, 0, 1, -1};
    while (frente < cola.size()) {
      int actual = cola.get(frente);
      frente++;
      if (actual == meta) break;
      int ci = actual % ancho;
      int cj = actual / ancho;
      for (int k = 0; k < 4; k++) {
        int ni = ci + di[k];
        int nj = cj + dj[k];
        if (esSolidoVigilante(ni, nj)) continue;
        int n = nj * ancho + ni;
        if (!visitado[n]) {
          visitado[n] = true;
          anterior[n] = actual;
          cola.add(n);
        }
      }
    }
    if (!visitado[meta]) return camino;
    int paso = meta;
    while (paso != -1) {
      camino.add(0, new int[] {paso % ancho, paso / ancho});
      paso = anterior[paso];
    }
    return camino;
  }

  // ---------------------------------------------------------------------
  // Dijkstra de los civiles sobre la cuadricula. No todas las baldosas
  // cuestan lo mismo: cruzar una puerta cuesta 3 (hay que abrirla) y una
  // zona a oscuras tambien 3 (les da miedo). Por eso el camino mas corto no
  // siempre es el de menos baldosas y BFS no basta.
  // Igual que en clase: "dist" son los temporales, "fijo" marca los que ya
  // son definitivos y "anteriorCivil" guarda de donde se llego.
  // ---------------------------------------------------------------------
  int[] anteriorCivil;

  int costoCivil(int i, int j) {
    if (celdas[i][j] == 'D' || esPuertaCerrada(i, j)) return 3;
    if (zonaApagada[zona[i][j]]) return 3;
    return 1;
  }

  int[] dijkstraCivil(int i0, int j0) {
    int total = ancho * alto;
    int[] dist = new int[total];
    boolean[] fijo = new boolean[total];
    anteriorCivil = new int[total];
    for (int k = 0; k < total; k++) {
      dist[k] = Integer.MAX_VALUE;
      anteriorCivil[k] = -1;
    }
    dist[j0 * ancho + i0] = 0;
    int[] di = {1, -1, 0, 0};
    int[] dj = {0, 0, 1, -1};
    for (int vuelta = 0; vuelta < total; vuelta++) {
      // se fija la baldosa con el menor temporal
      int u = -1;
      for (int k = 0; k < total; k++) {
        if (!fijo[k] && dist[k] != Integer.MAX_VALUE && (u == -1 || dist[k] < dist[u])) u = k;
      }
      if (u == -1) break;
      fijo[u] = true;
      // y se relajan sus vecinas
      int ui = u % ancho;
      int uj = u / ancho;
      for (int k = 0; k < 4; k++) {
        int ni = ui + di[k];
        int nj = uj + dj[k];
        if (esSolidoVigilante(ni, nj)) continue;
        int n = nj * ancho + ni;
        int nueva = dist[u] + costoCivil(ni, nj);
        if (!fijo[n] && nueva < dist[n]) {
          dist[n] = nueva;
          anteriorCivil[n] = u;
        }
      }
    }
    return dist;
  }

  // Camino desde el origen del ultimo Dijkstra hasta (i, j), leyendo
  // "anteriorCivil" hacia atras
  ArrayList<int[]> caminoCivil(int i, int j) {
    ArrayList<int[]> camino = new ArrayList<int[]>();
    int paso = j * ancho + i;
    if (anteriorCivil == null || (anteriorCivil[paso] == -1)) return camino;
    while (paso != -1) {
      camino.add(0, new int[] {paso % ancho, paso / ancho});
      paso = anteriorCivil[paso];
    }
    return camino;
  }

  // Ruido por BFS: el sonido avanza por los pasillos y las puertas abiertas,
  // no atraviesa paredes. Devuelve cuantos pasos hay desde (x, y) hasta cada
  // baldosa, hasta "maxPasos" (las que no alcanza quedan en -1).
  int[][] pasosRuido(float x, float y, int maxPasos) {
    int[][] pasos = new int[ancho][alto];
    for (int i = 0; i < ancho; i++) {
      for (int j = 0; j < alto; j++) pasos[i][j] = -1;
    }
    int i0 = constrain(floor(x), 0, ancho - 1);
    int j0 = constrain(floor(y), 0, alto - 1);
    ArrayList<int[]> cola = new ArrayList<int[]>();
    cola.add(new int[] {i0, j0});
    pasos[i0][j0] = 0;
    int frente = 0;
    int[] di = {1, -1, 0, 0};
    int[] dj = {0, 0, 1, -1};
    while (frente < cola.size()) {
      int[] a = cola.get(frente);
      frente++;
      if (pasos[a[0]][a[1]] >= maxPasos) continue;
      for (int k = 0; k < 4; k++) {
        int ni = a[0] + di[k];
        int nj = a[1] + dj[k];
        if (ni < 0 || nj < 0 || ni >= ancho || nj >= alto) continue;
        if (esPared(ni, nj) || esPuertaCerrada(ni, nj) || pasos[ni][nj] >= 0) continue;
        pasos[ni][nj] = pasos[a[0]][a[1]] + 1;
        cola.add(new int[] {ni, nj});
      }
    }
    return pasos;
  }

  // ---------------------------------------------------------------------
  // Ductos: grafo de rejillas con Dijkstra (el peso es el largo del ducto)
  // ---------------------------------------------------------------------

  // Minutos (aqui: baldosas) desde la rejilla "origen" hasta cada rejilla
  int[] distanciasDucto(int origen) {
    int n = rejillas.size();
    int[] dist = new int[n];
    boolean[] fijo = new boolean[n];
    for (int k = 0; k < n; k++) dist[k] = Integer.MAX_VALUE;
    dist[origen] = 0;
    for (int vuelta = 0; vuelta < n; vuelta++) {
      // se fija la rejilla de menor distancia temporal
      int u = -1;
      for (int k = 0; k < n; k++) {
        if (!fijo[k] && dist[k] != Integer.MAX_VALUE && (u == -1 || dist[k] < dist[u])) u = k;
      }
      if (u == -1) break;
      fijo[u] = true;
      // y se relajan sus ductos
      for (int[] d : ductos) {
        int otra = -1;
        if (d[0] == u) otra = d[1];
        if (d[1] == u) otra = d[0];
        if (otra >= 0 && !fijo[otra] && dist[u] + d[2] < dist[otra]) dist[otra] = dist[u] + d[2];
      }
    }
    return dist;
  }

  int rejillaEn(int i, int j) {
    for (int k = 0; k < rejillas.size(); k++) {
      if (rejillas.get(k)[0] == i && rejillas.get(k)[1] == j) return k;
    }
    return -1;
  }
}


// ======================================================================
// MapaGrande.pde
// ======================================================================
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


// ======================================================================
// Mochila.pde
// ======================================================================
// Botin y mochila. Cada cosa que se roba tiene un valor (lo que suma al
// final) y un peso que no es proporcional: el disco duro es lo que mas vale
// por kilo y el portatil, aunque vale mas, pesa mucho. Como en la mochila
// caben 6 kg y no cabe todo, hay que elegir: es el problema de la mochila
// 0/1. Al empezar, programacion dinamica calcula el mejor botin posible y
// ese es el objetivo del HUD.
// La mochila es una pila: con X (J1) o K (J2) se saca lo ultimo que se
// guardo y queda en el piso, por si conviene cambiarlo por otra cosa.
// Mientras mas peso, mas lento y mas ruidoso se camina. Solo cuenta lo que
// se saca de la sede.

final int CAPACIDAD_MOCHILA = 6;   // kilos
final String LETRAS_BOTIN = "Phl";
final String[] NOMBRES_BOTIN = {"documento", "disco duro", "portátil"};
final int[] VALOR_BOTIN = {2, 5, 6};
final int[] PESO_BOTIN = {1, 2, 3};

int indiceBotin(char c) {
  return LETRAS_BOTIN.indexOf(c);
}

// Botin que el jugador tiene al lado (o null)
int[] botinCercano(Jugador j) {
  if (soloEscapar()) return null;
  int[] mejor = null;
  float mejorD = 1.2;
  for (int k = 0; k < LETRAS_BOTIN.length(); k++) {
    int[] t = mapa.cercano(j.x, j.y, LETRAS_BOTIN.charAt(k), 1.2);
    if (t != null && dist(j.x, j.y, t[0] + 0.5, t[1] + 0.5) <= mejorD) {
      mejor = t;
      mejorD = dist(j.x, j.y, t[0] + 0.5, t[1] + 0.5);
    }
  }
  return mejor;
}

boolean cabeEnMochila(Jugador j, int[] t) {
  int k = indiceBotin(mapa.celdas[t[0]][t[1]]);
  return j.peso + PESO_BOTIN[k] <= CAPACIDAD_MOCHILA;
}

void guardarBotin(Jugador j, int[] t) {
  int k = indiceBotin(mapa.celdas[t[0]][t[1]]);
  if (!cabeEnMochila(j, t)) {
    avisar("No cabe: la mochila lleva " + j.peso + " de " + CAPACIDAD_MOCHILA + " kg");
    return;
  }
  mapa.celdas[t[0]][t[1]] = '.';
  j.mochila.push(k);
  j.peso += PESO_BOTIN[k];
  j.valorBotin += VALOR_BOTIN[k];
  j.pruebas++;
  sonar("recoger");
  textoFlotante(t[0] + 0.5, t[1] + 0.5, "+" + VALOR_BOTIN[k], NEON_VERDE);
  chispas(t[0] + 0.5, t[1] + 0.5, NEON_VERDE, 10);
  avisar("Guardaste un " + NOMBRES_BOTIN[k] + " (+" + VALOR_BOTIN[k] + "). Mochila: " + j.peso + "/" + CAPACIDAD_MOCHILA + " kg");
}

// Saca de la mochila lo ultimo que se guardo (tope de la pila) y lo deja en
// el piso, en la baldosa libre mas cercana
void soltarBotin(Jugador j) {
  if (j.mochila.size() == 0 || j.enDucto || j.escondido || soloEscapar()) return;
  int ci = floor(j.x), cj = floor(j.y);
  int[] libre = null;
  for (int r = 0; r <= 1 && libre == null; r++) {
    for (int di = -r; di <= r && libre == null; di++) {
      for (int dj = -r; dj <= r && libre == null; dj++) {
        int i = ci + di, jj = cj + dj;
        if (i < 0 || jj < 0 || i >= mapa.ancho || jj >= mapa.alto) continue;
        if (mapa.celdas[i][jj] == '.' && !mapa.esPared(i, jj)) libre = new int[] {i, jj};
      }
    }
  }
  if (libre == null) {
    avisar("Aquí no hay espacio para dejarlo");
    return;
  }
  int k = j.mochila.pop();
  mapa.celdas[libre[0]][libre[1]] = LETRAS_BOTIN.charAt(k);
  j.peso -= PESO_BOTIN[k];
  j.valorBotin -= VALOR_BOTIN[k];
  j.pruebas--;
  sonar("recoger");
  textoFlotante(libre[0] + 0.5, libre[1] + 0.5, "-" + VALOR_BOTIN[k], COLOR_AMBAR);
  avisar("Dejaste el " + NOMBRES_BOTIN[k] + ". Mochila: " + j.peso + "/" + CAPACIDAD_MOCHILA + " kg");
}

// Mejor botin posible con las mochilas de los jugadores (programacion
// dinamica). Con un jugador es la mochila 0/1 clasica: mejor[c] = el mayor
// valor que cabe en c kilos. Con dos, el estado son los kilos libres de cada
// mochila: mejor[a][b].
int mejorBotin;

int calcularMejorBotin() {
  IntList objetos = new IntList();
  for (int i = 0; i < mapa.ancho; i++) {
    for (int j = 0; j < mapa.alto; j++) {
      int k = indiceBotin(mapa.celdas[i][j]);
      if (k >= 0) objetos.append(k);
    }
  }
  int C = CAPACIDAD_MOCHILA;
  if (numJugadores == 1) {
    int[] mejor = new int[C + 1];
    for (int k : objetos) {
      int w = PESO_BOTIN[k], v = VALOR_BOTIN[k];
      for (int c = C; c >= w; c--) mejor[c] = max(mejor[c], mejor[c - w] + v);   // de atras hacia adelante: cada objeto una vez
    }
    return mejor[C];
  }
  int[][] mejor = new int[C + 1][C + 1];
  for (int k : objetos) {
    int w = PESO_BOTIN[k], v = VALOR_BOTIN[k];
    for (int a = C; a >= 0; a--) {
      for (int b = C; b >= 0; b--) {
        if (a >= w) mejor[a][b] = max(mejor[a][b], mejor[a - w][b] + v);
        if (b >= w) mejor[a][b] = max(mejor[a][b], mejor[a][b - w] + v);
      }
    }
  }
  return mejor[C][C];
}

// Con peso se camina mas lento (hasta un 30 % menos)...
float factorPeso(Jugador j) {
  return max(0.7, 1 - 0.05 * j.peso);
}

// ...y los pasos se oyen mas lejos
float ruidoPeso(Jugador j) {
  return 0.08 * j.peso;
}

// Valor de todo el botin que hay en el mapa al empezar
int valorTotalBotin() {
  return mapa.valorBotinTotal;
}


// ======================================================================
// Oportunidades.pde
// ======================================================================
// Oportunidades (como en Hitman): objetivos opcionales que se descubren
// revisando la sede y que cambian lo que pasa despues en Alcalde Digital.
//   0. Cambiar el borrador del bulo en el computador del rival. Se descubre
//      leyendo su chat. Mantener usar 4 s junto al escritorio.
//   1. Fotografiar el tablero de conspiracion. Se descubre al verlo. El
//      flash hace un poco de ruido.
//   2. Sabotear la impresora de volantes falsos de la redaccion. Se descubre
//      en el cuaderno del rival. Mantener usar 4 s; la impresora suena.

final String[] NOMBRES_OPORTUNIDAD = {"Cambiar el borrador del bulo", "Fotografiar el tablero", "Sabotear la impresora de volantes"};
final char[] OBJETO_OPORTUNIDAD = {'O', 'X', 'I'};
final float[] RADIO_OPORTUNIDAD = {1.6, 1.9, 1.5};
final float TIEMPO_OPORTUNIDAD = 4;

boolean[] oportunidadVista = new boolean[3];
boolean[] oportunidadHecha = new boolean[3];
float[] progresoOportunidad = new float[3];
float zumbidoImpresora;

void prepararOportunidades() {
  oportunidadVista = new boolean[3];
  oportunidadHecha = new boolean[3];
  progresoOportunidad = new float[3];
}

void descubrirOportunidad(int k) {
  if (oportunidadVista[k]) return;
  oportunidadVista[k] = true;
  avisar("Oportunidad nueva: " + NOMBRES_OPORTUNIDAD[k]);
}

// La oportunidad que este jugador puede hacer ahora (o -1)
int oportunidadCercana(Jugador j) {
  if (soloEscapar()) return -1;
  for (int k = 0; k < 3; k++) {
    if (!oportunidadVista[k] || oportunidadHecha[k]) continue;
    if (mapa.cercano(j.x, j.y, OBJETO_OPORTUNIDAD[k], RADIO_OPORTUNIDAD[k]) != null) return k;
  }
  return -1;
}

// La foto es al presionar; las otras dos se hacen manteniendo usar
boolean usarOportunidad(Jugador j) {
  int k = oportunidadCercana(j);
  if (k < 0) return false;
  if (k == 1) {
    oportunidadHecha[1] = true;
    hacerRuido(j.x, j.y, 2.5);   // el flash y el "clic"
    destelloFoto = 1;
    sonar("foto");
    textoFlotante(j.x, j.y, "+3", NEON_MAGENTA);
    avisar("Foto del tablero tomada: es una prueba más (+3)");
  }
  return true;
}

float destelloFoto;

void actualizarOportunidades(float dt) {
  destelloFoto = max(0, destelloFoto - dt * 3);
  for (Jugador j : jugadores) {
    int k = oportunidadCercana(j);
    if (k != 0 && k != 2) continue;
    if (!j.usandoMantenido()) continue;
    progresoOportunidad[k] += dt / TIEMPO_OPORTUNIDAD;
    if (k == 2) {
      zumbidoImpresora -= dt;
      if (zumbidoImpresora <= 0) {
        zumbidoImpresora = 1;
        hacerRuido(j.x, j.y, 2);
      }
    }
    if (progresoOportunidad[k] >= 1) {
      oportunidadHecha[k] = true;
      sonar("servidor_listo");
      textoFlotante(j.x, j.y, "+10 apoyo", NEON_MAGENTA);
      chispas(j.x, j.y, NEON_MAGENTA, 12);
      avisar(k == 0 ? "Cambiaste el borrador: mañana su bulo sale con los datos reales"
        : "Impresora saboteada: los volantes falsos salen en blanco");
    }
  }
}

int oportunidadesHechas() {
  int n = 0;
  for (boolean b : oportunidadHecha) if (b) n++;
  return n;
}

// Panel de oportunidades debajo de los objetivos
void dibujarOportunidades(float x, float y, float w) {
  float e = escala;
  panel(x, y, w, 92 * e);
  textFont(letraChica);
  textAlign(LEFT, TOP);
  fill(NEON_MAGENTA);
  text("Oportunidades " + oportunidadesHechas() + "/3", x + 12 * e, y + 8 * e);
  for (int k = 0; k < 3; k++) {
    String t = oportunidadVista[k] ? NOMBRES_OPORTUNIDAD[k] : "??? (revisa la oficina del rival)";
    if (oportunidadVista[k] && !oportunidadHecha[k] && progresoOportunidad[k] > 0 && k != 1) t += "  " + round(progresoOportunidad[k] * 100) + "%";
    objetivo(x + 12 * e, y + 28 * e + k * 20 * e, oportunidadHecha[k], t);
  }
}

void dibujarDestelloFoto() {
  if (destelloFoto <= 0) return;
  noStroke();
  fill(255, 255, 255, 200 * destelloFoto);
  rect(0, 0, width, height);
}


// ======================================================================
// Persona.pde
// ======================================================================
// Lo que comparten los vigilantes y los civiles: posicion, hacia donde miran
// y lo que les puede pasar si los noquean (quedar en el piso, que los
// arrastren, que los escondan y que otro los encuentre).
class Persona {
  float x, y, angulo;
  boolean inconsciente;
  boolean cuerpoEscondido;   // metido en un armario o en el contenedor
  boolean encontrado;        // alguien ya vio el cuerpo y dio la alerta
  Jugador arrastradoPor;     // quien lo esta arrastrando (o null)

  // Se puede noquear si el jugador esta muy cerca y por la espalda: fuera
  // de lo que la persona tiene al frente.
  boolean sePuedeNoquear(Jugador j) {
    if (inconsciente) return false;
    if (dist(x, y, j.x, j.y) > 1.25) return false;
    float haciaJugador = atan2(j.y - y, j.x - x);
    return abs(diferenciaAngulo(haciaJugador, angulo)) > radians(100);
  }

  void noquear() {
    inconsciente = true;
    cuerpoEscondido = false;
    encontrado = false;
    arrastradoPor = null;
  }

  // El cuerpo se ve en el piso y nadie lo ha encontrado todavia
  boolean cuerpoALaVista() {
    return inconsciente && !cuerpoEscondido && !encontrado;
  }
}

// Todas las personas de la sede (vigilantes y civiles) en una sola lista,
// para recorrerlas igual al noquear, arrastrar o buscar cuerpos.
ArrayList<Persona> personas() {
  ArrayList<Persona> lista = new ArrayList<Persona>();
  lista.addAll(vigilantes);
  lista.addAll(civiles);
  return lista;
}

// La persona que el jugador puede noquear ahora (o null)
Persona aQuienNoquear(Jugador j) {
  if (j.arrastrando != null || j.escondido) return null;
  for (Persona p : personas()) {
    if (p instanceof Vigilante && ((Vigilante) p).estado == V_ALERTA) continue;
    if (p.sePuedeNoquear(j)) return p;
  }
  return null;
}

// El cuerpo que el jugador puede empezar a arrastrar (o null)
Persona cuerpoCercano(Jugador j) {
  if (j.arrastrando != null) return null;
  for (Persona p : personas()) {
    if (p.inconsciente && !p.cuerpoEscondido && p.arrastradoPor == null && dist(p.x, p.y, j.x, j.y) < 1.2) return p;
  }
  return null;
}

// Armario o contenedor libre donde meter el cuerpo que se arrastra
int[] esconditeParaCuerpo(Jugador j) {
  if (j.arrastrando == null) return null;
  int[] a = mapa.cercano(j.x, j.y, 'A', 1.7);
  if (a != null && !esconditeOcupado(a[0], a[1])) return a;
  int[] z = mapa.cercano(j.x, j.y, 'z', 1.6);
  if (z != null && !esconditeOcupado(z[0], z[1])) return z;
  return null;
}

// Armarios que ya tienen un cuerpo adentro (columna * 1000 + fila)
IntList escondites = new IntList();

boolean esconditeOcupado(int i, int j) {
  return escondites.hasValue(i * 1000 + j);
}

void noquearPersona(Jugador j, Persona p) {
  p.noquear();
  noqueos++;
  sonar("noqueo");
  sacudir(4);
  textoFlotante(p.x, p.y, "¡Pum!", NEON_MAGENTA);
  chispas(p.x, p.y, color(240, 240, 255), 8);
  hacerRuido(p.x, p.y, 1.5);   // el golpe se oye un poco
  for (int k = 0; k < 8; k++) particulas.add(new Particula(p.x, p.y));
  if (p instanceof Vigilante) {
    Vigilante v = (Vigilante) p;
    v.camino.clear();
    v.sospecha = 0;
    v.empezarRadio();
    avisar("Noqueaste al vigilante. Escóndelo antes de que lo vean");
  } else {
    avisar("Noqueaste a un empleado. Escóndelo antes de que lo vean");
  }
}

void empezarArrastre(Jugador j, Persona p) {
  j.arrastrando = p;
  p.arrastradoPor = j;
  j.agachado = false;
  avisar("Arrastrando el cuerpo. " + j.teclaUsar() + " junto a un armario para esconderlo");
}

void soltarCuerpo(Jugador j) {
  if (j.arrastrando == null) return;
  j.arrastrando.arrastradoPor = null;
  j.arrastrando = null;
}

void esconderCuerpo(Jugador j, int[] lugar) {
  Persona p = j.arrastrando;
  soltarCuerpo(j);
  p.cuerpoEscondido = true;
  p.x = lugar[0] + 0.5;
  p.y = lugar[1] + 0.5;
  escondites.append(lugar[0] * 1000 + lugar[1]);
  sonar("esconder");
  avisar(mapa.celdas[lugar[0]][lugar[1]] == 'z' ? "Cuerpo en el contenedor" : "Cuerpo escondido en el armario");
}

// El cuerpo va detras del jugador que lo arrastra
void actualizarArrastres(float dt) {
  for (Jugador j : jugadores) {
    Persona p = j.arrastrando;
    if (p == null) continue;
    float mx = j.x - j.dirX * 0.65;
    float my = j.y - j.dirY * 0.65;
    float k = min(1, dt * 8);
    p.x += (mx - p.x) * k;
    p.y += (my - p.y) * k;
    p.angulo = atan2(j.y - p.y, j.x - p.x);
  }
}

// Un vigilante (o una camara) vio un cuerpo: toda la sede se pone en alerta
void cuerpoEncontrado(Persona cuerpo, Vigilante quien) {
  cuerpo.encontrado = true;
  subirAlarma(cuerpo instanceof Vigilante ? "¡Encontraron a un vigilante noqueado!" : "¡Encontraron a un empleado noqueado!");
  for (Vigilante v : vigilantes) {
    if (v != quien) v.alarma(cuerpo.x, cuerpo.y);
  }
  if (quien != null) quien.irADespertar(cuerpo);
}


// ======================================================================
// Radio.pde
// ======================================================================
// Radio de los vigilantes. Poco despues de noquear a uno, la central lo
// llama. Si nadie contesta a tiempo, sube la alarma y mandan gente a revisar.
// Para contestar hay que acercarse al cuerpo y repetir una secuencia de
// direcciones (el jugador "imita" la voz del vigilante con calma).
// La central acepta pocas excusas: despues de MAX_RADIOS ya no se las cree.

final float ESPERA_RADIO = 4;     // segundos desde el golpe hasta que suena
final float TIEMPO_RADIO = 12;    // segundos que suena antes de que la central sospeche
final int MAX_RADIOS = 3;
final int LARGO_SECUENCIA = 4;
int radiosContestadas;

// Lo que dice la central (se elige uno al azar)
String[] LLAMADAS = {
  "Unidad, reporte su posición.",
  "¿Todo en orden por ahí?",
  "Oímos un golpe en su zona. Confirme.",
  "Control de rutina. Responda."
};
String[] RESPUESTAS = {
  "Todo tranquilo, central.",
  "Sin novedad. Fue una caja que se cayó.",
  "Aquí todo en orden.",
  "Sigo la ronda, sin novedad."
};

void sonarRadio(Vigilante v) {
  v.radioSonando = TIEMPO_RADIO;
  v.tiempoPitido = 0;
  avisar("Suena la radio del vigilante. Contéstala antes de que la central sospeche");
}

// Se llama desde Vigilante.actualizarRadio mientras esta noqueado
void actualizarRadioDe(Vigilante v, float dt) {
  if (v.radioTerminada) return;
  if (v.esperaRadio > 0) {
    v.esperaRadio -= dt;
    if (v.esperaRadio <= 0) sonarRadio(v);
    return;
  }
  if (v.radioSonando < 0) return;
  v.radioSonando -= dt;
  v.tiempoPitido -= dt;
  if (v.tiempoPitido <= 0) {
    v.tiempoPitido = 1.5;
    hacerRuido(v.x, v.y, 1.2);   // el pitido se oye de cerca
    sonar("radio");
  }
  if (v.radioSonando <= 0) falloRadio(v, "Nadie contestó la radio. La central manda a revisar");
}

void falloRadio(Vigilante v, String motivo) {
  sonar("estatica");
  v.radioSonando = -1;
  v.radioTerminada = true;
  for (Jugador j : jugadores) {
    if (j.contestando == v) j.contestando = null;
  }
  subirAlarma(motivo);
  for (Vigilante otro : vigilantes) {
    if (otro != v) otro.alarma(v.x, v.y);
  }
}

// Vigilante cuya radio suena cerca del jugador (o null)
Vigilante radioCercana(Jugador j) {
  for (Vigilante v : vigilantes) {
    if (v.inconsciente && v.radioSonando > 0 && dist(v.x, v.y, j.x, j.y) < 1.5) return v;
  }
  return null;
}

void contestarRadio(Jugador j, Vigilante v) {
  if (radiosContestadas >= maxRadios()) {
    falloRadio(v, "La central ya no te cree: reconoció que no es su vigilante");
    return;
  }
  if (j.arrastrando != null) soltarCuerpo(j);
  j.contestando = v;
  j.pasoRadio = 0;
  j.secuenciaRadio = new int[largoSecuenciaRadio(j)];
  for (int k = 0; k < j.secuenciaRadio.length; k++) j.secuenciaRadio[k] = int(random(4));
  j.llamada = int(random(LLAMADAS.length));
  j.agachado = false;
}

// dir: 0 arriba, 1 derecha, 2 abajo, 3 izquierda
void teclaRadio(Jugador j, int dir) {
  Vigilante v = j.contestando;
  if (v == null) return;
  if (dir != j.secuenciaRadio[j.pasoRadio]) {
    j.contestando = null;
    falloRadio(v, "Titubeaste en la radio. La central sospecha");
    return;
  }
  j.pasoRadio++;
  if (j.pasoRadio >= j.secuenciaRadio.length) {
    j.contestando = null;
    v.radioSonando = -1;
    v.radioTerminada = true;
    radiosContestadas++;
    String extra = radiosContestadas >= maxRadios() ? " La central no aceptará otra excusa." : "";
    avisar("\"" + RESPUESTAS[j.llamada] + "\" La central se lo creyó." + extra);
    sonar("radio_ok");
    textoFlotante(j.x, j.y, "Sin novedad", NEON_VERDE);
  }
}

// Cuadro del minijuego encima del jugador que contesta
void dibujarRadios() {
  for (Jugador j : jugadores) {
    Vigilante v = j.contestando;
    if (v == null) continue;
    float w = 330 * escala;
    float h = 112 * escala;
    // abajo al centro (en cooperativo, cada uno de su lado)
    float x = width / 2 - w / 2;
    if (jugadores.size() > 1) x = j.numero == 1 ? width / 2 - w - 10 * escala : width / 2 + 10 * escala;
    float y = height * 0.62;
    stroke(COLOR_AMBAR);
    strokeWeight(1.5 * escala);
    fill(11, 14, 26, 240);
    rect(x, y, w, h, 4 * escala);
    textFont(letraChica);
    textAlign(LEFT, TOP);
    fill(COLOR_AMBAR);
    text("RADIO · CENTRAL", x + 12 * escala, y + 10 * escala);
    fill(242, 242, 233);
    text("\"" + LLAMADAS[j.llamada] + "\"", x + 12 * escala, y + 28 * escala);
    // secuencia de flechas
    float lado = 34 * escala;
    float sep = 12 * escala;
    int largo = j.secuenciaRadio.length;
    float x0 = x + (w - (largo * lado + (largo - 1) * sep)) / 2;
    float y0 = y + 52 * escala;
    for (int k = 0; k < largo; k++) {
      float bx = x0 + k * (lado + sep);
      boolean hecha = k < j.pasoRadio;
      boolean actual = k == j.pasoRadio;
      stroke(hecha ? NEON_VERDE : (actual ? COLOR_AMBAR : color(90, 100, 130)));
      strokeWeight((actual ? 2 : 1) * escala);
      fill(hecha ? color(61, 220, 132, 60) : color(20, 26, 46));
      rect(bx, y0, lado, lado, 3 * escala);
      flecha(bx + lado / 2, y0 + lado / 2, j.secuenciaRadio[k], hecha ? NEON_VERDE : color(242, 242, 233));
    }
    // tiempo que queda
    float u = constrain(v.radioSonando / TIEMPO_RADIO, 0, 1);
    noStroke();
    fill(40, 46, 70);
    rect(x + 12 * escala, y + h - 14 * escala, w - 24 * escala, 4 * escala);
    fill(u > 0.35 ? COLOR_AMBAR : COLOR_RIVAL);
    rect(x + 12 * escala, y + h - 14 * escala, (w - 24 * escala) * u, 4 * escala);
    textAlign(RIGHT, TOP);
    fill(150, 160, 190);
    text(j.numero == 1 ? "WASD" : "Flechas", x + w - 12 * escala, y + 10 * escala);
  }
}

void flecha(float x, float y, int dir, color c) {
  pushMatrix();
  translate(x, y);
  rotate(dir * HALF_PI);
  noStroke();
  fill(c);
  float s = 7 * escala;
  triangle(0, -s * 1.3, -s, 0, s, 0);
  rect(-s * 0.35, 0, s * 0.7, s * 1.1);
  popMatrix();
}

// Radio que parpadea encima del cuerpo, con el tiempo que le queda
void iconoRadio(Vigilante v) {
  float sx = pantallaX(v.x, v.y) + 8 * pixel;
  float sy = pantallaY(v.x, v.y) - (v.cuerpoEscondido ? 34 : 20) * pixel;
  boolean prendido = (millis() / 250) % 2 == 0;
  medidor(sx, sy, 100 * v.radioSonando / TIEMPO_RADIO, COLOR_AMBAR);
  noStroke();
  fill(15, 20, 36, 230);
  ellipse(sx, sy, 20 * escala, 20 * escala);
  fill(prendido ? COLOR_AMBAR : color(120, 90, 40));
  rect(sx - 4 * escala, sy - 5 * escala, 8 * escala, 11 * escala, 1 * escala);
  rect(sx + 1 * escala, sy - 10 * escala, 2 * escala, 5 * escala);
  fill(COLOR_FONDO);
  rect(sx - 2 * escala, sy - 3 * escala, 4 * escala, 3 * escala);
}


// ======================================================================
// Rescate.pde
// ======================================================================
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


// ======================================================================
// Roles.pde
// ======================================================================
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

int rolElegido = ROL_HACKER;   // en la pantalla de elegir

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

// Pantalla para elegir el rol (entre el inicio y el reconocimiento). Va en
// pixel art, como el HUD: se dibuja en una capa del tamaño del arte (unos
// 640 x 360) con los marcos y la letra del HUD, y se agranda sin suavizar.
PGraphics capaRol;

void dibujarElegirRol() {
  if (capaRol == null || capaRol.width != capaHud.width || capaRol.height != capaHud.height) {
    capaRol = createGraphics(capaHud.width, capaHud.height);
    capaRol.noSmooth();
  }
  PGraphics g = capaRol;
  g.beginDraw();
  g.clear();
  g.noStroke();
  g.fill(0, 150);
  g.rect(0, 0, g.width, g.height);
  int w = 404, h = 262;
  int x = (g.width - w) / 2, y = (g.height - h) / 2;
  marcoPixel(g, x, y, x + w - 1, y + h - 1, NEON_CIAN);
  // titulo con una raya debajo
  g.textAlign(CENTER, TOP);
  textoPixel(g, numJugadores == 1 ? "ELIGE TU ROL" : "JUGADOR 1: ELIGE TU ROL", g.width / 2, y + 9, color(242, 242, 233), pixel12);
  g.fill(NEON_CIAN);
  g.rect(g.width / 2 - 40, y + 25, 80, 1);
  String[][] textos = {
    {"Apaga 12 s la cámara más cercana.", "Contesta la radio con 3 flechas, no 4.", "Habilidad cada 25 s."},
    {"Sombra: 6 s en los que casi nadie te nota.", "Agachado se mueve más rápido.", "Habilidad cada 30 s."}
  };
  color[] colores = {NEON_CIAN, NEON_MAGENTA};
  int cw = 184, ch = 128;
  for (int r = 0; r < 2; r++) {
    int cx = x + 14 + r * (cw + 8);
    int cy = y + 34;
    boolean sel = r == rolElegido;
    // la tarjeta elegida se levanta un pixel y titila el borde
    int sube = sel ? 1 : 0;
    color borde = sel ? ((frameCount / 20) % 2 == 0 ? colores[r] : color(242, 242, 233)) : color(70, 80, 110);
    marcoPixel(g, cx, cy - sube, cx + cw - 1, cy + ch - 1 - sube, borde);
    if (sel) {
      g.noStroke();
      g.fill(red(colores[r]), green(colores[r]), blue(colores[r]), 28);
      g.rect(cx + 3, cy + 3 - sube, cw - 6, ch - 6);
    }
    iconoRol(g, r, cx + 10, cy + 10 - sube, sel ? colores[r] : color(110, 120, 150));
    g.textAlign(LEFT, TOP);
    textoPixel(g, NOMBRES_ROL[r].toUpperCase(), cx + 32, cy + 10 - sube, sel ? colores[r] : color(170, 176, 196), pixel12);
    textoPixel(g, "F / M: " + HABILIDAD_ROL[r], cx + 32, cy + 25 - sube, color(140, 146, 170), pixel8);
    g.fill(sel ? color(226, 228, 236) : color(150, 156, 176));
    g.textFont(pixel8);
    float ty = cy + 44 - sube;
    for (int k = 0; k < 3; k++) {
      g.text("· " + textos[r][k], cx + 10, round(ty), cw - 20, 30);
      ty += g.textWidth(textos[r][k]) > cw - 28 ? 22 : 12;
    }
    if (numJugadores == 2) {
      textoPixel(g, sel ? "JUGADOR 1" : "JUGADOR 2", cx + 10, cy + ch - 16 - sube, sel ? NEON_CIAN : NEON_VERDE, pixel8);
    }
  }
  herramientasPixel(g, x + 14, y + 172, w - 28);
  // pie: teclas
  g.textAlign(CENTER, TOP);
  textoPixel(g, "A / D: CAMBIAR      E / ENTER: ENTRAR", g.width / 2, y + h - 17,
    (frameCount / 30) % 2 == 0 ? color(242, 242, 233) : color(150, 156, 176), pixel8);
  g.endDraw();
  image(capaRol, 0, 0, capaRol.width * pixel, capaRol.height * pixel);
}

// Icono de 16 x 16 de cada rol: un portátil para el hacker y un fantasma
void iconoRol(PGraphics g, int r, int x, int y, color c) {
  g.noStroke();
  if (r == 0) {
    g.fill(c);
    g.rect(x + 2, y + 2, 12, 9);
    g.fill(10, 14, 26);
    g.rect(x + 3, y + 3, 10, 7);
    g.fill(c);
    g.rect(x + 4, y + 4, 4, 1);
    g.rect(x + 4, y + 6, 6, 1);
    g.rect(x + 4, y + 8, 3, 1);
    g.rect(x, y + 12, 16, 2);
    g.fill(red(c) * 0.6, green(c) * 0.6, blue(c) * 0.6);
    g.rect(x + 1, y + 14, 14, 1);
  } else {
    g.fill(c);
    g.rect(x + 4, y + 1, 8, 1);
    g.rect(x + 2, y + 2, 12, 2);
    g.rect(x + 1, y + 4, 14, 9);
    g.rect(x + 1, y + 13, 3, 2);
    g.rect(x + 6, y + 13, 4, 2);
    g.rect(x + 12, y + 13, 3, 2);
    g.fill(10, 14, 26);
    g.rect(x + 4, y + 6, 2, 3);
    g.rect(x + 10, y + 6, 2, 3);
    g.rect(x + 7, y + 10, 2, 1);
  }
}

// Las herramientas de la campaña, en letra pixel
void herramientasPixel(PGraphics g, int x, int y, int w) {
  g.textAlign(LEFT, TOP);
  textoPixel(g, "HERRAMIENTAS DE TU CAMPAÑA" + (campanaDePrueba ? " (DE PRUEBA)" : " · " + barrioCampana.toUpperCase()), x, y, NEON_VERDE, pixel8);
  g.fill(NEON_VERDE);
  g.rect(x, y + 11, w, 1);
  int n = 0;
  for (int k = 0; k < HERRAMIENTAS.length; k++) {
    if (!tieneHerramienta(HERRAMIENTAS[k])) continue;
    if (n == 4) {
      break;   // no caben más
    }
    int cx = x;
    int cy = y + 16 + n * 11;
    g.fill(NEON_VERDE);
    g.rect(cx, cy + 3, 2, 2);
    textoPixel(g, HERRAMIENTAS[k] + ": " + EFECTO_HERRAMIENTA[k], cx + 5, cy, color(220, 222, 230), pixel8);
    n++;
  }
  if (n == 0) {
    textoPixel(g, "Ninguna. Desbloquea habilidades en el árbol de Alcalde Digital.", x, y + 16, color(140, 146, 170), pixel8);
  }
}


// ======================================================================
// Salidas.pde
// ======================================================================
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


// ======================================================================
// Seguridad.pde
// ======================================================================
// Consola del cuarto de seguridad (las pantallas de las camaras). Desde ahi:
//   1. Apagar las camaras 30 s (despues hay que esperar a que se enfrien).
//   2. Borrar las grabaciones: la alarma baja un nivel (una vez por mision).
//   3. Buscar en las pantallas: marca 30 s donde estan las tarjetas y el botin.
//   4. Vigilar: pone las camaras en bucle mientras el jugador se quede en la
//      consola. Sirve en cooperativo: uno vigila y el otro avanza.
// Mientras se usa, el jugador no se mueve. W/S o flechas eligen, E/Enter confirma.

final float TIEMPO_CAMARAS_APAGADAS = 30;
final float ENFRIAR_CAMARAS = 45;
final float TIEMPO_MOSTRAR = 30;
String[] OPCIONES_CONSOLA = {"Apagar las cámaras", "Borrar las grabaciones", "Buscar en las pantallas", "Vigilar: cámaras en bucle", "Salir"};
boolean camarasEnBucle;    // alguien se quedo en la consola vigilando

int opcionConsola;
float camarasApagadas;     // segundos que les quedan apagadas
float enfriarCamaras;      // segundos para poder volver a apagarlas
boolean grabacionesBorradas;
float mostrarObjetos;      // segundos que quedan marcados tarjetas y botin

void abrirConsola(Jugador j) {
  abrirVentana(j, 5);
  opcionConsola = 0;
}

boolean usandoConsola(Jugador j) {
  return ventana == 5 && quienLee == j;
}

void moverOpcionConsola(int d) {
  if (camarasEnBucle) return;
  opcionConsola = (opcionConsola + d + OPCIONES_CONSOLA.length) % OPCIONES_CONSOLA.length;
}

// Por que una opcion no se puede usar ahora ("" si se puede)
String bloqueoOpcion(int k) {
  if (camarasEnBucle && k != 3) return "";
  if (k == 3 && camarasEnBucle) return "vigilando";
  if (k == 0 && camarasApagadas > 0) return "apagadas " + ceil(camarasApagadas) + " s";
  if (k == 0 && enfriarCamaras > 0) return "espera " + ceil(enfriarCamaras) + " s";
  if (k == 1 && grabacionesBorradas) return "ya borradas";
  if (k == 1 && nivelAlarma == 0) return "no hay nada que borrar";
  return "";
}

void elegirOpcionConsola() {
  int k = opcionConsola;
  if (camarasEnBucle) {
    // estaba vigilando: E deja la consola
    camarasEnBucle = false;
    ventana = 0;
    avisar("Dejaste la consola: las cámaras vuelven a grabar");
    return;
  }
  if (k == 4) {
    ventana = 0;
    return;
  }
  if (k == 3) {
    camarasEnBucle = true;
    avisar("Cámaras en bucle mientras te quedes aquí. Tu compañero puede avanzar");
    return;
  }
  if (!bloqueoOpcion(k).equals("")) return;
  if (k == 0) {
    camarasApagadas = TIEMPO_CAMARAS_APAGADAS;
    for (CamaraSeguridad c : camaras) c.sospecha = 0;
    avisar("Cámaras apagadas por 30 segundos");
  } else if (k == 1) {
    grabacionesBorradas = true;
    bajarAlarma();
    avisar("Grabaciones borradas: la alarma bajó un nivel");
  } else if (k == 2) {
    mostrarObjetos = TIEMPO_MOSTRAR;
    avisar("Marcadas las tarjetas y el botín por 30 segundos");
  }
  ventana = 0;
}

void actualizarSeguridad(float dt) {
  if (camarasApagadas > 0) {
    camarasApagadas -= dt;
    if (camarasApagadas <= 0) {
      enfriarCamaras = ENFRIAR_CAMARAS;
      avisar("Las cámaras volvieron a encenderse");
    }
  } else {
    enfriarCamaras = max(0, enfriarCamaras - dt);
  }
  mostrarObjetos = max(0, mostrarObjetos - dt);
  if (camarasEnBucle && ventana != 5) camarasEnBucle = false;
}

boolean camarasEncendidas() {
  return camarasApagadas <= 0 && !camarasEnBucle;
}

void dibujarConsola() {
  float e = escala;
  float w = min(460 * e, width - 40 * e);
  float h = 290 * e;
  float x = width / 2 - w / 2;
  float y = height / 2 - h / 2 - 20 * e;
  noStroke();
  fill(0, 120);
  rect(0, 0, width, height);
  stroke(NEON_CIAN);
  strokeWeight(1.5 * e);
  fill(11, 14, 26, 245);
  rect(x, y, w, h, 4 * e);
  textFont(letraMedia);
  textAlign(LEFT, TOP);
  fill(NEON_CIAN);
  text("SEGURIDAD · consola de cámaras", x + 18 * e, y + 14 * e);
  textFont(letraChica);
  for (int k = 0; k < OPCIONES_CONSOLA.length; k++) {
    float oy = y + 52 * e + k * 38 * e;
    boolean sel = k == opcionConsola;
    String bloqueo = bloqueoOpcion(k);
    if (sel) {
      noStroke();
      fill(25, 227, 227, 40);
      rect(x + 12 * e, oy - 4 * e, w - 24 * e, 30 * e, 3 * e);
    }
    fill(bloqueo.equals("") ? color(242, 242, 233) : color(120, 128, 150));
    textAlign(LEFT, TOP);
    text((sel ? "> " : "  ") + OPCIONES_CONSOLA[k], x + 20 * e, oy + 4 * e);
    if (!bloqueo.equals("")) {
      fill(COLOR_AMBAR);
      textAlign(RIGHT, TOP);
      text(bloqueo, x + w - 22 * e, oy + 4 * e);
    }
  }
  textAlign(LEFT, BOTTOM);
  fill(150, 160, 190);
  String teclas = quienLee != null && quienLee.numero == 2 ? "Flechas elegir · Enter confirmar" : "W/S elegir · E confirmar";
  if (camarasEnBucle) teclas = "Vigilando: las cámaras no te ven ni a tu compañero · " + (quienLee != null && quienLee.numero == 2 ? "Enter" : "E") + " para salir";
  text(teclas, x + 18 * e, y + h - 12 * e);
}

// Marcas de tarjetas y botin en todo el mapa (opcion 3 de la consola)
void dibujarObjetosMarcados() {
  if (mostrarObjetos <= 0) return;
  for (int i = 0; i < mapa.ancho; i++) {
    for (int j = 0; j < mapa.alto; j++) {
      char c = mapa.celdas[i][j];
      if ("rbynPhl".indexOf(c) < 0) continue;
      float sx = pantallaX(i + 0.5, j + 0.5);
      float sy = pantallaY(i + 0.5, j + 0.5);
      color col = "rby".indexOf(c) >= 0 ? NEON_CIAN : NEON_VERDE;
      manchaLuz(sx, sy - 6 * pixel, 1.2, col, 120 + 60 * sin(millis() / 200.0), false);
      marcador(i + 0.5, j + 0.5, 24, col);
    }
  }
}


// ======================================================================
// Sprites.pde
// ======================================================================
// Sprites en pixel art (carpeta data/). Estan hechos a tamano real (una
// baldosa mide 32x16 pixeles) y se dibujan agrandados "pixel" veces sin
// suavizar, asi cada pixel del dibujo se ve como un cuadrito.

PImage[] pisoAlfombra = new PImage[2];
PImage[] pisoMadera = new PImage[2];
PImage[] pisoBaldosa = new PImage[2];
PImage pisoSalida;
PImage[] paredLadrillo = new PImage[2];
PImage paredNeon, paredNeonLuz, paredLetrero, paredLetreroLuz, paredBaja;
PImage escritorio, escritorioLuz, servidor, servidorLuz, servidorLuzCopiado;
PImage armario, farol, farolLuz, prueba;
PImage brillo;   // mancha de luz blanca y suave, se pinta del color de cada luz
PImage[] pisoAsfalto = new PImage[2];
PImage[] pisoMetal = new PImage[2];
PImage[] pisoNegro = new PImage[2];
PImage[] pisoBlanca = new PImage[2];
PImage[] pisoRoja = new PImage[2];
// Sprite (y su parte que brilla) de cada letra del mapa: muebles, objetos y puertas
PImage[] spriteObjeto = new PImage[128];
PImage[] spriteObjetoLuz = new PImage[128];

SpritesPersona spritesJugador1, spritesJugador2, spritesVigilante;
SpritesPersona spritesCivil, spritesCivil2, spritesJefe, spritesConserje1, spritesConserje2;

// Los cuadros de un personaje: de frente y de espaldas, quieto y dos pasos
// de caminar, y agachado (solo los jugadores).
class SpritesPersona {
  PImage[] frente = new PImage[3];
  PImage[] espalda = new PImage[3];
  PImage frenteAgachado, espaldaAgachado;

  SpritesPersona(String nombre, boolean conAgachado) {
    for (int k = 0; k < 3; k++) {
      frente[k] = loadImage(nombre + "_frente_" + k + ".png");
      espalda[k] = loadImage(nombre + "_espalda_" + k + ".png");
    }
    if (conAgachado) {
      frenteAgachado = loadImage(nombre + "_frente_agachado.png");
      espaldaAgachado = loadImage(nombre + "_espalda_agachado.png");
    }
  }
}

void cargarSprites() {
  for (int k = 0; k < 2; k++) {
    pisoAlfombra[k] = loadImage("piso_alfombra_" + k + ".png");
    pisoMadera[k] = loadImage("piso_madera_" + k + ".png");
    pisoBaldosa[k] = loadImage("piso_baldosa_" + k + ".png");
    paredLadrillo[k] = loadImage("pared_" + k + ".png");
  }
  pisoSalida = loadImage("piso_salida.png");
  paredNeon = loadImage("pared_neon.png");
  paredNeonLuz = loadImage("pared_neon_luz.png");
  paredLetrero = loadImage("pared_letrero.png");
  paredLetreroLuz = loadImage("pared_letrero_luz.png");
  paredBaja = loadImage("pared_baja.png");
  escritorio = loadImage("escritorio.png");
  escritorioLuz = loadImage("escritorio_luz.png");
  servidor = loadImage("servidor.png");
  servidorLuz = loadImage("servidor_luz.png");
  servidorLuzCopiado = loadImage("servidor_luz_copiado.png");
  armario = loadImage("armario.png");
  farol = loadImage("farol.png");
  farolLuz = loadImage("farol_luz.png");
  prueba = loadImage("prueba.png");
  brillo = loadImage("brillo.png");
  for (int k = 0; k < 2; k++) {
    pisoAsfalto[k] = loadImage("piso_asfalto_" + k + ".png");
    pisoMetal[k] = loadImage("piso_metal_" + k + ".png");
    pisoNegro[k] = loadImage("piso_negro_" + k + ".png");
    pisoBlanca[k] = loadImage("piso_blanca_" + k + ".png");
    pisoRoja[k] = loadImage("piso_roja_" + k + ".png");
  }
  ponerSprite('A', "armario", false);
  ponerSprite('M', "escritorio", true);
  ponerSprite('S', "servidor", true);
  ponerSprite('L', "farol", true);
  ponerSprite('P', "prueba", false);
  ponerSprite('h', "disco_duro", true);
  ponerSprite('l', "laptop", true);
  ponerSprite('m', "moto", true);
  ponerSprite('E', "camioneta", true);
  ponerSprite('T', "tablero_electrico", true);
  ponerSprite('r', "tarjeta_roja", true);
  ponerSprite('b', "tarjeta_azul", true);
  ponerSprite('y', "tarjeta_amarilla", true);
  ponerSprite('n', "nota", false);
  ponerSprite('o', "botella", false);
  ponerSprite('C', "carro", true);
  ponerSprite('p', "planta", false);
  ponerSprite('I', "impresora", true);
  ponerSprite('V', "camara_estudio", true);
  ponerSprite('Q', "consola", true);
  ponerSprite('O', "escritorio_rival", true);
  ponerSprite('W', "tv_rival", true);
  ponerSprite('X', "tablero_conspiracion", false);
  ponerSprite('U', "cuaderno_rival", true);
  ponerSprite('H', "sofa", false);
  ponerSprite('Z', "casillero", false);
  ponerSprite('F', "cafetera", true);
  ponerSprite('v', "rejilla", false);
  ponerSprite('c', "caseta", true);
  ponerSprite('z', "contenedor", false);
  ponerSprite('G', "pantalla_verde", false);
  ponerSprite('1', "puerta_roja", true);
  ponerSprite('2', "puerta_azul", true);
  ponerSprite('3', "puerta_amarilla", true);
  ponerSprite('4', "puerta_codigo", true);
  spritesJugador1 = new SpritesPersona("jugador1", true);
  spritesJugador2 = new SpritesPersona("jugador2", true);
  spritesVigilante = new SpritesPersona("vigilante", false);
  spritesCivil = new SpritesPersona("civil", false);
  spritesCivil2 = new SpritesPersona("civil2", false);
  spritesJefe = new SpritesPersona("jefe", false);
  spritesConserje1 = new SpritesPersona("jugador1_conserje", true);
  spritesConserje2 = new SpritesPersona("jugador2_conserje", true);
}

void ponerSprite(char letra, String nombre, boolean conLuz) {
  spriteObjeto[letra] = loadImage(nombre + ".png");
  if (conLuz) spriteObjetoLuz[letra] = loadImage(nombre + "_luz.png");
}

// Dibuja un sprite agrandado. (x, y) es la esquina de arriba a la izquierda
// en pantalla; se redondea para que los pixeles no queden partidos.
void sprite(PImage img, float x, float y) {
  image(img, round(x), round(y), img.width * pixel, img.height * pixel);
}

// Tinte segun la luz de la baldosa (azul de noche, rojo cerca de un farol...)
void tinteLuz(int i, int j, float alfa) {
  i = constrain(i, 0, mapa.ancho - 1);
  j = constrain(j, 0, mapa.alto - 1);
  tint(min(255, mapa.luzR[i][j] * 255), min(255, mapa.luzG[i][j] * 255), min(255, mapa.luzB[i][j] * 255), alfa);
}

// Mancha de luz de color, transparente, encima de lo ya dibujado: da el
// brillo de neon. "radio" en baldosas; "aplastada" la deja ovalada como
// se ve un circulo en el piso isometrico.
void manchaLuz(float sx, float sy, float radio, color c, float alfa, boolean aplastada) {
  float w = radio * anchoBaldosa * 1.414;
  float h = aplastada ? w / 2 : w;
  tint(red(c), green(c), blue(c), min(255, alfa));
  image(brillo, sx - w / 2, sy - h / 2, w, h);
  noTint();
}


// ======================================================================
// Teclado.pde
// ======================================================================
// Puerta del cuarto del servidor: teclado con un codigo de 4 digitos que
// cambia en cada mision. Los dos primeros estan en una nota del archivo y
// los dos ultimos se escuchan en una conversacion. Se puede intentar sin
// saberlo, pero con 3 codigos malos salta la alarma y el teclado se bloquea.
// Se marca con las teclas de numeros; Borrar corrige; E/Enter cierra.

final int INTENTOS_TECLADO = 3;
final float BLOQUEO_TECLADO = 20;

String codigoServidor = "0000";
boolean[] digitoConocido = new boolean[4];
String marcado = "";
int intentosMalos;
float tecladoBloqueado;
int[] puertaTeclado;          // la puerta que se esta abriendo
float mensajeTeclado;         // segundos que se muestra "incorrecto"

void prepararCodigo() {
  codigoServidor = "";
  for (int k = 0; k < 4; k++) codigoServidor += int(random(10));
  digitoConocido = new boolean[4];
  marcado = "";
  intentosMalos = 0;
  tecladoBloqueado = 0;
  mensajeTeclado = 0;
}

void conocerDigitos(int a, int b, String mensaje) {
  boolean nuevo = !digitoConocido[a] || !digitoConocido[b];
  digitoConocido[a] = true;
  digitoConocido[b] = true;
  boolean todos = digitoConocido[0] && digitoConocido[1] && digitoConocido[2] && digitoConocido[3];
  tarjetas[4] = todos;   // para el grafo de cuartos: ya se puede entrar
  if (nuevo) avisar(mensaje + ": " + codigoConocido() + (todos ? ". ¡Ya tienes el código completo!" : ""));
}

// El codigo con lo que se sabe y "_" en lo que falta
String codigoConocido() {
  String s = "";
  for (int k = 0; k < 4; k++) s += digitoConocido[k] ? "" + codigoServidor.charAt(k) : "_";
  return s;
}

void abrirTeclado(Jugador j, int[] puerta) {
  if (tecladoBloqueado > 0) {
    avisar("El teclado está bloqueado " + ceil(tecladoBloqueado) + " s");
    return;
  }
  puertaTeclado = puerta;
  marcado = "";
  abrirVentana(j, 6);
}

boolean usandoTeclado(Jugador j) {
  return ventana == 6 && quienLee == j;
}

void teclaTeclado(char c) {
  if (c == BACKSPACE) {
    if (marcado.length() > 0) marcado = marcado.substring(0, marcado.length() - 1);
    return;
  }
  if (c < '0' || c > '9' || marcado.length() >= 4) return;
  marcado += c;
  sonar("tecla");
  if (marcado.length() < 4) return;
  if (marcado.equals(codigoServidor)) {
    mapa.abrirPuerta(puertaTeclado[0], puertaTeclado[1]);
    conocerDigitos(0, 1, "");
    conocerDigitos(2, 3, "");
    ventana = 0;
    avisar("Código correcto: la puerta del servidor se abrió");
    sonar("codigo_ok");
    sonar("puerta");
    return;
  }
  intentosMalos++;
  sonar("codigo_mal");
  sacudir(3);
  mensajeTeclado = 1.2;
  if (intentosMalos >= INTENTOS_TECLADO) {
    intentosMalos = 0;
    tecladoBloqueado = BLOQUEO_TECLADO;
    ventana = 0;
    subirAlarma("Tres códigos malos: saltó la alarma del teclado");
    hacerRuido(puertaTeclado[0] + 0.5, puertaTeclado[1] + 0.5, 6);
  }
}

void actualizarTeclado(float dt) {
  tecladoBloqueado = max(0, tecladoBloqueado - dt);
  mensajeTeclado = max(0, mensajeTeclado - dt);
  if (mensajeTeclado <= 0 && marcado.length() == 4) marcado = "";
}

void dibujarTeclado() {
  float e = escala;
  float w = 330 * e;
  float h = 316 * e;
  float x = width / 2 - w / 2;
  float y = height / 2 - h / 2 - 20 * e;
  noStroke();
  fill(0, 120);
  rect(0, 0, width, height);
  stroke(NEON_CIAN);
  strokeWeight(1.5 * e);
  fill(11, 14, 26, 245);
  rect(x, y, w, h, 6 * e);
  textFont(letraChica);
  textAlign(CENTER, TOP);
  fill(NEON_CIAN);
  text("CUARTO DEL SERVIDOR", x + w / 2, y + 12 * e);
  // pantalla con lo marcado
  boolean malo = mensajeTeclado > 0;
  fill(malo ? color(90, 20, 30) : color(8, 30, 30));
  stroke(malo ? COLOR_RIVAL : color(25, 227, 227, 120));
  rect(x + 30 * e, y + 34 * e, w - 60 * e, 46 * e, 3 * e);
  textFont(letraGrande);
  textAlign(CENTER, CENTER);
  fill(malo ? COLOR_RIVAL : NEON_VERDE);
  String pantalla = malo ? "ERROR" : "";
  if (!malo) {
    for (int k = 0; k < 4; k++) pantalla += (k < marcado.length() ? marcado.charAt(k) : '·') + (k < 3 ? " " : "");
  }
  text(pantalla, x + w / 2, y + 56 * e);
  // teclas (solo dibujo: se marca con el teclado de verdad)
  textFont(letraMedia);
  String[] filas = {"1 2 3", "4 5 6", "7 8 9", "  0  "};
  for (int f = 0; f < 4; f++) {
    for (int c = 0; c < 3; c++) {
      char d = filas[f].charAt(c * 2);
      if (d == ' ') continue;
      float bx = x + w / 2 - 66 * e + c * 46 * e;
      float by = y + 94 * e + f * 34 * e;
      noStroke();
      fill(30, 38, 62);
      rect(bx, by, 40 * e, 28 * e, 3 * e);
      fill(220);
      text(d, bx + 20 * e, by + 13 * e);
    }
  }
  textFont(letraChica);
  textAlign(LEFT, BOTTOM);
  fill(150, 160, 190);
  text("Sabes: " + codigoConocido(), x + 14 * e, y + h - 26 * e);
  textAlign(RIGHT, BOTTOM);
  text("Intentos malos: " + intentosMalos + " de " + INTENTOS_TECLADO, x + w - 14 * e, y + h - 26 * e);
  textAlign(CENTER, BOTTOM);
  fill(110, 120, 150);
  text("Marca con los números · E/Enter para salir", x + w / 2, y + h - 8 * e);
}


// ======================================================================
// Valeria.pde
// ======================================================================
// Valeria: la estratega de la campana que guia al candidato por el auricular.
// No tiene frases grabadas: cada vez que pasa algo importante el juego arma
// un resumen de la mision (donde estas, que falta, la alarma, los vigilantes
// y lo ultimo que ella dijo) y se lo manda a un modelo de lenguaje (Claude),
// que escribe la frase. Despues la frase se convierte en voz (Azure, voz
// colombiana) y suena con un filtro de radio, con subtitulo en el HUD.
//
//   evento -> cola de prioridad -> resumen -> Claude -> texto -> Azure -> voz
//
// Las llamadas a internet van en un hilo aparte para que el juego no se
// trabe. Sin claves o sin internet usa frases de respaldo (solo texto).
// Las claves van en data/valeria.txt (no se comparte ese archivo).
//
// Para no hablar de mas:
//   - Los eventos entran a una cola de prioridad (alarma > pista > consejo).
//   - Entre una frase y otra hay una pausa minima; lo urgente espera menos.
//   - Cada tipo de evento tiene su propio tiempo de espera.
//   - Un evento viejo (que ya no tiene sentido comentar) se descarta.

final int LLAMADA = 7;
final color COLOR_VALERIA = #C08CFF;
final float PAUSA_VALERIA = 9;          // segundos minimos entre frases
final float PAUSA_URGENTE = 1.5;        // si el evento es de prioridad 3
final int FALLOS_PARA_RESPALDO = 3;     // tras 3 errores seguidos deja de intentar

final String PERSONA_VALERIA =
  "Eres Valeria, la estratega digital de la campaña de un candidato a la alcaldía. " +
  "Esta noche lo guías por un auricular mientras él se mete a escondidas a la sede de Titulares Ya, " +
  "la agencia que fabrica bulos contra él, para copiar su servidor y salir sin que lo vean.\n" +
  "Cómo hablas:\n" +
  "- Español neutro. Tuteas al candidato (tú, nunca vos). Sin groserías.\n" +
  "- Una o dos frases, máximo 22 palabras en total: es por radio, corto y claro.\n" +
  "- El tono va con el momento: urgente si lo persiguen, tranquila si todo va bien, a veces con humor seco.\n" +
  "- Usa solo los datos que te pasan. No inventes cuartos, objetos, códigos, nombres ni personas.\n" +
  "- Nunca digas dígitos del código que no estén en los datos.\n" +
  "- Si das un consejo, que sea uno solo y concreto, basado en el siguiente paso que te pasan.\n" +
  "- Comenta solo lo que acaba de pasar y qué hacer justo con eso. No repitas la lista de objetivos ni cosas que el candidato ya sabe.\n" +
  "- No hables de las botellas a menos que el evento las mencione.\n" +
  "- No repitas lo que ya dijiste.\n" +
  "- Sin emojis, comillas, asteriscos ni acotaciones: solo lo que dices.";

// ---------------------------------------------------------------- claves

// proveedor del modelo que escribe: "groq" (API compatible con OpenAI) o "claude"
String proveedorIA = "groq";
String claveClaude = "", modeloClaude = "claude-haiku-5-5";
String claveGroq = "", modeloGroq = "openai/gpt-oss-20b";
String claveAzure = "", regionAzure = "eastus", vozAzure = "es-CO-SalomeNeural";
// la voz de Marta, la periodista que llama cada turno (Alcalde Digital)
String vozPeriodista = "es-MX-DaliaNeural";
boolean valeriaActiva = true, efectoRadio = true;
// Por ahora Valeria usa frases programadas segun lo que pasa (Jose, 25-10).
// La IA y la voz quedan listas para el mundo abierto: usar_ia=si en valeria.txt.
boolean usarIA = false;
// La voz (Azure) si se usa con las frases programadas: usar_voz=si. Cada frase
// se guarda en data/voz/ la primera vez, asi despues suena sin internet.
boolean usarVoz = true;
int fallosSeguidos;
// Si internet falla, durante un rato no se vuelve a intentar: Valeria habla
// con sus frases de respaldo y las voces ya guardadas, sin hacer esperar.
volatile long sinRedHasta = 0;
final int SEGUNDOS_SIN_RED = 40;

boolean hayRed() {
  return System.currentTimeMillis() > sinRedHasta;
}

void marcarSinRed(Exception e) {
  // los errores de conexión y de tiempo agotado cuentan; un error HTTP no
  if (e instanceof java.io.IOException) sinRedHasta = System.currentTimeMillis() + SEGUNDOS_SIN_RED * 1000L;
}

void leerConfigValeria() {
  String[] lineas = null;
  try {
    if (new java.io.File(dataPath("valeria.txt")).exists()) lineas = loadStrings("valeria.txt");
  } catch (Exception e) {
    lineas = null;
  }
  if (lineas == null) return;
  for (String l : lineas) {
    l = trim(l);
    if (l.length() == 0 || l.charAt(0) == '#' || l.indexOf('=') < 0) continue;
    String clave = trim(l.substring(0, l.indexOf('=')));
    String valor = trim(l.substring(l.indexOf('=') + 1));
    if (clave.equals("proveedor") && valor.length() > 0) proveedorIA = valor.toLowerCase();
    if (clave.equals("groq_clave")) claveGroq = valor;
    if (clave.equals("groq_modelo") && valor.length() > 0) modeloGroq = valor;
    if (clave.equals("claude_clave")) claveClaude = valor;
    if (clave.equals("claude_modelo") && valor.length() > 0) modeloClaude = valor;
    if (clave.equals("azure_clave")) claveAzure = valor;
    if (clave.equals("azure_region") && valor.length() > 0) regionAzure = valor;
    if (clave.equals("azure_voz") && valor.length() > 0) vozAzure = valor;
    if (clave.equals("azure_voz_periodista") && valor.length() > 0) vozPeriodista = valor;
    if (clave.equals("activa")) valeriaActiva = !valor.equals("no");
    if (clave.equals("usar_ia")) usarIA = valor.equals("si");
    if (clave.equals("usar_voz")) usarVoz = !valor.equals("no");
    if (clave.equals("efecto_radio")) efectoRadio = !valor.equals("no");
  }
  println("Valeria: " + (valeriaConIA() ? "con IA (" + proveedorIA + ", " + modeloIA() + ")" : "frases de respaldo") +
    (valeriaConVoz() ? ", voz " + vozAzure : ", sin voz" + (claveAzure.length() > 10 ? "" : " (falta azure_clave)")));
}

boolean valeriaConIA() {
  String clave = proveedorIA.equals("claude") ? claveClaude : claveGroq;
  return usarIA && clave.length() > 10 && fallosSeguidos < FALLOS_PARA_RESPALDO && hayRed();
}

String modeloIA() {
  return proveedorIA.equals("claude") ? modeloClaude : modeloGroq;
}

boolean valeriaConVoz() {
  return (usarIA || usarVoz) && claveAzure.length() > 10;
}

// ---------------------------------------------------------------- eventos

class EventoValeria {
  String tipo;       // "alarma", "pista", "consejo"...
  int prioridad;     // 0 a 3
  String detalle;    // lo que paso, en palabras, para el modelo
  String fija;       // frase programada para este evento (o null: una del tipo)
  float cuando;      // segundos reales (millis) en que paso

  EventoValeria(String tipo, int prioridad, String detalle) {
    this.tipo = tipo;
    this.prioridad = prioridad;
    this.detalle = detalle;
    cuando = millis() / 1000.0;
  }

  float edad() {
    return millis() / 1000.0 - cuando;
  }

  // despues de este tiempo ya no vale la pena comentarlo
  float vida() {
    return prioridad >= 3 ? 12 : 8;
  }
}

// Cola de prioridad: primero la prioridad mas alta y, a igual prioridad, el
// mas reciente
java.util.PriorityQueue<EventoValeria> colaValeria = new java.util.PriorityQueue<EventoValeria>(16,
  new java.util.Comparator<EventoValeria>() {
  public int compare(EventoValeria a, EventoValeria b) {
    if (a.prioridad != b.prioridad) return b.prioridad - a.prioridad;
    return Float.compare(b.cuando, a.cuando);
  }
}
);

// Tiempo minimo entre dos eventos del mismo tipo
HashMap<String, Float> ultimoDeTipo = new HashMap<String, Float>();
String[] TIPOS_ESPERA = {"sospecha", "persecucion", "escapo", "consejo", "botin", "noqueo", "oportunidad"};
float[] SEGUNDOS_ESPERA = {40, 25, 30, 60, 45, 30, 30};

void eventoValeria(String tipo, int prioridad, String detalle) {
  eventoValeria(tipo, prioridad, detalle, null);
}

// fija: la frase que dice Valeria en el modo de frases programadas
void eventoValeria(String tipo, int prioridad, String detalle, String fija) {
  if (!valeriaActiva || estado == GANASTE || estado == PERDISTE) return;
  float ahora = millis() / 1000.0;
  int k = java.util.Arrays.asList(TIPOS_ESPERA).indexOf(tipo);
  if (k >= 0 && ultimoDeTipo.containsKey(tipo) && ahora - ultimoDeTipo.get(tipo) < SEGUNDOS_ESPERA[k]) return;
  ultimoDeTipo.put(tipo, ahora);
  // un solo evento de cada tipo en la cola: el nuevo reemplaza al viejo
  java.util.Iterator<EventoValeria> it = colaValeria.iterator();
  while (it.hasNext()) if (it.next().tipo.equals(tipo)) it.remove();
  EventoValeria ev = new EventoValeria(tipo, prioridad, detalle);
  ev.fija = fija;
  colaValeria.add(ev);
}

// ---------------------------------------------------------------- estado

// Lo que se miro en el cuadro anterior, para notar los cambios
boolean[] vTarj = new boolean[5];
int vAlarma, vTarjetas, vDigitos, vNoqueos, vBotin, vOportVistas, vOportHechas;
boolean vAlerta, vSospecha, vServidor, vPistaA, vPistaR, vDisfraz, vAtrapado;
String vAviso = "";
int vEstado = -1;
float sinAlerta, quieto;

// La frase que se esta diciendo
String fraseValeria = "";
float tiempoFrase, duracionFrase, finUltimaFrase = -99;
Clip vozActual;
StringList dichas = new StringList();   // lo ultimo que dijo (para no repetir)
boolean esperandoValeria;               // hay un pedido en camino
volatile RespuestaValeria respuestaLista;
PImage caraValeria;
PGraphics capaValeria;

class RespuestaValeria {
  EventoValeria ev;  // el evento que se está comentando
  String texto;
  Clip voz;
  float segundos;
  boolean conIA;
}

void iniciarValeria() {
  leerConfigValeria();
  caraValeria = loadImage("valeria.png");
  capaValeria = createGraphics(300, 52);
  capaValeria.noSmooth();
}

void reiniciarValeria() {
  colaValeria.clear();
  ultimoDeTipo.clear();
  dichas.clear();
  callarValeria();
  vEstado = -1;
}

void callarValeria() {
  if (vozActual != null) vozActual.stop();
  vozActual = null;
  fraseValeria = "";
  respuestaLista = null;
  esperandoValeria = false;
  if (musica != null) musica.atenuar = 1;
}

int tarjetasTenidas() {
  int n = 0;
  for (int k = 1; k <= 3; k++) if (tarjetas[k]) n++;
  return n;
}

int digitosConocidos() {
  int n = 0;
  for (boolean b : digitoConocido) if (b) n++;
  return n;
}

int botinLlevado() {
  int n = 0;
  for (Jugador j : jugadores) n += j.valorBotin;
  return n;
}

// Cada cuadro: mira que cambio y lo vuelve evento
void detectarEventosValeria(float dt) {
  if (estado != vEstado) {
    if (estado == JUGANDO && vEstado == RECONOCIMIENTO) {
      eventoValeria("inicio", 2, "El candidato acaba de entrar a la sede. Dale ánimo y un recordatorio corto.");
    }
    // al terminar la mision (ganes o pierdas) se calla
    if (estado == GANASTE || estado == PERDISTE) {
      callarValeria();
      colaValeria.clear();
    }
    vEstado = estado;
    leerEstadoValeria();
    return;
  }
  if (estado != JUGANDO || mapaAbierto) return;

  boolean alerta = false, sospecha = false, jefeAlerta = false;
  for (Vigilante v : vigilantes) {
    if (v.inconsciente) continue;
    if (v.estado == V_ALERTA) {
      alerta = true;
      if (v.esJefe) jefeAlerta = true;
    } else if (v.estado != V_PATRULLA) sospecha = true;
  }
  boolean atrapado = false, disfraz = false;
  for (Jugador j : jugadores) {
    if (j.atrapado) atrapado = true;
    if (j.disfrazado) disfraz = true;
  }
  int oVistas = 0, oHechas = oportunidadesHechas();
  for (boolean b : oportunidadVista) if (b) oVistas++;
  boolean algo = false;   // ya se genero un evento en este cuadro

  if (nivelAlarma > vAlarma) {
    eventoValeria("alarma", 3, "La alarma subió a nivel " + nivelAlarma + " (" + NOMBRES_ALARMA[nivelAlarma] + "). Motivo: " + aviso +
      (nivelAlarma == 2 ? ". Prendieron las luces y cerraron la entrada principal." : "") +
      (nivelAlarma == 3 ? ". La policía viene en camino: hay que salir ya." : ""));
    algo = true;
  }
  if (atrapado && !vAtrapado) {
    eventoValeria("atrapado", 3, jugadores.size() > 1 ? "Atraparon a uno de los dos; el otro puede rescatarlo." : "Atraparon al candidato.");
    algo = true;
  }
  if (alerta && !vAlerta) {
    eventoValeria("persecucion", 3, (jefeAlerta ? "El jefe de seguridad" : "Un vigilante") + " vio al candidato y lo persigue.");
    algo = true;
  }
  // cuando pasan 4 s sin que nadie lo persiga, lo perdieron
  if (alerta) {
    alertaReciente = true;
    sinAlerta = 0;
  } else {
    sinAlerta += dt;
    if (alertaReciente && sinAlerta > 4) {
      eventoValeria("escapo", 2, "Los vigilantes le perdieron el rastro al candidato.");
      alertaReciente = false;
    }
  }
  if (sospecha && !vSospecha && !alerta) {
    eventoValeria("sospecha", 2, "Un vigilante notó algo raro y está sospechando, pero todavía no lo ha visto bien." +
      (jugadores.get(0).botellas > 0 ? " Tiene " + jugadores.get(0).botellas + " botellas: lanzar una lejos manda al vigilante hacia el ruido." : ""),
      jugadores.get(0).botellas > 0 ? "¡Te está mirando! Lanza una botella lejos con la Q o escóndete." : "¡Te está mirando! Aléjate o escóndete ya.");
    algo = true;
  }
  if (servidorCopiado && !vServidor) {
    eventoValeria("servidor", 3, "¡Copió el servidor! Ya solo queda escapar. Salidas que sirven ahora: " + salidasQueSirven() + ".",
      "¡Lo tienes! Ahora sal de ahí. Te sirven " + salidasQueSirven() + ".");
    algo = true;
  }
  // tarjeta nueva: que diga para que sirve y que la busque en el mapa
  String[] queAbre = {"",
    "la puerta de carga del parqueadero (es otra salida y otro camino para entrar)",
    "el cuarto de Seguridad, donde la consola deja apagar cámaras, borrar grabaciones o vigilar las pantallas",
    "la Oficina del rival, donde puede leer el chat del rival y descubrir oportunidades"};
  int[] zonaQueAbre = {-1, -1, 4, 7};
  String[] colorTarjeta = {"", "roja", "azul", "amarilla"};
  for (int k = 1; k <= 3; k++) {
    if (tarjetas[k] && !vTarj[k]) {
      if (zonaQueAbre[k] >= 0) resalteZona[zonaQueAbre[k]] = 25;   // parpadea en el mapa
      String[] fijas = {"",
        "La tarjeta roja abre la puerta de carga del parqueadero: otra salida si la entrada se complica.",
        "La azul abre el cuarto de Seguridad. Abre el mapa con la G, está parpadeando. Desde la consola apagas las cámaras.",
        "La amarilla abre la oficina del rival. Mírala en el mapa con la G y lee su chat."};
      eventoValeria("tarjeta", 2, "Recogió la tarjeta " + colorTarjeta[k] + ". Abre " + queAbre[k] +
        ". Dile para qué le sirve y que abra el mapa con la G para ubicar ese cuarto" + (zonaQueAbre[k] >= 0 ? ", que ahora está parpadeando." : "."), fijas[k]);
      algo = true;
    }
  }
  if (digitosConocidos() > vDigitos) {
    if (digitosConocidos() == 4) {
      resalteZona[6] = 25;
      eventoValeria("codigo", 2, "Ya tiene el código completo del Cuarto del servidor: " + codigoConocido() +
        ". Ya puede entrar (en el mapa con G está parpadeando), pero copiar el servidor es lo último que se hace: después solo queda escapar.",
        "Código completo: " + codigoConocido() + ". El cuarto del servidor parpadea en el mapa. Cópialo de último, luego solo queda salir.");
    } else {
      eventoValeria("codigo", 2, "Descubrió dígitos del código del Cuarto del servidor. Código conocido: " + codigoConocido() +
        (digitoConocido[0] ? ". Los dígitos que faltan se escuchan en una conversación de los empleados." : ". Los que faltan están anotados en el Archivo."),
        digitoConocido[0] ? "Tenemos la mitad del código. La otra mitad la dicen los empleados cuando conversan: acércate a escuchar." : "Ya sabemos el final del código. El resto está anotado en el Archivo.");
    }
    algo = true;
  }
  if ((pistaAmarilla && !vPistaA) || (pistaRoja && !vPistaR)) {
    eventoValeria("pista", 2, "Escuchó una conversación con una pista: " + aviso);
    algo = true;
  }
  if (disfraz && !vDisfraz) {
    eventoValeria("disfraz", 2, "Se puso el uniforme de conserje. Los vigilantes normales no lo reconocen salvo que esté pegado a ellos; el jefe de seguridad sí lo reconoce de cerca.",
      "Con ese uniforme pasas por cualquier cuarto. No corras, no te agaches y no te acerques al jefe de gorra blanca.");
    algo = true;
  }
  if (noqueos > vNoqueos) {
    eventoValeria("noqueo", 1, "Noqueó a alguien. Conviene esconder el cuerpo: si lo encuentran sube la alarma.");
    algo = true;
  }
  if (botinLlevado() > vBotin) {
    eventoValeria("botin", 1, "Guardó botín en la mochila. Lleva " + botinLlevado() + " puntos; lo mejor que cabe en la mochila es " + mejorBotin +
      ". Cada objeto vale distinto a lo que pesa (documento 1 kg = 2, disco duro 2 kg = 5, portátil 3 kg = 6), así que conviene elegir bien; con X suelta lo último que guardó.",
      botinLlevado() >= mejorBotin ? "Ese es el mejor botín que cabe. Ya no cargues más." :
      "Llevas " + botinLlevado() + " de " + mejorBotin + " posibles. Lo que más vale por kilo es el disco duro.");
    algo = true;
  }
  if (oVistas > vOportVistas || oHechas > vOportHechas) {
    eventoValeria("oportunidad", 1, aviso);
    algo = true;
  }

  // si se queda quieto un rato sin peligro, un consejo
  boolean seMueve = false;
  for (Jugador j : jugadores) if (j.moviendose) seMueve = true;
  quieto = seMueve || alerta || sospecha ? 0 : quieto + dt;
  if (quieto > 45) {
    quieto = 0;
    String paso = siguientePaso();
    eventoValeria("consejo", 0, "El candidato lleva rato quieto. Dale un consejo concreto sobre qué hacer ahora.",
      "¿Seguimos? Lo que falta: " + paso);
  }
  vAlerta = alerta;
  vSospecha = sospecha;
  vAtrapado = atrapado;
  vDisfraz = disfraz;
  vOportVistas = oVistas;
  vOportHechas = oHechas;
  vAlarma = nivelAlarma;
  vServidor = servidorCopiado;
  vTarjetas = tarjetasTenidas();
  vTarj = tarjetas.clone();
  vDigitos = digitosConocidos();
  vPistaA = pistaAmarilla;
  vPistaR = pistaRoja;
  vNoqueos = noqueos;
  vBotin = botinLlevado();
  vAviso = aviso;
}

boolean alertaReciente;

void leerEstadoValeria() {
  vAlarma = nivelAlarma;
  vServidor = servidorCopiado;
  vTarjetas = tarjetasTenidas();
  vTarj = tarjetas.clone();
  vDigitos = digitosConocidos();
  vPistaA = pistaAmarilla;
  vPistaR = pistaRoja;
  vNoqueos = noqueos;
  vBotin = botinLlevado();
  vAviso = aviso;
  vAlerta = false;
  vSospecha = false;
  vAtrapado = false;
  vDisfraz = false;
  alertaReciente = false;
  quieto = 0;
}

String salidasQueSirven() {
  String[] nombres = {"la camioneta de la entrada", "la moto del fondo del parqueadero", "el ducto a la calle"};
  String s = "";
  for (int k = 0; k < 3; k++) {
    String b = bloqueoSalida(k);
    if (b.equals("") || b.startsWith("Espera")) s += (s.equals("") ? "" : ", ") + nombres[k];
  }
  return s.equals("") ? "ninguna por ahora" : s;
}

// ---------------------------------------------------------------- resumen

// Lo que Valeria sabe de la mision en este momento
String resumenMision(boolean conPlan) {
  Jugador j = jugadores.get(0);
  StringBuilder s = new StringBuilder();
  s.append("- Hora: ").append(horaTexto()).append("; jugadores: ").append(jugadores.size()).append(".\n");
  s.append("- El candidato está en: ").append(NOMBRES_ZONA[mapa.zonaEn(j.x, j.y)]).append(". Postura: ").append(j.postura())
    .append(j.escondido ? " (escondido)" : "").append(j.enDucto ? " (dentro de un ducto)" : "").append(".\n");
  s.append("- Alarma: nivel ").append(nivelAlarma).append(" de 3 (").append(NOMBRES_ALARMA[nivelAlarma]).append(")");
  if (nivelAlarma == 3) s.append(", la policía llega en ").append(ceil(max(0, tiempoPolicia))).append(" s");
  s.append(".\n");
  s.append("- Vigilantes: ").append(resumenVigilantes(j)).append(".\n");
  String t = "";
  String[] nt = {"", "roja", "azul", "amarilla"};
  for (int k = 1; k <= 3; k++) t += (tarjetas[k] ? "tiene la " : "le falta la ") + nt[k] + (k < 3 ? ", " : "");
  s.append("- Tarjetas: ").append(t).append(". La roja abre la puerta de carga, la azul el cuarto de seguridad y la amarilla la oficina del rival.\n");
  s.append("- Código del servidor que conoce: ").append(codigoConocido()).append(" (\"_\" es lo que falta).\n");
  s.append("- Botín: ").append(botinLlevado()).append(" puntos (lo mejor que cabe: ").append(mejorBotin).append("), mochila ").append(j.peso).append(" de ").append(CAPACIDAD_MOCHILA).append(" kg. Oportunidades hechas: ")
    .append(oportunidadesHechas()).append(" de 3.\n");
  s.append("- Servidor copiado: ").append(servidorCopiado ? "sí, ahora solo hay que escapar" : "no (es lo último que se hace)").append(".\n");
  String pistas = "";
  if (pistaAmarilla && !tarjetas[3]) pistas += "la tarjeta amarilla está en el descanso, junto a la cafetera. ";
  if (pistaRoja && !tarjetas[1]) pistas += "la tarjeta roja está en la caseta del parqueadero. ";
  if (digitoConocido[2] && !digitoConocido[0]) pistas += "los dos primeros dígitos están anotados en el archivo. ";
  if (!pistas.equals("")) s.append("- Pistas escuchadas: ").append(pistas).append("\n");
  if (conPlan) s.append("- Siguiente paso: ").append(siguientePaso()).append("\n");
  return s.toString();
}

String resumenVigilantes(Jugador j) {
  int patrulla = 0, dudan = 0, alerta = 0, ko = 0;
  float cerca = 999;
  for (Vigilante v : vigilantes) {
    if (v.inconsciente) {
      ko++;
      continue;
    }
    if (v.estado == V_ALERTA) alerta++;
    else if (v.estado == V_PATRULLA) patrulla++;
    else dudan++;
    cerca = min(cerca, dist(v.x, v.y, j.x, j.y));
  }
  String s = patrulla + " en su ronda, " + dudan + " sospechando o buscando, " + alerta + " persiguiéndolo";
  if (ko > 0) s += ", " + ko + " noqueados";
  if (cerca < 999) s += "; el más cercano está a " + round(cerca) + " pasos";
  return s;
}

String siguientePaso() {
  if (soloEscapar()) return "escapar por " + salidasQueSirven() + ".";
  if (nivelAlarma == 3) return "salir cuanto antes, la policía viene.";
  String falta = "";
  if (botinLlevado() < mejorBotin) falta += "elegir bien el botín (lo que más vale por kilo es el disco duro), ";
  if (!tarjetas[3]) falta += pistaAmarilla ? "ir por la tarjeta amarilla al descanso, " : "conseguir la tarjeta amarilla (escuchar conversaciones ayuda), ";
  else if (!chatLeido) falta += "leer el chat del rival en su oficina, ";
  if (digitosConocidos() < 4) falta += "completar el código del servidor, ";
  if (falta.equals("")) return "ir al cuarto del servidor, marcar el código y copiarlo.";
  return falta + "y al final copiar el servidor.";
}

// ---------------------------------------------------------------- respaldo

HashMap<String, String[]> respaldo = new HashMap<String, String[]>();

void prepararRespaldo() {
  respaldo.put("inicio", new String[] {"Ya estás adentro. Respira y muévete despacio.", "Bien, entraste. Ojo con las cámaras."});
  respaldo.put("sospecha", new String[] {"Alguien notó algo. Agáchate y no te muevas.", "Ese vigilante está dudando. Quédate quieto."});
  respaldo.put("persecucion", new String[] {"¡Te vieron! Corre y busca dónde esconderte.", "¡Te están siguiendo! Rompe la línea de vista."});
  respaldo.put("escapo", new String[] {"Te perdieron. Buen trabajo, sigue con calma.", "Listo, ya no te buscan. Despacio otra vez."});
  respaldo.put("alarma", new String[] {"La alarma subió. Van a estar más atentos.", "Subió la alarma. Cuidado, ahora miran más."});
  respaldo.put("atrapado", new String[] {"¡Te atraparon! Aguanta.", "No, no, no... te tienen."});
  respaldo.put("servidor", new String[] {"¡Lo tienes! Ahora sal de ahí.", "Servidor copiado. Busca una salida, ya."});
  respaldo.put("tarjeta", new String[] {"Esa tarjeta abre un cuarto nuevo. Búscalo en el mapa con la G.", "Bien, otra puerta abierta. Mira el mapa con la G."});
  respaldo.put("codigo", new String[] {"Anota esos números, los vamos a necesitar.", "Ya sabemos más del código."});
  respaldo.put("pista", new String[] {"¿Oíste eso? Revisa el mapa con la G.", "Esa conversación nos sirve. Mira el mapa."});
  respaldo.put("disfraz", new String[] {"Con ese uniforme pasas, pero no te acerques al jefe.", "Buen disfraz. Al jefe no lo engañas de cerca."});
  respaldo.put("noqueo", new String[] {"Escóndelo antes de que alguien lo vea.", "Uno menos. Ahora esconde el cuerpo."});
  respaldo.put("botin", new String[] {"Eso nos sirve. Cuida el peso de la mochila.", "Bien, eso va para las pruebas."});
  respaldo.put("oportunidad", new String[] {"Eso también nos ayuda.", "Buena esa."});
  respaldo.put("consejo", new String[] {"Revisa el mapa con la G si estás perdido.", "No te quedes ahí mucho tiempo."});
  respaldo.put("final", new String[] {"Bueno, ya pasó. Hablamos en la mañana.", "Gracias por arriesgarte, candidato."});
}

// Graba de una vez (en otro hilo) las frases fijas que aún no están en
// data/voz/, para que después suenen aunque no haya internet. Solo se piden
// las que faltan, así que después de la primera vez no gasta nada.
void precargarVoces(String[] extra) {
  if (!valeriaConVoz()) return;
  final StringList frases = new StringList();
  for (String[] op : respaldo.values()) for (String f : op) frases.append(f);
  frases.append("En ese casillero hay uniformes de conserje. Póntelo con E: así casi nadie te reconoce.");
  if (extra != null) for (String f : extra) frases.append(f);
  Thread h = new Thread(new Runnable() {
    public void run() {
      int nuevas = 0;
      for (String f : frases) {
        if (!hayRed()) return;
        java.io.File g = new java.io.File(dataPath("voz/" + vozAzure + "_" + Integer.toHexString(f.hashCode()) + ".wav"));
        if (g.exists()) continue;
        try {
          vozDeAzure(f).close();
          nuevas++;
        } catch (Exception e) {
          marcarSinRed(e);
        }
      }
      if (nuevas > 0) println("Valeria: " + nuevas + " voces nuevas guardadas en data/voz/");
    }
  });
  h.setDaemon(true);
  h.start();
}

String fraseDeRespaldo(String tipo) {
  String[] op = respaldo.get(tipo);
  if (op == null) return null;
  // la que no se haya dicho hace poco
  for (int intento = 0; intento < 4; intento++) {
    String f = op[int(random(op.length))];
    if (!dichas.hasValue(f)) return f;
  }
  return op[0];
}

// ---------------------------------------------------------------- cuadro

void actualizarValeria(float dt) {
  if (!valeriaActiva || estado == LLAMADA) return;
  detectarEventosValeria(dt);
  float ahora = millis() / 1000.0;

  // la mision termino (ganaste o perdiste): Valeria ya no habla
  if (estado == GANASTE || estado == PERDISTE) {
    if (!fraseValeria.equals("") || respuestaLista != null) callarValeria();
    return;
  }
  // llego una frase
  RespuestaValeria r = respuestaLista;
  if (r != null) {
    respuestaLista = null;
    esperandoValeria = false;
    // si llegó tarde y ya no viene al caso, no se dice
    if (r.ev == null || r.ev.fija != null || r.ev.edad() < r.ev.vida() + 4) decir(r);
  }

  if (!fraseValeria.equals("")) {
    if (!mapaAbierto) tiempoFrase += dt;
    if (tiempoFrase > duracionFrase + 1.6) {
      fraseValeria = "";
      finUltimaFrase = ahora;
      if (musica != null) musica.atenuar = 1;
    }
    return;
  }
  if (esperandoValeria || colaValeria.isEmpty()) return;
  EventoValeria ev = colaValeria.peek();
  float pausa = ev.prioridad >= 3 ? PAUSA_URGENTE : PAUSA_VALERIA;
  if (ahora - finUltimaFrase < pausa) return;
  colaValeria.poll();
  if (ev.edad() > ev.vida()) return;   // ya paso de moda
  pedirFraseValeria(ev);
}

void decir(RespuestaValeria r) {
  if (r.texto == null || r.texto.equals("")) return;
  if (vozActual != null) vozActual.stop();
  fraseValeria = r.texto;
  tiempoFrase = 0;
  vozActual = r.voz;
  duracionFrase = r.voz != null ? r.segundos : max(2.8, r.texto.length() / 15.0);
  sonar("auricular");
  if (vozActual != null) vozActual.start();
  if (musica != null) musica.atenuar = 0.4;
  dichas.append(r.texto);
  while (dichas.size() > 6) dichas.remove(0);
}

// Arma el pedido en el hilo del juego (lee el estado) y lo manda a otro hilo
void pedirFraseValeria(EventoValeria ev) {
  String respaldoTexto = ev.fija != null ? ev.fija : fraseDeRespaldo(ev.tipo);
  if (!valeriaConIA() && respaldoTexto == null) return;   // sin IA, el aviso generico no se comenta
  String usuario = null;
  if (valeriaConIA()) {
    StringBuilder s = new StringBuilder();
    s.append("ACABA DE PASAR: ").append(ev.detalle).append("\n\n");
    s.append("ESTADO DE LA MISIÓN:\n").append(estado == JUGANDO || estado == RECONOCIMIENTO ? resumenMision(ev.tipo.equals("consejo") || ev.tipo.equals("inicio")) : "- La misión terminó.\n");
    if (dichas.size() > 0) {
      s.append("\nLO ÚLTIMO QUE DIJISTE (no lo repitas):\n");
      for (String d : dichas) s.append("- ").append(d).append("\n");
    }
    s.append("\nResponde solo con lo que Valeria dice ahora por el auricular.");
    usuario = s.toString();
  }
  esperandoValeria = true;
  Thread h = new Thread(new PedidoValeria(ev, usuario, respaldoTexto));
  h.setDaemon(true);
  h.start();
}

class PedidoValeria implements Runnable {
  EventoValeria ev;
  String usuario, respaldoTexto;

  PedidoValeria(EventoValeria ev, String usuario, String respaldoTexto) {
    this.ev = ev;
    this.usuario = usuario;
    this.respaldoTexto = respaldoTexto;
  }

  public void run() {
    RespuestaValeria r = new RespuestaValeria();
    r.ev = ev;
    long t0 = System.currentTimeMillis();
    if (usuario != null) {
      try {
        r.texto = limpiarFrase(pedirAlModelo(PERSONA_VALERIA, usuario, 90));
        r.conIA = true;
        fallosSeguidos = 0;
      } catch (Exception e) {
        fallosSeguidos++;
        marcarSinRed(e);
        println("Valeria (" + proveedorIA + "): " + e.getMessage());
      }
    }
    if (r.texto == null || r.texto.equals("")) r.texto = respaldoTexto;
    long t1 = System.currentTimeMillis();
    if (r.texto != null && valeriaConVoz()) {
      try {
        r.voz = vozDeAzure(r.texto);
        r.segundos = r.voz.getMicrosecondLength() / 1e6;
      } catch (Exception e) {
        r.voz = null;
        marcarSinRed(e);
        println("Valeria (Azure): " + e.getMessage());
      }
    }
    println("Valeria: texto " + (t1 - t0) + " ms, voz " + (System.currentTimeMillis() - t1) + " ms: " + r.texto);
    respuestaLista = r;
  }
}

// Quita comillas, "Valeria:" y saltos de linea que a veces pone el modelo
String limpiarFrase(String t) {
  if (t == null) return null;
  t = trim(t.replace('\n', ' ').replace("*", "").replace("\"", "").replace("“", "").replace("”", ""));
  if (t.toLowerCase().startsWith("valeria:")) t = trim(t.substring(8));
  if (t.length() > 220) t = t.substring(0, 220);
  return t;
}

// ---------------------------------------------------------------- internet

byte[] enviarPost(String direccion, String[][] cabeceras, byte[] cuerpo, int espera) throws Exception {
  java.net.HttpURLConnection c = (java.net.HttpURLConnection) new java.net.URL(direccion).openConnection();
  c.setRequestMethod("POST");
  c.setDoOutput(true);
  c.setConnectTimeout(2500);
  c.setReadTimeout(espera);
  for (String[] h : cabeceras) c.setRequestProperty(h[0], h[1]);
  OutputStream o = c.getOutputStream();
  o.write(cuerpo);
  o.close();
  int codigo = c.getResponseCode();
  InputStream in = codigo < 400 ? c.getInputStream() : c.getErrorStream();
  byte[] r = in == null ? new byte[0] : in.readAllBytes();
  if (in != null) in.close();
  if (codigo >= 400) throw new RuntimeException("HTTP " + codigo + " " + new String(r, "UTF-8"));
  return r;
}

String pedirAlModelo(String sistema, String usuario, int maxTokens) throws Exception {
  return proveedorIA.equals("claude") ? pedirAClaude(sistema, usuario, maxTokens) : pedirAGroq(sistema, usuario, maxTokens);
}

// Groq usa el mismo formato de OpenAI. gpt-oss primero "piensa" y eso tambien
// gasta tokens, por eso se le pide poco razonamiento y se le da margen.
String pedirAGroq(String sistema, String usuario, int maxTokens) throws Exception {
  JSONObject cuerpo = new JSONObject();
  cuerpo.setString("model", modeloGroq);
  cuerpo.setInt("max_tokens", maxTokens + 400);
  if (modeloGroq.startsWith("openai/gpt-oss")) cuerpo.setString("reasoning_effort", "low");
  JSONArray mensajes = new JSONArray();
  JSONObject s = new JSONObject();
  s.setString("role", "system");
  s.setString("content", sistema);
  mensajes.append(s);
  JSONObject m = new JSONObject();
  m.setString("role", "user");
  m.setString("content", usuario);
  mensajes.append(m);
  cuerpo.setJSONArray("messages", mensajes);
  String[][] cab = {{"Authorization", "Bearer " + claveGroq}, {"Content-Type", "application/json"}};
  byte[] r = enviarPost("https://api.groq.com/openai/v1/chat/completions", cab, cuerpo.toString().getBytes("UTF-8"), 5000);
  JSONObject res = parseJSONObject(new String(r, "UTF-8"));
  return res.getJSONArray("choices").getJSONObject(0).getJSONObject("message").getString("content", "");
}

String pedirAClaude(String sistema, String usuario, int maxTokens) throws Exception {
  JSONObject cuerpo = new JSONObject();
  cuerpo.setString("model", modeloClaude);
  cuerpo.setInt("max_tokens", maxTokens);
  cuerpo.setString("system", sistema);
  JSONArray mensajes = new JSONArray();
  JSONObject m = new JSONObject();
  m.setString("role", "user");
  m.setString("content", usuario);
  mensajes.append(m);
  cuerpo.setJSONArray("messages", mensajes);
  String[][] cab = {{"x-api-key", claveClaude}, {"anthropic-version", "2023-06-01"}, {"content-type", "application/json"}};
  byte[] r = enviarPost("https://api.anthropic.com/v1/messages", cab, cuerpo.toString().getBytes("UTF-8"), 5000);
  JSONObject res = parseJSONObject(new String(r, "UTF-8"));
  JSONArray contenido = res.getJSONArray("content");
  String texto = "";
  for (int k = 0; k < contenido.size(); k++) {
    JSONObject b = contenido.getJSONObject(k);
    if (b.getString("type", "").equals("text")) texto += b.getString("text");
  }
  return texto;
}

String escaparXml(String t) {
  return t.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("'", "&apos;").replace("\"", "&quot;");
}

// Texto -> voz con Azure. Llega un WAV de 24 kHz; se le pasa el filtro de
// radio y queda listo en un Clip para sonar.
Clip vozDeAzure(String texto) throws Exception {
  return vozDeAzure(texto, vozAzure);
}

// La misma, con otra voz (la periodista usa vozPeriodista)
Clip vozDeAzure(String texto, String voz) throws Exception {
  String ssml = "<speak version='1.0' xml:lang='es-CO'><voice name='" + voz + "'>" +
    "<prosody rate='+25%'>" + escaparXml(texto) + "</prosody></voice></speak>";
  String[][] cab = {{"Ocp-Apim-Subscription-Key", claveAzure}, {"Content-Type", "application/ssml+xml"},
    {"X-Microsoft-OutputFormat", "riff-24khz-16bit-mono-pcm"}, {"User-Agent", "InfiltradoPrueba"}};
  // si esta frase ya se dijo antes, se usa la grabacion guardada
  java.io.File guardada = new java.io.File(dataPath("voz/" + voz + "_" + Integer.toHexString(texto.hashCode()) + ".wav"));
  byte[] wav;
  if (guardada.exists()) {
    wav = java.nio.file.Files.readAllBytes(guardada.toPath());
  } else {
    if (!hayRed()) throw new RuntimeException("sin internet: la frase sale solo en texto");
    wav = enviarPost("https://" + regionAzure + ".tts.speech.microsoft.com/cognitiveservices/v1", cab, ssml.getBytes("UTF-8"), 4000);
    try {
      guardada.getParentFile().mkdirs();
      java.nio.file.Files.write(guardada.toPath(), wav);
    } catch (Exception e) {
      println("Valeria: no se pudo guardar la voz: " + e.getMessage());
    }
  }
  AudioInputStream ais = AudioSystem.getAudioInputStream(new java.io.ByteArrayInputStream(wav));
  AudioFormat fmt = ais.getFormat();
  byte[] b = ais.readAllBytes();
  ais.close();
  if (efectoRadio) filtroRadio(b, fmt.getSampleRate());
  Clip c = AudioSystem.getClip();
  c.open(fmt, b, 0, b.length);
  return c;
}

// Filtro de radio: quita graves y agudos (queda la banda del telefono) y
// satura un poquito. Muestras de 16 bits little endian, mono.
void filtroRadio(byte[] b, float frecuencia) {
  int n = b.length / 2;
  float aBajo = exp(-TWO_PI * 300 / frecuencia);    // pasa altos en 300 Hz
  float aAlto = exp(-TWO_PI * 3400 / frecuencia);   // pasa bajos en 3400 Hz
  float prevX = 0, hp = 0, lp1 = 0, lp2 = 0;
  for (int i = 0; i < n; i++) {
    float x = (short) ((b[2 * i + 1] << 8) | (b[2 * i] & 0xff)) / 32768.0;
    hp = aBajo * (hp + x - prevX);
    prevX = x;
    lp1 = (1 - aAlto) * hp + aAlto * lp1;
    lp2 = (1 - aAlto) * lp1 + aAlto * lp2;
    float y = (float) Math.tanh(lp2 * 1.8) * 0.85;
    int v = (int) constrain(y * 32767, -32768, 32767);
    b[2 * i] = (byte) (v & 0xff);
    b[2 * i + 1] = (byte) ((v >> 8) & 0xff);
  }
}

// ---------------------------------------------------------------- dibujo

// Recuadro de Valeria encima de las tarjetas de los jugadores
void dibujarValeria() {
  if (!valeriaActiva || mapaAbierto) return;
  if (estado != JUGANDO && estado != GANASTE && estado != PERDISTE) return;
  boolean hablando = !fraseValeria.equals("");
  if (!hablando && !esperandoValeria) return;
  PGraphics g = capaValeria;
  g.beginDraw();
  g.clear();
  g.textAlign(LEFT, TOP);
  marcoPixel(g, 0, 0, g.width - 1, g.height - 1, COLOR_VALERIA);
  g.noStroke();
  g.fill(40, 30, 64);
  g.rect(6, 6, 24, 24);
  g.image(caraValeria, 8, 8);
  textoPixel(g, "VALERIA", 36, 4, COLOR_VALERIA, pixel10);
  if (hablando) {
    int letras = fraseValeria.length();
    if (vozActual != null) letras = ceil(letras * constrain(tiempoFrase / max(0.1, duracionFrase * 0.9), 0, 1));
    else letras = min(letras, ceil(tiempoFrase * 32));
    g.textFont(pixel8);
    g.fill(242, 242, 233);
    g.text(fraseValeria.substring(0, letras), 36, 17, g.width - 44, g.height - 20);
  } else {
    // esperando la frase: puntos que se mueven (tapa la demora de internet)
    int p = (millis() / 250) % 4;
    textoPixel(g, "· · ·".substring(0, min(5, p * 2)), 36, 20, color(160, 168, 190), pixel10);
  }
  g.endDraw();
  int x = (width / pixel - g.width) / 2;
  int y = height / pixel - 62 - g.height - 6;
  if (estado == GANASTE || estado == PERDISTE) y = height / pixel - g.height - 10;
  image(g, x * pixel, y * pixel, g.width * pixel, g.height * pixel);
}


// ======================================================================
// Vigilante.pde
// ======================================================================
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

}
