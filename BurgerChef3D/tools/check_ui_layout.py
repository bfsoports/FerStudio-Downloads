#!/usr/bin/env python3
"""Comprueba, sin abrir Godot, que la interfaz responsive cabe en cualquier pantalla razonable.

Reproduce a mano las fórmulas de reparto de los scripts de scripts/interface (ventanas, columnas, tarjetas, comandas...)
con las constantes leídas de los propios scripts, para varios lienzos: 16:9, 20:9, tableta 4:3 y los tres tamaños de
interfaz de ajustes (pequeña 0,9, normal 1,0, grande 1,15). Verifica que el contenido de ancho fijo cabe en su ventana y
que la columna del menú no tapa a la hamburguesa. No sustituye a ver la interfaz en el motor (el texto largo y las
alturas finas solo se pueden comprobar ejecutándola).

Uso:  python3 tools/check_ui_layout.py        (sale con código 1 si algo no cabe)
"""
import math
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UI = os.path.join(ROOT, "scripts", "interface")
errors = []
BASE_W, BASE_H = 1024.0, 576.0   # tamaño base del lienzo (project.godot)
UI_SCALES = {"pequeña": 0.9, "normal": 1.0, "grande": 1.15}
ASPECTS = {"16:9": 16 / 9, "20:9": 20 / 9, "4:3": 4 / 3}


def const(path, name):
    src = open(os.path.join(UI, path), encoding="utf8").read()
    m = re.search(r"const %s\s*(?::=|=)\s*([\d.]+)" % name, src)
    if not m:
        errors.append("no encuentro la constante %s en %s" % (name, path))
        return 0.0
    return float(m.group(1))


def fit_columns(avail, item, gap, min_c, max_c):
    return max(min_c, min(max_c, int(math.floor((avail + gap) / (item + gap)))))


def fit_width(avail, cols, gap, max_w):
    return min(max_w, math.floor((avail - gap * (cols - 1)) / cols))


def canvas(aspect, scale):
    """Tamaño del lienzo con stretch «expand»: nunca menor que la base 1024 x 576 dividida por el factor de escala."""
    bw, bh = BASE_W / scale, BASE_H / scale
    if aspect >= bw / bh:
        return bh * aspect, bh
    return bw, bw / aspect


def need(ok, msg):
    if not ok:
        errors.append(msg)


