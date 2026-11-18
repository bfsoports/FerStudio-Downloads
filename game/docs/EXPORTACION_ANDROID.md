# Exportación a Android

El proyecto ya incluye `export_presets.cfg` con el preset **Android** (arm64-v8a, inmersivo, borde a borde, vibración, icono, paquete `com.ferstudio.sectorabandonado`). La orientación horizontal forzada sale de `display/window/handheld/orientation = Sensor Landscape` en `project.godot`.

## Requisitos
1. Godot **4.7.2** con las plantillas de exportación 4.7.2 instaladas (*Editor → Manage Export Templates → Download*).
2. JDK 17 o superior.
3. Android SDK con `platform-tools`, `build-tools;35.0.1` y `platforms;android-35` (o superior).
4. *Editor → Editor Settings → Export → Android*: rutas de `Java SDK Path` y `Android SDK Path`. Godot crea un keystore de depuración automáticamente.

## APK de prueba (debug)
Editor: *Project → Export → Android → Export Project* (marcar "Export With Debug").
Línea de comandos:
```
godot --headless --path game --export-debug "Android" ../build/SectorAbandonado-debug.apk
adb install -r build/SectorAbandonado-debug.apk
```

## Versión de publicación (release)
1. Crear keystore propio:
   `keytool -genkeypair -v -keystore sector.keystore -alias sector -keyalg RSA -keysize 2048 -validity 10000`
2. En el preset: *Keystore → Release*, usuario y contraseña (no subirlos al repositorio).
3. Para Google Play: activar *Gradle Build* (instalar la plantilla de compilación de Android desde *Project → Install Android Build Template*) y exportar en formato **AAB**.
4. Subir `version/code` en cada publicación.

## Notas de rendimiento
- Renderizador Mobile (Vulkan). En dispositivos sin Vulkan, Godot usa automáticamente OpenGL ES 3 (`rendering_device/fallback_to_opengl3=true`).
- Texturas importadas con compresión ETC2/ASTC.
- La calidad se autodetecta en el primer arranque (RAM/GPU) y puede cambiarse en *Configuración*.
- En móvil se activa la resolución dinámica (`PerfGovernor`) para sostener 30/60 FPS.
- Primera verificación recomendada en dispositivo: activar "Mostrar FPS" en Configuración y jugar hasta la ronda 10 en cada perfil.
