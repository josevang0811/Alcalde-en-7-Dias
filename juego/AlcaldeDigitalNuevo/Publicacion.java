import java.util.ArrayList;

// Lo que paso con una publicacion: en que barrio se publico, con que
// categoria quedo al final (las habilidades pueden cambiarla), cuanto cambio
// el apoyo del barrio, cuanto les toco a los barrios de alrededor y la
// lista de habilidades que se activaron, para que el influencer las cuente.
// Partida.publicar() la arma y la interfaz solo la lee.
public class Publicacion {
    private int zona;
    private int categoria;
    private int valor;   // lo que valio la tarjeta, antes de topar en 0 o 100
    private int cambio;  // lo que cambio de verdad el apoyo del barrio
    private int[] bonos;  // cambio de apoyo en cada barrio por Volantes y Megafono
    private boolean usoIA;
    private boolean iaDescubierta;
    private ArrayList<String> efectos;
    private int credAntes, credDespues;   // la credibilidad antes y después
    private int alcance;                  // cuánta gente la vio

    public Publicacion(int zona, int cantidadBarrios) {
        this.zona = zona;
        this.bonos = new int[cantidadBarrios];
        this.efectos = new ArrayList<String>();
    }

    public void setCategoria(int categoria) {
        this.categoria = categoria;
    }

    public void setValor(int valor) {
        this.valor = valor;
    }

    public void setCambio(int cambio) {
        this.cambio = cambio;
    }

    public void setBono(int barrio, int valor) {
        bonos[barrio] = valor;
    }

    public void marcarIA(boolean descubierta) {
        usoIA = true;
        iaDescubierta = descubierta;
    }

    public void agregarEfecto(String texto) {
        efectos.add(texto);
    }

    public int getZona() {
        return zona;
    }

    public int getCategoria() {
        return categoria;
    }

    public int getValor() {
        return valor;
    }

    public int getCambio() {
        return cambio;
    }

    public int getBono(int barrio) {
        return bonos[barrio];
    }

    public boolean usoIA() {
        return usoIA;
    }

    public boolean iaDescubierta() {
        return iaDescubierta;
    }

    public void setCredibilidad(int antes, int despues) {
        credAntes = antes;
        credDespues = despues;
    }

    public int getCredAntes() {
        return credAntes;
    }

    public int getCredDespues() {
        return credDespues;
    }

    public void setAlcance(int alcance) {
        this.alcance = alcance;
    }

    public int getAlcance() {
        return alcance;
    }

    public ArrayList<String> getEfectos() {
        return efectos;
    }
}
