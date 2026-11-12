#!/usr/bin/env python3
"""make_data.py — autoría de los datos de juego de Valdebruma (IDs estables).

Uso: python3 tools/data/make_data.py
Escribe en data/: items.json, recipes.json, loot_tables.json, harvest.json, structures.json,
creatures.json, effects.json, documents.json, progression.json.
Todos los textos llevan español (es) e inglés (en). Sin recetas reales de objetos peligrosos.
"""
import json, os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ITEMS = {}


def T(es, en):
    return {"es": es, "en": en}


def item(i, es, en, des, den, cat, w, stack=1, rarity=0, **kw):
    ITEMS[i] = {"id": i, "name": T(es, en), "desc": T(des, den), "cat": cat, "weight": w, "stack": stack, "rarity": rarity, **kw}


# ---- alimento y bebida: use = efectos inmediatos; "gives" devuelve un objeto (envase) -------------
item("lata_legumbres", "Lata de legumbres", "Canned beans", "Conserva de la cooperativa. Saciante y fría.", "Co-op preserve. Filling, eaten cold.", "food", 0.42, 6, 0, use={"food": 34, "water": 4})
item("lata_melocoton", "Melocotón en almíbar", "Peaches in syrup", "Dulce y con algo de líquido.", "Sweet, with a little liquid.", "food", 0.4, 6, 0, use={"food": 22, "water": 12})
item("conserva_pescado", "Conserva de pescado", "Tinned fish", "Lata plana de Conservas Sotoalto.", "A flat tin from Conservas Sotoalto.", "food", 0.15, 8, 0, use={"food": 20})
item("galletas", "Galletas saladas", "Crackers", "Secas. Dan sed.", "Dry. They make you thirsty.", "food", 0.2, 6, 0, use={"food": 16, "water": -5})
item("barrita", "Barrita de cereal", "Cereal bar", "Energía rápida para el camino.", "Quick energy for the road.", "food", 0.06, 10, 0, use={"food": 11, "stamina": 20})
item("bayas", "Bayas de zarza", "Bramble berries", "Recogidas en los lindes del bosque.", "Picked at the forest edge.", "food", 0.08, 12, 0, use={"food": 6, "water": 4})
item("setas", "Setas de robledal", "Oakwood mushrooms", "Crudas sientan regular. Mejor asadas.", "Unpleasant raw. Better roasted.", "food", 0.1, 10, 0, use={"food": 5, "effect": ["malestar", 90, 0.4]})
item("setas_asadas", "Setas asadas", "Roasted mushrooms", "Brocheta hecha a la lumbre.", "A skewer cooked over the fire.", "food", 0.1, 10, 0, use={"food": 15, "temp": 6})
item("manzana", "Manzana", "Apple", "Del huerto de Las Eras.", "From the Las Eras orchard.", "food", 0.15, 10, 0, use={"food": 9, "water": 6})
item("guiso", "Guiso de campo", "Field stew", "Caliente y contundente. Reconforta.", "Hot and hearty. Comforting.", "food", 0.45, 3, 1, use={"food": 46, "water": 10, "temp": 18, "effect": ["bien_alimentado", 600, 1.0]})
item("refresco", "Refresco Burbuja", "Burbuja soda", "Gaseosa local. Dulce.", "Local fizzy drink. Sweet.", "drink", 0.36, 6, 0, use={"water": 22, "food": 3, "stamina": 10})
item("botella_vacia", "Botella vacía", "Empty bottle", "Se puede llenar en pozos, bombas o en el río.", "Fill it at wells, pumps or the river.", "drink", 0.08, 5, 0, fill="agua_turbia")
item("agua_turbia", "Agua sin tratar", "Untreated water", "Quita la sed, pero puede sentar mal.", "Quenches thirst, but may upset you.", "drink", 0.58, 5, 0, use={"water": 30, "effect": ["malestar", 150, 0.5]}, gives="botella_vacia")
item("agua_potable", "Agua potable", "Clean water", "Hervida o tratada.", "Boiled or treated.", "drink", 0.58, 5, 0, use={"water": 38}, gives="botella_vacia")
item("infusion", "Infusión de hierbas", "Herbal infusion", "Caliente. Entona el cuerpo y calma el malestar.", "Hot. Warms you up and settles the stomach.", "drink", 0.3, 3, 1, use={"water": 26, "temp": 22, "cure": ["malestar"], "effect": ["abrigado", 240, 1.0]})
# ---- botiquín -------------------------------------------------------------------------------------
item("venda", "Venda", "Bandage", "Recupera algo de salud.", "Restores some health.", "medical", 0.05, 10, 0, use={"health": 14})
item("botiquin", "Botiquín", "First-aid kit", "Cura completa y descanso para el cuerpo.", "A thorough treatment.", "medical", 0.5, 2, 2, use={"health": 60, "cure": ["aturdido", "malestar"]})
item("pastillas", "Pastillas potabilizadoras", "Purification tablets", "Para tratar agua sin hervirla.", "Treats water without boiling.", "medical", 0.03, 10, 1)
item("unguento", "Ungüento de hierbas", "Herbal salve", "Alivia y recupera poco a poco.", "Soothes and heals over time.", "medical", 0.12, 5, 1, use={"health": 8, "effect": ["alivio", 180, 1.0]})
item("filtro", "Filtro de mascarilla", "Mask filter", "Recambio. Se gasta dentro de la bruma.", "Spare filter. Wears out inside the mist.", "medical", 0.1, 6, 1)
# ---- materiales --------------------------------------------------------------------------------------
item("palo", "Palos", "Sticks", "Ramas secas. Base de casi todo.", "Dry branches. The basis of nearly everything.", "material", 0.25, 20)
item("tablon", "Tablón", "Plank", "Madera aprovechable.", "Usable timber.", "material", 0.9, 10)
item("piedra", "Piedra", "Stone", "Canto manejable.", "A manageable rock.", "material", 0.6, 15)
item("fibra", "Fibra vegetal", "Plant fibre", "Juncos y tallos para trenzar.", "Rushes and stems for braiding.", "material", 0.05, 30)
item("cuerda", "Cuerda", "Rope", "Trenzada a mano.", "Hand braided.", "material", 0.2, 10)
item("tela", "Tela", "Cloth", "Retales limpios.", "Clean scraps.", "material", 0.1, 20)
item("chatarra", "Chatarra", "Scrap metal", "Chapa y piezas sueltas.", "Sheet metal and loose parts.", "material", 0.5, 15)
item("clavos", "Clavos", "Nails", "Una caja de clavos.", "A box of nails.", "material", 0.1, 20)
item("cinta", "Cinta americana", "Duct tape", "Arregla casi cualquier cosa.", "Fixes almost anything.", "material", 0.15, 5, 1)
item("lona", "Lona", "Tarp", "Impermeable y resistente.", "Waterproof and tough.", "material", 1.0, 3, 1)
item("hierbas", "Hierbas del valle", "Valley herbs", "Milenrama y otras plantas útiles.", "Yarrow and other useful plants.", "material", 0.03, 20)
item("pilas", "Pilas", "Batteries", "Alimentan la linterna.", "They power the flashlight.", "material", 0.06, 10, 1)
item("liquen", "Liquen brumal", "Mist lichen", "Brilla débilmente. El Instituto lo estudiaba.", "It glows faintly. The Institute studied it.", "material", 0.1, 10, 2)
# ---- herramientas y utilidad -----------------------------------------------------------------------------
item("hachuela", "Hachuela", "Hatchet", "Para leña. Acelera la recogida de madera.", "For firewood. Speeds up wood gathering.", "tool", 0.8, 1, 1, dur=120, tool="hachuela", equip={"slot": "mano"})
item("martillo", "Martillo", "Hammer", "Imprescindible para construir en firme.", "Essential for solid building.", "tool", 0.6, 1, 1, dur=160, tool="martillo", equip={"slot": "mano"})
item("palanca", "Palanca", "Crowbar", "Abre puertas y cajas atascadas.", "Opens stuck doors and crates.", "tool", 1.4, 1, 2, dur=60, tool="palanca", equip={"slot": "mano"})
item("linterna", "Linterna", "Flashlight", "Luz dirigida. Gasta pilas.", "A focused beam. Uses batteries.", "tool", 0.3, 1, 1, dur=100, equip={"slot": "mano", "light": "spot"}, fuel="pilas")
item("farol", "Farol", "Lantern", "Luz cálida alrededor. Ahuyenta la oscuridad.", "Warm light all around.", "tool", 0.7, 1, 1, dur=100, equip={"slot": "mano", "light": "omni"}, fuel="liquen")
item("espantador", "Espantador", "Rattle", "Latas y piedras. El estruendo aleja a las criaturas.", "Tins and stones. The racket drives creatures off.", "tool", 0.5, 1, 1, dur=12, use={"deter": 26}, equip={"slot": "mano"})
item("brujula", "Brújula", "Compass", "Mientras la lleves verás el rumbo en pantalla.", "Shows your heading while you carry it.", "tool", 0.08, 1, 1)
item("llave_estacion", "Tarjeta de la Estación", "Station keycard", "Abre las puertas de la Estación Liquen.", "Opens the doors of Lichen Station.", "key", 0.02, 1, 3)
item("llave_archivo", "Llave del archivo", "Archive key", "Del archivo de la Casa Consistorial.", "For the Town Hall archive.", "key", 0.03, 1, 2)
# ---- ropa y equipo -------------------------------------------------------------------------------------------
item("gorro_lana", "Gorro de lana", "Wool hat", "Abriga la cabeza.", "Keeps your head warm.", "clothing", 0.1, 1, 0, dur=200, equip={"slot": "cabeza", "warmth": 4})
item("chaqueta_campo", "Chaqueta de campo", "Field jacket", "Abrigo resistente.", "A sturdy coat.", "clothing", 0.9, 1, 1, dur=300, equip={"slot": "torso", "warmth": 9, "wet": 0.2})
item("impermeable", "Impermeable", "Raincoat", "Poca abriga, pero no cala.", "Not warm, but keeps you dry.", "clothing", 0.5, 1, 1, dur=200, equip={"slot": "torso", "warmth": 3, "wet": 0.85})
item("pantalon_monte", "Pantalón de monte", "Hiking trousers", "Tejido grueso.", "Thick fabric.", "clothing", 0.6, 1, 0, dur=300, equip={"slot": "piernas", "warmth": 5, "wet": 0.15})
item("botas_monte", "Botas de monte", "Hiking boots", "Menos cansancio al caminar.", "Walking tires you less.", "clothing", 1.1, 1, 1, dur=400, equip={"slot": "pies", "warmth": 3, "wet": 0.3, "stamina": 0.15})
item("mochila_pequena", "Mochila pequeña", "Small backpack", "Seis huecos más.", "Six more slots.", "clothing", 0.5, 1, 0, equip={"slot": "espalda", "slots": 6, "carry": 8})
item("mochila_grande", "Mochila de travesía", "Trekking pack", "Doce huecos más y mejor reparto del peso.", "Twelve more slots and better load.", "clothing", 1.2, 1, 2, equip={"slot": "espalda", "slots": 12, "carry": 16})
item("mascarilla", "Mascarilla con filtros", "Filter mask", "Protege de las esporas mientras tenga filtro.", "Protects from spores while the filter lasts.", "clothing", 0.4, 1, 2, dur=100, equip={"slot": "cara", "filter": True}, fuel="filtro")

