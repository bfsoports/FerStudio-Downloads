#!/usr/bin/env python3
"""Comprueba, sin abrir Godot, que los modelos 3D reales y su uso son coherentes.

  1. La tabla scripts/core/model_table.gd coincide con los archivos de assets/models/ (existen, tamaños y desplazamientos al día).
  2. Cada modelo tiene sus .bin / texturas al lado y no sobran archivos en assets/models/.
  3. Todos los modelos que citan food_models.gd y restaurant.gd existen en la tabla, y todos los de la tabla se usan.
  4. Todos los ingredientes de resources/data/ingredients.json tienen modelo 3D real.
  5. Presupuesto para Android: peso total de assets/models y triángulos por modelo.
  6. Distribución: las huellas de muebles y estaciones caben en la sala y no se solapan (resources/data/layout.json).

Uso:  python3 tools/check_models.py        (sale con código 1 si hay errores)
"""
import glob
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import gen_models as gm  # noqa: E402

MODELS = os.path.join(ROOT, "assets", "models")
MAX_TOTAL_BYTES = 4 * 1024 * 1024
MAX_TRIS = 3000          # KayKit y Kenney
# modelos propios (custom/): ya simplificados por tools/optimize_models.py, que se para antes del objetivo si seguir
# deformaría la textura; los dos equipos grandes llevan más detalle
MAX_TRIS_CUSTOM = {"fryer": 18500, "dispenser": 14500}
MAX_TRIS_CUSTOM_DEFAULT = 7500
MIN_AISLE = 1.2   # ancho mínimo cómodo de un pasillo (la cápsula del jugador mide 0,6 m)
errors, warnings = [], []


def err(msg):
    errors.append(msg)


def parse_table():
    txt = open(os.path.join(ROOT, "scripts", "core", "model_table.gd"), encoding="utf8").read()
    table = {}
    for m in re.finditer(r'"(\w+)": \["([^"]+)", ([^\]]+)\]', txt):
        nums = [float(v) for v in m.group(3).split(",")]
        table[m.group(1)] = {"file": m.group(2), "s": nums[0], "off": nums[1:4], "size": nums[4:7]}
    return table


def tri_count(js):
    n = 0
    for mesh in js["meshes"]:
        for p in mesh["primitives"]:
            n += js["accessors"][p["indices"]]["count"] // 3 if "indices" in p else js["accessors"][p["attributes"]["POSITION"]]["count"] // 3
    return n


def check_assets(table):
    spec = {k: (pack, f, s, a) for k, pack, f, s, a in gm.SPEC}
    used_files = set()
    for key, e in table.items():
        if key not in spec:
            err("la tabla tiene '%s' que no está en gen_models.SPEC" % key)
            continue
        pack, fname, scale, align = spec[key]
        path = os.path.join(MODELS, e["file"])
        if not os.path.exists(path):
            err("falta el modelo %s" % e["file"])
            continue
        used_files.add(os.path.normpath(path))
        js = gm.load_gltf(path)
        base = os.path.dirname(path)
        for b in js.get("buffers", []):
            if "uri" in b and not b["uri"].startswith("data:"):
                used_files.add(os.path.normpath(os.path.join(base, b["uri"])))
                if not os.path.exists(os.path.join(base, b["uri"])):
                    err("%s: falta el buffer %s" % (e["file"], b["uri"]))
        for im in js.get("images", []):
            if "uri" in im and not im["uri"].startswith("data:"):
                used_files.add(os.path.normpath(os.path.join(base, im["uri"])))
                if not os.path.exists(os.path.join(base, im["uri"])):
                    err("%s: falta la textura %s" % (e["file"], im["uri"]))
        mn, mx = gm.aabb(js)
        size = [(mx[i] - mn[i]) * scale for i in range(3)]
        off = {"c": [-(mn[0] + mx[0]) / 2, -mn[1], -(mn[2] + mx[2]) / 2], "b": [0.0, -mn[1], 0.0], "n": [0.0, 0.0, 0.0]}[align]
        if abs(e["s"] - scale) > 1e-6 or any(abs(size[i] - e["size"][i]) > 2e-3 for i in range(3)) or any(abs(off[i] - e["off"][i]) > 2e-3 for i in range(3)):
            err("%s: la tabla está desactualizada, ejecuta tools/gen_models.py" % key)
        t = tri_count(js)
        limit = MAX_TRIS_CUSTOM.get(key, MAX_TRIS_CUSTOM_DEFAULT) if pack == "custom" else MAX_TRIS
        if t > limit:
            err("%s tiene %d triángulos (máximo %d)" % (key, t, limit))
        if pack == "custom" and (len(js.get("images", [])) != 1 or "uri" in js["images"][0]):
            err("%s: se esperaba una única textura incrustada en el GLB" % key)
    total = 0
    for f in glob.glob(os.path.join(MODELS, "**", "*"), recursive=True):
        if os.path.isfile(f):
            total += os.path.getsize(f)
            n = os.path.normpath(f)
            if n not in used_files and os.path.basename(f) not in ("LICENSE.txt", "ORIGEN.txt") and not f.endswith(".import"):
                err("archivo sobrante en assets/models: %s" % os.path.relpath(f, ROOT))
    if total > MAX_TOTAL_BYTES:
        err("assets/models pesa %.1f MB (máximo %.1f MB)" % (total / 1048576, MAX_TOTAL_BYTES / 1048576))
    for pack in ("kaykit", "kenney"):
        if not os.path.exists(os.path.join(MODELS, pack, "LICENSE.txt")):
            err("falta la licencia de %s" % pack)
    if not os.path.exists(os.path.join(MODELS, "custom", "ORIGEN.txt")):
        err("falta assets/models/custom/ORIGEN.txt (origen y licencia de los modelos propios)")
    return total


