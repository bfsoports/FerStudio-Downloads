#!/usr/bin/env python3
"""Genera los recursos propios de Burger Chef 3D: iconos SVG, texturas PNG, audio WAV e iconos de la app.
Todo se crea por código (sin descargas), así que no hay licencias de terceros salvo la fuente Poppins (OFL)."""
import math, os, shutil, subprocess, wave
import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
ICONS = os.path.join(ROOT, "assets", "icons")
TEX = os.path.join(ROOT, "assets", "textures")
AUD = os.path.join(ROOT, "assets", "audio")
FONTS = os.path.join(ROOT, "assets", "fonts")
for d in (ICONS, TEX, AUD, FONTS):
    os.makedirs(d, exist_ok=True)

DARK = "#3a2620"; CREAM = "#fff1d6"; MUSTARD = "#f2b134"; RED = "#d8392b"; GREEN = "#6fb43f"; BUN = "#d9964f"

# ---------------------------------------------------------------- fuentes
for src, dst in (("Poppins-Bold.ttf", "Poppins-Bold.ttf"), ("Poppins-Medium.ttf", "Poppins-Medium.ttf")):
    p = os.path.join("/usr/share/fonts/truetype/google-fonts", src)
    if os.path.exists(p):
        shutil.copy(p, os.path.join(FONTS, dst))

# ---------------------------------------------------------------- iconos SVG
def svg(name, body, w=128, h=128):
    # Ya no se genera ningún icono SVG: los iconos son los 3D propios de assets/ui/icons (Canva) y la mira del HUD se
    # dibuja en código. Se conservan las definiciones solo como referencia histórica.
    return
    with open(os.path.join(ICONS, "icon_%s.svg" % name), "w") as f:
        f.write('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">%s</svg>\n' % (w, h, w, h, body))

def badge(glyph):
    return ('<circle cx="64" cy="64" r="60" fill="%s" fill-opacity="0.86"/>'
            '<circle cx="64" cy="64" r="57" fill="none" stroke="%s" stroke-width="5"/>' % (DARK, MUSTARD)) + glyph

def star_points(cx, cy, R, r, n=5):
    pts = []
    for i in range(n * 2):
        ang = -math.pi / 2 + i * math.pi / n
        rad = R if i % 2 == 0 else r
        pts.append("%.1f,%.1f" % (cx + rad * math.cos(ang), cy + rad * math.sin(ang)))
    return " ".join(pts)

def gear_path(cx, cy, R=52, r=40, teeth=8, hole=17):
    pts = []
    for i in range(teeth):
        base = i * 2 * math.pi / teeth
        for rad, off in ((r, -0.30), (R, -0.17), (R, 0.17), (r, 0.30)):
            a = base + off
            pts.append("%.1f,%.1f" % (cx + rad * math.cos(a), cy + rad * math.sin(a)))
    d = "M" + " L".join(pts) + " Z"
    d += " M%d,%d A%d,%d 0 1 0 %d,%d A%d,%d 0 1 0 %d,%d Z" % (cx + hole, cy, hole, hole, cx - hole, cy, hole, hole, cx + hole, cy)
    return d

# --- iconos de interacción (insignia oscura + glifo crema)
svg("grab", badge(
    '<g fill="%s"><rect x="38" y="54" width="52" height="42" rx="14"/>'
    '<rect x="40" y="28" width="11" height="42" rx="5.5"/><rect x="53" y="22" width="11" height="48" rx="5.5"/>'
    '<rect x="66" y="24" width="11" height="46" rx="5.5"/><rect x="79" y="32" width="11" height="38" rx="5.5"/>'
    '<rect x="25" y="60" width="11" height="30" rx="5.5" transform="rotate(-32 30 75)"/></g>' % CREAM))
svg("drop", badge(
    '<g fill="%s"><rect x="55" y="24" width="18" height="34" rx="4"/><polygon points="37,54 91,54 64,86"/></g>'
    '<rect x="30" y="94" width="68" height="10" rx="5" fill="%s"/>' % (CREAM, MUSTARD)))