RECIPES = []


def recipe(i, es, en, out, n, ins, cat, station="", tool="", time=3.0, level=0):
    RECIPES.append({"id": i, "name": T(es, en), "out": out, "n": n, "in": ins, "cat": cat, "station": station, "tool": tool, "time": time, "level": level})


recipe("r_cuerda", "Trenzar cuerda", "Braid rope", "cuerda", 1, {"fibra": 5}, "util")
recipe("r_venda", "Preparar vendas", "Make bandages", "venda", 2, {"tela": 2}, "salud")
recipe("r_unguento", "Ungüento de hierbas", "Herbal salve", "unguento", 1, {"hierbas": 4, "tela": 1}, "salud")
recipe("r_agua_hervida", "Hervir agua", "Boil water", "agua_potable", 1, {"agua_turbia": 1}, "cocina", station="fire", time=6.0)
recipe("r_agua_pastilla", "Tratar agua", "Treat water", "agua_potable", 1, {"agua_turbia": 1, "pastillas": 1}, "cocina", time=2.0)
recipe("r_setas", "Asar setas", "Roast mushrooms", "setas_asadas", 2, {"setas": 2, "palo": 1}, "cocina", station="fire", time=5.0)
recipe("r_infusion", "Infusión de hierbas", "Herbal infusion", "infusion", 1, {"agua_potable": 1, "hierbas": 2}, "cocina", station="fire", time=5.0)
recipe("r_guiso", "Guiso de campo", "Field stew", "guiso", 1, {"lata_legumbres": 1, "setas": 2, "agua_potable": 1}, "cocina", station="fire", time=8.0)
recipe("r_tablon", "Serrar tablones", "Cut planks", "tablon", 2, {"palo": 5}, "material", tool="hachuela", time=4.0)
recipe("r_tela", "Deshacer ropa vieja", "Tear old cloth", "tela", 3, {"chaqueta_campo": 1}, "material", time=3.0)
recipe("r_hachuela", "Hachuela", "Hatchet", "hachuela", 1, {"palo": 2, "chatarra": 2, "cuerda": 1}, "util", station="workbench", time=6.0)
recipe("r_martillo", "Martillo", "Hammer", "martillo", 1, {"palo": 1, "chatarra": 2, "cinta": 1}, "util", station="workbench", time=6.0)
recipe("r_espantador", "Espantador", "Rattle", "espantador", 1, {"palo": 1, "chatarra": 1, "piedra": 2, "cuerda": 1}, "util", time=4.0)
recipe("r_farol", "Farol", "Lantern", "farol", 1, {"chatarra": 3, "tela": 1, "liquen": 1}, "util", station="workbench", time=8.0, level=2)
recipe("r_filtro", "Filtro de mascarilla", "Mask filter", "filtro", 1, {"tela": 2, "hierbas": 2, "chatarra": 1}, "salud", station="workbench", time=5.0)
recipe("r_gorro", "Gorro de lana", "Wool hat", "gorro_lana", 1, {"tela": 3, "fibra": 4}, "ropa", time=5.0)
recipe("r_mochila", "Mochila pequeña", "Small backpack", "mochila_pequena", 1, {"tela": 6, "cuerda": 2}, "ropa", time=7.0)
recipe("r_mochila_grande", "Mochila de travesía", "Trekking pack", "mochila_grande", 1, {"mochila_pequena": 1, "lona": 1, "cuerda": 2, "cinta": 1}, "ropa", station="workbench", time=10.0, level=3)
recipe("r_impermeable", "Impermeable", "Raincoat", "impermeable", 1, {"lona": 1, "cuerda": 1, "cinta": 1}, "ropa", station="workbench", time=8.0)
recipe("r_lona", "Lona remendada", "Patched tarp", "lona", 1, {"tela": 8, "cinta": 1}, "material", station="workbench", time=6.0)

