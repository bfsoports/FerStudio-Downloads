#!/usr/bin/env python3
"""Prepara para Android los modelos propios del usuario (GLB generados con Tripo, una malla y una textura cada uno).

Los GLB originales traen entre 17.000 y 104.000 triángulos por objeto (la cocina entera de KayKit suma unos 37.000),
así que aquí se simplifican con colapso de aristas por error cuadrático (QEM, Garland-Heckbert) en su variante de
"medio colapso": el vértice que sobrevive conserva su posición, su normal y su UV originales, de modo que la textura
no se re-hornea ni se deforma. Las costuras UV se respetan:
  - un vértice de costura solo se puede eliminar deslizándolo a lo largo de su propia costura y si cada copia (UV) del
    vértice tiene su pareja en el vértice destino; los cruces de costuras y los bordes abiertos quedan bloqueados;
  - se rechaza cualquier colapso que dé la vuelta a un triángulo en 3D o en el espacio UV, o que rompa la variedad.
  - se rechaza también cualquier cara nueva cuyo triángulo UV pise texeles de otra isla o del fondo del atlas, y el
    desplazamiento de la textura en el punto eliminado no puede pasar de MAX_TEXEL_SHIFT texeles (y entra en el coste).
La textura conserva su resolución (512 px); solo se rellena el fondo negro entre islas con el color de la isla más
cercana (relleno de bordes) y se guarda como JPEG de calidad 92. Solo se usan numpy y Pillow.

Uso:
  python3 tools/optimize_models.py <carpeta_con_los_glb_originales>
      -> escribe assets/models/custom/<nombre>.glb para cada entrada de SPEC
"""
import heapq
import io
import json
import os
import struct
import sys

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEST = os.path.join(ROOT, "assets", "models", "custom")

# (archivo original, archivo de salida, triángulos objetivo)
# Los objetos que se ven de cerca (freidora, dispensador, bote) conservan más detalle; las lámparas, en el techo, menos.
SPEC = [
    ("Freidora_de_patatas.glb", "fryer.glb", 18000),
    ("dispensador_de_bebidas.glb", "drink_dispenser.glb", 14000),
    ("l_mpara_colgante.glb", "pendant_lamp.glb", 2000),
    ("planta_en_maceta.glb", "potted_plant.glb", 5000),
    ("campanita_de_servicio.glb", "service_bell.glb", 3000),
    ("bote_de_basura.glb", "trash_can.glb", 7000),
    ("bandeja_de_servicio.glb", "serving_tray.glb", 2500),
]
MAX_TEXEL_SHIFT = 1.25   # desplazamiento máximo de la textura en un vértice eliminado (texeles)

CT = {5126: np.float32, 5125: np.uint32, 5123: np.uint16, 5121: np.uint8}
NC = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


# ------------------------------------------------------------------ lectura y escritura de GLB
def read_glb(path):
    data = open(path, "rb").read()
    off, js, binc = 12, None, None
    while off < len(data):
        ln, ty = struct.unpack("<II", data[off:off + 8])
        chunk = data[off + 8:off + 8 + ln]
        if ty == 0x4E4F534A:
            js = json.loads(chunk)
        elif ty == 0x004E4942:
            binc = chunk
        off += 8 + ln
    return js, binc


def accessor(js, binc, idx):
    a = js["accessors"][idx]
    bv = js["bufferViews"][a["bufferView"]]
    if bv.get("byteStride"):
        raise ValueError("accesor intercalado no soportado")
    n = NC[a["type"]]
    arr = np.frombuffer(binc, dtype=CT[a["componentType"]], count=a["count"] * n,
                        offset=bv.get("byteOffset", 0) + a.get("byteOffset", 0)).copy()
    return arr.reshape(-1, n) if n > 1 else arr


