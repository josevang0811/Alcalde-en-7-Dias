import java.util.ArrayList;
import java.util.Random;

// Partida guarda el estado de una sesion de juego: quien juega, en que turno
// va, cuantos puntos tiene para el arbol, que noticia le llego en este
// turno, sus seis tarjetas, la ciudad donde hace campana (el grafo de
// barrios) y cuanto apoyo tiene en cada barrio. Tambien conoce el arbol de
// habilidades del candidato, porque al publicar tiene que saber que
// habilidades estan activas. ArbolHabilidades.desbloquear() la recibe como
// parametro para poder cobrar el costo de una habilidad sin mezclar
// responsabilidades.
public class Partida {
    // La campana dura siete dias, como dice el periodico del menu.
    public static final int TURNOS_TOTALES = 7;
    // Puntos para el arbol al terminar cada turno: recibe mas quien peor le
    // fue, para que siempre se pueda remontar.
    public static final int PUNTOS_INICIALES = 3;
    public static final int PUNTOS_SI_PERDIO = 4;
    public static final int PUNTOS_SI_QUEDO_IGUAL = 3;
    public static final int PUNTOS_SI_GANO = 2;
    // Barrio donde el candidato tiene su sede de campana (La Colina). Por
    // ahora es el unico candidato: los rivales llegan despues.
    public static final int ZONA_SEDE = 2;
    // Apoyo de un barrio: de 0 a TOPE_APOYO. Con UMBRAL_CONQUISTA o mas, el
    // barrio es del candidato (la sede lo es siempre).
    public static final int TOPE_APOYO = 100;
    public static final int UMBRAL_CONQUISTA = 50;

    // Valores de las habilidades (ver ArbolHabilidades).
    public static final int BONO_VOLANTES = 5;
    public static final int BONO_MEGAFONO = 3;
    public static final int EXTRA_FUENTE = 10;
    public static final int PROB_FUENTE = 50;
    public static final int PROB_GOLPE = 20;
    public static final int PROB_IA = 20;
    public static final int PROB_IA_MEJORADA = 40;
    public static final int EXTRA_BOTS = 10;

    private String nombreCandidato;
    private int turno;
    private int puntos;
    private int puntosUltimoTurno;
    private Noticiero noticiero;
    private Noticia noticiaDelTurno;
    private GrafoCiudad ciudad;
    private Influencer influencer;
    private ArbolHabilidades arbol;
    private ArrayList<Tarjeta> tarjetasDelTurno;
    private int[] apoyo;
    private boolean publicoEsteTurno;
    // Lo que valio la publicacion del turno (antes de topar en 0 o en 100):
    // dice si al candidato le fue bien o mal aunque el barrio ya estuviera
    // en un limite.
    private int resultadoEsteTurno;
    private int resultadoTurnoAnterior;
    private boolean transmisionUsada;
    private Random azar;
    // Lo que se jugo en cada turno, para el mapa del noticiero: el barrio y
    // cuanto cambio el apoyo ahi (-1 en el barrio si ese turno no se jugo).
    private int[] jugadaZona = new int[TURNOS_TOTALES + 2];
    private int[] jugadaCambio = new int[TURNOS_TOTALES + 2];

    // --- La credibilidad en Civitas (de 0 a 100) ---
    // Es lo que la gente cree de lo que publica el candidato. Sube cuando
    // publica bien (comparte lo verificado, desmiente bulos, presenta las
    // opiniones como opiniones) y baja cuando riega bulos, amplifica odio o
    // lo pillan inventando con IA. Con más credibilidad sus publicaciones
    // llegan a más gente (y suman más apoyo); con poca, a menos.
    public static final int CREDIBILIDAD_INICIAL = 50;
    private int credibilidad;
    // Para el informe final ("Tu huella digital")
    private int aciertos, bulosCompartidos, odioAmplificado, usosIA, alcanceTotal;

