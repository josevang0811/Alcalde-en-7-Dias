// LetraGlobal — todo el texto del juego en la letra pixel (Diseno.pde).
//
// En vez de cambiar cada text() del juego (son cientos, en la oficina, el
// celular, el mundo abierto, la misión...), aquí se reemplazan las
// funciones de texto de Processing: text() y textWidth() dibujan y miden
// con la letra pixel de 5 x 7. Se respeta lo que ya decía el código: el
// tamaño (textSize, que pone usarLetra), el color (fill) y la alineación
// (textAlign). Así todo se ve igual que el libro, el mapa y la TV.
//
// Cada texto se arma una sola vez en blanco y se guarda; al dibujarlo se
// tiñe con el color del fill (así un texto que se desvanece no crea una
// imagen por cada transparencia).

HashMap<String, PImage> textosBlancos = new HashMap<String, PImage>();

// Lo que mide un pixel de la letra para el tamaño actual: las mayúsculas
// de la letra pixel quedan del alto de las de la letra normal.
float celdaDeTamano() {
    // en medios pixeles, para que los cuadritos de la letra queden parejos
    return max(1, round(g.textSize / 9.0 * 2) / 2.0);
}

PImage textoBlanco(String texto) {
    PImage img = textosBlancos.get(texto);
    if (img == null) {
        if (textosBlancos.size() > 3000) {
            textosBlancos.clear();   // los textos que cambian cada cuadro (relojes) no se acumulan
        }
        img = imagenTextoPixel(texto, 1, #ffffff, 0, 0, 0, false);
        textosBlancos.put(texto, img);
    }
    return img;
}

// Una línea en (x, y) con la alineación actual
void lineaPixel(String texto, float x, float y, float celda) {
    if (texto.length() == 0) {
        return;
    }
    float ancho = medirPixel(texto) * celda;
    float alto = 7 * celda;
    float x0 = x;
    if (g.textAlign == CENTER) {
        x0 = x - ancho / 2;
    } else if (g.textAlign == RIGHT) {
        x0 = x - ancho;
    }
    float y0;
    if (g.textAlignY == TOP) {
        y0 = y;
    } else if (g.textAlignY == CENTER) {
        y0 = y - alto / 2;
    } else if (g.textAlignY == BOTTOM) {
        y0 = y - alto - celda * 2;
    } else {
        y0 = y - alto;   // BASELINE: la línea de abajo de las mayúsculas
    }
    PImage img = textoBlanco(texto);
    boolean conTinte = g.tint;
    int tinte = g.tintColor;
    // el color del fill, multiplicado por el tint que ya hubiera (un fundido)
    tint(conTinte ? multiplicarColor(g.fillColor, tinte) : g.fillColor);
    image(img, x0 - MARGEN_PIXEL * celda, y0 - (MARGEN_PIXEL + 2) * celda, img.width * celda, img.height * celda);
    if (conTinte) {
        tint(tinte);
    } else {
        noTint();
    }
}

color multiplicarColor(color a, color b) {
    return color(red(a) * red(b) / 255, green(a) * green(b) / 255, blue(a) * blue(b) / 255, alpha(a) * alpha(b) / 255);
}

@Override
public void text(String texto, float x, float y) {
    if (texto == null || !g.fill) {
        return;
    }
    float celda = celdaDeTamano();
    String[] lineas = split(texto, '\n');
    float paso = 11 * celda;
    // con varias líneas, la alineación vertical es la del bloque
    float y0 = y;
    if (lineas.length > 1) {
        if (g.textAlignY == CENTER) {
            y0 = y - (lineas.length - 1) * paso / 2;
        } else if (g.textAlignY == BOTTOM || g.textAlignY == BASELINE) {
            y0 = y - (lineas.length - 1) * paso;
        }
    }
    for (int i = 0; i < lineas.length; i++) {
        lineaPixel(lineas[i], x, y0 + i * paso, celda);
    }
}

@Override
public void text(String texto, float x, float y, float z) {
    text(texto, x, y);
}

@Override
public void text(char c, float x, float y) {
    text(String.valueOf(c), x, y);
}

@Override
public void text(int n, float x, float y) {
    text(String.valueOf(n), x, y);
}

@Override
public void text(float n, float x, float y) {
    text(nfs(n, 0, 3).trim(), x, y);
}

// El texto en una caja: se parte en líneas que quepan en el ancho
@Override
public void text(String texto, float x1, float y1, float x2, float y2) {
    if (texto == null || !g.fill) {
        return;
    }
    float ancho = x2, alto = y2;   // en el modo CORNER (el de siempre) son ancho y alto
    float celda = celdaDeTamano();
    int maxCeldas = max(1, floor(ancho / celda));
    ArrayList<String> lineas = new ArrayList<String>();
    for (String parrafo : split(texto, '\n')) {
        lineas.addAll(partirPixel(parrafo, maxCeldas));
    }
    float paso = 11 * celda;
    int alinY = g.textAlignY;
    float yTexto = y1;
    float total = lineas.size() * paso;
    if (alinY == CENTER) {
        yTexto = y1 + (alto - total) / 2;
    } else if (alinY == BOTTOM) {
        yTexto = y1 + alto - total;
    }
    float xTexto = g.textAlign == CENTER ? x1 + ancho / 2 : (g.textAlign == RIGHT ? x1 + ancho : x1);
    textAlign(g.textAlign, TOP);
    for (int i = 0; i < lineas.size(); i++) {
        if (alinY == TOP && (i + 1) * paso > alto + paso * 0.5) {
            break;   // como Processing: lo que no cabe en la caja no se ve
        }
        lineaPixel(lineas.get(i), xTexto, yTexto + i * paso, celda);
    }
    textAlign(g.textAlign, alinY);
}

@Override
public float textWidth(String texto) {
    if (texto == null) {
        return 0;
    }
    float mayor = 0;
    for (String linea : split(texto, '\n')) {
        mayor = max(mayor, medirPixel(linea));
    }
    return mayor * celdaDeTamano();
}

@Override
public float textWidth(char c) {
    return textWidth(String.valueOf(c));
}

@Override
public float textAscent() {
    return 7 * celdaDeTamano();
}

@Override
public float textDescent() {
    return 2 * celdaDeTamano();
}