def load_single_mesh(path):
    js, binc = read_glb(path)
    if len(js["meshes"]) != 1 or len(js["meshes"][0]["primitives"]) != 1:
        raise ValueError("%s: se esperaba una malla con una primitiva" % path)
    if len(js["nodes"]) != 1 or any(k in js["nodes"][0] for k in ("matrix", "rotation", "scale")):
        raise ValueError("%s: se esperaba un nodo con, como mucho, una traslación" % path)
    pr = js["meshes"][0]["primitives"][0]
    # la traslación del nodo (Tripo deja desplazamientos de décimas de milímetro) se aplica a los vértices
    P = accessor(js, binc, pr["attributes"]["POSITION"]).astype(np.float64) + np.array(js["nodes"][0].get("translation", [0, 0, 0]))
    N = accessor(js, binc, pr["attributes"]["NORMAL"]).astype(np.float64)
    UV = accessor(js, binc, pr["attributes"]["TEXCOORD_0"]).astype(np.float64)
    F = accessor(js, binc, pr["indices"]).reshape(-1, 3).astype(np.int64)
    img = js["images"][0]
    bv = js["bufferViews"][img["bufferView"]]
    tex = binc[bv.get("byteOffset", 0):bv.get("byteOffset", 0) + bv["byteLength"]]
    mat = js["materials"][pr["material"]] if "material" in pr else {}
    return P, N, UV, F, tex, img.get("mimeType", "image/jpeg"), mat


def write_glb(path, name, P, N, UV, F, tex, mime, mat):
    P = P.astype(np.float32)
    N = N.astype(np.float32)
    nl = np.linalg.norm(N, axis=1)
    nl[nl < 1e-12] = 1.0
    N = (N / nl[:, None]).astype(np.float32)
    UV = UV.astype(np.float32)
    idx = F.reshape(-1).astype(np.uint16 if len(P) < 65536 else np.uint32)
    blobs, views = [], []

    def add(b, target=None):
        off = sum(len(x) for x in blobs)
        blobs.append(b + b"\0" * ((4 - len(b) % 4) % 4))
        v = {"buffer": 0, "byteOffset": off, "byteLength": len(b)}
        if target:
            v["target"] = target
        views.append(v)
        return len(views) - 1

    vp = add(P.tobytes(), 34962)
    vn = add(N.tobytes(), 34962)
    vu = add(UV.tobytes(), 34962)
    vi = add(idx.tobytes(), 34963)
    vt = add(tex)
    accessors = [
        {"bufferView": vp, "componentType": 5126, "count": len(P), "type": "VEC3",
         "min": P.min(0).tolist(), "max": P.max(0).tolist()},
        {"bufferView": vn, "componentType": 5126, "count": len(N), "type": "VEC3"},
        {"bufferView": vu, "componentType": 5126, "count": len(UV), "type": "VEC2"},
        {"bufferView": vi, "componentType": 5123 if idx.dtype == np.uint16 else 5125, "count": len(idx), "type": "SCALAR"},
    ]
    pbr = dict(mat.get("pbrMetallicRoughness", {}))
    pbr["baseColorTexture"] = {"index": 0}
    material = {"name": name, "pbrMetallicRoughness": pbr}
    for k in ("doubleSided", "alphaMode", "alphaCutoff"):
        if k in mat:
            material[k] = mat[k]
    js = {
        "asset": {"version": "2.0", "generator": "BurgerChef3D tools/optimize_models.py (origen: Tripo)"},
        "scene": 0, "scenes": [{"nodes": [0]}],
        "nodes": [{"name": name, "mesh": 0}],
        "meshes": [{"name": name, "primitives": [{"attributes": {"POSITION": 0, "NORMAL": 1, "TEXCOORD_0": 2},
                                                  "indices": 3, "material": 0}]}],
        "materials": [material],
        "textures": [{"source": 0, "sampler": 0}],
        "samplers": [{"magFilter": 9729, "minFilter": 9987, "wrapS": 10497, "wrapT": 10497}],
        "images": [{"bufferView": vt, "mimeType": mime}],
        "accessors": accessors, "bufferViews": views,
        "buffers": [{"byteLength": sum(len(x) for x in blobs)}],
    }
    jb = json.dumps(js, separators=(",", ":")).encode("utf8")
    jb += b" " * ((4 - len(jb) % 4) % 4)
    bb = b"".join(blobs)
    total = 12 + 8 + len(jb) + 8 + len(bb)
    with open(path, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, total))
        f.write(struct.pack("<II", len(jb), 0x4E4F534A) + jb)
        f.write(struct.pack("<II", len(bb), 0x004E4942) + bb)


