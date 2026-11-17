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