# ---- tablas de botín: [id, peso, min, max] ---------------------------------------------------------------------
LOOT = {
    "house_kitchen": {"rolls": [1, 3], "items": [["lata_legumbres", 10, 1, 2], ["lata_melocoton", 7, 1, 1], ["galletas", 9, 1, 2], ["botella_vacia", 8, 1, 2], ["refresco", 5, 1, 1], ["conserva_pescado", 7, 1, 2], ["pastillas", 2, 1, 2], ["agua_potable", 3, 1, 1]]},
    "house_bedroom": {"rolls": [1, 2], "items": [["tela", 12, 1, 3], ["gorro_lana", 4, 1, 1], ["pantalon_monte", 3, 1, 1], ["chaqueta_campo", 3, 1, 1], ["venda", 5, 1, 2], ["pilas", 4, 1, 2], ["mochila_pequena", 2, 1, 1], ["botas_monte", 2, 1, 1]]},
    "house_any": {"rolls": [0, 2], "items": [["tela", 8, 1, 2], ["pilas", 5, 1, 2], ["cinta", 3, 1, 1], ["botella_vacia", 6, 1, 1], ["barrita", 5, 1, 2], ["linterna", 2, 1, 1], ["cuerda", 3, 1, 1], ["clavos", 4, 1, 3]]},
    "shop_food": {"rolls": [1, 3], "items": [["lata_legumbres", 10, 1, 3], ["lata_melocoton", 8, 1, 2], ["conserva_pescado", 9, 1, 3], ["galletas", 9, 1, 3], ["barrita", 8, 1, 4], ["refresco", 7, 1, 3], ["agua_potable", 5, 1, 2], ["pilas", 3, 1, 2]]},
    "pharmacy": {"rolls": [1, 3], "items": [["venda", 12, 1, 3], ["pastillas", 9, 1, 4], ["botiquin", 3, 1, 1], ["unguento", 5, 1, 2], ["filtro", 3, 1, 2], ["tela", 5, 1, 2]]},
    "clinic": {"rolls": [1, 3], "items": [["venda", 12, 1, 4], ["botiquin", 5, 1, 1], ["pastillas", 7, 1, 3], ["mascarilla", 2, 1, 1], ["filtro", 4, 1, 2], ["tela", 5, 1, 3]]},
    "office": {"rolls": [0, 2], "items": [["pilas", 8, 1, 3], ["cinta", 6, 1, 1], ["linterna", 3, 1, 1], ["barrita", 5, 1, 2], ["brujula", 2, 1, 1], ["botella_vacia", 4, 1, 1]]},
    "school": {"rolls": [0, 2], "items": [["cinta", 6, 1, 1], ["tela", 6, 1, 2], ["galletas", 5, 1, 1], ["pilas", 4, 1, 2], ["brujula", 3, 1, 1], ["manzana", 3, 1, 2]]},
    "tools": {"rolls": [1, 3], "items": [["clavos", 12, 2, 6], ["cuerda", 7, 1, 2], ["cinta", 6, 1, 1], ["martillo", 3, 1, 1], ["hachuela", 3, 1, 1], ["chatarra", 8, 1, 3], ["palanca", 1.5, 1, 1], ["tablon", 6, 1, 3], ["lona", 2, 1, 1]]},
    "workshop": {"rolls": [1, 3], "items": [["chatarra", 12, 1, 4], ["clavos", 10, 2, 6], ["cinta", 7, 1, 2], ["pilas", 6, 1, 3], ["martillo", 4, 1, 1], ["palanca", 3, 1, 1], ["linterna", 3, 1, 1], ["lona", 3, 1, 1], ["cuerda", 5, 1, 2]]},
    "warehouse": {"rolls": [1, 3], "items": [["tablon", 10, 1, 4], ["lona", 5, 1, 1], ["cuerda", 8, 1, 3], ["chatarra", 8, 1, 3], ["clavos", 8, 2, 8], ["lata_legumbres", 5, 1, 3], ["conserva_pescado", 5, 2, 4], ["mochila_pequena", 2, 1, 1], ["cinta", 4, 1, 2]]},
    "factory": {"rolls": [1, 3], "items": [["conserva_pescado", 14, 1, 4], ["lata_legumbres", 8, 1, 3], ["lata_melocoton", 6, 1, 2], ["chatarra", 8, 1, 3], ["tela", 5, 1, 2], ["botella_vacia", 5, 1, 2], ["cinta", 4, 1, 1], ["pilas", 3, 1, 2]]},
    "farm": {"rolls": [1, 3], "items": [["cuerda", 8, 1, 2], ["manzana", 8, 1, 3], ["tablon", 6, 1, 3], ["clavos", 6, 2, 5], ["tela", 5, 1, 2], ["lona", 2, 1, 1], ["hachuela", 2, 1, 1], ["botella_vacia", 5, 1, 2], ["hierbas", 5, 1, 3]]},
    "cabin": {"rolls": [1, 3], "items": [["palo", 8, 2, 5], ["cuerda", 6, 1, 2], ["lata_legumbres", 6, 1, 1], ["venda", 5, 1, 2], ["gorro_lana", 3, 1, 1], ["pilas", 4, 1, 2], ["brujula", 2, 1, 1], ["botas_monte", 2, 1, 1], ["hachuela", 2, 1, 1]]},
    "ranger": {"rolls": [1, 3], "items": [["brujula", 6, 1, 1], ["linterna", 5, 1, 1], ["pilas", 7, 1, 3], ["botiquin", 3, 1, 1], ["chaqueta_campo", 3, 1, 1], ["botas_monte", 3, 1, 1], ["cuerda", 5, 1, 2], ["barrita", 6, 1, 3]]},
    "fishing": {"rolls": [1, 2], "items": [["cuerda", 9, 1, 2], ["conserva_pescado", 8, 1, 2], ["impermeable", 3, 1, 1], ["lona", 3, 1, 1], ["botella_vacia", 5, 1, 2], ["fibra", 6, 2, 5]]},
    "chapel": {"rolls": [1, 2], "items": [["venda", 7, 1, 2], ["agua_potable", 7, 1, 2], ["galletas", 6, 1, 2], ["tela", 6, 1, 3], ["infusion", 3, 1, 1], ["hierbas", 5, 2, 4]]},
    "lab": {"rolls": [1, 3], "items": [["filtro", 10, 1, 3], ["mascarilla", 4, 1, 1], ["liquen", 8, 1, 3], ["pilas", 7, 1, 4], ["botiquin", 3, 1, 1], ["pastillas", 6, 1, 4], ["linterna", 3, 1, 1], ["cinta", 4, 1, 2]]},
    "station_secure": {"rolls": [2, 4], "items": [["liquen", 10, 2, 4], ["botiquin", 6, 1, 2], ["mochila_grande", 4, 1, 1], ["filtro", 8, 2, 4], ["farol", 4, 1, 1], ["mascarilla", 4, 1, 1], ["pilas", 6, 2, 5]]},
    "archive": {"rolls": [1, 1], "items": [["llave_estacion", 1, 1, 1]], "guaranteed": ["llave_estacion"]},
    "secret": {"rolls": [2, 4], "items": [["botiquin", 5, 1, 1], ["mochila_grande", 3, 1, 1], ["farol", 4, 1, 1], ["lona", 5, 1, 2], ["guiso", 4, 1, 2], ["palanca", 3, 1, 1], ["botas_monte", 4, 1, 1], ["impermeable", 4, 1, 1], ["liquen", 5, 1, 2]]},
}
# botín de arranque de algunos contenedores concretos
LOOT["house_kitchen"]["respawn"] = 5400
for k in LOOT:
    LOOT[k].setdefault("respawn", 7200)
