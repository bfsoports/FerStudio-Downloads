#!/bin/bash
# Arranca el servidor dedicado unos segundos y muestra errores de script (uso en desarrollo).
cd "$(dirname "$0")/.."
D=${1:-/tmp/vb_srvcheck}
rm -rf "$D"
timeout 90 godot --headless --path . -- --server --port=24690 --data="$D" --world=prueba --exit-after=${2:-4} 2>&1 | grep -v "^$" | grep -E "ERROR|at:|\[servidor\]|\[net\]|Parse|Invalid" | head -${3:-30}
