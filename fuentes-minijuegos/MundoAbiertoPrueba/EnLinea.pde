// Los eventos del parque en línea (multijugador en red).
//
// El anfitrión (el PC que creó la partida) simula todo: los bots, la gente,
// los carros, las botellas y de quién es cada punto. Cada invitado manda sus
// teclas y el anfitrión le devuelve, unas 15 veces por segundo, una "foto"
// del estado (estadoRed). El invitado no simula: copia esa foto y mueve las
// cosas suavemente hacia donde dice. Los efectos (papelitos, chispas, vidrios
// y textos que suben) y los avisos también se mandan, para que cada uno los
// vea en su pantalla.
//
// Los asientos van de 0 a 3. El 0 es el anfitrión; los que no tienen persona
// los juega el computador. En la prueba (sin red) todo esto queda apagado.
//
// Quien manda y recibe los mensajes es el juego principal (Red.pde); aquí
// solo se arma y se lee el texto.

final int SOLO = 0, ANFITRION = 1, INVITADO = 2;
int modoRed = SOLO;
int miAsiento = 0;
boolean[] asientoHumano = new boolean[4];
String[] nombresAsiento = new String[4];
boolean fotoRecibida = false;     // el invitado ya recibió la primera foto
int momentoFoto = 0;              // cuándo llegó la última
int[] ultimaEntrada = new int[4]; // cuándo mandó teclas cada invitado (para saber quién está en el parque)
float esperaReunion = 0;          // cuánto lleva el anfitrión esperando en la plaza

// Teclas de cada asiento: arriba, abajo, izquierda, derecha, correr, pegar
final int T_ARRIBA = 0, T_ABAJO = 1, T_IZQ = 2, T_DER = 3, T_CORRER = 4, T_PEGAR = 5;
boolean[][] teclasAsiento = new boolean[4][6];
int ultimaMascara = -1;
int momentoMascara = 0;

// El juego principal empieza un evento en red con esto
void configurarEventoRed(int tipo, int modo, int asiento, boolean[] humanos, String[] nombres) {
  modoRed = modo;
  miAsiento = asiento;
  for (int k = 0; k < 4; k++) {
    asientoHumano[k] = humanos[k];
    nombresAsiento[k] = nombres[k];
    for (int t = 0; t < 6; t++) teclasAsiento[k][t] = false;
  }
  fotoRecibida = false;
  esperaReunion = 0;
  for (int k = 0; k < 4; k++) ultimaEntrada[k] = -100000;
  crearCandidatos();
  configurarEvento(tipo);
}

String nombreVisible(Candidato c) {
  return c == yo ? "Tú" : c.nombre;
}

boolean[] teclasDe(Candidato c) {
  if (c == yo) {
    return new boolean[] {tArriba, tAbajo, tIzquierda, tDerecha, tCorrer, tPegar};
  }
  return teclasAsiento[c.id];
}

int mascaraLocal() {
  boolean[] t = teclasDe(yo);
  int m = 0;
  for (int k = 0; k < 6; k++) if (t[k]) m |= 1 << k;
  return m;
}

// El anfitrión recibe las teclas de un invitado
void entradaRemota(int asiento, int mascara) {
  if (asiento < 0 || asiento > 3) return;
  ultimaEntrada[asiento] = millis();
  for (int k = 0; k < 6; k++) teclasAsiento[asiento][k] = (mascara & (1 << k)) != 0;
}

// ... y sus acciones de un toque: e, f, q o una flecha (0 a 3)
void accionRemota(int asiento, char a) {
  if (asiento < 0 || asiento >= candidatos.size()) return;
  Candidato c = candidatos.get(asiento);
  if (a == 'e') accionRapida(c);
  else if (a == 'f') accionAsegurar(c);
  else if (a == 'q' && rondaActiva()) lanzarDe(c);
  else if (a >= '0' && a <= '3' && enSecuencia(c)) marcarFlecha(c, a - '0');
}

// El invitado manda sus teclas cuando cambian (y cada cuarto de segundo)
void mandarTeclas() {
  int m = mascaraLocal();
  if (m != ultimaMascara || millis() - momentoMascara > 250) {
    enviarTeclasRed(m);
    ultimaMascara = m;
    momentoMascara = millis();
  }
}

