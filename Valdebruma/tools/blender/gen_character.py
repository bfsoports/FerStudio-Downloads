"""gen_character.py — superviviente (cuerpo completo) con esqueleto y animaciones.

Ejecutar: blender -b --python tools/blender/gen_character.py
Salida: assets/models/characters/survivor.glb con los objetos de malla:
  body (siempre visible), hat, pack_small, pack_large, mask (se muestran según el equipo)
y los clips: idle, walk, jog, sprint, crouch_idle, crouch_walk, turn, jump, fall, land,
interact, pickup, consume, open_door, search, build, cold, tired, wave, point, sit, faint.
data/models/survivor.json guarda duración y bucle de cada clip.
El personaje mira a −Y en Blender (queda mirando a +Z en Godot).
"""
import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
import bpy
from mathutils import Vector
import vb, rig
from rig import leg_ik, smooth, env

L1, L2 = 0.43, 0.40
HIP_Z, ANKLE_Z = 0.93, 0.10
S2 = 2 * math.pi


def bones():
    b = [("root", (0, 0, 0), (0, 0.15, 0), None), ("hips", (0, 0, 0.95), (0, 0, 1.07), "root"), ("spine", (0, 0, 1.07), (0, 0, 1.25), "hips"),
         ("chest", (0, 0, 1.25), (0, 0, 1.47), "spine"), ("neck", (0, 0, 1.47), (0, 0, 1.56), "chest"), ("head", (0, 0, 1.56), (0, 0, 1.78), "neck")]
    for s, sx in (("L", 1), ("R", -1)):
        b += [("shoulder." + s, (sx * 0.03, 0, 1.43), (sx * 0.185, 0, 1.44), "chest"),
              ("upper_arm." + s, (sx * 0.185, 0, 1.44), (sx * 0.235, 0, 1.16), "shoulder." + s),
              ("forearm." + s, (sx * 0.235, 0, 1.16), (sx * 0.265, -0.01, 0.90), "upper_arm." + s),
              ("hand." + s, (sx * 0.265, -0.01, 0.90), (sx * 0.275, -0.015, 0.78), "forearm." + s),
              ("thigh." + s, (sx * 0.095, 0, HIP_Z), (sx * 0.095, 0, 0.5), "hips"),
              ("shin." + s, (sx * 0.095, 0, 0.5), (sx * 0.095, 0, ANKLE_Z), "thigh." + s),
              ("foot." + s, (sx * 0.095, 0, ANKLE_Z), (sx * 0.095, -0.19, 0.02), "shin." + s)]
    return b


ALLOWED = {"torso": ["hips", "spine", "chest"], "neck": ["chest", "neck", "head"], "head": ["head"], "pelvis": ["hips", "thigh.L", "thigh.R"],
           "pack": ["chest", "spine"], "belt": ["hips", "spine"]}
for s in ("L", "R"):
    ALLOWED["arm" + s] = ["shoulder." + s, "upper_arm." + s, "forearm." + s]
    ALLOWED["cuff" + s] = ["forearm." + s]
    ALLOWED["hand" + s] = ["hand." + s]
    ALLOWED["leg" + s] = ["hips", "thigh." + s, "shin." + s]
    ALLOWED["boot" + s] = ["shin." + s, "foot." + s]
    ALLOWED["foot" + s] = ["foot." + s]


