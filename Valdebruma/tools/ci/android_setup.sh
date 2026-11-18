#!/bin/bash
# Prepara la exportación Android en CI: ajustes del editor (SDK y JDK) y clave de DEPURACIÓN
# generada en el momento (nunca se guarda en el repositorio). La firma de publicación solo se
# usa si existen los secretos VALDEBRUMA_KEYSTORE_B64 / _ALIAS / _PASSWORD (ver docs/ANDROID_BUILD_GUIDE.md).
set -euo pipefail
SDK=${ANDROID_HOME:-${ANDROID_SDK_ROOT:-/usr/local/lib/android/sdk}}
JDK=${JAVA_HOME:?JAVA_HOME no definido}
KS_DIR="$HOME/.local/share/godot/keystores"
mkdir -p "$KS_DIR" "$HOME/.config/godot"
if [ ! -f "$KS_DIR/debug.keystore" ]; then
  keytool -genkeypair -v -keystore "$KS_DIR/debug.keystore" -storepass android -alias androiddebugkey -keypass android \
    -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US" >/dev/null 2>&1
fi
cat > "$HOME/.config/godot/editor_settings-4.7.tres" <<CFG
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/android_sdk_path = "$SDK"
export/android/java_sdk_path = "$JDK"
export/android/debug_keystore = "$KS_DIR/debug.keystore"
export/android/debug_keystore_user = "androiddebugkey"
export/android/debug_keystore_pass = "android"
CFG
{
  echo "GODOT_ANDROID_KEYSTORE_DEBUG_PATH=$KS_DIR/debug.keystore"
  echo "GODOT_ANDROID_KEYSTORE_DEBUG_USER=androiddebugkey"
  echo "GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD=android"
} >> "${GITHUB_ENV:-/dev/null}"
if [ -n "${VALDEBRUMA_KEYSTORE_B64:-}" ]; then
  echo "$VALDEBRUMA_KEYSTORE_B64" | base64 -d > "$RUNNER_TEMP/release.keystore"
  {
    echo "GODOT_ANDROID_KEYSTORE_RELEASE_PATH=$RUNNER_TEMP/release.keystore"
    echo "GODOT_ANDROID_KEYSTORE_RELEASE_USER=${VALDEBRUMA_KEYSTORE_ALIAS:?falta VALDEBRUMA_KEYSTORE_ALIAS}"
    echo "GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=${VALDEBRUMA_KEYSTORE_PASSWORD:?falta VALDEBRUMA_KEYSTORE_PASSWORD}"
    echo "HAS_RELEASE_KEY=true"
  } >> "${GITHUB_ENV:-/dev/null}"
  echo "Firma de publicación: configurada desde secretos."
else
  echo "Firma de publicación: no hay secretos; solo se generará la versión de depuración."
fi
ls "$SDK/build-tools"
