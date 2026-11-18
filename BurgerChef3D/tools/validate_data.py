#!/usr/bin/env python3
"""Valida los datos de contenido (resources/data/*.json) sin necesitar Godot. Equivale a scripts/core/data_validator.gd.
Uso: python3 tools/validate_data.py   (devuelve código 1 si hay errores)"""
import json, os, sys
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
D = os.path.join(ROOT, "resources", "data")
def load(n): return json.load(open(os.path.join(D, n), encoding="utf-8"))
ings = {i["id"]: i for i in load("ingredients.json")}
recs = {r["id"]: r for r in load("recipes.json")}
levels = load("levels.json"); missions = load("missions.json"); upgrades = load("upgrades.json")
shop = load("shop.json"); layout = load("layout.json")
KNOWN = {"burgers_made","customers_served","orders_correct","coins_earned","no_burn_shifts","perfect_burgers","recipes_unlocked","upgrades_bought","levels_completed","best_streak","patties_cooked","combos_served","stars_total","items_bought","player_level","shifts_played","three_star_levels","trays_washed"}
WIN = {"orders","income","satisfaction","no_burnt","customers","recipe"}
err = []
def hexok(c): return isinstance(c, str) and len(c) == 7 and c[0] == "#" and all(x in "0123456789abcdefABCDEF" for x in c[1:])
for i in ings.values():
    if not hexok(i["color"]): err.append(f"ingrediente {i['id']}: color")
    if i["cook"] and (i["cook"]["cook_time"] <= 0 or i["cook"]["burn_time"] <= 0): err.append(f"ingrediente {i['id']}: cocción")
    for lang in ("es", "en"):
        if not i["name"].get(lang): err.append(f"ingrediente {i['id']}: nombre {lang}")
for r in recs.values():
    if r["price"] <= 0: err.append(f"receta {r['id']}: precio")
    if not 1 <= r["unlock_level"] <= len(levels): err.append(f"receta {r['id']}: unlock_level")
    for lang in ("es", "en"):
        if not r["name"].get(lang): err.append(f"receta {r['id']}: nombre {lang}")
    if r["kind"] == "burger":
        l = r["ingredients"]
        if l[0] != "bun_bottom" or l[-1] != "bun_top" or len(l) < 3: err.append(f"receta {r['id']}: panes")
        for x in l + r["extras"]:
            if x not in ings or not ings[x]["stackable"]: err.append(f"receta {r['id']}: ingrediente {x}")
        if r["order"] not in ("strict", "flexible"): err.append(f"receta {r['id']}: order")
    elif r["kind"] == "combo":
        for c in r["components"]:
            if c["type"] == "recipe" and (c["id"] not in recs or recs[c["id"]]["kind"] != "burger"): err.append(f"receta {r['id']}: componente {c['id']}")
            elif c["type"] == "item" and c["id"] not in ings: err.append(f"receta {r['id']}: componente {c['id']}")
    else: err.append(f"receta {r['id']}: kind")
if len(levels) < 30: err.append(f"faltan niveles: {len(levels)}")
prev_dur = 0
for n, lv in enumerate(levels, 1):
    if lv["id"] != n: err.append(f"nivel {n}: id")
    if lv["duration"] <= 0 or lv["spawn_interval"] <= 0 or lv["patience"] <= 0: err.append(f"nivel {n}: tiempos")
    for rid in lv["recipes"]:
        if rid not in recs: err.append(f"nivel {n}: receta {rid}")
        elif recs[rid]["unlock_level"] > n: err.append(f"nivel {n}: {rid} aún bloqueada")
    for k in lv["win"]:
        if k not in WIN: err.append(f"nivel {n}: condición {k}")
    cap = (lv["duration"] / lv["spawn_interval"] + 1) * 0.8
    for k in ("orders", "customers"):
        if lv["win"].get(k, 0) > cap: err.append(f"nivel {n}: {k} imposible ({lv['win'][k]} > {cap:.1f})")
    if "recipe" in lv["win"]:
        if lv["win"]["recipe"]["id"] not in lv["recipes"]: err.append(f"nivel {n}: receta objetivo")
        if lv["win"]["recipe"]["count"] > cap: err.append(f"nivel {n}: recetas imposibles")
    si = lv["star_income"]
    if len(si) != 2 or si[0] >= si[1]: err.append(f"nivel {n}: star_income")
    if "income" in lv["win"] and lv["win"]["income"] > si[0]: err.append(f"nivel {n}: income > estrella 1")
    if lv["lose"]["max_failed"] < 1: err.append(f"nivel {n}: max_failed")
    if lv["max_active"] < 1 or lv["max_active"] > 3: err.append(f"nivel {n}: max_active")
    for lang in ("es", "en"):
        if not lv["name"].get(lang): err.append(f"nivel {n}: nombre {lang}")
seen = set()
for m in missions:
    if m["id"] in seen: err.append(f"misión repetida {m['id']}")
    seen.add(m["id"])
    if m["stat"] not in KNOWN: err.append(f"misión {m['id']}: stat")
    if m["target"] <= 0 or m["kind"] not in ("mission", "challenge", "achievement"): err.append(f"misión {m['id']}")
counts = {k: sum(1 for m in missions if m["kind"] == k) for k in ("mission", "challenge", "achievement")}
if counts["mission"] < 20 or counts["challenge"] < 10 or counts["achievement"] < 10: err.append(f"faltan misiones/desafíos/logros: {counts}")
stats = set()
for u in upgrades:
    if len(u["costs"]) != u["max_level"]: err.append(f"mejora {u['id']}: costs")
    if u["effect"]["stat"] in stats: err.append(f"mejora {u['id']}: efecto repetido")
    stats.add(u["effect"]["stat"])
cats = shop["categories"]; first = {}
for it in shop["items"]:
    if it["category"] not in cats: err.append(f"artículo {it['id']}: categoría")
    first.setdefault(it["category"], it["price"] == 0)
    for lang in ("es", "en"):
        if not it["name"].get(lang): err.append(f"artículo {it['id']}: nombre {lang}")
for c in cats:
    if not first.get(c): err.append(f"categoría {c}: el primero debe ser gratuito")
# contenido que depende de una mejora (recetas nuevas y catálogo de decoración)
upg = {u["id"]: u for u in upgrades}
for r in recs.values():
    ru = r.get("requires_upgrade")
    if ru is not None:
        if ru.get("id") not in upg or not 1 <= ru.get("level", 0) <= upg[ru["id"]]["max_level"]: err.append(f"receta {r['id']}: requires_upgrade inválido")
        for lv in levels:
            if r["id"] in lv["recipes"]: err.append(f"nivel {lv['id']}: {r['id']} depende de una mejora y no puede estar en la lista fija")
for it in shop["items"]:
    if "requires_upgrade" in it and it["requires_upgrade"] not in upg: err.append(f"artículo {it['id']}: requires_upgrade inválido")
for lv in levels:
    if not isinstance(lv.get("dirty_trays", False), bool): err.append(f"nivel {lv['id']}: dirty_trays debe ser booleano")
for b in layout["bins"]:
    if b["ingredient"] not in ings: err.append(f"layout: ingrediente {b['ingredient']}")
if len(layout["service_points"]) < 3: err.append("layout: puestos de servicio")
# recorrido por niveles: ¿hay comida suficiente en cada nivel?
print(f"ingredientes {len(ings)}, recetas {len(recs)}, niveles {len(levels)}, misiones {counts}, mejoras {len(upgrades)}, artículos {len(shop['items'])}")
for e in err: print("ERROR:", e)
print(f"{len(err)} errores")
sys.exit(1 if err else 0)
