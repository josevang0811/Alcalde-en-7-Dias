// Valeria: la estratega de la campana que guia al candidato por el auricular.
// No tiene frases grabadas: cada vez que pasa algo importante el juego arma
// un resumen de la mision (donde estas, que falta, la alarma, los vigilantes
// y lo ultimo que ella dijo) y se lo manda a un modelo de lenguaje (Claude),
// que escribe la frase. Despues la frase se convierte en voz (Azure, voz
// colombiana) y suena con un filtro de radio, con subtitulo en el HUD.
//
//   evento -> cola de prioridad -> resumen -> Claude -> texto -> Azure -> voz
//
// Las llamadas a internet van en un hilo aparte para que el juego no se
// trabe. Sin claves o sin internet usa frases de respaldo (solo texto).
// Las claves van en data/valeria.txt (no se comparte ese archivo).
//
// Para no hablar de mas:
//   - Los eventos entran a una cola de prioridad (alarma > pista > consejo).
//   - Entre una frase y otra hay una pausa minima; lo urgente espera menos.
//   - Cada tipo de evento tiene su propio tiempo de espera.
//   - Un evento viejo (que ya no tiene sentido comentar) se descarta.

final int LLAMADA = 7;
final color COLOR_VALERIA = #C08CFF;
final float PAUSA_VALERIA = 9;          // segundos minimos entre frases
final float PAUSA_URGENTE = 1.5;        // si el evento es de prioridad 3
final int FALLOS_PARA_RESPALDO = 3;     // tras 3 errores seguidos deja de intentar

final String PERSONA_VALERIA =
  "Eres Valeria, la estratega digital de la campaña de un candidato a la alcaldía. " +
  "Esta noche lo guías por un auricular mientras él se mete a escondidas a la sede de Titulares Ya, " +
  "la agencia que fabrica bulos contra él, para copiar su servidor y salir sin que lo vean.\n" +
  "Cómo hablas:\n" +
  "- Español neutro. Tuteas al candidato (tú, nunca vos). Sin groserías.\n" +
  "- Una o dos frases, máximo 22 palabras en total: es por radio, corto y claro.\n" +
  "- El tono va con el momento: urgente si lo persiguen, tranquila si todo va bien, a veces con humor seco.\n" +
  "- Usa solo los datos que te pasan. No inventes cuartos, objetos, códigos, nombres ni personas.\n" +
  "- Nunca digas dígitos del código que no estén en los datos.\n" +
  "- Si das un consejo, que sea uno solo y concreto, basado en el siguiente paso que te pasan.\n" +
  "- Comenta solo lo que acaba de pasar y qué hacer justo con eso. No repitas la lista de objetivos ni cosas que el candidato ya sabe.\n" +
  "- No hables de las botellas a menos que el evento las mencione.\n" +
  "- No repitas lo que ya dijiste.\n" +
  "- Sin emojis, comillas, asteriscos ni acotaciones: solo lo que dices.";

// ---------------------------------------------------------------- claves

// proveedor del modelo que escribe: "groq" (API compatible con OpenAI) o "claude"
String proveedorIA = "groq";
String claveClaude = "", modeloClaude = "claude-haiku-5-5";
String claveGroq = "", modeloGroq = "openai/gpt-oss-20b";
String claveAzure = "", regionAzure = "eastus", vozAzure = "es-CO-SalomeNeural";
// la voz de Marta, la periodista que llama cada turno (Alcalde Digital)
String vozPeriodista = "es-MX-DaliaNeural";
boolean valeriaActiva = true, efectoRadio = true;
// Por ahora Valeria usa frases programadas segun lo que pasa (Jose, 25-10).
// La IA y la voz quedan listas para el mundo abierto: usar_ia=si en valeria.txt.
boolean usarIA = false;
// La voz (Azure) si se usa con las frases programadas: usar_voz=si. Cada frase
// se guarda en data/voz/ la primera vez, asi despues suena sin internet.
boolean usarVoz = true;
int fallosSeguidos;
// Si internet falla, durante un rato no se vuelve a intentar: Valeria habla
// con sus frases de respaldo y las voces ya guardadas, sin hacer esperar.
volatile long sinRedHasta = 0;
final int SEGUNDOS_SIN_RED = 40;

boolean hayRed() {
  return System.currentTimeMillis() > sinRedHasta;
}

void marcarSinRed(Exception e) {
  // los errores de conexión y de tiempo agotado cuentan; un error HTTP no
  if (e instanceof java.io.IOException) sinRedHasta = System.currentTimeMillis() + SEGUNDOS_SIN_RED * 1000L;
}

void leerConfigValeria() {
  String[] lineas = null;
  try {
    if (new java.io.File(dataPath("valeria.txt")).exists()) lineas = loadStrings("valeria.txt");
  } catch (Exception e) {
    lineas = null;
  }
  if (lineas == null) return;
  for (String l : lineas) {
    l = trim(l);
    if (l.length() == 0 || l.charAt(0) == '#' || l.indexOf('=') < 0) continue;
    String clave = trim(l.substring(0, l.indexOf('=')));
    String valor = trim(l.substring(l.indexOf('=') + 1));
    if (clave.equals("proveedor") && valor.length() > 0) proveedorIA = valor.toLowerCase();
    if (clave.equals("groq_clave")) claveGroq = valor;
    if (clave.equals("groq_modelo") && valor.length() > 0) modeloGroq = valor;
    if (clave.equals("claude_clave")) claveClaude = valor;
    if (clave.equals("claude_modelo") && valor.length() > 0) modeloClaude = valor;
    if (clave.equals("azure_clave")) claveAzure = valor;
    if (clave.equals("azure_region") && valor.length() > 0) regionAzure = valor;
    if (clave.equals("azure_voz") && valor.length() > 0) vozAzure = valor;
    if (clave.equals("azure_voz_periodista") && valor.length() > 0) vozPeriodista = valor;
    if (clave.equals("activa")) valeriaActiva = !valor.equals("no");
    if (clave.equals("usar_ia")) usarIA = valor.equals("si");
    if (clave.equals("usar_voz")) usarVoz = !valor.equals("no");
    if (clave.equals("efecto_radio")) efectoRadio = !valor.equals("no");
  }
  println("Valeria: " + (valeriaConIA() ? "con IA (" + proveedorIA + ", " + modeloIA() + ")" : "frases de respaldo") +
    (valeriaConVoz() ? ", voz " + vozAzure : ", sin voz" + (claveAzure.length() > 10 ? "" : " (falta azure_clave)")));
}

