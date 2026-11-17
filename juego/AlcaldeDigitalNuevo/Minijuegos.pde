// Minijuegos — qué ronda es de llamada y cuál de minijuego.
//
// Las 7 rondas se intercalan: 1, 3, 5 y 7 son de llamada (la periodista, el
// celular y las tarjetas); 2, 4 y 6 son de minijuego. Al empezar la campaña
// se barajan los minijuegos de la lista y se toman los tres primeros, así que
// cada campaña tiene otro orden y ninguno se repite. En red, el anfitrión
// baraja y les manda el orden a los demás (Red.pde) para que todos jueguen lo
// mismo en la misma ronda.
//
// Para agregar un minijuego nuevo: se agrega a la lista y Valeria lo presenta
// en su llamada (EventoParque.pde o MisionCampana.pde).

final int MINI_INFILTRADO = 0, MINI_VOLANTES = 1, MINI_GENTE = 2, MINI_LIVES = 3;
final String[] NOMBRES_MINIJUEGO = {"Infiltrado", "Volantes", "Convencer a la gente", "Lives"};
final int[] RONDAS_MINIJUEGO = {2, 4, 6};
int[] ordenMinijuegos = {MINI_INFILTRADO, MINI_VOLANTES, MINI_GENTE};
int rondaMinijuegoHecha = -1;     // el turno en que ya se jugó el minijuego

// Baraja la lista (Fisher-Yates, con el shuffle de IntList) y toma los primeros
void sortearMinijuegos() {
    IntList lista = new IntList();
    for (int k = 0; k < NOMBRES_MINIJUEGO.length; k++) {
        lista.append(k);
    }
    lista.shuffle();
    for (int i = 0; i < RONDAS_MINIJUEGO.length; i++) {
        ordenMinijuegos[i] = lista.get(i);
    }
    rondaMinijuegoHecha = -1;
}

// El minijuego de la ronda actual, o -1 si es ronda de llamada
int minijuegoDeRonda() {
    return minijuegoDelTurno(partida.getTurno());
}

int minijuegoDelTurno(int turno) {
    for (int i = 0; i < RONDAS_MINIJUEGO.length; i++) {
        if (RONDAS_MINIJUEGO[i] == turno) {
            return ordenMinijuegos[i];
        }
    }
    return -1;
}

boolean minijuegoHecho() {
    return rondaMinijuegoHecha == partida.getTurno();
}

// "2,0,3" (para mandarlo por la red)
String textoOrdenMinijuegos() {
    return join(nf(ordenMinijuegos, 0), ",");
}

void leerOrdenMinijuegos(String s) {
    int[] v = int(split(trim(s), ','));
    if (v.length != RONDAS_MINIJUEGO.length) {
        return;
    }
    for (int i = 0; i < v.length; i++) {
        ordenMinijuegos[i] = constrain(v[i], 0, NOMBRES_MINIJUEGO.length - 1);
    }
}
