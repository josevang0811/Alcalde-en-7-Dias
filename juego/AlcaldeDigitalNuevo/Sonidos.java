import java.util.Random;
import javax.sound.sampled.AudioFormat;
import javax.sound.sampled.AudioSystem;
import javax.sound.sampled.Clip;

// Los sonidos del telefono: el timbre, descolgar, la voz de la periodista,
// el tono de "tu-tu-tu" cuando se corta y colgar.
//
// No se usa ninguna libreria ni archivo de audio: cada sonido se calcula
// muestra por muestra con senos y un poco de ruido, una sola vez al abrir
// el juego, y se guarda en un Clip de javax.sound (que viene con Java). Asi
// el juego funciona en cualquier computador del equipo sin instalar nada.
//
// Si el computador no tiene salida de audio, cualquier error se atrapa y el
// juego sigue funcionando en silencio.
public class Sonidos {
    private static final float MUESTREO = 22050;  // muestras por segundo

    private Clip timbre;
    private Clip descolgar;
    private Clip colgar;
    private Clip ocupado;
    private Clip[] voces;
    private Clip mensaje;
    private Clip envio;
    private Clip exito;
    private Clip fallo;
    private Clip tic;
    private boolean disponible;
    private Random ruido;

    public Sonidos() {
        ruido = new Random(5);
        try {
            timbre = abrir(timbreDeTelefono());
            descolgar = abrir(golpeDeAuricular(0.3f, 150, 0.45f));
            colgar = abrir(golpeDeAuricular(0.35f, 95, 0.6f));
            ocupado = abrir(tonoOcupado());
            voces = new Clip[5];
            float[] tonos = {195, 210, 225, 240, 255};
            for (int i = 0; i < voces.length; i++) {
                voces[i] = abrir(silaba(tonos[i], i));
            }
            mensaje = abrir(notas(new float[] {988, 1319}, 0.09f, 0.18f));
            envio = abrir(barrido());
            exito = abrir(notas(new float[] {523, 659, 784, 1047}, 0.08f, 0.26f));
            fallo = abrir(notas(new float[] {392, 311}, 0.16f, 0.24f));
            tic = abrir(notas(new float[] {1568}, 0.03f, 0.2f));
            disponible = true;
        } catch (Throwable e) {
            disponible = false;
        }
    }

    // --- Lo que usa la interfaz ---

    public void tocarTimbre() {
        tocar(timbre);
    }

    public void pararTimbre() {
        parar(timbre);
    }

    public void tocarDescolgar() {
        tocar(descolgar);
    }

    public void tocarColgar() {
        tocar(colgar);
    }

    public void tocarOcupado() {
        tocar(ocupado);
    }

    public void pararOcupado() {
        parar(ocupado);
    }

    // Una silaba de la voz de la periodista (hay cinco, un poco distintas).
    public void tocarVoz(int numero) {
        if (disponible) {
            tocar(voces[numero % voces.length]);
        }
    }

    // El "tin-tin" de un mensaje nuevo en el chat.
    public void tocarMensaje() {
        tocar(mensaje);
    }

    // El "fiuuu" de la publicacion saliendo hacia el barrio.
    public void tocarEnvio() {
        tocar(envio);
    }

    // Tres notas que suben: la publicacion sumo apoyo.
    public void tocarExito() {
        tocar(exito);
    }

    // Dos notas que bajan: la publicacion resto apoyo.
    public void tocarFallo() {
        tocar(fallo);
    }

    // El tic-tac de los últimos segundos de la ronda (Ronda.pde).
    public void tocarTic() {
        tocar(tic);
    }

    private void tocar(Clip c) {
        if (!disponible) {
            return;
        }
        try {
            c.stop();
            c.setFramePosition(0);
            c.start();
        } catch (Throwable e) {
            disponible = false;
        }
    }

    private void parar(Clip c) {
        if (!disponible) {
            return;
        }
        try {
            c.stop();
        } catch (Throwable e) {
            disponible = false;
        }
    }

    // --- Como se fabrica cada sonido ---

