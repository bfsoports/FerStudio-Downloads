#!/usr/bin/env python3
"""build_world.py — genera el valle de Valdebruma (datos compartidos cliente/servidor).

Uso: python3 tools/world/build_world.py
Entradas: data/buildings/*.json y data/models/*.json (tamaños de modelos).
Salidas:
  data/world/height.bin      float32 641×641 (2 m/muestra), fila = z, columna = x
  data/world/veg.bin         float32 [tipo, x, y, z, giro, escala] por instancia, ordenado por sector
  data/world/world.json      regiones, carreteras, edificios, objetos, recolección, criaturas, lugares…
  assets/textures/gen/world_splat.png   R hojarasca, G tierra/barro, B roca (resto = hierba)
  assets/textures/gen/world_tint.png    tinte macro del terreno (128 = neutro)
  data/world/regions.bin     uint8 128×128, id de región por celda de 10 m
  assets/textures/gen/world_map.png     mapa ilustrado para la pantalla de mapa
Coordenadas: x este, z sur, 0..1280 m. Norte = −z. Determinista (semillas fijas).
"""
import json, math, os, random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SIZE, N, STEP, SECTOR = 1280.0, 641, 2.0, 64.0
WL = 10.0                                   # nivel del agua
rng = np.random.default_rng(20261111)
rnd = random.Random(20261111)


# ----------------------------------------------------------------------------- utilidades
def lattice_noise(n, cells, seed):
    r = np.random.default_rng(seed)
    g = r.random((cells + 2, cells + 2))
    idx = np.linspace(0, cells, n)
    i0 = np.floor(idx).astype(int); f = idx - i0
    f = f * f * (3 - 2 * f)
    a = g[np.ix_(i0, i0)] * (1 - f)[None, :] + g[np.ix_(i0, i0 + 1)] * f[None, :]
    b = g[np.ix_(i0 + 1, i0)] * (1 - f)[None, :] + g[np.ix_(i0 + 1, i0 + 1)] * f[None, :]
    return a * (1 - f)[:, None] + b * f[:, None]


def fbm(n, wavelength, octaves, seed):
    out = np.zeros((n, n)); amp, tot = 1.0, 0.0
    cells = max(1, int(round(SIZE / wavelength)))
    for o in range(octaves):
        out += amp * (lattice_noise(n, cells * 2 ** o, seed + o * 101) - 0.5)
        tot += amp; amp *= 0.5
    return out / tot


def sstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def dist_polyline(X, Z, pts):
    d = np.full(X.shape, 1e9)
    for (x0, z0), (x1, z1) in zip(pts, pts[1:]):
        vx, vz = x1 - x0, z1 - z0
        t = np.clip(((X - x0) * vx + (Z - z0) * vz) / (vx * vx + vz * vz + 1e-9), 0, 1)
        d = np.minimum(d, np.hypot(X - (x0 + t * vx), Z - (z0 + t * vz)))
    return d


def resample(pts, step):
    out = [pts[0]]
    for (x0, z0), (x1, z1) in zip(pts, pts[1:]):
        L = math.hypot(x1 - x0, z1 - z0)
        k = max(1, int(round(L / step)))
        for i in range(1, k + 1):
            out.append((x0 + (x1 - x0) * i / k, z0 + (z1 - z0) * i / k))
    return out


def smooth_path(pts, it=3):
    """Suaviza esquinas (Chaikin) conservando los extremos."""
    for _ in range(it):
        out = [pts[0]]
        for a, b in zip(pts, pts[1:]):
            out.append((a[0] * 0.75 + b[0] * 0.25, a[1] * 0.75 + b[1] * 0.25))
            out.append((a[0] * 0.25 + b[0] * 0.75, a[1] * 0.25 + b[1] * 0.75))
        out.append(pts[-1]); pts = out
    return pts


ax = np.linspace(0, SIZE, N)
X, Z = np.meshgrid(ax, ax)                 # H[z, x]


def sample(H, x, z):
    fx, fz = min(max(x / STEP, 0), N - 1.001), min(max(z / STEP, 0), N - 1.001)
    i, j = int(fx), int(fz); u, v = fx - i, fz - j
    return (H[j, i] * (1 - u) + H[j, i + 1] * u) * (1 - v) + (H[j + 1, i] * (1 - u) + H[j + 1, i + 1] * u) * v


# ----------------------------------------------------------------------------- diseño del valle
RIVER = smooth_path([(800, -20), (790, 120), (838, 250), (828, 330), (822, 420), (858, 540), (850, 650), (888, 780), (872, 920), (884, 1000), (908, 1080), (892, 1190), (900, 1300)], 3)
ROADS = [   # id, tipo, puntos
    ("principal", "asphalt", [(-10, 1012), (150, 1006), (300, 986), (430, 930), (520, 822), (580, 702), (616, 656), (640, 650), (760, 650), (835, 650), (865, 650), (960, 655), (1050, 700), (1120, 790), (1146, 880)]),
    ("fragua", "asphalt", [(640, 650), (646, 600), (650, 540), (660, 420), (670, 300), (690, 196)]),
    ("eras", "asphalt", [(640, 650), (646, 700), (650, 760), (640, 880), (660, 1000), (700, 1100)]),
    ("robledal", "dirt", [(430, 930), (380, 800), (330, 650), (300, 500), (262, 380), (240, 276)]),
    ("ermita", "dirt", [(1050, 700), (1100, 622), (1132, 566)]),
    ("pasarela", "dirt", [(670, 300), (760, 300), (816, 300)]),
    ("vado", "dirt", [(700, 1100), (800, 1042), (868, 1002), (900, 1000), (960, 992), (1040, 1022), (1100, 1090), (1146, 1128)]),
    ("orilla", "path", [(960, 655), (982, 560), (1000, 482)]),
    ("bodega", "path", [(300, 500), (212, 470), (156, 440)]),
    ("escondida", "path", [(330, 650), (230, 652), (140, 646)]),
    ("mirador", "path", [(262, 380), (180, 350), (124, 334)]),
    ("finca", "dirt", [(640, 900), (628, 912), (622, 930)]),
]
ROAD_W = {"asphalt": 6.4, "dirt": 3.4, "path": 1.8}
BRIDGES = [("bridge_road", 850.0, 650.0, 90.0, 30.0), ("bridge_wood", 829.0, 300.0, 90.0, 22.0)]
BOARDWALK = [(840 + i * 4.0, 300.0) for i in range(0, 53)]          # hasta x ≈ 1048
MARSH_C, MARSH_R = (1030.0, 330.0), (200.0, 185.0)
LAKE_C, LAKE_R = (1105.0, 235.0), 78.0
ISLET = (1064.0, 303.0, 30.0)