// ---------------------------------------------------------------------------
// Avisos y efectos: se ven aquí y, si es el anfitrión, se mandan
// ---------------------------------------------------------------------------

void avisarA(Candidato c, String s) {
  if (c == null || c.bot != null) return;
  if (c == yo) avisar(s);
  else if (modoRed == ANFITRION) avisoRed(c.id, s);
}

void avisarTodos(String s) {
  avisar(s);
  if (modoRed == ANFITRION) avisoRed(-1, s);
}

void efectoPapel(float x, float y, color col) {
  float sx = pantallaX(x, y), sy = pantallaY(x, y) - 16;
  for (int k = 0; k < 14; k++) {
    particulas.add(new Particula(sx, sy, random(-40, 40), random(-70, -20), random(0.5, 0.9), k % 3 == 0 ? color(250, 246, 236) : col, 2));
  }
  sonarEn("volante", x, y);
  if (modoRed == ANFITRION) fxRed("papel " + x + " " + y + " " + col);
}

void efectoChispas(float x, float y, color col) {
  float sx = pantallaX(x, y), sy = pantallaY(x, y) - 20;
  for (int k = 0; k < 12; k++) {
    particulas.add(new Particula(sx, sy, random(-40, 40), random(-70, -20), random(0.5, 0.9),
      k % 3 == 0 ? color(250, 246, 236) : col, 2));
  }
  if (millis() - momentoAsegurado > 100) sonarEn("convencer", x, y);
  if (modoRed == ANFITRION) fxRed("chispas " + x + " " + y + " " + col);
}

void efectoVidrio(float x, float y) {
  float sx = pantallaX(x, y), sy = pantallaY(x, y) - 10;
  for (int k = 0; k < 10; k++) {
    particulas.add(new Particula(sx, sy, random(-50, 50), random(-60, -10), random(0.3, 0.6),
      k % 2 == 0 ? color(90, 170, 110) : color(200, 236, 210), 1.5));
  }
  sonarEn("vidrio", x, y);
  if (modoRed == ANFITRION) fxRed("vidrio " + x + " " + y);
}

int momentoAsegurado = -1000;

void efectoTexto(float x, float y, String texto, color col) {
  textosFlotantes.add(new TextoFlotante(x, y, texto, col));
  if (texto.equals("¡PUM!")) sonarEn("golpe", x, y);
  if (texto.equals("¡Asegurado!")) {
    sonarEn("asegurado", x, y);
    momentoAsegurado = millis();
  }
  if (modoRed == ANFITRION) fxRed("texto " + x + " " + y + " " + col + " " + texto.replace(' ', '_'));
}

// El invitado repite el efecto que le mandó el anfitrión
void aplicarFx(String linea) {
  String[] p = splitTokens(linea);
  if (p.length < 3) return;
  int antes = modoRed;
  modoRed = SOLO;   // para que no lo vuelva a mandar
  float x = float(p[1]), y = float(p[2]);
  if (p[0].equals("papel") && p.length >= 4) efectoPapel(x, y, int(p[3]));
  else if (p[0].equals("chispas") && p.length >= 4) efectoChispas(x, y, int(p[3]));
  else if (p[0].equals("vidrio")) efectoVidrio(x, y);
  else if (p[0].equals("texto") && p.length >= 5) efectoTexto(x, y, p[4].replace('_', ' '), int(p[3]));
  modoRed = antes;
}

// ---------------------------------------------------------------------------
// La foto del estado (anfitrión -> invitados)
// ---------------------------------------------------------------------------

String f2(float v) {
  return nf(v, 0, 2).replace(',', '.');
}