def body_mesh():
    p = vb.Parts()
    dark = (0.82, 0.82, 0.82, 1)
    p.cur_part = "pelvis"
    p.loft([(0, 0, 0.84, 0.15, 0.11), (0, 0, 0.9, 0.178, 0.125), (0, 0, 0.98, 0.18, 0.125), (0, 0, 1.02, 0.175, 0.12)], "char_trousers", seg=12, cap_bottom=True)
    for s, sx in (("L", 1), ("R", -1)):
        p.cur_part = "leg" + s
        p.tube([(sx * 0.095, 0, 0.96), (sx * 0.095, 0, 0.8), (sx * 0.095, 0, 0.62), (sx * 0.095, -0.004, 0.5), (sx * 0.095, 0, 0.4), (sx * 0.095, 0, 0.3)],
               [0.088, 0.086, 0.072, 0.064, 0.058, 0.056], "char_trousers", seg=8, cap=False)
        p.box((sx * 0.14, -0.02, 0.68), (0.03, 0.1, 0.12), "char_trousers", tint=dark)          # bolsillo de pernera
        p.cur_part = "boot" + s
        p.tube([(sx * 0.095, 0, 0.36), (sx * 0.095, 0, 0.33), (sx * 0.095, 0, 0.2), (sx * 0.095, -0.005, 0.1), (sx * 0.095, -0.02, 0.04)],
               [0.062, 0.066, 0.06, 0.058, 0.056], "char_boots", seg=8, cap=False)
        p.cur_part = "foot" + s
        p.sphere((sx * 0.095, -0.075, 0.058), 1.0, "char_boots", seg=8, rings=6, scale=(0.054, 0.14, 0.056))
        p.box((sx * 0.095, -0.07, 0.012), (0.108, 0.3, 0.024), "item_dark")
    p.cur_part = "torso"
    p.loft([(0, 0, 0.9, 0.2, 0.142), (0, 0, 1.0, 0.186, 0.13), (0, 0, 1.1, 0.176, 0.12), (0, -0.005, 1.25, 0.19, 0.128), (0, -0.005, 1.36, 0.2, 0.13),
            (0, 0, 1.44, 0.19, 0.108), (0, 0, 1.49, 0.1, 0.085), (0, 0, 1.52, 0.066, 0.066)], "char_jacket", seg=14)
    p.box((0, -0.127, 1.2), (0.014, 0.012, 0.56), "item_dark")
    for sx in (-1, 1):
        p.box((sx * 0.105, -0.128, 1.0), (0.095, 0.02, 0.085), "char_jacket", tint=dark)
        p.box((sx * 0.105, -0.14, 1.045), (0.1, 0.012, 0.022), "char_jacket", tint=(0.7, 0.7, 0.7, 1))
    p.box((0.1, -0.133, 1.33), (0.075, 0.014, 0.07), "char_jacket", tint=dark)
    p.cur_part = "belt"
    p.loft([(0, 0, 0.985, 0.19, 0.134), (0, 0, 1.02, 0.188, 0.132)], "item_dark", seg=14)
    p.box((0, -0.136, 1.0), (0.04, 0.012, 0.04), "item_metal")
    p.box((0.17, 0.02, 0.96), (0.05, 0.1, 0.1), "char_pack")
    for s, sx in (("L", 1), ("R", -1)):
        p.cur_part = "arm" + s
        p.tube([(sx * 0.185, 0, 1.445), (sx * 0.2, 0, 1.36), (sx * 0.235, 0, 1.16), (sx * 0.25, -0.005, 1.02), (sx * 0.264, -0.01, 0.915)],
               [0.066, 0.06, 0.052, 0.047, 0.044], "char_jacket", seg=8, cap=False)
        p.sphere((sx * 0.185, 0, 1.445), 0.068, "char_jacket", seg=8, rings=6)
        p.cur_part = "cuff" + s
        p.tube([(sx * 0.262, -0.01, 0.93), (sx * 0.266, -0.011, 0.895)], [0.047, 0.047], "char_jacket", seg=8, tint=dark)
        p.cur_part = "hand" + s
        p.sphere((sx * 0.271, -0.013, 0.835), 1.0, "char_gloves", seg=8, rings=6, scale=(0.034, 0.03, 0.068))
        p.sphere((sx * 0.262, -0.045, 0.855), 1.0, "char_gloves", seg=6, rings=4, scale=(0.016, 0.02, 0.036), rot=(-25, 0, 0))
    p.cur_part = "neck"
    p.tube([(0, 0, 1.48), (0, 0, 1.6)], 0.052, "char_skin", seg=8, cap=False)
    p.lathe([(0.066, 1.475), (0.1, 1.49), (0.108, 1.53), (0.092, 1.566), (0.06, 1.57)], "char_scarf", seg=12, close=False)
    p.box((0.045, -0.118, 1.41), (0.07, 0.02, 0.18), "char_scarf", rot=(-6, 0, 6))
    p.cur_part = "head"
    p.sphere((0, -0.005, 1.665), 1.0, "char_skin", seg=12, rings=9, scale=(0.091, 0.104, 0.118))
    p.tri((0, -0.125, 1.652), (-0.014, -0.103, 1.64), (0.014, -0.103, 1.64), "char_skin")
    p.tri((0, -0.125, 1.652), (0.014, -0.103, 1.64), (0, -0.103, 1.69), "char_skin")
    p.tri((0, -0.125, 1.652), (0, -0.103, 1.69), (-0.014, -0.103, 1.64), "char_skin")
    for sx in (-1, 1):
        p.sphere((sx * 0.034, -0.094, 1.682), 0.011, "char_eye", seg=6, rings=4)
        p.box((sx * 0.035, -0.099, 1.702), (0.036, 0.01, 0.008), "char_hair", rot=(0, sx * -6, 0))
        p.sphere((sx * 0.091, 0.0, 1.665), 1.0, "char_skin", seg=5, rings=4, scale=(0.012, 0.02, 0.028))
    p.box((0, -0.101, 1.612), (0.036, 0.006, 0.006), "char_hair")
    p.lathe([(0.094, 1.676), (0.099, 1.71), (0.092, 1.75), (0.062, 1.782), (0.0, 1.792)], "char_hair", seg=12, c=(0, 0.0, 0), close=False)   # pelo corto
    p.sphere((0, 0.05, 1.655), 1.0, "char_hair", seg=8, rings=6, scale=(0.088, 0.066, 0.08))
    return p.build("body", ao=True, ao_dist=0.12, ao_strength=0.5, ao_samples=10, smooth=62, ground=None)


