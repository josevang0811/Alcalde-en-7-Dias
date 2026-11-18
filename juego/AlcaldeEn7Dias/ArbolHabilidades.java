import java.util.ArrayList;

// ArbolHabilidades es el arbol n-ario completo: guarda la raiz y concentra
// todas las operaciones (buscar, desbloquear, recorrer, medir). Se separa
// de Nodo a proposito: un Nodo solo conoce sus propios datos y sus hijos,
// pero preguntas como "quien es el padre de X" o "se puede desbloquear Y"
// necesitan mirar el arbol completo, no solo un nodo aislado.
public class ArbolHabilidades {
    // Los nombres de las habilidades que tienen efecto en el juego. Se usan
    // como constantes para que Partida pregunte tiene(VOLANTES) sin escribir
    // el texto a mano en otro lado (un error de tipeo no se notaria).
    public static final String VOLANTES = "Volantes";
    public static final String MEGAFONO = "Megáfono";
    public static final String PERFIL_VERIFICADO = "Perfil verificado";
    public static final String TRANSMISION = "Transmisión en vivo";
    public static final String LIBRETA = "Libreta de notas";
    public static final String FUENTE_CONFIABLE = "Fuente confiable";
    public static final String GOLPE_DE_SUERTE = "Golpe de suerte";
    public static final String RUEDA_DE_PRENSA = "Rueda de prensa";
    public static final String ASISTENTE_IA = "Asistente de IA";
    public static final String MODELO_MEJORADO = "Modelo mejorado";
    public static final String BOTS = "Bots de difusión";
    public static final String IA_PERFECTA = "IA perfecta";

    private Nodo raiz;

    // El arbol arma su propia estructura al nacer: para esta entrega las
    // trece habilidades son siempre las mismas, no hay que leerlas de
    // ningun lado ni permitir que cambien en tiempo de ejecucion.
    public ArbolHabilidades() {
        construirArbol();
    }

    // Arma a mano las tres ramas del diseño (Alcance, Credibilidad e IA)
    // usando agregarHijo(). Esta hecho a mano y no con un bucle porque cada
    // habilidad tiene su propio nombre, costo y lugar fijo en el arbol: no
    // hay un patron repetible que valga la pena generalizar.
    private void construirArbol() {
        raiz = new Nodo("Campaña", "Punto de partida de la campaña", 0, 1);
        raiz.setDesbloqueada(true); // la raiz siempre arranca disponible

        // Alcance: llegar a mas barrios (usa el grafo de la ciudad).
        Nodo volantes = new Nodo(VOLANTES, "Si la publicación suma, los barrios vecinos al elegido reciben +5.", 2, 1);
        Nodo megafono = new Nodo(MEGAFONO, "Si la publicación suma, los vecinos de los vecinos también reciben +3.", 3, 1);
        Nodo perfilVerificado = new Nodo(PERFIL_VERIFICADO, "Puedes publicar hasta a 2 calles de tu territorio.", 3, 1);
        Nodo transmision = new Nodo(TRANSMISION, "Una vez por partida: tu publicación cuenta como la mejor, pase lo que pase (100%).", 5, 6);
        volantes.agregarHijo(megafono);
        volantes.agregarHijo(perfilVerificado);
        perfilVerificado.agregarHijo(transmision);

        // Credibilidad: jugar limpio y que te crean.
        Nodo libreta = new Nodo(LIBRETA, "Puedes volver a oír la noticia del teléfono una vez por turno.", 2, 1);
        Nodo fuenteConfiable = new Nodo(FUENTE_CONFIABLE, "Cuando aciertas, 50% de probabilidad de +10 extra.", 3, 1);
        Nodo golpeDeSuerte = new Nodo(GOLPE_DE_SUERTE, "20% de probabilidad de que tu tarjeta se cambie por la mejor.", 5, 1);
        Nodo ruedaDePrensa = new Nodo(RUEDA_DE_PRENSA, "Cuando una publicación resta, pierdes solo la mitad.", 4, 1);
        libreta.agregarHijo(fuenteConfiable);
        libreta.agregarHijo(ruedaDePrensa);
        fuenteConfiable.agregarHijo(golpeDeSuerte);

        // IA: el atajo. Funciona, pero puede salir muy mal si la descubren.
        Nodo asistente = new Nodo(ASISTENTE_IA, "Desbloquea la tarjeta de IA: inventa una noticia. 20% de que no la descubran (+30); si la descubren, -10.", 3, 2);
        Nodo modelo = new Nodo(MODELO_MEJORADO, "La noticia de la IA engaña más: 40% de que no la descubran.", 4, 1);
        Nodo bots = new Nodo(BOTS, "Si la IA no es descubierta, +10 extra.", 5, 1);
        Nodo iaPerfecta = new Nodo(IA_PERFECTA, "En la última ronda, si en la anterior perdiste apoyo, la IA no falla (100%).", 6, 6);
        asistente.agregarHijo(modelo);
        modelo.agregarHijo(bots);
        modelo.agregarHijo(iaPerfecta);

        raiz.agregarHijo(volantes);
        raiz.agregarHijo(libreta);
        raiz.agregarHijo(asistente);
    }

