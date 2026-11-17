// Red — el multijugador en red: cada candidato juega en su PC.
//
// Uno crea la partida (el anfitrión) y los demás se unen con su IP. Se usa
// la librería de red que trae Processing (processing.net): el anfitrión abre
// un Server y cada invitado se conecta con un Client. Todo lo que se manda
// son líneas de texto, una por mensaje:
//
//   invitado -> anfitrión     HOLA nombre · LISTO turno apoyo · APOYO apoyo
//                             IN teclas · AC acción
//   anfitrión -> invitados    BIENVENIDO asiento · SALA nombres · EMPEZAR nombres minijuegos
//                             ESPERA listos total · TABLA apoyos · TURNO n
//                             ES foto · FX efecto · AV asiento aviso
//
// La campaña es compartida: cada uno juega su oficina (publica, compra
// habilidades, la misión de Valeria...) y al pasar turno avisa que está
// listo con su apoyo en cada barrio. El turno avanza cuando todos están
// listos. Con la tabla de apoyos, la TV pasa el sondeo y al final vienen las
// votaciones: cada barrio lo gana el candidato con más apoyo ahí.
//
// En los minijuegos del mundo abierto todos entran a la misma ciudad: el
// anfitrión simula y manda la foto del estado; los invitados mandan sus
// teclas (EnLinea.pde, dentro de MundoAbierto.pde). Los asientos sin
// persona los juega el computador.

import processing.net.*;

final int PUERTO_RED = 5204;
final int RED_SOLO = 0, RED_ANFITRION = 1, RED_INVITADO = 2;
int modoRedJuego = RED_SOLO;
Server servidor;
Client cliente;
Client[] clienteAsiento = new Client[4];
String[] nombreAsiento = {"", "", "", ""};
boolean[] humanoAsiento = new boolean[4];
int miAsientoRed = 0;
HashMap<Client, StringBuilder> bufferRed = new HashMap<Client, StringBuilder>();
boolean campanaEnRed = false;     // ya empezó la campaña en red

// La sala (antes de empezar)
boolean enSala = false;
final int SALA_ELEGIR = 0, SALA_ANFITRION = 1, SALA_IP = 2, SALA_UNIDO = 3;
int pasoSala = SALA_ELEGIR;
String campoNombre = "";
String campoIP = "";
int campoActivo = 0;              // 0 nombre, 1 IP
String errorSala = "";
String textoIPs = "";
Boton botonCrear, botonUnirse, botonVolverSala, botonEmpezar, botonConectar;

// Los turnos
boolean esperandoTurno = false;
boolean permisoTurno = false;
boolean[] listoAsiento = new boolean[4];
int listosVistos = 0, totalVistos = 1;
int[][] apoyoAsiento = new int[4][8];
boolean[] tieneTabla = new boolean[4];
boolean votacionesCerradas = false;

// ---------------------------------------------------------------------------
// Conexión
// ---------------------------------------------------------------------------

boolean enRed() {
    return modoRedJuego != RED_SOLO;
}

void crearPartidaRed() {
    try {
        servidor = new Server(this, PUERTO_RED);
    } catch (Exception e) {
        errorSala = "No se pudo abrir el puerto " + PUERTO_RED + ".";
        return;
    }
    if (!servidor.active()) {
        errorSala = "No se pudo abrir el puerto " + PUERTO_RED + ".";
        servidor = null;
        return;
    }
    modoRedJuego = RED_ANFITRION;
    miAsientoRed = 0;
    for (int k = 0; k < 4; k++) {
        humanoAsiento[k] = k == 0;
        nombreAsiento[k] = k == 0 ? nombreLimpio(campoNombre) : "";
        clienteAsiento[k] = null;
    }
    textoIPs = ipsLocales();
    pasoSala = SALA_ANFITRION;
    errorSala = "";
}

void unirsePartidaRed() {
    String ip = trim(campoIP);
    if (ip.length() == 0) {
        errorSala = "Escribe la IP del anfitrión.";
        return;
    }
    try {
        cliente = new Client(this, ip, PUERTO_RED);
    } catch (Exception e) {
        cliente = null;
    }
    if (cliente == null || !cliente.active()) {
        errorSala = "No se pudo conectar con " + ip + ". Revisa la IP y que estén en la misma red.";
        cliente = null;
        return;
    }
    modoRedJuego = RED_INVITADO;
    enviarRed("HOLA " + nombreLimpio(campoNombre).replace(' ', '_'));
    pasoSala = SALA_UNIDO;
    errorSala = "";
}

