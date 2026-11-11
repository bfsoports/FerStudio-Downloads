#!/usr/bin/env python3
"""Atlas de rótulos, señales y carteles ficticios de Valdebruma (PIL).

Uso: python3 make_signs.py
Salida: assets/textures/gen/signs_atlas.png y data/signs_atlas.json
        {id: [u0, v0, u1, v1]} en espacio UV de Blender (v hacia arriba).
Todos los nombres comerciales y topónimos son inventados para el juego.
"""
import json, math, os, random
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
FONTS = os.path.join(ROOT, "assets", "fonts")
W = H = 2048
atlas = Image.new("RGB", (W, H), (40, 40, 40))
rects = {}
cur = [0, 0, 0]          # x, y, alto de fila
rnd = random.Random(21)


def font(size, cond=True, bold=True):
    name = ("BarlowCondensed-SemiBold.ttf" if bold else "BarlowCondensed-Medium.ttf") if cond else ("Barlow-SemiBold.ttf" if bold else "Barlow-Regular.ttf")
    return ImageFont.truetype(os.path.join(FONTS, name), size)


def alloc(w, h):
    if cur[0] + w > W:
        cur[0] = 0; cur[1] += cur[2]; cur[2] = 0
    x, y = cur[0], cur[1]
    cur[0] += w; cur[2] = max(cur[2], h)
    assert y + h <= H, "atlas lleno"
    return x, y