# ------------------------------------------------------------------ islas UV y relleno de la textura
def island_mask(UV, F, island, px):
    """Rasteriza las caras originales en el espacio UV: cada texel guarda el id (+1) de su isla, 0 = fondo."""
    from PIL import Image, ImageDraw
    ids = {}
    img = Image.new("I", (px, px), 0)
    d = ImageDraw.Draw(img)
    for f in F:
        iid = ids.setdefault(island[int(f[0])], len(ids) + 1)
        d.polygon([(float(UV[w, 0]) * px - 0.5, float(UV[w, 1]) * px - 0.5) for w in f], fill=iid, outline=iid)
    m = np.array(img, dtype=np.int64)
    # cada texel acepta también las islas de sus 8 vecinos (tolerancia de 1 texel en los bordes)
    sets = [[set() for _ in range(px)] for _ in range(px)]
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            sh = np.roll(np.roll(m, dy, 0), dx, 1)
            ys, xs = np.nonzero(sh)
            for y, x in zip(ys.tolist(), xs.tolist()):
                sets[y][x].add(int(sh[y, x]))
    return {"sets": sets, "ids": ids}


def inside_island(mask, uvs, isl, px):
    """True si todos los texeles que cubre el triángulo UV pertenecen (con 1 texel de tolerancia) a la isla isl."""
    iid = mask["ids"].get(isl)
    sets = mask["sets"]
    xs = [u[0] * px for u in uvs]
    ys = [u[1] * px for u in uvs]
    pts = [((xs[0] + xs[1] + xs[2]) / 3, (ys[0] + ys[1] + ys[2]) / 3)]
    for a, b in ((0, 1), (1, 2), (2, 0)):
        pts.append(((xs[a] + xs[b]) / 2, (ys[a] + ys[b]) / 2))
    x0, x1 = int(min(xs)), int(max(xs)) + 1
    y0, y1 = int(min(ys)), int(max(ys)) + 1
    if (x1 - x0) * (y1 - y0) > 4:
        den = (ys[1] - ys[2]) * (xs[0] - xs[2]) + (xs[2] - xs[1]) * (ys[0] - ys[2])
        if abs(den) > 1e-12:
            for y in range(y0, y1):
                for x in range(x0, x1):
                    cx, cy = x + 0.5, y + 0.5
                    w0 = ((ys[1] - ys[2]) * (cx - xs[2]) + (xs[2] - xs[1]) * (cy - ys[2])) / den
                    w1 = ((ys[2] - ys[0]) * (cx - xs[2]) + (xs[0] - xs[2]) * (cy - ys[2])) / den
                    if w0 >= 0 and w1 >= 0 and 1 - w0 - w1 >= 0:
                        pts.append((cx, cy))
    for x, y in pts:
        xi, yi = int(x) % px, int(y) % px
        if iid not in sets[yi][xi]:
            return False
    return True


def pad_texture(tex_bytes, UV, F, px_hint=None, rings=12):
    """Rellena el fondo del atlas (texeles sin isla) con el color de la isla más cercana, para que el filtrado, los
    mipmaps y los bordes de las caras simplificadas no muestren el fondo negro. Devuelve JPEG (calidad 92)."""
    from PIL import Image, ImageDraw
    im = Image.open(io.BytesIO(tex_bytes)).convert("RGB")
    w, h = im.size
    cov = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(cov)
    for f in F:
        d.polygon([(float(UV[k, 0]) * w - 0.5, float(UV[k, 1]) * h - 0.5) for k in f], fill=255, outline=255)
    a = np.array(im, dtype=np.float64)
    m = np.array(cov) > 0
    for _ in range(rings):
        acc = np.zeros_like(a)
        cnt = np.zeros(m.shape)
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                if dx == 0 and dy == 0:
                    continue
                mm = np.roll(np.roll(m, dy, 0), dx, 1)
                acc += np.roll(np.roll(a, dy, 0), dx, 1) * mm[..., None]
                cnt += mm
        grow = (~m) & (cnt > 0)
        a[grow] = acc[grow] / cnt[grow, None]
        m = m | grow
    out = io.BytesIO()
    Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)).save(out, "JPEG", quality=92, optimize=True)
    return out.getvalue()