def check_canvas(label, w, h):
    win_w_max, win_h_max = const("screens/menu_screen.gd", "WINDOW_W"), const("screens/menu_screen.gd", "WINDOW_H")
    margin = const("screens/menu_screen.gd", "WINDOW_MARGIN")
    win_w, win_h = min(win_w_max, w - 2 * margin), min(win_h_max, h - 2 * margin)
    inner = win_w - 2 * 18 - 6
    tag = "[%s %dx%d]" % (label, round(w), round(h))
    need(win_h >= 420, "%s la ventana mide solo %d px de alto" % (tag, win_h))
    tile = const("screens/level_select_screen.gd", "TILE_W")
    cols = fit_columns(inner, tile, 12, 3, 6)
    need(cols * tile + (cols - 1) * 12 <= inner + 1e-6, "%s niveles: %d columnas no caben" % (tag, cols))
    card_max, card_min = const("screens/upgrades_screen.gd", "CARD_W"), const("screens/upgrades_screen.gd", "CARD_MIN")
    cols = 2 if inner >= 2 * card_min + 14 else 1
    cw = fit_width(inner, cols, 14, card_max)
    need(cw >= 340 and cols * cw + (cols - 1) * 14 <= inner + 1e-6, "%s tarjetas de mejoras/recetas: %d x %d" % (tag, cols, cw))
    colw = min(const("screens/missions_screen.gd", "CARD_W"), inner)
    need(colw >= 560, "%s misiones: la columna mide solo %d" % (tag, colw))
    tcols = fit_columns(inner, 214, 8, 2, 4)
    need(fit_width(inner, tcols, 8, 214) >= 150, "%s pestañas de personalización demasiado estrechas" % tag)
    icols = fit_columns(inner, const("screens/customization_screen.gd", "CARD_W"), 12, 2, 3)
    need(fit_width(inner, icols, 12, const("screens/customization_screen.gd", "CARD_W")) >= 240, "%s tarjetas de personalización estrechas" % tag)
    rcol = min(930.0, inner)
    scols = fit_columns(rcol, const("screens/restaurant_screen.gd", "TILE_W"), 12, 2, 3)
    need(fit_width(rcol, scols, 12, const("screens/restaurant_screen.gd", "TILE_W")) >= 200, "%s casillas del restaurante estrechas" % tag)
    panel = const("settings_panel.gd", "PANEL_W")
    need(min(panel, inner) >= 520, "%s ajustes: el panel mide solo %d" % (tag, min(panel, inner)))
    pause_inner = min(900.0, w - 28) - 42
    need(min(panel, pause_inner) >= 520, "%s ajustes en pausa: el panel mide solo %d" % (tag, min(panel, pause_inner)))
    res_inner = min(940.0, w - 28) - 42
    stat = const("result_screen.gd", "STAT_W")
    rc = fit_columns(res_inner, stat, 12, 2, 3)
    need(fit_width(res_inner, rc, 12, stat) >= 190, "%s casillas de resultados estrechas" % tag)
    need(max(110.0, min(290.0, h - 28 - 330)) >= 110, "%s resultados: sin altura para el cuerpo" % tag)
    need(min(660.0, w - 28) >= 500, "%s el diálogo de nivel mide solo %d" % (tag, min(660.0, w - 28)))
    for cont in (True, False):
        mm = main_menu_layout(w, h, cont, "en" if not cont else "es")
        need(mm["total"] <= mm["avail_h"] + 1, "%s menú: la columna de botones (%d) no cabe en alto (%d)" % (tag, mm["total"], mm["avail_h"]))
        need(mm["tile_font"] >= 13, "%s menú: los nombres de las secciones quedan a %d px" % (tag, mm["tile_font"]))
        need(mm["tile_h"] >= 48, "%s menú: botones de sección de solo %d px de alto" % (tag, mm["tile_h"]))
        need(mm["play_h"] >= 75, "%s menú: botón Jugar de solo %d px" % (tag, mm["play_h"]))
    menu_w = mm["menu_w"]
    # comandas en columna a la derecha, bajo los botones de recetas y pausa (68 px): las tres deben quedar por encima
    # del botón de acción táctil (radio 62 x 0,8, a 56 px del borde inferior) para no taparlo
    tw = const("hud.gd", "TICKET_W")
    col_bottom = 12 + 68 + 8 + 3 * const("hud.gd", "TICKET_H_EST") + 2 * 6
    btn_top = h - 2 * 62 * const("touch_controls.gd", "BASE_SCALE") - 56
    need(col_bottom <= btn_top - 8, "%s HUD: las comandas (hasta y=%d) pisan el botón de acción (y=%d)" % (tag, col_bottom, btn_top))
    need(12 + 170 + 12 + 300 + 12 + tw + 12 <= w, "%s HUD: la barra superior no cabe" % tag)
    # la pastilla de interacción va abajo en el centro, entre el joystick y el botón de acción
    joy_right = 2 * 105 * const("touch_controls.gd", "BASE_SCALE") + 56
    need(w / 2 - 230 >= joy_right - 10, "%s HUD: la pastilla de interacción pisa el joystick" % tag)
    return {"ventana": (round(win_w), round(win_h)), "interior": round(inner), "menú": round(menu_w), "comanda": round(tw)}


_FONT_CACHE = {}


def text_w(text, size, font="Fredoka-Bold.ttf"):
    from PIL import ImageFont
    key = (font, size)
    if key not in _FONT_CACHE:
        _FONT_CACHE[key] = ImageFont.truetype(os.path.join(ROOT, "assets", "fonts", font), size)
    return _FONT_CACHE[key].getlength(text)


MENU_LABELS = {"es": ["RESTAURANTE", "MEJORAS", "RECETAS", "MISIONES", "PERSONALIZAR", "AJUSTES"],
               "en": ["RESTAURANT", "UPGRADES", "RECIPES", "MISSIONS", "CUSTOMIZE", "SETTINGS"]}


def main_menu_layout(w, h, has_continue=True, lang="es"):
    """Reproduce el reparto de main_menu.gd (_measure y _build_column) para un lienzo de w x h (sin muescas)."""
    c = lambda n: const("main_menu.gd", n)
    s = min(h / c("REF_H"), (w * 0.47) / (c("COL_W") + 2 * 10.0 + 30.0))
    y = 320.0 + 162.0 + (117.0 if has_continue else 30.0)
    tile_h_ref = max(82.0, min(104.0, (890.0 - y - 20.0) / 3.0))
    tile_w_ref = (c("COL_W") - 20.0 - 10.0) * 0.5
    fonts = []
    for t in MENU_LABELS[lang]:
        sz = 36
        while sz > 14 and text_w(t, sz) > tile_w_ref - 124.0:
            sz -= 1
        fonts.append(sz)
    total = (890.0 - c("COL_TOP")) * s
    return {"menu_w": c("COL_W") * s, "s": s, "play_h": 146.0 * s, "tile_h": tile_h_ref * s, "tile_w": tile_w_ref * s,
            "tile_font": min(fonts) * s, "total": total, "avail_h": h}