    // Arranca siempre en el turno 1 con los puntos iniciales. Cada partida
    // tiene su propio mazo de noticias, barajado con la hora actual para que
    // no salgan siempre en el mismo orden. La sede empieza con el apoyo justo
    // para ser propia; los demas barrios, en cero.
    public void iniciar(String nombre, ArbolHabilidades arbolDelCandidato) {
        nombreCandidato = nombre;
        arbol = arbolDelCandidato;
        turno = 1;
        puntos = PUNTOS_INICIALES;
        puntosUltimoTurno = PUNTOS_INICIALES;
        long semilla = System.currentTimeMillis();
        noticiero = new Noticiero(semilla);
        influencer = new Influencer(semilla);
        azar = new Random(semilla);
        ciudad = new GrafoCiudad();
        apoyo = new int[ciudad.cantidad()];
        apoyo[ZONA_SEDE] = UMBRAL_CONQUISTA;
        resultadoTurnoAnterior = 0;
        credibilidad = CREDIBILIDAD_INICIAL;
        aciertos = bulosCompartidos = odioAmplificado = usosIA = alcanceTotal = 0;
        transmisionUsada = false;
        java.util.Arrays.fill(jugadaZona, -1);
        java.util.Arrays.fill(jugadaCambio, 0);
        prepararTurno();
    }

    // Los puntos se acumulan turno a turno en vez de reiniciarse: si el
    // jugador no gasta todo, puede ahorrar para una habilidad mas cara.
    // Cada turno nuevo trae una noticia nueva (la que cuenta la llamada) y
    // sus seis tarjetas.
    public void siguienteTurno() {
        puntosUltimoTurno = puntosPorResultado();
        puntos = puntos + puntosUltimoTurno;
        resultadoTurnoAnterior = publicoEsteTurno ? resultadoEsteTurno : 0;
        turno = turno + 1;
        if (!seAcabaronLosTurnos()) {
            prepararTurno();
        }
    }

    // Si la publicacion del turno resto, se reciben mas puntos; si sumo,
    // menos. Si no se publico, cuenta como quedar igual.
    private int puntosPorResultado() {
        if (!publicoEsteTurno || resultadoEsteTurno == 0) {
            return PUNTOS_SI_QUEDO_IGUAL;
        } else if (resultadoEsteTurno < 0) {
            return PUNTOS_SI_PERDIO;
        }
        return PUNTOS_SI_GANO;
    }

    private void prepararTurno() {
        noticiaDelTurno = noticiero.siguiente();
        tarjetasDelTurno = influencer.armarTarjetas(noticiaDelTurno);
        publicoEsteTurno = false;
        resultadoEsteTurno = 0;
    }

    // Consulta de solo lectura: separarla de gastar() permite que quien
    // llama (por ejemplo la interfaz) pregunte "se podria" sin arriesgarse
    // a modificar el estado por accidente.
    public boolean puedePagar(int costo) {
        return puntos >= costo;
    }

    // No valida nada aqui a proposito: la validacion (hay padre desbloqueado,
    // hay puntos suficientes) es responsabilidad de ArbolHabilidades.desbloquear(),
    // que solo llama a gastar() despues de confirmar que es seguro hacerlo.
    public void gastar(int costo) {
        puntos = puntos - costo;
    }

    // La campana dura TURNOS_TOTALES turnos: cuando el turno pasa de ese
    // limite, la partida se da por terminada.
    public boolean seAcabaronLosTurnos() {
        return turno > TURNOS_TOTALES;
    }

    // --- Barrios ---

    public boolean esPropio(int zona) {
        return zona == ZONA_SEDE || apoyo[zona] >= UMBRAL_CONQUISTA;
    }

    // Barrio por barrio, si es del candidato: es lo que necesita el grafo
    // para calcular a donde llega y desde donde sale una publicacion.
    public boolean[] barriosPropios() {
        boolean[] propios = new boolean[ciudad.cantidad()];
        for (int z = 0; z < propios.length; z++) {
            propios[z] = esPropio(z);
        }
        return propios;
    }

    public int contarBarriosPropios() {
        int cuenta = 0;
        for (int z = 0; z < ciudad.cantidad(); z++) {
            if (esPropio(z)) {
                cuenta++;
            }
        }
        return cuenta;
    }

    // Hasta cuantas calles de distancia del territorio se puede publicar.
    public int callesDeAlcance() {
        return arbol.tiene(ArbolHabilidades.PERFIL_VERIFICADO) ? 2 : 1;
    }

