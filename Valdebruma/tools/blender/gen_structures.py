"""gen_structures.py — piezas del sistema de construcción de refugios.

Ejecutar: blender -b --python tools/blender/gen_structures.py
Cada estructura tiene dos mallas con el mismo lenguaje visual (madera basta, cuerda, lona):
  structures/<id>_frame.glb  etapa de replanteo/armazón
  structures/<id>.glb        etapa terminada
data/models/structures.json guarda las cajas envolventes y de colisión.
"""
import sys, os, math, random, json
sys.path.insert(0, os.path.dirname(__file__))
import bpy
from mathutils import Vector
import vb
import gen_props as gp
from gen_props import P, fin

OUT = {}


def reg(name, obs, **meta):
    gp.REG.clear()
    gp.reg(name, obs, sub="structures", **meta)
    OUT[name] = gp.REG[name]


def post(p, x, y, h, r=0.055, mat="bark_oak", lean=(0, 0)):
    p.tube([(x, y, -0.25), (x + lean[0], y + lean[1], h)], [r, r * 0.85], mat, seg=6)


def lash(p, c, r=0.07):
    p.lathe([(r, -0.03), (r + 0.008, 0.0), (r, 0.03)], "rope", seg=7, c=c, close=False)


def stakes(p, w, d):
    """Replanteo: cuatro estacas con cordel (etapa inicial común)."""
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.tube([(sx * w / 2, sy * d / 2, -0.15), (sx * w / 2, sy * d / 2, 0.35)], [0.022, 0.016], "item_wood", seg=5)
    for sx in (-1, 1):
        p.tube([(sx * w / 2, -d / 2, 0.3), (sx * w / 2, d / 2, 0.3)], 0.005, "rope", seg=3)
    for sy in (-1, 1):
        p.tube([(-w / 2, sy * d / 2, 0.3), (w / 2, sy * d / 2, 0.3)], 0.005, "rope", seg=3)


def wall_panel(p, kind, frame):
    W, H = 2.4, 2.4
    for sx in (-1, 1):
        post(p, sx * (W / 2 - 0.06), 0, H, 0.06)
    p.tube([(-W / 2, 0, H - 0.05), (W / 2, 0, H - 0.05)], 0.05, "bark_oak", seg=6)
    p.tube([(-W / 2, 0, 0.08), (W / 2, 0, 0.08)], 0.05, "bark_oak", seg=6)
    for sx in (-1, 1):
        lash(p, (sx * (W / 2 - 0.06), 0, H - 0.05))
    if frame:
        p.tube([(-W / 2 + 0.06, 0, 0.1), (W / 2 - 0.06, 0, H - 0.1)], 0.035, "bark_oak", seg=5)
        return
    rnd = random.Random(sum(map(ord, kind)))
    n = 11
    for i in range(n):
        x = -W / 2 + 0.14 + (W - 0.28) * i / (n - 1)
        if kind == "puerta" and abs(x) < 0.52:
            continue
        z0, z1 = 0.1, H - 0.1
        if kind == "muro_ventana" and abs(x) < 0.45:
            p.box((x, 0, 0.5), (0.2, 0.035, 0.8 + rnd.uniform(-0.02, 0.02)), "wood_raw", rot=(0, 0, rnd.uniform(-1.5, 1.5)))
            p.box((x, 0, 2.05), (0.2, 0.035, 0.5), "wood_raw")
            continue
        p.box((x, rnd.uniform(-0.006, 0.006), (z0 + z1) / 2), (0.2, 0.035, z1 - z0 + rnd.uniform(-0.04, 0.02)), "wood_raw", rot=(0, rnd.uniform(-0.6, 0.6), 0))
    if kind == "muro_ventana":
        for z in (0.92, 1.78):
            p.box((0, 0, z), (1.0, 0.07, 0.06), "wood_dark")
    if kind == "puerta":
        for sx in (-1, 1):
            p.box((sx * 0.5, 0, 1.05), (0.08, 0.1, 2.1), "wood_dark")
        p.box((0, 0, 2.12), (1.08, 0.1, 0.08), "wood_dark")
        for i in range(2):
            x = -0.84 + i * 0.2 if i < 1 else 0.84
    else:
        p.box((0, -0.03, 1.2), (math.hypot(W - 0.3, 1.6), 0.03, 0.09), "wood_grey", rot=(0, -math.degrees(math.atan2(1.6, W - 0.3)), 0))


