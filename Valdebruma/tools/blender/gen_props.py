"""gen_props.py — mobiliario, contenedores, puertas y objetos de mundo de Valdebruma.

Ejecutar: blender -b --python tools/blender/gen_props.py [-- nombre ...]
Salidas: assets/models/props/<nombre>.glb y data/models/props.json con, por modelo:
  size/center (caja envolvente en coords Godot), solid, y para contenedores:
  container = {slots, lid: {type: door|lid|drawer, angle|slide}}.
Los contenedores exportan dos objetos: cuerpo y '<nombre>_lid' con origen en la bisagra.
Las puertas tienen el origen en la bisagra inferior y se extienden hacia +X.
"""
import sys, os, math, random, json
sys.path.insert(0, os.path.dirname(__file__))
import bpy
from mathutils import Vector
import vb

REG = {}
ONLY = [a for a in sys.argv[sys.argv.index("--") + 1:]] if "--" in sys.argv else []
GEN = []
SIGNS = {}
_sp = os.path.join(vb.DATA, "signs_atlas.json")
if os.path.exists(_sp):
    SIGNS = json.load(open(_sp))


def prop(fn):
    GEN.append(fn)
    return fn


def P():
    return vb.Parts()


def fin(p, name, bevel=0.006, ao_dist=0.35, smooth=42, ao_samples=12, **kw):
    return p.build(name, bevel=bevel, ao_dist=ao_dist, ao_strength=0.7, ao_samples=ao_samples, smooth=smooth, **kw)


def bounds(obs):
    lo, hi = Vector((1e9,) * 3), Vector((-1e9,) * 3)
    for ob in obs:
        for v in ob.data.vertices:
            w = ob.matrix_world @ v.co if ob.location.length == 0 else ob.location + v.co
            for i in range(3):
                lo[i] = min(lo[i], w[i]); hi[i] = max(hi[i], w[i])
    return lo, hi


def reg(name, obs, solid=True, sub="props", **meta):
    if not isinstance(obs, (list, tuple)):
        obs = [obs]
    lo, hi = bounds(obs)
    c = (lo + hi) / 2
    s = hi - lo
    REG[name] = {"size": [round(s.x, 3), round(s.z, 3), round(s.y, 3)], "center": vb.g3(c), "solid": solid,
                 "tris": sum(vb.tris(o) for o in obs), **meta}
    vb.export(list(obs), sub + "/" + name)
    vb.clear_objects()


def sign_quad(p, sid, w, h, c=(0, 0, 0), rot=(0, 0, 0)):
    uv = SIGNS.get(sid, [0, 0, 1, 1])
    p.push(c, rot)
    p.quad((-w / 2, 0, -h / 2), (w / 2, 0, -h / 2), (w / 2, 0, h / 2), (-w / 2, 0, h / 2), "signs",
           uvs=[(uv[0], uv[1]), (uv[2], uv[1]), (uv[2], uv[3]), (uv[0], uv[3])])
    p.pop()


def legs(p, w, d, h, t, mat, z0=0.0):
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.box((sx * (w / 2 - t / 2), sy * (d / 2 - t / 2), z0 + h / 2), (t, t, h), mat)


# =============================== MOBILIARIO ===========================================
@prop
def bed():
    p = P()
    legs(p, 0.95, 2.0, 0.3, 0.07, "wood_dark")
    p.box((0, 0, 0.26), (0.95, 2.0, 0.1), "wood_dark")
    p.box((0, 0.98, 0.55), (0.95, 0.05, 0.7), "wood_dark")
    p.box((0, -0.98, 0.36), (0.95, 0.05, 0.3), "wood_dark")
    p.box((0, 0, 0.4), (0.9, 1.9, 0.18), "cloth_white")
    p.box((0, -0.28, 0.5), (0.93, 1.3, 0.05), "fabric_pattern", rot=(0, 0, 2))
    p.box((0, 0.7, 0.53), (0.6, 0.36, 0.1), "cloth_white", rot=(0, 0, -6))
    reg("bed", fin(p, "bed", bevel=0.012))


@prop
def bunk_bed():
    p = P()
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.box((sx * 0.45, sy * 0.97, 0.9), (0.06, 0.06, 1.8), "metal_dark")
    for z in (0.35, 1.3):
        p.box((0, 0, z), (0.9, 1.94, 0.05), "metal_dark")
        p.box((0, 0, z + 0.1), (0.86, 1.88, 0.14), "cloth_white")
        p.box((0, -0.2, z + 0.18), (0.88, 1.2, 0.04), "fabric_denim")
        p.box((0, 0.72, z + 0.2), (0.5, 0.3, 0.08), "cloth_white")
    for k in range(4):
        p.box((0.45, -0.6, 0.5 + k * 0.28), (0.03, 0.4, 0.03), "metal_dark")
    reg("bunk_bed", fin(p, "bunk_bed", bevel=0.008))


@prop
def tables():
    p = P()
    legs(p, 1.4, 0.8, 0.72, 0.07, "wood_dark")
    p.box((0, 0, 0.74), (1.5, 0.9, 0.045), "wood_floor")
    p.box((0, 0, 0.66), (1.3, 0.7, 0.08), "wood_dark")
    reg("table", fin(p, "table", bevel=0.008))
    p = P()
    legs(p, 0.55, 0.55, 0.45, 0.05, "wood_dark")
    p.box((0, 0, 0.47), (0.62, 0.62, 0.035), "wood_floor")
    p.box((0, 0, 0.2), (0.5, 0.5, 0.02), "wood_dark")
    reg("table_small", fin(p, "table_small"))
    p = P()
    legs(p, 0.42, 0.42, 0.44, 0.04, "wood_dark")
    p.box((0, 0, 0.45), (0.44, 0.44, 0.035), "wood_floor")
    for sx in (-1, 1):
        p.box((sx * 0.19, 0.2, 0.7), (0.04, 0.04, 0.5), "wood_dark", rot=(-6, 0, 0))
    for z in (0.62, 0.78, 0.92):
        p.box((0, 0.215, z), (0.36, 0.02, 0.07), "wood_dark", rot=(-6, 0, 0))
    reg("chair", fin(p, "chair"))
    p = P()
    for a in range(3):
        an = a * 2.094
        p.tube([(math.cos(an) * 0.17, math.sin(an) * 0.17, 0), (math.cos(an) * 0.1, math.sin(an) * 0.1, 0.5)], 0.02, "metal_dark", seg=5)
    p.cyl((0, 0, 0.52), 0.17, 0.05, "wood_floor", seg=12)
    reg("stool", fin(p, "stool"))
    p = P()                                            # banco interior / de iglesia
    for sx in (-1, 1):
        p.box((sx * 0.95, 0, 0.42), (0.05, 0.42, 0.84), "wood_dark")
    p.box((0, -0.04, 0.44), (1.9, 0.36, 0.04), "wood_floor")
    p.box((0, 0.17, 0.68), (1.9, 0.035, 0.34), "wood_floor", rot=(-8, 0, 0))
    reg("pew", fin(p, "pew"))


