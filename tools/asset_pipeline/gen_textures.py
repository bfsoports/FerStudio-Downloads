#!/usr/bin/env python3
"""
SECTOR ABANDONADO - stylized tileable texture generator.
All textures are original, generated procedurally (value noise + painted
details) in the art direction palette: greys, muted greens, browns.
Outputs 512x512 PNGs (Godot imports them VRAM compressed, ETC2/ASTC).
"""
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

S = 512
rng = np.random.default_rng(7)


def noise(scale, octaves=4, seed=0):
    r = np.random.default_rng(seed)
    out = np.zeros((S, S))
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        n = max(2, int(scale * 2 ** o))
        g = r.random((n, n))
        img = Image.fromarray((g * 255).astype(np.uint8)).resize((S, S), Image.BICUBIC)
        # tileable: wrap by averaging rolled copy
        a = np.asarray(img, dtype=float) / 255
        out += a * amp
        tot += amp
        amp *= 0.5
    out /= tot
    return out


def tile(a):
    """make tileable by blending with half-offset copy"""
    b = np.roll(np.roll(a, S // 2, 0), S // 2, 1)
    y, x = np.mgrid[0:S, 0:S] / S
    m = (np.minimum(np.minimum(x, 1 - x), np.minimum(y, 1 - y)) * 2)
    m = np.clip(m * 3, 0, 1)
    if a.ndim == 3:
        m = m[..., None]
    return a * m + b * (1 - m)


def colorize(n, c0, c1):
    c0, c1 = np.array(c0, float), np.array(c1, float)
    return c0 + (c1 - c0) * n[..., None]


def save(arr, name):
    Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8)).save(f'{OUT}/{name}.png', optimize=True)
    print('wrote', name)


def posterize(n, steps):
    return np.round(n * steps) / steps


def concrete():
    n = tile(noise(4, 5, 1))
    stains = tile(noise(2, 3, 2))
    c = colorize(posterize(n, 10), (92, 94, 90), (138, 140, 134))
    c *= (0.8 + 0.2 * stains)[..., None]
    im = Image.fromarray(np.clip(c, 0, 255).astype(np.uint8))
    d = ImageDraw.Draw(im)
    for _ in range(14):  # cracks
        x, y = rng.integers(0, S, 2)
        pts = [(x, y)]
        for _ in range(8):
            x += rng.integers(-30, 30)
            y += rng.integers(-30, 30)
            pts.append((x % S, y % S))
        d.line(pts, fill=(70, 72, 68), width=1)
    # panel seams
    for k in (0, S // 2):
        d.line([(k, 0), (k, S)], fill=(80, 82, 78), width=2)
        d.line([(0, k), (S, k)], fill=(80, 82, 78), width=2)
    return np.asarray(im, dtype=float)


def asphalt():
    n = tile(noise(16, 4, 3))
    c = colorize(n, (38, 40, 42), (78, 80, 82))
    grit = rng.random((S, S))
    c[grit > 0.985] += 40
    patch = tile(noise(2, 2, 4)) > 0.62
    c[patch] *= 0.82
    return c


def brick():
    im = Image.new('RGB', (S, S), (70, 60, 52))
    d = ImageDraw.Draw(im)
    bh, bw = 32, 64
    for row in range(S // bh):
        off = (bw // 2) * (row % 2)
        for col in range(-1, S // bw + 1):
            x0 = col * bw + off + 2
            y0 = row * bh + 2
            base = rng.integers(-14, 14)
            col_ = (122 + base, 66 + base // 2, 50 + base // 3)
            if rng.random() < 0.12:
                col_ = (96 + base, 90 + base, 80 + base)  # soot / replaced bricks
            d.rectangle([x0, y0, x0 + bw - 5, y0 + bh - 5], fill=col_)
    a = np.asarray(im, float)
    n = tile(noise(6, 3, 5))
    a *= (0.75 + 0.35 * n)[..., None]
    grime = tile(noise(2, 2, 6))
    a = a * (1 - 0.35 * np.clip(grime - 0.4, 0, 1)[..., None] * 2)
    return a


def metal_corrugated():
    y, x = np.mgrid[0:S, 0:S]
    ridges = (np.sin(x / S * np.pi * 2 * 16) * 0.5 + 0.5)
    n = tile(noise(5, 4, 7))
    rust = tile(noise(3, 4, 8))
    base = colorize(posterize(ridges, 4) * 0.5 + n * 0.5, (70, 84, 78), (120, 136, 128))
    r = np.clip((rust - 0.55) * 4, 0, 1)[..., None]
    base = base * (1 - r) + np.array([120, 70, 40]) * r * (0.7 + 0.3 * n[..., None])
    return base


def wood_planks():
    a = np.zeros((S, S, 3))
    ph = S // 8
    for i in range(8):
        tone = rng.integers(-18, 18)
        y0 = i * ph
        grain = tile(noise(24, 3, 20 + i))[y0:y0 + ph]
        streak = np.sin(np.linspace(0, 40, S)[None, :] + grain * 6) * 0.5 + 0.5
        col = colorize(streak * 0.4 + grain * 0.6, (88 + tone, 62 + tone, 40 + tone), (140 + tone, 104 + tone, 70 + tone))
        a[y0:y0 + ph] = col
        a[y0:y0 + 3] *= 0.55
        for nx in rng.integers(10, S - 10, 2):  # nails
            a[y0 + ph // 2 - 2:y0 + ph // 2 + 2, nx:nx + 4] = (60, 60, 62)
    return a


def dirt():
    n = tile(noise(6, 5, 30))
    c = colorize(posterize(n, 8), (66, 58, 44), (110, 98, 72))
    g = tile(noise(3, 3, 31))
    grass = np.clip((g - 0.6) * 3, 0, 1)[..., None]
    c = c * (1 - grass) + np.array([78, 92, 52]) * grass
    return c


def tiles():
    im = Image.new('RGB', (S, S), (60, 62, 58))
    d = ImageDraw.Draw(im)
    t = 64
    for yy in range(0, S, t):
        for xx in range(0, S, t):
            v = rng.integers(-12, 12)
            c = (150 + v, 148 + v, 136 + v) if ((xx + yy) // t) % 2 == 0 else (118 + v, 120 + v, 112 + v)
            d.rectangle([xx + 2, yy + 2, xx + t - 3, yy + t - 3], fill=c)
    a = np.asarray(im, float)
    a *= (0.7 + 0.35 * tile(noise(3, 3, 40)))[..., None]
    return a


def hazard():
    y, x = np.mgrid[0:S, 0:S]
    stripe = ((x + y) // 64) % 2
    c = np.where(stripe[..., None] == 0, np.array([214, 160, 32]), np.array([30, 30, 30])).astype(float)
    c *= (0.75 + 0.3 * tile(noise(5, 3, 50)))[..., None]
    return c


def roof():
    n = tile(noise(10, 4, 60))
    c = colorize(n, (48, 50, 52), (80, 80, 78))
    y = np.arange(S)
    c[(y % 64) < 3] *= 0.6
    return c


def plaster():
    n = tile(noise(5, 5, 70))
    c = colorize(posterize(n, 12), (150, 146, 128), (190, 184, 162))
    grime = tile(noise(2, 3, 71))
    y = np.linspace(0, 1, S)[:, None]
    c *= (1 - 0.35 * np.clip(grime * y * 1.6 - 0.3, 0, 1))[..., None]
    return c


if __name__ == '__main__':
    OUT = sys.argv[1]
    for fn in (concrete, asphalt, brick, metal_corrugated, wood_planks, dirt, tiles, hazard, roof, plaster):
        save(fn(), fn.__name__)
