import java.util.ArrayList;
import java.util.ArrayDeque;
import java.util.Random;

// RedCivitas — la red social de la ciudad para el acto 2 (contener el bulo).
//
// Es un grafo DIRIGIDO guardado con listas de adyacencia: siguen[u] tiene a
// las cuentas que ven lo que publica u (sus seguidores). Un bulo viaja en la
// dirección de las flechas.
//
// El contagio avanza por niveles, como un BFS: en cada turno el bulo da un
// solo paso desde las cuentas que ya lo tienen (la "frontera", que se guarda
// en una cola) hacia sus seguidores. Quien lo compartió lo sigue regando en
// los turnos siguientes hasta que lo corrijan o lo reporten. Cada vez que una
// cuenta se contagia se anota de quién le llegó en padre[]: eso arma el árbol
// del BFS, y seguirlo hacia atrás (rastrear) lleva a quien lo publicó primero.
public class RedCivitas {

    // estados de una cuenta
    public static final int LIMPIA = 0;      // no lo ha visto o no se lo creyó
    public static final int CONTAGIADA = 1;  // lo compartió
    public static final int PROTEGIDA = 2;   // verificada: ya no se lo cree
    public static final int CORREGIDA = 3;   // lo había compartido y lo desmintió
    public static final int ELIMINADA = 4;   // cuenta reportada (bots, el origen)

    // tipos de cuenta
    public static final String PERSONA = "persona";
    public static final String GRUPO = "grupo";
    public static final String MEDIO = "medio";
    public static final String INFLUENCER = "influencer";
    public static final String BOT = "bot";

    public final ArrayList<String> nombres = new ArrayList<String>();
    public final ArrayList<String> tipos = new ArrayList<String>();
    public final ArrayList<Float> credulidad = new ArrayList<Float>();  // 0 = nunca se lo cree, 1 = siempre
    public final ArrayList<float[]> posiciones = new ArrayList<float[]>(); // x, y entre 0 y 1
    public final ArrayList<ArrayList<Integer>> siguen = new ArrayList<ArrayList<Integer>>();

    public int[] estado;
    public int[] padre;          // de quién le llegó el bulo (-1 = nadie)
    public int[] turnoContagio;  // en qué turno lo compartió
    public boolean[] rastreada;  // ya se sabe de quién le llegó
    public boolean[] esBotConocido; // se descubrió que es bot (pista del acto 1)
    public int origen = -1;
    public boolean origenDescubierto = false;
    public int turno = 0;
    public float contagio = 0.3f;   // qué tan fácil se lo cree alguien que lo ve (se multiplica por su credulidad)
    private Random azar;

    // Lo que pasó en el último turno, para dibujar los pulsos y el feed
    public final ArrayList<int[]> ultimosContagios = new ArrayList<int[]>(); // {de, a}

    public int agregarCuenta(String nombre, String tipo, float cred, float x, float y) {
        nombres.add(nombre);
        tipos.add(tipo);
        credulidad.add(cred);
        posiciones.add(new float[] {x, y});
        siguen.add(new ArrayList<Integer>());
        return nombres.size() - 1;
    }

    public int buscar(String nombre) {
        return nombres.indexOf(nombre);
    }

    // b sigue a a: lo que a publica le llega a b
    public void seguir(int b, int a) {
        if (a >= 0 && b >= 0 && a != b && !siguen.get(a).contains(b)) {
            siguen.get(a).add(b);
        }
    }

    public int total() {
        return nombres.size();
    }

    // Se llama cuando ya están todas las cuentas y conexiones.
    public void empezar(int cuentaOrigen, long semilla) {
        int n = total();
        estado = new int[n];
        padre = new int[n];
        turnoContagio = new int[n];
        rastreada = new boolean[n];
        esBotConocido = new boolean[n];
        for (int i = 0; i < n; i++) {
            padre[i] = -1;
            turnoContagio[i] = -1;
        }
        azar = new Random(semilla);
        origen = cuentaOrigen;
        estado[origen] = CONTAGIADA;
        turnoContagio[origen] = 0;
        turno = 0;
    }

