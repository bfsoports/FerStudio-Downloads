"""rodin_textures.py — prepara para móvil las texturas de los modelos generados con Hyper3D Rodin.

Entrada: <SRC>/<modelo>/tex/{texture_diffuse,texture_metallic-texture_roughness,texture_normal}.png
(2048², extraídas del GLB) y, para el Brumal, <SRC>/brumal/texture_emissive.png.
Salida: assets/textures/pbr/rd_<nombre>_{albedo.jpg,orm.jpg,normal.png} reducidas, con su .import
de compresión VRAM (ETC2/ASTC + S3TC), siguiendo la convención del resto de materiales PBR:
ORM = oclusión (R), rugosidad (G), metal (B).

Extras:
  · superviviente: el canal R del ORM guarda la máscara de la chaqueta (para teñirla por
    cosmético en assets/shaders/character.gdshader).
  · turismo: variante de pintura roja (rd_sedan_red_albedo.jpg) girando el tono de la chapa.

Uso: python3 tools/textures/rodin_textures.py [SRC=/root/tools/rodin]
"""
import os, sys, colorsys
import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "textures", "pbr")
SRC = sys.argv[1] if len(sys.argv) > 1 else "/root/tools/rodin"

# modelo de origen → (nombre del juego, lado del albedo/normal, lado del ORM)
SETS = {"survivor": ("rd_survivor", 1024, 1024), "brumal": ("rd_brumal", 1024, 512), "zarzo": ("rd_zarzo", 512, 256),
        "car_sedan": ("rd_sedan", 1024, 512), "car_van": ("rd_van", 1024, 512), "tractor": ("rd_tractor", 1024, 512)}

PARAMS = """[remap]

importer="texture"
type="CompressedTexture2D"

[params]

compress/mode=2
compress/high_quality=false
compress/lossy_quality=0.7
compress/hdr_compression=1
compress/normal_map=%d
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=0
"""


def stub(path, normal=False):
    """Fuerza compresión VRAM desde la primera importación (sin depender del editor)."""
    if not os.path.exists(path + ".import"):
        with open(path + ".import", "w") as f:
            f.write(PARAMS % (1 if normal else 0))


def save(img, name, quality=90):
    path = os.path.join(OUT, name)
    if name.endswith(".jpg"):
        img.convert("RGB").save(path, quality=quality, optimize=True)
    else:
        img.save(path, optimize=True)
    stub(path, normal="_normal" in name)
    return path


def hsv(arr):
    """RGB float [0,1] (h,w,3) → H,S,V."""
    r, g, b = arr[..., 0], arr[..., 1], arr[..., 2]
    mx = arr.max(-1); mn = arr.min(-1); d = mx - mn
    h = np.zeros_like(mx)
    m = d > 1e-6
    rc = np.where(m, (mx - r) / np.where(m, d, 1), 0); gc = np.where(m, (mx - g) / np.where(m, d, 1), 0); bc = np.where(m, (mx - b) / np.where(m, d, 1), 0)
    h = np.where(mx == r, bc - gc, np.where(mx == g, 2.0 + rc - bc, 4.0 + gc - rc))
    h = (h / 6.0) % 1.0
    s = np.where(mx > 1e-6, d / np.where(mx > 1e-6, mx, 1), 0)
    return h, s, mx


def hsv_to_rgb(h, s, v):
    i = np.floor(h * 6.0).astype(int) % 6
    f = h * 6.0 - np.floor(h * 6.0)
    p = v * (1 - s); q = v * (1 - f * s); t = v * (1 - (1 - f) * s)
    r = np.choose(i, [v, q, p, p, t, v]); g = np.choose(i, [t, v, v, q, p, p]); b = np.choose(i, [p, p, t, v, v, q])
    return np.stack([r, g, b], -1)


def run():
    os.makedirs(OUT, exist_ok=True)
    for src, (name, side, oside) in SETS.items():
        d = os.path.join(SRC, src, "tex")
        if not os.path.isdir(d):
            print("falta", d); continue
        alb = Image.open(os.path.join(d, "texture_diffuse.png")).convert("RGB")
        orm = Image.open(os.path.join(d, "texture_metallic-texture_roughness.png")).convert("RGB")
        nrm = Image.open(os.path.join(d, "texture_normal.png")).convert("RGB")
        alb_s = alb.resize((side, side), Image.LANCZOS)
        nrm_s = nrm.resize((side, side), Image.LANCZOS)
        o = np.asarray(orm.resize((oside, oside), Image.LANCZOS)).astype(np.float32) / 255.0
        o[..., 0] = 1.0                               # sin oclusión horneada
        if src == "survivor":
            a = np.asarray(alb.resize((oside, oside), Image.LANCZOS)).astype(np.float32) / 255.0
            h, s, v = hsv(a)
            mask = ((h > 0.14) & (h < 0.34) & (s > 0.18) & (v > 0.12) & (v < 0.8)).astype(np.float32)
            mi = Image.fromarray((mask * 255).astype(np.uint8)).filter(ImageFilter.MedianFilter(5)).filter(ImageFilter.GaussianBlur(1.2))
            o[..., 0] = np.asarray(mi).astype(np.float32) / 255.0
            mi.save(os.path.join(SRC, src, "jacket_mask_preview.png"))
        if src in ("car_sedan", "car_van", "tractor"):
            o[..., 2] = np.minimum(o[..., 2], 0.35)   # chapa vieja: metal contenido para que no ennegrezca sin reflejos
        save(alb_s, name + "_albedo.jpg")
        save(Image.fromarray((o * 255).astype(np.uint8)), name + "_orm.jpg", quality=88)
        save(nrm_s, name + "_normal.png")
        if src == "car_sedan":
            a = np.asarray(alb_s).astype(np.float32) / 255.0
            h, s, v = hsv(a)
            paint = ((h > 0.47) & (h < 0.66) & (s > 0.12)).astype(np.float32)
            paint = np.asarray(Image.fromarray((paint * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.0))).astype(np.float32) / 255.0
            red = hsv_to_rgb(np.full_like(h, 0.015), np.clip(s * 1.9 + 0.12, 0, 0.9), np.clip(v * 0.82, 0, 1))
            out = a * (1 - paint[..., None]) + red * paint[..., None]
            save(Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8)), "rd_sedan_red_albedo.jpg")
        if src == "brumal":
            em = Image.open(os.path.join(SRC, src, "texture_emissive.png")).convert("RGB").resize((512, 512), Image.LANCZOS)
            save(em, name + "_emission.jpg", quality=88)
        print("ok", name, side, oside)


if __name__ == "__main__":
    run()
