# Efectos de sonido del mundo abierto, estilo 8 bits, generados con numpy.
# Uso: python3 gen_sonidos.py <carpeta data/sfx_mundo>
import sys, wave
import numpy as np

SR = 22050
OUT = sys.argv[1] if len(sys.argv) > 1 else '.'
rng = np.random.default_rng(7)

def t(seg):
    return np.arange(int(SR * seg)) / SR

def env(n, ataque=0.005, caida=None):
    e = np.ones(n)
    a = max(1, int(SR * ataque))
    e[:a] = np.linspace(0, 1, a)
    if caida is None:
        e *= np.linspace(1, 0, n) ** 1.5
    return e

def cuadrada(f, seg, ciclo=0.5):
    x = t(seg)
    fase = (np.cumsum(np.broadcast_to(f, x.shape)) / SR) % 1.0
    return np.where(fase < ciclo, 1.0, -1.0)

def ruido(seg):
    return rng.uniform(-1, 1, int(SR * seg))

def pasa_bajos(x, a):
    y = np.zeros_like(x); p = 0.0
    for i, v in enumerate(x):
        p = p + a * (v - p); y[i] = p
    return y

def notas(lista, ciclo=0.25, vol=0.5):
    partes = []
    for f, seg in lista:
        s = cuadrada(f, seg, ciclo) * env(int(SR * seg), 0.003)
        partes.append(s)
    return np.concatenate(partes) * vol

def guardar(nombre, x, vol=1.0):
    x = np.clip(x * vol, -1, 1)
    d = (x * 32767).astype('<i2')
    with wave.open(f'{OUT}/{nombre}.wav', 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(d.tobytes())

# un paso: golpecito de ruido grave y corto
p = pasa_bajos(ruido(0.07), 0.08) * env(int(SR * 0.07), 0.002)
guardar('paso', p, 2.2)
# lanzar: soplido que sube
n = int(SR * 0.22)
guardar('lanzar', pasa_bajos(ruido(0.22), 0.25) * np.sin(np.linspace(0, np.pi, n)) ** 2, 0.9)
# vidrio: chasquido brillante con tintineos
v = ruido(0.35) * env(int(SR * 0.35), 0.001)
tin = sum(cuadrada(f, 0.35, 0.5) * env(int(SR * 0.35), 0.001) * 0.15 for f in (2350, 3100, 3900))
guardar('vidrio', v * 0.6 + tin, 0.8)
# golpe: el botellazo (tono que cae + ruido)
f = np.linspace(260, 70, int(SR * 0.18))
guardar('golpe', cuadrada(f, 0.18, 0.5) * env(int(SR * 0.18), 0.001) * 0.5 + pasa_bajos(ruido(0.18), 0.3) * env(int(SR * 0.18), 0.001) * 0.6, 0.9)
# volante pegado: papel + ding
pap = pasa_bajos(ruido(0.08), 0.5) * env(int(SR * 0.08), 0.001)
guardar('volante', np.concatenate([pap * 0.7, notas([(988, 0.06), (1319, 0.14)], 0.25, 0.45)]))
# convencer: dos notas que suben
guardar('convencer', notas([(659, 0.07), (988, 0.16)], 0.25, 0.45))
# asegurado: arpegio y candado
guardar('asegurado', np.concatenate([notas([(523, 0.06), (659, 0.06), (784, 0.06), (1047, 0.2)], 0.25, 0.45),
                                     cuadrada(140, 0.05, 0.5) * env(int(SR * 0.05), 0.001) * 0.4]))
# flechas: acierto y error
guardar('flecha_ok', notas([(1175, 0.06)], 0.5, 0.35))
guardar('flecha_mal', notas([(196, 0.09), (147, 0.16)], 0.5, 0.4))
# cuenta regresiva y salida
guardar('cuenta', notas([(587, 0.16)], 0.5, 0.4))
guardar('empieza', notas([(1175, 0.35)], 0.5, 0.4))
# fin de la ronda: silbato (tono con vibrato)
def pito(seg):
    x = t(seg)
    f = 2100 + 140 * np.sin(2 * np.pi * 30 * x)
    e = np.ones(len(x)); a = int(SR * 0.01); e[:a] = np.linspace(0, 1, a); e[-a * 3:] = np.linspace(1, 0, a * 3)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * e
guardar('fin', np.concatenate([pito(0.18), np.zeros(int(SR * 0.08)), pito(0.5)]), 0.45)
# puerta (subirse o bajarse del carro, entrar a la sede)
guardar('puerta', np.concatenate([cuadrada(110, 0.04, 0.5) * env(int(SR * 0.04), 0.001) * 0.5,
                                  pasa_bajos(ruido(0.09), 0.2) * env(int(SR * 0.09), 0.001) * 0.7]), 0.9)
print('ok')