LOOT["archive"]["respawn"] = 10800
LOOT["archive_office"] = {"rolls": [1, 1], "items": [["llave_archivo", 1, 1, 1]], "guaranteed": ["llave_archivo"], "respawn": 10800}

HARVEST = {
    "bayas": {"name": T("Zarza con bayas", "Berry bramble"), "verb": T("Recoger bayas", "Pick berries"), "model": "vegetation/bush_berry", "empty": "vegetation/bush_berry_empty", "time": 2.5, "yield": [["bayas", 2, 5]], "regrow": 900, "radius": 1.3},
    "setas": {"name": T("Setas", "Mushrooms"), "verb": T("Recoger setas", "Pick mushrooms"), "model": "vegetation/mushrooms", "empty": "", "time": 2.0, "yield": [["setas", 1, 3]], "regrow": 1200, "radius": 0.6},
    "hierbas": {"name": T("Hierbas del valle", "Valley herbs"), "verb": T("Recoger hierbas", "Gather herbs"), "model": "vegetation/herb_plant", "empty": "vegetation/herb_plant_empty", "time": 2.0, "yield": [["hierbas", 1, 3]], "regrow": 800, "radius": 0.7},
    "fibra": {"name": T("Junco fibroso", "Fibre rush"), "verb": T("Cortar fibra", "Cut fibre"), "model": "vegetation/fiber_plant", "empty": "vegetation/fiber_plant_empty", "time": 2.2, "yield": [["fibra", 2, 5]], "regrow": 700, "radius": 0.7},
    "piedra": {"name": T("Montón de piedras", "Stone pile"), "verb": T("Recoger piedras", "Collect stones"), "model": "vegetation/stone_pile", "empty": "", "time": 3.0, "yield": [["piedra", 2, 4]], "regrow": 1800, "radius": 0.9},
    "lena": {"name": T("Ramas caídas", "Fallen branches"), "verb": T("Recoger leña", "Gather firewood"), "model": "vegetation/fallen_log", "empty": "", "time": 3.5, "yield": [["palo", 2, 5]], "regrow": 1100, "radius": 1.6, "tool_bonus": "hachuela", "keep": True},
    "chatarra": {"name": T("Bidón con restos", "Drum of scrap"), "verb": T("Rebuscar chatarra", "Scavenge scrap"), "model": "props/barrel_rust", "empty": "", "time": 4.0, "yield": [["chatarra", 1, 3], ["clavos", 0, 4]], "regrow": 2400, "radius": 0.9, "keep": True},
    "liquen": {"name": T("Liquen brumal", "Mist lichen"), "verb": T("Recoger liquen", "Collect lichen"), "model": "props/lichen_cluster", "empty": "", "time": 3.0, "yield": [["liquen", 1, 2]], "regrow": 2000, "radius": 0.8},
    "manzano": {"name": T("Manzano", "Apple tree"), "verb": T("Recoger manzanas", "Pick apples"), "model": "vegetation/tree_apple_fruit_a_lod0", "empty": "vegetation/tree_apple_a_lod0", "time": 3.0, "yield": [["manzana", 2, 4]], "regrow": 1500, "radius": 1.8, "trunk": 0.14},
}

