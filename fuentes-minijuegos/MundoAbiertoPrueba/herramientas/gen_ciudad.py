# Boceto de la ciudad (mundo abierto) en pixel art isometrico, de dia.
# Misma proyeccion que Infiltrado: una baldosa mide 32x16 pixeles.
# Mundo en "unidades": 16 unidades por baldosa. iso: X = x - y, Y = (x + y)/2 - z
# Se arma con: ciudad_parte1.py + objetos (de gen_parque.py) + ciudad_parte2.py
import math, random, sys, re
import numpy as np
from PIL import Image, ImageDraw

random.seed(11)
rng = np.random.default_rng(11)
T = 16
DATA_INF = sys.argv[1] if len(sys.argv) > 1 else '.'
SALIDA = sys.argv[2] if len(sys.argv) > 2 else '.'
DISENO = sys.argv[3] if len(sys.argv) > 3 else 'Diseno.pde'
OUT = (43, 30, 26)

# ------------------------------------------------------------------ trazado
# E: borde, S: anden, R: via (4 baldosas, un carril por sentido de 2), K: manzana
SEGX = [('E', 8), ('S', 2), ('R', 4), ('S', 2), ('K', 20), ('S', 2), ('R', 4), ('S', 2), ('K', 24),
        ('S', 2), ('R', 4), ('S', 2), ('K', 20), ('S', 2), ('R', 4), ('S', 2), ('E', 4)]
SEGY = [('E', 4)] + SEGX[1:]

def expandir(seg):
    kind, blk, origen, pos, b = [], [], {}, 0, -1
    for k, n in seg:
        if k == 'K':
            b += 1
            origen[b] = pos
        kind += [k] * n
        blk += [b if k == 'K' else -1] * n
        pos += n
    return np.array(kind), np.array(blk), origen, pos

KINDX, BLKX, ORX, NTX = expandir(SEGX)
KINDY, BLKY, ORY, NTY = expandir(SEGY)
TAMX = {0: 20, 1: 24, 2: 20}
TAMY = {0: 20, 1: 24, 2: 20}
SZX, SZY = NTX * T, NTY * T
OX = SZY
OY = 170
W = SZX + SZY
H = (SZX + SZY) // 2 + OY + 30

def iso(x, y, z=0):
    return (OX + (x - y), OY + (x + y) / 2 - z)

def mezcla(c, f):
    return tuple(max(0, min(255, int(v * f))) for v in c[:3])

def aclarar(c, f):
    return tuple(min(255, int(v + (255 - v) * f)) for v in c[:3])

TIPOS = {(0, 0): 'titulares', (1, 0): 'residencial', (2, 0): 'mercado',
         (0, 1): 'comercio', (1, 1): 'parque', (2, 1): 'colegio',
         (0, 2): 'sede', (1, 2): 'obra', (2, 2): 'gasolinera'}

def manzana(tipo):
    for (bx, by), t in TIPOS.items():
        if t == tipo:
            return ORX[bx], ORY[by], TAMX[bx], TAMY[by]

P0X, P0Y, _, _ = manzana('parque')
RIO = 5        # baldosas de agua
MALECON = 8    # hasta aqui llega el malecon

