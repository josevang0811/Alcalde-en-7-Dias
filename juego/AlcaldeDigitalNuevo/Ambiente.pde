// Ambiente — la corrección de color del mundo abierto.
//
// La ciudad se dibuja con los colores originales del equipo de diseño y,
// justo antes del HUD, un shader (data/ambiente/ambiente.glsl) le cambia el
// tono: así el mundo se ve más pesado sin redibujar ningún sprite. El HUD,
// los avisos y Civitas en vivo se dibujan después, con sus colores de
// siempre.
//
// Cada ambiente es una fila de AJUSTES_AMBIENTE. Para probar cambios sin
// abrir el juego está herramientas/ambiente_pruebas.py, que hace las mismas
// cuentas sobre una captura.
//
// El ambiente elegido se guarda en data/ajustes.txt (ambiente=noche) y se
// cambia dentro del mundo abierto con la tecla F8.

final String[] AMBIENTES = {"ninguno", "nublado", "atardecer", "noche"};

// saturación, sombras (r, g, b), luces (r, g, b), fuerza del tono,
// contraste, centro del contraste, brillo, viñeta
final float[][] AJUSTES_AMBIENTE = {
    {},
    {0.48, 0.55, 0.68, 0.78, 0.78, 0.74, 0.66, 0.55, 1.12, 0.45, 0.80, 0.45},
    {0.60, 0.45, 0.42, 0.70, 1.00, 0.70, 0.45, 0.70, 1.12, 0.50, 0.82, 0.50},
    {0.35, 0.26, 0.34, 0.62, 0.62, 0.72, 0.95, 0.85, 1.25, 0.45, 0.55, 0.60}
};

String ambienteMundo = "noche";
PShader shaderAmbiente;
boolean ambienteFallo = false;     // si el shader no compila, se sigue sin él

void aplicarAmbiente() {
    int i = indiceAmbiente();
    if (ambienteFallo || i <= 0 || !(g instanceof PGraphicsOpenGL)) {
        return;
    }
    try {
        if (shaderAmbiente == null) {
            shaderAmbiente = loadShader("ambiente/ambiente.glsl");
        }
        float[] a = AJUSTES_AMBIENTE[i];
        shaderAmbiente.set("saturacion", a[0]);
        shaderAmbiente.set("tonoSombras", a[1], a[2], a[3]);
        shaderAmbiente.set("tonoLuces", a[4], a[5], a[6]);
        shaderAmbiente.set("fuerzaTono", a[7]);
        shaderAmbiente.set("contraste", a[8]);
        shaderAmbiente.set("centroContraste", a[9]);
        shaderAmbiente.set("brillo", a[10]);
        shaderAmbiente.set("vineta", a[11]);
        filter(shaderAmbiente);
    } catch (Exception e) {
        ambienteFallo = true;
        println("Ambiente: no se pudo aplicar la corrección de color (" + e.getMessage() + ")");
    }
}

int indiceAmbiente() {
    for (int k = 0; k < AMBIENTES.length; k++) {
        if (AMBIENTES[k].equals(ambienteMundo)) {
            return k;
        }
    }
    return 0;
}

// F8 pasa al siguiente ambiente (para que el equipo los compare jugando).
void siguienteAmbiente() {
    ambienteMundo = AMBIENTES[(indiceAmbiente() + 1) % AMBIENTES.length];
    guardarAjustes();
}