def read(rel):
    return open(os.path.join(ROOT, rel), encoding="utf8").read()


def check_usage(table):
    food, rest = read("scripts/ingredients/food_models.gd"), read("scripts/restaurant/restaurant.gd")
    refs = set()
    for src in (food, rest):
        refs |= set(re.findall(r'"(\w+)"', src))
    for key in table:
        if key not in refs:
            err("el modelo '%s' está en la tabla pero ningún script lo usa" % key)
    # valores de COOK_MODELS, LAYER_MODELS y CRATE_MODELS, y llamadas a ModelLib.spawn con literales
    for m in re.finditer(r'"(?:raw|done|burnt)": "(\w+)"|"\w+": "(\w+)"', food + rest):
        v = m.group(1) or m.group(2)
        if v not in table and v in ("crate_buns", "crate_lettuce", "crate_tomatoes", "crate_onions", "crate_potatoes"):
            err("modelo citado y ausente de la tabla: %s" % v)
    for m in re.finditer(r'ModelLib\.(?:spawn|size_of)\(\s*"(\w+)"', food + rest):
        if m.group(1) not in table:
            err("ModelLib cita el modelo inexistente '%s'" % m.group(1))
    for m in re.finditer(r'"(\w+)" if [^"]+ else "(\w+)"', rest):
        for k in m.groups():
            if k.startswith(("counter_", "fridge_", "chair_")) and k not in table:
                err("modelo citado y ausente de la tabla: %s" % k)
    for m in re.finditer(r'"(raw|done|burnt)": "(\w+)"', food):
        if m.group(2) not in table:
            err("COOK_MODELS cita el modelo inexistente '%s'" % m.group(2))
    for m in re.finditer(r'"(\w+)": "(\w+)"', re.search(r"const LAYER_MODELS.*?\n}", food, re.S).group(0)):
        if m.group(2) not in table:
            err("LAYER_MODELS cita el modelo inexistente '%s'" % m.group(2))
    for m in re.finditer(r'"(\w+)": "(\w+)"', re.search(r"const CRATE_MODELS.*?\}", rest, re.S).group(0)):
        if m.group(2) not in table:
            err("CRATE_MODELS cita el modelo inexistente '%s'" % m.group(2))
    # ingredientes con modelo
    ings = json.load(open(os.path.join(ROOT, "resources", "data", "ingredients.json"), encoding="utf8"))
    cook = set(re.findall(r'^\t"(\w+)": \{"raw"', food, re.M))
    layer = set(re.findall(r'"(\w+)": "\w+"', re.search(r"const LAYER_MODELS.*?\n}", food, re.S).group(0)))
    for i in ings:
        if i["id"] not in cook | layer | {"drink"}:
            err("el ingrediente '%s' no tiene modelo 3D real" % i["id"])


