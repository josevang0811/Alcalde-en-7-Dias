import java.util.ArrayList;

// Un Nodo representa una habilidad del arbol de campana. Es la pieza basica
// del arbol n-ario: cada nodo guarda su propia informacion (nombre, costo,
// si esta desbloqueada) y la lista de sus hijos directos. No sabe nada del
// resto del arbol ni de quien es su padre; esa relacion la maneja
// ArbolHabilidades, para que esta clase se quede simple y facil de explicar.
public class Nodo {
    private String nombre;
    private String descripcion;
    private int costo;
    private int rondaMinima;  // desde que turno se puede comprar (1 = desde el principio)
    private boolean desbloqueada;
    private ArrayList<Nodo> hijos;

    // Un nodo nuevo siempre nace bloqueado y sin hijos: los hijos se agregan
    // despues, uno por uno, cuando ArbolHabilidades arma el arbol completo.
    // rondaMinima sirve para que las habilidades mas fuertes no se puedan
    // comprar al principio de la campana (asi no se desbalancea el juego).
    public Nodo(String nombre, String descripcion, int costo, int rondaMinima) {
        this.nombre = nombre;
        this.descripcion = descripcion;
        this.costo = costo;
        this.rondaMinima = rondaMinima;
        this.desbloqueada = false;
        this.hijos = new ArrayList<Nodo>();
    }

    public String getNombre() {
        return nombre;
    }

    public String getDescripcion() {
        return descripcion;
    }

    public int getCosto() {
        return costo;
    }

    public int getRondaMinima() {
        return rondaMinima;
    }

    public boolean getDesbloqueada() {
        return desbloqueada;
    }

    public ArrayList<Nodo> getHijos() {
        return hijos;
    }

    // Se usa desde ArbolHabilidades.desbloquear(): el nodo no decide por si
    // solo si puede desbloquearse (eso depende del padre y de los puntos de
    // la partida), solo guarda el resultado una vez que ya se decidio.
    public void setDesbloqueada(boolean valor) {
        desbloqueada = valor;
    }

    // Solo se llama durante construirArbol(), al armar la estructura fija
    // de las trece habilidades. Despues de eso la forma del arbol no cambia.
    public void agregarHijo(Nodo h) {
        hijos.add(h);
    }

    // Una hoja es una habilidad final de su rama (no abre mas caminos).
    // Sirve para saber donde termina la recursion en los recorridos del arbol.
    public boolean esHoja() {
        return hijos.isEmpty();
    }
}