boolean valeriaConIA() {
  String clave = proveedorIA.equals("claude") ? claveClaude : claveGroq;
  return usarIA && clave.length() > 10 && fallosSeguidos < FALLOS_PARA_RESPALDO && hayRed();
}

String modeloIA() {
  return proveedorIA.equals("claude") ? modeloClaude : modeloGroq;
}

boolean valeriaConVoz() {
  return (usarIA || usarVoz) && claveAzure.length() > 10;
}

// ---------------------------------------------------------------- eventos

class EventoValeria {
  String tipo;       // "alarma", "pista", "consejo"...
  int prioridad;     // 0 a 3
  String detalle;    // lo que paso, en palabras, para el modelo
  String fija;       // frase programada para este evento (o null: una del tipo)
  float cuando;      // segundos reales (millis) en que paso

  EventoValeria(String tipo, int prioridad, String detalle) {
    this.tipo = tipo;
    this.prioridad = prioridad;
    this.detalle = detalle;
    cuando = millis() / 1000.0;
  }

  float edad() {
    return millis() / 1000.0 - cuando;
  }

  // despues de este tiempo ya no vale la pena comentarlo
  float vida() {
    return prioridad >= 3 ? 12 : 8;
  }
}

// Cola de prioridad: primero la prioridad mas alta y, a igual prioridad, el
// mas reciente
java.util.PriorityQueue<EventoValeria> colaValeria = new java.util.PriorityQueue<EventoValeria>(16,
  new java.util.Comparator<EventoValeria>() {
  public int compare(EventoValeria a, EventoValeria b) {
    if (a.prioridad != b.prioridad) return b.prioridad - a.prioridad;
    return Float.compare(b.cuando, a.cuando);
  }
}
);

// Tiempo minimo entre dos eventos del mismo tipo
HashMap<String, Float> ultimoDeTipo = new HashMap<String, Float>();
String[] TIPOS_ESPERA = {"sospecha", "persecucion", "escapo", "consejo", "botin", "noqueo", "oportunidad"};
float[] SEGUNDOS_ESPERA = {40, 25, 30, 60, 45, 30, 30};

void eventoValeria(String tipo, int prioridad, String detalle) {
  eventoValeria(tipo, prioridad, detalle, null);
}

// fija: la frase que dice Valeria en el modo de frases programadas
void eventoValeria(String tipo, int prioridad, String detalle, String fija) {
  if (!valeriaActiva || estado == GANASTE || estado == PERDISTE) return;
  float ahora = millis() / 1000.0;
  int k = java.util.Arrays.asList(TIPOS_ESPERA).indexOf(tipo);
  if (k >= 0 && ultimoDeTipo.containsKey(tipo) && ahora - ultimoDeTipo.get(tipo) < SEGUNDOS_ESPERA[k]) return;
  ultimoDeTipo.put(tipo, ahora);
  // un solo evento de cada tipo en la cola: el nuevo reemplaza al viejo
  java.util.Iterator<EventoValeria> it = colaValeria.iterator();
  while (it.hasNext()) if (it.next().tipo.equals(tipo)) it.remove();
  EventoValeria ev = new EventoValeria(tipo, prioridad, detalle);
  ev.fija = fija;
  colaValeria.add(ev);
}

// ---------------------------------------------------------------- estado

// Lo que se miro en el cuadro anterior, para notar los cambios
boolean[] vTarj = new boolean[5];
int vAlarma, vTarjetas, vDigitos, vNoqueos, vBotin, vOportVistas, vOportHechas;
boolean vAlerta, vSospecha, vServidor, vPistaA, vPistaR, vDisfraz, vAtrapado;
int vEstado = -1;
float sinAlerta, quieto;

// La frase que se esta diciendo
String fraseValeria = "";
float tiempoFrase, duracionFrase, finUltimaFrase = -99;
Clip vozActual;
StringList dichas = new StringList();   // lo ultimo que dijo (para no repetir)
boolean esperandoValeria;               // hay un pedido en camino
volatile RespuestaValeria respuestaLista;
PImage caraValeria;
PGraphics capaValeria;

class RespuestaValeria {
  EventoValeria ev;  // el evento que se está comentando
  String texto;
  Clip voz;
  float segundos;
}

void iniciarValeria() {
  leerConfigValeria();
  caraValeria = loadImage("valeria.png");
  capaValeria = createGraphics(300, 52);
  capaValeria.noSmooth();
}

void reiniciarValeria() {
  colaValeria.clear();
  ultimoDeTipo.clear();
  dichas.clear();
  callarValeria();
  vEstado = -1;
}

// Para la voz que suena y la cierra: cada frase trae su propio Clip y no
// se vuelve a usar.
void soltarVoz() {
  if (vozActual != null) {
    vozActual.stop();
    vozActual.close();
  }
  vozActual = null;
}