String estadoRed() {
  StringBuilder s = new StringBuilder();
  s.append(estadoRonda).append(' ').append(f2(relojRonda)).append(' ').append(evento).append('|');
  for (Candidato c : candidatos) {
    s.append(f2(c.x)).append(' ').append(f2(c.y)).append(' ').append(f2(c.dirX)).append(' ').append(f2(c.dirY)).append(' ')
      .append(c.moviendose ? 1 : 0).append(' ').append(c.corriendo ? 1 : 0).append(' ').append(f2(c.aturdido)).append(' ')
      .append(f2(c.progresoPegar)).append(' ').append(c.botellas).append(' ').append(c.ultimoLogro).append(';');
  }
  s.append('|');
  for (Ciudadano z : ciudadanos) {
    s.append(f2(z.x)).append(' ').append(f2(z.y)).append(' ').append(f2(z.dirX)).append(' ').append(f2(z.dirY)).append(' ')
      .append(z.moviendose ? 1 : 0).append(' ').append(z.dueno).append(' ').append(z.asegurado ? 1 : 0).append(' ').append(z.ocupadoPor).append(' ')
      .append(z.live ? 1 : (z.quieto ? 2 : 0)).append(';');
  }
  s.append('|');
  for (Carro c : carros) {
    s.append(f2(c.x)).append(' ').append(f2(c.y)).append(' ').append(f2(c.ang)).append(' ').append(c.variante).append(';');
  }
  s.append('|');
  for (Punto p : puntos) s.append(dueno(p.id)).append(' ');
  s.append('|');
  for (Botella b : botellasVolando) {
    s.append(f2(b.x)).append(' ').append(f2(b.y)).append(' ').append(f2(b.recorrido)).append(';');
  }
  s.append('|');
  for (Candidato c : candidatos) {
    java.util.ArrayDeque<Integer> cola = secuencias.get(c.id);
    Ciudadano z = secuenciaCon.get(c.id);
    if (cola == null || z == null) continue;
    s.append(c.id).append(' ').append(z.id).append(' ');
    for (int f : cola) s.append(f);
    s.append(';');
  }
  return s.toString();
}

// El invitado copia la foto. Las posiciones no saltan: se guardan como
// destino y cada cuadro se acercan (seguirFoto).
float[][] destinoCand = new float[4][2];
float[][] destinoCiud;

void aplicarEstado(String foto) {
  String[] partes = split(foto, '|');
  if (partes.length < 7) return;
  String[] g = splitTokens(partes[0]);
  int nuevoEstado = int(g[0]);
  relojRonda = float(g[1]);
  evento = int(g[2]);
  // candidatos
  String[] cs = splitTokens(partes[1], ";");
  for (int k = 0; k < cs.length && k < candidatos.size(); k++) {
    String[] v = splitTokens(cs[k]);
    if (v.length < 10) continue;
    Candidato c = candidatos.get(k);
    destinoCand[k][0] = float(v[0]);
    destinoCand[k][1] = float(v[1]);
    if (!fotoRecibida || dist(c.x, c.y, destinoCand[k][0], destinoCand[k][1]) > 3) {
      c.x = destinoCand[k][0];
      c.y = destinoCand[k][1];
    }
    c.dirX = float(v[2]);
    c.dirY = float(v[3]);
    c.moviendose = v[4].equals("1");
    c.corriendo = v[5].equals("1");
    c.aturdido = float(v[6]);
    c.progresoPegar = float(v[7]);
    c.botellas = int(v[8]);
    c.ultimoLogro = int(v[9]);
  }
  // gente
  String[] zs = splitTokens(partes[2], ";");
  // la lista del anfitrión manda (en la ronda de los lives cambia de tamaño)
  while (ciudadanos.size() > zs.length) ciudadanos.remove(ciudadanos.size() - 1);
  while (ciudadanos.size() < zs.length) {
    String[] v = splitTokens(zs[ciudadanos.size()]);
    ciudadanos.add(new Ciudadano(ciudadanos.size(), float(v[0]), float(v[1])));
  }
  if (destinoCiud == null || destinoCiud.length != ciudadanos.size()) destinoCiud = new float[ciudadanos.size()][2];
  for (int k = 0; k < zs.length && k < ciudadanos.size(); k++) {
    String[] v = splitTokens(zs[k]);
    if (v.length < 8) continue;
    Ciudadano z = ciudadanos.get(k);
    destinoCiud[k][0] = float(v[0]);
    destinoCiud[k][1] = float(v[1]);
    if (!fotoRecibida || dist(z.x, z.y, destinoCiud[k][0], destinoCiud[k][1]) > 3) {
      z.x = destinoCiud[k][0];
      z.y = destinoCiud[k][1];
    }
    z.dirX = float(v[2]);
    z.dirY = float(v[3]);
    z.moviendose = v[4].equals("1");
    z.dueno = int(v[5]);
    z.asegurado = v[6].equals("1");
    z.ocupadoPor = int(v[7]);
    if (v.length > 8) {
      z.live = v[8].equals("1");
      z.quieto = !v[8].equals("0");
    }
  }
  // carros (la lista del anfitrión manda)
  String[] ks = splitTokens(partes[3], ";");
  while (carros.size() > ks.length) carros.remove(carros.size() - 1);
  for (int k = 0; k < ks.length; k++) {
    String[] v = splitTokens(ks[k]);
    if (v.length < 4) continue;
    if (k >= carros.size()) carros.add(new Carro(float(v[0]), float(v[1]), float(v[2]), int(v[3])));
    Carro c = carros.get(k);
    c.ia = false;
    c.x = float(v[0]);
    c.y = float(v[1]);
    c.ang = float(v[2]);
    c.variante = int(v[3]);
  }
  // puntos
  String[] ps = splitTokens(partes[4]);
  duenoDePunto.clear();
  for (int k = 0; k < ps.length && k < puntos.size(); k++) {
    int d = int(ps[k]);
    if (d >= 0) duenoDePunto.put(k, d);
  }
  // botellas
  botellasVolando.clear();
  for (String b : splitTokens(partes[5], ";")) {
    String[] v = splitTokens(b);
    if (v.length < 3) continue;
    Botella bt = new Botella(yo, 1, 0);
    bt.x = float(v[0]);
    bt.y = float(v[1]);
    bt.recorrido = float(v[2]);
    botellasVolando.add(bt);
  }
  // secuencias de flechas
  secuencias.clear();
  secuenciaCon.clear();
  for (String q : splitTokens(partes[6], ";")) {
    String[] v = splitTokens(q);
    if (v.length < 3) continue;
    int id = int(v[0]), z = int(v[1]);
    java.util.ArrayDeque<Integer> cola = new java.util.ArrayDeque<Integer>();
    for (char f : v[2].toCharArray()) cola.add(f - '0');
    secuencias.put(id, cola);
    if (z >= 0 && z < ciudadanos.size()) secuenciaCon.put(id, ciudadanos.get(z));
  }
  // cambios de momento
  if (nuevoEstado != estadoRonda) {
    if (nuevoEstado == RONDA) arenaCerrada = true;
    if (nuevoEstado == FINAL) {
      arenaCerrada = false;
      resultado = listaOrdenada();
    }
    estadoRonda = nuevoEstado;
  }
  fotoRecibida = true;
  momentoFoto = millis();
}

