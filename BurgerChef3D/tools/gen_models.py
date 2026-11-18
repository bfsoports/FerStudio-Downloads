#!/usr/bin/env python3
"""Copia al proyecto SOLO los modelos 3D reales que usa el juego y genera scripts/core/model_table.gd.

Packs:
  - KayKit Restaurant Bits 1.0 FREE  (CC0; carpeta Assets/gltf/*.gltf + .bin + restaurantbits_texture.png)
  - Kenney Food Kit                  (CC0; carpeta "Models/GLB format"/*.glb + Textures/colormap.png)
  - custom: modelos propios del usuario (generados con Tripo). No se copian desde aquí: los escribe ya optimizados
    tools/optimize_models.py en assets/models/custom/ (ver ese script y docs/licenses.md).

Uso:
  python3 tools/gen_models.py --kaykit <ruta>/KayKit_Restaurant_Bits_1.0_FREE --kenney <ruta>/kenney_food-kit
      -> copia los modelos del SPEC a assets/models/ y regenera la tabla
  python3 tools/gen_models.py
      -> solo regenera la tabla a partir de lo que ya hay en assets/models/

Cada entrada de la tabla es: clave -> [archivo, escala uniforme, desplazamiento X, Y, Z, tamaño final X, Y, Z en metros].
El desplazamiento se aplica en unidades del modelo (antes de escalar) para alinear la base con y=0 y, según el
modo de alineación, centrar el modelo en X/Z:
  c = centrar en X/Z y apoyar la base en y=0      b = solo apoyar la base en y=0 (conserva X/Z originales)
  n = sin desplazamiento
"""
import argparse
import json
import os
import shutil
import struct
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEST = os.path.join(ROOT, "assets", "models")
TABLE = os.path.join(ROOT, "scripts", "core", "model_table.gd")

# (clave, pack, archivo, escala, alineación)
SPEC = [
    # --- comida: capas de hamburguesa y ritmos de cocción
    ("bun_bottom", "kaykit", "food_ingredient_bun_bottom.gltf", 0.62, "c"),
    ("bun_top", "kaykit", "food_ingredient_bun_top.gltf", 0.62, "c"),
    ("patty_raw", "kaykit", "food_ingredient_burger_uncooked.gltf", 0.62, "c"),
    ("patty_done", "kaykit", "food_ingredient_burger_cooked.gltf", 0.62, "c"),
    ("patty_burnt", "kaykit", "food_ingredient_burger_trash.gltf", 0.62, "c"),
    ("veggie_raw", "kaykit", "food_ingredient_vegetableburger_uncooked.gltf", 0.6, "c"),
    ("veggie_done", "kaykit", "food_ingredient_vegetableburger_cooked.gltf", 0.6, "c"),
    ("cheese", "kaykit", "food_ingredient_cheese_slice.gltf", 0.6, "c"),
    ("lettuce", "kaykit", "food_ingredient_lettuce_slice.gltf", 0.62, "c"),
    ("tomato", "kaykit", "food_ingredient_tomato_slice.gltf", 0.62, "c"),
    ("onion", "kaykit", "food_ingredient_onion_rings.gltf", 0.6, "c"),
    ("bacon_raw", "kenney", "bacon-raw.glb", 0.9, "c"),
    ("bacon_done", "kenney", "bacon.glb", 0.9, "c"),
    ("fries_raw", "kaykit", "food_ingredient_potato_chopped.gltf", 0.32, "c"),
    ("fries_done", "kenney", "fries.glb", 0.85, "c"),
    ("drink", "kenney", "soda.glb", 0.7, "c"),
    # --- modelos propios del usuario (Tripo), normalizados a 1 m por su lado mayor y escalados a su tamaño real
    ("fryer", "custom", "fryer.glb", 0.75, "c"),
    ("dispenser", "custom", "drink_dispenser.glb", 0.7, "c"),
    ("lamp", "custom", "pendant_lamp.glb", 0.62, "c"),
    ("plant", "custom", "potted_plant.glb", 1.1, "c"),
    ("bell", "custom", "service_bell.glb", 0.28, "c"),
    ("trash", "custom", "trash_can.glb", 0.95, "c"),
    ("tray", "custom", "serving_tray.glb", 1.0, "c"),
    # --- cocina y sala
    ("counter_a", "kaykit", "kitchencounter_straight_A.gltf", 1.0, "b"),
    ("counter_b", "kaykit", "kitchencounter_straight_B.gltf", 1.0, "b"),
    ("sink", "kaykit", "kitchencounter_sink.gltf", 1.0, "b"),
    ("stove", "kaykit", "stove_multi.gltf", 1.0, "b"),
    ("hood", "kaykit", "extractorhood.gltf", 1.0, "n"),
    ("crate_buns", "kaykit", "crate_buns.gltf", 0.5, "c"),
    ("crate_lettuce", "kaykit", "crate_lettuce.gltf", 0.5, "c"),
    ("crate_tomatoes", "kaykit", "crate_tomatoes.gltf", 0.5, "c"),
    ("crate_onions", "kaykit", "crate_onions.gltf", 0.5, "c"),
    ("crate_potatoes", "kaykit", "crate_potatoes.gltf", 0.5, "c"),
    ("table", "kaykit", "table_round_A_small.gltf", 1.0, "c"),
    ("chair_a", "kaykit", "chair_A.gltf", 1.0, "c"),
    ("chair_b", "kaykit", "chair_B.gltf", 1.0, "c"),
    ("board", "kaykit", "cuttingboard.gltf", 1.0, "c"),
]