def extras():
    obs = []
    p = vb.Parts(); p.cur_part = "head"
    p.lathe([(0.1, 1.685), (0.107, 1.7), (0.107, 1.735), (0.1, 1.742), (0.1, 1.765), (0.082, 1.805), (0.045, 1.83), (0.0, 1.838)], "char_hat", seg=12, close=False)
    p.sphere((0, 0.045, 1.69), 1.0, "char_hat", seg=8, rings=6, scale=(0.098, 0.075, 0.07))
    obs.append(p.build("hat", ao=True, ao_dist=0.08, ao_strength=0.4, smooth=62, ground=None))
    for nm, (w, d, h, zc) in (("pack_small", (0.3, 0.15, 0.38, 1.26)), ("pack_large", (0.36, 0.21, 0.56, 1.24))):
        p = vb.Parts(); p.cur_part = "pack"
        p.box((0, 0.13 + d / 2, zc), (w, d, h), "char_pack")
        p.box((0, 0.13 + d + 0.025, zc - h * 0.18), (w * 0.7, 0.05, h * 0.4), "char_pack", tint=(0.84, 0.84, 0.84, 1))
        p.box((0, 0.13 + d / 2, zc + h / 2 + 0.012), (w * 1.03, d * 1.06, 0.03), "char_pack", tint=(0.78, 0.78, 0.78, 1))
        for sx in (-1, 1):
            p.box((sx * 0.115, -0.115, 1.31), (0.045, 0.02, 0.3), "item_dark", rot=(4, 0, 0))
            p.box((sx * 0.115, 0.0, 1.47), (0.045, 0.24, 0.02), "item_dark")
            p.box((sx * 0.14, 0.06, 1.12), (0.03, 0.18, 0.02), "item_dark", rot=(0, 0, sx * 20))
        if nm == "pack_large":
            p.cyl((0, 0.13 + d / 2, zc + h / 2 + 0.085), 0.07, 0.4, "char_scarf", seg=9, rot=(0, 90, 0))
            for sx in (-1, 1):
                p.box((sx * (w / 2 + 0.03), 0.13 + d / 2, zc - 0.12), (0.06, d * 0.7, 0.2), "char_pack", tint=(0.84, 0.84, 0.84, 1))
        obs.append(p.build(nm, ao=True, ao_dist=0.1, ao_strength=0.5, smooth=50, ground=None))
    p = vb.Parts(); p.cur_part = "head"
    p.sphere((0, -0.085, 1.622), 1.0, "item_dark", seg=9, rings=6, scale=(0.062, 0.05, 0.052))
    for sx in (-1, 1):
        p.lathe([(0.018, 0), (0.036, 0.004), (0.036, 0.028), (0.026, 0.032)], "item_paint", seg=9, c=(sx * 0.058, -0.105, 1.612), rot=(90, 0, sx * 38), tint=(0.75, 0.6, 0.2, 1))
    p.loft([(0, -0.005, 1.63, 0.094, 0.107), (0, -0.005, 1.645, 0.094, 0.107)], "item_dark", seg=12)
    obs.append(p.build("mask", ao=True, ao_dist=0.06, ao_strength=0.4, smooth=62, ground=None))
    return obs