@prop
def seating():
    p = P()
    p.box((0, 0, 0.2), (1.9, 0.82, 0.24), "fabric_denim")
    p.box((0, 0.33, 0.55), (1.9, 0.2, 0.5), "fabric_denim", rot=(-8, 0, 0))
    for sx in (-1, 1):
        p.box((sx * 0.88, 0, 0.36), (0.16, 0.82, 0.5), "fabric_denim")
        p.box((sx * 0.42, -0.05, 0.38), (0.78, 0.6, 0.14), "fabric_pattern")
    legs(p, 1.8, 0.7, 0.08, 0.06, "wood_dark")
    reg("sofa", fin(p, "sofa", bevel=0.03))
    p = P()
    p.box((0, 0, 0.2), (0.8, 0.8, 0.24), "leather_brown")
    p.box((0, 0.32, 0.55), (0.8, 0.18, 0.55), "leather_brown", rot=(-10, 0, 0))
    for sx in (-1, 1):
        p.box((sx * 0.34, 0, 0.38), (0.14, 0.8, 0.5), "leather_brown")
    p.box((0, -0.04, 0.38), (0.52, 0.6, 0.13), "leather_brown")
    reg("armchair", fin(p, "armchair", bevel=0.03))
    p = P()
    p.cyl((0, 0, 0.04), 0.28, 0.04, "plastic_black", seg=5)
    p.cyl((0, 0, 0.25), 0.03, 0.4, "metal_steel", seg=6)
    p.box((0, 0, 0.48), (0.46, 0.46, 0.07), "fabric_denim")
    p.box((0, 0.2, 0.8), (0.42, 0.06, 0.45), "fabric_denim", rot=(-8, 0, 0))
    reg("office_chair", fin(p, "office_chair", bevel=0.015))


def cabinet_body(p, w, d, h, mat, shelves=2, back=True, toe=0.0, tk=0.03):
    """Mueble hueco abierto por delante (−Y)."""
    for sx in (-1, 1):
        p.box((sx * (w / 2 - tk / 2), 0, toe + (h - toe) / 2), (tk, d, h - toe), mat)
    p.box((0, 0, h - tk / 2), (w, d, tk), mat)
    p.box((0, 0, toe + tk / 2), (w, d, tk), mat)
    if back:
        p.box((0, d / 2 - 0.01, toe + (h - toe) / 2), (w, 0.02, h - toe), mat)
    for k in range(shelves):
        z = toe + (h - toe) * (k + 1) / (shelves + 1)
        p.box((0, 0.01, z), (w - 2 * tk, d - 0.04, 0.022), mat)
    if toe > 0:
        p.box((0, 0.03, toe / 2), (w - 0.06, d - 0.1, toe), mat)


def handle(p, c, vertical=True, mat="metal_steel"):
    s = (0.015, 0.03, 0.12) if vertical else (0.12, 0.03, 0.015)
    p.box(c, s, mat)


@prop
def wardrobe():
    p = P()
    cabinet_body(p, 1.1, 0.55, 1.95, "wood_dark", shelves=1, toe=0.08)
    p.tube([(-0.5, 0, 1.6), (0.5, 0, 1.6)], 0.012, "metal_steel", seg=5)
    for k, x in enumerate((-0.3, 0.05, 0.3)):
        p.box((x, 0.02, 1.25), (0.04, 0.36, 0.62), ("fabric_denim", "fabric_pattern", "cloth_white")[k])
    body = fin(p, "wardrobe", bevel=0.008)
    p = P()
    p.box((0.27, -0.012, 0.93), (0.54, 0.024, 1.84), "wood_dark")
    p.box((0.27, -0.03, 0.93), (0.4, 0.012, 1.6), "wood_floor")
    handle(p, (0.49, -0.045, 0.95))
    lid = fin(p, "wardrobe_lid", bevel=0.004, ground=None)
    lid.location = (-0.545, -0.275, 0.09)
    p = P()
    p.box((0, 0, 0), (0.545, 0.024, 1.84), "wood_dark")
    p.box((0, -0.018, 0), (0.4, 0.012, 1.6), "wood_floor")
    handle(p, (-0.22, -0.033, 0.02))
    fixed = fin(p, "wardrobe_door2", bevel=0.004, ground=None)
    fixed.location = (0.275, -0.287, 1.01)
    reg("wardrobe", [body, lid, fixed], container={"slots": 14, "lid": {"type": "door", "angle": -105}})


