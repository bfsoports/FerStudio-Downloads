# Arquitectura

## Flujo de escenas
`boot.tscn` (comprueba datos, aplica ajustes) -> `main_menu.tscn` (fondo 3D + pantallas) -> `gameplay.tscn` (una partida). `SceneManager` hace el cambio con fundido y pasa parámetros (`mode`, `level_id`, `difficulty`).

## Autoloads (orden de carga; cada uno solo depende de los anteriores)
| Autoload | Responsabilidad |
|---|---|
| Events | Bus de señales global (monedas, pedidos, cocina, UI). Los sistemas se comunican sin conocerse. |
| Loc | Traducciones es/en desde `resources/i18n/strings.json` (`Loc.t(clave, args)`, `Loc.pick(dict)`). |
| Catalog | Carga y valida los JSON de `resources/data/`; consultas tipadas. |
| SettingsManager | Ajustes (ConfigFile `user://settings.cfg`), calidad gráfica y modo táctil. |
| GameState | Datos persistentes del jugador (monedas, XP, niveles, mejoras, estadísticas...). |
| SaveManager | Guardado JSON versionado: escritura atómica, copia de seguridad, archivos corruptos conservados. |
| EconomyManager | Única vía para ganar/gastar monedas; efectos de las mejoras; tienda. |
| MissionManager | Misiones/desafíos/logros a partir de `GameState.stats`; reclamación única. |
| AudioManager | Buses Music/SFX, pool de efectos, música en bucle. |
| SceneManager | Cambio de escena, botón Atrás de Android, guardado al pasar a segundo plano. |

## Datos (resources/data)
`ingredients`, `recipes` (reglas por receta: orden, extras permitidos), `levels` (30 niveles), `missions`, `upgrades`, `shop`, `customers`, `layout` (posiciones del restaurante). Se validan al arrancar (`DataValidator`) y con `tools/validate_data.py`.

## Sistemas de juego
- **Interacción**: `Interactable` (StaticBody3D con `get_prompt`/`interact`) -> `Carryable` (objetos que se llevan) y `Station` (ranuras fijas). El jugador lanza un rayo físico desde la cámara contra mundo+interactuables: el primer impacto manda, así que no se interactúa a través de paredes.
- **Colocación por ranuras**: un objeto solo se coloca en una ranura libre y válida de una estación; nunca queda en posiciones imposibles. Mientras se transporta no tiene colisión.
- **Cocción**: `CookStation` (plancha/freidora) avanza `FoodItem.cook_progress` con el tiempo de juego y la mejora de velocidad: crudo -> cocinándose -> cocinado -> quemado. Barra 3D + texto + humo + sonido.
- **Montaje y recetas**: `AssemblyStation` apila capas reales en un `BurgerStack`; `RecipeValidator` evalúa el resultado (correcta, variación, incompleta, ingredientes incorrectos, duplicados, orden, cocción, quemada).
- **Pedidos**: `OrderManager` (paciencia, estados Creado/Esperando/En preparación/Listo/Entregado/Cancelado, entrega por campana, recompensas con `RewardCalc`). Cada puesto (`ServicePoint`) tiene su bandeja de 3 ranuras.
- **Clientes**: `CustomerSpawner` + `Customer` (modelo procedural, rutas por puntos, cola de dos posiciones por puesto, burbuja con icono y barra de paciencia).
- **Turno**: `ShiftManager` (tiempo, estadísticas, victoria/derrota/estrellas con `ShiftRules`, recompensas de campaña una sola vez, récords del modo libre).
- **Interfaz**: `UITheme`/`UIKit` (sistema de diseño y componentes), `ContentFrame` (marco que limita el ancho del contenido), HUD compacto con contenedores, `TouchControls` (cada dedo pertenece a un único control), pantallas de menú derivadas de `MenuScreen` (ventana centrada de ancho fijo).

## Decisiones técnicas y motivos
- **Modelos 3D reales + recursos propios**: la comida, los mostradores, los fogones, las neveras, las cajas, el fregadero, las mesas y las sillas usan modelos de KayKit Restaurant Bits y Kenney Food Kit (`assets/models/`, solo los usados); la freidora, el dispensador de bebidas, la bandeja, la campanita, el bote de basura, las lámparas y las plantas usan los modelos propios del usuario (`assets/models/custom/`, generados con Tripo y simplificados por `tools/optimize_models.py`). `ModelLib` los instancia desde la tabla generada `scripts/core/model_table.gd` (escala y desplazamiento calculados desde las cajas envolventes por `tools/gen_models.py`); `FoodModels` elige el modelo de cada fase de cocción. Estructura, clientes, decoración sin equivalente, texturas y audio siguen siendo propios (`tools/gen_assets.py`). Terceros: los dos packs CC0, los modelos de Tripo (licencia por confirmar), los iconos del pack «Free Icon Pack» (licencia propia, ver `licenses.md`) y la fuente Poppins (OFL). Los ingredientes que no tienen modelo en esos packs no existen en el juego.
- **Interfaz sin estirarse**: todo el contenido (HUD, menús, diálogos) vive dentro de un `ContentFrame` de 1280 px como máximo y las ventanas miden 1020 px; los componentes de `UIKit` tienen ancho fijo (tarjetas de 300-470 px en cuadrículas centradas) en lugar de expandirse. Con `stretch aspect = expand` en un móvil 20:9 el lienzo es más ancho que 1280 px, pero la interfaz se queda centrada. Los iconos reales (PNG de 64 y 256 px) se reescalan una vez al tamaño real en pantalla y se guardan en caché (`UIKit.icon`).
- **Vídeo y música reales**: `boot.gd` reproduce el vídeo de FerStudio (Ogg Theora) mientras precarga el menú con `ResourceLoader.load_threaded_request`; `AudioManager` mantiene la música del menú y usa una pista real en OGG Vorbis (`music_cafe.ogg`) solo en las partidas.
- **Interfaz adaptable**: el lienzo base es 1024 x 576 y el tamaño de la interfaz se cambia en ajustes con `Window.content_scale_factor` (`SettingsManager.apply_ui_scale` avisa con `Events.ui_scale_changed`). Cada pantalla calcula sus columnas con el lienzo disponible (`UIKit.canvas_size`, `fit_columns`, `fit_width`).
- **Datos en JSON, no `.tres`**: se pueden validar fuera del motor (`validate_data.py`) y editar con cualquier editor de texto.
- **Interfaz construida por código con componentes reutilizables** (con escenas mínimas `boot`, `main_menu`, `gameplay`, `hud`, `player`): no hay editor de Godot en el entorno de desarrollo, y un `.tscn` escrito a mano no se puede comprobar. Migrar pantallas a escenas es una tarea futura (ver `known_issues.md`).
- **Clientes por rutas de puntos, sin NavMesh**: el recorrido es fijo y se evita todo obstáculo por diseño de la planta.
- **GL Compatibility**: máxima compatibilidad con móviles; sin SSAO ni efectos pesados.