void callarValeria() {
  soltarVoz();
  fraseValeria = "";
  respuestaLista = null;
  esperandoValeria = false;
  if (musica != null) musica.atenuar = 1;
}

int tarjetasTenidas() {
  int n = 0;
  for (int k = 1; k <= 3; k++) if (tarjetas[k]) n++;
  return n;
}

int digitosConocidos() {
  int n = 0;
  for (boolean b : digitoConocido) if (b) n++;
  return n;
}

int botinLlevado() {
  int n = 0;
  for (Jugador j : jugadores) n += j.valorBotin;
  return n;
}

// Cada cuadro: mira que cambio y lo vuelve evento
void detectarEventosValeria(float dt) {
  if (estado != vEstado) {
    if (estado == JUGANDO && vEstado == RECONOCIMIENTO) {
      eventoValeria("inicio", 2, "El candidato acaba de entrar a la sede. Dale ánimo y un recordatorio corto.");
    }
    // al terminar la mision (ganes o pierdas) se calla
    if (estado == GANASTE || estado == PERDISTE) {
      callarValeria();
      colaValeria.clear();
    }
    vEstado = estado;
    leerEstadoValeria();
    return;
  }
  if (estado != JUGANDO || mapaAbierto) return;

  boolean alerta = false, sospecha = false, jefeAlerta = false;
  for (Vigilante v : vigilantes) {
    if (v.inconsciente) continue;
    if (v.estado == V_ALERTA) {
      alerta = true;
      if (v.esJefe) jefeAlerta = true;
    } else if (v.estado != V_PATRULLA) sospecha = true;
  }
  boolean atrapado = false, disfraz = false;
  for (Jugador j : jugadores) {
    if (j.atrapado) atrapado = true;
    if (j.disfrazado) disfraz = true;
  }
  int oVistas = 0, oHechas = oportunidadesHechas();
  for (boolean b : oportunidadVista) if (b) oVistas++;
  boolean algo = false;   // ya se genero un evento en este cuadro

  if (nivelAlarma > vAlarma) {
    eventoValeria("alarma", 3, "La alarma subió a nivel " + nivelAlarma + " (" + NOMBRES_ALARMA[nivelAlarma] + "). Motivo: " + aviso +
      (nivelAlarma == 2 ? ". Prendieron las luces y cerraron la entrada principal." : "") +
      (nivelAlarma == 3 ? ". La policía viene en camino: hay que salir ya." : ""));
    algo = true;
  }
  if (atrapado && !vAtrapado) {
    eventoValeria("atrapado", 3, jugadores.size() > 1 ? "Atraparon a uno de los dos; el otro puede rescatarlo." : "Atraparon al candidato.");
    algo = true;
  }
  if (alerta && !vAlerta) {
    eventoValeria("persecucion", 3, (jefeAlerta ? "El jefe de seguridad" : "Un vigilante") + " vio al candidato y lo persigue.");
    algo = true;
  }
  // cuando pasan 4 s sin que nadie lo persiga, lo perdieron
  if (alerta) {
    alertaReciente = true;
    sinAlerta = 0;
  } else {
    sinAlerta += dt;
    if (alertaReciente && sinAlerta > 4) {
      eventoValeria("escapo", 2, "Los vigilantes le perdieron el rastro al candidato.");
      alertaReciente = false;
    }
  }
  if (sospecha && !vSospecha && !alerta) {
    eventoValeria("sospecha", 2, "Un vigilante notó algo raro y está sospechando, pero todavía no lo ha visto bien." +
      (jugadores.get(0).botellas > 0 ? " Tiene " + jugadores.get(0).botellas + " botellas: lanzar una lejos manda al vigilante hacia el ruido." : ""),
      jugadores.get(0).botellas > 0 ? "¡Te está mirando! Lanza una botella lejos con la Q o escóndete." : "¡Te está mirando! Aléjate o escóndete ya.");
    algo = true;
  }
  if (servidorCopiado && !vServidor) {
    eventoValeria("servidor", 3, "¡Copió el servidor! Ya solo queda escapar. Salidas que sirven ahora: " + salidasQueSirven() + ".",
      "¡Lo tienes! Ahora sal de ahí. Te sirven " + salidasQueSirven() + ".");
    algo = true;
  }
  // tarjeta nueva: que diga para que sirve y que la busque en el mapa
  String[] queAbre = {"",
    "la puerta de carga del parqueadero (es otra salida y otro camino para entrar)",
    "el cuarto de Seguridad, donde la consola deja apagar cámaras, borrar grabaciones o vigilar las pantallas",
    "la Oficina del rival, donde puede leer el chat del rival y descubrir oportunidades"};
  int[] zonaQueAbre = {-1, -1, 4, 7};
  String[] colorTarjeta = {"", "roja", "azul", "amarilla"};
  for (int k = 1; k <= 3; k++) {
    if (tarjetas[k] && !vTarj[k]) {
      if (zonaQueAbre[k] >= 0) resalteZona[zonaQueAbre[k]] = 25;   // parpadea en el mapa
      String[] fijas = {"",
        "La tarjeta roja abre la puerta de carga del parqueadero: otra salida si la entrada se complica.",
        "La azul abre el cuarto de Seguridad. Abre el mapa con la G, está parpadeando. Desde la consola apagas las cámaras.",
        "La amarilla abre la oficina del rival. Mírala en el mapa con la G y lee su chat."};
      eventoValeria("tarjeta", 2, "Recogió la tarjeta " + colorTarjeta[k] + ". Abre " + queAbre[k] +
        ". Dile para qué le sirve y que abra el mapa con la G para ubicar ese cuarto" + (zonaQueAbre[k] >= 0 ? ", que ahora está parpadeando." : "."), fijas[k]);
      algo = true;
    }
  }
  if (digitosConocidos() > vDigitos) {
    if (digitosConocidos() == 4) {
      resalteZona[6] = 25;
      eventoValeria("codigo", 2, "Ya tiene el código completo del Cuarto del servidor: " + codigoConocido() +
        ". Ya puede entrar (en el mapa con G está parpadeando), pero copiar el servidor es lo último que se hace: después solo queda escapar.",
        "Código completo: " + codigoConocido() + ". El cuarto del servidor parpadea en el mapa. Cópialo de último, luego solo queda salir.");
    } else {
      eventoValeria("codigo", 2, "Descubrió dígitos del código del Cuarto del servidor. Código conocido: " + codigoConocido() +
        (digitoConocido[0] ? ". Los dígitos que faltan se escuchan en una conversación de los empleados." : ". Los que faltan están anotados en el Archivo."),
        digitoConocido[0] ? "Tenemos la mitad del código. La otra mitad la dicen los empleados cuando conversan: acércate a escuchar." : "Ya sabemos el final del código. El resto está anotado en el Archivo.");
    }
    algo = true;
  }
  if ((pistaAmarilla && !vPistaA) || (pistaRoja && !vPistaR)) {
    eventoValeria("pista", 2, "Escuchó una conversación con una pista: " + aviso);
    algo = true;
  }
  if (disfraz && !vDisfraz) {
    eventoValeria("disfraz", 2, "Se puso el uniforme de conserje. Los vigilantes normales no lo reconocen salvo que esté pegado a ellos; el jefe de seguridad sí lo reconoce de cerca.",
      "Con ese uniforme pasas por cualquier cuarto. No corras, no te agaches y no te acerques al jefe de gorra blanca.");
    algo = true;
  }
  if (noqueos > vNoqueos) {
    eventoValeria("noqueo", 1, "Noqueó a alguien. Conviene esconder el cuerpo: si lo encuentran sube la alarma.");
    algo = true;
  }
  if (botinLlevado() > vBotin) {
    eventoValeria("botin", 1, "Guardó botín en la mochila. Lleva " + botinLlevado() + " puntos; lo mejor que cabe en la mochila es " + mejorBotin +
      ". Cada objeto vale distinto a lo que pesa (documento 1 kg = 2, disco duro 2 kg = 5, portátil 3 kg = 6), así que conviene elegir bien; con X suelta lo último que guardó.",
      botinLlevado() >= mejorBotin ? "Ese es el mejor botín que cabe. Ya no cargues más." :
      "Llevas " + botinLlevado() + " de " + mejorBotin + " posibles. Lo que más vale por kilo es el disco duro.");
    algo = true;
  }
  if (oVistas > vOportVistas || oHechas > vOportHechas) {
    eventoValeria("oportunidad", 1, aviso);
    algo = true;
  }

  // si se queda quieto un rato sin peligro, un consejo
  boolean seMueve = false;
  for (Jugador j : jugadores) if (j.moviendose) seMueve = true;
  quieto = seMueve || alerta || sospecha ? 0 : quieto + dt;
  if (quieto > 45) {
    quieto = 0;
    String paso = siguientePaso();
    eventoValeria("consejo", 0, "El candidato lleva rato quieto. Dale un consejo concreto sobre qué hacer ahora.",
      "¿Seguimos? Lo que falta: " + paso);
  }
  vAlerta = alerta;
  vSospecha = sospecha;
  vAtrapado = atrapado;
  vDisfraz = disfraz;
  vOportVistas = oVistas;
  vOportHechas = oHechas;
  vAlarma = nivelAlarma;
  vServidor = servidorCopiado;
  vTarjetas = tarjetasTenidas();
  vTarj = tarjetas.clone();
  vDigitos = digitosConocidos();
  vPistaA = pistaAmarilla;
  vPistaR = pistaRoja;
  vNoqueos = noqueos;
  vBotin = botinLlevado();
}