@prop
def dresser():
    p = P()
    cabinet_body(p, 1.0, 0.45, 0.85, "wood_dark", shelves=2, toe=0.06)
    for k in (0, 1):
        p.box((0, -0.215, 0.2 + k * 0.26), (0.92, 0.022, 0.23), "wood_floor")
        handle(p, (0, -0.235, 0.2 + k * 0.26), vertical=False)
    body = fin(p, "dresser", bevel=0.008)
    p = P()
    p.box((0, 0.2, 0.0), (0.9, 0.4, 0.015), "wood_dark")
    p.box((0, 0.0, 0.1), (0.92, 0.022, 0.23), "wood_floor")
    for sx in (-1, 1):
        p.box((sx * 0.44, 0.2, 0.08), (0.015, 0.4, 0.17), "wood_dark")
    handle(p, (0, -0.02, 0.1), vertical=False)
    lid = fin(p, "dresser_lid", bevel=0.004, ground=None)
    lid.location = (0, -0.215, 0.62)
    reg("dresser", [body, lid], container={"slots": 10, "lid": {"type": "drawer", "slide": 0.3}})


@prop
def kitchen():
    p = P()
    cabinet_body(p, 1.2, 0.6, 0.86, "wood_white", shelves=1, toe=0.1)
    p.box((0, -0.01, 0.88), (1.24, 0.64, 0.04), "concrete_floor")
    p.box((0.3, -0.3, 0.47), (0.58, 0.022, 0.7), "wood_white")
    handle(p, (0.07, -0.32, 0.6))
    body = fin(p, "kitchen_cabinet", bevel=0.008)
    p = P()
    p.box((0.29, -0.011, 0.35), (0.58, 0.022, 0.7), "wood_white")
    handle(p, (0.52, -0.03, 0.48))
    lid = fin(p, "kitchen_cabinet_lid", bevel=0.004, ground=None)
    lid.location = (-0.59, -0.3, 0.12)
    reg("kitchen_cabinet", [body, lid], container={"slots": 10, "lid": {"type": "door", "angle": -100}})
    p = P()
    cabinet_body(p, 0.9, 0.6, 0.86, "wood_white", shelves=0, toe=0.1)
    p.box((0, -0.3, 0.47), (0.86, 0.022, 0.7), "wood_white")
    p.box((0, -0.01, 0.88), (0.94, 0.64, 0.04), "concrete_floor")
    p.box((0, 0, 0.84), (0.5, 0.38, 0.12), "metal_steel")
    p.box((0, 0, 0.905), (0.44, 0.32, 0.01), "metal_dark")
    p.tube([(0, 0.24, 0.9), (0, 0.24, 1.12), (0, 0.1, 1.14)], 0.014, "metal_steel", seg=6)
    reg("kitchen_sink", fin(p, "kitchen_sink", bevel=0.008))
    p = P()
    p.box((0, 0, 0.45), (0.6, 0.6, 0.9), "metal_white")
    p.box((0, -0.305, 0.42), (0.5, 0.012, 0.5), "glass_dark")
    p.box((0, -0.32, 0.72), (0.44, 0.02, 0.02), "metal_steel")
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.cyl((sx * 0.14, sy * 0.13, 0.91), 0.085, 0.015, "metal_dark", seg=10)
    p.box((0, 0.28, 0.98), (0.6, 0.04, 0.16), "metal_white")
    reg("stove", fin(p, "stove", bevel=0.008))
    p = P()
    p.box((0, 0.02, 0.87), (0.65, 0.6, 1.74), "metal_white")
    body = fin(p, "fridge", bevel=0.012)
    p = P()
    p.box((0.325, -0.03, 0.56), (0.65, 0.06, 1.12), "metal_white")
    p.box((0.58, -0.07, 0.7), (0.025, 0.03, 0.4), "metal_steel")
    lid = fin(p, "fridge_lid", bevel=0.012, ground=None)
    lid.location = (-0.325, -0.28, 0.6)
    p = P()
    p.box((0, 0, 0), (0.65, 0.06, 0.54), "metal_white")
    p.box((0.255, -0.04, -0.1), (0.025, 0.03, 0.22), "metal_steel")
    top = fin(p, "fridge_top", bevel=0.012, ground=None)
    top.location = (0, -0.31, 0.3)
    reg("fridge", [body, lid, top], container={"slots": 12, "lid": {"type": "door", "angle": -110}})


@prop
def shelves():
    rnd = random.Random(3)
    p = P()
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.box((sx * 0.58, sy * 0.19, 0.95), (0.04, 0.04, 1.9), "metal_dark")
    goods = ["paint_red", "paint_yellow", "paint_green", "paint_blue", "plastic_white", "metal_steel"]
    for k in range(5):
        z = 0.12 + k * 0.43
        p.box((0, 0, z), (1.2, 0.42, 0.025), "metal_shutter")
        if k < 4:
            x = -0.52
            while x < 0.45:
                if rnd.random() < 0.55:
                    w = rnd.uniform(0.07, 0.14)
                    h = rnd.uniform(0.1, 0.26)
                    if rnd.random() < 0.5:
                        p.cyl((x + w / 2, rnd.uniform(-0.08, 0.08), z + 0.013 + h / 2), w / 2, h, rnd.choice(goods), seg=8)
                    else:
                        p.box((x + w / 2, rnd.uniform(-0.08, 0.08), z + 0.013 + h / 2), (w, w * 1.2, h), rnd.choice(goods), rot=(0, 0, rnd.uniform(-12, 12)))
                    x += w + 0.02
                else:
                    x += rnd.uniform(0.1, 0.3)
    reg("shelf_unit", fin(p, "shelf_unit", bevel=0.0))
    p = P()
    cabinet_body(p, 0.9, 0.3, 1.9, "wood_dark", shelves=4, toe=0.06)
    cols = ["paint_red", "paint_green", "paint_blue", "leather_brown", "paint_dark", "paint_yellow", "cloth_white"]
    for k in range(5):
        z = 0.06 + (1.9 - 0.06) * k / 5 + 0.03
        x = -0.4
        while x < 0.36:
            if rnd.random() < 0.75:
                w = rnd.uniform(0.025, 0.05)
                h = rnd.uniform(0.2, 0.3)
                lean = rnd.choice([0, 0, 0, 12])
                p.box((x + w / 2, 0.0, z + h / 2), (w, 0.2, h), rnd.choice(cols), rot=(0, lean, 0))
                x += w + 0.004 + (0.04 if lean else 0)
            else:
                x += 0.12
    reg("bookshelf", fin(p, "bookshelf", bevel=0.0))


