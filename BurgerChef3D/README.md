# Burger Chef 3D

Simulador 3D en primera persona de una hamburguesería para Android (Godot 4.7.2, GDScript, renderer GL Compatibility).
Estado actual: **Fases 1-9 implementadas en código, tutorial jugable incluido** (ver `docs/development_status.md`). **Todavía no se ha abierto en Godot ni probado en un dispositivo**: lee `docs/known_issues.md` antes de empezar.

## Cómo abrirlo
1. Descomprime el ZIP y abre la carpeta `BurgerChef3D/` con **Godot 4.7.2** (Importar proyecto -> `project.godot`).
2. La primera vez Godot importa las texturas, **la interfaz de `assets/ui/` (fondo, logotipo, botones e iconos)**, audio, fuentes y los **modelos 3D de `assets/models/`** (puede tardar un momento; las pruebas de modelos y el juego necesitan esa importación).
3. Pulsa Ejecutar (F5). La escena principal es `scenes/boot/boot.tscn` y lleva al menú.
4. Pruebas automáticas (tras la primera importación): `godot --headless --path . res://tests/test_runner.tscn` (o F6 sobre `tests/test_runner.tscn`).

## Controles
Móvil: joystick virtual (mitad izquierda), deslizar en la mitad derecha para mirar, botón de la mano para interactuar. Escritorio: WASD, ratón, E (o clic), R (recetas) y Esc. Detalles en `docs/controls.md`.

## Contenido jugable
- Tutorial jugable de 17 pasos (JUGAR > Tutorial), con flechas que guían y textos para táctil o teclado.
- 14 recetas (4 se desbloquean con la mejora «Recetas nuevas»), 11 ingredientes (todos con modelo 3D real), plancha y freidora con cocción real, tablas de montaje, fregadero para las bandejas sucias (desde el nivel 6), clientes con pedidos y paciencia.
- Campaña de 30 niveles definidos por datos (`resources/data/levels.json`), modo libre, 41 misiones/desafíos/logros.
- Economía con monedas, 12 mejoras con efecto real y tienda de personalización (43 artículos, 10 con el «Catálogo de decoración»). Vibración en el móvil y avisos de novedades en el menú.
- Anuncios de Google AdMob (de prueba hasta poner los IDs propios): segunda oportunidad, x2 monedas, monedas gratis e intersticial al perder. Ver `docs/anuncios_admob.md`.
- Un juego de **FerStudio** (rincondigitaloficial.com). Preparado para la Amazon Appstore: `docs/amazon_appstore.md` y recursos en `store/`.
- Guardado persistente versionado, ajustes, español e inglés, audio sintetizado, texturas propias, menú ilustrado e iconos 3D cartoon propios (hechos con Canva) que se adaptan a cualquier pantalla y cocina con modelos reales: KayKit Restaurant Bits y Kenney Food Kit (CC0) más freidora, dispensador de bebidas, bandeja, campanita, bote de basura, lámparas y plantas propios (Tripo, optimizados para móvil).

## Documentación
`docs/architecture.md` · `docs/controls.md` · `docs/style_guide.md` · `docs/testing.md` · `docs/build_android.md` · `docs/licenses.md` · `docs/release_checklist.md` · `docs/acceptance_checklist.md` · `docs/known_issues.md` · `docs/development_status.md` · `docs/anuncios_admob.md` · `docs/amazon_appstore.md`

## Herramientas (Python 3, sin Godot)
`tools/validate_data.py` valida los datos · `tools/static_check.py` comprobación estática de scripts/escenas/traducciones · `tools/gen_*.py` regeneran texturas, audio, datos, textos y la tabla de modelos · `tools/slice_icons.py` recorta las hojas de iconos de Canva · `tools/process_ui.py` prepara el logotipo y los botones del menú · `tools/screenshots.sh` saca capturas del juego en 8 tamaños de pantalla (necesita Godot y xvfb) · `tools/check_ui_layout.py` comprueba que los anchos fijos de la interfaz caben · `tools/check_models.py` comprueba modelos, referencias y huellas de la distribución · `tools/preview_layout.py` renderiza vistas de la cocina con los modelos reales (`docs/preview/`).

## GitHub Actions
`.github/workflows/burger-chef-3d.yml` (en la raíz del repositorio) importa el proyecto con Godot 4.7.2, ejecuta las pruebas, saca capturas del menú en móviles y tabletas y compila el APK de Android. Las capturas y el APK se descargan desde la pestaña Actions > ejecución > Artifacts.