    public Nodo getRaiz() {
        return raiz;
    }

    // Punto de entrada publico: quien llama no necesita saber desde donde
    // empieza la busqueda, siempre es desde la raiz.
    public Nodo buscar(String nombre) {
        return buscarRec(raiz, nombre);
    }

    // Caso base: n es null (se acabo una rama sin encontrar nada) o el
    // nombre coincide con el nodo actual. Si no, se busca en cada hijo por
    // turno y se corta apenas alguno devuelve un resultado no nulo, porque
    // en este arbol los nombres no se repiten y no hace falta seguir.
    private Nodo buscarRec(Nodo n, String nombre) {
        if (n == null) return null;
        if (n.getNombre().equals(nombre)) return n;
        for (Nodo hijo : n.getHijos()) {
            Nodo resultado = buscarRec(hijo, nombre);
            if (resultado != null) return resultado;
        }
        return null;
    }

    // Busca el padre de un nodo por nombre en vez de guardar un puntero al
    // padre en cada Nodo: asi Nodo se queda simple y esta pregunta (poco
    // frecuente, solo se usa para el panel lateral y estaDisponible) vive
    // aqui, donde ya se recorre el arbol de todas formas.
    // Caso base: actual es null. Primero se revisa si alguno de los hijos
    // directos de actual es el nodo buscado (ahi actual mismo es la
    // respuesta); si no, se repite el proceso mas abajo en cada hijo.
    public Nodo buscarPadre(Nodo actual, String nombre) {
        if (actual == null) return null;
        for (Nodo hijo : actual.getHijos()) {
            if (hijo.getNombre().equals(nombre)) return actual;
        }
        for (Nodo hijo : actual.getHijos()) {
            Nodo resultado = buscarPadre(hijo, nombre);
            if (resultado != null) return resultado;
        }
        return null;
    }

    // Una habilidad esta disponible cuando todavia no esta desbloqueada
    // pero su padre si lo esta: es justo el estado intermedio entre
    // "bloqueada" y "desbloqueada" que la interfaz pinta resaltado.
    public boolean estaDisponible(Nodo n) {
        if (n == null || n.getDesbloqueada()) return false;
        Nodo padre = buscarPadre(raiz, n.getNombre());
        if (padre == null) return false;
        return padre.getDesbloqueada();
    }

    // Metodo central del juego. Tiene que cumplirse dos condiciones antes
    // de tocar nada: (1) estaDisponible(n) ya revisa que el nodo no este
    // desbloqueado todavia y que su padre si lo este (regla de jerarquia
    // del arbol); (2) p.puedePagar(n.getCosto()) revisa que la partida
    // tenga puntos suficientes (regla del juego). Si cualquiera falla se
    // devuelve false sin cambiar nada; solo si pasan las dos se cobra el
    // costo y se marca el nodo, en ese orden, para no descontar puntos de
    // un desbloqueo que despues resulte invalido.
    // Ademas, (3) la habilidad tiene que estar permitida en el turno actual
    // (rondaMinima).
    public boolean desbloquear(String nombre, Partida p) {
        Nodo n = buscar(nombre);
        if (n == null) return false;
        if (!estaDisponible(n)) return false;
        if (p.getTurno() < n.getRondaMinima()) return false;
        if (!p.puedePagar(n.getCosto())) return false;
        p.gastar(n.getCosto());
        n.setDesbloqueada(true);
        return true;
    }

