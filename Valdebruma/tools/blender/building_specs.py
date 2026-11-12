"""Especificaciones de edificios de Valdebruma (ver gen_buildings.py).

Coordenadas locales en metros: X ancho, Y fondo (fachada 'S' en y = -d/2), Z arriba.
openings: (muro, u, 'door'|'win', params) con u desde la izquierda visto desde fuera.
partitions: (x0, y0, x1, y1, [(dist, ancho[, tipo[, llave]])][, planta]).
props: (modelo, x, y, giro[, planta[, z]]).  containers: (modelo, x, y, giro, tabla[, planta[, llave]]).
loot: (x, y, altura, tabla[, planta]).  Giro 0 = frente hacia -Y; 90 = hacia +X; 180 = +Y; -90 = -X.
"""
import math

SPECS = []


def add(**kw):
    SPECS.append(kw)
    return kw


def variant(_src, _name, **over):
    s = dict(_src)
    s.update(over)
    s["name"] = _name
    SPECS.append(s)
    return s


CLAY = dict(type="gable", mat="roof_clay", pitch=34, axis="x")
SLATE = dict(type="gable", mat="roof_slate", pitch=36, axis="x")

# --- casa de pueblo de una planta ---------------------------------------------------------
house_a = add(
    name="house_a", kind="house", label="Casa", w=9.0, d=7.0, wall="plaster_white", base="stone_wall", inner="plaster_inner",
    floor_mat="wood_floor", roof=CLAY, shutters=True, shutter_mat="wood_green", frame="paint_white", chimneys=[(-2.6, 0.8)],
    openings=[("S", 3.3, "door", dict(kind="door_wood")), ("S", 1.35, "win", dict(w=1.3)), ("S", 6.9, "win", dict(w=1.3)),
              ("N", 2.2, "win", dict(w=1.2)), ("N", 6.6, "win", dict(w=1.2)), ("E", 3.5, "win", dict(w=1.2)), ("W", 2.2, "win", dict(w=1.1))],
    partitions=[(1.0, -3.25, 1.0, 3.25, [(1.5, 0.9), (5.1, 0.85)]), (1.0, 0.3, 4.25, 0.3, [])],
    ivy=[("W", 5.5, 2.6, 2.4), ("N", 0.9, 1.4, 1.8)],
    props=[("sofa", -2.6, 2.75, 0), ("rug", -2.4, 1.2, 0), ("tv_old", -0.2, 1.2, -90), ("table", -2.4, -1.3, 0), ("chair", -2.9, -2.0, 180), ("chair", -1.9, -0.6, 0),
           ("stove", -3.93, -0.2, 90), ("kitchen_sink", -3.93, -1.1, 90), ("bed", 3.7, -1.5, 0), ("picture_a", -1.5, 3.22, 0, 0, 1.75),
           ("shelf_unit", 4.0, 1.9, -90), ("lamp_ceiling", -2.0, 0.5, 0, 0, 2.85), ("chair", 1.6, 2.6, 30), ("barrel_wood", 3.6, 0.9, 0)],
    containers=[("kitchen_cabinet", -3.93, -2.35, 90, "house_kitchen"), ("fridge", 0.45, -2.9, 180, "house_kitchen"), ("wardrobe", 1.42, -0.55, 90, "house_bedroom"),
                ("dresser", 2.6, -2.98, 180, "house_bedroom"), ("crate_wood", 1.7, 2.7, 0, "tools"), ("cardboard_box", 2.7, 2.8, 20, "house_any")],
    loot=[(-2.4, -1.3, 0.8, "house_kitchen"), (-1.2, 1.9, 0.03, "house_any"), (2.6, -1.3, 0.03, "house_bedroom"), (3.0, 1.6, 0.03, "tools")])
variant(house_a, "house_a2", wall="plaster_yellow", roof=SLATE, shutter_mat="wood_blue", chimneys=[(2.8, 1.0)], ivy=[("E", 1.2, 1.6, 2.2)], seed=71)
variant(house_a, "house_a3", wall="plaster_pink", base="brick_red", shutter_mat="wood_white", ivy=[("S", 8.3, 1.2, 2.0), ("N", 4.5, 2.5, 2.6)], seed=93)

# --- casa de dos plantas -----------------------------------------------------------------
Z1 = 0.15 + 2.7 + 0.25
add(name="house_b", kind="house", label="Casa de dos plantas", w=8.0, d=7.0, floors=2, wall="plaster_yellow", base="stone_wall", inner="plaster_inner",
    floor_mat="wood_floor", roof=CLAY, shutters=True, shutter_mat="wood_red", chimneys=[(2.9, -0.5)], stairs=(-3.3, 2.7, "x+", 0.95, -1),
    openings=[("S", 4.0, "door", dict(kind="door_wood")), ("S", 1.5, "win", {}), ("S", 6.5, "win", {}),
              ("S", 1.5, "win", dict(floor=1)), ("S", 4.0, "win", dict(floor=1)), ("S", 6.5, "win", dict(floor=1)),
              ("N", 2.0, "win", dict(floor=1)), ("N", 6.0, "win", dict(floor=1)), ("N", 1.6, "win", dict(w=1.0)),
              ("E", 3.5, "win", {}), ("W", 3.5, "win", dict(floor=1)), ("E", 2.0, "win", dict(floor=1))],
    partitions=[(0.9, -3.25, 0.9, 3.25, [(1.6, 0.9)]),
                (-3.75, 1.15, 3.75, 1.15, [(1.3, 0.85), (5.9, 0.85)], 1), (0.0, -3.25, 0.0, 1.15, [], 1)],
    boxes=[((-0.78, 2.2, Z1 + 0.45), (3.1, 0.05, 0.9), "wood_dark", (0, 0, 0), True), ((-2.36, 2.7, Z1 + 0.45), (0.05, 1.0, 0.9), "wood_dark", (0, 0, 0), True)],
    props=[("sofa", -1.6, -2.75, 180), ("armchair", -3.2, -1.2, 90), ("rug", -1.6, -1.3, 0), ("bookshelf", -3.58, 0.6, 90), ("table_small", -1.6, -1.5, 0),
           ("table", 2.4, 1.6, 90), ("chair", 1.7, 1.6, -90), ("chair", 3.1, 1.0, 90), ("stove", 3.42, -1.6, -90), ("kitchen_sink", 3.42, -2.6, -90),
           ("bed", -3.2, -1.8, 0, 1), ("bed", 3.2, -1.8, 0, 1), ("table_small", -2.2, -2.8, 0, 1), ("chair", 1.0, -2.6, 200, 1), ("rug", 1.9, -1.0, 90, 1),
           ("picture_b", 3.72, 2.6, -90, 1, Z1 + 1.6), ("lamp_ceiling", -1.5, -1.2, 0, 0, 2.85)],
    containers=[("kitchen_cabinet", 1.5, -2.93, 180, "house_kitchen"), ("fridge", 1.35, 2.85, 0, "house_kitchen"), ("wardrobe", -0.4, -2.2, -90, "house_bedroom", 1),
                ("dresser", -1.8, 0.85, 0, "house_bedroom", 1), ("wardrobe", 0.42, -2.2, 90, "house_bedroom", 1), ("chest_metal", 2.9, 0.75, 0, "house_any", 1),
                ("cardboard_box", 3.2, 2.7, 10, "house_any", 1)],
    loot=[(2.4, 1.6, 0.8, "house_kitchen"), (-1.6, -1.5, 0.52, "house_any"), (-2.0, -0.5, 0.03, "house_bedroom", 1), (2.0, -0.6, 0.03, "house_bedroom", 1), (2.5, 2.4, 0.03, "house_any", 1)])

