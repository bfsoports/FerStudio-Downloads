"""gen_fp_arms.py — brazos en primera persona con esqueleto y animaciones.

Los brazos son los del superviviente generado con Hyper3D Rodin (mismas mangas, guantes con
dedos y texturas que ven los demás jugadores): se recortan del cuerpo, se llevan al espacio de
la cámara y se animan con cinemática inversa hacia posiciones de muñeca en ese espacio.

Ejecutar: blender -b --python tools/blender/gen_fp_arms.py [-- SRC]
La cámara está en el origen mirando a +Y de Blender (−Z en Godot). Mano derecha en +X.
Clips: fp_idle, fp_walk, fp_sprint, fp_interact, fp_pickup, fp_consume, fp_door, fp_search,
fp_build, fp_cold, fp_tired, fp_hold, fp_wave. El hueso «item.R» (palma derecha; Y = eje del
puño, Z = hacia los dedos) es el anclaje del objeto en mano.
"""
import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
import bpy, bmesh
from mathutils import Vector, Matrix, Quaternion
import vb, rig
import import_rodin as ir
from rig import env, smooth, arm_ik

if "--" in sys.argv and len(sys.argv) > sys.argv.index("--") + 1:
    ir.SRC = sys.argv[sys.argv.index("--") + 1]

S2 = 2 * math.pi
FPS = 30
SHOULDER = {"Right": Vector((0.24, -0.06, -0.24)), "Left": Vector((-0.24, -0.06, -0.24))}   # hombros en espacio de cámara
ARM_SCALE = 1.32                 # el personaje es de brazo corto: se alarga para llegar a las poses de cámara
CHAIN = ["Arm", "ForeArm", "Hand"] + ["Hand" + f + str(i) for f in ("Thumb", "Index", "Middle", "Ring", "Pinky") for i in (1, 2, 3)]


