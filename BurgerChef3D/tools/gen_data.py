#!/usr/bin/env python3
"""Genera los datos de contenido (JSON) de Burger Chef 3D: ingredientes, recetas, niveles, misiones,
mejoras, tienda, clientes y distribución del restaurante. Los datos viven en resources/data/ y se pueden editar a mano."""
import json, math, os
from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
DATA = os.path.join(ROOT, "resources", "data")
os.makedirs(DATA, exist_ok=True)

def T(es, en):
    return {"es": es, "en": en}

def dump(name, obj):
    with open(os.path.join(DATA, name), "w", encoding="utf-8") as f:
        json.dump(obj, f, ensure_ascii=False, indent=1)
        f.write("\n")

# ------------------------------------------------------------------ ingredientes
def ing(id_, es, en, color, stackable=True, cook=None, price=1):
    return {"id": id_, "name": T(es, en), "color": color, "stackable": stackable, "cook": cook, "unit_price": price}

# Solo hay ingredientes con modelo 3D real en los packs KayKit Restaurant Bits / Kenney Food Kit (ver scripts/core/model_table.gd).
# Pepinillos y salsas no tienen asset en esos packs, así que no existen en el juego.
ING = [
    ing("bun_bottom", "Pan inferior", "Bottom bun", "#d9964f", price=2),
    ing("bun_top", "Pan superior", "Top bun", "#e0a15a", price=2),
    ing("patty", "Carne", "Beef patty", "#7a4a2c", cook={"station": "grill", "cook_time": 8.0, "burn_time": 8.0}, price=4),
    ing("veggie_patty", "Medallón vegetal", "Veggie patty", "#6f7d3a", cook={"station": "grill", "cook_time": 7.0, "burn_time": 8.0}, price=4),
    ing("bacon", "Bacon", "Bacon", "#b24a3a", cook={"station": "grill", "cook_time": 5.0, "burn_time": 6.0}, price=3),
    ing("cheese", "Queso", "Cheese", "#f2b92e", price=2),
    ing("lettuce", "Lechuga", "Lettuce", "#6fb43f", price=1),
    ing("tomato", "Tomate", "Tomato", "#d8392b", price=1),
    ing("onion", "Cebolla", "Onion", "#c8a2d6", price=1),
    ing("fries", "Patatas fritas", "Fries", "#f3b72f", stackable=False, cook={"station": "fryer", "cook_time": 7.0, "burn_time": 8.0}, price=2),
    ing("drink", "Bebida", "Drink", "#4a90d9", stackable=False, price=1),
]
dump("ingredients.json", ING)

# ------------------------------------------------------------------ recetas
def burger(id_, es, en, ings, order, extras, max_extras, price, xp, diff, unlock, prep):
    return {"id": id_, "name": T(es, en), "kind": "burger", "ingredients": ings, "order": order, "extras": extras,
            "max_extras": max_extras, "price": price, "xp": xp, "difficulty": diff, "unlock_level": unlock,
            "prep_time": prep, "stations": ["grill", "assembly"]}

