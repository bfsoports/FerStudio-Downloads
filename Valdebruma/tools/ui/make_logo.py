"""make_logo.py — emblema, logotipo e iconos de la aplicación (originales, generados por código).

El emblema es un valle al anochecer: sol bajo, tres líneas de monte, bandas de bruma y un pino.
Salidas:
  assets/ui/emblem.png (512)            emblema redondo con transparencia
  assets/ui/logo.png (1400×420)         emblema + rótulo VALDEBRUMA
  icon.png (512)                        icono del proyecto / lanzador
  export/android/icon_main_192.png, icon_fg_432.png, icon_bg_432.png   iconos de Android (adaptativo)
Uso: python3 tools/ui/make_logo.py
"""
import os, math
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
FONT = os.path.join(ROOT, "assets", "fonts", "BarlowCondensed-SemiBold.ttf")
FONT_M = os.path.join(ROOT, "assets", "fonts", "BarlowCondensed-Medium.ttf")
SS = 4


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(len(a)))


def scene(size, inset=0.0):
    """Paisaje cuadrado (sin recortar) a 'size' px. inset reduce el motivo (icono adaptativo)."""
    n = size * SS
    im = Image.new("RGB", (n, n))
    d = ImageDraw.Draw(im)
    top, mid, low = (22, 38, 44), (60, 92, 92), (222, 160, 96)
    for y in range(n):
        t = y / n
        col = lerp(top, mid, t / 0.55) if t < 0.55 else lerp(mid, low, min(1.0, (t - 0.55) / 0.3))
        d.line([(0, y), (n, y)], fill=col)
    k = 1.0 - inset
    cx, cy = n * 0.5, n * 0.5

    def X(u):
        return cx + (u - 0.5) * n * k

    def Y(v):
        return cy + (v - 0.5) * n * k

    # sol bajo y su halo
    glow = Image.new("RGB", (n, n), (0, 0, 0))
    gd = ImageDraw.Draw(glow)
    r = n * 0.19 * k
    gd.ellipse([X(0.62) - r, Y(0.52) - r, X(0.62) + r, Y(0.52) + r], fill=(120, 84, 44))
    glow = glow.filter(ImageFilter.GaussianBlur(n * 0.05))
    im = Image.composite(im, im, Image.new("L", (n, n), 255))
    im = Image.blend(im, Image.eval(Image.merge("RGB", [Image.eval(a, lambda v: v) for a in im.split()]), lambda v: v), 0)
    im = Image.fromarray(__import__("numpy").clip(__import__("numpy").asarray(im).astype("int32") + __import__("numpy").asarray(glow).astype("int32"), 0, 255).astype("uint8"))
    d = ImageDraw.Draw(im)
    r = n * 0.085 * k
    d.ellipse([X(0.62) - r, Y(0.52) - r, X(0.62) + r, Y(0.52) + r], fill=(246, 214, 150))

    def ridge(base, amp, freq, phase, col, seed):
        pts = [(0, n)]
        steps = 160
        for i in range(steps + 1):
            u = -0.2 + 1.4 * i / steps
            h = base - amp * (0.6 * math.sin(u * freq + phase) + 0.3 * math.sin(u * freq * 2.3 + phase * 1.7 + seed) + 0.1 * math.sin(u * freq * 5.1 + seed * 2))
            pts.append((X(u), Y(h)))
        pts.append((n, n))
        d.polygon(pts, fill=col)

    def mist(v, h, alpha):
        nonlocal im, d
        band = Image.new("L", (n, n), 0)
        bd = ImageDraw.Draw(band)
        bd.rectangle([0, Y(v) - n * h * k, n, Y(v) + n * h * k], fill=alpha)
        band = band.filter(ImageFilter.GaussianBlur(n * 0.022))
        im = Image.composite(Image.new("RGB", (n, n), (214, 224, 220)), im, band)
        d = ImageDraw.Draw(im)

    ridge(0.60, 0.09, 5.0, 0.6, (58, 84, 86), 1.0)
    mist(0.63, 0.018, 120)
    ridge(0.70, 0.07, 6.5, 2.2, (38, 62, 62), 2.0)
    mist(0.745, 0.016, 110)
    ridge(0.82, 0.05, 8.0, 4.0, (20, 36, 36), 3.0)
    # pino en primer término
    px, base_y, hgt = 0.3, 0.86, 0.42
    d.rectangle([X(px) - n * 0.008 * k, Y(base_y - hgt * 0.25), X(px) + n * 0.008 * k, Y(base_y)], fill=(14, 24, 24))
    for i in range(5):
        t = i / 4
        w = (0.105 - 0.07 * t)
        y0 = base_y - hgt * (0.2 + 0.2 * t)
        y1 = y0 - hgt * (0.3 - 0.08 * t)
        d.polygon([(X(px - w), Y(y0)), (X(px + w), Y(y0)), (X(px), Y(y1))], fill=(14, 24, 24))
    return im.resize((size, size), Image.LANCZOS)