# ------------------------------- animación ---------------------------------------------------
def legs(pose, side, ank_y, lift, hips_dz, pitch=0.0):
    th, sh = leg_ik(ank_y, (ANKLE_Z + lift) - (HIP_Z + hips_dz), L1, L2)
    pose["thigh." + side] = (th, 0, 0)
    pose["shin." + side] = (sh, 0, 0)
    pose["foot." + side] = (-(th + sh) + pitch, 0, 0)


def stand(pose, hips_dz=0.0, spread=0.0):
    for s, sg in (("L", 1), ("R", -1)):
        legs(pose, s, spread * sg, 0.0, hips_dz)
    pose["hips:loc"] = (0, 0, hips_dz)


def gait(t, dist, sf, lift, base, bob, lean, arm, elbow, twist, run=False):
    """Ciclo de marcha: dist = metros por ciclo, sf = fracción de apoyo."""
    pose = {}
    a = dist * sf / 2
    if run:
        dz = base + bob * (0.5 - 0.5 * math.cos(2 * S2 * (t - sf / 2)))
    else:
        dz = base + bob * (0.5 + 0.5 * math.cos(2 * S2 * (t - sf / 2)))
    for s, ph in (("L", 0.0), ("R", 0.5)):
        p_ = (t + ph) % 1.0
        if p_ < sf:
            q = p_ / sf
            y, lf = -a + 2 * a * q, 0.0
            pitch = -10 * max(0.0, 1 - q * 5) + 18 * max(0.0, (q - 0.75) * 4)
        else:
            q = (p_ - sf) / (1 - sf)
            y = a - 2 * a * smooth(q)
            lf = lift * math.sin(math.pi * q) ** 0.85
            pitch = 22 * (1 - q) ** 2 - 10 * q ** 3
        legs(pose, s, y, lf, dz, pitch)
    c = math.cos(S2 * t)
    pose["hips:loc"] = (0.012 * math.sin(S2 * t) * (0 if run else 1), 0, dz)
    pose["hips"] = (0, 0, -twist * 0.6 * c)
    pose["spine"] = (lean, 0, twist * 1.1 * c)
    pose["chest"] = (lean * 0.4, 0, twist * 0.7 * c)
    pose["head"] = (-lean * 0.9, 0, -twist * 1.0 * c)
    pose["upper_arm.L"] = (arm * c - 4, -3, 0)
    pose["upper_arm.R"] = (-arm * c - 4, 3, 0)
    pose["forearm.L"] = (-(elbow + arm * 0.35 * (1 - c)), 0, 0)
    pose["forearm.R"] = (-(elbow + arm * 0.35 * (1 + c)), 0, 0)
    return pose


def idle(t):
    pose = {}
    b = math.sin(S2 * t)
    stand(pose, -0.012 + 0.003 * b)
    pose["hips:loc"] = (0.008 * math.sin(S2 * t * 0.5), 0, -0.012 + 0.003 * b)
    pose["spine"] = (2 + 0.8 * b, 0, 0)
    pose["chest"] = (1.5 * b, 0, 0)
    pose["head"] = (-2 - 1.0 * b, 0, 3 * math.sin(S2 * t * 0.5))
    for s, sg in (("L", 1), ("R", -1)):
        pose["shoulder." + s] = (0, -sg * 1.5 * b, 0)
        pose["upper_arm." + s] = (2, -sg * (2 + b), 0)
        pose["forearm." + s] = (-12 - 2 * b, 0, 0)
    return pose