@prop
def shop_furniture():
    p = P()
    p.box((0, 0, 0.5), (2.0, 0.6, 0.94), "wood_dark")
    p.box((0, -0.02, 1.0), (2.1, 0.7, 0.05), "wood_floor")
    p.box((0, -0.31, 0.5), (1.8, 0.012, 0.7), "wood_floor")
    p.box((0.6, 0, 1.12), (0.36, 0.38, 0.2), "metal_dark")          # caja registradora
    p.box((0.6, 0.06, 1.27), (0.3, 0.2, 0.1), "metal_dark", rot=(20, 0, 0))
    p.box((0.6, -0.1, 1.24), (0.26, 0.14, 0.02), "plastic_white", rot=(25, 0, 0))
    reg("counter", fin(p, "counter", bevel=0.008))
    p = P()
    legs(p, 1.3, 0.65, 0.72, 0.05, "metal_dark")
    p.box((0, 0, 0.74), (1.36, 0.7, 0.04), "wood_floor")
    p.box((0.42, 0, 0.5), (0.42, 0.6, 0.44), "wood_dark")
    p.box((-0.3, 0.1, 0.78), (0.42, 0.3, 0.015), "cloth_white", rot=(0, 0, 12))   # papeles
    p.box((-0.3, 0.12, 0.795), (0.3, 0.21, 0.01), "cloth_white", rot=(0, 0, -8))
    body = fin(p, "desk", bevel=0.008)
    p = P()
    p.box((0, 0, 0), (0.38, 0.02, 0.18), "wood_floor")
    p.box((0, 0.25, -0.07), (0.36, 0.5, 0.012), "wood_dark")
    handle(p, (0, -0.02, 0), vertical=False)
    lid = fin(p, "desk_lid", bevel=0.004, ground=None)
    lid.location = (0.42, -0.305, 0.6)
    reg("desk", [body, lid], container={"slots": 8, "lid": {"type": "drawer", "slide": 0.28}})
    p = P()
    p.box((0, 0.01, 0.65), (0.45, 0.58, 1.3), "metal_green")
    for k in (0, 1, 3):
        p.box((0, -0.29, 0.17 + k * 0.32), (0.41, 0.015, 0.29), "metal_green")
        handle(p, (0, -0.305, 0.22 + k * 0.32), vertical=False)
    body = fin(p, "filing_cabinet", bevel=0.008)
    p = P()
    p.box((0, 0, 0), (0.41, 0.015, 0.29), "metal_green")
    p.box((0, 0.26, -0.03), (0.38, 0.5, 0.2), "metal_green", mats={"+z": None})
    handle(p, (0, -0.02, 0.05), vertical=False)
    lid = fin(p, "filing_cabinet_lid", bevel=0.004, ground=None)
    lid.location = (0, -0.29, 0.81)
    reg("filing_cabinet", [body, lid], container={"slots": 8, "lid": {"type": "drawer", "slide": 0.3}})


@prop
def metal_storage():
    p = P()
    p.box((0, 0.01, 0.93), (0.4, 0.48, 1.85), "metal_blue", mats={"-y": None})
    p.box((0, 0.0, 1.5), (0.36, 0.44, 0.02), "metal_blue")
    p.box((0, 0.0, 0.5), (0.36, 0.44, 0.02), "metal_blue")
    body = fin(p, "locker", bevel=0.0)
    p = P()
    p.box((0.19, -0.008, 0.9), (0.38, 0.016, 1.8), "metal_blue")
    for k in range(4):
        p.box((0.19, -0.02, 1.5 + k * 0.045), (0.24, 0.008, 0.012), "metal_dark")
    handle(p, (0.33, -0.03, 0.95))
    lid = fin(p, "locker_lid", bevel=0.004, ground=None)
    lid.location = (-0.19, -0.23, 0.025)
    reg("locker", [body, lid], container={"slots": 10, "lid": {"type": "door", "angle": -100}})
    p = P()
    p.box((0, 0, 0.1), (0.5, 0.24, 0.2), "metal_red", mats={"+z": None})
    p.box((0, 0, 0.012), (0.46, 0.2, 0.02), "metal_dark")
    body = fin(p, "toolbox", bevel=0.008)
    p = P()
    p.box((0, -0.12, 0.03), (0.5, 0.24, 0.06), "metal_red")
    p.tube([(-0.12, -0.12, 0.06), (-0.12, -0.12, 0.11), (0.12, -0.12, 0.11), (0.12, -0.12, 0.06)], 0.012, "metal_steel", seg=5)
    lid = fin(p, "toolbox_lid", bevel=0.008, ground=None)
    lid.location = (0, 0.12, 0.2)
    reg("toolbox", [body, lid], solid=False, container={"slots": 6, "lid": {"type": "lid", "angle": 70}})
    p = P()
    p.box((0, 0, 0.25), (0.9, 0.5, 0.5), "metal_green", mats={"+z": None})
    p.box((0, 0, 0.02), (0.86, 0.46, 0.02), "metal_dark")
    for sx in (-1, 1):
        p.box((sx * 0.455, 0, 0.3), (0.02, 0.16, 0.03), "metal_steel")
    body = fin(p, "chest_metal", bevel=0.01)
    p = P()
    p.box((0, -0.25, 0.04), (0.92, 0.52, 0.08), "metal_green")
    p.box((0, -0.515, 0.0), (0.08, 0.02, 0.1), "metal_steel")
    lid = fin(p, "chest_metal_lid", bevel=0.01, ground=None)
    lid.location = (0, 0.25, 0.5)
    reg("chest_metal", [body, lid], container={"slots": 16, "lid": {"type": "lid", "angle": 75}})
    p = P()
    p.box((0, 0, 0.3), (0.5, 0.16, 0.6), "metal_white", mats={"-y": None})
    p.box((0, 0, 0.3), (0.46, 0.14, 0.015), "metal_white")
    for x, c in ((-0.14, "paint_red"), (0.0, "plastic_white"), (0.13, "paint_blue")):
        p.cyl((x, 0, 0.37), 0.03, 0.1, c, seg=7)
    body = fin(p, "medicine_cabinet", bevel=0.006, ground=None)
    p = P()
    p.box((0.25, -0.008, 0.3), (0.5, 0.016, 0.6), "metal_white")
    p.box((0.25, -0.018, 0.3), (0.36, 0.006, 0.44), "glass")
    lid = fin(p, "medicine_cabinet_lid", bevel=0.004, ground=None)
    lid.location = (-0.25, -0.08, 0.0)
    reg("medicine_cabinet", [body, lid], solid=False, container={"slots": 6, "lid": {"type": "door", "angle": -110}}, wall=1.25)