svg("use", badge(
    '<path d="M64 20 C74 44 94 54 90 80 C87 98 73 108 64 108 C52 108 38 98 38 80 C38 66 48 60 52 46 C58 54 60 60 64 20 Z" fill="%s"/>'
    '<path d="M64 62 C70 74 78 80 76 92 C75 100 69 104 64 104 C58 104 52 100 52 92 C52 84 58 80 64 62 Z" fill="%s"/>' % (MUSTARD, CREAM)))
svg("tray", badge(
    '<path d="M26 82 A38 38 0 0 1 102 82 Z" fill="%s"/><rect x="20" y="82" width="88" height="10" rx="5" fill="%s"/>'
    '<circle cx="64" cy="38" r="6" fill="%s"/>' % (CREAM, MUSTARD, CREAM)))
svg("trash", badge(
    '<g fill="%s"><rect x="40" y="48" width="48" height="50" rx="8"/><rect x="34" y="36" width="60" height="9" rx="4"/>'
    '<rect x="54" y="27" width="20" height="10" rx="4"/></g>'
    '<g stroke="%s" stroke-width="4" stroke-linecap="round"><line x1="54" y1="58" x2="54" y2="88"/><line x1="64" y1="58" x2="64" y2="88"/><line x1="74" y1="58" x2="74" y2="88"/></g>' % (CREAM, DARK)))
svg("blocked", badge(
    '<g stroke="#ff7b6b" stroke-width="12" stroke-linecap="round"><line x1="42" y1="42" x2="86" y2="86"/><line x1="86" y1="42" x2="42" y2="86"/></g>'))
svg("lock", badge(
    '<rect x="38" y="58" width="52" height="40" rx="9" fill="%s"/>'
    '<path d="M48 58 V48 A16 16 0 0 1 80 48 V58" fill="none" stroke="%s" stroke-width="9"/>'
    '<circle cx="64" cy="78" r="6" fill="%s"/>' % (CREAM, CREAM, DARK)))
svg("reticle",
    '<circle cx="32" cy="32" r="11" fill="none" stroke="%s" stroke-opacity="0.8" stroke-width="5"/>'
    '<circle cx="32" cy="32" r="3" fill="%s" fill-opacity="0.9"/>' % (CREAM, CREAM), 64, 64)

# --- iconos de interfaz
svg("coin",
    '<circle cx="64" cy="64" r="56" fill="%s" stroke="#8a5a14" stroke-width="6"/>'
    '<circle cx="64" cy="64" r="38" fill="none" stroke="#fbd780" stroke-width="7"/>'
    '<path d="M38 52 A30 30 0 0 1 60 36" fill="none" stroke="#fff3c4" stroke-width="7" stroke-linecap="round"/>' % MUSTARD)
svg("star", '<polygon points="%s" fill="%s" stroke="#8a5a14" stroke-width="6" stroke-linejoin="round"/>' % (star_points(64, 68, 56, 25), MUSTARD))
svg("star_empty", '<polygon points="%s" fill="#5b4038" stroke="#8d7468" stroke-width="6" stroke-linejoin="round"/>' % star_points(64, 68, 56, 25))
svg("clock",
    '<circle cx="64" cy="64" r="56" fill="%s" stroke="%s" stroke-width="8"/>'
    '<g stroke="%s" stroke-width="9" stroke-linecap="round"><line x1="64" y1="64" x2="64" y2="34"/><line x1="64" y1="64" x2="86" y2="76"/></g>' % (CREAM, DARK, DARK))
svg("pause",
    '<rect x="30" y="24" width="24" height="80" rx="8" fill="%s"/><rect x="74" y="24" width="24" height="80" rx="8" fill="%s"/>' % (CREAM, CREAM))