# edificios: (tipo, x, z, giro)  — el frente (+Z local) mira hacia (sin giro, cos giro)
BUILDINGS = [
    ("cottage", 238, 976, 0), ("shed", 290, 982, 0),
    ("shop", 612, 637, 0), ("cafe", 611, 663, 180), ("pharmacy", 626, 663.5, 180), ("clinic", 672, 663, 180), ("school", 696, 664, 180),
    ("townhall", 673, 597, 0), ("house_a", 722, 637, 0), ("house_c", 745, 636, 0), ("house_b", 724, 663, 180), ("house_a2", 745, 663, 180),
    ("house_a3", 634, 598, 90), ("house_c2", 633, 571, 90), ("workshop", 663, 566, -90), ("house_a", 663, 702, -90), ("house_c", 663, 727, -90),
    ("house_a2", 630, 708, 90), ("shed", 618, 724, 90), ("house_b", 629, 740, 90),
    ("factory", 695, 250, -90), ("warehouse", 649, 342, 90), ("warehouse", 722, 316, 180), ("pump_station", 792, 291, 0), ("shed", 668, 204, 0),
    ("farmhouse", 617, 896, 90), ("barn", 610, 934, 90), ("shed", 596, 910, 90), ("farmhouse", 696, 1040, -90), ("barn", 709, 1073, -90), ("cottage", 520, 1012, 0),
    ("ranger_hut", 240, 256, 0), ("cottage_hidden", 122, 640, 90), ("bodega", 142, 424, 0),
    ("chapel", 1138, 540, 0), ("fishing_hut", 1004, 470, 0), ("station_lab", 1064, 304.6, -90), ("shed", 1150, 1140, 180), ("shed", 1136, 892, -90),
]
# objetos sueltos: (modelo, x, z, giro)
PROPS = [
    ("notice_board", 262, 993, 0), ("bus_stop", 226, 999, 0), ("tent_camp", 252, 968, 20), ("tent_camp", 262, 962, -30), ("tent_camp", 272, 972, 80),
    ("campfire_ring", 262, 978, 0), ("picnic_table", 276, 990, 10), ("picnic_table", 246, 990, -6), ("hand_pump", 284, 996, 0), ("sign_collado", 204, 998, 0),
    ("woodpile", 246, 970, 90), ("bench", 268, 984, 180), ("car_van", 300, 996, 80), ("trash_bin", 232, 994, 0),
    ("fountain", 668, 626, 0), ("market_stall", 656, 616, 20), ("market_stall", 682, 632, -70), ("bench", 660, 636, 180), ("bench", 678, 614, 0),
    ("street_lamp", 652, 642, 0), ("street_lamp", 690, 642, 0), ("street_lamp", 612, 642, 0), ("street_lamp", 740, 642, 0), ("street_lamp", 655, 580, 90),
    ("bus_stop", 700, 643, 0), ("mailbox", 688, 606, 0), ("sign_sotoalto", 566, 716, 40), ("sign_sotoalto", 778, 644, 90), ("car_sedan", 704, 652, 96),
    ("car_sedan_red", 644, 622, 8), ("dumpster", 622, 646, 90), ("trash_bin", 652, 656, 0), ("sign_a_fragua", 650, 636, 180), ("sign_a_eras", 636, 664, 0),
    ("swing", 708, 676, 0), ("bench", 700, 680, 180), ("barrier_wood", 833, 648, 90), ("sign_puente", 826, 644, 90), ("cone", 836, 652, 0), ("car_sedan", 880, 652, 78),
    ("silo", 716, 222, 0), ("silo", 716, 214, 0), ("water_tower", 640, 250, 0), ("shipping_container", 668, 352, 0), ("shipping_container", 672, 360, 6),
    ("shipping_container", 736, 290, 90), ("pipe_stack", 700, 300, 90), ("barrel_metal", 676, 268, 0), ("barrel_rust", 677, 269.2, 0), ("pallet", 680, 232, 20),
    ("crate_stack", 706, 286, 10), ("sign_fragua", 656, 430, 180), ("car_van", 672, 274, 170), ("tractor", 740, 322, 40), ("dumpster", 664, 322, 0),
    ("generator", 786, 292, 90), ("sign_warn_marjal", 838, 296, 90), ("sign_a_marjal", 676, 304, 180), ("street_lamp", 676, 250, 90), ("street_lamp", 664, 330, -90),
    ("well", 630, 916, 0), ("tractor", 598, 950, 120), ("trailer", 592, 958, 110), ("hay_bale_round", 570, 940, 0), ("hay_bale_round", 552, 962, 40),
    ("hay_bale_round", 530, 930, 90), ("scarecrow", 540, 960, 30), ("trough", 604, 918, 90), ("sign_eras", 646, 846, 180), ("windpump", 724, 1052, 0),
    ("silo", 728, 1092, 0), ("scarecrow", 790, 1060, -40), ("hay_bale_square", 716, 1066, 0), ("hay_bale_square", 717, 1067.2, 12), ("wheelbarrow", 700, 1056, 60),
    ("trough", 720, 1040, 0), ("well", 528, 1004, 0), ("woodpile", 512, 1006, 0), ("planter", 760, 918, 0), ("planter", 764, 918, 0), ("planter", 768, 918, 0),
    ("sign_a_ermita", 1056, 696, -40), ("bench", 1128, 548, 90), ("well", 1150, 552, 0), ("notice_board", 1128, 534, 90),
    ("rowboat", 1010, 452, 40), ("dock", 1004, 446, 0), ("sign_warn_bruma", 1040, 296, 90), ("sign_no_pasar", 1046, 304, 90), ("barrel_metal", 1052, 292, 0),
    ("spore_pod", 1080, 286, 0), ("spore_pod", 1050, 322, 40), ("spore_pod", 1090, 320, 100), ("radio_mast", 1160, 1140, 0), ("sign_repetidor", 1140, 1124, 200),
    ("sign_cantera", 1140, 870, 180), ("crate_stack", 1146, 904, 0), ("wheelbarrow", 1156, 910, 0), ("barrier_concrete", 1150, 884, 80),
    ("picnic_table", 304, 506, 30), ("sign_robledal", 420, 916, 220), ("sign_a_robledal", 436, 926, 200), ("bench", 126, 330, 120), ("sign_marjal", 950, 640, 90),
    ("rowboat", 876, 986, 20), ("sign_a_collado", 418, 944, 30), ("sign_a_sotoalto_r", 312, 978, 0), ("barrier_wood", 866, 1004, 60), ("car_sedan_red", 470, 884, 210),
    ("guardrail", 846, 642, 90), ("guardrail", 862, 658, 90), ("sign_a_sotoalto_l", 950, 660, 180),
]
PLACES = [   # id, nombre, x, z, radio, experiencia, secreto
    ("el_collado", "El Collado", 258, 988, 46, 20, 0), ("cruce_robledal", "Cruce del Robledal", 300, 500, 26, 25, 0), ("caseta_forestal", "Caseta forestal", 240, 256, 24, 30, 0),
    ("cabana_escondida", "Cabaña escondida", 122, 640, 18, 60, 1), ("bodega_vieja", "Bodega vieja", 142, 424, 16, 60, 1), ("mirador", "Mirador del Roble Gordo", 124, 334, 18, 50, 1),
    ("plaza_sotoalto", "Plaza de Sotoalto", 668, 626, 34, 25, 0), ("ultramarinos", "Ultramarinos Lucero", 612, 637, 11, 15, 0), ("botica", "Botica del Río", 626, 663, 10, 15, 0),
    ("cafe", "Café La Parada", 611, 663, 10, 15, 0), ("consistorial", "Casa Consistorial", 673, 597, 14, 30, 0), ("consultorio", "Consultorio", 672, 663, 10, 15, 0),
    ("escuela", "Escuela rural", 696, 664, 11, 15, 0), ("taller", "Taller Ardila", 663, 566, 12, 15, 0), ("la_fragua", "Polígono La Fragua", 680, 290, 60, 30, 0),
    ("conservas", "Conservas Sotoalto", 695, 250, 22, 35, 0), ("bombeo", "Estación de bombeo", 792, 291, 10, 25, 0), ("puente", "Puente de Sotoalto", 850, 650, 22, 20, 0),
    ("pasarela", "Pasarela del Marjal", 829, 300, 16, 25, 0), ("las_eras", "Las Eras", 616, 916, 44, 25, 0), ("finca_sur", "Finca del Molino", 706, 1056, 36, 25, 0),
    ("manzanos", "Huerto de manzanos", 770, 950, 34, 20, 0), ("vado", "Vado del río", 884, 1000, 18, 25, 0), ("marjal", "Marjal de la Bruma", 960, 420, 60, 35, 0),
    ("estacion_liquen", "Estación Liquen", 1064, 304, 30, 80, 0), ("caseta_pesca", "Caseta de pesca", 1004, 468, 14, 25, 0), ("ermita", "Ermita de San Telmo", 1138, 542, 24, 40, 0),
    ("cantera", "Cantera del Alto", 1150, 900, 36, 35, 0), ("repetidor", "Repetidor del Alto", 1160, 1140, 22, 60, 1),
]
REGIONS = ["pradera", "collado", "robledal", "sotoalto", "fragua", "eras", "marjal", "alto", "bruma", "ribera"]


