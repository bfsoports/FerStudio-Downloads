#!/usr/bin/env python3
"""Genera las texturas de follaje originales (RGBA) de Valdebruma con PIL.

Uso: python3 make_foliage.py <dir_salida>
Cada textura es una "tarjeta" de rama/mata dibujada por capas (hojas del fondo
oscuras, hojas del frente claras) para dar profundidad sin mapas de normales.
El punto de unión con la rama está en el centro inferior (sauce: centro superior).
"""
import math, os, random, sys
from PIL import Image, ImageDraw, ImageFilter

SS = 2          # supermuestreo
N = 512         # lado final


def jitter(c, rnd, a=0.12):
    f = 1.0 + rnd.uniform(-a, a)
    g = rnd.uniform(-10, 10)
    return tuple(max(0, min(255, int(v * f + (g if i == 1 else g * 0.4)))) for i, v in enumerate(c))


def shade(c, f):
    return tuple(max(0, min(255, int(v * f))) for v in c)


def leaf_poly(length, width, lobes=0, lobe_depth=0.0, tip=1.0, n=22):
    """Contorno de hoja en coordenadas locales (x a lo largo, y transversal)."""
    up, dn = [], []
    for i in range(n + 1):
        t = i / n
        w = width * (math.sin(math.pi * t ** tip) ** 0.75)
        if lobes:
            w *= 1.0 - lobe_depth * (0.5 + 0.5 * math.cos(t * lobes * 2 * math.pi))
        up.append((t * length, w))
        dn.append((t * length, -w))
    return up + dn[::-1]


def place(poly, x, y, ang):
    ca, sa = math.cos(ang), math.sin(ang)
    return [(x + px * ca - py * sa, y + px * sa + py * ca) for px, py in poly]


def draw_leaf(d, x, y, ang, length, width, col, rnd, lobes=0, lobe_depth=0.0, tip=1.0, vein=True):
    col = jitter(col, rnd)
    poly = leaf_poly(length, width, lobes, lobe_depth, tip)
    d.polygon(place(poly, x, y, ang), fill=col + (255,))
    # mitad superior algo más clara: simula el pliegue del nervio central
    half = [(px, max(0.0, py)) for px, py in poly]
    d.polygon(place(half, x, y, ang), fill=shade(col, 1.12) + (255,))
    if vein:
        ex, ey = x + math.cos(ang) * length * 0.95, y + math.sin(ang) * length * 0.95
        d.line([(x, y), (ex, ey)], fill=shade(col, 0.72) + (255,), width=max(1, int(width * 0.12)))


def twig(d, x0, y0, ang, length, width, col, rnd, bend=0.0, steps=8):
    pts = [(x0, y0)]
    a = ang
    for i in range(steps):
        a += bend / steps + rnd.uniform(-0.06, 0.06)
        x0 += math.cos(a) * length / steps
        y0 += math.sin(a) * length / steps
        pts.append((x0, y0))
    for i in range(steps):
        w = max(1, int(width * (1 - i / steps) + 1))
        d.line([pts[i], pts[i + 1]], fill=col + (255,), width=w)
    return pts, a


def canvas():
    im = Image.new("RGBA", (N * SS, N * SS), (0, 0, 0, 0))
    return im, ImageDraw.Draw(im)


def finish(im, out, name, base):
    """Reduce, rellena el color bajo el alfa (evita halos) y guarda."""
    im = im.resize((N, N), Image.LANCZOS)
    bg = Image.new("RGBA", (N, N), base + (0,))
    blur = im.filter(ImageFilter.GaussianBlur(6))
    fill = Image.alpha_composite(bg, Image.merge("RGBA", (*blur.split()[:3], blur.split()[3].point(lambda a: 255 if a > 4 else 0))))
    res = Image.merge("RGBA", (*Image.alpha_composite(fill, im).split()[:3], im.split()[3]))
    res.save(os.path.join(out, name + ".png"))
    print("ok", name)


