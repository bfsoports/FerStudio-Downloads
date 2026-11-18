"""import_binbun.py — integra efectos visuales CC0 de Binbun3D (BinbunVFX Vol. 2) en el proyecto.

Origen: los ZIP «…FXFree» aportados por el propietario del proyecto, cada uno con su license.txt
(Creative Commons Zero). Solo se copian los efectos que encajan con el juego (sin combate):
  FlameFX (hogueras), StylizedHitFX (golpes de herramienta), ElectricFX (rayo de tormenta),
  DarkMagicFX/area (nube de esporas del Farol), StatusFX (aura de estado).
Los ZIP del mismo lote sin fichero de licencia NO se integran (ver docs/ASSET_LICENSES.md).

Modificaciones aplicadas al copiar:
  · se omiten escenas de demostración, modelos de prueba y cielos HDR;
  · se quitan los botones de editor «About» que abrían páginas externas (OS.shell_open);
  · se elimina el desvanecido por proximidad con textura de profundidad de los shaders
    (evita la copia del búfer de profundidad en móvil);
  · los shaders del rayo ignoran la niebla (fog_disabled) para verse a lo lejos en tormenta.

Uso: python3 tools/vfx/import_binbun.py <carpeta con los packs extraídos>
"""
import os, re, shutil, sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
DEST = os.path.join(ROOT, "assets", "BinbunVFX_Vol2")
SRC = sys.argv[1] if len(sys.argv) > 1 else "/root/tools/efectos_zip"

# pack → (subcarpeta dentro de BinbunVFX_Vol2, escenas de efecto que se conservan)
PACKS = {
    "FlameFXFree": ("FlameFX", ["effects/fire/vfx_basic_fire_01.tscn"]),
    "HitFXFree": ("StylizedHitFX", ["effects/hit/vfx_hit_01.tscn", "effects/hit/vfx_hit_02.tscn", "effects/impact/vfx_impact_01.tscn"]),
    "ElectricFXFree": ("ElectricFX", ["effects/zap/vfx_zap_lightning_01.tscn"]),
    "DarkMagicFXFree": ("DarkMagicFX", ["effects/area/vfx_evil_area_01.tscn"]),
    "StatusFXFree": ("StatusFX", ["effects/status/vfx_status_shatter.tscn"]),
}
SHARED = ["VFXEmitterBB.gd", "VFXOmniLightBB.gd", "VFXControllerBB.gd"]


def strip_about(text):
    i = text.find('@export_group("About")')
    return text[:i].rstrip() + "\n" if i >= 0 else text


def strip_depth(text):
    text = re.sub(r"^uniform sampler2D depth_texture[^\n]*\n", "", text, flags=re.M)
    out, i = [], 0
    while True:
        m = re.search(r"[ \t]*if\s*\(\s*proximity_fade\s*\)\s*\{", text[i:])
        if not m:
            out.append(text[i:])
            break
        out.append(text[i:i + m.start()])
        j = i + m.end()
        depth = 1
        while depth > 0 and j < len(text):
            depth += {"{": 1, "}": -1}.get(text[j], 0)
            j += 1
        if j < len(text) and text[j] == "\n":
            j += 1
        i = j
    return "".join(out)


def copy(src, dst):
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    if src.endswith(".gd"):
        open(dst, "w").write(strip_about(open(src).read()))
    elif src.endswith(".gdshader") or src.endswith(".gdshaderinc"):
        text = strip_depth(open(src).read())
        if "/ElectricFX/" in src.replace(os.sep, "/"):      # el rayo lejano debe verse a través de la niebla
            text = re.sub(r"render_mode\s+", "render_mode fog_disabled, ", text, count=1)
        open(dst, "w").write(text)
    elif src.endswith(".tscn"):
        # sin los UID de origen: los recursos se resuelven por ruta y no hay avisos de UID desconocido
        text = re.sub(r'(\[ext_resource[^\]]*?) uid="uid://[a-z0-9]+"', r"\1", open(src).read())
        open(dst, "w").write(text)
    else:
        shutil.copyfile(src, dst)


def run():
    if os.path.isdir(DEST):
        shutil.rmtree(DEST)
    n = 0
    for pack, (sub, scenes) in PACKS.items():
        base = os.path.join(SRC, pack, pack, "assets", "BinbunVFX_Vol2")
        for name in SHARED:
            for ext in ("", ".uid"):
                s = os.path.join(base, "shared", "script", name + ext)
                if os.path.exists(s):
                    copy(s, os.path.join(DEST, "shared", "script", name + ext))
        used = set()
        for scene in scenes:
            s = os.path.join(base, sub, scene)
            copy(s, os.path.join(DEST, sub, scene))
            n += 1
            for ref in re.findall(r'path="res://assets/BinbunVFX_Vol2/([^"]+)"', open(s).read()):
                used.add(ref)
        for ref in sorted(used):
            for ext in ("", ".uid"):
                s = os.path.join(base, ref + ext)
                if os.path.exists(s):
                    copy(s, os.path.join(DEST, ref + ext))
        # inclusiones de shader
        for r, _, fs in os.walk(os.path.join(base, sub)):
            for f in fs:
                if f.endswith(".gdshaderinc") or f == "license.txt":
                    rel = os.path.relpath(os.path.join(r, f), base)
                    copy(os.path.join(r, f), os.path.join(DEST, rel))
    with open(os.path.join(DEST, "LEEME.txt"), "w") as f:
        f.write("Efectos de Binbun3D (BinbunVFX Vol. 2), licencia CC0. Copia recortada y adaptada por\n"
                "tools/vfx/import_binbun.py (ver la cabecera de ese guion y docs/ASSET_LICENSES.md).\n")
    print("efectos integrados:", n)


if __name__ == "__main__":
    run()
