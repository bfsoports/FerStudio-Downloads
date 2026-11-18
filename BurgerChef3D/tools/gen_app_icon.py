#!/usr/bin/env python3
"""Genera los iconos de la app a partir de la imagen del usuario (hamburguesa sobre círculo amarillo y fondo rojo).

Uso:  python3 tools/gen_app_icon.py <imagen_cuadrada.png>

Escribe (PNG optimizados, de pocos KB):
  icon.png                              icono del proyecto (256 px)
  assets/icons/launcher_192.png         icono clásico de Android (192 px, la imagen completa)
  assets/icons/adaptive_bg_432.png      fondo del icono adaptable (rojo liso, el color de la imagen)
  assets/icons/adaptive_fg_432.png      primer plano: el círculo amarillo con la hamburguesa, recortado con
                                        transparencia y encajado en la zona segura (66 % central) del icono adaptable
La imagen original (2000 px, 2,2 MB) no se copia al proyecto.
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ICONS = os.path.join(ROOT, "assets", "icons")


def save_png(im, path, colors=None):
    if colors:
        im = im.quantize(colors=colors, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.FLOYDSTEINBERG) if im.mode == "RGB" else im
    im.save(path, optimize=True)
    print("%-36s %4d KB" % (os.path.relpath(path, ROOT), os.path.getsize(path) // 1024))


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    src = Image.open(sys.argv[1]).convert("RGB")
    w, h = src.size
    side = min(w, h)
    src = src.crop(((w - side) // 2, (h - side) // 2, (w + side) // 2, (h + side) // 2))
    a = np.array(src).astype(int)
    bg = tuple(int(v) for v in np.median(a[:8, :8].reshape(-1, 3), axis=0))
    # círculo: todo lo que no es el rojo del fondo
    diff = np.abs(a - np.array(bg)).sum(axis=2) > 60
    ys, xs = np.nonzero(diff)
    cx, cy = (xs.min() + xs.max()) / 2.0, (ys.min() + ys.max()) / 2.0
    r = max(xs.max() - xs.min(), ys.max() - ys.min()) / 2.0 + 2
    disc = src.crop((int(cx - r), int(cy - r), int(cx + r), int(cy + r)))
    ds = disc.size[0]
    big = 4 * ds
    mask = Image.new("L", (big, big), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, big - 1, big - 1), fill=255)
    mask = mask.resize((ds, ds), Image.LANCZOS)
    disc = disc.convert("RGBA")
    disc.putalpha(mask)

    save_png(src.resize((256, 256), Image.LANCZOS), os.path.join(ROOT, "icon.png"))
    save_png(src.resize((192, 192), Image.LANCZOS), os.path.join(ICONS, "launcher_192.png"))
    save_png(Image.new("RGB", (432, 432), bg), os.path.join(ICONS, "adaptive_bg_432.png"))
    fg = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
    d = 288   # zona segura del icono adaptable: 66 de 108 dp
    fg.alpha_composite(disc.resize((d, d), Image.LANCZOS), ((432 - d) // 2, (432 - d) // 2))
    save_png(fg, os.path.join(ICONS, "adaptive_fg_432.png"))


if __name__ == "__main__":
    main()
