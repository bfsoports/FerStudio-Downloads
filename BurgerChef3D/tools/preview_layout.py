#!/usr/bin/env python3
"""Vista previa del restaurante SIN abrir Godot: reproduce las colocaciones de scripts/restaurant/restaurant.gd con los
modelos reales (assets/models/) y los renderiza con un rasterizador de software (numpy + Pillow).

Es una comprobación de la geometría (orientaciones, alturas, huecos, solapes), NO sustituye a ejecutar el juego en Godot:
las fórmulas están duplicadas aquí a mano, así que si cambias restaurant.gd hay que actualizar este script.

Uso:  python3 tools/preview_layout.py [carpeta_de_salida]      (por defecto docs/preview/)
Genera: kitchen_player.png (vista del jugador), kitchen_top.png (cenital), kitchen_west.png, kitchen_east.png,
kitchen_fryer.png (freidoras, dispensador y bote de basura) y hall_counter.png (mostrador, bandejas, campanitas y
lámparas vistos desde la sala).
"""
import json
import math
import os
import re
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import gen_models as gm  # noqa: E402  (reutiliza el lector de glTF)

MODELS_DIR = os.path.join(ROOT, "assets", "models")
SURF, STOVE_TOP, MOD_W, MOD_D, BIN_SURF = 1.06, 1.17, 2.0, 2.0, 0.75
FRYER_BASKET_H, FRYER_BASKET_Z = 0.8, -0.063
LAMP_SPOTS = [(-3.2, 0.9), (0, 0.9), (3.2, 0.9), (-3.5, 4.5), (-0.6, 4.5), (2.4, 4.5), (-4, -4), (0, -4.5), (4, -3)]
PLANT_SPOTS = [(-8.2, -8.2), (5.2, -8.3), (-8.2, -0.3), (8.3, -0.5)]
CT = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
NC = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


def load_table():
    txt = open(os.path.join(ROOT, "scripts", "core", "model_table.gd"), encoding="utf8").read()
    table = {}
    for m in re.finditer(r'"(\w+)": \["([^"]+)", ([^\]]+)\]', txt):
        nums = [float(v) for v in m.group(3).split(",")]
        table[m.group(1)] = {"file": m.group(2), "s": nums[0], "off": nums[1:4], "size": nums[4:7]}
    return table


TABLE = load_table()
_cache = {}


def read_accessor(js, bufs, idx):
    a = js["accessors"][idx]
    bv = js["bufferViews"][a["bufferView"]]
    dt = CT[a["componentType"]]
    n = NC[a["type"]]
    isz = np.dtype(dt).itemsize * n
    start = bv.get("byteOffset", 0)
    stride = bv.get("byteStride", 0)
    buf = bufs[bv["buffer"]]
    if stride and stride != isz:
        arr = np.frombuffer(buf, dtype=np.uint8, count=a["count"] * stride, offset=start)
        off = a.get("byteOffset", 0)
        arr = arr.reshape(a["count"], stride)[:, off:off + isz].copy().view(dt).reshape(a["count"], n)
    else:
        arr = np.frombuffer(buf, dtype=dt, count=a["count"] * n, offset=start + a.get("byteOffset", 0)).reshape(a["count"], n)
    return arr


