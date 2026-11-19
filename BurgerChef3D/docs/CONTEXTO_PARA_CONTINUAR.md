# Contexto para continuar: Burger Chef 3D

Pégame este archivo (o súbelo) en la nueva cuenta para retomar el proyecto sin empezar de cero.

## Qué es
Simulador 3D en primera persona de una hamburguesería para Android, en Godot 4.7.2 (GDScript, renderer GL Compatibility), en horizontal. Controles táctiles (joystick a la izquierda, cámara deslizando a la derecha) y de escritorio (WASD, ratón, E, R para recetas, Esc). Idioma por defecto: español, con inglés.

## Estado real (importante)
- Todo el código está escrito, pero **NUNCA se ha abierto en Godot ni probado en un móvil**. Las pruebas automáticas (`tests/`) no se han ejecutado.
- Comprobaciones hechas sin motor: `tools/validate_data.py` (0 errores), `tools/static_check.py` (0 errores en 91 scripts) y `tools/check_models.py`, `tools/check_ui_layout.py`, `tools/check_media.py` y `tools/gen_icons.py --check` (0 errores). No sustituyen a Godot.
- Pendiente: probar en Godot y en el móvil lo hecho en la última ronda (tutorial, fregadero, mejoras nuevas, vibración), vista previa 3D en la tienda, medición de rendimiento, exportación firmada y requisitos de la tienda. AdMob integrado con IDs de prueba; falta instalar el plugin de Poing Studios, probarlo en el móvil y poner los IDs reales (`docs/anuncios_admob.md`).
- Lista completa de problemas: `docs/known_issues.md`. Estado por fases: `docs/development_status.md`. Requisitos con su estado: `docs/acceptance_checklist.md`.

## Estructura clave
- `scripts/core/`: constantes, utilidades, `events.gd` (bus de señales), `loc.gd` (traducciones), `catalog.gd` (carga los JSON), `data_validator.gd`.
- `scripts/save/`: `save_manager.gd` (guardado JSON versionado), `settings_manager.gd`.
- `scripts/economy/`, `scripts/missions/`, `scripts/audio/`: economía central, misiones/logros, audio.
- `scripts/restaurant/restaurant.gd`: construye todo el restaurante en código (muebles y equipos con modelos reales; estructura y decoración procedurales).
- `scripts/core/model_lib.gd` y `model_table.gd` (generada): cargan los modelos reales de `assets/models/` (KayKit Restaurant Bits y Kenney Food Kit, CC0).
- `scripts/ingredients/`, `scripts/cooking/`, `scripts/orders/`, `scripts/customers/`: cocina, pedidos y clientes.
- `scripts/player/player_controller.gd`, `scripts/interface/touch_controls.gd`: jugador y controles.
- `scripts/tutorial/`: tutorial jugable (`tutorial.gd`, pasos y flecha 3D; `tutorial_pointer.gd`, flecha en el borde de la pantalla).
- `scripts/cooking/sink_station.gd` y `scripts/orders/dirty_tray.gd`: fregadero y bandejas sucias. `scripts/core/haptics.gd`: vibración (autoload).
- `scripts/interface/` y `scripts/interface/screens/`: HUD, menús y pantallas.
- `resources/data/*.json`: recetas, niveles, misiones, mejoras, tienda, layout (se editan a mano).
- `resources/i18n/strings.json`: todos los textos (es/en). Se regenera con `tools/gen_strings.py`.
- `tools/`: generadores (`gen_assets.py`, `gen_data.py`, `gen_strings.py`, `gen_models.py`) y comprobaciones (`validate_data.py`, `static_check.py`, `check_models.py`, `check_ui_layout.py`, `preview_layout.py`, `preview_ui.py`) y `gen_icons.py` (copia los iconos del pack y `--check` los valida).

## Reglas de trabajo acordadas
- Proyecto real, sin pseudocódigo ni sistemas falsos; no afirmar que algo funciona sin comprobarlo.
- Distinguir: implementado / comprobado estáticamente / probado en Godot / probado en Android.
- No marcar como verificado lo que no se ha ejecutado.

## Siguientes pasos
1. Abrir en Godot 4.7.2 (importa `assets/models/`), corregir errores de primera carga y ejecutar `tests/test_runner.tscn` (incluye `test_models.gd`).
2. Revisar un turno completo en el editor (menú, partida, pausa, resultados) y ajustar escalas y luces.
3. Tutorial jugable y función del fregadero.
4. Probar en móvil: táctil, rendimiento, aspectos de pantalla.
5. Exportar APK/AAB y revisar los requisitos de Google Play.

