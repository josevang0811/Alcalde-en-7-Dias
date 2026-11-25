import java.util.ArrayList;
import java.util.Collections;
import java.util.Random;

// El Noticiero es el banco de noticias de ultima hora que la periodista le
// va contando al candidato, una por turno.
//
// Funciona como un mazo de cartas: al empezar la partida se barajan todas y
// cada turno se saca la de arriba. Asi no se repite ninguna hasta que se
// hayan contado todas (el banco tiene mas noticias que turnos la campana),
// y cada partida llegan en otro orden.
public class Noticiero {
    // La periodista que llama: sale en la llamada y en la ayuda.
    public static final String PERIODISTA = "Marta Ríos";
    public static final String MEDIO = "Noticiero Ciudad Nova";

    private ArrayList<Noticia> mazo;
    private Random azar;

    // La semilla decide el orden del mazo: con la misma semilla las noticias
    // salen siempre en el mismo orden (util para probar el juego).
    public Noticiero(long semilla) {
        azar = new Random(semilla);
        mazo = new ArrayList<Noticia>();
        barajar();
    }

    // Saca la noticia de arriba del mazo. Si ya se contaron todas, se vuelve
    // a armar y barajar el mazo completo. El mazo es una pila: la de arriba
    // es la ultima de la lista, asi sacarla no corre las demas.
    public Noticia siguiente() {
        if (mazo.isEmpty()) {
            barajar();
        }
        return mazo.remove(mazo.size() - 1);
    }

    // Todas las noticias del banco, sin barajar ni sacar ninguna (para grabar
    // la voz de la periodista antes de jugar, en MisionCampana.pde). Incluye
    // las de las historias.
    public ArrayList<Noticia> todas() {
        ArrayList<Noticia> guardado = mazo;
        mazo = new ArrayList<Noticia>();
        agregarNoticias();
        ArrayList<Noticia> lista = mazo;
        mazo = guardado;
        for (int dia = 1; dia <= 7; dia++) {
            Noticia n = historiaDelDia(dia);
            if (n != null) {
                lista.add(n);
            }
        }
        return lista;
    }

    // Las historias de Ciudad Nova (Historias.pde): ciertos dias la noticia no
    // sale del mazo sino que es fija, porque tiene una cinematica antes y un
    // final que depende de lo que haga el jugador. null si ese dia no hay.
    public Noticia historiaDelDia(int dia) {
        if (dia == 1) {   // "El audio": Don Efrain y el video sin contexto
            return new Noticia(Noticia.FALSA,
                "el señor de la tienda La Esquina de Efra se lleva a los niños en un furgón blanco",
                "@alerta_mercado", Noticia.ANONIMO,
                "la Policía dice que no hay ninguna denuncia y vecinos con nombre cuentan que la niña del video es su nieta",
                true);
        }
        if (dia == 5) {   // "Mijo, necesito plata": Doña Carmen y el video que se volvió chiste
            return new Noticia(Noticia.OPINION,
                "una abuela del Barrio Sur cayó en la estafa de «mijo, necesito plata» y el video de ella llorando en la tienda se volvió chiste",
                "@memes_del_sur", Noticia.ANONIMO,
                "unos se burlan de ella y otros dicen que hay que compartirlo para que nadie más caiga",
                true)
                .conTarjetas(new String[] {
                    "Publica cómo funciona la estafa, sin mostrar a nadie.",
                    "Pide que dejen de compartir el video.",
                    "No digas nada: no es asunto tuyo.",
                    "Compártelo «para que nadie más caiga».",
                    "Súbelo con un chiste: así se riega más rápido."
                })
                .conInforme("EL VIDEO ERA REAL. LA VÍCTIMA, TAMBIÉN",
                    "Doña Carmen no hizo nada malo: la engañaron. Compartir su video, aunque sea «para alertar», la expone y la humilla.",
                    "Para alertar de una estafa no hace falta mostrar a la víctima: basta con explicar cómo funciona.");
        }
        return null;
    }

    private void barajar() {
        mazo.clear();
        agregarNoticias();
        Collections.shuffle(mazo, azar);
    }