def overlap(a, b):
    ox = min(a[0] + a[2] / 2, b[0] + b[2] / 2) - max(a[0] - a[2] / 2, b[0] - b[2] / 2)
    oz = min(a[1] + a[3] / 2, b[1] + b[3] / 2) - max(a[1] - a[3] / 2, b[1] - b[3] / 2)
    return ox, oz


def check_layout():
    lay = json.load(open(os.path.join(ROOT, "resources", "data", "layout.json"), encoding="utf8"))
    room = lay["room"]
    boxes = {}
    sc = lay["service_counter"]
    boxes["service_counter"] = (sc["x"], sc["z"], sc["w"], sc["d"])
    for i, g in enumerate(lay["gates"]):
        boxes["gate%d" % i] = (g["x"], g["z"], g["w"], g["d"])
    for k in ("grill", "stage_a", "island", "fryer", "stage_b"):
        e = lay[k]
        boxes[k] = (e["x"], e["z"], e["w"], e["d"])
    south = [b for b in lay["bins"] if b["group"] == "shelf" and abs(b["x"]) <= 7.0]
    if south:
        xs = [b["x"] for b in south]
        boxes["south_counter"] = ((min(xs) + max(xs)) / 2, south[0]["z"], max(xs) - min(xs) + 1.2, 1.0)
    for b in lay["bins"]:
        if abs(b["x"]) > 7.0:
            # caja, tabla o dispensador sobre el mostrador bajo de la pared (1,0 m de fondo, 1,2 m por puesto)
            boxes["bin_" + b["ingredient"]] = (b["x"], b["z"], 1.0, 1.2)
    boxes["trash"] = (lay["trash"]["x"], lay["trash"]["z"], 0.8, 0.8)
    boxes["sink"] = (lay["sink"]["x"], lay["sink"]["z"], 1.0, 1.1)
    for name, (x, z, w, d) in boxes.items():
        if x - w / 2 < room["x_min"] - 1e-6 or x + w / 2 > room["x_max"] + 1e-6 or z - d / 2 < room["z_min"] - 1e-6 or z + d / 2 > room["z_max"] + 1e-6:
            err("la huella de %s se sale de la sala" % name)
    names = list(boxes)
    for i in range(len(names)):
        for j in range(i + 1, len(names)):
            ox, oz = overlap(boxes[names[i]], boxes[names[j]])
            if ox > 0.02 and oz > 0.02:
                err("se solapan %s y %s (%.2f x %.2f m)" % (names[i], names[j], ox, oz))
    # pasillos mínimos para el jugador (cápsula de unos 0,6 m)
    gaps = {}
    isl, fry, grill = boxes["island"], boxes["fryer"], boxes["grill"]
    gaps["isla - freidora"] = (fry[0] - fry[2] / 2) - (isl[0] + isl[2] / 2)
    gaps["fogón - mostrador oeste"] = (grill[0] - grill[2] / 2) - max(b["x"] + 0.5 for b in lay["bins"] if b["x"] < -7)
    gaps["fogón delantero - cajas sur"] = (boxes["south_counter"][1] - 0.5) - (grill[1] + grill[3] / 2 + 0.26)
    east_front = min(b["x"] - 0.5 for b in lay["bins"] if b["x"] > 7)
    gaps["puesto B - muebles este"] = east_front - (boxes["stage_b"][0] + boxes["stage_b"][2] / 2)
    gaps["pasillo norte (mostrador - fogones)"] = (grill[1] - grill[3] / 2) - (sc["z"] + sc["d"] / 2)
    for k, v in gaps.items():
        if v < MIN_AISLE:
            err("pasillo demasiado estrecho (%s): %.2f m, mínimo %.1f m" % (k, v, MIN_AISLE))
    return gaps


def main():
    table = parse_table()
    total = check_assets(table)
    check_usage(table)
    gaps = check_layout()
    print("modelos en la tabla: %d, peso de assets/models: %.2f MB" % (len(table), total / 1048576))
    print("pasillos (m):", {k: round(v, 2) for k, v in gaps.items()})
    for e in errors:
        print("ERROR:", e)
    print("%d errores" % len(errors))
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