@prop
def crates():
    def crate_box(p, w, d, h, lid=False):
        mat = "wood_raw"
        if not lid:
            p.box((0, 0, h / 2), (w, d, h), mat, mats={"+z": None})
            p.box((0, 0, 0.015), (w - 0.04, d - 0.04, 0.02), mat)
            for sx in (-1, 1):
                for sy in (-1, 1):
                    p.box((sx * (w / 2 + 0.005), sy * (d / 2 - 0.04), h / 2), (0.02, 0.07, h), "wood_grey")
                    p.box((sx * (w / 2 - 0.04), sy * (d / 2 + 0.005), h / 2), (0.07, 0.02, h), "wood_grey")
            for z in (0.06, h - 0.06):
                for sy in (-1, 1):
                    p.box((0, sy * (d / 2 + 0.005), z), (w, 0.02, 0.07), "wood_grey")
    p = P()
    crate_box(p, 0.8, 0.6, 0.55)
    body = fin(p, "crate_wood", bevel=0.004)
    p = P()
    for k in range(5):
        p.box((-0.32 + k * 0.16, -0.3, 0.012), (0.15, 0.62, 0.022), "wood_raw")
    for sx in (-1, 1):
        p.box((sx * 0.3, -0.3, 0.032), (0.07, 0.62, 0.02), "wood_grey")
    lid = fin(p, "crate_wood_lid", bevel=0.003, ground=None)
    lid.location = (0, 0.3, 0.55)
    reg("crate_wood", [body, lid], container={"slots": 12, "lid": {"type": "lid", "angle": 65}})
    p = P()
    p.box((0, 0, 0.175), (0.5, 0.4, 0.35), "cardboard", mats={"+z": None})
    p.box((0, 0, 0.01), (0.48, 0.38, 0.01), "cardboard")
    p.box((-0.25, 0, 0.42), (0.01, 0.4, 0.2), "cardboard", rot=(0, -25, 0))
    p.box((0.25, 0, 0.42), (0.01, 0.4, 0.2), "cardboard", rot=(0, 25, 0))
    body = fin(p, "cardboard_box", bevel=0.0)
    p = P()
    p.box((0, -0.1, 0.0), (0.5, 0.2, 0.008), "cardboard")
    lid = fin(p, "cardboard_box_lid", bevel=0.0, ground=None)
    lid.location = (0, 0.2, 0.35)
    reg("cardboard_box", [body, lid], solid=False, container={"slots": 6, "lid": {"type": "lid", "angle": 110}})
    rnd = random.Random(5)
    p = P()
    for (x, y, z, r) in ((0, 0, 0, 3), (0.85, 0.1, 0, -6), (0.4, 0.05, 0.57, 12)):
        p.push((x, y, z), (0, 0, r))
        crate_box(p, 0.8, 0.6, 0.55)
        for k in range(5):
            p.box((-0.32 + k * 0.16, 0, 0.56), (0.15, 0.62, 0.022), "wood_raw")
        p.pop()
    reg("crate_stack", fin(p, "crate_stack", bevel=0.0))
    p = P()
    for k in range(7):
        p.box((0, -0.54 + k * 0.18, 0.13), (1.2, 0.1, 0.022), "wood_raw")
    for x in (-0.55, 0, 0.55):
        p.box((x, 0, 0.06), (0.1, 1.18, 0.1), "wood_raw")
    for k in (-1, 0, 1):
        p.box((0, k * 0.54, 0.011), (1.2, 0.1, 0.022), "wood_raw")
    reg("pallet", fin(p, "pallet", bevel=0.0), solid=False)


@prop
def barrels():
    p = P()
    p.lathe([(0.28, 0), (0.29, 0.02), (0.29, 0.3), (0.3, 0.31), (0.29, 0.32), (0.29, 0.58), (0.3, 0.59), (0.29, 0.6), (0.29, 0.86), (0.28, 0.88)], "metal_blue", seg=14)
    p.cyl((0.14, 0.1, 0.885), 0.03, 0.02, "metal_dark", seg=6)
    reg("barrel_metal", fin(p, "barrel_metal", bevel=0.0, smooth=50))
    p = P()
    p.lathe([(0.28, 0), (0.29, 0.02), (0.29, 0.3), (0.3, 0.31), (0.29, 0.32), (0.29, 0.58), (0.3, 0.59), (0.29, 0.6), (0.29, 0.86), (0.28, 0.88)], "metal_rust", seg=14)
    reg("barrel_rust", fin(p, "barrel_rust", bevel=0.0, smooth=50))
    p = P()
    prof = [(0.25, 0), (0.3, 0.2), (0.33, 0.45), (0.3, 0.7), (0.25, 0.9)]
    p.lathe(prof, "wood_siding", seg=14)
    for z, r in ((0.1, 0.285), (0.3, 0.325), (0.6, 0.325), (0.8, 0.285)):
        p.lathe([(r, z - 0.02), (r + 0.008, z), (r, z + 0.02)], "metal_dark", seg=14, close=False)
    reg("barrel_wood", fin(p, "barrel_wood", bevel=0.0, smooth=50))
    p = P()
    for (x, y, z, rz, ry) in ((0, 0, 0.16, 10, 0), (0.5, 0.2, 0.16, -30, 0), (0.25, 0.1, 0.42, 60, 8)):
        p.push((x, y, z), (0, ry, rz))
        p.sphere((0, 0, 0), 0.3, "sack_cloth", seg=10, rings=6, scale=(1.0, 0.62, 0.5))
        p.box((0.3, 0, 0.02), (0.08, 0.2, 0.04), "sack_cloth")
        p.pop()
    reg("sacks", fin(p, "sacks", bevel=0.0, smooth=60))
    p = P()
    for k in range(3):
        p.lathe([(0.3, 0), (0.33, 0.05), (0.33, 0.17), (0.3, 0.22)], "rubber", seg=14, c=(k * 0.04, k * 0.03, k * 0.22))
    reg("tires", fin(p, "tires", bevel=0.0, smooth=60))


