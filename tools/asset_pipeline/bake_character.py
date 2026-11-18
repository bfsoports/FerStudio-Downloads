#!/usr/bin/env python3
"""
SECTOR ABANDONADO - character bake pipeline.

Takes a rigged humanoid GLB (Mixamo-style bone names, identity rest rotations,
as produced by the auto-rigger used on the Hyper3D Rodin meshes) plus a list of
CC0 animation clips in three.js AnimationClip JSON format, and writes a
mobile-ready GLB with:
  * the original skinned mesh,
  * textures downscaled for Android (base colour / normal / metal-rough),
  * every clip retargeted onto the character's own skeleton and embedded as a
    glTF animation (Godot imports them into an AnimationPlayer),
  * feet placed on Y=0.

Retargeting is direction based: for every bone we build an orthonormal frame
from joint *positions* (bone direction + an anatomical secondary axis such as
the elbow / knee bend plane or the pelvis / chest lateral axis) both on the
animated source skeleton and on the target rest pose, and solve the target
world rotation that maps one onto the other.  This is independent of the bone
roll conventions of either skeleton, which differ between the clip library
and the auto-rigged characters.

Usage: bake_character.py <rigged.glb> <clips_dir> <out.glb> <clipset.json>
"""
import json
import struct
import sys
import io
import math

import numpy as np
from PIL import Image
from pygltflib import GLTF2, Animation, AnimationChannel, AnimationChannelTarget, AnimationSampler, Accessor, BufferView, Node

FPS = 30.0

# ----------------------------------------------------------------------------
# quaternion / matrix helpers (x, y, z, w)
# ----------------------------------------------------------------------------

def q_mul(a, b):
    ax, ay, az, aw = a
    bx, by, bz, bw = b
    return np.array([
        aw * bx + ax * bw + ay * bz - az * by,
        aw * by - ax * bz + ay * bw + az * bx,
        aw * bz + ax * by - ay * bx + az * bw,
        aw * bw - ax * bx - ay * by - az * bz,
    ])