// El invitado sin fotos (el anfitrión no ha llegado o se fue) puede volver
boolean sinFotos() {
  return modoRed == INVITADO && estadoRonda != FINAL && (!fotoRecibida || millis() - momentoFoto > 4000);
}

// Para empezar no se espera a quien todavía no ha entrado al parque
// (un invitado que sigue en su oficina): ese entra cuando llegue.
boolean estaEnElParque(Candidato c) {
  return c.bot != null || c == yo || millis() - ultimaEntrada[c.id] < 3000;
}

int faltanEnLaPlaza() {
  int n = 0;
  for (Candidato c : candidatos) if (!enLaPlaza(c) && estaEnElParque(c)) n++;
  return n;
}

// Cada cuadro, el invitado acerca todo a la última foto
void seguirFoto(float dt) {
  float f = min(1, dt * 12);
  for (int k = 0; k < candidatos.size(); k++) {
    Candidato c = candidatos.get(k);
    c.x += (destinoCand[k][0] - c.x) * f;
    c.y += (destinoCand[k][1] - c.y) * f;
  }
  if (destinoCiud != null) {
    for (int k = 0; k < ciudadanos.size() && k < destinoCiud.length; k++) {
      Ciudadano z = ciudadanos.get(k);
      z.x += (destinoCiud[k][0] - z.x) * f;
      z.y += (destinoCiud[k][1] - z.y) * f;
    }
  }
  for (int k = particulas.size() - 1; k >= 0; k--) {
    if (!particulas.get(k).actualizar(dt)) particulas.remove(k);
  }
  for (int k = textosFlotantes.size() - 1; k >= 0; k--) {
    if (!textosFlotantes.get(k).actualizar(dt)) textosFlotantes.remove(k);
  }
}

// En la prueba no hay red: estas funciones las pone el juego principal (Red.pde).
// <solo-sketch>
void enviarTeclasRed(int mascara) {
}
void enviarAccionRed(char a) {
}
void avisoRed(int asiento, String texto) {
}
void fxRed(String linea) {
}
// </solo-sketch>
