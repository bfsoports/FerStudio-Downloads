#!/usr/bin/env python3
"""Prepara los personajes de los clientes (KayKit, CC0) para el juego.

  - Copia a assets/characters/ los cuerpos que se usan: el maniquí (KayKit Character Animations) y tres esqueletos
    (KayKit Skeletons FREE). Todos usan el mismo esqueleto «Rig_Medium».
  - Crea assets/characters/customer_anims.glb con SOLO las animaciones que usan los clientes (andar, esperar,
    saludar, celebrar y quejarse), sacadas de los GLB de animaciones de KayKit. Cada GLB original de animaciones pesa
    670-840 KB porque lleva el maniquí completo y entre 11 y 15 animaciones; aquí la malla se sustituye por un
    triángulo de 3 vértices (necesario para que Godot cree el Skeleton3D al importar) y se descarta lo demás.

Uso:
  python3 tools/gen_characters.py --anims <KayKit_Character_Animations_1.1> --skeletons <KayKit_Skeletons_1.1_FREE>
  python3 tools/gen_characters.py --check      (comprueba lo que hay en assets/characters/)
"""
import argparse
import json
import os
import shutil
import struct
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEST = os.path.join(ROOT, "assets", "characters")
ANIM_OUT = "customer_anims.glb"

# cuerpo -> (pack, ruta dentro del pack)
BODIES = {
    "mannequin_medium.glb": ("anims", os.path.join("Mannequin Character", "characters", "Mannequin_Medium.glb")),
    "skeleton_minion.glb": ("skeletons", os.path.join("characters", "gltf", "Skeleton_Minion.glb")),
    "skeleton_rogue.glb": ("skeletons", os.path.join("characters", "gltf", "Skeleton_Rogue.glb")),
    "skeleton_mage.glb": ("skeletons", os.path.join("characters", "gltf", "Skeleton_Mage.glb")),
}
# animación -> GLB de KayKit Character Animations que la contiene (Rig_Medium)
ANIMS = {
    "Idle_A": "Rig_Medium_General.glb",
    "Hit_A": "Rig_Medium_General.glb",
    "Walking_A": "Rig_Medium_MovementBasic.glb",
    "Cheering": "Rig_Medium_Simulation.glb",
    "Waving": "Rig_Medium_Simulation.glb",
}
ANIM_SUB = os.path.join("Animations", "gltf", "Rig_Medium")


def read_glb(path):
    data = open(path, "rb").read()
    off, js, binc = 12, None, b""
    while off < len(data):
        ln, ty = struct.unpack("<II", data[off:off + 8])
        chunk = data[off + 8:off + 8 + ln]
        if ty == 0x4E4F534A:
            js = json.loads(chunk)
        elif ty == 0x004E4942:
            binc = chunk
        off += 8 + ln
    return js, binc


def write_glb(path, js, binc):
    jb = json.dumps(js, separators=(",", ":")).encode("utf8")
    jb += b" " * ((4 - len(jb) % 4) % 4)
    binc += b"\0" * ((4 - len(binc) % 4) % 4)
    total = 12 + 8 + len(jb) + 8 + len(binc)
    with open(path, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, total))
        f.write(struct.pack("<II", len(jb), 0x4E4F534A) + jb)
        f.write(struct.pack("<II", len(binc), 0x004E4942) + binc)


class Builder:
    """Acumula accesores copiados de otros GLB en un buffer nuevo."""

    def __init__(self):
        self.blob = bytearray()
        self.views = []
        self.accessors = []

    def add_raw(self, raw, target=None):
        while len(self.blob) % 4:
            self.blob.append(0)
        v = {"buffer": 0, "byteOffset": len(self.blob), "byteLength": len(raw)}
        if target:
            v["target"] = target
        self.blob += raw
        self.views.append(v)
        return len(self.views) - 1

    def copy_accessor(self, js, binc, idx):
        a = dict(js["accessors"][idx])
        bv = js["bufferViews"][a["bufferView"]]
        if bv.get("byteStride"):
            raise ValueError("accesor intercalado no soportado")
        comp = {5120: 1, 5121: 1, 5122: 2, 5123: 2, 5125: 4, 5126: 4}[a["componentType"]]
        n = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}[a["type"]]
        start = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
        raw = binc[start:start + a["count"] * comp * n]
        a["bufferView"] = self.add_raw(raw)
        a.pop("byteOffset", None)
        self.accessors.append(a)
        return len(self.accessors) - 1

    def add_accessor(self, raw, comp_type, count, typ, mn=None, mx=None, target=None):
        a = {"bufferView": self.add_raw(raw, target), "componentType": comp_type, "count": count, "type": typ}
        if mn is not None:
            a["min"], a["max"] = mn, mx
        self.accessors.append(a)
        return len(self.accessors) - 1