## Assets reales integrados (KayKit Restaurant Bits y Kenney Food Kit, ambos CC0)
El usuario aportó dos packs de assets y pidió reemplazar lo que se pudiera por los modelos reales; **lo que no tiene asset en los packs no se pone** (ejemplo suyo: los pepinillos). Hecho:
- Solo se copian a `assets/models/` los modelos usados (0,85 MB). La tabla `scripts/core/model_table.gd` se genera con `tools/gen_models.py` (escala y desplazamiento salen de las cajas envolventes); licencias registradas en `docs/licenses.md`.
- `FoodModels` usa modelos reales para todas las capas, con modelos distintos de crudo, cocinado y quemado (carne y medallón vegetal; bacon y patatas con tinte oscuro al quemarse). La bebida, el bacon, las patatas y la bandeja son de Kenney; el resto de KayKit.
- `restaurant.gd`: mostradores, fogones, campana, neveras, cajas, fregadero, tablas de cortar, mesas y sillas son modelos reales; la distribución de `layout.json` se ajustó a módulos de 2 m y la sala se amplió a 18 x 18 m (cocina de 18 x 8,5 m, pasillos de 1,6 a 2,2 m) porque se pidió más espacio para moverse, sin escalar ningún modelo. Paredes, suelos, techo, carteles y clientes siguen siendo procedurales (lámparas, plantas, campanita, papelera, bandeja, freidora y bebidas pasaron después a modelos propios, ver más abajo).
- **Ingredientes eliminados por no tener asset:** pepinillos (`pickle`), salsa de la casa (`sauce`) y salsa picante (`hot_sauce`). La receta `spicy` se sustituyó por `blt` (Hamburguesa BLT). Quedan 11 ingredientes y 10 recetas.
- Nada de esto se ha cargado todavía en Godot: ver `docs/known_issues.md` (puntos 17-24). Vistas de la cocina con los modelos reales en `docs/preview/`.

## Interfaz rediseñada e iconos reales (última petición del usuario)
El usuario subió `Free_Icon_Pack_v3_1__Basic_.zip` y pidió iconos de verdad y cambiar casi por completo la interfaz porque estaba muy estirada hacia los lados. Hecho:
- `ContentFrame` (marco de ancho máximo 1280 px) envuelve HUD, menús y diálogos; las ventanas miden 1020 px y todas las tarjetas son de ancho fijo en cuadrículas centradas (`UIKit.grid`, `UIKit.column`, `UIKit.centered`). Nuevo tema oscuro compacto en `ui_theme.gd` y componentes nuevos en `ui_kit.gd` (`icon_text_button`, `chip`, `stat_tile`, `pips`, `badge`...). Todas las pantallas se reescribieron (menú principal, 8 pantallas de menú, HUD, pausa, resultados, ajustes, recetas).
- Iconos: `tools/gen_icons.py` copia sin modificar 42 iconos del pack a `assets/icons/pack/` (64 y 256 px) y genera `scripts/interface/icon_table.gd`; `UIKit.icon(nombre, px)` los reescala. Los iconos SVG antiguos se eliminaron; solo queda la mira (`icon_reticle.svg`). Las estaciones siguen enviando nombres de indicador (`grab`, `drop`, `use`, `tray`, `blocked`, `trash`) que el HUD traduce a iconos reales en `HUD.PROMPT_ICONS`.
- Licencia del pack: propia, no CC0 (ver `docs/licenses.md`); no publicar el proyecto con los iconos en un repositorio público.
- Nada de esto se ha visto en Godot todavía: ver `docs/known_issues.md` (puntos 25-29).

## Interfaz más grande y adaptable, vídeo de presentación y música
El usuario ejecutó el juego en Godot (capturas en Android): la interfaz se veía **muy pequeña** y no aprovechaba la pantalla. Pidió: interfaz más grande que se ajuste a cada pantalla (sin estirarla de lado a lado), el vídeo de FerStudio en cada arranque como pantalla de carga, y la música aportada solo en las partidas, más ligera. Hecho:
- Lienzo base de 1280 x 720 a **1024 x 576**. `ContentFrame` de 1500. Ventanas, columnas y tarjetas se calculan con el lienzo disponible y se recolocan al cambiar el tamaño de la interfaz. Ajuste nuevo «Tamaño de la interfaz» (pequeña 0,9 / normal 1,0 / grande 1,15).
- Menú principal con accesos en mosaico, hamburguesa a la derecha; HUD con una pastilla de tiempo+objetivo y las comandas en su fila; controles táctiles al 0,8.
- (el vídeo de arranque se eliminó después: ver la última ronda).
- (sustituida después por `music_jazz.ogg`, ver más abajo) música de las partidas en `AudioManager.MUSIC_FILES["game"]`.
- Nada de esto se ha ejecutado en Godot desde que se hizo: ver `docs/known_issues.md` (puntos 25-31).

