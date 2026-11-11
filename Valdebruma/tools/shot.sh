#!/bin/bash
# Captura con el visor de arte: tools/shot.sh <salida.png> <args del visor...>
out="$1"; shift
timeout 300 xvfb-run -a -s "-screen 0 1600x900x24" godot --audio-driver Dummy --path "$(dirname "$0")/.." --resolution 1600x900 -s tools/godot/viewer.gd -- --out="$out" "$@" 2>&1 | grep -E "captura|ERROR|SIN DEFINIR|rror" | grep -v ALSA | head