svg("book",
    '<rect x="18" y="14" width="92" height="100" rx="12" fill="%s" stroke="%s" stroke-width="6"/>'
    '<rect x="34" y="14" width="8" height="100" fill="#a82a1f"/>'
    '<g fill="%s"><rect x="52" y="36" width="46" height="8" rx="4"/><rect x="52" y="54" width="46" height="8" rx="4"/><rect x="52" y="72" width="30" height="8" rx="4"/></g>' % (RED, DARK, CREAM))
svg("burger",
    '<ellipse cx="64" cy="116" rx="42" ry="5" fill="#000" fill-opacity="0.2"/>'
    '<path d="M20 68 C20 36 42 16 64 16 C86 16 108 36 108 68 Z" fill="#e0a15a" stroke="#8a5a2a" stroke-width="5" stroke-linejoin="round"/>'
    '<g fill="%s"><ellipse cx="46" cy="40" rx="5" ry="2.8" transform="rotate(-25 46 40)"/><ellipse cx="68" cy="30" rx="5" ry="2.8"/>'
    '<ellipse cx="88" cy="42" rx="5" ry="2.8" transform="rotate(25 88 42)"/><ellipse cx="60" cy="52" rx="5" ry="2.8" transform="rotate(10 60 52)"/></g>'
    '<path d="M14 72 q10 -10 20 0 t20 0 t20 0 t20 0 t20 0 v8 h-100 z" fill="%s" stroke="#3f7a1f" stroke-width="3"/>'
    '<polygon points="20,80 108,80 98,94 84,84 64,96 44,84 30,94" fill="%s" stroke="#a87a10" stroke-width="3" stroke-linejoin="round"/>'
    '<rect x="18" y="84" width="92" height="16" rx="8" fill="#5b3524" stroke="#2d1a12" stroke-width="4"/>'
    '<rect x="22" y="98" width="84" height="16" rx="8" fill="%s" stroke="#8a5a2a" stroke-width="5"/>' % (CREAM, GREEN, MUSTARD, BUN))
svg("check",
    '<circle cx="64" cy="64" r="58" fill="%s" stroke="#3f7a1f" stroke-width="6"/>'
    '<path d="M36 66 L56 86 L94 44" fill="none" stroke="#fff" stroke-width="13" stroke-linecap="round" stroke-linejoin="round"/>' % GREEN)
svg("cross",
    '<circle cx="64" cy="64" r="58" fill="%s" stroke="#8c1f16" stroke-width="6"/>'
    '<g stroke="#fff" stroke-width="13" stroke-linecap="round"><line x1="42" y1="42" x2="86" y2="86"/><line x1="86" y1="42" x2="42" y2="86"/></g>' % RED)
svg("back", '<path d="M80 22 L38 64 L80 106" fill="none" stroke="%s" stroke-width="16" stroke-linecap="round" stroke-linejoin="round"/>' % CREAM)
svg("settings", '<path d="%s" fill="%s" fill-rule="evenodd"/>' % (gear_path(64, 64), CREAM))
svg("flag",
    '<rect x="26" y="14" width="10" height="100" rx="5" fill="%s"/>'
    '<path d="M36 20 H104 L88 44 L104 68 H36 Z" fill="%s" stroke="%s" stroke-width="5" stroke-linejoin="round"/>' % (CREAM, RED, DARK))
svg("palette",
    '<path d="M64 14 C32 14 14 36 14 62 C14 92 38 114 66 114 C78 114 80 104 74 96 C68 88 74 80 86 80 H98 C108 80 114 74 114 64 C114 36 94 14 64 14 Z" fill="#c98a4b" stroke="%s" stroke-width="6"/>'
    '<circle cx="40" cy="58" r="9" fill="%s"/><circle cx="62" cy="38" r="9" fill="%s"/><circle cx="88" cy="44" r="9" fill="%s"/><circle cx="42" cy="86" r="9" fill="#4a90d9"/>' % (DARK, RED, MUSTARD, GREEN))