## Modelos propios del usuario (última ronda)
El usuario subió 7 GLB generados con Tripo (dispensador de bebidas, freidora de patatas, lámpara colgante, planta en maceta, campanita de servicio, bandeja de servicio y bote de basura) y de nuevo el Kenney Food Kit (ya integrado; no hacía falta nada nuevo de él). Hecho:
- `tools/optimize_models.py` (numpy + Pillow) los simplifica sin re-hornear la textura (QEM de medio colapso, costuras UV respetadas, máximo 2 texeles de desplazamiento, sin pisar otras islas del atlas, relleno del fondo del atlas) y los deja en `assets/models/custom/`: de 17.000-104.000 a 1.700-10.200 triángulos. Vistas con textura en `docs/preview/models_custom.png`.
- `gen_models.py` tiene el pack `custom` (claves `fryer`, `dispenser`, `lamp`, `plant`, `bell`, `trash`, `tray`); se quitaron `pot`, `fridge_b` y la bandeja de Kenney porque ya no se usan.
- Freidora: mostrador de 2 x 1 m (`layout.json`: `fryer.d` = 1,0) con dos freidoras (la segunda con la mejora); `CookStation.configure` admite `lock_y`. Bebidas: dispensador sobre mostrador en la pared este. Campanita dentro de un pivote para la animación. Lámparas (9) y plantas (4) con modelo; la bombilla sigue siendo procedural.
- La escena sube de ~37.000 a ~109.000 triángulos; **licencia de Tripo por confirmar** (depende del plan). Nada de esto se ha cargado en Godot: `docs/known_issues.md` puntos 32-38.

## Tras la prueba en Android de los modelos propios
El usuario probó la versión con los modelos de Tripo en su móvil y pidió: mejor calidad de modelos, que nada tape la vista, no poner comida encima de neveras (mesa o caja) y bajar los mostradores para ver qué hay en cada caja. Hecho (sin probar en Godot):
- Más detalle en los modelos (freidora 18.000, dispensador 14.000 triángulos...) y tolerancia de textura de 1,25 texeles; `project.godot` importa las texturas sin compresión con pérdida (`[importer_defaults]`). Requiere importar en una carpeta nueva.
- Carnes y queso sobre tablas de cortar en un mostrador bajo (adiós neveras); mostradores de ingredientes a 0,75 m (`BIN_SURF`), uno continuo por pared.
- HUD: comandas en columna a la derecha bajo recetas/pausa; pastilla de interacción abajo; rótulos 3D ocultos a menos de 1,8 m.
- Escena ~154.000 triángulos en la vista previa. Detalles: `docs/known_issues.md` puntos 36-42.

## Icono, clientes reales, pantalla de carga y música (última ronda)
El usuario subió: imagen de una hamburguesa (icono), su logotipo de FerStudio, una captura de la pantalla «Login…» de Brotato, la pista «Smooth Instrumental Jazz Music» (Tunetank, MP3 5,3 MB) y tres ZIP de KayKit (Skeletons FREE, Skeletons EXTRA y Character Animations, todos CC0). Pidió además «otro ZIP con animación de transición» que no llegó. Hecho (sin probar en Godot):
- Icono: `tools/gen_app_icon.py` genera `icon.png` y los iconos de Android desde la imagen (ya no los dibuja `gen_assets.py`).
- Clientes: `scripts/customers/character_lib.gd` + `tools/gen_characters.py` (maniquí teñido + esqueletos Minion/Rogue/Mage, animaciones andar/esperar/saludar/celebrar/quejarse en `assets/characters/customer_anims.glb`). Prueba en `tests/unit/test_characters.gd`.
- Pantalla de carga estilo Brotato con el logotipo (`scripts/interface/loading_screen.gd`), usada por `SceneManager.change_scene` (carga en segundo plano).
- Música de las partidas: `assets/audio/music_jazz.ogg` (0,9 MB); menú en OGG. Licencia de la pista por confirmar.
- Detalles: `docs/known_issues.md` puntos 43-47.