boolean alertaReciente;

void leerEstadoValeria() {
  vAlarma = nivelAlarma;
  vServidor = servidorCopiado;
  vTarjetas = tarjetasTenidas();
  vTarj = tarjetas.clone();
  vDigitos = digitosConocidos();
  vPistaA = pistaAmarilla;
  vPistaR = pistaRoja;
  vNoqueos = noqueos;
  vBotin = botinLlevado();
  vAlerta = false;
  vSospecha = false;
  vAtrapado = false;
  vDisfraz = false;
  alertaReciente = false;
  quieto = 0;
}

String salidasQueSirven() {
  String[] nombres = {"la camioneta de la entrada", "la moto del fondo del parqueadero", "el ducto a la calle"};
  String s = "";
  for (int k = 0; k < 3; k++) {
    String b = bloqueoSalida(k);
    if (b.equals("") || b.startsWith("Espera")) s += (s.equals("") ? "" : ", ") + nombres[k];
  }
  return s.equals("") ? "ninguna por ahora" : s;
}

// ---------------------------------------------------------------- resumen

// Lo que Valeria sabe de la mision en este momento
String resumenMision(boolean conPlan) {
  Jugador j = jugadores.get(0);
  StringBuilder s = new StringBuilder();
  s.append("- Hora: ").append(horaTexto()).append("; jugadores: ").append(jugadores.size()).append(".\n");
  s.append("- El candidato está en: ").append(NOMBRES_ZONA[mapa.zonaEn(j.x, j.y)]).append(". Postura: ").append(j.postura())
    .append(j.escondido ? " (escondido)" : "").append(j.enDucto ? " (dentro de un ducto)" : "").append(".\n");
  s.append("- Alarma: nivel ").append(nivelAlarma).append(" de 3 (").append(NOMBRES_ALARMA[nivelAlarma]).append(")");
  if (nivelAlarma == 3) s.append(", la policía llega en ").append(ceil(max(0, tiempoPolicia))).append(" s");
  s.append(".\n");
  s.append("- Vigilantes: ").append(resumenVigilantes(j)).append(".\n");
  String t = "";
  String[] nt = {"", "roja", "azul", "amarilla"};
  for (int k = 1; k <= 3; k++) t += (tarjetas[k] ? "tiene la " : "le falta la ") + nt[k] + (k < 3 ? ", " : "");
  s.append("- Tarjetas: ").append(t).append(". La roja abre la puerta de carga, la azul el cuarto de seguridad y la amarilla la oficina del rival.\n");
  s.append("- Código del servidor que conoce: ").append(codigoConocido()).append(" (\"_\" es lo que falta).\n");
  s.append("- Botín: ").append(botinLlevado()).append(" puntos (lo mejor que cabe: ").append(mejorBotin).append("), mochila ").append(j.peso).append(" de ").append(CAPACIDAD_MOCHILA).append(" kg. Oportunidades hechas: ")
    .append(oportunidadesHechas()).append(" de 3.\n");
  s.append("- Servidor copiado: ").append(servidorCopiado ? "sí, ahora solo hay que escapar" : "no (es lo último que se hace)").append(".\n");
  String pistas = "";
  if (pistaAmarilla && !tarjetas[3]) pistas += "la tarjeta amarilla está en el descanso, junto a la cafetera. ";
  if (pistaRoja && !tarjetas[1]) pistas += "la tarjeta roja está en la caseta del parqueadero. ";
  if (digitoConocido[2] && !digitoConocido[0]) pistas += "los dos primeros dígitos están anotados en el archivo. ";
  if (!pistas.equals("")) s.append("- Pistas escuchadas: ").append(pistas).append("\n");
  if (conPlan) s.append("- Siguiente paso: ").append(siguientePaso()).append("\n");
  return s.toString();
}

