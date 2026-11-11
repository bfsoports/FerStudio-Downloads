"""gen_buildings.py — generador paramétrico de edificios de Valdebruma.

Ejecutar: blender -b --python tools/blender/gen_buildings.py [-- nombre ...]
Cada edificio se describe en building_specs.py. Salidas:
  assets/models/buildings/<nombre>.glb   malla única (exterior + interior)
  data/buildings/<nombre>.json           colisiones, puertas, contenedores, muebles,
                                         puntos de botín, volúmenes interiores (coords Godot)
Convenio local: X ancho, Y fondo, Z arriba; fachada principal 'S' en y = -d/2.
'u' de cada muro va de izquierda a derecha visto desde fuera.
"""
import sys, os, math, random, json
sys.path.insert(0, os.path.dirname(__file__))
import bpy
from mathutils import Vector
import vb

SIGNS = {}
_sp = os.path.join(vb.DATA, "signs_atlas.json")
if os.path.exists(_sp):
    SIGNS = json.load(open(_sp))


class Building:
    def __init__(self, spec):
        self.s = spec
        self.p = vb.Parts()
        self.rnd = random.Random(spec.get("seed", sum(map(ord, spec["name"]))))
        self.w, self.d = spec["w"], spec["d"]
        self.floors = spec.get("floors", 1)
        self.fh = spec.get("fh", 2.7)
        self.t = spec.get("t", 0.25)
        self.z0 = spec.get("z0", 0.15)
        self.slab = 0.25
        self.H = self.z0 + self.floors * self.fh + (self.floors - 1) * self.slab
        hw, hd = self.w / 2, self.d / 2
        self.walls = {"S": ((-hw, -hd), (1, 0), (0, -1), self.w), "N": ((hw, hd), (-1, 0), (0, 1), self.w),
                      "E": ((hw, -hd), (0, 1), (1, 0), self.d), "W": ((-hw, hd), (0, -1), (-1, 0), self.d)}
        self.meta = {"size": [self.w, 0, self.d], "floor_y": self.z0, "floors": self.floors, "floor_h": self.fh,
                     "colliders": [], "ramps": [], "doors": [], "containers": [], "props": [], "loot": [],
                     "lights": [], "interior": [], "kind": spec.get("kind", "house")}
        self.roof = spec.get("roof", {"type": "gable"})
        self.open_ceiling = spec.get("open_ceiling", False)

    # ---- geometría de apoyo ----------------------------------------------------------
    def wp(self, wall, u, z, depth=0.0):
        (ox, oy), (ux, uy), (nx, ny), L = self.walls[wall]
        return Vector((ox + ux * u - nx * depth, oy + uy * u - ny * depth, z))

    def floor_z(self, f):
        return self.z0 + f * (self.fh + self.slab)

    def collider(self, lo, hi):
        c = [(lo[i] + hi[i]) / 2 for i in range(3)]
        s = [abs(hi[i] - lo[i]) for i in range(3)]
        if min(s) < 0.01:
            return
        g = vb.g3(c)
        self.meta["colliders"].append(g + [round(s[0], 3), round(s[2], 3), round(s[1], 3)])

    def top_profile(self, wall):
        """Puntos (u, z) del borde superior del muro según el tejado."""
        (o, ud, n, L) = self.walls[wall]
        r = self.roof
        tan = math.tan(math.radians(r.get("pitch", 35)))
        typ = r.get("type", "gable")
        H = self.H
        if typ == "gable":
            gable = ("E", "W") if r.get("axis", "x") == "x" else ("S", "N")
            if wall in gable:
                return [(0, H), (L / 2, H + L / 2 * tan), (L, H)]
        elif typ == "shed":
            hi = r.get("high", "N")
            opp = {"N": "S", "S": "N", "E": "W", "W": "E"}[hi]
            span = self.d if hi in ("N", "S") else self.w
            if wall == hi:
                return [(0, H + span * tan), (L, H + span * tan)]
            if wall != opp:
                a = self.wp(wall, 0, 0); b = self.wp(wall, L, 0)
                hp = self.wp(hi, 0, 0)
                def rise(pt):
                    dist = abs((pt.y - hp.y) if hi in ("N", "S") else (pt.x - hp.x))
                    return H + (span - dist) * tan
                return [(0, rise(a)), (L, rise(b))]
        elif typ == "flat":
            ph = r.get("parapet", 0.45)
            return [(0, H + ph), (L, H + ph)]
        return [(0, H), (L, H)]

    # ---- muros exteriores -----------------------------------------------------------
    def build_walls(self):
        s, p, t = self.s, self.p, self.t
        ops = {k: [] for k in self.walls}
        for op in s.get("openings", []):
            wall, u, kind = op[0], op[1], op[2]
            prm = dict(op[3]) if len(op) > 3 else {}
            f = prm.get("floor", 0)
            w = prm.get("w", 1.0 if kind == "door" else 1.2)
            if kind == "door":
                v0, v1 = self.floor_z(f), self.floor_z(f) + prm.get("h", 2.1)
            else:
                v0 = self.floor_z(f) + prm.get("sill", 0.95)
                v1 = v0 + prm.get("h", 1.2)
            ops[wall].append(dict(u0=u - w / 2, u1=u + w / 2, v0=v0, v1=v1, kind=kind, prm=prm, f=f))
        base_h = s.get("base_h", 0.55)
        for wall, (o, ud, n, L) in self.walls.items():
            n3 = Vector((n[0], n[1], 0))
            mat_out = s.get("wall_" + wall, s["wall"])
            mat_in = s.get("inner", "plaster_inner")
            us = {0.0, L, t, L - t}
            for o_ in ops[wall]:
                us.add(o_["u0"]); us.add(o_["u1"])
            us = sorted(us)
            dense = []
            for a, b in zip(us, us[1:]):
                k = max(1, math.ceil((b - a) / 1.1))
                dense += [a + (b - a) * i / k for i in range(k)]
            dense.append(L)
            solid_runs = []
            for a, b in zip(dense, dense[1:]):
                if b - a < 1e-5:
                    continue
                here = [o_ for o_ in ops[wall] if o_["u0"] <= a + 1e-6 and o_["u1"] >= b - 1e-6]
                vs = {-0.6, self.z0, self.H}
                if s.get("base") and base_h > 0:
                    vs.add(base_h)
                for f in range(1, self.floors):
                    vs.add(self.floor_z(f) - self.slab); vs.add(self.floor_z(f))
                for o_ in here:
                    vs.add(o_["v0"]); vs.add(o_["v1"])
                vs = sorted(vs)
                dv = []
                for va, vb_ in zip(vs, vs[1:]):
                    k = max(1, math.ceil((vb_ - va) / 1.0))
                    dv += [va + (vb_ - va) * i / k for i in range(k)]
                dv.append(self.H)
                for va, vb_ in zip(dv, dv[1:]):
                    if any(o_["v0"] <= va + 1e-6 and o_["v1"] >= vb_ - 1e-6 for o_ in here):
                        continue
                    mo = s["base"] if (s.get("base") and vb_ <= base_h + 1e-6) else mat_out
                    p.cur_flag = 0
                    p.quad_n([self.wp(wall, a, va), self.wp(wall, b, va), self.wp(wall, b, vb_), self.wp(wall, a, vb_)], mo, n3)
                    inside_slab = any(self.floor_z(f) - self.slab - 1e-6 <= va and vb_ <= self.floor_z(f) + 1e-6 for f in range(1, self.floors))
                    if a >= t - 1e-6 and b <= L - t + 1e-6 and va >= self.z0 - 1e-6 and not inside_slab:
                        p.cur_flag = 1
                        p.quad_n([self.wp(wall, a, va, t), self.wp(wall, b, va, t), self.wp(wall, b, vb_, t), self.wp(wall, a, vb_, t)], mat_in, -n3)
                        p.cur_flag = 0
                has_door = any(o_["kind"] == "door" for o_ in here)
                solid_runs.append((a, b, has_door, here))
            # parte superior (hastiales, muro alto de tejado a un agua, peto)
            prof = self.top_profile(wall)
            for (ua, za), (ub, zb) in zip(prof, prof[1:]):
                k = max(1, math.ceil((ub - ua) / 1.2))
                for i in range(k):
                    a, b = ua + (ub - ua) * i / k, ua + (ub - ua) * (i + 1) / k
                    ha, hb = za + (zb - za) * i / k, za + (zb - za) * (i + 1) / k
                    if max(ha, hb) - self.H < 1e-4:
                        continue
                    pts = [self.wp(wall, a, self.H), self.wp(wall, b, self.H), self.wp(wall, b, hb), self.wp(wall, a, ha)]
                    p.cur_flag = 0
                    self._poly(pts, mat_out, n3)
                    if self.open_ceiling or self.roof.get("type") == "flat":
                        a2, b2 = max(a, t), min(b, L - t)
                        if b2 > a2:
                            fa = lambda uu: ha + (hb - ha) * (uu - a) / (b - a)
                            pts = [self.wp(wall, a2, self.H, t), self.wp(wall, b2, self.H, t), self.wp(wall, b2, fa(b2), t), self.wp(wall, a2, fa(a2), t)]
                            p.cur_flag = 1 if self.open_ceiling else 0
                            self._poly(pts, mat_in if self.open_ceiling else mat_out, -n3)
                            p.cur_flag = 0
            # colisiones: tramos macizos fusionados; sobre las puertas solo el dintel
            run = None
            top = max(z for _, z in prof)
            def flush(r):
                if r:
                    a_, b_ = r
                    q0, q1 = self.wp(wall, a_, 0, 0), self.wp(wall, b_, 0, t)
                    self.collider((min(q0.x, q1.x), min(q0.y, q1.y), -0.6), (max(q0.x, q1.x), max(q0.y, q1.y), top))
            for a, b, has_door, here in solid_runs:
                if has_door:
                    flush(run); run = None
                    dz = max(o_["v1"] for o_ in here if o_["kind"] == "door")
                    q0, q1 = self.wp(wall, a, 0, 0), self.wp(wall, b, 0, t)
                    self.collider((min(q0.x, q1.x), min(q0.y, q1.y), dz), (max(q0.x, q1.x), max(q0.y, q1.y), top))
                    self.collider((min(q0.x, q1.x), min(q0.y, q1.y), -0.6), (max(q0.x, q1.x), max(q0.y, q1.y), min(o_["v0"] for o_ in here if o_["kind"] == "door")))
                else:
                    run = (run[0], b) if run else (a, b)
            flush(run)
            for o_ in ops[wall]:
                self.opening_detail(wall, o_, n3, mat_out)

    def _poly(self, pts, mat, n):
        clean = []
        for q in pts:
            if not clean or (q - clean[-1]).length > 1e-5:
                clean.append(q)
        if (clean[0] - clean[-1]).length < 1e-5:
            clean.pop()
        if len(clean) < 3:
            return
        a, b, c = clean[0], clean[1], clean[2]
        if (b - a).cross(c - a).dot(n) < 0:
            clean.reverse()
        self.p._face([self.p._v(q) for q in clean], mat, smooth=False)

    def opening_detail(self, wall, o_, n3, mat_out):
        p, t, s = self.p, self.t, self.s
        (og, ud, n, L) = self.walls[wall]
        u3 = Vector((ud[0], ud[1], 0))
        up = Vector((0, 0, 1))
        u0, u1, v0, v1 = o_["u0"], o_["u1"], o_["v0"], o_["v1"]
        prm = o_["prm"]
        rev = s.get("reveal", mat_out)
        # jambas, dintel y alféizar (a través del grosor del muro)
        p.quad_n([self.wp(wall, u0, v0), self.wp(wall, u0, v0, t), self.wp(wall, u0, v1, t), self.wp(wall, u0, v1)], rev, u3)
        p.quad_n([self.wp(wall, u1, v0), self.wp(wall, u1, v0, t), self.wp(wall, u1, v1, t), self.wp(wall, u1, v1)], rev, -u3)
        p.quad_n([self.wp(wall, u0, v1), self.wp(wall, u1, v1), self.wp(wall, u1, v1, t), self.wp(wall, u0, v1, t)], rev, -up)
        p.quad_n([self.wp(wall, u0, v0), self.wp(wall, u1, v0), self.wp(wall, u1, v0, t), self.wp(wall, u0, v0, t)],
                 s.get("floor_mat", "wood_floor") if o_["kind"] == "door" else rev, up)
        frame = prm.get("frame", s.get("frame", "paint_white"))
        ang = math.degrees(math.atan2(ud[1], ud[0]))
        cu, w, h = (u0 + u1) / 2, u1 - u0, v1 - v0
        c = self.wp(wall, cu, (v0 + v1) / 2, t * 0.4)
        p.push((c.x, c.y, c.z), (0, 0, ang))
        fw, fd = 0.07, 0.09
        if o_["kind"] == "win":
            for sx in (-1, 1):
                p.box((sx * (w / 2 - fw / 2), 0, 0), (fw, fd, h), frame)
            for sz in (-1, 1):
                p.box((0, 0, sz * (h / 2 - fw / 2)), (w - 2 * fw, fd, fw), frame)
            style = prm.get("style", "cross")
            if style in ("cross", "bars"):
                p.box((0, 0, 0), (0.045, fd * 0.7, h - 2 * fw), frame)
            if style == "cross":
                p.box((0, 0, h * 0.12), (w - 2 * fw, fd * 0.7, 0.045), frame)
            if style == "grid":
                for k in range(1, 4):
                    p.box((-w / 2 + w * k / 4, 0, 0), (0.04, fd * 0.7, h - 2 * fw), frame)
                p.box((0, 0, 0), (w - 2 * fw, fd * 0.7, 0.04), frame)
            state = prm.get("state") or self.rnd.choices(["glass", "broken", "boards"], [0.62, 0.23, 0.15])[0]
            if state == "glass":
                p.quad((-w / 2 + fw, 0, -h / 2 + fw), (w / 2 - fw, 0, -h / 2 + fw), (w / 2 - fw, 0, h / 2 - fw), (-w / 2 + fw, 0, h / 2 - fw), "glass")
            elif state == "boards":
                for k in range(3):
                    zz = -h / 2 + h * (k + 0.5) / 3 + self.rnd.uniform(-0.06, 0.06)
                    p.box((0, -t * 0.42, zz), (w + 0.25, 0.025, 0.16), "wood_grey", rot=(0, self.rnd.uniform(-7, 7), 0))
            p.box((0, -t * 0.4 - 0.05, -h / 2 - 0.035), (w + 0.16, 0.2, 0.06), s.get("sill_mat", "concrete_floor"))
            if prm.get("shutters", s.get("shutters", False)):
                sm = s.get("shutter_mat", "wood_green")
                for sx in (-1, 1):
                    a = self.rnd.choice([0, 0, 8, 25]) * sx
                    p.push((sx * (w / 2 + 0.01), -t * 0.4 - 0.02, 0), (0, 0, -a))
                    p.box((sx * w / 4, 0, 0), (w / 2 - 0.02, 0.035, h), sm)
                    for k in range(3):
                        p.box((sx * w / 4, -0.022, -h / 2 + h * (k + 0.5) / 3), (w / 2 - 0.08, 0.012, 0.06), sm)
                    p.pop()
        else:
            for sx in (-1, 1):
                p.box((sx * (w / 2 - fw / 2), 0, 0), (fw, fd + 0.04, h), frame)
            p.box((0, 0, h / 2 - fw / 2), (w - 2 * fw, fd + 0.04, fw), frame)
            kind = prm.get("kind", "door_wood")
            if kind != "none":
                hinge = self.wp(wall, u0 + fw, v0, t * 0.4)
                self.meta["doors"].append({"id": len(self.meta["doors"]), "pos": vb.g3(hinge), "yaw": round(ang, 2),
                                           "w": round(w - 2 * fw, 3), "h": round(h - fw, 3), "type": kind, "ext": True,
                                           "locked": prm.get("locked", ""), "swing": prm.get("swing", -1)})
            # escalón exterior
            if prm.get("step", True) and v0 < 0.5:
                p.box((0, -t * 0.4 - 0.32, -h / 2 - self.z0 / 2 - 0.01), (w + 0.5, 0.6, self.z0 * 0.55 + 0.02), s.get("step_mat", "concrete_floor"))
                st = self.wp(wall, cu, 0, -0.32)
                self.collider((st.x - (w + 0.5) / 2 * abs(ud[0]) - 0.3 * abs(n[0]), st.y - (w + 0.5) / 2 * abs(ud[1]) - 0.3 * abs(n[1]), -0.3),
                              (st.x + (w + 0.5) / 2 * abs(ud[0]) + 0.3 * abs(n[0]), st.y + (w + 0.5) / 2 * abs(ud[1]) + 0.3 * abs(n[1]), self.z0 * 0.55))
        p.pop()

    # ---- suelos, techos, tabiques ---------------------------------------------------
    def build_floors(self):
        s, p, t = self.s, self.p, self.t
        hw, hd = self.w / 2 - t, self.d / 2 - t
        well = s.get("stairs")
        for f in range(self.floors):
            z = self.floor_z(f)
            fm = s.get("floor_mats", [s.get("floor_mat", "wood_floor")] * self.floors)[f]
            rects = [(-hw, -hd, hw, hd)]
            if f > 0 and well:
                x0, y0, x1, y1 = self.well_rect()
                rects = [(-hw, -hd, hw, y0), (-hw, y1, hw, hd), (-hw, y0, x0, y1), (x1, y0, hw, y1)]
            for (x0, y0, x1, y1) in rects:
                if x1 - x0 < 0.02 or y1 - y0 < 0.02:
                    continue
                p.cur_flag = 1
                p.rect((x0, y0, z), (1, 0, 0), (0, 1, 0), x1 - x0, y1 - y0, fm, (0, 0, 1), step=0.95)
                if f > 0:
                    p.rect((x0, y0, z - self.slab), (1, 0, 0), (0, 1, 0), x1 - x0, y1 - y0, s.get("ceil_mat", "plaster_ceiling"), (0, 0, -1), step=1.2)
                    self.collider((x0, y0, z - self.slab), (x1, y1, z))
                p.cur_flag = 0
            if f > 0 and well:
                x0, y0, x1, y1 = self.well_rect()
                p.cur_flag = 1
                for (a, b, n) in (((x0, y0), (x1, y0), (0, 1, 0)), ((x0, y1), (x1, y1), (0, -1, 0)), ((x0, y0), (x0, y1), (1, 0, 0)), ((x1, y0), (x1, y1), (-1, 0, 0))):
                    p.quad_n([(a[0], a[1], z - self.slab), (b[0], b[1], z - self.slab), (b[0], b[1], z), (a[0], a[1], z)], "wood_dark", n)
                p.cur_flag = 0
        self.collider((-self.w / 2, -self.d / 2, -0.6), (self.w / 2, self.d / 2, self.z0))
        self.meta["interior"].append([round(-hw, 2), round(-hd, 2), round(hw, 2), round(hd, 2), 0.0, round(self.H + 0.2, 2)])
        if not self.open_ceiling:
            p.cur_flag = 1
            p.rect((-hw, -hd, self.H), (1, 0, 0), (0, 1, 0), 2 * hw, 2 * hd, s.get("ceil_mat", "plaster_ceiling"), (0, 0, -1), step=1.2)
            p.cur_flag = 0
            self.collider((-hw, -hd, self.H), (hw, hd, self.H + 0.2))

    def well_rect(self):
        x, y, dr, wd = self.s["stairs"][:4]
        run = self.stair_run()
        if dr == "x+":
            return (x + 0.9, y - wd / 2, x + run + 0.05, y + wd / 2)
        if dr == "x-":
            return (x - run - 0.05, y - wd / 2, x - 0.9, y + wd / 2)
        if dr == "y+":
            return (x - wd / 2, y + 0.9, x + wd / 2, y + run + 0.05)
        return (x - wd / 2, y - run - 0.05, x + wd / 2, y - 0.9)

    def stair_run(self):
        n = math.ceil((self.fh + self.slab) / 0.2)
        return n * 0.26

    def build_stairs(self):
        if "stairs" not in self.s:
            return
        p = self.p
        x, y, dr, wd = self.s["stairs"][:4]
        rise = self.fh + self.slab
        n = math.ceil(rise / 0.2)
        sh, tr = rise / n, 0.26
        ang = {"x+": 0, "y+": 90, "x-": 180, "y-": 270}[dr]
        p.push((x, y, self.z0), (0, 0, ang))
        p.cur_flag = 1
        for i in range(n):
            p.box((tr * (i + 0.5), 0, sh * (i + 1) - 0.02), (tr + 0.02, wd, 0.04), "wood_floor")
            p.box((tr * (i + 1) - 0.01, 0, sh * (i + 0.5)), (0.02, wd, sh), "wood_dark")
        L = math.hypot(n * tr, rise)
        pitch = math.degrees(math.atan2(rise, n * tr))
        for sy in (-1, 1):
            p.box((n * tr / 2, sy * (wd / 2 - 0.02), rise / 2 - 0.12), (L, 0.04, 0.26), "wood_dark", rot=(0, -pitch, 0))
        side = self.s["stairs"][4] if len(self.s["stairs"]) > 4 else 1
        for i in range(0, n + 1, 3):
            p.box((tr * i, side * (wd / 2 - 0.03), sh * i + 0.5), (0.05, 0.05, 1.0), "wood_dark")
        p.box((n * tr / 2, side * (wd / 2 - 0.03), rise / 2 + 1.0), (L, 0.06, 0.05), "wood_dark", rot=(0, -pitch, 0))
        p.cur_flag = 0
        a = p.M @ Vector((0, 0, 0)); b = p.M @ Vector((n * tr, 0, rise))
        p.pop()
        self.meta["ramps"].append({"a": vb.g3(a), "b": vb.g3(b), "w": wd})

    def build_partitions(self):
        s, p = self.s, self.p
        ti = s.get("ti", 0.12)
        mat = s.get("inner", "plaster_inner")
        for part in s.get("partitions", []):
            x0, y0, x1, y1 = part[0:4]
            doors = part[4] if len(part) > 4 else []
            f = part[5] if len(part) > 5 else 0
            z = self.floor_z(f)
            h = self.fh if not (self.open_ceiling and f == self.floors - 1) else min(self.fh, 2.6)
            a, b = Vector((x0, y0, 0)), Vector((x1, y1, 0))
            L = (b - a).length
            ud = (b - a).normalized()
            nrm = Vector((-ud.y, ud.x, 0))
            cuts = {0.0, L}
            dlist = []
            for dspec in doors:
                dc, dw = dspec[0], dspec[1]
                kind = dspec[2] if len(dspec) > 2 else "door_inner"
                cuts.add(dc - dw / 2); cuts.add(dc + dw / 2)
                dlist.append((dc - dw / 2, dc + dw / 2, kind, dspec[3] if len(dspec) > 3 else ""))
            cuts = sorted(cuts)
            p.cur_flag = 1
            for ua, ub in zip(cuts, cuts[1:]):
                dr = [dd for dd in dlist if dd[0] <= ua + 1e-6 and dd[1] >= ub - 1e-6]
                zb = z + 2.05 if dr else z
                for sgn in (-1, 1):
                    o = a + ud * ua + nrm * (sgn * ti / 2) + Vector((0, 0, zb))
                    p.rect(o, ud, (0, 0, 1), ub - ua, z + h - zb, mat, nrm * sgn, step=1.0)
                lo, hi = a + ud * ua, a + ud * ub
                bx0, bx1 = min(lo.x, hi.x) - abs(nrm.x) * ti / 2, max(lo.x, hi.x) + abs(nrm.x) * ti / 2
                by0, by1 = min(lo.y, hi.y) - abs(nrm.y) * ti / 2, max(lo.y, hi.y) + abs(nrm.y) * ti / 2
                self.collider((bx0, by0, zb), (bx1, by1, z + h))
                if dr:
                    d0, d1, kind, locked = dr[0]
                    ang = math.degrees(math.atan2(ud.y, ud.x))
                    c = a + ud * ((d0 + d1) / 2) + Vector((0, 0, z + 1.025))
                    p.push((c.x, c.y, c.z), (0, 0, ang))
                    fr = s.get("frame_in", "wood_dark")
                    for sx in (-1, 1):
                        p.box((sx * ((d1 - d0) / 2 - 0.03), 0, 0), (0.06, ti + 0.04, 2.05), fr)
                    p.box((0, 0, 1.0), (d1 - d0, ti + 0.04, 0.06), fr)
                    p.quad_n([(-(d1 - d0) / 2, -ti / 2, 1.025), ((d1 - d0) / 2, -ti / 2, 1.025), ((d1 - d0) / 2, ti / 2, 1.025), (-(d1 - d0) / 2, ti / 2, 1.025)], mat, (0, 0, -1))
                    p.pop()
                    if kind != "none":
                        hinge = a + ud * (d0 + 0.06) + Vector((0, 0, z))
                        self.meta["doors"].append({"id": len(self.meta["doors"]), "pos": vb.g3(hinge), "yaw": round(ang, 2),
                                                   "w": round(d1 - d0 - 0.12, 3), "h": 2.0, "type": kind, "ext": False, "locked": locked, "swing": 1})
            # testas del tabique
            for (pt, dirn) in ((a, -ud), (b, ud)):
                o = pt + nrm * (-ti / 2) + Vector((0, 0, z))
                p.quad_n([o, o + nrm * ti, o + nrm * ti + Vector((0, 0, h)), o + Vector((0, 0, h))], mat, dirn)
            if self.open_ceiling:
                o = a + nrm * (-ti / 2) + Vector((0, 0, z + h))
                p.quad_n([o, o + ud * L, o + ud * L + nrm * ti, o + nrm * ti], mat, (0, 0, 1))
            p.cur_flag = 0

    # ---- tejado ---------------------------------------------------------------------
    def build_roof(self):
        r, p, s = self.roof, self.p, self.s
        typ = r.get("type", "gable")
        mat = r.get("mat", "roof_clay")
        under = r.get("under", "wood_raw")
        ov = r.get("overhang", 0.45)
        tan = math.tan(math.radians(r.get("pitch", 35)))
        H = self.H
        th = 0.1
        if typ in ("gable", "hip"):
            swap = r.get("axis", "x") == "y"
            hw, hd = (self.d / 2, self.w / 2) if swap else (self.w / 2, self.d / 2)
            p.push(rot=(0, 0, 90 if swap else 0))
            ridge_z = H + hd * tan
            eave_z = H - ov * tan
            sl = math.hypot(hd + ov, ridge_z - eave_z)
            if typ == "gable":
                xl = hw + r.get("rake", 0.35)
                for sy in (-1, 1):
                    e0, e1 = (-xl, sy * (hd + ov), eave_z), (xl, sy * (hd + ov), eave_z)
                    r0, r1 = (-xl, 0, ridge_z), (xl, 0, ridge_z)
                    nrm = Vector((0, sy * tan, 1)).normalized()
                    off = nrm * th
                    k = max(1, round(2 * xl / 2.5))
                    for i in range(k):
                        xa, xb = -xl + 2 * xl * i / k, -xl + 2 * xl * (i + 1) / k
                        pts = [Vector((xa, e0[1], eave_z)) + off, Vector((xb, e0[1], eave_z)) + off, Vector((xb, 0, ridge_z)) + off, Vector((xa, 0, ridge_z)) + off]
                        uv = [(xa, 0), (xb, 0), (xb, sl), (xa, sl)]
                        p.quad_n(pts, mat, nrm, uvs=uv)
                        p.cur_flag = 1 if self.open_ceiling else 0
                        p.quad_n([Vector((xa, e0[1], eave_z)), Vector((xb, e0[1], eave_z)), Vector((xb, 0, ridge_z)), Vector((xa, 0, ridge_z))], under, -nrm)
                        p.cur_flag = 0
                    p.quad_n([Vector(e0), Vector(e1), Vector(e1) + off, Vector(e0) + off], "wood_dark", (0, sy, 0))
                    for sx in (-1, 1):   # borde de hastial
                        p.quad_n([Vector((sx * xl, e0[1], eave_z)), Vector((sx * xl, 0, ridge_z)), Vector((sx * xl, 0, ridge_z)) + off, Vector((sx * xl, e0[1], eave_z)) + off], "wood_dark", (sx, 0, 0))
                    if r.get("gutters", True):
                        gy = sy * (hd + ov + 0.05)
                        p.tube([(-xl, gy, eave_z - 0.02), (xl, gy, eave_z - 0.02)], 0.065, "metal_dark", seg=6)
                        gx = (hw - 0.15) * (1 if sy > 0 else -1)
                        p.tube([(gx, gy, eave_z - 0.05), (gx, sy * (hd + 0.07), eave_z - 0.35), (gx, sy * (hd + 0.07), 0.05)], 0.045, "metal_dark", seg=6)
                p.box((0, 0, ridge_z + th + 0.01), (2 * xl, 0.22, 0.07), r.get("ridge", mat))
            else:
                rl = max(0.0, hw - hd)
                ex, ey = hw + ov, hd + ov
                e = [(-ex, -ey, eave_z), (ex, -ey, eave_z), (ex, ey, eave_z), (-ex, ey, eave_z)]
                ra, rb = (-rl, 0, ridge_z + ov * 0), (rl, 0, ridge_z)
                ra = (-rl, 0, ridge_z)
                for (pts, nrm, base) in (([e[0], e[1], rb, ra], Vector((0, -tan, 1)), 2 * ex), ([e[2], e[3], ra, rb], Vector((0, tan, 1)), 2 * ex)):
                    uv = [(-ex, 0), (ex, 0), (rl, sl), (-rl, sl)]
                    p.quad_n([Vector(q) for q in pts], mat, nrm, uvs=uv)
                for (pts, nrm) in (([e[1], e[2], rb], Vector((tan, 0, 1))), ([e[3], e[0], ra], Vector((-tan, 0, 1)))):
                    self._tri_uv(pts, mat, nrm, [(-ey, 0), (ey, 0), (0, sl)])
                # sofito
                for (a, b, n) in ((e[0], e[1], (0, -1)), (e[1], e[2], (1, 0)), (e[2], e[3], (0, 1)), (e[3], e[0], (-1, 0))):
                    ia = (max(-hw, min(hw, a[0])), max(-hd, min(hd, a[1])), eave_z)
                    ib = (max(-hw, min(hw, b[0])), max(-hd, min(hd, b[1])), eave_z)
                    p.quad_n([Vector(a), Vector(b), Vector(ib), Vector(ia)], under, (0, 0, -1))
                    p.quad_n([Vector(a), Vector(b), Vector(b) + Vector((0, 0, th)), Vector(a) + Vector((0, 0, th))], "wood_dark", (n[0], n[1], 0))
            p.pop()
            self.meta["size"][1] = round(ridge_z + 0.3, 2)
        elif typ == "shed":
            hi = r.get("high", "N")
            span = self.d if hi in ("N", "S") else self.w
            rot = {"N": 0, "W": 90, "S": 180, "E": 270}[hi]
            hw, hd = (self.w / 2, self.d / 2) if hi in ("N", "S") else (self.d / 2, self.w / 2)
            p.push(rot=(0, 0, rot))
            z_lo, z_hi = H - ov * tan, H + (span + ov) * tan
            nrm = Vector((0, -tan, 1)).normalized()
            off = nrm * th
            sl = math.hypot(span + 2 * ov, z_hi - z_lo)
            xl = hw + ov
            k = max(1, round(2 * xl / 2.5))
            for i in range(k):
                xa, xb = -xl + 2 * xl * i / k, -xl + 2 * xl * (i + 1) / k
                a, b, c, d_ = Vector((xa, -hd - ov, z_lo)), Vector((xb, -hd - ov, z_lo)), Vector((xb, hd + ov, z_hi)), Vector((xa, hd + ov, z_hi))
                p.quad_n([a + off, b + off, c + off, d_ + off], mat, nrm, uvs=[(xa, 0), (xb, 0), (xb, sl), (xa, sl)])
                p.cur_flag = 1 if self.open_ceiling else 0
                p.quad_n([a, b, c, d_], under, -nrm)
                p.cur_flag = 0
            for (a, b, n) in ((Vector((-xl, -hd - ov, z_lo)), Vector((xl, -hd - ov, z_lo)), (0, -1, 0)), (Vector((-xl, hd + ov, z_hi)), Vector((xl, hd + ov, z_hi)), (0, 1, 0)),
                              (Vector((-xl, -hd - ov, z_lo)), Vector((-xl, hd + ov, z_hi)), (-1, 0, 0)), (Vector((xl, -hd - ov, z_lo)), Vector((xl, hd + ov, z_hi)), (1, 0, 0))):
                p.quad_n([a, b, b + off, a + off], "wood_dark", n)
            if r.get("gutters", True):
                p.tube([(-xl, -hd - ov - 0.05, z_lo - 0.02), (xl, -hd - ov - 0.05, z_lo - 0.02)], 0.065, "metal_dark", seg=6)
                p.tube([(hw - 0.2, -hd - ov - 0.05, z_lo - 0.05), (hw - 0.2, -hd - 0.07, z_lo - 0.3), (hw - 0.2, -hd - 0.07, 0.05)], 0.045, "metal_dark", seg=6)
            p.pop()
            self.meta["size"][1] = round(z_hi + 0.2, 2)
        else:   # plano con peto
            ph = r.get("parapet", 0.45)
            t = self.t
            hw, hd = self.w / 2, self.d / 2
            p.rect((-hw + t, -hd + t, H + 0.12), (1, 0, 0), (0, 1, 0), self.w - 2 * t, self.d - 2 * t, mat, (0, 0, 1), step=3.0)
            for (c, sz) in (((0, -hd + t / 2, H + ph + 0.03), (self.w + 0.06, t + 0.06, 0.06)), ((0, hd - t / 2, H + ph + 0.03), (self.w + 0.06, t + 0.06, 0.06)),
                            ((-hw + t / 2, 0, H + ph + 0.03), (t + 0.06, self.d + 0.06, 0.06)), ((hw - t / 2, 0, H + ph + 0.03), (t + 0.06, self.d + 0.06, 0.06))):
                p.box(c, sz, r.get("coping", "concrete_floor"))
            p.tube([(hw - 0.3, -hd - 0.06, H + 0.1), (hw - 0.3, -hd - 0.06, 0.05)], 0.05, "metal_dark", seg=6)
            self.meta["size"][1] = round(H + ph + 0.1, 2)
        if self.open_ceiling and typ == "gable" and not r.get("no_truss"):
            swap = r.get("axis", "x") == "y"
            hw, hd = (self.d / 2, self.w / 2) if swap else (self.w / 2, self.d / 2)
            p.push(rot=(0, 0, 90 if swap else 0))
            n = max(1, round(2 * hw / 3.2))
            p.cur_flag = 1
            pitch = math.degrees(math.atan(tan))
            for i in range(1, n):
                x = -hw + 2 * hw * i / n
                tm = r.get("truss_mat", "wood_dark")
                p.box((x, 0, H + 0.02), (0.14, 2 * hd - 0.1, 0.16), tm)
                p.box((x, 0, H + hd * tan / 2), (0.12, 0.12, hd * tan), tm)
                rl = math.hypot(hd, hd * tan)
                for sy in (-1, 1):
                    p.box((x, sy * hd / 2, H + hd * tan / 2 - 0.04), (0.12, rl, 0.14), tm, rot=(-sy * pitch, 0, 0))
            p.cur_flag = 0
            p.pop()

    def _tri_uv(self, pts, mat, nrm, uv):
        a, b, c = [Vector(q) for q in pts]
        if (b - a).cross(c - a).dot(nrm) < 0:
            b, c = c, b
            uv = [uv[0], uv[2], uv[1]]
        self.p._face([self.p._v(q) for q in (a, b, c)], mat, uvs=uv, smooth=False)

    # ---- extras ---------------------------------------------------------------------
    def build_extras(self):
        s, p = self.s, self.p
        r = self.roof
        tan = math.tan(math.radians(r.get("pitch", 35)))
        for ch in s.get("chimneys", []):
            x, y = ch[0], ch[1]
            cm = ch[2] if len(ch) > 2 else "brick_red"
            if r.get("type", "gable") in ("gable", "hip"):
                span = self.d / 2 if r.get("axis", "x") == "x" else self.w / 2
                top = self.H + span * tan + 0.7
            else:
                top = self.H + 1.4
            p.box((x, y, (top + self.H + 0.05) / 2), (0.62, 0.62, top - self.H - 0.05), cm)
            p.box((x, y, top + 0.04), (0.78, 0.78, 0.08), "concrete_floor")
            p.cyl((x, y, top + 0.24), 0.13, 0.32, "roof_clay", seg=8)
        if "porch" in s:
            po = s["porch"]
            wall, u0, u1, dep = po["wall"], po["u0"], po["u1"], po.get("depth", 1.8)
            (og, ud, n, L) = self.walls[wall]
            ang = math.degrees(math.atan2(ud[1], ud[0]))
            c = self.wp(wall, (u0 + u1) / 2, 0, 0)
            p.push((c.x, c.y, 0), (0, 0, ang))
            wd = u1 - u0
            pm = po.get("mat", "wood_grey")
            p.box((0, -dep / 2, self.z0 - 0.05), (wd, dep, 0.1), pm)
            for i in range(int(wd / 0.5)):
                pass
            zr = self.z0 + po.get("h", 2.35)
            n_posts = max(2, round(wd / 2.4) + 1)
            for i in range(n_posts):
                x = -wd / 2 + 0.08 + (wd - 0.16) * i / (n_posts - 1)
                p.box((x, -dep + 0.1, (self.z0 + zr) / 2), (0.12, 0.12, zr - self.z0), po.get("post", "wood_dark"))
                p.box((x, -dep + 0.1, zr - 0.12), (0.2, 0.2, 0.06), po.get("post", "wood_dark"))
            p.box((0, -dep + 0.1, zr - 0.05), (wd, 0.14, 0.14), po.get("post", "wood_dark"))
            sl = math.hypot(dep + 0.3, 0.45)
            pitch = math.degrees(math.atan2(0.45, dep + 0.3))
            p.box((0, -dep / 2 - 0.1, zr + 0.25), (wd + 0.4, sl, 0.07), po.get("roof", r.get("mat", "roof_clay")), rot=(pitch, 0, 0),
                  mats={"-z": "wood_raw"})
            if po.get("rail", True):
                for i in range(n_posts - 1):
                    xa = -wd / 2 + 0.08 + (wd - 0.16) * i / (n_posts - 1)
                    xb = -wd / 2 + 0.08 + (wd - 0.16) * (i + 1) / (n_posts - 1)
                    if po.get("gap") is not None and i == po["gap"]:
                        continue
                    p.box(((xa + xb) / 2, -dep + 0.1, self.z0 + 0.9), (xb - xa, 0.07, 0.06), pm)
                    for k in range(1, int((xb - xa) / 0.18)):
                        p.box((xa + k * 0.18, -dep + 0.1, self.z0 + 0.45), (0.035, 0.035, 0.86), pm)
            p.box((0, -dep - 0.25, self.z0 / 2 - 0.05), (1.6, 0.5, self.z0 * 0.5), pm)
            lo = p.M @ Vector((-wd / 2, -dep, -0.4)); hi = p.M @ Vector((wd / 2, 0, self.z0))
            self.collider((min(lo.x, hi.x), min(lo.y, hi.y), -0.4), (max(lo.x, hi.x), max(lo.y, hi.y), self.z0))
            p.pop()
        for aw in s.get("awnings", []):
            wall, u0, u1, z = aw["wall"], aw["u0"], aw["u1"], aw.get("z", 2.55)
            (og, ud, n, L) = self.walls[wall]
            ang = math.degrees(math.atan2(ud[1], ud[0]))
            c = self.wp(wall, (u0 + u1) / 2, z, 0)
            p.push((c.x, c.y, c.z), (0, 0, ang))
            dep = aw.get("depth", 1.2)
            p.box((0, -dep / 2, -0.2), (u1 - u0, dep * 1.05, 0.04), aw.get("mat", "fabric_awning"), rot=(-18, 0, 0))
            p.box((0, -dep, -0.48), (u1 - u0, 0.03, 0.18), aw.get("mat", "fabric_awning"))
            for sx in (-1, 1):
                p.tube([(sx * (u1 - u0) / 2, 0, -0.5), (sx * (u1 - u0) / 2, -dep, -0.4)], 0.015, "metal_dark", seg=4)
            p.pop()
        for sg in s.get("signs", []):
            wall, u, z, w, h = sg["wall"], sg["u"], sg["z"], sg["w"], sg["h"]
            (og, ud, n, L) = self.walls[wall]
            ang = math.degrees(math.atan2(ud[1], ud[0]))
            c = self.wp(wall, u, z, -0.06)
            p.push((c.x, c.y, c.z), (0, 0, ang))
            p.box((0, 0.02, 0), (w + 0.1, 0.06, h + 0.1), sg.get("back", "wood_dark"))
            uv = SIGNS.get(sg["id"], [0, 0, 1, 1])
            p.quad((-w / 2, -0.012, -h / 2), (w / 2, -0.012, -h / 2), (w / 2, -0.012, h / 2), (-w / 2, -0.012, h / 2), "signs",
                   uvs=[(uv[0], uv[1]), (uv[2], uv[1]), (uv[2], uv[3]), (uv[0], uv[3])])
            p.pop()
        for iv in s.get("ivy", []):
            wall, u, w, h = iv
            (og, ud, n, L) = self.walls[wall]
            ang = math.degrees(math.atan2(ud[1], ud[0]))
            for k in range(max(1, round(w / 1.3))):
                uu = u - w / 2 + w * (k + 0.5) / max(1, round(w / 1.3))
                c = self.wp(wall, uu, 0.0, -0.05 - 0.03 * k)
                hh = h * self.rnd.uniform(0.7, 1.1)
                p.push((c.x, c.y, c.z), (0, 0, ang))
                p.cur_flag = 2
                p.card((0, 0, 0), 1.7, hh, "leaf_ivy", tint=(0.9, 0.95, 0.9, 0.15))
                p.cur_flag = 0
                p.pop()
        for ex in s.get("boxes", []):       # volúmenes libres: (centro, tamaño, material[, rot])
            p.box(ex[0], ex[1], ex[2], rot=ex[3] if len(ex) > 3 else (0, 0, 0))
            if len(ex) > 4 and ex[4]:
                c, sz = ex[0], ex[1]
                self.collider((c[0] - sz[0] / 2, c[1] - sz[1] / 2, c[2] - sz[2] / 2), (c[0] + sz[0] / 2, c[1] + sz[1] / 2, c[2] + sz[2] / 2))
        if "custom" in s:
            s["custom"](self)

    def place(self):
        s = self.s
        for pr in s.get("props", []):
            name, x, y, rot = pr[0], pr[1], pr[2], pr[3]
            f = pr[4] if len(pr) > 4 else 0
            z = pr[5] if len(pr) > 5 else self.floor_z(f)
            self.meta["props"].append({"model": name, "pos": vb.g3((x, y, z)), "yaw": rot})
        for c in s.get("containers", []):
            name, x, y, rot, table = c[0], c[1], c[2], c[3], c[4]
            f = c[5] if len(c) > 5 else 0
            self.meta["containers"].append({"id": len(self.meta["containers"]), "model": name, "pos": vb.g3((x, y, self.floor_z(f))),
                                            "yaw": rot, "loot": table, "locked": c[6] if len(c) > 6 else ""})
        for l in s.get("loot", []):
            x, y, zoff, table = l[0], l[1], l[2], l[3]
            f = l[4] if len(l) > 4 else 0
            self.meta["loot"].append({"id": len(self.meta["loot"]), "pos": vb.g3((x, y, self.floor_z(f) + zoff)), "table": table})
        for l in s.get("lights", []):
            self.meta["lights"].append({"pos": vb.g3((l[0], l[1], l[2])), "color": l[3] if len(l) > 3 else [1.0, 0.85, 0.6], "range": l[4] if len(l) > 4 else 6.0})
        for k in ("doc", "station", "label", "safe_zone"):
            if k in s:
                self.meta[k] = s[k]

    def build(self):
        self.build_walls()
        self.build_floors()
        self.build_partitions()
        self.build_stairs()
        self.build_roof()
        self.build_extras()
        self.place()
        g = self.s.get("grime", (0.0, 1.1, (0.62, 0.6, 0.52)))
        ob = self.p.build(self.s["name"], bevel=0.0, smooth=35, ao=True, ao_dist=0.9, ao_strength=0.7, ao_samples=12,
                          ground=0.0, grime=g, weld=0.0015, sky=(16.0, self.s.get("dark", 0.46)))
        return ob


def run():
    import importlib, building_specs
    importlib.reload(building_specs)
    only = [a for a in sys.argv[sys.argv.index("--") + 1:]] if "--" in sys.argv else []
    vb.reset()
    index = {}
    for spec in building_specs.SPECS:
        if only and spec["name"] not in only:
            continue
        b = Building(spec)
        ob = b.build()
        vb.export([ob], "buildings/" + spec["name"])
        vb.write_json("buildings/%s.json" % spec["name"], b.meta)
        print("BUILDING %s tris=%d colliders=%d doors=%d" % (spec["name"], vb.tris(ob), len(b.meta["colliders"]), len(b.meta["doors"])))
        vb.clear_objects()


if __name__ == "__main__":
    run()
