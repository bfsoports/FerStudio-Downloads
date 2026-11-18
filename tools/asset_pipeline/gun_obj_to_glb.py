#!/usr/bin/env python3
"""
Converts Quaternius "Ultimate Gun Pack" (CC0) OBJ/MTL models into game-ready
GLBs for SECTOR ABANDONADO:
  * barrel re-oriented to Godot forward (-Z), grip at origin-ish,
  * uniform scale so the weapon has a believable real-world length,
  * one flat-colour material per MTL material (shared palette, no textures),
  * an empty "Muzzle" node at the barrel tip and "Eject" node for casings,
  * optional accessories merged (e.g. a bipod on the LMG).

Usage: gun_obj_to_glb.py <out.glb> <length_m> <main.obj> [<accessory.obj> dx dy dz scale] ...
"""
import sys
import struct
import json
import numpy as np


def parse_mtl(path):
    mats, cur = {}, None
    try:
        for line in open(path):
            p = line.split()
            if not p:
                continue
            if p[0] == 'newmtl':
                cur = p[1]
                mats[cur] = {'kd': [0.5, 0.5, 0.5]}
            elif p[0] == 'Kd' and cur:
                mats[cur]['kd'] = [float(x) for x in p[1:4]]
    except FileNotFoundError:
        pass
    return mats


def parse_obj(path, offset=(0, 0, 0), scale=1.0):
    verts, groups, cur = [], {}, 'default'
    for line in open(path):
        p = line.split()
        if not p:
            continue
        if p[0] == 'v':
            verts.append([float(x) for x in p[1:4]])
        elif p[0] == 'usemtl':
            cur = p[1]
        elif p[0] == 'f':
            idx = [int(t.split('/')[0]) for t in p[1:]]
            idx = [i - 1 if i > 0 else len(verts) + i for i in idx]
            for k in range(1, len(idx) - 1):
                groups.setdefault(cur, []).append((idx[0], idx[k], idx[k + 1]))
    v = np.array(verts) * scale + np.array(offset)
    return v, groups, parse_mtl(path[:-4] + '.mtl')


def main():
    out, length = sys.argv[1], float(sys.argv[2])
    parts = [(sys.argv[3], (0, 0, 0), 1.0)]
    rest = sys.argv[4:]
    while rest:
        parts.append((rest[0], tuple(float(x) for x in rest[1:4]), float(rest[4])))
        rest = rest[5:]

    tris_by_mat, mat_colors = {}, {}
    all_v = []
    for path, off, sc in parts:
        v, groups, mtl = parse_obj(path, off, sc)
        for mname, tris in groups.items():
            key = mname
            mat_colors[key] = mtl.get(mname, {'kd': [0.4, 0.4, 0.4]})['kd']
            for a, b, c in tris:
                tris_by_mat.setdefault(key, []).append((v[a], v[b], v[c]))
        all_v.append(v)
    V = np.concatenate(all_v)
    main_v = all_v[0]
    mn, mx = main_v.min(0), main_v.max(0)
    s = length / (mx[0] - mn[0])
    # muzzle: barrel tip at max X
    tip = main_v[main_v[:, 0] > mx[0] - 0.02 * (mx[0] - mn[0])]
    muzzle_src = np.array([mx[0], tip[:, 1].mean(), tip[:, 2].mean()])
    # grip origin: lowest region in the rear half (pistol grip)
    rear = main_v[main_v[:, 0] < mn[0] + 0.55 * (mx[0] - mn[0])]
    low = rear[rear[:, 1] < rear[:, 1].min() + 0.25 * (mx[1] - mn[1])]
    grip = np.array([low[:, 0].mean(), muzzle_src[1], 0.0]) if len(low) else np.array([mn[0], muzzle_src[1], 0.0])

    def xf(p):
        q = (np.asarray(p) - grip) * s
        # OBJ +X (barrel) -> Godot -Z ; OBJ +Y up ; OBJ +Z -> +X
        return np.stack([q[..., 2], q[..., 1], -q[..., 0]], axis=-1)

    blob = bytearray()
    views, accessors, meshes_prims, materials = [], [], [], []

    def add_view(data, target):
        while len(blob) % 4:
            blob.append(0)
        off = len(blob)
        blob.extend(data)
        views.append({'buffer': 0, 'byteOffset': off, 'byteLength': len(data), 'target': target})
        return len(views) - 1

    for mi, (mname, tris) in enumerate(sorted(tris_by_mat.items())):
        T = np.array(tris)  # n,3,3
        P = xf(T.reshape(-1, 3)).reshape(-1, 3, 3)
        n = np.cross(P[:, 1] - P[:, 0], P[:, 2] - P[:, 0])
        n /= np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-12)
        pos = P.reshape(-1, 3).astype(np.float32)
        nor = np.repeat(n, 3, axis=0).astype(np.float32)
        pv = add_view(pos.tobytes(), 34962)
        nv = add_view(nor.tobytes(), 34962)
        accessors.append({'bufferView': pv, 'componentType': 5126, 'count': len(pos), 'type': 'VEC3',
                          'min': pos.min(0).tolist(), 'max': pos.max(0).tolist()})
        accessors.append({'bufferView': nv, 'componentType': 5126, 'count': len(nor), 'type': 'VEC3'})
        kd = mat_colors[mname]
        lname = mname.lower()
        metal = 0.55 if ('metal' in lname or 'black' in lname or 'grey' in lname or 'gray' in lname) else 0.0
        rough = 0.55 if metal > 0 else 0.8
        materials.append({'name': 'gun_' + mname, 'pbrMetallicRoughness': {
            'baseColorFactor': [kd[0], kd[1], kd[2], 1.0], 'metallicFactor': metal, 'roughnessFactor': rough}})
        meshes_prims.append({'attributes': {'POSITION': len(accessors) - 2, 'NORMAL': len(accessors) - 1},
                             'material': len(materials) - 1})

    muzzle = xf(muzzle_src).tolist()
    eject = xf(np.array([grip[0] + 0.6 * (muzzle_src[0] - grip[0]) * 0.5, mx[1], 0.0])).tolist()
    gltf = {
        'asset': {'version': '2.0', 'generator': 'sector-abandonado gun_obj_to_glb (Quaternius CC0 source)'},
        'scene': 0,
        'scenes': [{'nodes': [0]}],
        'nodes': [
            {'name': 'Gun', 'children': [1, 2, 3]},
            {'name': 'GunMesh', 'mesh': 0},
            {'name': 'Muzzle', 'translation': muzzle},
            {'name': 'Eject', 'translation': eject},
        ],
        'meshes': [{'name': 'gun', 'primitives': meshes_prims}],
        'materials': materials,
        'accessors': accessors,
        'bufferViews': views,
        'buffers': [{'byteLength': len(blob)}],
    }
    js = json.dumps(gltf).encode()
    while len(js) % 4:
        js += b' '
    while len(blob) % 4:
        blob.append(0)
    with open(out, 'wb') as f:
        total = 12 + 8 + len(js) + 8 + len(blob)
        f.write(struct.pack('<III', 0x46546C67, 2, total))
        f.write(struct.pack('<II', len(js), 0x4E4F534A))
        f.write(js)
        f.write(struct.pack('<II', len(blob), 0x004E4942))
        f.write(bytes(blob))
    ntri = sum(len(t) for t in tris_by_mat.values())
    print(f'{out}: {ntri} tris, muzzle={np.round(muzzle, 3).tolist()}')


if __name__ == '__main__':
    main()