def region_map():
    """Mapa de regiones 128×128 (celdas de 10 m)."""
    g = np.linspace(5, SIZE - 5, 128)
    gx, gz = np.meshgrid(g, g)
    gx = gx + 300 * fbm(128, 170, 3, 31)
    gz = gz + 300 * fbm(128, 170, 3, 32)
    r = np.zeros((128, 128), np.uint8)
    r[(gx < 520) & (gz > 820)] = 1
    r[(gx < 470) & (gz < 860)] = 2
    r[(gx > 470) & (gx < 800) & (gz > 110) & (gz < 470)] = 4
    r[(gx > 440) & (gx < 860) & (gz > 830)] = 5
    r[(gx > 930) & (gz > 560)] = 7
    r[((gx - MARSH_C[0]) / (MARSH_R[0] + 20)) ** 2 + ((gz - MARSH_C[1]) / (MARSH_R[1] + 20)) ** 2 < 1] = 6
    r[np.hypot(gx - ISLET[0], gz - ISLET[1]) < 120] = 8
    r[(gx > 570) & (gx < 780) & (gz > 540) & (gz < 780)] = 3
    dr = dist_polyline(gx, gz, RIVER)
    r[(dr < 26) & (r != 6) & (r != 8) & (r != 3)] = 9
    return r


def build_height():
    base = 14.0 + 6.0 * fbm(N, 300, 4, 1) * 2 + 2.4 * fbm(N, 80, 3, 2) * 2 + 0.6 * fbm(N, 22, 2, 3) * 2
    west = 40 * sstep(520, 60, X) * (0.7 + 0.6 * (fbm(N, 260, 3, 4) + 0.5))
    north = 16 * sstep(260, 20, Z) * sstep(760, 500, X)
    east = 34 * sstep(930, 1230, X) * sstep(520, 760, Z) * (0.75 + 0.5 * (fbm(N, 240, 3, 5) + 0.5))
    ermita_hill = 12 * np.exp(-((X - 1140) ** 2 + (Z - 545) ** 2) / (2 * 55 ** 2))
    mirador = 9 * np.exp(-((X - 124) ** 2 + (Z - 334) ** 2) / (2 * 40 ** 2))
    H = base + west + north + east + ermita_hill + mirador
    edge = np.minimum(np.minimum(X, SIZE - X), np.minimum(Z, SIZE - Z))
    H += 46 * sstep(70, 0, edge)                                  # el borde del valle se cierra
    floor = WL + 2.6 + 0.8 * (fbm(N, 50, 2, 9) + 0.5)
    H = np.where(H < floor + 1.5, floor + 1.5 * sstep(floor - 4.0, floor + 1.5, H), H)   # sin charcas involuntarias
    dr = dist_polyline(X, Z, RIVER)
    H = H * sstep(0, 150, dr) ** 0.6 + (WL + 3.2) * (1 - sstep(0, 150, dr) ** 0.6) + 46 * sstep(70, 0, edge) * (1 - sstep(0, 150, dr) ** 0.6) * 0
    bed = WL - 2.4 + 2.0 * sstep(4, 11, dr)
    H = np.where(dr < 30, bed * (1 - sstep(8, 30, dr)) + H * sstep(8, 30, dr), H)
    ford = np.hypot(X - 884, Z - 1000)
    H = np.where((dr < 14) & (ford < 22), np.maximum(H, WL - 0.45 + 0.1 * sstep(10, 22, ford) * 0), H)
    H = np.where((dr < 12) & (ford < 16), WL - 0.42, H)
    m = ((X - MARSH_C[0]) / MARSH_R[0]) ** 2 + ((Z - MARSH_C[1]) / MARSH_R[1]) ** 2 + 0.5 * fbm(N, 90, 3, 6)
    marsh_h = WL + 0.12 + 1.5 * fbm(N, 30, 3, 7) + 0.5 * fbm(N, 8, 2, 8)
    k = sstep(1.0, 0.6, m)
    H = H * (1 - k) + marsh_h * k
    dl = np.hypot(X - LAKE_C[0], Z - LAKE_C[1])
    H = np.where(dl < LAKE_R + 30, np.minimum(H, WL - 2.6 + 2.8 * sstep(LAKE_R - 25, LAKE_R + 30, dl)), H)
    di = np.hypot(X - ISLET[0], Z - ISLET[1])
    H = np.where(di < ISLET[2] + 16, np.maximum(H, WL + 1.3 - 2.2 * sstep(ISLET[2], ISLET[2] + 16, di)), H)
    dq = np.hypot(X - 1158, Z - 908)                              # cantera: cubeta con paredes
    H = np.where(dq < 46, np.minimum(H, 30.0 + 14 * sstep(26, 46, dq)), H)
    return H, dr


