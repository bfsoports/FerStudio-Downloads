#!/usr/bin/env python3
"""Descarga conjuntos PBR CC0 de Poly Haven y los prepara para móvil.

Uso: python3 fetch_polyhaven.py <dir_cache> <dir_salida>
Salida por conjunto: <nombre>_albedo.jpg, <nombre>_normal.png, <nombre>_orm.jpg
(ORM = oclusión R, rugosidad G, metal B, formato que usa ORMMaterial3D).
También escribe sources.json con URL y licencia de cada conjunto para
docs/ASSET_LICENSES.md. Todas las texturas de Poly Haven son CC0 1.0.
"""
import json, os, sys, urllib.request
from PIL import Image

UA = {"User-Agent": "game-asset-fetcher/1.0"}
# nombre interno -> (id en Poly Haven, lado final en px)
SETS = {
    # terreno
    "t_grass": ("leafy_grass", 1024), "t_grass_dry": ("sparse_grass", 512),
    "t_forest": ("forest_leaves_02", 1024), "t_dirt": ("brown_mud_leaves_01", 1024),
    "t_mud": ("brown_mud_02", 512), "t_gravel": ("gravel_floor_02", 512),
    "t_rock": ("rock_ground", 512), "t_soil": ("farm_soil", 512),
    "t_pebbles": ("ganges_river_pebbles", 512),
    # cortezas y roca
    "bark_oak": ("bark_brown_02", 512), "bark_pine": ("pine_bark", 512),
    "bark_willow": ("bark_willow", 512), "rock_cliff": ("rock_face_03", 512),
    "rock_mossy": ("mossy_rock", 512), "rock_boulder": ("rock_boulder_dry", 512),
    # arquitectura
    "plaster_white": ("plastered_wall_04", 512), "plaster_yellow": ("yellow_plaster", 512),
    "plaster_worn": ("worn_plaster_wall", 512), "plaster_blue": ("blue_plaster_weathered", 512),
    "brick_red": ("red_brick_03", 512), "brick_factory": ("factory_brick", 512),
    "stone_wall": ("rustic_stone_wall_02", 512),
    "wood_siding": ("weathered_brown_planks", 512), "wood_grey": ("wood_planks_grey", 512),
    "wood_green": ("green_rough_planks", 512), "wood_floor": ("wood_floor_worn", 512),
    "wood_raw": ("raw_plank_wall", 512), "wood_dark": ("dark_wooden_planks", 512),
    "roof_clay": ("clay_roof_tiles_02", 512), "roof_slate": ("grey_roof_tiles_02", 512),
    "metal_corrugated": ("corrugated_iron_02", 512), "metal_corr_rust": ("rusty_corrugated_iron", 512),
    "metal_rust": ("rusty_metal_02", 512), "metal_green": ("green_metal_rust", 512),
    "metal_shutter": ("painted_metal_shutter", 512), "metal_plate": ("metal_plate", 512),
    "metal_blue": ("blue_metal_plate", 512),
    "concrete_wall": ("concrete_wall_008", 512), "concrete_floor": ("concrete_floor_worn_001", 512),
    "concrete_block": ("concrete_block_wall_02", 512), "concrete_painted": ("painted_concrete", 512),
    "asphalt": ("asphalt_02", 512), "cobble": ("cobblestone_floor_08", 512),
    "pavement": ("concrete_pavement", 512),
    "tiles_floor": ("floor_tiles_06", 512), "tiles_white": ("long_white_tiles", 512),
    "fabric_denim": ("denim_fabric", 512), "fabric_pattern": ("fabric_pattern_07", 512),
    "leather_brown": ("brown_leather", 512), "wallpaper_old": ("decrepit_wallpaper", 512),
    "carpet_dirty": ("dirty_carpet", 512), "thatch": ("reed_roof_03", 512),
}

def fetch(url, path):
    if os.path.exists(path) and os.path.getsize(path) > 0:
        return
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=120) as r, open(path, "wb") as f:
        f.write(r.read())

def pick(files, keys):
    for k in keys:
        if k in files and "1k" in files[k]:
            fm = files[k]["1k"]
            for ext in ("jpg", "png"):
                if ext in fm:
                    return fm[ext]["url"], ext
    return None, None

def main(cache, out):
    os.makedirs(cache, exist_ok=True); os.makedirs(out, exist_ok=True)
    sources = {}
    for name, (pid, size) in SETS.items():
        meta_path = os.path.join(cache, pid + ".json")
        fetch("https://api.polyhaven.com/files/" + pid, meta_path)
        files = json.load(open(meta_path))
        maps = {}
        for label, keys in (("albedo", ["Diffuse", "diff", "Color", "col_1"]), ("normal", ["nor_gl", "Normal"]),
                            ("arm", ["arm"]), ("rough", ["Rough", "rough"]), ("ao", ["AO", "ao"])):
            url, ext = pick(files, keys)
            if url:
                p = os.path.join(cache, f"{pid}_{label}.{ext}")
                fetch(url, p); maps[label] = p
        if "albedo" not in maps:
            print("SIN ALBEDO", name, pid, list(files.keys())); continue
        Image.open(maps["albedo"]).convert("RGB").resize((size, size), Image.LANCZOS).save(
            os.path.join(out, name + "_albedo.jpg"), quality=90)
        if "normal" in maps:
            Image.open(maps["normal"]).convert("RGB").resize((size, size), Image.LANCZOS).save(
                os.path.join(out, name + "_normal.png"))
        if "arm" in maps:
            orm = Image.open(maps["arm"]).convert("RGB")
        else:
            w = Image.open(maps["albedo"]).size
            r = Image.open(maps["rough"]).convert("L") if "rough" in maps else Image.new("L", w, 200)
            a = Image.open(maps["ao"]).convert("L") if "ao" in maps else Image.new("L", w, 255)
            orm = Image.merge("RGB", (a.resize(w), r.resize(w), Image.new("L", w, 0)))
        orm.resize((size, size), Image.LANCZOS).save(os.path.join(out, name + "_orm.jpg"), quality=88)
        sources[name] = {"source_id": pid, "url": "https://polyhaven.com/a/" + pid,
                         "license": "CC0 1.0", "author": "Poly Haven", "size": size}
        print("ok", name)
    json.dump(sources, open(os.path.join(out, "sources.json"), "w"), indent=1, sort_keys=True)

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