# --- casa de ladrillo con porche ------------------------------------------------------------
house_c = add(
    name="house_c", kind="house", label="Casa con porche", w=10.0, d=8.0, wall="brick_red", base="concrete_wall", base_h=0.35, inner="plaster_inner",
    floor_mat="wood_floor", roof=dict(type="hip", mat="roof_slate", pitch=30, axis="x"), frame="paint_white", chimneys=[(-3.0, 1.0)],
    porch=dict(wall="S", u0=3.0, u1=7.0, depth=1.9, gap=1),
    openings=[("S", 5.0, "door", dict(kind="door_wood", step=False)), ("S", 1.7, "win", dict(w=1.4)), ("S", 8.3, "win", dict(w=1.4)), ("N", 2.5, "win", {}), ("N", 7.5, "win", {}),
              ("E", 2.2, "win", {}), ("E", 6.0, "win", {}), ("W", 2.0, "win", {}), ("W", 6.0, "win", {})],
    partitions=[(-4.75, 0.5, 4.75, 0.5, [(2.3, 0.9), (7.2, 0.9)]), (0.0, 0.5, 0.0, 3.75, [])],
    ivy=[("E", 4.0, 2.4, 2.6)],
    props=[("sofa", -2.9, -0.2, 0), ("armchair", -4.1, -2.0, 60), ("rug", -2.8, -1.7, 0), ("tv_old", -2.8, -3.4, 180), ("table", 2.6, -1.8, 0), ("chair", 2.0, -2.5, 180),
           ("chair", 3.2, -2.5, 180), ("chair", 2.6, -1.0, 0), ("bookshelf", 4.58, -0.4, -90), ("stove", -4.42, 2.0, 90), ("kitchen_sink", -4.42, 3.0, 90),
           ("table_small", -1.2, 2.9, 0), ("bed", 3.9, 2.3, 0), ("bed", 1.2, 2.3, 0), ("picture_a", 2.5, -3.72, 180, 0, 1.7), ("lamp_ceiling", 0.0, -1.8, 0, 0, 2.85)],
    containers=[("kitchen_cabinet", -2.6, 3.43, 0, "house_kitchen"), ("fridge", -0.5, 3.35, 0, "house_kitchen"), ("wardrobe", 2.55, 0.9, 180, "house_bedroom"),
                ("dresser", 2.5, 3.5, 0, "house_bedroom"), ("cardboard_box", -4.2, -0.4, 15, "house_any")],
    loot=[(2.6, -1.8, 0.8, "house_kitchen"), (-1.2, 2.9, 0.52, "house_kitchen"), (0.5, -2.5, 0.03, "house_any"), (2.6, 2.0, 0.03, "house_bedroom")])
variant(house_c, "house_c2", wall="plaster_blue", base="stone_wall", roof=dict(type="hip", mat="roof_clay", pitch=30, axis="x"), ivy=[("W", 4.0, 3.0, 2.6)], seed=57)

# --- cabaña del bosque ------------------------------------------------------------------------
cottage = add(
    name="cottage", kind="cabin", label="Cabaña", w=6.0, d=5.0, t=0.2, wall="wood_siding", inner="wood_raw", floor_mat="wood_floor", ceil_mat="wood_raw",
    roof=dict(type="gable", mat="roof_slate", pitch=38, axis="x", under="wood_raw"), open_ceiling=True, frame="wood_dark", chimneys=[(2.0, 1.2, "stone_wall")],
    porch=dict(wall="S", u0=0.4, u1=3.6, depth=1.5, gap=0, roof="roof_slate"),
    openings=[("S", 2.0, "door", dict(kind="door_wood", step=False)), ("S", 4.6, "win", dict(w=1.0)), ("E", 2.5, "win", dict(w=1.0)), ("W", 2.5, "win", dict(w=1.0))],
    props=[("bed", -2.25, 1.2, 0), ("wood_stove", 2.0, 1.95, 0), ("table", 0.8, -1.2, 90), ("chair", 0.1, -1.2, -90), ("stool", 1.6, -0.6, 0), ("rug", -0.4, 0.4, 0),
           ("woodpile", 4.2, -1.5, 90), ("radio_old", 0.8, -1.0, 20, 0, 0.93), ("wall_map", -0.3, 2.28, 0, 0, 1.6)],
    containers=[("chest_metal", -0.8, 2.0, 0, "cabin"), ("dresser", -2.55, -1.6, 90, "cabin"), ("crate_wood", 2.4, -1.9, 0, "tools")],
    loot=[(0.8, -1.2, 0.8, "cabin"), (-0.4, 0.4, 0.03, "cabin"), (1.9, 0.6, 0.03, "tools")])
variant(cottage, "cottage_hidden", wall="wood_grey", seed=13, ivy=[("N", 3.0, 4.0, 2.4), ("E", 3.5, 2.0, 2.2)], label="Cabaña escondida",
        containers=[("chest_metal", -0.8, 2.0, 0, "secret"), ("dresser", -2.55, -1.6, 90, "cabin"), ("crate_wood", 2.4, -1.9, 0, "tools")])

# --- casa de labranza -------------------------------------------------------------------------
add(name="farmhouse", kind="farm", label="Casa de labranza", w=11.0, d=8.0, wall="plaster_worn", base="stone_wall", base_h=1.0, inner="plaster_inner",
    floor_mat="tiles_floor", roof=dict(type="gable", mat="roof_clay", pitch=32, axis="x"), shutters=True, shutter_mat="wood_grey", frame="wood_dark",
    chimneys=[(-3.8, 0.0, "stone_wall"), (3.6, 1.0)],
    openings=[("S", 5.0, "door", dict(kind="door_wood")), ("S", 2.0, "win", {}), ("S", 9.0, "win", {}), ("N", 2.5, "win", {}), ("N", 8.5, "win", {}), ("N", 5.6, "door", dict(kind="door_wood")),
              ("E", 4.0, "win", {}), ("W", 4.0, "win", {})],
    partitions=[(-1.6, -3.75, -1.6, 3.75, [(2.2, 0.9)]), (2.0, -3.75, 2.0, 3.75, [(1.7, 0.9), (5.9, 0.9)]), (2.0, 0.2, 5.25, 0.2, [])],
    ivy=[("W", 2.0, 2.6, 2.8), ("S", 10.2, 1.4, 2.2)],
    props=[("table", -3.4, -1.0, 90), ("chair", -4.1, -1.4, -90), ("chair", -2.7, -0.6, 90), ("chair", -3.4, 0.0, 0), ("stove", -4.92, 2.0, 90), ("kitchen_sink", -4.92, 3.0, 90),
           ("wood_stove", -3.8, -3.3, 180), ("sacks", -2.4, 3.0, 0), ("armchair", 0.9, 2.6, -20), ("rug", 0.2, 1.0, 90), ("pew", 0.2, -3.4, 180),
           ("bed", 4.6, -1.8, 0), ("bed", 4.6, 2.2, 0), ("bed", 2.7, 2.2, 0), ("picture_b", 0.2, 3.72, 0, 0, 1.7), ("lamp_ceiling", -3.4, -0.5, 0, 0, 2.85)],
    containers=[("kitchen_cabinet", -4.2, -3.43, 180, "house_kitchen"), ("fridge", -2.1, 0.6, -90, "house_kitchen"), ("wardrobe", 2.42, -1.2, 90, "house_bedroom"),
                ("dresser", 4.0, -3.5, 180, "house_bedroom"), ("chest_metal", 3.6, 0.6, 0, "farm"), ("crate_wood", -0.9, -0.2, 0, "farm")],
    loot=[(-3.4, -1.0, 0.8, "house_kitchen"), (0.4, 0.2, 0.03, "house_any"), (3.6, -2.0, 0.03, "house_bedroom"), (-2.6, 2.4, 0.03, "farm")])