def flatten_roads(H, dr):
    roads_out = []
    for rid, kind, pts in ROADS:
        pts = resample(smooth_path(pts, 2), 4.0)
        w = ROAD_W[kind]
        hs = np.array([sample(H, x, z) for x, z in pts])
        k = 11 if kind == "asphalt" else 7
        pad = np.pad(hs, k, mode="edge")
        hs = np.convolve(pad, np.ones(2 * k + 1) / (2 * k + 1), mode="valid")
        for i, (x, z) in enumerate(pts):                         # tablero de los puentes
            for (_, bx, bz, _, span) in BRIDGES:
                dd = math.hypot(x - bx, z - bz)
                if dd < span / 2 + 34:
                    deck = WL + (2.7 if span > 25 else 1.6)
                    t = 1.0 if dd < span / 2 + 6 else 1 - (dd - span / 2 - 6) / 28
                    hs[i] = hs[i] * (1 - t) + deck * t
            if rid == "vado" and math.hypot(x - 884, z - 1000) < 24:
                hs[i] = min(hs[i], WL + 0.25)
        x0, x1 = max(0, min(p[0] for p in pts) - 20), min(SIZE, max(p[0] for p in pts) + 20)
        z0, z1 = max(0, min(p[1] for p in pts) - 20), min(SIZE, max(p[1] for p in pts) + 20)
        i0, i1, j0, j1 = int(x0 / STEP), int(x1 / STEP) + 1, int(z0 / STEP), int(z1 / STEP) + 1
        sx, sz = X[j0:j1, i0:i1], Z[j0:j1, i0:i1]
        best_d = np.full(sx.shape, 1e9); best_h = np.zeros(sx.shape)
        for (xa, za), (xb, zb), ha, hb in zip(pts, pts[1:], hs, hs[1:]):
            vx, vz = xb - xa, zb - za
            t = np.clip(((sx - xa) * vx + (sz - za) * vz) / (vx * vx + vz * vz + 1e-9), 0, 1)
            d = np.hypot(sx - (xa + t * vx), sz - (za + t * vz))
            upd = d < best_d
            best_d = np.where(upd, d, best_d); best_h = np.where(upd, ha + (hb - ha) * t, best_h)
        blend = 1 - sstep(w / 2 + 0.8, w / 2 + 7.0, best_d)
        water_gap = (dr[j0:j1, i0:i1] < 13) & (best_h > WL + 1.0)   # bajo los puentes no se rellena el cauce
        blend = np.where(water_gap, 0.0, blend)
        H[j0:j1, i0:i1] = H[j0:j1, i0:i1] * (1 - blend) + (best_h - 0.06) * blend
        roads_out.append({"id": rid, "kind": kind, "width": w, "points": [[round(x, 2), round(float(h), 2), round(z, 2)] for (x, z), h in zip(pts, hs)]})
    return roads_out


def bsize(kind):
    meta = json.load(open(os.path.join(ROOT, "data", "buildings", kind + ".json")))
    return meta["size"][0], meta["size"][2], meta


def flatten_buildings(H):
    out = []
    for idx, (kind, x, z, yaw) in enumerate(BUILDINGS):
        w, d, meta = bsize(kind)
        if "porch" in kind:
            pass
        y = sample(H, x, z)
        if kind == "station_lab":
            y = WL + 1.3
        if kind == "fishing_hut":
            y = max(y, WL + 0.9)
        c, s = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
        lx = (X - x) * c - (Z - z) * s                           # coordenadas locales del edificio
        lz = (X - x) * s + (Z - z) * c
        dx = np.maximum(np.abs(lx) - (w / 2 + 2.5), 0); dz = np.maximum(np.abs(lz) - (d / 2 + 3.5), 0)
        dd = np.hypot(dx, dz)
        k = 1 - sstep(0.0, 7.0, dd)
        H[:] = H * (1 - k) + (y - 0.02) * k
        out.append({"id": idx, "type": kind, "pos": [x, round(float(y), 3), z], "yaw": yaw, "w": w, "d": d})
    return out


def in_building(bl, x, z, margin):
    for b in bl:
        c, s = math.cos(math.radians(b["yaw"])), math.sin(math.radians(b["yaw"]))
        lx = (x - b["pos"][0]) * c - (z - b["pos"][2]) * s
        lz = (x - b["pos"][0]) * s + (z - b["pos"][2]) * c
        if abs(lx) < b["w"] / 2 + margin and abs(lz) < b["d"] / 2 + margin:
            return True
    return False


VEG_TYPES = ["tree_pine_a", "tree_pine_b", "tree_fir_a", "tree_fir_b", "tree_oak_a", "tree_oak_b", "tree_oak_autumn_a", "tree_birch_a", "tree_birch_b", "tree_willow_a",
             "tree_poplar_a", "tree_apple_a", "tree_dead_a", "tree_dead_b", "tree_sapling_a", "bush_a", "bush_b", "fern", "reeds", "rock_a", "rock_b", "rock_c", "rock_d",
             "rock_e", "cliff_a", "stump", "fallen_log", "grass_b", "grass_flowers"]