void cerrarRed() {
    if (servidor != null) servidor.stop();
    if (cliente != null) cliente.stop();
    servidor = null;
    cliente = null;
    modoRedJuego = RED_SOLO;
    campanaEnRed = false;
}

String nombreLimpio(String s) {
    s = trim(s);
    if (s.length() == 0) s = "Candidato";
    return s.length() > 16 ? s.substring(0, 16) : s;
}

// Las IP de este PC (sin la de "localhost"), para que el anfitrión se las dicte a los demás
String ipsLocales() {
    String res = "";
    try {
        for (java.net.NetworkInterface ni : java.util.Collections.list(java.net.NetworkInterface.getNetworkInterfaces())) {
            if (!ni.isUp() || ni.isLoopback()) continue;
            for (java.net.InetAddress a : java.util.Collections.list(ni.getInetAddresses())) {
                if (a instanceof java.net.Inet4Address) res += (res.length() > 0 ? "   ·   " : "") + a.getHostAddress();
            }
        }
    } catch (Exception e) {
        res = "";
    }
    return res.length() > 0 ? res : "(no se encontró ninguna red)";
}

// Quien se desconecta deja su asiento libre (y no se le espera más para
// pasar turno). Se revisa en cada cuadro, no en el hilo de la red.
void revisarDesconectados() {
    for (int k = 1; k < 4; k++) {
        Client c = clienteAsiento[k];
        if (c == null || c.active()) continue;
        clienteAsiento[k] = null;
        humanoAsiento[k] = false;
        listoAsiento[k] = false;
        if (campanaEnRed) avisar(nombreAsiento[k] + " se desconectó.");
        nombreAsiento[k] = "";
        bufferRed.remove(c);
        difundirSala();
        if (esperandoTurno) revisarTurnoAnfitrion();
    }
}

void enviarRed(String s) {
    if (modoRedJuego == RED_INVITADO && cliente != null) cliente.write(s + "\n");
}

void enviarA(Client c, String s) {
    if (c != null && c.active()) c.write(s + "\n");
}

void difundir(String s) {
    if (modoRedJuego == RED_ANFITRION && servidor != null) servidor.write(s + "\n");
}

// Se llama al principio de cada draw(): lee todo lo que haya llegado
void procesarRed() {
    if (modoRedJuego == RED_ANFITRION && servidor != null) {
        revisarDesconectados();
        Client c = servidor.available();
        int vueltas = 0;
        while (c != null && vueltas < 50) {
            leerDe(c);
            c = servidor.available();
            vueltas++;
        }
    } else if (modoRedJuego == RED_INVITADO && cliente != null) {
        if (!cliente.active()) {
            avisar("Se perdió la conexión con el anfitrión: sigues solo.");
            cliente = null;
            modoRedJuego = RED_SOLO;
            esperandoTurno = false;
            return;
        }
        if (cliente.available() > 0) leerDe(cliente);
    }
}

void leerDe(Client c) {
    String s = c.readString();
    if (s == null) return;
    StringBuilder b = bufferRed.get(c);
    if (b == null) {
        b = new StringBuilder();
        bufferRed.put(c, b);
    }
    b.append(s);
    int i;
    while ((i = b.indexOf("\n")) >= 0) {
        String linea = b.substring(0, i);
        b.delete(0, i + 1);
        if (linea.length() > 0) recibir(c, linea);
    }
}

int asientoDe(Client c) {
    for (int k = 1; k < 4; k++) if (clienteAsiento[k] == c) return k;
    return -1;
}