## Tras la segunda prueba en Android (última ronda)
El usuario probó en Godot: vio el error de `hud.gd` (columna de comandas con tipo equivocado) y avisos; pidió quitar el vídeo de arranque (solo la imagen), un menú más cómodo y entendible que aproveche la pantalla, botones más gruesos y arreglar listas que no se desplazaban. Hecho (sin probar en Godot): sin vídeo (arranque = pantalla de carga con logotipo), errores y avisos corregidos, `TouchScroll` en todas las listas, menú principal nuevo (columna a media pantalla, 2 x 3 secciones), botones más altos y con más relieve, ventanas de hasta 1220 x 720. Ver `docs/known_issues.md` puntos 48-52.

## Tutorial, fregadero y juego completo (última ronda)
El usuario confirmó que **todos los assets son de uso libre** (modelos de Tripo y música incluidos) y pidió el tutorial jugable bien hecho y completar todas las funciones. Hecho (sin probar en Godot):
- Tutorial jugable de 17 pasos con tarjeta, flecha 3D y flecha de borde; pasos de cocina calculados con el estado real; sin tiempo, sin quemarse, sin contar estadísticas; 100 monedas la primera vez. Se ofrece al pulsar JUGAR la primera vez y está en JUGAR > Tutorial; se salta desde la pausa.
- Fregadero funcional: desde el nivel 6 (y modo libre dificultad 3+) la bandeja queda sucia tras entregar, se lleva al fregadero, se lava sola en 3 s y vuelve a su puesto.
- Mejoras nuevas: «Recetas nuevas» (4 recetas), «Catálogo de decoración» (10 artículos) y «Fregadero rápido» (12 mejoras en total). Vibración con ajuste. Avisos de novedades en el menú. Licencias de Godot y OFL en Créditos. Misión «Bandejas relucientes».
- Detalles: `docs/known_issues.md` puntos 53-59.

