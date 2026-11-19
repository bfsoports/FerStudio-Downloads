#!/usr/bin/env python3
# Uso: python3 tools/slice_icons.py <carpeta con las hojas sheetN.png exportadas de Canva> assets/ui/icons [5,6]
# Recorta las 4 hojas de iconos exportadas de Canva (4 x 3 iconos cada una) en iconos sueltos cuadrados.
import sys, os
import numpy as np
from PIL import Image
from scipy import ndimage

SHEETS = [
    ["shop", "upgrade", "book", "target", "palette", "settings", "coin", "medal", "heart", "play", "skip", "home"],
    ["trophy", "star", "star_empty", "clock", "check", "close", "info", "warning", "lock", "gift", "burger", "fire"],
    ["trash", "cursor", "backpack", "downgrade", "rebirth", "stats", "skull", "lightning", "crown", "cash", "plus", "dice"],
    ["sound_on", "sound_off", "music_on", "music_off", "calendar", "player", "friend", "chat", "utensils", "cloche", "soda", "fries"],
    ["ing_bun_bottom", "ing_bun_top", "ing_patty", "ing_veggie_patty", "ing_bacon", "ing_cheese", "ing_lettuce", "ing_tomato", "ing_onion", "grill", "fryer", "board"],
    ["roller", "floor", "counter", "table", "chair", "lamp", "sign", "plant", "register", "sink", "crate", "hourglass"],
]
# hojas a procesar: todas por defecto, o un subconjunto con --sheets 5,6 (las hojas sheetN.png de la carpeta de origen)
SIZE = 160
src, out = sys.argv[1], sys.argv[2]
ONLY = [int(x) for x in sys.argv[3].split(",")] if len(sys.argv) > 3 else list(range(1, len(SHEETS) + 1))
FILE_OF = {n: i + 1 for i, n in enumerate(ONLY)}   # hoja n -> archivo sheet<i>.png dentro de src
os.makedirs(out, exist_ok=True)
total = 0
for si, names in enumerate(SHEETS):
    if si + 1 not in ONLY:
        continue
    im = Image.open(os.path.join(src, f"sheet{FILE_OF[si+1]}.png")).convert("RGBA")
    a = np.array(im)
    alpha = a[..., 3]
    mask = alpha > 24
    H, W = mask.shape
    big = ndimage.binary_dilation(mask, iterations=4)
    lab, n = ndimage.label(big)
    cells = {}
    for k in range(1, n + 1):
        ys, xs = np.where((lab == k) & mask)
        if ys.size < 150:
            continue
        cy, cx = ys.mean(), xs.mean()
        col = min(3, int(cx / (W / 4))); row = min(2, int(cy / (H / 3)))
        box = cells.get((row, col))
        b = [xs.min(), ys.min(), xs.max(), ys.max()]
        if box is None:
            cells[(row, col)] = b
        else:
            cells[(row, col)] = [min(box[0], b[0]), min(box[1], b[1]), max(box[2], b[2]), max(box[3], b[3])]
    assert len(cells) == 12, (si, len(cells), sorted(cells))
    for (row, col), (x0, y0, x1, y1) in cells.items():
        name = names[row * 4 + col]
        crop = im.crop((x0, y0, x1 + 1, y1 + 1))
        # limpia el halo casi transparente que deja el borrado del fondo
        c = np.array(crop)
        c[..., 3] = np.where(c[..., 3] < 10, 0, c[..., 3])
        crop = Image.fromarray(c)
        side = int(max(crop.size) * 1.06)
        sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        sq.paste(crop, ((side - crop.size[0]) // 2, (side - crop.size[1]) // 2))
        sq = sq.resize((SIZE, SIZE), Image.LANCZOS)
        p = os.path.join(out, name + ".webp")
        sq.save(p, "WEBP", quality=88, method=6, alpha_quality=95)
        total += os.path.getsize(p)
        print(f"{name:12s} {crop.size} -> {os.path.getsize(p)//1024 + 1} KB")
print("total KB", total // 1024)
