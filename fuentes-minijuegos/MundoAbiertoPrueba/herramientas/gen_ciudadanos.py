# Variantes de color de la gente del parque (a partir de los dibujos de Infiltrado)
import sys
from PIL import Image
src, dst = sys.argv[1], sys.argv[2]
CAMISA = [(201, 205, 211), (138, 147, 168), (230, 232, 236)]      # base, sombra, brillo
CORBATA = (255, 46, 136)
PIEL = [(201, 138, 94), (142, 90, 58)]
PELO = [(42, 26, 18)]
PANTALON = [(43, 47, 69), (30, 39, 66)]
def tonos(c):
    return [c, tuple(int(v * 0.68) for v in c), tuple(min(255, int(v + (255 - v) * 0.35)) for v in c)]
variantes = [
    # camisa, corbata/detalle, piel, pelo, pantalon
    ((242, 200, 80), (214, 62, 52), PIEL, (42, 26, 18), [(70, 96, 150), (50, 70, 116)]),
    ((120, 190, 120), (246, 240, 226), [(227, 167, 126), (176, 118, 84)], (122, 74, 53), [(120, 100, 76), (90, 74, 56)]),
    ((236, 132, 160), (250, 240, 230), [(150, 98, 64), (104, 66, 42)], (24, 18, 14), [(43, 47, 69), (30, 39, 66)]),
    ((120, 176, 220), (40, 70, 140), PIEL, (186, 140, 70), [(176, 160, 120), (136, 122, 90)]),
    ((240, 150, 70), (250, 230, 150), [(120, 76, 48), (84, 52, 32)], (24, 18, 14), [(70, 96, 150), (50, 70, 116)]),
    ((246, 244, 236), (66, 150, 86), [(227, 167, 126), (176, 118, 84)], (60, 40, 26), [(150, 70, 60), (110, 50, 44)]),
    ((160, 120, 200), (246, 240, 226), PIEL, (42, 26, 18), [(43, 47, 69), (30, 39, 66)]),
    ((96, 170, 160), (236, 190, 60), [(150, 98, 64), (104, 66, 42)], (122, 74, 53), [(120, 100, 76), (90, 74, 56)]),
]
for n, (camisa, detalle, piel, pelo, pant) in enumerate(variantes):
    mapa = {}
    for a, b in zip(CAMISA, tonos(camisa)): mapa[a] = b
    mapa[CORBATA] = detalle
    for a, b in zip(PIEL, piel): mapa[a] = b
    mapa[PELO[0]] = pelo
    for a, b in zip(PANTALON, pant): mapa[a] = b
    for lado in ('frente', 'espalda'):
        for k in range(3):
            im = Image.open(f'{src}/civil_{lado}_{k}.png').convert('RGBA')
            px = im.load()
            for y in range(im.height):
                for x in range(im.width):
                    r, g, b_, a = px[x, y]
                    if a and (r, g, b_) in mapa:
                        px[x, y] = mapa[(r, g, b_)] + (a,)
            im.save(f'{dst}/ciudadano{n}_{lado}_{k}.png')
print(len(variantes), 'variantes')
