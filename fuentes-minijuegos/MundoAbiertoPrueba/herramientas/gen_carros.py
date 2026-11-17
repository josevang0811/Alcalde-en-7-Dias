# Dibujos de los carros del mundo abierto en 8 direcciones (pixel art isometrico).
# Misma proyeccion que la ciudad: X = x - y, Y = (x + y)/2 - z (unidades: 16 por baldosa).
# Cada dibujo mide ANCHO x ALTO y el centro del carro (en el piso) cae en (ANCLA_X, ANCLA_Y).
# Uso: python3 gen_carros.py <carpeta de salida>
import math, sys
import numpy as np
from PIL import Image, ImageDraw

SALIDA = sys.argv[1] if len(sys.argv) > 1 else '.'
ANCHO, ALTO = 64, 48
ANCLA_X, ANCLA_Y = 32, 32
OUT = (43, 30, 26)

# color de la carroceria de cada variante (la 7 es el taxi amarillo)
VARIANTES = [(214, 62, 52), (60, 112, 200), (96, 166, 120), (236, 236, 228), (150, 60, 120),
             (52, 96, 196), (236, 140, 50), (240, 196, 48)]
TAXI = 7

def mezcla(c, f):
    return tuple(max(0, min(255, int(v * f))) for v in c[:3])

def aclarar(c, f):
    return tuple(min(255, int(v + (255 - v) * f)) for v in c[:3])

def P(x, y, z):
    return (ANCLA_X + (x - y), ANCLA_Y + (x + y) / 2 - z)

class Carro:
    def __init__(self, ang):
        self.c, self.s = math.cos(ang), math.sin(ang)
        self.img = Image.new('RGBA', (ANCHO, ALTO), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)

    # (u, v) son medidas del carro: u hacia adelante, v hacia su izquierda
    def mundo(self, u, v):
        return (u * self.c - v * self.s, u * self.s + v * self.c)

    def pt(self, u, v, z):
        x, y = self.mundo(u, v)
        return P(x, y, z)

    def poly(self, pts, col):
        q = [self.pt(*p) for p in pts]
        self.d.polygon(q, fill=col, outline=col)

    # Caja girada: lados visibles (los que miran hacia abajo de la pantalla) y tapa
    def caja(self, u0, u1, v0, v1, z0, z1, col, top=None, caras=None):
        top = top or aclarar(col, 0.18)
        esquinas = [(u1, v1), (u1, v0), (u0, v0), (u0, v1)]
        visibles = []
        for k in range(4):
            a, b = esquinas[k], esquinas[(k + 1) % 4]
            # normal hacia afuera en (u, v)
            mu, mv = (a[0] + b[0]) / 2 - (u0 + u1) / 2, (a[1] + b[1]) / 2 - (v0 + v1) / 2
            nx, ny = self.mundo(mu, mv)
            l = math.hypot(nx, ny) or 1
            nx, ny = nx / l, ny / l
            if nx + ny > 0.02:
                visibles.append((nx + ny, k, a, b, nx, ny))
        visibles.sort()
        for _, k, a, b, nx, ny in visibles:
            f = 0.78 + 0.22 * (ny - nx + 1) / 2
            self.poly([(a[0], a[1], z0), (b[0], b[1], z0), (b[0], b[1], z1), (a[0], a[1], z1)], mezcla(col, f))
            if caras:
                caras(k, a, b, nx, ny)
        self.poly([(u0, v0, z1), (u1, v0, z1), (u1, v1, z1), (u0, v1, z1)], top)
        return visibles

    def contorno(self):
        a = np.array(self.img)
        m = a[..., 3] > 0
        p = np.pad(m, 1)
        dil = p[:-2, 1:-1] | p[2:, 1:-1] | p[1:-1, :-2] | p[1:-1, 2:]
        a[dil & ~m] = OUT + (255,)
        self.img = Image.fromarray(a)

def dibujar_carro(ang, col, taxi):
    k = Carro(ang)
    L, W = 13.0, 7.0    # medio largo y medio ancho (unidades)
    rueda = (34, 32, 32)
    for (u, v) in [(L - 4, W), (L - 4, -W), (-L + 4, W), (-L + 4, -W)]:
        k.caja(u - 2.6, u + 2.6, v - 1.2, v + 1.2, 0, 4.5, rueda)
    vidrio = (70, 104, 136)
    vidrio2 = (110, 160, 200)

    def caras_carroceria(i, a, b, nx, ny):
        # faros adelante (cara i=0, u = +L) y luces rojas atras (i=2, u = -L)
        if i == 0:
            for v in (W - 2.5, -W + 2.5):
                k.poly([(L + 0.1, v - 1.2, 5.5), (L + 0.1, v + 1.2, 5.5), (L + 0.1, v + 1.2, 7.5), (L + 0.1, v - 1.2, 7.5)], (250, 244, 210))
        if i == 2:
            for v in (W - 2.5, -W + 2.5):
                k.poly([(-L - 0.1, v - 1.2, 5.5), (-L - 0.1, v + 1.2, 5.5), (-L - 0.1, v + 1.2, 7.5), (-L - 0.1, v - 1.2, 7.5)], (200, 40, 40))

    k.caja(-L, L, -W, W, 2.5, 8.5, col, caras=caras_carroceria)
    cu0, cu1 = -L + 6, L - 7

    def caras_cabina(i, a, b, nx, ny):
        # ventana en cada cara visible de la cabina
        f = 0.12
        a2 = (a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f)
        b2 = (b[0] + (a[0] - b[0]) * f, b[1] + (a[1] - b[1]) * f)
        g = vidrio2 if i == 0 else vidrio
        k.poly([(a2[0], a2[1], 9.5), (b2[0], b2[1], 9.5), (b2[0], b2[1], 13.5), (a2[0], a2[1], 13.5)], g)

    k.caja(cu0, cu1, -W + 1, W - 1, 8.5, 14.5, col, caras=caras_cabina)
    if taxi:
        k.caja(-1.5, 2.5, -2.5, 2.5, 14.5, 17, (250, 244, 220))
    k.contorno()
    return k.img

if __name__ == '__main__':
    for v, col in enumerate(VARIANTES):
        for d in range(8):
            img = dibujar_carro(d * math.pi / 4, col, v == TAXI)
            img.save(f'{SALIDA}/carro_{v}_{d}.png')
    if len(sys.argv) < 3:
        print('ok', len(VARIANTES) * 8, 'dibujos')
        sys.exit(0)
    # hoja de muestra (con un segundo argumento)
    hoja = Image.new('RGBA', (ANCHO * 8, ALTO * len(VARIANTES)), (200, 196, 186, 255))
    for v in range(len(VARIANTES)):
        for d in range(8):
            hoja.alpha_composite(Image.open(f'{SALIDA}/carro_{v}_{d}.png'), (d * ANCHO, v * ALTO))
    hoja.save(f'{SALIDA}/../carros_muestra.png')
    print('ok', len(VARIANTES) * 8, 'dibujos')