def model_tris(key):
    """Triángulos del modelo en sus unidades originales: (N,3,3) vértices y (N,3) color por triángulo."""
    if key in _cache:
        return _cache[key]
    path = os.path.join(MODELS_DIR, TABLE[key]["file"])
    js = gm.load_gltf(path)
    if path.endswith(".glb"):
        import struct
        data = open(path, "rb").read()
        length = struct.unpack("<I", data[8:12])[0]
        off = 12
        bufs = []
        while off < length:
            clen, ctype = struct.unpack("<II", data[off:off + 8])
            if ctype == 0x004E4942:
                bufs.append(data[off + 8:off + 8 + clen])
            off += 8 + clen
    else:
        bufs = [open(os.path.join(os.path.dirname(path), b["uri"]), "rb").read() for b in js["buffers"]]
    tex = None
    if js.get("images"):
        im = js["images"][0]
        if "uri" in im:
            tex = np.array(Image.open(os.path.join(os.path.dirname(path), im["uri"])).convert("RGB"))
        else:   # textura incrustada en el GLB (modelos propios de assets/models/custom/)
            import io
            bv = js["bufferViews"][im["bufferView"]]
            raw = bufs[bv["buffer"]][bv.get("byteOffset", 0):bv.get("byteOffset", 0) + bv["byteLength"]]
            tex = np.array(Image.open(io.BytesIO(raw)).convert("RGB"))
    verts, cols = [], []

    def walk(i, parent):
        n = js["nodes"][i]
        m = np.array(gm.mat_mul(parent, gm.node_matrix(n)))
        if "mesh" in n:
            for prim in js["meshes"][n["mesh"]]["primitives"]:
                pos = read_accessor(js, bufs, prim["attributes"]["POSITION"]).astype(np.float64)
                uv = read_accessor(js, bufs, prim["attributes"]["TEXCOORD_0"]).astype(np.float64)
                idx = read_accessor(js, bufs, prim["indices"]).reshape(-1).astype(np.int64)
                ph = (np.c_[pos, np.ones(len(pos))] @ m.T)[:, :3]
                for t in range(0, len(idx) - 2, 3):
                    tri = idx[t:t + 3]
                    verts.append(ph[tri])
                    c = uv[tri].mean(axis=0)
                    h, w, _ = tex.shape
                    cols.append(tex[min(h - 1, int((c[1] % 1.0) * h)), min(w - 1, int((c[0] % 1.0) * w))])
        for c in n.get("children", []):
            walk(c, m)

    ident = [[1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]]
    for r in js["scenes"][js.get("scene", 0)]["nodes"]:
        walk(r, ident)
    _cache[key] = (np.array(verts), np.array(cols, dtype=np.float64))
    return _cache[key]


# ---------------------------------------------------------------- transformaciones (igual que los nodos de Godot)
def T(x, y, z):
    m = np.eye(4)
    m[:3, 3] = [x, y, z]
    return m


def RY(a):
    c, s = math.cos(a), math.sin(a)
    m = np.eye(4)
    m[0, 0], m[0, 2], m[2, 0], m[2, 2] = c, s, -s, c
    return m


def S(x, y, z):
    return np.diag([x, y, z, 1.0])


class Scene:
    def __init__(self):
        self.tris = []   # (verts_world (N,3,3), colors (N,3))

    def model(self, parent, key, pos=(0, 0, 0), rot=0.0, stretch=(1, 1, 1), tint=None):
        e = TABLE[key]
        s = e["s"]
        m = parent @ T(*pos) @ RY(rot) @ S(s * stretch[0], s * stretch[1], s * stretch[2]) @ T(*e["off"])
        v, c = model_tris(key)
        vw = (np.c_[v.reshape(-1, 3), np.ones(len(v) * 3)] @ m.T)[:, :3].reshape(-1, 3, 3)
        self.tris.append((vw, c if tint is None else c * np.array(tint)))

    def box(self, parent, size, pos, color):
        sx, sy, sz = [v / 2 for v in size]
        corners = np.array([[x, y, z] for x in (-sx, sx) for y in (-sy, sy) for z in (-sz, sz)])
        faces = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
        tv = []
        for f in faces:
            tv.append(corners[[f[0], f[1], f[2]]])
            tv.append(corners[[f[0], f[2], f[3]]])
        tv = np.array(tv)
        m = parent @ T(*pos)
        vw = (np.c_[tv.reshape(-1, 3), np.ones(len(tv) * 3)] @ m.T)[:, :3].reshape(-1, 3, 3)
        self.tris.append((vw, np.tile(np.array(color, dtype=np.float64), (len(vw), 1))))


def size_of(key):
    return TABLE[key]["size"]


def rnd(x):
    return int(math.floor(x + 0.5))


def counter_run(sc, parent, center, w, d, rot, tint=None, height=SURF):
    n = max(1, rnd(w / MOD_W))
    mw = w / n
    run = parent @ T(center[0], 0, center[1]) @ RY(rot)
    for i in range(n):
        sc.model(run, "counter_a" if i % 2 == 0 else "counter_b", pos=(-w / 2 + mw * (i + 0.5), 0, 0), stretch=(mw / MOD_W, height, d / MOD_D), tint=tint)


def food_item(sc, parent, ident, scale=1.0, pos=(0, 0, 0)):
    keys = {"patty": "patty_raw", "veggie_patty": "veggie_raw", "bacon": "bacon_raw", "cheese": "cheese", "drink": "drink",
            "bun_bottom": "bun_bottom", "bun_top": "bun_top", "lettuce": "lettuce", "tomato": "tomato", "onion": "onion", "fries": "fries_raw"}
    m = parent @ T(*pos) @ S(scale, scale, scale)
    if ident == "bacon":
        sc.model(m, "bacon_raw", pos=(-0.085, 0, 0), rot=0.1)
        sc.model(m, "bacon_raw", pos=(0.085, 0, 0), rot=-0.08)
    else:
        sc.model(m, keys[ident])


