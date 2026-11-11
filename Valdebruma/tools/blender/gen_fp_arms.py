"""gen_fp_arms.py — brazos en primera persona con esqueleto y animaciones.

Ejecutar: blender -b --python tools/blender/gen_fp_arms.py
La cámara está en el origen mirando a +Y de Blender (−Z en Godot). Mano derecha en +X.
Clips: fp_idle, fp_walk, fp_sprint, fp_interact, fp_pickup, fp_consume, fp_door, fp_search,
fp_build, fp_cold, fp_tired, fp_hold, fp_wave. El hueso 'item.R' sirve de anclaje del objeto en mano.
"""
import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
import bpy
from mathutils import Vector
import vb, rig
from rig import env, smooth, arm_ik

S2 = 2 * math.pi
REST = {}
for s, sx in (("R", 1), ("L", -1)):
    REST["upper." + s] = ((sx * 0.24, -0.06, -0.24), (sx * 0.27, 0.14, -0.45))
    REST["fore." + s] = ((sx * 0.27, 0.14, -0.45), (sx * 0.2, 0.42, -0.31))
    REST["hand." + s] = ((sx * 0.2, 0.42, -0.31), (sx * 0.185, 0.53, -0.28))
REST["item.R"] = ((0.19, 0.49, -0.26), (0.19, 0.62, -0.26))