@prop
def work_and_machines():
    p = P()
    legs(p, 1.8, 0.7, 0.86, 0.08, "wood_dark")
    p.box((0, 0, 0.89), (1.9, 0.76, 0.06), "wood_raw")
    p.box((0, 0.02, 0.3), (1.7, 0.6, 0.03), "wood_raw")
    p.box((0, 0.36, 1.45), (1.9, 0.03, 1.0), "wood_grey")                 # panel de herramientas
    for k, x in enumerate((-0.7, -0.4, -0.1, 0.25, 0.6)):
        p.box((x, 0.335, 1.5), (0.04, 0.02, 0.3 + 0.05 * (k % 2)), "metal_steel", rot=(0, (k - 2) * 5, 0))
        p.box((x, 0.335, 1.3 - 0.02 * k), (0.06, 0.03, 0.12), "wood_dark")
    p.box((-0.7, -0.2, 0.98), (0.2, 0.14, 0.12), "metal_dark")            # tornillo de banco
    p.box((-0.7, -0.3, 1.02), (0.18, 0.04, 0.1), "metal_dark")
    p.tube([(-0.7, -0.42, 1.0), (-0.7, -0.26, 1.0)], 0.012, "metal_steel", seg=5)
    p.box((0.5, 0, 0.36), (0.5, 0.24, 0.2), "metal_red")
    reg("workbench", fin(p, "workbench", bevel=0.006), station="workbench")
    p = P()
    p.box((0, 0, 0.4), (0.9, 0.55, 0.5), "metal_yellow")
    p.box((0, 0, 0.12), (1.0, 0.6, 0.06), "metal_dark")
    p.cyl((0.2, 0, 0.72), 0.14, 0.2, "metal_dark", seg=10)
    p.cyl((-0.28, 0, 0.7), 0.05, 0.25, "metal_dark", seg=7)
    for sx in (-1, 1):
        p.cyl((sx * 0.4, -0.3, 0.12), 0.11, 0.06, "rubber", seg=10, rot=(90, 0, 0))
    p.tube([(-0.45, -0.25, 0.3), (-0.75, -0.25, 0.6), (-0.75, 0.25, 0.6), (-0.45, 0.25, 0.3)], 0.016, "metal_dark", seg=5)
    reg("generator", fin(p, "generator", bevel=0.008))
    p = P()                                                                 # cinta transportadora
    p.box((0, 0, 0.8), (4.0, 0.7, 0.1), "metal_dark")
    p.box((0, 0, 0.86), (3.9, 0.56, 0.02), "rubber")
    for x in (-1.8, -0.6, 0.6, 1.8):
        for sy in (-1, 1):
            p.box((x, sy * 0.3, 0.4), (0.07, 0.07, 0.8), "metal_green")
    for sy in (-1, 1):
        p.box((0, sy * 0.36, 0.95), (4.0, 0.03, 0.14), "metal_green")
    for x in (-1.2, 0.2, 1.3):
        p.lathe([(0.04, 0), (0.05, 0.01), (0.05, 0.1), (0.04, 0.11)], "metal_steel", seg=10, c=(x, 0.05, 0.87))
    reg("conveyor", fin(p, "conveyor", bevel=0.0))
    p = P()                                                                 # depósito / cuba
    p.lathe([(0.9, 0.5), (0.95, 0.55), (0.95, 2.4), (0.7, 2.7), (0.25, 2.8), (0.25, 2.9)], "metal_steel", seg=16)
    for a in range(4):
        an = a * 1.5708 + 0.785
        p.box((math.cos(an) * 0.8, math.sin(an) * 0.8, 0.28), (0.1, 0.1, 0.56), "metal_dark")
    p.tube([(0.95, 0, 0.8), (1.3, 0, 0.8), (1.3, 0, 0.1)], 0.06, "metal_green", seg=8)
    p.lathe([(0.02, 0), (0.12, 0), (0.12, 0.02), (0.02, 0.02)], "metal_red", seg=10, c=(1.32, 0, 0.5), rot=(0, 90, 0))
    reg("vat", fin(p, "vat", bevel=0.0, smooth=50, ao_dist=0.8))
    p = P()                                                                 # grupo de bombeo
    p.box((0, 0, 0.1), (1.6, 0.8, 0.2), "concrete_floor")
    p.cyl((-0.3, 0, 0.5), 0.28, 0.7, "metal_green", seg=12, rot=(0, 90, 0))
    p.cyl((0.4, 0, 0.5), 0.2, 0.4, "metal_blue", seg=12, rot=(0, 90, 0))
    p.tube([(0.6, 0, 0.5), (0.9, 0, 0.5), (0.9, 0, 1.4), (0.9, 0.8, 1.4)], 0.09, "metal_rust", seg=8)
    p.tube([(-0.3, 0, 0.78), (-0.3, 0, 1.5), (-0.3, 0.8, 1.5)], 0.07, "metal_rust", seg=8)
    p.lathe([(0.02, 0), (0.16, 0), (0.16, 0.025), (0.02, 0.025)], "metal_red", seg=10, c=(0.9, -0.12, 1.0), rot=(90, 0, 0))
    reg("pump_unit", fin(p, "pump_unit", bevel=0.0, smooth=50, ao_dist=0.6))
    p = P()                                                                 # panel de control
    p.box((0, 0, 0.5), (1.0, 0.5, 1.0), "metal_shutter")
    p.box((0, -0.12, 1.12), (1.0, 0.45, 0.3), "metal_shutter", rot=(28, 0, 0))
    for k in range(6):
        col = ("paint_red", "paint_green", "paint_yellow")[k % 3]
        p.cyl((-0.35 + k * 0.14, -0.2, 1.21), 0.025, 0.03, col, seg=8, rot=(28, 0, 0))
    p.box((0, -0.03, 1.3), (0.5, 0.01, 0.16), "glass_dark", rot=(28, 0, 0))
    reg("control_panel", fin(p, "control_panel", bevel=0.008), station="terminal")
    p = P()                                                                 # mesa de laboratorio
    legs(p, 1.8, 0.75, 0.86, 0.05, "metal_steel")
    p.box((0, 0, 0.89), (1.9, 0.8, 0.05), "plastic_white")
    p.box((0, 0, 0.25), (1.75, 0.7, 0.02), "metal_steel")
    p.box((-0.55, 0.1, 1.02), (0.28, 0.3, 0.22), "metal_white")
    p.cyl((-0.55, 0.0, 1.2), 0.04, 0.2, "metal_dark", seg=8, rot=(30, 0, 0))
    for k, x in enumerate((0.1, 0.25, 0.4, 0.6)):
        p.lathe([(0.03, 0), (0.035, 0.08), (0.012, 0.12), (0.012, 0.16)], "glass", seg=8, c=(x, 0.12 - 0.05 * k, 0.915))
    p.box((0.55, -0.2, 0.93), (0.3, 0.22, 0.03), "paint_dark")
    reg("lab_table", fin(p, "lab_table", bevel=0.006), station="lab")
    p = P()                                                                 # armario de servidores
    p.box((0, 0, 1.0), (0.6, 0.8, 2.0), "metal_dark")
    for k in range(9):
        p.box((0, -0.405, 0.25 + k * 0.19), (0.5, 0.01, 0.15), "metal_shutter")
        p.box((0.18, -0.412, 0.25 + k * 0.19), (0.02, 0.006, 0.02), "led_green" if k % 3 else "led_amber")
    reg("server_rack", fin(p, "server_rack", bevel=0.008))
    p = P()                                                                 # cama de consultorio
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.tube([(sx * 0.4, sy * 0.9, 0.0), (sx * 0.4, sy * 0.9, 0.6)], 0.02, "metal_steel", seg=6)
    p.box((0, 0, 0.6), (0.85, 1.9, 0.04), "metal_steel")
    p.box((0, 0, 0.68), (0.8, 1.85, 0.12), "cloth_white")
    p.box((0, 0.68, 0.77), (0.5, 0.3, 0.08), "cloth_white")
    reg("clinic_bed", fin(p, "clinic_bed", bevel=0.01))


