#!/bin/bash
# Prueba EN VIVO del juego real con render por software (Vulkan lavapipe + Xvfb):
# arranca el cliente, recorre el menú principal, crea una partida como anfitrión (servidor
# autoritativo en el mismo proceso), entra al valle, hace capturas en varios lugares, horas y
# climas con el HUD táctil y abre todas las pantallas de partida. Falla si hay errores de
# guion, si el juego no termina bien o si falta alguna captura.
# Uso: tools/ci/live_test.sh [dir_salida]
set -u
cd "$(dirname "$0")/../.."
OUT=$(realpath -m "${1:-../builds/live}")
rm -rf "$OUT" /tmp/vb_live_data
mkdir -p "$OUT"
VIEWS="collado:300,990,60,-6,10;sotoalto:690,640,-20,-4,18;fragua:733,330,-40,-4,16;tormenta_noche:300,990,150,6,21,tormenta"
MENU="main,play,play@join,profile,settings,settings@video,legal"
UI="inventory,craft,build,map,social,journal,journal@challenges,journal@board,pause"
timeout ${LIVE_TIMEOUT:-1500} xvfb-run -a -s "-screen 0 1280x720x24" godot --audio-driver Dummy --path . --resolution 1280x720 -- \
  --demo --out="$OUT" --data=/tmp/vb_live_data --max-time=${LIVE_TIMEOUT:-1500} --settle=2.0 \
  --hud --touch --menu="$MENU" --views="$VIEWS" --ui="$UI" > "$OUT/live.log" 2>&1
code=$?
grep -E "DEMO|SCRIPT ERROR|Parse Error" "$OUT/live.log" || true
errors=$(grep -c "SCRIPT ERROR\|Parse Error" "$OUT/live.log")
expected=0
missing=""
for n in $(echo "$VIEWS" | tr ';' '\n' | cut -d: -f1) $(echo "$MENU" | tr ',' '\n' | sed 's/@/_/; s/^/menu_/') ui_hud $(echo "$UI" | tr ',' '\n' | sed 's/@/_/; s/^/ui_/'); do
  expected=$((expected + 1))
  [ -s "$OUT/$n.png" ] || missing="$missing $n"
done
echo "salida=$code errores_de_guion=$errors capturas=$(ls "$OUT"/*.png 2>/dev/null | wc -l)/$expected"
if [ $code -ne 0 ] || [ "$errors" -ne 0 ] || [ -n "$missing" ]; then
  echo "PRUEBA EN VIVO: FALLO${missing:+ (faltan:$missing)}"
  exit 1
fi
echo "PRUEBA EN VIVO: CORRECTO"
