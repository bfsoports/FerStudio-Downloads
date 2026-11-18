# Valdebruma

Juego de supervivencia cooperativa en primera persona para Android (horizontal), con mundo abierto,
multijugador en línea con servidor autoritativo y estética de valle rural abandonado bajo la bruma.
Proyecto en **Godot 4.7.2 estable** y **GDScript**. Nombre, lore, mapa, criaturas, interfaz y logotipo
son originales.

> Estado: versión 0.1.0 jugable de principio a fin en PC y exportable a APK. Lo que falta o depende
> de terceros está en [`docs/PROJECT_STATUS.md`](docs/PROJECT_STATUS.md), sin adornos.

## Qué hay dentro

- Valle de 1,28 × 1,28 km en 400 sectores con carga progresiva y niveles de detalle: río, marjal,
  robledal, pueblo (Sotoalto), aldeas, estación de bombeo, fábrica, ermita, 39 edificios con interiores.
- Superviviente, Brumal, Zarzo, turismo, furgoneta y tractor generados con **Hyper3D Rodin** (malla,
  texturas PBR, esqueleto y animaciones) y optimizados en Blender; el resto del arte se genera con los
  guiones de `tools/` (Blender + texturas CC0 de Poly Haven).
- Supervivencia completa: salud, hambre, sed, energía, temperatura, cansancio, humedad, 16 estados.
- Inventario por huecos con peso, equipo en 7 ranuras, contenedores, botín por tablas, 50 objetos,
  20 recetas, 13 estructuras modulares con armazón y obra, permisos de grupo.
- Tres criaturas con IA por estados (acecho, investigación, alerta, persecución, búsqueda, huida…).
- Ciclo día/noche, clima (despejado, nublado, niebla, lluvia, tormenta con rayos) y bruma por zonas.
- Multijugador real: servidor dedicado sin ventana o partida alojada en el móvil, validación de todas
  las acciones, interés por sectores, grupos, chat con silencio y denuncia, intercambio, señales,
  reconexión y persistencia con escritura atómica, copias y recuperación de archivos dañados.
- Interfaz completa en español e inglés: menú con escena 3D, HUD, controles táctiles multitáctiles,
  inventario, fabricación, construcción con vista previa, mapa, diario, ajustes con perfiles gráficos,
  accesibilidad, privacidad y créditos.

## Requisitos

| Uso | Necesitas |
|---|---|
| Abrir y jugar en PC | Godot 4.7.2 estable (Linux, Windows o macOS) |
| Exportar a Android | Plantillas de exportación 4.7.2, Android SDK (build-tools 35), JDK 17+ |
| Regenerar el arte | Blender 4.2 LTS, Python 3 con Pillow y NumPy |
| Servidor dedicado | Linux x86_64 (binario exportado) o Godot 4.7.2 sin ventana |

## Arranque rápido

```bash
# importar recursos la primera vez (crea .godot/)
godot --headless --path . --import

# jugar (abre el menú principal)
godot --path .

# servidor dedicado
godot --headless --path . -- --server --port=24680 --world=valle --data=./datos
#   o bien: server/run_server.sh  (configurable con variables VB_*)
```

En la partida: **Crear partida** aloja el servidor en el propio dispositivo (otros se unen desde la
misma red con la IP que aparece en el menú de pausa) y **Unirse** conecta por dirección a un servidor
dedicado o a otro jugador. No existe servidor público oficial.

Controles en PC: WASD, ratón, E interactuar, F acción secundaria, Espacio saltar, Ctrl agacharse,
Mayús esprintar, Tab inventario, C fabricar, B construir, M mapa, J diario, G grupo, L linterna,
Intro chat, 1–4 accesos rápidos, Esc menú. En Android: joystick flotante, cámara arrastrando y botones.

## Pruebas

```bash
godot --headless --path . -- --unit-tests   # 781 comprobaciones: inventario, persistencia, datos, arte, textos…
tests/net_session.sh                         # servidor dedicado + 2 clientes ENet reales (40 comprobaciones)
tools/ci/live_test.sh                        # juego real con render por software: menú, partida, capturas
```

El flujo de GitHub Actions [`../.github/workflows/valdebruma.yml`](../.github/workflows/valdebruma.yml)
ejecuta todo lo anterior y publica como artefactos el **APK de depuración**, el **AAB** (Gradle), el
**servidor Linux** y las capturas de la prueba en vivo.

## Exportar

```bash
godot --headless --path . --export-debug "Android" ../builds/android/Valdebruma-debug.apk
godot --headless --path . --install-android-build-template --export-debug "Android AAB" ../builds/android/Valdebruma-debug.aab
godot --headless --path . --export-release "Linux Server" ../builds/server/valdebruma_server.x86_64
```

Detalles, firma de publicación y problemas habituales: [`docs/ANDROID_BUILD_GUIDE.md`](docs/ANDROID_BUILD_GUIDE.md).

## Estructura

```
autoload/      servicios globales: datos, ajustes, perfil, red, sesión, audio, controles, interfaz
scenes/        escenas mínimas (arranque, menú, mundo); casi todo se construye desde código
scripts/       core, world, player, gameplay, ai, inventory, multiplayer (cliente y servidor), ui
assets/        modelos GLB, materiales, texturas, sombreadores, iconos, fuentes, efectos, interfaz
data/          datos de juego en JSON (objetos, recetas, botín, estructuras, criaturas, progresión…)
localization/  textos de interfaz es/en
server/        lanzador, unidad systemd y Dockerfile del servidor dedicado
tests/         pruebas unitarias, clientes automáticos de red y capturas del juego real
tools/         generadores de arte, mundo, datos e iconos; visores; guiones de CI
docs/          documentación del proyecto
export/        iconos del lanzador de Android
```

## Documentación

[Diseño](docs/GAME_DESIGN_DOCUMENT.md) · [Arquitectura](docs/TECHNICAL_ARCHITECTURE.md) ·
[Red y servidor](docs/NETWORKING_AND_SERVER.md) · [Android](docs/ANDROID_BUILD_GUIDE.md) ·
[Despliegue del servidor](docs/SERVER_DEPLOYMENT_GUIDE.md) · [QA](docs/QA_TEST_REPORT.md) ·
[Rendimiento](docs/PERFORMANCE_REPORT.md) · [Licencias](docs/ASSET_LICENSES.md) ·
[Privacidad y tienda](docs/PRIVACY_AND_STORE_CHECKLIST.md) · [Cambios](docs/CHANGELOG.md) ·
[Estado](docs/PROJECT_STATUS.md)
