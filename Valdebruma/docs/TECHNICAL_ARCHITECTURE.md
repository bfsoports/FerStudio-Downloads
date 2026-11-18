# Arquitectura técnica

## Principios

1. **Un único proyecto** para cliente, anfitrión y servidor dedicado; el modo lo decide
   `scripts/core/boot.gd` según los argumentos.
2. **El servidor manda.** El cliente solo envía peticiones (`Session.request_*`, `Net.send`) y dibuja
   lo que el servidor confirma. Ningún resultado de juego se decide en el cliente.
3. **Datos fuera del código.** Objetos, recetas, botín, estructuras, criaturas, efectos, documentos,
   progresión, materiales y modelos se describen en `data/*.json`; el código los interpreta.
4. **Arte reproducible.** Casi todo el arte sale de guiones (`tools/`), con texturas CC0 y modelos de
   Hyper3D importados por guion. Regenerar es repetible y documentado.
5. **Pensado para móvil.** Renderizador Mobile (Vulkan), texturas ETC2/ASTC, MultiMesh para la
   vegetación, LOD por sector, presupuesto de tiempo por fotograma para construir el mundo.

## Modos de ejecución (`boot.gd`)

| Argumentos (tras `--`) | Modo |
|---|---|
| (ninguno) | Cliente: arranque → menú (`Ui.goto_menu`) |
| `--server [--port --world --data --difficulty --day-length --name --hour --test-kit --exit-after]` | Servidor dedicado sin interfaz |
| `--admin=list|ban|unban [--account]` | Administración de cuentas |
| `--unit-tests` | Pruebas unitarias |
| `--bot=<escenario> --connect=host:puerto --name=` | Cliente automático de pruebas |
| `--demo --out= --views= [--menu= --ui= --hud --touch]` | Recorrido real con capturas |

## Autoloads (orden de carga)

| Nodo | Archivo | Responsabilidad |
|---|---|---|
| `GameData` | `autoload/game_data.gd` | Carga `data/*.json` y el `WorldMap`; textos bilingües |
| `Config` | `autoload/config.gd` | Ajustes con rangos, perfiles gráficos, guardado atómico |
| `Profile` | `autoload/profile.gd` | Identidad local (cuenta + secreto aleatorios), nombre, cosméticos, servidores recientes |
| `Net` | `autoload/net.gd` | Transporte ENet: anfitrión/cliente, reintentos, RPC genéricos, ping |
| `Session` | `autoload/session.gd` | Espejo del estado que envía el servidor + señales para mundo e interfaz |
| `AudioDirector` | `autoload/audio_director.gd` | Buses, ambientes por contexto con fundidos, efectos 2D/3D, pasos, música |
| `Controls` | `autoload/controls.gd` | Entrada unificada (teclado/ratón y táctil) |
| `Ui` | `autoload/ui.gd` | Tema, pila de pantallas, HUD, avisos, diálogos, carga y flujo de partida |

## Cliente

```
WorldRoot (scripts/world/world_root.gd)
├─ SkyWeather          cielo procedimental, sol/luna, niebla, lluvia, rayos, variables globales de sombreado
├─ Water               plano único con profundidad leída del mapa de alturas
├─ Dynamic             objetos que dicta el servidor: recogibles, estructuras, jugadores remotos, criaturas, efectos
├─ WorldStreamer       cola de trabajos por sector con presupuesto en ms
│   └─ Sector ×N       terreno + bordes, colisión HeightMap, MultiMesh de árboles por LOD, hierba, carreteras,
│                      objetos, edificios con interiores, puertas, contenedores, luces
├─ PlayerController    CharacterBody3D, cámara, brazos en 1.ª persona, sonda de interacción, predicción
└─ BuildMode           vista previa y encaje de estructuras
```

- **Streaming**: el valle tiene 20×20 sectores de 64 m. Nivel 0 (cerca) con todo; nivel 1 con
  árboles LOD1 y edificios; nivel 2 con terreno y follaje LOD2. Los trabajos se reparten entre
  fotogramas (14 ms al cargar, 4–6 ms en juego).
- **Interacción**: cada `Interactable` se registra en una lista; el jugador elige el mejor por
  distancia, ángulo, visibilidad y prioridad, lo resalta y muestra el texto de acción.
- **Predicción**: el jugador se mueve en local y envía su estado 15 veces por segundo; si el
  servidor rechaza un movimiento, corrige la posición (`S.CORRECT`).
- **Jugadores remotos y criaturas**: interpolación con 130–160 ms de retraso; animación según
  velocidad real, estado de IA y acción visible.