def build():
    arm, body = ir.load("survivor")
    arm.name = "FPArms"
    body.name = "body"
    ir.set_material(body, "ch_survivor")
    ir.normalize(arm, body, height=1.78)
    for act in list(bpy.data.actions):
        bpy.data.actions.remove(act)
    B = arm.data.bones
    # matriz por lado: giro de 180° (el cuerpo pasa a mirar a +Y), escala y hombro a su sitio de cámara
    M = {}
    for side in ("Left", "Right"):
        s0 = Matrix.Rotation(math.pi, 4, "Z") @ B[side + "Arm"].head_local
        M[side] = Matrix.Translation(SHOULDER[side]) @ Matrix.Scale(ARM_SCALE, 4) @ Matrix.Translation(-s0) @ Matrix.Rotation(math.pi, 4, "Z")
    keep = {side: [side + c for c in CHAIN] for side in ("Left", "Right")}
    gi = {g.index: g.name for g in body.vertex_groups}
    # cada vértice: suma de pesos por lado en la cadena del brazo; el resto del cuerpo se elimina
    side_of = {}
    for v in body.data.vertices:
        w = {"Left": 0.0, "Right": 0.0}
        for g in v.groups:
            n = gi[g.group]
            for side in w:
                if n in keep[side]:
                    w[side] += g.weight
        best = max(w, key=lambda k: w[k])
        if w[best] >= 0.5:
            side_of[v.index] = best
    # pesos de huesos que desaparecen (hombro, columna) → al brazo de su lado
    for vi, side in side_of.items():
        v = body.data.vertices[vi]
        extra = sum(g.weight for g in v.groups if gi[g.group] not in keep[side])
        if extra > 0:
            body.vertex_groups[side + "Arm"].add([vi], extra, "ADD")
    for g in list(body.vertex_groups):
        if g.name not in keep["Left"] and g.name not in keep["Right"]:
            body.vertex_groups.remove(g)
    for vi, side in side_of.items():
        v = body.data.vertices[vi]
        v.co = M[side] @ v.co
    bm = bmesh.new()
    bm.from_mesh(body.data)
    bm.verts.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.index not in side_of], context="VERTS")
    bm.to_mesh(body.data)
    bm.free()
    body.data.update()
    # esqueleto: solo las dos cadenas de brazo bajo una raíz, más el anclaje del objeto en mano
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm.data.edit_bones
    all_keep = set(keep["Left"]) | set(keep["Right"])
    for side in ("Left", "Right"):
        for n in keep[side]:
            eb[n].transform(M[side])
    for b in list(eb):
        if b.name not in all_keep:
            eb.remove(b)
    root = eb.new("root")
    root.head = (0, 0, 0)
    root.tail = (0, 0.1, 0)
    for side in ("Left", "Right"):
        eb[side + "Arm"].parent = root
        eb[side + "Arm"].use_connect = False
    hand = eb["RightHand"]
    idx, pnk, mid = eb["RightHandIndex1"].head, eb["RightHandPinky1"].head, eb["RightHandMiddle1"].head
    n = (idx - hand.head).cross(pnk - hand.head).normalized()
    if n.dot(Vector((-1, 0, -1))) < 0:
        n = -n
    palm = hand.head.lerp(mid, 0.85) + n * 0.04
    it = eb.new("item.R")
    it.head = palm
    it.tail = palm + (idx - pnk).normalized() * 0.1
    it.parent = hand
    it.align_roll((mid - hand.head).normalized())
    bpy.ops.object.mode_set(mode="OBJECT")
    B = arm.data.bones
    REST = {}
    for side in ("Left", "Right"):
        REST[side + "Arm"] = (B[side + "Arm"].head_local.copy(), B[side + "ForeArm"].head_local.copy())
        REST[side + "ForeArm"] = (B[side + "ForeArm"].head_local.copy(), B[side + "Hand"].head_local.copy())
        REST[side + "Hand"] = (B[side + "Hand"].head_local.copy(), B[side + "HandMiddle1"].head_local.copy())
    axes = ir.finger_axes(B)
    # el pulgar del reposo en A queda muy abierto: se arrima al índice antes de flexionarlo
    adduct = {}
    for side in ("Left", "Right"):
        d_th = (B[side + "HandThumb2"].head_local - B[side + "HandThumb1"].head_local).normalized()
        d_fi = (B[side + "HandIndex1"].head_local - B[side + "Hand"].head_local).normalized()
        adduct[side + "HandThumb1"] = Quaternion(d_th.cross(d_fi).normalized(), math.radians(34))

    an = rig.Animator(arm, fps=FPS)
    RW = Vector((0.2, 0.42, -0.31)); LW = Vector((-0.2, 0.42, -0.31))
    FWD = (0, 1, 0.25)

    def arms(r=None, l=None, rdir=FWD, ldir=FWD, grip_r=1.0, grip_l=1.0, tw_r=0.0, tw_l=0.0):
        pose = {}
        arm_ik(pose, ("RightArm", "RightForeArm", "RightHand"), REST, r if r is not None else RW, (0.5, -0.1, -0.7), (rdir[0] - 0.12, rdir[1], rdir[2]), roll=ROLL, twist=TWIST + tw_r)
        arm_ik(pose, ("LeftArm", "LeftForeArm", "LeftHand"), REST, l if l is not None else LW, (-0.5, -0.1, -0.7), (ldir[0] + 0.12, ldir[1], ldir[2]), roll=-ROLL, twist=-TWIST - tw_l)
        for b, (axis, ang) in axes.items():
            k = grip_r if b.startswith("Right") else grip_l
            if "Thumb" in b:
                ang *= 2.4                      # el pulgar se recoge sobre el índice
            pose[b] = Quaternion(axis, math.radians(min(ang * k, 88.0)))
            if b in adduct:
                pose[b] = adduct[b] @ pose[b]
        return pose

    def idle(t):
        b = math.sin(S2 * t)
        return arms(RW + Vector((0, 0, 0.006 * b)), LW + Vector((0, 0, 0.006 * b)))

    def walk(t):
        b, c = math.sin(2 * S2 * t), math.sin(S2 * t)
        return arms(RW + Vector((0.008 * c, 0.02 * c, 0.016 * b + 0.01)), LW + Vector((0.008 * c, -0.02 * c, 0.016 * b + 0.01)))

    def sprint(t):
        c, s_ = math.cos(S2 * t), math.sin(S2 * t)
        return arms(Vector((0.19, 0.36 + 0.13 * c, -0.2 + 0.07 * abs(s_))), Vector((-0.19, 0.36 - 0.13 * c, -0.2 + 0.07 * abs(s_))), (0, 0.8, 0.7), (0, 0.8, 0.7), grip_r=2.2, grip_l=2.2)

    def interact(t):
        e = env(t, 0.0, 0.4, 0.55, 1.0)
        return arms(RW.lerp(Vector((0.1, 0.62, -0.1)), e), grip_r=1.0 - 0.6 * e)

    def pickup(t):
        down = env(t, 0.0, 0.35, 0.45, 0.8)
        up = smooth((t - 0.45) / 0.3) * (1 - smooth((t - 0.8) / 0.2))
        tgt = RW.lerp(Vector((0.07, 0.58, -0.3)), down).lerp(Vector((0.12, 0.42, -0.16)), up)
        return arms(tgt, None, (0, 1, -0.5 * down + 0.4 * up), grip_r=0.5 + 1.8 * smooth((t - 0.35) / 0.15) * (1 - smooth((t - 0.85) / 0.15)))

    def consume(t):
        e = env(t, 0.0, 0.22, 0.75, 1.0)
        sip = env(t, 0.28, 0.4, 0.62, 0.74)
        tgt = RW.lerp(Vector((0.06, 0.24, -0.12 + 0.03 * sip)), e)
        return arms(tgt, None, (-0.5 * e, 1 - 1.2 * e, 0.25 + 0.9 * e + 0.5 * sip), grip_r=1.0 + 1.3 * e)

    def door(t):
        e = env(t, 0.0, 0.3, 0.45, 1.0)
        push = env(t, 0.25, 0.5, 0.6, 0.9)
        return arms(None, LW.lerp(Vector((-0.12, 0.56 + 0.12 * push, -0.08)), e), FWD, (0, 1, 0.9 * e), grip_l=1.0 - 0.7 * e)

    def search(t):
        s_ = math.sin(S2 * t)
        return arms(Vector((0.14, 0.54 + 0.07 * s_, -0.2 + 0.02 * s_)), Vector((-0.14, 0.54 - 0.07 * s_, -0.2 - 0.02 * s_)), (0, 1, -0.2), (0, 1, -0.2),
                    grip_r=1.0 + 0.8 * max(0.0, s_), grip_l=1.0 + 0.8 * max(0.0, -s_))

    def build_(t):
        k = (1 - math.cos(S2 * t)) * 0.5
        hit = k ** 3
        return arms(Vector((0.17, 0.46 + 0.08 * hit, 0.0 - 0.22 * hit)), Vector((-0.14, 0.56, -0.2)), (0, 1 - 0.3 * (1 - hit), 0.9 - 1.1 * hit), (0.3, 1, 0.1), grip_r=2.4, grip_l=0.6, tw_r=18.0)

    def cold(t):
        s_ = math.sin(S2 * t * 2)
        sh = 0.004 * math.sin(S2 * t * 11)
        return arms(Vector((0.05 + 0.02 * s_ + sh, 0.42, -0.2)), Vector((-0.05 - 0.02 * s_ + sh, 0.42, -0.21)), (-0.7, 1, 0.5), (0.7, 1, 0.5), grip_r=1.6, grip_l=1.6)

    def tired(t):
        b = math.sin(S2 * t)
        return arms(RW + Vector((0.02, -0.03, -0.03 + 0.022 * b)), LW + Vector((-0.02, -0.03, -0.03 + 0.022 * b)), (0, 1, -0.3), (0, 1, -0.3))

    def hold(t):
        b = math.sin(S2 * t)
        return arms(Vector((0.25, 0.42, -0.19 + 0.006 * b)), None, (0, 1, 0.2), grip_r=2.4, tw_r=18.0)

    def wave(t):
        e = env(t, 0.0, 0.2, 0.8, 1.0)
        w = math.sin(S2 * t * 3)
        return arms(RW.lerp(Vector((0.24 + 0.05 * w, 0.5, 0.02)), e), None, (0.2 * w, 0.3, 1.0), grip_r=1.0 - 0.7 * e)

    an.clip("fp_idle", 3.0, idle); an.clip("fp_walk", 1.0, walk); an.clip("fp_sprint", 0.56, sprint)
    an.clip("fp_interact", 0.6, interact, loop=False, step=1); an.clip("fp_pickup", 0.9, pickup, loop=False, step=1)
    an.clip("fp_consume", 1.6, consume, loop=False); an.clip("fp_door", 0.8, door, loop=False, step=1); an.clip("fp_search", 1.6, search)
    an.clip("fp_build", 0.8, build_, step=1); an.clip("fp_cold", 2.0, cold, step=1); an.clip("fp_tired", 2.4, tired); an.clip("fp_hold", 3.0, hold)
    an.clip("fp_wave", 1.4, wave, loop=False)
    an.finish()
    vb.export([arm, body], "characters/fp_arms", anim=True)
    vb.write_json("models/fp_arms.json", {"clips": an.clips, "tris": ir.tris(body), "source": "rodin"})
    print("FPARMS tris=%d clips=%d" % (ir.tris(body), len(an.clips)))


ROLL = float(os.environ.get("VB_FP_ROLL", "0"))
TWIST = float(os.environ.get("VB_FP_TWIST", "-18"))   # antebrazo algo pronado en reposo; +18 deja el puño vertical

if __name__ == "__main__":
    build()
