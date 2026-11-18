import java.util.ArrayList;

// El grafo de la ciudad: los vertices son los ocho barrios de Ciudad Nova y
// las aristas son las calles que los unen. Se guarda como en el curso: una
// lista de vertices (aqui, arreglos con el nombre y la posicion de cada
// barrio) y una matriz de adyacencia con los minutos de camino de cada calle
// (0 significa que no hay calle). Es no dirigido: cada calle se recorre en
// los dos sentidos, por eso conectar() llena las dos casillas.
//
// Para que sirve en el juego:
// - El recorrido por niveles (BFS) decide a donde se puede publicar: los
//   barrios propios y los que estan a 1 calle (o a 2 con la habilidad
//   Perfil verificado), y a que barrios les llega el bono de Volantes y
//   Megafono (vecinos y vecinos de vecinos del barrio elegido).
// - Dijkstra da el camino mas corto por el que viaja la publicacion desde el
//   territorio del candidato hasta el barrio elegido (caminoMasCorto()).
public class GrafoCiudad {
    // Marca de "todavia no hay camino" en Dijkstra: un numero mas grande que
    // cualquier suma de minutos posible en esta ciudad.
    public static final int INFINITO = Integer.MAX_VALUE;
    // En la tabla de Dijkstra, el origen no tiene anterior.
    public static final int SIN_ANTERIOR = -1;

    private String[] nombres = {
        "Centro", "La Universidad", "La Colina", "El Puerto",
        "El Mercado", "Barrio Sur", "Parque Industrial", "Barrio Norte"
    };
    // Donde va cada barrio al dibujarlo, de 0 a 1 (0,0 es arriba a la izquierda).
    private float[] posX = {0.50f, 0.30f, 0.10f, 0.15f, 0.48f, 0.82f, 0.90f, 0.72f};
    private float[] posY = {0.47f, 0.22f, 0.35f, 0.75f, 0.82f, 0.78f, 0.45f, 0.15f};
    private int[][] matriz;

    // Arma Ciudad Nova: los ocho barrios y sus doce calles {barrio, barrio, minutos}.
    public GrafoCiudad() {
        matriz = new int[nombres.length][nombres.length];
        int[][] calles = {
            {0, 1, 4}, {0, 4, 3}, {0, 7, 5}, {0, 6, 6}, {0, 3, 5}, {1, 2, 3},
            {1, 7, 6}, {2, 3, 4}, {3, 4, 4}, {4, 5, 5}, {5, 6, 4}, {6, 7, 4}
        };
        for (int[] c : calles) {
            conectar(c[0], c[1], c[2]);
        }
    }

    public void conectar(int a, int b, int minutos) {
        matriz[a][b] = minutos;
        matriz[b][a] = minutos;
    }

    public int getMinutos(int a, int b) {
        return matriz[a][b];
    }

    public boolean hayCalle(int a, int b) {
        return matriz[a][b] > 0;
    }

    public int cantidad() {
        return nombres.length;
    }

    public String getNombre(int zona) {
        return nombres[zona];
    }

    public float getX(int zona) {
        return posX[zona];
    }

    public float getY(int zona) {
        return posY[zona];
    }

    // Los vecinos de un barrio: recorrer su fila de la matriz y quedarse con
    // las casillas que tienen calle.
    public ArrayList<Integer> vecinos(int zona) {
        ArrayList<Integer> lista = new ArrayList<Integer>();
        for (int z = 0; z < cantidad(); z++) {
            if (hayCalle(zona, z)) {
                lista.add(z);
            }
        }
        return lista;
    }

    // --- BFS: recorrido por niveles ---
    // Arranca desde todos los barrios marcados en "origenes" a la vez (nivel
    // 0) y avanza por capas: primero los que estan a 1 calle, despues a 2, y
    // asi. Usa una cola (FIFO): se saca el primero, se miran sus vecinos y
    // los que no se habian visitado entran al final con un nivel mas. Un
    // barrio al que no se llega queda con nivel -1.
    public int[] niveles(boolean[] origenes) {
        int[] nivel = new int[cantidad()];
        ArrayList<Integer> cola = new ArrayList<Integer>();
        for (int z = 0; z < cantidad(); z++) {
            nivel[z] = -1;
            if (origenes[z]) {
                nivel[z] = 0;
                cola.add(z);
            }
        }
        while (!cola.isEmpty()) {
            int actual = cola.remove(0);
            for (int v : vecinos(actual)) {
                if (nivel[v] == -1) {
                    nivel[v] = nivel[actual] + 1;
                    cola.add(v);
                }
            }
        }
        return nivel;
    }

