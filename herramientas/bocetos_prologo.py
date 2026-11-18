# Bocetos provisionales del prólogo (320x180). Uso: python bocetos_prologo.py (en una carpeta vacía).
# El equipo de diseño los reemplaza por los definitivos en data/cinematicas/prologo/.

from PIL import Image, ImageDraw
import random, math
W,H=320,180
random.seed(7)
def grad(d,top,bot,y0=0,y1=H):
    for y in range(y0,y1):
        t=(y-y0)/max(1,(y1-y0-1)); c=tuple(int(top[i]+(bot[i]-top[i])*t) for i in range(3)); d.line([(0,y),(W,y)],fill=c)
def dither_glow(im,cx,cy,r,col,fuerza=1.0):
    px=im.load()
    for y in range(max(0,cy-r),min(H,cy+r)):
        for x in range(max(0,cx-r),min(W,cx+r)):
            d=math.hypot(x-cx,(y-cy)*1.2)/r
            if d<1:
                a=(1-d)**2*fuerza
                # tramado ordenado para que se vea pixel art
                b=[[0,8,2,10],[12,4,14,6],[3,11,1,9],[15,7,13,5]][y%4][x%4]/16
                if a>b*0.9:
                    p=px[x,y]; px[x,y]=tuple(int(p[i]+(col[i]-p[i])*min(1,a*1.2)) for i in range(3))+((p[3],) if len(p)==4 else ())
SIL=(10,10,16)
# 1. Cuarto de noche
im=Image.new('RGB',(W,H)); d=ImageDraw.Draw(im); grad(d,(18,20,32),(10,10,18))
d.rectangle([200,30,262,92],fill=(24,30,52)); d.rectangle([203,33,259,89],fill=(30,40,70))
for _ in range(14):   # ventanas de edificios a lo lejos
    x=random.randint(205,255); y=random.randint(55,86); d.rectangle([x,y,x+1,y+1],fill=(200,170,90))
d.line([(231,33),(231,89)],fill=(24,30,52),width=2); d.line([(203,61),(259,61)],fill=(24,30,52),width=2)
d.rectangle([0,128,W,H],fill=(16,14,22))                       # piso
d.rectangle([60,110,190,140],fill=(34,30,44)); d.rectangle([60,104,190,112],fill=(52,46,64))  # cama
d.rectangle([62,96,96,108],fill=(70,64,86))                      # almohada
# Andrés de espaldas sentado
d.ellipse([132,64,150,84],fill=SIL); d.rectangle([128,82,156,118],fill=SIL); d.polygon([(128,86),(120,112),(128,112)],fill=SIL); d.polygon([(156,86),(164,112),(156,112)],fill=SIL)
dither_glow(im,140,96,34,(90,140,220),0.9)
d.rectangle([137,93,143,99],fill=(170,215,255))
im.save('cuarto.png')
# 2. Celular de cerca (manos)
im=Image.new('RGB',(W,H)); d=ImageDraw.Draw(im); grad(d,(12,12,20),(6,6,10))
dither_glow(im,160,90,120,(40,70,120),0.7)
d.rounded_rectangle([110,8,210,190],8,fill=(18,18,24)); d.rounded_rectangle([116,16,204,190],4,fill=(22,30,48))
d.rectangle([116,16,204,28],fill=(30,42,70))
d.ellipse([92,120,126,176],fill=(58,42,40)); d.ellipse([194,120,228,176],fill=(58,42,40))   # pulgares
im.save('celular_cerca.png')
# 3. Balcón al atardecer
im=Image.new('RGB',(W,H)); d=ImageDraw.Draw(im); grad(d,(44,40,74),(170,92,74),0,110)
d.rectangle([0,110,W,H],fill=(26,22,36))
for i in range(26):                                             # ciudad
    x=i*13+random.randint(-3,3); h=random.randint(18,62); d.rectangle([x,110-h,x+11,110],fill=(34,30,52))
    for _ in range(3):
        wx=x+random.randint(2,8); wy=110-random.randint(4,h-2); d.point((wx,wy),fill=(230,190,110))
d.rectangle([0,118,W,124],fill=(20,18,28))                      # baranda
for x in range(4,W,10): d.rectangle([x,124,x+2,160],fill=(20,18,28))
d.rectangle([0,160,W,H],fill=(30,26,40))
d.rectangle([0,40,46,160],fill=(14,12,20)); d.rectangle([6,48,40,160],fill=(52,40,40))   # puerta
dither_glow(im,24,110,30,(120,90,70),0.6)
# Andrés de pie junto a la baranda, de espaldas
d.ellipse([196,70,212,88],fill=SIL); d.rectangle([193,86,215,128],fill=SIL); d.rectangle([195,128,203,160],fill=SIL); d.rectangle([205,128,213,160],fill=SIL)
im.save('balcon.png')
# capa: Mateo pequeño en la puerta
m=Image.new('RGBA',(W,H),(0,0,0,0)); d=ImageDraw.Draw(m)
d.ellipse([16,108,28,120],fill=SIL+(255,)); d.rectangle([15,119,29,146],fill=SIL+(255,)); d.rectangle([16,146,21,160],fill=SIL+(255,)); d.rectangle([23,146,28,160],fill=SIL+(255,))
m.save('mateo_puerta.png')
# 4. Celular en el piso
im=Image.new('RGB',(W,H)); d=ImageDraw.Draw(im); grad(d,(8,8,12),(16,14,20))
for y in range(100,H,14): d.line([(0,y),(W,y)],fill=(22,20,28))
d.polygon([(120,128),(200,118),(210,150),(130,162)],fill=(14,14,18))
d.polygon([(124,129),(198,120),(206,148),(132,159)],fill=(40,70,120))
d.line([(150,126),(170,152)],fill=(200,230,255)); d.line([(160,139),(190,128)],fill=(200,230,255)); d.line([(160,139),(150,150)],fill=(200,230,255))
dither_glow(im,165,140,60,(40,80,150),0.8)
im.save('celular_piso.png')
for f in ['cuarto','celular_cerca','balcon','celular_piso']:
    Image.open(f+'.png').resize((W*4,H*4),Image.NEAREST).save('vista_'+f+'.png')
