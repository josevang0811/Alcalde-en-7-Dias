// Una Tarjeta es una de las seis ordenes que el candidato le puede dar al
// influencer en el celular. Guarda el texto que se ve, que accion es (por
// ejemplo, desmentir) y en que categoria queda segun la noticia del turno
// (correcta mayor, correcta menor, neutra, negativa o IA). El jugador solo
// ve el texto: la categoria es lo que tiene que adivinar. Si la de IA se
// puede usar o no lo decide Partida, porque depende del arbol.
public class Tarjeta {
    private String texto;
    private int accion;
    private int categoria;

    public Tarjeta(String texto, int accion, int categoria) {
        this.texto = texto;
        this.accion = accion;
        this.categoria = categoria;
    }

    public String getTexto() {
        return texto;
    }

    public int getAccion() {
        return accion;
    }

    public int getCategoria() {
        return categoria;
    }
}
