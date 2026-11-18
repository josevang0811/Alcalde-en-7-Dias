# Pasa una ilustración grande a pixel art de 320x180 con pocos colores.
import sys
from PIL import Image, ImageEnhance
def pixelar(src, dst, colores=40, ancho=320, alto=180, contraste=1.08):
    im = Image.open(src).convert('RGB')
    # recorte 16:9
    w, h = im.size; r = ancho / alto
    if w / h > r: nw = int(h * r); im = im.crop(((w - nw)//2, 0, (w - nw)//2 + nw, h))
    else: nh = int(w / r); im = im.crop((0, (h - nh)//2, w, (h - nh)//2 + nh))
    im = im.resize((ancho, alto), Image.BOX)
    im = ImageEnhance.Contrast(im).enhance(contraste)
    im = im.quantize(colors=colores, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert('RGB')
    im.save(dst)
    return im
if __name__ == '__main__':
    pixelar(sys.argv[1], sys.argv[2], int(sys.argv[3]) if len(sys.argv) > 3 else 40)
