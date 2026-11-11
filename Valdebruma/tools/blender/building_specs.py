"""Especificaciones de edificios (ver gen_buildings.py). Coordenadas locales en metros."""

SPECS = []


def add(**kw):
    SPECS.append(kw)


add(name="house_a", kind="house", w=9.0, d=7.0, wall="plaster_white", base="stone_wall", inner="plaster_inner",
    floor_mat="wood_floor", roof=dict(type="gable", mat="roof_clay", pitch=34, axis="x"), shutters=True, shutter_mat="wood_green",
    frame="paint_white", chimneys=[(-2.6, 0.8)],
    openings=[("S", 3.3, "door", dict(kind="door_wood")), ("S", 1.35, "win", dict(w=1.3)), ("S", 6.9, "win", dict(w=1.3)),
              ("N", 2.2, "win", dict(w=1.2)), ("N", 6.6, "win", dict(w=1.2)), ("E", 3.5, "win", dict(w=1.2)), ("W", 2.2, "win", dict(w=1.1))],
    partitions=[(1.0, -3.25, 1.0, 3.25, [(1.5, 0.9), (5.1, 0.85)]), (1.0, 0.3, 4.25, 0.3, [])],
    ivy=[("W", 5.5, 2.6, 2.4), ("N", 0.9, 1.4, 1.8)])