String resumenVigilantes(Jugador j) {
  int patrulla = 0, dudan = 0, alerta = 0, ko = 0;
  float cerca = 999;
  for (Vigilante v : vigilantes) {
    if (v.inconsciente) {
      ko++;
      continue;
    }
    if (v.estado == V_ALERTA) alerta++;
    else if (v.estado == V_PATRULLA) patrulla++;
    else dudan++;
    cerca = min(cerca, dist(v.x, v.y, j.x, j.y));
  }
  String s = patrulla + " en su ronda, " + dudan + " sospechando o buscando, " + alerta + " persiguiéndolo";
  if (ko > 0) s += ", " + ko + " noqueados";
  if (cerca < 999) s += "; el más cercano está a " + round(cerca) + " pasos";
  return s;
}

String siguientePaso() {
  if (soloEscapar()) return "escapar por " + salidasQueSirven() + ".";
  if (nivelAlarma == 3) return "salir cuanto antes, la policía viene.";
  String falta = "";
  if (botinLlevado() < mejorBotin) falta += "elegir bien el botín (lo que más vale por kilo es el disco duro), ";
  if (!tarjetas[3]) falta += pistaAmarilla ? "ir por la tarjeta amarilla al descanso, " : "conseguir la tarjeta amarilla (escuchar conversaciones ayuda), ";
  else if (!chatLeido) falta += "leer el chat del rival en su oficina, ";
  if (digitosConocidos() < 4) falta += "completar el código del servidor, ";
  if (falta.equals("")) return "ir al cuarto del servidor, marcar el código y copiarlo.";
  return falta + "y al final copiar el servidor.";
}

// ---------------------------------------------------------------- respaldo

HashMap<String, String[]> respaldo = new HashMap<String, String[]>();

void prepararRespaldo() {
  respaldo.put("inicio", new String[] {"Ya estás adentro. Respira y muévete despacio.", "Bien, entraste. Ojo con las cámaras."});
  respaldo.put("sospecha", new String[] {"Alguien notó algo. Agáchate y no te muevas.", "Ese vigilante está dudando. Quédate quieto."});
  respaldo.put("persecucion", new String[] {"¡Te vieron! Corre y busca dónde esconderte.", "¡Te están siguiendo! Rompe la línea de vista."});
  respaldo.put("escapo", new String[] {"Te perdieron. Buen trabajo, sigue con calma.", "Listo, ya no te buscan. Despacio otra vez."});
  respaldo.put("alarma", new String[] {"La alarma subió. Van a estar más atentos.", "Subió la alarma. Cuidado, ahora miran más."});
  respaldo.put("atrapado", new String[] {"¡Te atraparon! Aguanta.", "No, no, no... te tienen."});
  respaldo.put("servidor", new String[] {"¡Lo tienes! Ahora sal de ahí.", "Servidor copiado. Busca una salida, ya."});
  respaldo.put("tarjeta", new String[] {"Esa tarjeta abre un cuarto nuevo. Búscalo en el mapa con la G.", "Bien, otra puerta abierta. Mira el mapa con la G."});
  respaldo.put("codigo", new String[] {"Anota esos números, los vamos a necesitar.", "Ya sabemos más del código."});
  respaldo.put("pista", new String[] {"¿Oíste eso? Revisa el mapa con la G.", "Esa conversación nos sirve. Mira el mapa."});
  respaldo.put("disfraz", new String[] {"Con ese uniforme pasas, pero no te acerques al jefe.", "Buen disfraz. Al jefe no lo engañas de cerca."});
  respaldo.put("noqueo", new String[] {"Escóndelo antes de que alguien lo vea.", "Uno menos. Ahora esconde el cuerpo."});
  respaldo.put("botin", new String[] {"Eso nos sirve. Cuida el peso de la mochila.", "Bien, eso va para las pruebas."});
  respaldo.put("oportunidad", new String[] {"Eso también nos ayuda.", "Buena esa."});
  respaldo.put("consejo", new String[] {"Revisa el mapa con la G si estás perdido.", "No te quedes ahí mucho tiempo."});
  respaldo.put("final", new String[] {"Bueno, ya pasó. Hablamos en la mañana.", "Gracias por arriesgarte, candidato."});
}