def broadleaf(out, name, seed, col, leaf_len, leaf_w, lobes, lobe_depth, tip, count, droop=0.0, twigs=7):
    rnd = random.Random(seed)
    im, d = canvas()
    S = N * SS
    bark = (70, 52, 38)
    for layer, f in ((0, 0.62), (1, 0.82), (2, 1.0)):
        for t in range(twigs):
            ang = -math.pi / 2 + (t - (twigs - 1) / 2) * (2.3 / twigs) + rnd.uniform(-0.12, 0.12)
            ln = S * rnd.uniform(0.5, 0.76) * (1.0 - 0.25 * abs(t - (twigs - 1) / 2) / twigs)
            pts, a = twig(d, S / 2, S * 0.985, ang, ln, 5 * SS * (1 if layer == 0 else 0.6), bark, rnd,
                          bend=rnd.uniform(-0.4, 0.4) + droop * (1 if ang > -math.pi / 2 else -1))
            for k in range(count):
                i = rnd.randint(1, len(pts) - 1)
                px, py = pts[i]
                la = a + rnd.choice((-1, 1)) * rnd.uniform(0.5, 1.5) + droop * rnd.uniform(0, 1)
                px += rnd.uniform(-S * 0.04, S * 0.04)
                py += rnd.uniform(-S * 0.04, S * 0.04)
                draw_leaf(d, px, py, la, leaf_len * S * rnd.uniform(0.75, 1.2), leaf_w * S * rnd.uniform(0.8, 1.15),
                          shade(col, f), rnd, lobes, lobe_depth, tip)
    finish(im, out, name, shade(col, 0.8))


def pine(out, name, seed, col):
    rnd = random.Random(seed)
    im, d = canvas()
    S = N * SS
    bark = (62, 46, 34)
    for layer, f in ((0, 0.6), (1, 0.8), (2, 1.0)):
        for t in range(6):
            ang = -math.pi / 2 + (t - 2.5) * 0.42 + rnd.uniform(-0.1, 0.1)
            ln = S * rnd.uniform(0.6, 0.92) * (1.0 - 0.08 * abs(t - 2.5))
            pts, a = twig(d, S / 2, S * 0.99, ang, ln, 6 * SS, bark, rnd, bend=rnd.uniform(-0.25, 0.25), steps=14)
            for i in range(1, len(pts)):
                x0, y0 = pts[i - 1]
                x1, y1 = pts[i]
                ta = math.atan2(y1 - y0, x1 - x0)
                for k in range(26):
                    u = rnd.random()
                    px, py = x0 + (x1 - x0) * u, y0 + (y1 - y0) * u
                    na = ta + rnd.choice((-1, 1)) * rnd.uniform(0.35, 1.1)
                    nl = S * rnd.uniform(0.035, 0.07)
                    c = jitter(shade(col, f), rnd, 0.18)
                    d.line([(px, py), (px + math.cos(na) * nl, py + math.sin(na) * nl)], fill=c + (255,), width=SS + 1)
                # ramillas secundarias
                if i % 3 == 0 and layer > 0:
                    sa = ta + rnd.choice((-1, 1)) * rnd.uniform(0.5, 0.9)
                    sp, _ = twig(d, x1, y1, sa, S * rnd.uniform(0.12, 0.22), 3 * SS, bark, rnd, steps=5)
                    for j in range(1, len(sp)):
                        for k in range(18):
                            u = rnd.random()
                            px = sp[j - 1][0] + (sp[j][0] - sp[j - 1][0]) * u
                            py = sp[j - 1][1] + (sp[j][1] - sp[j - 1][1]) * u
                            na = sa + rnd.choice((-1, 1)) * rnd.uniform(0.35, 1.1)
                            nl = S * rnd.uniform(0.03, 0.055)
                            c = jitter(shade(col, f), rnd, 0.18)
                            d.line([(px, py), (px + math.cos(na) * nl, py + math.sin(na) * nl)], fill=c + (255,), width=SS + 1)
    finish(im, out, name, shade(col, 0.75))


def willow(out, name, seed, col):
    rnd = random.Random(seed)
    im, d = canvas()
    S = N * SS
    for layer, f in ((0, 0.6), (1, 0.8), (2, 1.0)):
        for t in range(13):
            x = S * (0.08 + 0.84 * (t + rnd.uniform(-0.3, 0.3)) / 12)
            pts, a = twig(d, x, S * 0.01, math.pi / 2 + rnd.uniform(-0.08, 0.08), S * rnd.uniform(0.7, 0.97), 2 * SS,
                          (92, 96, 52), rnd, bend=rnd.uniform(-0.15, 0.15), steps=16)
            for i in range(1, len(pts)):
                for k in range(3):
                    px, py = pts[i]
                    la = math.pi / 2 + rnd.choice((-1, 1)) * rnd.uniform(0.25, 0.7)
                    draw_leaf(d, px, py, la, S * rnd.uniform(0.05, 0.08), S * 0.008, shade(col, f), rnd, vein=False)
    finish(im, out, name, shade(col, 0.8))


