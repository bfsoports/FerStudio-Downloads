#!/bin/bash
# Captura de los brazos en primera persona: tools/fpshot.sh <salida.png> <args de fp_viewer...>
out="$1"; shift
timeout 200 xvfb-run -a -s "-screen 0 1280x720x24" godot --audio-driver Dummy --path "$(dirname "$0")/.." --resolution 1280x720 -s tools/godot/fp_viewer.gd -- --out="$out" "$@" 2>&1 | grep -E "captura|ERROR|rror" | grep -v ALSA | head