// Graba de una vez (en otro hilo) las frases fijas que aún no están en
// data/voz/, para que después suenen aunque no haya internet. Solo se piden
// las que faltan, así que después de la primera vez no gasta nada.
void precargarVoces(String[] extra) {
  if (!valeriaConVoz()) return;
  final StringList frases = new StringList();
  for (String[] op : respaldo.values()) for (String f : op) frases.append(f);
  frases.append("En ese casillero hay uniformes de conserje. Póntelo con E: así casi nadie te reconoce.");
  if (extra != null) for (String f : extra) frases.append(f);
  Thread h = new Thread(new Runnable() {
    public void run() {
      int nuevas = 0;
      for (String f : frases) {
        if (!hayRed()) return;
        java.io.File g = new java.io.File(dataPath("voz/" + vozAzure + "_" + Integer.toHexString(f.hashCode()) + ".wav"));
        if (g.exists()) continue;
        try {
          vozDeAzure(f).close();
          nuevas++;
        } catch (Exception e) {
          marcarSinRed(e);
        }
      }
      if (nuevas > 0) println("Valeria: " + nuevas + " voces nuevas guardadas en data/voz/");
    }
  });
  h.setDaemon(true);
  h.start();
}

String fraseDeRespaldo(String tipo) {
  String[] op = respaldo.get(tipo);
  if (op == null) return null;
  // la que no se haya dicho hace poco
  for (int intento = 0; intento < 4; intento++) {
    String f = op[int(random(op.length))];
    if (!dichas.hasValue(f)) return f;
  }
  return op[0];
}

// ---------------------------------------------------------------- cuadro

void actualizarValeria(float dt) {
  if (!valeriaActiva || estado == LLAMADA) return;
  detectarEventosValeria(dt);
  float ahora = millis() / 1000.0;

  // la mision termino (ganaste o perdiste): Valeria ya no habla
  if (estado == GANASTE || estado == PERDISTE) {
    if (!fraseValeria.equals("") || respuestaLista != null) callarValeria();
    return;
  }
  // llego una frase
  RespuestaValeria r = respuestaLista;
  if (r != null) {
    respuestaLista = null;
    esperandoValeria = false;
    // si llegó tarde y ya no viene al caso, no se dice
    if (r.ev == null || r.ev.fija != null || r.ev.edad() < r.ev.vida() + 4) decir(r);
  }

  if (!fraseValeria.equals("")) {
    if (!mapaAbierto) tiempoFrase += dt;
    if (tiempoFrase > duracionFrase + 1.6) {
      fraseValeria = "";
      finUltimaFrase = ahora;
      if (musica != null) musica.atenuar = 1;
    }
    return;
  }
  if (esperandoValeria || colaValeria.isEmpty()) return;
  EventoValeria ev = colaValeria.peek();
  float pausa = ev.prioridad >= 3 ? PAUSA_URGENTE : PAUSA_VALERIA;
  if (ahora - finUltimaFrase < pausa) return;
  colaValeria.poll();
  if (ev.edad() > ev.vida()) return;   // ya paso de moda
  pedirFraseValeria(ev);
}

void decir(RespuestaValeria r) {
  if (r.texto == null || r.texto.equals("")) return;
  soltarVoz();
  fraseValeria = r.texto;
  tiempoFrase = 0;
  vozActual = r.voz;
  duracionFrase = r.voz != null ? r.segundos : max(2.8, r.texto.length() / 15.0);
  sonar("auricular");
  if (vozActual != null) vozActual.start();
  if (musica != null) musica.atenuar = 0.4;
  dichas.append(r.texto);
  while (dichas.size() > 6) dichas.remove(0);
}

// Arma el pedido en el hilo del juego (lee el estado) y lo manda a otro hilo
void pedirFraseValeria(EventoValeria ev) {
  String respaldoTexto = ev.fija != null ? ev.fija : fraseDeRespaldo(ev.tipo);
  if (!valeriaConIA() && respaldoTexto == null) return;   // sin IA, el aviso generico no se comenta
  String usuario = null;
  if (valeriaConIA()) {
    StringBuilder s = new StringBuilder();
    s.append("ACABA DE PASAR: ").append(ev.detalle).append("\n\n");
    s.append("ESTADO DE LA MISIÓN:\n").append(estado == JUGANDO || estado == RECONOCIMIENTO ? resumenMision(ev.tipo.equals("consejo") || ev.tipo.equals("inicio")) : "- La misión terminó.\n");
    if (dichas.size() > 0) {
      s.append("\nLO ÚLTIMO QUE DIJISTE (no lo repitas):\n");
      for (String d : dichas) s.append("- ").append(d).append("\n");
    }
    s.append("\nResponde solo con lo que Valeria dice ahora por el auricular.");
    usuario = s.toString();
  }
  esperandoValeria = true;
  Thread h = new Thread(new PedidoValeria(ev, usuario, respaldoTexto));
  h.setDaemon(true);
  h.start();
}

class PedidoValeria implements Runnable {
  EventoValeria ev;
  String usuario, respaldoTexto;