void recibir(Client c, String linea) {
    int esp = linea.indexOf(' ');
    String tipo = esp < 0 ? linea : linea.substring(0, esp);
    String resto = esp < 0 ? "" : linea.substring(esp + 1);
    if (modoRedJuego == RED_ANFITRION) {
        int asiento = asientoDe(c);
        if (tipo.equals("HOLA")) {
            if (campanaEnRed) {
                enviarA(c, "LLENO");
                return;
            }
            int libre = -1;
            for (int k = 1; k < 4 && libre < 0; k++) if (!humanoAsiento[k]) libre = k;
            if (libre < 0) {
                enviarA(c, "LLENO");
                return;
            }
            humanoAsiento[libre] = true;
            clienteAsiento[libre] = c;
            nombreAsiento[libre] = nombreLimpio(resto.replace('_', ' '));
            enviarA(c, "BIENVENIDO " + libre);
            difundirSala();
        } else if (asiento < 0) {
            return;
        } else if (tipo.equals("LISTO")) {
            String[] p = splitTokens(resto);
            listoAsiento[asiento] = true;
            if (p.length >= 2) guardarApoyo(asiento, p[1]);
            revisarTurnoAnfitrion();
        } else if (tipo.equals("APOYO")) {
            guardarApoyo(asiento, trim(resto));
            difundirTabla();
        } else if (tipo.equals("IN")) {
            if (estado == EVENTO) mundo.entradaRemota(asiento, int(trim(resto)));
        } else if (tipo.equals("AC")) {
            if (estado == EVENTO && resto.length() > 0) mundo.accionRemota(asiento, resto.charAt(0));
        }
    } else {
        if (tipo.equals("BIENVENIDO")) {
            miAsientoRed = int(trim(resto));
        } else if (tipo.equals("LLENO")) {
            errorSala = "La partida ya está llena o ya empezó.";
            cerrarRed();
            pasoSala = SALA_IP;
        } else if (tipo.equals("SALA")) {
            leerNombres(resto);
        } else if (tipo.equals("EMPEZAR")) {
            String[] p = splitTokens(resto);
            leerNombres(p.length > 0 ? p[0] : "");
            empezarCampanaRed();
            // los minijuegos que sorteó el anfitrión, en el mismo orden
            if (p.length > 1) leerOrdenMinijuegos(p[1]);
        } else if (tipo.equals("ESPERA")) {
            String[] p = splitTokens(resto);
            if (p.length >= 2) {
                listosVistos = int(p[0]);
                totalVistos = int(p[1]);
            }
        } else if (tipo.equals("TABLA")) {
            leerTabla(resto);
        } else if (tipo.equals("TURNO")) {
            aplicarTurnoRed();
        } else if (tipo.equals("ES")) {
            if (estado == EVENTO) mundo.aplicarEstado(resto);
        } else if (tipo.equals("FX")) {
            if (estado == EVENTO) mundo.aplicarFx(resto);
        } else if (tipo.equals("AV")) {
            int e2 = resto.indexOf(' ');
            if (e2 > 0 && estado == EVENTO) {
                int a = int(resto.substring(0, e2));
                if (a == -1 || a == miAsientoRed) mundo.avisar(resto.substring(e2 + 1));
            }
        }
    }
}

// "nombre0;nombre1;nombre2;nombre3" (vacío = lo juega el computador)
void leerNombres(String s) {
    String[] p = split(s, ';');
    for (int k = 0; k < 4; k++) {
        nombreAsiento[k] = k < p.length ? p[k].replace('_', ' ') : "";
        humanoAsiento[k] = nombreAsiento[k].length() > 0;
    }
}

String textoNombres() {
    String s = "";
    for (int k = 0; k < 4; k++) s += (k > 0 ? ";" : "") + (humanoAsiento[k] ? nombreAsiento[k].replace(' ', '_') : "");
    return s;
}

void difundirSala() {
    difundir("SALA " + textoNombres());
}

// ---------------------------------------------------------------------------
// Empezar y los turnos
// ---------------------------------------------------------------------------

void empezarCampanaRed() {
    // todos empiezan la campaña desde el turno 1, con su nombre
    partida.iniciar(nombreAsiento[miAsientoRed], arbol);
    reiniciarPartida();
    campanaEnRed = true;
    enSala = false;
    votacionesCerradas = false;
    for (int k = 0; k < 4; k++) {
        tieneTabla[k] = false;
        listoAsiento[k] = false;
    }
    camaraBajando = true;
    momentoCamara = millis();
}

void empezarComoAnfitrion() {
    empezarCampanaRed();   // aquí se sortean los minijuegos
    difundir("EMPEZAR " + textoNombres() + " " + textoOrdenMinijuegos());
}

String textoApoyo() {
    String s = "";
    for (int z = 0; z < partida.getCiudad().cantidad(); z++) s += (z > 0 ? "," : "") + partida.getApoyo(z);
    return s;
}

void guardarApoyo(int asiento, String s) {
    int[] v = int(split(s, ','));
    for (int z = 0; z < min(v.length, 8); z++) apoyoAsiento[asiento][z] = v[z];
    tieneTabla[asiento] = true;
}