def build_scene(layout):
    sc = Scene()
    I = np.eye(4)
    room = layout["room"]
    room_h = room["height"]
    # suelos y paredes (estructura procedural, solo como referencia visual)
    # el suelo se divide en losetas de 2 m para que el rasterizador no descarte triángulos que cruzan la cámara
    for ix in range(int((room["x_max"] - room["x_min"]) // 2)):
        for iz in range(int(math.ceil((room["z_max"] - room["z_min"]) / 2))):
            cx = room["x_min"] + 1 + ix * 2
            cz = room["z_min"] + 1 + iz * 2
            kitchen = cz > room["split_z"]
            shade = 8 if (ix + iz) % 2 else 0
            sc.box(I, (2.0, 0.2, 2.0), (cx, -0.1, cz), (190 - shade, 200 - shade, 205 - shade) if kitchen else (170 - shade, 100, 90))
    wall = (243, 227, 195)
    zlen, zmid = room["z_max"] - room["z_min"] + 0.6, (room["z_min"] + room["z_max"]) / 2
    sc.box(I, (0.3, room_h, zlen), (room["x_min"] - 0.15, room_h / 2, zmid), wall)
    sc.box(I, (0.3, room_h, zlen), (room["x_max"] + 0.15, room_h / 2, zmid), wall)
    sc.box(I, (room["x_max"] - room["x_min"] + 0.6, room_h, 0.3), (0, room_h / 2, room["z_max"] + 0.15), wall)
    for g in layout["gates"]:
        sc.box(I, (g["w"], room_h, g["d"]), (g["x"], room_h / 2, g["z"]), wall)
    # mostrador de servicio y bandejas
    scn = layout["service_counter"]
    counter_run(sc, I, (scn["x"], scn["z"]), scn["w"], scn["d"], math.pi)
    ts = size_of("tray")
    for p in layout["service_points"]:
        sc.model(T(p["x"], 0, scn["z"] - 0.05), "tray", pos=(0, SURF, 0), stretch=(1.5 / ts[0], 0.07 / ts[1], 0.7 / ts[2]))
        sc.model(T(p["x"] + 1.05, SURF, scn["z"] - 0.2), "bell")
    # fogones, isla y freidora
    sy = (room_h - 2.2) / size_of("hood")[1]

    def hood(m):
        sc.model(m, "hood", pos=(0, 2.2 - 2.0 * sy, -0.8), stretch=(1, sy, 1))

    g = layout["grill"]
    gm_ = T(g["x"], 0, g["z"])
    sc.model(gm_, "stove")
    hood(gm_)
    food_item(sc, gm_, "patty", 1.0, (-0.5, STOVE_TOP, 0.5))
    sc.model(gm_ @ T(0.5, STOVE_TOP, 0.5), "patty_done")
    for k in ("stage_a", "stage_b"):
        e = layout[k]
        counter_run(sc, T(e["x"], 0, e["z"]), (0, 0), e["w"], e["d"], 0.0)
    isl = layout["island"]
    counter_run(sc, I, (isl["x"], isl["z"]), isl["w"], isl["d"], 0.0)
    bs = size_of("board")
    for i, b in enumerate(layout["assembly"]):
        bm = T(b["x"], 0, b["z"])
        sc.model(bm, "board", pos=(0, SURF, 0), stretch=(1.0 / bs[0], 0.06 / bs[1], 0.72 / bs[2]))
        if i == 1:   # hamburguesa de muestra: pan, carne, queso, lechuga, tomate, pan
            y = SURF + 0.06
            for idx, key in enumerate(["bun_bottom", "patty_done", "cheese", "lettuce", "tomato", "bun_top"]):
                sc.model(bm @ T(0, y, 0) @ RY(idx * 0.9), key)
                y += size_of(key)[1]
    f = layout["fryer"]
    fm = T(f["x"], 0, f["z"])
    counter_run(sc, fm, (0, 0), f["w"], f["d"], 0.0)
    fs = size_of("fryer")
    for bx in (-f["w"] * 0.25, f["w"] * 0.25):
        sc.model(fm, "fryer", pos=(bx, SURF, 0))
    hood(fm)
    sc.model(fm @ T(-f["w"] * 0.25, SURF + fs[1] * FRYER_BASKET_H, FRYER_BASKET_Z * fs[2]), "fries_raw")
    # mostradores bajos de ingredientes (uno por pared), cajas, tablas con carnes y queso, y dispensador de bebidas
    def wall_of(x):
        return "west" if x < -7.0 else ("east" if x > 7.0 else "south")
    runs = {}
    for b in layout["bins"]:
        w_ = wall_of(b["x"])
        along, fixed = (b["x"], b["z"]) if w_ == "south" else (b["z"], b["x"])
        r = runs.setdefault(w_, [along, along, fixed])
        r[0], r[1] = min(r[0], along), max(r[1], along)
    for w_, (a0, a1, fixed) in runs.items():
        mid, length = (a0 + a1) / 2, a1 - a0 + 1.2
        center = (mid, fixed) if w_ == "south" else (fixed, mid)
        counter_run(sc, I, center, length, 1.0, {"south": math.pi, "west": math.pi / 2, "east": -math.pi / 2}[w_], height=BIN_SURF)
    crate_models = {"bun_bottom": "crate_buns", "bun_top": "crate_buns", "lettuce": "crate_lettuce", "tomato": "crate_tomatoes", "onion": "crate_onions", "fries": "crate_potatoes"}
    bsz = size_of("board")
    for b in layout["bins"]:
        ident, x, z = b["ingredient"], b["x"], b["z"]
        along_z = wall_of(x) != "south"
        face = (math.pi / 2 if x < 0 else -math.pi / 2) if along_z else 0.0
        cm = T(x, 0, z)
        if b["group"] == "dispenser":
            sc.model(cm, "dispenser", pos=(0, BIN_SURF, 0), rot=face)
            ds = size_of("dispenser")
            for side in (-1.0, 1.0):
                off = side * (ds[0] * 0.5 + 0.12)
                food_item(sc, cm, ident, 0.85, (0.0 if along_z else off, BIN_SURF, off if along_z else 0.0))
        elif b["group"] == "fridge":
            sc.model(cm, "board", pos=(0, BIN_SURF, 0), rot=face, stretch=(1.0 / bsz[0], 0.05 / bsz[1], 0.72 / bsz[2]))
            for k in range(2):
                off = (k - 0.5) * 0.46
                food_item(sc, cm, ident, 0.9, (0.0 if along_z else off, BIN_SURF + 0.05, off if along_z else 0.0))
        else:
            ckey = crate_models.get(ident, "crate_buns")
            sc.model(cm, ckey, pos=(0, BIN_SURF, 0))
            if ident in ("bun_bottom", "bun_top"):
                food_item(sc, cm, ident, 0.8, (0, BIN_SURF + size_of(ckey)[1] - 0.04, 0))
    # bote de basura y fregadero
    tr = layout["trash"]
    sc.model(T(tr["x"], 0, tr["z"]), "trash", rot=-math.pi / 2 if tr["x"] > 0 else math.pi / 2)
    sk = layout["sink"]
    sc.model(T(sk["x"], 0, sk["z"]), "sink", rot=-math.pi / 2, stretch=(1.1 / MOD_W, SURF, 1.0 / MOD_D))
    # mesas y sillas de la sala
    ts_ = size_of("table")
    for t in layout["tables"]:
        tm = T(t["x"], 0, t["z"])
        sc.model(tm, "table", stretch=(1.4 / ts_[0], 0.78 / ts_[1], 1.4 / ts_[2]))
        for i, (px, pz) in enumerate([(1.0, 0), (-1.0, 0), (0, 1.0), (0, -1.0)]):
            sc.model(tm, "chair_a" if i % 2 == 0 else "chair_b", pos=(px, 0, pz), rot=math.atan2(-px, -pz))
    # lámparas colgantes (florón en el techo) y plantas (decoración desbloqueable)
    lh = size_of("lamp")[1]
    for lx, lz in LAMP_SPOTS:
        sc.model(T(lx, room_h - lh, lz), "lamp")
    for k, (px, pz) in enumerate(PLANT_SPOTS):
        sc.model(T(px, 0, pz), "plant", rot=k * 1.7)
    return sc


def render(sc, out, cam_pos, cam_target, size=(960, 600), fov=70.0, ortho=None):
    W, H = size
    forward = np.array(cam_target, dtype=float) - np.array(cam_pos, dtype=float)
    forward /= np.linalg.norm(forward)
    up = np.array([0.0, 1.0, 0.0]) if abs(forward[1]) < 0.99 else np.array([0.0, 0.0, -1.0])
    right = np.cross(forward, up)
    right /= np.linalg.norm(right)
    up = np.cross(right, forward)
    f = (H / 2) / math.tan(math.radians(fov) / 2)
    img = np.full((H, W, 3), (150, 205, 235), dtype=np.float64)
    zb = np.zeros((H, W))
    light = np.array([0.35, 0.85, 0.4])
    light /= np.linalg.norm(light)
    cpos = np.array(cam_pos, dtype=float)
    for vw, cols in sc.tris:
        rel = vw - cpos
        x = rel @ right
        y = rel @ up
        z = rel @ forward
        n = np.cross(vw[:, 1] - vw[:, 0], vw[:, 2] - vw[:, 0])
        ln = np.linalg.norm(n, axis=1)
        ln[ln < 1e-12] = 1
        n = n / ln[:, None]
        shade = 0.5 + 0.5 * np.abs(n @ light)
        for t in range(len(vw)):
            zz = z[t]
            if zz.min() < 0.1:
                continue
            if ortho:
                sx = W / 2 + x[t] * ortho
                sy = H / 2 - y[t] * ortho
            else:
                sx = W / 2 + f * x[t] / zz
                sy = H / 2 - f * y[t] / zz
            minx, maxx = int(max(0, math.floor(sx.min()))), int(min(W - 1, math.ceil(sx.max())))
            miny, maxy = int(max(0, math.floor(sy.min()))), int(min(H - 1, math.ceil(sy.max())))
            if minx > maxx or miny > maxy:
                continue
            den = (sy[1] - sy[2]) * (sx[0] - sx[2]) + (sx[2] - sx[1]) * (sy[0] - sy[2])
            if abs(den) < 1e-9:
                continue
            xs, ys = np.meshgrid(np.arange(minx, maxx + 1) + 0.5, np.arange(miny, maxy + 1) + 0.5)
            w0 = ((sy[1] - sy[2]) * (xs - sx[2]) + (sx[2] - sx[1]) * (ys - sy[2])) / den
            w1 = ((sy[2] - sy[0]) * (xs - sx[2]) + (sx[0] - sx[2]) * (ys - sy[2])) / den
            w2 = 1 - w0 - w1
            m = (w0 >= -0.001) & (w1 >= -0.001) & (w2 >= -0.001)
            if not m.any():
                continue
            inv = w0 / zz[0] + w1 / zz[1] + w2 / zz[2]
            sub = zb[miny:maxy + 1, minx:maxx + 1]
            upd = m & (inv > sub)
            sub[upd] = inv[upd]
            img[miny:maxy + 1, minx:maxx + 1][upd] = cols[t] * shade[t]
    Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).save(out)


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "docs", "preview")
    os.makedirs(out, exist_ok=True)
    layout = json.load(open(os.path.join(ROOT, "resources", "data", "layout.json"), encoding="utf8"))
    sc = build_scene(layout)
    print("triángulos:", sum(len(v) for v, _ in sc.tris))
    sp = layout["player_spawn"]
    render(sc, os.path.join(out, "kitchen_player.png"), (sp["x"], 1.6, sp["z"]), (sp["x"] - 1.0, 1.1, sp["z"] - 6.0), fov=75)
    render(sc, os.path.join(out, "kitchen_top.png"), (0, 22, 4.8), (0, 0, 4.7), size=(960, 600), ortho=48)
    render(sc, os.path.join(out, "kitchen_west.png"), (3.0, 1.7, 7.0), (-7.5, 1.0, 4.4), fov=80)
    render(sc, os.path.join(out, "kitchen_east.png"), (-2.0, 1.7, 6.8), (8.0, 1.0, 4.2), fov=80)
    f = layout["fryer"]
    render(sc, os.path.join(out, "kitchen_fryer.png"), (f["x"] + 0.4, 1.75, f["z"] + 2.3), (f["x"] + 1.6, 1.15, f["z"] - 0.2), fov=70)
    render(sc, os.path.join(out, "hall_counter.png"), (-1.0, 1.6, -3.2), (0.5, 1.4, 1.0), fov=80)
    print("vistas en", os.path.relpath(out, ROOT))


if __name__ == "__main__":
    main()