# --- granero ----------------------------------------------------------------------------------
add(name="barn", kind="barn", label="Granero", w=12.0, d=9.0, fh=4.2, wall="wood_red", base="stone_wall", base_h=0.7, inner="wood_raw", floor_mat="concrete_floor",
    roof=dict(type="gable", mat="metal_corr_rust", pitch=30, axis="y", under="wood_raw"), open_ceiling=True, frame="wood_white", dark=0.42,
    openings=[("S", 6.0, "door", dict(kind="door_barn", w=1.64, h=2.7, step=False)), ("E", 2.0, "door", dict(kind="door_wood")),
              ("N", 3.0, "win", dict(w=1.0, h=0.8, sill=2.4, style="bars")), ("N", 9.0, "win", dict(w=1.0, h=0.8, sill=2.4, style="bars")),
              ("W", 4.5, "win", dict(w=1.0, h=0.8, sill=2.4, style="bars")), ("S", 2.0, "win", dict(w=1.0, h=0.8, sill=2.4, style="bars")), ("S", 10.0, "win", dict(w=1.0, h=0.8, sill=2.4, style="bars"))],
    partitions=[(-5.75, 1.0, -2.0, 1.0, [(1.2, 1.0, "none")])],
    props=[("hay_bale_round", -4.3, 3.0, 20), ("hay_bale_round", -2.9, 3.2, 70), ("hay_bale_square", -4.6, -0.2, 0), ("hay_bale_square", -4.6, -0.75, 4), ("hay_bale_square", -4.5, -0.45, 0, 0, 0.6),
           ("sacks", 4.6, 3.4, 40), ("barrel_wood", 5.2, 1.8, 0), ("barrel_wood", 5.25, 1.0, 0), ("pallet", 3.0, 3.2, 10), ("wheelbarrow", 1.5, 2.8, 150), ("trough", -4.6, -3.2, 0),
           ("workbench", 4.4, -3.75, 180), ("tires", 5.1, -1.2, 0), ("crate_stack", 0.6, 3.5, 0)],
    containers=[("crate_wood", 2.2, -3.5, 5, "farm"), ("crate_wood", 3.2, 3.0, -8, "farm", 0), ("toolbox", 4.4, -3.6, 170, "tools"), ("chest_metal", -2.6, 0.2, 90, "farm")],
    loot=[(0.0, 0.0, 0.03, "farm"), (-3.5, 2.0, 0.03, "farm"), (4.0, -2.5, 0.03, "tools"), (4.4, -3.7, 0.95, "tools")], station="workbench")

# --- cobertizo ---------------------------------------------------------------------------------
add(name="shed", kind="shed", label="Cobertizo", w=4.0, d=3.2, t=0.14, fh=2.3, wall="wood_grey", inner="wood_raw", floor_mat="concrete_floor", ceil_mat="wood_raw",
    roof=dict(type="shed", mat="metal_corrugated", pitch=12, high="N", under="wood_raw", overhang=0.3), open_ceiling=True, frame="wood_dark", dark=0.42,
    openings=[("S", 1.2, "door", dict(kind="door_wood")), ("E", 1.6, "win", dict(w=0.8, h=0.7, sill=1.2))],
    props=[("shelf_unit", 1.0, 1.2, 0), ("barrel_rust", -1.5, 1.1, 0), ("sacks", 1.3, -0.9, 20), ("wheelbarrow", 3.0, 0.3, 30)],
    containers=[("toolbox", -0.6, 1.2, 10, "tools"), ("crate_wood", -1.3, -0.9, 90, "tools")],
    loot=[(0.2, 0.0, 0.03, "tools")])

# --- ultramarinos --------------------------------------------------------------------------------
add(name="shop", kind="shop", label="Ultramarinos Lucero", w=10.0, d=8.0, fh=3.2, wall="plaster_white", wall_S="brick_red", base="concrete_wall", base_h=0.4, inner="plaster_inner",
    floor_mat="tiles_floor", roof=CLAY, frame="paint_green",
    openings=[("S", 5.0, "door", dict(kind="door_glass")), ("S", 2.2, "win", dict(w=2.6, h=1.7, sill=0.5, style="grid", state="glass")),
              ("S", 7.8, "win", dict(w=2.6, h=1.7, sill=0.5, style="grid")), ("N", 8.5, "door", dict(kind="door_metal")), ("N", 3.0, "win", dict(w=1.0, h=0.7, sill=1.6, style="bars")),
              ("E", 6.5, "win", dict(w=1.0, h=0.7, sill=1.6, style="bars"))],
    signs=[dict(wall="S", u=5.0, z=3.02, w=4.6, h=0.5, id="lucero")],
    awnings=[dict(wall="S", u0=0.8, u1=3.6, z=2.5), dict(wall="S", u0=6.4, u1=9.2, z=2.5)],
    partitions=[(-4.75, 1.6, 4.75, 1.6, [(7.5, 0.9, "door_inner")])],
    props=[("shelf_unit", -4.5, -2.6, 90), ("shelf_unit", -4.5, -1.2, 90), ("shelf_unit", -4.5, 0.4, 90), ("shelf_unit", -2.2, -1.6, 90), ("shelf_unit", -1.75, -1.6, -90),
           ("shelf_unit", -2.2, -0.2, 90), ("shelf_unit", -1.75, -0.2, -90), ("shelf_unit", 0.4, 1.35, 0), ("shelf_unit", 1.7, 1.35, 0), ("counter", 3.0, -1.2, -90),
           ("stool", 3.9, -1.2, 0), ("shelf_unit", -3.5, 3.5, 0), ("shelf_unit", -2.2, 3.5, 0), ("pallet", 0.2, 2.9, 0), ("sacks", 0.2, 2.9, 30, 0, 0.3), ("crate_stack", -0.9, 2.2, 90),
           ("lamp_ceiling", 0.0, -1.0, 0, 0, 3.35)],
    containers=[("fridge", 4.4, 0.9, -90, "shop_food"), ("cardboard_box", 2.0, 3.2, 0, "shop_food"), ("cardboard_box", 2.7, 3.3, 30, "shop_food"), ("crate_wood", 4.1, 3.2, 0, "shop_food"),
                ("cardboard_box", 0.2, -2.9, 10, "shop_food")],
    loot=[(-4.4, -2.6, 0.58, "shop_food"), (-4.4, -1.2, 1.0, "shop_food"), (-2.1, -1.6, 0.58, "shop_food"), (-1.8, -0.2, 1.0, "shop_food"), (0.4, 1.3, 0.58, "shop_food"),
          (3.0, -1.6, 1.06, "shop_food"), (-2.2, 3.4, 0.58, "shop_food"), (1.0, -1.5, 0.03, "house_any")])

# --- botica ----------------------------------------------------------------------------------------
add(name="pharmacy", kind="pharmacy", label="Botica del Río", w=8.0, d=7.0, fh=3.1, wall="plaster_white", base="stone_wall", base_h=0.5, inner="plaster_inner", floor_mat="tiles_white",
    roof=SLATE, frame="paint_green",
    openings=[("S", 4.0, "door", dict(kind="door_glass")), ("S", 1.6, "win", dict(w=2.0, h=1.6, sill=0.6, style="grid")), ("S", 6.4, "win", dict(w=2.0, h=1.6, sill=0.6, style="grid")),
              ("N", 2.0, "win", dict(w=1.0, h=0.8, sill=1.5, style="bars")), ("E", 5.4, "win", dict(w=1.0))],
    signs=[dict(wall="S", u=4.0, z=2.92, w=3.6, h=0.5, id="botica")],
    partitions=[(-3.75, 1.2, 3.75, 1.2, [(6.2, 0.9, "door_inner")])],
    props=[("counter", 0.0, 0.2, 0), ("shelf_unit", -2.9, 0.95, 0), ("shelf_unit", -1.6, 0.95, 0), ("shelf_unit", -3.5, -1.6, 90), ("pew", 2.9, -2.9, 180),
           ("desk", -2.6, 2.6, 180), ("office_chair", -2.6, 3.0, 0), ("clinic_bed", 1.0, 2.6, 90), ("lamp_ceiling", 0.0, -1.2, 0, 0, 2.85)],
    containers=[("medicine_cabinet", 3.66, -1.0, -90, "pharmacy"), ("medicine_cabinet", 3.66, 0.0, -90, "pharmacy"), ("medicine_cabinet", -0.5, 3.16, 0, "pharmacy"),
                ("locker", 3.4, 3.0, -90, "pharmacy"), ("filing_cabinet", -0.6, 1.55, 180, "office"), ("cardboard_box", 2.6, 1.8, 10, "pharmacy")],
    loot=[(0.0, 0.3, 1.06, "pharmacy"), (-2.9, 0.9, 0.58, "pharmacy"), (-1.6, 0.9, 1.0, "pharmacy"), (-2.6, 2.6, 0.8, "office"), (1.5, -1.5, 0.03, "pharmacy")])

