"""gen_props_world.py — objetos de exterior de Valdebruma (lo importa gen_props.py).

Vallas, postes, señales, pozo, vehículos abandonados, puentes, pasarelas, silo,
torre de agua, repetidor, molino de viento (rotor aparte para animarlo), etc.
"""
import math, random
from mathutils import Vector
import vb
from gen_props import prop, P, fin, reg, sign_quad, legs


@prop
def fences():
    rnd = random.Random(2)
    p = P()
    for x in (-1.25, 1.25):
        p.box((x, 0, 0.55), (0.11, 0.11, 1.3), "wood_grey", rot=(rnd.uniform(-3, 3), rnd.uniform(-3, 3), 0))
    for z in (0.3, 0.65, 1.0):
        p.box((0, 0.06, z), (2.6, 0.03, 0.12), "wood_grey", rot=(0, rnd.uniform(-1.5, 1.5), 0))
    reg("fence_wood", fin(p, "fence_wood", bevel=0.0), collider=[2.6, 1.2, 0.15])
    p = P()
    for x in (-1.5, 1.5):
        p.box((x, 0, 0.6), (0.09, 0.09, 1.3), "wood_grey", rot=(rnd.uniform(-4, 4), 0, 0))
    for z in (0.35, 0.7, 1.05):
        p.box((0, 0, z), (3.0, 0.012, 0.012), "metal_dark")
    reg("fence_wire", fin(p, "fence_wire", bevel=0.0, ao=False), collider=[3.0, 1.2, 0.1])
    p = P()
    for i in range(9):
        w = rnd.uniform(0.28, 0.42)
        for k in range(3):
            h = rnd.uniform(0.26, 0.34)
            p.box((-1.5 + (i + 0.5) * 3.0 / 9 + rnd.uniform(-0.03, 0.03) + (0.16 if k % 2 else 0), rnd.uniform(-0.03, 0.03), 0.15 + k * 0.3),
                  (w, rnd.uniform(0.4, 0.5), h), "stone_wall", rot=(0, 0, rnd.uniform(-4, 4)))
    reg("stone_wall_low", fin(p, "stone_wall_low", bevel=0.02), collider=[3.2, 1.0, 0.5])
    p = P()
    p.lathe([(0.2, 0), (0.42, 0.04), (0.44, 0.75), (0.2, 0.8)], "concrete_wall", seg=4)
    reg("bollard", fin(p, "bollard", bevel=0.0))
    p = P()                                              # barrera de hormigón tipo New Jersey
    prof = [(-0.3, 0), (0.3, 0), (0.3, 0.18), (0.12, 0.42), (0.09, 0.82), (-0.09, 0.82), (-0.12, 0.42), (-0.3, 0.18)]
    p.push(rot=(90, 0, 90))
    p.prism(prof, -1.5, 1.5, "concrete_wall")
    p.pop()
    reg("barrier_concrete", fin(p, "barrier_concrete", bevel=0.0))
    p = P()                                              # quitamiedos
    for x in (-1.9, 0, 1.9):
        p.box((x, 0.05, 0.35), (0.1, 0.06, 0.75), "metal_dark")
    p.box((0, 0, 0.58), (4.0, 0.03, 0.3), "metal_shutter")
    p.box((0, -0.02, 0.58), (4.0, 0.03, 0.08), "metal_shutter")
    reg("guardrail", fin(p, "guardrail", bevel=0.0), collider=[4.0, 0.8, 0.12])
    p = P()                                              # valla de obra a rayas
    for x in (-0.9, 0.9):
        p.box((x, 0, 0.5), (0.06, 0.4, 1.0), "wood_grey", rot=(0, 0, 0))
    p.box((0, 0, 0.85), (2.1, 0.03, 0.2), "paint_red")
    p.box((0, 0, 0.5), (2.1, 0.03, 0.14), "plastic_white")
    reg("barrier_wood", fin(p, "barrier_wood", bevel=0.0), collider=[2.1, 1.0, 0.3])


@prop
def poles():
    p = P()
    p.tube([(0, 0, -0.3), (0.03, 0, 4), (0.05, 0.02, 8.2)], [0.15, 0.13, 0.1], "bark_dead", seg=7, uscale=1.0)
    p.box((0.05, 0.02, 7.6), (1.8, 0.1, 0.12), "wood_dark")
    p.box((0.05, 0.02, 7.0), (1.2, 0.09, 0.1), "wood_dark")
    for x in (-0.8, -0.4, 0.4, 0.8):
        p.lathe([(0.03, 0), (0.05, 0.03), (0.03, 0.07), (0.05, 0.1), (0.02, 0.14)], "ceramic", seg=7, c=(0.05 + x, 0.02, 7.66))
    p.tube([(0.85, 0.02, 7.75), (1.6, 0.1, 7.2), (2.2, 0.15, 5.4)], 0.012, "rubber", seg=4)      # cable caído
    p.box((0.05, 0.11, 6.2), (0.3, 0.14, 0.4), "metal_shutter")
    reg("power_pole", fin(p, "power_pole", bevel=0.0, ao_dist=0.5), collider=[0.3, 8.0, 0.3])
    p = P()
    p.tube([(0, 0, 0), (0, 0, 4.6), (0, -0.25, 5.1), (0, -0.9, 5.2)], [0.08, 0.06, 0.05, 0.045], "metal_dark", seg=7)
    p.lathe([(0.1, 0), (0.12, 0.3), (0.085, 0.36)], "metal_dark", seg=8, close=False)
    p.box((0, -1.05, 5.17), (0.26, 0.5, 0.1), "metal_dark")
    p.box((0, -1.05, 5.11), (0.2, 0.42, 0.03), "lamp_glass")
    reg("street_lamp", fin(p, "street_lamp", bevel=0.0, ao_dist=0.4), collider=[0.25, 5.0, 0.25], light=[0, 5.0, 1.05])


