#!/bin/bash
# Capturas del juego real: tools/demo.sh <dir_salida> "<vistas>" [args extra]
cd "$(dirname "$0")/.."
OUT="$1"; VIEWS="$2"; shift 2
rm -rf /tmp/vb_demo_data
timeout ${DEMO_TIMEOUT:-420} xvfb-run -a -s "-screen 0 1280x720x24" godot --audio-driver Dummy --path . --resolution 1280x720 -- --demo --out="$OUT" --data=/tmp/vb_demo_data ${VIEWS:+--views="$VIEWS"} "$@" 2>&1 | grep -E "DEMO|SCRIPT ERROR|ERROR|at: |Parse" | grep -v -i "alsa\|audio" | head -${LINES_MAX:-40}