    // A que barrios se puede publicar si los propios fueran "propios". La
    // interfaz lo usa con los propios "visibles" mientras la publicacion
    // viaja (ver Celular.pde).
    public boolean[] alcanzablesDesde(boolean[] propios) {
        return ciudad.alcanzables(propios, callesDeAlcance());
    }

    public boolean puedePublicarEn(int zona) {
        return alcanzablesDesde(barriosPropios())[zona];
    }

    // --- Tarjetas y habilidades que se usan al publicar ---

    // La tarjeta de IA solo se puede usar con el Asistente de IA.
    public boolean estaBloqueada(Tarjeta t) {
        return t.getCategoria() == Influencer.IA && !arbol.tiene(ArbolHabilidades.ASISTENTE_IA);
    }

    // Probabilidad (de 100) de que no descubran la noticia de la IA.
    public int probabilidadIA() {
        if (arbol.tiene(ArbolHabilidades.IA_PERFECTA) && turno == TURNOS_TOTALES && resultadoTurnoAnterior < 0) {
            return 100;
        } else if (arbol.tiene(ArbolHabilidades.MODELO_MEJORADO)) {
            return PROB_IA_MEJORADA;
        }
        return PROB_IA;
    }

    public boolean puedeUsarTransmision() {
        return arbol.tiene(ArbolHabilidades.TRANSMISION) && !transmisionUsada;
    }

    // --- Publicar ---

    // Una publicacion por turno. Las habilidades se aplican siempre en el
    // mismo orden, despues de que el jugador eligio:
    //   1. Transmision en vivo (si se activo): la tarjeta cuenta como la mejor.
    //   2. Si es la tarjeta de IA: se sortea si la descubren.
    //      Si no es de IA: Golpe de suerte puede cambiarla por la mejor y
    //      Fuente confiable puede sumar extra si se acerto.
    //   3. Rueda de prensa: si resta, resta la mitad.
    //   4. Se aplica al barrio, sin pasarse de 0 ni de TOPE_APOYO.
    //   5. Volantes y Megafono: si sumo, los barrios de alrededor reciben un
    //      bono (BFS desde el barrio elegido: nivel 1 y nivel 2).
    // Devuelve que paso, o null si no se podia publicar.
    public Publicacion publicar(Tarjeta tarjeta, int zona, boolean usarTransmision) {
        if (publicoEsteTurno || estaBloqueada(tarjeta) || !puedePublicarEn(zona)) {
            return null;
        }
        Publicacion p = new Publicacion(zona, ciudad.cantidad());
        int categoria = tarjeta.getCategoria();
        int valor;
        if (usarTransmision && puedeUsarTransmision()) {
            transmisionUsada = true;
            categoria = Influencer.MAYOR;
            valor = Influencer.PUNTOS[categoria];
            p.agregarEfecto("Transmisión en vivo: tu publicación contó como la mejor.");
        } else if (categoria == Influencer.IA) {
            boolean descubierta = azar.nextInt(100) >= probabilidadIA();
            p.marcarIA(descubierta);
            categoria = descubierta ? Influencer.NEGATIVA : Influencer.MAYOR;
            valor = Influencer.PUNTOS[categoria];
            if (!descubierta && arbol.tiene(ArbolHabilidades.BOTS)) {
                valor += EXTRA_BOTS;
                p.agregarEfecto("Bots de difusión: +" + EXTRA_BOTS + " extra.");
            }
        } else {
            if (categoria != Influencer.MAYOR && arbol.tiene(ArbolHabilidades.GOLPE_DE_SUERTE) && azar.nextInt(100) < PROB_GOLPE) {
                categoria = Influencer.MAYOR;
                p.agregarEfecto("Golpe de suerte: tu tarjeta se cambió por la mejor.");
            }
            valor = Influencer.PUNTOS[categoria];
            boolean acerto = categoria == Influencer.MAYOR || categoria == Influencer.MENOR;
            if (acerto && arbol.tiene(ArbolHabilidades.FUENTE_CONFIABLE) && azar.nextInt(100) < PROB_FUENTE) {
                valor += EXTRA_FUENTE;
                p.agregarEfecto("Fuente confiable: +" + EXTRA_FUENTE + " extra.");
            }
        }
        // la credibilidad cambia lo que llega: con 50 queda igual, con 100
        // suma un 40 % más y con 0 un 40 % menos (solo lo bueno; lo malo
        // pesa igual)
        if (valor > 0) {
            valor = Math.round(valor * factorCredibilidad());
        }
        int antes = credibilidad;
        anotarCredibilidad(p, tarjeta, categoria);
        p.setCredibilidad(antes, credibilidad);
        p.setAlcance(calcularAlcance(categoria, tarjeta.getAccion()));
        alcanceTotal += p.getAlcance();
        boolean rueda = valor < 0 && arbol.tiene(ArbolHabilidades.RUEDA_DE_PRENSA);
        if (rueda) {
            valor = valor / 2;
        }
        p.setCategoria(categoria);
        p.setValor(valor);
        p.setCambio(cambiarApoyo(zona, valor));
        if (rueda && p.getCambio() < 0) {
            p.agregarEfecto("Rueda de prensa: perdiste solo la mitad.");
        }
        if (p.getCambio() > 0) {
            aplicarBonos(p);
        }
        publicoEsteTurno = true;
        resultadoEsteTurno = valor;
        anotarJugada(zona, p.getCambio());
        return p;
    }