def sign_post(name, sid, w, h, pole_h=2.2, two_poles=False, back="metal_shutter"):
    p = P()
    xs = (-w / 2 + 0.12, w / 2 - 0.12) if two_poles else (0,)
    for x in xs:
        p.tube([(x, 0.04, -0.2), (x, 0.04, pole_h + h / 2)], 0.035, "metal_dark", seg=6)
    p.box((0, 0, pole_h), (w, 0.025, h), back)
    sign_quad(p, sid, w - 0.04, h - 0.04, c=(0, -0.014, pole_h))
    ob = fin(p, name, bevel=0.0, ao=False)
    ob.rotation_euler = (math.radians(random.Random(name).uniform(-2.5, 2.5)), 0, 0)
    reg(name, ob, collider=[0.2, pole_h, 0.2])


@prop
def signs():
    for sid in ("s_sotoalto", "s_fragua", "s_eras", "s_marjal", "s_robledal", "s_collado", "s_cantera", "s_repetidor"):
        sign_post("sign_" + sid[2:], sid, 2.0, 0.5, pole_h=1.9, two_poles=True)
    for sid in ("a_sotoalto_r", "a_sotoalto_l", "a_fragua", "a_eras", "a_marjal", "a_ermita", "a_collado", "a_robledal"):
        sign_post("sign_" + sid, sid, 1.4, 0.35, pole_h=2.3)
    sign_post("sign_warn_bruma", "w_bruma", 0.8, 0.8, pole_h=2.0)
    sign_post("sign_warn_marjal", "w_marjal", 0.8, 0.8, pole_h=2.0)
    sign_post("sign_no_pasar", "no_pasar", 1.6, 0.4, pole_h=1.7, two_poles=True)
    sign_post("sign_puente", "puente", 1.4, 0.35, pole_h=1.8)
    p = P()                                                      # tablón de encargos
    for x in (-1.1, 1.1):
        p.box((x, 0, 1.15), (0.12, 0.12, 2.5), "wood_dark")
    p.box((0, 0, 1.45), (2.1, 0.06, 1.3), "wood_raw")
    p.box((0, -0.05, 2.5), (2.6, 0.5, 0.06), "wood_dark", rot=(12, 0, 0))
    sign_quad(p, "contratos", 1.6, 0.4, c=(0, -0.035, 2.25))
    sign_quad(p, "p_notas", 0.6, 0.8, c=(-0.6, -0.033, 1.45), rot=(0, 3, 0))
    sign_quad(p, "p_evac", 0.6, 0.8, c=(0.08, -0.033, 1.42), rot=(0, -2, 0))
    sign_quad(p, "p_coop", 0.55, 0.73, c=(0.72, -0.033, 1.46), rot=(0, 4, 0))
    reg("notice_board", fin(p, "notice_board", bevel=0.004), station="contracts", collider=[2.4, 2.5, 0.3])
    p = P()                                                      # parada de autobús
    for x in (-1.6, 1.6):
        for y in (-0.1, 1.1):
            p.box((x, y, 1.2), (0.07, 0.07, 2.4), "metal_dark")
    p.box((0, 0.5, 2.45), (3.6, 1.6, 0.07), "metal_corrugated", rot=(4, 0, 0))
    p.box((0, 1.1, 1.25), (3.2, 0.02, 1.9), "glass")
    p.box((-1.6, 0.5, 1.25), (0.02, 1.15, 1.9), "glass")
    p.box((0, 0.85, 0.45), (2.6, 0.38, 0.05), "wood_grey")
    for x in (-1.1, 1.1):
        p.box((x, 0.85, 0.22), (0.05, 0.3, 0.44), "metal_dark")
    sign_quad(p, "bus_linea", 1.6, 0.4, c=(0.6, -0.14, 2.2))
    p.box((0.6, -0.12, 2.2), (1.7, 0.03, 0.46), "metal_dark")
    reg("bus_stop", fin(p, "bus_stop", bevel=0.0, ao_dist=0.5), collider=[3.4, 2.4, 0.2], collider_off=[0, 0, -1.1])