    // Un turno del bulo: la frontera (las cuentas que lo tienen al empezar
    // el turno) lo muestra a sus seguidores, y se contagian los que se lo
    // crean. Los bots siempre lo comparten. Devuelve cuántas se contagiaron.
    public int avanzar() {
        ultimosContagios.clear();
        ArrayDeque<Integer> frontera = new ArrayDeque<Integer>();
        for (int i = 0; i < total(); i++) {
            if (estado[i] == CONTAGIADA) {
                frontera.add(i);
            }
        }
        turno++;
        int nuevos = 0;
        while (!frontera.isEmpty()) {
            int u = frontera.poll();
            for (int v : siguen.get(u)) {
                if (estado[v] != LIMPIA) {
                    continue;
                }
                float p = tipos.get(v).equals(BOT) ? 1f : credulidad.get(v) * contagio;
                if (azar.nextFloat() < p) {
                    estado[v] = CONTAGIADA;
                    padre[v] = u;
                    turnoContagio[v] = turno;
                    ultimosContagios.add(new int[] {u, v});
                    nuevos++;
                }
            }
        }
        return nuevos;
    }

    // ¿Le queda a alguien por compartir? (si no, el bulo ya no avanza)
    public boolean sigueVivo() {
        for (int i = 0; i < total(); i++) {
            if (estado[i] == CONTAGIADA) {
                for (int v : siguen.get(i)) {
                    if (estado[v] == LIMPIA) {
                        return true;
                    }
                }
            }
        }
        return false;
    }

    // ---- Acciones del jugador ----

    public boolean verificar(int i) {
        if (estado[i] != LIMPIA) {
            return false;
        }
        estado[i] = PROTEGIDA;
        return true;
    }

    // Desmentir con prueba: la cuenta y todos sus seguidores quedan
    // protegidos; si ya lo había compartido, lo corrige y deja de regarlo.
    public int desmentir(int i) {
        int cambiadas = 0;
        if (estado[i] == CONTAGIADA) {
            estado[i] = CORREGIDA;
            cambiadas++;
        } else if (estado[i] == LIMPIA) {
            estado[i] = PROTEGIDA;
            cambiadas++;
        }
        for (int v : siguen.get(i)) {
            if (estado[v] == LIMPIA) {
                estado[v] = PROTEGIDA;
                cambiadas++;
            }
        }
        return cambiadas;
    }

    // Hablar con un influencer: él queda protegido (o corrige) y uno de cada
    // dos de sus seguidores también.
    public int hablarConInfluencer(int i) {
        int cambiadas = 0;
        if (estado[i] == CONTAGIADA) {
            estado[i] = CORREGIDA;
            cambiadas++;
        } else if (estado[i] == LIMPIA) {
            estado[i] = PROTEGIDA;
            cambiadas++;
        }
        int k = 0;
        for (int v : siguen.get(i)) {
            if (estado[v] == LIMPIA && k % 2 == 0) {
                estado[v] = PROTEGIDA;
                cambiadas++;
            }
            k++;
        }
        return cambiadas;
    }

    // Reportar: solo bots conocidos o el origen ya descubierto.
    public boolean reportar(int i) {
        boolean puede = (tipos.get(i).equals(BOT) && esBotConocido[i]) || (i == origen && origenDescubierto);
        if (!puede || estado[i] == ELIMINADA) {
            return false;
        }
        estado[i] = ELIMINADA;
        return true;
    }

    // Rastrear una cuenta contagiada: se ve de quién le llegó. Si esa cuenta
    // es el origen, queda descubierto.
    public int rastrear(int i) {
        if (estado[i] != CONTAGIADA && estado[i] != CORREGIDA) {
            return -1;
        }
        rastreada[i] = true;
        if (i == origen) {
            origenDescubierto = true;
            return i;
        }
        if (padre[i] == origen) {
            origenDescubierto = true;
        }
        return padre[i];
    }

    // ---- Resultados ----

    public int cuantas(int e) {
        int n = 0;
        for (int i = 0; i < total(); i++) {
            if (estado[i] == e) {
                n++;
            }
        }
        return n;
    }

    // Porcentaje de la red que compartió el bulo (sin contar bots)
    public float porcentajeContagiado() {
        int personas = 0, contagiadas = 0;
        for (int i = 0; i < total(); i++) {
            if (tipos.get(i).equals(BOT)) {
                continue;
            }
            personas++;
            if (estado[i] == CONTAGIADA || estado[i] == CORREGIDA) {
                contagiadas++;
            }
        }
        return personas == 0 ? 0 : 100f * contagiadas / personas;
    }

    // Seguidores de una cuenta (cuánta gente ve lo que publica)
    public int seguidores(int i) {
        return siguen.get(i).size();
    }
}
