// Conexion con Alcalde Digital.
// El juego principal no se toca: se comunican por dos archivos de texto en
// data/ (clave=valor, faciles de escribir con saveStrings y leer con
// loadStrings).
//   campana.txt   lo escribe Alcalde Digital antes de entrar: el barrio, el
//                 apoyo y las habilidades que el candidato tiene en su arbol.
//                 Si no existe se usan valores de prueba.
//   resultado.txt lo escribe Infiltrado al terminar: si salio bien, el
//                 botin, el rango, las oportunidades, cuanto apoyo cambia y
//                 la noticia que saldria al dia siguiente.
// Cada habilidad del arbol se vuelve una herramienta en la mision:
//   Volantes           +2 paquetes para lanzar y distraer (como las botellas)
//   Megafono           lo que se lanza hace mas ruido (atrae desde mas lejos)
//   Perfil verificado  el jefe de seguridad tiene que estar mas cerca para reconocerte
//   Libreta de notas   el reconocimiento dura 25 s en vez de 15
//   Fuente confiable   empiezas sabiendo los dos primeros digitos del codigo
//   Rueda de prensa    la central acepta una respuesta mas por radio
//   Asistente de IA    la habilidad del rol se recarga un 30 % mas rapido
//   Bots de difusion   las camaras tardan mas en verte

String barrioCampana = "La Colina";
int apoyoCampana = 45;
String buloCampana = "agua contaminada en El Puerto";
boolean campanaDePrueba = true;
StringList habilidadesCampana = new StringList();

// Cuando la mision se juega dentro de Alcalde Digital (ronda 2), el juego
// principal pasa los datos directamente con configurarCampana() y no se
// leen ni se escriben archivos.
boolean desdeCampana = false;

void configurarCampana(String barrio, int apoyo, String bulo, StringList habilidades) {
  desdeCampana = true;
  campanaDePrueba = false;
  barrioCampana = barrio;
  apoyoCampana = apoyo;
  buloCampana = bulo;
  habilidadesCampana.clear();
  for (String h : habilidades) habilidadesCampana.append(h);
}

// <solo-sketch>
// Jugando solo este sketch no hay campana a la cual volver. Dentro de
// Alcalde Digital esta funcion la pone el juego principal.
void volverALaCampana() {
}
// </solo-sketch>

void leerCampana() {
  if (desdeCampana) return;
  habilidadesCampana.clear();
  String[] lineas = null;
  try {
    if (new java.io.File(dataPath("campana.txt")).exists()) lineas = loadStrings("campana.txt");
  } catch (Exception e) {
    lineas = null;
  }
  campanaDePrueba = lineas == null;
  if (lineas == null) {
    // valores de prueba cuando se juega sin pasar por Alcalde Digital
    habilidadesCampana.append("Volantes");
    habilidadesCampana.append("Libreta de notas");
    habilidadesCampana.append("Asistente de IA");
    return;
  }
  for (String l : lineas) {
    l = trim(l);
    if (l.length() == 0 || l.charAt(0) == '#' || l.indexOf('=') < 0) continue;
    String clave = trim(l.substring(0, l.indexOf('=')));
    String valor = trim(l.substring(l.indexOf('=') + 1));
    if (clave.equals("barrio")) barrioCampana = valor;
    if (clave.equals("apoyo")) apoyoCampana = int(valor);
    if (clave.equals("bulo")) buloCampana = valor;
    if (clave.equals("habilidades")) {
      for (String h : split(valor, ',')) if (trim(h).length() > 0) habilidadesCampana.append(trim(h));
    }
  }
}

boolean tieneHerramienta(String nombre) {
  return habilidadesCampana.hasValue(nombre);
}

// Lo que cambia al empezar la mision
void aplicarHerramientas() {
  for (Jugador j : jugadores) {
    if (tieneHerramienta("Volantes")) j.botellas += 2;
  }
  if (tieneHerramienta("Fuente confiable")) {
    digitoConocido[0] = true;
    digitoConocido[1] = true;
  }
}

float tiempoReconocimientoTotal() {
  return tieneHerramienta("Libreta de notas") ? 14 : TIEMPO_RECONOCIMIENTO;
}

float ruidoLanzamiento() {
  return tieneHerramienta("Megáfono") ? 17 : RUIDO_BOTELLA;
}

float distanciaJefe() {
  return tieneHerramienta("Perfil verificado") ? 1.8 : DISTANCIA_JEFE;
}

int maxRadios() {
  return tieneHerramienta("Rueda de prensa") ? MAX_RADIOS + 1 : MAX_RADIOS;
}

float enfriamientoRol(int rol) {
  return ENFRIAR_ROL[rol] * (tieneHerramienta("Asistente de IA") ? 0.7 : 1);
}

float factorCamaraHerramienta() {
  return tieneHerramienta("Bots de difusión") ? 0.7 : 1;
}

// Cuanto apoyo gana o pierde el candidato en el barrio: con exito, 25 mas el
// botin y 5 por cada oportunidad; si sale mal, -15.
int cambioApoyo(boolean exito) {
  if (!exito) return -15;
  return 25 + valorExtraido + 5 * oportunidadesHechas();
}

String proximaNoticia(boolean exito) {
  if (!exito) return "Titulares Ya acusa a tu campaña de espiar su sede";
  if (oportunidadHecha[0]) return "El bulo sobre " + buloCampana + " salió con los datos reales y Titulares Ya quedó en evidencia";
  if (chatLeido) return "Filtran los chats de Titulares Ya: el bulo sobre " + buloCampana + " era inventado";
  return "Se filtra el servidor de Titulares Ya: el bulo sobre " + buloCampana + " queda desmentido";
}

void escribirResultado(boolean exito) {
  if (desdeCampana) return;   // el juego principal lee el resultado directamente
  StringList l = new StringList();
  l.append("# Lo escribe Infiltrado al terminar. Alcalde Digital lo puede leer con loadStrings.");
  l.append("exito=" + (exito ? "si" : "no"));
  l.append("barrio=" + barrioCampana);
  l.append("salida=" + (salidaUsada >= 0 ? NOMBRES_SALIDA[salidaUsada] : "ninguna"));
  l.append("rango=" + rangoFinal());
  l.append("botin=" + (exito ? valorExtraido : 0));
  l.append("chat_leido=" + (chatLeido ? "si" : "no"));
  String ops = "";
  for (int k = 0; k < 3; k++) if (oportunidadHecha[k]) ops += (ops.equals("") ? "" : ";") + NOMBRES_OPORTUNIDAD[k];
  l.append("oportunidades=" + ops);
  l.append("alarma_maxima=" + alarmaMaxima);
  l.append("apoyo_cambio=" + cambioApoyo(exito));
  l.append("proxima_noticia=" + proximaNoticia(exito));
  try {
    saveStrings(dataPath("resultado.txt"), l.array());
  } catch (Exception e) {
    println("No se pudo escribir resultado.txt: " + e.getMessage());
  }
}