def emblem(size):
    sc = scene(size)
    n = size * SS
    mask = Image.new("L", (n, n), 0)
    ImageDraw.Draw(mask).ellipse([n * 0.04, n * 0.04, n * 0.96, n * 0.96], fill=255)
    ring = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    rd = ImageDraw.Draw(ring)
    rd.ellipse([n * 0.02, n * 0.02, n * 0.98, n * 0.98], outline=(233, 228, 212, 255), width=int(n * 0.022))
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(sc, (0, 0), mask.resize((size, size), Image.LANCZOS))
    out.alpha_composite(ring.resize((size, size), Image.LANCZOS))
    return out


def spaced(draw, xy, text, font, fill, tracking):
    x, y = xy
    for ch in text:
        draw.text((x, y), ch, font=font, fill=fill)
        x += draw.textlength(ch, font=font) + tracking
    return x


def logo():
    W, H = 1400, 420
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    em = emblem(360)
    im.alpha_composite(em, (20, 30))
    d = ImageDraw.Draw(im)
    f = ImageFont.truetype(FONT, 190)
    spaced(d, (420, 62), "VALDEBRUMA", f, (233, 228, 212, 255), 12)
    f2 = ImageFont.truetype(FONT_M, 46)
    spaced(d, (428, 286), "SUPERVIVENCIA COOPERATIVA", f2, (226, 168, 75, 255), 9)
    return im


def run():
    os.makedirs(os.path.join(ROOT, "assets", "ui"), exist_ok=True)
    os.makedirs(os.path.join(ROOT, "export", "android"), exist_ok=True)
    emblem(512).save(os.path.join(ROOT, "assets", "ui", "emblem.png"))
    logo().save(os.path.join(ROOT, "assets", "ui", "logo.png"))
    # icono cuadrado con esquinas redondeadas
    sq = scene(512)
    mask = Image.new("L", (512 * SS, 512 * SS), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, 512 * SS - 1, 512 * SS - 1], radius=96 * SS, fill=255)
    icon = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    icon.paste(sq, (0, 0), mask.resize((512, 512), Image.LANCZOS))
    icon.save(os.path.join(ROOT, "icon.png"))
    icon.resize((192, 192), Image.LANCZOS).save(os.path.join(ROOT, "export", "android", "icon_main_192.png"))
    # adaptativo: el primer plano deja margen de seguridad (66 % central)
    fg = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
    e = emblem(300)
    fg.alpha_composite(e, (66, 66))
    fg.save(os.path.join(ROOT, "export", "android", "icon_fg_432.png"))
    Image.new("RGB", (432, 432), (22, 38, 44)).save(os.path.join(ROOT, "export", "android", "icon_bg_432.png"))
    print("logo e iconos generados")


if __name__ == "__main__":
    run()