  PedidoValeria(EventoValeria ev, String usuario, String respaldoTexto) {
    this.ev = ev;
    this.usuario = usuario;
    this.respaldoTexto = respaldoTexto;
  }

  public void run() {
    RespuestaValeria r = new RespuestaValeria();
    r.ev = ev;
    long t0 = System.currentTimeMillis();
    if (usuario != null) {
      try {
        r.texto = limpiarFrase(pedirAlModelo(PERSONA_VALERIA, usuario, 90));
        fallosSeguidos = 0;
      } catch (Exception e) {
        fallosSeguidos++;
        marcarSinRed(e);
        println("Valeria (" + proveedorIA + "): " + e.getMessage());
      }
    }
    if (r.texto == null || r.texto.equals("")) r.texto = respaldoTexto;
    long t1 = System.currentTimeMillis();
    if (r.texto != null && valeriaConVoz()) {
      try {
        r.voz = vozDeAzure(r.texto);
        r.segundos = r.voz.getMicrosecondLength() / 1e6;
      } catch (Exception e) {
        r.voz = null;
        marcarSinRed(e);
        println("Valeria (Azure): " + e.getMessage());
      }
    }
    println("Valeria: texto " + (t1 - t0) + " ms, voz " + (System.currentTimeMillis() - t1) + " ms: " + r.texto);
    respuestaLista = r;
  }
}

// Quita comillas, "Valeria:" y saltos de linea que a veces pone el modelo
String limpiarFrase(String t) {
  if (t == null) return null;
  t = trim(t.replace('\n', ' ').replace("*", "").replace("\"", "").replace("“", "").replace("”", ""));
  if (t.toLowerCase().startsWith("valeria:")) t = trim(t.substring(8));
  if (t.length() > 220) t = t.substring(0, 220);
  return t;
}

// ---------------------------------------------------------------- internet

byte[] enviarPost(String direccion, String[][] cabeceras, byte[] cuerpo, int espera) throws Exception {
  java.net.HttpURLConnection c = (java.net.HttpURLConnection) java.net.URI.create(direccion).toURL().openConnection();
  c.setRequestMethod("POST");
  c.setDoOutput(true);
  c.setConnectTimeout(2500);
  c.setReadTimeout(espera);
  for (String[] h : cabeceras) c.setRequestProperty(h[0], h[1]);
  OutputStream o = c.getOutputStream();
  o.write(cuerpo);
  o.close();
  int codigo = c.getResponseCode();
  InputStream in = codigo < 400 ? c.getInputStream() : c.getErrorStream();
  byte[] r = in == null ? new byte[0] : in.readAllBytes();
  if (in != null) in.close();
  if (codigo >= 400) throw new RuntimeException("HTTP " + codigo + " " + new String(r, "UTF-8"));
  return r;
}

String pedirAlModelo(String sistema, String usuario, int maxTokens) throws Exception {
  return proveedorIA.equals("claude") ? pedirAClaude(sistema, usuario, maxTokens) : pedirAGroq(sistema, usuario, maxTokens);
}

// Groq usa el mismo formato de OpenAI. gpt-oss primero "piensa" y eso tambien
// gasta tokens, por eso se le pide poco razonamiento y se le da margen.
String pedirAGroq(String sistema, String usuario, int maxTokens) throws Exception {
  JSONObject cuerpo = new JSONObject();
  cuerpo.setString("model", modeloGroq);
  cuerpo.setInt("max_tokens", maxTokens + 400);
  if (modeloGroq.startsWith("openai/gpt-oss")) cuerpo.setString("reasoning_effort", "low");
  JSONArray mensajes = new JSONArray();
  JSONObject s = new JSONObject();
  s.setString("role", "system");
  s.setString("content", sistema);
  mensajes.append(s);
  JSONObject m = new JSONObject();
  m.setString("role", "user");
  m.setString("content", usuario);
  mensajes.append(m);
  cuerpo.setJSONArray("messages", mensajes);
  String[][] cab = {{"Authorization", "Bearer " + claveGroq}, {"Content-Type", "application/json"}};
  byte[] r = enviarPost("https://api.groq.com/openai/v1/chat/completions", cab, cuerpo.toString().getBytes("UTF-8"), 5000);
  JSONObject res = parseJSONObject(new String(r, "UTF-8"));
  return res.getJSONArray("choices").getJSONObject(0).getJSONObject("message").getString("content", "");
}

String pedirAClaude(String sistema, String usuario, int maxTokens) throws Exception {
  JSONObject cuerpo = new JSONObject();
  cuerpo.setString("model", modeloClaude);
  cuerpo.setInt("max_tokens", maxTokens);
  cuerpo.setString("system", sistema);
  JSONArray mensajes = new JSONArray();
  JSONObject m = new JSONObject();
  m.setString("role", "user");
  m.setString("content", usuario);
  mensajes.append(m);
  cuerpo.setJSONArray("messages", mensajes);
  String[][] cab = {{"x-api-key", claveClaude}, {"anthropic-version", "2023-06-01"}, {"content-type", "application/json"}};
  byte[] r = enviarPost("https://api.anthropic.com/v1/messages", cab, cuerpo.toString().getBytes("UTF-8"), 5000);
  JSONObject res = parseJSONObject(new String(r, "UTF-8"));
  JSONArray contenido = res.getJSONArray("content");
  String texto = "";
  for (int k = 0; k < contenido.size(); k++) {
    JSONObject b = contenido.getJSONObject(k);
    if (b.getString("type", "").equals("text")) texto += b.getString("text");
  }
  return texto;
}

String escaparXml(String t) {
  return t.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("'", "&apos;").replace("\"", "&quot;");
}