KAYKIT_SUB = os.path.join("Assets", "gltf")
KENNEY_SUB = os.path.join("Models", "GLB format")
KAYKIT_TEX = "restaurantbits_texture.png"
KENNEY_TEX = os.path.join("Textures", "colormap.png")


def load_gltf(path):
    if path.endswith(".glb"):
        with open(path, "rb") as f:
            data = f.read()
        length = struct.unpack("<I", data[8:12])[0]
        off = 12
        while off < length:
            clen, ctype = struct.unpack("<II", data[off:off + 8])
            if ctype == 0x4E4F534A:
                return json.loads(data[off + 8:off + 8 + clen].decode("utf8"))
            off += 8 + clen
        raise ValueError("GLB sin chunk JSON: " + path)
    with open(path, encoding="utf8") as f:
        return json.load(f)


def node_matrix(n):
    if "matrix" in n:
        m = n["matrix"]
        return [[m[c * 4 + r] for c in range(4)] for r in range(4)]
    t = n.get("translation", [0, 0, 0])
    q = n.get("rotation", [0, 0, 0, 1])
    s = n.get("scale", [1, 1, 1])
    x, y, z, w = q
    r = [[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
         [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
         [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]]
    return [[r[0][0] * s[0], r[0][1] * s[1], r[0][2] * s[2], t[0]],
            [r[1][0] * s[0], r[1][1] * s[1], r[1][2] * s[2], t[1]],
            [r[2][0] * s[0], r[2][1] * s[1], r[2][2] * s[2], t[2]],
            [0, 0, 0, 1]]


def mat_mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(4)) for j in range(4)] for i in range(4)]


def aabb(js):
    """Caja envolvente del modelo (mín, máx) a partir de los límites de los accesores POSITION y las transformaciones."""
    mn = [1e9] * 3
    mx = [-1e9] * 3

    def walk(idx, parent):
        n = js["nodes"][idx]
        m = mat_mul(parent, node_matrix(n))
        if "mesh" in n:
            for prim in js["meshes"][n["mesh"]]["primitives"]:
                acc = js["accessors"][prim["attributes"]["POSITION"]]
                for cx in (acc["min"][0], acc["max"][0]):
                    for cy in (acc["min"][1], acc["max"][1]):
                        for cz in (acc["min"][2], acc["max"][2]):
                            p = [m[i][0] * cx + m[i][1] * cy + m[i][2] * cz + m[i][3] for i in range(3)]
                            for i in range(3):
                                mn[i] = min(mn[i], p[i])
                                mx[i] = max(mx[i], p[i])
        for c in n.get("children", []):
            walk(c, m)

    ident = [[1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]]
    scene = js["scenes"][js.get("scene", 0)]
    for r in scene["nodes"]:
        walk(r, ident)
    return mn, mx


