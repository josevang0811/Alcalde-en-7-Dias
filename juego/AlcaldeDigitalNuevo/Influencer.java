import java.util.ArrayList;
import java.util.Collections;
import java.util.Random;

// El Influencer es quien publica en Civitas por el candidato. Cada turno,
// despues de la llamada, le escribe por el celular con la noticia y le
// ofrece seis tarjetas: seis formas de publicarla. Aqui viven las reglas de
// esas tarjetas: que textos hay, cuanto vale cada una segun la noticia y
// como se arman las seis de cada turno.
//
// Las tarjetas son ACCIONES (compartir, desmentir, presentarla como
// opinion...) y cada una tiene cinco formas de decirse que se rotan al azar,
// para que la respuesta no sea tan obvia. Lo que vale una accion depende de
// que era la noticia en realidad: compartir una noticia verdadera es lo
// mejor, pero compartir una falsa es regar un bulo. Por eso la pista sigue
// siendo la fuente que dio la periodista.
public class Influencer {
    public static final String NOMBRE = "Nico Viral";

    // Categorias de una tarjeta (lo que vale segun la noticia del turno).
    public static final int MAYOR = 0;     // la mejor respuesta
    public static final int MENOR = 1;     // buena, pero vale menos
    public static final int NEUTRA = 2;    // no suma ni resta
    public static final int NEGATIVA = 3;  // resta apoyo
    public static final int IA = 4;        // inventar una noticia (se desbloquea con el arbol)
    public static final int[] PUNTOS = {30, 15, 0, -10, 0};

    // Acciones: la fila de TEXTOS que les corresponde.
    public static final int COMPARTIR = 0;
    public static final int DESMENTIR = 1;
    public static final int OPINION = 2;
    public static final int CAUTELA = 3;
    public static final int CALLAR = 4;
    public static final int EXAGERAR = 5;
    public static final int INVENTAR = 6;

    // Probabilidad (de 100) de cada categoria para la sexta tarjeta, la que
    // se repite. La que mas puntos da sale poco, para que casi nunca haya
    // dos respuestas perfectas.
    private static final int[] PESO_REPETIDA = {10, 25, 25, 40};

    private static final String[][] TEXTOS = {
        {   // COMPARTIR: tal como llego, con su fuente
            "Compártela tal cual, con el enlace de donde salió.",
            "Publícala como llegó y cita la fuente.",
            "Súbela completa para que los vecinos se enteren ya.",
            "Haz un post claro con el dato y quién lo dijo.",
            "Reenvíala a tus seguidores sin cambiarle nada."
        },
        {   // DESMENTIR
            "Desmiéntela: di que es falsa y pide que no la reenvíen.",
            "Publica que es un bulo y explica por qué.",
            "Avisa que es mentira antes de que se riegue más.",
            "Haz un video diciendo que eso no es cierto.",
            "Responde con un «¡Falso!» bien grande y sin rodeos."
        },
        {   // OPINION: presentarla como un punto de vista
            "Compártela aclarando que es una opinión, no un hecho.",
            "Abre un debate: «esto piensan algunos, ¿y ustedes?».",
            "Publícala como punto de vista y da el tuyo con respeto.",
            "Haz una encuesta para ver qué opinan los vecinos.",
            "Dila como lo que es: lo que piensa alguien."
        },
        {   // CAUTELA: mencionarla sin afirmar nada
            "Compártela con cuidado: «todavía no está confirmado».",
            "Sube una historia pidiendo esperar la información oficial.",
            "Pregunta si alguien la puede confirmar antes de regarla.",
            "Menciónala de pasada, sin afirmar nada.",
            "Publícala con un «ojo: verifiquen antes de compartir»."
        },
        {   // CALLAR
            "Mejor no publiquemos nada esta vez.",
            "Déjala pasar: hoy no toquemos el tema.",
            "Guárdala y sigamos con otra cosa.",
            "Ni la comentes: que se la lleve el viento.",
            "Esperemos a ver qué hacen los demás."
        },
        {   // EXAGERAR: siempre sale mal
            "Ponle un título alarmante para que se comparta más.",
            "Agrégale detalles que la hagan más impactante.",
            "Publícala con «¡URGENTE!» y muchos signos de admiración.",
            "Úsala para echarle la culpa al alcalde actual.",
            "Hazla meme, aunque se pierda lo que de verdad dice."
        }
    };
    private static final String TEXTO_IA = "Pídele a la IA que invente una noticia.";

    private static final String[][] REACCIONES = {
        {   // MAYOR
            "¡Se hizo viral! En {barrio} te están aplaudiendo.",
            "¡Eso! En {barrio} la están compartiendo con tu nombre.",
            "Buenísimo, jefe: en {barrio} confían más en ti."
        },
        {   // MENOR
            "Pegó, pero poquito. En {barrio} algunos la vieron.",
            "Algo es algo: en {barrio} sumamos unos votos.",
            "No fue la mejor jugada, pero en {barrio} nos fue bien."
        },
        {   // NEUTRA
            "Nada se movió en {barrio}. Ni bien ni mal.",
            "Silencio total en {barrio}. Seguimos igual.",
            "Hoy no ganamos ni perdimos nada en {barrio}."
        },
        {   // NEGATIVA
            "Uy… en {barrio} nos cayeron encima en los comentarios.",
            "Eso salió mal: en {barrio} perdimos apoyo.",
            "Nos están criticando en {barrio}. Hay que tener más cuidado."
        }
    };