// Texto -> voz con Azure. Llega un WAV de 24 kHz; se le pasa el filtro de
// radio y queda listo en un Clip para sonar.
Clip vozDeAzure(String texto) throws Exception {
  return vozDeAzure(texto, vozAzure);
}

// La misma, con otra voz (la periodista usa vozPeriodista)
Clip vozDeAzure(String texto, String voz) throws Exception {
  String ssml = "<speak version='1.0' xml:lang='es-CO'><voice name='" + voz + "'>" +
    "<prosody rate='+25%'>" + escaparXml(texto) + "</prosody></voice></speak>";
  String[][] cab = {{"Ocp-Apim-Subscription-Key", claveAzure}, {"Content-Type", "application/ssml+xml"},
    {"X-Microsoft-OutputFormat", "riff-24khz-16bit-mono-pcm"}, {"User-Agent", "InfiltradoPrueba"}};
  // si esta frase ya se dijo antes, se usa la grabacion guardada
  java.io.File guardada = new java.io.File(dataPath("voz/" + voz + "_" + Integer.toHexString(texto.hashCode()) + ".wav"));
  byte[] wav;
  if (guardada.exists()) {
    wav = java.nio.file.Files.readAllBytes(guardada.toPath());
  } else {
    if (!hayRed()) throw new RuntimeException("sin internet: la frase sale solo en texto");
    wav = enviarPost("https://" + regionAzure + ".tts.speech.microsoft.com/cognitiveservices/v1", cab, ssml.getBytes("UTF-8"), 4000);
    try {
      // se escribe aparte y luego se renombra: si se corta a la mitad no
      // queda un archivo dañado que después se tome por bueno
      guardada.getParentFile().mkdirs();
      java.io.File temporal = new java.io.File(guardada.getPath() + ".tmp");
      java.nio.file.Files.write(temporal.toPath(), wav);
      java.nio.file.Files.move(temporal.toPath(), guardada.toPath(), java.nio.file.StandardCopyOption.REPLACE_EXISTING);
    } catch (Exception e) {
      println("Valeria: no se pudo guardar la voz: " + e.getMessage());
    }
  }
  AudioInputStream ais = AudioSystem.getAudioInputStream(new java.io.ByteArrayInputStream(wav));
  AudioFormat fmt = ais.getFormat();
  byte[] b = ais.readAllBytes();
  ais.close();
  if (efectoRadio) filtroRadio(b, fmt.getSampleRate());
  Clip c = AudioSystem.getClip();
  c.open(fmt, b, 0, b.length);
  return c;
}

// Filtro de radio: quita graves y agudos (queda la banda del telefono) y
// satura un poquito. Muestras de 16 bits little endian, mono.
void filtroRadio(byte[] b, float frecuencia) {
  int n = b.length / 2;
  float aBajo = exp(-TWO_PI * 300 / frecuencia);    // pasa altos en 300 Hz
  float aAlto = exp(-TWO_PI * 3400 / frecuencia);   // pasa bajos en 3400 Hz
  float prevX = 0, hp = 0, lp1 = 0, lp2 = 0;
  for (int i = 0; i < n; i++) {
    float x = (short) ((b[2 * i + 1] << 8) | (b[2 * i] & 0xff)) / 32768.0;
    hp = aBajo * (hp + x - prevX);
    prevX = x;
    lp1 = (1 - aAlto) * hp + aAlto * lp1;
    lp2 = (1 - aAlto) * lp1 + aAlto * lp2;
    float y = (float) Math.tanh(lp2 * 1.8) * 0.85;
    int v = (int) constrain(y * 32767, -32768, 32767);
    b[2 * i] = (byte) (v & 0xff);
    b[2 * i + 1] = (byte) ((v >> 8) & 0xff);
  }
}

// ---------------------------------------------------------------- dibujo

// Recuadro de Valeria encima de las tarjetas de los jugadores
void dibujarValeria() {
  if (!valeriaActiva || mapaAbierto) return;
  if (estado != JUGANDO && estado != GANASTE && estado != PERDISTE) return;
  boolean hablando = !fraseValeria.equals("");
  if (!hablando && !esperandoValeria) return;
  PGraphics g = capaValeria;
  g.beginDraw();
  g.clear();
  g.textAlign(LEFT, TOP);
  marcoPixel(g, 0, 0, g.width - 1, g.height - 1, COLOR_VALERIA);
  g.noStroke();
  g.fill(40, 30, 64);
  g.rect(6, 6, 24, 24);
  g.image(caraValeria, 8, 8);
  textoPixel(g, "VALERIA", 36, 4, COLOR_VALERIA, pixel10);
  if (hablando) {
    int letras = fraseValeria.length();
    if (vozActual != null) letras = ceil(letras * constrain(tiempoFrase / max(0.1, duracionFrase * 0.9), 0, 1));
    else letras = min(letras, ceil(tiempoFrase * 32));
    g.textFont(pixel8);
    g.fill(242, 242, 233);
    g.text(fraseValeria.substring(0, letras), 36, 17, g.width - 44, g.height - 20);
  } else {
    // esperando la frase: puntos que se mueven (tapa la demora de internet)
    int p = (millis() / 250) % 4;
    textoPixel(g, "· · ·".substring(0, min(5, p * 2)), 36, 20, color(160, 168, 190), pixel10);
  }
  g.endDraw();
  int x = (width / pixel - g.width) / 2;
  int y = height / pixel - 62 - g.height - 6;
  if (estado == GANASTE || estado == PERDISTE) y = height / pixel - g.height - 10;
  image(g, x * pixel, y * pixel, g.width * pixel, g.height * pixel);
}