def bush(out, name, seed, col, berries=None):
    rnd = random.Random(seed)
    im, d = canvas()
    S = N * SS
    for layer, f in ((0, 0.55), (1, 0.78), (2, 1.0)):
        for k in range(190):
            a = rnd.uniform(-math.pi, 0)
            r = S * 0.46 * math.sqrt(rnd.random())
            px, py = S / 2 + math.cos(a) * r, S * 0.97 + math.sin(a) * r * 1.9
            if py < S * 0.04:
                continue
            draw_leaf(d, px, py, rnd.uniform(0, 2 * math.pi), S * rnd.uniform(0.05, 0.085), S * rnd.uniform(0.022, 0.034),
                      shade(col, f), rnd, tip=0.9)
        if layer == 1:
            for t in range(5):
                twig(d, S / 2, S * 0.99, -math.pi / 2 + (t - 2) * 0.45, S * 0.6, 4 * SS, (66, 50, 38), rnd, bend=rnd.uniform(-0.3, 0.3))
    if berries:
        for k in range(46):
            a = rnd.uniform(-math.pi, 0)
            r = S * 0.4 * math.sqrt(rnd.random())
            px, py = S / 2 + math.cos(a) * r, S * 0.93 + math.sin(a) * r * 1.8
            for j in range(rnd.randint(2, 4)):
                bx, by = px + rnd.uniform(-14, 14) * SS, py + rnd.uniform(-14, 14) * SS
                rr = rnd.uniform(5.5, 8) * SS
                c = jitter(berries, rnd, 0.15)
                d.ellipse([bx - rr, by - rr, bx + rr, by + rr], fill=c + (255,))
                d.ellipse([bx - rr * 0.45, by - rr * 0.55, bx - rr * 0.05, by - rr * 0.15], fill=shade(c, 1.7) + (255,))
    finish(im, out, name, shade(col, 0.75))


def fern(out, name, seed, col):
    rnd = random.Random(seed)
    im, d = canvas()
    S = N * SS
    for t, f in zip(range(7), (0.6, 0.7, 0.8, 1.0, 0.85, 0.72, 0.62)):
        ang = -math.pi / 2 + (t - 3) * 0.33
        pts, a = twig(d, S / 2, S * 0.99, ang, S * rnd.uniform(0.7, 0.93), 3 * SS, shade(col, 0.6), rnd,
                      bend=(t - 3) * 0.16, steps=26)
        for i in range(2, len(pts)):
            x0, y0 = pts[i - 1]
            x1, y1 = pts[i]
            ta = math.atan2(y1 - y0, x1 - x0)
            ln = S * 0.115 * math.sin(math.pi * (i / len(pts)) ** 0.6) + S * 0.01
            for sgn in (-1, 1):
                draw_leaf(d, x1, y1, ta + sgn * 1.15, ln, S * 0.011, shade(col, f), rnd, lobes=5, lobe_depth=0.35)
    finish(im, out, name, shade(col, 0.75))


def grass(out, name, seed, col, flowers=None, seedheads=False, dry=0.0):
    rnd = random.Random(seed)
    im, d = canvas()
    S = N * SS
    for layer, f in ((0, 0.6), (1, 0.8), (2, 1.0)):
        for k in range(46):
            x0 = S * (0.5 + rnd.uniform(-0.3, 0.3))
            h = S * rnd.uniform(0.35, 0.95) * (0.75 + 0.25 * layer / 2)
            lean = rnd.uniform(-0.55, 0.55)
            w = S * rnd.uniform(0.008, 0.018)
            c = jitter(shade(col, f), rnd, 0.16)
            if rnd.random() < dry:
                c = jitter((168, 150, 92), rnd, 0.1)
            segs = 10
            left, right = [], []
            for i in range(segs + 1):
                t = i / segs
                x = x0 + lean * h * t * t
                y = S * 0.995 - h * t
                ww = w * (1 - t) ** 0.8
                left.append((x - ww, y))
                right.append((x + ww, y))
            d.polygon(left + right[::-1], fill=c + (255,))
            d.line(left[:segs], fill=shade(c, 0.78) + (255,), width=SS)
            tipx, tipy = x0 + lean * h, S * 0.995 - h
            if seedheads and layer == 2 and rnd.random() < 0.3:
                for j in range(7):
                    yy = tipy + j * 7 * SS
                    d.ellipse([tipx - 4 * SS + (j % 2) * 4 * SS, yy, tipx + 4 * SS + (j % 2) * 4 * SS, yy + 9 * SS], fill=(186, 164, 104, 255))
            if flowers and layer == 2 and rnd.random() < 0.34:
                fc = jitter(rnd.choice(flowers), rnd, 0.08)
                r = rnd.uniform(9, 14) * SS
                for p in range(6):
                    a = p * math.pi / 3
                    cx, cy = tipx + math.cos(a) * r * 0.7, tipy + math.sin(a) * r * 0.7
                    d.ellipse([cx - r * 0.5, cy - r * 0.5, cx + r * 0.5, cy + r * 0.5], fill=fc + (255,))
                d.ellipse([tipx - r * 0.38, tipy - r * 0.38, tipx + r * 0.38, tipy + r * 0.38], fill=(226, 182, 60, 255))
    finish(im, out, name, shade(col, 0.75))