STRUCT = {}


def struct(i, es, en, des, den, cost, frame_cost, **kw):
    STRUCT[i] = {"id": i, "name": T(es, en), "desc": T(des, den), "cost": cost, "frame_cost": frame_cost, **kw}


struct("hoguera", "Hoguera", "Campfire", "Calor, luz y cocina. Hay que alimentarla.", "Warmth, light and cooking. Needs feeding.", {"palo": 4}, {"piedra": 4}, station="fire", warm=7.0, fuel="palo", burn=420, radius=0.8, light=True)
struct("refugio", "Refugio de lona", "Tarp shelter", "Para descansar y volver aquí si desfalleces.", "Rest here and return if you collapse.", {"lona": 1, "cuerda": 2, "tela": 2}, {"palo": 6}, rest=True, respawn=True, radius=1.9, tool="")
struct("saco_dormir", "Saco de dormir", "Bedroll", "Descanso rápido donde lo extiendas.", "Quick rest wherever you unroll it.", {"tela": 5, "fibra": 6}, {}, rest=True, radius=1.1, instant=True)
struct("arcon", "Arcón", "Storage chest", "Almacén con permisos de grupo.", "Storage with group permissions.", {"tablon": 5, "clavos": 6}, {"palo": 2}, container=20, radius=0.8, tool="martillo")
struct("banco", "Banco de trabajo", "Workbench", "Permite fabricar objetos avanzados.", "Lets you craft advanced items.", {"tablon": 6, "clavos": 8, "chatarra": 2}, {"palo": 4}, station="workbench", radius=1.2, tool="martillo")
struct("muro", "Muro de tablas", "Plank wall", "Panel de 2,4 m.", "A 2.4 m panel.", {"tablon": 4, "clavos": 4}, {"palo": 3}, radius=1.3, tool="martillo", snap=True)
struct("muro_ventana", "Muro con ventana", "Window wall", "Panel con hueco para mirar.", "A panel with an opening.", {"tablon": 3, "clavos": 4}, {"palo": 3}, radius=1.3, tool="martillo", snap=True)
struct("puerta", "Marco con puerta", "Door frame", "Puerta que solo abre tu grupo si la cierras.", "A door only your group opens when locked.", {"tablon": 5, "clavos": 6, "cuerda": 1}, {"palo": 3}, radius=1.3, tool="martillo", snap=True, door=True)
struct("suelo", "Tarima", "Floor deck", "Base nivelada de 2,4 m.", "A levelled 2.4 m base.", {"tablon": 6, "clavos": 6}, {"palo": 4}, radius=1.6, tool="martillo", snap=True)
struct("tejado", "Tejadillo", "Roof panel", "Cubre un módulo.", "Covers one module.", {"palo": 4, "fibra": 12, "cuerda": 2}, {"palo": 3}, radius=1.6, snap=True, roof=True)
struct("colector", "Colector de lluvia", "Rain collector", "Acumula agua cuando llueve.", "Collects water when it rains.", {"lona": 1, "cuerda": 2, "chatarra": 3}, {"palo": 4}, station="water", radius=1.1, collector=5)
struct("poste_farol", "Poste con farol", "Lantern post", "Luz fija para el campamento.", "A fixed camp light.", {"farol": 1, "cuerda": 1}, {"palo": 2}, radius=0.4, light=True)
struct("valla", "Valla", "Fence", "Delimita el campamento.", "Marks out your camp.", {"palo": 4, "cuerda": 1}, {"palo": 2}, radius=1.25, snap=True)

CREATURES = {
    "brumal": {"name": T("Brumal", "Brumal"), "desc": T("Acechador del robledal. Le molestan el ruido y la luz.", "A stalker of the oakwood. Noise and light bother it."), "model": "creatures/brumal",
               "walk": 1.5, "run": 6.0, "sight": 34, "fov": 110, "hear": 1.0, "leash": 85, "contact": 1.7, "hit": {"health": 14, "stamina": 30, "effect": ["aturdido", 8, 1.0]},
               "float": 0.0, "radius": 0.7, "behavior": "stalker", "fear_light": True},
    "zarzo": {"name": T("Zarzo", "Zarzo"), "desc": T("Pequeño recolector asustadizo. Se hace una bola si lo acorralan.", "A small, skittish forager. Curls up when cornered."), "model": "creatures/zarzo",
              "walk": 0.9, "run": 4.6, "sight": 14, "fov": 200, "hear": 1.4, "leash": 60, "contact": 0.0, "float": 0.0, "radius": 0.3, "behavior": "skittish"},
    "farol": {"name": T("Farol", "Wisp"), "desc": T("Flota sobre el marjal y suelta esporas si te acercas.", "Drifts over the marsh and puffs spores when you get close."), "model": "creatures/farol",
              "walk": 0.7, "run": 1.5, "sight": 22, "fov": 360, "hear": 0.2, "leash": 70, "contact": 3.6, "hit": {"effect": ["esporas", 60, 1.0]}, "float": 1.9, "radius": 0.5, "behavior": "drifter", "likes_light": True},
}

