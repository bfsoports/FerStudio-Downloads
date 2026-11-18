# Licencias de recursos

Cada recurso incluido en el juego, con autoría, licencia, origen y modificaciones. Ningún recurso
procede de una franquicia existente; nombres, lore, mapa, criaturas, logotipo e interfaz son originales.

## Resumen

| Grupo | Autoría | Licencia | Origen |
|---|---|---|---|
| Motor | Godot Engine y colaboradores | MIT | godotengine.org |
| Superviviente, Brumal, Zarzo, turismo, furgoneta, tractor | Generados con Hyper3D Rodin para este proyecto; optimizados con `tools/blender/import_rodin.py` | Contenido generado por la cuenta del titular del proyecto en Hyper3D (ver nota) | hyper3d.ai |
| Texturas PBR (52 conjuntos) | Poly Haven | CC0 1.0 | polyhaven.com (tabla abajo) |
| Efectos visuales (llama, impactos, rayo, nube, aura) | Binbun3D — BinbunVFX Vol. 2 | CC0 1.0 (`license.txt` incluido en cada pack) | bun3d.com · aportados por el titular del proyecto |
| Tipografías Barlow y Barlow Condensed | The Barlow Project Authors (Jeremy Tribby) | SIL Open Font License 1.1 (`assets/fonts/OFL_Barlow.txt`) | github.com/jpt/barlow |
| Edificios, vegetación, objetos, estructuras, Farol, brazos | Generados por los guiones de `tools/blender/` | Propios del proyecto | este repositorio |
| Follaje, señales, carteles, nubes, agua, ruido, mapa, iconos, logotipo | Generados por `tools/textures/`, `tools/world/` y `tools/ui/` | Propios del proyecto | este repositorio |
| Sonido (51 efectos, ambientes y música) | Sintetizado por `tools/audio/synth.py` (sin muestras de terceros) | Propio del proyecto | este repositorio |

### Nota sobre Hyper3D Rodin

Generaciones realizadas desde la cuenta conectada del titular del proyecto (registro en
hyper3d.ai/workspace/rodin/…). Las condiciones de uso comercial dependen del plan de esa cuenta en
Hyper3D: **compruébalas antes de publicar**. Identificadores de las generaciones:

| Recurso | Malla | Esqueleto y animación |
|---|---|---|
| Superviviente | 2ea0231c-8f83-40d4-9aec-7c098ebeefc6 | ef6e0133-6ef5-4f08-9f83-0ba3a752af49 |
| Brumal | 620a6f80-c9f6-4a97-9c2b-667fed017b3f | 9af13d76-f07c-46b8-ad16-7f6e755adcd7 |
| Zarzo | f101e787-f07d-4ab5-9b95-6da044da34d2 | 3460c088-a493-4b00-9299-0855f3a56297 |
| Turismo (y variante roja) | efbaa8d3-3a53-438c-8514-4e9e6b5b259f | — |
| Furgoneta | e1a53b47-ac1a-4f00-9581-fdbebf798fdf | — |
| Tractor | 46c50b24-9846-4ecc-a78c-3c22dc5c333c | — |

Modificaciones: escala real, origen en el suelo, orientación, materiales del proyecto, texturas
reducidas a 1024/512 px con compresión VRAM, máscara de prenda teñible, variante de color del
turismo, clips renombrados y llevados «en el sitio», clips de acción añadidos al esqueleto (poses
de `gen_character.py` reorientadas), gorro/mochilas/mascarilla ajustados, brazos en primera
persona recortados del cuerpo y animados por cinemática inversa.

### Efectos de Binbun3D

