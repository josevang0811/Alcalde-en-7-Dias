import processing.opengl.*;

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

void setup() {
  fullScreen(P2D);
  noSmooth();   // bordes duros y sin suavizar al agrandar el pixel art
  // En OpenGL hay que pedir aparte que las imagenes se agranden sin suavizar
  if (g instanceof PGraphicsOpenGL) ((PGraphicsOpenGL) g).textureSampling(2);
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
  // <solo-sketch>
  precargarVoces(null);   // en el juego principal la llama MisionCampana con las llamadas
  // </solo-sketch>
  ultimoMillis = millis();
}

void draw() {
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

void keyPressed() {
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

void keyReleased() {
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
