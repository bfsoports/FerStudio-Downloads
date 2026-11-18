#!/bin/bash
# Instala Godot 4.7.2 estable (binario oficial) y, opcionalmente, sus plantillas de exportación.
# Uso: tools/ci/setup_godot.sh [--templates]
# Descarga de las versiones oficiales de github.com/godotengine/godot y deja el binario en
# /usr/local/bin/godot. Las descargas se guardan en ~/godot-dl para que la caché de CI las reutilice.
set -euo pipefail
VER=4.7.2
TAG=${VER}-stable
BASE=https://github.com/godotengine/godot/releases/download/${TAG}
DL=${GODOT_DL:-$HOME/godot-dl}
mkdir -p "$DL"
if [ ! -f "$DL/Godot_v${TAG}_linux.x86_64.zip" ]; then
  curl -fsSL --retry 4 -o "$DL/Godot_v${TAG}_linux.x86_64.zip" "$BASE/Godot_v${TAG}_linux.x86_64.zip"
fi
unzip -oq "$DL/Godot_v${TAG}_linux.x86_64.zip" -d "$DL/bin"
sudo install -m 755 "$DL/bin/Godot_v${TAG}_linux.x86_64" /usr/local/bin/godot
godot --version
if [ "${1:-}" = "--templates" ]; then
  if [ ! -f "$DL/Godot_v${TAG}_export_templates.tpz" ]; then
    curl -fsSL --retry 4 -o "$DL/Godot_v${TAG}_export_templates.tpz" "$BASE/Godot_v${TAG}_export_templates.tpz"
  fi
  T="$HOME/.local/share/godot/export_templates/${VER}.stable"
  mkdir -p "$T"
  rm -rf "$DL/tpl" && unzip -oq "$DL/Godot_v${TAG}_export_templates.tpz" -d "$DL/tpl"
  cp -r "$DL/tpl/templates/." "$T/"
  ls "$T"
fi