Copiados por `tools/vfx/import_binbun.py` desde los ZIP «…FXFree» con `license.txt` CC0: FlameFX,
StylizedHitFX, ElectricFX, DarkMagicFX (área) y StatusFX. Cambios: sin escenas de demostración ni
HDR, sin botones de editor con enlaces externos, sin desvanecido por profundidad (móvil), rayo sin
niebla. **No se integran** los ZIP del mismo lote sin fichero de licencia (BeamVFX, LootVFX, PortalVFX,
MagicProjectilesVFX, MuzzleFlashVFX) ni «Pipoya VFX LightPillar», porque no se pudo verificar su
licencia dentro del material aportado; ni BattleFX, ExplosionFX ni ElementalMagicFX, por no encajar
con un juego sin combate.

## Texturas de Poly Haven (CC0 1.0)

| Conjunto en el juego | Recurso original | URL | Licencia | Modificación |
|---|---|---|---|---|
| `asphalt` | asphalt_02 | https://polyhaven.com/a/asphalt_02 | CC0 1.0 | reducida a 512 px, ORM empaquetado, JPG/PNG |
| `bark_oak` | bark_brown_02 | https://polyhaven.com/a/bark_brown_02 | CC0 1.0 | reducida a 512 px, ORM empaquetado, JPG/PNG |
| `bark_pine` | pine_bark | https://polyhaven.com/a/pine_bark | CC0 1.0 | reducida a 512 px, ORM empaquetado, JPG/PNG |
| `bark_willow` | bark_willow | https://polyhaven.com/a/bark_willow | CC0 1.0 | reducida a 512 px, ORM empaquetado, JPG/PNG |
| `brick_factory` | factory_brick | https://polyhaven.com/a/factory_brick | CC0 1.0 | reducida a 512 px, ORM empaquetado, JPG/PNG |
| `brick_red` | red_brick_03 | https://polyhaven.com/a/red_brick_03 | CC0 1.0 | reducida a 512 px, ORM empaquetado, JPG/PNG |
| `carpet_dirty` | dirty_carpet | https://polyhaven.com/a/dirty_carpet | CC0 1.0 | reducida a 512 px, ORM empaquetado, JPG/PNG |
| `cobble` | cobblestone_floor_08 | https://polyhaven.com/a/cobblestone_floor_08 | CC0 1.0 | reducida a 512 px, ORM empaquetado, JPG/PNG |
| `concrete_block` | concrete_block_wall_02 | https://polyhaven.com/a/concrete_block_wall_02 | CC0 1.0 | reducida a 512 px, ORM empaquetado, JPG/PNG |
| `concrete_floor` | concrete_floor_worn_001 | https://polyhaven.com/a/concrete_floor_worn_001 | CC0 1.0 | reducida a 512 px, ORM empaquetado, JPG/PNG |
| `concrete_painted` | painted_concrete | https://polyhaven.com/a/painted_concrete | CC0 1.0 | reducida a 512 px, ORM empaquetado, JPG/PNG |
| `concrete_wall` | concrete_wall_008 | https://polyhaven.com/a/concrete_wall_008 | CC0 1.0 | reducida a 512 px, ORM empaquetado, JPG/PNG |
| `fabric_denim` | denim_fabric | https://polyhaven.com/a/denim_fabric | CC0 1.0 | reducida a 512 px, ORM empaquetado, JPG/PNG |
| `fabric_pattern` | fabric_pattern_07 | https://polyhaven.com/a/fabric_pattern_07 | CC0 1.0 | reducida a 512 px, ORM empaquetado, JPG/PNG |
| `leather_brown` | brown_leather | https://polyhaven.com/a/brown_leather | CC0 1.0 | reducida a 512 px, ORM empaquetado, JPG/PNG |
| `metal_blue` | blue_metal_plate | https://polyhaven.com/a/blue_metal_plate | CC0 1.0 | reducida a 512 px, ORM empaquetado, JPG/PNG |
| `metal_corr_rust` | rusty_corrugated_iron | https://polyhaven.com/a/rusty_corrugated_iron | CC0 1.0 | reducida a 512 px, ORM empaquetado, JPG/PNG |
| `metal_corrugated` | corrugated_iron_02 | https://polyhaven.com/a/corrugated_iron_02 | CC0 1.0 | reducida a 512 px, ORM empaquetado, JPG/PNG |
| `metal_green` | green_metal_rust | https://polyhaven.com/a/green_metal_rust | CC0 1.0 | reducida a 512 px, ORM empaquetado, JPG/PNG |
| `metal_plate` | metal_plate | https://polyhaven.com/a/metal_plate | CC0 1.0 | reducida a 512 px, ORM empaquetado, JPG/PNG |
| `metal_rust` | rusty_metal_02 | https://polyhaven.com/a/rusty_metal_02 | CC0 1.0 | reducida a 512 px, ORM empaquetado, JPG/PNG |
| `metal_shutter` | painted_metal_shutter | https://polyhaven.com/a/painted_metal_shutter | CC0 1.0 | reducida a 512 px, ORM empaquetado, JPG/PNG |
| `pavement` | concrete_pavement | https://polyhaven.com/a/concrete_pavement | CC0 1.0 | reducida a 512 px, ORM empaquetado, JPG/PNG |
| `plaster_blue` | blue_plaster_weathered | https://polyhaven.com/a/blue_plaster_weathered | CC0 1.0 | reducida a 512 px, ORM empaquetado, JPG/PNG |
| `plaster_white` | plastered_wall_04 | https://polyhaven.com/a/plastered_wall_04 | CC0 1.0 | reducida a 512 px, ORM empaquetado, JPG/PNG |
| `plaster_worn` | worn_plaster_wall | https://polyhaven.com/a/worn_plaster_wall | CC0 1.0 | reducida a 512 px, ORM empaquetado, JPG/PNG |
| `plaster_yellow` | yellow_plaster | https://polyhaven.com/a/yellow_plaster | CC0 1.0 | reducida a 512 px, ORM empaquetado, JPG/PNG |
| `rock_boulder` | rock_boulder_dry | https://polyhaven.com/a/rock_boulder_dry | CC0 1.0 | reducida a 512 px, ORM empaquetado, JPG/PNG |
| `rock_cliff` | rock_face_03 | https://polyhaven.com/a/rock_face_03 | CC0 1.0 | reducida a 512 px, ORM empaquetado, JPG/PNG |
| `rock_mossy` | mossy_rock | https://polyhaven.com/a/mossy_rock | CC0 1.0 | reducida a 512 px, ORM empaquetado, JPG/PNG |
| `roof_clay` | clay_roof_tiles_02 | https://polyhaven.com/a/clay_roof_tiles_02 | CC0 1.0 | reducida a 512 px, ORM empaquetado, JPG/PNG |
| `roof_slate` | grey_roof_tiles_02 | https://polyhaven.com/a/grey_roof_tiles_02 | CC0 1.0 | reducida a 512 px, ORM empaquetado, JPG/PNG |
| `stone_wall` | rustic_stone_wall_02 | https://polyhaven.com/a/rustic_stone_wall_02 | CC0 1.0 | reducida a 512 px, ORM empaquetado, JPG/PNG |
| `t_dirt` | brown_mud_leaves_01 | https://polyhaven.com/a/brown_mud_leaves_01 | CC0 1.0 | reducida a 1024 px, ORM empaquetado, JPG/PNG |
| `t_forest` | forest_leaves_02 | https://polyhaven.com/a/forest_leaves_02 | CC0 1.0 | reducida a 1024 px, ORM empaquetado, JPG/PNG |
| `t_grass` | leafy_grass | https://polyhaven.com/a/leafy_grass | CC0 1.0 | reducida a 1024 px, ORM empaquetado, JPG/PNG |
| `t_grass_dry` | sparse_grass | https://polyhaven.com/a/sparse_grass | CC0 1.0 | reducida a 512 px, ORM empaquetado, JPG/PNG |
| `t_gravel` | gravel_floor_02 | https://polyhaven.com/a/gravel_floor_02 | CC0 1.0 | reducida a 512 px, ORM empaquetado, JPG/PNG |
| `t_mud` | brown_mud_02 | https://polyhaven.com/a/brown_mud_02 | CC0 1.0 | reducida a 512 px, ORM empaquetado, JPG/PNG |
| `t_pebbles` | ganges_river_pebbles | https://polyhaven.com/a/ganges_river_pebbles | CC0 1.0 | reducida a 512 px, ORM empaquetado, JPG/PNG |
| `t_rock` | rock_ground | https://polyhaven.com/a/rock_ground | CC0 1.0 | reducida a 512 px, ORM empaquetado, JPG/PNG |
| `t_soil` | farm_soil | https://polyhaven.com/a/farm_soil | CC0 1.0 | reducida a 512 px, ORM empaquetado, JPG/PNG |
| `thatch` | reed_roof_03 | https://polyhaven.com/a/reed_roof_03 | CC0 1.0 | reducida a 512 px, ORM empaquetado, JPG/PNG |
| `tiles_floor` | floor_tiles_06 | https://polyhaven.com/a/floor_tiles_06 | CC0 1.0 | reducida a 512 px, ORM empaquetado, JPG/PNG |
| `tiles_white` | long_white_tiles | https://polyhaven.com/a/long_white_tiles | CC0 1.0 | reducida a 512 px, ORM empaquetado, JPG/PNG |
| `wallpaper_old` | decrepit_wallpaper | https://polyhaven.com/a/decrepit_wallpaper | CC0 1.0 | reducida a 512 px, ORM empaquetado, JPG/PNG |
| `wood_dark` | dark_wooden_planks | https://polyhaven.com/a/dark_wooden_planks | CC0 1.0 | reducida a 512 px, ORM empaquetado, JPG/PNG |
| `wood_floor` | wood_floor_worn | https://polyhaven.com/a/wood_floor_worn | CC0 1.0 | reducida a 512 px, ORM empaquetado, JPG/PNG |
| `wood_green` | green_rough_planks | https://polyhaven.com/a/green_rough_planks | CC0 1.0 | reducida a 512 px, ORM empaquetado, JPG/PNG |
| `wood_grey` | wood_planks_grey | https://polyhaven.com/a/wood_planks_grey | CC0 1.0 | reducida a 512 px, ORM empaquetado, JPG/PNG |
| `wood_raw` | raw_plank_wall | https://polyhaven.com/a/raw_plank_wall | CC0 1.0 | reducida a 512 px, ORM empaquetado, JPG/PNG |
| `wood_siding` | weathered_brown_planks | https://polyhaven.com/a/weathered_brown_planks | CC0 1.0 | reducida a 512 px, ORM empaquetado, JPG/PNG |
## Generados por el proyecto

| Recurso | Guion |
|---|---|
| 26 edificios con interiores, 129 objetos de escenario, 50 objetos, 13 estructuras, puertas | `tools/blender/gen_buildings.py`, `building_specs.py`, `gen_props*.py`, `gen_items.py`, `gen_structures.py` |
| 39 modelos de vegetación con LOD, rocas y acantilados | `tools/blender/gen_vegetation.py` |
| Farol (criatura) y personaje procedimental de reserva | `tools/blender/gen_creatures.py`, `gen_character.py` |
| Texturas de follaje, corteza de abedul, agua, nubes, ruido | `tools/textures/make_foliage.py`, `make_procedural.py` |
| Atlas de señales y carteles (49 rótulos ficticios) | `tools/textures/make_signs.py` |
| Relieve, mezcla de suelos, mapa del valle | `tools/world/build_world.py` |
| 96 iconos de interfaz (SVG), emblema, logotipo, iconos de Android | `tools/ui/make_icons.py`, `make_logo.py` |
| Iconos de objetos (render) | `tools/godot/render_icons.gd` |
