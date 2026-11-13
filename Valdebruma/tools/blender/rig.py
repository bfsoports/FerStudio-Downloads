"""rig.py — esqueletos, pesos y animación por script para Valdebruma (Blender 4.2).

- make_armature(): crea el esqueleto a partir de una lista de huesos.
- skin(): pesos automáticos por distancia a los segmentos de hueso, limitados a los
  huesos permitidos para cada "parte" de la malla (etiquetas de vb.Parts.cur_part).
- Animator: hornea clips muestreando una función pose(t) -> {hueso: (rx, ry, rz)} con
  giros en grados respecto a los ejes del esqueleto en reposo (X lateral, Y fondo, Z arriba).
- leg_ik(): cinemática inversa analítica de dos huesos en el plano sagital.
"""
import math
import bpy
from mathutils import Vector, Matrix, Euler, Quaternion


def make_armature(name, bones):
    """bones: [(nombre, cabeza, cola, padre|None), ...] en coordenadas de objeto."""
    arm = bpy.data.armatures.new(name)
    ob = bpy.data.objects.new(name, arm)
    bpy.context.scene.collection.objects.link(ob)
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    for (n, head, tail, parent) in bones:
        eb = arm.edit_bones.new(n)
        eb.head, eb.tail = head, tail
        eb.roll = 0.0
        if parent:
            eb.parent = arm.edit_bones[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    for pb in ob.pose.bones:
        pb.rotation_mode = "QUATERNION"
    return ob


def _seg_dist(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(1e-9, ab.dot(ab))))
    return (p - (a + ab * t)).length


def skin(mesh_ob, arm_ob, allowed, power=4.0, default=None):
    """allowed: {parte: [huesos]}; los vértices sin parte usan 'default' o todos."""
    bones = {b.name: (b.head_local.copy(), b.tail_local.copy()) for b in arm_ob.data.bones}
    parts = mesh_ob.get("vparts", "").split(",") if mesh_ob.get("vparts") else []
    groups = {n: mesh_ob.vertex_groups.new(name=n) for n in bones}
    for v in mesh_ob.data.vertices:
        part = parts[v.index] if v.index < len(parts) else ""
        names = allowed.get(part) or default or list(bones.keys())
        if len(names) == 1:
            groups[names[0]].add([v.index], 1.0, "REPLACE")
            continue
        ds = sorted(((_seg_dist(v.co, *bones[n]), n) for n in names))[:2]
        w0 = 1.0 / max(1e-4, ds[0][0]) ** power
        w1 = 1.0 / max(1e-4, ds[1][0]) ** power
        t = w0 + w1
        groups[ds[0][1]].add([v.index], w0 / t, "REPLACE")
        if w1 / t > 0.02:
            groups[ds[1][1]].add([v.index], w1 / t, "REPLACE")
    mod = mesh_ob.modifiers.new("Armature", "ARMATURE")
    mod.object = arm_ob
    mesh_ob.parent = arm_ob


def leg_ik(dy, dz, l1, l2, bend=1.0):
    """Devuelve (giro_muslo, giro_espinilla) en grados para llevar el tobillo a (dy, dz)
    relativo a la cadera (dz negativo). Giro X positivo = hacia atrás (+Y).
    bend=1 rodilla hacia delante (humano, pata trasera); bend=-1 codo hacia atrás."""
    d = max(0.05, min(l1 + l2 - 0.002, math.hypot(dy, dz)))
    phi = math.acos(max(-1, min(1, (l1 * l1 + l2 * l2 - d * d) / (2 * l1 * l2))))
    alpha = math.atan2(dy, -dz)
    beta = math.acos(max(-1, min(1, (l1 * l1 + d * d - l2 * l2) / (2 * l1 * d))))
    return math.degrees(alpha - bend * beta), math.degrees(bend * (math.pi - phi))