    public float factorCredibilidad() {
        return 0.6f + 0.8f * credibilidad / 100f;
    }

    public int getCredibilidad() {
        return credibilidad;
    }

    public void cambiarCredibilidad(int cuanto) {
        credibilidad = Math.max(0, Math.min(100, credibilidad + cuanto));
    }

    // Lo que hizo el candidato con la noticia, en credibilidad y en la huella.
    private void anotarCredibilidad(Publicacion p, Tarjeta tarjeta, int categoria) {
        Noticia n = noticiaDelTurno;
        int accion = tarjeta.getAccion();
        boolean regaLaNoticia = accion == Influencer.COMPARTIR || accion == Influencer.EXAGERAR;
        if (p.usoIA()) {
            usosIA++;
            cambiarCredibilidad(p.iaDescubierta() ? -20 : -5);   // aunque no lo pillen, la confianza se gasta
            return;
        }
        if (categoria == Influencer.MAYOR) {
            aciertos++;
            cambiarCredibilidad(10);
        } else if (categoria == Influencer.MENOR) {
            cambiarCredibilidad(4);
        } else if (categoria == Influencer.NEGATIVA) {
            cambiarCredibilidad(-10);
        }
        if (n != null && n.getTipo() == Noticia.FALSA && regaLaNoticia) {
            bulosCompartidos++;
            cambiarCredibilidad(-8);
        }
        if (n != null && n.generaOdio() && regaLaNoticia) {
            odioAmplificado++;
            cambiarCredibilidad(-8);
        }
        if (accion == Influencer.EXAGERAR) {
            cambiarCredibilidad(-4);
        }
    }

    // Cuánta gente vio la publicación. Lo exagerado y lo falso se riega más
    // rápido (por eso engancha), pero resta: viral no es lo mismo que bueno.
    private int calcularAlcance(int categoria, int accion) {
        int base;
        if (accion == Influencer.CALLAR) {
            return 0;
        } else if (accion == Influencer.EXAGERAR || accion == Influencer.INVENTAR) {
            base = 3200;
        } else if (categoria == Influencer.MAYOR) {
            base = 2000;
        } else if (categoria == Influencer.MENOR) {
            base = 900;
        } else {
            base = 1500;
        }
        float azarito = 0.85f + azar.nextFloat() * 0.3f;
        return Math.round(base * azarito * factorCredibilidad());
    }

    public int getAciertos() {
        return aciertos;
    }

    public int getBulosCompartidos() {
        return bulosCompartidos;
    }

    public int getOdioAmplificado() {
        return odioAmplificado;
    }

    public int getUsosIA() {
        return usosIA;
    }

    public int getAlcanceTotal() {
        return alcanceTotal;
    }

    public void sumarAlcance(int vistas) {
        alcanceTotal += vistas;
    }

