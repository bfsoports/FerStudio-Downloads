# Guía de compilación para Android

## Qué se obtiene

| Salida | Preset | Firma | Estado |
|---|---|---|---|
| `Valdebruma-debug.apk` (arm64-v8a) | `Android` | clave de depuración | EJECUTADO: exportado y verificado con `apksigner` y `aapt2` |
| `Valdebruma-release.apk` | `Android` | clave de publicación propia | PENDIENTE: requiere tu almacén de claves |
| `Valdebruma-debug.aab` | `Android AAB` (Gradle) | clave de depuración | EJECUTADO: generado con Gradle 8.11.1 / AGP 8.6.1 (117 MB) |
| `valdebruma_server.x86_64` | `Linux Server` | — | EJECUTADO: exportado y arrancado |

Características del APK: paquete `io.github.bfsoports.valdebruma` (cámbialo antes de publicar si
usarás otra cuenta), versión 0.1.0 (código 1), SDK objetivo 36, orientación horizontal con sensor
(`sensorLandscape`), modo inmersivo, Vulkan (renderizador Mobile), texturas ETC2/ASTC, permisos
`INTERNET`, `ACCESS_NETWORK_STATE` y `ACCESS_WIFI_STATE` (nada más), icono adaptativo.

## Opción A — GitHub Actions (recomendada)

El flujo `.github/workflows/valdebruma.yml` se ejecuta en cada envío a `main`, `master` o `claude/**`
que toque `Valdebruma/`, y también a mano (pestaña **Actions → Valdebruma CI → Run workflow**).

1. Abre la ejecución y espera a que terminen los trabajos.
2. En **Artifacts** descarga `valdebruma-android-apk` (APK), `valdebruma-android-aab` (AAB),
   `valdebruma-servidor-linux` y `valdebruma-prueba-en-vivo` (capturas del juego real).
3. Instala el APK: `adb install -r Valdebruma-debug.apk` o cópialo al móvil y ábrelo (permite
   «instalar apps de origen desconocido»).

### Firma de publicación en CI

Crea tu propio almacén de claves (una vez, y guárdalo en lugar seguro: si lo pierdes no podrás
actualizar la app en la tienda):

```bash
keytool -genkeypair -v -keystore valdebruma-release.keystore -alias valdebruma \
  -keyalg RSA -keysize 4096 -validity 10000
base64 -w0 valdebruma-release.keystore > keystore.b64
```

En GitHub: **Settings → Secrets and variables → Actions** y añade:

| Secreto | Valor |
|---|---|
| `VALDEBRUMA_KEYSTORE_B64` | contenido de `keystore.b64` |
| `VALDEBRUMA_KEYSTORE_ALIAS` | el alias (`valdebruma` en el ejemplo) |
| `VALDEBRUMA_KEYSTORE_PASSWORD` | la contraseña |

Con esos secretos el trabajo `android` genera también `Valdebruma-release.apk`. Sin ellos solo se
genera la versión de depuración. Ninguna clave se guarda en el repositorio (`.gitignore` excluye
`*.keystore` y `*.jks`).

## Opción B — En tu equipo

1. Instala Godot 4.7.2 estable y sus plantillas de exportación (Editor → Gestionar plantillas, o
   descomprime `Godot_v4.7.2-stable_export_templates.tpz` en
   `~/.local/share/godot/export_templates/4.7.2.stable/`).
2. Instala JDK 17 o superior y el Android SDK con `platform-tools`, `build-tools;35.0.0` y
   `platforms;android-35` (por ejemplo con `sdkmanager`).
3. En Godot: **Editor → Configuración del editor → Exportar → Android**: ruta del SDK, ruta del JDK y
   almacén de depuración (`keytool -genkeypair -keystore debug.keystore -storepass android
   -alias androiddebugkey -keypass android -keyalg RSA -validity 10000 -dname "CN=Android Debug"`).
   En servidores sin escritorio se puede hacer como en `tools/ci/android_setup.sh`.
4. Importa una vez: `godot --headless --path . --import`.
5. Exporta:

```bash
godot --headless --path . --export-debug "Android" ../builds/android/Valdebruma-debug.apk
# AAB con Gradle (descarga Gradle y dependencias la primera vez)
godot --headless --path . --install-android-build-template --export-debug "Android AAB" ../builds/android/Valdebruma-debug.aab
# publicación (con tu clave en la configuración del editor o en las variables
# GODOT_ANDROID_KEYSTORE_RELEASE_PATH / _USER / _PASSWORD)
godot --headless --path . --export-release "Android" ../builds/android/Valdebruma-release.apk
```

6. Comprueba: `apksigner verify --print-certs` y `aapt2 dump badging` sobre el APK.

## Probar en un dispositivo

- `adb install -r Valdebruma-debug.apk`; registros con `adb logcat -s godot`.
- Para jugar en compañía en la misma Wi-Fi: un móvil o PC pulsa **Crear partida**; el resto **Unirse**
  con la dirección que muestra el menú de pausa del anfitrión (puerto UDP 24680 por defecto).
- Ajustes recomendados en gama media: perfil gráfico **Medio** (por defecto en móvil). En gama baja,
  **Bajo** (escala 0,7, sin sombras, 30 FPS).

## Problemas habituales

| Síntoma | Causa y solución |
|---|---|
| «No se encontró la plantilla» | Faltan las plantillas 4.7.2 o la versión no coincide exactamente. |
| «Could not find version of build tools that matches Target SDK» | Solo es un aviso: usa la build-tools disponible (35.0.0). |
| El APK no se instala sobre otro | Firmas distintas: desinstala la versión previa. |
| Pantalla negra al abrir | El dispositivo no tiene Vulkan 1.1. El renderizador Mobile lo exige; ver `PERFORMANCE_REPORT.md`. |
| Nadie puede unirse a mi partida | Cortafuegos o red de invitados que aísla dispositivos; usa un servidor dedicado. |

## Lo que NO se ha hecho (y por qué)

- No se ha instalado el APK en un teléfono físico ni en un emulador: el entorno de desarrollo no tiene
  dispositivos ni virtualización (`/dev/kvm`). Pendiente de probar en hardware real.
- No hay clave de publicación ni cuenta de Google Play: no se inventan; los pasos están arriba.