## Anuncios, empresa y Amazon (última ronda)
El usuario probó la versión anterior en Godot (Android) y le gustó. Pidió: recetas del turno más grandes, hamburguesa del menú más a la derecha, anuncios AdMob (recompensado e intersticial al perder) **de prueba hasta tener sus IDs**, los datos de su empresa (rincondigitaloficial.com) y preparar Amazon Appstore. Hecho (sin probar en Godot):
- Empresa: **FerStudio**, de **Bairon Fernando Portocarrero Rodríguez**, soporte `bfsoports@gmail.com`, web rincondigitaloficial.com (privacidad, términos, ayuda). Está en Créditos y en Ajustes > Privacidad y ayuda.
- Anuncios: `scripts/ads/ads_manager.gd` (autoload `Ads`), configuración en `resources/data/ads_config.json` y guía en `docs/anuncios_admob.md`. Segunda oportunidad, x2 monedas, monedas gratis e intersticial al perder.
- Amazon: identificador `com.ferstudio.burgerchef3d`, versión 1.0.0, preset «Amazon Appstore (Fire, APK)», recursos en `store/` y guía en `docs/amazon_appstore.md`. La Appstore solo funciona ya en Fire tablets y Fire TV (objetivo: Fire tablets).
- Web: todo vive en la web de FerStudio (https://rincondigitaloficial.com), un sitio estático en Netlify con Decap CMS (el usuario envió su `dist`). Para Burger Chef 3D se añadieron la ficha completa, `/legal/privacidad-burger-chef-3d/`, `/legal/terminos-burger-chef-3d/` (ES + EN) y `/app-ads.txt`. El sitio de prueba ferstudioburgerchef3d.netlify.app redirige ahí. Textos definitivos, sin marcadores: el usuario no revisa antes de publicar. Nunca publicar su ciudad ni su teléfono.
- El usuario vive en Colombia (ley aplicable en términos y Ley 1581 de 2012 en privacidad). La política colombiana pide también ciudad, dirección y teléfono del responsable: el usuario aún no los ha dado.
- La cuenta de AdMob del usuario está bloqueada y en apelación (8-11-2026): el juego sigue con IDs de prueba.
- Cuando el juego salga en Amazon: en la ficha de la web, cambiar el estado a «Disponible», poner la versión y el enlace a la tienda (en el CMS: campos estado, version y tienda de `src/content/juegos/burgerchef3d.json`).
- Pendiente del usuario: IDs reales de AdMob, keystore, capturas y su nombre legal y dirección en la consola de Amazon.
- Detalles: `docs/known_issues.md` puntos 60-67.

## Carpeta de trabajo
El proyecto completo está en `BurgerChef3D_Godot_4.7.2.zip` (carpeta `BurgerChef3D/`). Empieza leyendo `docs/development_status.md` y `docs/known_issues.md`.

## Menú nuevo, iconos de Canva y GitHub Actions (18-11-2026)
El usuario envió una imagen de cómo quería el menú (`sii.zip`: fondo, logotipo, botones JUGAR y CONTINUAR y una hoja de iconos de referencia) y pidió quitar todos los iconos, hacer otros nuevos 3D cartoon en Canva (hojas de 12), que todo se adapte a cualquier pantalla y probar y compilar en GitHub Actions. Hecho y **probado en Godot 4.7.2** (con renderizado real por software):
- Menú principal reescrito (`main_menu.gd`) a partir del diseño de referencia de 1672 x 941: fondo en modo «cubrir» con la hamburguesa centrada en el hueco libre (sin bandas negras ni estirado; fondo ampliado x2 con EDSR), logotipo, JUGAR (texto traducible sobre la imagen sin texto), CONTINUAR, 6 secciones en pastillas marrones y barra de monedas | nivel | corazón. Capturas revisadas en 20:9, 16:9, 21:9, 720p y 4:3.
- 48 iconos nuevos de Canva (4 hojas de 12, fondo quitado en Canva) en `assets/ui/icons/` (WebP de 160 px, 307 KB en total). Pack antiguo, `icon_table.gd`, `gen_icons.py` y la mira SVG eliminados (la mira se dibuja en código). Los nombres antiguos `rocket` y `wheel` se redirigen a `play` y `palette`.
- Tema (`ui_theme.gd`) a juego: Fredoka Bold, ventanas chocolate con borde caramelo, botones con contorno oscuro.
- Pruebas: 616 correctas, 0 fallidas (se corrigieron el ejecutor, que ahora corre en diferido, y recuentos antiguos de recetas y misiones). Hay que importar dos veces: en la primera algunos `.gltf` se importan antes que su textura.
- `.github/workflows/burger-chef-3d.yml`: pruebas, capturas en 8 tamaños y APK de depuración (arm64 + armeabi-v7a, sin Gradle porque el plugin de AdMob aún no está instalado).
- La primera sección se mantiene como «RESTAURANTE» (la referencia decía «TIENDA», pero esa pantalla es el resumen del restaurante; la tienda es «PERSONALIZAR»). Se cambia en `tools/gen_strings.py` (`menu.restaurant`).

## Pantallas completas, más iconos y rendimiento (19-11-2026)
El usuario probó el APK: le gustó el menú y pidió que las secciones no fueran ventanas flotantes sino pantalla completa aprovechando el espacio, iconos donde faltaban (tienda de decoración, mejoras...), arreglar las recetas del turno (asimétricas y pequeñas) y quitar el lag (más de 30 FPS estables sin perder calidad ni mecánicas). Hecho y probado en Godot 4.7.2:
- `UIKit.screen_shell`: todas las pantallas del menú y las recetas del turno ocupan la pantalla completa (cabecera con icono, título, monedas y cerrar; respeta muescas). Cada pantalla reparte el ancho con `UIKit.fill_columns` (mejoras y recetas en 2 columnas, personalizar en 4, misiones en 2, ajustes y créditos en 2 columnas en móviles anchos).
- 24 iconos más de Canva (hojas 5 y 6): ingredientes, plancha, freidora, tabla, rodillo, suelo, mostrador, mesa, silla, lámpara, letrero, planta, caja registradora, fregadero, caja y reloj de arena. Cada mejora, categoría y artículo de la tienda y cada misión tiene su icono; las recetas se dibujan con los iconos de sus ingredientes apilados (`UIKit.burger_stack`).
- Recetas del turno: tarjeta en dos mitades (nombre, precio, reglas y hamburguesa despiezada | pasos grandes con icono).
- Rendimiento: fuera las 6 luces puntuales (una direccional de relleno da el mismo tono), sin sombra en modelos pesados de techo/pared (la pasada de sombras baja de 115.000 a 66.000 triángulos), resolución interna 3D limitada en móviles (alta 900 px, media 760, baja 620; la interfaz sigue nítida), `PerfGovernor` (si la media baja de 40 FPS quita antialiasing, luego resolución y por último sombras), precarga de los clientes y el HUD ya no recoloca la interfaz cada fotograma. Medido con `--bench` del capturador: de 170 a ~100 ms por fotograma en el renderizador por software (no representa un móvil; falta medir en el teléfono).
