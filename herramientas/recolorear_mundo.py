# Recolorea los dibujos del mundo abierto con una paleta más profunda.
#
# No cambia la forma de nada: a cada color le aplica la misma regla (en el
# espacio de color OKLab, que se parece a como vemos):
#   - todo un poco más oscuro, sobre todo los tonos medios y claros;
#   - las sombras tiran a azul y las luces a cálido (como en el pixel art
#     con "hue shifting"), en vez de solo oscurecer con gris;
#   - los verdes amarillentos (pasto "Stardew") pasan a verde bosque;
#   - los amarillos y cremas pasan a ocre y piedra.
#
# Uso (desde la raíz del repositorio):
#   python herramientas/recolorear_mundo.py arte/originales/mundo juego/AlcaldeDigitalNuevo/data/mundo 1.4
# Siempre se parte de los originales (arte/originales/mundo): si se corre sobre
# data/mundo, el cambio se aplica dos veces. El equipo eligió el nivel 1.4.
# Si cambia el nivel, también hay que cambiar el background() de MundoAbierto
# (el script lo imprime al final).
# choques.png y zonas.png no se tocan: son mapas de datos, no dibujos.
import os, sys, numpy as np

# 1 = el nivel elegido; 0 = casi sin cambio; 1.5 = todavía más oscuro
PROFUNDIDAD = 1.0
from PIL import Image

def a_lineal(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)

def a_srgb(c):
    c = np.clip(c, 0, 1)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055)

def rgb_a_oklab(rgb):
    r, g, b = a_lineal(rgb).T
    l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
    m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
    s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b
    l, m, s = np.cbrt(l), np.cbrt(m), np.cbrt(s)
    return np.stack([0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
                     1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
                     0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s], -1)

def oklab_a_rgb(lab):
    L, a, b = lab.T
    l = (L + 0.3963377774 * a + 0.2158037573 * b) ** 3
    m = (L - 0.1055613458 * a - 0.0638541728 * b) ** 3
    s = (L - 0.0894841775 * a - 1.2914855480 * b) ** 3
    return a_srgb(np.stack([4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
                            -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
                            -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s], -1))

def acercar(h, desde, hasta, centro, objetivo, fuerza):
    # mueve los tonos entre 'desde' y 'hasta' hacia 'objetivo' (más fuerte cerca de 'centro')
    dentro = (h >= desde) & (h <= hasta)
    peso = np.clip(1 - np.abs(h - centro) / ((hasta - desde) / 2), 0, 1) * fuerza
    return np.where(dentro, h + (objetivo - h) * peso, h)

def profundo(rgb, k=1.0):
    lab = rgb_a_oklab(rgb)
    L, a, b = lab[:, 0], lab[:, 1], lab[:, 2]
    C = np.hypot(a, b)
    h = np.degrees(np.arctan2(b, a)) % 360
    # 1. más oscuro, sobre todo arriba
    L2 = 0.05 + (0.86 - 0.08 * k) * L ** (1 + 0.3 * k)
    # 2. verdes amarillentos -> verde bosque; amarillos -> ocre; cian -> azul petróleo
    h = acercar(h, 95, 150, 125, 150 + 6 * k, 0.85)
    h = acercar(h, 70, 105, 90, 72, 0.6)
    h = acercar(h, 190, 240, 215, 228, 0.5)
    C2 = C * np.where(C > 0.10, 0.88, 1.0)
    C2 = np.where((h > 120) & (h < 175), C2 * (1 - 0.18 * k), C2)   # verdes menos chillones
    C2 = np.where((L > 0.7) & (C < 0.08) & (h > 60) & (h < 110), C2 * (1 - 0.35 * k), C2)   # cremas y arena -> piedra (no los árboles amarillos)
    a2 = C2 * np.cos(np.radians(h))
    b2 = C2 * np.sin(np.radians(h))
    # 3. sombras hacia azul, luces hacia cálido
    oscuro = np.clip((0.55 - L2) / 0.45, 0, 1)
    claro = np.clip((L2 - 0.55) / 0.4, 0, 1)
    a2 += (-0.010 * oscuro + 0.006 * claro) * k
    b2 += (-0.032 * oscuro + 0.014 * claro) * k
    return oklab_a_rgb(np.stack([L2, a2, b2], -1))

def recolorear(img, k=1.0):
    arr = np.asarray(img.convert('RGBA'))
    rgb = arr[..., :3].reshape(-1, 3)
    unicos, inv = np.unique(rgb, axis=0, return_inverse=True)
    nuevos = (profundo(unicos / 255.0, k) * 255 + 0.5).astype(np.uint8)
    out = arr.copy()
    out[..., :3] = nuevos[inv.reshape(-1)].reshape(arr.shape[:2] + (3,))
    return Image.fromarray(out, 'RGBA')

def color_suelto(r, g, b, k=1.0):
    c = (profundo(np.array([[r, g, b]]) / 255.0, k)[0] * 255 + 0.5).astype(int)
    return tuple(int(v) for v in c)

if __name__ == '__main__':
    origen, destino = sys.argv[1], sys.argv[2]
    if len(sys.argv) > 3:
        PROFUNDIDAD = float(sys.argv[3])
    os.makedirs(destino, exist_ok=True)
    for f in sorted(os.listdir(origen)):
        src = os.path.join(origen, f)
        if f.endswith('.png') and f not in ('choques.png', 'zonas.png'):
            recolorear(Image.open(src), PROFUNDIDAD).save(os.path.join(destino, f))
        else:
            with open(src, 'rb') as a, open(os.path.join(destino, f), 'wb') as b:
                b.write(a.read())
    print('fondo del mundo (antes 150,196,226):', color_suelto(150, 196, 226, PROFUNDIDAD))
