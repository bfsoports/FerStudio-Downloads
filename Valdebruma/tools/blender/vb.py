"""vb.py — biblioteca de modelado por script de Valdebruma (Blender 4.2 LTS, modo -b).

Responsabilidad: construir mallas con UV en metros, sombreado suave/duro, oclusión
ambiental horneada en color de vértice y exportarlas a GLB. Los materiales del GLB
solo llevan NOMBRE: Godot los sustituye por `assets/materials/<nombre>.tres`.

Convenio de ejes al modelar: X derecha, Y fondo, Z arriba (Blender). El frente de
edificios y muebles mira a −Y (queda en +Z local de Godot). `g3()` convierte un
punto a coordenadas Godot para los metadatos JSON.
"""
import bpy, bmesh, math, random, json, os
from mathutils import Vector, Matrix, Euler
from mathutils.bvhtree import BVHTree

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
MODELS = os.path.join(ROOT, "assets", "models")
DATA = os.path.join(ROOT, "data")

# Color de previsualización por prefijo de material (solo ayuda visual en Blender).
_PREVIEW = {"wood": (0.45, 0.32, 0.2), "metal": (0.4, 0.42, 0.45), "plaster": (0.85, 0.82, 0.75),
            "brick": (0.6, 0.3, 0.25), "roof": (0.5, 0.25, 0.2), "glass": (0.6, 0.75, 0.8),
            "leaf": (0.25, 0.45, 0.2), "bark": (0.3, 0.25, 0.2), "rock": (0.5, 0.5, 0.48)}


def g3(v):
    """Punto Blender (x, y, z) -> Godot [x, y, z]."""
    return [round(v[0], 4), round(v[2], 4), round(-v[1], 4)]


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def material(name):
    m = bpy.data.materials.get(name)
    if m is None:
        m = bpy.data.materials.new(name)
        col = (0.6, 0.6, 0.6)
        for k, c in _PREVIEW.items():
            if name.startswith(k):
                col = c
        m.diffuse_color = (*col, 1.0)
    return m


def rot_m(rot):
    """Matriz de rotación a partir de grados XYZ."""
    return Euler([math.radians(a) for a in rot], "XYZ").to_matrix().to_4x4()


