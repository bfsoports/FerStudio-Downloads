#!/usr/bin/env python3
# Uso: python3 tools/process_ui.py <carpeta con las imágenes de referencia> assets/ui   (el fondo ampliado x2 se genera aparte con EDSR)
# Prepara los recursos del menú a partir de las imágenes de referencia (sii.zip):
# título, botón JUGAR sin texto (el texto lo pone Godot, traducible), botón CONTINUAR y la pastilla marrón.
import sys, os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

src, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)

def save_webp(im, name, q=90):
    p = os.path.join(out, name)
    im.save(p, "WEBP", quality=q, method=6, alpha_quality=95)
    print(name, im.size, os.path.getsize(p) // 1024, "KB")

def trim(im, pad=4):
    a = np.array(im)[..., 3]
    ys, xs = np.where(a > 8)
    return im.crop((max(0, xs.min() - pad), max(0, ys.min() - pad), min(im.width, xs.max() + pad + 1), min(im.height, ys.max() + pad + 1)))

# ---- título
t = trim(Image.open(os.path.join(src, "titulo_burgerchef_3D.png")).convert("RGBA"))
t = t.resize((1000, round(t.height * 1000 / t.width)), Image.LANCZOS)
save_webp(t, "title.webp")

# ---- JUGAR: se borra el texto rellenando cada fila por interpolación entre los píxeles verdes de los lados
p = Image.open(os.path.join(src, "boton_de_jugar.png")).convert("RGBA")
a = np.array(p).astype(np.float32)
rgb = a[..., :3] / 255.0
mx = rgb.max(-1); mn = rgb.min(-1)
sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
dark = mx < 0.55
yellow = (r > 0.75) & (g > 0.75) & (r > g * 0.93) & (b < 0.55)   # contorno amarillo de las letras
X0, X1, Y0, Y1 = 790, 2020, 205, 640
region = np.zeros(mx.shape, bool); region[Y0:Y1, X0:X1] = True
mask = (dark | yellow) & region
mask = ndimage.binary_dilation(mask, iterations=4) & region
# no tocar el borde exterior oscuro del botón: solo dentro del relleno (filas donde a ambos lados hay verde)
for y in range(Y0, Y1):
    row = mask[y]
    if not row.any():
        continue
    xs = np.where(row)[0]
    # tramos contiguos
    splits = np.split(xs, np.where(np.diff(xs) > 1)[0] + 1)
    for s in splits:
        l, rr = s[0] - 1, s[-1] + 1
        if l < 0 or rr >= a.shape[1]:
            continue
        cl, cr = a[y, l].copy(), a[y, rr].copy()
        n = rr - l
        for i, x in enumerate(range(l + 1, rr)):
            k = (i + 1) / n
            a[y, x] = cl * (1 - k) + cr * k
pc = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))
pc = pc.filter(ImageFilter.SMOOTH) if False else pc
pc = trim(pc)
pc = pc.resize((1000, round(pc.height * 1000 / pc.width)), Image.LANCZOS)
save_webp(pc, "btn_play.webp")

# ---- CONTINUAR (ya viene sin texto)
c = trim(Image.open(os.path.join(src, "boton_de_continuar.png")).convert("RGBA"))
c = c.resize((1000, round(c.height * 1000 / c.width)), Image.LANCZOS)
save_webp(c, "btn_continue.webp")

# ---- pastilla marrón de las secciones (dibujada a 4x y reducida para que los bordes queden suaves)
def pill(w, h, fill_top, fill_bot, rim, outline, gloss=True):
    S = 4
    W, H = w * S, h * S
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    rad = H // 2 - 2 * S
    # sombra inferior
    d.rounded_rectangle((2 * S, 6 * S, W - 2 * S, H - 1 * S), rad, fill=(20, 8, 4, 150))
    d.rounded_rectangle((2 * S, 2 * S, W - 2 * S, H - 5 * S), rad, fill=outline)
    d.rounded_rectangle((5 * S, 5 * S, W - 5 * S, H - 8 * S), rad - 3 * S, fill=rim)
    # relleno con degradado vertical
    grad = Image.new("RGBA", (W, H))
    gd = ImageDraw.Draw(grad)
    for y in range(H):
        k = y / H
        col = tuple(int(fill_top[i] * (1 - k) + fill_bot[i] * k) for i in range(3)) + (255,)
        gd.line((0, y, W, y), fill=col)
    m = Image.new("L", (W, H), 0)
    ImageDraw.Draw(m).rounded_rectangle((8 * S, 7 * S, W - 8 * S, H - 11 * S), rad - 6 * S, fill=255)
    im.paste(grad, (0, 0), m)
    if gloss:
        # reflejos en las esquinas superiores, como en la referencia
        g = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        gd = ImageDraw.Draw(g)
        for cx in (rad * 0.62, W - rad * 0.62):
            gd.ellipse((cx - 9 * S, 13 * S, cx + 9 * S, 19 * S), fill=(255, 220, 200, 120))
        im.alpha_composite(g)
    return im.resize((w, h), Image.LANCZOS)

save_webp(pill(360, 100, (128, 62, 40), (92, 42, 26), (176, 92, 56), (46, 20, 12)), "pill_brown.webp")
save_webp(pill(360, 100, (110, 56, 38), (78, 36, 22), (150, 80, 50), (40, 18, 10)), "pill_brown_pressed.webp")
save_webp(pill(360, 100, (70, 46, 36), (52, 32, 24), (96, 66, 52), (34, 20, 14), gloss=False), "pill_disabled.webp")