EFFECTS = {
    "hambriento": {"name": T("Hambre", "Hungry"), "desc": T("Recuperas menos resistencia. Come algo.", "Stamina recovers slowly. Eat something."), "icon": "hunger", "bad": True},
    "sediento": {"name": T("Sed", "Thirsty"), "desc": T("Te cansas antes. Bebe agua.", "You tire sooner. Drink water."), "icon": "thirst", "bad": True},
    "agotado": {"name": T("Agotamiento", "Exhausted"), "desc": T("No puedes esprintar. Descansa en un refugio.", "You cannot sprint. Rest in a shelter."), "icon": "fatigue", "bad": True},
    "frio": {"name": T("Frío", "Cold"), "desc": T("Pierdes resistencia. Busca abrigo o fuego.", "You lose stamina. Find shelter or a fire."), "icon": "cold", "bad": True},
    "hipotermia": {"name": T("Entumecimiento", "Numb with cold"), "desc": T("El frío ya te hace daño. Caliéntate cuanto antes.", "The cold is hurting you. Warm up now."), "icon": "cold", "bad": True},
    "calor": {"name": T("Calor", "Hot"), "desc": T("Bebes más de la cuenta.", "You get thirsty faster."), "icon": "heat", "bad": True},
    "mojado": {"name": T("Mojado", "Wet"), "desc": T("La ropa mojada enfría. Sécate bajo techo o al fuego.", "Wet clothes chill you. Dry off indoors or by a fire."), "icon": "wet", "bad": True},
    "esporas": {"name": T("Esporas", "Spores"), "desc": T("Toses y te fatigas. Sal de la bruma o usa mascarilla.", "You cough and tire. Leave the mist or wear a mask."), "icon": "spores", "bad": True},
    "malestar": {"name": T("Malestar", "Queasy"), "desc": T("Algo te ha sentado mal. Pierdes agua.", "Something disagreed with you. You lose water."), "icon": "sick", "bad": True},
    "aturdido": {"name": T("Aturdimiento", "Dazed"), "desc": T("Un Brumal te ha embestido. Te mueves más despacio.", "A Brumal rammed you. You move slower."), "icon": "dazed", "bad": True},
    "abrigado": {"name": T("Abrigado", "Warm"), "desc": T("Entras en calor.", "You are warming up."), "icon": "warm", "bad": False},
    "bien_alimentado": {"name": T("Bien alimentado", "Well fed"), "desc": T("Recuperas resistencia y salud más rápido.", "Stamina and health recover faster."), "icon": "food", "bad": False},
    "descansado": {"name": T("Descansado", "Rested"), "desc": T("Te cansas más despacio.", "You tire more slowly."), "icon": "rest", "bad": False},
    "alivio": {"name": T("Alivio", "Soothed"), "desc": T("El ungüento hace efecto.", "The salve is working."), "icon": "health", "bad": False},
    "a_cubierto": {"name": T("A cubierto", "Sheltered"), "desc": T("Bajo techo no te mojas y pierdes menos calor.", "Indoors you stay dry and lose less heat."), "icon": "shelter", "bad": False},
    "junto_al_fuego": {"name": T("Junto al fuego", "By the fire"), "desc": T("El fuego te calienta y te seca.", "The fire warms and dries you."), "icon": "fire", "bad": False},
}

DOCS = {
    "aviso_tablon": {"title": T("Aviso en el tablón", "Notice on the board"), "where": "el_collado", "text": T(
        "A QUIEN LLEGUE AL COLLADO:\nAquí se reparte lo que hay. Deja lo que te sobre y coge lo que te falte.\nNo cruces el Marjal sin mascarilla. La bruma no perdona al que corre.\nSi oyes ramas partirse en el robledal, no corras: apaga la luz, agáchate y espera.\n— Los del último turno",
        "TO WHOEVER REACHES EL COLLADO:\nWe share what there is. Leave what you can spare, take what you need.\nDo not cross the Marsh without a mask. The mist does not forgive runners.\nIf you hear branches snap in the oakwood, do not run: kill the light, crouch and wait.\n— The last shift")},
    "acta_evacuacion": {"title": T("Acta de la Junta", "Council minutes"), "where": "consistorial", "text": T(
        "Sesión extraordinaria. Se acuerda desalojar Sotoalto y sus pedanías mientras dure la bruma sobre el Marjal.\nEl Instituto asegura que es cuestión de semanas. La Cooperativa guardará las llaves del archivo.\nLa tarjeta de la Estación queda en el arcón, por si alguien tiene que volver a por los suyos.",
        "Extraordinary session. It is agreed to clear Sotoalto and its hamlets while the mist lies over the Marsh.\nThe Institute insists it is a matter of weeks. The Co-op will keep the archive keys.\nThe Station keycard stays in the chest, in case someone must go back for their own.")},
    "cuaderno_maestra": {"title": T("Cuaderno de la maestra", "The teacher's notebook"), "where": "escuela", "text": T(
        "Los niños llaman 'faroles' a las luces del Marjal. Dicen que siguen a quien lleva candil.\nHoy hemos dibujado el valle: el río, el puente, la ermita arriba. Les he prometido que volveremos a clase en otoño.",
        "The children call the Marsh lights 'wisps'. They say they follow anyone carrying a lamp.\nToday we drew the valley: the river, the bridge, the chapel up high. I promised them school again by autumn.")},
    "parte_fabrica": {"title": T("Parte de turno", "Shift report"), "where": "conservas", "text": T(
        "Línea 2 parada. El agua de la toma norte llega turbia y con hilos azulados.\nBombeo dice que no es cosa suya. Se suspende el envasado hasta nuevo aviso.\nQuien cierre, que deje la llave del archivo en la oficina.",
        "Line 2 stopped. Water from the north intake arrives cloudy, with bluish threads.\nPumping says it is not their doing. Canning is suspended until further notice.\nWhoever locks up: leave the archive key in the office.")},
    "registro_bombeo": {"title": T("Registro de bombeo", "Pumping log"), "where": "bombeo", "text": T(
        "Día 3: caudal normal. Día 9: espuma en el aliviadero. Día 12: el liquen ha tapado la rejilla.\nDía 14: brilla de noche. No pienso bajar a limpiarlo solo.",
        "Day 3: normal flow. Day 9: foam at the spillway. Day 12: lichen has clogged the grate.\nDay 14: it glows at night. I am not going down to clean it alone.")},
    "diario_estacion": {"title": T("Diario de la Estación", "Station journal"), "where": "estacion_liquen", "text": T(
        "El liquen brumal no es tóxico: respira. Suelta esporas cuando sube la temperatura del agua.\nLos flotadores son su manera de viajar. Buscan luz y calor; no atacan, pero su nube agota a cualquiera.\nUn filtro de tela y hierbas basta para cruzar. Lo difícil es convencer a la gente de volver.",
        "Mist lichen is not toxic: it breathes. It sheds spores when the water warms.\nThe floaters are how it travels. They seek light and warmth; they do not attack, but their cloud wears anyone out.\nA cloth-and-herb filter is enough to cross. The hard part is convincing people to come back.")},
    "carta_ermitano": {"title": T("Carta en la ermita", "Letter at the chapel"), "where": "ermita", "text": T(
        "Aquí arriba la bruma no llega. He dejado mantas y lo que he podido subir.\nSi vienes de paso, descansa. Si vienes a quedarte, trae leña.",
        "The mist does not reach up here. I left blankets and whatever I could carry up.\nIf you are passing through, rest. If you mean to stay, bring firewood.")},
    "cuaderno_guarda": {"title": T("Cuaderno del guarda", "The ranger's notebook"), "where": "caseta_forestal", "text": T(
        "Los brumales bajaron del collado alto con la primera niebla. No cazan: vigilan.\nSe plantan, escuchan y embisten si corres. El ruido de latas los espanta; la linterna, de noche, también.\nHe marcado en el mapa la cabaña vieja y la bodega. Por si acaso.",
        "The brumals came down from the high pass with the first fog. They do not hunt: they watch.\nThey stand, listen, and charge if you run. A rattle of tins scares them; so does a torch at night.\nI marked the old cabin and the cellar on the map. Just in case.")},
    "nota_bodega": {"title": T("Nota en la bodega", "Note in the cellar"), "where": "bodega_vieja", "text": T(
        "Si has encontrado esto, es que sabes mirar. Lo del arcón es para ti.\nDeja algo para el siguiente.",
        "If you found this, you know how to look. What is in the chest is yours.\nLeave something for the next one.")},
}