def weather(im, amount=0.5):
    """Suciedad, desgaste de bordes y arañazos."""
    w, h = im.size
    noise = Image.effect_noise((w // 28 + 2, h // 28 + 2), 46).resize((w, h), Image.BICUBIC)
    fine = Image.effect_noise((w // 3 + 1, h // 3 + 1), 30).resize((w, h), Image.BICUBIC)
    noise = Image.blend(noise, fine, 0.3)
    dirt = Image.new("RGB", (w, h), (84, 74, 60))
    mask = noise.point(lambda v: int(max(0, min(150, (v - 138) * 4.0 * amount))))
    im = Image.composite(dirt, im, mask)
    d = ImageDraw.Draw(im)
    for k in range(int(10 * amount)):
        x, y = rnd.randint(0, w), rnd.randint(0, h)
        d.line([(x, y), (x + rnd.randint(-40, 40), y + rnd.randint(-6, 6))], fill=(190, 185, 170), width=1)
    edge = Image.new("L", (w, h), 0)
    ImageDraw.Draw(edge).rectangle([3, 3, w - 4, h - 4], fill=255)
    edge = edge.filter(ImageFilter.GaussianBlur(6))
    return Image.composite(im, Image.new("RGB", (w, h), (52, 46, 40)), edge.point(lambda v: min(255, int(v * 1.6))))


pending = []


def put(sid, im):
    pending.append((sid, im))


def pack():
    """Empaquetado por estantes ordenando de mayor a menor altura."""
    for sid, im in sorted(pending, key=lambda t: (-t[1].size[1], -t[1].size[0])):
        x, y = alloc(*im.size)
        atlas.paste(im, (x, y))
        w, h = im.size
        rects[sid] = [round((x + 1) / W, 5), round(1 - (y + h - 1) / H, 5), round((x + w - 1) / W, 5), round(1 - (y + 1) / H, 5)]


def text_center(d, box, txt, fnt, fill, spacing=0):
    x0, y0, x1, y1 = box
    bb = d.textbbox((0, 0), txt, font=fnt)
    d.text(((x0 + x1 - (bb[2] - bb[0])) / 2 - bb[0], (y0 + y1 - (bb[3] - bb[1])) / 2 - bb[1]), txt, font=fnt, fill=fill)


def banner(sid, txt, bg, fg, sub=None, w=680, h=96, border=None, wear=0.5, emblem=None):
    im = Image.new("RGB", (w, h), bg)
    d = ImageDraw.Draw(im)
    if border:
        d.rectangle([6, 6, w - 7, h - 7], outline=border, width=4)
    size = int(h * (0.56 if sub is None else 0.46))
    fnt = font(size)
    while d.textlength(txt, font=fnt) > w * 0.86 and size > 20:
        size -= 2; fnt = font(size)
    x_off = 0
    if emblem:
        emblem(d, (int(h * 0.18), int(h * 0.18), int(h * 0.82), int(h * 0.82)), fg)
        x_off = int(h * 0.5)
    if sub:
        text_center(d, (x_off, h * 0.08, w, h * 0.66), txt, fnt, fg)
        text_center(d, (x_off, h * 0.62, w, h * 0.94), sub, font(int(h * 0.2), bold=False), fg)
    else:
        text_center(d, (x_off, 0, w, h), txt, fnt, fg)
    put(sid, weather(im, wear))


def leaf_emblem(d, box, col):
    x0, y0, x1, y1 = box
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    r = (x1 - x0) / 2
    d.ellipse([x0, y0, x1, y1], outline=col, width=4)
    pts = [(cx, cy - r * 0.62), (cx + r * 0.42, cy), (cx, cy + r * 0.62), (cx - r * 0.42, cy)]
    d.polygon(pts, fill=col)
    d.line([(cx, cy + r * 0.62), (cx, cy + r * 0.85)], fill=col, width=4)


def lichen_emblem(d, box, col):
    x0, y0, x1, y1 = box
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    r = (x1 - x0) / 2
    for k in range(6):
        a = k * math.pi / 3
        d.ellipse([cx + math.cos(a) * r * 0.5 - r * 0.3, cy + math.sin(a) * r * 0.5 - r * 0.3,
                   cx + math.cos(a) * r * 0.5 + r * 0.3, cy + math.sin(a) * r * 0.5 + r * 0.3], outline=col, width=3)
    d.ellipse([cx - r * 0.2, cy - r * 0.2, cx + r * 0.2, cy + r * 0.2], fill=col)


def road(sid, txt, w=400, h=100, bg=(232, 230, 220), fg=(26, 28, 30), arrow=0, wear=0.6):
    im = Image.new("RGB", (w, h), bg)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([5, 5, w - 6, h - 6], radius=12, outline=fg, width=5)
    x0, x1 = 20, w - 20
    if arrow:
        ax = 60 if arrow < 0 else w - 60
        s = -1 if arrow < 0 else 1
        d.polygon([(ax + s * 34, h / 2), (ax - s * 6, h / 2 - 30), (ax - s * 6, h / 2 - 11), (ax - s * 34, h / 2 - 11),
                   (ax - s * 34, h / 2 + 11), (ax - s * 6, h / 2 + 11), (ax - s * 6, h / 2 + 30)], fill=fg)
        if arrow < 0:
            x0 = 110
        else:
            x1 = w - 110
    size = int(h * 0.56)
    fnt = font(size)
    while d.textlength(txt, font=fnt) > (x1 - x0) * 0.94 and size > 16:
        size -= 2; fnt = font(size)
    text_center(d, (x0, 0, x1, h), txt, fnt, fg)
    put(sid, weather(im, wear))


def warning(sid, title, lines, bg=(226, 176, 40), fg=(24, 22, 18), w=384, h=384):
    im = Image.new("RGB", (w, h), bg)
    d = ImageDraw.Draw(im)
    d.rectangle([8, 8, w - 9, h - 9], outline=fg, width=8)
    # pictograma de bruma: tres ondas sobre un triángulo
    d.polygon([(w / 2, 46), (w / 2 + 92, 190), (w / 2 - 92, 190)], outline=fg, width=9)
    for k in range(3):
        y = 120 + k * 22
        pts = [(w / 2 - 44 + i * 8, y + 7 * math.sin(i * 0.9)) for i in range(12)]
        d.line(pts, fill=fg, width=6)
    text_center(d, (0, 204, w, 276), title, font(60), fg)
    for i, ln in enumerate(lines):
        text_center(d, (0, 280 + i * 34, w, 312 + i * 34), ln, font(27, bold=False), fg)
    put(sid, weather(im, 0.7).resize((320, 320), Image.LANCZOS))


def poster(sid, title, lines, w=384, h=512, bg=(226, 220, 200), fg=(40, 38, 34), accent=(150, 40, 30), wear=0.8):
    im = Image.new("RGB", (w, h), bg)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, w, 78], fill=accent)
    text_center(d, (0, 0, w, 78), title, font(46), bg)
    y = 100
    for ln in lines:
        if ln.startswith("#"):
            d.text((26, y), ln[1:], font=font(34), fill=accent); y += 44
        elif ln == "-":
            d.line([(26, y + 8), (w - 26, y + 8)], fill=fg, width=2); y += 20
        else:
            d.text((26, y), ln, font=font(24, cond=False, bold=False), fill=fg); y += 32
    put(sid, weather(im, wear).resize((320, 426), Image.LANCZOS))


def painting(sid, w=384, h=288, portrait=False):
    if portrait:
        w, h = h, w
    im = Image.new("RGB", (w, h), (206, 196, 168))
    d = ImageDraw.Draw(im)
    if not portrait:      # paisaje del valle
        for y in range(h):
            t = y / h
            d.line([(0, y), (w, y)], fill=(int(190 - 60 * t), int(200 - 40 * t), int(205 - 20 * t)))
        d.ellipse([w * 0.68, h * 0.14, w * 0.8, h * 0.14 + w * 0.12], fill=(240, 226, 180))
        for k, (base, col) in enumerate(((0.55, (120, 140, 132)), (0.66, (88, 116, 92)), (0.78, (62, 92, 60)))):
            pts = [(0, h)] + [(x, h * (base + 0.08 * math.sin(x * 0.012 * (k + 1) + k * 2) + 0.03 * math.sin(x * 0.05 + k))) for x in range(0, w + 8, 8)] + [(w, h)]
            d.polygon(pts, fill=col)
        d.line([(w * 0.1, h * 0.98), (w * 0.4, h * 0.86), (w * 0.52, h * 0.8), (w * 0.9, h * 0.76)], fill=(150, 170, 176), width=6)
    else:                 # lámina botánica
        cx = w / 2
        d.line([(cx, h * 0.9), (cx - 6, h * 0.2)], fill=(70, 90, 50), width=5)
        for k in range(7):
            y = h * (0.82 - k * 0.09)
            for s in (-1, 1):
                ex, ey = cx + s * w * (0.34 - k * 0.03), y - h * 0.07
                d.polygon([(cx, y), ((cx + ex) / 2, y - h * 0.075), (ex, ey), ((cx + ex) / 2, y + h * 0.01)], fill=(86, 122, 62), outline=(56, 82, 44))
        text_center(d, (0, h * 0.91, w, h), "Lichen brumalis", font(22, cond=False, bold=False), (60, 52, 44))
    put(sid, weather(im, 0.35))


def valley_map(sid, w=512, h=384):
    im = Image.new("RGB", (w, h), (216, 206, 176))
    d = ImageDraw.Draw(im)
    for k in range(9):
        d.arc([w * 0.02 + k * 12, h * 0.05 + k * 9, w * 0.5 - k * 10, h * 0.75 - k * 12], 0, 360, fill=(176, 160, 124), width=1)
        d.arc([w * 0.6 + k * 8, h * 0.45 + k * 8, w * 0.98 - k * 8, h * 0.98 - k * 8], 0, 360, fill=(176, 160, 124), width=1)
    pts = [(w * (0.62 + 0.05 * math.sin(i * 0.7)), h * i / 12) for i in range(13)]
    d.line(pts, fill=(96, 136, 160), width=7)
    d.ellipse([w * 0.7, h * 0.12, w * 0.95, h * 0.42], fill=(120, 156, 170))
    d.line([(0, h * 0.8), (w * 0.3, h * 0.78), (w * 0.45, h * 0.52), (w * 0.66, h * 0.5), (w, h * 0.56)], fill=(90, 70, 50), width=3)
    for (x, y, t) in ((0.45, 0.5, "Sotoalto"), (0.2, 0.8, "El Collado"), (0.22, 0.34, "Robledal"), (0.52, 0.22, "La Fragua"), (0.5, 0.82, "Las Eras"), (0.82, 0.27, "Marjal")):
        d.rectangle([w * x - 4, h * y - 4, w * x + 4, h * y + 4], fill=(120, 40, 30))
        d.text((w * x + 8, h * y - 12), t, font=font(20), fill=(50, 40, 30))
    text_center(d, (0, 2, w, 34), "VALLE DE VALDEBRUMA", font(26), (50, 40, 30))
    put(sid, weather(im, 0.4))


def stencil(sid, txt, w=384, h=128, fg=(30, 28, 26), bg=(150, 118, 78)):
    im = Image.new("RGB", (w, h), bg)
    d = ImageDraw.Draw(im)
    text_center(d, (0, 0, w, h), txt, font(int(h * 0.5)), fg)
    put(sid, weather(im, 0.8))


def main():
    os.makedirs(os.path.join(ROOT, "assets", "textures", "gen"), exist_ok=True)
    banner("lucero", "ULTRAMARINOS LUCERO", (36, 70, 52), (230, 220, 180), border=(230, 220, 180))
    banner("botica", "BOTICA DEL RÍO", (30, 96, 100), (236, 236, 226), emblem=leaf_emblem)
    banner("cafe", "CAFÉ LA PARADA", (226, 214, 184), (140, 36, 30), border=(140, 36, 30))
    banner("taller", "TALLER ARDILA", (34, 62, 110), (236, 236, 230), sub="MECÁNICA · NEUMÁTICOS · SOLDADURA")
    banner("ferreteria", "FERRETERÍA EL YUNQUE", (28, 28, 30), (228, 180, 50), border=(228, 180, 50))
    banner("consultorio", "CONSULTORIO MÉDICO", (86, 110, 130), (240, 240, 236), sub="SOTOALTO")
    banner("ayuntamiento", "CASA CONSISTORIAL", (150, 142, 124), (52, 46, 40), wear=0.3)
    banner("conservas", "CONSERVAS SOTOALTO", (128, 44, 32), (240, 232, 214), sub="SOCIEDAD COOPERATIVA DEL VALLE · DESDE 1961")
    banner("cooperativa", "COOPERATIVA AGRARIA DEL VALLE", (60, 84, 44), (236, 228, 196))
    banner("estacion", "ESTACIÓN LIQUEN", (22, 40, 66), (226, 236, 240), sub="INSTITUTO DE BOTÁNICA HÍDRICA", emblem=lichen_emblem, wear=0.25)
    banner("bombeo", "ESTACIÓN DE BOMBEO Nº 2", (196, 196, 188), (30, 50, 80), wear=0.7)
    banner("estafeta", "ESTAFETA DEL VALLE", (196, 150, 40), (40, 36, 30))
    banner("escuela", "ESCUELA RURAL DE SOTOALTO", (214, 208, 190), (60, 80, 60), wear=0.4)
    banner("ermita", "ERMITA DE SAN TELMO", (140, 134, 120), (48, 44, 40), wear=0.3)
    banner("camping", "ÁREA DE ACAMPADA EL COLLADO", (70, 52, 36), (232, 222, 190), border=(232, 222, 190))
    banner("guarda", "CASETA FORESTAL · ROBLEDAL VIEJO", (52, 74, 50), (232, 226, 200))
    for sid, txt, arrow in (("s_sotoalto", "SOTOALTO", 0), ("s_fragua", "POLÍGONO LA FRAGUA", 0), ("s_eras", "LAS ERAS", 0), ("s_marjal", "MARJAL DE LA BRUMA", 0),
                            ("s_robledal", "ROBLEDAL VIEJO", 0), ("s_collado", "EL COLLADO", 0), ("s_cantera", "CANTERA DEL ALTO", 0), ("s_repetidor", "REPETIDOR", 0),
                            ("a_sotoalto_r", "SOTOALTO 1 km", 1), ("a_sotoalto_l", "SOTOALTO 1 km", -1), ("a_fragua", "LA FRAGUA", 1), ("a_eras", "LAS ERAS", -1),
                            ("a_marjal", "MARJAL · ESTACIÓN", 1), ("a_ermita", "ERMITA", 1), ("a_collado", "EL COLLADO", -1), ("a_robledal", "ROBLEDAL", -1)):
        road(sid, txt, arrow=arrow)
    road("no_pasar", "ZONA RESTRINGIDA · NO PASAR", bg=(170, 40, 32), fg=(240, 236, 226))
    road("puente", "PUENTE EN MAL ESTADO", bg=(226, 176, 40))
    road("bus_linea", "LÍNEA 4 · SOTOALTO — EL COLLADO", bg=(34, 62, 110), fg=(236, 236, 230))
    road("contratos", "TABLÓN DE ENCARGOS", bg=(70, 52, 36), fg=(232, 222, 190))
    warning("w_bruma", "PELIGRO", ["BRUMA DENSA", "USE PROTECCIÓN"])
    warning("w_marjal", "ATENCIÓN", ["TERRENO INUNDABLE", "NO SALGA DE LA PASARELA"])
    poster("p_evac", "AVISO DE EVACUACIÓN", ["#A todos los vecinos del valle", "Por orden de la Junta se desaloja", "Sotoalto y sus pedanías.", "-", "Punto de reunión: El Collado.", "Lleven agua, abrigo y documentos.", "No crucen el Marjal.", "-", "#Volveremos cuando", "#la bruma levante."])
    poster("p_coop", "COOPERATIVA DEL VALLE", ["#Campaña de la conserva", "Se necesitan manos para la", "recogida y el envasado.", "-", "Jornal justo y almuerzo.", "Pregunten en la fábrica,", "Polígono La Fragua.", "-", "#Lo que da el valle,", "#se queda en el valle."], accent=(60, 84, 44))
    poster("p_liquen", "INSTITUTO LIQUEN", ["#Estudio del liquen brumal", "Se ruega a los vecinos no", "recolectar ejemplares de", "color azulado en el Marjal.", "-", "Las muestras se entregan en la", "Estación, pasarela norte.", "-", "#Gracias por su", "#colaboración."], accent=(22, 40, 66))
    poster("p_notas", "ENCARGOS", ["Se busca quien lleve", "vendas al Consultorio.", "-", "Falta leña en la Ermita.", "-", "¿Alguien ha visto la", "llave de la Estación?", "-", "Trueque: cuerda por latas."], accent=(120, 90, 40), wear=0.5)
    painting("picture_a")
    painting("picture_b", portrait=True)
    valley_map("map_valley")
    stencil("st_conservas", "CONSERVAS")
    stencil("st_fragil", "FRÁGIL")
    stencil("st_coop", "S. COOP. VALLE", bg=(52, 84, 110), fg=(230, 230, 220))
    stencil("st_liquen", "I. LIQUEN 07", bg=(196, 196, 188), fg=(22, 40, 66))
    pack()
    atlas.save(os.path.join(ROOT, "assets", "textures", "gen", "signs_atlas.png"))
    json.dump(rects, open(os.path.join(ROOT, "data", "signs_atlas.json"), "w"), indent=0, sort_keys=True)
    print("rótulos:", len(rects), "fila final y=", cur[1] + cur[2])


if __name__ == "__main__":
    main()