@prop
def water_and_farm():
    rnd = random.Random(8)
    p = P()                                                      # pozo
    for i in range(12):
        a = i * math.pi / 6
        for k in range(3):
            a2 = a + (0.26 if k % 2 else 0)
            p.box((math.cos(a2) * 0.72, math.sin(a2) * 0.72, 0.15 + k * 0.3), (0.3, 0.38, 0.29), "stone_wall", rot=(0, 0, math.degrees(a2) + 90))
    p.lathe([(0.56, 0.02), (0.56, 0.3)], "paint_dark", seg=12, close=False)
    p.cyl((0, 0, 0.3), 0.56, 0.02, "water_still", seg=12)
    for sx in (-1, 1):
        p.box((sx * 0.8, 0, 1.35), (0.12, 0.12, 1.5), "wood_dark")
    p.box((0, 0, 2.3), (2.0, 1.1, 0.06), "wood_raw", rot=(24, 0, 0))
    p.box((0, 0, 2.3), (2.0, 1.1, 0.06), "wood_raw", rot=(-24, 0, 0))
    p.tube([(-0.8, 0, 1.8), (0.95, 0, 1.8)], 0.05, "wood_dark", seg=7)
    p.tube([(0.95, 0, 1.8), (0.95, 0, 1.55), (1.15, 0, 1.55)], 0.015, "metal_dark", seg=5)
    p.tube([(0.1, 0, 1.76), (0.1, 0, 1.15)], 0.01, "rope", seg=4)
    p.lathe([(0.1, 0), (0.13, 0.24)], "metal_shutter", seg=9, c=(0.1, 0, 0.9), close=False)
    reg("well", fin(p, "well", bevel=0.012, ao_dist=0.5), station="water", collider=[1.9, 1.0, 1.9])
    p = P()                                                      # bomba manual
    p.box((0, 0, 0.06), (0.6, 0.6, 0.12), "concrete_floor")
    p.lathe([(0.07, 0.12), (0.07, 0.9), (0.1, 0.95), (0.1, 1.15), (0.05, 1.22)], "metal_green", seg=9)
    p.tube([(0, 0.08, 1.0), (0, 0.3, 1.0), (0, 0.34, 0.88)], 0.03, "metal_green", seg=6)
    p.tube([(0, -0.04, 1.2), (0, -0.2, 1.38), (0, -0.62, 1.1)], 0.018, "metal_dark", seg=5)
    reg("hand_pump", fin(p, "hand_pump", bevel=0.0, smooth=50), station="water", collider=[0.4, 1.3, 0.4])
    p = P()                                                      # abrevadero
    p.box((0, 0, 0.3), (2.0, 0.7, 0.5), "concrete_wall", mats={"+z": None})
    p.box((0, 0, 0.5), (1.84, 0.54, 0.02), "water_still")
    p.box((0, 0, 0.1), (1.84, 0.54, 0.02), "concrete_wall")
    reg("trough", fin(p, "trough", bevel=0.01), station="water")
    p = P()                                                      # espantapájaros
    p.box((0, 0, 1.0), (0.07, 0.07, 2.1), "wood_grey")
    p.box((0, 0, 1.55), (1.5, 0.05, 0.05), "wood_grey")
    p.box((0, 0, 1.3), (0.5, 0.2, 0.7), "fabric_pattern")
    for sx in (-1, 1):
        p.box((sx * 0.5, 0, 1.52), (0.55, 0.16, 0.16), "fabric_pattern", rot=(0, sx * 8, 0))
    p.sphere((0, 0, 1.92), 0.17, "sack_cloth", seg=9, rings=6)
    p.lathe([(0.32, 0), (0.17, 0.03), (0.13, 0.2), (0.0, 0.24)], "thatch", seg=10, c=(0, 0, 2.03), rot=(6, 4, 0))
    reg("scarecrow", fin(p, "scarecrow", bevel=0.0, smooth=55), collider=[0.3, 2.0, 0.3])
    p = P()                                                      # carretilla
    p.push(rot=(90, 0, 90))
    p.prism([(-0.45, 0.32), (0.4, 0.3), (0.55, 0.62), (-0.6, 0.62)], -0.3, 0.3, "metal_rust")
    p.pop()
    p.cyl((0, -0.7, 0.2), 0.2, 0.07, "rubber", seg=12, rot=(0, 90, 0))
    for sx in (-1, 1):
        p.tube([(sx * 0.1, -0.7, 0.2), (sx * 0.28, -0.1, 0.36), (sx * 0.3, 0.95, 0.52)], 0.018, "metal_dark", seg=5)
        p.tube([(sx * 0.28, 0.35, 0.34), (sx * 0.28, 0.4, 0.0)], 0.018, "metal_dark", seg=5)
    reg("wheelbarrow", fin(p, "wheelbarrow", bevel=0.0))
    for nm, kind in (("hay_bale_round", 0), ("hay_bale_square", 1)):
        p = P()
        if kind == 0:
            p.cyl((0, 0, 0.65), 0.65, 1.2, "thatch", seg=14, rot=(0, 90, 0))
        else:
            p.box((0, 0, 0.23), (0.95, 0.46, 0.44), "thatch")
            for x in (-0.25, 0.25):
                p.box((x, 0, 0.23), (0.012, 0.47, 0.45), "rope")
        reg(nm, fin(p, nm, bevel=0.03 if kind else 0.0, smooth=50))
    p = P()                                                      # jardinera
    p.box((0, 0, 0.2), (2.0, 0.8, 0.4), "wood_grey", mats={"+z": None})
    p.box((0, 0, 0.34), (1.9, 0.7, 0.02), "soil")
    reg("planter", fin(p, "planter", bevel=0.0))
    p = P()                                                      # leñera
    for sx in (-1, 1):
        p.box((sx * 0.9, 0, 0.6), (0.08, 0.5, 1.2), "wood_grey")
    for k in range(4):
        for i in range(9 - k % 2):
            p.cyl((-0.72 + i * 0.18 + (0.09 if k % 2 else 0), 0, 0.1 + k * 0.17), 0.085 + rnd.uniform(-0.012, 0.01), 0.5, "bark_oak", seg=7, rot=(90, 0, 0), cap_mat="wood_end")
    reg("woodpile", fin(p, "woodpile", bevel=0.0, smooth=50), harvest="woodpile")