B, T_ = "bun_bottom", "bun_top"
REC = [
    burger("classic", "Hamburguesa clásica", "Classic burger", [B, "patty", "lettuce", "tomato", T_], "flexible", ["onion"], 1, 10, 8, 1, 1, 25),
    burger("cheese", "Hamburguesa con queso", "Cheeseburger", [B, "patty", "cheese", T_], "strict", ["onion"], 1, 13, 10, 1, 2, 28),
    burger("double", "Hamburguesa doble", "Double burger", [B, "patty", "patty", "cheese", T_], "strict", ["onion"], 1, 18, 14, 2, 4, 38),
    burger("veggie", "Hamburguesa vegetal", "Veggie burger", [B, "veggie_patty", "lettuce", "tomato", T_], "flexible", ["onion"], 1, 14, 11, 2, 5, 32),
    burger("house", "Especial de la casa", "House special", [B, "patty", "cheese", "onion", T_], "strict", [], 1, 17, 13, 2, 8, 36),
    burger("bacon", "Hamburguesa con bacon", "Bacon burger", [B, "patty", "bacon", "cheese", T_], "strict", ["onion"], 1, 19, 15, 3, 10, 40),
    burger("blt", "Hamburguesa BLT", "BLT burger", [B, "patty", "bacon", "lettuce", "tomato", T_], "strict", ["onion"], 1, 18, 14, 3, 13, 40),
    burger("complete", "Hamburguesa completa", "Full-stack burger", [B, "patty", "cheese", "lettuce", "tomato", "onion", T_], "flexible", [], 1, 24, 19, 4, 16, 46),
    burger("premium", "Hamburguesa premium", "Premium burger", [B, "patty", "patty", "bacon", "cheese", "tomato", T_], "strict", ["onion"], 1, 32, 26, 5, 20, 52),
    {"id": "combo", "name": T("Menú con patatas y bebida", "Burger meal"), "kind": "combo",
     "components": [{"type": "recipe", "id": "cheese"}, {"type": "item", "id": "fries"}, {"type": "item", "id": "drink"}],
     "price": 30, "xp": 22, "difficulty": 4, "unlock_level": 24, "prep_time": 60, "stations": ["grill", "assembly", "fryer"]},
]
# Recetas extra de la mejora «Recetas nuevas» (recipe_book): solo usan ingredientes con modelo real. Se añaden a la carta
# (modo libre y niveles de campaña a partir de su unlock_level) cuando se compra el nivel de mejora indicado.
def needs(r, level):
    r["requires_upgrade"] = {"id": "recipe_book", "level": level}
    return r
EXTRA_REC = [
    needs(burger("veggie_cheese", "Vegetal con queso", "Cheesy veggie burger", [B, "veggie_patty", "cheese", "lettuce", T_], "flexible", ["tomato"], 1, 16, 12, 2, 5, 32), 1),
    needs({"id": "classic_meal", "name": T("Menú clásico con patatas", "Classic burger with fries"), "kind": "combo",
           "components": [{"type": "recipe", "id": "classic"}, {"type": "item", "id": "fries"}],
           "price": 18, "xp": 14, "difficulty": 3, "unlock_level": 6, "prep_time": 45, "stations": ["grill", "assembly", "fryer"]}, 1),
    needs({"id": "veggie_meal", "name": T("Menú vegetal con bebida", "Veggie burger with a drink"), "kind": "combo",
           "components": [{"type": "recipe", "id": "veggie"}, {"type": "item", "id": "drink"}],
           "price": 22, "xp": 17, "difficulty": 3, "unlock_level": 8, "prep_time": 45, "stations": ["grill", "assembly"]}, 2),
    needs(burger("double_bacon", "Doble bacon", "Double bacon burger", [B, "patty", "bacon", "cheese", "patty", "bacon", T_], "strict", ["onion"], 1, 30, 24, 4, 12, 52), 2),
]
dump("recipes.json", REC + EXTRA_REC)