PROGRESSION = {
    "levels": [0, 60, 150, 280, 450, 660, 920, 1240, 1620, 2080],
    "perks": {"2": {"slots": 2, "text": T("+2 huecos de inventario", "+2 inventory slots")}, "4": {"sprint": 0.9, "text": T("Esprintar cansa un 10 % menos", "Sprinting costs 10% less")},
              "6": {"harvest": 1, "text": T("+1 al recolectar", "+1 when harvesting")}, "8": {"needs": 0.9, "text": T("Hambre y sed un 10 % más lentas", "Hunger and thirst 10% slower")}},
    "cosmetics": {"chaqueta_oliva": {"name": T("Chaqueta oliva", "Olive jacket"), "color": [0.34, 0.4, 0.27], "unlock": ""},
                  "chaqueta_teja": {"name": T("Chaqueta teja", "Rust jacket"), "color": [0.55, 0.26, 0.18], "unlock": "explorador_valle"},
                  "chaqueta_azul": {"name": T("Chaqueta azul bruma", "Mist-blue jacket"), "color": [0.26, 0.36, 0.46], "unlock": "cruzar_marjal"},
                  "chaqueta_ocre": {"name": T("Chaqueta ocre", "Ochre jacket"), "color": [0.62, 0.48, 0.2], "unlock": "buen_vecino"},
                  "gorro_rojo": {"name": T("Gorro rojo", "Red hat"), "hat": [0.5, 0.2, 0.14], "unlock": ""},
                  "gorro_verde": {"name": T("Gorro musgo", "Moss hat"), "hat": [0.26, 0.36, 0.22], "unlock": "primer_refugio"},
                  "gorro_gris": {"name": T("Gorro gris", "Grey hat"), "hat": [0.42, 0.42, 0.44], "unlock": "archivero"}},
    "challenges": {
        "primeros_pasos": {"name": T("Primeros pasos", "First steps"), "desc": T("Recoge 5 objetos del mundo.", "Pick up 5 items from the world."), "stat": "pickups", "goal": 5, "xp": 20},
        "recolector": {"name": T("Lo que da el valle", "What the valley gives"), "desc": T("Recolecta 25 veces.", "Harvest 25 times."), "stat": "harvests", "goal": 25, "xp": 50},
        "manitas": {"name": T("Manitas", "Handy"), "desc": T("Fabrica 10 objetos.", "Craft 10 items."), "stat": "crafts", "goal": 10, "xp": 50},
        "primer_refugio": {"name": T("Bajo techo", "Under a roof"), "desc": T("Termina tu primer refugio.", "Finish your first shelter."), "stat": "built_refugio", "goal": 1, "xp": 60},
        "explorador_valle": {"name": T("Explorador del valle", "Valley explorer"), "desc": T("Descubre 15 lugares.", "Discover 15 places."), "stat": "places", "goal": 15, "xp": 120},
        "secretos": {"name": T("Saber mirar", "Knowing how to look"), "desc": T("Encuentra los 4 lugares secretos.", "Find the 4 secret places."), "stat": "secrets", "goal": 4, "xp": 150},
        "lector": {"name": T("Lo que quedó escrito", "What was left in writing"), "desc": T("Lee 6 documentos.", "Read 6 documents."), "stat": "docs", "goal": 6, "xp": 90},
        "cruzar_marjal": {"name": T("Cruzar el Marjal", "Crossing the Marsh"), "desc": T("Llega a la Estación Liquen.", "Reach Lichen Station."), "stat": "place:estacion_liquen", "goal": 1, "xp": 100},
        "archivero": {"name": T("Archivero", "Archivist"), "desc": T("Abre el archivo de la Casa Consistorial.", "Open the Town Hall archive."), "stat": "unlock:llave_archivo", "goal": 1, "xp": 60},
        "superviviente": {"name": T("Tres amaneceres", "Three sunrises"), "desc": T("Sobrevive 3 días seguidos.", "Survive 3 days in a row."), "stat": "days", "goal": 3, "xp": 120},
        "caminante": {"name": T("Caminante", "Wayfarer"), "desc": T("Recorre 10 km.", "Travel 10 km."), "stat": "distance", "goal": 10000, "xp": 80},
        "buen_vecino": {"name": T("Buen vecino", "Good neighbour"), "desc": T("Cumple 5 encargos del tablón.", "Complete 5 board errands."), "stat": "contracts", "goal": 5, "xp": 120},
        "en_compania": {"name": T("En compañía", "In company"), "desc": T("Cooperativo: descubre 3 lugares yendo en grupo.", "Co-op: discover 3 places while in a group."), "stat": "group_places", "goal": 3, "xp": 100, "coop": True},
        "obra_comun": {"name": T("Obra común", "Common work"), "desc": T("Cooperativo: termina una estructura que empezó un compañero.", "Co-op: finish a structure a teammate started."), "stat": "group_builds", "goal": 1, "xp": 100, "coop": True},
        "trueque": {"name": T("Trueque", "Barter"), "desc": T("Cooperativo: completa un intercambio con otro jugador.", "Co-op: complete a trade with another player."), "stat": "trades", "goal": 1, "xp": 60, "coop": True},
    },
    "contracts": {
        "c_vendas": {"name": T("Vendas para el Consultorio", "Bandages for the Clinic"), "desc": T("Entrega 4 vendas en el tablón.", "Hand in 4 bandages at the board."), "deliver": {"venda": 4}, "xp": 40, "reward": {"botiquin": 1}},
        "c_lena": {"name": T("Leña para la Ermita", "Firewood for the Chapel"), "desc": T("Entrega 12 palos.", "Hand in 12 sticks."), "deliver": {"palo": 12}, "xp": 30, "reward": {"infusion": 2}},
        "c_conservas": {"name": T("Despensa común", "Common pantry"), "desc": T("Entrega 5 conservas de pescado.", "Hand in 5 tins of fish."), "deliver": {"conserva_pescado": 5}, "xp": 40, "reward": {"mochila_pequena": 1}},
        "c_liquen": {"name": T("Muestras para el Instituto", "Samples for the Institute"), "desc": T("Entrega 4 muestras de liquen brumal.", "Hand in 4 mist lichen samples."), "deliver": {"liquen": 4}, "xp": 70, "reward": {"filtro": 3, "mascarilla": 1}},
        "c_ermita": {"name": T("Subir a la Ermita", "Up to the Chapel"), "desc": T("Expedición: llega a la Ermita de San Telmo.", "Expedition: reach San Telmo Chapel."), "visit": "ermita", "xp": 50, "reward": {"agua_potable": 2}},
        "c_repetidor": {"name": T("El Repetidor", "The Relay Mast"), "desc": T("Expedición: encuentra el Repetidor del Alto.", "Expedition: find the Relay Mast."), "visit": "repetidor", "xp": 80, "reward": {"pilas": 6, "linterna": 1}},
        "c_bombeo": {"name": T("¿Qué pasa con el agua?", "What is wrong with the water?"), "desc": T("Expedición: lee el registro de la Estación de bombeo.", "Expedition: read the Pumping Station log."), "read": "registro_bombeo", "xp": 60, "reward": {"pastillas": 6}},
        "c_cuerda": {"name": T("Cuerda para todos", "Rope for everyone"), "desc": T("Entrega 4 cuerdas.", "Hand in 4 ropes."), "deliver": {"cuerda": 4}, "xp": 40, "reward": {"lona": 1}},
    },
    "achievements": {
        "a_llegada": {"name": T("Llegada al valle", "Arrival"), "desc": T("Entra en Valdebruma por primera vez.", "Enter Valdebruma for the first time."), "stat": "logins", "goal": 1},
        "a_lumbre": {"name": T("Lumbre", "Hearth"), "desc": T("Enciende una hoguera.", "Light a campfire."), "stat": "built_hoguera", "goal": 1},
        "a_noche": {"name": T("Noche en vela", "Sleepless night"), "desc": T("Pasa una noche entera a la intemperie.", "Spend a whole night outdoors."), "stat": "nights_out", "goal": 1},
        "a_bruma": {"name": T("A través de la bruma", "Through the mist"), "desc": T("Entra en la bruma con mascarilla.", "Enter the mist wearing a mask."), "stat": "mist_masked", "goal": 1},
        "a_espanto": {"name": T("Latas y piedras", "Tins and stones"), "desc": T("Ahuyenta a un Brumal.", "Drive off a Brumal."), "stat": "deterred", "goal": 1},
        "a_campamento": {"name": T("Campamento", "Camp"), "desc": T("Construye 8 estructuras.", "Build 8 structures."), "stat": "builds", "goal": 8},
        "a_todo": {"name": T("Conocer el valle", "Knowing the valley"), "desc": T("Descubre todos los lugares.", "Discover every place."), "stat": "places", "goal": 29},
    },
    "difficulty": {"tranquilo": {"needs": 0.6, "damage": 0.6, "creatures": 0.7, "name": T("Tranquilo", "Calm")}, "normal": {"needs": 1.0, "damage": 1.0, "creatures": 1.0, "name": T("Normal", "Normal")},
                   "exigente": {"needs": 1.4, "damage": 1.4, "creatures": 1.3, "name": T("Exigente", "Demanding")}},
}