@prop
def street():
    p = P()
    for sx in (-1, 1):
        p.box((sx * 0.72, 0, 0.22), (0.06, 0.42, 0.44), "metal_dark")
        p.box((sx * 0.72, 0.2, 0.62), (0.06, 0.05, 0.44), "metal_dark", rot=(-12, 0, 0))
    for i in range(4):
        p.box((0, -0.15 + i * 0.1, 0.46), (1.6, 0.085, 0.03), "wood_siding")
    for i in range(3):
        p.box((0, 0.22 + i * 0.022, 0.6 + i * 0.11), (1.6, 0.03, 0.085), "wood_siding", rot=(-12, 0, 0))
    reg("bench", fin(p, "bench", bevel=0.004))
    p = P()
    p.box((0, 0, 0.72), (1.8, 0.75, 0.05), "wood_grey")
    for sy in (-1, 1):
        p.box((0, sy * 0.72, 0.44), (1.8, 0.26, 0.045), "wood_grey")
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.box((sx * 0.7, sy * 0.4, 0.36), (0.07, 0.09, 0.95), "wood_grey", rot=(sy * 32, 0, 0))
        p.box((sx * 0.7, 0, 0.42), (0.07, 1.6, 0.07), "wood_grey")
    reg("picnic_table", fin(p, "picnic_table", bevel=0.004))
    p = P()
    p.box((0, 0, 0.7), (1.8, 1.1, 1.2), "metal_green")
    p.box((0, -0.1, 1.36), (1.86, 1.0, 0.06), "paint_dark", rot=(10, 0, 0))
    for sx in (-1, 1):
        p.cyl((sx * 0.7, 0.4, 0.09), 0.09, 0.06, "rubber", seg=8, rot=(0, 90, 0))
        p.cyl((sx * 0.7, -0.4, 0.09), 0.09, 0.06, "rubber", seg=8, rot=(0, 90, 0))
    reg("dumpster", fin(p, "dumpster", bevel=0.012), container={"slots": 10, "lid": {"type": "none"}})
    p = P()
    p.lathe([(0.2, 0), (0.24, 0.7), (0.26, 0.72), (0.26, 0.76)], "metal_shutter", seg=10)
    p.lathe([(0.27, 0.76), (0.2, 0.86), (0.05, 0.9)], "metal_dark", seg=10)
    reg("trash_bin", fin(p, "trash_bin", bevel=0.0, smooth=50), container={"slots": 4, "lid": {"type": "none"}})
    p = P()
    p.box((0, 0, 0.55), (0.07, 0.07, 1.1), "wood_grey")
    p.box((0, -0.05, 1.2), (0.2, 0.42, 0.2), "metal_red")
    p.cyl((0, -0.05, 1.3), 0.1, 0.42, "metal_red", seg=10, rot=(90, 0, 0))
    reg("mailbox", fin(p, "mailbox", bevel=0.0, smooth=50), container={"slots": 3, "lid": {"type": "none"}}, collider=[0.2, 1.3, 0.3])
    p = P()                                                      # puesto de mercado
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.box((sx * 1.2, sy * 0.7, 1.1), (0.07, 0.07, 2.2), "wood_dark")
    p.box((0, 0, 0.85), (2.5, 1.5, 0.05), "wood_raw")
    p.box((0, -0.2, 2.3), (2.9, 2.0, 0.04), "fabric_awning", rot=(12, 0, 0))
    for k in range(3):
        p.box((-0.8 + k * 0.8, 0.1, 0.98), (0.6, 0.45, 0.2), "wood_raw", mats={"+z": None})
    reg("market_stall", fin(p, "market_stall", bevel=0.0, ao_dist=0.5), collider=[2.5, 0.9, 1.5])
    p = P()                                                      # fuente de la plaza
    p.lathe([(1.7, 0), (1.75, 0.5), (1.6, 0.55), (1.5, 0.5), (1.5, 0.15)], "stone_wall", seg=16, close=False)
    p.cyl((0, 0, 0.08), 1.74, 0.16, "stone_wall", seg=16)
    p.cyl((0, 0, 0.4), 1.5, 0.02, "water_still", seg=16)
    p.lathe([(0.3, 0.15), (0.22, 0.4), (0.16, 1.2), (0.5, 1.4), (0.55, 1.5), (0.12, 1.5), (0.1, 1.9), (0.0, 2.0)], "stone_wall", seg=10)
    reg("fountain", fin(p, "fountain", bevel=0.0, smooth=50, ao_dist=0.6), station="water", collider=[3.5, 0.6, 3.5])
    p = P()                                                      # columpio (asiento aparte para balanceo)
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.tube([(sx * 1.2, sy * 0.8, 0), (sx * 1.1, 0, 2.3)], 0.035, "metal_red", seg=6)
    p.tube([(-1.1, 0, 2.3), (1.1, 0, 2.3)], 0.035, "metal_red", seg=6)
    frame = fin(p, "swing", bevel=0.0, ao=False)
    p = P()
    for sx in (-1, 1):
        p.tube([(sx * 0.22, 0, 0), (sx * 0.22, 0, -1.75)], 0.007, "metal_dark", seg=4)
    p.box((0, 0, -1.76), (0.5, 0.18, 0.03), "wood_grey")
    seat = fin(p, "swing_seat", bevel=0.0, ao=False, ground=None)
    seat.location = (0.2, 0, 2.28)
    reg("swing", [frame, seat], solid=False, sway="swing_seat")
    p = P()                                                      # cono y bidón
    p.lathe([(0.2, 0), (0.2, 0.03), (0.13, 0.04), (0.03, 0.6), (0.0, 0.6)], "paint_red", seg=9)
    reg("cone", fin(p, "cone", bevel=0.0, smooth=50), solid=False)


@prop
def camp():
    p = P()                                                      # tienda canadiense
    L, W, Hh = 2.4, 1.7, 1.25
    for sy in (-1, 1):
        p.quad((-W / 2, sy * L / 2, 0), (W / 2, sy * L / 2, 0), (0, sy * L / 2, Hh), (0, sy * L / 2, Hh), "tarp_green")
    for sx in (-1, 1):
        p.quad_n([(sx * W / 2, -L / 2, 0), (sx * W / 2, L / 2, 0), (0, L / 2, Hh), (0, -L / 2, Hh)], "tarp_green", (sx, 0, 0.7))
        p.quad_n([(sx * W / 2 * 0.98, -L / 2, 0), (sx * W / 2 * 0.98, L / 2, 0), (0, L / 2, Hh * 0.98), (0, -L / 2, Hh * 0.98)], "tarp_green", (-sx, 0, -0.7))
    for sy in (-1, 1):
        p.tube([(0, sy * L / 2, 0), (0, sy * L / 2, Hh + 0.05)], 0.015, "metal_steel", seg=4)
        p.tube([(0, sy * L / 2, Hh), (0, sy * (L / 2 + 0.9), 0)], 0.005, "rope", seg=3)
    p.box((0, 0, 0.02), (W * 0.9, L * 0.95, 0.03), "tarp_green")
    reg("tent_camp", fin(p, "tent_camp", bevel=0.0, ao_dist=0.6, weld=0.002), collider=[1.6, 1.0, 2.3])
    rnd = random.Random(12)
    p = P()                                                      # hogar de piedras apagado
    for i in range(9):
        a = i * 2 * math.pi / 9
        p.sphere((math.cos(a) * 0.5, math.sin(a) * 0.5, 0.06), 0.14, "rock_boulder", seg=6, rings=4, scale=(1.0, rnd.uniform(0.7, 1.1), 0.7), rot=(0, 0, rnd.uniform(0, 180)))
    for i in range(4):
        a = i * 1.6 + 0.3
        p.cyl((math.cos(a) * 0.12, math.sin(a) * 0.12, 0.09), 0.05, 0.6, "charcoal", seg=6, rot=(80, 0, math.degrees(a)))
    p.cyl((0, 0, 0.012), 0.42, 0.02, "charcoal", seg=10)
    reg("campfire_ring", fin(p, "campfire_ring", bevel=0.0, smooth=60), solid=False)


