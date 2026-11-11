# CONTINUIDAD DE DESARROLLO — Valdebruma

Archivo de trabajo para retomar el desarrollo sin repetir ni destruir nada.
Se actualiza a medida que avanza la construcción.

## Entorno verificado (11-11-2026)
- Godot `4.7.2.stable.official.ed1daf0bf` en `/usr/local/bin/godot` (binario en `/root/tools/godot`).
- Plantillas de exportación 4.7.2 en `~/.local/share/godot/export_templates/4.7.2.stable` (android + linux).
- Blender 4.2.9 LTS en `/usr/local/bin/blender` (solo modelado/rig/animación por script, en segundo plano).
- Android SDK en `/root/tools/android-sdk` (platform-tools, build-tools 35.0.0, platform android-35). JDK 21.
- Render por software: `xvfb-run` + lavapipe (Vulkan, renderer Mobile) y llvmpipe (OpenGL, Compatibility). Ambos probados.
- Sin `/dev/kvm` → no hay emulador Android utilizable. Sin dispositivo físico. Sin tarjeta de sonido (driver dummy).

## Decisiones técnicas
- Proyecto en `Valdebruma/` (raíz con `project.godot`). Herramientas reproducibles en `Valdebruma/tools/`.
- Arte: geometría propia generada por scripts de Blender (`tools/blender`), texturas PBR CC0 de Poly Haven
  (`tools/textures/fetch_polyhaven.py`), follaje/etiquetas/iconos generados en el proyecto, audio sintetizado
  (`tools/audio`). Los GLB solo llevan nombres de material; Godot aplica `assets/materials/<nombre>.tres`.
- Coordenadas: mundo 1280×1280 m, x∈[0,1280] este, z∈[0,1280] sur, sectores de 64 m (20×20). Norte = −Z.
- Red: ENet, servidor autoritativo (dedicado headless o anfitrión local en el mismo proceso), protocolo por
  mensajes versionado (`scripts/multiplayer/protocol.gd`). Movimiento: predicción en cliente + validación y
  corrección en servidor. Todo lo demás (inventario, botín, fabricación, construcción, supervivencia, IA,
  clima/tiempo) lo decide el servidor.
- Persistencia servidor: JSON versionado con escritura atómica y copias rotativas en `user://server/<mundo>/`.

## Estado
Ver `docs/PROJECT_STATUS.md` (tabla Sistema | Estado | Evidencia | Pendiente).

## Siguiente acción técnica
(se actualiza al final de cada bloque de trabajo)
