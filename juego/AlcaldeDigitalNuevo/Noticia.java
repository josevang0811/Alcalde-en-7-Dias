// Una Noticia es lo que la periodista le cuenta al candidato por telefono al
// empezar cada turno. Ya no viene de un periodico: la periodista la vio en
// una publicacion de Civitas, la red social de la ciudad. Guarda de que se
// trata (el titular), quien la publico, que dicen los comentarios, si la
// publicacion busca generar odio y que es en realidad: verdadera, falsa u
// opinion.
//
// Quien publica, quien comenta y el tono son las pistas del jugador para
// decidir que hacer (no es lo mismo un reportero verificado que una cuenta
// anonima creada ayer), pero no la respuesta: el tipo real no se dice nunca
// en la llamada.
public class Noticia {
    public static final int VERDADERA = 0;
    public static final int FALSA = 1;
    public static final int OPINION = 2;

    // Quien hizo la publicacion
    public static final int REPORTERO = 0;   // reportero o medio con cuenta verificada
    public static final int USUARIO = 1;     // una persona comun, con nombre
    public static final int ANONIMO = 2;     // cuenta sin nombre ni foto

    private String titular;
    private String autor;        // el @ de la cuenta
    private int tipoAutor;
    private String comentarios;  // lo que se ve en los comentarios
    private boolean odio;        // la publicacion ataca a un grupo de personas
    private int tipo;

    public Noticia(int tipo, String titular, String autor, int tipoAutor, String comentarios, boolean odio) {
        this.tipo = tipo;
        this.titular = titular;
        this.autor = autor;
        this.tipoAutor = tipoAutor;
        this.comentarios = comentarios;
        this.odio = odio;
    }

    public String getTitular() {
        return titular;
    }

    public String getAutor() {
        return autor;
    }

    public int getTipoAutor() {
        return tipoAutor;
    }

    public String getComentarios() {
        return comentarios;
    }

    public boolean generaOdio() {
        return odio;
    }

    public int getTipo() {
        return tipo;
    }

    // Las historias (Historias.pde) traen sus propias tarjetas y su propio
    // informe, porque las genéricas no cuentan lo que pasa en ellas.
    // tarjetas: mayor, menor, neutra, negativa y otra negativa.
    // informe: lo que era, la pista y la lección.
    private String[] tarjetasPropias = null;
    private String[] informePropio = null;

    public Noticia conTarjetas(String[] tarjetas) {
        tarjetasPropias = tarjetas;
        return this;
    }

    public Noticia conInforme(String verdad, String pista, String leccion) {
        informePropio = new String[] {verdad, pista, leccion};
        return this;
    }

    public String[] getTarjetasPropias() {
        return tarjetasPropias;
    }

    public String[] getInformePropio() {
        return informePropio;
    }

    // Quien la publico, para leer despues de "La publico ..."
    public String describirAutor() {
        if (tipoAutor == REPORTERO) {
            return autor + ", una cuenta verificada de reportero";
        } else if (tipoAutor == USUARIO) {
            return autor + ", un usuario común, con nombre y foto";
        }
        return autor + ", una cuenta anónima, sin foto y con pocos seguidores";
    }

    // La fuente en una linea, para el chat del influencer
    public String getFuente() {
        return "una publicación de " + describirAutor();
    }

    // Nombre del tipo para mostrarlo en la consola (tecla P).
    public String nombreTipo() {
        if (tipo == VERDADERA) {
            return "verdadera";
        } else if (tipo == FALSA) {
            return "falsa";
        }
        return "opinión";
    }
}