VT = {n: i for i, n in enumerate(VEG_TYPES)}
MIX = {
    2: [("tree_oak_a", 16), ("tree_oak_b", 14), ("tree_oak_autumn_a", 7), ("tree_pine_a", 12), ("tree_pine_b", 10), ("tree_fir_a", 12), ("tree_fir_b", 10), ("tree_birch_a", 7), ("tree_birch_b", 6), ("tree_dead_a", 3), ("tree_sapling_a", 3)],
    0: [("tree_oak_a", 4), ("tree_birch_a", 4), ("tree_poplar_a", 3), ("tree_oak_b", 3), ("tree_sapling_a", 2)],
    1: [("tree_oak_a", 4), ("tree_birch_a", 5), ("tree_birch_b", 4), ("tree_pine_a", 3), ("tree_sapling_a", 2)],
    3: [("tree_poplar_a", 3), ("tree_birch_a", 3), ("tree_sapling_a", 4), ("tree_oak_b", 2)],
    4: [("tree_sapling_a", 5), ("tree_birch_b", 3), ("tree_dead_b", 3), ("tree_poplar_a", 2)],
    5: [("tree_poplar_a", 5), ("tree_oak_a", 2), ("tree_sapling_a", 2)],
    6: [("tree_willow_a", 9), ("tree_dead_a", 4), ("tree_dead_b", 4), ("tree_birch_b", 2)],
    7: [("tree_pine_a", 8), ("tree_pine_b", 8), ("tree_oak_autumn_a", 3), ("tree_dead_a", 2), ("tree_fir_a", 3)],
    8: [("tree_dead_a", 6), ("tree_dead_b", 6), ("tree_willow_a", 4)],
    9: [("tree_willow_a", 6), ("tree_poplar_a", 5), ("tree_birch_a", 3)],
}
TREE_AREA = {0: 900, 1: 520, 2: 62, 3: 1100, 4: 800, 5: 1500, 6: 380, 7: 210, 8: 300, 9: 240}     # m² por árbol
BUSH_AREA = {0: 500, 1: 320, 2: 150, 3: 420, 4: 300, 5: 800, 6: 400, 7: 300, 8: 500, 9: 200}
ROCK_AREA = {0: 2500, 1: 1500, 2: 600, 3: 9000, 4: 4000, 5: 6000, 6: 3000, 7: 260, 8: 2500, 9: 500}


