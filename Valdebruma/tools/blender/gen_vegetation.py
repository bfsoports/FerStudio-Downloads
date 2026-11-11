"""gen_vegetation.py — árboles, arbustos, plantas y rocas de Valdebruma.

Ejecutar: blender -b --python tools/blender/gen_vegetation.py
Salida: assets/models/vegetation/*.glb (lod0/lod1/lod2 por especie) y
data/models/vegetation.json (radio de tronco, altura y triángulos por modelo).
Color de vértice: RGB = tinte/oclusión, A = peso de viento (0 rígido, 1 puntas).
"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(__file__))
import bpy, bmesh
from mathutils import Vector, Matrix
import vb

META = {}


def card_dir(p, pos, d, roll, w, h, mat, tint, uv=(0, 0, 1, 1), hang=False):
    """Tarjeta cuyo eje vertical sigue la dirección d (o cuelga hacia abajo si hang)."""
    d = Vector(d).normalized()
    z = -d if hang else d
    ref = Vector((0, 0, 1)) if abs(z.z) < 0.9 else Vector((1, 0, 0))
    x = ref.cross(z).normalized()
    y = z.cross(x)
    m = Matrix((x, y, z)).transposed().to_4x4()
    m = Matrix.Translation(pos) @ m @ Matrix.Rotation(roll, 4, "Z")
    p.stack.append(p.M @ m)
    if hang:
        u0, v0, u1, v1 = uv
        vs = [p._v(q) for q in ((-w / 2, 0, 0), (w / 2, 0, 0), (w / 2, 0, h), (-w / 2, 0, h))]
        p._face(vs, mat, uvs=[(u0, v1), (u1, v1), (u1, v0), (u0, v0)], tint=tint)
    else:
        p.card((0, 0, 0), w, h, mat, uv=uv, tint=tint)
    p.pop()


def path_curve(rnd, start, d, length, n, bend, droop=0.0):
    pts = [Vector(start)]
    d = Vector(d).normalized()
    for i in range(n):
        d = (d + Vector((rnd.uniform(-bend, bend), rnd.uniform(-bend, bend), rnd.uniform(-bend, bend) - droop))).normalized()
        pts.append(pts[-1] + d * (length / n))
    return pts


def foliage_normals(ob, center, lift=0.35):
    """Normales 'esféricas' en las hojas para un sombreado volumétrico suave."""
    me = ob.data
    leaf_idx = {i for i, m in enumerate(me.materials) if m.name.startswith(("leaf", "grass", "reed", "herb", "fiber"))}
    base = [Vector(cn.vector) for cn in me.corner_normals]
    c = Vector(center)
    for poly in me.polygons:
        if poly.material_index in leaf_idx:
            for li in poly.loop_indices:
                v = me.vertices[me.loops[li].vertex_index].co
                n = (v - c)
                n.z += lift * max(1.0, n.length)
                base[li] = n.normalized() if n.length > 1e-5 else Vector((0, 0, 1))
    me.normals_split_custom_set([tuple(n) for n in base])


def make_tree(name, seed, lod, sp):
    rnd = random.Random(seed)
    p = vb.Parts()
    H = sp["h"] * rnd.uniform(0.92, 1.08)
    r0 = sp["r"]
    tseg = (8, 6, 4)[lod]
    bseg = (4, 3, 3)[lod]
    n_tr = (9, 6, 3)[lod]
    lean = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), 0)) * sp.get("lean", 0.03)
    tpts, trad = [], []
    pos = Vector((0, 0, -0.25))
    d = Vector((0, 0, 1))
    for i in range(n_tr + 1):
        t = i / n_tr
        tpts.append(pos.copy())
        flare = 1.0 + 0.55 * max(0.0, 1 - t * 9) ** 2
        trad.append(max(0.03, r0 * (1 - t) ** sp.get("taper", 0.8) * flare + 0.02))
        d = (d + lean + Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), 0)) * sp.get("wobble", 0.04)).normalized()
        pos += d * ((H + 0.25) / n_tr)
    bark = sp["bark"]
    dark = (0.72, 0.7, 0.68)
    p.tube(tpts, trad, bark, seg=tseg, tint=(1, 1, 1, 0.0), cap=False, uscale=1.0 / max(0.3, 2 * math.pi * r0) * 1.0)

    def trunk_at(t):
        f = t * n_tr
        i = min(n_tr - 1, int(f))
        return tpts[i].lerp(tpts[i + 1], f - i), trad[i] + (trad[i + 1] - trad[i]) * (f - i)

    leaf = sp.get("leaf")
    nb = sp["branches"] if lod == 0 else max(4, sp["branches"] * (2 if lod == 1 else 1) // 3)
    ga = rnd.uniform(0, 6.28)
    crown_c = Vector((tpts[-1].x * 0.6, tpts[-1].y * 0.6, H * (sp["b0"] + 1) / 2))
    for b in range(nb):
        u = (b + rnd.uniform(0, 0.6)) / nb
        t = sp["b0"] + (0.97 - sp["b0"]) * u
        bp, br = trunk_at(t)
        ga += 2.399963 + rnd.uniform(-0.35, 0.35)
        shape = sp["shape"]
        if shape == "cone":
            ln = sp["spread"] * (1.05 - u) ** 0.85 * rnd.uniform(0.8, 1.15) + 0.35
        elif shape == "column":
            ln = sp["spread"] * rnd.uniform(0.7, 1.1) * (1.0 - 0.5 * u)
        else:
            ln = sp["spread"] * (0.55 + 0.75 * math.sin(math.pi * (0.15 + 0.8 * u))) * rnd.uniform(0.8, 1.15)
        el = math.radians(sp["elev"] + rnd.uniform(-12, 12) + sp.get("elev_top", 0) * u)
        bd = Vector((math.cos(ga) * math.cos(el), math.sin(ga) * math.cos(el), math.sin(el)))
        pts = path_curve(rnd, bp, bd, ln, 3 if lod == 0 else 2, sp.get("bend", 0.18), sp.get("droop", 0.0))
        rr = [max(0.012, br * 0.5 * (1 - k / (len(pts) - 1)) ** 0.9) for k in range(len(pts))]
        if lod < 2:
            p.tube(pts, rr, bark, seg=bseg, tint=(*dark, 0.25), cap=False, uscale=0.5)
        if not leaf:
            if lod == 0 and ln > 1.0:   # ramas rotas en árboles secos
                for k in range(2):
                    sp_ = pts[rnd.randint(1, len(pts) - 2)]
                    sd = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(0, 1)))
                    p.tube(path_curve(rnd, sp_, sd, ln * 0.4, 2, 0.2), [rr[1] * 0.6, rr[1] * 0.4, 0.01], bark, seg=3, tint=(*dark, 0.3), cap=False)
            continue
        cs = sp["card"] * rnd.uniform(0.85, 1.15)
        style = sp["style"]
        inner = 0.66 + 0.34 * u
        if style == "bough":      # coníferas: dos tarjetas en V invertida a lo largo de la rama
            L = ln * 1.12
            tip = pts[-1] - pts[0]
            tintv = (inner * 0.94, inner, inner * 0.94, 0.75)
            dk = (inner * 0.8, inner * 0.86, inner * 0.8, 0.75)
            base = pts[0] + Vector((0, 0, 0.05))
            if lod == 0:
                card_dir(p, base, tip, 0.55, L * 0.8, L, leaf, tintv)
                card_dir(p, base, tip, -0.55, L * 0.8, L, leaf, tintv)
                card_dir(p, base, tip, math.pi / 2, L * 0.5, L * 0.9, leaf, dk)
            elif lod == 1:
                card_dir(p, base, tip, 0.5 if b % 2 else -0.5, L * 0.9, L, leaf, tintv)
                if b % 2 == 0:
                    card_dir(p, base, tip, math.pi / 2, L * 0.5, L * 0.9, leaf, dk)
            else:
                card_dir(p, base, tip, 0.0, L * 1.1, L * 1.1, leaf, tintv)
        elif style == "hang":     # sauce: cortinas colgantes de largo y giro variables
            for k in range(1, len(pts)):
                if lod == 2 and k < len(pts) - 1:
                    continue
                for j in range((2, 1, 1)[lod]):
                    sh = inner * rnd.uniform(0.85, 1.0)
                    q = pts[k] + Vector((rnd.uniform(-0.5, 0.5), rnd.uniform(-0.5, 0.5), rnd.uniform(-0.1, 0.35)))
                    hl = min(q.z - 0.5, cs * sp.get("hang_len", 1.6) * rnd.uniform(0.6, 1.15))
                    card_dir(p, q, Vector((0, 0, 1)), rnd.uniform(0, 3.14), cs * rnd.uniform(0.7, 1.0), hl, leaf, (sh, sh, sh * 0.95, 1.0), hang=True)
        else:                     # frondosas: racimos repartidos por el tercio exterior de la rama
            n_cl = (6, 3, 1)[lod]
            for k in range(n_cl):
                f = 1.0 - 0.55 * (k / max(1, n_cl - 1)) if n_cl > 1 else 1.0
                seg_f = f * (len(pts) - 1)
                i0 = min(len(pts) - 2, int(seg_f))
                q = pts[i0].lerp(pts[i0 + 1], seg_f - i0)
                q = q + Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-0.4, 0.9))) * (cs * 0.3)
                out = (q - crown_c)
                sh = 0.62 + 0.38 * min(1.0, out.length / max(0.5, sp["spread"]))
                sh *= (0.82 + 0.18 * min(1.0, max(0.0, (q.z - H * sp["b0"]) / max(0.5, H * (1 - sp["b0"])))))
                tintv = (sh, sh, sh * 0.96, 0.9)
                dd = (out.normalized() * 0.6 + Vector((rnd.uniform(-0.4, 0.4), rnd.uniform(-0.4, 0.4), 0.9))).normalized()
                size = cs * (0.72 if lod == 0 else (1.2 if lod == 1 else 1.9)) * rnd.uniform(0.85, 1.15)
                r0_ = rnd.uniform(0, 3.14)
                card_dir(p, q - dd * size * 0.45, dd, r0_, size, size, leaf, tintv)
                if lod < 2 and (lod == 0 or k % 2 == 0):
                    card_dir(p, q - dd * size * 0.45, dd, r0_ + 1.57, size, size, leaf, tintv)
    if leaf and sp["style"] != "hang" and sp["shape"] != "cone":
        # copa superior
        top = tpts[-1]
        for k in range((3, 2, 1)[lod]):
            cs = sp["card"] * 1.2
            card_dir(p, top - Vector((0, 0, cs * 0.5)), Vector((rnd.uniform(-0.3, 0.3), rnd.uniform(-0.3, 0.3), 1)), k * 1.05, cs, cs * 1.1, leaf, (1, 1, 0.97, 1.0))
    if leaf and sp["style"] == "hang":
        for k in range((26, 12, 5)[lod]):
            a, rr_ = rnd.uniform(0, 6.28), sp["spread"] * math.sqrt(rnd.random()) * 0.95
            zz = H * (0.72 + 0.3 * (1 - (rr_ / sp["spread"]) ** 2))
            hl = sp["card"] * rnd.uniform(0.9, 1.5)
            sh = 0.75 + 0.25 * (rr_ / sp["spread"])
            card_dir(p, Vector((math.cos(a) * rr_, math.sin(a) * rr_, zz)), Vector((0, 0, 1)), rnd.uniform(0, 3.14), sp["card"] * 0.9, hl, leaf, (sh, sh, sh * 0.95, 1.0), hang=True)
    if leaf and sp["shape"] == "cone":
        top = tpts[-1]
        cs = sp["spread"] * 0.55
        for k in range((2, 2, 1)[lod]):
            card_dir(p, top - Vector((0, 0, cs * 0.75)), Vector((0, 0, 1)), k * 1.57, cs, cs * 1.25, leaf, (1, 1, 1, 0.9))
    if sp.get("fruit") and lod == 0:
        for k in range(16):
            a, rr_ = rnd.uniform(0, 6.28), sp["spread"] * rnd.uniform(0.45, 0.95)
            p.sphere((math.cos(a) * rr_, math.sin(a) * rr_, H * rnd.uniform(0.5, 0.85)), 0.045, "fruit_red", seg=6, rings=4, tint=(1, 1, 1, 0.6))
    ob = p.build(name, ao=False, smooth=60)
    foliage_normals(ob, crown_c)
    return ob, H


SPECIES = {
    "pine": dict(h=13.5, r=0.24, bark="bark_pine", leaf="leaf_pine", b0=0.5, branches=24, spread=2.9, shape="round",
                 elev=12, elev_top=28, card=2.4, style="bough", bend=0.14, droop=0.04, lean=0.02, taper=0.7),
    "fir": dict(h=12.5, r=0.26, bark="bark_pine", leaf="leaf_fir", b0=0.12, branches=34, spread=3.1, shape="cone",
                elev=-14, elev_top=30, card=2.2, style="bough", bend=0.06, droop=0.05, lean=0.0, wobble=0.012, taper=0.85),
    "oak": dict(h=9.5, r=0.42, bark="bark_oak", leaf="leaf_oak", b0=0.3, branches=15, spread=4.3, shape="round",
                elev=28, elev_top=30, card=2.7, style="cluster", bend=0.22, wobble=0.07, taper=0.6),
    "oak_autumn": dict(h=8.5, r=0.36, bark="bark_oak", leaf="leaf_autumn", b0=0.32, branches=13, spread=3.8, shape="round",
                       elev=30, elev_top=30, card=2.5, style="cluster", bend=0.22, wobble=0.07, taper=0.6),
    "birch": dict(h=11.0, r=0.15, bark="bark_birch", leaf="leaf_birch", b0=0.4, branches=14, spread=2.1, shape="round",
                  elev=42, elev_top=20, card=2.0, style="cluster", bend=0.15, droop=0.08, wobble=0.05, taper=0.75),
    "willow": dict(h=7.0, r=0.4, bark="bark_willow", leaf="leaf_willow", b0=0.4, branches=12, spread=3.6, shape="round",
                   elev=38, elev_top=15, card=1.7, style="hang", hang_len=1.8, bend=0.2, droop=0.12, wobble=0.09, taper=0.55),
    "poplar": dict(h=16.0, r=0.24, bark="bark_birch", leaf="leaf_poplar", b0=0.16, branches=22, spread=1.5, shape="column",
                   elev=62, elev_top=10, card=1.9, style="cluster", bend=0.08, taper=0.85),
    "apple": dict(h=4.2, r=0.14, bark="bark_oak", leaf="leaf_apple", b0=0.38, branches=11, spread=2.0, shape="round",
                  elev=30, elev_top=25, card=1.7, style="cluster", bend=0.2, wobble=0.08, taper=0.6),
    "apple_fruit": dict(h=4.2, r=0.14, bark="bark_oak", leaf="leaf_apple", b0=0.38, branches=11, spread=2.0, shape="round",
                        elev=30, elev_top=25, card=1.7, style="cluster", bend=0.2, wobble=0.08, taper=0.6, fruit=True),
    "dead": dict(h=8.0, r=0.3, bark="bark_dead", leaf=None, b0=0.35, branches=9, spread=2.6, shape="round",
                 elev=35, elev_top=20, card=0, style="none", bend=0.3, wobble=0.09, lean=0.06, taper=0.7),
    "sapling": dict(h=3.2, r=0.05, bark="bark_birch", leaf="leaf_birch", b0=0.3, branches=7, spread=0.9, shape="round",
                    elev=45, elev_top=15, card=1.0, style="cluster", bend=0.1, taper=0.8),
}
VARIANTS = {"pine": 2, "fir": 2, "oak": 2, "oak_autumn": 1, "birch": 2, "willow": 1, "poplar": 1, "apple": 1,
            "apple_fruit": 1, "dead": 2, "sapling": 1}
SEEDS = {"apple": 501, "apple_fruit": 501}


def plant_cards(name, mat, n, w, h, tilt, spread=0.0, seed=1, hang=False, tint=(1, 1, 1, 1), extra=None):
    rnd = random.Random(seed)
    p = vb.Parts()
    for i in range(n):
        a = math.pi * i / n + rnd.uniform(-0.15, 0.15)
        off = Vector((math.cos(a + 1.57), math.sin(a + 1.57), 0)) * spread * rnd.uniform(-1, 1)
        d = Vector((math.cos(a + 1.57) * math.sin(tilt) * (1 if i % 2 else -1), math.sin(a + 1.57) * math.sin(tilt) * (1 if i % 2 else -1), math.cos(tilt)))
        ww, hh = w * rnd.uniform(0.9, 1.1), h * rnd.uniform(0.85, 1.1)
        p.stack.append(Matrix.Translation(off) @ Matrix.Rotation(a, 4, "Z"))
        vs = [p._v(q) for q in ((-ww / 2, 0, -0.03), (ww / 2, 0, -0.03), (ww / 2 + d.x * hh * 0.3, d.y * hh, hh * d.z), (-ww / 2 + d.x * hh * 0.3, d.y * hh, hh * d.z))]
        p._face(vs, mat, uvs=[(0, 0), (1, 0), (1, 1), (0, 1)], tint=None)
        f = p.bm.faces[-1] if False else None
        p.pop()
    if extra:
        extra(p, rnd)
    p.bm.faces.ensure_lookup_table()
    for f in p.bm.faces:
        for l in f.loops:
            z = l.vert.co.z
            wgt = min(1.0, max(0.0, z / h))
            c = l[p.col]
            sh = 0.62 + 0.38 * wgt
            l[p.col] = (c[0] * sh * tint[0], c[1] * sh * tint[1], c[2] * sh * tint[2], wgt)
    ob = p.build(name, ao=False, smooth=80)
    foliage_normals(ob, (0, 0, -h * 0.5), lift=1.2)
    return ob


def mushrooms(name, seed, cap_mat):
    rnd = random.Random(seed)
    p = vb.Parts()
    for i in range(5):
        a, r = rnd.uniform(0, 6.28), rnd.uniform(0.02, 0.16)
        s = rnd.uniform(0.6, 1.25)
        x, y = math.cos(a) * r, math.sin(a) * r
        p.push((x, y, 0), (rnd.uniform(-10, 10), rnd.uniform(-10, 10), 0), (s, s, s))
        p.lathe([(0.018, -0.02), (0.016, 0.07), (0.012, 0.085)], "mushroom_stem", seg=7, close=False)
        p.lathe([(0.0, 0.078), (0.062, 0.074), (0.07, 0.086), (0.058, 0.108), (0.03, 0.124), (0.0, 0.128)], cap_mat, seg=9, close=False)
        p.pop()
    return p.build(name, ao=True, ao_dist=0.12, ao_strength=0.6, smooth=70)


def rock(name, seed, size, subdiv, flat=0.35, strata=0.0, mat="rock_boulder", moss=True):
    rnd = random.Random(seed)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=1.0)
    sx, sy, sz = size
    off = (rnd.uniform(0, 50), rnd.uniform(0, 50), rnd.uniform(0, 50))
    for v in bm.verts:
        n = v.co.normalized()
        dsp = 1.0 + 0.32 * vb.fbm((n.x * 1.3 + off[0], n.y * 1.3 + off[1], n.z * 1.3 + off[2]), 3, 1.0, seed)
        dsp += 0.1 * vb.noise3(n.x * 5 + off[0], n.y * 5, n.z * 5, seed + 3)
        co = n * dsp
        if strata > 0:
            co.z = round(co.z / strata) * strata * 0.6 + co.z * 0.4
        co = Vector((co.x * sx, co.y * sy, co.z * sz))
        if co.z < -sz * flat:
            co.z = -sz * flat + (co.z + sz * flat) * 0.15
        v.co = co + Vector((0, 0, sz * flat * 0.9))
    p = vb.Parts()
    bm.normal_update()
    vmap = {v: p.bm.verts.new(v.co) for v in bm.verts}
    for f in bm.faces:
        up = max(0.0, f.normal.z)
        g = 0.72 + 0.28 * up
        tint = (g * (1 - 0.25 * up * moss), g, g * (1 - 0.35 * up * moss), 1.0) if moss else (g, g, g, 1.0)
        p._face([vmap[v] for v in f.verts], mat, tint=tint)
    bm.free()
    return p.build(name, ao=True, ao_dist=max(sx, sz) * 0.6, ao_strength=0.5, ao_samples=10, smooth=75, ground=0.0)


def stump(name):
    p = vb.Parts()
    rnd = random.Random(4)
    prof = [(0.5, -0.2), (0.4, 0.05), (0.34, 0.3), (0.33, 0.55)]
    p.lathe(prof, "bark_oak", seg=10, close=False)
    p.lathe([(0.0, 0.57), (0.2, 0.56), (0.33, 0.55)], "wood_end", seg=10, close=False)
    for i in range(4):
        a = i * 1.57 + 0.4
        p.tube([(math.cos(a) * 0.3, math.sin(a) * 0.3, 0.12), (math.cos(a) * 0.75, math.sin(a) * 0.75, -0.08), (math.cos(a) * 1.0, math.sin(a) * 1.0, -0.2)], [0.12, 0.07, 0.03], "bark_oak", seg=5, cap=False)
    return p.build(name, ao=True, ao_dist=0.5, smooth=70)


def log(name):
    p = vb.Parts()
    pts = [(-1.9, 0, 0.3), (-0.6, 0.05, 0.3), (0.7, -0.04, 0.31), (2.0, 0.06, 0.28)]
    p.tube(pts, [0.3, 0.28, 0.26, 0.24], "bark_oak", seg=9, cap=False)
    p.lathe([(0.0, 0.0), (0.3, 0.0)], "wood_end", seg=9, c=(-1.9, 0, 0.3), rot=(0, -90, 0), close=False)
    p.lathe([(0.0, 0.0), (0.24, 0.0)], "wood_end", seg=9, c=(2.0, 0.06, 0.28), rot=(0, 90, 0), close=False)
    p.tube([(0.4, 0, 0.5), (0.5, 0.25, 0.95), (0.45, 0.4, 1.3)], [0.08, 0.05, 0.02], "bark_oak", seg=5, cap=False)
    return p.build(name, ao=True, ao_dist=0.6, smooth=70)


def run():
    vb.reset()
    out = []
    for sp_name, sp in SPECIES.items():
        for var in range(VARIANTS[sp_name]):
            for lod in range(3):
                nm = f"tree_{sp_name}_{'ab'[var]}_lod{lod}"
                ob, H = make_tree(nm, SEEDS.get(sp_name, hash(sp_name) % 1000 * 0 + sum(map(ord, sp_name))) + var * 31, lod, sp)
                vb.export([ob], "vegetation/" + nm)
                if lod == 0:
                    META[f"tree_{sp_name}_{'ab'[var]}"] = {"trunk_r": round(sp["r"] * 0.9, 3), "h": round(H, 2), "lods": 3}
                META.setdefault("_tris", {})[nm] = vb.tris(ob)
                vb.clear_objects()

    def single(ob, solid_r=0.0, h=1.0):
        vb.export([ob], "vegetation/" + ob.name)
        META[ob.name] = {"trunk_r": solid_r, "h": h, "lods": 1}
        META["_tris"][ob.name] = vb.tris(ob)
        vb.clear_objects()

    single(plant_cards("bush_a", "leaf_bush", 4, 1.9, 1.5, 0.25, 0.25, 1), 0.0, 1.5)
    single(plant_cards("bush_b", "leaf_bush_dark", 4, 2.3, 1.9, 0.2, 0.3, 2), 0.0, 1.9)
    single(plant_cards("bush_berry", "leaf_bush_berry", 4, 1.7, 1.35, 0.25, 0.2, 3), 0.0, 1.35)
    single(plant_cards("bush_berry_empty", "leaf_bush", 4, 1.7, 1.35, 0.25, 0.2, 3), 0.0, 1.35)
    single(plant_cards("fern", "leaf_fern", 3, 1.2, 0.8, 0.75, 0.05, 4), 0.0, 0.8)
    single(plant_cards("grass_a", "grass_tuft", 3, 0.9, 0.62, 0.18, 0.08, 5), 0.0, 0.6)
    single(plant_cards("grass_b", "grass_dry", 3, 0.95, 0.7, 0.18, 0.08, 6), 0.0, 0.7)
    single(plant_cards("grass_flowers", "grass_flowers", 3, 0.9, 0.62, 0.2, 0.08, 7), 0.0, 0.6)
    single(plant_cards("reeds", "reed", 3, 1.5, 2.0, 0.08, 0.2, 8), 0.0, 2.0)
    single(plant_cards("herb_plant", "herb", 3, 0.7, 0.75, 0.2, 0.04, 9), 0.0, 0.75)
    single(plant_cards("herb_plant_empty", "leaf_fern", 2, 0.4, 0.25, 0.6, 0.02, 9), 0.0, 0.25)
    single(plant_cards("fiber_plant", "fiber_plant", 3, 0.8, 0.9, 0.2, 0.04, 10), 0.0, 0.9)
    single(plant_cards("fiber_plant_empty", "grass_dry", 2, 0.4, 0.25, 0.3, 0.02, 10), 0.0, 0.25)
    single(mushrooms("mushrooms", 3, "mushroom_cap"), 0.0, 0.15)
    single(stump("stump"), 0.4, 0.6)
    single(log("fallen_log"), 0.0, 0.6)
    single(rock("rock_a", 1, (0.9, 0.75, 0.6), 2), 0.7, 0.9)
    single(rock("rock_b", 2, (1.6, 1.2, 1.0), 2), 1.2, 1.5)
    single(rock("rock_c", 3, (2.6, 2.0, 1.9), 3, mat="rock_mossy"), 2.0, 2.8)
    single(rock("rock_d", 4, (0.45, 0.4, 0.25), 1), 0.0, 0.3)
    single(rock("rock_e", 5, (3.8, 2.6, 3.4), 3, flat=0.2, strata=0.35, mat="rock_cliff", moss=False), 2.6, 5.5)
    single(rock("cliff_a", 6, (7.5, 4.0, 6.5), 3, flat=0.15, strata=0.3, mat="rock_cliff", moss=False), 4.5, 10.0)
    single(rock("stone_pile", 7, (0.7, 0.6, 0.35), 2, mat="rock_boulder", moss=False), 0.5, 0.5)
    for k, v in sorted(META["_tris"].items()):
        print(f"TRIS {k}: {v}")
    vb.write_json("models/vegetation.json", {k: v for k, v in META.items() if k != "_tris"})


run()