- **Materiales**: los GLB solo llevan nombres de material; `AssetLib.apply_materials` los sustituye
  por `assets/materials/<nombre>.tres`, generados desde `data/materials.json`.

## Servidor (`scripts/multiplayer/server/`)

| Clase | Responsabilidad |
|---|---|
| `GameServer` | Conexiones, bucles (acciones 20 Hz, criaturas 10 Hz, fotos 12 Hz, lento 1 Hz), despacho de mensajes, validación de movimiento, interés por sectores, guardado |
| `ServerPlayer` | Estado del jugador: posición, necesidades, inventario, equipo, progreso, límites de peticiones |
| `ServerWorld` | Puertas, cerraduras, contenedores, objetos sueltos, botín con reaparición, recolección, estructuras |
| `ServerEnvironment` | Hora, clima (Markov), temperatura ambiente por lugar |
| `ServerSurvival` | Necesidades, estados, colapso y reaparición, uso de objetos |
| `ServerActions` | Interacciones, inventario, fabricación, construcción, acciones con duración |
| `ServerCreatures` | IA por estados, percepción, A* (AStarGrid2D) |
| `ServerSocial` | Grupos, chat, emotes, señales, intercambio, denuncias |
| `ServerProgress` | Experiencia, niveles, desafíos, logros, encargos, cosméticos |
| `ServerPersistence` | Cuentas, guardado atómico con SHA-256 y copias, recuperación |
| `Guard` | Saneado de todo dato que llega de la red |

## Interfaz (`scripts/ui/`)

`UiKit` (tema y constructores), `UiScreen` (base de pantallas a pantalla completa con zonas seguras),
`Hud`, `TouchControls`, `ChatBox` y una clase por pantalla. La interfaz se construye desde código
para mantener un único estilo y adaptar tamaños táctiles; no hay estado de juego en ella.

## Datos

| Archivo | Contenido |
|---|---|
| `data/items.json` | 50 objetos: categoría, peso, pila, uso, equipo, durabilidad, recarga |
| `data/recipes.json` | 20 recetas |
| `data/loot_tables.json` | 22 tablas de botín |
| `data/harvest.json` | 9 tipos de recolección con rendimiento y reaparición |
| `data/structures.json` | 13 estructuras con costes, estación, permisos |
| `data/creatures.json` | 3 criaturas con percepción y comportamiento |
| `data/effects.json` | 16 estados |
| `data/documents.json` | 9 documentos (es/en) |
| `data/progression.json` | niveles, ventajas, desafíos, logros, encargos, cosméticos, dificultad |
| `data/world/*` | mapa de alturas, regiones, mezcla de suelos, vegetación, `world.json` |
| `data/buildings/*.json` | colisiones, puertas, contenedores, luces e interiores de cada edificio |
| `data/models/*.json` | tamaños, colisiones y clips de los modelos |
| `data/materials.json` | definición de los 149 materiales |
| `data/legal.json` | créditos, privacidad, términos, soporte |

## Cadena de arte

```
tools/textures/fetch_polyhaven.py → assets/textures/pbr (CC0)
tools/blender/gen_*.py            → assets/models/** + data/models/*.json + data/buildings/*.json
tools/blender/import_rodin.py     → personajes, criaturas y vehículos de Hyper3D Rodin
tools/textures/rodin_textures.py  → texturas rd_* reducidas
tools/vfx/import_binbun.py        → assets/BinbunVFX_Vol2 (CC0)
tools/world/build_world.py        → data/world/* + mapa
tools/data/make_*.py              → data/*.json, localization/strings.csv
tools/audio/synth.py              → assets/audio/*.ogg
tools/ui/make_*.py                → iconos, logotipo, iconos de Android
tools/godot/build_materials.gd    → assets/materials/*.tres
tools/godot/render_icons.gd       → assets/icons/items/*.png
```

Visores de verificación: `tools/godot/viewer.gd` (modelos y animaciones), `fp_viewer.gd` (brazos),
`vfx_viewer.gd` (efectos) y `tests/demo_shots.gd` (juego real).

## Rendimiento

Ver `PERFORMANCE_REPORT.md`. Puntos clave: MultiMesh por especie y LOD, colisiones simples
(cilindros para troncos, cajas para edificios), sin sombras en luces puntuales, distancia de visión
configurable (2–6 sectores), escala de render 0,5–1,0, límite de FPS, sin lectura de profundidad en
los efectos.

## Riesgos conocidos

- Sin prueba en hardware Android real (no disponible en el entorno de desarrollo).
- ENet sin cifrar.
- Una sola versión de guardado (sin migraciones reales todavía).