class Parts:
    """Acumulador de geometría. Cada primitiva acepta material por nombre."""

    def __init__(self):
        self.bm = bmesh.new()
        self.mats = []
        self.uv = self.bm.loops.layers.uv.new("UVMap")
        self.col = self.bm.loops.layers.color.new("Col")
        self.lock = self.bm.faces.layers.int.new("uvlock")
        self.flag = self.bm.faces.layers.int.new("flag")
        self.cur_flag = 0
        self.stack = [Matrix.Identity(4)]

    # ---- transformaciones anidadas -------------------------------------------------
    @property
    def M(self):
        return self.stack[-1]

    def push(self, loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1)):
        m = Matrix.Translation(loc) @ rot_m(rot) @ Matrix.Diagonal((*scale, 1.0))
        self.stack.append(self.M @ m)
        return self

    def pop(self):
        self.stack.pop()

    def __enter__(self):
        return self

    def __exit__(self, *a):
        self.pop()

    # ---- utilidades -----------------------------------------------------------------
    def mi(self, name):
        if name not in self.mats:
            self.mats.append(name)
        return self.mats.index(name)

    def _face(self, verts, mat, uvs=None, tint=None, smooth=True):
        try:
            f = self.bm.faces.new(verts)
        except ValueError:
            return None
        f.material_index = self.mi(mat)
        f.smooth = smooth
        f[self.flag] = self.cur_flag
        if uvs is not None:
            f[self.lock] = 1
            for l, uv in zip(f.loops, uvs):
                l[self.uv].uv = uv
        c = (1, 1, 1, 1) if tint is None else (*tint[:3], tint[3] if len(tint) > 3 else 1.0)
        for l in f.loops:
            l[self.col] = c
        return f

    def _v(self, co, m=None):
        return self.bm.verts.new((m if m is not None else self.M) @ Vector(co))

    # ---- primitivas -----------------------------------------------------------------
    def box(self, c, s, mat, rot=(0, 0, 0), mats=None, skip=(), tint=None):
        """Caja centrada en c con tamaño s. mats: dict cara->material ('+x','-z'...)."""
        m = self.M @ Matrix.Translation(c) @ rot_m(rot)
        hx, hy, hz = s[0] / 2, s[1] / 2, s[2] / 2
        v = [self._v((x, y, z), m) for z in (-hz, hz) for y in (-hy, hy) for x in (-hx, hx)]
        faces = {"-z": (0, 2, 3, 1), "+z": (4, 5, 7, 6), "-y": (0, 1, 5, 4),
                 "+y": (2, 6, 7, 3), "-x": (0, 4, 6, 2), "+x": (1, 3, 7, 5)}
        out = []
        for k, idx in faces.items():
            if k in skip:
                continue
            fm = mats.get(k, mat) if mats else mat
            if fm is None:
                continue
            out.append(self._face([v[i] for i in idx], fm, tint=tint, smooth=False))
        return out

    def cyl(self, c, r, h, mat, seg=12, r2=None, rot=(0, 0, 0), caps=True, cap_mat=None,
            tint=None, vscale=1.0):
        """Cilindro/cono con eje Z local centrado en c. UV cilíndrica en metros."""
        r2 = r if r2 is None else r2
        m = self.M @ Matrix.Translation(c) @ rot_m(rot)
        ring0, ring1 = [], []
        for i in range(seg):
            a = 2 * math.pi * i / seg
            ring0.append(self._v((r * math.cos(a), r * math.sin(a), -h / 2), m))
            ring1.append(self._v((r2 * math.cos(a), r2 * math.sin(a), h / 2), m))
        per = 2 * math.pi * max(r, r2)
        for i in range(seg):
            j = (i + 1) % seg
            u0, u1 = per * i / seg, per * (i + 1) / seg
            self._face([ring0[i], ring0[j], ring1[j], ring1[i]], mat,
                       uvs=[(u0, 0), (u1, 0), (u1, h * vscale), (u0, h * vscale)], tint=tint)
        if caps:
            cm = cap_mat or mat
            if r > 1e-5:
                self._face(list(reversed(ring0)), cm, tint=tint, smooth=False)
            if r2 > 1e-5:
                self._face(ring1, cm, tint=tint, smooth=False)

    def lathe(self, profile, mat, seg=16, c=(0, 0, 0), rot=(0, 0, 0), tint=None, mats=None,
              close=True):
        """Superficie de revolución alrededor de Z. profile: [(radio, z), ...] de abajo arriba."""
        m = self.M @ Matrix.Translation(c) @ rot_m(rot)
        rings = []
        for r, z in profile:
            if r < 1e-5:
                rings.append([self._v((0, 0, z), m)])
            else:
                rings.append([self._v((r * math.cos(2 * math.pi * i / seg),
                                       r * math.sin(2 * math.pi * i / seg), z), m)
                              for i in range(seg)])
        vdist = 0.0
        for k in range(len(rings) - 1):
            a, b = rings[k], rings[k + 1]
            (r0, z0), (r1, z1) = profile[k], profile[k + 1]
            d = math.hypot(r1 - r0, z1 - z0)
            fm = mats[k] if mats else mat
            per = 2 * math.pi * max(r0, r1, 0.01)
            for i in range(seg):
                j = (i + 1) % seg
                u0, u1 = per * i / seg, per * (i + 1) / seg
                if len(a) == 1 and len(b) == 1:
                    continue
                if len(a) == 1:
                    self._face([a[0], b[j], b[i]], fm, uvs=[((u0 + u1) / 2, vdist), (u1, vdist + d), (u0, vdist + d)], tint=tint)
                elif len(b) == 1:
                    self._face([a[i], a[j], b[0]], fm, uvs=[(u0, vdist), (u1, vdist), ((u0 + u1) / 2, vdist + d)], tint=tint)
                else:
                    self._face([a[i], a[j], b[j], b[i]], fm,
                               uvs=[(u0, vdist), (u1, vdist), (u1, vdist + d), (u0, vdist + d)], tint=tint)
            vdist += d
        if close:
            if len(rings[0]) > 1:
                self._face(list(reversed(rings[0])), mats[0] if mats else mat, tint=tint, smooth=False)
            if len(rings[-1]) > 1:
                self._face(rings[-1], mats[-1] if mats else mat, tint=tint, smooth=False)

    def sphere(self, c, r, mat, seg=12, rings=8, scale=(1, 1, 1), rot=(0, 0, 0), tint=None):
        prof = []
        for k in range(rings + 1):
            a = -math.pi / 2 + math.pi * k / rings
            prof.append((max(0.0, r * math.cos(a)) if 0 < k < rings else 0.0, r * math.sin(a)))
        self.push(c, rot, scale)
        self.lathe(prof, mat, seg=seg, tint=tint, close=False)
        self.pop()

    def tube(self, pts, radii, mat, seg=6, uscale=1.0, vscale=1.0, tint=None, cap=True, v0=0.0):
        """Tubo a lo largo de una polilínea con radios por punto. UV en metros (bloqueada)."""
        pts = [Vector(p) for p in pts]
        n = len(pts)
        if isinstance(radii, (int, float)):
            radii = [radii] * n
        up = Vector((0, 0, 1))
        t0 = (pts[1] - pts[0]).normalized()
        side = t0.cross(up)
        if side.length < 1e-3:
            side = t0.cross(Vector((1, 0, 0)))
        side.normalize()
        rings = []
        v = v0
        vs = []
        for k in range(n):
            if k == 0:
                t = (pts[1] - pts[0])
            elif k == n - 1:
                t = (pts[k] - pts[k - 1])
            else:
                t = (pts[k + 1] - pts[k - 1])
            t.normalize()
            side = (side - t * side.dot(t))
            if side.length < 1e-4:
                side = t.cross(up)
            side.normalize()
            bn = t.cross(side).normalized()
            rings.append([self._v(pts[k] + (side * math.cos(2 * math.pi * i / seg) +
                                            bn * math.sin(2 * math.pi * i / seg)) * radii[k])
                          for i in range(seg)])
            if k > 0:
                v += (pts[k] - pts[k - 1]).length
            vs.append(v)
        for k in range(n - 1):
            per = 2 * math.pi * max(radii[k], radii[k + 1], 0.005)
            for i in range(seg):
                j = (i + 1) % seg
                u0, u1 = per * i / seg * uscale, per * (i + 1) / seg * uscale
                self._face([rings[k][i], rings[k][j], rings[k + 1][j], rings[k + 1][i]], mat,
                           uvs=[(u0, vs[k] * vscale), (u1, vs[k] * vscale),
                                (u1, vs[k + 1] * vscale), (u0, vs[k + 1] * vscale)], tint=tint)
        if cap:
            if radii[0] > 1e-4:
                self._face(list(reversed(rings[0])), mat, tint=tint, smooth=False)
            if radii[-1] > 1e-4:
                self._face(rings[-1], mat, tint=tint, smooth=False)
        return vs[-1]

    def prism(self, poly, z0, z1, mat, cap_mat=None, tint=None, side_smooth=False):
        """Extrusión vertical de un polígono 2D [(x, y), ...] antihorario entre z0 y z1."""
        lo = [self._v((x, y, z0)) for x, y in poly]
        hi = [self._v((x, y, z1)) for x, y in poly]
        n = len(poly)
        for i in range(n):
            j = (i + 1) % n
            self._face([lo[i], lo[j], hi[j], hi[i]], mat, tint=tint, smooth=side_smooth)
        self._face(hi, cap_mat or mat, tint=tint, smooth=False)
        self._face(list(reversed(lo)), cap_mat or mat, tint=tint, smooth=False)

    def quad(self, p0, p1, p2, p3, mat, uvs=None, tint=None, smooth=False):
        return self._face([self._v(p) for p in (p0, p1, p2, p3)], mat, uvs=uvs, tint=tint, smooth=smooth)

    def tri(self, p0, p1, p2, mat, uvs=None, tint=None):
        return self._face([self._v(p) for p in (p0, p1, p2)], mat, uvs=uvs, tint=tint, smooth=False)

    def grid(self, fn, nu, nv, mat, uv_fn=None, tint=None, flip=False):
        """Superficie paramétrica fn(u, v)->(x, y, z) con u, v en [0, 1]."""
        vs = [[self._v(fn(i / nu, j / nv)) for j in range(nv + 1)] for i in range(nu + 1)]
        for i in range(nu):
            for j in range(nv):
                q = [vs[i][j], vs[i + 1][j], vs[i + 1][j + 1], vs[i][j + 1]]
                uv = None
                if uv_fn:
                    uv = [uv_fn(i / nu, j / nv), uv_fn((i + 1) / nu, j / nv),
                          uv_fn((i + 1) / nu, (j + 1) / nv), uv_fn(i / nu, (j + 1) / nv)]
                if flip:
                    q.reverse()
                    if uv:
                        uv.reverse()
                self._face(q, mat, uvs=uv, tint=tint)

    def card(self, c, w, h, mat, rot=(0, 0, 0), uv=(0, 0, 1, 1), tint=None, pivot_bottom=True):
        """Plano vertical (para follaje/etiquetas) con UV de atlas (u0, v0, u1, v1)."""
        m = self.M @ Matrix.Translation(c) @ rot_m(rot)
        z0 = 0 if pivot_bottom else -h / 2
        v = [self._v(p, m) for p in ((-w / 2, 0, z0), (w / 2, 0, z0), (w / 2, 0, z0 + h), (-w / 2, 0, z0 + h))]
        u0, v0, u1, v1 = uv
        return self._face(v, mat, uvs=[(u0, v0), (u1, v0), (u1, v1), (u0, v1)], tint=tint, smooth=True)

    # ---- acabado --------------------------------------------------------------------
    def _bevel(self, width, min_angle=50):
        edges = [e for e in self.bm.edges if len(e.link_faces) == 2 and
                 math.degrees(e.calc_face_angle(0.0)) > min_angle]
        if edges:
            bmesh.ops.bevel(self.bm, geom=edges, offset=width, segments=1, affect="EDGES",
                            profile=0.5, clamp_overlap=True)

    def _box_uv(self):
        for f in self.bm.faces:
            if f[self.lock]:
                continue
            n = f.normal
            ax = max(range(3), key=lambda i: abs(n[i]))
            for l in f.loops:
                p = l.vert.co
                if ax == 0:
                    uv = (p.y * (1 if n.x < 0 else -1), p.z)
                elif ax == 1:
                    uv = (p.x * (1 if n.y > 0 else -1), p.z)
                else:
                    uv = (p.x, p.y)
                l[self.uv].uv = uv

    def _sharp(self, angle):
        lim = math.radians(angle)
        for e in self.bm.edges:
            if len(e.link_faces) == 2:
                fa, fb = e.link_faces
                e.smooth = (fa.smooth and fb.smooth and e.calc_face_angle(0.0) < lim)
            else:
                e.smooth = False
        for f in self.bm.faces:
            f.smooth = True

    def quad_n(self, pts, mat, n, tint=None, uvs=None):
        """Cuadrilátero orientado para que su normal coincida con n."""
        a, b, c = Vector(pts[0]), Vector(pts[1]), Vector(pts[2])
        if (b - a).cross(c - a).dot(Vector(n)) < 0:
            pts = pts[::-1]
            uvs = uvs[::-1] if uvs else None
        return self._face([self._v(q) for q in pts], mat, uvs=uvs, tint=tint, smooth=False)

    def rect(self, o, du, dv, U, V, mat, n, step=1.0, tint=None):
        """Rectángulo o + du*u + dv*v subdividido (malla para luz horneada por vértice)."""
        o, du, dv = Vector(o), Vector(du), Vector(dv)
        nu, nv = max(1, math.ceil(U / step - 1e-6)), max(1, math.ceil(V / step - 1e-6))
        for i in range(nu):
            for j in range(nv):
                u0, u1, v0, v1 = U * i / nu, U * (i + 1) / nu, V * j / nv, V * (j + 1) / nv
                self.quad_n([o + du * u0 + dv * v0, o + du * u1 + dv * v0, o + du * u1 + dv * v1, o + du * u0 + dv * v1], mat, n, tint=tint)

    def _sky(self, dist, floor, samples=48):
        """Luz de cielo horneada en caras con flag=1: fracción de rayos que escapan."""
        bm = self.bm
        tmp = bm.copy()
        glass = [i for i, m in enumerate(self.mats) if m.startswith("glass")]
        bmesh.ops.delete(tmp, geom=[f for f in tmp.faces if f.material_index in glass], context="FACES")
        bmesh.ops.triangulate(tmp, faces=tmp.faces[:])
        bvh = BVHTree.FromBMesh(tmp)
        rnd = random.Random(11)
        dirs = []
        while len(dirs) < samples:
            v = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-0.25, 1)))
            if 0.05 < v.length <= 1.0:
                dirs.append(v.normalized())
        vis = {}
        for f in bm.faces:
            if f[self.flag] != 1:
                continue
            for v in f.verts:
                if v.index in vis:
                    continue
                o = v.co + f.normal * 0.06
                esc = 0
                for d in dirs:
                    if d.dot(f.normal) < 0.0:
                        d = d - 2 * d.dot(f.normal) * f.normal
                    if bvh.ray_cast(o, d, dist)[0] is None:
                        esc += 1
                vis[v.index] = esc / samples
        for it in range(3):      # suavizado por aristas
            nv = {}
            for v in bm.verts:
                if v.index in vis:
                    acc, n = vis[v.index] * 2.0, 2.0
                    for e in v.link_edges:
                        o2 = e.other_vert(v)
                        if o2.index in vis:
                            acc += vis[o2.index]; n += 1
                    nv[v.index] = acc / n
            vis = nv
        for f in bm.faces:
            if f[self.flag] != 1:
                continue
            for l in f.loops:
                b = min(1.0, floor + 3.4 * vis.get(l.vert.index, 0.0) ** 0.62)
                c = l[self.col]
                l[self.col] = (c[0] * b, c[1] * b, c[2] * (b * 0.97 + 0.03), c[3])
        tmp.free()

    def _ao(self, dist, strength, samples, ground, grime):
        bm = self.bm
        tmp = bm.copy()
        if ground is not None:
            g = 60.0
            vs = [tmp.verts.new(p) for p in ((-g, -g, ground), (g, -g, ground), (g, g, ground), (-g, g, ground))]
            tmp.faces.new(vs)
        bmesh.ops.triangulate(tmp, faces=tmp.faces[:])
        bvh = BVHTree.FromBMesh(tmp)
        rnd = random.Random(7)
        dirs = []
        while len(dirs) < samples:
            v = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(0.15, 1)))
            if 0.05 < v.length <= 1.0:
                dirs.append(v.normalized())
        acc = {}
        for f in bm.faces:
            n = f.normal
            if n.length < 1e-6 or f[self.flag] == 2:
                continue
            q = n.to_track_quat("Z", "Y")
            wd = [q @ d for d in dirs]
            for l in f.loops:
                o = l.vert.co + n * 0.012
                occ = 0.0
                for d in wd:
                    hit = bvh.ray_cast(o, d, dist)
                    if hit[0] is not None:
                        occ += 1.0 - 0.6 * (hit[3] / dist)
                key = (l.vert.index, round(n.x * 1.5), round(n.y * 1.5), round(n.z * 1.5))
                a = acc.setdefault(key, [0.0, 0])
                a[0] += occ / samples
                a[1] += 1
                l.tag = False
        for f in bm.faces:
            n = f.normal
            if f[self.flag] == 2:
                continue
            for l in f.loops:
                key = (l.vert.index, round(n.x * 1.5), round(n.y * 1.5), round(n.z * 1.5))
                a = acc.get(key)
                ao = 1.0 - strength * (a[0] / a[1]) if a else 1.0
                c = l[self.col]
                k = [c[0] * ao, c[1] * ao, c[2] * ao]
                if grime:
                    h0, h1, gc = grime
                    z = l.vert.co.z
                    t = 1.0 - min(1.0, max(0.0, (z - h0) / max(1e-4, h1 - h0)))
                    if abs(n.z) < 0.7:
                        k = [k[i] * (1 - t + t * gc[i]) for i in range(3)]
                l[self.col] = (k[0], k[1], k[2], c[3])
        tmp.free()

    def build(self, name, bevel=0.0, smooth=42, ao=True, ao_dist=0.8, ao_strength=0.75,
              ao_samples=14, ground=0.0, grime=None, weld=0.0, tri=True, sky=None):
        """Convierte lo acumulado en un objeto de malla listo para exportar."""
        bm = self.bm
        if weld > 0:
            bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=weld)
        bm.normal_update()
        if bevel > 0:
            self._bevel(bevel)
            bm.normal_update()
        self._box_uv()
        self._sharp(smooth)
        bm.verts.index_update()
        if ao:
            self._ao(ao_dist, ao_strength, ao_samples, ground, grime)
        if sky:
            bm.verts.index_update()
            self._sky(sky[0], sky[1])
        if tri:
            bmesh.ops.triangulate(bm, faces=bm.faces[:])
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        bm.free()
        for mname in self.mats:
            me.materials.append(material(mname))
        if me.color_attributes:
            me.color_attributes.active_color = me.color_attributes[0]
            me.color_attributes.render_color_index = 0
        ob = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(ob)
        return ob


