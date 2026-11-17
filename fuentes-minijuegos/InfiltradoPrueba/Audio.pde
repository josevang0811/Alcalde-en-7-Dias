import javax.sound.sampled.*;

// Musica dinamica y efectos de sonido, con javax.sound (viene con Java: no
// hace falta instalar ninguna libreria en Processing).
//
// Musica: cuatro pistas, una por momento de la mision:
//   0 calma    nadie sospecha
//   1 tension  un vigilante sospecha, un empleado huye o suena una radio
//   2 alerta   te persiguen, la policia viene o atraparon a un jugador
//   3 escape   ya copiaste el servidor y vas a salir
// Las cuatro suenan en un hilo aparte que las mezcla; al cambiar de momento
// una baja y la otra sube en 1,5 s (fundido). Cada pista sigue donde iba.
// Si hay archivos en data/musica/ (calma.wav, tension.wav, alerta.wav,
// escape.wav y opcional menu.wav) se usan esos; si no, la musica generada de
// data/musica_respaldo/.
// Efectos: WAV cortos de data/sfx/, cada uno con su volumen y tres copias para
// que puedan sonar encima de si mismos.

final int M_CALMA = 0, M_TENSION = 1, M_ALERTA = 2, M_ESCAPE = 3, M_MENU = 4;
final String[] PISTAS = {"calma", "tension", "alerta", "escape", "menu"};
final float VOLUMEN_MUSICA = 0.55;
final float VOLUMEN_EFECTOS = 0.8;

Musica musica;
HashMap<String, Clip[]> efectos = new HashMap<String, Clip[]>();
HashMap<String, Integer> turnoEfecto = new HashMap<String, Integer>();
boolean hayAudio = true;
boolean musicaPropia;   // se encontraron los archivos de data/musica/

// Volumen de cada efecto (los de onda cuadrada suenan mas fuerte)
String[] NOMBRES_EFECTO = {"paso", "paso_correr", "puerta", "negado", "tarjeta", "recoger", "botella", "lanzar",
  "noqueo", "radio", "radio_ok", "estatica", "alarma", "descubierto", "tecla", "codigo_ok", "codigo_mal",
  "copiando", "servidor_listo", "hackeo", "sombra", "interruptor", "ducto", "esconder", "foto", "aviso",
  "victoria", "derrota", "empujar", "pitido_camara", "telefono", "auricular"};
float[] VOLUMEN_EFECTO = {0.25, 0.35, 0.7, 0.35, 0.5, 0.7, 0.9, 0.6,
  0.9, 0.5, 0.5, 0.6, 0.35, 0.8, 0.4, 0.6, 0.4,
  0.4, 0.7, 0.6, 0.7, 0.7, 0.7, 0.8, 0.8, 0.3,
  0.8, 0.8, 0.8, 0.4, 0.55, 0.45};

void iniciarAudio() {
  try {
    for (int k = 0; k < NOMBRES_EFECTO.length; k++) cargarEfecto(NOMBRES_EFECTO[k], VOLUMEN_EFECTO[k] * VOLUMEN_EFECTOS);
    musica = new Musica();
    Thread hilo = new Thread(musica);
    hilo.setDaemon(true);
    hilo.start();
  } catch (Exception e) {
    hayAudio = false;
    println("Sin sonido: " + e.getMessage());
  }
}

// Lee un WAV de 16 bits como muestras entre -1 y 1 (mono)
float[] leerWav(String ruta) throws Exception {
  java.io.File f = new java.io.File(ruta);
  if (!f.exists()) return null;
  AudioInputStream ais = AudioSystem.getAudioInputStream(f);
  AudioFormat fmt = ais.getFormat();
  byte[] b = ais.readAllBytes();
  ais.close();
  int canales = fmt.getChannels();
  int n = b.length / (2 * canales);
  float[] x = new float[n];
  boolean grande = fmt.isBigEndian();
  for (int i = 0; i < n; i++) {
    float suma = 0;
    for (int c = 0; c < canales; c++) {
      int p = (i * canales + c) * 2;
      int v = grande ? (b[p] << 8) | (b[p + 1] & 0xff) : (b[p + 1] << 8) | (b[p] & 0xff);
      suma += v / 32768.0;
    }
    x[i] = suma / canales;
  }
  return x;
}

// Igual que leerWav pero guarda las muestras en short (para la musica)
short[] leerWavCorto(String ruta) throws Exception {
  java.io.File f = new java.io.File(ruta);
  if (!f.exists()) return null;
  AudioInputStream ais = AudioSystem.getAudioInputStream(f);
  AudioFormat fmt = ais.getFormat();
  byte[] b = ais.readAllBytes();
  ais.close();
  int canales = fmt.getChannels();
  int n = b.length / (2 * canales);
  short[] x = new short[n];
  boolean grande = fmt.isBigEndian();
  for (int i = 0; i < n; i++) {
    int suma = 0;
    for (int c = 0; c < canales; c++) {
      int p = (i * canales + c) * 2;
      suma += grande ? (b[p] << 8) | (b[p + 1] & 0xff) : (b[p + 1] << 8) | (b[p] & 0xff);
    }
    x[i] = (short) (suma / canales);
  }
  return x;
}