def car_body(p, body, cabin, width, mat, cab_inset=0.1):
    p.push(rot=(90, 0, 90))
    p.prism(body, -width / 2, width / 2, mat)
    p.prism(cabin, -width / 2 + cab_inset, width / 2 - cab_inset, "glass_dark", cap_mat="glass_dark")
    p.pop()


def wheel(p, x, y, r, w=0.2, flat=False):
    p.push((x, y, r * (0.86 if flat else 1.0)), (0, 90, 0), (0.86 if flat else 1.0, 1, 1))
    p.lathe([(r * 0.55, -w / 2), (r, -w / 2 + 0.03), (r, w / 2 - 0.03), (r * 0.55, w / 2)], "rubber", seg=12, close=False)
    p.cyl((0, 0, 0), r * 0.56, w * 0.8, "metal_shutter", seg=10)
    p.pop()


@prop
def vehicles():
    for nm, mat in (("car_sedan", "metal_blue"), ("car_sedan_red", "metal_red")):
        p = P()
        body = [(-2.12, 0.34), (2.1, 0.34), (2.16, 0.6), (2.08, 0.8), (1.15, 0.9), (-1.25, 0.92), (-2.08, 0.86), (-2.18, 0.62)]
        cabin = [(-1.2, 0.9), (1.1, 0.88), (0.62, 1.38), (-0.6, 1.4)]
        car_body(p, body, cabin, 1.66, mat)
        p.box((0, 0, 1.4), (1.42, 1.26, 0.04), mat)
        for y in (-1.2, 0.0, 1.1):
            for sx in (-1, 1):
                top = 1.39
                p.box((sx * 0.72, y * 0.52 if y else 0.0, 1.15), (0.05, 0.07, 0.5), mat)
        for sx in (-1, 1):
            for y in (-1.32, 1.3):
                wheel(p, sx * 0.76, y, 0.31, flat=(sx > 0 and y > 0))
            p.box((sx * 0.6, -2.15, 0.68), (0.3, 0.05, 0.12), "lamp_glass")
            p.box((sx * 0.62, 2.14, 0.72), (0.28, 0.05, 0.1), "paint_red")
        p.box((0, -2.2, 0.42), (1.7, 0.1, 0.16), "plastic_black")
        p.box((0, 2.2, 0.44), (1.7, 0.1, 0.16), "plastic_black")
        p.box((0, 0, 0.3), (1.5, 3.9, 0.1), "plastic_black")
        ob = fin(p, nm, bevel=0.02, ao_dist=0.5, smooth=40)
        ob.rotation_euler = (0, math.radians(1.2), 0)
        reg(nm, ob, collider=[1.7, 1.4, 4.3], container={"slots": 6, "lid": {"type": "none"}})
    p = P()                                                      # furgoneta
    body = [(-2.3, 0.36), (2.35, 0.36), (2.4, 0.7), (2.36, 1.95), (-1.35, 1.98), (-1.75, 1.2), (-2.34, 1.05), (-2.4, 0.6)]
    p.push(rot=(90, 0, 90)); p.prism(body, -0.9, 0.9, "metal_white"); p.pop()
    p.box((0, -1.56, 1.52), (1.6, 0.5, 0.6), "glass_dark", rot=(-28, 0, 0))
    for sx in (-1, 1):
        p.box((sx * 0.905, -0.95, 1.45), (0.01, 0.7, 0.5), "glass_dark")
        for y in (-1.5, 1.45):
            wheel(p, sx * 0.82, y, 0.34, flat=(sx < 0 and y > 0))
        p.box((sx * 0.65, -2.38, 0.8), (0.3, 0.05, 0.14), "lamp_glass")
        p.box((sx * 0.8, 2.4, 1.0), (0.12, 0.04, 0.3), "paint_red")
    p.box((0, -2.42, 0.45), (1.84, 0.1, 0.18), "plastic_black")
    p.box((0, 2.42, 0.45), (1.84, 0.1, 0.18), "plastic_black")
    sign_quad(p, "st_coop", 1.5, 0.5, c=(0.906, 0.6, 1.25), rot=(0, 0, 90))
    reg("car_van", fin(p, "car_van", bevel=0.03, ao_dist=0.5, smooth=40), collider=[1.85, 2.0, 4.8], container={"slots": 10, "lid": {"type": "none"}})
    p = P()                                                      # tractor
    p.box((0, -0.8, 1.05), (0.7, 1.6, 0.6), "metal_red")
    p.box((0, -0.8, 0.7), (0.5, 1.9, 0.3), "metal_dark")
    p.box((0, -1.62, 1.05), (0.6, 0.06, 0.5), "metal_dark")
    p.box((0, 0.6, 0.95), (1.0, 1.2, 0.5), "metal_red")
    for sx in (-1, 1):
        wheel(p, sx * 0.78, 0.7, 0.75, w=0.38)
        wheel(p, sx * 0.62, -1.3, 0.4, w=0.2, flat=(sx > 0))
        p.box((sx * 0.78, 0.7, 1.58), (0.42, 1.1, 0.05), "metal_red")
        for y in (0.15, 1.2):
            p.box((sx * 0.5, y, 2.0), (0.05, 0.05, 1.3), "metal_dark")
    p.box((0, 0.67, 2.66), (1.15, 1.25, 0.06), "metal_red")
    p.box((0, 0.75, 1.3), (0.5, 0.5, 0.12), "leather_brown")
    p.box((0, 1.0, 1.6), (0.5, 0.08, 0.5), "leather_brown")
    p.tube([(0, 0.2, 1.3), (0, 0.05, 1.75)], 0.02, "metal_dark", seg=5)
    p.lathe([(0.2, 0), (0.2, 0.03)], "plastic_black", seg=10, c=(0, 0.05, 1.75), rot=(-65, 0, 0), close=True)
    p.tube([(0.28, -1.1, 1.35), (0.28, -1.1, 2.3)], 0.035, "metal_rust", seg=6)
    reg("tractor", fin(p, "tractor", bevel=0.012, ao_dist=0.5), collider=[1.9, 2.4, 3.6])
    p = P()                                                      # remolque agrícola
    p.box((0, 0, 0.85), (1.9, 3.4, 0.1), "wood_grey")
    for sx in (-1, 1):
        p.box((sx * 0.94, 0, 1.15), (0.04, 3.4, 0.5), "wood_green")
        wheel(p, sx * 0.9, 0.3, 0.4, w=0.22)
    for sy in (-1, 1):
        p.box((0, sy * 1.69, 1.15), (1.9, 0.04, 0.5), "wood_green")
    p.tube([(0, -1.7, 0.8), (0, -2.9, 0.55)], 0.04, "metal_dark", seg=6)
    p.box((0, -2.4, 0.3), (0.06, 0.06, 0.6), "metal_dark")
    for k in range(3):
        p.box((-0.4 + k * 0.45, 0.3 * (k - 1), 1.14), (0.95, 0.46, 0.44), "thatch", rot=(0, 0, 12 * k))
    reg("trailer", fin(p, "trailer", bevel=0.0, ao_dist=0.5), collider=[1.95, 1.5, 3.5])
    p = P()                                                      # bote de remos
    def hull(u, v):
        y = (u - 0.5) * 3.6
        wdt = 0.7 * (1 - (2 * u - 1) ** 2) ** 0.6 + 0.04
        a = (v - 0.5) * math.pi
        return (math.sin(a) * wdt, y, 0.45 - math.cos(a) * 0.42 * (0.75 + 0.25 * (1 - abs(2 * u - 1))))
    p.grid(hull, 10, 6, "wood_blue", flip=True)
    p.grid(lambda u, v: tuple(c * (0.94 if i < 1 else 1) + (0.03 if i == 2 else 0) for i, c in enumerate(hull(u, v))), 10, 6, "wood_grey")
    for y in (-0.7, 0.5):
        p.box((0, y, 0.38), (1.15, 0.22, 0.03), "wood_grey")
    p.tube([(0.5, 0.2, 0.5), (1.6, 0.8, 0.3)], 0.02, "wood_grey", seg=5)
    ob = fin(p, "rowboat", bevel=0.0, smooth=60, ao_dist=0.4, ground=None)
    reg("rowboat", ob, collider=[1.4, 0.5, 3.6], container={"slots": 6, "lid": {"type": "none"}})