def run():
    vb.reset()
    rnd = random.Random(77)
    # --- hoguera -------------------------------------------------------------------------------
    for frame in (True, False):
        p = P()
        for i in range(10):
            a = i * S2 / 10
            p.sphere((math.cos(a) * 0.48, math.sin(a) * 0.48, 0.06), 0.13, "rock_boulder", seg=6, rings=4, scale=(1.0, rnd.uniform(0.75, 1.1), 0.7), rot=(0, 0, rnd.uniform(0, 180)))
        if not frame:
            for i in range(5):
                a = i * S2 / 5 + 0.3
                p.tube([(math.cos(a) * 0.3, math.sin(a) * 0.3, 0.03), (math.cos(a) * 0.03, math.sin(a) * 0.03, 0.46)], [0.045, 0.03], "bark_oak", seg=6)
            p.cyl((0, 0, 0.015), 0.38, 0.03, "charcoal", seg=10)
            for i in range(6):
                a = rnd.uniform(0, 6.28)
                p.sphere((math.cos(a) * 0.14, math.sin(a) * 0.14, 0.05), 0.035, "fire_ember", seg=5, rings=4)
        reg("hoguera" + ("_frame" if frame else ""), fin(p, "hoguera" + ("_frame" if frame else ""), bevel=0.0, smooth=60), solid=False)
    # --- refugio (cobertizo de lona) ----------------------------------------------------------------
    for frame in (True, False):
        p = P()
        W, D, Hh = 2.2, 2.4, 1.5
        for sx in (-1, 1):
            post(p, sx * W / 2, -D / 2, Hh, 0.05)
            p.tube([(sx * W / 2, -D / 2, Hh), (sx * W / 2, D / 2, 0.05)], 0.045, "bark_oak", seg=6)
            lash(p, (sx * W / 2, -D / 2, Hh - 0.03), 0.06)
        p.tube([(-W / 2 - 0.15, -D / 2, Hh), (W / 2 + 0.15, -D / 2, Hh)], 0.045, "bark_oak", seg=6)
        if not frame:
            p.quad_n([(-W / 2 - 0.1, -D / 2 - 0.1, Hh + 0.04), (W / 2 + 0.1, -D / 2 - 0.1, Hh + 0.04), (W / 2 + 0.1, D / 2 + 0.1, 0.06), (-W / 2 - 0.1, D / 2 + 0.1, 0.06)], "tarp_green", (0, 0.6, 1))
            for k in range(4):
                y = -D / 2 + (k + 0.5) * D / 4
                zz = Hh * (1 - (k + 0.5) / 4)
                p.tube([(-W / 2, y, zz + 0.02), (W / 2, y, zz + 0.02)], 0.022, "bark_oak", seg=5)
            for sx in (-1, 1):
                p.tri((sx * W / 2, -D / 2, Hh), (sx * W / 2, D / 2, 0.05), (sx * W / 2, -D / 2 + 0.9, 0.05), "tarp_green")
            p.box((0, 0.1, 0.05), (0.75, 1.9, 0.08), "fabric_pattern")
            p.cyl((0, 0.95, 0.12), 0.1, 0.6, "cloth_white", seg=8, rot=(0, 90, 0))
        else:
            stakes(p, W, D)
        reg("refugio" + ("_frame" if frame else ""), fin(p, "refugio" + ("_frame" if frame else ""), bevel=0.0, ao_dist=0.5), collider=[2.2, 0.3, 0.2], collider_off=[0, 0, 1.15], rest=True)
    # --- saco de dormir desplegado --------------------------------------------------------------------
    p = P()
    p.box((0, 0, 0.05), (0.72, 1.9, 0.09), "fabric_pattern")
    p.box((0, 0.1, 0.1), (0.7, 1.4, 0.04), "fabric_denim")
    p.box((0, -0.78, 0.12), (0.5, 0.3, 0.08), "cloth_white")
    reg("saco_dormir", fin(p, "saco_dormir", bevel=0.02), solid=False, rest=True)
    # --- arcón de almacenamiento ----------------------------------------------------------------------
    for frame in (True, False):
        p = P()
        if frame:
            stakes(p, 1.0, 0.6)
            p.box((0, 0, 0.03), (0.96, 0.56, 0.04), "wood_raw")
            body = fin(p, "arcon_frame", bevel=0.0)
            reg("arcon_frame", body, solid=False)
        else:
            p.box((0, 0, 0.28), (1.0, 0.6, 0.5), "wood_raw", mats={"+z": None})
            p.box((0, 0, 0.05), (0.96, 0.56, 0.03), "wood_raw")
            for sx in (-1, 1):
                for sy in (-1, 1):
                    p.box((sx * 0.47, sy * 0.27, 0.28), (0.08, 0.08, 0.54), "wood_dark")
                p.tube([(sx * 0.52, -0.1, 0.4), (sx * 0.56, 0, 0.36), (sx * 0.52, 0.1, 0.4)], 0.012, "rope", seg=4)
            body = fin(p, "arcon", bevel=0.004)
            p = P()
            for k in range(5):
                p.box((-0.4 + k * 0.2, -0.31, 0.015), (0.19, 0.64, 0.03), "wood_raw")
            for sx in (-1, 1):
                p.box((sx * 0.38, -0.31, 0.04), (0.07, 0.64, 0.025), "wood_dark")
            lid = fin(p, "arcon_lid", bevel=0.003, ground=None)
            lid.location = (0, 0.31, 0.53)
            reg("arcon", [body, lid], container={"slots": 20, "lid": {"type": "lid", "angle": 70}})
    # --- banco de trabajo de campo --------------------------------------------------------------------
    for frame in (True, False):
        p = P()
        for sx in (-1, 1):
            for sy in (-1, 1):
                post(p, sx * 0.75, sy * 0.3, 0.86, 0.045)
        for sy in (-1, 1):
            p.tube([(-0.8, sy * 0.3, 0.3), (0.8, sy * 0.3, 0.3)], 0.03, "bark_oak", seg=5)
        if frame:
            stakes(p, 1.8, 0.9)
        else:
            for k in range(4):
                p.box((0, -0.3 + k * 0.2, 0.89), (1.8, 0.19, 0.045), "wood_raw", rot=(0, 0, rnd.uniform(-0.6, 0.6)))
            p.box((0, 0, 0.32), (1.5, 0.5, 0.03), "wood_raw")
            p.box((-0.55, 0.05, 0.96), (0.3, 0.2, 0.1), "item_wood")
            p.tube([(0.2, -0.1, 0.93), (0.6, 0.1, 0.93)], 0.014, "item_wood", seg=5)
            p.box((0.2, -0.1, 0.94), (0.03, 0.1, 0.03), "item_metal", rot=(0, 0, 26))
            p.box((0.5, 0.1, 0.4), (0.4, 0.22, 0.14), "wood_grey")
        reg("banco" + ("_frame" if frame else ""), fin(p, "banco" + ("_frame" if frame else ""), bevel=0.0, ao_dist=0.4), station="workbench", collider=[1.8, 0.9, 0.8])
    # --- paneles modulares: muro, muro con ventana, marco de puerta, suelo, tejado -------------------------
    for kind in ("muro", "muro_ventana", "puerta"):
        for frame in (True, False):
            p = P()
            wall_panel(p, kind, frame)
            nm = kind + ("_frame" if frame else "")
            cols = [[0, 1.2, 0, 2.4, 2.4, 0.14]] if kind != "puerta" else [[-0.86, 1.2, 0, 0.68, 2.4, 0.14], [0.86, 1.2, 0, 0.68, 2.4, 0.14], [0, 2.28, 0, 1.08, 0.24, 0.14]]
            reg(nm, fin(p, nm, bevel=0.0, ao_dist=0.4), colliders=cols if not frame else [], solid=not frame)
    p = P()                                    # hoja de puerta del kit
    for k in range(5):
        p.box((0.1 + k * 0.19, 0, 1.02), (0.185, 0.03, 2.02), "wood_raw")
    for z in (0.4, 1.6):
        for sy in (-1, 1):
            p.box((0.48, sy * 0.022, z), (0.95, 0.02, 0.1), "wood_dark")
    p.tube([(0.86, -0.05, 1.0), (0.86, -0.09, 1.05), (0.86, -0.05, 1.1)], 0.01, "rope", seg=4)
    reg("puerta_hoja", fin(p, "puerta_hoja", bevel=0.0, ground=None), door={"w": 0.96, "h": 2.03})
    for frame in (True, False):
        p = P()
        for sx in (-1, 1):
            p.tube([(sx * 1.14, -1.2, 0.12), (sx * 1.14, 1.2, 0.12)], 0.06, "bark_oak", seg=6)
        for sy in (-1, 0, 1):
            p.tube([(-1.2, sy * 1.1, 0.14), (1.2, sy * 1.1, 0.14)], 0.05, "bark_oak", seg=6)
        if not frame:
            for k in range(12):
                p.box((0, -1.1 + k * 0.2, 0.215), (2.4, 0.19, 0.035), "wood_raw", rot=(0, 0, rnd.uniform(-0.5, 0.5)))
        else:
            stakes(p, 2.4, 2.4)
        nm = "suelo" + ("_frame" if frame else "")
        reg(nm, fin(p, nm, bevel=0.0, ao_dist=0.3), colliders=[[0, 0.115, 0, 2.4, 0.23, 2.4]] if not frame else [], solid=not frame)
    for frame in (True, False):
        p = P()
        pitch = 26
        p.push((0, 0, 2.45), (pitch, 0, 0))
        for sx in (-1, 0, 1):
            p.tube([(sx * 1.14, -1.4, 0), (sx * 1.14, 1.4, 0)], 0.045, "bark_oak", seg=6)
        if not frame:
            for k in range(7):
                p.box((0, -1.25 + k * 0.42, 0.06 + 0.0), (2.55, 0.46, 0.03), "thatch", rot=(-6, 0, 0))
        p.pop()
        nm = "tejado" + ("_frame" if frame else "")
        reg(nm, fin(p, nm, bevel=0.0, ao_dist=0.4, ground=None), solid=False)
    # --- colector de lluvia ----------------------------------------------------------------------------
    for frame in (True, False):
        p = P()
        for sx in (-1, 1):
            for sy in (-1, 1):
                post(p, sx * 0.8, sy * 0.8, 1.5 if sy > 0 else 1.2, 0.04)
        if frame:
            stakes(p, 1.8, 1.8)
        else:
            c = (0, 0.1, 0.95)
            for (a, b) in (((-0.8, -0.8, 1.2), (0.8, -0.8, 1.2)), ((0.8, -0.8, 1.2), (0.8, 0.8, 1.5)), ((0.8, 0.8, 1.5), (-0.8, 0.8, 1.5)), ((-0.8, 0.8, 1.5), (-0.8, -0.8, 1.2))):
                p.tri(a, b, c, "tarp_green")
                p.tri(b, a, (c[0], c[1], c[2] - 0.01), "tarp_green")
            p.lathe([(0.28, 0), (0.29, 0.02), (0.3, 0.4), (0.29, 0.78), (0.27, 0.8)], "metal_blue", seg=12, c=(0, 0.1, 0.0))
            p.cyl((0, 0.1, 0.72), 0.27, 0.02, "water_still", seg=12)
        nm = "colector" + ("_frame" if frame else "")
        reg(nm, fin(p, nm, bevel=0.0, smooth=50, ao_dist=0.4), station="water", collider=[0.7, 0.9, 0.7])
    # --- poste con farol ---------------------------------------------------------------------------------
    for frame in (True, False):
        p = P()
        post(p, 0, 0, 2.2, 0.05)
        if not frame:
            p.tube([(0, 0, 2.1), (0.4, 0, 2.2)], 0.03, "bark_oak", seg=5)
            lash(p, (0, 0, 2.08), 0.06)
            p.tube([(0.36, 0, 2.18), (0.36, 0, 2.0)], 0.004, "rope", seg=3)
            p.lathe([(0.0, 0), (0.05, 0), (0.055, 0.03), (0.035, 0.045)], "item_metal", seg=8, c=(0.36, 0, 1.8))
            p.lathe([(0.033, 0.045), (0.045, 0.09), (0.033, 0.14)], "item_glass", seg=8, c=(0.36, 0, 1.8), close=False)
            p.sphere((0.36, 0, 1.885), 0.02, "lamp_glass", seg=6, rings=5)
            p.lathe([(0.035, 0.14), (0.045, 0.15), (0.02, 0.175), (0.0, 0.18)], "item_metal", seg=8, c=(0.36, 0, 1.8), close=False)
        nm = "poste_farol" + ("_frame" if frame else "")
        reg(nm, fin(p, nm, bevel=0.0, smooth=55, ao_dist=0.2), collider=[0.14, 2.2, 0.14], light=[0.36, 1.9, 0.0])
    # --- valla --------------------------------------------------------------------------------------------
    for frame in (True, False):
        p = P()
        for sx in (-1, 1):
            post(p, sx * 1.15, 0, 1.15, 0.05)
        if not frame:
            for z in (0.35, 0.7, 1.0):
                p.tube([(-1.2, 0.03, z), (1.2, 0.03, z + rnd.uniform(-0.03, 0.03))], 0.032, "bark_oak", seg=5)
            for sx in (-1, 1):
                lash(p, (sx * 1.15, 0, 1.0), 0.06)
        nm = "valla" + ("_frame" if frame else "")
        reg(nm, fin(p, nm, bevel=0.0, ao_dist=0.3), collider=[2.4, 1.1, 0.14], solid=not frame)
    vb.write_json("models/structures.json", OUT)
    print("STRUCTURES", len(OUT), " ".join(sorted(OUT)))


S2 = 2 * math.pi
if __name__ == "__main__":
    run()
