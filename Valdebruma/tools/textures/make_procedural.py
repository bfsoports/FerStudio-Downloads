#!/usr/bin/env python3
"""Texturas procedurales originales (numpy + PIL) que no vienen de Poly Haven.

Uso: python3 make_procedural.py <dir_salida_pbr> <dir_salida_fx>
Genera: corteza de abedul, testa de tronco (anillos), ruido para agua/nubes/detalle.
"""
import os, sys
import numpy as np
from PIL import Image, ImageFilter


def tile_noise(n, cells, rng):
    """Ruido de valor periódico (teselable) de n×n con 'cells' celdas."""
    g = rng.random((cells, cells))
    idx = np.arange(n) * cells / n
    i0 = np.floor(idx).astype(int) % cells
    i1 = (i0 + 1) % cells
    f = idx - np.floor(idx)
    f = f * f * (3 - 2 * f)
    a = g[np.ix_(i0, i0)] * (1 - f)[None, :] + g[np.ix_(i0, i1)] * f[None, :]
    b = g[np.ix_(i1, i0)] * (1 - f)[None, :] + g[np.ix_(i1, i1)] * f[None, :]
    return a * (1 - f)[:, None] + b * f[:, None]


def fbm(n, base, octs, rng):
    out = np.zeros((n, n))
    amp, tot = 1.0, 0.0
    for o in range(octs):
        out += amp * tile_noise(n, base * 2 ** o, rng)
        tot += amp
        amp *= 0.5
    return out / tot


def normal_from_height(h, strength):
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * strength
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * strength
    nz = np.ones_like(h)
    l = np.sqrt(dx * dx + dy * dy + nz * nz)
    return np.stack([(-dx / l) * 0.5 + 0.5, (dy / l) * 0.5 + 0.5, (nz / l) * 0.5 + 0.5], -1)


def save_rgb(a, path):
    Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8)).save(path, quality=92)


def birch(out, n=512):
    rng = np.random.default_rng(5)
    base = 0.86 + 0.1 * (fbm(n, 6, 4, rng) - 0.5)
    streak = np.repeat(fbm(n, 8, 3, rng)[:, :1], n, 1)          # bandas horizontales suaves
    col = np.stack([base * 0.97, base * 0.95, base * 0.9], -1) * (0.92 + 0.16 * streak[..., None])
    h = np.ones((n, n)) * 0.6
    yy, xx = np.mgrid[0:n, 0:n]
    for k in range(150):                                         # lenticelas oscuras
        cx, cy = rng.integers(0, n, 2)
        w, t = rng.integers(8, 60), rng.integers(1, 4)
        dxm = np.minimum(np.abs(xx - cx), n - np.abs(xx - cx))
        dym = np.minimum(np.abs(yy - cy), n - np.abs(yy - cy))
        m = np.clip(1 - (dxm / w) ** 2 - (dym / t) ** 2, 0, 1)
        col *= (1 - 0.75 * m[..., None])
        h -= 0.3 * m
    for k in range(9):                                           # cicatrices negras
        cx, cy = rng.integers(0, n, 2)
        w, t = rng.integers(20, 46), rng.integers(10, 26)
        dxm = np.minimum(np.abs(xx - cx), n - np.abs(xx - cx))
        dym = np.minimum(np.abs(yy - cy), n - np.abs(yy - cy))
        m = np.clip(1.2 - (dxm / w) ** 2 - ((dym + 0.4 * dxm) / t) ** 2, 0, 1)
        col = col * (1 - m[..., None]) + m[..., None] * np.array([0.1, 0.09, 0.08])
        h -= 0.5 * m
    save_rgb(col, os.path.join(out, "bark_birch_albedo.jpg"))
    Image.fromarray((normal_from_height(h, 2.5) * 255).astype(np.uint8)).save(os.path.join(out, "bark_birch_normal.png"))
    orm = np.stack([np.clip(h + 0.3, 0, 1), np.full((n, n), 0.78), np.zeros((n, n))], -1)
    save_rgb(orm, os.path.join(out, "bark_birch_orm.jpg"))


def wood_end(out, n=256):
    rng = np.random.default_rng(9)
    yy, xx = np.mgrid[0:n, 0:n]
    cx, cy = n * 0.52, n * 0.47
    r = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) + 6 * (fbm(n, 4, 3, rng) - 0.5)
    rings = 0.5 + 0.5 * np.sin(r * 0.55)
    tone = 0.62 + 0.2 * rings - 0.12 * (r / n)
    col = np.stack([tone * 0.86, tone * 0.66, tone * 0.44], -1)
    ang = np.arctan2(yy - cy, xx - cx)
    for k in range(5):                                           # grietas radiales
        a0 = rng.uniform(-np.pi, np.pi)
        m = np.clip(1 - np.abs(np.angle(np.exp(1j * (ang - a0)))) * r / 2.5, 0, 1) * (r > 8) * (r < n * rng.uniform(0.2, 0.45))
        col *= (1 - 0.6 * m[..., None])
    save_rgb(col, os.path.join(out, "wood_end_albedo.jpg"))


def fx(out, n=256):
    rng = np.random.default_rng(3)
    h = fbm(n, 6, 5, rng)
    Image.fromarray((normal_from_height(h, 10.0) * 255).astype(np.uint8)).save(os.path.join(out, "water_normal.png"))
    a = fbm(n, 4, 5, rng); b = fbm(n, 8, 4, rng); c = fbm(n, 3, 4, rng)
    save_rgb(np.stack([a, b, c], -1) * 1.15 - 0.05, os.path.join(out, "noise_rgb.png"))
    cl = np.clip((fbm(512, 4, 6, rng) - 0.42) * 3.2, 0, 1)
    Image.fromarray((cl * 255).astype(np.uint8)).save(os.path.join(out, "clouds.png"))


if __name__ == "__main__":
    os.makedirs(sys.argv[1], exist_ok=True); os.makedirs(sys.argv[2], exist_ok=True)
    birch(sys.argv[1]); wood_end(sys.argv[1]); fx(sys.argv[2])
    print("ok procedural")