def build_anims(anim_dir):
    base_js, base_bin = read_glb(os.path.join(anim_dir, ANIM_SUB, "Rig_Medium_General.glb"))
    names = [n.get("name") for n in base_js["nodes"]]
    b = Builder()
    nodes = json.loads(json.dumps(base_js["nodes"]))
    mesh_nodes = [i for i, n in enumerate(nodes) if "mesh" in n]
    for i in mesh_nodes:
        nodes[i].pop("mesh", None)
        nodes[i].pop("skin", None)
    # malla mínima (un triángulo pegado al hueso raíz) para que el importador cree el Skeleton3D
    keep = mesh_nodes[0]
    nodes[keep]["name"] = "AnimRigProxy"
    pos = struct.pack("<9f", 0, 0, 0, 0.001, 0, 0, 0, 0.001, 0)
    joints = struct.pack("<12B", *([0, 0, 0, 0] * 3))
    weights = struct.pack("<12f", *([1, 0, 0, 0] * 3))
    p = b.add_accessor(pos, 5126, 3, "VEC3", [0, 0, 0], [0.001, 0.001, 0], 34962)
    j = b.add_accessor(joints, 5121, 3, "VEC4", target=34962)
    w = b.add_accessor(weights, 5126, 3, "VEC4", target=34962)
    ind = b.add_accessor(struct.pack("<3H", 0, 1, 2) + b"\0\0", 5123, 3, "SCALAR", target=34963)
    b.accessors[ind]["count"] = 3
    meshes = [{"name": "AnimRigProxy", "primitives": [{"attributes": {"POSITION": p, "JOINTS_0": j, "WEIGHTS_0": w}, "indices": ind}]}]
    nodes[keep]["mesh"] = 0
    nodes[keep]["skin"] = 0
    skin = dict(base_js["skins"][0])
    if "inverseBindMatrices" in skin:
        skin["inverseBindMatrices"] = b.copy_accessor(base_js, base_bin, skin["inverseBindMatrices"])
    animations = []
    cache = {}
    for anim_name, fname in ANIMS.items():
        if fname not in cache:
            cache[fname] = read_glb(os.path.join(anim_dir, ANIM_SUB, fname))
        js, binc = cache[fname]
        # los GLB de KayKit tienen los mismos nodos pero en distinto orden: los canales se reasignan por nombre
        src_names = [n.get("name") for n in js["nodes"]]
        if sorted(src_names) != sorted(names) or len(set(names)) != len(names):
            sys.exit("%s no tiene los mismos nodos que Rig_Medium_General.glb" % fname)
        remap = {i: names.index(nm) for i, nm in enumerate(src_names)}
        src = next((a for a in js["animations"] if a.get("name") == anim_name), None)
        if src is None:
            sys.exit("falta la animación %s en %s" % (anim_name, fname))
        samplers = []
        for s in src["samplers"]:
            samplers.append({"input": b.copy_accessor(js, binc, s["input"]),
                             "output": b.copy_accessor(js, binc, s["output"]),
                             "interpolation": s.get("interpolation", "LINEAR")})
        channels = []
        for c in src["channels"]:
            c = json.loads(json.dumps(c))
            c["target"]["node"] = remap[c["target"]["node"]]
            channels.append(c)
        animations.append({"name": anim_name, "samplers": samplers, "channels": channels})
    out = {
        "asset": {"version": "2.0", "generator": "BurgerChef3D tools/gen_characters.py (KayKit Character Animations 1.1, CC0)"},
        "scene": 0, "scenes": [base_js["scenes"][base_js.get("scene", 0)]],
        "nodes": nodes, "meshes": meshes, "skins": [skin], "animations": animations,
        "accessors": b.accessors, "bufferViews": b.views, "buffers": [{"byteLength": len(b.blob)}],
    }
    write_glb(os.path.join(DEST, ANIM_OUT), out, bytes(b.blob))


def check():
    errors = []
    for f in list(BODIES) + [ANIM_OUT, "LICENSE.txt"]:
        if not os.path.exists(os.path.join(DEST, f)):
            errors.append("falta assets/characters/%s" % f)
    if not errors:
        js, _ = read_glb(os.path.join(DEST, ANIM_OUT))
        have = {a["name"] for a in js.get("animations", [])}
        for a in ANIMS:
            if a not in have:
                errors.append("customer_anims.glb no tiene la animación %s" % a)
        lib = open(os.path.join(ROOT, "scripts", "customers", "character_lib.gd"), encoding="utf8").read()
        for f in BODIES:
            if '"%s"' % f not in lib:
                errors.append("character_lib.gd no usa %s" % f)
        for a in ANIMS:
            if '"%s"' % a not in lib:
                errors.append("character_lib.gd no usa la animación %s" % a)
        for f in os.listdir(DEST):
            if f not in BODIES and f not in (ANIM_OUT, "LICENSE.txt") and not f.endswith(".import"):
                errors.append("archivo sobrante en assets/characters: %s" % f)
    total = sum(os.path.getsize(os.path.join(DEST, f)) for f in os.listdir(DEST)) if os.path.isdir(DEST) else 0
    print("personajes: %d cuerpos + animaciones, %.2f MB" % (len(BODIES), total / 1048576))
    for e in errors:
        print("ERROR:", e)
    print("%d errores" % len(errors))
    return 1 if errors else 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--anims", help="carpeta KayKit_Character_Animations_1.1")
    ap.add_argument("--skeletons", help="carpeta KayKit_Skeletons_1.1_FREE")
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()
    if args.check:
        sys.exit(check())
    if not (args.anims and args.skeletons):
        sys.exit(__doc__)
    os.makedirs(DEST, exist_ok=True)
    packs = {"anims": args.anims, "skeletons": args.skeletons}
    for out, (pack, rel) in BODIES.items():
        shutil.copy2(os.path.join(packs[pack], rel), os.path.join(DEST, out))
    shutil.copy2(os.path.join(args.anims, "License.txt"), os.path.join(DEST, "LICENSE.txt"))
    build_anims(args.anims)
    for f in sorted(os.listdir(DEST)):
        print("%-28s %5d KB" % (f, os.path.getsize(os.path.join(DEST, f)) // 1024))


if __name__ == "__main__":
    main()