    // Volantes: +5 a los barrios a 1 calle del elegido. Megafono: +3 a los
    // que estan a 2 calles. Los niveles salen del BFS desde el barrio.
    private void aplicarBonos(Publicacion p) {
        boolean volantes = arbol.tiene(ArbolHabilidades.VOLANTES);
        boolean megafono = arbol.tiene(ArbolHabilidades.MEGAFONO);
        if (!volantes) {
            return;
        }
        int[] nivel = ciudad.nivelesDesde(p.getZona());
        String nivel1 = "";
        String nivel2 = "";
        for (int z = 0; z < ciudad.cantidad(); z++) {
            if (nivel[z] == 1) {
                p.setBono(z, cambiarApoyo(z, BONO_VOLANTES));
                nivel1 += (nivel1.isEmpty() ? "" : ", ") + ciudad.getNombre(z);
            } else if (nivel[z] == 2 && megafono) {
                p.setBono(z, cambiarApoyo(z, BONO_MEGAFONO));
                nivel2 += (nivel2.isEmpty() ? "" : ", ") + ciudad.getNombre(z);
            }
        }
        p.agregarEfecto("Volantes: +" + BONO_VOLANTES + " en " + nivel1 + ".");
        if (megafono && !nivel2.isEmpty()) {
            p.agregarEfecto("Megáfono: +" + BONO_MEGAFONO + " en " + nivel2 + ".");
        }
    }

    // Suma (o resta) apoyo sin pasarse de 0 ni de TOPE_APOYO y devuelve
    // cuanto cambio de verdad.
    private int cambiarApoyo(int zona, int valor) {
        int antes = apoyo[zona];
        apoyo[zona] = Math.max(0, Math.min(TOPE_APOYO, antes + valor));
        return apoyo[zona] - antes;
    }

    // La mision de la ronda 2 cuenta como la jugada del turno: cambia el
    // apoyo del barrio del bulo y, al pasar turno, da puntos igual que una
    // publicacion que sumo (o que resto). Devuelve cuanto cambio el apoyo.
    public int registrarMision(int zona, int valor) {
        int cambio = cambiarApoyo(zona, valor);
        publicoEsteTurno = true;
        resultadoEsteTurno = valor;
        anotarJugada(zona, cambio);
        return cambio;
    }

    // Los eventos del parque (rondas 3 y 4) tambien cuentan como la jugada
    // del turno, igual que la mision.
    public int registrarEvento(int zona, int valor) {
        return registrarMision(zona, valor);
    }

    // El barrio con mas apoyo (ahi se resta si el candidato queda de ultimo
    // en un evento del parque).
    public int barrioConMasApoyo() {
        int mejor = ZONA_SEDE;
        for (int z = 0; z < apoyo.length; z++) {
            if (apoyo[z] > apoyo[mejor]) {
                mejor = z;
            }
        }
        return mejor;
    }

    public boolean yaPublicoEsteTurno() {
        return publicoEsteTurno;
    }

    private void anotarJugada(int zona, int cambio) {
        if (turno < jugadaZona.length) {
            jugadaZona[turno] = zona;
            jugadaCambio[turno] = cambio;
        }
    }

    // El barrio que se jugo en ese turno (-1 si ninguno) y cuanto cambio
    public int getJugadaZona(int t) {
        return t >= 0 && t < jugadaZona.length ? jugadaZona[t] : -1;
    }

    public int apoyoTotal() {
        int s = 0;
        for (int v : apoyo) {
            s += v;
        }
        return s;
    }

    public int getApoyo(int zona) {
        return apoyo[zona];
    }

    public String getNombreCandidato() {
        return nombreCandidato;
    }

    public int getTurno() {
        return turno;
    }

    public int getPuntos() {
        return puntos;
    }

    public int getPuntosUltimoTurno() {
        return puntosUltimoTurno;
    }

    public Noticia getNoticiaDelTurno() {
        return noticiaDelTurno;
    }

    public GrafoCiudad getCiudad() {
        return ciudad;
    }

    public Influencer getInfluencer() {
        return influencer;
    }

    public ArrayList<Tarjeta> getTarjetasDelTurno() {
        return tarjetasDelTurno;
    }
}
