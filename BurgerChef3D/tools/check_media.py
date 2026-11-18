#!/usr/bin/env python3
"""Comprueba, sin abrir Godot, la pantalla de carga (sin vídeo) y la música: que los archivos existen, que los códecs son los que
Godot reproduce (vídeo Ogg Theora + Vorbis; música OGG Vorbis), que pesan poco y que los scripts apuntan a ellos.

Uso:  python3 tools/check_media.py        (sale con código 1 si hay errores; usa ffprobe si está instalado)
"""
import json
import os
import re
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MAX_MUSIC = int(1.2 * 1024 * 1024)
errors = []


def probe(path):
    if not shutil.which("ffprobe"):
        return None
    out = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration:stream=codec_type,codec_name,width,height",
                          "-of", "json", path], capture_output=True, text=True)
    return json.loads(out.stdout) if out.returncode == 0 else None


def read(rel):
    return open(os.path.join(ROOT, rel), encoding="utf8").read()


def main():
    boot = read("scripts/core/boot.gd")
    audio = read("scripts/audio/audio_manager.gd")
    music_rel = re.search(r'"game": "res://([^"]+)"', audio).group(1)
    music = os.path.join(ROOT, music_rel)
    # el arranque ya no tiene vídeo: solo la pantalla de carga con el logotipo
    if "VideoStream" in boot or os.path.isdir(os.path.join(ROOT, "assets", "video")):
        errors.append("el arranque no debe usar vídeo (se pidió solo la imagen del logotipo)")
    if not os.path.exists(os.path.join(ROOT, "assets", "branding", "ferstudio_logo.png")):
        errors.append("falta assets/branding/ferstudio_logo.png (pantalla de carga)")
    for path, rel, limit, what in ((music, music_rel, MAX_MUSIC, "música"),):
        if not os.path.exists(path):
            errors.append("falta el archivo de %s: %s" % (what, rel))
            continue
        size = os.path.getsize(path)
        print("%s: %s, %.2f MB" % (what, rel, size / 1048576))
        if size > limit:
            errors.append("%s pesa %.2f MB (máximo %.2f MB)" % (rel, size / 1048576, limit / 1048576))
    if not music_rel.endswith(".ogg"):
        errors.append("la música de las partidas debería ser OGG Vorbis (.ogg), no %s" % music_rel)
    info = probe(music) if os.path.exists(music) else None
    if info is not None:
        codecs = {s["codec_type"]: s["codec_name"] for s in info["streams"]}
        print("música: códec", codecs, "duración %.1f s" % float(info["format"]["duration"]))
        if codecs.get("audio") != "vorbis":
            errors.append("la música debe estar en Vorbis (es %s)" % codecs.get("audio"))
    menu_rel = re.search(r'"menu": "res://([^"]+)"', audio).group(1)
    if not menu_rel.endswith(".ogg"):
        errors.append("la música del menú debería ser OGG Vorbis (.ogg, pesa 10 veces menos que WAV), no %s" % menu_rel)
    elif not os.path.exists(os.path.join(ROOT, menu_rel)):
        errors.append("falta %s" % menu_rel)
    elif os.path.getsize(os.path.join(ROOT, menu_rel)) > 300 * 1024:
        errors.append("la música del menú pesa demasiado (%d KB)" % (os.path.getsize(os.path.join(ROOT, menu_rel)) // 1024))
    for f in os.listdir(os.path.join(ROOT, "assets", "audio")):
        if f.startswith("music_") and f.endswith(".wav"):
            errors.append("música sin comprimir en assets/audio: %s" % f)
    if 'play_music("game")' not in read("scripts/progression/gameplay.gd"):
        errors.append("gameplay.gd no reproduce la música de las partidas")
    if 'play_music("menu")' not in read("scripts/interface/main_menu.gd"):
        errors.append("el menú principal no reproduce la música del menú")
    for e in errors:
        print("ERROR:", e)
    print("%d errores" % len(errors))
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