    // Lo que "escribe" la IA cuando se usa su tarjeta. Son exageraciones o
    // inventos: justo lo que el juego enseña a no creer.
    private static final String[] NOTICIAS_IA = {
        "En {barrio} van a regalar mercados a quien vote por nosotros.",
        "Exclusivo: el agua de {barrio} será gratis desde el lunes.",
        "Confirmado: en {barrio} van a construir un estadio nuevo.",
        "Un experto asegura que {barrio} es el barrio más seguro del país.",
        "Filtran que el alcalde actual quiere cerrar los parques de {barrio}."
    };

    private Random azar;

    public Influencer(long semilla) {
        azar = new Random(semilla);
    }

    // Cuanto vale cada accion segun lo que era la noticia. La accion que
    // corresponde al tipo de noticia es la mayor; mencionarla con cautela
    // siempre es la menor; callar siempre es neutra, y todo lo demas resta.
    public int categoriaDe(int accion, int tipoNoticia) {
        if (accion == accionCorrecta(tipoNoticia)) {
            return MAYOR;
        } else if (accion == CAUTELA) {
            return MENOR;
        } else if (accion == CALLAR) {
            return NEUTRA;
        } else if (accion == INVENTAR) {
            return IA;
        }
        return NEGATIVA;
    }

    // Verdadera: compartirla. Falsa: desmentirla. Opinion: presentarla como
    // opinion.
    public int accionCorrecta(int tipoNoticia) {
        if (tipoNoticia == Noticia.VERDADERA) {
            return COMPARTIR;
        } else if (tipoNoticia == Noticia.FALSA) {
            return DESMENTIR;
        }
        return OPINION;
    }

    // Las seis tarjetas del turno: una de cada categoria (mayor, menor,
    // neutra y negativa), una sexta que repite cualquiera de esas cuatro, y
    // la de la IA (que se puede usar solo con el Asistente de IA del arbol).
    // Al final se barajan para que la posicion no de pistas. Ningun texto
    // sale dos veces.
    public ArrayList<Tarjeta> armarTarjetas(Noticia noticia) {
        int tipo = noticia.getTipo();
        ArrayList<Tarjeta> tarjetas = new ArrayList<Tarjeta>();
        tarjetas.add(tarjetaDe(MAYOR, tipo, tarjetas));
        tarjetas.add(tarjetaDe(MENOR, tipo, tarjetas));
        tarjetas.add(tarjetaDe(NEUTRA, tipo, tarjetas));
        tarjetas.add(tarjetaDe(NEGATIVA, tipo, tarjetas));
        tarjetas.add(tarjetaDe(categoriaRepetida(), tipo, tarjetas));
        tarjetas.add(new Tarjeta(TEXTO_IA, INVENTAR, IA));
        Collections.shuffle(tarjetas, azar);
        return tarjetas;
    }

    // Sortea la categoria de la sexta tarjeta con los pesos de PESO_REPETIDA:
    // un numero de 0 a 99 cae en uno de los cuatro tramos.
    private int categoriaRepetida() {
        int sorteo = azar.nextInt(100);
        int acumulado = 0;
        for (int c = 0; c < PESO_REPETIDA.length; c++) {
            acumulado += PESO_REPETIDA[c];
            if (sorteo < acumulado) {
                return c;
            }
        }
        return NEGATIVA;
    }

    // Una tarjeta de la categoria pedida, con un texto que todavia no este
    // entre las ya elegidas: se sortea una accion de esa categoria y una de
    // sus cinco formas de decirla.
    private Tarjeta tarjetaDe(int categoria, int tipo, ArrayList<Tarjeta> yaElegidas) {
        ArrayList<Integer> acciones = new ArrayList<Integer>();
        for (int a = 0; a < TEXTOS.length; a++) {
            if (categoriaDe(a, tipo) == categoria) {
                acciones.add(a);
            }
        }
        while (true) {
            int accion = acciones.get(azar.nextInt(acciones.size()));
            String texto = TEXTOS[accion][azar.nextInt(TEXTOS[accion].length)];
            if (!textoRepetido(texto, yaElegidas)) {
                return new Tarjeta(texto, accion, categoria);
            }
        }
    }

    private boolean textoRepetido(String texto, ArrayList<Tarjeta> tarjetas) {
        for (Tarjeta t : tarjetas) {
            if (t.getTexto().equals(texto)) {
                return true;
            }
        }
        return false;
    }

    // Lo que contesta el influencer cuando la publicacion llega al barrio.
    public String reaccion(int categoria, String barrio) {
        String[] opciones = REACCIONES[categoria];
        return opciones[azar.nextInt(opciones.length)].replace("{barrio}", barrio);
    }

    public String noticiaInventada(String barrio) {
        return NOTICIAS_IA[azar.nextInt(NOTICIAS_IA.length)].replace("{barrio}", barrio);
    }

    // Despues de publicar se le cuenta al jugador que era la noticia, para
    // que aprenda a leer la fuente la proxima vez.
    public String explicacion(int tipoNoticia) {
        if (tipoNoticia == Noticia.VERDADERA) {
            return "Era verdadera: lo mejor era compartirla tal cual, con su fuente.";
        } else if (tipoNoticia == Noticia.FALSA) {
            return "Era falsa: lo mejor era desmentirla.";
        }
        return "Era una opinión: lo mejor era presentarla como opinión, no como un hecho.";
    }
}