void cargarEfecto(String nombre, float volumen) throws Exception {
  float[] x = leerWav(dataPath("sfx/" + nombre + ".wav"));
  if (x == null) return;
  byte[] b = new byte[x.length * 2];
  for (int i = 0; i < x.length; i++) {
    int v = (int) constrain(x[i] * volumen * 32767, -32768, 32767);
    b[2 * i] = (byte) (v & 0xff);
    b[2 * i + 1] = (byte) ((v >> 8) & 0xff);
  }
  AudioFormat fmt = new AudioFormat(22050, 16, 1, true, false);
  Clip[] copias = new Clip[3];
  for (int k = 0; k < 3; k++) {
    copias[k] = AudioSystem.getClip();
    copias[k].open(fmt, b, 0, b.length);
  }
  efectos.put(nombre, copias);
  turnoEfecto.put(nombre, 0);
}

void sonar(String nombre) {
  if (!hayAudio) return;
  Clip[] copias = efectos.get(nombre);
  if (copias == null) return;
  int k = turnoEfecto.get(nombre);
  turnoEfecto.put(nombre, (k + 1) % copias.length);
  Clip c = copias[k];
  c.stop();
  c.setFramePosition(0);
  c.start();
}

// Que momento de la musica toca segun lo que pasa en la mision
int momentoMusica() {
  if (estado == INICIO || estado == ELEGIR_ROL || estado == CREDITOS || estado == LLAMADA) return M_MENU;
  if (estado == RECONOCIMIENTO) return M_CALMA;
  if (estado == GANASTE) return M_ESCAPE;
  if (estado == PERDISTE) return M_TENSION;
  boolean alerta = nivelAlarma >= 3;
  boolean tension = false;
  for (Vigilante v : vigilantes) {
    if (v.inconsciente) {
      if (v.radioSonando > 0) tension = true;
      continue;
    }
    if (v.estado == V_ALERTA) alerta = true;
    else if (v.estado != V_PATRULLA) tension = true;
  }
  for (Civil c : civiles) if (c.estado == C_HUYENDO) tension = true;
  for (Jugador j : jugadores) if (j.atrapado) alerta = true;
  if (alerta) return M_ALERTA;
  if (servidorCopiado) return M_ESCAPE;
  if (tension) return M_TENSION;
  return M_CALMA;
}

void actualizarMusica() {
  if (musica != null) musica.momento = momentoMusica();
}

// Mezclador de la musica en su propio hilo
class Musica implements Runnable {
  final int FRECUENCIA = 22050;
  short[][] pistas = new short[5][];   // en short y no en float: las canciones son largas y asi ocupan la mitad
  int[] posicion = new int[5];
  float[] ganancia = new float[5];
  volatile int momento = M_MENU;
  volatile float atenuar = 1;   // baja la musica mientras habla Valeria
  volatile float volumenUsuario = 1;   // el de Opciones (Alcalde Digital)
  float atenuacion = 1;

  Musica() throws Exception {
    musicaPropia = false;
    for (int k = 0; k < 5; k++) {
      short[] propia = leerWavCorto(dataPath("musica/" + PISTAS[k] + ".wav"));
      if (propia != null) musicaPropia = true;   // basta con una canción propia
      pistas[k] = propia != null ? propia : leerWavCorto(dataPath("musica_respaldo/" + PISTAS[k] + ".wav"));
    }
    // sin pista de menu: se usa la de calma
    if (pistas[M_MENU] == null) pistas[M_MENU] = pistas[M_CALMA];
  }

  public void run() {
    try {
      AudioFormat fmt = new AudioFormat(FRECUENCIA, 16, 1, true, false);
      SourceDataLine linea = AudioSystem.getSourceDataLine(fmt);
      int bloque = 1024;
      linea.open(fmt, bloque * 8);
      linea.start();
      byte[] salida = new byte[bloque * 2];
      float pasoFundido = bloque / (1.5 * FRECUENCIA);   // 1,5 s de fundido
      while (true) {
        int m = momento;
        atenuacion += constrain(atenuar - atenuacion, -0.03, 0.03);
        for (int k = 0; k < 5; k++) {
          float meta = k == m ? 1 : 0;
          ganancia[k] += constrain(meta - ganancia[k], -pasoFundido, pasoFundido);
        }
        for (int i = 0; i < bloque; i++) {
          float v = 0;
          for (int k = 0; k < 5; k++) {
            if (ganancia[k] <= 0.001 || pistas[k] == null) continue;
            // la de menu comparte datos con calma: no se avanza dos veces
            if (k == M_MENU && pistas[M_MENU] == pistas[M_CALMA]) {
              v += pistas[M_CALMA][posicion[M_CALMA] % pistas[M_CALMA].length] / 32768.0 * ganancia[k] * 0.7;
              continue;
            }
            v += pistas[k][posicion[k]] / 32768.0 * ganancia[k];
            posicion[k] = (posicion[k] + 1) % pistas[k].length;
          }
          if (ganancia[M_MENU] > 0.001 && pistas[M_MENU] == pistas[M_CALMA] && ganancia[M_CALMA] <= 0.001) {
            posicion[M_CALMA] = (posicion[M_CALMA] + 1) % pistas[M_CALMA].length;
          }
          int s = (int) constrain(v * VOLUMEN_MUSICA * volumenUsuario * atenuacion * 32767, -32768, 32767);
          salida[2 * i] = (byte) (s & 0xff);
          salida[2 * i + 1] = (byte) ((s >> 8) & 0xff);
        }
        linea.write(salida, 0, salida.length);
      }
    } catch (Exception e) {
      println("La música no pudo sonar: " + e.getMessage());
    }
  }
}
