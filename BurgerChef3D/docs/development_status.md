# Estado del desarrollo

**Última comprobación:** `tools/validate_data.py` (0 errores), `tools/static_check.py` (0 errores, 91 scripts), `tools/check_models.py`, `tools/check_ui_layout.py`, `tools/check_media.py` y `tools/gen_icons.py --check` (0 errores). Godot no estaba disponible: nada se ha ejecutado en el motor.

## Fase actual
Fases 1-9 implementadas en código (tutorial jugable incluido); Fase 10 (calidad) en curso: pruebas escritas pero sin ejecutar.

## Fases
| Fase | Estado |
|---|---|
| 1 Planificación y arquitectura | Terminada (docs/architecture.md, datos, estilo) |
| 2 Base técnica (horizontal, cámara, movimiento, táctil, escritorio, interacción) | Implementada, sin probar |
| 3 Escenario y recursos (restaurante, estaciones, ingredientes, iluminación, audio, iconos, texturas) | Implementada, sin probar. Comida, mostradores, fogones, neveras, cajas, fregadero, mesas y sillas usan modelos reales CC0 (KayKit/Kenney); freidora, dispensador, bandeja, campanita, bote de basura, lámparas y plantas usan los modelos propios (Tripo, optimizados) |
| 4 Mecánicas de cocina (recoger, colocar, recetas, montaje, plancha/freidora) | Implementada, sin probar |
| 5 Clientes y pedidos | Implementada, sin probar |
| 6 Progresión (30 niveles, misiones, logros, XP) | Implementada, sin probar |
| 7 Economía y personalización (monedas, 12 mejoras, tienda de 43 artículos) | Implementada, sin probar |
| 8 Interfaz completa (menú, HUD, pausa, ajustes, resultados) | Implementada y **rediseñada** (compacta, con marco de ancho limitado e iconos reales del pack), sin probar en el motor; **tutorial jugable** de 17 pasos implementado |
| 9 Guardado y audio | Implementada, sin probar |
| 10 Control de calidad | Pruebas escritas; sin ejecutar; sin mediciones de rendimiento |
| 11 Exportación Android | Presets para Google Play (AAB) y Amazon (APK), con Gradle y AdMob; sin exportar |
| 12 Entrega final | Pendiente |

## Sistemas funcionales (implementados, no probados en el motor)
Anuncios AdMob de prueba (recompensados e intersticial) · Datos de FerStudio y enlaces legales · Presets para Google Play y Amazon · Tutorial jugable · Fregadero y bandejas sucias · Recetas nuevas y catálogo de decoración por mejora · Vibración · Avisos de novedades en el menú · Licencias en créditos · Arranque y menú con fondo 3D · Selección de nivel (30) y modo libre · Partida completa (cuenta atrás, turno, pausa, resultados) · Jugador + táctil + escritorio · Restaurante con modelos reales (KayKit/Kenney y propios de Tripo), mostradores de ingredientes bajos y estructura procedural · Clientes con modelos y animaciones de KayKit · Pantalla de carga con el logotipo de FerStudio · Cajas con existencias y reposición · Plancha/freidora · Montaje y validación de recetas · Clientes, cola, pedidos, entrega · Economía, mejoras, tienda · Misiones/logros · Guardado y ajustes · Audio · es/en.

## Sistemas pendientes
Vista previa 3D de la personalización · Pruebas en motor y dispositivo · Probar AdMob con el plugin en un móvil · IDs reales de AdMob · Publicar la política de privacidad del juego · Capturas para la tienda · Mediciones de rendimiento · Exportación firmada.

## Errores conocidos
Ver `docs/known_issues.md`.

## Próximas tareas (en orden)
1. Abrir en Godot 4.7.2 (el editor importa `assets/models/`), corregir los errores de la primera carga y ejecutar `tests/test_runner.tscn` (incluye `test_models.gd`).
2. Revisar el juego en el editor (menú, un turno completo, pausa, resultados) y ajustar posiciones, escalas y luces; comparar con `docs/preview/` las colocaciones de los modelos reales.
3. Jugar el tutorial completo y los niveles 6-8 (bandejas sucias) y ajustar textos, alturas de la flecha y equilibrio.
4. Probar en un móvil: controles táctiles, rendimiento, aspectos de pantalla; ajustar calidad.
5. Exportar APK/AAB y revisar los requisitos de Google Play.

## Comandos de verificación
```
python3 tools/validate_data.py
python3 tools/static_check.py
python3 tools/check_models.py
python3 tools/check_ui_layout.py
python3 tools/check_media.py
godot --headless --path . res://tests/test_runner.tscn
```
Regenerar recursos: `python3 tools/gen_assets.py`, `tools/gen_app_icon.py <imagen>`, `tools/gen_characters.py --anims <pack> --skeletons <pack>` (y `--check`), `tools/gen_data.py`, `tools/gen_strings.py`. Modelos: `python3 tools/gen_models.py --kaykit <carpeta del pack> --kenney <carpeta del pack>` copia los modelos usados y regenera `scripts/core/model_table.gd`; `python3 tools/optimize_models.py <carpeta con los GLB originales de Tripo>` vuelve a generar `assets/models/custom/`; `python3 tools/preview_layout.py` renderiza vistas de la cocina en `docs/preview/`.