# --- café ------------------------------------------------------------------------------------------
add(name="cafe", kind="cafe", label="Café La Parada", w=10.0, d=7.0, fh=3.2, wall="plaster_yellow", base="brick_red", base_h=0.5, inner="plaster_inner", floor_mat="tiles_floor",
    roof=CLAY, frame="paint_red",
    openings=[("S", 2.6, "door", dict(kind="door_glass")), ("S", 6.0, "win", dict(w=2.6, h=1.5, sill=0.7, style="grid")), ("S", 8.9, "win", dict(w=1.2)),
              ("W", 3.5, "win", dict(w=1.6)), ("N", 8.6, "door", dict(kind="door_metal")), ("E", 5.2, "win", dict(w=0.9, h=0.7, sill=1.5))],
    signs=[dict(wall="S", u=5.6, z=3.02, w=4.2, h=0.5, id="cafe")], awnings=[dict(wall="S", u0=4.5, u1=7.5, z=2.55)],
    partitions=[(1.8, 0.4, 1.8, 3.25, []), (1.8, 0.4, 4.75, 0.4, [(1.2, 0.9, "door_inner")])],
    props=[("counter", -1.4, 1.9, 0), ("stool", -2.2, 1.2, 0), ("stool", -1.4, 1.2, 0), ("stool", -0.6, 1.2, 0), ("shelf_unit", -1.6, 3.0, 0), ("shelf_unit", -0.3, 3.0, 0),
           ("table", -3.4, -1.6, 90), ("chair", -4.1, -1.6, -90), ("chair", -2.7, -1.6, 90), ("table", 0.6, -2.0, 0), ("chair", 0.6, -2.7, 180), ("chair", 0.0, -1.3, 20),
           ("table", 3.4, -1.8, 0), ("chair", 3.4, -1.1, 0), ("chair", 4.1, -2.2, 250), ("stove", 4.42, 2.6, -90), ("kitchen_sink", 4.42, 1.6, -90), ("radio_old", -0.7, 1.9, 10, 0, 1.03),
           ("picture_a", -4.72, 1.6, 90, 0, 1.7), ("lamp_ceiling", -1.0, -1.0, 0, 0, 2.85)],
    containers=[("fridge", 2.3, 2.9, 90, "shop_food"), ("kitchen_cabinet", 3.2, 2.93, 0, "house_kitchen"), ("cardboard_box", 2.4, 0.9, 0, "shop_food")],
    loot=[(-1.4, 2.0, 1.06, "shop_food"), (-3.4, -1.6, 0.8, "house_kitchen"), (0.6, -2.0, 0.8, "house_kitchen"), (3.4, -1.8, 0.8, "shop_food"), (-2.5, 0.0, 0.03, "house_any")])

# --- casa consistorial (dos plantas) -----------------------------------------------------------------
ZT = 0.15 + 3.0 + 0.25
add(name="townhall", kind="townhall", label="Casa Consistorial", w=14.0, d=9.0, floors=2, fh=3.0, wall="plaster_white", base="stone_wall", base_h=1.1, inner="plaster_inner",
    floor_mat="tiles_floor", floor_mats=["tiles_floor", "wood_floor"], roof=dict(type="hip", mat="roof_clay", pitch=28, axis="x"), frame="wood_dark", stairs=(-2.7, 3.65, "x+", 1.0, -1),
    openings=[("S", 7.0, "door", dict(kind="door_wood", w=1.0)), ("S", 2.2, "win", {}), ("S", 4.4, "win", {}), ("S", 9.6, "win", {}), ("S", 11.8, "win", {}),
              ("S", 2.2, "win", dict(floor=1)), ("S", 4.4, "win", dict(floor=1)), ("S", 7.0, "win", dict(floor=1, w=1.5, h=1.5, sill=0.6)), ("S", 9.6, "win", dict(floor=1)), ("S", 11.8, "win", dict(floor=1)),
              ("N", 2.2, "win", {}), ("N", 11.8, "win", {}), ("N", 2.2, "win", dict(floor=1)), ("N", 11.8, "win", dict(floor=1)),
              ("E", 4.5, "win", {}), ("E", 4.5, "win", dict(floor=1)), ("W", 4.5, "win", {}), ("W", 4.5, "win", dict(floor=1))],
    signs=[dict(wall="S", u=7.0, z=2.9, w=3.6, h=0.5, id="ayuntamiento", back="stone_wall"), dict(wall="E", u=7.4, z=2.2, w=2.4, h=0.34, id="estafeta")],
    partitions=[(-3.0, -4.25, -3.0, 4.25, [(2.5, 0.95)]), (3.0, -4.25, 3.0, 4.25, [(2.5, 0.95)]),
                (-3.0, -4.25, -3.0, 4.25, [(2.0, 0.95, "door_inner", "llave_archivo")], 1), (3.0, -4.25, 3.0, 4.25, [(2.0, 0.95)], 1)],
    boxes=[((0.15, 3.12, ZT + 0.45), (3.7, 0.05, 0.9), "wood_dark", (0, 0, 0), True), ((-1.78, 3.65, ZT + 0.45), (0.05, 1.1, 0.9), "wood_dark", (0, 0, 0), True)],
    props=[("pew", -1.2, -3.9, 180), ("pew", 1.4, -3.9, 180), ("wall_map", 1.0, 4.22, 0, 0, 1.7), ("desk", -5.2, 1.5, 90), ("office_chair", -5.9, 1.5, 90), ("bookshelf", -6.58, -1.0, 90),
           ("bookshelf", -6.58, -2.0, 90), ("chair", -3.8, 1.0, -70), ("counter", 4.6, 0.6, 90), ("shelf_unit", 6.5, -2.4, -90), ("sacks", 5.6, 3.4, 0), ("mailbox", 3.6, -3.6, 0),
           ("table", 5.0, -0.5, 0, 1), ("chair", 4.4, -1.2, 180, 1), ("chair", 5.6, -1.2, 180, 1), ("chair", 5.0, 0.2, 0, 1), ("chair", 6.2, -0.5, 90, 1), ("blackboard", 6.72, 1.5, -90, 1, ZT + 1.5),
           ("wall_map", 4.8, 4.22, 0, 1, ZT + 1.6), ("bookshelf", -6.58, 0.5, 90, 1), ("bookshelf", -6.58, 1.5, 90, 1), ("shelf_unit", -4.4, 3.95, 0, 1), ("table_small", -4.6, -1.0, 0, 1),
           ("armchair", 0.2, -3.4, 180, 1), ("picture_a", 0.0, -4.22, 180, 1, ZT + 1.7), ("lamp_ceiling", 0.0, 0.0, 0, 0, 3.15)],
    containers=[("filing_cabinet", -3.4, 3.6, 180, "office"), ("filing_cabinet", -3.95, 3.6, 180, "office"), ("locker", 6.5, 1.6, -90, "office"), ("locker", 6.5, 2.1, -90, "office"),
                ("crate_wood", 4.0, 3.5, 0, "house_any"), ("filing_cabinet", -3.4, -3.6, 0, "office", 1), ("filing_cabinet", -3.95, -3.6, 0, "office", 1),
                ("chest_metal", -6.2, -3.4, 90, "archive", 1), ("desk", -5.0, 2.6, 180, "office", 1)],
    loot=[(-5.2, 1.5, 0.8, "office"), (4.6, 0.6, 1.06, "office"), (0.0, -1.0, 0.03, "house_any"), (5.0, -0.5, 0.8, "office", 1), (-4.6, -1.0, 0.52, "archive", 1), (0.5, -1.5, 0.03, "house_any", 1)],
    doc="acta_evacuacion")