void leerTabla(String s) {
    String[] p = split(s, '/');
    for (int k = 0; k < min(4, p.length); k++) {
        if (p[k].equals("-")) {
            tieneTabla[k] = false;
        } else {
            guardarApoyo(k, p[k]);
        }
    }
}

// En red, pasar turno es avisar que se está listo; el turno avanza cuando
// todos lo están. Devuelve true si hay que esperar.
boolean esperarTurnoRed() {
    if (!enRed() || !campanaEnRed || permisoTurno) {
        return false;
    }
    if (esperandoTurno) {
        return true;
    }
    esperandoTurno = true;
    if (modoRedJuego == RED_ANFITRION) {
        listoAsiento[0] = true;
        guardarApoyo(0, textoApoyo());
        revisarTurnoAnfitrion();
    } else {
        enviarRed("LISTO " + partida.getTurno() + " " + textoApoyo());
    }
    return true;
}

void revisarTurnoAnfitrion() {
    if (modoRedJuego != RED_ANFITRION || !campanaEnRed) return;
    int listos = 0, total = 0;
    for (int k = 0; k < 4; k++) {
        if (!humanoAsiento[k]) continue;
        total++;
        if (listoAsiento[k]) listos++;
    }
    listosVistos = listos;
    totalVistos = total;
    difundir("ESPERA " + listos + " " + total);
    if (listos < total || !listoAsiento[0]) return;
    difundirTabla();
    difundir("TURNO " + (partida.getTurno() + 1));
    for (int k = 0; k < 4; k++) listoAsiento[k] = false;
    aplicarTurnoRed();
}

void difundirTabla() {
    String tabla = "";
    for (int k = 0; k < 4; k++) {
        String fila = "-";
        if (humanoAsiento[k] && tieneTabla[k]) {
            fila = "";
            for (int z = 0; z < 8; z++) fila += (z > 0 ? "," : "") + apoyoAsiento[k][z];
        }
        tabla += (k > 0 ? "/" : "") + fila;
    }
    difundir("TABLA " + tabla);
}

void aplicarTurnoRed() {
    esperandoTurno = false;
    permisoTurno = true;
    pasarTurno();
    permisoTurno = false;
    // el apoyo ya con lo que dejó el turno, para el sondeo y las votaciones
    if (modoRedJuego == RED_ANFITRION) {
        guardarApoyo(0, textoApoyo());
        difundirTabla();
    } else {
        enviarRed("APOYO " + textoApoyo());
    }
}

// ---------------------------------------------------------------------------
// Lo que el mundo (MundoAbierto) le pide a la red durante un evento
// ---------------------------------------------------------------------------

void enviarTeclasRed(int mascara) {
    enviarRed("IN " + mascara);
}

void enviarAccionRed(char a) {
    enviarRed("AC " + a);
}

void avisoRed(int asiento, String texto) {
    if (asiento < 0) difundir("AV -1 " + texto);
    else if (asiento < 4) enviarA(clienteAsiento[asiento], "AV " + asiento + " " + texto);
}

void fxRed(String linea) {
    difundir("FX " + linea);
}

// El anfitrión manda la foto del parque unas 15 veces por segundo
void mandarFotoEvento() {
    if (modoRedJuego == RED_ANFITRION && frameCount % 4 == 0) {
        difundir("ES " + mundo.estadoRed());
    }
}

// ---------------------------------------------------------------------------
// Sondeo y votaciones
// ---------------------------------------------------------------------------

int votosDe(int asiento) {
    int s = 0;
    for (int z = 0; z < 8; z++) s += apoyoAsiento[asiento][z];
    return s;
}

// Para la TV: "SONDEO · Ana 120 · Luis 95"
String textoSondeo() {
    if (!enRed() || !campanaEnRed) return "";
    String s = "";
    for (int k = 0; k < 4; k++) {
        if (humanoAsiento[k] && tieneTabla[k]) s += "  " + nombreAsiento[k].toUpperCase() + " " + votosDe(k);
    }
    return s.length() > 0 ? "SONDEO DE APOYO:" + s + "  ■  " : "";
}

// Al terminar la campaña en red, la lista de las votaciones
boolean hayVotaciones() {
    return enRed() && campanaEnRed && partidaTerminada() && !votacionesCerradas && !enMenu;
}

