# Exportar a Android

> **No verificado**: no se ha exportado ni instalado todavía. Este documento describe el flujo oficial de Godot; comprueba las versiones exactas en la documentación oficial "Exporting for Android" de Godot 4.7 antes de empezar (no se han fijado números de SDK/JDK aquí a propósito).

## Requisitos
- Godot **4.7.2 stable** y sus plantillas de exportación (Editor -> Gestionar plantillas de exportación).
- Android SDK y JDK en las versiones que indique la documentación oficial de Godot 4.7. Configúralos en Editor -> Ajustes del editor -> Exportar -> Android.
- Un dispositivo Android con depuración USB (o emulador) para las pruebas.

## Configuración incluida (`export_presets.cfg`, preset "Android")
- Identificador `com.ferstudio.burgerchef3d`, nombre "Burger Chef 3D", versión 1.0.0 (código 1). Dos presets: «Android (Google Play, AAB)» (solo arm64) y «Amazon Appstore (Fire, APK)» (arm64 + armeabi-v7a). Los dos usan **Gradle** (lo necesita el plugin de AdMob): instala la plantilla de compilación de Android y, en el editor de Android, la app GABE (ver `docs/anuncios_admob.md`). Si quieres exportar sin anuncios y sin Gradle, desactiva «Use Gradle Build»: el juego funciona igual, sin anuncios.
- Solo `arm64-v8a`. Orientación horizontal por sensor (en `project.godot`), modo inmersivo.
- **Sin permisos** (Internet y vibración desactivados): el juego funciona sin conexión.
- `include_filter="*.json"`: los datos del juego son JSON y **no se exportan sin este filtro**.
- Excluye `tests/`, `tools/` y `docs/`. Los modelos de `assets/models/` se exportan ya importados (`export_filter="all_resources"`); comprueba el tamaño del APK tras exportar.
- Iconos de la app en `assets/icons/launcher_192.png` y `adaptive_*_432.png`.
- `min_sdk` y `target_sdk` vacíos (valores por defecto del motor). **Comprueba los requisitos vigentes de Google Play antes de publicar** y fija el SDK objetivo que exijan.

## APK de pruebas
1. Proyecto -> Exportar -> Android -> Exportar proyecto (formato APK, keystore de depuración).
2. `adb install -r BurgerChef3D.apk`.

## Android App Bundle (Google Play)
1. Proyecto -> Instalar plantilla de compilación de Android.
2. En el preset: activar "Use Gradle Build" y "Export Format" = AAB.
3. Crear una clave de firma de producción (p. ej. con `keytool`) y configurar `keystore/release*` **solo en tu editor**. Nunca subas la clave ni las contraseñas al repositorio (`.gitignore` ya excluye `*.keystore`/`*.jks`).
4. Aumenta `version/code` en cada subida.
5. Exporta, instala una build de prueba y revisa `release_checklist.md`.

## Pruebas de instalación
Orientación horizontal, controles táctiles, guardado tras cerrar y reabrir, botón Atrás, suspender/reanudar, varias resoluciones y rendimiento (anota dispositivo y FPS en `known_issues.md`).

## Actualizar versiones
Edita `version/name` y `version/code` en el preset y `Const.GAME_VERSION` (`scripts/core/const.gd`). Si cambias el formato de guardado, sube `Const.SAVE_VERSION` y añade la migración en `SaveManager._migrate`.