# --- consultorio -----------------------------------------------------------------------------------
add(name="clinic", kind="clinic", label="Consultorio", w=9.0, d=7.0, wall="plaster_white", base="concrete_wall", base_h=0.4, inner="plaster_inner", floor_mat="tiles_white",
    roof=SLATE, frame="paint_white",
    openings=[("S", 2.4, "door", dict(kind="door_glass")), ("S", 5.4, "win", {}), ("S", 7.6, "win", {}), ("N", 2.0, "win", {}), ("N", 6.8, "win", {}), ("E", 3.5, "win", {})],
    signs=[dict(wall="S", u=2.9, z=2.62, w=3.4, h=0.46, id="consultorio")],
    partitions=[(0.4, -3.25, 0.4, 3.25, [(2.0, 0.9, "door_inner")]), (-4.25, 0.9, 0.4, 0.9, [(3.4, 0.9, "door_inner")])],
    props=[("pew", -3.9, -1.2, 90), ("desk", -1.2, -0.2, 0), ("office_chair", -1.2, 0.3, 0), ("picture_b", -4.22, -2.2, 90, 0, 1.7), ("clinic_bed", 3.6, -1.6, 0), ("clinic_bed", 3.6, 1.8, 0),
           ("table_small", 2.3, -2.6, 0), ("stool", 2.4, 0.2, 0), ("shelf_unit", -3.4, 3.0, 0), ("lamp_ceiling", 2.4, 0.0, 0, 0, 2.85)],
    containers=[("medicine_cabinet", 0.52, 1.6, 90, "clinic"), ("medicine_cabinet", 2.2, 3.16, 0, "clinic"), ("locker", 0.75, -2.9, 90, "clinic"), ("filing_cabinet", -3.9, 1.3, 0, "office"),
                ("cardboard_box", -1.6, 2.8, 20, "clinic"), ("dresser", -0.6, 3.0, 0, "clinic")],
    loot=[(-1.2, -0.2, 0.8, "office"), (2.3, -2.6, 0.52, "clinic"), (3.0, 0.2, 0.03, "clinic"), (-2.6, 2.2, 0.03, "clinic")])

# --- escuela rural ------------------------------------------------------------------------------------
add(name="school", kind="school", label="Escuela rural", w=12.0, d=8.0, wall="plaster_worn", base="brick_red", base_h=0.8, inner="plaster_inner", floor_mat="wood_floor",
    roof=CLAY, frame="paint_green",
    openings=[("S", 1.8, "door", dict(kind="door_wood")), ("S", 5.0, "win", dict(w=1.6, h=1.5)), ("S", 7.6, "win", dict(w=1.6, h=1.5)), ("S", 10.2, "win", dict(w=1.6, h=1.5)),
              ("N", 2.6, "win", dict(w=1.6, h=1.5)), ("N", 5.4, "win", dict(w=1.6, h=1.5)), ("N", 10.0, "win", {}), ("E", 4.0, "win", {})],
    signs=[dict(wall="S", u=7.6, z=2.62, w=4.4, h=0.46, id="escuela")],
    partitions=[(-3.2, -3.75, -3.2, 3.75, [(1.6, 0.9, "door_inner"), (6.0, 0.9, "door_inner")]), (-5.75, 0.6, -3.2, 0.6, [])],
    props=[("blackboard", 5.72, 0.0, -90, 0, 1.6), ("desk", 4.2, 0.0, -90), ("chair", 4.9, 0.0, 90), ("table_small", -1.6, -2.2, 0), ("chair", -2.2, -2.2, -90), ("table_small", 0.2, -2.2, 0),
           ("chair", -0.4, -2.2, -90), ("table_small", 2.0, -2.2, 0), ("chair", 1.4, -2.2, -90), ("table_small", -1.6, 0.0, 0), ("chair", -2.2, 0.0, -90), ("table_small", 0.2, 0.0, 0),
           ("chair", -0.4, 0.2, -110), ("table_small", 2.0, 0.0, 0), ("table_small", -1.6, 2.2, 0), ("chair", -2.2, 2.2, -90), ("table_small", 0.2, 2.2, 0), ("chair", 0.9, 2.9, 200),
           ("bookshelf", -2.9, 3.0, 90), ("wall_map", 0.0, 3.72, 0, 0, 1.7), ("shelf_unit", -5.5, 2.4, 90), ("pew", -4.4, -3.4, 180), ("lamp_ceiling", 0.6, 0.0, 0, 0, 2.85)],
    containers=[("locker", -5.5, -1.0, 90, "school"), ("locker", -5.5, -0.5, 90, "school"), ("cardboard_box", -4.2, 3.2, 0, "school"), ("filing_cabinet", -3.6, 1.1, 180, "office")],
    loot=[(4.2, 0.0, 0.8, "school"), (0.2, -2.2, 0.52, "school"), (2.0, 0.0, 0.52, "school"), (-4.6, 2.0, 0.03, "school")], doc="cuaderno_maestra")

# --- taller mecánico -------------------------------------------------------------------------------------
add(name="workshop", kind="workshop", label="Taller Ardila", w=12.0, d=9.0, fh=3.6, wall="concrete_block", base="concrete_wall", base_h=0.3, inner="concrete_block", floor_mat="concrete_floor",
    roof=dict(type="gable", mat="metal_corrugated", pitch=17, axis="x", under="metal_corrugated", truss_mat="metal_dark", overhang=0.3), open_ceiling=True, frame="paint_blue", dark=0.42,
    openings=[("S", 4.0, "door", dict(kind="none", w=3.6, h=3.0, step=False)), ("S", 9.8, "door", dict(kind="door_metal")), ("N", 3.0, "win", dict(w=1.6, h=0.9, sill=2.2, style="grid")),
              ("N", 9.0, "win", dict(w=1.6, h=0.9, sill=2.2, style="grid")), ("E", 6.5, "win", dict(w=1.2)), ("W", 4.5, "win", dict(w=1.6, h=0.9, sill=2.2, style="grid"))],
    signs=[dict(wall="S", u=6.0, z=3.3, w=5.0, h=0.56, id="taller", back="metal_dark")],
    boxes=[((-2.0, -4.38, 3.0), (3.6, 0.06, 0.9), "metal_shutter"), ((-2.0, -4.4, 2.52), (3.7, 0.1, 0.08), "metal_dark")],
    partitions=[(2.6, -4.25, 2.6, 0.2, [(3.4, 0.9, "door_inner")]), (2.6, 0.2, 5.75, 0.2, [])],
    props=[("car_sedan_red", -2.0, -0.8, 8), ("workbench", -5.35, 1.5, 90), ("tires", -5.2, -3.4, 0), ("tires", -4.4, -3.6, 30), ("barrel_metal", 1.9, 3.8, 0), ("barrel_rust", 1.1, 3.8, 0),
           ("shelf_unit", -3.0, 3.98, 0), ("shelf_unit", -1.7, 3.98, 0), ("generator", 4.4, 3.4, 0), ("pallet", 4.6, 1.4, 0), ("desk", 4.2, -1.0, 180), ("office_chair", 4.2, -0.5, 0),
           ("wall_map", 5.72, -2.0, -90, 0, 1.6), ("cone", -0.2, -3.6, 0)],
    containers=[("toolbox", -5.35, 1.2, 80, "tools", 0), ("chest_metal", -5.3, 3.4, 90, "workshop"), ("locker", 5.5, -3.9, -90, "workshop"), ("locker", 5.5, -3.4, -90, "workshop"),
                ("crate_wood", 0.2, 3.7, 0, "workshop"), ("filing_cabinet", 3.0, -0.6, 90, "office")],
    loot=[(-5.3, 1.9, 0.95, "tools"), (-2.9, 3.9, 0.58, "workshop"), (-1.0, 2.0, 0.03, "workshop"), (4.2, -1.0, 0.8, "office"), (3.6, 2.4, 0.03, "workshop")], station="workbench")