U, V = np.meshgrid(np.arange(SZX), np.arange(SZY))   # arreglos [y][x]
KX = KINDX[U // T]
KY = KINDY[V // T]
BX = BLKX[U // T]
BY = BLKY[V // T]
agua = U < RIO * T
malecon = (U >= RIO * T) & (U < MALECON * T)
borde_rio = agua | malecon
road = ((KX == 'R') | (KY == 'R')) & ~borde_rio
side = ~road & ((KX == 'S') | (KY == 'S')) & ~borde_rio
enK = (BX >= 0) & (BY >= 0)
lot = ~road & ~side & ~borde_rio & ~enK

def mascara_manzana(tipo):
    x0, y0, w, d = manzana(tipo)
    return (U >= x0 * T) & (U < (x0 + w) * T) & (V >= y0 * T) & (V < (y0 + d) * T)

M = {t: mascara_manzana(t) for t in TIPOS.values()}

# ---- parque (mismo trazado del boceto anterior)
park = M['parque']
pu = U / T - P0X
pv = V / T - P0Y
cross = (np.abs(pu - 12) < 1.0) | (np.abs(pv - 12) < 1.0)
anti = np.abs(pu + pv - 24) < 1.5
dist = np.hypot(pu - 12, pv - 12)
plaza = dist < 5.6
camino = park & (cross | anti | plaza)
cesped = park & ~camino

# ------------------------------------------------------------------ texturas del piso
tex = np.zeros((SZY, SZX, 3), np.uint8)
fino = rng.random((SZY, SZX))

def bloques(escala, n):
    a = rng.integers(0, n, size=(SZY // escala + 1, SZX // escala + 1))
    return np.kron(a, np.ones((escala, escala), int))[:SZY, :SZX]

def pintar(mask, arr):
    tex[mask] = arr[mask]

VERDES = np.array([(112, 170, 70), (100, 156, 62), (124, 182, 76)], np.uint8)
GRASS = VERDES[bloques(3, 3)]
GRASS[fino < 0.05] = (88, 140, 56)
GRASS[fino > 0.95] = (140, 196, 86)

PATH = np.array((233, 214, 153), np.uint8)
lineaP = (V % 5 == 0) | (((U + 5 * ((V // 5) % 2)) % 10) == 0)
ADOQ = np.where(lineaP[..., None], np.array((206, 186, 132), np.uint8), PATH).copy()
ADOQ[fino < 0.04] = (222, 202, 142)

ls = (U % 8 == 0) | (V % 8 == 0)
ANDEN = np.where(ls[..., None], np.array((178, 170, 152), np.uint8), np.array((210, 202, 184), np.uint8)).copy()
ANDEN[fino < 0.02] = (196, 188, 170)

ASF = np.array([(100, 98, 96), (92, 90, 88), (108, 106, 102)], np.uint8)[bloques(2, 3)]
ASF[fino < 0.03] = (84, 82, 80)

TIERRA = np.array([(168, 124, 82), (156, 112, 74), (180, 136, 92)], np.uint8)[bloques(3, 3)]
TIERRA[fino < 0.04] = (130, 96, 64)
TIERRA[fino > 0.97] = (204, 176, 132)

lr = ((U // 6 + V // 6) % 2 == 0)
LADR = np.where(lr[..., None], np.array((204, 128, 92), np.uint8), np.array((190, 114, 80), np.uint8)).copy()
LADR[(U % 6 == 0) | (V % 6 == 0)] = (166, 98, 70)

CONC = np.where(((U % 16 == 0) | (V % 16 == 0))[..., None], np.array((186, 184, 176), np.uint8),
                np.array((214, 212, 204), np.uint8)).copy()

ola = ((U * 2 + V) % 29 < 2) & (fino < 0.55)
AGUA = np.array([(66, 138, 184), (60, 128, 176), (72, 146, 190)], np.uint8)[bloques(4, 3)]
AGUA[ola] = (150, 200, 228)

# base
pintar(lot, ANDEN)
pintar(side, ANDEN)
pintar(road, ASF)
pintar(agua, AGUA)
pintar(malecon, LADR)
tex[malecon & (U >= MALECON * T - 2)] = (150, 140, 124)

# parque
pintar(cesped, GRASS)
pintar(camino & ~plaza, ADOQ)
ang = np.arctan2(pv - 12, pu - 12)
anillo = np.floor(dist * T / 7).astype(int)
pz = np.where((anillo % 2 == 0)[..., None], np.array((206, 124, 84), np.uint8), np.array((238, 216, 172), np.uint8))
radial = (np.abs(((ang + math.pi) % (2 * math.pi / 28)) - math.pi / 28) < 0.012 * (6 / np.maximum(dist, 0.5)))
pz = np.where(radial[..., None], np.array((176, 120, 90), np.uint8), pz).copy()
pz[(dist >= 5.25) & (dist < 5.6)] = (150, 96, 70)
pintar(park & plaza, pz)
cam_p = np.pad(camino, 1)
interior = cam_p[:-2, 1:-1] & cam_p[2:, 1:-1] & cam_p[1:-1, :-2] & cam_p[1:-1, 2:]
tex[camino & ~interior & ~plaza] = (168, 146, 104)

def rect(x0, y0, x1, y1, col):   # en baldosas
    tex[int(y0 * T):int(y1 * T), int(x0 * T):int(x1 * T)] = col

def rect_arr(x0, y0, x1, y1, arr):
    sl = (slice(int(y0 * T), int(y1 * T)), slice(int(x0 * T), int(x1 * T)))
    tex[sl] = arr[sl]

def linea_x(y, x0, x1, col, grosor=1):   # linea a lo largo de x, en unidades
    tex[int(y):int(y) + grosor, int(x0):int(x1)] = col

def linea_y(x, y0, y1, col, grosor=1):
    tex[int(y0):int(y1), int(x):int(x) + grosor] = col

BLANCO = (238, 234, 220)
AMARILLO = (236, 190, 60)

# titulares: plazoleta de concreto
x0, y0, w, d = manzana('titulares')
rect_arr(x0, y0, x0 + w, y0 + d, CONC)
# residencial: patios de pasto y senderitos
x0, y0, w, d = manzana('residencial')
rect_arr(x0, y0, x0 + w, y0 + d, GRASS)
rect_arr(x0, y0 + 9, x0 + w, y0 + 11, ADOQ)
# mercado: piso de ladrillo
x0, y0, w, d = manzana('mercado')
rect_arr(x0, y0, x0 + w, y0 + d, LADR)
# comercio
x0, y0, w, d = manzana('comercio')
rect_arr(x0, y0, x0 + w, y0 + d, CONC)
rect_arr(x0 + 8, y0, x0 + 12, y0 + d, GRASS)
# colegio: pasto + cancha
x0, y0, w, d = manzana('colegio')
CX0, CY0, CX1, CY1 = x0 + 9, y0 + 4, x0 + 19, y0 + 20
rect_arr(x0, y0, x0 + w, y0 + d, GRASS)
rect(CX0, CY0, CX1, CY1, (70, 132, 170))
rect(CX0 + 0.5, CY0 + 0.5, CX1 - 0.5, CY1 - 0.5, (64, 150, 112))
cx0, cy0, cx1, cy1 = [int(v * T) for v in (CX0 + 0.5, CY0 + 0.5, CX1 - 0.5, CY1 - 0.5)]
for (a, b) in [(cy0, None), (cy1 - 1, None)]:
    linea_x(a, cx0, cx1, BLANCO)
linea_y(cx0, cy0, cy1, BLANCO); linea_y(cx1 - 1, cy0, cy1, BLANCO)
linea_x((cy0 + cy1) // 2, cx0, cx1, BLANCO)
mc = np.hypot(U - (cx0 + cx1) / 2, V - (cy0 + cy1) / 2)
tex[(np.abs(mc - 18) < 0.8) & M['colegio']] = BLANCO
for (a, s) in [(cy0, 1), (cy1, -1)]:
    ar = np.hypot(U - (cx0 + cx1) / 2, V - a)
    tex[(np.abs(ar - 30) < 0.8) & ((V - a) * s > 0) & M['colegio']] = BLANCO
rect_arr(x0 + 1, y0 + 20.5, x0 + 19, y0 + 22.5, ADOQ)
# sede: parqueadero y jardin
x0, y0, w, d = manzana('sede')
SEDE = (x0, y0)
rect_arr(x0, y0, x0 + w, y0 + d, CONC)
rect_arr(x0 + 11, y0 + 1, x0 + 20, y0 + 19, ASF)
for k in range(7):
    linea_x((y0 + 1.5 + k * 2.6) * T, (x0 + 13) * T, (x0 + 19.5) * T, BLANCO)
rect_arr(x0 + 1, y0 + 13, x0 + 10, y0 + 19, GRASS)
rect_arr(x0 + 4.5, y0 + 13, x0 + 6.5, y0 + 20, ADOQ)
# obra: tierra
x0, y0, w, d = manzana('obra')
rect_arr(x0, y0, x0 + w, y0 + d, TIERRA)
# gasolinera
x0, y0, w, d = manzana('gasolinera')
rect_arr(x0, y0, x0 + w, y0 + d, CONC)
rect_arr(x0 + 1, y0 + 1, x0 + 19, y0 + 13, ASF)
for k in range(2):
    rect(x0 + 6, y0 + 4 + k * 5, x0 + 15, y0 + 4.4 + k * 5, AMARILLO)
for k in range(6):
    linea_y((x0 + 2 + k * 2.8) * T, (y0 + 14.5) * T, (y0 + 19) * T, BLANCO)
rect_arr(x0 + 1, y0 + 14, x0 + 19, y0 + 19.5, ASF)
for k in range(7):
    linea_y((x0 + 1.5 + k * 2.8) * T, (y0 + 15) * T, (y0 + 19.3) * T, BLANCO)

# ---- marcas en las vias
interseccion = (KX == 'R') & (KY == 'R')

def bandas(kind):
    res, a = [], None
    for i, k in enumerate(list(kind) + ['#']):
        if k == 'R' and a is None:
            a = i
        if k != 'R' and a is not None:
            res.append((a * T, i * T)); a = None
    return res

for (a, b) in bandas(KINDX):
    enV = (U >= a) & (U < b) & ~interseccion & road
    zona = enV & ((KY == 'S') | ((V >= (P0Y + 11) * T) & (V < (P0Y + 13) * T) & (np.abs(U - P0X * T) < 12 * T + (P0X * T - a) * 0 + 40 * T)))
    zona = enV & ((KY == 'S') | ((V >= (P0Y + 11) * T) & (V < (P0Y + 13) * T)))
    tex[zona & (((U - a) % 6) < 3) & (U > a + 1) & (U < b - 2)] = BLANCO
    linea = enV & ~zona
    tex[linea & (U >= (a + b) // 2 - 1) & (U < (a + b) // 2 + 1) & ((V % 24) < 14)] = AMARILLO
    tex[linea & ((U == a + 2) | (U == b - 3))] = BLANCO
for (a, b) in bandas(KINDY):
    enH = (V >= a) & (V < b) & ~interseccion & road
    zona = enH & ((KX == 'S') | ((U >= (P0X + 11) * T) & (U < (P0X + 13) * T)))
    tex[zona & (((V - a) % 6) < 3) & (V > a + 1) & (V < b - 2)] = BLANCO
    linea = enH & ~zona
    tex[linea & (V >= (a + b) // 2 - 1) & (V < (a + b) // 2 + 1) & ((U % 24) < 14)] = AMARILLO
    tex[linea & ((V == a + 2) | (V == b - 3))] = BLANCO
for _ in range(30):
    cx = rng.integers(0, SZX); cy = rng.integers(0, SZY)
    if road[cy, cx] and not interseccion[cy, cx]:
        m = (np.abs(U - cx) < 5) & (np.abs(V - cy) < 5)
        tex[m & (np.hypot(U - cx, V - cy) < 4) & road] = (70, 68, 66)

codigo = np.zeros((SZY, SZX), np.uint8)   # 0 via, 1 elevado, 3 agua
codigo[~road] = 1
codigo[agua] = 3

# ------------------------------------------------------------------ proyeccion isometrica del piso
cy, cx = np.mgrid[0:H, 0:W]
X = cx - OX
Y = cy - OY
uu = (2 * Y + X) // 2
vv = (2 * Y - X) // 2
ok = (uu >= 0) & (uu < SZX) & (vv >= 0) & (vv < SZY)
img = np.zeros((H, W, 4), np.uint8)
img[..., 3] = 255
uc = np.clip(uu, 0, SZX - 1); vc = np.clip(vv, 0, SZY - 1)
img[ok, :3] = tex[vc[ok], uc[ok]]
cod = np.full((H, W), 9, np.uint8)
cod[ok] = codigo[vc[ok], uc[ok]]
arriba = np.roll(cod, 1, axis=0)
cara = (cod == 0) & (arriba == 1)
cara2 = np.roll(cara, 1, axis=0) & (cod == 0)
img[cara, :3] = (176, 168, 150)
img[cara2 & ~cara, :3] = (150, 142, 126)
debajo = np.roll(cara2, 1, axis=0) & (cod == 0)
img[debajo & ~cara & ~cara2, :3] = (60, 50, 44)
abajo = np.roll(cod, -1, axis=0)
img[(cod == 1) & (abajo == 0) & ~cara, :3] = (226, 220, 204)
# borde del malecon sobre el agua
img[(cod == 3) & (np.roll(cod, -1, axis=1) == 1), :3] = (60, 50, 44)
del cy, cx, X, Y, uu, vv, uc, vc
img[~ok, :3] = (150, 196, 226)
fuera = ~ok
piso = Image.fromarray(img, 'RGBA')
sombras = Image.new('L', (W, H), 0)
ds = ImageDraw.Draw(sombras)

# ---- choques: cuadricula de 4x4 unidades (un cuarto de baldosa)
CEL = 4
choque = np.zeros((SZY // CEL, SZX // CEL), bool)
choque[:, :RIO * T // CEL] = True      # el rio no se camina
ultima_huella = None

def bloquear_caja(x, y, w, d, huella=True):
    global ultima_huella
    i0 = max(0, int(math.floor(x / CEL))); i1 = min(SZX // CEL, int(math.ceil((x + w) / CEL)))
    j0 = max(0, int(math.floor(y / CEL))); j1 = min(SZY // CEL, int(math.ceil((y + d) / CEL)))
    choque[j0:j1, i0:i1] = True
    if huella:
        ultima_huella = (x, y, w, d)

def bloquear_circulo(x, y, r):
    global ultima_huella
    i0 = max(0, int((x - r) / CEL)); i1 = min(SZX // CEL, int((x + r) / CEL) + 1)
    j0 = max(0, int((y - r) / CEL)); j1 = min(SZY // CEL, int((y + r) / CEL) + 1)
    for j in range(j0, j1):
        for i in range(i0, i1):
            if math.hypot((i + 0.5) * CEL - x, (j + 0.5) * CEL - y) < r + CEL * 0.35:
                choque[j, i] = True
    ultima_huella = (x - r, y - r, 2 * r, 2 * r)

def bloquear_linea(a, b, c, d):
    if b == d:
        bloquear_caja(min(a, c), b - 1, abs(c - a), 2)
    else:
        bloquear_caja(a - 1, min(b, d), 2, abs(d - b))

def sombra_caja(x, y, w, d, h):
    k = 0.55 * h
    pts = [(x, y), (x + w, y), (x + w, y + d), (x, y + d),
           (x + k, y), (x + w + k, y), (x + w + k, y + d), (x + k, y + d)]
    pp_ = sorted(set(iso(px, py) for px, py in pts))
    def cruz(o, a, b): return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    lo = []
    for p in pp_:
        while len(lo) >= 2 and cruz(lo[-2], lo[-1], p) <= 0: lo.pop()
        lo.append(p)
    up = []
    for p in reversed(pp_):
        while len(up) >= 2 and cruz(up[-2], up[-1], p) <= 0: up.pop()
        up.append(p)
    ds.polygon(lo[:-1] + up[:-1], fill=255)

def sombra_elipse(x, y, r, dx=0):
    X0, Y0 = iso(x + dx, y)
    rx = r * 1.414; ry = rx / 2
    ds.ellipse([X0 - rx, Y0 - ry, X0 + rx, Y0 + ry], fill=255)


# ------------------------------------------------------------------ objetos
class Capa:
    def __init__(self, bbox):
        x0, y0, x1, y1 = bbox
        self.x0 = int(math.floor(x0)) - 3
        self.y0 = int(math.floor(y0)) - 3
        self.img = Image.new('RGBA', (int(x1 - self.x0) + 5, int(y1 - self.y0) + 5), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)

    def P(self, x, y, z=0):
        X, Y = iso(x, y, z)
        return (X - self.x0, Y - self.y0)

    def poly(self, pts, fill):
        q = [self.P(*p) for p in pts]
        self.d.polygon(q, fill=fill, outline=fill)

    def linea(self, a, b, fill, w=1):
        self.d.line([self.P(*a), self.P(*b)], fill=fill, width=w)

    def caja(self, x, y, z, w, d, h, col, top=None, lados=True):
        top = top or aclarar(col, 0.18)
        izq = col
        der = mezcla(col, 0.76)
        if lados:
            self.poly([(x, y + d, z), (x + w, y + d, z), (x + w, y + d, z + h), (x, y + d, z + h)], izq)
            self.poly([(x + w, y, z), (x + w, y + d, z), (x + w, y + d, z + h), (x + w, y, z + h)], der)
        self.poly([(x, y, z + h), (x + w, y, z + h), (x + w, y + d, z + h), (x, y + d, z + h)], top)
        if lados and h >= 3:
            self.linea((x + w, y + d, z), (x + w, y + d, z + h), mezcla(col, 0.62))
            self.linea((x, y + d, z + h), (x + w, y + d, z + h), aclarar(col, 0.32))
            self.linea((x + w, y, z + h), (x + w, y + d, z + h), aclarar(col, 0.1))

    def cara_x(self, X1, y0, y1, z0, z1, col):   # cuadro sobre la cara que mira a +x
        self.poly([(X1, y0, z0), (X1, y1, z0), (X1, y1, z1), (X1, y0, z1)], col)

    def cara_y(self, Y1, x0, x1, z0, z1, col):   # cuadro sobre la cara que mira a +y
        self.poly([(x0, Y1, z0), (x1, Y1, z0), (x1, Y1, z1), (x0, Y1, z1)], col)

    def cilindro(self, x, y, z, r, h, col, top=None):
        top = top or aclarar(col, 0.2)
        X0, Y0 = self.P(x, y, z)
        rx = r * 1.414; ry = rx / 2
        n = int(math.ceil(rx))
        for dx in range(-n, n + 1):
            if abs(dx) > rx: continue
            e = ry * math.sqrt(max(0, 1 - (dx / rx) ** 2))
            f = 1.08 - 0.32 * (dx + rx) / (2 * rx)
            c = mezcla(col, f)
            self.d.line([(X0 + dx, Y0 - h + e), (X0 + dx, Y0 + e)], fill=c)
        self.d.ellipse([X0 - rx, Y0 - h - ry, X0 + rx, Y0 - h + ry], fill=top)

    def elipse(self, x, y, z, r, col):
        X0, Y0 = self.P(x, y, z)
        rx = r * 1.414; ry = rx / 2
        self.d.ellipse([X0 - rx, Y0 - ry, X0 + rx, Y0 + ry], fill=col)

    def contorno(self, color=OUT):
        a = np.array(self.img)
        m = a[..., 3] > 0
        p = np.pad(m, 1)
        dil = p[:-2, 1:-1] | p[2:, 1:-1] | p[1:-1, :-2] | p[1:-1, 2:]
        borde = dil & ~m
        a[borde] = color + (255,)
        self.img = Image.fromarray(a)
        self.d = ImageDraw.Draw(self.img)

objetos = []   # (profundidad, funcion que devuelve una Capa)

def agregar(prof, bbox, dibujar, contorno=True, exportar=True, punto=-1, semaforo=-1):
    global ultima_huella
    objetos.append((prof, bbox, dibujar, contorno, exportar, ultima_huella, punto, semaforo))
    ultima_huella = None

def bbox_caja(x, y, z, w, d, h, extra=0):
    pts = [iso(x + a, y + b, z + c) for a in (0, w) for b in (0, d) for c in (0, h + extra)]
    xs = [p[0] for p in pts]; ys = [p[1] for p in pts]
    return (min(xs) - 2, min(ys) - 2, max(xs) + 2, max(ys) + 2)

def bbox_punto(x, y, ancho, alto, abajo=6):
    X, Y = iso(x, y)
    return (X - ancho, Y - alto, X + ancho, Y + abajo)

# ---- seto
def seto(i, j, n=1, eje='x'):
    x, y = i * T, j * T
    w = n * T - 2 if eje == 'x' else 14
    d = 14 if eje == 'x' else n * T - 2
    sombra_caja(x + 1, y + 1, w, d, 7)
    bloquear_caja(x + 1, y + 1, w, d)
    def dib(L):
        L.caja(x + 1, y + 1, 0, w, d, 7, (78, 136, 58), top=(104, 164, 70))
        for k in range(1, n):
            if eje == 'x':
                L.linea((x + k * T, y + 15, 0.5), (x + k * T, y + 15, 6.5), (70, 124, 52))
            else:
                L.linea((x + 15, y + k * T, 0.5), (x + 15, y + k * T, 6.5), (66, 112, 48))
        for _ in range(16 * n):
            a, b = random.uniform(2, w), random.uniform(2, d)
            L.d.point(L.P(x + a, y + b, 7), fill=random.choice([(132, 190, 86), (70, 120, 50), (140, 198, 92)]))
        if random.random() < 0.3:
            for _ in range(4):
                a, b = random.uniform(3, 13), random.uniform(3, 13)
                L.d.point(L.P(x + a, y + b, 7), fill=random.choice([(240, 90, 110), (250, 220, 90)]))
    agregar(x + y + (w + d) / 2 + 2, bbox_caja(x, y, 0, w + 2, d + 2, 8), dib)

# ---- arboles
def arbol(x, y, tipo='redondo', escala=1.0):
    sombra_elipse(x, y, 11 * escala, dx=14 * escala)
    bloquear_circulo(x, y, 3.5)
    X, Y = iso(x, y)
    alto = int(54 * escala)
    def dib(L):
        bx, by = L.P(x, y)
        if tipo == 'palma':
            # tronco curvo con anillos
            pts = []
            for k in range(0, alto, 2):
                curva = 6 * escala * (k / alto) ** 2
                pts.append((bx + curva, by - k))
            for n, (px, py) in enumerate(pts):
                c = (150, 112, 74) if (n // 2) % 2 == 0 else (124, 90, 60)
                L.d.rectangle([px - 2, py - 2, px + 1, py], fill=c)
            tx, ty = pts[-1]
            for a in range(0, 360, 40):
                r = math.radians(a + 10)
                largo = 20 * escala
                xs = [tx + math.cos(r) * largo * s for s in np.linspace(0, 1, 10)]
                ys = [ty + math.sin(r) * largo * s * 0.55 + 10 * escala * s * s for s in np.linspace(0, 1, 10)]
                col = (84, 150, 62) if a % 80 == 0 else (110, 176, 72)
                for k in range(9):
                    L.d.line([(xs[k], ys[k]), (xs[k + 1], ys[k + 1])], fill=col, width=3 if k < 6 else 2)
            for dx, dy in [(-2, 2), (2, 3), (0, 4)]:
                L.d.ellipse([tx + dx - 2, ty + dy - 1, tx + dx + 1, ty + dy + 2], fill=(122, 84, 46))
            return
        # tronco
        L.d.rectangle([bx - 2, by - alto * 0.45, bx + 2, by], fill=(126, 92, 66))
        L.d.line([(bx + 2, by - alto * 0.45), (bx + 2, by)], fill=(98, 70, 50))
        L.d.line([(bx - 1, by - alto * 0.3), (bx - 5, by - alto * 0.5)], fill=(126, 92, 66), width=2)
        # copa: union de circulos
        if tipo == 'redondo':
            base, luz, sombra = (92, 154, 64), (134, 194, 84), (62, 112, 50)
        elif tipo == 'guayacan':
            base, luz, sombra = (238, 196, 52), (252, 228, 110), (196, 146, 40)
        else:  # flamboyan
            base, luz, sombra = (226, 96, 52), (250, 150, 86), (172, 62, 40)
        w, h = int(40 * escala), int(40 * escala)
        cop = np.zeros((h + 8, w + 8), bool)
        yy, xx = np.mgrid[0:h + 8, 0:w + 8]
        for _ in range(7):
            cxx = random.uniform(w * 0.3, w * 0.7) + 4
            cyy = random.uniform(h * 0.35, h * 0.65) + 4
            rr = random.uniform(w * 0.22, w * 0.32)
            cop |= np.hypot(xx - cxx, yy - cyy) < rr
        cop |= np.hypot(xx - (w / 2 + 4), yy - (h / 2 + 4)) < w * 0.36
        s1 = np.zeros_like(cop); s1[:-3, :-3] = cop[3:, 3:]
        s2 = np.zeros_like(cop); s2[3:, 3:] = cop[:-3, :-3]
        arr = np.zeros((h + 8, w + 8, 4), np.uint8)
        arr[cop] = base + (255,)
        arr[cop & ~s2] = luz + (255,)
        arr[cop & ~s1] = sombra + (255,)
        manchas = rng.random(cop.shape)
        arr[cop & (manchas < 0.06)] = luz + (255,)
        arr[cop & (manchas > 0.94)] = sombra + (255,)
        if tipo != 'redondo':
            verde = cop & (manchas > 0.86) & (manchas < 0.92)
            arr[verde] = (96, 150, 62, 255)
        copa = Image.fromarray(arr)
        L.img.alpha_composite(copa, (int(bx - (w + 8) / 2), int(by - alto - h * 0.25)))
        L.d = ImageDraw.Draw(L.img)
    agregar(x + y, (X - 30 * escala, Y - alto - 36 * escala, X + 30 * escala, Y + 6), dib)

# ---- banca
def banca(x, y, eje, mira):
    # eje: 'x' o 'y' (largo de la banca); mira: +1 o -1 (hacia donde da el asiento)
    madera = (176, 104, 64)
    hierro = (64, 58, 54)
    if eje == 'x':
        sombra_caja(x - 8, y - 3, 16, 6, 6)
        bloquear_caja(x - 8, y - 3, 16, 6)
    else:
        sombra_caja(x - 3, y - 8, 6, 16, 6)
        bloquear_caja(x - 3, y - 8, 6, 16)
    def dib(L):
        if eje == 'x':
            yb = y - 3 if mira > 0 else y + 2   # respaldo atras del asiento
            partes = []
            for dx in (-7, 6):
                partes.append(('c', (x + dx, y - 3, 0, 1, 6, 4, hierro)))
            partes.append(('c', (x - 8, y - 3, 4, 16, 6, 1.5, madera)))
            partes.append(('c', (x - 8, yb, 5.5, 16, 1.2, 6, madera)))
            partes.sort(key=lambda p: p[1][1] + p[1][4])
        else:
            xb = x - 3 if mira > 0 else x + 2
            partes = []
            for dy in (-7, 6):
                partes.append(('c', (x - 3, y + dy, 0, 6, 1, 4, hierro)))
            partes.append(('c', (x - 3, y - 8, 4, 6, 16, 1.5, madera)))
            partes.append(('c', (xb, y - 8, 5.5, 1.2, 16, 6, madera)))
            partes.sort(key=lambda p: p[1][0] + p[1][3])
        for _, (a, b, c, w, d, h, col) in partes:
            L.caja(a, b, c, w, d, h, col)
    agregar(x + y + 2, bbox_caja(x - 9, y - 9, 0, 18, 18, 12), dib)

# ---- caneca
def caneca(x, y):
    sombra_elipse(x, y, 4, dx=3)
    bloquear_circulo(x, y, 4)
    def dib(L):
        L.cilindro(x, y, 0, 3.6, 11, (66, 140, 86), top=(40, 70, 50))
        L.cilindro(x, y, 7, 3.7, 2, (236, 190, 60), top=(40, 70, 50))
        L.elipse(x, y, 11, 2.4, (30, 34, 30))
    agregar(x + y, bbox_punto(x, y, 8, 18), dib)

# ---- poste de luz (apagado de dia)
def poste(x, y):
    sombra_caja(x - 1, y - 1, 2, 2, 30)
    bloquear_circulo(x, y, 2.5)
    def dib(L):
        L.cilindro(x, y, 0, 2.2, 4, (58, 66, 60))
        L.cilindro(x, y, 4, 1.1, 40, (58, 66, 60))
        L.caja(x - 2.5, y - 2.5, 44, 5, 5, 7, (236, 228, 196), top=(250, 244, 220))
        L.caja(x - 3.2, y - 3.2, 51, 6.4, 6.4, 1.6, (58, 66, 60))
        L.cilindro(x, y, 52.6, 1.5, 2, (58, 66, 60))
    agregar(x + y, bbox_punto(x, y, 10, 64), dib)

# ---- cartelera para los volantes (punto de flyers)
def cartelera(x, y, eje, volantes):
    sombra_caja(x - 8, y - 2, 16, 4, 16) if eje == 'x' else sombra_caja(x - 2, y - 8, 4, 16, 16)
    bloquear_caja(x - 9, y - 2, 18, 4) if eje == 'x' else bloquear_caja(x - 2, y - 9, 4, 18)
    # marca en el piso: anillo punteado amarillo
    def dib_marca():
        pass
    def dib(L):
        if eje == 'x':
            for dx in (-7, 6):
                L.caja(x + dx, y - 1, 0, 1.4, 1.4, 22, (110, 76, 52))
            L.caja(x - 9, y - 1.5, 9, 18, 2, 14, (196, 150, 98))
            L.cara_y(y + 0.5, x - 8, x + 8, 10, 22, (206, 160, 104))
            for k, col in enumerate(volantes):
                if col is None: continue
                a = x - 7 + k * 5.2
                L.cara_y(y + 0.5, a, a + 4, 12, 20, col)
                L.cara_y(y + 0.5, a + 0.8, a + 3.2, 17, 18.5, (250, 246, 236))
            L.caja(x - 10, y - 2.5, 23, 20, 4, 1.6, (150, 64, 48))
        else:
            for dy in (-7, 6):
                L.caja(x - 1, y + dy, 0, 1.4, 1.4, 22, (110, 76, 52))
            L.caja(x - 1.5, y - 9, 9, 2, 18, 14, (196, 150, 98))
            L.cara_x(x + 0.5, y - 8, y + 8, 10, 22, (186, 140, 92))
            for k, col in enumerate(volantes):
                if col is None: continue
                a = y - 7 + k * 5.2
                L.cara_x(x + 0.5, a, a + 4, 12, 20, mezcla(col, 0.85))
                L.cara_x(x + 0.5, a + 0.8, a + 3.2, 17, 18.5, (236, 232, 222))
            L.caja(x - 2.5, y - 10, 23, 4, 20, 1.6, (150, 64, 48))
    # punto para pegar volantes: el juego pinta el volante sobre la cara visible
    if eje == 'x':
        quad = [iso(x - 7, y + 0.6, 11), iso(x + 7, y + 0.6, 11), iso(x + 7, y + 0.6, 21), iso(x - 7, y + 0.6, 21)]
        frente = (x, y + 14)
    else:
        quad = [iso(x + 0.6, y + 7, 11), iso(x + 0.6, y - 7, 11), iso(x + 0.6, y - 7, 21), iso(x + 0.6, y + 7, 21)]
        frente = (x + 14, y)
    puntos.append((x, y, eje, quad, frente))
    agregar(x + y + 1, bbox_punto(x, y, 26, 44, 14), dib, punto=len(puntos) - 1)

marcas = []
puntos = []

# ---- fuente
def fuente(x, y):
    bloquear_circulo(x, y, 38)
    def dib(L):
        L.cilindro(x, y, 0, 38, 7, (226, 206, 158), top=(240, 226, 186))
        L.elipse(x, y, 7, 34, (78, 152, 196))
        L.elipse(x, y, 7, 30, (96, 170, 210))
        for _ in range(60):
            a = random.uniform(0, 2 * math.pi); r = random.uniform(4, 30)
            X0, Y0 = L.P(x + r * math.cos(a), y + r * math.sin(a), 7)
            L.d.line([(X0, Y0), (X0 + 2, Y0)], fill=(170, 220, 240))
        L.cilindro(x, y, 7, 5, 16, (226, 206, 158))
        L.cilindro(x, y, 23, 14, 3, (226, 206, 158), top=(240, 226, 186))
        L.elipse(x, y, 26, 11.5, (96, 170, 210))
        L.cilindro(x, y, 26, 2.5, 8, (226, 206, 158))
        X0, Y0 = L.P(x, y, 34)
        for k in range(14):
            L.d.point((X0 + random.uniform(-1, 1), Y0 - k), fill=(220, 244, 252))
        for a in range(0, 360, 30):
            r = math.radians(a)
            for s in range(1, 9):
                px = X0 + math.cos(r) * s * 2.6
                py = Y0 - 12 + s * s * 0.45 + math.sin(r) * s * 0.9
                L.d.point((px, py), fill=(200, 236, 250) if s % 2 else (150, 210, 238))
    X, Y = iso(x, y)
    agregar(x + y, (X - 60, Y - 60, X + 60, Y + 32), dib)

# ---- tarima con toldo y banderines
def tarima(x, y, w, d):
    sombra_caja(x, y, w, d, 40)
    bloquear_caja(x, y, w, d + 9)
    def dib(L):
        madera = (170, 108, 70)
        L.caja(x, y, 0, w, d, 9, madera, top=(196, 136, 88))
        for k in range(1, int(w / 6)):
            L.linea((x + k * 6, y, 9), (x + k * 6, y + d, 9), (170, 112, 72))
        # escalones al frente (+y)
        for k in range(3):
            L.caja(x + w * 0.38, y + d + (2 - k) * 3, 0, w * 0.24, 3, 3 * (k + 1), (160, 100, 64))
        # pared de fondo
        L.caja(x, y - 2, 9, w, 2, 30, (236, 214, 160))
        L.cara_y(y, x + 6, x + w - 6, 18, 32, (66, 120, 170))
        for k in range(6):
            L.cara_y(y, x + 10 + k * (w - 20) / 6, x + 13 + k * (w - 20) / 6, 22, 28, (250, 214, 80))
        # postes
        for (a, b) in [(x, y), (x + w - 2, y), (x, y + d - 2), (x + w - 2, y + d - 2)]:
            if (a, b) == (x + w - 2, y + d - 2) or (a, b) == (x, y + d - 2):
                continue
            L.caja(a, b, 9, 2, 2, 34, (240, 236, 224))
        for (a, b) in [(x, y + d - 2), (x + w - 2, y + d - 2)]:
            L.caja(a, b, 9, 2, 2, 34, (240, 236, 224))
        # toldo a rayas
        z = 43
        franjas = 8
        for k in range(franjas):
            col = (214, 62, 52) if k % 2 == 0 else (246, 240, 226)
            a = x - 3 + k * (w + 6) / franjas
            L.poly([(a, y - 3, z + 6), (a + (w + 6) / franjas, y - 3, z + 6),
                    (a + (w + 6) / franjas, y + d + 3, z), (a, y + d + 3, z)], col)
            L.poly([(a, y + d + 3, z), (a + (w + 6) / franjas, y + d + 3, z),
                    (a + (w + 6) / franjas, y + d + 3, z - 4), (a, y + d + 3, z - 4)], mezcla(col, 0.82))
        # banderines
        cols = [(236, 190, 60), (66, 120, 200), (214, 62, 52), (96, 170, 90), (240, 140, 170)]
        n = 12
        for k in range(n):
            a = x - 2 + (k + 0.5) * (w + 4) / n
            X0, Y0 = L.P(a, y + d + 3, z - 4)
            L.d.polygon([(X0 - 3, Y0), (X0 + 3, Y0 + 1.5), (X0, Y0 + 7)], fill=cols[k % 5])
    agregar(x + y + d, bbox_caja(x - 4, y - 4, 0, w + 8, d + 14, 52), dib)

# ---- puesto de raspao con sombrilla, y mesas
def sombrilla(L, x, y, z, r, cols):
    X0, Y0 = L.P(x, y, z)
    rx = r * 1.414; ry = rx / 2
    n = 10
    for k in range(n):
        a0 = 2 * math.pi * k / n; a1 = 2 * math.pi * (k + 1) / n
        p0 = (X0 + rx * math.cos(a0), Y0 + ry * math.sin(a0) + 3)
        p1 = (X0 + rx * math.cos(a1), Y0 + ry * math.sin(a1) + 3)
        L.d.polygon([(X0, Y0 - 6), p0, p1], fill=cols[k % 2])
    L.d.ellipse([X0 - 1, Y0 - 8, X0 + 1, Y0 - 6], fill=(240, 236, 224))

def puesto(x, y):
    sombra_caja(x - 9, y - 6, 18, 12, 30)
    bloquear_caja(x - 9, y - 6, 18, 12)
    def dib(L):
        L.caja(x - 9, y - 6, 4, 18, 12, 12, (66, 150, 186), top=(240, 236, 224))
        L.cara_y(y + 6, x - 7, x + 7, 8, 13, (250, 214, 80))
        L.cara_x(x + 9, y - 4, y + 4, 8, 13, (226, 96, 52))
        for dx, dy in [(-7, 4), (7, 4), (7, -4)]:
            L.cilindro(x + dx, y + dy, 0, 2.2, 4, (40, 40, 40))
        for k, col in enumerate([(226, 60, 70), (250, 214, 80), (96, 190, 110)]):
            L.cilindro(x - 4 + k * 3, y - 2, 16, 1.3, 4, col)
        L.caja(x - 0.6, y - 0.6, 16, 1.2, 1.2, 18, (220, 220, 210))
        sombrilla(L, x, y, 36, 16, [(226, 96, 52), (250, 238, 210)])
    agregar(x + y + 6, bbox_punto(x, y, 34, 52, 16), dib)

def mesa(x, y):
    sombra_elipse(x, y, 10, dx=8)
    bloquear_circulo(x, y, 8)
    def dib(L):
        for dx, dy in [(-7, 0), (7, 0), (0, -7)]:
            L.caja(x + dx - 2, y + dy - 2, 0, 4, 4, 5, (150, 96, 60))
        L.cilindro(x, y, 0, 1, 8, (60, 60, 60))
        L.cilindro(x, y, 8, 6, 1.5, (240, 236, 224))
        L.caja(x - 0.5, y - 0.5, 9, 1, 1, 14, (220, 220, 210))
        sombrilla(L, x, y, 25, 13, [(66, 140, 86), (246, 240, 226)])
        L.caja(x + 3, y + 7 - 2, 0, 4, 4, 5, (150, 96, 60))
    agregar(x + y + 4, bbox_punto(x, y, 26, 42, 14), dib)

# ---- jardinera de flores
def jardinera(x, y, w, d):
    bloquear_caja(x, y, w, d)
    def dib(L):
        L.caja(x, y, 0, w, d, 4, (196, 120, 82), top=(110, 76, 52))
        for _ in range(int(w * d / 6)):
            a, b = random.uniform(x + 1.5, x + w - 1.5), random.uniform(y + 1.5, y + d - 1.5)
            X0, Y0 = L.P(a, b, 4)
            L.d.point((X0, Y0 - 1), fill=(90, 150, 62))
            L.d.point((X0, Y0 - 2), fill=random.choice([(240, 80, 100), (250, 214, 80), (246, 240, 236), (240, 140, 190), (250, 140, 60)]))
    agregar(x + y + d, bbox_caja(x, y, 0, w, d, 8), dib)

# ---- columpios y rodadero
def columpios(x, y):
    sombra_caja(x - 16, y - 6, 32, 12, 20)
    bloquear_caja(x - 16, y - 6, 32, 12)
    def dib(L):
        azul = (60, 120, 196)
        for dx in (-15, 13):
            L.caja(x + dx, y - 6, 0, 2, 1.6, 30, azul)
            L.caja(x + dx, y + 4.4, 0, 2, 1.6, 30, azul)
        L.caja(x - 16, y - 1, 30, 32, 2, 2, (214, 62, 52))
        for dx in (-8, 4):
            L.linea((x + dx, y, 30), (x + dx, y, 8), (90, 90, 90))
            L.linea((x + dx + 4, y, 30), (x + dx + 4, y, 8), (90, 90, 90))
            L.caja(x + dx - 0.5, y - 1.5, 7, 5, 3, 1.4, (236, 190, 60))
    agregar(x + y + 6, bbox_caja(x - 18, y - 8, 0, 36, 16, 34), dib)

def rodadero(x, y):
    sombra_caja(x - 4, y - 14, 8, 28, 22)
    bloquear_caja(x - 4, y - 14, 8, 28)
    def dib(L):
        L.caja(x - 4, y - 14, 0, 8, 8, 22, (236, 190, 60))
        for k in range(5):
            L.caja(x - 4, y - 14 - 1.5, k * 4.4, 8, 1.5, 1.2, (214, 62, 52))
        pts = 10
        for k in range(pts):
            z0 = 22 - k * 22 / pts
            yy = y - 6 + k * 20 / pts
            L.caja(x - 3.5, yy, z0 - 2, 7, 20 / pts + 0.3, 2, (214, 62, 52))
    agregar(x + y + 8, bbox_caja(x - 6, y - 16, 0, 12, 34, 28), dib)

# ---- semaforo (carcasa amarilla)
semaforos_lista = []

def semaforo(x, y, hacia, cruce=(-1, -1), eje='v'):
    sombra_caja(x - 1, y - 1, 2, 2, 34)
    bloquear_circulo(x, y, 2)
    hx0, hy0 = x + hacia[0] * 16, y + hacia[1] * 16
    luces = [iso(hx0, hy0 + 2.2, 35 - k * 3.5) for k in range(3)]   # roja, amarilla, verde
    semaforos_lista.append((cruce[0], cruce[1], eje, luces))
    indice = len(semaforos_lista) - 1
    def dib(L):
        L.cilindro(x, y, 0, 1.3, 40, (70, 74, 70))
        ax, ay = hacia
        L.caja(min(x, x + ax * 18), min(y, y + ay * 18), 38, abs(ax) * 18 + 1.4, abs(ay) * 18 + 1.4, 1.4, (70, 74, 70))
        hx, hy = x + ax * 16, y + ay * 16
        L.caja(hx - 2, hy - 2, 26, 4, 4, 12, (236, 190, 60))
        for k, c in enumerate([(110, 40, 36), (110, 90, 40), (40, 80, 50)]):
            L.cara_y(hy + 2, hx - 1.2, hx + 1.2, 34 - k * 3.5, 36 - k * 3.5, c)
    agregar(x + y, bbox_caja(x - 20, y - 20, 0, 40, 40, 44), dib, semaforo=indice)

# ---- carros
# Los carros no se dibujan en la ciudad: el juego los mueve (y se pueden
# manejar). Aqui solo se anotan los que quedan estacionados.
VARIANTES_CARRO = [(214, 62, 52), (60, 112, 200), (96, 166, 120), (236, 236, 228), (150, 60, 120),
                   (52, 96, 196), (236, 140, 50), (240, 196, 48)]
carros_lista = []

def carro(x, y, eje, color, taxi=False):
    if taxi:
        v = 7
    else:
        v = min(range(7), key=lambda k: sum((a - b) ** 2 for a, b in zip(VARIANTES_CARRO[k], color[:3])))
    ang = 0.0 if eje == 'x' else math.pi / 2
    carros_lista.append((x / T, y / T, ang, v))

# ---- edificios
FACHADAS = [(232, 212, 160), (214, 126, 88), (96, 166, 164), (240, 200, 92), (230, 132, 110),
            (166, 196, 120), (236, 170, 90), (150, 170, 210)]
TOLDOS = [((214, 62, 52), (246, 240, 226)), ((66, 140, 86), (246, 240, 226)), ((66, 120, 200), (246, 240, 226)),
          ((236, 190, 60), (214, 62, 52))]

def edificio(x, y, w, d, pisos, ver_x, ver_y, bajo=False):
    FH = 20
    h = pisos * FH
    col = random.choice(FACHADAS)
    toldo = random.choice(TOLDOS)
    tanque = random.random() < 0.6
    sombra_caja(x, y, w, d, h)
    bloquear_caja(x, y, w, d)
    def ventanas_x(L, X1, ya, yb, z0):
        n = max(1, int((yb - ya) / 12))
        paso = (yb - ya) / n
        for k in range(n):
            a = ya + k * paso + paso / 2 - 3.5
            L.cara_x(X1, a - 1, a + 8, z0 + 4, z0 + 15, mezcla(col, 0.7))
            L.cara_x(X1, a, a + 7, z0 + 5, z0 + 14, (96, 160, 200))
            L.cara_x(X1, a, a + 2, z0 + 11, z0 + 14, (170, 214, 236))
            L.cara_x(X1, a - 1.5, a + 8.5, z0 + 3, z0 + 4.4, (246, 240, 226))
    def ventanas_y(L, Y1, xa, xb, z0):
        n = max(1, int((xb - xa) / 12))
        paso = (xb - xa) / n
        for k in range(n):
            a = xa + k * paso + paso / 2 - 3.5
            L.cara_y(Y1, a - 1, a + 8, z0 + 4, z0 + 15, mezcla(col, 0.7))
            L.cara_y(Y1, a, a + 7, z0 + 5, z0 + 14, (110, 176, 214))
            L.cara_y(Y1, a, a + 2, z0 + 11, z0 + 14, (186, 226, 244))
            L.cara_y(Y1, a - 1.5, a + 8.5, z0 + 3, z0 + 4.4, (246, 240, 226))
    def dib(L):
        L.caja(x, y, 0, w, d, h, col, top=(186, 112, 84) if not bajo else (176, 170, 160))
        # cornisa
        L.caja(x - 1, y - 1, h, w + 2, d + 2, 3, aclarar(col, 0.4), top=(160, 150, 140))
        L.caja(x + 2, y + 2, h + 0.5, w - 4, d - 4, 2.6, (150, 144, 136), top=(196, 190, 180))
        if ver_x:
            X1 = x + w
            for p in range(1, pisos):
                ventanas_x(L, X1, y + 3, y + d - 3, p * FH)
            # planta baja: puerta, vitrina y toldo
            L.cara_x(X1, y + d / 2 - 4, y + d / 2 + 4, 0, 13, (110, 70, 46))
            L.cara_x(X1, y + d / 2 - 3, y + d / 2 + 3, 1, 12, (140, 92, 60))
            if d > 30:
                L.cara_x(X1, y + 4, y + d / 2 - 7, 3, 12, (96, 160, 200))
                L.cara_x(X1, y + d / 2 + 7, y + d - 4, 3, 12, (96, 160, 200))
            fr = 8
            for k in range(fr):
                c = toldo[k % 2]
                a = y + 2 + k * (d - 4) / fr
                L.poly([(X1, a, 16), (X1, a + (d - 4) / fr, 16), (X1 + 7, a + (d - 4) / fr, 12), (X1 + 7, a, 12)], c)
                L.poly([(X1 + 7, a, 12), (X1 + 7, a + (d - 4) / fr, 12), (X1 + 7, a + (d - 4) / fr, 10), (X1 + 7, a, 10)], mezcla(c, 0.8))
        if ver_y:
            Y1 = y + d
            for p in range(1, pisos):
                ventanas_y(L, Y1, x + 3, x + w - 3, p * FH)
            L.cara_y(Y1, x + w / 2 - 4, x + w / 2 + 4, 0, 13, (110, 70, 46))
            L.cara_y(Y1, x + w / 2 - 3, x + w / 2 + 3, 1, 12, (140, 92, 60))
            if w > 30:
                L.cara_y(Y1, x + 4, x + w / 2 - 7, 3, 12, (110, 176, 214))
                L.cara_y(Y1, x + w / 2 + 7, x + w - 4, 3, 12, (110, 176, 214))
            fr = 8
            for k in range(fr):
                c = toldo[k % 2]
                a = x + 2 + k * (w - 4) / fr
                L.poly([(a, Y1, 16), (a + (w - 4) / fr, Y1, 16), (a + (w - 4) / fr, Y1 + 7, 12), (a, Y1 + 7, 12)], aclarar(c, 0.08))
                L.poly([(a, Y1 + 7, 12), (a + (w - 4) / fr, Y1 + 7, 12), (a + (w - 4) / fr, Y1 + 7, 10), (a, Y1 + 7, 10)], mezcla(c, 0.85))
        if tanque:
            L.cilindro(x + w * 0.35, y + d * 0.4, h + 3, 5, 9, (40, 44, 48), top=(60, 64, 68))
        if random.random() < 0.6:
            L.caja(x + w * 0.6, y + d * 0.55, h + 3, 6, 5, 4, (200, 200, 196))
    agregar(x + w / 2 + y + d / 2 + (w + d) / 4, bbox_caja(x - 2, y - 2, 0, w + 12, d + 12, h + 14), dib)

def bloque_edificios(i0, i1, j0, j1, ver_x, ver_y, bajo):
    # parte el lote en edificios de 2 a 4 baldosas a lo largo de la calle
    largo_x = i1 - i0; largo_y = j1 - j0
    if largo_x >= largo_y:
        a = i0
        while a < i1:
            n = min(random.choice([2, 3, 3, 4]), i1 - a)
            pisos = 1 if bajo else random.choice([2, 3, 3, 4])
            edificio(a * T, j0 * T, n * T, (j1 - j0) * T, pisos, ver_x and a + n == i1 or ver_x, ver_y, bajo)
            a += n
    else:
        b = j0
        while b < j1:
            n = min(random.choice([2, 3, 3, 4]), j1 - b)
            pisos = 1 if bajo else random.choice([2, 3, 3, 4])
            edificio(i0 * T, b * T, (i1 - i0) * T, n * T, pisos, ver_x, ver_y and b + n == j1 or ver_y, bajo)
            b += n


# ================================================================== objetos nuevos de la ciudad

# ---- letras (la misma fuente 5x7 del juego, sacada de Diseno.pde)
GLIFOS = {}
try:
    txt = open(DISENO, encoding='utf-8').read()
    bloque = txt[txt.index('String[] GLIFOS'):]
    bloque = bloque[bloque.index('{') + 1:bloque.index('};')]
    for linea in bloque.splitlines():
        linea = linea.strip().rstrip(',')
        if len(linea) < 3 or not linea.startswith('"'):
            continue
        s = linea[1:-1].replace('\\"', '"').replace('\\\\', '\\')
        GLIFOS[s[0]] = s[1:].split('/')
except Exception as e:
    print('sin fuente:', e)

TILDES = {'Á': 'A', 'É': 'E', 'Í': 'I', 'Ó': 'O', 'Ú': 'U', 'Ñ': 'N'}

def pixeles_texto(texto):
    # lista de (columna, fila) encendidas; las tildes van en las filas -2
    res, col = [], 0
    for ch in texto:
        base = TILDES.get(ch, ch)
        g = GLIFOS.get(base, GLIFOS.get(' ', ['000'] * 7))
        ancho = len(g[0])
        for f, fila in enumerate(g):
            for c, v in enumerate(fila):
                if v == '1':
                    res.append((col + c, f))
        if ch in TILDES:
            if ch == 'Ñ':
                for c, f in [(0, -2), (1, -3), (2, -2), (3, -3)]:
                    res.append((col + c + (ancho - 4) // 2, f))
            else:
                res.append((col + ancho // 2 + 1, -3)); res.append((col + ancho // 2, -2))
        col += ancho + 1
    return res, col - 1

def letrero_y(L, Y1, x0, ztop, texto, col, fondo=None, s=1.0):
    px, ancho = pixeles_texto(texto)
    if fondo:
        L.cara_y(Y1, x0 - 2, x0 + ancho * s + 2, ztop - 7 * s - 2, ztop + 4 * s, fondo)
    for (c, f) in px:
        a = x0 + c * s; z = ztop - f * s
        L.cara_y(Y1, a, a + s * 0.9, z - s, z, col)

def letrero_x(L, X1, y0, ztop, texto, col, fondo=None, s=1.0):
    px, ancho = pixeles_texto(texto)
    if fondo:
        L.cara_x(X1, y0 - ancho * s - 2, y0 + 2, ztop - 7 * s - 2, ztop + 4 * s, fondo)
    for (c, f) in px:
        a = y0 - c * s; z = ztop - f * s
        L.cara_x(X1, a - s * 0.9, a, z - s, z, col)

def ancho_texto(texto, s=1.0):
    return pixeles_texto(texto)[1] * s

# ---- casa con techo de teja a dos aguas
TEJA = (196, 96, 62)

def casa(x, y, w, d, col, eje='x', puerta='y', h=18):
    sombra_caja(x, y, w, d, h + 10)
    bloquear_caja(x, y, w, d)
    def dib(L):
        L.caja(x, y, 0, w, d, h, col)
        rh = min(w, d) * 0.42
        # puerta y ventanas
        if puerta == 'y':
            L.cara_y(y + d, x + w / 2 - 3, x + w / 2 + 3, 0, 11, (130, 82, 54))
            for a in (x + 3, x + w - 9):
                if w > 26:
                    L.cara_y(y + d, a, a + 6, 5, 12, (246, 240, 226))
                    L.cara_y(y + d, a + 1, a + 5, 6, 11, (96, 160, 200))
        else:
            L.cara_x(x + w, y + d / 2 - 3, y + d / 2 + 3, 0, 11, (130, 82, 54))
            for a in (y + 3, y + d - 9):
                if d > 26:
                    L.cara_x(x + w, a, a + 6, 5, 12, (246, 240, 226))
                    L.cara_x(x + w, a + 1, a + 5, 6, 11, (96, 160, 200))
        if eje == 'x':
            L.poly([(x - 1, y - 1.5, h), (x + w + 1, y - 1.5, h), (x + w + 1, y + d / 2, h + rh), (x - 1, y + d / 2, h + rh)], aclarar(TEJA, 0.12))
            L.poly([(x + w, y, h), (x + w, y + d, h), (x + w, y + d / 2, h + rh)], mezcla(col, 0.8))
            L.poly([(x - 1, y + d / 2, h + rh), (x + w + 1, y + d / 2, h + rh), (x + w + 1, y + d + 1.5, h - 1), (x - 1, y + d + 1.5, h - 1)], TEJA)
            for k in range(1, 4):
                f = k / 4
                L.linea((x - 1, y + d / 2 + f * (d / 2 + 1.5), h + rh - f * (rh + 1)), (x + w + 1, y + d / 2 + f * (d / 2 + 1.5), h + rh - f * (rh + 1)), mezcla(TEJA, 0.82))
            L.linea((x - 1, y + d / 2, h + rh), (x + w + 1, y + d / 2, h + rh), aclarar(TEJA, 0.3))
        else:
            L.poly([(x - 1.5, y - 1, h), (x - 1.5, y + d + 1, h), (x + w / 2, y + d + 1, h + rh), (x + w / 2, y - 1, h + rh)], aclarar(TEJA, 0.12))
            L.poly([(x, y + d, h), (x + w, y + d, h), (x + w / 2, y + d, h + rh)], col)
            L.poly([(x + w / 2, y - 1, h + rh), (x + w / 2, y + d + 1, h + rh), (x + w + 1.5, y + d + 1, h - 1), (x + w + 1.5, y - 1, h - 1)], mezcla(TEJA, 0.86))
            for k in range(1, 4):
                f = k / 4
                L.linea((x + w / 2 + f * (w / 2 + 1.5), y - 1, h + rh - f * (rh + 1)), (x + w / 2 + f * (w / 2 + 1.5), y + d + 1, h + rh - f * (rh + 1)), mezcla(TEJA, 0.72))
            L.linea((x + w / 2, y - 1, h + rh), (x + w / 2, y + d + 1, h + rh), aclarar(TEJA, 0.3))
    agregar(x + w / 2 + y + d / 2 + (w + d) / 4, bbox_caja(x - 3, y - 3, 0, w + 6, d + 6, h + 20), dib)

# ---- torre de Titulares Ya (el medio rival de la mision)
def torre_titulares(x, y, w, d, pisos=6):
    FH = 18
    h = pisos * FH
    sombra_caja(x, y, w, d, h)
    bloquear_caja(x, y, w, d)
    def dib(L):
        L.caja(x, y, 0, w, d, h, (226, 226, 220), top=(176, 176, 172))
        for p in range(1, pisos):
            z = p * FH
            L.cara_y(y + d, x + 3, x + w - 3, z + 3, z + 14, (84, 140, 186))
            L.cara_x(x + w, y + 3, y + d - 3, z + 3, z + 14, (72, 124, 168))
            for k in range(1, int(w / 12)):
                L.cara_y(y + d, x + k * 12, x + k * 12 + 1, z + 3, z + 14, (226, 226, 220))
            for k in range(1, int(d / 12)):
                L.cara_x(x + w, y + k * 12, y + k * 12 + 1, z + 3, z + 14, (200, 200, 196))
            L.linea((x + 3, y + d, z + 13), (x + w / 3, y + d, z + 13), (170, 214, 236))
        # entrada
        L.cara_y(y + d, x + w / 2 - 12, x + w / 2 + 12, 0, 14, (72, 124, 168))
        L.cara_y(y + d, x + w / 2 - 1, x + w / 2 + 1, 0, 14, (226, 226, 220))
        L.caja(x + w / 2 - 16, y + d, 14, 32, 6, 2, (214, 52, 60))
        # letrero rojo arriba
        texto = 'TITULARES YA'
        s = 1.6
        aw = ancho_texto(texto, s)
        L.cara_y(y + d + 0.2, x + w / 2 - aw / 2 - 4, x + w / 2 + aw / 2 + 4, h - 16, h + 1, (214, 52, 60))
        letrero_y(L, y + d + 0.4, x + w / 2 - aw / 2, h - 4, texto, (250, 246, 236), s=s)
        letrero_x(L, x + w + 0.4, y + d / 2 + 8, h - 5, 'TY', (250, 246, 236), fondo=(214, 52, 60), s=1.6)
        # antena y parabolica
        L.caja(x + w * 0.3, y + d * 0.3, h, 10, 10, 6, (190, 190, 186))
        L.cilindro(x + w * 0.3 + 5, y + d * 0.3 + 5, h + 6, 1, 40, (200, 200, 196))
        L.cilindro(x + w * 0.3 + 5, y + d * 0.3 + 5, h + 40, 1.6, 4, (214, 52, 60))
        X0, Y0 = L.P(x + w * 0.7, y + d * 0.6, h + 12)
        L.d.ellipse([X0 - 9, Y0 - 6, X0 + 9, Y0 + 6], fill=(236, 236, 232))
        L.d.ellipse([X0 - 6, Y0 - 4, X0 + 6, Y0 + 4], fill=(206, 206, 202))
        L.caja(x + w * 0.7 - 1, y + d * 0.6 - 1, h, 2, 2, 8, (150, 150, 146))
    agregar(x + w / 2 + y + d / 2 + (w + d) / 4, bbox_caja(x - 4, y - 4, 0, w + 10, d + 10, h + 50), dib)

# ---- mercado: techo grande sobre puestos
def mercado(x, y, w, d):
    sombra_caja(x, y, w, d, 34)
    global ultima_huella
    for i in range(3):
        for j in range(2):
            bloquear_caja(x + 10 + i * (w - 20) / 2.5, y + 14 + j * (d - 28), 22, 10)
    for i in range(4):
        for j in (0, 1):
            bloquear_caja(x + 2 + i * (w - 6) / 3, y + 2 + j * (d - 6), 2, 2)
    ultima_huella = (x, y, w, d)
    def dib(L):
        verde = (66, 140, 96)
        # puestos debajo
        for i in range(3):
            for j in range(2):
                px = x + 10 + i * (w - 20) / 2.5
                py = y + 14 + j * (d - 28)
                L.caja(px, py, 0, 22, 10, 8, (176, 112, 70), top=(196, 140, 92))
                for k in range(8):
                    c = random.choice([(240, 80, 60), (250, 200, 60), (120, 186, 70), (250, 140, 50), (150, 60, 120)])
                    X0, Y0 = L.P(px + 3 + k * 2.4, py + 3 + (k % 2) * 3, 8)
                    L.d.ellipse([X0 - 2, Y0 - 2, X0 + 1, Y0 + 1], fill=c)
        # postes
        for i in range(4):
            for j in (0, 1):
                L.caja(x + 2 + i * (w - 6) / 3, y + 2 + j * (d - 6), 0, 2, 2, 34, (240, 236, 224))
        # techo a dos aguas (cumbrera a lo largo de x)
        h = 34; rh = 14
        L.poly([(x - 3, y - 4, h), (x + w + 3, y - 4, h), (x + w + 3, y + d / 2, h + rh), (x - 3, y + d / 2, h + rh)], aclarar(verde, 0.15))
        L.poly([(x + w + 3, y - 4, h), (x + w + 3, y + d + 4, h), (x + w + 3, y + d / 2, h + rh)], (236, 214, 160))
        letrero_x(L, x + w + 3.2, y + d / 2 + ancho_texto('MERCADO') / 2, h + 7, 'MERCADO', (150, 64, 48))
        L.poly([(x - 3, y + d / 2, h + rh), (x + w + 3, y + d / 2, h + rh), (x + w + 3, y + d + 4, h), (x - 3, y + d + 4, h)], verde)
        for k in range(1, int(w / 6)):
            L.linea((x - 3 + k * 6, y + d / 2, h + rh), (x - 3 + k * 6, y + d + 4, h), mezcla(verde, 0.8))
        L.linea((x - 3, y + d + 4, h), (x + w + 3, y + d + 4, h), mezcla(verde, 0.6))
    agregar(x + w / 2 + y + d / 2 + (w + d) / 4, bbox_caja(x - 6, y - 6, 0, w + 12, d + 12, 52), dib)

def caja_frutas(x, y):
    bloquear_caja(x - 4, y - 3, 8, 6)
    def dib(L):
        L.caja(x - 4, y - 3, 0, 8, 6, 5, (176, 128, 80))
        for k in range(5):
            X0, Y0 = L.P(x - 3 + k * 1.6, y - 1 + (k % 2) * 2, 5)
            L.d.ellipse([X0 - 1.5, Y0 - 2, X0 + 1.5, Y0 + 1], fill=random.choice([(240, 80, 60), (250, 200, 60), (120, 186, 70)]))
    agregar(x + y + 2, bbox_punto(x, y, 10, 14), dib)

# ---- colegio
def bandera(x, y, colores, alto=46):
    sombra_caja(x - 1, y - 1, 2, 2, alto)
    bloquear_circulo(x, y, 2.5)
    def dib(L):
        L.cilindro(x, y, 0, 2.4, 3, (190, 186, 176))
        L.cilindro(x, y, 3, 0.8, alto, (220, 220, 214))
        z = alto - 2
        alturas = [0.5, 0.25, 0.25] if len(colores) == 3 else [1.0 / len(colores)] * len(colores)
        alto_b = 11
        for c, f in zip(colores, alturas):
            L.cara_y(y, x + 1, x + 17, z - alto_b * f, z, c)
            z -= alto_b * f
    agregar(x + y, bbox_punto(x, y, 26, alto + 14), dib)

COLOMBIA = [(250, 206, 50), (40, 80, 170), (206, 40, 50)]

def arco(x, y, mira):
    # arco de micro: los palos van a lo largo de x, la red hacia afuera de la cancha
    def dib(L):
        blanco = (246, 244, 236)
        fondo = y - 6 * mira
        for k in range(0, 25, 4):
            L.linea((x - 12 + k, fondo, 12), (x - 12 + k, fondo, 0), (200, 200, 196))
        L.linea((x - 12, fondo, 12), (x + 12, fondo, 12), (200, 200, 196))
        L.caja(x - 12, y - 0.7, 0, 1.4, 1.4, 12, blanco)
        L.caja(x + 10.6, y - 0.7, 0, 1.4, 1.4, 12, blanco)
        L.caja(x - 12, y - 0.7, 12, 24, 1.4, 1.4, blanco)
    agregar(x + y, bbox_caja(x - 14, y - 10, 0, 28, 20, 16), dib, contorno=False)

def malla(x0, y0, x1, y1):
    # cerca de malla de la cancha (postes y barra arriba), por tramos
    def tramo(a, b, c, d):
        bloquear_linea(a, b, c, d)
        def dib(L):
            gris = (120, 128, 124)
            n = int(max(abs(c - a), abs(d - b)) / 16)
            for k in range(n + 1):
                px = a + (c - a) * k / max(n, 1); py = b + (d - b) * k / max(n, 1)
                L.caja(px - 0.6, py - 0.6, 0, 1.2, 1.2, 20, gris)
            L.linea((a, b, 20), (c, d, 20), gris)
            for z in (6, 12):
                L.linea((a, b, z), (c, d, z), (170, 176, 172))
        agregar(max(a, c) + max(b, d) - 4, bbox_caja(min(a, c) - 2, min(b, d) - 2, 0, abs(c - a) + 4, abs(d - b) + 4, 22), dib, contorno=False)
    for k in range(0, int((x1 - x0) / 32)):
        tramo(x0 + k * 32, y0, min(x1, x0 + (k + 1) * 32), y0)
        if k != int((x1 - x0) / 32) // 2:
            tramo(x0 + k * 32, y1, min(x1, x0 + (k + 1) * 32), y1)
    for k in range(0, int((y1 - y0) / 32)):
        tramo(x0, y0 + k * 32, x0, min(y1, y0 + (k + 1) * 32))
        tramo(x1, y0 + k * 32, x1, min(y1, y0 + (k + 1) * 32))

def edificio_simple(x, y, w, d, pisos, col, letrero=None, cara='y', banda=None, toldo=None, FH=20):
    h = pisos * FH
    sombra_caja(x, y, w, d, h)
    bloquear_caja(x, y, w, d)
    def dib(L):
        L.caja(x, y, 0, w, d, h, col, top=(186, 112, 84))
        L.caja(x - 1, y - 1, h, w + 2, d + 2, 3, aclarar(col, 0.4), top=(160, 150, 140))
        L.caja(x + 2, y + 2, h + 0.5, w - 4, d - 4, 2.6, (150, 144, 136), top=(196, 190, 180))
        if banda:
            L.cara_y(y + d, x, x + w, FH - 4, FH - 1, banda)
            L.cara_x(x + w, y, y + d, FH - 4, FH - 1, mezcla(banda, 0.85))
        for p in range(pisos):
            z = p * FH
            n = max(1, int((w - 6) / 12))
            for k in range(n):
                a = x + 3 + k * (w - 6) / n + ((w - 6) / n - 7) / 2
                if p == 0 and abs(a + 3.5 - (x + w / 2)) < 8:
                    continue
                L.cara_y(y + d, a - 1, a + 8, z + 4, z + 15, mezcla(col, 0.72))
                L.cara_y(y + d, a, a + 7, z + 5, z + 14, (110, 176, 214))
                L.cara_y(y + d, a, a + 2, z + 11, z + 14, (186, 226, 244))
            n = max(1, int((d - 6) / 12))
            for k in range(n):
                a = y + 3 + k * (d - 6) / n + ((d - 6) / n - 7) / 2
                L.cara_x(x + w, a - 1, a + 8, z + 4, z + 15, mezcla(col, 0.62))
                L.cara_x(x + w, a, a + 7, z + 5, z + 14, (96, 160, 200))
        L.cara_y(y + d, x + w / 2 - 5, x + w / 2 + 5, 0, 14, (130, 82, 54))
        L.cara_y(y + d, x + w / 2 - 4, x + w / 2 + 4, 1, 13, (96, 160, 200))
        if toldo:
            fr = 6
            for k in range(fr):
                c = toldo[k % 2]
                a = x + w / 2 - 9 + k * 18 / fr
                L.poly([(a, y + d, 18), (a + 18 / fr, y + d, 18), (a + 18 / fr, y + d + 7, 14), (a, y + d + 7, 14)], c)
        if letrero:
            texto, colt, fondo, s = letrero
            aw = ancho_texto(texto, s)
            if cara == 'y':
                letrero_y(L, y + d + 0.3, x + w / 2 - aw / 2, h - 3, texto, colt, fondo=fondo, s=s)
            else:
                letrero_x(L, x + w + 0.3, y + d / 2 + aw / 2, h - 3, texto, colt, fondo=fondo, s=s)
    agregar(x + w / 2 + y + d / 2 + (w + d) / 4, bbox_caja(x - 4, y - 4, 0, w + 12, d + 12, h + 10), dib)

# ---- obra / lote reservado
def valla(x0, y0, x1, y1):
    def tramo(a, b, c, d, cara_vis):
        bloquear_linea(a, b, c, d)
        def dib(L):
            if b == d:
                L.caja(a, b - 1, 0, c - a, 2, 14, (236, 232, 222))
                for k in range(int((c - a) / 8)):
                    L.cara_y(b + 1, a + k * 8, a + k * 8 + 4, 2, 12, (240, 140, 50))
            else:
                L.caja(a - 1, b, 0, 2, d - b, 14, (236, 232, 222))
                for k in range(int((d - b) / 8)):
                    L.cara_x(a + 1, b + k * 8, b + k * 8 + 4, 2, 12, (226, 126, 44))
        agregar(max(a, c) + max(b, d) - 6, bbox_caja(min(a, c) - 2, min(b, d) - 2, 0, abs(c - a) + 4, abs(d - b) + 4, 16), dib)
    paso = 32
    k = x0
    while k < x1:
        tramo(k, y0, min(x1, k + paso), y0, 'y'); tramo(k, y1, min(x1, k + paso), y1, 'y'); k += paso
    k = y0
    while k < y1:
        tramo(x0, k, x0, min(y1, k + paso), 'x'); tramo(x1, k, x1, min(y1, k + paso), 'x'); k += paso

def letrero_poste(x, y, texto, fondo, colt, eje='y', alto=30, s=1.0):
    def dib(L):
        aw = ancho_texto(texto, s)
        if eje == 'y':
            L.caja(x - aw / 2 - 1, y - 0.6, 0, 1.2, 1.2, alto, (110, 80, 56))
            L.caja(x + aw / 2 - 0.2, y - 0.6, 0, 1.2, 1.2, alto, (110, 80, 56))
            L.caja(x - aw / 2 - 4, y - 1, alto - 2, aw + 8, 2, 14 * s / 1.2, fondo)
            letrero_y(L, y + 1.1, x - aw / 2, alto + 9 * s / 1.2, texto, colt, s=s)
        else:
            L.caja(x - 0.6, y - aw / 2 - 1, 0, 1.2, 1.2, alto, (110, 80, 56))
            L.caja(x - 0.6, y + aw / 2 - 0.2, 0, 1.2, 1.2, alto, (110, 80, 56))
            L.caja(x - 1, y - aw / 2 - 4, alto - 2, 2, aw + 8, 14 * s / 1.2, fondo)
            letrero_x(L, x + 1.1, y + aw / 2, alto + 9 * s / 1.2, texto, colt, s=s)
    agregar(x + y + 2, bbox_caja(x - 60, y - 60, 0, 120, 120, alto + 20), dib)

def cono(x, y):
    bloquear_circulo(x, y, 2)
    def dib(L):
        X0, Y0 = L.P(x, y, 0)
        L.d.polygon([(X0 - 3, Y0), (X0 + 3, Y0), (X0, Y0 - 9)], fill=(240, 120, 40))
        L.d.line([(X0 - 2, Y0 - 4), (X0 + 2, Y0 - 4)], fill=(246, 244, 236))
        L.d.rectangle([X0 - 4, Y0, X0 + 4, Y0 + 1], fill=(220, 100, 30))
    agregar(x + y, bbox_punto(x, y, 8, 14), dib)

def monton(x, y, r, col):
    bloquear_circulo(x, y, r)
    def dib(L):
        X0, Y0 = L.P(x, y)
        rx = r * 1.414; ry = rx / 2; hh = r * 0.75
        arriba = [(X0 + rx * math.cos(t), Y0 - hh * math.sin(t)) for t in np.linspace(0, math.pi, 24)]
        abajo = [(X0 + rx * math.cos(t), Y0 + ry * math.sin(t)) for t in np.linspace(math.pi, 2 * math.pi, 24)]
        abajo = [(X0 - rx * math.cos(t), Y0 + ry * abs(math.sin(t))) for t in np.linspace(0, math.pi, 24)]
        L.d.polygon(arriba + abajo, fill=col)
        luz = [(X0 - rx * 0.25 + rx * 0.5 * math.cos(t), Y0 - hh * 0.55 - hh * 0.3 * math.sin(t)) for t in np.linspace(0, 2 * math.pi, 18)]
        L.d.polygon(luz, fill=aclarar(col, 0.25))
        for _ in range(int(r)):
            px = X0 + random.uniform(-rx * 0.7, rx * 0.7); py = Y0 - random.uniform(0, hh * 0.7)
            L.d.point((px, py), fill=mezcla(col, 0.85))
    agregar(x + y, bbox_punto(x, y, r * 1.6 + 4, r * 1.6 + 6, r), dib)

# ---- gasolinera
def gasolinera(x, y, w, d):
    sombra_caja(x, y, w, d, 32)
    global ultima_huella
    for (a, b) in [(x + 4, y + 4), (x + w - 6, y + 4), (x + 4, y + d - 6), (x + w - 6, y + d - 6)]:
        bloquear_caja(a, b, 2.4, 2.4)
    for k in range(2):
        bloquear_caja(x + w / 2 - 20, y + d / 2 - 12 + k * 20, 40, 6)
    ultima_huella = (x, y, w, d)
    def dib(L):
        for (a, b) in [(x + 4, y + 4), (x + w - 6, y + 4), (x + 4, y + d - 6), (x + w - 6, y + d - 6)]:
            L.caja(a, b, 0, 2.4, 2.4, 30, (236, 236, 228))
        for k in range(2):
            py = y + d / 2 - 12 + k * 20
            L.caja(x + w / 2 - 20, py, 0, 40, 6, 2, (200, 196, 186))
            for j in range(2):
                L.caja(x + w / 2 - 14 + j * 22, py + 1, 2, 6, 4, 12, (214, 52, 60), top=(246, 240, 230))
                L.cara_y(py + 5, x + w / 2 - 13 + j * 22, x + w / 2 - 9 + j * 22, 8, 12, (40, 40, 40))
        L.caja(x, y, 30, w, d, 4, (246, 244, 236), top=(236, 234, 226))
        L.cara_y(y + d, x, x + w, 30, 34, (214, 52, 60))
        L.cara_x(x + w, y, y + d, 30, 34, (190, 44, 52))
        letrero_y(L, y + d + 0.3, x + w / 2 - ancho_texto('GASOLINA') / 2, 41, 'GASOLINA', (214, 52, 60), fondo=(246, 244, 236))
    agregar(x + w / 2 + y + d / 2 + (w + d) / 4, bbox_caja(x - 4, y - 4, 0, w + 8, d + 8, 48), dib)

# ---- lancha en el rio
def lancha(x, y, col):
    def dib(L):
        L.caja(x - 6, y - 14, -2, 12, 28, 6, (246, 244, 236), top=(160, 110, 70))
        L.cara_x(x + 6, y - 14, y + 14, 0, 2, col)
        L.caja(x - 4, y - 2, 4, 8, 8, 6, col)
        L.cara_y(y + 6, x - 3, x + 3, 6, 9, (96, 160, 200))
    agregar(x + y, bbox_caja(x - 8, y - 16, -2, 16, 32, 14), dib)

def baranda(x, y0, y1):
    # en tramos de una baldosa: asi cada tramo se ordena bien con las palmas,
    # bancas y postes que tiene delante
    k = y0
    while k < y1:
        a, b = k, min(y1, k + 16)
        bloquear_caja(x - 1, a, 2, b - a)
        def dib(L, a=a, b=b):
            for py in (a, a + 8):
                L.caja(x - 0.6, py - 0.6, 0, 1.2, 1.2, 9, (236, 236, 228))
            if b == y1:
                L.caja(x - 0.6, b - 0.6, 0, 1.2, 1.2, 9, (236, 236, 228))
            L.caja(x - 0.8, a, 8, 1.6, b - a, 1.6, (236, 236, 228))
        agregar(x + (a + b) / 2, bbox_caja(x - 2, a - 2, 0, 4, b - a + 4, 12), dib)
        k = b

def buseta(x, y, eje, col):
    if eje == 'y':
        w, d = 15, 44
    else:
        w, d = 44, 15
    sombra_caja(x - w / 2, y - d / 2, w, d, 16)
    bloquear_caja(x - w / 2, y - d / 2, w, d)
    def dib(L):
        x0, y0 = x - w / 2, y - d / 2
        if eje == 'y':
            for dy in (5, d - 11):
                L.caja(x0 - 0.8, y0 + dy, 0, w + 1.6, 6, 4.5, (34, 32, 32))
            L.caja(x0, y0, 2.5, w, d, 16, (246, 244, 236), top=aclarar(col, 0.3))
            L.cara_x(x0 + w, y0 + 2, y0 + d - 2, 4, 8, col)
            L.cara_y(y0 + d, x0, x0 + w, 4, 8, col)
            L.cara_x(x0 + w, y0 + 3, y0 + d - 4, 11, 16.5, (70, 104, 136))
            L.cara_y(y0 + d, x0 + 1.5, x0 + w - 1.5, 10, 16.5, (60, 90, 120))
        else:
            for dx in (5, w - 11):
                L.caja(x0 + dx, y0 - 0.8, 0, 6, d + 1.6, 4.5, (34, 32, 32))
            L.caja(x0, y0, 2.5, w, d, 16, (246, 244, 236), top=aclarar(col, 0.3))
            L.cara_y(y0 + d, x0 + 2, x0 + w - 2, 4, 8, col)
            L.cara_x(x0 + w, y0, y0 + d, 4, 8, col)
            L.cara_y(y0 + d, x0 + 3, x0 + w - 4, 11, 16.5, (60, 90, 120))
            L.cara_x(x0 + w, y0 + 1.5, y0 + d - 1.5, 10, 16.5, (70, 104, 136))
    agregar(x + y + 4, bbox_caja(x - w / 2 - 2, y - d / 2 - 2, 0, w + 4, d + 4, 22), dib)

# ================================================================== poblar la ciudad
def B(tipo):
    x0, y0, w, d = manzana(tipo)
    return x0 * T, y0 * T, w * T, d * T

def segmentos(kind, validos):
    res, a = [], None
    for i, k in enumerate(list(kind) + ['#']):
        if k in validos and a is None:
            a = i
        if k not in validos and a is not None:
            res.append((a, i)); a = None
    return res

# ---- bordes de la ciudad: edificios de la orilla de arriba (y chica) y casas bajas en los bordes cercanos
for (j0, j1) in [(0, 4)]:
    for (i0, i1) in segmentos(KINDX, ('K', 'E')):
        if i1 <= MALECON: continue
        bloque_edificios(max(i0, MALECON), i1, j0, j1, False, True, False)
for (i0, i1) in segmentos(KINDY, ('K', 'E')):
    bloque_edificios(NTX - 4, NTX, i0, i1, False, False, True)
for (i0, i1) in segmentos(KINDX, ('K', 'E')):
    if i1 <= MALECON: continue
    bloque_edificios(max(i0, MALECON), i1, NTY - 4, NTY, False, False, True)

# ---- malecon y rio
baranda(RIO * T + 1, 4 * T, (NTY - 2) * T)
for k in range(3, NTY - 2, 6):
    arbol(6.6 * T, k * T, 'palma', 0.95)
for k in range(6, NTY - 4, 12):
    banca(6.0 * T, (k + 0.5) * T, 'y', -1)
    poste(7.4 * T, (k + 3.5) * T)
lancha(2.4 * T, 30 * T, (214, 62, 52))
lancha(2.0 * T, 70 * T, (60, 112, 200))

# ---- Titulares Ya
x0, y0, w, d = B('titulares')
edificio_simple(x0 + 8, y0 + 8, 6 * T, 10 * T, 2, (232, 212, 160))
torre_titulares(x0 + 8 * T, y0 + 4 * T, 10 * T, 10 * T, 6)
for k in range(3):
    jardinera(x0 + (9 + k * 3.4) * T, y0 + 16.5 * T, 2 * T, T)
carro(x0 + 3.2 * T, y0 + 16 * T, 'y', (246, 244, 236))
bandera(x0 + 18.8 * T, y0 + 15.5 * T, [(214, 52, 60), (246, 244, 236)], 40)

# ---- barrio residencial
x0, y0, w, d = B('residencial')
COL_CASA = [(240, 214, 150), (150, 200, 196), (236, 160, 120), (246, 236, 214), (180, 204, 132), (240, 186, 110), (196, 176, 220)]
a = 0.5
while a < 23:
    n = random.choice([4, 4, 5])
    if a + n > 23.5: break
    casa(x0 + (a + 0.3) * T, y0 + 12.4 * T, (n - 0.6) * T, 5 * T, random.choice(COL_CASA), 'x', 'y')
    casa(x0 + (a + 0.3) * T, y0 + 1.4 * T, (n - 0.6) * T, 5 * T, random.choice(COL_CASA), 'x', 'y')
    arbol(x0 + (a + 1) * T, y0 + 7.6 * T, 'redondo' if random.random() < 0.7 else 'guayacan', 0.8)
    a += n
for k in range(4):
    arbol(x0 + (2 + k * 6) * T, y0 + 18.6 * T, 'redondo', 0.8)

# ---- mercado
x0, y0, w, d = B('mercado')
mercado(x0 + 3 * T, y0 + 3 * T, 14 * T, 12 * T)
puesto(x0 + 5 * T, y0 + 17.5 * T)
puesto(x0 + 15 * T, y0 + 17.5 * T)
for k in range(5):
    caja_frutas(x0 + (3 + k * 3.2) * T, y0 + 19.0 * T)
mesa(x0 + 18.4 * T, y0 + 5 * T); mesa(x0 + 18.4 * T, y0 + 10 * T)

# ---- comercio
x0, y0, w, d = B('comercio')
bloque_edificios(ORX[0], ORX[0] + 7, ORY[1], ORY[1] + 24, True, False, False)
bloque_edificios(ORX[0] + 13, ORX[0] + 20, ORY[1], ORY[1] + 24, True, False, False)
for k in range(4):
    arbol(x0 + 10 * T, y0 + (3 + k * 6) * T, 'redondo', 0.9)
    banca(x0 + 10 * T + 16, y0 + (5.5 + k * 6) * T, 'y', -1)

# ---- colegio
x0, y0, w, d = B('colegio')
edificio_simple(x0 + 1 * T, y0 + 1 * T, 6 * T, 18 * T, 2, (246, 236, 214), banda=(60, 112, 200),
                letrero=('COLEGIO', (40, 80, 170), (246, 244, 236), 1.4), cara='x')
edificio_simple(x0 + 8 * T, y0 + 1 * T, 11 * T, 2.5 * T, 1, (246, 236, 214), banda=(60, 112, 200))
malla((CX0 - ORX[2] + ORX[2]) * T - 8, CY0 * T - 8, CX1 * T + 8, CY1 * T + 8)
arco((CX0 + CX1) / 2 * T, CY0 * T + 10, 1)
arco((CX0 + CX1) / 2 * T, CY1 * T - 10, -1)
cxm = (CX0 + CX1) / 2 * T
L_arcos = None
bandera(x0 + 7.6 * T, y0 + 21.5 * T, COLOMBIA)
for k in range(3):
    arbol(x0 + (2 + k * 2.5) * T, y0 + 22.6 * T, 'redondo', 0.8)

# ---- sede de campana del candidato
x0, y0, w, d = B('sede')
AZUL_CAMPANA = (52, 96, 196)
edificio_simple(x0 + 1 * T, y0 + 1 * T, 10 * T, 11 * T, 2, (246, 240, 226), banda=AZUL_CAMPANA,
                letrero=('SEDE DE CAMPAÑA', (246, 244, 236), AZUL_CAMPANA, 1.0), cara='y',
                toldo=(AZUL_CAMPANA, (246, 244, 236)))
bandera(x0 + 9.6 * T, y0 + 13.6 * T, [AZUL_CAMPANA, (246, 244, 236), AZUL_CAMPANA], 50)
bandera(x0 + 2.4 * T, y0 + 13.6 * T, COLOMBIA, 50)
carro(x0 + 16.3 * T, y0 + 4.1 * T, 'x', AZUL_CAMPANA)          # el carro del candidato
carro(x0 + 16.3 * T, y0 + 9.3 * T, 'x', (236, 236, 228))
for k in range(2):
    jardinera(x0 + (1.5 + k * 5.5) * T, y0 + 17 * T, 2.5 * T, T)
arbol(x0 + 2 * T, y0 + 15.4 * T, 'flamboyan', 0.9)
arbol(x0 + 8.8 * T, y0 + 16 * T, 'redondo', 0.9)
banca(x0 + 7.6 * T, y0 + 14.8 * T, 'x', 1)
letrero_poste(x0 + 15.5 * T, y0 + 19.6 * T, 'PARQUEADERO', (246, 244, 236), AZUL_CAMPANA, 'y', 16)

# ---- obra (lote libre para lo que venga)
x0, y0, w, d = B('obra')
valla(x0 + 8, y0 + 8, x0 + w - 8, y0 + d - 8)
letrero_poste(x0 + w / 2, y0 + d - 6, 'PRÓXIMAMENTE', (240, 140, 50), (246, 244, 236), 'y', 18, 1.2)
monton(x0 + 6 * T, y0 + 6 * T, 30, (212, 180, 120))
monton(x0 + 9 * T, y0 + 5 * T, 18, (200, 168, 110))
for k in range(6):
    cono(x0 + (12 + k * 1.4) * T, y0 + 12 * T)
edificio_simple(x0 + 16 * T, y0 + 3 * T, 5 * T, 2.4 * T, 1, (236, 190, 60), FH=16)

# ---- gasolinera
x0, y0, w, d = B('gasolinera')
gasolinera(x0 + 5 * T, y0 + 2 * T, 11 * T, 9 * T)
edificio_simple(x0 + 13.6 * T, y0 + 14.2 * T, 5 * T, 5 * T, 1, (246, 244, 236), banda=(214, 52, 60),
                letrero=('TIENDA', (214, 52, 60), None, 1.0), cara='y')
for k, c in enumerate([(240, 196, 48), (96, 166, 120), (214, 62, 52)]):
    carro(x0 + (2.9 + k * 2.8) * T, y0 + 17 * T, 'y', c, taxi=(k == 0))

# ---- parque (igual que el boceto anterior)
def pp(a, b):
    return ((P0X + a) * T, (P0Y + b) * T)

def hueco(a, b):
    return 11 <= a <= 12 or 11 <= b <= 12 or abs(a + b - 23) <= 1
for (fijo, eje) in [(0, 'x'), (23, 'x'), (0, 'y'), (23, 'y')]:
    k = 0
    while k < 24:
        a, b = (k, fijo) if eje == 'x' else (fijo, k)
        if hueco(a, b) or (eje == 'y' and (k == 0 or k == 23)):
            k += 1; continue
        n = 0
        while k + n < 24:
            a2, b2 = (k + n, fijo) if eje == 'x' else (fijo, k + n)
            if hueco(a2, b2) or (eje == 'y' and (k + n == 0 or k + n == 23)): break
            n += 1
        while n > 0:
            m = min(n, 4)
            seto(P0X + a, P0Y + b, m, eje)
            if eje == 'x': a += m
            else: b += m
            k += m; n -= m

fuente(*pp(12, 12))
# plaza: solo dos postes, el resto queda libre alrededor de la fuente
for ang in (45, 225):
    r = math.radians(ang)
    poste(*pp(12 + 5.0 * math.cos(r), 12 + 5.0 * math.sin(r)))
# senderos en cruz: una banca por lado cerca de la entrada, una caneca y un poste por brazo
for a in (4.5, 19.5):
    for (lado, mira) in ((10.6, -1), (13.4, 1)):
        x, y = pp(a, lado); banca(x, y, 'x', -mira)
        x, y = pp(lado, a); banca(x, y, 'y', -mira)
for (a, b) in [(6.6, 10.6), (17.4, 13.4), (10.6, 17.4), (13.4, 6.6)]:
    caneca(*pp(a, b))
for (a, b) in [(2.0, 10.4), (22.0, 13.6), (10.4, 22.0), (13.6, 2.0)]:
    poste(*pp(a, b))
# arriba: la tarima con dos jardineras a los lados
tarima(*pp(3.0, 3.5), 5 * T, 3 * T)
jardinera(*pp(1.5, 8.2), 2 * T, T)
jardinera(*pp(8.6, 1.5), T, 2 * T)
# derecha: el puesto de raspao con una mesa
puesto(*pp(16.5, 4.2))
mesa(*pp(21.4, 5.6))
# izquierda: jardín de flores, una jardinera a cada lado del sendero diagonal
jardinera(*pp(1.8, 16.0), 2 * T, T)
jardinera(*pp(6.6, 20.6), 2 * T, T)
# abajo: juegos
columpios(*pp(18.6, 17.4))
rodadero(*pp(15.6, 20.2))
J1, J2, J3 = (214, 62, 52), (60, 112, 200), (236, 170, 40)
VACIA = [None, None, None]
# carteleras: en el pasto, a la orilla de cada brazo de la cruz (nunca sobre el camino)
CARTELERAS_PARQUE = [(6.0, 9.4, 'x'), (14.6, 6.0, 'y'), (17.5, 14.6, 'x'), (9.4, 17.6, 'y'),
                     (9.4, 6.0, 'y'), (6.0, 14.6, 'x')]
for (a, b, e) in CARTELERAS_PARQUE:
    cartelera(*pp(a, b), e, VACIA)
# en los andenes de las manzanas vecinas (afuera del parque, al otro lado de la calle)
for b in (4.0, 12.0, 20.0):
    cartelera(*pp(-7.0, b), 'y', VACIA)       # anden de la zona comercial
for a in (6.0, 18.0):
    cartelera(*pp(a, -7.0), 'x', VACIA)       # anden del barrio residencial
for b in (7.0, 17.0):
    cartelera(*pp(31.0, b), 'y', VACIA)       # anden del colegio
for a in (4.0, 12.0, 20.0):
    cartelera(*pp(a, 31.0), 'x', VACIA)       # anden de la obra
ocupado = [(12, 12, 7.5), (5.5, 5, 4.5), (17, 4.5, 2.6), (20.2, 7.8, 1.6), (21.4, 5.6, 1.6), (18.6, 17.6, 3.6), (15.6, 20.2, 2.4),
           (2.8, 16.5, 1.8), (7.6, 21.1, 1.8), (2.5, 8.7, 1.8), (9.1, 2.5, 1.8)] + \
          [(a, b, 1.8) for (a, b, e) in CARTELERAS_PARQUE]
puestos = []
def libre(a, b, rmin):
    if not (1.6 < a < 22.4 and 1.6 < b < 22.4): return False
    if abs(a - 12) < 2.2 or abs(b - 12) < 2.2 or abs(a + b - 24) < 3.2: return False
    if math.hypot(a - 12, b - 12) < 7.2: return False
    for (c, d_, r) in ocupado:
        if math.hypot(a - c, b - d_) < r: return False
    for (c, d_) in puestos:
        if math.hypot(a - c, b - d_) < rmin: return False
    return True
intentos = 0
while len(puestos) < 16 and intentos < 4000:
    intentos += 1
    a, b = random.uniform(1.5, 22.5), random.uniform(1.5, 22.5)
    if libre(a, b, 3.3):
        puestos.append((a, b))
for n, (a, b) in enumerate(puestos):
    tipo = 'palma' if (a < 9 and b > 14) else ['redondo', 'redondo', 'guayacan', 'redondo', 'flamboyan'][n % 5]
    arbol(*pp(a, b), tipo, random.uniform(0.85, 1.1))
for k in range(1, 24, 5):
    for (a, b) in [(k + 0.5, -1.4), (-1.4, k + 0.5)]:
        arbol(*pp(a, b), 'redondo', 0.8)
    for (a, b) in [(k + 0.5, 25.4), (25.4, k + 0.5)]:
        poste(*pp(a, b))

# ---- semaforos en todas las esquinas con via
for i, (a, b) in enumerate(bandas(KINDX)):
    for j, (c, d_) in enumerate(bandas(KINDY)):
        if a < MALECON * T: continue
        semaforo(a - 1.2 * T, c - 1.2 * T, (1, 0), (i, j), 'v')
        semaforo(b + 1.2 * T, d_ + 1.2 * T, (-1, 0), (i, j), 'h')

# ---- el trafico lo pone el juego (Carros.pde): aqui no va ningun carro andando

# ------------------------------------------------------------------ personas (sprites de Infiltrado)
def persona(nombre, x, y):
    try:
        im = Image.open(f'{DATA_INF}/{nombre}.png').convert('RGBA')
    except Exception:
        return
    sombra_elipse(x, y, 4)
    X, Y = iso(x, y)
    def dib(L):
        L.img.alpha_composite(im, (int(X - L.x0 - im.width / 2), int(Y - L.y0 - im.height + 2)))
    agregar(x + y + 1, (X - 12, Y - 32, X + 12, Y + 6), dib, contorno=False, exportar=False)

for nombre, (a, b) in [('jugador1_frente_0', (12.2, 18.5)), ('jugador2_frente_1', (16.2, 12.6)), ('civil_frente_0', (7.0, 12.4)),
                       ('civil2_espalda_1', (12.6, 4.0)), ('civil_frente_2', (18.0, 11.4)), ('civil2_frente_0', (5.2, 6.4)),
                       ('civil_espalda_0', (6.4, 7.2)), ('civil2_frente_2', (19.2, 5.2)), ('civil_frente_1', (9.6, 20.6))]:
    persona(nombre, *pp(a, b))
nombres = ['civil_frente_0', 'civil2_frente_1', 'civil_espalda_2', 'civil2_espalda_0', 'civil_frente_2']
for k in range(40):
    for _ in range(50):
        cx_ = rng.integers(0, SZX); cy_ = rng.integers(0, SZY)
        if (side[cy_, cx_] or malecon[cy_, cx_]) and not park[cy_, cx_]:
            persona(random.choice(nombres), cx_, cy_)
            break
x0, y0, w, d = B('sede')
persona('jugador1_frente_0', x0 + 12.6 * T, y0 + 6 * T)
persona('civil2_frente_0', x0 + 6 * T, y0 + 13.6 * T)
x0, y0, w, d = B('mercado')
for k in range(6):
    persona(random.choice(nombres), x0 + (4 + k * 2.3) * T, y0 + (16.2 + (k % 2)) * T)
x0, y0, w, d = B('colegio')
for k in range(5):
    persona(random.choice(nombres), (CX0 + 2 + k * 1.6) * T, (CY0 + 4 + (k % 3) * 3) * T)

# ------------------------------------------------------------------ componer
pd = ImageDraw.Draw(piso)
for (x, y) in marcas:
    for k in range(0, 20, 2):
        a = 2 * math.pi * k / 20
        X0, Y0 = iso(x + 13 * math.cos(a), y + 13 * math.sin(a))
        pd.rectangle([X0 - 1, Y0, X0 + 1, Y0], fill=(250, 214, 80))

sm = np.array(sombras)
pa = np.array(piso).astype(np.float32)
k = ((sm > 0) & ~fuera)[..., None] * 0.26
pa[..., :3] = pa[..., :3] * (1 - k) + np.array((40, 34, 60)) * k
lienzo = Image.fromarray(pa.astype(np.uint8))
del pa, sm

import os, hashlib
DATOS = os.environ.get('DATOS_MUNDO')      # carpeta data/mundo del sketch (si se exporta)
if DATOS:
    os.makedirs(DATOS, exist_ok=True)
    for f in os.listdir(DATOS):
        if f.endswith('.png') or f.endswith('.txt'):
            os.remove(os.path.join(DATOS, f))
    # piso en trozos de 512 px
    TROZO = 512
    for j in range(0, H, TROZO):
        for i in range(0, W, TROZO):
            lienzo.crop((i, j, min(W, i + TROZO), min(H, j + TROZO))).save(f'{DATOS}/piso_{i // TROZO}_{j // TROZO}.png')

lienzo_juego = lienzo.copy()
encima = []
for prof, bbox, dibujar, contorno, exportar, huella, punto, sem in objetos:
    if not huella or not exportar: continue
    hx, hy, hw, hd = huella
    i0, i1, j0, j1 = int(hx), int(hx + hw), int(hy), int(hy + hd)
    if i1 <= i0 or j1 <= j0: continue
    zona_obj = camino[max(0, j0):j1, max(0, i0):i1] & ~plaza[max(0, j0):j1, max(0, i0):i1]
    if zona_obj.any() and park[min(SZY - 1, j0), min(SZX - 1, i0)]:
        encima.append((round(hx / T - P0X, 1), round(hy / T - P0Y, 1), round(hw / T, 2), round(hd / T, 2)))
print('objetos sobre senderos del parque:', encima)
objetos.sort(key=lambda o: o[0])
lineas_obj = []
vistos = {}
for prof, bbox, dibujar, contorno, exportar, huella, punto, sem in objetos:
    L = Capa(bbox)
    dibujar(L)
    if contorno:
        L.contorno()
    # recortar lo transparente
    caja = L.img.getbbox()
    if caja is None:
        continue
    img = L.img.crop(caja)
    x0, y0 = L.x0 + caja[0], L.y0 + caja[1]
    lienzo.alpha_composite(img, (x0, y0))
    if exportar:
        lienzo_juego.alpha_composite(img, (x0, y0))
    if DATOS and exportar:
        clave = hashlib.md5(img.tobytes() + bytes(str(img.size), 'ascii')).hexdigest()
        if clave not in vistos:
            vistos[clave] = f'obj_{len(vistos)}.png'
            img.save(f'{DATOS}/{vistos[clave]}')
        hx, hy, hw, hd = huella if huella else (-1, -1, -1, -1)
        lineas_obj.append(f'{vistos[clave]} {x0} {y0} {prof:.1f} {hx:.1f} {hy:.1f} {hw:.1f} {hd:.1f} {punto} {sem}')

if DATOS:
    open(f'{DATOS}/objetos.txt', 'w').write('\n'.join(lineas_obj) + '\n')
    Image.fromarray((choque * 255).astype(np.uint8), 'L').save(f'{DATOS}/choques.png')
    # zonas por baldosa
    NOMBRES = ['Calle', 'Río', 'Malecón', 'Titulares Ya', 'Barrio residencial', 'Mercado', 'Zona comercial',
               'Parque central', 'Colegio', 'Sede de campaña', 'Lote en obra', 'Gasolinera', 'Edificios']
    TIPO_ID = {'titulares': 3, 'residencial': 4, 'mercado': 5, 'comercio': 6, 'parque': 7, 'colegio': 8,
               'sede': 9, 'obra': 10, 'gasolinera': 11}
    zon = np.zeros((NTY, NTX), np.uint8)
    cu, cv = U[T // 2::T, T // 2::T], V[T // 2::T, T // 2::T]
    zon[lot[T // 2::T, T // 2::T]] = 12
    for t, m in M.items():
        zon[m[T // 2::T, T // 2::T]] = TIPO_ID[t]
    zon[malecon[T // 2::T, T // 2::T]] = 2
    zon[agua[T // 2::T, T // 2::T]] = 1
    Image.fromarray(zon, 'L').save(f'{DATOS}/zonas.png')
    open(f'{DATOS}/zonas.txt', 'w', encoding='utf-8').write('\n'.join(NOMBRES) + '\n')
    lienzo_juego.resize((W // 4, H // 4), Image.LANCZOS).save(f'{DATOS}/minimapa.png')
    sx, sy, _, _ = B('sede')
    with open(f'{DATOS}/mundo.txt', 'w') as f:
        f.write(f'OX={OX}\nOY={OY}\nT={T}\nCEL={CEL}\nANCHO={W}\nALTO={H}\nTROZO=512\n')
        f.write(f'BALDOSAS_X={NTX}\nBALDOSAS_Y={NTY}\n')
        f.write(f'INICIO_X={sx / T + 12.6:.2f}\nINICIO_Y={sy / T + 6.5:.2f}\n')
        f.write(f'CENTRO_X={P0X + 12}\nCENTRO_Y={P0Y + 12}\nRADIO_PLAZA=5.4\n')
        f.write(f'ARENA_X0={P0X - 8}\nARENA_Y0={P0Y - 8}\nARENA_X1={P0X + 32}\nARENA_Y1={P0Y + 32}\n')
        f.write('VIAS_X=' + ','.join(str(a // T) for a, b in bandas(KINDX)) + '\n')
        f.write('VIAS_Y=' + ','.join(str(a // T) for a, b in bandas(KINDY)) + '\n')
        f.write(f'MALECON={MALECON}\n')
    with open(f'{DATOS}/carros.txt', 'w') as f:
        for (x, y, ang, v) in carros_lista:
            f.write(f'{x:.3f} {y:.3f} {ang:.4f} {v}\n')
    with open(f'{DATOS}/semaforos.txt', 'w') as f:
        for (i, j, eje, luces) in semaforos_lista:
            f.write(f'{i} {j} {eje} ' + ' '.join(f'{a:.1f} {b:.1f}' for a, b in luces) + '\n')
    import subprocess
    subprocess.run([sys.executable, os.path.join(os.path.dirname(os.path.abspath(__file__)), 'gen_carros.py'), DATOS], check=True)
    with open(f'{DATOS}/puntos.txt', 'w') as f:
        for (x, y, eje, quad, frente) in puntos:
            q = ' '.join(f'{a:.1f} {b:.1f}' for a, b in quad)
            f.write(f'{x / T:.3f} {y / T:.3f} {eje} {frente[0] / T:.3f} {frente[1] / T:.3f} {q}\n')
    print('exportado:', len(vistos), 'dibujos,', len(lineas_obj), 'objetos')

lienzo.save(f'{SALIDA}/ciudad_completa.png')
lienzo.resize((lienzo.width // 2, lienzo.height // 2), Image.LANCZOS).save(f'{SALIDA}/ciudad_mini.png')

def vista(nombre, x, y):
    cx_, cy_ = iso(x, y)
    lienzo.crop((int(cx_ - 300), int(cy_ - 168), int(cx_ + 300), int(cy_ + 167))).resize((1200, 670), Image.NEAREST).save(f'{SALIDA}/{nombre}.png')

x0, y0, w, d = B('sede')
vista('vista_sede', x0 + 12 * T, y0 + 10 * T)
vista('vista_parque', *pp(12, 13.5))
x0, y0, w, d = B('titulares')
vista('vista_titulares', x0 + 16 * T, y0 + 14 * T)
x0, y0, w, d = B('obra')
vista('vista_obra', x0 + 12 * T, y0 + 6 * T)
print('ok', lienzo.size, len(objetos))
