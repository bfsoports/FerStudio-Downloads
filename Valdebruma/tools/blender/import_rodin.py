"""import_rodin.py — integra en el juego los modelos generados con Hyper3D Rodin.

Los modelos complejos (superviviente, Brumal, Zarzo y vehículos) se generaron con Rodin
(malla + texturas PBR) y, los animados, se pasaron por su auto-rig con clips del catálogo.
Este script los deja listos para móvil y con las convenciones del proyecto:

  · escala real, origen en el suelo y frente hacia −Y en Blender (+Z en Godot);
  · un único material por nombre (las texturas reducidas viven en assets/textures/pbr/rd_*,
    ver tools/textures/rodin_textures.py) → el GLB no lleva imágenes incrustadas;
  · clips renombrados a los nombres que usa el juego, ajustados a fotogramas enteros;
  · superviviente: se añaden los clips de acción (interactuar, recoger, consumir, abrir puerta,
    registrar, construir, frío, saludar, saltar, caer, aterrizar, agachado quieto, girar)
    reorientando al esqueleto de Rodin las poses de gen_character.py; se añaden gorro,
    mochilas y mascarilla ajustados a su cuerpo y el hueso «item.R» para lo que lleva en la mano;
  · criaturas: clips extra derivados (descanso con la cabeza baja, enterrado).

Uso: blender -b --python tools/blender/import_rodin.py -- <survivor|brumal|zarzo|vehicles|all> [SRC]
SRC (por defecto /root/tools/rodin) contiene <modelo>/rigged.glb tal y como lo entrega Rodin.
"""
import sys, os, math, json
sys.path.insert(0, os.path.dirname(__file__))
import bpy
from mathutils import Vector, Matrix, Quaternion, Euler
import vb, rig

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else ["all"]
SRC = ARGS[1] if len(ARGS) > 1 else "/root/tools/rodin"
FPS = 24


# ------------------------------- utilidades comunes -------------------------------------------
def load(name):
    vb.reset()
    bpy.ops.import_scene.gltf(filepath=os.path.join(SRC, name, "rigged.glb"))
    bpy.context.scene.render.fps = FPS
    ico = bpy.data.objects.get("Icosphere")
    if ico is not None:
        bpy.data.objects.remove(ico, do_unlink=True)
    arm = next((o for o in bpy.data.objects if o.type == "ARMATURE"), None)
    mesh = next(o for o in bpy.data.objects if o.type == "MESH")
    for im in list(bpy.data.images):
        bpy.data.images.remove(im)
    return arm, mesh


def set_material(mesh, name):
    """Sustituye el material incrustado por uno vacío con el nombre del juego."""
    mat = bpy.data.materials.new(name)
    mesh.data.materials.clear()
    mesh.data.materials.append(mat)
    for poly in mesh.data.polygons:
        poly.use_smooth = True


def bounds(mesh):
    xs = [v.co for v in mesh.data.vertices]
    return Vector((min(c.x for c in xs), min(c.y for c in xs), min(c.z for c in xs))), Vector((max(c.x for c in xs), max(c.y for c in xs), max(c.z for c in xs)))


def normalize(arm, mesh, height=None, length=None, yaw=0.0, center_xy=False):
    """Escala a tamaño real, apoya en el suelo y (opcional) gira/centra. Devuelve el factor."""
    lo, hi = bounds(mesh)
    s = height / (hi.z - lo.z) if height else length / (hi.y - lo.y)
    cx, cy = ((lo.x + hi.x) / 2, (lo.y + hi.y) / 2) if center_xy else (0.0, 0.0)
    M = Matrix.Rotation(math.radians(yaw), 4, "Z") @ Matrix.Scale(s, 4) @ Matrix.Translation((-cx, -cy, -lo.z))
    mesh.data.transform(M)
    mesh.data.update()
    if arm is not None:
        arm.data.transform(M)
        for act in bpy.data.actions:
            for fc in act.fcurves:
                if fc.data_path.endswith("location"):
                    for kp in fc.keyframe_points:
                        kp.co.y *= s
                        kp.handle_left.y *= s
                        kp.handle_right.y *= s
    return s