def copy_sources(kaykit_dir, kenney_dir):
    os.makedirs(os.path.join(DEST, "kaykit"), exist_ok=True)
    os.makedirs(os.path.join(DEST, "kenney", "Textures"), exist_ok=True)
    for key, pack, fname, _s, _a in SPEC:
        if pack == "custom":
            continue
        if pack == "kaykit":
            src = os.path.join(kaykit_dir, KAYKIT_SUB, fname)
            shutil.copy2(src, os.path.join(DEST, "kaykit", fname))
            js = load_gltf(src)
            for b in js.get("buffers", []):
                if "uri" in b and not b["uri"].startswith("data:"):
                    shutil.copy2(os.path.join(kaykit_dir, KAYKIT_SUB, b["uri"]), os.path.join(DEST, "kaykit", b["uri"]))
        else:
            shutil.copy2(os.path.join(kenney_dir, KENNEY_SUB, fname), os.path.join(DEST, "kenney", fname))
    shutil.copy2(os.path.join(kaykit_dir, KAYKIT_SUB, KAYKIT_TEX), os.path.join(DEST, "kaykit", KAYKIT_TEX))
    shutil.copy2(os.path.join(kenney_dir, KENNEY_SUB, KENNEY_TEX), os.path.join(DEST, "kenney", KENNEY_TEX))
    for pack, d in (("kaykit", kaykit_dir), ("kenney", kenney_dir)):
        lic = os.path.join(d, "License.txt")
        if os.path.exists(lic):
            shutil.copy2(lic, os.path.join(DEST, pack, "LICENSE.txt"))


def fmt(v):
    s = ("%.4f" % v).rstrip("0").rstrip(".")
    return "0.0" if s in ("", "-0") else (s if "." in s else s + ".0")


def build_table():
    lines = []
    for key, pack, fname, scale, align in SPEC:
        path = os.path.join(DEST, pack, fname)
        if not os.path.exists(path):
            sys.exit("Falta el modelo %s (ejecuta con --kaykit y --kenney, o tools/optimize_models.py para custom/)" % path)
        mn, mx = aabb(load_gltf(path))
        size = [mx[i] - mn[i] for i in range(3)]
        if align == "c":
            off = [-(mn[0] + mx[0]) * 0.5, -mn[1], -(mn[2] + mx[2]) * 0.5]
        elif align == "b":
            off = [0.0, -mn[1], 0.0]
        else:
            off = [0.0, 0.0, 0.0]
        final = [size[i] * scale for i in range(3)]
        lines.append('\t"%s": ["%s/%s", %s, %s, %s, %s, %s, %s, %s],' % (
            key, pack, fname, fmt(scale), fmt(off[0]), fmt(off[1]), fmt(off[2]), fmt(final[0]), fmt(final[1]), fmt(final[2])))
    head = (
        "class_name ModelTable\n"
        "extends RefCounted\n"
        "## GENERADO por tools/gen_models.py a partir de assets/models/. No editar a mano.\n"
        "## clave -> [archivo relativo a assets/models/, escala uniforme, desplazamiento X, Y, Z (unidades del modelo), tamaño final X, Y, Z (m)]\n\n"
        "const MODELS: Dictionary = {\n")
    with open(TABLE, "w", encoding="utf8", newline="\n") as f:
        f.write(head + "\n".join(lines) + "\n}\n")
    print("Tabla escrita: %d modelos -> %s" % (len(SPEC), os.path.relpath(TABLE, ROOT)))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--kaykit", help="carpeta KayKit_Restaurant_Bits_1.0_FREE descomprimida")
    ap.add_argument("--kenney", help="carpeta kenney_food-kit descomprimida")
    args = ap.parse_args()
    if args.kaykit and args.kenney:
        copy_sources(args.kaykit, args.kenney)
    build_table()


if __name__ == "__main__":
    main()