def main():
    os.makedirs(os.path.join(ROOT, "data", "world"), exist_ok=True)
    gen = os.path.join(ROOT, "assets", "textures", "gen")
    os.makedirs(gen, exist_ok=True)
    H, dr = build_height()
    roads = flatten_roads(H, dr)
    blds = flatten_buildings(H)
    H = H.astype(np.float32)
    regmap = region_map()

    def region_at(x, z):
        return int(regmap[min(127, int(z / 10)), min(127, int(x / 10))])

    road_d = np.full((N, N), 1e9); road_dirt = np.full((N, N), 1e9)
    for r in roads:
        pts = [(p[0], p[2]) for p in r["points"]]
        d = dist_polyline(X, Z, pts) - r["width"] / 2
        road_d = np.minimum(road_d, d)
        if r["kind"] != "asphalt":
            road_dirt = np.minimum(road_dirt, d)
    gy, gx = np.gradient(H, STEP)
    slope = np.hypot(gx, gy)

    # ---------------- cubierta del suelo y tinte ---------------------------------------------
    S = 1024
    def up(a):
        return np.asarray(Image.fromarray(a.astype(np.float32)).resize((S, S), Image.BILINEAR))
    reg_up = np.asarray(Image.fromarray(regmap).resize((S, S), Image.NEAREST))
    slope_u, h_u, road_u, dirt_u, river_u = up(slope), up(H), up(road_d), up(road_dirt), up(dr)
    n1, n2 = fbm(S, 60, 4, 21) * 2, fbm(S, 14, 3, 22) * 2
    forest = np.clip((reg_up == 2) * (0.85 + 0.5 * n1) + (reg_up == 7) * (0.35 + 0.5 * n1) + (reg_up == 9) * 0.3 + (reg_up == 1) * (0.15 + 0.5 * n1), 0, 1)
    rock = np.clip(sstep(0.5, 0.95, slope_u) + (np.hypot(up(X) - 1158, up(Z) - 908) < 44) * 0.9 + 0.35 * sstep(WL - 0.2, WL - 1.4, h_u) * (river_u < 14), 0, 1)
    fields = np.zeros((S, S))
    FIELD_RECTS = [(470, 880, 590, 1000, 0.92), (486, 1030, 600, 1110, 0.8), (730, 1000, 850, 1110, 0.88), (560, 780, 630, 860, 0.75), (700, 800, 800, 880, 0.82)]
    ux, uz = up(X), up(Z)
    for (x0, z0, x1, z1, _) in FIELD_RECTS:
        fields = np.maximum(fields, sstep(0, 4, np.minimum(np.minimum(ux - x0, x1 - ux), np.minimum(uz - z0, z1 - uz))))
    furrow = 0.5 + 0.5 * np.sin(uz * 2.2 + ux * 0.25)
    dirt = np.clip(sstep(2.5, -0.5, dirt_u) + 0.55 * sstep(3.0, 0.0, road_u) + fields * (0.55 + 0.35 * furrow) + sstep(WL + 0.7, WL + 0.1, h_u) * 0.9
                   + (reg_up == 4) * (0.3 + 0.4 * n2) + (reg_up == 3) * 0.2 + (reg_up == 8) * 0.4, 0, 1)
    plaza = (np.abs(ux - 669) < 21) & (np.abs(uz - 626) < 17)
    dirt = np.where(plaza, 0.0, dirt); rock = np.where(plaza, 1.0, rock)
    forest = forest * (1 - dirt) * (1 - rock); dirt = dirt * (1 - rock)
    splat = np.stack([forest, dirt, rock], -1)
    Image.fromarray((np.clip(splat, 0, 1) * 255).astype(np.uint8)).save(os.path.join(gen, "world_splat.png"))
    tint = np.ones((S, S, 3)) * np.array([1.0, 1.0, 0.94])
    tint *= (1.0 + 0.16 * n1[..., None]) * (1.0 + 0.07 * n2[..., None])
    tint = np.where((reg_up == 2)[..., None], tint * np.array([0.84, 0.94, 0.8]), tint)
    tint = np.where(((reg_up == 6) | (reg_up == 8))[..., None], tint * np.array([0.8, 0.86, 0.74]), tint)
    tint = np.where((reg_up == 5)[..., None], tint * np.array([1.08, 1.04, 0.84]), tint)
    tint = np.where((reg_up == 7)[..., None], tint * np.array([1.02, 0.98, 0.86]), tint)
    for i, (x0, z0, x1, z1, tone) in enumerate(FIELD_RECTS):
        m = (ux > x0) & (ux < x1) & (uz > z0) & (uz < z1)
        tint = np.where(m[..., None], tint * np.array([tone, tone * 0.93, tone * 0.82]), tint)
    tint = tint * (1 - 0.3 * sstep(WL + 0.6, WL - 0.6, h_u))[..., None]
    Image.fromarray((np.clip(tint * 0.5, 0, 1) * 255).astype(np.uint8)).save(os.path.join(gen, "world_tint.png"))
    regmap.tofile(os.path.join(ROOT, "data", "world", "regions.bin"))

    # ---------------- colocación ---------------------------------------------------------------
    props = []
    for (model, x, z, yaw) in PROPS:
        props.append({"model": model, "pos": [x, round(float(sample(H, x, z)), 3), z], "yaw": yaw})
    for (model, bx, bz, yaw, span) in BRIDGES:
        deck = WL + (2.7 if span > 25 else 1.6)
        props.append({"model": model, "pos": [bx, round(deck + (0.0 if span > 25 else 0.03), 3), bz], "yaw": yaw})
    for i, (x, z) in enumerate(BOARDWALK):
        props.append({"model": "boardwalk", "pos": [x, WL + 0.62, z + 0.25 * math.sin(i * 0.7)], "yaw": 90 + 2.0 * math.sin(i * 1.3)})
    for i in range(3):
        props.append({"model": "dock", "pos": [1004, WL + 0.5, 452 - i * 4.0], "yaw": 0})

    def road_points(rid):
        return [(p[0], p[2]) for r in roads if r["id"] == rid for p in r["points"]]
    main_pts = road_points("principal")
    for i in range(6, len(main_pts) - 4, 11):                  # tendido eléctrico junto a la carretera
        (x0, z0), (x1, z1) = main_pts[i], main_pts[i + 1]
        nx, nz = -(z1 - z0), (x1 - x0)
        l = math.hypot(nx, nz)
        px, pz = x0 + nx / l * 6.5, z0 + nz / l * 6.5
        if sample(H, px, pz) > WL + 1.5 and not in_building(blds, px, pz, 2.0):
            props.append({"model": "power_pole", "pos": [round(px, 2), round(float(sample(H, px, pz)), 3), round(pz, 2)], "yaw": round(math.degrees(math.atan2(x1 - x0, z1 - z0)), 1)})

    def fence_rect(x0, z0, x1, z1, model="fence_wood", gap=None):
        L = 2.6 if model == "fence_wood" else 3.0
        for (ax_, az_, bx_, bz_) in ((x0, z0, x1, z0), (x1, z0, x1, z1), (x1, z1, x0, z1), (x0, z1, x0, z0)):
            n = max(1, int(math.hypot(bx_ - ax_, bz_ - az_) / L))
            for k in range(n):
                cx, cz = ax_ + (bx_ - ax_) * (k + 0.5) / n, az_ + (bz_ - az_) * (k + 0.5) / n
                if gap and math.hypot(cx - gap[0], cz - gap[1]) < 4.5:
                    continue
                if any(dist_seg(cx, cz, r) < r_w for r, r_w in ROAD_SEGS):
                    continue
                props.append({"model": model, "pos": [round(cx, 2), round(float(sample(H, cx, cz)), 3), round(cz, 2)], "yaw": round(math.degrees(math.atan2(bx_ - ax_, bz_ - az_)) + 90, 1)})

    global ROAD_SEGS
    ROAD_SEGS = [([(p[0], p[2]) for p in r["points"]], r["width"] / 2 + 1.5) for r in roads]
    for (x0, z0, x1, z1, _) in FIELD_RECTS:
        fence_rect(x0 - 2, z0 - 2, x1 + 2, z1 + 2, "fence_wire" if x0 > 600 else "fence_wood", gap=((x0 + x1) / 2, z0 - 2))
    fence_rect(736, 912, 806, 986, "fence_wood", gap=(736, 950))

    # vegetación
    veg = []
    rmask_cache = {}

    def blocked(x, z, margin):
        if x < 6 or z < 6 or x > SIZE - 6 or z > SIZE - 6:
            return True
        i, j = int(x / STEP), int(z / STEP)
        if road_d[j, i] < margin:
            return True
        return in_building(blds, x, z, margin + 1.0)

    clear = [(262, 980, 26), (669, 626, 22), (1138, 545, 16), (1160, 1140, 12), (1064, 304, 24), (300, 500, 9), (124, 334, 8)]
    def cleared(x, z):
        return any(math.hypot(x - cx, z - cz) < cr for cx, cz, cr in clear)

    cell = 5.0
    for j in range(int(SIZE / cell)):
        for i in range(int(SIZE / cell)):
            x, z = (i + rnd.random()) * cell, (j + rnd.random()) * cell
            reg = region_at(x, z)
            h = sample(H, x, z)
            sl = slope[min(N - 1, int(z / STEP)), min(N - 1, int(x / STEP))]
            dens = float(n1[min(S - 1, int(z / SIZE * S)), min(S - 1, int(x / SIZE * S))])
            # árboles
            area = TREE_AREA[reg] * (0.55 if dens > 0.15 else (1.8 if dens < -0.2 else 1.0))
            if rnd.random() < cell * cell / area and sl < 0.75 and not cleared(x, z):
                names = MIX[reg]
                tname = rnd.choices([n for n, _ in names], [w for _, w in names])[0]
                wet_ok = tname.startswith(("tree_willow", "tree_dead"))
                if (h > WL + 0.5 or (wet_ok and h > WL - 0.2)) and not blocked(x, z, 2.2) and not any(z0 < z < z1 and x0 < x < x1 for (x0, z0, x1, z1, _) in FIELD_RECTS):
                    sc = rnd.uniform(0.8, 1.25) * (1.25 if (abs(x - 124) < 6 and abs(z - 334) < 6) else 1.0)
                    veg.append((VT[tname], x, h - 0.05, z, rnd.uniform(0, 6.283), sc))
                    continue
            if rnd.random() < cell * cell / BUSH_AREA[reg] and h > WL + 0.4 and sl < 0.8 and not blocked(x, z, 1.2) and not cleared(x, z):
                veg.append((VT[rnd.choice(["bush_a", "bush_b", "bush_a", "fern"])], x, h - 0.03, z, rnd.uniform(0, 6.283), rnd.uniform(0.75, 1.3)))
                continue
            if rnd.random() < cell * cell / ROCK_AREA[reg] * (1 + 3 * min(1.0, sl)) and h > WL - 0.6 and not blocked(x, z, 1.5) and not cleared(x, z):
                rn = rnd.choices(["rock_a", "rock_b", "rock_c", "rock_d", "rock_e"], [5, 4, 2, 5, 1 if reg in (2, 7) else 0.1])[0]
                veg.append((VT[rn], x, h - 0.12, z, rnd.uniform(0, 6.283), rnd.uniform(0.7, 1.5)))
                continue
            if reg == 2 and rnd.random() < cell * cell / 900 and h > WL + 1 and not blocked(x, z, 1.5):
                veg.append((VT[rnd.choice(["stump", "fallen_log"])], x, h, z, rnd.uniform(0, 6.283), rnd.uniform(0.85, 1.2)))
                continue
            if WL - 0.75 < h < WL + 0.35 and rnd.random() < cell * cell / 34 and road_d[int(z / STEP), int(x / STEP)] > 1.0:
                veg.append((VT["reeds"], x, max(h, WL - 0.5) - 0.05, z, rnd.uniform(0, 6.283), rnd.uniform(0.8, 1.3)))
    for gx_ in range(8):                                        # huerto de manzanos en cuadrícula
        for gz_ in range(8):
            x, z = 742 + gx_ * 8.4 + rnd.uniform(-0.8, 0.8), 918 + gz_ * 8.6 + rnd.uniform(-0.8, 0.8)
            if (gx_ + gz_ * 3) % 5 == 0:
                continue        # hueco: ahí va un nodo de recolección (manzano con fruta)
            veg.append((VT["tree_apple_a"], x, sample(H, x, z) - 0.04, z, rnd.uniform(0, 6.283), rnd.uniform(0.9, 1.15)))
    for (cx, cz) in ((1150, 876), (1186, 900), (1176, 936), (1130, 930), (1196, 880)):
        veg.append((VT["cliff_a"], cx, sample(H, cx, cz) - 1.0, cz, rnd.uniform(0, 6.283), rnd.uniform(0.9, 1.3)))
    veg.append((VT["tree_oak_a"], 124, sample(H, 124, 334) - 0.1, 328, 1.0, 1.9))      # el Roble Gordo

    # recolección
    harvest = []
    def add_h(kind, x, z, yaw=None):
        harvest.append({"id": len(harvest), "type": kind, "pos": [round(x, 2), round(float(sample(H, x, z)), 3), round(z, 2)], "yaw": round(rnd.uniform(0, 360), 1) if yaw is None else yaw})

    def scatter(kind, count, regs, hmin=WL + 0.5, hmax=99, near_road=None, tries=6000, min_sep=7.0):
        got = 0
        for _ in range(tries):
            if got >= count:
                break
            x, z = rnd.uniform(40, SIZE - 40), rnd.uniform(40, SIZE - 40)
            if region_at(x, z) not in regs:
                continue
            h = sample(H, x, z)
            if not (hmin < h < hmax) or blocked(x, z, 1.5) or cleared(x, z):
                continue
            if near_road is not None and road_d[int(z / STEP), int(x / STEP)] > near_road:
                continue
            if any(math.hypot(x - o["pos"][0], z - o["pos"][2]) < min_sep for o in harvest[-60:]):
                continue
            add_h(kind, x, z); got += 1

    scatter("bayas", 64, (1, 2, 0, 7))
    scatter("setas", 70, (2,))
    scatter("hierbas", 54, (0, 1, 5, 7, 9))
    scatter("fibra", 50, (6, 9, 8), hmin=WL - 0.1, hmax=WL + 1.6)
    scatter("piedra", 46, (7, 9, 2), hmin=WL - 0.2)
    scatter("lena", 80, (2, 1, 7))
    scatter("chatarra", 34, (4, 3), near_road=40)
    scatter("liquen", 26, (8, 6), hmin=WL - 0.1, hmax=WL + 2.0, min_sep=5.0)
    for gx_ in range(8):
        for gz_ in range(8):
            if (gx_ + gz_ * 3) % 5 == 0:
                add_h("manzano", 742 + gx_ * 8.4, 918 + gz_ * 8.6)
    for (x, z) in ((1154, 912), (1164, 902), (1160, 918), (1148, 898), (1170, 912)):
        add_h("piedra", x, z)
    for (x, z) in ((760.6, 918), (764.6, 918), (768.6, 918)):
        add_h("hierbas", x, z)

    creatures = [
        {"type": "brumal", "center": [200, 420], "radius": 110, "count": 2}, {"type": "brumal", "center": [330, 700], "radius": 100, "count": 2},
        {"type": "brumal", "center": [150, 780], "radius": 90, "count": 1}, {"type": "brumal", "center": [1090, 1000], "radius": 100, "count": 2},
        {"type": "brumal", "center": [720, 200], "radius": 80, "count": 1, "night_only": True}, {"type": "brumal", "center": [1000, 420], "radius": 70, "count": 1, "night_only": True},
        {"type": "zarzo", "center": [530, 950], "radius": 70, "count": 4}, {"type": "zarzo", "center": [780, 1050], "radius": 70, "count": 4},
        {"type": "zarzo", "center": [360, 900], "radius": 60, "count": 3}, {"type": "zarzo", "center": [1000, 760], "radius": 70, "count": 3},
        {"type": "zarzo", "center": [520, 760], "radius": 50, "count": 2},
        {"type": "farol", "center": [960, 330], "radius": 70, "count": 4}, {"type": "farol", "center": [1064, 304], "radius": 60, "count": 5},
        {"type": "farol", "center": [1080, 430], "radius": 60, "count": 3}, {"type": "farol", "center": [1150, 300], "radius": 50, "count": 3},
    ]
    world = {
        "version": 1, "size": SIZE, "sector": SECTOR, "samples": N, "step": STEP, "water_level": WL, "regions": REGIONS,
        "spawns": [[250, 1000], [258, 1002], [266, 1000], [272, 996], [244, 996], [262, 990]],
        "safe_zones": [{"center": [258, 988], "radius": 46, "name": "El Collado"}, {"center": [1138, 542], "radius": 24, "name": "Ermita de San Telmo"}],
        "hazards": [{"type": "bruma", "center": [ISLET[0], ISLET[1]], "radius": 115, "inner": 60}, {"type": "bruma", "center": [1150, 300], "radius": 70, "inner": 30}],
        "border": 40.0, "roads": roads, "river": [[round(x, 1), round(z, 1)] for x, z in RIVER],
        "buildings": blds, "props": props, "harvest": harvest, "creatures": creatures, "veg_types": VEG_TYPES,
        "places": [{"id": p[0], "name": p[1], "pos": [p[2], p[3]], "radius": p[4], "xp": p[5], "secret": bool(p[6])} for p in PLACES],
    }
    # vegetación ordenada por sector + índice
    ns = int(SIZE / SECTOR)
    buckets = {}
    for v in veg:
        key = min(ns - 1, int(v[3] / SECTOR)) * ns + min(ns - 1, int(v[1] / SECTOR))
        buckets.setdefault(key, []).append(v)
    flat, index = [], [[0, 0] for _ in range(ns * ns)]
    for key in sorted(buckets):
        index[key] = [len(flat), len(buckets[key])]
        flat.extend(buckets[key])
    world["veg_index"] = index
    np.asarray(flat, dtype=np.float32).tofile(os.path.join(ROOT, "data", "world", "veg.bin"))
    H.tofile(os.path.join(ROOT, "data", "world", "height.bin"))
    json.dump(world, open(os.path.join(ROOT, "data", "world", "world.json"), "w"), separators=(",", ":"))
    draw_map(H, regmap, roads, blds, veg, os.path.join(gen, "world_map.png"))
    print("mundo: árboles/vegetación=%d objetos=%d edificios=%d recolección=%d altura=[%.1f, %.1f]" % (len(veg), len(props), len(blds), len(harvest), H.min(), H.max()))


