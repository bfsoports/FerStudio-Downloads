#!/bin/bash
# Empaqueta la entrega: <salida>/Valdebruma.zip con el proyecto completo (sin caché de importación),
# la documentación y, si existen, el APK de depuración y el AAB en Valdebruma/builds/android/.
# Uso: tools/make_zip.sh [carpeta_salida]   (por defecto ../builds)
set -euo pipefail
cd "$(dirname "$0")/.."
OUT=$(realpath -m "${1:-../builds}")
STAGE=$(mktemp -d)
mkdir -p "$OUT" "$STAGE/Valdebruma"
git ls-files -z . | xargs -0 -I{} cp --parents "{}" "$STAGE/Valdebruma/" 2>/dev/null || \
  rsync -a --exclude .godot --exclude __pycache__ ./ "$STAGE/Valdebruma/"
mkdir -p "$STAGE/Valdebruma/builds/android"
for f in ../builds/android/Valdebruma-debug.apk; do
  [ -f "$f" ] && cp "$f" "$STAGE/Valdebruma/builds/android/"
done
cat > "$STAGE/Valdebruma/builds/LEEME.md" <<'TXT'
# Compilaciones

- `android/Valdebruma-debug.apk` — APK de depuración (arm64-v8a) firmado con clave de depuración.
  Instálalo con `adb install -r` o copiándolo al teléfono. No es apto para la tienda.
- El AAB y el servidor Linux no se incluyen por tamaño: se generan con los comandos de
  `docs/ANDROID_BUILD_GUIDE.md` y `docs/SERVER_DEPLOYMENT_GUIDE.md`, o se descargan como artefactos
  del flujo de GitHub Actions «Valdebruma CI».
TXT
rm -f "$OUT/Valdebruma.zip"
(cd "$STAGE" && zip -qr -9 "$OUT/Valdebruma.zip" Valdebruma)
rm -rf "$STAGE"
ls -la "$OUT/Valdebruma.zip"