# --- almacén ---------------------------------------------------------------------------------------------
add(name="warehouse", kind="warehouse", label="Almacén", w=20.0, d=12.0, fh=5.0, wall="metal_corrugated", base="concrete_wall", base_h=1.0, inner="metal_corrugated", floor_mat="concrete_floor",
    roof=dict(type="gable", mat="metal_corr_rust", pitch=14, axis="x", under="metal_corrugated", truss_mat="metal_dark", overhang=0.3), open_ceiling=True, frame="paint_dark", dark=0.4,
    openings=[("S", 8.0, "door", dict(kind="none", w=4.0, h=4.0, step=False)), ("S", 17.0, "door", dict(kind="door_metal")), ("N", 3.0, "door", dict(kind="door_metal")),
              ("N", 8.0, "win", dict(w=2.0, h=1.0, sill=3.2, style="grid")), ("N", 13.0, "win", dict(w=2.0, h=1.0, sill=3.2, style="grid")),
              ("S", 3.0, "win", dict(w=2.0, h=1.0, sill=3.2, style="grid")), ("S", 13.5, "win", dict(w=2.0, h=1.0, sill=3.2, style="grid")),
              ("E", 6.0, "win", dict(w=2.0, h=1.0, sill=3.2, style="grid")), ("W", 6.0, "win", dict(w=2.0, h=1.0, sill=3.2, style="grid"))],
    signs=[dict(wall="S", u=14.0, z=4.3, w=6.0, h=0.66, id="cooperativa", back="metal_dark")],
    partitions=[(6.0, 1.5, 6.0, 5.75, [(1.2, 0.9, "door_inner")]), (6.0, 1.5, 9.75, 1.5, [])],
    props=[("shelf_unit", -8.5, 3.0, 0), ("shelf_unit", -7.2, 3.0, 0), ("shelf_unit", -5.9, 3.0, 0), ("shelf_unit", -8.5, 2.55, 180), ("shelf_unit", -7.2, 2.55, 180), ("shelf_unit", -5.9, 2.55, 180),
           ("shelf_unit", -8.5, -0.2, 0), ("shelf_unit", -7.2, -0.2, 0), ("shelf_unit", -5.9, -0.2, 0), ("shelf_unit", -8.5, -0.65, 180), ("shelf_unit", -7.2, -0.65, 180),
           ("pallet", -3.0, 4.2, 0), ("crate_stack", -3.0, 4.2, 0, 0, 0.15), ("pallet", -1.0, 4.4, 8), ("sacks", -1.0, 4.4, 0, 0, 0.15), ("pallet", 1.4, 4.3, -5), ("barrel_metal", 1.1, 4.2, 0, 0, 0.15),
           ("barrel_metal", 1.75, 4.4, 0, 0, 0.15), ("crate_stack", 3.4, -4.6, 180), ("crate_stack", 6.2, -4.7, 170), ("barrel_rust", 8.9, -4.9, 0), ("barrel_rust", 9.0, -4.1, 0),
           ("pipe_stack", -8.3, -4.4, 90), ("tires", 9.0, 0.6, 0), ("desk", 8.2, 4.9, 0), ("office_chair", 8.2, 4.4, 180), ("shelf_unit", 9.5, 3.0, -90), ("generator", 4.6, 0.6, 90)],
    containers=[("crate_wood", -4.4, -4.8, 0, "warehouse"), ("crate_wood", -3.4, -4.9, 12, "warehouse"), ("crate_wood", 0.6, -5.0, 0, "warehouse"), ("chest_metal", 4.9, 4.9, 0, "warehouse"),
                ("locker", 6.4, 2.4, 90, "workshop"), ("filing_cabinet", 6.8, 5.3, 0, "office"), ("cardboard_box", -6.0, -4.6, 30, "warehouse"), ("crate_wood", 2.4, 1.2, 40, "warehouse")],
    loot=[(-8.5, 2.9, 0.58, "warehouse"), (-7.2, 2.6, 1.0, "warehouse"), (-5.9, -0.3, 0.58, "warehouse"), (-8.5, -0.6, 1.0, "warehouse"), (0.0, 0.0, 0.03, "warehouse"),
          (8.2, 4.9, 0.8, "office"), (-2.0, -3.0, 0.03, "warehouse"), (5.0, -2.0, 0.03, "tools")])

# --- fábrica de conservas ------------------------------------------------------------------------------
add(name="factory", kind="factory", label="Conservas Sotoalto", w=24.0, d=14.0, fh=5.5, wall="brick_factory", base="concrete_wall", base_h=0.8, inner="plaster_inner_worn", floor_mat="concrete_floor",
    roof=dict(type="gable", mat="metal_corr_rust", pitch=16, axis="x", under="metal_corrugated", truss_mat="metal_dark", overhang=0.35), open_ceiling=True, frame="paint_dark", dark=0.4,
    chimneys=[(-9.0, 5.0, "brick_factory")],
    openings=[("S", 5.0, "door", dict(kind="none", w=3.6, h=3.6, step=False)), ("S", 15.0, "door", dict(kind="door_metal")), ("N", 20.0, "door", dict(kind="door_metal")),
              ("S", 9.5, "win", dict(w=2.2, h=1.8, sill=2.4, style="grid")), ("S", 12.5, "win", dict(w=2.2, h=1.8, sill=2.4, style="grid")), ("S", 18.5, "win", dict(w=2.2, h=1.8, sill=2.4, style="grid")),
              ("S", 21.5, "win", dict(w=2.2, h=1.8, sill=2.4, style="grid")),
              ("N", 3.0, "win", dict(w=2.2, h=1.8, sill=2.4, style="grid")), ("N", 6.5, "win", dict(w=2.2, h=1.8, sill=2.4, style="grid")), ("N", 10.0, "win", dict(w=2.2, h=1.8, sill=2.4, style="grid")),
              ("N", 13.5, "win", dict(w=2.2, h=1.8, sill=2.4, style="grid")), ("N", 17.0, "win", dict(w=2.2, h=1.8, sill=2.4, style="grid")),
              ("E", 4.0, "win", dict(w=1.4)), ("E", 10.0, "win", dict(w=1.4)), ("W", 7.0, "win", dict(w=2.2, h=1.8, sill=2.4, style="grid"))],
    signs=[dict(wall="S", u=14.0, z=4.9, w=9.0, h=1.1, id="conservas", back="metal_dark")],
    partitions=[(7.0, -6.75, 7.0, 6.75, [(3.2, 1.0, "door_inner"), (10.5, 1.0, "door_inner")]), (7.0, 0.3, 11.75, 0.3, [])],
    props=[("conveyor", -6.0, 2.0, 0), ("conveyor", -1.8, 2.0, 0), ("conveyor", -4.0, -1.5, 0), ("vat", -9.5, 2.0, 0), ("vat", -9.5, -1.6, 90), ("vat", 2.6, 4.2, 180), ("control_panel", 1.2, 0.6, 180),
           ("pallet", 4.6, -5.2, 0), ("crate_stack", 4.6, -5.2, 0, 0, 0.15), ("pallet", 2.4, -5.4, 10), ("barrel_metal", 2.2, -5.5, 0, 0, 0.15), ("barrel_metal", 2.8, -5.3, 0, 0, 0.15),
           ("crate_stack", -10.4, -5.4, 90), ("shelf_unit", -3.0, 6.48, 0), ("shelf_unit", -1.7, 6.48, 0), ("shelf_unit", -0.4, 6.48, 0), ("pipe_stack", 4.0, 5.2, 90), ("sacks", -6.0, -5.6, 0),
           ("pew", 9.4, -6.3, 180), ("desk", 9.6, 4.6, 0), ("office_chair", 9.6, 4.1, 180), ("bookshelf", 11.58, 2.4, -90), ("wall_map", 9.4, 6.72, 0, 0, 1.7), ("table", 9.4, -2.0, 90),
           ("chair", 8.7, -2.0, -90), ("chair", 10.1, -2.4, 90)],
    containers=[("locker", 11.5, -6.2, -90, "factory"), ("locker", 11.5, -5.7, -90, "factory"), ("locker", 11.5, -5.2, -90, "factory"), ("locker", 11.5, -4.7, -90, "factory"),
                ("filing_cabinet", 7.6, 6.2, 0, "office"), ("filing_cabinet", 8.15, 6.2, 0, "office"), ("crate_wood", -7.6, -5.6, 0, "factory"), ("crate_wood", -8.6, -5.5, 10, "factory"),
                ("crate_wood", 0.2, -5.6, 0, "factory"), ("chest_metal", 11.2, 1.0, -90, "archive_office"), ("cardboard_box", -5.0, 3.2, 0, "factory", 0), ("cardboard_box", -1.0, -0.3, 0, "factory")],
    loot=[(-6.0, 2.0, 0.9, "factory"), (-1.8, 2.0, 0.9, "factory"), (-4.0, -1.5, 0.9, "factory"), (-3.0, 6.4, 0.58, "factory"), (-0.4, 6.4, 1.0, "factory"), (0.0, -3.0, 0.03, "factory"),
          (9.6, 4.6, 0.8, "office"), (9.4, -2.0, 0.8, "house_kitchen"), (-8.0, 5.0, 0.03, "tools")], doc="parte_fabrica")