@prop
def infrastructure():
    rnd = random.Random(31)
    for nm, L, wd in (("boardwalk", 4.0, 1.6), ("dock", 4.0, 2.2)):
        p = P()
        n = int(L / 0.2)
        for i in range(n):
            if nm == "boardwalk" and i in (7, 13):
                continue
            p.box((rnd.uniform(-0.02, 0.02), -L / 2 + (i + 0.5) * L / n, 0.0 + rnd.uniform(-0.006, 0.006)), (wd, L / n - 0.015, 0.04), "wood_grey", rot=(0, 0, rnd.uniform(-1.2, 1.2)))
        for sx in (-1, 1):
            p.box((sx * (wd / 2 - 0.12), 0, -0.09), (0.1, L, 0.14), "wood_dark")
            for y in (-L / 2 + 0.2, L / 2 - 0.2):
                p.tube([(sx * (wd / 2 - 0.05), y, -2.2), (sx * (wd / 2 - 0.05), y, 0.12 if nm == "boardwalk" else 0.6)], 0.08, "bark_dead", seg=6)
        reg(nm, fin(p, nm, bevel=0.0, ao_dist=0.3, ground=None), walk=[wd, L], collider=[wd, 0.2, L], collider_off=[0, -0.08, 0])
    p = P()                                                      # puente de carretera (30 × 7,6 m)
    L, wd = 30.0, 7.6
    p.box((0, 0, -0.3), (wd, L, 0.6), "concrete_wall", mats={"+z": "asphalt"})
    for y in (-9, 0, 9):
        p.box((0, y, -3.6), (wd - 1.2, 1.2, 6.0), "concrete_wall")
        p.box((0, y, -0.75), (wd, 1.6, 0.3), "concrete_wall")
    for sx in (-1, 1):
        p.box((sx * (wd / 2 - 0.25), 0, 0.1), (0.5, L, 0.2), "concrete_floor")
        for i in range(16):
            p.box((sx * (wd / 2 - 0.2), -L / 2 + 0.5 + i * (L - 1) / 15, 0.65), (0.14, 0.14, 0.9), "concrete_wall")
        p.box((sx * (wd / 2 - 0.2), 0, 1.08), (0.2, L, 0.12), "concrete_wall")
        p.box((sx * (wd / 2 - 0.2), 0, 0.62), (0.08, L, 0.08), "metal_rust")
    reg("bridge_road", fin(p, "bridge_road", bevel=0.0, ao_dist=1.0, ground=None), walk=[wd - 1.0, L],
        colliders=[[0, -0.3, 0, wd, 0.6, L], [wd / 2 - 0.2, 0.6, 0, 0.3, 1.2, L], [-wd / 2 + 0.2, 0.6, 0, 0.3, 1.2, L]])
    p = P()                                                      # pasarela de madera (22 × 2,4 m)
    L, wd = 22.0, 2.4
    n = int(L / 0.22)
    for i in range(n):
        if i in (31, 32, 58):
            continue
        p.box((0, -L / 2 + (i + 0.5) * L / n, rnd.uniform(-0.008, 0.008)), (wd, L / n - 0.02, 0.05), "wood_grey", rot=(0, 0, rnd.uniform(-1, 1)))
    for sx in (-1, 1):
        p.box((sx * (wd / 2 - 0.15), 0, -0.14), (0.16, L, 0.22), "wood_dark")
        p.box((sx * (wd / 2 - 0.06), 0, 1.0), (0.08, L, 0.1), "wood_dark")
        for i in range(10):
            y = -L / 2 + 0.3 + i * (L - 0.6) / 9
            p.box((sx * (wd / 2 - 0.06), y, 0.45), (0.1, 0.1, 1.1), "wood_dark")
            if i < 9:
                p.box((sx * (wd / 2 - 0.06), y + (L - 0.6) / 18, 0.5), (0.04, math.hypot((L - 0.6) / 9, 0.9), 0.07), "wood_grey", rot=(math.degrees(math.atan2(0.9, (L - 0.6) / 9)) * (1 if i % 2 else -1), 0, 0))
    for y in (-7, 0, 7):
        for sx in (-1, 1):
            p.tube([(sx * (wd / 2 - 0.2), y, -4.5), (sx * (wd / 2 - 0.2), y, -0.1)], 0.13, "bark_dead", seg=7)
        p.box((0, y, -1.6), (wd, 0.1, 0.18), "wood_dark", rot=(0, 30, 0))
    reg("bridge_wood", fin(p, "bridge_wood", bevel=0.0, ao_dist=0.5, ground=None), walk=[wd - 0.3, L],
        colliders=[[0, -0.1, 0, wd, 0.25, L], [wd / 2 - 0.06, 0.55, 0, 0.12, 1.1, L], [-wd / 2 + 0.06, 0.55, 0, 0.12, 1.1, L]])
    p = P()                                                      # contenedor marítimo
    p.box((0, 0, 1.3), (2.44, 6.06, 2.6), "metal_corr_rust")
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.box((sx * 1.2, sy * 3.0, 1.3), (0.12, 0.12, 2.62), "metal_dark")
    for sx in (-1, 1):
        p.box((sx * 0.6, -3.04, 1.3), (1.16, 0.04, 2.4), "metal_blue")
        p.tube([(sx * 0.3, -3.08, 0.2), (sx * 0.3, -3.08, 2.4)], 0.02, "metal_steel", seg=5)
    sign_quad(p, "st_coop", 2.2, 0.72, c=(1.225, 0, 1.6), rot=(0, 0, 90))
    reg("shipping_container", fin(p, "shipping_container", bevel=0.0, ao_dist=0.6))
    p = P()                                                      # tubos apilados
    for (x, z) in ((-0.62, 0.3), (0, 0.3), (0.62, 0.3), (-0.31, 0.83), (0.31, 0.83)):
        p.lathe([(0.3, -2.0), (0.3, 2.0)], "concrete_wall", seg=12, c=(x, 0, z), rot=(90, 0, 0), close=False)
        p.lathe([(0.25, 2.0), (0.25, -2.0)], "concrete_wall", seg=12, c=(x, 0, z), rot=(90, 0, 0), close=False)
        for sy in (-1, 1):
            p.lathe([(0.25, 0), (0.3, 0)], "concrete_wall", seg=12, c=(x, sy * 2.0, z), rot=(90, 0, 0), close=False)
    reg("pipe_stack", fin(p, "pipe_stack", bevel=0.0, smooth=50, ao_dist=0.5))
    p = P()                                                      # silo
    p.lathe([(2.0, 0), (2.0, 8.0), (1.1, 9.2), (0.3, 9.6), (0.0, 9.7)], "metal_corrugated", seg=18, mats=["metal_corrugated", "metal_shutter", "metal_shutter", "metal_shutter"])
    for z in (2.0, 4.0, 6.0):
        p.lathe([(2.01, z - 0.05), (2.04, z), (2.01, z + 0.05)], "metal_dark", seg=18, close=False)
    for sx in (-1, 1):
        p.tube([(2.06, sx * 0.22, 0.3), (2.06, sx * 0.22, 8.2)], 0.02, "metal_dark", seg=4)
    for k in range(26):
        p.tube([(2.06, -0.22, 0.5 + k * 0.3), (2.06, 0.22, 0.5 + k * 0.3)], 0.012, "metal_dark", seg=4)
    p.lathe([(0.5, 0.1), (0.5, 0.9), (2.0, 1.6)], "metal_shutter", seg=10, c=(0, 0, 0), close=False)
    reg("silo", fin(p, "silo", bevel=0.0, smooth=40, ao_dist=1.0, ao_samples=10), collider=[3.9, 9.0, 3.9])
    p = P()                                                      # torre de agua
    p.lathe([(0.3, 8.6), (2.2, 9.2), (2.3, 9.3), (2.3, 11.8), (1.4, 12.5), (0.0, 12.7)], "metal_rust", seg=16)
    for i in range(4):
        a = i * math.pi / 2 + math.pi / 4
        x, y = math.cos(a), math.sin(a)
        p.tube([(x * 2.6, y * 2.6, 0), (x * 1.9, y * 1.9, 9.2)], 0.09, "metal_dark", seg=6)
        a2 = a + math.pi / 2
        x2, y2 = math.cos(a2), math.sin(a2)
        for k in range(3):
            f0, f1 = k / 3, (k + 1) / 3
            r0, r1 = 2.6 - 0.7 * f0, 2.6 - 0.7 * f1
            p.tube([(x * r0, y * r0, 9.2 * f0), (x2 * r1, y2 * r1, 9.2 * f1)], 0.035, "metal_dark", seg=4)
            p.tube([(x * r1, y * r1, 9.2 * f1), (x2 * r1, y2 * r1, 9.2 * f1)], 0.035, "metal_dark", seg=4)
    p.tube([(0, 0, 0), (0, 0, 8.7)], 0.12, "metal_rust", seg=7)
    reg("water_tower", fin(p, "water_tower", bevel=0.0, smooth=45, ao_dist=1.0, ao_samples=8), collider=[1.0, 9.0, 1.0])
    p = P()                                                      # repetidor de radio (celosía de 30 m)
    Hm = 30.0
    def leg(i, z):
        a = i * 2 * math.pi / 3
        r = 1.6 - 1.3 * (z / Hm)
        return (math.cos(a) * r, math.sin(a) * r, z)
    for i in range(3):
        p.tube([leg(i, 0), leg(i, Hm)], 0.06, "metal_red", seg=5)
        for k in range(10):
            z0, z1 = Hm * k / 10, Hm * (k + 1) / 10
            j = (i + 1) % 3
            p.tube([leg(i, z0), leg(j, z1)], 0.025, "metal_white" if k % 2 else "metal_red", seg=3)
            p.tube([leg(i, z1), leg(j, z1)], 0.025, "metal_white" if k % 2 else "metal_red", seg=3)
    p.tube([(0, 0, Hm), (0, 0, Hm + 4)], 0.03, "metal_steel", seg=4)
    for (z, a) in ((24, 0.5), (26.5, 2.6), (21, 4.4)):
        p.lathe([(0.0, 0), (0.45, 0.08), (0.6, 0.25)], "metal_white", seg=10, c=(math.cos(a) * 0.9, math.sin(a) * 0.9, z), rot=(90, 0, math.degrees(a) - 90), close=False)
    p.box((0, 0, 0.15), (3.6, 3.6, 0.3), "concrete_floor")
    p.box((1.2, -1.0, 1.1), (1.0, 0.7, 1.6), "metal_shutter")
    p.sphere((0, 0, Hm + 4.05), 0.09, "led_red", seg=6, rings=4)
    reg("radio_mast", fin(p, "radio_mast", bevel=0.0, ao=False), collider=[3.6, 2.0, 3.6], collider_off=[0, 0, 0], light=[0, 34.0, 0])
    p = P()                                                      # molino de viento (bomba de agua)
    Ht = 9.0
    for i in range(4):
        a = i * math.pi / 2 + math.pi / 4
        x, y = math.cos(a), math.sin(a)
        p.tube([(x * 1.5, y * 1.5, 0), (x * 0.3, y * 0.3, Ht)], 0.05, "metal_dark", seg=5)
        a2 = a + math.pi / 2
        x2, y2 = math.cos(a2), math.sin(a2)
        for k in range(4):
            f0, f1 = k / 4, (k + 1) / 4
            r0, r1 = 1.5 - 1.2 * f0, 1.5 - 1.2 * f1
            p.tube([(x * r0, y * r0, Ht * f0), (x2 * r1, y2 * r1, Ht * f1)], 0.02, "metal_dark", seg=3)
            p.tube([(x * r1, y * r1, Ht * f1), (x2 * r1, y2 * r1, Ht * f1)], 0.02, "metal_dark", seg=3)
    p.box((0, 0, Ht + 0.1), (0.5, 0.9, 0.3), "metal_rust")
    p.box((0, 1.5, Ht + 0.35), (0.03, 1.8, 0.9), "metal_corr_rust")
    p.tube([(0, 0, 0.2), (0, 0, Ht)], 0.03, "metal_rust", seg=5)
    p.box((0, 0, 0.3), (1.0, 1.0, 0.6), "concrete_wall")
    tower = fin(p, "windpump", bevel=0.0, ao=False)
    p = P()
    p.cyl((0, 0, 0), 0.16, 0.2, "metal_dark", seg=8, rot=(90, 0, 0))
    for i in range(14):
        a = i * 2 * math.pi / 14
        p.push(rot=(0, math.degrees(a), 0))
        p.box((0, 0, 0.95), (0.3, 0.015, 1.2), "metal_shutter", rot=(0, 0, 24))
        p.pop()
    p.lathe([(1.5, -0.01), (1.54, 0.0), (1.5, 0.01)], "metal_dark", seg=20, rot=(90, 0, 0), close=False)
    rotor = fin(p, "windpump_rotor", bevel=0.0, ao=False, ground=None)
    rotor.location = (0, -0.6, Ht + 0.1)
    reg("windpump", [tower, rotor], spin="windpump_rotor", station="water", collider=[1.2, 2.0, 1.2])


