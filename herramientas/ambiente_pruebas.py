# Prueba los ambientes de color del mundo abierto sobre capturas, sin abrir el juego.
# Hace las mismas cuentas que data/ambiente/ambiente.glsl (sin la viñeta).
# Uso: python ambiente_pruebas.py captura.png [...]  -> una imagen por ambiente y captura.
# Si se cambian los números aquí, hay que copiarlos a AJUSTES_AMBIENTE en Ambiente.pde.
import numpy as np
from PIL import Image
def lum(c): return c[...,0]*.299+c[...,1]*.587+c[...,2]*.114
def mix(a,b,t): return a+(b-a)*t
def sat(c,s):
    L=lum(c)[...,None]; return L+(c-L)*s
def splittone(c,sh,hi,amt):
    L=lum(c)[...,None]; sh=np.array(sh); hi=np.array(hi)
    tint=mix(sh,hi,np.clip(L,0,1)); return mix(c,c*tint*1.6,amt)
def contrast(c,k,p=.5): return (c-p)*k+p
def rojos(c):
    r,g,b=c[...,0],c[...,1],c[...,2]
    return np.clip((r-np.maximum(g,b))*2.2,0,1)[...,None]
def A(c):  # Nublado
    o=sat(c,.48); o=splittone(o,(.55,.68,.78),(.78,.74,.66),.55); o=contrast(o,1.12,.45); return o*.8
def B(c):  # Atardecer sodio
    o=sat(c,.6); o=splittone(o,(.45,.42,.70),(1.0,.70,.45),.7); o=contrast(o,1.12,.5); return o*.82
def C(c):  # Noche fria
    o=sat(c,.35); o=splittone(o,(.26,.34,.62),(.62,.72,.95),.85); o=contrast(o,1.25,.45); return o*.55
G={'A_nublado':A,'B_atardecer':B,'C_noche':C}
def aplicar(f,img):
    c=np.asarray(img.convert('RGB'),np.float32)/255; return Image.fromarray((np.clip(f(c),0,1)*255+.5).astype(np.uint8))
import sys
src=sys.argv[1:]
for name,f in G.items():
    for s in src:
        aplicar(f,Image.open(s)).save(f"{name}__{s.split('/')[-1].split('.')[0]}.jpg",quality=90)