def retime(act):
    """Lleva el clip a empezar en el fotograma 1 y terminar en un fotograma entero."""
    a, b = act.frame_range
    n = max(2, int(round(b - a)))
    k = n / (b - a)
    for fc in act.fcurves:
        for kp in fc.keyframe_points:
            x = (kp.co.x - a) * k + 1
            kp.co.x = x
            kp.handle_left.x = x - 0.3
            kp.handle_right.x = x + 0.3
            kp.interpolation = "LINEAR"
        fc.update()
    return n


def rename_clips(arm, table):
    """table: id de catálogo → (nombre, bucle). Devuelve {nombre: {length, loop}}."""
    clips = {}
    for act in list(bpy.data.actions):
        key = act.name.replace("_Armature", "")
        if key not in table:
            bpy.data.actions.remove(act)
            continue
        name, loop = table[key]
        act.name = name
        n = retime(act)
        act.use_fake_user = True
        clips[name] = {"length": round(n / FPS, 4), "loop": loop}
    return clips


def sample(arm, act, bones):
    """Posiciones (espacio del esqueleto) de las cabezas de 'bones' en cada fotograma del clip."""
    arm.animation_data_create()
    arm.animation_data.action = act
    a, b = [int(round(v)) for v in act.frame_range]
    out = []
    for f in range(a, b + 1):
        bpy.context.scene.frame_set(f)
        out.append([arm.pose.bones[n].head.copy() for n in bones])
    return out


def in_place(arm, act, root="Hips"):
    """Quita el desplazamiento horizontal neto de la raíz (los bucles deben quedarse en el sitio)."""
    R = arm.data.bones[root].matrix_local.to_3x3()
    fcs = [fc for fc in act.fcurves if fc.data_path == 'pose.bones["%s"].location' % root]
    if len(fcs) < 3:
        return 0.0
    fcs.sort(key=lambda fc: fc.array_index)
    a, b = act.frame_range
    first = R @ Vector([fc.evaluate(a) for fc in fcs])
    last = R @ Vector([fc.evaluate(b) for fc in fcs])
    drift = Vector((last.x - first.x, last.y - first.y, 0.0))
    if drift.length < 0.02:
        return drift.length
    frames = sorted({kp.co.x for fc in fcs for kp in fc.keyframe_points})
    vals = {f: R @ Vector([fc.evaluate(f) for fc in fcs]) for f in frames}
    for f in frames:
        t = (f - a) / (b - a)
        w = R.inverted() @ (vals[f] - drift * t)
        for i, fc in enumerate(fcs):
            fc.keyframe_points.insert(f, w[i], options={"REPLACE"}).interpolation = "LINEAR"
    return drift.length