_TEXT_FONTS = {}


def text_w_medium(text, size):
    from PIL import ImageFont
    if size not in _TEXT_FONTS:
        _TEXT_FONTS[size] = ImageFont.truetype(os.path.join(ROOT, "assets", "fonts", "Poppins-Medium.ttf"), size)
    return _TEXT_FONTS[size].getlength(text)


def wrap_lines(text, w, size):
    n, cur = 1, ""
    for word in text.split():
        t = (cur + " " + word).strip()
        if text_w_medium(t, size) > w and cur:
            n += 1
            cur = word
        else:
            cur = t
    return n


def check_tutorial_card(label, w, h):
    """La tarjeta del tutorial (esquina superior izquierda) no debe bajar hasta el joystick en reposo (escala 1)."""
    import json
    tut = os.path.join(ROOT, "scripts", "tutorial", "tutorial.gd")
    src = open(tut, encoding="utf8").read()
    tc = lambda n: float(re.search(r"const %s\s*(?::=|=)\s*([\d.]+)" % n, src).group(1))
    strings = json.load(open(os.path.join(ROOT, "resources", "i18n", "strings.json"), encoding="utf8"))
    steps = re.search(r"const STEPS: Array = \[([^\]]+)\]", src).group(1)
    steps = re.findall(r'"(\w+)"', steps)
    cont = re.findall(r'"(\w+)"', re.search(r"const CONTINUE_STEPS: Array = \[([^\]]+)\]", src).group(1))
    card_w = max(tc("CARD_MIN_W"), min(tc("CARD_MAX_W"), w * tc("CARD_W_RATIO")))
    text_w = card_w - 30.0 - 24.0
    joy_r = const("touch_controls.gd", "JOY_RADIUS") * const("touch_controls.gd", "BASE_SCALE")
    joy_top = h - joy_r - 48.0 - joy_r
    worst = (0.0, "")
    for step in steps:
        keys = ["tut.%s_touch" % step] if step in ("move", "look") else ["tut." + step]
        for key in keys:
            for lang in ("es", "en"):
                text = strings[key][lang].replace("%s", strings["tut.act_touch"][lang])
                lines = wrap_lines(text, text_w, int(tc("CARD_FONT")))
                height = 24.0 + 30.0 + 6.0 + lines * 27.0
                if step in cont:
                    height += 6.0 + const("ui_kit.gd", "H_SMALL")
                else:
                    # pista de una o dos líneas (letra 15) en los pasos de cocina
                    height += 6.0 + 2 * 22.0 if step not in ("welcome", "move", "look", "customer", "book", "bell", "dirty", "trash", "tips") else 0.0
                bottom = tc("CARD_Y") + height
                if bottom > worst[0]:
                    worst = (bottom, "%s/%s" % (key, lang))
    need(worst[0] <= joy_top, "[%s] la tarjeta del tutorial (%s) llega a %d y el joystick empieza en %d" % (label, worst[1], worst[0], joy_top))
    return {"tutorial": int(worst[0]), "joystick": int(joy_top), "card_w": int(card_w)}


def main():
    print("%-26s %-34s" % ("lienzo", "ventana / interior / menú / comanda"))
    for aspect_name, aspect in ASPECTS.items():
        for scale_name, scale in UI_SCALES.items():
            w, h = canvas(aspect, scale)
            res = check_canvas("%s %s" % (aspect_name, scale_name), w, h)
            tut = check_tutorial_card("%s %s" % (aspect_name, scale_name), w, h)
            print("%-26s %dx%d  ventana %s  interior %d  menú %d  comanda %d  tutorial %d/%d" % (
                "%s %s" % (aspect_name, scale_name), round(w), round(h), res["ventana"], res["interior"], res["menú"], res["comanda"],
                tut["tutorial"], tut["joystick"]))
    for e in errors:
        print("ERROR:", e)
    print("%d errores" % len(errors))
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