def dist_seg(x, z, pts):
    best = 1e9
    for (x0, z0), (x1, z1) in zip(pts, pts[1:]):
        vx, vz = x1 - x0, z1 - z0
        t = max(0.0, min(1.0, ((x - x0) * vx + (z - z0) * vz) / (vx * vx + vz * vz + 1e-9)))
        best = min(best, math.hypot(x - (x0 + t * vx), z - (z0 + t * vz)))
    return best


def draw_map(H, regmap, roads, blds, veg, path):
    """Mapa ilustrado: papel, relieve sombreado, agua, bosque, caminos y edificios."""
    M = 1024
    k = M / SIZE
    h = np.asarray(Image.fromarray(H).resize((M, M), Image.BILINEAR)).astype(np.float64)
    gy, gx = np.gradient(h, SIZE / M)
    shade = np.clip(0.5 + (gx * -0.6 + gy * -0.6) * 0.9, 0.15, 1.0)
    paper = np.ones((M, M, 3)) * np.array([0.86, 0.81, 0.68])
    paper *= (0.94 + 0.12 * (fbm(M, 40, 4, 55) * 2 + 0.5))[..., None]
    reg = np.asarray(Image.fromarray(regmap).resize((M, M), Image.NEAREST))
    col = paper * (0.78 + 0.3 * shade[..., None])
    dens = Image.new("L", (M, M), 0)
    dd = ImageDraw.Draw(dens)
    for v in veg:
        if v[0] <= VT["tree_sapling_a"]:
            dd.ellipse([v[1] * k - 5, v[3] * k - 5, v[1] * k + 5, v[3] * k + 5], fill=255)
    dens = np.asarray(dens.filter(ImageFilter.GaussianBlur(7))).astype(np.float64) / 255.0
    col = col * (1 - 0.3 * np.clip(dens * 1.6, 0, 1)[..., None] * np.array([1.0, 0.45, 1.1]))
    for lvl in range(14, 70, 6):                                 # curvas de nivel
        sl_ = np.hypot(gx, gy)
        c = (np.abs(h - lvl) < 0.9 * sl_) & (sl_ > 0.03)
        col = np.where(c[..., None], col * 0.84, col)
    water = h < WL
    col = np.where(water[..., None], np.array([0.5, 0.64, 0.7]) * (0.9 + 0.1 * shade[..., None]), col)
    shore = (h < WL + 0.35) & ~water
    col = np.where(shore[..., None], col * 0.82, col)
    im = Image.fromarray((np.clip(col, 0, 1) * 255).astype(np.uint8))
    d = ImageDraw.Draw(im)
    for v in veg:
        if v[0] <= VT["tree_sapling_a"]:
            x, z = v[1] * k, v[3] * k
            d.ellipse([x - 1.6, z - 1.6, x + 1.6, z + 1.6], fill=(96, 122, 84))
    for r in roads:
        pts = [(p[0] * k, p[2] * k) for p in r["points"]]
        if r["kind"] == "asphalt":
            d.line(pts, fill=(84, 70, 56), width=5); d.line(pts, fill=(226, 208, 170), width=3)
        else:
            for a, b in zip(pts[::2], pts[1::2]):
                d.line([a, b], fill=(110, 86, 62), width=2 if r["kind"] == "dirt" else 1)
    for b in blds:
        c, s = math.cos(math.radians(b["yaw"])), math.sin(math.radians(b["yaw"]))
        w2, d2 = b["w"] / 2, b["d"] / 2
        poly = [((b["pos"][0] + lx * c + lz * s) * k, (b["pos"][2] - lx * s + lz * c) * k) for lx, lz in ((-w2, -d2), (w2, -d2), (w2, d2), (-w2, d2))]
        d.polygon(poly, fill=(120, 60, 46), outline=(60, 34, 28))
    for (_, bx, bz, yaw, span) in BRIDGES:
        d.line([((bx - span / 2) * k, bz * k), ((bx + span / 2) * k, bz * k)], fill=(70, 56, 44), width=4)
    d.line([(BOARDWALK[0][0] * k, 300 * k), (BOARDWALK[-1][0] * k, 300 * k)], fill=(96, 78, 58), width=1)
    im = im.filter(ImageFilter.SMOOTH)
    im.save(path)


if __name__ == "__main__":
    main()