def smooth(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def env(t, a, b, c, d):
    """Envolvente trapezoidal suave: sube en [a,b], se mantiene y baja en [c,d]."""
    if t <= a or t >= d:
        return 0.0
    if t < b:
        return smooth((t - a) / (b - a))
    if t <= c:
        return 1.0
    return 1.0 - smooth((t - c) / (d - c))


class Animator:
    def __init__(self, arm_ob, fps=30):
        self.ob = arm_ob
        self.fps = fps
        self.rest = {pb.name: pb.bone.matrix_local.to_3x3() for pb in arm_ob.pose.bones}
        arm_ob.animation_data_create()
        bpy.context.scene.render.fps = fps
        self.clips = {}

    def _apply(self, pose, frame, last):
        for pb in self.ob.pose.bones:
            R = self.rest[pb.name]
            rot = pose.get(pb.name, (0, 0, 0))
            if isinstance(rot, Quaternion):      # giro ya expresado en ejes del esqueleto
                q = (R.inverted() @ rot.to_matrix() @ R).to_quaternion()
            else:
                q = (R.inverted() @ Euler([math.radians(a) for a in rot], "XYZ").to_matrix() @ R).to_quaternion()
            if pb.name in last and last[pb.name].dot(q) < 0:
                q.negate()
            last[pb.name] = q.copy()
            pb.rotation_quaternion = q
            pb.keyframe_insert("rotation_quaternion", frame=frame)
            sc = pose.get(pb.name + ":scale")
            if sc is not None:
                pb.scale = sc
                pb.keyframe_insert("scale", frame=frame)
            loc = pose.get(pb.name + ":loc")
            if loc is not None or pb.parent is None or pb.name == "hips":
                pb.location = R.inverted() @ Vector(loc or (0, 0, 0))
                pb.keyframe_insert("location", frame=frame)

    def clip(self, name, seconds, fn, loop=True, step=2):
        act = bpy.data.actions.new(name)
        self.ob.animation_data.action = act
        n = max(2, int(round(seconds * self.fps)))
        last = {}
        frames = list(range(0, n, step)) + [n]
        for f in frames:
            t = f / n
            self._apply(fn(0.0 if (loop and f == n) else t), f + 1, last)
        for fc in act.fcurves:
            for kp in fc.keyframe_points:
                kp.interpolation = "LINEAR"
        act.use_fake_user = True
        self.clips[name] = {"length": round(n / self.fps, 4), "loop": loop}
        return act

    def finish(self):
        """Pasa cada acción a una pista NLA para que el exportador glTF las incluya todas."""
        ad = self.ob.animation_data
        ad.action = None
        for name in self.clips:
            act = bpy.data.actions[name]
            tr = ad.nla_tracks.new()
            tr.name = name
            tr.strips.new(name, 1, act)
        for pb in self.ob.pose.bones:
            pb.rotation_quaternion = Quaternion()
            pb.location = (0, 0, 0)
            pb.scale = (1, 1, 1)


def arm_ik(pose, names, rest, target, pole, hand_dir, roll=0.0, twist=0.0):
    """Cadena de dos huesos + mano hacia 'target' (posición de la muñeca).
    names = (brazo, antebrazo, mano); rest = {hueso: (cabeza, cola)} en reposo.
    roll gira el brazo entero sobre su eje y twist el antebrazo (grados): orientan la palma
    sin mover la muñeca."""
    up, fo, ha = names
    S = Vector(rest[up][0])
    l1 = (Vector(rest[up][1]) - S).length
    l2 = (Vector(rest[fo][1]) - Vector(rest[fo][0])).length
    T = Vector(target)
    d = max(0.02, min(l1 + l2 - 0.002, (T - S).length))
    dirn = (T - S).normalized()
    a = (l1 * l1 - l2 * l2 + d * d) / (2 * d)
    h = math.sqrt(max(0.0, l1 * l1 - a * a))
    mid = S + dirn * a
    pv = Vector(pole) - mid
    pv = pv - dirn * pv.dot(dirn)
    pv = pv.normalized() if pv.length > 1e-5 else Vector((0, 0, -1))
    elbow = mid + pv * h
    wrist = S + dirn * d
    r_up = (Vector(rest[up][1]) - Vector(rest[up][0])).normalized()
    r_fo = (Vector(rest[fo][1]) - Vector(rest[fo][0])).normalized()
    r_ha = (Vector(rest[ha][1]) - Vector(rest[ha][0])).normalized()
    q_up = r_up.rotation_difference((elbow - S).normalized())
    if roll:
        q_up = q_up @ Quaternion(r_up, math.radians(roll))
    q_fo = r_fo.rotation_difference(q_up.inverted() @ (wrist - elbow).normalized())
    if twist:
        q_fo = q_fo @ Quaternion(r_fo, math.radians(twist))
    acc = q_up @ q_fo
    q_ha = r_ha.rotation_difference(acc.inverted() @ Vector(hand_dir).normalized())
    pose[up], pose[fo], pose[ha] = q_up, q_fo, q_ha