@prop
def decor():
    p = P()
    p.box((0, 0, 0.008), (2.0, 1.4, 0.016), "carpet_dirty")
    reg("rug", fin(p, "rug", bevel=0.0, ao=False), solid=False)
    p = P()
    p.box((0, 0, 0), (0.6, 0.03, 0.45), "wood_dark")
    sign_quad(p, "picture_a", 0.5, 0.36, c=(0, -0.018, 0))
    reg("picture_a", fin(p, "picture_a", bevel=0.004, ground=None), solid=False, wall=1.6)
    p = P()
    p.box((0, 0, 0), (0.45, 0.03, 0.6), "wood_dark")
    sign_quad(p, "picture_b", 0.36, 0.5, c=(0, -0.018, 0))
    reg("picture_b", fin(p, "picture_b", bevel=0.004, ground=None), solid=False, wall=1.6)
    p = P()
    p.box((0, 0, 0), (0.9, 0.02, 0.65), "wood_grey")
    sign_quad(p, "map_valley", 0.84, 0.6, c=(0, -0.012, 0))
    reg("wall_map", fin(p, "wall_map", bevel=0.0, ground=None), solid=False, wall=1.5)
    p = P()
    p.box((0, 0, 0), (2.4, 0.04, 1.2), "wood_dark")
    p.box((0, -0.022, 0), (2.3, 0.01, 1.1), "paint_dark")
    p.box((0, -0.06, -0.58), (2.3, 0.08, 0.03), "wood_dark")
    reg("blackboard", fin(p, "blackboard", bevel=0.004, ground=None), solid=False, wall=1.5)
    p = P()
    p.tube([(0, 0, 0), (0, 0, -0.5)], 0.008, "metal_dark", seg=4)
    p.lathe([(0.02, -0.5), (0.2, -0.66), (0.21, -0.68)], "metal_green", seg=12, close=False)
    p.sphere((0, 0, -0.62), 0.045, "lamp_glass", seg=8, rings=6)
    reg("lamp_ceiling", fin(p, "lamp_ceiling", bevel=0.0, ground=None, ao=False), solid=False, ceiling=True)
    p = P()
    p.box((0, 0, 0.13), (0.34, 0.14, 0.22), "wood_dark")
    p.box((-0.07, -0.072, 0.13), (0.14, 0.006, 0.14), "sack_cloth")
    p.cyl((0.09, -0.075, 0.17), 0.03, 0.02, "metal_brass", seg=8, rot=(90, 0, 0))
    p.cyl((0.09, -0.075, 0.09), 0.02, 0.02, "metal_brass", seg=8, rot=(90, 0, 0))
    p.tube([(0.14, 0.02, 0.24), (0.14, 0.02, 0.6)], 0.004, "metal_steel", seg=4)
    reg("radio_old", fin(p, "radio_old", bevel=0.01), solid=False)
    p = P()
    p.box((0, 0, 0.3), (0.6, 0.45, 0.46), "wood_dark")
    p.box((-0.07, -0.228, 0.31), (0.4, 0.01, 0.34), "glass_dark")
    for k in range(2):
        p.cyl((0.22, -0.23, 0.38 - k * 0.12), 0.03, 0.02, "plastic_black", seg=8, rot=(90, 0, 0))
    legs(p, 0.5, 0.36, 0.07, 0.04, "wood_dark")
    reg("tv_old", fin(p, "tv_old", bevel=0.012))
    p = P()
    p.box((0, 0, 0.5), (1.4, 0.7, 1.0), "stone_wall")
    p.box((0, 0, 1.03), (1.6, 0.85, 0.07), "concrete_floor")
    p.box((0, 0, 1.1), (1.2, 0.5, 0.02), "cloth_white")
    for sx in (-1, 1):
        p.lathe([(0.05, 0), (0.03, 0.03), (0.015, 0.2), (0.025, 0.22)], "metal_brass", seg=8, c=(sx * 0.45, 0, 1.11))
    reg("altar", fin(p, "altar", bevel=0.008))
    p = P()                                                 # estufa de leña
    p.box((0, 0, 0.42), (0.55, 0.45, 0.6), "metal_dark")
    legs(p, 0.5, 0.4, 0.12, 0.05, "metal_dark")
    p.box((0, -0.228, 0.42), (0.3, 0.012, 0.3), "metal_rust")
    p.tube([(0, 0.1, 0.72), (0, 0.1, 2.6)], 0.07, "metal_dark", seg=8)
    reg("wood_stove", fin(p, "wood_stove", bevel=0.01))