def tris(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def export(objs, relpath, anim=False):
    """Exporta objetos a assets/models/<relpath>.glb (solo selección)."""
    path = os.path.join(MODELS, relpath + ".glb")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.gltf(
        filepath=path, export_format="GLB", use_selection=True, export_apply=True,
        export_yup=True, export_vertex_color="ACTIVE", export_all_vertex_colors=False,
        export_active_vertex_color_when_no_material=True, export_materials="EXPORT",
        export_animations=anim, export_tangents=False, export_skins=True,
        export_animation_mode="ACTIONS", export_force_sampling=True,
        export_optimize_animation_size=True, export_def_bones=False,
        export_morph=False)
    return path


def write_json(relpath, data):
    path = os.path.join(DATA, relpath)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        json.dump(data, f, separators=(",", ":"), sort_keys=True)


def clear_objects():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for me in list(bpy.data.meshes):
        if me.users == 0:
            bpy.data.meshes.remove(me)


def noise3(x, y, z, seed=0):
    """Ruido de valor suave determinista en [-1, 1] (sin dependencias externas)."""
    def h(i, j, k):
        n = (i * 374761393 + j * 668265263 + k * 2147483647 + seed * 1274126177) & 0xFFFFFFFF
        n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
        return ((n ^ (n >> 16)) & 0xFFFF) / 32767.5 - 1.0
    xi, yi, zi = math.floor(x), math.floor(y), math.floor(z)
    xf, yf, zf = x - xi, y - yi, z - zi
    u, v, w = (t * t * (3 - 2 * t) for t in (xf, yf, zf))
    def lerp(a, b, t):
        return a + (b - a) * t
    c = [[[h(xi + a, yi + b, zi + cc) for cc in (0, 1)] for b in (0, 1)] for a in (0, 1)]
    x00 = lerp(c[0][0][0], c[1][0][0], u); x10 = lerp(c[0][1][0], c[1][1][0], u)
    x01 = lerp(c[0][0][1], c[1][0][1], u); x11 = lerp(c[0][1][1], c[1][1][1], u)
    return lerp(lerp(x00, x10, v), lerp(x01, x11, v), w)


def fbm(p, octaves=3, scale=1.0, seed=0):
    a, f, s = 1.0, scale, 0.0
    for o in range(octaves):
        s += a * noise3(p[0] * f, p[1] * f, p[2] * f, seed + o * 17)
        a *= 0.5
        f *= 2.0
    return s