svg("home",
    '<path d="M64 16 L16 62 H30 V108 H98 V62 H112 Z" fill="%s" stroke="%s" stroke-width="6" stroke-linejoin="round"/>'
    '<rect x="52" y="74" width="24" height="34" rx="4" fill="%s"/>' % (CREAM, DARK, RED))
svg("upgrade",
    '<circle cx="64" cy="64" r="58" fill="%s" stroke="#3f7a1f" stroke-width="6"/>'
    '<path d="M64 98 V36 M38 62 L64 34 L90 62" fill="none" stroke="#fff" stroke-width="14" stroke-linecap="round" stroke-linejoin="round"/>' % GREEN)
svg("play", '<polygon points="34,20 108,64 34,108" fill="%s" stroke="%s" stroke-width="6" stroke-linejoin="round"/>' % (CREAM, DARK))
svg("xp", '<polygon points="64,10 112,64 64,118 16,64" fill="#4aa3df" stroke="#1f5f8f" stroke-width="6" stroke-linejoin="round"/>'
          '<polygon points="64,26 64,64 36,64" fill="#9ad4f5"/>')
svg("smile",
    '<circle cx="64" cy="64" r="56" fill="%s" stroke="#8a5a14" stroke-width="6"/>'
    '<circle cx="46" cy="52" r="7" fill="%s"/><circle cx="82" cy="52" r="7" fill="%s"/>'
    '<path d="M38 76 Q64 106 90 76" fill="none" stroke="%s" stroke-width="8" stroke-linecap="round"/>' % (MUSTARD, DARK, DARK, DARK))
svg("recipes_small", '<rect x="20" y="16" width="88" height="96" rx="10" fill="%s" stroke="%s" stroke-width="6"/>'
                     '<g fill="%s"><rect x="36" y="36" width="56" height="9" rx="4"/><rect x="36" y="58" width="56" height="9" rx="4"/><rect x="36" y="80" width="36" height="9" rx="4"/></g>' % (CREAM, DARK, DARK))
svg("orders", '<rect x="26" y="10" width="76" height="108" rx="8" fill="%s" stroke="%s" stroke-width="6"/>'
              '<g fill="%s"><rect x="40" y="30" width="48" height="8" rx="4"/><rect x="40" y="50" width="48" height="8" rx="4"/><rect x="40" y="70" width="32" height="8" rx="4"/></g>' % (CREAM, DARK, RED))

# ---------------------------------------------------------------- texturas
rng = np.random.default_rng(11)

def hexc(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], dtype=float)

def save_tex(name, arr):
    Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB").save(os.path.join(TEX, name + ".png"), optimize=True)

def checker(c1, c2, size=256, squares=2, grout=3):
    img = np.zeros((size, size, 3))
    s = size // squares
    for y in range(squares):
        for x in range(squares):
            img[y * s:(y + 1) * s, x * s:(x + 1) * s] = hexc(c1) if (x + y) % 2 == 0 else hexc(c2)
    img += rng.normal(0, 2.0, (size, size, 1))
    for k in range(squares):
        img[k * s:k * s + grout, :] *= 0.9
        img[:, k * s:k * s + grout] *= 0.9
    return img

save_tex("floor_red", checker("#f3e6cc", "#c9453a"))
save_tex("floor_blue", checker("#f3e6cc", "#3f78b8"))
save_tex("floor_green", checker("#f3e6cc", "#5aa04a"))

def wood(size=256, planks=4):
    img = np.zeros((size, size, 3))
    ph = size // planks
    base = [hexc("#b57b45"), hexc("#a56d3b"), hexc("#bd8650"), hexc("#a97440")]
    xs = np.arange(size)
    for p in range(planks):
        y0, y1 = p * ph, (p + 1) * ph
        img[y0:y1, :] = base[p % len(base)]
        for y in range(y0, y1):
            g = 0.0
            for k, a in ((3, 5), (7, 3), (13, 2)):
                g = g + a * np.sin(2 * np.pi * k * xs / size + y * 0.35 + p * 1.7)
            img[y, :, :] += g[:, None]
        img[y0:y0 + 3, :] *= 0.72
        off = (p * 83) % size
        img[y0:y1, off:off + 2] *= 0.75
    img += rng.normal(0, 1.5, (size, size, 1))
    return img