void dibujarVotaciones() {
    if (!hayVotaciones()) return;
    GrafoCiudad ciudad = partida.getCiudad();
    // barrios ganados: el que tiene más apoyo en cada uno (si empatan, nadie)
    int[] ganados = new int[4];
    for (int z = 0; z < ciudad.cantidad(); z++) {
        int mejor = -1;
        boolean empate = false;
        for (int k = 0; k < 4; k++) {
            if (!humanoAsiento[k] || !tieneTabla[k]) continue;
            if (mejor < 0 || apoyoAsiento[k][z] > apoyoAsiento[mejor][z]) {
                mejor = k;
                empate = false;
            } else if (apoyoAsiento[k][z] == apoyoAsiento[mejor][z]) {
                empate = true;
            }
        }
        if (mejor >= 0 && !empate) ganados[mejor]++;
    }
    ArrayList<Integer> orden = new ArrayList<Integer>();
    for (int k = 0; k < 4; k++) if (humanoAsiento[k] && tieneTabla[k]) orden.add(k);
    // de más a menos votos y, si empatan, más barrios (inserción)
    for (int a = 1; a < orden.size(); a++) {
        int v = orden.get(a);
        int b = a - 1;
        while (b >= 0 && (votosDe(orden.get(b)) < votosDe(v)
            || (votosDe(orden.get(b)) == votosDe(v) && ganados[orden.get(b)] < ganados[v]))) {
            orden.set(b + 1, orden.get(b));
            b--;
        }
        orden.set(b + 1, v);
    }
    float w = min(width * 0.6, 760), h = 170 + orden.size() * 54;
    float x = width / 2 - w / 2, y = height / 2 - h / 2;
    noStroke();
    fill(0, 150);
    rect(0, 0, width, height);
    fill(COLOR_PAPEL);
    stroke(COLOR_CONTORNO);
    strokeWeight(3);
    rect(x, y, w, h, 14);
    noStroke();
    fill(COLOR_TEXTO);
    textAlign(CENTER, TOP);
    usarLetra(LETRA_TITULO, tx(38, 26));
    text("VOTACIONES", width / 2, y + 22);
    usarLetra(LETRA_TEXTO, tx(17, 13));
    fill(COLOR_TEXTO_SUAVE);
    text("Los votos son el apoyo sumado de todos los barrios", width / 2, y + 74);
    for (int i = 0; i < orden.size(); i++) {
        int k = orden.get(i);
        float fy = y + 112 + i * 54;
        fill(i == 0 ? COLOR_POSTIT : color(245, 240, 225));
        rect(x + 30, fy, w - 60, 44, 8);
        fill(COLOR_TEXTO);
        textAlign(LEFT, CENTER);
        usarLetra(LETRA_NEGRITA, tx(20, 15));
        text((i + 1) + ".  " + nombreAsiento[k] + (k == miAsientoRed ? " (tú)" : ""), x + 48, fy + 22);
        textAlign(RIGHT, CENTER);
        usarLetra(LETRA_TEXTO, tx(17, 13));
        text(votosDe(k) + " votos  ·  " + ganados[k] + (ganados[k] == 1 ? " barrio" : " barrios"), x + w - 48, fy + 22);
    }
    textAlign(CENTER, BOTTOM);
    usarLetra(LETRA_NEGRITA, tx(16, 12));
    fill(COLOR_TEXTO);
    String titular = "";
    if (orden.size() > 1 && votosDe(orden.get(0)) == votosDe(orden.get(1)) && ganados[orden.get(0)] == ganados[orden.get(1)]) {
        titular = "¡Empate entre " + nombreAsiento[orden.get(0)] + " y " + nombreAsiento[orden.get(1)] + "!";
    } else if (orden.size() > 0) {
        titular = "¡" + nombreAsiento[orden.get(0)] + " es el nuevo alcalde de Ciudad Nova!";
    }
    text(titular + "   ·   clic para cerrar", width / 2, y + h - 16);
}

// Mientras se espera a los demás para pasar turno
void dibujarEsperaTurno() {
    if (!esperandoTurno) return;
    String s = "Esperando a los demás candidatos para pasar el turno (" + listosVistos + " de " + totalVistos + " listos)";
    usarLetra(LETRA_NEGRITA, tx(17, 13));
    float w = textWidth(s) + 40;
    noStroke();
    fill(0, 190);
    rect(width / 2 - w / 2, 18, w, 44, 10);
    fill(COLOR_TEXTO_CREMA);
    textAlign(CENTER, CENTER);
    text(s, width / 2, 39);
}