def reed(out, name, seed, col):
    rnd = random.Random(seed)
    im, d = canvas()
    S = N * SS
    for layer, f in ((0, 0.6), (1, 0.8), (2, 1.0)):
        for k in range(15):
            x0 = S * (0.5 + rnd.uniform(-0.3, 0.3))
            h = S * rnd.uniform(0.6, 0.93)
            lean = rnd.uniform(-0.12, 0.12)
            c = jitter(shade(col, f), rnd)
            pts = [(x0 + lean * h * (i / 12) ** 2, S * 0.995 - h * i / 12) for i in range(13)]
            d.line(pts, fill=c + (255,), width=3 * SS)
            for j in range(3):
                i = rnd.randint(2, 9)
                draw_leaf(d, pts[i][0], pts[i][1], -math.pi / 2 + rnd.choice((-1, 1)) * rnd.uniform(0.25, 0.6),
                          S * rnd.uniform(0.2, 0.34), S * 0.012, c, rnd, vein=False, tip=0.6)
            if rnd.random() < 0.55:
                tx, ty = pts[-1]
                d.rounded_rectangle([tx - 7 * SS, ty - 6 * SS, tx + 7 * SS, ty + 62 * SS], radius=7 * SS,
                                    fill=jitter((92, 60, 36), rnd, 0.1) + (255,))
                d.line([(tx, ty - 6 * SS), (tx, ty - 26 * SS)], fill=c + (255,), width=2 * SS)
    finish(im, out, name, shade(col, 0.75))


def herb(out, name, seed, col, bloom):
    rnd = random.Random(seed)
    im, d = canvas()
    S = N * SS
    for t in range(6):
        ang = -math.pi / 2 + (t - 2.5) * 0.3
        pts, a = twig(d, S / 2, S * 0.99, ang, S * rnd.uniform(0.6, 0.85), 3 * SS, shade(col, 0.7), rnd, bend=rnd.uniform(-0.2, 0.2), steps=10)
        for i in range(1, len(pts) - 2):
            for sgn in (-1, 1):
                draw_leaf(d, pts[i][0], pts[i][1], a + sgn * rnd.uniform(0.7, 1.2), S * 0.11, S * 0.02, col, rnd, lobes=4, lobe_depth=0.4)
        tx, ty = pts[-1]
        for k in range(26):
            bx, by = tx + rnd.gauss(0, S * 0.045), ty + rnd.gauss(0, S * 0.018)
            r = rnd.uniform(4, 7) * SS
            d.ellipse([bx - r, by - r, bx + r, by + r], fill=jitter(bloom, rnd, 0.06) + (255,))
    finish(im, out, name, shade(col, 0.75))


def main(out):
    os.makedirs(out, exist_ok=True)
    broadleaf(out, "leaf_oak", 11, (74, 108, 44), 0.085, 0.03, 4, 0.32, 1.0, 34)
    broadleaf(out, "leaf_birch", 12, (118, 146, 56), 0.05, 0.022, 0, 0, 0.7, 46, droop=0.5, twigs=9)
    broadleaf(out, "leaf_poplar", 13, (96, 128, 50), 0.055, 0.03, 0, 0, 0.6, 44, twigs=5)
    broadleaf(out, "leaf_apple", 14, (70, 112, 48), 0.07, 0.027, 0, 0, 0.9, 36)
    broadleaf(out, "leaf_autumn", 15, (150, 104, 40), 0.08, 0.03, 4, 0.3, 1.0, 26)
    pine(out, "leaf_pine", 21, (44, 82, 52))
    pine(out, "leaf_fir", 22, (38, 70, 58))
    willow(out, "leaf_willow", 31, (104, 132, 62))
    bush(out, "leaf_bush", 41, (62, 98, 42))
    bush(out, "leaf_bush_berry", 41, (62, 98, 42), berries=(64, 44, 110))
    bush(out, "leaf_bush_dark", 43, (46, 78, 46))
    fern(out, "leaf_fern", 51, (70, 112, 44))
    grass(out, "grass_tuft", 61, (86, 118, 46), seedheads=True, dry=0.12)
    grass(out, "grass_dry", 62, (140, 132, 70), seedheads=True, dry=0.6)
    grass(out, "grass_flowers", 63, (82, 116, 46), flowers=[(232, 228, 214), (224, 190, 70), (150, 110, 190)])
    reed(out, "reed", 71, (112, 128, 62))
    herb(out, "herb", 81, (88, 122, 70), (232, 226, 200))
    herb(out, "fiber_plant", 82, (124, 136, 66), (190, 170, 96))


if __name__ == "__main__":
    main(sys.argv[1])