    // Si el candidato ya tiene una habilidad. Es lo que pregunta Partida
    // para saber que efectos aplicar al publicar.
    public boolean tiene(String nombre) {
        Nodo n = buscar(nombre);
        return n != null && n.getDesbloqueada();
    }

    public ArrayList<Nodo> preorden() {
        ArrayList<Nodo> lista = new ArrayList<Nodo>();
        preordenRec(raiz, lista);
        return lista;
    }

    // Recorrido preorden: primero se visita el nodo (se agrega a la lista)
    // y despues cada uno de sus hijos, de izquierda a derecha. Caso base:
    // n es null, que pasa cuando se llega mas alla de una hoja (una hoja
    // no tiene hijos, asi que el for simplemente no itera y la recursion
    // termina sola ahi).
    public void preordenRec(Nodo n, ArrayList<Nodo> lista) {
        if (n == null) return;
        lista.add(n);
        for (Nodo hijo : n.getHijos()) {
            preordenRec(hijo, lista);
        }
    }

    // Reutiliza preorden() en vez de escribir otro recorrido: recorrer los
    // trece nodos una vez de mas es barato y evita duplicar la logica de
    // "visitar todo el arbol" en dos lugares distintos.
    public ArrayList<Nodo> disponibles() {
        ArrayList<Nodo> lista = new ArrayList<Nodo>();
        for (Nodo n : preorden()) {
            if (estaDisponible(n)) lista.add(n);
        }
        return lista;
    }

    public int contarDesbloqueadas() {
        int contador = 0;
        for (Nodo n : preorden()) {
            if (n.getDesbloqueada()) contador++;
        }
        return contador;
    }

    // Igual que contarDesbloqueadas(), pero solo dentro del subarbol que
    // cuelga de n. La interfaz lo usa con cada hijo de la raiz para mostrar
    // cuanto ha avanzado el jugador en cada rama (Alcance, Credibilidad,
    // IA). Caso base: n es null y no suma nada; si no, cuenta a n (si
    // esta desbloqueado) mas lo que cuente cada uno de sus hijos.
    public int contarDesbloqueadasEn(Nodo n) {
        if (n == null) return 0;
        int suma = n.getDesbloqueada() ? 1 : 0;
        for (Nodo hijo : n.getHijos()) {
            suma += contarDesbloqueadasEn(hijo);
        }
        return suma;
    }

    // Dice en cual de las ramas principales esta un nodo: devuelve la
    // posicion (0, 1 o 2) del hijo de la raiz cuyo subarbol lo contiene, o
    // -1 si el nodo es la raiz misma. La interfaz lo usa para pintar cada
    // habilidad con el color de su rama. Reutiliza buscarRec() empezando
    // desde cada rama en vez de desde la raiz.
    public int indiceRama(Nodo n) {
        ArrayList<Nodo> ramas = raiz.getHijos();
        for (int i = 0; i < ramas.size(); i++) {
            if (buscarRec(ramas.get(i), n.getNombre()) != null) return i;
        }
        return -1;
    }

    // Caso base: una hoja tiene altura 1 (se cuenta a si misma, no tiene
    // subarboles debajo). Para un nodo con hijos, la altura es 1 mas la
    // altura mas grande entre sus hijos: siempre importa la rama mas
    // profunda, no el promedio ni la suma de todas.
    public int altura(Nodo n) {
        if (n == null) return 0;
        if (n.esHoja()) return 1;
        int max = 0;
        for (Nodo hijo : n.getHijos()) {
            int alturaHijo = altura(hijo);
            if (alturaHijo > max) max = alturaHijo;
        }
        return 1 + max;
    }

    // Caso base: n es null, entonces no suma nada (esto es lo que hace que
    // una hoja, sin hijos, de peso 1: el for no itera y solo queda el "+1"
    // de ella misma). A diferencia de altura(), aqui si importa la suma de
    // todas las ramas, porque el peso cuenta cuantos nodos hay en total.
    public int peso(Nodo n) {
        if (n == null) return 0;
        int suma = 0;
        for (Nodo hijo : n.getHijos()) {
            suma += peso(hijo);
        }
        return 1 + suma;
    }
}