    // El timbre de un telefono antiguo: un martillito golpea dos campanas,
    // una y otra, unas cuarenta veces por segundo. Cada golpe suena como una
    // campanita que se apaga rapido, y como el siguiente llega antes de que
    // se apague, se oye el "rrring" continuo. Son dos rafagas de 0,4
    // segundos separadas por 0,2 (el "ring-ring" de siempre).
    private float[] timbreDeTelefono() {
        float[] m = new float[(int) (1.0f * MUESTREO)];
        agregarRafaga(m, 0.0f, 0.4f);
        agregarRafaga(m, 0.6f, 0.4f);
        return normalizar(m, 0.5f);
    }

    private void agregarRafaga(float[] m, float inicio, float duracion) {
        int golpes = (int) (duracion / 0.025f);
        for (int g = 0; g < golpes; g++) {
            float frecuencia = (g % 2 == 0) ? 1250 : 1480;
            agregarCampana(m, inicio + g * 0.025f, frecuencia);
            agregarRuido(m, inicio + g * 0.025f, 0.002f, 0.4f);
        }
    }

    // Una campana no suena como una sola nota: tiene una frecuencia
    // principal y otras mas agudas que no son multiplos exactos de ella.
    private void agregarCampana(float[] m, float inicio, float f) {
        int desde = (int) (inicio * MUESTREO);
        int cuantas = (int) (0.2f * MUESTREO);
        for (int i = 0; i < cuantas && desde + i < m.length; i++) {
            double t = i / MUESTREO;
            double onda = Math.sin(2 * Math.PI * f * t)
                + 0.35 * Math.sin(2 * Math.PI * f * 2.0 * t)
                + 0.55 * Math.sin(2 * Math.PI * f * 2.76 * t)
                + 0.2 * Math.sin(2 * Math.PI * f * 5.4 * t);
            m[desde + i] += (float) (onda * Math.exp(-t * 20));
        }
    }

    // Descolgar y colgar: un "clac" de plastico (ruido muy corto) sobre un
    // golpe grave que se apaga rapido. Colgar es mas grave y mas fuerte.
    private float[] golpeDeAuricular(float duracion, float grave, float volumen) {
        float[] m = new float[(int) (duracion * MUESTREO)];
        for (int i = 0; i < m.length; i++) {
            double t = i / MUESTREO;
            m[i] += (float) (0.9 * Math.sin(2 * Math.PI * grave * t) * Math.exp(-t * 28));
        }
        agregarRuido(m, 0.0f, 0.006f, 1.0f);
        agregarRuido(m, 0.028f, 0.004f, 0.5f);
        return normalizar(m, volumen);
    }

    // "Tu, tu, tu": tres pitidos de 425 Hz, el tono de ocupado que se usa en
    // Colombia. Los armonicos le dan el sonido "de linea telefonica".
    private float[] tonoOcupado() {
        float[] m = new float[(int) (1.35f * MUESTREO)];
        for (int p = 0; p < 3; p++) {
            int desde = (int) (p * 0.45f * MUESTREO);
            int cuantas = (int) (0.22f * MUESTREO);
            for (int i = 0; i < cuantas; i++) {
                double t = i / MUESTREO;
                double onda = Math.sin(2 * Math.PI * 425 * t)
                    + 0.25 * Math.sin(2 * Math.PI * 850 * t)
                    + 0.1 * Math.sin(2 * Math.PI * 1275 * t);
                m[desde + i] = (float) (onda * suavizado(i, cuantas));
            }
        }
        return normalizar(m, 0.22f);
    }

    // Una silaba corta, como si se oyera una voz por el telefono: una nota
    // grave con sus armonicos, y de esos armonicos suenan mas los que caen
    // cerca de las "formantes" de una vocal (a, e, o, a, i). No dice
    // palabras: es el murmullo de alguien hablando al otro lado.
    private float[] silaba(float tono, int numero) {
        float[][] vocales = {{750, 1200}, {450, 1900}, {500, 900}, {700, 1300}, {300, 2300}};
        float[] formantes = vocales[numero % vocales.length];
        float[] m = new float[(int) (0.075f * MUESTREO)];
        for (int i = 0; i < m.length; i++) {
            double t = i / MUESTREO;
            double f0 = tono * (1 - 0.06 * i / m.length);  // la voz baja un poquito al final
            double onda = 0;
            for (int k = 1; k * f0 < 3400; k++) {
                double f = k * f0;
                double peso = campana(f, formantes[0], 160) + 0.6 * campana(f, formantes[1], 220);
                onda += peso * Math.sin(2 * Math.PI * f * t);
            }
            m[i] = (float) (onda * suavizado(i, m.length));
        }
        return normalizar(m, 0.22f);
    }