def dump(name, data):
    with open(os.path.join(ROOT, "data", name), "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=1, sort_keys=True)


if __name__ == "__main__":
    for r in RECIPES:
        assert r["out"] in ITEMS, r["out"]
        for k in r["in"]:
            assert k in ITEMS, k
    for t in LOOT.values():
        for e in t["items"]:
            assert e[0] in ITEMS, e[0]
    for h in HARVEST.values():
        for y in h["yield"]:
            assert y[0] in ITEMS, y[0]
    for s in STRUCT.values():
        for k in list(s["cost"]) + list(s["frame_cost"]):
            assert k in ITEMS, k
    for c in PROGRESSION["contracts"].values():
        for k in list(c.get("deliver", {})) + list(c.get("reward", {})):
            assert k in ITEMS, k
    for i in ITEMS:
        assert os.path.exists(os.path.join(ROOT, "assets", "models", "items", i + ".glb")), "sin modelo: " + i
        assert os.path.exists(os.path.join(ROOT, "assets", "icons", "items", i + ".png")), "sin icono: " + i
    dump("items.json", ITEMS); dump("recipes.json", {r["id"]: r for r in RECIPES}); dump("loot_tables.json", LOOT); dump("harvest.json", HARVEST)
    dump("structures.json", STRUCT); dump("creatures.json", CREATURES); dump("effects.json", EFFECTS); dump("documents.json", DOCS); dump("progression.json", PROGRESSION)
    print("datos: %d objetos, %d recetas, %d tablas de botín, %d estructuras, %d documentos" % (len(ITEMS), len(RECIPES), len(LOOT), len(STRUCT), len(DOCS)))