def build():
    vb.reset()
    bn = [("root", (0, 0, 0), (0, 0.1, 0), None)]
    for s in ("R", "L"):
        bn += [("upper." + s, *REST["upper." + s], "root"), ("fore." + s, *REST["fore." + s], "upper." + s), ("hand." + s, *REST["hand." + s], "fore." + s)]
    bn.append(("item.R", *REST["item.R"], "hand.R"))
    arm = rig.make_armature("FPArms", bn)
    p = vb.Parts()
    for s, sx in (("R", 1), ("L", -1)):
        u0, u1 = Vector(REST["upper." + s][0]), Vector(REST["upper." + s][1])
        f1 = Vector(REST["fore." + s][1])
        p.cur_part = "arm" + s
        pts = [u0, u0.lerp(u1, 0.5), u1, u1.lerp(f1, 0.33), u1.lerp(f1, 0.66), u1.lerp(f1, 0.93)]
        p.tube(pts, [0.07, 0.064, 0.058, 0.052, 0.047, 0.044], "char_jacket", seg=10, cap=False)
        p.sphere(u1, 0.06, "char_jacket", seg=8, rings=6)
        p.cur_part = "cuff" + s
        p.tube([u1.lerp(f1, 0.88), u1.lerp(f1, 0.99)], [0.047, 0.047], "char_jacket", seg=10, tint=(0.8, 0.8, 0.8, 1))
        p.cur_part = "hand" + s
        h0, h1 = Vector(REST["hand." + s][0]), Vector(REST["hand." + s][1])
        d = (h1 - h0).normalized()
        c = h0 + d * 0.075
        p.push(c, (math.degrees(math.asin(d.z)), 0, -math.degrees(math.atan2(d.x, d.y))))
        p.sphere((0, 0, 0), 1.0, "char_gloves", seg=10, rings=7, scale=(0.042, 0.078, 0.028))
        p.sphere((0, 0.055, -0.012), 1.0, "char_gloves", seg=8, rings=5, scale=(0.038, 0.045, 0.024), rot=(-28, 0, 0))     # dedos recogidos
        p.sphere((-sx * 0.04, 0.005, -0.004), 1.0, "char_gloves", seg=7, rings=5, scale=(0.017, 0.042, 0.017), rot=(0, 0, sx * 32))  # pulgar
        p.pop()
    ob = p.build("fp_arms", ao=True, ao_dist=0.06, ao_strength=0.45, ao_samples=10, smooth=65, ground=None)
    allowed = {}
    for s in ("R", "L"):
        allowed["arm" + s] = ["upper." + s, "fore." + s]; allowed["cuff" + s] = ["fore." + s]; allowed["hand" + s] = ["hand." + s]
    rig.skin(ob, arm, allowed, power=5.0)
    an = rig.Animator(arm)
    RW = Vector((0.2, 0.42, -0.31)); LW = Vector((-0.2, 0.42, -0.31))
    FWD = (0, 1, 0.25)

    def arms(r=None, l=None, rdir=FWD, ldir=FWD, extra=None):
        pose = dict(extra or {})
        arm_ik(pose, ("upper.R", "fore.R", "hand.R"), REST, r if r is not None else RW, (0.5, -0.1, -0.7), (rdir[0] - 0.12, rdir[1], rdir[2]))
        arm_ik(pose, ("upper.L", "fore.L", "hand.L"), REST, l if l is not None else LW, (-0.5, -0.1, -0.7), (ldir[0] + 0.12, ldir[1], ldir[2]))
        return pose

    def idle(t):
        b = math.sin(S2 * t)
        return arms(RW + Vector((0, 0, 0.006 * b)), LW + Vector((0, 0, 0.006 * b)))

    def walk(t):
        b, c = math.sin(2 * S2 * t), math.sin(S2 * t)
        return arms(RW + Vector((0.008 * c, 0.02 * c, 0.016 * b + 0.01)), LW + Vector((0.008 * c, -0.02 * c, 0.016 * b + 0.01)))

    def sprint(t):
        c, s_ = math.cos(S2 * t), math.sin(S2 * t)
        return arms(Vector((0.19, 0.36 + 0.13 * c, -0.2 + 0.07 * abs(s_))), Vector((-0.19, 0.36 - 0.13 * c, -0.2 + 0.07 * abs(s_))), (0, 0.8, 0.7), (0, 0.8, 0.7))

    def interact(t):
        e = env(t, 0.0, 0.4, 0.55, 1.0)
        return arms(RW.lerp(Vector((0.1, 0.62, -0.1)), e))

    def pickup(t):
        down = env(t, 0.0, 0.35, 0.45, 0.8)
        up = smooth((t - 0.45) / 0.3) * (1 - smooth((t - 0.8) / 0.2))
        tgt = RW.lerp(Vector((0.07, 0.58, -0.3)), down).lerp(Vector((0.12, 0.42, -0.16)), up)
        return arms(tgt, None, (0, 1, -0.5 * down + 0.4 * up))

    def consume(t):
        e = env(t, 0.0, 0.22, 0.75, 1.0)
        sip = env(t, 0.28, 0.4, 0.62, 0.74)
        tgt = RW.lerp(Vector((0.06, 0.24, -0.12 + 0.03 * sip)), e)
        return arms(tgt, None, (-0.5 * e, 1 - 1.2 * e, 0.25 + 0.9 * e + 0.5 * sip))

    def door(t):
        e = env(t, 0.0, 0.3, 0.45, 1.0)
        push = env(t, 0.25, 0.5, 0.6, 0.9)
        return arms(None, LW.lerp(Vector((-0.12, 0.56 + 0.12 * push, -0.08)), e), FWD, (0, 1, 0.9 * e))

    def search(t):
        s_ = math.sin(S2 * t)
        return arms(Vector((0.14, 0.54 + 0.07 * s_, -0.2 + 0.02 * s_)), Vector((-0.14, 0.54 - 0.07 * s_, -0.2 - 0.02 * s_)), (0, 1, -0.2), (0, 1, -0.2))

    def build_(t):
        k = (1 - math.cos(S2 * t)) * 0.5
        hit = k ** 3
        return arms(Vector((0.17, 0.46 + 0.08 * hit, 0.0 - 0.22 * hit)), Vector((-0.14, 0.56, -0.2)), (0, 1 - 0.3 * (1 - hit), 0.9 - 1.1 * hit), (0.3, 1, 0.1))

    def cold(t):
        s_ = math.sin(S2 * t * 2)
        sh = 0.004 * math.sin(S2 * t * 11)
        return arms(Vector((0.05 + 0.02 * s_ + sh, 0.42, -0.2)), Vector((-0.05 - 0.02 * s_ + sh, 0.42, -0.21)), (-0.7, 1, 0.5), (0.7, 1, 0.5))

    def tired(t):
        b = math.sin(S2 * t)
        return arms(RW + Vector((0.02, -0.03, -0.03 + 0.022 * b)), LW + Vector((-0.02, -0.03, -0.03 + 0.022 * b)), (0, 1, -0.3), (0, 1, -0.3))

    def hold(t):
        b = math.sin(S2 * t)
        return arms(Vector((0.2, 0.5, -0.2 + 0.006 * b)), None, (0, 1, 0.12))

    def wave(t):
        e = env(t, 0.0, 0.2, 0.8, 1.0)
        w = math.sin(S2 * t * 3)
        return arms(RW.lerp(Vector((0.24 + 0.05 * w, 0.5, 0.02)), e), None, (0.2 * w, 0.3, 1.0))

    an.clip("fp_idle", 3.0, idle); an.clip("fp_walk", 1.0, walk); an.clip("fp_sprint", 0.56, sprint)
    an.clip("fp_interact", 0.6, interact, loop=False, step=1); an.clip("fp_pickup", 0.9, pickup, loop=False, step=1)
    an.clip("fp_consume", 1.6, consume, loop=False); an.clip("fp_door", 0.8, door, loop=False, step=1); an.clip("fp_search", 1.6, search)
    an.clip("fp_build", 0.8, build_, step=1); an.clip("fp_cold", 2.0, cold, step=1); an.clip("fp_tired", 2.4, tired); an.clip("fp_hold", 3.0, hold)
    an.clip("fp_wave", 1.4, wave, loop=False)
    an.finish()
    vb.export([arm, ob], "characters/fp_arms", anim=True)
    vb.write_json("models/fp_arms.json", {"clips": an.clips, "tris": vb.tris(ob)})
    print("FPARMS tris=%d clips=%d" % (vb.tris(ob), len(an.clips)))


if __name__ == "__main__":
    build()
