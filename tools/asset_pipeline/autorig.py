#!/usr/bin/env python3
"""
SECTOR ABANDONADO - fallback humanoid auto-rigger.

Used for meshes the external auto-rigger rejects (the hulking Tank zombie).
Writes a GLB in the same convention bake_character.py expects:
mixamorig:* joint names, identity rest rotations, translations only.

1. Joint placement: joints of a reference rig are mapped into the target
   mesh bounding box, then limb joints are re-centred on the local
   cross-section centroid of the mesh so they sit inside the limbs.
2. Skin weights: inverse distance (power 4) to bone segments, limited to the
   4 closest bones, with left/right side masking for limbs.

Usage: autorig.py <static.glb> <reference_rigged.glb> <out.glb>
"""
import sys
import numpy as np
from pygltflib import GLTF2, Node, Skin, Accessor, BufferView

JOINTS = ['Hips', 'Spine', 'Spine1', 'Spine2', 'Neck', 'Head',
          'LeftShoulder', 'LeftArm', 'LeftForeArm', 'LeftHand',
          'RightShoulder', 'RightArm', 'RightForeArm', 'RightHand',
          'LeftUpLeg', 'LeftLeg', 'LeftFoot', 'LeftToeBase',
          'RightUpLeg', 'RightLeg', 'RightFoot', 'RightToeBase']
PARENT = {'Hips': None, 'Spine': 'Hips', 'Spine1': 'Spine', 'Spine2': 'Spine1', 'Neck': 'Spine2', 'Head': 'Neck',
          'LeftShoulder': 'Spine2', 'LeftArm': 'LeftShoulder', 'LeftForeArm': 'LeftArm', 'LeftHand': 'LeftForeArm',
          'RightShoulder': 'Spine2', 'RightArm': 'RightShoulder', 'RightForeArm': 'RightArm', 'RightHand': 'RightForeArm',
          'LeftUpLeg': 'Hips', 'LeftLeg': 'LeftUpLeg', 'LeftFoot': 'LeftLeg', 'LeftToeBase': 'LeftFoot',
          'RightUpLeg': 'Hips', 'RightLeg': 'RightUpLeg', 'RightFoot': 'RightLeg', 'RightToeBase': 'RightFoot'}
CHILD = {'Hips': 'Spine', 'Spine': 'Spine1', 'Spine1': 'Spine2', 'Spine2': 'Neck', 'Neck': 'Head', 'Head': None,
         'LeftShoulder': 'LeftArm', 'LeftArm': 'LeftForeArm', 'LeftForeArm': 'LeftHand', 'LeftHand': None,
         'RightShoulder': 'RightArm', 'RightArm': 'RightForeArm', 'RightForeArm': 'RightHand', 'RightHand': None,
         'LeftUpLeg': 'LeftLeg', 'LeftLeg': 'LeftFoot', 'LeftFoot': 'LeftToeBase', 'LeftToeBase': None,
         'RightUpLeg': 'RightLeg', 'RightLeg': 'RightFoot', 'RightFoot': 'RightToeBase', 'RightToeBase': None}


def read_acc(g, blob, idx):
    a = g.accessors[idx]
    bv = g.bufferViews[a.bufferView]
    n = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}[a.type]
    dt = {5126: np.float32, 5125: np.uint32, 5123: np.uint16, 5121: np.uint8}[a.componentType]
    off = (bv.byteOffset or 0) + (a.byteOffset or 0)
    return np.frombuffer(blob[off:off + a.count * n * np.dtype(dt).itemsize], dtype=dt).reshape(a.count, n)


def ref_positions(path):
    g = GLTF2().load(path)
    nodes = {n.name.split(':', 1)[1]: i for i, n in enumerate(g.nodes) if n.name and n.name.startswith('mixamorig:')}
    P = {}

    def walk(b, acc):
        t = np.array(g.nodes[nodes[b]].translation or [0, 0, 0])
        P[b] = acc + t
        for c in g.nodes[nodes[b]].children or []:
            walk(g.nodes[c].name.split(':', 1)[1], P[b])
    walk('Hips', np.zeros(3))
    blob = g.binary_blob()
    pos = read_acc(g, blob, g.meshes[0].primitives[0].attributes.POSITION)
    return {k: P[k] for k in JOINTS}, pos.min(0), pos.max(0)


