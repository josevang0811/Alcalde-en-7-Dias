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