def gait_speed(arm, act, feet):
    """Velocidad (m/s) que representa un ciclo en el sitio: lo que retrocede el pie apoyado."""
    pts = sample(arm, act, feet)
    best = []
    for i in range(len(feet)):
        zs = [p[i].z for p in pts]
        zmin = min(zs)
        v = [(pts[f + 1][i].y - pts[f][i].y) * FPS for f in range(len(pts) - 1) if zs[f] < zmin + 0.035 and zs[f + 1] < zmin + 0.035]
        v = sorted(x for x in v if x > 0.05)
        if v:
            best.append(v[len(v) // 2])
    return round(sum(best) / len(best), 2) if best else 0.0


def offset_clip(arm, src, name, deltas, speed=1.0):
    """Copia un clip añadiendo giros constantes (grados, ejes del esqueleto) a algunos huesos."""
    act = src.copy()
    act.name = name
    act.use_fake_user = True
    for bone, eul in deltas.items():
        R = arm.data.bones[bone].matrix_local.to_3x3()
        q_add = (R.inverted() @ Euler([math.radians(a) for a in eul], "XYZ").to_matrix() @ R).to_quaternion()
        fcs = sorted([fc for fc in act.fcurves if fc.data_path == 'pose.bones["%s"].rotation_quaternion' % bone], key=lambda fc: fc.array_index)
        if len(fcs) < 4:
            continue
        frames = sorted({kp.co.x for fc in fcs for kp in fc.keyframe_points})
        for f in frames:
            q = q_add @ Quaternion([fc.evaluate(f) for fc in fcs])
            for i, fc in enumerate(fcs):
                fc.keyframe_points.insert(f, q[i], options={"REPLACE"}).interpolation = "LINEAR"
    if speed != 1.0:
        for fc in act.fcurves:
            for kp in fc.keyframe_points:
                kp.co.x = (kp.co.x - 1) / speed + 1
            fc.update()
    return act


def hold_clip(arm, src, name, at_end=True, seconds=2.0):
    """Clip estático con la pose final (o inicial) de otro."""
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    f_src = src.frame_range[1] if at_end else src.frame_range[0]
    n = int(round(seconds * FPS))
    for fc in src.fcurves:
        nf = act.fcurves.new(fc.data_path, index=fc.array_index, action_group=fc.group.name if fc.group else "")
        v = fc.evaluate(f_src)
        nf.keyframe_points.insert(1, v)
        nf.keyframe_points.insert(n + 1, v)
    return act


def finish(arm, names):
    """Cada acción a una pista NLA para que el exportador glTF las incluya todas."""
    ad = arm.animation_data or arm.animation_data_create()
    ad.action = None
    for name in names:
        act = bpy.data.actions[name]
        tr = ad.nla_tracks.new()
        tr.name = name
        tr.strips.new(name, int(round(act.frame_range[0])), act)
    for pb in arm.pose.bones:
        pb.rotation_quaternion = Quaternion()
        pb.location = (0, 0, 0)
        pb.scale = (1, 1, 1)
    bpy.context.scene.frame_set(1)


def rigid(ob, arm, bone):
    """Une un objeto a un único hueso (peso 1)."""
    for g in list(ob.vertex_groups):
        ob.vertex_groups.remove(g)
    g = ob.vertex_groups.new(name=bone)
    g.add(list(range(len(ob.data.vertices))), 1.0, "REPLACE")
    for m in list(ob.modifiers):
        if m.type == "ARMATURE":
            ob.modifiers.remove(m)
    mod = ob.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    ob.parent = arm


def weighted(mesh, bones, thr=0.5):
    """Vértices cuya suma de pesos en 'bones' supera thr."""
    idx = {mesh.vertex_groups[b].index for b in bones if b in mesh.vertex_groups}
    out = []
    for v in mesh.data.vertices:
        w = sum(g.weight for g in v.groups if g.group in idx)
        if w >= thr:
            out.append(v.co.copy())
    return out


def tris(ob):
    ob.data.calc_loop_triangles()
    return len(ob.data.loop_triangles)


# ------------------------------- superviviente -------------------------------------------------
HUMAN = {"human_000093": ("idle", True), "human_000089": ("walk", True), "human_000029": ("jog", True), "human_000067": ("sprint", True),
         "human_000073": ("crouch_walk", True), "human_000085": ("sit_chair", True), "human_000074": ("faint", False),
         "human_000061": ("swim", True), "human_000050": ("tired", True), "human_000041": ("point", False)}

PMAP = {"hips": "Hips", "spine": "Spine", "chest": "Spine2", "neck": "Neck", "head": "Head"}
for _p, _r in (("L", "Left"), ("R", "Right")):
    PMAP.update({"shoulder." + _p: _r + "Shoulder", "upper_arm." + _p: _r + "Arm", "forearm." + _p: _r + "ForeArm", "hand." + _p: _r + "Hand",
                 "thigh." + _p: _r + "UpLeg", "shin." + _p: _r + "Leg", "foot." + _p: _r + "Foot"})
CHILD = {}
for _r in ("Left", "Right"):
    CHILD.update({_r + "Arm": _r + "ForeArm", _r + "ForeArm": _r + "Hand", _r + "UpLeg": _r + "Leg", _r + "Leg": _r + "Foot", _r + "Foot": _r + "ToeBase"})


class Retarget:
    """Convierte las poses del esqueleto procedimental (gen_character) al de Rodin.

    Las poses son giros jerárquicos en ejes del esqueleto respecto al reposo. Si C_h lleva la
    dirección de reposo del hueso de Rodin a la del procedimental, el giro equivalente es
    D' = C_padre⁻¹ · D · C_h (así la orientación final en el mundo coincide)."""

    def __init__(self, arm):
        import gen_character as gc
        self.gc = gc
        proc = {b[0]: (Vector(b[1]), Vector(b[2])) for b in gc.bones()}
        B = arm.data.bones
        self.C = {}
        for pn, rn in PMAP.items():
            if rn in CHILD:
                d_r = (B[CHILD[rn]].head_local - B[rn].head_local).normalized()
                d_p = (proc[pn][1] - proc[pn][0]).normalized()
                self.C[rn] = d_r.rotation_difference(d_p)
            else:
                self.C[rn] = Quaternion()
        for r in ("Left", "Right"):
            self.C[r + "Hand"] = self.C[r + "ForeArm"].copy()
        inv = {v: k for k, v in PMAP.items()}
        self.parent = {}
        for rn in PMAP.values():
            p = B[rn].parent
            while p is not None and p.name not in inv:
                p = p.parent
            self.parent[rn] = p.name if p is not None else None
        # proporción de piernas y altura de cadera para trasladar el desplazamiento de la pelvis
        l1 = (B["LeftLeg"].head_local - B["LeftUpLeg"].head_local).length
        l2 = (B["LeftFoot"].head_local - B["LeftLeg"].head_local).length
        self.k = (l1 + l2) / (gc.L1 + gc.L2)
        self.dz0 = B["LeftFoot"].head_local.z - B["LeftUpLeg"].head_local.z + self.k * (gc.HIP_Z - gc.ANKLE_Z)
        # dedos: flexión suave constante (mano relajada)
        self.curl = {}
        for r, sg in (("Left", 1), ("Right", -1)):
            hand = B[r + "Hand"].head_local
            n = (B[r + "HandIndex1"].head_local - hand).cross(B[r + "HandPinky1"].head_local - hand).normalized()
            if n.dot(Vector((-sg, 0, -1))) < 0:
                n = -n
            for finger, angs in (("Index", (22, 30, 20)), ("Middle", (26, 34, 22)), ("Ring", (30, 36, 24)), ("Pinky", (34, 38, 24)), ("Thumb", (6, 12, 10))):
                for i, ang in enumerate(angs):
                    b = B[r + "Hand" + finger + str(i + 1)]
                    d = ((b.children[0].head_local if b.children else b.tail_local) - b.head_local).normalized()
                    axis = d.cross(n)
                    if axis.length > 1e-4:
                        self.curl[b.name] = Quaternion(axis.normalized(), math.radians(ang))

    def __call__(self, fn, grip=1.0):
        def wrapped(t):
            pose = fn(t)
            out = {}
            for pn, rn in PMAP.items():
                v = pose.get(pn, (0, 0, 0))
                D = v if isinstance(v, Quaternion) else Euler([math.radians(a) for a in v], "XYZ").to_quaternion()
                Cp = self.C[self.parent[rn]] if self.parent[rn] else Quaternion()
                out[rn] = Cp.inverted() @ D @ self.C[rn]
            loc = pose.get("hips:loc", (0, 0, 0))
            out["Hips:loc"] = (loc[0] * self.k, loc[1] * self.k, loc[2] * self.k + self.dz0)
            for b, q in self.curl.items():
                out[b] = q
            return out
        return wrapped


def fit_extras(arm, body, R):
    """Gorro, mochilas y mascarilla de gen_character ajustados al cuerpo de Rodin."""
    gc = R.gc
    hat, pack_s, pack_l, mask = gc.extras()
    B = arm.data.bones
    head = weighted(body, ["Head"], 0.6)
    top = max(c.z for c in head)

    def band(pts, z0, z1):
        sel = [c for c in pts if z0 <= c.z <= z1]
        xs = [c.x for c in sel]; ys = [c.y for c in sel]
        return (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, (max(xs) - min(xs)) / 2, (max(ys) - min(ys)) / 2

    # gorro: su borde (radio 0.1 a z=1.685; copa hasta 1.838) abraza la cabeza por encima de las cejas
    cx, cy, hx, hy = band(head, top - 0.115, top - 0.05)
    sx, sy = hx * 1.07 / 0.1, hy * 1.07 / 0.1
    M = Matrix.Translation((cx, cy, top + 0.014)) @ Matrix.Diagonal((sx, sy, 1.0, 1.0)) @ Matrix.Translation((0, 0, -1.838))
    hat.data.transform(M)
    # mascarilla: la cinta (radios 0.094×0.107 a z≈1.637) rodea la cabeza a la altura de la boca
    zm = top - 0.185
    cx2, cy2, mx, my = band(head, zm - 0.02, zm + 0.03)
    M = Matrix.Translation((cx2, cy2, zm)) @ Matrix.Diagonal((mx * 1.04 / 0.094, my * 1.04 / 0.107, 1.0, 1.0)) @ Matrix.Translation((0, 0.005, -1.628))
    mask.data.transform(M)
    for ob in (hat, mask):
        ob.data.update()
        rigid(ob, arm, "Head")
    # mochilas: espalda (y=0.12 en el modelo procedimental) y hombros (z=1.47) → los de Rodin
    torso = weighted(body, ["Spine1", "Spine2"], 0.6)
    z_sh = B["LeftArm"].head_local.z + 0.05
    z_hip = B["Hips"].head_local.z
    kz = (z_sh - z_hip) / (1.47 - 0.95)
    chest = [c for c in torso if z_hip + 0.25 < c.z < z_sh - 0.05 and abs(c.x) < 0.12]
    y_back = max(c.y for c in chest)
    y_front = min(c.y for c in chest)
    ky = (y_back - y_front) / (0.12 + 0.115)
    kx = B["LeftArm"].head_local.x / 0.185
    for ob in (pack_s, pack_l):
        M = Matrix.Translation((0, y_back + 0.004, z_sh)) @ Matrix.Diagonal((kx, max(ky, 0.9), kz, 1.0)) @ Matrix.Translation((0, -0.12, -1.47))
        ob.data.transform(M)
        ob.data.update()
        rigid(ob, arm, "Spine2")
    return [hat, pack_s, pack_l, mask]


def add_item_bone(arm):
    """Hueso «item.R»: origen en la palma, Y del puño (meñique→índice), Z hacia los dedos."""
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm.data.edit_bones
    hand = eb["RightHand"]
    idx, pnk, mid = eb["RightHandIndex1"].head, eb["RightHandPinky1"].head, eb["RightHandMiddle1"].head
    n = (idx - hand.head).cross(pnk - hand.head).normalized()
    if n.dot(Vector((1, 0, -1))) < 0:
        n = -n
    palm = hand.head.lerp(mid, 0.8) + n * 0.03
    b = eb.new("item.R")
    b.head = palm
    b.tail = palm + (idx - pnk).normalized() * 0.1
    b.parent = hand
    b.align_roll((mid - hand.head).normalized())
    bpy.ops.object.mode_set(mode="OBJECT")


def survivor():
    arm, body = load("survivor")
    arm.name = "Survivor"
    body.name = "body"
    set_material(body, "ch_survivor")
    normalize(arm, body, height=1.78)
    clips = rename_clips(arm, HUMAN)
    for name in ("idle", "walk", "jog", "sprint", "crouch_walk", "swim", "tired", "sit_chair"):
        in_place(arm, bpy.data.actions[name])
    measured = {name: gait_speed(arm, bpy.data.actions[name], ["LeftFoot", "RightFoot"]) for name in ("walk", "jog", "sprint", "crouch_walk")}
    # en carrera el apoyo es tan breve que la medida se queda corta: trote y esprint se fijan a mano
    for name, v in (("walk", measured["walk"]), ("crouch_walk", measured["crouch_walk"]), ("jog", 3.0), ("sprint", 5.6)):
        clips[name]["speed"] = v
    R = Retarget(arm)
    gc = R.gc
    add_item_bone(arm)
    an = rig.Animator(arm, fps=FPS)
    an.clip("crouch_idle", 3.0, R(lambda t: gc.crouch(t, False)))
    an.clip("turn", 0.7, R(lambda t: gc.gait(t, 0.16, 0.6, 0.05, -0.02, 0.008, 2, 4, 14, 2)))
    an.clip("jump", 0.45, R(gc.jump), loop=False, step=1)
    an.clip("fall", 0.9, R(gc.fall))
    an.clip("land", 0.4, R(gc.land), loop=False, step=1)
    an.clip("interact", 0.8, R(gc.interact), loop=False)
    an.clip("pickup", 1.0, R(gc.pickup), loop=False)
    an.clip("consume", 1.7, R(gc.consume), loop=False)
    an.clip("open_door", 0.9, R(gc.open_door), loop=False)
    an.clip("search", 1.8, R(gc.search))
    an.clip("build", 0.8, R(gc.build))
    an.clip("cold", 2.0, R(gc.cold), step=1)
    an.clip("wave", 1.6, R(gc.wave), loop=False)
    an.clip("sit", 3.2, R(gc.sit))
    clips.update(an.clips)
    extras = fit_extras(arm, body, R)
    finish(arm, sorted(clips))
    parts = [body] + extras
    vb.export([arm] + parts, "characters/survivor", anim=True)
    B = arm.data.bones
    vb.write_json("models/survivor.json", {"clips": clips, "tris": sum(tris(o) for o in parts), "source": "rodin",
                                            "head_y": round(B["Head"].head_local.z, 3), "height": 1.78})
    print("SURVIVOR tris=%d clips=%d" % (sum(tris(o) for o in parts), len(clips)), {k: v.get("speed") for k, v in clips.items() if "speed" in v})


# ------------------------------- criaturas -----------------------------------------------------
BRUMAL = {"heavyhooved_000014": ("idle", True), "heavyhooved_000023": ("look", True), "heavyhooved_000013": ("walk", True),
          "heavyhooved_000018": ("search", True), "heavyhooved_000010": ("trot", True), "heavyhooved_000005": ("run", True),
          "heavyhooved_000007": ("sniff", True), "heavyhooved_000025": ("alert", False), "heavyhooved_000002": ("charge", False),
          "heavyhooved_000022": ("flinch", False)}
ZARZO = {"rodentia_000008": ("idle", True), "rodentia_000007": ("walk", True), "rodentia_000002": ("run", True),
         "rodentia_000004": ("forage", True), "rodentia_000011": ("dig", True), "rodentia_000013": ("alert", True),
         "rodentia_000017": ("stunned", False), "rodentia_000022": ("curl", False), "rodentia_000025": ("uncurl", False),
         "rodentia_000001": ("scratch", False)}
QUAD_FEET = ["LeftFrontFoot", "RightFrontFoot", "LeftHindFoot", "RightHindFoot"]


def brumal():
    arm, body = load("brumal")
    arm.name = "Brumal"
    body.name = "body"
    set_material(body, "cr_brumal")
    normalize(arm, body, height=2.05, center_xy=False)
    clips = rename_clips(arm, BRUMAL)
    for name in ("idle", "look", "walk", "search", "trot", "run", "sniff"):
        in_place(arm, bpy.data.actions[name])
    for name in ("walk", "search", "trot", "run"):
        clips[name]["speed"] = gait_speed(arm, bpy.data.actions[name], QUAD_FEET)
    # descanso: el reposo con el cuello vencido y más lento (recuperándose tras huir de la luz)
    offset_clip(arm, bpy.data.actions["idle"], "rest", {"Neck": (-22, 0, 0), "Neck1": (-18, 0, 0), "Head": (-12, 0, 0), "Spine3": (-4, 0, 0)}, speed=0.7)
    clips["rest"] = {"length": round(clips["idle"]["length"] / 0.7, 4), "loop": True}
    finish(arm, sorted(clips))
    vb.export([arm, body], "creatures/brumal", anim=True)
    lo, hi = bounds(body)
    vb.write_json("models/brumal.json", {"clips": clips, "tris": tris(body), "source": "rodin", "size": [round(hi.x - lo.x, 2), round(hi.z, 2), round(hi.y - lo.y, 2)]})
    print("BRUMAL tris=%d clips=%d size=%s" % (tris(body), len(clips), [round(hi.x - lo.x, 2), round(hi.z, 2), round(hi.y - lo.y, 2)]), {k: v.get("speed") for k, v in clips.items() if "speed" in v})


def zarzo():
    arm, body = load("zarzo")
    arm.name = "Zarzo"
    body.name = "body"
    set_material(body, "cr_zarzo")
    normalize(arm, body, length=0.72)
    clips = rename_clips(arm, ZARZO)
    for name in ("idle", "walk", "run", "forage", "dig", "alert"):
        in_place(arm, bpy.data.actions[name])
    for name in ("walk", "run"):
        clips[name]["speed"] = gait_speed(arm, bpy.data.actions[name], QUAD_FEET)
    hold_clip(arm, bpy.data.actions["curl"], "curled", at_end=True, seconds=2.0)
    clips["curled"] = {"length": 2.0, "loop": True}
    finish(arm, sorted(clips))
    vb.export([arm, body], "creatures/zarzo", anim=True)
    lo, hi = bounds(body)
    vb.write_json("models/zarzo.json", {"clips": clips, "tris": tris(body), "source": "rodin", "size": [round(hi.x - lo.x, 2), round(hi.z, 2), round(hi.y - lo.y, 2)]})
    print("ZARZO tris=%d clips=%d size=%s" % (tris(body), len(clips), [round(hi.x - lo.x, 2), round(hi.z, 2), round(hi.y - lo.y, 2)]), {k: v.get("speed") for k, v in clips.items() if "speed" in v})


# ------------------------------- vehículos -----------------------------------------------------
# origen → (modelos de salida [(nombre, material)], largo en metros, giro para que el morro mire a −Y, huecos de maletero)
VEHICLES = {"car_sedan": ([("car_sedan", "veh_sedan"), ("car_sedan_red", "veh_sedan_red")], 4.2, 0.0, 6),
            "car_van": ([("car_van", "veh_van")], 4.6, 0.0, 10),
            "tractor": ([("tractor", "veh_tractor")], 3.0, 0.0, 0)}


def vehicles():
    path = os.path.join(vb.DATA, "models", "props.json")
    props = json.load(open(path))
    for src, (outs, length, yaw, slots) in VEHICLES.items():
        for name, mat in outs:
            _, mesh = load(src)
            mesh.name = name
            set_material(mesh, mat)
            normalize(None, mesh, length=length, yaw=yaw, center_xy=True)
            lo, hi = bounds(mesh)
            vb.export([mesh], "props/" + name)
            size = [round(hi.x - lo.x, 3), round(hi.z, 3), round(hi.y - lo.y, 3)]
            entry = {"size": size, "center": [0.0, round(hi.z / 2, 3), 0.0], "solid": True, "tris": tris(mesh), "source": "rodin",
                     "collider": [round(size[0] * 0.94, 2), round(size[1] * 0.96, 2), round(size[2] * 0.95, 2)]}
            if slots:
                entry["container"] = {"lid": {"type": "none"}, "slots": slots}
            props[name] = entry
            print("VEHICLE", name, size, tris(mesh))
    with open(path, "w") as f:
        json.dump(props, f, separators=(",", ":"), sort_keys=True)


if __name__ == "__main__":
    what = ARGS[0] if ARGS else "all"
    if what in ("survivor", "all"):
        survivor()
    if what in ("brumal", "all"):
        brumal()
    if what in ("zarzo", "all"):
        zarzo()
    if what in ("vehicles", "all"):
        vehicles()