def crouch(t, moving):
    if moving:
        pose = gait(t, 1.2, 0.62, 0.07, -0.3, 0.015, 26, 12, 55, 5)
    else:
        pose = {}
        b = math.sin(S2 * t)
        pose["hips:loc"] = (0, 0, -0.32 + 0.004 * b)
        legs(pose, "L", -0.12, 0.0, -0.32 + 0.004 * b)
        legs(pose, "R", 0.12, 0.0, -0.32 + 0.004 * b, 18)
        pose["spine"] = (26 + b, 0, 0)
        pose["chest"] = (8, 0, 0)
        for s in ("L", "R"):
            pose["upper_arm." + s] = (-22, 0, 0)
            pose["forearm." + s] = (-70, 0, 0)
    pose["head"] = (-24, 0, pose.get("head", (0, 0, 0))[2])
    return pose


def jump(t):
    pose = {}
    k = env(t, 0.0, 0.45, 0.5, 0.75)
    up = smooth((t - 0.5) / 0.5)
    dz = -0.24 * k + 0.02 * up
    stand(pose, dz)
    for s in ("L", "R"):
        legs(pose, s, 0.0, 0.1 * up, dz, 30 * up)
        pose["upper_arm." + s] = (30 * k - 70 * up, 0, 0)
        pose["forearm." + s] = (-30 - 30 * up, 0, 0)
    pose["spine"] = (30 * k - 4 * up, 0, 0)
    pose["head"] = (-20 * k, 0, 0)
    return pose


def fall(t):
    pose = {}
    b = math.sin(S2 * t)
    pose["hips:loc"] = (0, 0, 0.02)
    legs(pose, "L", -0.1, 0.16 + 0.02 * b, 0.02, 25)
    legs(pose, "R", 0.08, 0.1 - 0.02 * b, 0.02, 30)
    pose["spine"] = (6, 0, 0)
    pose["upper_arm.L"] = (-20, -55 - 6 * b, 0)
    pose["upper_arm.R"] = (-20, 55 + 6 * b, 0)
    pose["forearm.L"] = (-35, 0, 0)
    pose["forearm.R"] = (-35, 0, 0)
    return pose


def land(t):
    pose = {}
    k = env(t, 0.0, 0.25, 0.3, 1.0)
    stand(pose, -0.26 * k)
    pose["spine"] = (28 * k, 0, 0)
    pose["head"] = (-16 * k, 0, 0)
    for s in ("L", "R"):
        pose["upper_arm." + s] = (-30 * k, 0, 0)
        pose["forearm." + s] = (-12 - 40 * k, 0, 0)
    return pose


def base_stand():
    pose = {}
    stand(pose, -0.012)
    pose["spine"] = (2, 0, 0)
    for s, sg in (("L", 1), ("R", -1)):
        pose["upper_arm." + s] = (2, -sg * 2, 0)
        pose["forearm." + s] = (-12, 0, 0)
    return pose


def interact(t):
    pose = base_stand()
    e = env(t, 0.0, 0.35, 0.55, 1.0)
    pose["spine"] = (2 + 7 * e, 0, -6 * e)
    pose["upper_arm.R"] = (2 - 72 * e, 2 + 4 * e, 0)
    pose["forearm.R"] = (-12 - 22 * e, 0, 0)
    pose["hand.R"] = (-10 * e, 0, 0)
    return pose


def pickup(t):
    pose = {}
    e = env(t, 0.0, 0.4, 0.55, 1.0)
    dz = -0.012 - 0.34 * e
    pose["hips:loc"] = (0, 0, dz)
    legs(pose, "L", -0.1 * e, 0.0, dz)
    legs(pose, "R", 0.14 * e, 0.0, dz, 20 * e)
    pose["spine"] = (2 + 42 * e, 0, -8 * e)
    pose["chest"] = (10 * e, 0, 0)
    pose["head"] = (-10 * e, 0, 0)
    pose["upper_arm.R"] = (2 - 50 * e, 2, 0)
    pose["forearm.R"] = (-12 - 18 * e, 0, 0)
    pose["upper_arm.L"] = (2 + 10 * e, -2 - 10 * e, 0)
    pose["forearm.L"] = (-12 - 30 * e, 0, 0)
    return pose