# --- estación de bombeo ---------------------------------------------------------------------------------
add(name="pump_station", kind="pump", label="Estación de bombeo", w=5.5, d=4.5, t=0.22, fh=3.0, wall="concrete_wall", inner="concrete_wall", floor_mat="concrete_floor", ceil_mat="concrete_wall",
    roof=dict(type="flat", mat="t_gravel", parapet=0.3), frame="paint_dark", dark=0.4,
    openings=[("S", 1.3, "door", dict(kind="door_metal")), ("E", 2.2, "win", dict(w=1.0, h=0.7, sill=1.8, style="bars")), ("N", 2.8, "win", dict(w=1.0, h=0.7, sill=1.8, style="bars"))],
    signs=[dict(wall="S", u=3.6, z=2.3, w=2.6, h=0.36, id="bombeo", back="metal_dark")],
    props=[("pump_unit", 0.9, 0.9, 0), ("control_panel", -2.0, 1.3, 90)],
    containers=[("toolbox", 1.6, -1.6, 20, "tools"), ("locker", -2.3, -0.4, 90, "workshop")],
    loot=[(0.0, -1.0, 0.03, "tools")], doc="registro_bombeo")

# --- Estación Liquen (zona de riesgo) --------------------------------------------------------------------
add(name="station_lab", kind="station", label="Estación Liquen", w=14.0, d=8.0, fh=2.9, wall="metal_white", base="concrete_wall", base_h=0.5, inner="plaster_ceiling", floor_mat="tiles_white",
    roof=dict(type="flat", mat="t_gravel", parapet=0.4), frame="paint_dark", dark=0.36,
    openings=[("S", 2.4, "door", dict(kind="door_station", locked="llave_estacion")), ("S", 6.5, "win", dict(w=1.6, h=1.0, sill=1.1, style="bars", state="glass")),
              ("S", 9.6, "win", dict(w=1.6, h=1.0, sill=1.1, style="bars", state="glass")), ("S", 12.3, "win", dict(w=1.2, h=1.0, sill=1.1, style="bars", state="broken")),
              ("N", 3.0, "win", dict(w=1.6, h=1.0, sill=1.1, style="bars")), ("N", 8.0, "win", dict(w=1.6, h=1.0, sill=1.1, style="bars")), ("W", 4.0, "win", dict(w=1.6, h=1.0, sill=1.1, style="bars"))],
    signs=[dict(wall="S", u=8.0, z=2.66, w=5.2, h=0.6, id="estacion", back="metal_dark")],
    partitions=[(-2.4, -3.75, -2.4, 3.75, [(2.2, 0.98, "door_station")]), (3.2, -3.75, 3.2, 3.75, [(5.6, 0.98, "door_station", "llave_estacion")])],
    boxes=[((5.0, 2.0, 3.55), (1.6, 1.2, 0.7), "metal_shutter"), ((-4.5, -1.0, 3.5), (0.9, 0.9, 0.6), "metal_shutter"), ((1.0, 0.5, 3.45), (0.5, 0.5, 0.5), "metal_dark")],
    props=[("desk", -5.0, 2.6, 180), ("office_chair", -5.0, 3.1, 0), ("bookshelf", -6.58, 0.4, 90), ("wall_map", -4.6, 3.72, 0, 0, 1.6), ("pew", -5.6, -3.3, 180),
           ("lab_table", 0.4, 2.9, 0), ("lab_table", 0.4, -0.6, 90), ("stool", 0.4, 2.2, 0), ("stool", -0.4, -0.6, 0), ("control_panel", 2.7, -2.6, -90), ("shelf_unit", -1.9, -2.6, 90),
           ("lichen_cluster", 2.4, 3.2, 0), ("lichen_cluster", -1.6, 3.3, 40, 0, 0.0), ("server_rack", 6.3, 3.2, 0), ("server_rack", 5.6, 3.2, 0), ("server_rack", 4.9, 3.2, 0),
           ("generator", 5.6, -2.9, 180), ("barrel_metal", 3.9, -3.2, 0), ("lichen_cluster", 6.2, -0.4, 80)],
    containers=[("locker", -6.5, -1.6, 90, "lab"), ("locker", -6.5, -1.1, 90, "lab"), ("locker", -6.5, -0.6, 90, "lab"), ("filing_cabinet", -2.9, 3.3, 0, "office"),
                ("medicine_cabinet", 3.08, 1.6, -90, "lab"), ("chest_metal", 6.2, 1.0, -90, "station_secure"), ("crate_wood", 3.9, 0.2, 0, "lab"), ("cardboard_box", -1.6, 0.8, 0, "lab")],
    loot=[(-5.0, 2.6, 0.8, "office"), (0.4, 2.9, 0.95, "lab"), (0.4, -0.6, 0.95, "lab"), (-1.9, -2.6, 0.58, "lab"), (1.4, 1.0, 0.03, "lab"), (5.4, 0.0, 0.03, "station_secure")],
    lights=[(0.4, 0.8, 2.7, [0.55, 0.85, 1.0], 7.0), (5.4, 0.5, 2.7, [0.5, 1.0, 0.75], 6.0)], doc="diario_estacion")