@prop
def bruma_flora():
    rnd = random.Random(44)
    p = P()                                                      # liquen brumal (emisivo)
    for i in range(9):
        a, r = rnd.uniform(0, 6.28), rnd.uniform(0.0, 0.5)
        s = rnd.uniform(0.5, 1.2)
        x, y = math.cos(a) * r, math.sin(a) * r
        p.lathe([(0.0, 0.0), (0.16 * s, 0.02), (0.2 * s, 0.07 * s), (0.13 * s, 0.1 * s), (0.05 * s, 0.07 * s), (0.0, 0.08 * s)], "lichen_glow", seg=8, c=(x, y, 0), rot=(rnd.uniform(-14, 14), rnd.uniform(-14, 14), 0), close=False)
    for i in range(5):
        a, r = rnd.uniform(0, 6.28), rnd.uniform(0.1, 0.4)
        x, y = math.cos(a) * r, math.sin(a) * r
        h = rnd.uniform(0.2, 0.5)
        p.tube([(x, y, 0), (x + rnd.uniform(-0.05, 0.05), y + rnd.uniform(-0.05, 0.05), h)], [0.012, 0.008], "lichen_stalk", seg=4, cap=False)
        p.sphere((x, y, h + 0.02), 0.035, "lichen_glow", seg=6, rings=4)
    reg("lichen_cluster", fin(p, "lichen_cluster", bevel=0.0, smooth=70, ao=False), solid=False, harvest="lichen", light=[0, 0.3, 0])
    p = P()                                                      # vaina de esporas
    p.lathe([(0.0, 0.0), (0.18, 0.05), (0.3, 0.3), (0.32, 0.55), (0.22, 0.85), (0.08, 1.0), (0.0, 1.02)], "spore_pod", seg=10, close=False)
    for i in range(5):
        a = i * 1.2566
        p.tube([(math.cos(a) * 0.25, math.sin(a) * 0.25, 0.1), (math.cos(a) * 0.55, math.sin(a) * 0.55, 0.0), (math.cos(a) * 0.8, math.sin(a) * 0.8, -0.1)], [0.05, 0.035, 0.01], "lichen_stalk", seg=5, cap=False)
    for i in range(6):
        a = i * 1.05
        p.sphere((math.cos(a) * 0.3, math.sin(a) * 0.3, 0.45 + 0.1 * math.sin(i * 2.1)), 0.05, "lichen_glow", seg=6, rings=4)
    reg("spore_pod", fin(p, "spore_pod", bevel=0.0, smooth=70, ao_dist=0.3), collider=[0.6, 1.0, 0.6])
