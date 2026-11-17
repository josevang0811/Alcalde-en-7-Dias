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