def consume(t):
    pose = base_stand()
    e = env(t, 0.0, 0.25, 0.7, 1.0)
    sip = env(t, 0.3, 0.45, 0.6, 0.72)
    pose["upper_arm.R"] = (2 - 52 * e, 2 + 10 * e, 0)
    pose["forearm.R"] = (-12 - 112 * e, 0, 0)
    pose["hand.R"] = (-20 * sip, 0, 0)
    pose["head"] = (-14 * sip, 0, 0)
    pose["spine"] = (2 - 3 * sip, 0, 0)
    return pose


def open_door(t):
    pose = base_stand()
    e = env(t, 0.0, 0.3, 0.5, 1.0)
    push = env(t, 0.25, 0.5, 0.6, 0.9)
    pose["spine"] = (2 + 5 * e, 0, 8 * e)
    pose["upper_arm.L"] = (2 - 64 * e - 14 * push, -2 - 6 * e, 0)
    pose["forearm.L"] = (-12 - 40 * e + 34 * push, 0, 0)
    return pose


def search(t):
    pose = {}
    s = math.sin(S2 * t)
    stand(pose, -0.08)
    pose["spine"] = (24 + 2 * s, 0, 4 * s)
    pose["head"] = (4, 0, -4 * s)
    pose["upper_arm.L"] = (-48 + 12 * s, -4, 0)
    pose["forearm.L"] = (-46 - 16 * s, 0, 0)
    pose["upper_arm.R"] = (-48 - 12 * s, 4, 0)
    pose["forearm.R"] = (-46 + 16 * s, 0, 0)
    return pose


def build(t):
    pose = {}
    k = (1 - math.cos(S2 * t)) * 0.5
    hit = k ** 3
    stand(pose, -0.1)
    pose["spine"] = (18 + 5 * hit, 0, -6)
    pose["upper_arm.R"] = (-78 + 30 * hit, 6, 0)
    pose["forearm.R"] = (-96 + 62 * hit, 0, 0)
    pose["upper_arm.L"] = (-52, -4, 0)
    pose["forearm.L"] = (-38, 0, 0)
    pose["head"] = (6, 0, 0)
    return pose


def cold(t):
    pose = {}
    sh = math.sin(S2 * t * 9) * 1.2
    b = math.sin(S2 * t)
    stand(pose, -0.04)
    pose["spine"] = (12 + b, 0, sh)
    pose["chest"] = (6, 0, 0)
    pose["head"] = (10, 0, -sh)
    pose["shoulder.L"] = (0, 6 + sh * 0.5, 0)
    pose["shoulder.R"] = (0, -6 - sh * 0.5, 0)
    pose["upper_arm.L"] = (-30, 10, -52)
    pose["upper_arm.R"] = (-30, -10, 52)
    pose["forearm.L"] = (-104 + sh, 0, 0)
    pose["forearm.R"] = (-98 - sh, 0, 0)
    return pose


def tired(t):
    pose = {}
    b = math.sin(S2 * t)
    dz = -0.14 + 0.01 * b
    pose["hips:loc"] = (0, 0.06, dz)
    for s, sg in (("L", 1), ("R", -1)):
        legs(pose, s, -0.05, 0.0, dz)
        pose["upper_arm." + s] = (-42 - 2 * b, -sg * 4, 0)
        pose["forearm." + s] = (-6, 0, 0)
    pose["spine"] = (44 + 4 * b, 0, 0)
    pose["chest"] = (10 + 3 * b, 0, 0)
    pose["head"] = (14, 0, 0)
    return pose


def wave(t):
    pose = base_stand()
    e = env(t, 0.0, 0.2, 0.8, 1.0)
    w = math.sin(S2 * t * 3)
    pose["upper_arm.R"] = (2, 2 + 138 * e, 0)
    pose["forearm.R"] = (-12 - 14 * e, 26 * w * e, 0)
    pose["head"] = (-3 * e, 0, -6 * e)
    return pose


