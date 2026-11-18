# Pruebas

## Automáticas (GDScript)
`godot --headless --path . res://tests/test_runner.tscn` (o F6 en el editor). En un proyecto recién descomprimido importa antes los recursos (abre el editor una vez o ejecuta `godot --headless --path . --import`): sin importar, las pruebas de modelos fallan porque Godot aún no ha convertido `assets/models/`. El ejecutor protege tu partida: guarda y restaura el estado y desactiva el autoguardado.

| Suite | Cubre |
|---|---|
| unit/test_data.gd | Datos sin errores, 30 niveles, validador, traducciones es/en |
| unit/test_media.gd | El vídeo de presentación se importa como `VideoStream`; se cargan la música del menú y la de las partidas; la pista de las partidas dura más de 100 s |
| unit/test_ui.gd | Todos los iconos del pack se cargan a varios tamaños; `ContentFrame` limita y centra el ancho; las 8 pantallas del menú, la pausa, los resultados y el HUD se construyen sin errores |
| unit/test_models.gd | Todos los ingredientes tienen modelo 3D; todos los modelos de la tabla se importan e instancian; la comida cambia de modelo de crudo a cocinado y a quemado sin acumular nodos |
| unit/test_recipe_validator.gd | Receta correcta, variaciones, incompleta, incorrecta, duplicados, orden, cocción, quemada |
| unit/test_cooking.gd | Estados de cocción, velocidad, calidad, no cocinables |
| unit/test_rewards_rules.gd | Recompensas, satisfacción, penalizaciones, victoria/derrota/estrellas |
| unit/test_economy.gd | Saldo insuficiente, compras, efectos de mejoras, tienda |
| unit/test_missions.gd | Progreso por estadísticas, reclamación única |
| unit/test_save.gd | Ida y vuelta, datos corruptos o con tipos inesperados, archivos, ajustes |
| unit/test_sink.gd | Bandeja sucia tras entregar, puesto bloqueado, fregadero (lavado, dos ranuras, vuelta al puesto), papelera que rechaza bandejas |
| unit/test_tutorial.gd | Pasos y textos del tutorial, estadísticas desactivadas, recetas de mejora, catálogo de decoración, fregadero rápido y guardado de los campos nuevos |
| unit/test_ads.gd | IDs de prueba, recompensas (x2, monedas gratis y su espera), límites del intersticial y segunda oportunidad del turno |
| integration/test_delivery.gd | Entrega correcta, incorrecta, caducada y con componentes que faltan |

**Resultado real: NO EJECUTADAS.** Godot no está disponible en el entorno donde se escribieron; nadie ha visto aún estas pruebas en verde. Si alguna falla, corrige y vuelve a ejecutar.

## Sin Godot (ejecutadas)
- `python3 tools/validate_data.py` -> 0 errores (11 ingredientes, 10 recetas, 30 niveles, 40 misiones, 9 mejoras, 33 artículos).
- `python3 tools/static_check.py` -> 0 errores, 0 avisos sobre 77 scripts: indentación, paréntesis, referencias entre scripts/autoloads, claves y argumentos de traducción, rutas `res://`, escenas `.tscn` y `$Nodo`. No es un compilador de GDScript.

- `python3 tools/check_models.py` -> 0 errores: la tabla de modelos coincide con los archivos (tamaños y desplazamientos), no sobran ni faltan archivos, todos los modelos citados por los scripts existen, todos los ingredientes tienen modelo, `assets/models` pesa 0,85 MB (máximo 3 MB), ningún modelo supera 3.000 triángulos, y las huellas de la distribución caben en la sala sin solaparse con pasillos de al menos 1,2 m (hoy entre 1,6 y 2,2 m).
- `python3 tools/check_media.py` -> 0 errores: el vídeo es Ogg Theora + Vorbis, la música de las partidas es OGG Vorbis, y los scripts apuntan a ellos.
- `godot --headless --path . res://tests/test_runner.tscn` -> 616 correctas, 0 fallidas (18-11-2026, Godot 4.7.2; importar antes dos veces con `--import`).
- `python3 tools/check_ui_layout.py` -> 0 errores: las cuadrículas y columnas de ancho fijo de cada ventana caben (p. ej. mejoras 954 de 978 px, resultados 894 de 898 px) y el HUD y el menú caben en el marco de 1280 px. No comprueba alturas ni textos largos.
- `tools/screenshots.sh <carpeta>` -> capturas reales del menú, Mejoras y Ajustes en 8 tamaños (20:9, 16:9, 21:9, QHD, 720p, tabletas 4:3 y 16:10). Lo ejecuta GitHub Actions en cada cambio.
- `python3 tools/preview_layout.py` -> vistas en `docs/preview/` de la cocina con los modelos reales. Es una comprobación visual de la geometría con las fórmulas de `restaurant.gd` duplicadas a mano; no es el motor.

## Manuales pendientes (necesitan el motor / un móvil)
| Caso | Esperado |
|---|---|
| Movimiento y colisiones | No se atraviesan paredes ni mostradores; se puede pasar entre isla y fuentes |
| Interacción a través de una pared | Imposible (el rayo se detiene en la pared) |
| Objeto fuera de alcance (3,2 m) | No se puede coger |
| Pulsar interactuar repetidamente | No duplica objetos ni cobros |
| Interrumpir un toque (llamada, notificación) | Joystick y cámara se cancelan y no quedan atascados |
| Cambiar de escena durante una acción | Sin errores; objetos transportados se liberan con la escena |
| Reiniciar nivel | Estadísticas y pedidos empiezan de cero; las monedas ganadas se conservan |
| Pausa y reanudación | Se detienen tiempo, paciencia, cocción y clientes; se reanudan igual |
| Aplicación suspendida y reanudada | Se guarda y se pausa sola al volver |
| Varias relaciones de aspecto (16:9, 18:9, 20:9, tablet) | HUD sin solapes ni texto cortado |
| Interfaz compacta en 16:9, 18:9, 20:9 y tablet | Nada se estira de lado a lado: HUD, menús y diálogos quedan centrados en un marco de 1280 px; sin textos cortados en español ni en inglés |
| Tamaño táctil de los botones | Se pulsan sin fallos con el pulgar (botones de 56-68 px, el principal de 84 px) |
| Iconos | Nítidos, sin deformar y con el icono correcto en cada botón, indicador y estadística |
| Aspecto de los modelos reales | Comida, fogones, neveras, cajas, mesas y sillas con su textura, orientadas hacia el jugador y sin atravesarse |
| Cocción en plancha y freidora | Los alimentos se apoyan en las parrillas / asoman de la olla y cambian de modelo al cocinarse y quemarse |
| Personalización de color | Mostrador, mesas y sillas se tiñen y la opción por defecto deja el modelo original |
| Rendimiento | Anotar dispositivo y FPS observados (no hay mediciones todavía) |