// ---------------------------------------------------------------------------
// La sala
// ---------------------------------------------------------------------------

void abrirSala() {
    enSala = true;
    pasoSala = modoRedJuego == RED_ANFITRION ? SALA_ANFITRION : (modoRedJuego == RED_INVITADO ? SALA_UNIDO : SALA_ELEGIR);
    campoActivo = 0;
    errorSala = "";
}

void pantallaSala() {
    float w = min(width * 0.62, 820), h = min(height * 0.82, 560);
    float x = width / 2 - w / 2, y = height / 2 - h / 2;
    noStroke();
    fill(0, 170);
    rect(0, 0, width, height);
    stroke(COLOR_CONTORNO);
    strokeWeight(3);
    fill(COLOR_PAPEL);
    rect(x, y, w, h, 14);
    noStroke();
    fill(COLOR_TEXTO);
    textAlign(CENTER, TOP);
    usarLetra(LETRA_TITULO, tx(34, 24));
    text("MULTIJUGADOR EN RED", width / 2, y + 20);
    usarLetra(LETRA_TEXTO, tx(15, 12));
    fill(COLOR_TEXTO_SUAVE);
    text("Cada candidato juega en su PC. Todos en la misma red (o con Radmin VPN / Tailscale).", width / 2, y + 66);

    float bw = w * 0.36, bh = tx(44, 34);
    float fy = y + 104;
    // nombre
    dibujarCampo("Tu nombre", campoNombre, x + 40, fy, w - 80, campoActivo == 0 && (pasoSala == SALA_ELEGIR || pasoSala == SALA_IP));
    fy += 78;
    if (pasoSala == SALA_ELEGIR) {
        botonCrear = new Boton(width / 2 - bw - 10, fy, bw, bh, "Crear partida");
        botonUnirse = new Boton(width / 2 + 10, fy, bw, bh, "Unirse a una");
        botonCrear.dibujar();
        botonUnirse.dibujar();
        fill(COLOR_TEXTO_SUAVE);
        usarLetra(LETRA_TEXTO, tx(14, 11));
        textAlign(CENTER, TOP);
        text("Quien crea la partida es el anfitrión: los demás se unen con su IP.\nLos puestos que queden libres los juega el computador.", width / 2, fy + bh + 22);
    } else if (pasoSala == SALA_IP) {
        dibujarCampo("IP del anfitrión", campoIP, x + 40, fy, w - 80, campoActivo == 1);
        fy += 78;
        botonConectar = new Boton(width / 2 - bw / 2, fy, bw, bh, "Conectar");
        botonConectar.dibujar();
    } else {
        fill(COLOR_TEXTO);
        textAlign(LEFT, TOP);
        usarLetra(LETRA_NEGRITA, tx(16, 12));
        if (pasoSala == SALA_ANFITRION) {
            text("Dile tu IP a los demás (puerto " + PUERTO_RED + "):", x + 40, fy - 22);
            usarLetra(LETRA_TEXTO, tx(16, 12));
            fill(COLOR_TINTA);
            text(textoIPs, x + 40, fy + 2);
            fy += 36;
        } else {
            text("Conectado. Esperando a que el anfitrión empiece la campaña...", x + 40, fy - 22);
            fy += 14;
        }
        for (int k = 0; k < 4; k++) {
            float ry = fy + k * 40;
            fill(humanoAsiento[k] ? COLOR_POSTIT : color(238, 234, 222));
            rect(x + 40, ry, w - 80, 34, 6);
            fill(COLOR_TEXTO);
            textAlign(LEFT, CENTER);
            usarLetra(humanoAsiento[k] ? LETRA_NEGRITA : LETRA_TEXTO, tx(16, 12));
            String n = humanoAsiento[k] ? nombreAsiento[k] + (k == 0 ? "  (anfitrión)" : "") + (k == miAsientoRed ? "  · tú" : "")
                : "Libre: lo juega el computador";
            text((k + 1) + ".  " + n, x + 56, ry + 17);
        }
        fy += 4 * 40 + 14;
        if (pasoSala == SALA_ANFITRION && !campanaEnRed) {
            botonEmpezar = new Boton(width / 2 - bw / 2, fy, bw, bh, "Empezar campaña");
            botonEmpezar.dibujar();
        }
    }
    botonVolverSala = new Boton(x + 20, y + h - bh - 18, w * 0.22, bh, pasoSala == SALA_ELEGIR ? "Volver" : "Salir");
    botonVolverSala.dibujar();
    if (errorSala.length() > 0) {
        fill(COLOR_ERROR);
        textAlign(RIGHT, CENTER);
        usarLetra(LETRA_NEGRITA, tx(14, 11));
        text(errorSala, x + w - 24, y + h - bh / 2 - 18);
    }
}