def point(t):
    pose = base_stand()
    e = env(t, 0.0, 0.25, 0.75, 1.0)
    pose["upper_arm.R"] = (2 - 86 * e, 2, 0)
    pose["forearm.R"] = (-12 + 8 * e, 0, 0)
    pose["spine"] = (2 + 3 * e, 0, -5 * e)
    return pose


def sit(t):
    pose = {}
    b = math.sin(S2 * t)
    dz = -0.66
    pose["hips:loc"] = (0, 0.1, dz)
    for s, sg in (("L", 1), ("R", -1)):
        legs(pose, s, -0.42, 0.0, dz, 10)
        pose["upper_arm." + s] = (-46, -sg * 6, 0)
        pose["forearm." + s] = (-34, 0, 0)
    pose["spine"] = (10 + b, 0, 0)
    pose["head"] = (2 - b, 0, 0)
    return pose


def faint(t):
    pose = {}
    k = smooth(t / 0.45)
    f = smooth((t - 0.4) / 0.6)
    dz = -0.5 * k - 0.24 * f
    pose["hips:loc"] = (0.25 * f, 0, dz)
    pose["hips"] = (0, -78 * f, 0)
    for s, sg in (("L", 1), ("R", -1)):
        pose["thigh." + s] = (-70 * k + 30 * f, 0, 0)
        pose["shin." + s] = (120 * k - 50 * f, 0, 0)
        pose["foot." + s] = (-30 * k, 0, 0)
        pose["upper_arm." + s] = (-20 * k, -sg * 10 * k, 0)
        pose["forearm." + s] = (-30 * k, 0, 0)
    pose["spine"] = (30 * k - 10 * f, 0, 0)
    pose["head"] = (20 * k, 0, 10 * f)
    return pose


def run():
    vb.reset()
    arm = rig.make_armature("Survivor", bones())
    body = body_mesh()
    parts = [body] + extras()
    for ob in parts:
        rig.skin(ob, arm, ALLOWED, power=5.0)
    an = rig.Animator(arm)
    an.clip("idle", 4.0, idle)
    an.clip("walk", 1.0, lambda t: gait(t, 1.6, 0.6, 0.08, -0.03, 0.022, 4, 22, 14, 6))
    an.clip("jog", 0.7, lambda t: gait(t, 2.25, 0.42, 0.16, -0.06, 0.05, 9, 32, 70, 9, run=True))
    an.clip("sprint", 0.56, lambda t: gait(t, 3.1, 0.34, 0.24, -0.07, 0.07, 16, 46, 84, 12, run=True))
    an.clip("crouch_idle", 3.0, lambda t: crouch(t, False))
    an.clip("crouch_walk", 1.1, lambda t: crouch(t, True))
    an.clip("turn", 0.7, lambda t: gait(t, 0.16, 0.6, 0.05, -0.02, 0.008, 2, 4, 14, 2))
    an.clip("jump", 0.45, jump, loop=False, step=1)
    an.clip("fall", 0.9, fall)
    an.clip("land", 0.4, land, loop=False, step=1)
    an.clip("interact", 0.8, interact, loop=False)
    an.clip("pickup", 1.0, pickup, loop=False)
    an.clip("consume", 1.7, consume, loop=False)
    an.clip("open_door", 0.9, open_door, loop=False)
    an.clip("search", 1.8, search)
    an.clip("build", 0.8, build)
    an.clip("cold", 2.0, cold, step=1)
    an.clip("tired", 2.4, tired)
    an.clip("wave", 1.6, wave, loop=False)
    an.clip("point", 1.4, point, loop=False)
    an.clip("sit", 3.2, sit)
    an.clip("faint", 1.8, faint, loop=False)
    an.finish()
    vb.export([arm] + parts, "characters/survivor", anim=True)
    vb.write_json("models/survivor.json", {"clips": an.clips, "tris": sum(vb.tris(o) for o in parts)})
    print("CHARACTER tris=%d clips=%d" % (sum(vb.tris(o) for o in parts), len(an.clips)))


if __name__ == "__main__":
    run()
