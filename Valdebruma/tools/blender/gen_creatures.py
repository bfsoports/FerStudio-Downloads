"""gen_creatures.py — criaturas originales de Valdebruma con esqueleto y animaciones.

Ejecutar: blender -b --python tools/blender/gen_creatures.py
  brumal  Acechador del bosque: cuadrúpedo alto con lomo de musgo y liquen luminoso.
  zarzo   Recolector pequeño y asustadizo de lomo espinoso; se hace una bola.
  farol   Flotador del marjal: campana translúcida con zarcillos y núcleo luminoso.
Salidas: assets/models/creatures/<id>.glb y data/models/<id>.json (clips).
Las criaturas miran a −Y en Blender (+Z en Godot). Sin sangre ni daño gráfico.
"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(__file__))
import bpy
from mathutils import Vector
import vb, rig
from rig import leg_ik, smooth, env

S2 = 2 * math.pi


def quad_legs(pose, t, phases, joints, a, lift, dz, stance=0.6):
    """Patas de cuadrúpedo: joints = {pata: (z_cadera, l1, l2, bend, z_tobillo)}."""
    for name, ph in phases.items():
        hz, l1, l2, bend, az = joints[name]
        p_ = (t + ph) % 1.0
        if p_ < stance:
            q = p_ / stance
            y, lf, pitch = -a + 2 * a * q, 0.0, 0.0
        else:
            q = (p_ - stance) / (1 - stance)
            y, lf = a - 2 * a * smooth(q), lift * math.sin(math.pi * q)
            pitch = 25 * math.sin(math.pi * q)
        th, sh = leg_ik(y, (az + lf) - (hz + dz), l1, l2, bend)
        pose[name + "_up"] = (th, 0, 0)
        pose[name + "_lo"] = (sh, 0, 0)
        pose[name + "_ft"] = (-(th + sh) + pitch, 0, 0)


# ======================================= BRUMAL ==============================================
def brumal():
    vb.clear_objects()
    fz, rz_ = 1.12, 1.0                      # altura de hombro y de cadera
    bn = [("root", (0, 0, 0), (0, 0.2, 0), None), ("body", (0, 0.55, 1.05), (0, 0.0, 1.18), "root"), ("chest", (0, 0.0, 1.18), (0, -0.6, 1.22), "body"),
          ("neck", (0, -0.6, 1.22), (0, -1.05, 1.05), "chest"), ("head", (0, -1.05, 1.05), (0, -1.5, 0.92), "neck"),
          ("tail1", (0, 0.6, 1.02), (0, 0.95, 0.9), "body"), ("tail2", (0, 0.95, 0.9), (0, 1.3, 0.7), "tail1")]
    joints = {}
    for s, sx in (("L", 1), ("R", -1)):
        bn += [("f%s_up" % s, (sx * 0.24, -0.5, fz), (sx * 0.24, -0.5, 0.58), "chest"), ("f%s_lo" % s, (sx * 0.24, -0.5, 0.58), (sx * 0.24, -0.5, 0.08), "f%s_up" % s),
               ("f%s_ft" % s, (sx * 0.24, -0.5, 0.08), (sx * 0.24, -0.68, 0.02), "f%s_lo" % s),
               ("r%s_up" % s, (sx * 0.22, 0.5, rz_), (sx * 0.22, 0.5, 0.52), "body"), ("r%s_lo" % s, (sx * 0.22, 0.5, 0.52), (sx * 0.22, 0.5, 0.08), "r%s_up" % s),
               ("r%s_ft" % s, (sx * 0.22, 0.5, 0.08), (sx * 0.22, 0.34, 0.02), "r%s_lo" % s)]
        joints["f" + s] = (fz, 0.54, 0.5, -1.0, 0.08)
        joints["r" + s] = (rz_, 0.48, 0.44, 1.0, 0.08)
    arm = rig.make_armature("Brumal", bn)
    rnd = random.Random(5)
    p = vb.Parts()
    p.cur_part = "trunk"
    p.tube([(0, 0.72, 0.98), (0, 0.5, 1.06), (0, 0.15, 1.14), (0, -0.25, 1.2), (0, -0.55, 1.2), (0, -0.72, 1.16)], [0.12, 0.25, 0.3, 0.33, 0.27, 0.16], "brumal_hide", seg=10, uscale=0.6)
    p.cur_part = "neck"
    p.tube([(0, -0.62, 1.18), (0, -0.85, 1.12), (0, -1.05, 1.05), (0, -1.2, 1.0)], [0.2, 0.15, 0.12, 0.11], "brumal_hide", seg=8, cap=False, uscale=0.6)
    p.cur_part = "head"
    p.sphere((0, -1.3, 0.97), 1.0, "brumal_hide", seg=9, rings=7, scale=(0.105, 0.26, 0.11), rot=(16, 0, 0))
    p.sphere((0, -1.5, 0.9), 1.0, "brumal_hide", seg=7, rings=5, scale=(0.06, 0.09, 0.05), rot=(16, 0, 0))
    for sx in (-1, 1):                                   # manchas de liquen luminoso en lugar de ojos
        for k in range(3):
            p.sphere((sx * (0.085 - k * 0.012), -1.22 - k * 0.09, 1.02 - k * 0.022), 0.02 - k * 0.003, "lichen_glow", seg=6, rings=4)
        p.tube([(sx * 0.07, -1.12, 1.07), (sx * 0.16, -1.02, 1.2), (sx * 0.2, -0.9, 1.34)], [0.03, 0.02, 0.006], "brumal_hide", seg=5, cap=False)   # cuernos-rama
        p.tube([(sx * 0.16, -1.02, 1.2), (sx * 0.24, -1.06, 1.26)], [0.015, 0.004], "brumal_hide", seg=4, cap=False)
    p.cur_part = "tail"
    p.tube([(0, 0.66, 1.0), (0, 0.95, 0.9), (0, 1.15, 0.8), (0, 1.32, 0.68)], [0.1, 0.06, 0.04, 0.012], "brumal_hide", seg=6, cap=False, uscale=0.6)
    p.cur_part = "trunk"
    for k in range(9):                                  # placas de musgo sobre el lomo
        y = 0.55 - k * 0.15
        zz = 1.3 + 0.07 * math.sin(k * 0.5 + 0.4) + (0.06 if 2 < k < 7 else 0)
        s_ = rnd.uniform(0.8, 1.15)
        p.sphere((rnd.uniform(-0.04, 0.04), y, zz), 1.0, "brumal_moss", seg=7, rings=4, scale=(0.24 * s_, 0.14 * s_, 0.07), rot=(rnd.uniform(-12, 4), rnd.uniform(-10, 10), 0))
        if k % 2 == 0:
            for sx in (-1, 1):
                p.sphere((sx * 0.2, y + 0.03, zz - 0.07), 0.022, "lichen_glow", seg=5, rings=4)
    for k in range(5):                                  # helechos/colgajos vegetales
        y = 0.45 - k * 0.22
        for sx in (-1, 1):
            p.quad((sx * 0.24, y - 0.12, 1.22), (sx * 0.24, y + 0.12, 1.22), (sx * 0.4, y + 0.14, 0.86), (sx * 0.4, y - 0.14, 0.86), "leaf_fern", uvs=[(0, 1), (1, 1), (1, 0), (0, 0)], tint=(0.8, 0.85, 0.8, 0.6), smooth=True)
    for s, sx in (("L", 1), ("R", -1)):
        p.cur_part = "f" + s
        p.tube([(sx * 0.24, -0.5, 1.16), (sx * 0.25, -0.5, 0.9), (sx * 0.24, -0.5, 0.58), (sx * 0.24, -0.5, 0.3), (sx * 0.24, -0.5, 0.08)], [0.13, 0.085, 0.07, 0.05, 0.045], "brumal_hide", seg=7, cap=False, uscale=0.6)
        p.sphere((sx * 0.24, -0.5, 0.58), 0.085, "brumal_hide", seg=6, rings=5)
        p.cur_part = "f%sp" % s
        p.sphere((sx * 0.24, -0.56, 0.05), 1.0, "brumal_hide", seg=7, rings=5, scale=(0.075, 0.12, 0.05))
        p.cur_part = "r" + s
        p.tube([(sx * 0.22, 0.5, 1.08), (sx * 0.24, 0.48, 0.8), (sx * 0.22, 0.5, 0.52), (sx * 0.22, 0.5, 0.28), (sx * 0.22, 0.5, 0.08)], [0.15, 0.1, 0.075, 0.05, 0.045], "brumal_hide", seg=7, cap=False, uscale=0.6)
        p.sphere((sx * 0.22, 0.5, 0.52), 0.088, "brumal_hide", seg=6, rings=5)
        p.cur_part = "r%sp" % s
        p.sphere((sx * 0.22, 0.44, 0.05), 1.0, "brumal_hide", seg=7, rings=5, scale=(0.075, 0.12, 0.05))
    ob = p.build("brumal", ao=True, ao_dist=0.25, ao_strength=0.55, ao_samples=10, smooth=65, ground=None)
    allowed = {"trunk": ["body", "chest"], "neck": ["chest", "neck", "head"], "head": ["head"], "tail": ["body", "tail1", "tail2"]}
    for s in ("L", "R"):
        allowed["f" + s] = ["chest", "f%s_up" % s, "f%s_lo" % s]; allowed["f%sp" % s] = ["f%s_ft" % s]
        allowed["r" + s] = ["body", "r%s_up" % s, "r%s_lo" % s]; allowed["r%sp" % s] = ["r%s_ft" % s]
    rig.skin(ob, arm, allowed, power=5.0)
    an = rig.Animator(arm)
    WALK = {"rL": 0.0, "fL": 0.25, "rR": 0.5, "fR": 0.75}
    TROT = {"fL": 0.0, "rR": 0.0, "fR": 0.5, "rL": 0.5}
    RUN = {"fL": 0.0, "fR": 0.12, "rL": 0.5, "rR": 0.62}

    def standing(dz=0.0, y=0.0):
        pose = {"body:loc": (0, 0, dz)}
        quad_legs(pose, 0.0, {k: 0.3 for k in joints}, joints, y, 0.0, dz)
        return pose

    def breathe(pose, t, amp=1.0):
        b = math.sin(S2 * t)
        pose["chest:scale"] = (1 + 0.025 * b * amp, 1, 1 + 0.03 * b * amp)
        pose["tail1"] = (4 * b, 0, 6 * math.sin(S2 * t * 2))
        pose["tail2"] = (6 * b, 0, 10 * math.sin(S2 * t * 2 + 0.6))

    def idle(t):
        pose = standing(-0.03)
        breathe(pose, t)
        pose["neck"] = (4 + 2 * math.sin(S2 * t), 0, 0); pose["head"] = (2, 0, 4 * math.sin(S2 * t * 0.5))
        return pose

    def look(t):
        pose = standing(-0.03)
        breathe(pose, t * 2)
        sw = math.sin(S2 * t)
        pose["neck"] = (-14, 0, 28 * sw); pose["head"] = (-8, 0, 22 * sw)
        return pose

    def move(t, phases, a, lift, dz, bob, neck, stance):
        pose = {}
        b = math.sin(2 * S2 * t)
        pose["body:loc"] = (0, 0, dz + bob * b)
        quad_legs(pose, t, phases, joints, a, lift, dz + bob * b, stance)
        pose["body"] = (2 * b, 0, 3 * math.sin(S2 * t)); pose["chest"] = (-2 * b, 0, -4 * math.sin(S2 * t))
        pose["neck"] = (neck + 3 * b, 0, 0); pose["head"] = (-neck * 0.6, 0, 0)
        pose["tail1"] = (-10, 0, 10 * math.sin(S2 * t)); pose["tail2"] = (-6, 0, 16 * math.sin(S2 * t - 0.7))
        return pose

    def sniff(t):
        pose = standing(-0.1, 0.05)
        sw = math.sin(S2 * t)
        pose["chest"] = (8, 0, 0); pose["neck"] = (34 + 4 * math.sin(S2 * t * 3), 0, 16 * sw); pose["head"] = (16, 0, 14 * sw)
        pose["tail1"] = (-14, 0, 0)
        return pose

    def alert(t):
        k = env(t, 0.0, 0.25, 0.8, 1.0)
        pose = standing(0.04 * k)
        pose["body"] = (-6 * k, 0, 0); pose["chest"] = (-10 * k, 0, 0); pose["neck"] = (-38 * k, 0, 0); pose["head"] = (18 * k, 0, 6 * math.sin(S2 * t * 4) * k)
        pose["tail1"] = (-30 * k, 0, 0); pose["tail2"] = (-20 * k, 0, 0)
        pose["chest:scale"] = (1 + 0.05 * k, 1, 1 + 0.05 * k)
        return pose

    def flinch(t):
        k = env(t, 0.0, 0.15, 0.4, 1.0)
        pose = standing(-0.16 * k, -0.1 * k)
        pose["body:loc"] = (0, 0.22 * k, -0.16 * k)
        pose["neck"] = (-20 * k, 0, 40 * k); pose["head"] = (10 * k, 0, 30 * k); pose["tail1"] = (20 * k, 0, 0)
        return pose

    def stumble(t):
        k = env(t, 0.0, 0.2, 0.5, 1.0)
        sh = math.sin(S2 * t * 5) * k
        pose = standing(-0.06 * k)
        pose["neck"] = (10 * k, 0, 24 * sh); pose["head"] = (6 * k, 14 * sh, 20 * sh); pose["chest"] = (0, 0, 5 * sh)
        return pose

    def rest(t):
        pose = {"body:loc": (0, 0, -0.56)}
        quad_legs(pose, 0.0, {k: 0.3 for k in joints}, joints, -0.22, 0.0, -0.56)
        breathe(pose, t, 1.6)
        pose["neck"] = (30, 0, 12); pose["head"] = (14, 0, 10); pose["tail1"] = (10, 0, 30); pose["tail2"] = (10, 0, 40)
        return pose

    def call(t):
        k = env(t, 0.0, 0.3, 0.75, 1.0)
        pose = standing(-0.02)
        pose["neck"] = (-52 * k, 0, 0); pose["head"] = (-24 * k + 4 * math.sin(S2 * t * 6) * k, 0, 0)
        pose["chest:scale"] = (1 + 0.07 * k, 1, 1 + 0.07 * k)
        return pose

    an.clip("idle", 3.6, idle); an.clip("look", 4.0, look)
    an.clip("walk", 1.3, lambda t: move(t, WALK, 0.3, 0.14, -0.03, 0.012, 6, 0.66))
    an.clip("search", 1.7, lambda t: {**move(t, WALK, 0.22, 0.1, -0.08, 0.008, 22, 0.7), "head": (10, 0, 18 * math.sin(S2 * t))})
    an.clip("run", 0.62, lambda t: move(t, RUN, 0.46, 0.26, -0.08, 0.05, 14, 0.4))
    an.clip("trot", 0.8, lambda t: move(t, TROT, 0.36, 0.2, -0.05, 0.03, 8, 0.5))
    an.clip("sniff", 3.0, sniff); an.clip("alert", 1.6, alert, loop=False); an.clip("flinch", 0.9, flinch, loop=False)
    an.clip("stumble", 1.1, stumble, loop=False); an.clip("rest", 4.0, rest); an.clip("call", 2.2, call, loop=False)
    an.finish()
    vb.export([arm, ob], "creatures/brumal", anim=True)
    vb.write_json("models/brumal.json", {"clips": an.clips, "tris": vb.tris(ob)})
    print("CREATURE brumal tris=%d clips=%d" % (vb.tris(ob), len(an.clips)))


# ======================================= ZARZO ===============================================
def zarzo():
    vb.clear_objects()
    hz = 0.3
    bn = [("root", (0, 0, 0), (0, 0.1, 0), None), ("body", (0, 0.2, 0.3), (0, -0.12, 0.33), "root"), ("head", (0, -0.12, 0.33), (0, -0.4, 0.3), "body"),
          ("tail", (0, 0.24, 0.3), (0, 0.42, 0.34), "body")]
    joints = {}
    for s, sx in (("L", 1), ("R", -1)):
        bn += [("ear" + s, (sx * 0.07, -0.16, 0.42), (sx * 0.12, -0.12, 0.6), "head")]
        for f, y in (("f", -0.1), ("r", 0.16)):
            n = f + s
            bn += [(n + "_up", (sx * 0.1, y, hz), (sx * 0.1, y, 0.16), "body"), (n + "_lo", (sx * 0.1, y, 0.16), (sx * 0.1, y, 0.03), n + "_up"),
                   (n + "_ft", (sx * 0.1, y, 0.03), (sx * 0.1, y - 0.07, 0.01), n + "_lo")]
            joints[n] = (hz, 0.14, 0.13, -1.0 if f == "f" else 1.0, 0.03)
    arm = rig.make_armature("Zarzo", bn)
    rnd = random.Random(9)
    p = vb.Parts()
    p.cur_part = "trunk"
    p.sphere((0, 0.05, 0.33), 1.0, "zarzo_fur", seg=10, rings=7, scale=(0.19, 0.3, 0.2))
    p.sphere((0, 0.04, 0.27), 1.0, "zarzo_belly", seg=8, rings=5, scale=(0.15, 0.24, 0.13))
    for k in range(26):                                 # lomo de zarza: púas blandas y hojitas
        a = rnd.uniform(-1.1, 1.1); y = rnd.uniform(-0.12, 0.3)
        r = 0.185 * math.cos(a * 0.2)
        base = Vector((math.sin(a) * r, y, 0.33 + math.cos(a) * 0.19))
        tip = base + Vector((math.sin(a) * 0.09, 0.07, math.cos(a) * 0.1)) * rnd.uniform(0.7, 1.3)
        p.tube([base, tip], [0.016, 0.002], "brumal_hide", seg=4, cap=False)
    for k in range(7):
        y = -0.08 + k * 0.06
        p.card((rnd.uniform(-0.05, 0.05), y, 0.47), 0.26, 0.2, "leaf_bush_dark", rot=(rnd.uniform(-25, 25), 0, rnd.uniform(0, 180)), tint=(0.9, 0.9, 0.9, 0.3))
    p.cur_part = "head"
    p.sphere((0, -0.24, 0.32), 1.0, "zarzo_fur", seg=9, rings=6, scale=(0.11, 0.14, 0.11))
    p.lathe([(0.06, 0), (0.035, 0.1), (0.018, 0.16), (0.0, 0.17)], "zarzo_belly", seg=8, c=(0, -0.33, 0.3), rot=(100, 0, 0), close=False)
    p.sphere((0, -0.5, 0.275), 0.02, "char_eye", seg=6, rings=4)
    for sx in (-1, 1):
        p.sphere((sx * 0.07, -0.33, 0.36), 0.019, "char_eye", seg=6, rings=4)
        p.cur_part = "ear" + ("L" if sx > 0 else "R")
        p.quad((sx * 0.05, -0.17, 0.4), (sx * 0.1, -0.13, 0.41), (sx * 0.16, -0.1, 0.62), (sx * 0.08, -0.14, 0.58), "zarzo_belly", smooth=True)
        p.quad((sx * 0.1, -0.13, 0.41), (sx * 0.05, -0.17, 0.4), (sx * 0.08, -0.14, 0.58), (sx * 0.16, -0.1, 0.62), "zarzo_fur", smooth=True)
        p.cur_part = "head"
    p.cur_part = "tail"
    p.sphere((0, 0.36, 0.33), 1.0, "zarzo_belly", seg=7, rings=5, scale=(0.05, 0.08, 0.05))
    for n, (hz_, l1, l2, bend, az) in joints.items():
        sx = 1 if n[1] == "L" else -1
        y = -0.1 if n[0] == "f" else 0.16
        p.cur_part = n
        p.tube([(sx * 0.1, y, 0.3), (sx * 0.1, y, 0.16), (sx * 0.1, y, 0.04)], [0.05, 0.034, 0.026], "zarzo_fur", seg=6, cap=False)
        p.cur_part = n + "p"
        p.sphere((sx * 0.1, y - 0.025, 0.022), 1.0, "brumal_hide", seg=6, rings=4, scale=(0.032, 0.05, 0.022))
    ob = p.build("zarzo", ao=True, ao_dist=0.1, ao_strength=0.5, ao_samples=10, smooth=65, ground=None)
    allowed = {"trunk": ["body"], "head": ["head"], "tail": ["tail"], "earL": ["earL"], "earR": ["earR"]}
    for n in joints:
        allowed[n] = ["body", n + "_up", n + "_lo"]; allowed[n + "p"] = [n + "_ft"]
    rig.skin(ob, arm, allowed, power=5.0)
    an = rig.Animator(arm)
    TROT = {"fL": 0.0, "rR": 0.0, "fR": 0.5, "rL": 0.5}
    BOUND = {"fL": 0.0, "fR": 0.06, "rL": 0.5, "rR": 0.56}

    def standing(dz=0.0, y=0.0):
        pose = {"body:loc": (0, 0, dz)}
        quad_legs(pose, 0.0, {k: 0.3 for k in joints}, joints, y, 0.0, dz)
        return pose

    def ears(pose, t, a=1.0):
        pose["earL"] = (0, -8 * a * math.sin(S2 * t * 3), 0); pose["earR"] = (0, 8 * a * math.sin(S2 * t * 3 + 1), 0)

    def idle(t):
        pose = standing(-0.01)
        b = math.sin(S2 * t)
        pose["body:scale"] = (1 + 0.03 * b, 1, 1 + 0.03 * b); pose["head"] = (4 * b, 0, 10 * math.sin(S2 * t * 0.5)); pose["tail"] = (0, 0, 14 * math.sin(S2 * t * 4))
        ears(pose, t)
        return pose

    def forage(t):
        pose = standing(-0.03)
        n = math.sin(S2 * t * 4)
        pose["body"] = (10, 0, 0); pose["head"] = (38 + 6 * n, 0, 10 * math.sin(S2 * t)); pose["tail"] = (-10, 0, 10 * math.sin(S2 * t * 2))
        ears(pose, t, 0.5)
        return pose

    def move(t, phases, a, lift, bob, stance):
        pose = {}
        b = math.sin(2 * S2 * t)
        pose["body:loc"] = (0, 0, -0.02 + bob * b)
        quad_legs(pose, t, phases, joints, a, lift, -0.02 + bob * b, stance)
        pose["body"] = (5 * b, 0, 4 * math.sin(S2 * t)); pose["head"] = (-5 * b, 0, 0); pose["tail"] = (-12 + 10 * b, 0, 0)
        pose["earL"] = (16 * abs(b), 0, 0); pose["earR"] = (16 * abs(b), 0, 0)
        return pose

    def alert(t):
        k = env(t, 0.0, 0.2, 0.85, 1.0)
        pose = {"body:loc": (0, 0.05 * k, 0.07 * k), "body": (-62 * k, 0, 0)}
        for n in joints:
            hz_, l1, l2, bend, az = joints[n]
            if n[0] == "r":
                th, sh = leg_ik(-0.05 * k, az - (hz_ - 0.02 * k), l1, l2, bend)
                pose[n + "_up"] = (th + 62 * k, 0, 0); pose[n + "_lo"] = (sh, 0, 0); pose[n + "_ft"] = (-(th + sh), 0, 0)
            else:
                pose[n + "_up"] = (30 * k, 0, 0); pose[n + "_lo"] = (-70 * k, 0, 0)
        pose["head"] = (58 * k, 0, 18 * math.sin(S2 * t * 2) * k)
        pose["earL"] = (-10 * k, 0, 0); pose["earR"] = (-10 * k, 0, 0)
        return pose

    def curl(t, hold=False):
        k = 1.0 if hold else smooth(t / 0.5)
        b = math.sin(S2 * t) if hold else 0.0
        pose = {"body:loc": (0, 0, -0.1 * k), "body:scale": (1 + 0.06 * k + 0.02 * b, 1 - 0.1 * k, 1 + 0.02 * b), "head": (86 * k, 0, 0), "tail": (-70 * k, 0, 0)}
        for n in joints:
            pose[n + "_up"] = ((-65 if n[0] == "r" else 60) * k, 0, 0); pose[n + "_lo"] = ((110 if n[0] == "r" else -110) * k, 0, 0)
        pose["earL"] = (40 * k, 0, 0); pose["earR"] = (40 * k, 0, 0)
        return pose

    an.clip("idle", 2.6, idle); an.clip("forage", 2.4, forage)
    an.clip("walk", 0.7, lambda t: move(t, TROT, 0.07, 0.04, 0.006, 0.6)); an.clip("run", 0.36, lambda t: move(t, BOUND, 0.11, 0.08, 0.03, 0.4))
    an.clip("alert", 2.4, alert, loop=False); an.clip("curl", 0.6, lambda t: curl(t), loop=False, step=1); an.clip("curled", 3.0, lambda t: curl(t, True))
    an.finish()
    vb.export([arm, ob], "creatures/zarzo", anim=True)
    vb.write_json("models/zarzo.json", {"clips": an.clips, "tris": vb.tris(ob)})
    print("CREATURE zarzo tris=%d clips=%d" % (vb.tris(ob), len(an.clips)))


# ======================================= FAROL ===============================================
def farol():
    vb.clear_objects()
    NT, NS = 6, 3
    bn = [("root", (0, 0, 0), (0, 0.1, 0), None), ("bell", (0, 0, 0.0), (0, 0, 0.5), "root")]
    for i in range(NT):
        a = i * S2 / NT
        x, y = math.cos(a) * 0.26, math.sin(a) * 0.26
        for k in range(NS):
            bn.append(("t%d_%d" % (i, k), (x, y, -0.05 - k * 0.3), (x, y, -0.35 - k * 0.3), "bell" if k == 0 else "t%d_%d" % (i, k - 1)))
    arm = rig.make_armature("Farol", bn)
    p = vb.Parts()
    p.cur_part = "bell"
    prof = [(0.0, 0.52), (0.2, 0.47), (0.36, 0.33), (0.43, 0.14), (0.4, -0.02), (0.44, -0.1)]
    p.lathe(prof, "farol_bell", seg=14, close=False)
    p.lathe([(0.4, -0.1), (0.34, 0.02), (0.3, 0.2), (0.16, 0.36), (0.0, 0.4)], "farol_bell", seg=14, close=False, tint=(0.8, 0.9, 0.9, 1))
    p.sphere((0, 0, 0.2), 1.0, "farol_core", seg=10, rings=7, scale=(0.13, 0.13, 0.16))
    for k in range(5):
        a = k * 1.2566
        p.sphere((math.cos(a) * 0.17, math.sin(a) * 0.17, 0.12), 0.04, "farol_core", seg=6, rings=4)
    for i in range(NT):
        a = i * S2 / NT
        x, y = math.cos(a) * 0.26, math.sin(a) * 0.26
        p.cur_part = "t%d" % i
        pts = [(x, y, -0.02 - j * 0.1) for j in range(10)]
        p.tube(pts, [0.03 * (1 - j / 10) + 0.006 for j in range(10)], "farol_tendril", seg=5, cap=False)
        p.sphere((x, y, -0.93), 0.022, "farol_core", seg=5, rings=4)
    ob = p.build("farol", ao=False, smooth=70, ground=None)
    allowed = {"bell": ["bell"]}
    for i in range(NT):
        allowed["t%d" % i] = ["bell"] + ["t%d_%d" % (i, k) for k in range(NS)]
    rig.skin(ob, arm, allowed, power=4.0)
    an = rig.Animator(arm)

    def tendrils(pose, t, amp, trail=0.0, curl_=0.0, speed=1.0):
        for i in range(NT):
            a = i * S2 / NT
            for k in range(NS):
                w = amp * (k + 1) * math.sin(S2 * (t * speed - k * 0.18) + i * 1.3)
                out = curl_ * (k + 1)
                # balanceo radial (hacia fuera/dentro) + arrastre hacia atrás al desplazarse
                pose["t%d_%d" % (i, k)] = (-math.sin(a) * (w + out) + trail * (k + 1), math.cos(a) * (w + out), 0)

    def floaty(t, bob=0.06, amp=6.0, pulse=0.05, speed=1.0, trail=0.0, curl_=0.0, tilt=0.0):
        pose = {}
        b = math.sin(S2 * t)
        c = math.sin(S2 * t * 2 * speed)
        pose["bell:loc"] = (0, 0, bob * b)
        pose["bell"] = (tilt + 3 * math.sin(S2 * t + 1), 3 * math.cos(S2 * t), 0)
        pose["bell:scale"] = (1 + pulse * c, 1 + pulse * c, 1 - pulse * 1.4 * c)
        tendrils(pose, t, amp, trail, curl_, speed)
        return pose

    def puff(t):
        k = env(t, 0.0, 0.25, 0.4, 1.0)
        pose = floaty(t, 0.02, 4.0, 0.02)
        pose["bell:scale"] = (1 - 0.28 * k + 0.2 * env(t, 0.35, 0.5, 0.6, 1.0), 1 - 0.28 * k + 0.2 * env(t, 0.35, 0.5, 0.6, 1.0), 1 + 0.3 * k)
        tendrils(pose, t, 3.0, 0.0, -9 * k)
        return pose

    an.clip("float", 4.0, lambda t: floaty(t))
    an.clip("drift", 2.4, lambda t: floaty(t, 0.04, 5.0, 0.07, 1.0, 13.0, 0.0, -14))
    an.clip("pulse", 1.2, lambda t: floaty(t, 0.03, 9.0, 0.14, 2.0, 0.0, 6.0))
    an.clip("puff", 1.4, puff, loop=False, step=1)
    an.clip("retreat", 1.6, lambda t: floaty(t, 0.03, 4.0, 0.1, 2.0, 18.0, -8.0, -22))
    an.clip("recover", 5.0, lambda t: floaty(t, 0.03, 3.0, 0.025, 0.5, 0.0, 4.0))
    an.finish()
    vb.export([arm, ob], "creatures/farol", anim=True)
    vb.write_json("models/farol.json", {"clips": an.clips, "tris": vb.tris(ob)})
    print("CREATURE farol tris=%d clips=%d" % (vb.tris(ob), len(an.clips)))


if __name__ == "__main__":
    vb.reset()
    brumal(); zarzo(); farol()
