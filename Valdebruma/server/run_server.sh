#!/bin/bash
# Lanza el servidor dedicado de Valdebruma.
# Usa el binario exportado (builds/server/valdebruma_server.x86_64) si existe; si no, el proyecto con
# el editor de Godot 4.7.2 en modo sin ventana. Todo se configura con variables de entorno:
#   VB_PORT (24680)  VB_WORLD (valle)  VB_DATA (./datos)  VB_NAME ("Valdebruma")
#   VB_DIFFICULTY (tranquilo|normal|exigente)  VB_DAY_LENGTH (segundos de un día, 2400)
# Parada ordenada: crear el archivo <VB_DATA>/<VB_WORLD>/stop (guarda y cierra en ≤ 1 s),
# o enviar SIGTERM (el estado se guarda en disco cada 15 s y al salir el último jugador).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
PORT=${VB_PORT:-24680}
WORLD=${VB_WORLD:-valle}
DATA=${VB_DATA:-$HERE/datos}
mkdir -p "$DATA"
ARGS=(--server --port="$PORT" --world="$WORLD" --data="$DATA" --difficulty="${VB_DIFFICULTY:-normal}" --day-length="${VB_DAY_LENGTH:-2400}")
[ -n "${VB_NAME:-}" ] && ARGS+=(--name="$VB_NAME")
BIN="${VB_BIN:-$HERE/../../builds/server/valdebruma_server.x86_64}"
[ -x "$HERE/valdebruma_server.x86_64" ] && BIN="$HERE/valdebruma_server.x86_64"
if [ -x "$BIN" ]; then
  exec "$BIN" --headless -- "${ARGS[@]}"
else
  exec godot --headless --path "$HERE/.." -- "${ARGS[@]}"
fi