    // Varias notas cortas seguidas, cada una "separacion" segundos despues
    // de la anterior. Cada nota es un seno con un armonico suave que se
    // apaga rapido, como una campanita de notificacion.
    private float[] notas(float[] frecuencias, float separacion, float volumen) {
        float duracionNota = 0.22f;
        float[] m = new float[(int) ((separacion * (frecuencias.length - 1) + duracionNota) * MUESTREO)];
        for (int n = 0; n < frecuencias.length; n++) {
            int desde = (int) (n * separacion * MUESTREO);
            int cuantas = (int) (duracionNota * MUESTREO);
            for (int i = 0; i < cuantas && desde + i < m.length; i++) {
                double t = i / MUESTREO;
                double onda = Math.sin(2 * Math.PI * frecuencias[n] * t)
                    + 0.3 * Math.sin(2 * Math.PI * frecuencias[n] * 2 * t);
                m[desde + i] += (float) (onda * Math.exp(-t * 14) * suavizado(i, cuantas));
            }
        }
        return normalizar(m, volumen);
    }

    // Un tono que sube rapido de grave a agudo con un poco de soplido
    // encima: suena a algo que sale volando.
    private float[] barrido() {
        float[] m = new float[(int) (0.32f * MUESTREO)];
        double fase = 0;
        for (int i = 0; i < m.length; i++) {
            double avance = i / (double) m.length;
            double f = 300 + 1500 * avance * avance;
            fase += 2 * Math.PI * f / MUESTREO;
            double envolvente = Math.sin(Math.PI * avance);
            m[i] = (float) ((Math.sin(fase) * 0.6 + (ruido.nextFloat() * 2 - 1) * 0.35) * envolvente);
        }
        return normalizar(m, 0.2f);
    }

    // --- Utilidades ---

    // Que tanto se parece f a "centro" (1 si es igual, casi 0 si esta lejos).
    private double campana(double f, double centro, double ancho) {
        double d = (f - centro) / ancho;
        return Math.exp(-d * d);
    }

    // Sube y baja el volumen en los bordes de un sonido para que no suene un
    // "clic" al empezar y al terminar.
    private double suavizado(int i, int total) {
        double borde = 0.008 * MUESTREO;
        return Math.min(1, Math.min(i / borde, (total - i) / borde));
    }

    private void agregarRuido(float[] m, float inicio, float duracion, float volumen) {
        int desde = (int) (inicio * MUESTREO);
        int cuantas = (int) (duracion * MUESTREO);
        for (int i = 0; i < cuantas && desde + i < m.length; i++) {
            float caida = 1 - i / (float) cuantas;
            m[desde + i] += (ruido.nextFloat() * 2 - 1) * volumen * caida;
        }
    }

    // Escala el sonido para que su punto mas alto quede en "volumen" (entre
    // 0 y 1). Asi todos los sonidos quedan parejos sin importar cuantas
    // ondas se sumaron para hacerlos.
    private float[] normalizar(float[] m, float volumen) {
        float maximo = 0;
        for (float v : m) {
            maximo = Math.max(maximo, Math.abs(v));
        }
        if (maximo > 0) {
            for (int i = 0; i < m.length; i++) {
                m[i] = m[i] / maximo * volumen;
            }
        }
        return m;
    }

    // Pasa las muestras (numeros entre -1 y 1) a 16 bits, que es el formato
    // que entiende la tarjeta de sonido, y las carga en un Clip.
    private Clip abrir(float[] m) throws Exception {
        byte[] datos = new byte[m.length * 2];
        for (int i = 0; i < m.length; i++) {
            short valor = (short) (m[i] * Short.MAX_VALUE);
            datos[i * 2] = (byte) (valor & 0xff);
            datos[i * 2 + 1] = (byte) ((valor >> 8) & 0xff);
        }
        AudioFormat formato = new AudioFormat(MUESTREO, 16, 1, true, false);
        Clip clip = AudioSystem.getClip();
        clip.open(formato, datos, 0, datos.length);
        return clip;
    }
}