void dibujarCampo(String etiqueta, String valor, float x, float y, float w, boolean activo) {
    fill(COLOR_TEXTO);
    textAlign(LEFT, BOTTOM);
    usarLetra(LETRA_NEGRITA, tx(15, 12));
    text(etiqueta, x, y + 2);
    stroke(activo ? COLOR_TINTA : COLOR_GRIS);
    strokeWeight(activo ? 2.5 : 1.5);
    fill(COLOR_BLANCO);
    rect(x, y + 6, w, 38, 6);
    noStroke();
    fill(COLOR_TEXTO);
    textAlign(LEFT, CENTER);
    usarLetra(LETRA_TEXTO, tx(18, 13));
    String cursor = activo && (millis() / 500) % 2 == 0 ? "|" : "";
    if (valor.length() == 0 && !activo) {
        fill(COLOR_GRIS);
        text("(sin escribir)", x + 12, y + 24);
    } else {
        text(valor + cursor, x + 12, y + 24);
    }
}

void clicEnSala() {
    float w = min(width * 0.62, 820);
    float x = width / 2 - w / 2;
    float yNombre = height / 2 - min(height * 0.82, 560) / 2 + 104;
    if (mouseX > x + 40 && mouseX < x + w - 40 && mouseY > yNombre + 6 && mouseY < yNombre + 44
        && (pasoSala == SALA_ELEGIR || pasoSala == SALA_IP)) {
        campoActivo = 0;
        return;
    }
    if (pasoSala == SALA_IP && mouseY > yNombre + 84 && mouseY < yNombre + 122) {
        campoActivo = 1;
        return;
    }
    if (botonVolverSala != null && botonVolverSala.contiene(mouseX, mouseY)) {
        if (pasoSala == SALA_ELEGIR) {
            enSala = false;
        } else {
            cerrarRed();
            pasoSala = SALA_ELEGIR;
        }
        return;
    }
    if (pasoSala == SALA_ELEGIR) {
        if (botonCrear != null && botonCrear.contiene(mouseX, mouseY)) crearPartidaRed();
        else if (botonUnirse != null && botonUnirse.contiene(mouseX, mouseY)) {
            pasoSala = SALA_IP;
            campoActivo = 1;
        }
    } else if (pasoSala == SALA_IP) {
        if (botonConectar != null && botonConectar.contiene(mouseX, mouseY)) unirsePartidaRed();
    } else if (pasoSala == SALA_ANFITRION) {
        if (!campanaEnRed && botonEmpezar != null && botonEmpezar.contiene(mouseX, mouseY)) empezarComoAnfitrion();
    }
}

// Escribir en los campos de la sala
void teclaSala() {
    if (key == ESC) {
        key = 0;
        if (pasoSala == SALA_ELEGIR) enSala = false;
        return;
    }
    if (pasoSala != SALA_ELEGIR && pasoSala != SALA_IP) return;
    if (key == ENTER || key == RETURN) {
        if (pasoSala == SALA_IP) unirsePartidaRed();
        return;
    }
    if (key == TAB && pasoSala == SALA_IP) {
        campoActivo = 1 - campoActivo;
        return;
    }
    boolean ip = campoActivo == 1 && pasoSala == SALA_IP;
    if (key == BACKSPACE) {
        if (ip && campoIP.length() > 0) campoIP = campoIP.substring(0, campoIP.length() - 1);
        if (!ip && campoNombre.length() > 0) campoNombre = campoNombre.substring(0, campoNombre.length() - 1);
        return;
    }
    if (key == CODED || key < 32 || key == ';' || key == '/' || key == '|') return;
    if (ip && campoIP.length() < 40) campoIP += key;
    if (!ip && campoNombre.length() < 16) campoNombre += key;
}
