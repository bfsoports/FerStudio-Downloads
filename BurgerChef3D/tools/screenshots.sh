#!/usr/bin/env bash
# Capturas del menú (y opcionalmente de una pantalla) en varios tamaños de móvil y tableta.
# Uso: tools/screenshots.sh <carpeta_salida> [godot]   (necesita xvfb-run en Linux)
set -u
OUT="${1:-screenshots}"; GODOT="${2:-godot}"
mkdir -p "$OUT"
cd "$(dirname "$0")/.."
fail=0
for spec in "2400x1080:phone_20x9" "1920x1080:phone_16x9" "3200x1440:phone_qhd_20x9" "2520x1080:phone_21x9" "1280x720:hd_16x9" "2048x1536:tablet_4x3" "2560x1600:tablet_16x10" "1600x720:phone_low_20x9"; do
  res="${spec%%:*}"; name="${spec##*:}"
  for scr in "" "upgrades" "customize" "credits"; do
    tag="$name${scr:+_$scr}"
    timeout 120 xvfb-run -a -s "-screen 0 ${res}x24" "$GODOT" --path . --rendering-driver opengl3 --resolution "$res" \
      res://tests/screenshots/screenshot_runner.tscn -- --out="$(realpath "$OUT")/$tag.png" ${scr:+--screen=$scr} >"$OUT/$tag.log" 2>&1 || { echo "FALLO $tag"; fail=1; }
    grep -E "SCRIPT ERROR|Parse Error" "$OUT/$tag.log" && fail=1
  done
done
# recetas del turno y escena de juego (con medición de rendimiento) en un móvil 20:9
for extra in "--recipes:ingame_recipes" "--bench=90:ingame_bench"; do
  arg="${extra%%:*}"; tag="${extra##*:}"
  timeout 180 xvfb-run -a -s "-screen 0 2400x1080x24" "$GODOT" --path . --rendering-driver opengl3 --resolution 2400x1080 \
    res://tests/screenshots/screenshot_runner.tscn -- --out="$(realpath "$OUT")/$tag.png" --scene=game $arg >"$OUT/$tag.log" 2>&1 || { echo "FALLO $tag"; fail=1; }
  grep -E "SCRIPT ERROR|Parse Error" "$OUT/$tag.log" && fail=1
  grep -E "BENCH" "$OUT/$tag.log" || true
done
exit $fail