    // Los niveles contando desde un solo barrio.
    public int[] nivelesDesde(int zona) {
        boolean[] origen = new boolean[cantidad()];
        origen[zona] = true;
        return niveles(origen);
    }

    // A que barrios puede llegar una publicacion: los que estan a "calles"
    // calles o menos de algun barrio propio. Cuando se conquista un barrio,
    // los que lo rodean tambien quedan al alcance: la frontera crece con el
    // territorio.
    public boolean[] alcanzables(boolean[] propios, int calles) {
        int[] nivel = niveles(propios);
        boolean[] resultado = new boolean[cantidad()];
        for (int z = 0; z < cantidad(); z++) {
            resultado[z] = nivel[z] >= 0 && nivel[z] <= calles;
        }
        return resultado;
    }

    // --- Dijkstra ---
    // Igual que en clase, cada barrio tiene tres datos:
    //   final    -> si su distancia ya quedo fija (no va a mejorar)
    //   temporal -> la mejor distancia conocida hasta ahora (en minutos)
    //   anterior -> desde que barrio se llega con esa distancia
    // En cada paso se fija el barrio no fijo de menor temporal y se relajan
    // sus calles: si pasar por el acorta el camino a un vecino, se corrige el
    // temporal y el anterior de ese vecino. Al final, el camino se lee
    // siguiendo la columna "anterior" hacia atras.
    //
    // Llena los arreglos que recibe (deben medir cantidad()) para que quien
    // llama pueda leer la tabla completa, por ejemplo para imprimirla.
    public void dijkstra(int origen, boolean[] fijo, int[] temporal, int[] anterior) {
        for (int z = 0; z < cantidad(); z++) {
            fijo[z] = false;
            temporal[z] = INFINITO;
            anterior[z] = SIN_ANTERIOR;
        }
        temporal[origen] = 0;
        for (int paso = 0; paso < cantidad(); paso++) {
            int actual = menorTemporalSinFijar(fijo, temporal);
            if (actual == SIN_ANTERIOR) {
                return;  // los que quedan no tienen camino desde el origen
            }
            fijo[actual] = true;
            for (int v : vecinos(actual)) {
                int porAqui = temporal[actual] + matriz[actual][v];
                if (!fijo[v] && porAqui < temporal[v]) {
                    temporal[v] = porAqui;
                    anterior[v] = actual;
                }
            }
        }
    }

    private int menorTemporalSinFijar(boolean[] fijo, int[] temporal) {
        int mejor = SIN_ANTERIOR;
        for (int z = 0; z < cantidad(); z++) {
            if (!fijo[z] && temporal[z] != INFINITO && (mejor == SIN_ANTERIOR || temporal[z] < temporal[mejor])) {
                mejor = z;
            }
        }
        return mejor;
    }

    // Minutos del camino mas corto entre dos barrios.
    public int minutosMasCorto(int origen, int destino) {
        int[] temporal = new int[cantidad()];
        dijkstra(origen, new boolean[cantidad()], temporal, new int[cantidad()]);
        return temporal[destino];
    }

    // El camino mas corto como lista de barrios, del origen al destino. Se
    // arma leyendo "anterior" desde el destino hacia atras y se va
    // insertando al principio, para que quede en el orden del recorrido.
    public ArrayList<Integer> caminoMasCorto(int origen, int destino) {
        int[] anterior = new int[cantidad()];
        dijkstra(origen, new boolean[cantidad()], new int[cantidad()], anterior);
        ArrayList<Integer> camino = new ArrayList<Integer>();
        int z = destino;
        while (z != SIN_ANTERIOR) {
            camino.add(0, z);
            z = anterior[z];
        }
        return camino;
    }

    // De todos los barrios propios, el que esta a menos minutos del destino.
    // Desde ahi sale la publicacion: llega por el camino mas corto desde el
    // territorio del candidato, no siempre desde la sede.
    public int propioMasCercano(boolean[] propios, int destino) {
        int mejor = SIN_ANTERIOR;
        int mejorMinutos = INFINITO;
        for (int z = 0; z < cantidad(); z++) {
            if (propios[z]) {
                int minutos = minutosMasCorto(z, destino);
                if (minutos < mejorMinutos) {
                    mejor = z;
                    mejorMinutos = minutos;
                }
            }
        }
        return mejor;
    }
}