def q_to_m(q):
    x, y, z, w = q / np.linalg.norm(q)
    return np.array([
        [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
        [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
        [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
    ])


def m_to_q(m):
    t = m[0, 0] + m[1, 1] + m[2, 2]
    if t > 0:
        s = math.sqrt(t + 1.0) * 2
        w = 0.25 * s
        x = (m[2, 1] - m[1, 2]) / s
        y = (m[0, 2] - m[2, 0]) / s
        z = (m[1, 0] - m[0, 1]) / s
    elif m[0, 0] > m[1, 1] and m[0, 0] > m[2, 2]:
        s = math.sqrt(1.0 + m[0, 0] - m[1, 1] - m[2, 2]) * 2
        w = (m[2, 1] - m[1, 2]) / s
        x = 0.25 * s
        y = (m[0, 1] + m[1, 0]) / s
        z = (m[0, 2] + m[2, 0]) / s
    elif m[1, 1] > m[2, 2]:
        s = math.sqrt(1.0 + m[1, 1] - m[0, 0] - m[2, 2]) * 2
        w = (m[0, 2] - m[2, 0]) / s
        x = (m[0, 1] + m[1, 0]) / s
        y = 0.25 * s
        z = (m[1, 2] + m[2, 1]) / s
    else:
        s = math.sqrt(1.0 + m[2, 2] - m[0, 0] - m[1, 1]) * 2
        w = (m[1, 0] - m[0, 1]) / s
        x = (m[0, 2] + m[2, 0]) / s
        y = (m[1, 2] + m[2, 1]) / s
        z = 0.25 * s
    q = np.array([x, y, z, w])
    return q / np.linalg.norm(q)


def slerp(a, b, t):
    d = float(np.dot(a, b))
    if d < 0:
        b = -b
        d = -d
    if d > 0.9995:
        r = a + t * (b - a)
        return r / np.linalg.norm(r)
    th = math.acos(d)
    s = math.sin(th)
    return (math.sin((1 - t) * th) * a + math.sin(t * th) * b) / s


def nrm(v):
    n = np.linalg.norm(v)
    return v / n if n > 1e-9 else v


def perp(v, axis):
    """component of v perpendicular to (unit) axis"""
    return v - axis * float(np.dot(v, axis))


def frame(primary, secondary):
    x = nrm(primary)
    z = nrm(np.cross(x, secondary))
    y = np.cross(z, x)
    return np.stack([x, y, z], axis=1)


# ----------------------------------------------------------------------------
# skeleton definitions
# ----------------------------------------------------------------------------

PARENT = {
    'Hips': None, 'Spine': 'Hips', 'Spine1': 'Spine', 'Spine2': 'Spine1', 'Neck': 'Spine2', 'Head': 'Neck',
    'LeftShoulder': 'Spine2', 'LeftArm': 'LeftShoulder', 'LeftForeArm': 'LeftArm', 'LeftHand': 'LeftForeArm',
    'RightShoulder': 'Spine2', 'RightArm': 'RightShoulder', 'RightForeArm': 'RightArm', 'RightHand': 'RightForeArm',
    'LeftUpLeg': 'Hips', 'LeftLeg': 'LeftUpLeg', 'LeftFoot': 'LeftLeg', 'LeftToeBase': 'LeftFoot',
    'RightUpLeg': 'Hips', 'RightLeg': 'RightUpLeg', 'RightFoot': 'RightLeg', 'RightToeBase': 'RightFoot',
}
for side in ('Left', 'Right'):
    for f in ('Thumb', 'Index', 'Middle', 'Ring', 'Pinky'):
        PARENT[f'{side}Hand{f}1'] = f'{side}Hand'
        PARENT[f'{side}Hand{f}2'] = f'{side}Hand{f}1'
        PARENT[f'{side}Hand{f}3'] = f'{side}Hand{f}2'

DRIVEN = ['Hips', 'Spine', 'Spine1', 'Spine2', 'Neck', 'Head',
          'LeftShoulder', 'LeftArm', 'LeftForeArm', 'LeftHand',
          'RightShoulder', 'RightArm', 'RightForeArm', 'RightHand',
          'LeftUpLeg', 'LeftLeg', 'LeftFoot', 'RightUpLeg', 'RightLeg', 'RightFoot']


def order_bones(names):
    out, seen = [], set()

    def add(n):
        if n in seen or n not in names:
            return
        p = PARENT.get(n)
        if p:
            add(p)
        seen.add(n)
        out.append(n)
    for n in names:
        add(n)
    return out


# ----------------------------------------------------------------------------
# source clip loading and FK
# ----------------------------------------------------------------------------

def load_clip(path):
    d = json.load(open(path))
    tracks = {}
    spine_seen = 0
    for t in d['tracks']:
        name, prop = t['name'].rsplit('.', 1)
        if name == 'Spine':
            # the library flattens Spine/Spine1/Spine2 to "Spine"; recover order
            if prop == 'position':
                spine_seen += 1
            name = ['Spine', 'Spine1', 'Spine2'][min(spine_seen, 3) - 1]
        tracks[(name, prop)] = (np.array(t['times'], dtype=float), np.array(t['values'], dtype=float))
    return d['name'], float(d['duration']), tracks


def sample(track, t, size):
    times, vals = track
    vals = vals.reshape(-1, size)
    if len(times) == 1 or t <= times[0]:
        return vals[0].copy()
    if t >= times[-1]:
        return vals[-1].copy()
    i = int(np.searchsorted(times, t)) - 1
    i = max(0, min(i, len(times) - 2))
    a = (t - times[i]) / max(1e-9, times[i + 1] - times[i])
    if size == 4:
        return slerp(vals[i], vals[i + 1], a)
    return vals[i] * (1 - a) + vals[i + 1] * a


def source_pose(tracks, t):
    """world positions and rotations of the source skeleton at time t"""
    bones = order_bones([n for (n, p) in tracks.keys()])
    P, R = {}, {}
    for b in bones:
        pos = sample(tracks[(b, 'position')], t, 3) if (b, 'position') in tracks else np.zeros(3)
        rot = sample(tracks[(b, 'quaternion')], t, 4) if (b, 'quaternion') in tracks else np.array([0, 0, 0, 1.0])
        p = PARENT.get(b)
        if p is None:
            P[b] = pos
            R[b] = q_to_m(rot)
        else:
            P[b] = P[p] + R[p] @ pos
            R[b] = R[p] @ q_to_m(rot)
    return P, R


# ----------------------------------------------------------------------------
# target frames
# ----------------------------------------------------------------------------

def limb_normal(a, b, c, rest_bend, body_fallback):
    """plane normal of a 3-joint limb, robust when nearly straight"""
    upper = nrm(b - a)
    lower = nrm(c - b)
    bend = perp(lower, upper)
    s = np.linalg.norm(bend)
    fb = perp(body_fallback, upper)
    if np.linalg.norm(fb) < 1e-4:
        fb = perp(rest_bend, upper)
    fb = nrm(fb)
    w = min(1.0, max(0.0, (s - 0.05) / 0.25))
    sec = nrm(nrm(bend) * w + fb * (1 - w)) if s > 1e-6 else fb
    return nrm(np.cross(upper, sec))


def bone_frames(P, R=None, head_axes=None, rest=False):
    """compute world frames for DRIVEN bones from joint positions"""
    F = {}
    left_hips = nrm(P['LeftUpLeg'] - P['RightUpLeg'])
    left_chest = nrm(P['LeftArm'] - P['RightArm'])
    up_body = nrm(P['Neck'] - P['Hips'])
    fwd_body = nrm(np.cross(left_chest, up_body))

    F['Hips'] = frame(P['Spine'] - P['Hips'], left_hips)
    F['Spine'] = frame(P['Spine1'] - P['Spine'], nrm(left_hips * 0.66 + left_chest * 0.34))
    F['Spine1'] = frame(P['Spine2'] - P['Spine1'], nrm(left_hips * 0.33 + left_chest * 0.67))
    F['Spine2'] = frame(P['Neck'] - P['Spine2'], left_chest)
    F['Neck'] = frame(P['Head'] - P['Neck'], left_chest)
    if rest:
        F['Head'] = frame(np.array([0, 1.0, 0]), np.array([1.0, 0, 0]))
    else:
        up_l, left_l = head_axes
        F['Head'] = frame(R['Head'] @ up_l, R['Head'] @ left_l)

    for side, sgn in (('Left', 1.0), ('Right', -1.0)):
        sh, arm, fore, hand = (P[f'{side}Shoulder'], P[f'{side}Arm'], P[f'{side}ForeArm'], P[f'{side}Hand'])
        F[f'{side}Shoulder'] = frame(arm - sh, up_body)
        if rest:
            n = nrm(np.cross(nrm(fore - arm), np.array([0, 0, 1.0])))
        else:
            n = limb_normal(arm, fore, hand, fwd_body, fwd_body * 0.7 - up_body * 0.3)
        F[f'{side}Arm'] = frame(fore - arm, np.cross(n, nrm(fore - arm)))
        F[f'{side}ForeArm'] = frame(hand - fore, np.cross(n, nrm(hand - fore)))
        mid = P.get(f'{side}HandMiddle1')
        idx = P.get(f'{side}HandIndex1')
        pky = P.get(f'{side}HandPinky1')
        if mid is not None and idx is not None and pky is not None:
            F[f'{side}Hand'] = frame(mid - hand, (idx - pky) * sgn)
        else:
            F[f'{side}Hand'] = F[f'{side}ForeArm']

        hip, knee, foot, toe = (P[f'{side}UpLeg'], P[f'{side}Leg'], P[f'{side}Foot'], P[f'{side}ToeBase'])
        if rest:
            nl = nrm(np.cross(nrm(knee - hip), -fwd_body))
        else:
            nl = limb_normal(hip, knee, foot, -fwd_body, -fwd_body)
        F[f'{side}UpLeg'] = frame(knee - hip, np.cross(nl, nrm(knee - hip)))
        F[f'{side}Leg'] = frame(foot - knee, np.cross(nl, nrm(foot - knee)))
        F[f'{side}Foot'] = frame(toe - foot, left_hips)
    return F


# ----------------------------------------------------------------------------
# GLB rewriting
# ----------------------------------------------------------------------------

class GlbBuilder:
    def __init__(self, gltf):
        self.g = gltf
        self.blob = bytearray()
        self.views = []

    def add_view(self, data, target=None):
        while len(self.blob) % 4:
            self.blob.append(0)
        off = len(self.blob)
        self.blob.extend(data)
        bv = BufferView(buffer=0, byteOffset=off, byteLength=len(data))
        if target:
            bv.target = target
        self.views.append(bv)
        return len(self.views) - 1


def downscale(png_bytes, size, fmt='PNG'):
    im = Image.open(io.BytesIO(png_bytes))
    im.load()
    if max(im.size) > size:
        im = im.resize((size, size), Image.LANCZOS)
    out = io.BytesIO()
    if fmt == 'JPEG':
        im.convert('RGB').save(out, 'JPEG', quality=88)
        return out.getvalue(), 'image/jpeg'
    im.save(out, 'PNG', optimize=True)
    return out.getvalue(), 'image/png'


def main():
    src_glb, clips_dir, out_glb, clipset_path = sys.argv[1:5]
    clipset = json.load(open(clipset_path))
    tex_sizes = clipset.get('textures', {'base': 1024, 'normal': 512, 'mr': 512})
    g = GLTF2().load(src_glb)
    raw = g.binary_blob()

    # ---- target skeleton --------------------------------------------------
    name_to_node = {}
    for i, n in enumerate(g.nodes):
        if n.name and n.name.startswith('mixamorig:'):
            name_to_node[n.name.split(':', 1)[1]] = i
    hips_node = name_to_node['Hips']
    rest_local_t = {b: np.array(g.nodes[i].translation or [0, 0, 0], dtype=float) for b, i in name_to_node.items()}
    for b, i in name_to_node.items():
        r = g.nodes[i].rotation
        if r and np.abs(np.array(r) - np.array([0, 0, 0, 1])).max() > 1e-4:
            raise SystemExit(f'non identity rest rotation on {b}; pipeline expects identity rests')
    TP = {}
    for b in order_bones(list(name_to_node.keys())):
        p = PARENT.get(b)
        TP[b] = rest_local_t[b] if p is None else TP[p] + rest_local_t[b]
    rest_frames = bone_frames(TP, rest=True)

    # mesh bounds -> feet offset
    prim = g.meshes[0].primitives[0]
    pos_acc = g.accessors[prim.attributes.POSITION]
    min_y = pos_acc.min[1]
    target_hip_h = TP['Hips'][1] - min_y

    # ---- rebuild buffer -----------------------------------------------------
    B = GlbBuilder(g)
    old_views = g.bufferViews
    view_map = {}
    # drop unreferenced accessors (the auto-rigger leaves stale copies behind)
    used_acc = set()
    for m in g.meshes:
        for pr in m.primitives:
            used_acc.update(v for v in pr.attributes.__dict__.values() if isinstance(v, int))
            if pr.indices is not None:
                used_acc.add(pr.indices)
    for sk in g.skins:
        if sk.inverseBindMatrices is not None:
            used_acc.add(sk.inverseBindMatrices)
    acc_map, new_accs = {}, []
    for ai, acc in enumerate(g.accessors):
        if ai in used_acc:
            acc_map[ai] = len(new_accs)
            new_accs.append(acc)
    g.accessors = new_accs
    for m in g.meshes:
        for pr in m.primitives:
            for k, v in list(pr.attributes.__dict__.items()):
                if isinstance(v, int):
                    setattr(pr.attributes, k, acc_map[v])
            if pr.indices is not None:
                pr.indices = acc_map[pr.indices]
            pr.targets = None
    for sk in g.skins:
        if sk.inverseBindMatrices is not None:
            sk.inverseBindMatrices = acc_map[sk.inverseBindMatrices]
    used_views = {a.bufferView for a in g.accessors if a.bufferView is not None}
    for vi, bv in enumerate(old_views):
        if vi not in used_views:
            continue
        data = raw[bv.byteOffset or 0:(bv.byteOffset or 0) + bv.byteLength]
        nv = B.add_view(data, bv.target)
        B.views[nv].byteStride = bv.byteStride
        view_map[vi] = nv
    for acc in g.accessors:
        if acc.bufferView is not None:
            acc.bufferView = view_map[acc.bufferView]

    # textures: keep base colour, normal, metal-rough; drop occlusion (mobile)
    mat = g.materials[0]
    tex_role = {}
    pbr = mat.pbrMetallicRoughness
    if pbr.baseColorTexture:
        tex_role[pbr.baseColorTexture.index] = 'base'
    if mat.normalTexture:
        tex_role[mat.normalTexture.index] = 'normal'
    if pbr.metallicRoughnessTexture:
        tex_role[pbr.metallicRoughnessTexture.index] = 'mr'
    mat.occlusionTexture = None
    new_images, new_textures, remap_tex = [], [], {}
    for ti, tex in enumerate(g.textures):
        if ti not in tex_role:
            continue
        src = tex.source
        if src is None and tex.extensions.get('EXT_texture_webp'):
            src = tex.extensions['EXT_texture_webp']['source']
        img = g.images[src]
        bv = old_views[img.bufferView]
        data = raw[bv.byteOffset or 0:(bv.byteOffset or 0) + bv.byteLength]
        role = tex_role[ti]
        size = tex_sizes.get(role, 512)
        if size == 0:
            continue
        nd, mime = downscale(data, size, 'JPEG' if role == 'base' else 'PNG')
        v = B.add_view(nd)
        from pygltflib import Image as GImage, Texture
        new_images.append(GImage(bufferView=v, mimeType=mime, name=f'{role}'))
        new_textures.append(Texture(sampler=0, source=len(new_images) - 1))
        remap_tex[ti] = len(new_textures) - 1
    g.images = new_images
    g.textures = new_textures
    g.extensionsUsed = [e for e in (g.extensionsUsed or []) if e != 'EXT_texture_webp']
    g.extensionsRequired = [e for e in (g.extensionsRequired or []) if e != 'EXT_texture_webp']
    if pbr.baseColorTexture:
        pbr.baseColorTexture.index = remap_tex[pbr.baseColorTexture.index]
    if mat.normalTexture:
        if mat.normalTexture.index in remap_tex:
            mat.normalTexture.index = remap_tex[mat.normalTexture.index]
        else:
            mat.normalTexture = None
    if pbr.metallicRoughnessTexture:
        if pbr.metallicRoughnessTexture.index in remap_tex:
            pbr.metallicRoughnessTexture.index = remap_tex[pbr.metallicRoughnessTexture.index]
        else:
            pbr.metallicRoughnessTexture = None
    mat.doubleSided = False
    mat.name = clipset.get('material_name', 'character')

    # ---- root node: put feet on the floor ----------------------------------
    scene = g.scenes[g.scene or 0]
    root = Node(name='Armature', translation=[0.0, float(-min_y), 0.0], children=list(scene.nodes))
    g.nodes.append(root)
    scene.nodes = [len(g.nodes) - 1]

    # ---- animations -----------------------------------------------------------
    g.animations = []

    def add_accessor(arr, typ, minmax=False):
        arr = np.ascontiguousarray(arr, dtype=np.float32)
        v = B.add_view(arr.tobytes())
        acc = Accessor(bufferView=v, componentType=5126, count=int(arr.shape[0]), type=typ)
        if minmax:
            acc.min = [float(arr.min())]
            acc.max = [float(arr.max())]
        g.accessors.append(acc)
        return len(g.accessors) - 1

    for entry in clipset['clips']:
        cname, cfile = entry['name'], entry['clip']
        _, dur, tracks = load_clip(f'{clips_dir}/{cfile}.json')
        speed = entry.get('speed', 1.0)
        n_frames = max(2, int(round(dur * FPS)) + 1)
        times = np.linspace(0, dur, n_frames)

        # source orientation correction from frame 0
        P0, R0 = source_pose(tracks, 0.0)
        up = nrm(P0['Neck'] - P0['Hips'])
        left = nrm(perp(P0['LeftUpLeg'] - P0['RightUpLeg'], up))
        fwd = np.cross(left, up)
        C = np.stack([left, up, fwd], axis=0)  # rows -> maps src to canonical
        # head local axes calibration (assume neutral head on frame 0)
        Rh = R0['Head']
        up_l = Rh.T @ up
        left_l = Rh.T @ left
        src_hip_h = None

        rot_keys = {b: [] for b in DRIVEN if b in name_to_node}
        hip_t = []
        for t in times:
            P, R = source_pose(tracks, t)
            P = {k: C @ v for k, v in P.items()}
            R = {k: C @ v for k, v in R.items()}
            if src_hip_h is None:
                foot_y = min(P['LeftToeBase'][1], P['RightToeBase'][1], P['LeftFoot'][1], P['RightFoot'][1])
                src_hip_h = P['Hips'][1] - foot_y + 0.03
                src_ground = foot_y - 0.03
            Fs = bone_frames(P, R, head_axes=(up_l, left_l))
            world = {}
            for b in order_bones(list(rot_keys.keys())):
                Wr = Fs[b] @ rest_frames[b].T
                world[b] = Wr
                p = PARENT.get(b)
                while p is not None and p not in world:
                    p = PARENT.get(p)
                local = Wr if p is None else world[p].T @ Wr
                rot_keys[b].append(m_to_q(local))
            s = target_hip_h / src_hip_h
            hp = (P['Hips'] - np.array([0, src_ground, 0])) * s
            hip_t.append(np.array([hp[0], hp[1] + min_y, hp[2]]))

        hip_t = np.array(hip_t)
        if entry.get('in_place', True):
            # remove horizontal travel but keep sway
            base = hip_t[0, [0, 2]].copy()
            drift = hip_t[-1, [0, 2]] - base
            for i in range(len(hip_t)):
                a = i / (len(hip_t) - 1)
                hip_t[i, [0, 2]] -= base + drift * a
                hip_t[i, [0, 2]] += TP['Hips'][[0, 2]]
        else:
            # keep the travel but start from the rest position
            hip_t[:, [0, 2]] += TP['Hips'][[0, 2]] - hip_t[0, [0, 2]]
        y_off = entry.get('y_offset', 0.0)
        hip_t[:, 1] += y_off

        # continuity of quaternion signs
        for b, qs in rot_keys.items():
            for i in range(1, len(qs)):
                if np.dot(qs[i], qs[i - 1]) < 0:
                    qs[i] = -qs[i]

        t_acc = add_accessor(times / speed, 'SCALAR', minmax=True)
        samplers, channels = [], []
        for b, qs in rot_keys.items():
            v_acc = add_accessor(np.array(qs), 'VEC4')
            samplers.append(AnimationSampler(input=t_acc, output=v_acc, interpolation='LINEAR'))
            channels.append(AnimationChannel(sampler=len(samplers) - 1,
                                             target=AnimationChannelTarget(node=name_to_node[b], path='rotation')))
        v_acc = add_accessor(hip_t, 'VEC3')
        samplers.append(AnimationSampler(input=t_acc, output=v_acc, interpolation='LINEAR'))
        channels.append(AnimationChannel(sampler=len(samplers) - 1,
                                         target=AnimationChannelTarget(node=hips_node, path='translation')))
        g.animations.append(Animation(name=cname, samplers=samplers, channels=channels))
        print(f'  baked {cname:<12} <- {cfile} ({dur:.2f}s, {n_frames} frames)')

    g.bufferViews = B.views
    g.buffers[0].byteLength = len(B.blob)
    g.buffers[0].uri = None
    g.set_binary_blob(bytes(B.blob))
    g.save_binary(out_glb)
    print(f'wrote {out_glb}: {len(B.blob) / 1e6:.2f} MB, tris={g.accessors[prim.indices].count // 3}')


if __name__ == '__main__':
    main()