# ------------------------------------------------------------------ niveles
NAMES = [
    ("Primer día", "First Day"), ("Hora del queso", "Cheese Time"), ("Calentando la plancha", "Warming the Grill"),
    ("Doble ración", "Double Trouble"), ("Opción verde", "Green Choice"), ("Almuerzo tranquilo", "Quiet Lunch"),
    ("Cola creciente", "Growing Line"), ("Especial de la casa", "House Special"), ("Sin quemar nada", "No Burnt Bites"),
    ("Bacon crujiente", "Crispy Bacon"), ("Mediodía", "Midday Rush"), ("Clientes exigentes", "Picky Customers"),
    ("Fiebre del BLT", "BLT Fever"), ("Turno doble", "Double Shift"), ("Mitad del camino", "Halfway There"),
    ("Todo en uno", "The Works"), ("Contra el reloj", "Racing the Clock"), ("Cocina impecable", "Spotless Kitchen"),
    ("Fin de semana", "Weekend Crowd"), ("Sabor premium", "Premium Taste"), ("Chef bajo presión", "Chef Under Pressure"),
    ("Noche de gala", "Gala Night"), ("Récord de ventas", "Sales Record"), ("Menú completo", "Full Menu"),
    ("Triple amenaza", "Triple Threat"), ("Maratón de pedidos", "Order Marathon"), ("Perfección", "Perfection"),
    ("Hora punta", "Rush Hour"), ("Casi maestro", "Almost a Master"), ("Maestro hamburguesero", "Burger Master"),
]
RBY = {r["id"]: r for r in REC}
LEVELS = []
for i in range(1, 31):
    duration = min(240, 120 + 4 * i)
    spawn = round(26 - 0.48 * (i - 1), 1)
    patience = round(100 - 1.45 * (i - 1))
    max_active = 1 if i <= 3 else (2 if i <= 12 else 3)
    pool = [r["id"] for r in REC if r["unlock_level"] <= i][-6:]   # solo recetas base (las de la mejora se añaden en el juego)
    avg_price = sum(RBY[p]["price"] for p in pool) / len(pool)
    avg_prep = sum(RBY[p]["prep_time"] for p in pool) / len(pool)
    feasible = int(duration / spawn) + 1
    parallel = 1 + 0.35 * (max_active - 1)
    realistic = max(3, min(feasible, int(duration / (avg_prep * 0.85) * parallel)))
    pot = realistic * avg_price
    kind = i % 6
    newest = pool[-1]
    if i == 1:
        win = {"orders": 3}
    elif kind == 0:
        win = {"orders": max(3, round(realistic * 0.55))}
    elif kind == 1:
        win = {"income": int(round(0.40 * pot / 5.0)) * 5}
    elif kind == 2:
        win = {"recipe": {"id": newest, "count": max(1, round(realistic * 0.3))}}
    elif kind == 3:
        win = {"orders": max(3, round(realistic * 0.5)), "no_burnt": True}
    elif kind == 4:
        win = {"orders": max(3, round(realistic * 0.45)), "satisfaction": 55 + min(20, i // 2)}
    else:
        win = {"customers": max(3, round(realistic * 0.65))}
    star1 = int(round(0.50 * pot / 5.0)) * 5
    star2 = int(round(0.75 * pot / 5.0)) * 5
    if "income" in win:
        star1 = max(star1, win["income"] + 5)
        star2 = max(star2, star1 + 10)
    LEVELS.append({
        "id": i, "name": T(*NAMES[i - 1]), "duration": duration,
        "target_orders": win.get("orders", win.get("customers", realistic)),
        "recipes": pool, "difficulty": 1 + (i - 1) // 6, "spawn_interval": spawn, "max_active": max_active,
        "patience": patience, "reward_coins": 40 + 12 * i, "reward_xp": 30 + 6 * i,
        "win": win, "lose": {"max_failed": 4 if i <= 10 else 3}, "star_income": [star1, star2],
        # a partir del nivel 6 las bandejas se ensucian al entregar y hay que lavarlas en el fregadero
        "dirty_trays": i >= 6,
    })
dump("levels.json", LEVELS)

# ------------------------------------------------------------------ misiones / desafíos / logros
def M(id_, kind, es, en, stat, target, coins, xp):
    return {"id": id_, "kind": kind, "name": T(es, en), "stat": stat, "target": target, "reward_coins": coins, "reward_xp": xp}

MIS = [
    M("m_burgers_10", "mission", "Aprendiz de la plancha", "Grill apprentice", "burgers_made", 10, 30, 20),
    M("m_burgers_50", "mission", "Mano rápida", "Quick hands", "burgers_made", 50, 80, 50),
    M("m_clients_20", "mission", "Atención al cliente", "Customer care", "customers_served", 20, 40, 25),
    M("m_clients_60", "mission", "Local lleno", "Full house", "customers_served", 60, 100, 60),
    M("m_coins_500", "mission", "Primeras ganancias", "First earnings", "coins_earned", 500, 50, 30),
    M("m_coins_2000", "mission", "Negocio en marcha", "Business running", "coins_earned", 2000, 120, 70),
    M("m_noburn_1", "mission", "Cocina limpia", "Clean cooking", "no_burn_shifts", 1, 40, 25),
    M("m_noburn_3", "mission", "Sin humo", "Smoke-free", "no_burn_shifts", 3, 90, 55),
    M("m_perfect_5", "mission", "Cinco perfectas", "Five perfect", "perfect_burgers", 5, 50, 35),
    M("m_perfect_20", "mission", "Perfeccionista", "Perfectionist", "perfect_burgers", 20, 130, 80),
    M("m_recipes_5", "mission", "Libro de recetas", "Recipe book", "recipes_unlocked", 5, 70, 45),
    M("m_upgrade_1", "mission", "Primera mejora", "First upgrade", "upgrades_bought", 1, 30, 20),
    M("m_upgrade_4", "mission", "Cocina equipada", "Equipped kitchen", "upgrades_bought", 4, 90, 55),
    M("m_levels_5", "mission", "Cinco turnos", "Five shifts", "levels_completed", 5, 60, 40),
    M("m_levels_10", "mission", "Diez turnos", "Ten shifts", "levels_completed", 10, 120, 70),
    M("m_streak_5", "mission", "Racha de cinco", "Five in a row", "best_streak", 5, 50, 30),
    M("m_streak_10", "mission", "Racha de diez", "Ten in a row", "best_streak", 10, 110, 65),
    M("m_patties_20", "mission", "Maestro de la plancha", "Grill master", "patties_cooked", 20, 45, 30),
    M("m_correct_30", "mission", "Pedidos correctos", "Correct orders", "orders_correct", 30, 80, 50),
    M("m_shop_1", "mission", "Primera decoración", "First decoration", "items_bought", 1, 30, 20),
    M("m_trays_20", "mission", "Bandejas relucientes", "Spotless trays", "trays_washed", 20, 50, 30),
    M("c_levels_20", "challenge", "Veinte turnos", "Twenty shifts", "levels_completed", 20, 250, 150),
    M("c_stars_30", "challenge", "Treinta estrellas", "Thirty stars", "stars_total", 30, 200, 120),
    M("c_stars_60", "challenge", "Sesenta estrellas", "Sixty stars", "stars_total", 60, 400, 250),
    M("c_three_5", "challenge", "Cinco turnos de tres estrellas", "Five three-star shifts", "three_star_levels", 5, 220, 130),
    M("c_combo_10", "challenge", "Diez menús", "Ten meals", "combos_served", 10, 180, 110),
    M("c_player_5", "challenge", "Chef nivel 5", "Chef level 5", "player_level", 5, 150, 90),
    M("c_player_10", "challenge", "Chef nivel 10", "Chef level 10", "player_level", 10, 350, 200),
    M("c_coins_10000", "challenge", "Diez mil monedas", "Ten thousand coins", "coins_earned", 10000, 500, 300),
    M("c_noburn_10", "challenge", "Diez turnos sin humo", "Ten smoke-free shifts", "no_burn_shifts", 10, 300, 180),
    M("c_streak_20", "challenge", "Racha de veinte", "Twenty in a row", "best_streak", 20, 280, 170),
    M("a_first_burger", "achievement", "Mi primera hamburguesa", "My first burger", "burgers_made", 1, 10, 10),
    M("a_first_client", "achievement", "Primer cliente", "First customer", "customers_served", 1, 10, 10),
    M("a_first_level", "achievement", "Primer turno superado", "First shift cleared", "levels_completed", 1, 20, 15),
    M("a_first_perfect", "achievement", "Sabor perfecto", "Perfect taste", "perfect_burgers", 1, 15, 10),
    M("a_burgers_200", "achievement", "Doscientas hamburguesas", "Two hundred burgers", "burgers_made", 200, 200, 120),
    M("a_clients_200", "achievement", "Doscientos clientes", "Two hundred customers", "customers_served", 200, 200, 120),
    M("a_levels_30", "achievement", "Maestro hamburguesero", "Burger master", "levels_completed", 30, 600, 400),
    M("a_stars_90", "achievement", "Todas las estrellas", "All the stars", "stars_total", 90, 800, 500),
    M("a_recipes_10", "achievement", "Carta completa", "Full menu card", "recipes_unlocked", 10, 300, 200),
    M("a_upgrades_20", "achievement", "Restaurante de lujo", "Luxury restaurant", "upgrades_bought", 20, 400, 250),
]
dump("missions.json", MIS)

# ------------------------------------------------------------------ mejoras
def U(id_, es, en, des, den, max_level, costs, stat, base, per, req):
    return {"id": id_, "name": T(es, en), "desc": T(des, den), "max_level": max_level, "costs": costs,
            "effect": {"stat": stat, "base": base, "per_level": per}, "requires_player_level": req}

UPG = [
    U("grill_capacity", "Plancha grande", "Bigger grill", "Más espacio para cocinar carne a la vez.", "More room to cook patties at once.", 2, [150, 400], "grill_slots", 2, 1, 2),
    U("fryer_capacity", "Freidora doble", "Double fryer", "Dos cestas de patatas a la vez.", "Two fry baskets at once.", 1, [200], "fryer_slots", 1, 1, 3),
    U("cook_speed", "Cocción rápida", "Fast cooking", "La plancha y la freidora cocinan más rápido.", "The grill and fryer cook faster.", 3, [120, 260, 520], "cook_speed", 1.0, 0.15, 2),
    U("prep_space", "Más espacio de montaje", "More prep space", "Desbloquea tablas de montaje extra.", "Unlocks extra assembly boards.", 2, [180, 450], "prep_boards", 1, 1, 3),
    U("storage", "Mayor almacenamiento", "Bigger storage", "Cada caja guarda más ingredientes.", "Every crate holds more ingredients.", 3, [100, 220, 400], "crate_stock", 8, 4, 2),
    U("patience", "Clientes pacientes", "Patient customers", "Los clientes esperan más tiempo.", "Customers wait longer.", 3, [140, 300, 600], "patience_mult", 1.0, 0.12, 4),
    U("service_points", "Tercer puesto de servicio", "Third service point", "Abre otro puesto en el mostrador.", "Opens another counter spot.", 1, [350], "service_points", 2, 1, 5),
    U("coin_bonus", "Caja registradora", "Cash register", "Ganas más monedas por pedido.", "Earn more coins per order.", 3, [200, 450, 900], "coin_mult", 1.0, 0.10, 3),
    U("restaurant_look", "Reforma del local", "Restaurant makeover", "Mejoras visuales: carteles, plantas y luces.", "Visual upgrades: signs, plants and lights.", 3, [250, 600, 1200], "look_level", 0, 1, 4),
    U("recipe_book", "Recetas nuevas", "New recipes", "Añade recetas nuevas a la carta, en la campaña y en el modo libre.", "Adds new recipes to the menu, in the campaign and in free mode.", 2, [260, 620], "recipe_pack", 0, 1, 4),
    U("decor_options", "Catálogo de decoración", "Decor catalog", "Desbloquea colores y decoraciones nuevas en la tienda de personalización.", "Unlocks new colours and decorations in the customization shop.", 1, [300], "decor_options", 0, 1, 5),
    U("dishwasher", "Fregadero rápido", "Fast sink", "Las bandejas sucias se lavan más rápido.", "Dirty trays get washed faster.", 2, [150, 350], "wash_speed", 1.0, 0.5, 6),
]
dump("upgrades.json", UPG)

# ------------------------------------------------------------------ tienda de personalización
def S(id_, cat, es, en, price, unlock, params):
    return {"id": id_, "category": cat, "name": T(es, en), "price": price, "unlock_level": unlock, "params": params}

SHOP = [
    S("wall_cream", "wall", "Crema", "Cream", 0, 1, {"color": "#f3e3c3"}),
    S("wall_mint", "wall", "Menta", "Mint", 80, 2, {"color": "#bfe3c8"}),
    S("wall_sky", "wall", "Cielo", "Sky", 80, 3, {"color": "#bcd8f0"}),
    S("wall_pink", "wall", "Rosa", "Pink", 120, 5, {"color": "#f2c4cf"}),
    S("wall_butter", "wall", "Mantequilla", "Butter", 120, 7, {"color": "#fbe29a"}),
    S("floor_red", "floor", "Damero rojo", "Red checker", 0, 1, {"tex": "floor_red"}),
    S("floor_blue", "floor", "Damero azul", "Blue checker", 150, 3, {"tex": "floor_blue"}),
    S("floor_green", "floor", "Damero verde", "Green checker", 150, 4, {"tex": "floor_green"}),
    S("floor_wood", "floor", "Madera", "Wood", 220, 6, {"tex": "floor_wood"}),
    S("counter_white", "counter", "Blanco", "White", 0, 1, {"color": "#e9e4d8"}),
    S("counter_red", "counter", "Rojo", "Red", 100, 2, {"color": "#c9453a"}),
    S("counter_teal", "counter", "Turquesa", "Teal", 100, 4, {"color": "#3f9a95"}),
    S("counter_dark", "counter", "Chocolate", "Chocolate", 160, 6, {"color": "#4a3a36"}),
    S("tables_wood", "tables", "Madera", "Wood", 0, 1, {"color": "#b57b45"}),
    S("tables_red", "tables", "Rojas", "Red", 90, 2, {"color": "#c9453a"}),
    S("tables_blue", "tables", "Azules", "Blue", 90, 3, {"color": "#3f78b8"}),
    S("tables_white", "tables", "Blancas", "White", 90, 5, {"color": "#f4f1ea"}),
    S("chairs_red", "chairs", "Rojas", "Red", 0, 1, {"color": "#d8392b"}),
    S("chairs_yellow", "chairs", "Amarillas", "Yellow", 60, 2, {"color": "#f2b134"}),
    S("chairs_teal", "chairs", "Turquesa", "Teal", 60, 4, {"color": "#3f9a95"}),
    S("chairs_dark", "chairs", "Oscuras", "Dark", 60, 6, {"color": "#4a3a36"}),
    S("lamps_warm", "lamps", "Cálida", "Warm", 0, 1, {"color": "#ffd9a0"}),
    S("lamps_white", "lamps", "Blanca", "White", 70, 2, {"color": "#fff4e0"}),
    S("lamps_pink", "lamps", "Rosada", "Pink", 100, 4, {"color": "#ffc2d4"}),
    S("lamps_blue", "lamps", "Azulada", "Blue", 100, 6, {"color": "#bfe0ff"}),
    S("sign_red", "sign", "Rojo", "Red", 0, 1, {"color": "#d8392b"}),
    S("sign_gold", "sign", "Dorado", "Gold", 120, 3, {"color": "#f2b134"}),
    S("sign_green", "sign", "Verde", "Green", 120, 5, {"color": "#6fb43f"}),
    S("sign_blue", "sign", "Azul", "Blue", 120, 7, {"color": "#4a90d9"}),
    S("decor_none", "decor", "Sencilla", "Simple", 0, 1, {"plants": False, "posters": False}),
    S("decor_plants", "decor", "Plantas", "Plants", 180, 3, {"plants": True, "posters": False}),
    S("decor_posters", "decor", "Pósters", "Posters", 180, 5, {"plants": False, "posters": True}),
    S("decor_both", "decor", "Plantas y pósters", "Plants and posters", 320, 8, {"plants": True, "posters": True}),
]
# Artículos del «Catálogo de decoración» (mejora decor_options): solo se pueden comprar con la mejora.
def X(item):
    item["requires_upgrade"] = "decor_options"
    return item
SHOP += [
    X(S("wall_coral", "wall", "Coral", "Coral", 160, 6, {"color": "#f4b7a0"})),
    X(S("wall_lavender", "wall", "Lavanda", "Lavender", 160, 8, {"color": "#d6c8ef"})),
    X(S("floor_tiles", "floor", "Azulejo blanco", "White tiles", 260, 7, {"tex": "tiles"})),
    X(S("counter_mustard", "counter", "Mostaza", "Mustard", 180, 6, {"color": "#e0a72e"})),
    X(S("counter_navy", "counter", "Azul marino", "Navy", 180, 9, {"color": "#2f4a6b"})),
    X(S("tables_black", "tables", "Negras", "Black", 150, 7, {"color": "#2e2a2a"})),
    X(S("chairs_pink", "chairs", "Rosas", "Pink", 120, 6, {"color": "#e88aa8"})),
    X(S("lamps_green", "lamps", "Verde suave", "Soft green", 150, 8, {"color": "#d6ffd0"})),
    X(S("sign_purple", "sign", "Morado", "Purple", 180, 9, {"color": "#8e5bd0"})),
    X(S("decor_garden", "decor", "Jardín completo", "Full garden", 420, 10, {"plants": True, "posters": True, "kitchen_plants": True})),
]
dump("shop.json", {"categories": ["wall", "floor", "counter", "tables", "chairs", "lamps", "sign", "decor"], "items": SHOP})

# ------------------------------------------------------------------ clientes
dump("customers.json", {
    "skin": ["#f5cfa0", "#e0ac69", "#c68642", "#8d5524", "#ffdbac"],
    "shirt": ["#d8392b", "#4a90d9", "#6fb43f", "#f2b134", "#8e5bd0", "#e8742f", "#3f9a95", "#e8e1d0"],
    "pants": ["#3b4a6b", "#4a3a36", "#2f5d50", "#5b5b66"],
    "hair": ["#2b1b12", "#5a3a22", "#b8862b", "#a8a8a8", "#c24a2b"],
    "hats": ["none", "cap", "beanie", "none", "none", "cap"],
})

# ------------------------------------------------------------------ distribución del restaurante
bins_south = [("bun_bottom", -2.8), ("bun_top", -1.4), ("lettuce", 0.0), ("tomato", 1.4), ("onion", 2.8)]
LAYOUT = {
    "room": {"x_min": -9.0, "x_max": 9.0, "z_min": -9.0, "z_max": 9.0, "height": 3.4, "split_z": 0.5, "door_x_min": 7.0, "door_x_max": 9.0},
    "player_spawn": {"x": 0.0, "z": 6.0},
    "service_counter": {"x": 0.0, "z": 1.0, "w": 15.2, "d": 1.1},
    "gates": [{"x": -8.3, "z": 1.0, "w": 1.4, "d": 1.1}, {"x": 8.3, "z": 1.0, "w": 1.4, "d": 1.1}],
    "service_points": [{"x": -3.2, "front_z": -0.8, "back_z": -2.4}, {"x": 0.0, "front_z": -0.8, "back_z": -2.4}, {"x": 3.2, "front_z": -0.8, "back_z": -2.4}],
    "grill": {"x": -5.3, "z": 4.5, "w": 2.0, "d": 2.0},
    "stage_a": {"x": -3.5, "z": 4.5, "w": 1.6, "d": 1.0},
    "island": {"x": -0.6, "z": 4.5, "w": 4.2, "d": 1.0},
    "assembly": [{"x": -1.9, "z": 4.5}, {"x": -0.6, "z": 4.5}, {"x": 0.7, "z": 4.5}],
    "fryer": {"x": 4.3, "z": 4.5, "w": 2.0, "d": 1.0},
    "stage_b": {"x": 5.8, "z": 4.5, "w": 1.0, "d": 1.0},
    "bins": (
        [{"ingredient": i, "x": x, "z": 8.5, "group": "shelf"} for i, x in bins_south]
        + [{"ingredient": i, "x": -8.45, "z": z, "group": "fridge"} for i, z in (("patty", 2.6), ("veggie_patty", 4.0), ("bacon", 5.4), ("cheese", 6.8))]
        + [{"ingredient": "fries", "x": 8.5, "z": 3.6, "group": "shelf"}, {"ingredient": "drink", "x": 8.45, "z": 5.0, "group": "dispenser"}]
    ),
    "trash": {"x": 8.6, "z": 6.4},
    "sink": {"x": 8.5, "z": 2.3},
    "tables": [{"x": -7.0, "z": -3.0}, {"x": -7.0, "z": -6.0}, {"x": -2.0, "z": -7.0}, {"x": 2.0, "z": -7.0}, {"x": 6.0, "z": -7.0}],
    "customer_route": {"spawn": {"x": 8.0, "z": -12.5}, "door": {"x": 8.0, "z": -8.2}, "turn_z": -4.8},
}
dump("layout.json", LAYOUT)

# ------------------------------------------------------------------ vista cenital (comprobación visual de la distribución)
S_ = 40; X0 = -10.0; Z0 = -13.5
img = Image.new("RGB", (int(20 * S_), int(23 * S_)), "#efe7d4")
d = ImageDraw.Draw(img)
def P(x, z): return ((x - X0) * S_, (z - Z0) * S_)
def R(cx, cz, w, dd, fill, label=None, outline="#3a2620"):
    a = P(cx - w / 2, cz - dd / 2); b = P(cx + w / 2, cz + dd / 2)
    d.rectangle([a, b], fill=fill, outline=outline)
    if label:
        d.text((a[0] + 2, a[1] + 2), label, fill="#222")
rm = LAYOUT["room"]
d.rectangle([P(rm["x_min"], rm["z_min"]), P(rm["x_max"], rm["split_z"])], fill="#f6dcd6")
d.rectangle([P(rm["x_min"], rm["split_z"]), P(rm["x_max"], rm["z_max"])], fill="#e8eef0")
d.rectangle([P(rm["x_min"], rm["z_min"]), P(rm["x_max"], rm["z_max"])], outline="#000", width=4)
d.rectangle([P(rm["door_x_min"], rm["z_min"] - 0.2), P(rm["door_x_max"], rm["z_min"] + 0.2)], fill="#7cc0ff")
sc = LAYOUT["service_counter"]; R(sc["x"], sc["z"], sc["w"], sc["d"], "#d9d2c0", "mostrador")
for g in LAYOUT["gates"]: R(g["x"], g["z"], g["w"], g["d"], "#aaa")
for i, sp in enumerate(LAYOUT["service_points"]):
    R(sp["x"], 0.95, 1.5, 0.7, "#ffe9a8", "bandeja %d" % (i + 1)); R(sp["x"] + 1.05, 0.8, 0.25, 0.25, "#d8392b")
    d.ellipse([P(sp["x"] - 0.3, sp["front_z"] - 0.3), P(sp["x"] + 0.3, sp["front_z"] + 0.3)], fill="#4a90d9")
    d.ellipse([P(sp["x"] - 0.3, sp["back_z"] - 0.3), P(sp["x"] + 0.3, sp["back_z"] + 0.3)], fill="#8bb8e8")
for k, c in (("grill", "#555"), ("stage_a", "#d9d2c0"), ("island", "#d9d2c0"), ("fryer", "#e0a030"), ("stage_b", "#d9d2c0")):
    e = LAYOUT[k]; R(e["x"], e["z"], e["w"], e["d"], c, k)
for a in LAYOUT["assembly"]: R(a["x"], a["z"], 1.0, 0.7, "#c98a4b")
for b in LAYOUT["bins"]:
    if b["group"] == "shelf": R(b["x"], b["z"], 1.0, 1.0, "#9ec5a0", b["ingredient"][:5])
    else: R(b["x"], b["z"], 1.1, 1.1, "#a9d8d0", b["ingredient"][:5])
R(LAYOUT["trash"]["x"], LAYOUT["trash"]["z"], 0.8, 0.8, "#777", "trash")
R(LAYOUT["sink"]["x"], LAYOUT["sink"]["z"], 1.0, 1.1, "#aad", "sink")
for t in LAYOUT["tables"]:
    d.ellipse([P(t["x"] - 0.7, t["z"] - 0.7), P(t["x"] + 0.7, t["z"] + 0.7)], fill="#b57b45", outline="#3a2620")
ps = LAYOUT["player_spawn"]; d.ellipse([P(ps["x"] - 0.3, ps["z"] - 0.3), P(ps["x"] + 0.3, ps["z"] + 0.3)], fill="#d8392b"); d.text(P(ps["x"] + 0.4, ps["z"]), "jugador", fill="#a00")
cr = LAYOUT["customer_route"]
pts = [P(cr["spawn"]["x"], cr["spawn"]["z"]), P(cr["door"]["x"], cr["door"]["z"]), P(cr["door"]["x"], cr["turn_z"]), P(-3.2, cr["turn_z"]), P(-3.2, -2.4), P(-3.2, -0.8)]
d.line(pts, fill="#2255cc", width=3)
img.save(os.path.join(ROOT, "docs", "layout_topdown.png"))
print("datos OK:", len(ING), "ingredientes,", len(REC) + len(EXTRA_REC), "recetas,", len(LEVELS), "niveles,", len(MIS), "misiones,", len(UPG), "mejoras,", len(SHOP), "artículos")