# ------------------------------------------------------------------ simplificación
def simplify(P, N, UV, F, target, tex_px=512, max_texel_shift=2.0):
    nw = len(P)
    # soldar copias de un mismo punto (las costuras UV duplican vértices)
    key = np.round(P / (np.abs(P).max() * 1e-6 + 1e-12)).astype(np.int64)
    _, pid_of = np.unique(key, axis=0, return_inverse=True)
    pid_of = pid_of.reshape(-1)
    npid = int(pid_of.max()) + 1
    pos = np.zeros((npid, 3))
    pos[pid_of] = P
    pos_l = pos.tolist()
    uv_l = UV.tolist()
    pidw = pid_of.tolist()
    faces = F.tolist()
    alive = [True] * len(faces)
    vf = [set() for _ in range(npid)]
    for fi, f in enumerate(faces):
        for w in f:
            vf[pidw[w]].add(fi)
    # quádricas de plano ponderadas por área
    tri = pos[pid_of[F]]
    nrm = np.cross(tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0])
    area2 = np.linalg.norm(nrm, axis=1)
    ok = area2 > 1e-20
    nu = np.zeros_like(nrm)
    nu[ok] = nrm[ok] / area2[ok, None]
    d = -np.einsum("ij,ij->i", nu, tri[:, 0])
    plane = np.c_[nu, d]
    K = np.einsum("i,ij,ik->ijk", area2 * 0.5, plane, plane)
    Q = np.zeros((npid, 4, 4))
    for c in range(3):
        np.add.at(Q, pid_of[F[:, c]], K)
    # aristas soldadas: bordes abiertos y costuras
    edge_faces = {}
    for fi, f in enumerate(faces):
        for a, b in ((0, 1), (1, 2), (2, 0)):
            pa, pb = pidw[f[a]], pidw[f[b]]
            edge_faces.setdefault((min(pa, pb), max(pa, pb)), []).append((fi, f[a], f[b]))
    locked = [False] * npid
    scale = float(np.linalg.norm(pos.max(0) - pos.min(0)))
    seam_w = 4.0
    for (pa, pb), lst in edge_faces.items():
        if len(lst) != 2:
            locked[pa] = locked[pb] = True
            continue
        (f1, a1, b1), (f2, a2, b2) = lst
        wa1 = a1 if pidw[a1] == pa else b1
        wb1 = b1 if pidw[b1] == pb else a1
        wa2 = a2 if pidw[a2] == pa else b2
        wb2 = b2 if pidw[b2] == pb else a2
        if wa1 != wa2 or wb1 != wb2:
            # costura: plano perpendicular a la cara que contiene la arista, para que la costura no se deforme
            e = pos[pb] - pos[pa]
            for fi in (f1, f2):
                n = nu[fi]
                pn = np.cross(e, n)
                ln = np.linalg.norm(pn)
                if ln < 1e-15:
                    continue
                pn /= ln
                pl = np.r_[pn, -pn @ pos[pa]]
                k = np.outer(pl, pl) * seam_w * float(e @ e)
                Q[pa] += k
                Q[pb] += k
    # islas UV: componentes conexas de las caras que comparten copias de vértice; mapa de islas a la resolución
    # de la textura (dilatado 1 texel) para rechazar caras nuevas que pisen otra isla o el fondo del atlas
    parent = list(range(nw))

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    for f in faces:
        ra = find(f[0])
        for w in f[1:]:
            rb = find(w)
            if rb != ra:
                parent[rb] = ra
    island = [find(w) for w in range(nw)]
    imask = island_mask(UV, F, island, tex_px)
    Ql = [q for q in Q]
    ver = [0] * npid
    palive = [True] * npid
    # el error de textura (en texeles) entra en el coste: un texel de desplazamiento cuesta como un error geométrico
    # de geo_per_texel metros (al cuadrado) sobre el área del vértice
    geo_per_texel = scale * 0.002

    def neighbors(p):
        s = set()
        for fi in vf[p]:
            for w in faces[fi]:
                s.add(pidw[w])
        s.discard(p)
        return s

    def fnormal(a, b, c):
        ux, uy, uz = b[0] - a[0], b[1] - a[1], b[2] - a[2]
        vx, vy, vz = c[0] - a[0], c[1] - a[1], c[2] - a[2]
        return (uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx)

    def uvarea(a, b, c):
        return (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])

    def bary(p, a, b, c):
        v0 = [b[i] - a[i] for i in range(3)]
        v1 = [c[i] - a[i] for i in range(3)]
        v2 = [p[i] - a[i] for i in range(3)]
        d00 = v0[0] * v0[0] + v0[1] * v0[1] + v0[2] * v0[2]
        d01 = v0[0] * v1[0] + v0[1] * v1[1] + v0[2] * v1[2]
        d11 = v1[0] * v1[0] + v1[1] * v1[1] + v1[2] * v1[2]
        d20 = v2[0] * v0[0] + v2[1] * v0[1] + v2[2] * v0[2]
        d21 = v2[0] * v1[0] + v2[1] * v1[1] + v2[2] * v1[2]
        den = d00 * d11 - d01 * d01
        if abs(den) < 1e-30:
            return None
        bv = (d11 * d20 - d01 * d21) / den
        bw = (d00 * d21 - d01 * d20) / den
        return (1.0 - bv - bw, bv, bw)

    def evaluate(u, v):
        """Comprueba el colapso u -> v. Devuelve (coste, wmap, shared, others) o None si no es válido."""
        if locked[u] or not (palive[u] and palive[v]):
            return None
        fu = vf[u]
        shared = [fi for fi in fu if any(pidw[w] == v for w in faces[fi])]
        if len(shared) != 2:
            return None
        wmap = {}
        opp = set()
        for fi in shared:
            f = faces[fi]
            wu = next(w for w in f if pidw[w] == u)
            wv = next(w for w in f if pidw[w] == v)
            if wmap.setdefault(wu, wv) != wv:
                return None
            for w in f:
                if pidw[w] not in (u, v):
                    opp.add(pidw[w])
        others = [fi for fi in fu if fi not in shared]
        for fi in others:
            for w in faces[fi]:
                if pidw[w] == u and w not in wmap:
                    return None
        if (neighbors(u) & neighbors(v)) != opp:
            return None
        pv = pos_l[v]
        pu = pos_l[u]
        for fi in others:
            f = faces[fi]
            pts = [pos_l[pidw[w]] for w in f]
            new = [pv if pidw[w] == u else pos_l[pidw[w]] for w in f]
            n0 = fnormal(*pts)
            n1 = fnormal(*new)
            l0 = (n0[0] ** 2 + n0[1] ** 2 + n0[2] ** 2) ** 0.5
            l1 = (n1[0] ** 2 + n1[1] ** 2 + n1[2] ** 2) ** 0.5
            if l1 < 1e-14 or l0 < 1e-14 or (n0[0] * n1[0] + n0[1] * n1[1] + n0[2] * n1[2]) < 0.35 * l0 * l1:
                return None
            a0 = uvarea(*[uv_l[w] for w in f])
            a1 = uvarea(*[uv_l[wmap.get(w, w)] for w in f])
            if a0 * a1 <= 0.0 or abs(a1) < 1e-12:
                return None
            if not inside_island(imask, [uv_l[wmap.get(w, w)] for w in f], island[f[0]], tex_px):
                return None
        # desplazamiento de la textura en el punto donde estaba u, para cada copia (isla UV) de u
        tex_err = 0.0
        for wu, wv in wmap.items():
            best, best_uv = -1e9, None
            for fi in others:
                f = faces[fi]
                if wu not in f:
                    continue
                nf = [wmap.get(w, w) for w in f]
                b = bary(pu, *[pos_l[pidw[w]] for w in nf])
                if b is None:
                    continue
                m = min(b)
                if m > best:
                    best = m
                    best_uv = [sum(b[k] * uv_l[nf[k]][j] for k in range(3)) for j in range(2)]
            if best_uv is None:
                best_uv = uv_l[wv]
            du = (best_uv[0] - uv_l[wu][0]) * tex_px
            dv = (best_uv[1] - uv_l[wu][1]) * tex_px
            tex_err = max(tex_err, (du * du + dv * dv) ** 0.5)
        if tex_err > max_texel_shift:
            return None
        h = np.array([pv[0], pv[1], pv[2], 1.0])
        q = max(float(h @ Ql[u] @ h), 0.0)
        area_u = float(Ql[u][0, 0] + Ql[u][1, 1] + Ql[u][2, 2])
        c = q + area_u * (tex_err * geo_per_texel) ** 2
        return c, wmap, shared, others

    heap = []

    def push(u, v):
        r = evaluate(u, v)
        if r is not None:
            heapq.heappush(heap, (r[0], u, v, ver[u], ver[v]))

    for (pa, pb) in edge_faces:
        push(pa, pb)
        push(pb, pa)

    nfaces = len(faces)
    while nfaces > target and heap:
        c0, u, v, vu, vv = heapq.heappop(heap)
        if not (palive[u] and palive[v]) or ver[u] != vu or ver[v] != vv:
            continue
        r = evaluate(u, v)
        if r is None:
            continue
        c, wmap, shared, others = r
        if c > c0 * 1.0001 + 1e-18:
            heapq.heappush(heap, (c, u, v, ver[u], ver[v]))
            continue
        for fi in shared:
            alive[fi] = False
            for w in faces[fi]:
                vf[pidw[w]].discard(fi)
            nfaces -= 1
        for fi in others:
            faces[fi] = [wmap.get(w, w) for w in faces[fi]]
            vf[v].add(fi)
        vf[u] = set()
        palive[u] = False
        Ql[v] = Ql[v] + Ql[u]
        ver[v] += 1
        nb = neighbors(v)
        for n in nb:
            ver[n] += 1
        for n in nb:
            push(v, n)
            push(n, v)
            for m in neighbors(n):
                if m != v:
                    push(n, m)
    F2 = np.array([f for fi, f in enumerate(faces) if alive[fi]], dtype=np.int64)
    used = np.unique(F2)
    remap = -np.ones(nw, dtype=np.int64)
    remap[used] = np.arange(len(used))
    return P[used], N[used], UV[used], remap[F2]


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    src = sys.argv[1]
    os.makedirs(DEST, exist_ok=True)
    for fname, out, target in SPEC:
        P, N, UV, F, tex, mime, mat = load_single_mesh(os.path.join(src, fname))
        from PIL import Image
        px = Image.open(io.BytesIO(tex)).size[0]
        P2, N2, UV2, F2 = simplify(P, N, UV, F, target, tex_px=px, max_texel_shift=MAX_TEXEL_SHIFT)
        tex2 = pad_texture(tex, UV, F)
        name = os.path.splitext(out)[0]
        write_glb(os.path.join(DEST, out), name, P2, N2, UV2, F2, tex2, "image/jpeg", mat)
        print("%-28s %6d -> %5d triángulos, %5d vértices, %4d KB" % (
            fname, len(F), len(F2), len(P2), os.path.getsize(os.path.join(DEST, out)) // 1024))


if __name__ == "__main__":
    main()