# =============================== PUERTAS ==============================================
@prop
def doors():
    def panel_door(name, w, h, mat, panel_mat, glass=False, th=0.045):
        p = P()
        p.box((w / 2, 0, h / 2), (w, th, h), mat)
        for sy in (-1, 1):
            if glass:
                p.box((w / 2, sy * (th / 2 + 0.002), h * 0.68), (w * 0.62, 0.006, h * 0.36), "glass_dark")
            else:
                p.box((w / 2, sy * (th / 2 + 0.004), h * 0.72), (w * 0.66, 0.012, h * 0.36), panel_mat)
            p.box((w / 2, sy * (th / 2 + 0.004), h * 0.27), (w * 0.66, 0.012, h * 0.36), panel_mat)
            p.cyl((w - 0.07, sy * (th / 2 + 0.03), h * 0.48), 0.022, 0.05, "metal_brass", seg=8, rot=(90, 0, 0))
        reg(name, fin(p, name, bevel=0.004, ground=None), sub="doors", door={"w": w, "h": h})
    panel_door("door_wood", 0.86, 2.03, "wood_green", "wood_dark")
    panel_door("door_inner", 0.78, 2.0, "wood_white", "wood_grey", th=0.04)
    panel_door("door_glass", 0.86, 2.03, "wood_dark", "wood_dark", glass=True)
    p = P()
    p.box((0.43, 0, 1.015), (0.86, 0.05, 2.03), "metal_green")
    for sy in (-1, 1):
        p.box((0.43, sy * 0.027, 1.6), (0.3, 0.006, 0.3), "glass_dark")
        p.box((0.75, sy * 0.04, 1.0), (0.03, 0.04, 0.16), "metal_steel")
    reg("door_metal", fin(p, "door_metal", bevel=0.004, ground=None), sub="doors", door={"w": 0.86, "h": 2.03})
    p = P()
    p.box((0.43, 0, 1.015), (0.86, 0.06, 2.03), "metal_white")
    for sy in (-1, 1):
        p.box((0.43, sy * 0.032, 1.5), (0.5, 0.006, 0.5), "glass_dark")
        p.box((0.43, sy * 0.032, 0.5), (0.7, 0.008, 0.08), "paint_yellow")
        p.box((0.76, sy * 0.045, 1.0), (0.03, 0.04, 0.3), "metal_steel")
    reg("door_station", fin(p, "door_station", bevel=0.004, ground=None), sub="doors", door={"w": 0.86, "h": 2.03})
    p = P()                                                     # hoja de portón de granero
    w, h = 1.5, 2.6
    for k in range(8):
        p.box((w * (k + 0.5) / 8, 0, h / 2), (w / 8 - 0.008, 0.04, h), "wood_siding")
    for sy in (-1, 1):
        for z in (0.25, h - 0.25):
            p.box((w / 2, sy * 0.03, z), (w, 0.025, 0.14), "wood_grey")
        p.box((w / 2, sy * 0.03, h / 2), (math.hypot(w, h - 0.5), 0.022, 0.13), "wood_grey", rot=(0, -math.degrees(math.atan2(h - 0.5, w)), 0))
    reg("door_barn", fin(p, "door_barn", bevel=0.0, ground=None), sub="doors", door={"w": w, "h": h})
    p = P()                                                     # cancela de madera
    for k in range(6):
        p.box((0.1 + k * 0.2, 0, 0.55), (0.08, 0.025, 1.0 + 0.06 * math.sin(k * 1.3)), "wood_grey")
    for z in (0.25, 0.85):
        p.box((0.6, 0.02, z), (1.2, 0.03, 0.08), "wood_grey")
    reg("gate_wood", fin(p, "gate_wood", bevel=0.0, ground=None), sub="doors", door={"w": 1.2, "h": 1.1})


def run():
    vb.reset()
    for fn in GEN:
        if ONLY and fn.__name__ not in ONLY:
            continue
        fn()
    path = os.path.join(vb.DATA, "models", "props.json")
    old = {}
    if os.path.exists(path):
        old = json.load(open(path))
        if not ONLY:      # regeneración completa: solo se conservan los modelos importados de Rodin
            old = {k: v for k, v in old.items() if v.get("source") == "rodin"}
    old.update(REG)
    vb.write_json("models/props.json", old)
    for k, v in sorted(REG.items()):
        print("PROP %s tris=%d size=%s" % (k, v["tris"], v["size"]))


if __name__ == "__main__":
    import gen_props as _gp          # el módulo importable es quien acumula el registro
    import gen_props_world           # noqa: F401  (registra los objetos de exterior)
    _gp.run()