def main():
    src, ref, out = sys.argv[1:4]
    RP, rmin, rmax = ref_positions(ref)
    g = GLTF2().load(src)
    blob = bytearray(g.binary_blob())
    prim = g.meshes[0].primitives[0]
    V = read_acc(g, blob, prim.attributes.POSITION).astype(np.float64)
    vmin, vmax = V.min(0), V.max(0)
    H = vmax[1] - vmin[1]

    # 1. map reference joints into the bbox
    P = {}
    for k, p in RP.items():
        u = (p - rmin) / (rmax - rmin)
        P[k] = vmin + u * (vmax - vmin)

    # 2. re-centre limb joints on local cross-section centroid
    def recenter(name, radius, side):
        c = P[name]
        mask = np.linalg.norm(V - c, axis=1) < radius
        if side:
            mask &= (np.sign(V[:, 0]) == side)
        if mask.sum() > 20:
            P[name] = V[mask].mean(0)

    for _ in range(2):
        for side, s in (('Left', 1), ('Right', -1)):
            for j, r in (('Hand', 0.10), ('ForeArm', 0.10), ('Arm', 0.10), ('Foot', 0.08), ('Leg', 0.09), ('UpLeg', 0.10)):
                recenter(side + j, r * H, s)
    # spine joints on the mid line
    for j in ('Hips', 'Spine', 'Spine1', 'Spine2', 'Neck', 'Head'):
        P[j][0] = 0.0
    # shoulders sit between neck and upper arm
    for side in ('Left', 'Right'):
        P[side + 'Shoulder'] = P['Spine2'] * 0.45 + P[side + 'Arm'] * 0.55
        P[side + 'Shoulder'][1] = max(P[side + 'Shoulder'][1], P[side + 'Arm'][1])
        P[side + 'ToeBase'] = P[side + 'Foot'] + np.array([0, -0.6, 1.6]) * (P[side + 'Foot'][1] - vmin[1])
        P[side + 'ToeBase'][1] = vmin[1] + 0.02 * H

    # 3. weights: distance to bone segments
    segs = []
    for j in JOINTS:
        c = CHILD[j]
        a = P[j]
        b = P[c] if c else P[j] + (P[j] - P[PARENT[j]]) * 0.5
        segs.append((a, b))
    A = np.array([s[0] for s in segs])
    B = np.array([s[1] for s in segs])
    AB = B - A
    d = np.zeros((len(V), len(JOINTS)))
    for i in range(len(JOINTS)):
        ap = V - A[i]
        t = np.clip((ap @ AB[i]) / max(1e-9, AB[i] @ AB[i]), 0, 1)
        proj = A[i] + t[:, None] * AB[i]
        d[:, i] = np.linalg.norm(V - proj, axis=1)
    # side masks: limbs only influence their own side
    for i, j in enumerate(JOINTS):
        if j.startswith('Left') and not j.endswith('Shoulder'):
            d[V[:, 0] < -0.02 * H, i] = 1e6
        if j.startswith('Right') and not j.endswith('Shoulder'):
            d[V[:, 0] > 0.02 * H, i] = 1e6
    # torso exclusion: vertices medial to the shoulder sockets never follow arm bones
    arm_x = abs(P['LeftArm'][0])
    medial = np.abs(V[:, 0]) < 0.85 * arm_x
    above_hips = V[:, 1] > P['Hips'][1]
    for i, j in enumerate(JOINTS):
        if any(j.endswith(k) for k in ('Arm', 'ForeArm', 'Hand')):
            d[medial, i] = 1e6
        if any(j.endswith(k) for k in ('Leg', 'Foot', 'ToeBase')) and not j.endswith('UpLeg'):
            d[above_hips, i] = 1e6
    # hard assignment to the nearest bone, then diffuse over the surface graph
    nearest = np.argmin(d, axis=1)
    W = np.zeros((len(V), len(JOINTS)))
    W[np.arange(len(V)), nearest] = 1.0
    # weld vertices split by UV seams so diffusion crosses seams
    key = np.round(V / (H * 1e-4)).astype(np.int64)
    _, weld, inv = np.unique(key, axis=0, return_index=True, return_inverse=True)
    inv = inv.reshape(-1)
    tri = read_acc(g, blob, prim.indices).reshape(-1, 3).astype(np.int64)
    tw_ = inv[tri]
    edges = np.concatenate([tw_[:, [0, 1]], tw_[:, [1, 2]], tw_[:, [2, 0]]])
    edges = np.concatenate([edges, edges[:, ::-1]])
    nW = len(weld)
    Ww = np.zeros((nW, len(JOINTS)))
    np.add.at(Ww, inv, W)
    Ww /= np.maximum(Ww.sum(1, keepdims=True), 1e-9)
    deg = np.bincount(edges[:, 0], minlength=nW).astype(float)[:, None]
    for _ in range(12):
        acc = np.zeros_like(Ww)
        np.add.at(acc, edges[:, 0], Ww[edges[:, 1]])
        Ww = 0.5 * Ww + 0.5 * acc / np.maximum(deg, 1)
    w = Ww[inv]
    top = np.argsort(-w, axis=1)[:, :4]
    tw = np.take_along_axis(w, top, axis=1)
    tw[tw < 0.04] = 0
    tw /= np.maximum(tw.sum(1, keepdims=True), 1e-9)
    joints_u8 = top.astype(np.uint8)
    weights_f = tw.astype(np.float32)

    # 4. write nodes + skin
    base = len(g.nodes)
    idx = {j: base + i for i, j in enumerate(JOINTS)}
    for j in JOINTS:
        p = PARENT[j]
        t = P[j] if p is None else P[j] - P[p]
        g.nodes.append(Node(name='mixamorig:' + j, translation=[float(x) for x in t]))
    for j in JOINTS:
        kids = [idx[c] for c in JOINTS if PARENT[c] == j]
        if kids:
            g.nodes[idx[j]].children = kids

    def add(arr, typ, ctype, target=None):
        while len(blob) % 4:
            blob.append(0)
        off = len(blob)
        data = np.ascontiguousarray(arr).tobytes()
        blob.extend(data)
        bv = BufferView(buffer=0, byteOffset=off, byteLength=len(data))
        if target:
            bv.target = target
        g.bufferViews.append(bv)
        g.accessors.append(Accessor(bufferView=len(g.bufferViews) - 1, componentType=ctype,
                                    count=int(arr.shape[0]), type=typ))
        return len(g.accessors) - 1

    ibm = np.zeros((len(JOINTS), 16), dtype=np.float32)
    for i, j in enumerate(JOINTS):
        m = np.eye(4, dtype=np.float32)
        m[:3, 3] = -P[j]
        ibm[i] = m.T.reshape(16)  # column major
    ibm_acc = add(ibm, 'MAT4', 5126)
    prim.attributes.JOINTS_0 = add(joints_u8, 'VEC4', 5121, 34962)
    prim.attributes.WEIGHTS_0 = add(weights_f, 'VEC4', 5126, 34962)
    g.skins = [Skin(joints=[idx[j] for j in JOINTS], inverseBindMatrices=ibm_acc, skeleton=idx['Hips'])]
    mesh_node = [i for i, n in enumerate(g.nodes) if n.mesh is not None][0]
    g.nodes[mesh_node].skin = 0
    g.scenes[g.scene or 0].nodes.append(idx['Hips'])
    g.buffers[0].byteLength = len(blob)
    g.set_binary_blob(bytes(blob))
    g.save_binary(out)
    for j in ('Hips', 'Head', 'LeftArm', 'LeftHand', 'LeftFoot'):
        print(j, np.round(P[j], 3))
    print('wrote', out)


if __name__ == '__main__':
    main()
