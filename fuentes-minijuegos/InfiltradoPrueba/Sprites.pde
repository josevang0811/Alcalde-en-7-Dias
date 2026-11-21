// Sprites en pixel art (carpeta data/). Estan hechos a tamano real (una
// baldosa mide 32x16 pixeles) y se dibujan agrandados "pixel" veces sin
// suavizar, asi cada pixel del dibujo se ve como un cuadrito.

PImage[] pisoAlfombra = new PImage[2];
PImage[] pisoMadera = new PImage[2];
PImage[] pisoBaldosa = new PImage[2];
PImage[] paredLadrillo = new PImage[2];
PImage paredNeon, paredNeonLuz, paredLetrero, paredLetreroLuz, paredBaja;
PImage servidorLuzCopiado;   // el servidor ya copiado (los demás muebles van en spriteObjeto)
PImage brillo;   // mancha de luz blanca y suave, se pinta del color de cada luz
PImage[] pisoAsfalto = new PImage[2];
PImage[] pisoMetal = new PImage[2];
PImage[] pisoNegro = new PImage[2];
PImage[] pisoBlanca = new PImage[2];
PImage[] pisoRoja = new PImage[2];
// Sprite (y su parte que brilla) de cada letra del mapa: muebles, objetos y puertas
PImage[] spriteObjeto = new PImage[128];
PImage[] spriteObjetoLuz = new PImage[128];

SpritesPersona spritesJugador1, spritesJugador2, spritesVigilante;
SpritesPersona spritesCivil, spritesCivil2, spritesJefe, spritesConserje1, spritesConserje2;

// Los cuadros de un personaje: de frente y de espaldas, quieto y dos pasos
// de caminar, y agachado (solo los jugadores).
class SpritesPersona {
  PImage[] frente = new PImage[3];
  PImage[] espalda = new PImage[3];
  PImage frenteAgachado, espaldaAgachado;

  SpritesPersona(String nombre, boolean conAgachado) {
    for (int k = 0; k < 3; k++) {
      frente[k] = loadImage(nombre + "_frente_" + k + ".png");
      espalda[k] = loadImage(nombre + "_espalda_" + k + ".png");
    }
    if (conAgachado) {
      frenteAgachado = loadImage(nombre + "_frente_agachado.png");
      espaldaAgachado = loadImage(nombre + "_espalda_agachado.png");
    }
  }
}

void cargarSprites() {
  for (int k = 0; k < 2; k++) {
    pisoAlfombra[k] = loadImage("piso_alfombra_" + k + ".png");
    pisoMadera[k] = loadImage("piso_madera_" + k + ".png");
    pisoBaldosa[k] = loadImage("piso_baldosa_" + k + ".png");
    paredLadrillo[k] = loadImage("pared_" + k + ".png");
  }
  paredNeon = loadImage("pared_neon.png");
  paredNeonLuz = loadImage("pared_neon_luz.png");
  paredLetrero = loadImage("pared_letrero.png");
  paredLetreroLuz = loadImage("pared_letrero_luz.png");
  paredBaja = loadImage("pared_baja.png");
  servidorLuzCopiado = loadImage("servidor_luz_copiado.png");
  brillo = loadImage("brillo.png");
  for (int k = 0; k < 2; k++) {
    pisoAsfalto[k] = loadImage("piso_asfalto_" + k + ".png");
    pisoMetal[k] = loadImage("piso_metal_" + k + ".png");
    pisoNegro[k] = loadImage("piso_negro_" + k + ".png");
    pisoBlanca[k] = loadImage("piso_blanca_" + k + ".png");
    pisoRoja[k] = loadImage("piso_roja_" + k + ".png");
  }
  ponerSprite('A', "armario", false);
  ponerSprite('M', "escritorio", true);
  ponerSprite('S', "servidor", true);
  ponerSprite('L', "farol", true);
  ponerSprite('P', "prueba", false);
  ponerSprite('h', "disco_duro", true);
  ponerSprite('l', "laptop", true);
  ponerSprite('m', "moto", true);
  ponerSprite('E', "camioneta", true);
  ponerSprite('T', "tablero_electrico", true);
  ponerSprite('r', "tarjeta_roja", true);
  ponerSprite('b', "tarjeta_azul", true);
  ponerSprite('y', "tarjeta_amarilla", true);
  ponerSprite('n', "nota", false);
  ponerSprite('o', "botella", false);
  ponerSprite('C', "carro", true);
  ponerSprite('p', "planta", false);
  ponerSprite('I', "impresora", true);
  ponerSprite('V', "camara_estudio", true);
  ponerSprite('Q', "consola", true);
  ponerSprite('O', "escritorio_rival", true);
  ponerSprite('W', "tv_rival", true);
  ponerSprite('X', "tablero_conspiracion", false);
  ponerSprite('U', "cuaderno_rival", true);
  ponerSprite('H', "sofa", false);
  ponerSprite('Z', "casillero", false);
  ponerSprite('F', "cafetera", true);
  ponerSprite('v', "rejilla", false);
  ponerSprite('c', "caseta", true);
  ponerSprite('z', "contenedor", false);
  ponerSprite('G', "pantalla_verde", false);
  ponerSprite('1', "puerta_roja", true);
  ponerSprite('2', "puerta_azul", true);
  ponerSprite('3', "puerta_amarilla", true);
  ponerSprite('4', "puerta_codigo", true);
  spritesJugador1 = new SpritesPersona("jugador1", true);
  spritesJugador2 = new SpritesPersona("jugador2", true);
  spritesVigilante = new SpritesPersona("vigilante", false);
  spritesCivil = new SpritesPersona("civil", false);
  spritesCivil2 = new SpritesPersona("civil2", false);
  spritesJefe = new SpritesPersona("jefe", false);
  spritesConserje1 = new SpritesPersona("jugador1_conserje", true);
  spritesConserje2 = new SpritesPersona("jugador2_conserje", true);
}

void ponerSprite(char letra, String nombre, boolean conLuz) {
  spriteObjeto[letra] = loadImage(nombre + ".png");
  if (conLuz) spriteObjetoLuz[letra] = loadImage(nombre + "_luz.png");
}

// Dibuja un sprite agrandado. (x, y) es la esquina de arriba a la izquierda
// en pantalla; se redondea para que los pixeles no queden partidos.
void sprite(PImage img, float x, float y) {
  image(img, round(x), round(y), img.width * pixel, img.height * pixel);
}

// Tinte segun la luz de la baldosa (azul de noche, rojo cerca de un farol...)
void tinteLuz(int i, int j, float alfa) {
  i = constrain(i, 0, mapa.ancho - 1);
  j = constrain(j, 0, mapa.alto - 1);
  tint(min(255, mapa.luzR[i][j] * 255), min(255, mapa.luzG[i][j] * 255), min(255, mapa.luzB[i][j] * 255), alfa);
}

// Mancha de luz de color, transparente, encima de lo ya dibujado: da el
// brillo de neon. "radio" en baldosas; "aplastada" la deja ovalada como
// se ve un circulo en el piso isometrico.
void manchaLuz(float sx, float sy, float radio, color c, float alfa, boolean aplastada) {
  float w = radio * anchoBaldosa * 1.414;
  float h = aplastada ? w / 2 : w;
  tint(red(c), green(c), blue(c), min(255, alfa));
  image(brillo, sx - w / 2, sy - h / 2, w, h);
  noTint();
}