    // Seis de cada tipo. Cada noticia es una publicacion de Civitas: quien la
    // hizo, de que se trata, que dicen los comentarios y si busca generar
    // odio. Como en la vida real, las verdaderas suelen venir de reporteros
    // verificados y los comentarios las confirman; las falsas, de cuentas
    // anonimas, y en los comentarios hay gente con nombre que las desmiente;
    // las opiniones son gustos o juicios, y los comentarios se dividen. Pero
    // no siempre: hay verdaderas que publica un vecino cualquiera y falsas
    // con nombre y foto, para que el jugador mire todo y no solo el autor.
    private void agregarNoticias() {
        agregar(Noticia.VERDADERA, "el puente peatonal del Parque Industrial va a estar cerrado este fin de semana por mantenimiento",
            "@ana_reporta", Noticia.REPORTERO,
            "varios trabajadores de la zona confirman que ya pusieron las vallas y subieron fotos del aviso de la Alcaldía", false);
        agregar(Noticia.VERDADERA, "desde el lunes la ruta 12 de bus también va a pasar por el mercado central",
            "@carlos.mejia", Noticia.USUARIO,
            "la cuenta verificada de la empresa de transporte respondió que es cierto y compartió el nuevo recorrido", false);
        agregar(Noticia.VERDADERA, "las inscripciones para las becas de la universidad pública están abiertas hasta el viernes",
            "@noticiasdelnorte", Noticia.REPORTERO,
            "estudiantes con nombre y foto cuentan que ya se inscribieron y pegaron el enlace de la universidad", false);
        agregar(Noticia.VERDADERA, "el jueves van a cortar el agua en el Barrio Norte de 8 a 12 por una reparación",
            "@luisa_vecina_norte", Noticia.USUARIO,
            "otros vecinos subieron foto de la carta del acueducto que llegó a todas las casas", false);
        agregar(Noticia.VERDADERA, "la biblioteca del centro va a abrir también los domingos",
            "@diario_nova", Noticia.REPORTERO,
            "la mayoría está feliz, y la Secretaría de Cultura comentó con el horario nuevo", false);
        agregar(Noticia.VERDADERA, "esta semana hay vacunación gratis en todos los puestos de salud de El Puerto",
            "@marcela.salud", Noticia.REPORTERO,
            "enfermeras del puerto confirman las jornadas y nadie trae pruebas de lo contrario", false);

        agregar(Noticia.FALSA, "se reportaron muchos robos y amenazas de los vendedores ambulantes contra los vecinos de La Colina",
            "@verdad_sin_filtro", Noticia.ANONIMO,
            "muchos vecinos con nombre dicen que no está pasando nada y suben videos de la zona tranquila", true);
        agregar(Noticia.FALSA, "el agua de la llave está contaminada y nadie la debe tomar hasta nuevo aviso",
            "@alerta_nova_24", Noticia.ANONIMO,
            "la empresa de acueducto respondió que el agua está bien y muestra los análisis de esta semana", false);
        agregar(Noticia.FALSA, "el próximo mes van a cerrar todos los colegios públicos de la ciudad",
            "@profe.jorge.r", Noticia.USUARIO,
            "rectores y profesores de varios colegios dicen que nadie les ha avisado nada y piden que muestre la fuente", false);
        agregar(Noticia.FALSA, "están regalando mercados a quien comparta esta publicación con diez amigos",
            "@ayudas_nova_oficial", Noticia.ANONIMO,
            "varias personas cuentan que compartieron y nunca les llegó nada; dicen que es una estafa para robar datos", false);
        agregar(Noticia.FALSA, "los estudiantes de la universidad están dañando el centro y habría que sacarlos de la ciudad",
            "@ciudadano_harto", Noticia.ANONIMO,
            "los comerciantes del centro, con nombre, dicen que los daños fueron de otra gente y publican los videos de las cámaras", true);
        agregar(Noticia.FALSA, "anoche hubo un apagón en toda la ciudad por un ataque de hackers",
            "@tecno_rumores", Noticia.ANONIMO,
            "alguien encontró que el video es de otro país y de hace tres años, y nadie más tuvo apagón", false);

        agregar(Noticia.OPINION, "Ciudad Nova necesita más ciclorrutas y menos parqueaderos",
            "@sofia_en_bici", Noticia.USUARIO,
            "unos están de acuerdo y otros dicen que los parqueaderos hacen falta; nadie habla de datos, solo de gustos", false);
        agregar(Noticia.OPINION, "el nuevo parque del centro quedó horrible",
            "@arquitecto_criticon", Noticia.USUARIO,
            "a unos les encanta y a otros no; mucha gente sube fotos del parque lleno de familias", false);
        agregar(Noticia.OPINION, "a los jóvenes de hoy ya no les interesa la política",
            "@radio_nova_manana", Noticia.REPORTERO,
            "jóvenes de la universidad responden molestos que ellos sí votan, pero el locutor dice que es su punto de vista", false);
        agregar(Noticia.OPINION, "la mejor comida de la ciudad está en el mercado central",
            "@comiendo_con_dani", Noticia.USUARIO,
            "cada quien defiende su sitio favorito; es un debate de gustos", false);
        agregar(Noticia.OPINION, "la ciudad estaba mejor hace diez años, antes de que llegara tanta gente de afuera",
            "@vecino_de_siempre", Noticia.USUARIO,
            "algunos lo apoyan, pero otros responden que culpar a los que llegan de afuera es discriminar", true);
        agregar(Noticia.OPINION, "el próximo alcalde debería prohibir los carros en el centro",
            "@el_universitario", Noticia.REPORTERO,
            "es la columna editorial del periódico universitario; los comentarios se dividen entre a favor y en contra", false);
    }

    private void agregar(int tipo, String titular, String autor, int tipoAutor, String comentarios, boolean odio) {
        mazo.add(new Noticia(tipo, titular, autor, tipoAutor, comentarios, odio));
    }
}