def espadana(b):
    """Espadaña con campana sobre el hastial de la ermita."""
    p = b.p
    hd = b.d / 2
    top = b.H + (b.w / 2) * math.tan(math.radians(b.roof["pitch"]))
    y = -hd + 0.2
    for sx in (-1, 1):
        p.box((sx * 0.75, y, top + 0.7), (0.5, 0.5, 2.6), "stone_wall")
    p.box((0, y, top + 2.2), (2.0, 0.5, 0.5), "stone_wall")
    p.box((0, y, top + 2.6), (1.5, 0.55, 0.3), "stone_wall")
    p.box((0, y, top + 2.95), (0.8, 0.55, 0.4), "stone_wall")
    p.box((0, y, top + 3.6), (0.08, 0.08, 0.9), "metal_dark")
    p.box((0, y, top + 3.75), (0.5, 0.08, 0.08), "metal_dark")
    p.tube([(-0.5, y, top + 1.85), (0.5, y, top + 1.85)], 0.04, "wood_dark", seg=5)
    p.lathe([(0.0, 0.62), (0.12, 0.6), (0.2, 0.4), (0.26, 0.12), (0.34, 0.0), (0.3, 0.0), (0.22, 0.1)], "metal_brass", seg=10, c=(0, y, top + 1.2), close=False)


# --- ermita (zona tranquila) -----------------------------------------------------------------------------
add(name="chapel", kind="chapel", label="Ermita de San Telmo", w=7.0, d=11.0, t=0.4, fh=4.2, wall="stone_wall", inner="plaster_inner", floor_mat="cobble",
    roof=dict(type="gable", mat="roof_slate", pitch=42, axis="y", under="wood_raw", overhang=0.3), open_ceiling=True, frame="wood_dark", dark=0.4, custom=espadana,
    openings=[("S", 3.5, "door", dict(kind="door_wood", w=1.0)), ("E", 2.5, "win", dict(w=0.7, h=1.9, sill=1.3, style="bars", state="glass")), ("E", 5.5, "win", dict(w=0.7, h=1.9, sill=1.3, style="bars", state="glass")),
              ("E", 8.5, "win", dict(w=0.7, h=1.9, sill=1.3, style="bars", state="glass")), ("W", 2.5, "win", dict(w=0.7, h=1.9, sill=1.3, style="bars", state="glass")),
              ("W", 5.5, "win", dict(w=0.7, h=1.9, sill=1.3, style="bars", state="glass")), ("W", 8.5, "win", dict(w=0.7, h=1.9, sill=1.3, style="bars", state="glass")),
              ("N", 3.5, "win", dict(w=0.9, h=1.4, sill=2.2, style="cross", state="glass"))],
    signs=[dict(wall="S", u=1.3, z=1.5, w=1.5, h=0.22, id="ermita", back="stone_wall")],
    props=[("pew", -1.6, -3.0, 180), ("pew", 1.6, -3.0, 180), ("pew", -1.6, -1.6, 180), ("pew", 1.6, -1.6, 180), ("pew", -1.6, -0.2, 180), ("pew", 1.6, -0.2, 180), ("pew", -1.6, 1.2, 180),
           ("altar", 0.0, 4.2, 0), ("rug", 0.0, 2.6, 90), ("table_small", 2.5, 4.4, 0), ("wood_stove", -2.5, 4.4, 0), ("notice_board", 5.2, -4.6, -90)],
    containers=[("chest_metal", 2.5, 3.2, -90, "chapel"), ("crate_wood", -2.6, 2.8, 90, "chapel")],
    loot=[(0.0, 4.2, 1.14, "chapel"), (2.5, 4.4, 0.52, "chapel"), (-1.0, 2.6, 0.03, "house_any")], safe_zone=14.0, doc="carta_ermitano")

# --- caseta de pescadores -----------------------------------------------------------------------------------
add(name="fishing_hut", kind="cabin", label="Caseta de pesca", w=4.6, d=4.0, t=0.16, fh=2.4, wall="wood_grey", inner="wood_raw", floor_mat="wood_floor", ceil_mat="wood_raw",
    roof=dict(type="shed", mat="metal_corr_rust", pitch=14, high="N", under="wood_raw", overhang=0.35), open_ceiling=True, frame="wood_blue", dark=0.44,
    openings=[("S", 1.3, "door", dict(kind="door_wood")), ("S", 3.4, "win", dict(w=1.0)), ("E", 2.0, "win", dict(w=1.0)), ("W", 2.0, "win", dict(w=0.9))],
    props=[("table_small", 1.4, -1.2, 0), ("stool", 0.8, -1.2, 0), ("barrel_wood", -1.8, 1.4, 0), ("shelf_unit", 0.4, 1.6, 0), ("rowboat", -4.2, 0.5, 15)],
    containers=[("crate_wood", 1.6, 1.5, 0, "fishing"), ("cardboard_box", -1.6, -1.2, 30, "fishing")],
    loot=[(1.4, -1.2, 0.52, "fishing"), (0.0, 0.2, 0.03, "fishing")])

# --- caseta forestal --------------------------------------------------------------------------------------------
add(name="ranger_hut", kind="ranger", label="Caseta forestal", w=6.5, d=5.0, t=0.2, wall="wood_green", base="stone_wall", base_h=0.5, inner="wood_raw", floor_mat="wood_floor",
    ceil_mat="wood_raw", roof=dict(type="gable", mat="roof_slate", pitch=34, axis="x", under="wood_raw"), frame="wood_white", chimneys=[(-2.3, 1.0, "stone_wall")],
    porch=dict(wall="S", u0=1.2, u1=5.3, depth=1.5, gap=1, roof="roof_slate"),
    openings=[("S", 3.25, "door", dict(kind="door_wood", step=False)), ("S", 1.0, "win", dict(w=1.0)), ("S", 5.5, "win", dict(w=1.0)), ("E", 2.5, "win", {}), ("W", 2.5, "win", {}), ("N", 4.6, "win", {})],
    signs=[dict(wall="S", u=3.25, z=2.5, w=3.4, h=0.34, id="guarda")],
    props=[("desk", 2.2, 1.9, 0), ("office_chair", 2.2, 1.4, 180), ("radio_old", 2.5, 2.0, -10, 0, 0.93), ("wall_map", 0.6, 2.28, 0, 0, 1.6), ("bunk_bed", -2.55, -1.2, 0), ("wood_stove", -2.3, 1.9, 0),
           ("table_small", 0.0, -0.6, 0), ("stool", 0.6, -0.8, 0), ("rug", 0.2, 0.2, 0)],
    containers=[("locker", 2.85, -1.4, -90, "ranger"), ("toolbox", -0.6, 2.0, 0, "tools"), ("dresser", -0.9, -2.05, 180, "cabin")],
    loot=[(2.2, 1.9, 0.8, "ranger"), (0.0, -0.6, 0.52, "cabin"), (0.8, 0.8, 0.03, "ranger")], doc="cuaderno_guarda")

# --- bodega enterrada (secreto) -------------------------------------------------------------------------------------
add(name="bodega", kind="cellar", label="Bodega vieja", w=5.0, d=6.5, t=0.35, fh=2.3, wall="stone_wall", inner="stone_wall", floor_mat="cobble", ceil_mat="stone_wall",
    roof=dict(type="flat", mat="t_grass", parapet=0.12), frame="wood_dark", dark=0.3,
    openings=[("S", 2.5, "door", dict(kind="door_wood", locked="palanca"))],
    props=[("barrel_wood", -1.6, 2.4, 0), ("barrel_wood", -0.9, 2.5, 0), ("barrel_wood", -1.7, 1.6, 0), ("barrel_wood", 1.7, 2.4, 0), ("sacks", 1.5, 0.6, 0), ("shelf_unit", 1.9, -1.4, -90),
           ("lichen_cluster", -1.5, -2.2, 0)],
    containers=[("chest_metal", 0.4, 2.5, 0, "secret"), ("crate_wood", -1.6, -0.2, 90, "secret"), ("crate_wood", 1.6, -2.4, 0, "house_kitchen")],
    loot=[(0.0, 0.0, 0.03, "secret"), (1.9, -1.4, 1.0, "shop_food")], doc="nota_bodega")