save_tex("floor_wood", wood())

def subway(size=256, th=32, tw=64):
    img = np.zeros((size, size, 3)) + hexc("#f4f1ea")
    rows = size // th
    for r in range(rows):
        off = (tw // 2) if r % 2 else 0
        y0 = r * th
        img[y0:y0 + 2, :] = hexc("#cdc7ba")
        for c in range(size // tw + 1):
            x0 = (c * tw + off) % size
            img[y0:y0 + th, x0:x0 + 2] = hexc("#cdc7ba")
            if x0 + 2 > size:
                img[y0:y0 + th, 0:(x0 + 2) - size] = hexc("#cdc7ba")
            img[y0 + 3:y0 + 6, x0 + 3:min(size, x0 + tw - 3)] += 5
    img += rng.normal(0, 1.4, (size, size, 1))
    return img

save_tex("tiles", subway())

# ---------------------------------------------------------------- audio
SR = 22050
arng = np.random.default_rng(7)

def adsr(n, a=0.005, d=0.05, s=0.7, r=0.08):
    an, dn, rn = max(1, int(a * SR)), max(1, int(d * SR)), max(1, int(r * SR))
    sus = max(0, n - an - dn - rn)
    env = np.concatenate([np.linspace(0, 1, an, endpoint=False), np.linspace(1, s, dn, endpoint=False), np.full(sus, s), np.linspace(s, 0, rn)])
    if len(env) < n:
        env = np.pad(env, (0, n - len(env)))
    return env[:n]

def wave_shape(ph, kind):
    if kind == "sine":
        return np.sin(ph)
    if kind == "tri":
        return 2 / np.pi * np.arcsin(np.sin(ph))
    if kind == "square":
        return np.tanh(3 * np.sin(ph)) * 0.7
    if kind == "saw":
        return 2 * ((ph / (2 * np.pi)) % 1.0) - 1
    return np.sin(ph)

def note(freq, dur, kind="sine", vol=0.5, **env):
    n = int(SR * dur)
    ph = 2 * np.pi * freq * (np.arange(n) / SR)
    return wave_shape(ph, kind) * adsr(n, **env) * vol

def sweep(f0, f1, dur, kind="sine", vol=0.5, **env):
    n = int(SR * dur)
    f = np.linspace(f0, f1, n)
    ph = 2 * np.pi * np.cumsum(f) / SR
    return wave_shape(ph, kind) * adsr(n, **env) * vol

def noise(dur, vol=1.0):
    return arng.uniform(-1, 1, int(SR * dur)) * vol

def lowpass(x, k):
    if k <= 1:
        return x
    c = np.cumsum(np.insert(x, 0, 0.0))
    y = (c[k:] - c[:-k]) / k
    return np.concatenate([np.full(k - 1, y[0]), y])

def mix(*arrs):
    n = max(len(a) for a in arrs)
    out = np.zeros(n)
    for a in arrs:
        out[:len(a)] += a
    return out

def seq(*arrs, gap=0.0):
    parts = []
    for a in arrs:
        parts.append(a)
        if gap > 0:
            parts.append(np.zeros(int(SR * gap)))
    return np.concatenate(parts)

def save_wav(name, x, peak=0.85):
    m = float(np.max(np.abs(x))) or 1.0
    y = (x / m * peak * 32767).astype(np.int16)
    with wave.open(os.path.join(AUD, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(y.tobytes())

save_wav("sfx_click", mix(note(1100, 0.07, "sine", 0.6, a=0.001, d=0.02, s=0.2, r=0.04), note(1650, 0.05, "sine", 0.25, a=0.001, d=0.01, s=0.1, r=0.03)))
save_wav("sfx_pickup", sweep(380, 760, 0.1, "tri", 0.6, a=0.003, d=0.03, s=0.5, r=0.04))
save_wav("sfx_place", mix(sweep(190, 80, 0.14, "sine", 0.7, a=0.002, d=0.05, s=0.3, r=0.06), lowpass(noise(0.05, 0.4), 6) * adsr(int(SR * 0.05), 0.001, 0.02, 0.2, 0.02)))

def make_sizzle():
    n = int(SR * 1.2); f = int(SR * 0.1)
    x = lowpass(noise(1.2 + 0.1), 3)[:n + f] * 0.35
    for _ in range(26):
        p = arng.integers(0, n + f - 200)
        x[p:p + 120] += arng.uniform(-1, 1, 120) * arng.uniform(0.3, 0.8) * np.linspace(1, 0, 120)
    out = x[:n].copy()
    ramp = np.linspace(0, 1, f)
    out[:f] = out[:f] * ramp + x[n:n + f] * (1 - ramp)
    return out

save_wav("sfx_sizzle", make_sizzle(), 0.6)

def bell(freq, dur=0.8):
    t = np.arange(int(SR * dur)) / SR
    return (np.sin(2 * np.pi * freq * t) * np.exp(-t * 6) + 0.4 * np.sin(2 * np.pi * freq * 2.01 * t) * np.exp(-t * 9) + 0.2 * np.sin(2 * np.pi * freq * 3.02 * t) * np.exp(-t * 12))

save_wav("sfx_ding", bell(1318.5, 0.8))
save_wav("sfx_deliver", mix(seq(note(659, 0.08, "tri", 0.6, a=0.002, d=0.03, s=0.5, r=0.03), note(880, 0.16, "tri", 0.6, a=0.002, d=0.04, s=0.5, r=0.08)), np.concatenate([np.zeros(int(SR * 0.1)), bell(1760, 0.5) * 0.35])))
save_wav("sfx_happy", seq(*[note(f, 0.075, "tri", 0.55, a=0.002, d=0.02, s=0.5, r=0.03) for f in (523, 659, 784, 1046)]))
save_wav("sfx_impatient", seq(note(330, 0.12, "square", 0.4, a=0.002, d=0.03, s=0.6, r=0.04), note(262, 0.22, "square", 0.4, a=0.002, d=0.03, s=0.6, r=0.1)))
save_wav("sfx_win", seq(*[note(f, 0.13, "tri", 0.55, a=0.002, d=0.03, s=0.6, r=0.04) for f in (523, 659, 784)], mix(note(523, 0.9, "tri", 0.4, a=0.01, d=0.1, s=0.6, r=0.4), note(659, 0.9, "tri", 0.35, a=0.01, d=0.1, s=0.6, r=0.4), note(784, 0.9, "tri", 0.35, a=0.01, d=0.1, s=0.6, r=0.4), note(1046, 0.9, "sine", 0.25, a=0.01, d=0.1, s=0.6, r=0.4))))
save_wav("sfx_lose", seq(note(392, 0.2, "tri", 0.5, a=0.005, d=0.05, s=0.6, r=0.06), note(311, 0.2, "tri", 0.5, a=0.005, d=0.05, s=0.6, r=0.06), note(262, 0.6, "tri", 0.5, a=0.005, d=0.1, s=0.6, r=0.3)))
save_wav("sfx_buy", mix(np.concatenate([noise(0.04, 0.5) - lowpass(noise(0.04, 0.5), 8), np.zeros(int(SR * 0.3))]), np.concatenate([np.zeros(int(SR * 0.04)), note(1568, 0.1, "sine", 0.5, a=0.002, d=0.02, s=0.5, r=0.05), note(2093, 0.3, "sine", 0.5, a=0.002, d=0.05, s=0.5, r=0.2)])))
save_wav("sfx_burnt", seq(*[note(880, 0.09, "square", 0.4, a=0.002, d=0.02, s=0.7, r=0.02) for _ in range(3)], gap=0.06))
save_wav("sfx_coin", seq(note(1568, 0.06, "sine", 0.5, a=0.002, d=0.02, s=0.5, r=0.02), note(2093, 0.2, "sine", 0.5, a=0.002, d=0.04, s=0.5, r=0.12)))
save_wav("sfx_error", sweep(220, 120, 0.18, "square", 0.45, a=0.002, d=0.03, s=0.7, r=0.06))
save_wav("sfx_cooked", mix(note(1046, 0.12, "sine", 0.5, a=0.002, d=0.03, s=0.5, r=0.06), np.concatenate([np.zeros(int(SR * 0.07)), note(1568, 0.22, "sine", 0.4, a=0.002, d=0.04, s=0.4, r=0.14)])))
save_wav("sfx_tick", note(800, 0.06, "sine", 0.6, a=0.001, d=0.02, s=0.4, r=0.03))
save_wav("sfx_go", note(1200, 0.3, "tri", 0.6, a=0.002, d=0.05, s=0.6, r=0.15))

def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)

def add(buf, start_s, sig):
    i = int(start_s * SR)
    idx = (np.arange(len(sig)) + i) % len(buf)
    np.add.at(buf, idx, sig)

CH = {"C": [60, 64, 67], "Am": [57, 60, 64], "F": [53, 57, 60], "G": [55, 59, 62]}
MELODY = [
    [(0, 76, 2), (2, 79, 2), (4, 76, 1), (5, 74, 1), (6, 72, 2)],
    [(0, 72, 2), (2, 76, 2), (4, 81, 2), (6, 76, 2)],
    [(0, 77, 2), (2, 76, 1), (3, 74, 1), (4, 72, 4)],
    [(0, 74, 2), (2, 79, 2), (4, 74, 2), (6, 71, 2)],
    [(0, 79, 2), (2, 76, 2), (4, 72, 2), (6, 76, 2)],
    [(0, 81, 3), (3, 79, 1), (4, 76, 2), (6, 72, 2)],
    [(0, 77, 2), (2, 81, 2), (4, 77, 2), (6, 72, 2)],
    [(0, 79, 2), (2, 74, 2), (4, 71, 2), (6, 74, 2)],
]

def music(name, bpm, prog, melody, lively):
    step = 60.0 / bpm / 2
    bars = len(prog)
    total = bars * 8 * step
    buf = np.zeros(int(total * SR))
    for b, chord in enumerate(prog):
        tones = CH[chord]
        t0 = b * 8 * step
        root = tones[0] - 12
        for s_i, deg in ((0, 0), (3, 0), (4, 2), (7, 0)) if lively else ((0, 0), (4, 2)):
            add(buf, t0 + s_i * step, note(midi(root + (7 if deg == 2 else 0)), step * 1.8, "tri", 0.5, a=0.005, d=0.08, s=0.5, r=0.08))
        pat = [0, 1, 2, 1, 0, 1, 2, 1] if lively else [0, 2, 1, 2, 0, 2, 1, 2]
        for s_i, k in enumerate(pat):
            add(buf, t0 + s_i * step, note(midi(tones[k] + 12), step * 1.4, "sine", 0.16, a=0.004, d=0.06, s=0.4, r=0.05))
        if lively:
            for s_i in (1, 3, 5, 7):
                add(buf, t0 + s_i * step, (noise(0.03) - lowpass(noise(0.03), 5)) * 0.10)
            for s_i in (0, 4):
                add(buf, t0 + s_i * step, sweep(130, 48, 0.16, "sine", 0.55, a=0.002, d=0.05, s=0.3, r=0.08))
        else:
            add(buf, t0, note(midi(tones[0]), step * 7.5, "sine", 0.10, a=0.2, d=0.2, s=0.7, r=0.5))
        if melody:
            for s_i, n_, ln in melody[b]:
                add(buf, t0 + s_i * step, note(midi(n_), step * ln * 0.95, "tri", 0.30, a=0.005, d=0.12, s=0.35, r=0.08))
        else:
            pent = [72, 74, 76, 79, 81, 84]
            for s_i in (2, 5, 6):
                if arng.random() < 0.75:
                    add(buf, t0 + s_i * step, note(midi(int(arng.choice(pent))), step * 2.2, "sine", 0.17, a=0.004, d=0.2, s=0.2, r=0.2))
    save_wav(name, buf, 0.6)

# La música de las partidas es una pista real (assets/audio/music_jazz.ogg, ver docs/licenses.md): ya no se sintetiza.
music("music_menu", 88, ["C", "F", "Am", "G", "C", "F", "G", "C"], None, False)
# la música del menú se guarda en OGG Vorbis (85 KB en vez de 962 KB en WAV) si hay ffmpeg
if shutil.which("ffmpeg"):
    _wav = os.path.join(AUD, "music_menu.wav")
    subprocess.run(["ffmpeg", "-hide_banner", "-v", "error", "-y", "-i", _wav, "-ar", "32000", "-c:a", "libvorbis", "-q:a", "2",
                    os.path.join(AUD, "music_menu.ogg")], check=True)
    os.remove(_wav)
else:
    print("AVISO: sin ffmpeg no se puede crear music_menu.ogg; AudioManager espera ese archivo")

# ---------------------------------------------------------------- iconos de la app
def draw_burger(size, bg=None, scale=1.0):
    S = size * 4
    img = Image.new("RGBA", (S, S), bg if bg else (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    u = S / 100.0 * scale
    cx = S / 2.0
    top = S / 2.0 - 40 * u
    def X(v): return cx + v * u
    def Y(v): return top + v * u
    d.rounded_rectangle([X(-30), Y(62), X(30), Y(76)], radius=7 * u, fill="#d9964f", outline="#8a5a2a", width=int(1.6 * u))
    d.rounded_rectangle([X(-33), Y(50), X(33), Y(64)], radius=7 * u, fill="#5b3524", outline="#2d1a12", width=int(1.6 * u))
    d.polygon([(X(-34), Y(46)), (X(34), Y(46)), (X(27), Y(58)), (X(15), Y(49)), (X(0), Y(60)), (X(-15), Y(49)), (X(-27), Y(58))], fill="#f2b134", outline="#a87a10")
    pts = [(X(-36 + i * 72 / 40.0), Y(40 + 4 * math.sin(i * 0.9))) for i in range(41)]
    d.polygon(pts + [(X(36), Y(50)), (X(-36), Y(50))], fill="#6fb43f", outline="#3f7a1f")
    d.pieslice([X(-34), Y(0), X(34), Y(70)], 180, 360, fill="#e0a15a", outline="#8a5a2a", width=int(1.8 * u))
    for sx, sy in ((-14, 14), (2, 8), (16, 16), (-3, 22), (-22, 26), (24, 28)):
        d.ellipse([X(sx - 2.4), Y(sy - 1.4), X(sx + 2.4), Y(sy + 1.4)], fill="#fff1d6")
    return img.resize((size, size), Image.LANCZOS)

def rounded_bg(size, color, radius_ratio=0.22):
    S = size * 4
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(img).rounded_rectangle([0, 0, S - 1, S - 1], radius=int(S * radius_ratio), fill=color)
    return img.resize((size, size), Image.LANCZOS)

# Los iconos de la app (launcher_192, adaptive_*_432, icon.png) ya no se dibujan aquí: salen de la imagen del usuario con
# tools/gen_app_icon.py, así que este script no los sobrescribe.
print("assets OK:", len(os.listdir(ICONS)), "iconos,", len(os.listdir(TEX)), "texturas,", len(os.listdir(AUD)), "audios")
